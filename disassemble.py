#!/usr/bin/env python3
"""Disassemble XMOS ROM into beebasm-compatible 65C02 assembly.

Uses capstone for instruction decoding and recursive descent
to separate code from data.
"""

from capstone import *

ROM_FILE = "original.rom"
OUT_FILE = "xmos.asm"
BASE = 0x8000
SIZE = 0x4000

# Instructions that end a basic block (don't fall through)
TERMINATORS = {"rts", "rti", "jmp", "bra"}
# Branch instructions (conditional - have a target but also fall through)
BRANCHES = {"bcc", "bcs", "beq", "bne", "bmi", "bpl", "bvc", "bvs", "bbr", "bbs"}

OS_VECTORS = {
    0xFFB9: "osrdrm", 0xFFBF: "oseven", 0xFFC2: "gsinit", 0xFFC5: "gsread",
    0xFFCE: "osfind", 0xFFD1: "osgbpb", 0xFFD4: "osbput", 0xFFD7: "osbget",
    0xFFDA: "osargs", 0xFFDD: "osfile", 0xFFE0: "osrdch", 0xFFE3: "osasci",
    0xFFE7: "osnewl", 0xFFEE: "oswrch", 0xFFF1: "osword", 0xFFF4: "osbyte",
    0xFFF7: "oscli",
}

# Map capstone 65C02 addressing modes to beebasm format
# Capstone gives us mnemonic and op_str, we need to convert to beebasm syntax


def load_rom():
    with open(ROM_FILE, "rb") as f:
        return f.read()


def recursive_descent(rom, md):
    """Identify code bytes via recursive descent from known entry points.

    Returns:
        code_insns: dict mapping offset -> (size, mnemonic, op_str, bytes)
        labels: set of addresses that are branch/jump targets
    """
    code_insns = {}  # offset -> (size, mnemonic, op_str, raw_bytes)
    labels = set()
    worklist = []

    def enqueue(addr):
        off = addr - BASE
        if 0 <= off < SIZE and off not in code_insns:
            worklist.append(off)

    # Known entry points
    enqueue(0x802B)  # Service entry

    # Command handler addresses (from command table at &8219)
    cmd_handlers = [
        0x9033, 0x9141, 0x9340, 0x9285, 0x92E1, 0x98C1, 0x8F78, 0x9705,
        0x8D54, 0x8DCB, 0x8F0F, 0x8B95, 0x9C00, 0x940C, 0x8A68, 0x9A2F,
        0x9346, 0x845E, 0x846C,
    ]
    for h in cmd_handlers:
        labels.add(h)
        enqueue(h)

    while worklist:
        offset = worklist.pop()
        if offset in code_insns:
            continue
        if offset < 0 or offset >= SIZE:
            continue

        # Disassemble one instruction at a time
        code = rom[offset:]
        addr = BASE + offset
        found = False
        for insn in md.disasm(code, addr, count=1):
            found = True
            raw = rom[offset:offset + insn.size]
            code_insns[offset] = (insn.size, insn.mnemonic, insn.op_str, raw)

            mnem = insn.mnemonic
            op_str = insn.op_str

            # Extract target addresses
            if mnem in BRANCHES:
                # Conditional branch: target + fall through
                try:
                    target = int(op_str.replace("$", "0x"), 0)
                    labels.add(target)
                    enqueue(target)
                except ValueError:
                    pass
                # Fall through
                enqueue(addr + insn.size)

            elif mnem == "bra":
                # Unconditional branch
                try:
                    target = int(op_str.replace("$", "0x"), 0)
                    labels.add(target)
                    enqueue(target)
                except ValueError:
                    pass

            elif mnem == "jmp":
                if op_str.startswith("("):
                    # Indirect jump - can't trace statically
                    pass
                else:
                    try:
                        target = int(op_str.replace("$", "0x"), 0)
                        labels.add(target)
                        enqueue(target)
                    except ValueError:
                        pass

            elif mnem == "jsr":
                try:
                    target = int(op_str.replace("$", "0x"), 0)
                    labels.add(target)
                    enqueue(target)
                except ValueError:
                    target = None

                # Check for inline string routines:
                # &89F0: print inline string (null-terminated), return past it
                # &8A0F: copy inline string to buffer, return past it
                INLINE_STRING_ROUTINES = {0x89F0, 0x8A0F}
                if target in INLINE_STRING_ROUTINES:
                    # Skip the null-terminated string after JSR
                    str_offset = offset + insn.size
                    while str_offset < SIZE and rom[str_offset] != 0:
                        str_offset += 1
                    if str_offset < SIZE:
                        str_offset += 1  # skip the null terminator
                    enqueue(BASE + str_offset)
                else:
                    # Normal JSR: fall through after return
                    enqueue(addr + insn.size)

            elif mnem in ("rts", "rti"):
                pass  # End of block

            else:
                # Normal instruction: fall through
                enqueue(addr + insn.size)

        if not found:
            # Couldn't disassemble - skip this byte
            pass

    return code_insns, labels


