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

### Current state (initial disassembly)
- `xmos.asm`: 3303 lines, 2202 instructions disassembled, 314 labels
- `check.sh` confirms byte-identical match with original ROM
- Data regions (strings, tables, padding) remain as EQUB
- Code regions are proper 65C02 assembly with labels

## 2026-03-21: Hand annotation pass

### Approach change
Switched from automated disassembly to hand annotation. The disassembler (`disassemble.py`) produced the baseline; from here we manually improve `xmos.asm` by reading and understanding the code.

### Annotations completed
- **ROM header**: proper EQUS strings, computed copyright offset, named constants
- **Service entry**: named dispatch labels (svc_command, svc_help, svc_post_reset, svc_claim_static)
- **Help handler** (`*HELP`, `*HELP XMOS`, `*HELP FEATURES`, `*HELP <command>`): fully annotated with `{ }` scoped local labels, EQUS string data
- **Command dispatcher**: walks the command table, self-modifying JMP for dispatch
- **Command table**: converted from raw hex to `EQUS "name" : EQUW handler : EQUS "help"` format
- **XON/XOFF**: simple flag + OSBYTE 4 calls
- **Utility routines**: `print_inline`, `copy_inline_to_stack`, `compare_string` — all documented with entry/exit conditions
- **Error messages**: all 11 BRK error strings converted to readable EQUS format
- **All 19 command handlers**: renamed from L#### to descriptive cmd_* names

### Discoveries
- `copy_inline_to_stack` implements a clever BRK-based error raising mechanism: copies inline data to &0100, prepends a BRK opcode, then JMPs there. The first byte of the inline data is the error number, followed by the error message string.
- `compare_string` is self-modifying: it patches two absolute addresses in its own code to point at the string being compared against. Supports case-insensitive matching and BBC Micro-style command abbreviation with '.'.
- The `xon_flag` at &847F and other workspace variables are stored within the ROM itself (sideways RAM on the BBC Master), making the code position-dependent.
- There's a `beep` routine hidden in what looked like workspace data: `LDA #7 : JMP oswrch`.

### STROUT macro
Introduced `STROUT addr` macro to replace the repeated "print null-terminated string at addr,X" pattern (LDX #0 / LDA addr,X / BEQ done / JSR osasci / INX / BNE loop). Found 9 instances, replaced 8 (one was interleaved with other logic). This is currently a macro generating identical bytes; in the improvements phase it could become a subroutine call to save ~8 bytes per call site.

beebasm quirk: macro names starting with `PRINT` fail because the parser treats `PRINTX arg` as `PRINT X, arg`. Documented in the source — beebasm has hardcoded keyword prefixes. `STROUT` works fine.

### Future subroutine candidates (for improvements phase)
These patterns appear multiple times and could be refactored into subroutines:
- **STROUT**: print null-terminated string at address (8 instances × ~11 bytes = ~88 bytes, could save ~70 bytes as a subroutine)
- **print_inline**: already a subroutine, but only used once — more places could use it
- **Hex digit parse**: appears in DIS, MEM, and alias commands
- **OSBYTE 4 cursor key setup**: duplicated in cmd_xon, cmd_xoff, and handle_reset

### Current state (annotated)
- Major structural elements annotated and readable
- Large swathes of code remain as raw EQUB data (extended input handler, key redefinition, alias management, disassembler, memory editor, etc.)
- Assembly still byte-identical: `check.sh` passes

## TODO — Remaining annotation work

### Raw data blocks to disassemble
These are still raw EQUB hex dumps that need proper 6502 instructions and labels:
- [ ] **Extended input handler** (&84D1–&85D8, 208 bytes) — the core XON keyboard handler
- [ ] **Key remapping code** (&8BE0–&8C70) — keyboard intercept / translation
- [ ] **cmd_keyon / L8C89** (&8C89–&8D63) — KEYON setup, KEYV hook installation
- [ ] **cmd_kstatus display loop** (&8F2B–&8F77) — print key assignments
- [ ] **cmd_defkeys** (&8F78–&9032) — interactive key redefinition
- [ ] **cmd_alias** (&9033–&9140) — alias definition
- [ ] **cmd_aliases** (&9141–&9184) — display aliases
- [ ] **check_alias** (&91B8–&9284) — alias lookup and execution
- [ ] **cmd_alild / cmd_alisv** (&9285–&9345) — alias file load/save
- [ ] **cmd_store** (&9346–&9378) — store function keys
- [ ] **L9379** (&9379–&93A7) — alias system init
- [ ] **cmd_mem** (&940C–&94FF) — memory editor
- [ ] **cmd_dis** (&9500–&9860) — built-in 6502 disassembler (has opcode tables!)
- [ ] **cmd_bau / cmd_space** (&98C1–&9A2E) — BASIC utilities
- [ ] **cmd_lvar** (&9C00–&9EEF) — BASIC variable lister (has keyword tables!)
- [ ] **Features text** (&9EF0–&A052) — long help text, should be EQUS
- [ ] **Embedded data** (&A053–&B25F) — BASIC keyword tables, key defs, build artifacts

### String data still as raw hex
- [ ] Convert remaining EQUB string data to EQUS where possible
- [ ] Label all string references with descriptive names

### Final passes (after all code is disassembled)
- [ ] **Macro pass**: identify more repeated patterns for macros
- [ ] **Label pass**: rename all remaining L#### labels to descriptive names
- [ ] **Constant pass**: replace all raw hex addresses with named constants
- [ ] **Zero page pass**: name all ZP locations used by XMOS
- [ ] **Comment pass**: add high-level comments explaining each routine's purpose
