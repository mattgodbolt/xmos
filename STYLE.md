# XMOS Assembly Style Guide

## Hex notation
- Use **lowercase hex** consistently: `&0d`, `&ff`, `&a8`, not `&0D`, `&FF`
- Exception: labels like `L9DFE` keep their uppercase (historical)

## Character literals
- Use character literals where the intent is a character: `LDA #' '`, `CMP #'.'`
- Use hex where the intent is a byte value: `LDA #&0d`, `CMP #&ff`

## Named constants
- **Every address must have a name.** No raw hex addresses in instructions.
- Zero page locations: use constants from `constants.asm` (`zp_ptr_lo`, `cmd_line_lo`, `rom_number`)
- OS workspace: use constants (`keyv_lo`, `saved_language_rom`, `os_vdu_queue_count`)
- ROM workspace variables: use labels at their actual location in the assembly
- **Address low/high bytes must use `LO(label)` / `HI(label)`**, never raw hex.
  Write `LDA #LO(alias_buffer)` not `LDA #&65`.
- The only exception is self-modifying code targets (`&ffff`) that get patched at runtime

## Self-modifying code
When patching an instruction's operand, reference the instruction's label with `+ 1` or `+ 2`:
```
.*patch_target
    LDA #&00        \ patched at runtime
    ...
    STA patch_target + 1    \ write new operand
```
**Never** use large offsets from a function label (e.g. `STA my_func + &25`).
These break silently if instructions are added or removed between the label
and the patched instruction. Every patchable instruction must have its own
`.*label` (global if patched from outside `{ }`).

## Strings
- Use `EQUS` with inline byte values: `EQUS 13, "text", 0`
- Not `EQUB &0D` then `EQUS "text"` then `EQUB 0` on separate lines
- For null-terminated strings: `EQUS "XMOS", 0`

## 65C02 instructions
- **Use real instructions**, not EQUB workarounds. beebasm with `CPU 1` supports:
  - `LDA (&a8)` — zero page indirect
  - `STA (&a8)` — zero page indirect
  - `BRA label` — branch always
  - `PHX`, `PHY`, `PLX`, `PLY` — push/pull X/Y
  - `STZ`, `TRB`, `TSB` — zero/test-and-set
  - `INC A`, `DEC A` — accumulator increment/decrement
- Only use `EQUB` for instructions where beebasm would change the encoding (absolute addressing for ZP locations where the original uses the 3-byte absolute form)

## Instruction compaction
Put logically related instructions on one line with `:` separator:
- **Register save/restore:** `PHA : PHX : PHY` / `PLY : PLX : PLA`
- **Pointer setup:** `LDA #LO(label) : STA zp_ptr_lo`
- **Word copy:** `LDA saved_keyv_lo : STA keyv_lo`
- **Shift chains:** `ASL A : ROL &ad` or `LSR A : LSR A : LSR A : LSR A`
- **OSBYTE setup:** `LDA #&04 : LDX #&01 : LDY #&00`
- **Print character:** `LDA #' ' : JSR osasci`
- **Field skipping:** `INY : INY : INY` with a comment explaining what's being skipped
- **Small routines:** `LDA #&07 : JMP oswrch`

Do NOT mechanically pair adjacent instructions. The line should represent one **logical operation**. Ask: "would I describe this as one thing?"

## Repeated instructions
Use `FOR` loops for 4+ identical instructions:
```
FOR n, 1, 10 : INY : NEXT      \ skip 10-byte entry
```

## Scoping with { }
Put the function name label BEFORE the `{`. Everything inside is local:
```
.my_function
{
    LDA #&00
.loop
    JSR osasci
    INY
    BNE loop
    RTS
}
```
`.my_function` is global (outside the braces). `.loop` is local (inside).
This means internal labels like `.loop`, `.done`, `.skip` can be reused
across functions without clashing.

- Wrap **whole functions** in `{ }` — one scope per function
- The function name label goes OUTSIDE the scope (naturally global)
- Use `.*label` only for the rare case where an internal label needs
  to be visible externally (e.g. self-modifying code patched from outside)
- Do NOT scope individual loops or branch targets mid-function

## Comments
- Comments should describe **what and why**, not restate the instruction
- Do NOT reference specific addresses in comments — they will rot when code moves
- Good: `\ skip null + handler address`
- Bad: `\ Skip to &8A26` or `\ Table ends at &B168`
- Section headers use `\ ====` banners for major sections only

## Macros
- `STROUT addr` — print null-terminated string at address
- `OP "mnem", mode` — DIS opcode table entry
- `NOOP` — undefined opcode entry
- `KW "name", token, flags` — BASIC keyword table entry
- Macro names must not start with a 6502 instruction mnemonic (beebasm parser quirk)

## File organisation
Each `.asm` file covers one subsystem. The main `xmos.asm` has the ROM header, service dispatch, help system, command table, and INCLUDEs everything else.