def to_beebasm(mnemonic, op_str, addr, raw_bytes, labels_map):
    """Convert capstone disassembly to beebasm syntax.

    Returns (asm_string, needs_equb) where needs_equb means we should
    emit raw bytes instead.
    """
    mnem = mnemonic.upper()
    op = op_str.strip()

    # capstone uses $xx for hex, beebasm uses &xx
    # capstone formats:
    #   implied: ""
    #   accumulator: "a"
    #   immediate: "#$xx" or "#$xxxx"  (not for 6502)
    #   zero page: "$xx"
    #   zero page,x: "$xx, x"
    #   zero page,y: "$xx, y"
    #   absolute: "$xxxx"
    #   absolute,x: "$xxxx, x"
    #   absolute,y: "$xxxx, y"
    #   indirect: "($xxxx)"
    #   (indirect,x): "($xx, x)"
    #   (indirect),y: "($xx), y"
    #   (zp): "($xx)"  -- 65C02
    #   relative: "$xxxx"  (target address)

    # BRK is 2 bytes in capstone but 1 in beebasm - always EQUB
    if mnem == "BRK":
        return None, True

    # If instruction is 3 bytes (absolute addressing) but the operand is
    # in zero page (< &100), beebasm will optimize to 2-byte zero page form.
    # Force EQUB to preserve the original encoding.
    if len(raw_bytes) == 3:
        operand = raw_bytes[1] | (raw_bytes[2] << 8)
        # Check if this is an absolute mode instruction where ZP form exists
        # (i.e., operand < 256 and there's a ZP equivalent opcode)
        if operand < 0x100:
            opcode = raw_bytes[0]
            # These absolute opcodes have ZP equivalents - beebasm will optimize
            abs_to_zp = {
                0x0D, 0x0E, 0x0C,  # ORA abs, ASL abs, TSB abs
                0x2D, 0x2E, 0x2C,  # AND abs, ROL abs, BIT abs
                0x4D, 0x4E,        # EOR abs, LSR abs
                0x6D, 0x6E,        # ADC abs, ROR abs
                0x8D, 0x8E, 0x8C, 0x9C,  # STA abs, STX abs, STY abs, STZ abs
                0xAD, 0xAE, 0xAC,  # LDA abs, LDX abs, LDY abs
                0xCD, 0xCE, 0xCC,  # CMP abs, DEC abs, CPY abs
                0xED, 0xEE, 0xEC,  # SBC abs, INC abs, CPX abs
                0x1D, 0x1E, 0x1C,  # ORA abx, ASL abx, TRB abs
                0x3D, 0x3E, 0x3C,  # AND abx, ROL abx, BIT abx
                0x5D, 0x5E,        # EOR abx, LSR abx
                0x7D, 0x7E,        # ADC abx, ROR abx
                0x9D, 0x9E,        # STA abx, STZ abx
                0xBD, 0xBC, 0xBE,  # LDA abx, LDY abx, LDX aby
                0xDD, 0xDE,        # CMP abx, DEC abx
                0xFD, 0xFE,        # SBC abx, INC abx
                0x19, 0x39, 0x59, 0x79, 0x99, 0xB9, 0xD9, 0xF9,  # xxx aby
            }
            if opcode in abs_to_zp:
                return None, True

    if not op:
        # Implied
        return f"    {mnem}", False

    if op.lower() == "a":
        # Accumulator
        return f"    {mnem} A", False

    # Immediate
    if op.startswith("#"):
        val = op[1:].replace("0x", "&").replace("$", "&")
        return f"    {mnem} #{val}", False

    # (Indirect,X)
    if op.startswith("(") and op.endswith(", x)"):
        val = op[1:].split(",")[0].replace("0x", "&").replace("$", "&")
        return f"    {mnem} ({val},X)", False

    # (Indirect),Y
    if op.startswith("(") and op.endswith("), y"):
        val = op[1:].split(")")[0].replace("0x", "&").replace("$", "&")
        return f"    {mnem} ({val}),Y", False

    # (ZP) indirect - 65C02 - beebasm might not support
    if op.startswith("(") and op.endswith(")") and ", " not in op:
        # This is (zp) indirect addressing - 65C02
        # beebasm with CPU 1 should support this
        val = op[1:-1].replace("0x", "&").replace("$", "&")
        return f"    {mnem} ({val})", True  # Use EQUB to be safe

    # Indirect JMP ($xxxx) or JMP ($xxxx, x)
    if op.startswith("("):
        if op.endswith(", x)"):
            val = op[1:].split(",")[0].replace("0x", "&").replace("$", "&")
            return f"    {mnem} ({val},X)", False
        else:
            val = op[1:-1].replace("0x", "&").replace("$", "&")
            return f"    {mnem} ({val})", False

    # Absolute/ZP with X or Y index
    if ", " in op:
        parts = op.split(", ")
        val_str = parts[0].replace("0x", "&").replace("$", "&")
        reg = parts[1].upper()
        # Check if it's an internal label
        try:
            target = int(parts[0].replace("$", "0x"), 0)
            if target in labels_map:
                return f"    {mnem} {labels_map[target]},{reg}", False
            if target in OS_VECTORS:
                return f"    {mnem} {OS_VECTORS[target]},{reg}", False
        except ValueError:
            pass
        return f"    {mnem} {val_str},{reg}", False

    # Relative branch or absolute/zp address
    try:
        target = int(op.replace("$", "0x"), 0)
    except ValueError:
        val = op.replace("0x", "&").replace("$", "&")
        return f"    {mnem} {val}", False

    # Check if this is a relative branch
    is_branch = mnem.lower() in BRANCHES or mnem.lower() == "bra"
    if is_branch:
        if target in labels_map:
            return f"    {mnem} {labels_map[target]}", False
        # Branch to unlabelled address - emit as EQUB to preserve exact offset
        return None, True

    # Absolute or ZP address
    if target in labels_map:
        return f"    {mnem} {labels_map[target]}", False
    if target in OS_VECTORS:
        return f"    {mnem} {OS_VECTORS[target]}", False

    val = op.replace("0x", "&").replace("$", "&")
    return f"    {mnem} {val}", False


