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

### Lessons learned: why bulk disassembly fails
Linear capstone sweep gets out of sync at:
- **Embedded variables**: single bytes between subroutines (e.g. &9DFD between two RTS/JMP blocks)
  where capstone treats the data byte as part of the next instruction
- **Self-modifying code**: `JMP &FFFF` where the address gets patched at runtime, or
  `STA addr+1` patterns
- **Data islands**: strings embedded in code ("SAVE" at &8700)

Each block must be manually verified. The approach: disassemble with capstone, then
check for RTS/JMP boundaries and verify the byte stream manually.

### Code disassembly status
All code blocks are now disassembled into proper 6502 instructions:
- [x] Extended input handler (&84D1–&89EF, 1310 bytes)
- [x] Key remapping KEYV interceptor (&8BDF–&8C70)
- [x] KEYON setup, KEYOFF, KSTATUS, DEFKEYS
- [x] Alias system (cmd_alias, cmd_aliases, check_alias, cmd_alild, cmd_alisv, cmd_aliclr)
- [x] cmd_store (partial — has EQUB for ZP absolute workarounds)
- [x] alias_init
- [x] cmd_mem, cmd_dis (with opcode format strings as structured data)
- [x] cmd_bau, cmd_space, cmd_lvar
- [x] Features text (611 bytes as EQUS)
- [x] All utility routines (print_inline, compare_string, parse_hex, etc.)

### Remaining raw EQUB data (474 lines)
- **11 lines in code**: ZP absolute workaround EQUB-encoded instructions
- **463 lines in tail** (&A154–&BFFF): structured data tables, not code
  - DIS opcode decode table (~1KB)
  - BASIC keyword tables for LVAR (~500 bytes)
  - Function key / alias buffers (~1KB of &0D-initialised workspace)
  - Build artifact strings
  - Zero/FF padding

### Completed passes
- [x] **Macro pass**: STROUT macro for string printing (8 instances)
- [x] **Label pass**: all 342 L#### labels renamed to descriptive names
- [x] **Constant pass**: OS workspace, hardware, display memory all named
- [x] **String pass**: all error messages, help text, key names as EQUS
- [x] **Scoping pass**: 26 `{ }` blocks with clean local labels

### Remaining work
- [x] **Scoping review**: all functions wrapped with label outside braces — many scopes wrap a single loop label mid-routine instead of wrapping the whole routine. Should mirror C-like scoping: one `{ }` per function, not per branch target. See util.asm `print_inline` and `copy_inline_to_stack` for examples of the problem.
- [x] **Tail data annotation**: all sections labelled — build artifacts, ghost code, key/alias buffers, stored key defs, build scripts. Remaining EQUB is dead code with corrupt boundaries (ghost help handler) and structured data tables (OSFILE template, key_codes, NOOP macro).
- [x] **Comment pass**: all routines documented across all 10 code files
- [ ] **ZP workarounds**: 23 &00xx absolute addressing EQUB instructions (fix in improvements phase)
- [x] **Second macro pass**: reviewed — remaining patterns are standard 6502 idioms (16-bit pointer arithmetic, OSBYTE setup) that are better left explicit. Existing macros (STROUT, OP, NOOP, KW) cover the domain-specific patterns well.

## 2026-03-21: Label pass and absolute address elimination

### Approach
Systematic pass through the entire file:
1. Renamed all 342 unnamed L#### labels to descriptive names by subsystem
2. Restructured key remap handler with per-instruction labels for self-modifying code
3. Replaced ~180 absolute addresses with named labels/constants
4. Added `{ }` scoping with local labels for self-contained functions

### Key remap handler restructuring
The KEYV interceptor at &8BDF has self-modifying JMP/JSR instructions whose
targets are patched by *KEYON. Each modified instruction now has its own label
(e.g. `kr_scan_ldx_0`, `key_remap_jmp1`) so the patching code can reference
`label + 1` for the operand byte. This means the handler code can be safely
edited without recalculating 30+ offset values.

### Constants added
- OS workspace: keyv_lo/hi, os_mode, os_escape_flag, os_wrch_dest,
  os_himem_lo/hi, os_key_trans, os_vdu_x, os_fkey_buf, os_autorepeat
- Hardware: crtc_addr/data, sheila_romsel, default_keyv, mode7_screen
- BASIC ZP: basic_page_hi, basic_top_lo/hi, basic_flags
- ROM workspace: 20+ labelled variables throughout the ROM data

### Scoping with { }
Applied `{ }` scoping to self-contained functions, replacing verbose
prefixed names (e.g. `xi_del_shift_loop`) with clean local names
(e.g. `shift_loop`). Functions scoped include:
- xi_dispatch (character dispatch table)
- xi_handle_delete, xi_handle_left, xi_handle_right, xi_handle_clear
- xi_do_clear, token_classify, print_decimal
- parse_hex_digit, bau token checks
- Plus 17 scoped blocks from earlier annotation passes

