#!/usr/bin/env python3
"""Disassemble a range of the XMOS ROM, handling BRK as 1 byte.

Usage: dis65c02.py <start_addr> <end_addr>
Outputs beebasm-compatible assembly to stdout.
"""

import sys
from capstone import *

rom = open("original.rom", "rb").read()
md = Cs(CS_ARCH_MOS65XX, CS_MODE_MOS65XX_65C02)
BASE = 0x8000

NAMES = {
    0xFFE0: "osrdch", 0xFFE3: "osasci", 0xFFE7: "osnewl",
    0xFFEE: "oswrch", 0xFFF1: "osword", 0xFFF4: "osbyte",
    0xFFF7: "oscli", 0xFFCE: "osfind", 0xFFD1: "osgbpb",
    0xFFD4: "osbput", 0xFFD7: "osbget", 0xFFDA: "osargs",
    0xFFDD: "osfile", 0xFFC2: "gsinit", 0xFFC5: "gsread",
    0xFE30: "sheila_romsel",
}
BRANCHES = {"bcc", "bcs", "beq", "bne", "bmi", "bpl", "bvc", "bvs", "bra"}
ABS_ZP = {
    0x0D, 0x0E, 0x0C, 0x2D, 0x2E, 0x2C, 0x4D, 0x4E, 0x6D, 0x6E,
    0x8D, 0x8E, 0x8C, 0x9C, 0xAD, 0xAE, 0xAC, 0xCD, 0xCE, 0xCC,
    0xED, 0xEE, 0xEC, 0x1D, 0x1E, 0x1C, 0x3D, 0x3E, 0x3C, 0x5D, 0x5E,
    0x7D, 0x7E, 0x9D, 0x9E, 0xBD, 0xBC, 0xBE, 0xDD, 0xDE, 0xFD, 0xFE,
    0x19, 0x39, 0x59, 0x79, 0x99, 0xB9, 0xD9, 0xF9,
}


def disassemble(start, end):
    """Disassemble ROM from start to end (absolute addresses)."""
    # Pass 1: collect instructions and find targets
    instructions = []  # (addr, size, mnemonic, op_str, raw_bytes)
    targets = set()
    off = start - BASE
    end_off = end - BASE

    while off < end_off:
        byte = rom[off]

        # Handle &00 as a single data byte (NOT a 2-byte BRK)
        if byte == 0x00:
            instructions.append((BASE + off, 1, "EQUB", "&00", bytes([0])))
            off += 1
            continue

        # Use capstone for everything else
        found = False
        for insn in md.disasm(rom[off : off + 4], BASE + off, count=1):
            raw = rom[off : off + insn.size]
            instructions.append(
                (insn.address, insn.size, insn.mnemonic, insn.op_str, raw)
            )

            m = insn.mnemonic
            o = insn.op_str
            if (m in BRANCHES or m in ("jmp", "jsr")) and not o.startswith("("):
                try:
                    t = int(o, 0)
                    if start <= t < end:
                        targets.add(t)
                except ValueError:
                    pass
            off += insn.size
            found = True

        if not found:
            instructions.append(
                (BASE + off, 1, "EQUB", f"&{rom[off]:02X}", bytes([rom[off]]))
            )
            off += 1

    labels = {t: f"L{t:04X}" for t in sorted(targets)}

    # Pass 2: format output
    for addr, size, mnem, op_str, raw in instructions:
        if addr in labels:
            print(f".{labels[addr]}")

        if mnem == "EQUB":
            print(f"    EQUB {op_str}")
            continue

        m = mnem.upper()
        o = op_str.strip()

        # EQUB fallbacks
        needs_equb = False
        if raw[0] in (0x12, 0x32, 0x52, 0x72, 0x92, 0xB2, 0xD2, 0xF2):
            needs_equb = True
        if raw[0] == 0x89:
            needs_equb = True
        if len(raw) == 3:
            operand = raw[1] | (raw[2] << 8)
            if operand < 0x100 and raw[0] in ABS_ZP:
                needs_equb = True

        if needs_equb:
            h = ", ".join(f"&{b:02X}" for b in raw)
            c = f"{m} {o}".replace("0x", "&")
            print(f"    EQUB {h}  \\ {c}")
            continue

        def resolve(v):
            return labels.get(v) or NAMES.get(v)

        if not o:
            print(f"    {m}")
        elif o == "a":
            print(f"    {m} A")
        elif o.startswith("#"):
            print(f"    {m} #{o[1:].replace('0x', '&')}")
        elif o.startswith("(") and o.endswith(", x)"):
            print(f"    {m} ({o[1:].split(',')[0].replace('0x', '&')},X)")
        elif o.startswith("(") and o.endswith("), y"):
            print(f"    {m} ({o[1:].split(')')[0].replace('0x', '&')}),Y")
        elif o.startswith("(") and o.endswith(")"):
            print(f"    {m} ({o[1:-1].replace('0x', '&')})")
        elif ", " in o:
            parts = o.split(", ")
            reg = parts[1].upper()
            try:
                t = int(parts[0], 0)
                n = resolve(t)
                if n:
                    print(f"    {m} {n},{reg}")
                else:
                    val = parts[0].replace('0x', '&')
                    print(f"    {m} {val},{reg}")
            except ValueError:
                print(f"    {m} {parts[0].replace('0x', '&')},{reg}")
        else:
            try:
                target = int(o, 0)
                n = resolve(target)
                if n:
                    print(f"    {m} {n}")
                elif m.lower() in BRANCHES:
                    h = ", ".join(f"&{b:02X}" for b in raw)
                    print(f"    EQUB {h}  \\ {m} &{target:04X}")
                else:
                    # Use appropriate width: 2 hex digits for ZP, 4 for absolute
                    if target < 0x100:
                        print(f"    {m} &{target:02X}")
                    else:
                        print(f"    {m} &{target:04X}")
            except ValueError:
                print(f"    {m} {o.replace('0x', '&')}")


if __name__ == "__main__":
    start = int(sys.argv[1], 0)
    end = int(sys.argv[2], 0)
    disassemble(start, end)