def generate(rom):
    """Generate beebasm assembly source."""
    md = Cs(CS_ARCH_MOS65XX, CS_MODE_MOS65XX_65C02)
    md.detail = False

    # Recursive descent to find code
    code_insns, labels = recursive_descent(rom, md)
    print(f"Found {len(code_insns)} instructions, {len(labels)} labels")

    # Resolve overlapping instructions: walk linearly and remove overlaps
    # The first instruction at each offset wins; overlapping later ones are removed
    occupied = set()
    to_remove = []
    for offset in sorted(code_insns.keys()):
        size = code_insns[offset][0]
        if any(b in occupied for b in range(offset, offset + size)):
            to_remove.append(offset)
        else:
            for b in range(offset, offset + size):
                occupied.add(b)
    for offset in to_remove:
        del code_insns[offset]
    if to_remove:
        print(f"Removed {len(to_remove)} overlapping instructions")

    # Only create labels for addresses that will actually be visited in the walk
    # A label is valid if offset is either a code_insn start or a data byte
    # that we'll walk over
    visited_offsets = set()
    offset = 0
    while offset < SIZE:
        visited_offsets.add(offset)
        if offset in code_insns:
            offset += code_insns[offset][0]
        else:
            offset += 1

    labels_map = {}
    for addr in sorted(labels):
        if BASE <= addr < BASE + SIZE and (addr - BASE) in visited_offsets:
            labels_map[addr] = f"L{addr:04X}"

    # Phase 3: generate output
    lines = []
    lines.append("\\ XMOS - MOS Extension ROM")
    lines.append("\\ By Richard Talbot-Watkins and Matt Godbolt, 1992")
    lines.append("\\ Reverse engineered disassembly")
    lines.append("")
    lines.append("CPU 1  \\ 65C02")
    lines.append("")
    lines.append("\\ OS entry points")
    for addr in sorted(OS_VECTORS):
        lines.append(f"{OS_VECTORS[addr]} = &{addr:04X}")
    lines.append("")
    lines.append("ORG &8000")
    lines.append("GUARD &C000")
    lines.append("")

    offset = 0
    while offset < SIZE:
        addr = BASE + offset

        # Emit label if needed
        if addr in labels_map:
            lines.append(f".{labels_map[addr]}")

        if offset in code_insns:
            size, mnem, op_str, raw = code_insns[offset]
            asm_line, needs_equb = to_beebasm(mnem, op_str, addr, raw, labels_map)

            if needs_equb or asm_line is None:
                # Emit as raw bytes with disassembly comment
                raw_hex = ", ".join(f"&{b:02X}" for b in raw)
                lines.append(f"    EQUB {raw_hex}  \\ {mnem.upper()} {op_str}")
            else:
                lines.append(asm_line)

            offset += size
        else:
            # Data byte - group consecutive data bytes
            run_start = offset
            while (offset < SIZE and
                   offset not in code_insns and
                   (BASE + offset) not in labels_map and
                   (offset - run_start) < 16):
                offset += 1
            if offset == run_start:
                offset += 1  # At least one byte

            chunk = rom[run_start:offset]
            hex_bytes = ", ".join(f"&{b:02X}" for b in chunk)
            # Try to show as ASCII if printable
            ascii_str = "".join(chr(b) if 32 <= b < 127 else "." for b in chunk)
            lines.append(f"    EQUB {hex_bytes}  \\ &{BASE + run_start:04X}: {ascii_str}")

    lines.append("")
    lines.append('SAVE "build.rom", &8000, &C000')
    lines.append("")

    return "\n".join(lines)


def main():
    rom = load_rom()
    asm = generate(rom)
    with open(OUT_FILE, "w") as f:
        f.write(asm)
    print(f"Generated {OUT_FILE} ({len(asm)} bytes, {asm.count(chr(10))} lines)")


if __name__ == "__main__":
    main()
