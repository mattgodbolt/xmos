# XMOS Reverse Engineering Journal

## 2026-03-21: Initial exploration

### What's on the disc
`original.ssd` contains a single file: `$.XMOS` — a 16KB sideways ROM image.

### ROM Header Analysis
- **Type**: Service-only ROM (&82) — no language entry (first 3 bytes are &00)
- **Service entry**: JMP &802B (at offset 3)
- **Title**: "MOS Extension"
- **Version**: 1
- **Copyright**: "(C) RTW and MG 1992"
- **CPU**: 65C02 (uses PHX/PHY/PLX/PLY, BRA, INC A/DEC A, STZ, (zp) indirect)

### Commands found (from string analysis)
| Command | Description |
|---------|-------------|
| ALIAS   | `<alias name> <alias>` — define an alias |
| ALIASES | Shows active aliases |
| ALICLR  | Clears all aliases |
| ALILD   | Loads alias file |
| ALISV   | Saves alias file |
| ; (semicolon) | Splits to single commands |
| DEFKEYS | Defines new keys |
| D       | `<addr>` — disassemble memory |
| KEYON   | Enables redefined keys |
| KEYOFF  | Disables redefined keys |
| KSTATUS | Displays KEYON status |
| M128    | Selects mode 128 |
| LVAR    | Shows current BASIC variables |
| MEDIT   | `<addr>` — memory editor |
| BAU     | Saves BASIC with incore name |
| SPACE   | Inserts spaces into programs |
| STORE   | Keeps function keys on break |
| XON     | Enables extended input |
| XOFF    | Disables extended input |
| XMOS    | Shows help |
| FEATURES| Shows features help |

### ROM structure
- &8000–&802A: ROM header (language entry stub + service JMP + type/copyright/title/version)
- &802B: Service entry point — dispatches on service call number (A=4 → unrecognised command, A=9 → help, A=&27 → ?, A=&22 → ?)
- Code runs to approximately &B234
- &B235–&BFEF: Zero padding
- &BFF0–&BFFF: &FF padding (16 bytes)

### Notable features
- Contains a built-in 6502 disassembler (the `*D` command)
- Has BASIC keyword token tables (for LVAR command to display variable names)
- Alias system with load/save support
- Key redefinition system
- Extended line input handling
- The ROM appears to have some build artifacts embedded — strings like `*SRSAVE XMos 8000+4000 7Q|M` suggest the original build process

### Approach
Starting with a raw EQUB dump in beebasm that is byte-identical, then progressively replacing with real 6502 assembly. Verification via `check.sh` which assembles and compares against `original.rom`.

## 2026-03-21: First working disassembly

### Disassembly technique
Used capstone (Python bindings, 65C02 mode) for instruction decoding, with recursive descent from known entry points to separate code from data. Key entry points:
- Service entry at &802B
- 19 command handler addresses parsed from the command table at &8219

### Command table format (at &8219)
Each entry: null-terminated command name, 2-byte handler address (LE), null-terminated help text. Table ends with &FF sentinel.

| Command  | Handler | Description |
|----------|---------|-------------|
| ALIAS    | &9033   | Define alias |
| ALIASES  | &9141   | Show active aliases |
| ALICLR   | &9340   | Clear all aliases |
| ALILD    | &9285   | Load alias file |
| ALISV    | &92E1   | Save alias file |
| BAU      | &98C1   | Save BASIC with incore name |
| DEFKEYS  | &8F78   | Define new keys |
| DIS      | &9705   | Disassemble memory |
| KEYON    | &8D54   | Enable redefined keys |
| KEYOFF   | &8DCB   | Disable redefined keys |
| KSTATUS  | &8F0F   | Display KEYON status |
| L        | &8B95   | Select mode 128 |
| LVAR     | &9C00   | Show current variables |
| MEM      | &940C   | Memory editor |
| S        | &8A68   | Save BASIC with incore name |
| SPACE    | &9A2F   | Insert spaces into programs |
| STORE    | &9346   | Keep function keys on break |
| XON      | &845E   | Enable extended input |
| XOFF     | &846C   | Disable extended input |

### Inline string routines (important for disassembly)
Two routines use "inline string" calling convention where the null-terminated string follows the JSR instruction in the code stream. The routine pulls the return address from the stack, uses it as a string pointer, then pushes back an adjusted address past the string:
- **&89F0**: Print inline string via OSASCI, return past null
- **&8A0F**: Copy inline string to &0100 buffer, return past null

These must be handled specially during disassembly — the bytes after `JSR &89F0` / `JSR &8A0F` are data, not code.

### Issues encountered
1. **beebasm zero-page optimization**: beebasm automatically uses zero-page addressing for operands < &100, even if the original code used absolute addressing. This changes instruction size from 3 to 2 bytes, shifting everything. Workaround: emit such instructions as raw `EQUB` bytes.
2. **65C02 (zp) indirect addressing**: `LDA (&xx)` — beebasm with `CPU 1` may not support this. Currently emitted as EQUB.
3. **BIT #imm**: 65C02 instruction, emitted as EQUB.

### Future improvements
Once we move from "byte-identical reproduction" to "making improvements", the EQUB workarounds for ZP optimization and 65C02 addressing modes can be replaced with proper assembly. At that point the ROM won't need to match the original byte-for-byte, so:
- `LDA &00F4` can become `LDA &F4` (saving a byte each time — free space!)
- `LDA (&A8)` and `BIT #&xx` can use native beebasm 65C02 syntax
- The inline string data after JSR &89F0/&8A0F calls could be EQUS strings

### Current state
- `xmos.asm`: 3303 lines, 2202 instructions disassembled, 314 labels
- `check.sh` confirms byte-identical match with original ROM
- Data regions (strings, tables, padding) remain as EQUB
- Code regions are proper 65C02 assembly with labels