### Remaining absolute addresses (46)
All are legitimate and cannot be converted:
- 23× &00xx: ZP absolute encoding (beebasm would optimise to 2-byte ZP form)
- 7× &FFFF: self-modifying targets patched at runtime
- 9× &8000-&8300: ROM bank pages for *STORE
- 4× &0100: stack page for copy_inline_to_stack
- 2× &831F: compare_string self-modifying code
- 1× &C000: GUARD directive

### Current state
- 0 unnamed labels, ~520 named labels
- 26 `{ }` scoped blocks with clean local names
- 46 legitimate absolute addresses remaining
- Assembly byte-identical: `check.sh` passes at every commit

## 2026-03-22: Automated testing with jsbeeb

### Setup
Using jsbeeb's `TestMachine` class (from npm) with vitest to run XMOS
commands in a headless BBC Master emulator. The test helper boots a
Master, loads the disc, `*SRLOAD`s the ROM into SWRAM slot 7, and hard
resets to activate it.

### Key discoveries

**Hard reset required for ROM recognition**: A soft reset (BREAK) does
NOT re-scan sideways ROM slots on the BBC Master. Only a hard reset
(CTRL+BREAK) triggers the MOS to page through all slots, read the type
byte at &8006, and rebuild the ROM type table at &2A1. This is real
hardware behaviour, not a jsbeeb quirk.

**SWRAM survives reset**: Sideways RAM contents persist across both
soft and hard resets in jsbeeb (and on real hardware). The `ramRomOs`
array is only zeroed below `romOffset` (main RAM), not in the ROM
area. The `*ROMS` command (from the SRAM utility in ROM slot 8) can
read SWRAM contents at any time, even when the MOS type table shows
the slot as empty.

**Disc cleared by hard reset**: `fdc.powerOnReset()` is called during
hard reset, which clears the loaded disc image. Tests that need disc
access must re-load the disc after the hard reset.

**Text capture timing**: `TestMachine.type()` runs the CPU to process
keypresses, and the MOS may begin producing output during that
execution. Capture hooks must be installed *before* `type()` to avoid
missing the first few characters.

**Paged output**: The MOS pauses long output with "Shift for more".
Tests hold SHIFT during `runFor()` to prevent this.

**Alias expansion**: XMOS aliases type the expanded text at the
prompt without pressing RETURN. `*ALIAS LS *CAT` followed by `*LS`
produces `>*CAT` with the cursor waiting — the user can edit or
press RETURN to execute. This is the intended behaviour (confirmed
on real hardware). The test verifies the expanded text appears.

**captureText() limitations**: TestMachine's `captureText()` installs
a VDU state machine per call. Calling it multiple times on the same
machine causes independent state machines to desync on control codes,
silently dropping output. The test helper uses a simpler raw WRCHV
hook that just collects printable characters. A TestMachine
improvement to support reusable capture would be cleaner.

**CAPS LOCK and case handling**: TestMachine's `_charToKey()` always
sends uppercase keycodes with `shift: false`. With CAPS LOCK on (boot
default), every letter is uppercase and lowercase is impossible. This
caused `total` to become `TOTAL` which BBC BASIC tokenises as `TO`+
`TAL`. Fix: toggle CAPS LOCK off after boot and use a `typeText()`
wrapper that sets `shift: true` for uppercase letters.

### Test results
30 tests across 7 files, all passing:
- `help.test.js` — full command listing, general help, features text, dot-abbreviation
- `xon-xoff.test.js` — TAB line recall with XON, XOFF disabling, KEYON/KEYOFF/KSTATUS
- `alias.test.js` — define/list/clear, multiple aliases, expansion typing
- `save.test.js` — *S save with incore filename, leading spaces
- `dis.test.js` — disassemble known addresses, multi-line scroll
- `lvar.test.js` — empty list, heap vs integer variables
- `bau.test.js` — *BAU line splitting, *SPACE keyword spacing

### CI and pre-commit
- `npm test` runs as a pre-commit hook alongside beebasm-fmt and check.sh
- GitHub Actions CI runs both `check.sh` (ROM verification) and `npm test`

### jsbeeb TestMachine improvements to propose
- **`type()` cannot produce lowercase**: workaround is CAPS LOCK off
  + `typeText()` wrapper. Proper fix: `type()` should handle case.
- **`keyDown()`/`keyUp()` methods**: currently have to reach through
  `processor.sysvia.keyDown(keyCode)` with raw key codes.
- **Reusable capture API**: `captureText()` installs a new VDU state
  machine per call. Multiple hooks desync on control codes.
- **`snapshotState()`/`restoreState()` including SWRAM**: currently
  only saves main RAM. Including ROM area would speed up tests.
- **`loadSidewaysRam(slot, data)`**: convenience method to avoid the
  *SRLOAD dance.
