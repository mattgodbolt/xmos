# XMOS

An extension to the MOS (Machine Operating System) for the BBC Master.
By Richard Talbot-Watkins and Matt Godbolt, circa 1992.

Found on an old disc by Rich, now being reverse engineered back to health by
Matt (and Claude).

## What is XMOS?

XMOS is a sideways ROM for the BBC Master that adds a collection of utility
commands and an extended line editing mode:

- **Extended input** (`*XON`) — cursor-based line editing with insert/delete,
  input history via SHIFT-Up/Down, and TAB to recall BASIC lines by number
- **Command aliases** (`*ALIAS`) — define shorthand names that type out their
  expansion at the prompt, with `%0`-`%9` parameter substitution
- **Key redefinition** (`*KEYON`/`*DEFKEYS`) — remap cursor and fire keys
- **BASIC utilities** — `*S` saves with an incore filename from `REM >`,
  `*BAU` splits multi-statement lines, `*SPACE` adds keyword spacing,
  `*LVAR` lists variable names
- **Development tools** — `*DIS` disassembles 6502 code, `*MEM` is a
  hex/ASCII memory editor

See [USAGE.md](USAGE.md) for the full command reference and user guide.

## Quick start

Load the ROM into sideways RAM and press CTRL+BREAK:

```
*SRLOAD XMOS 8000 7Q
```

Then type `*HELP XMOS` to see all commands, or `*XON` to enable
extended input mode.

## Building

Requires [beebasm](https://github.com/stardot/beebasm) on your PATH.

```bash
beebasm -i xmos.asm -o build.rom   # Assemble the ROM
npm test                            # Run automated tests (requires Node.js)
```

The original byte-identical disassembly is preserved at git tag `original`.
Since then, bug fixes and improvements mean the output no longer matches
the original ROM — correctness is verified by the automated test suite.

## Project structure

### Assembly source (split by subsystem)

| File | Description |
|------|-------------|
| `xmos.asm` | Main: ROM header, service dispatch, help, command table, XON/XOFF |
| `input.asm` | Extended input: handle_reset, keyboard intercept, cursor editing |
| `util.asm` | Utilities: print_inline, copy_inline_to_stack, compare_string |
| `basic.asm` | BASIC save: *S (save with incore name), *L (mode setup) |
| `keys.asm` | Key system: remap handler, *KEYON/OFF, *KSTATUS, *DEFKEYS |
| `alias.asm` | Aliases: *ALIAS, *ALIASES, *ALICLR, *ALILD, *ALISV, *STORE |
| `mem.asm` | Memory editor: *MEM command |
| `dis.asm` | Disassembler: *DIS command, addressing mode format tables |
| `bau.asm` | BASIC utilities: *BAU (split lines), *SPACE (insert spaces) |
| `lvar.asm` | Variable lister: *LVAR, token classifier, decimal printer |
| `data.asm` | ROM data: features text, opcode table, keyword table, padding |
| `constants.asm` | System constants: MOS vectors, hardware registers, zero page |
| `macros.asm` | Assembly macros: STROUT, OP, NOOP, KW |

### Other files

| File | Description |
|------|-------------|
| `original.ssd` | Original BBC Micro disc image |
| `original.rom` | Extracted 16KB ROM binary |
| `USAGE.md` | Full command reference and user guide |
| `JOURNAL.md` | Reverse engineering notes and discoveries |
| `TESTING_PLAN.md` | Test infrastructure and jsbeeb improvement notes |

## Status

The ROM is fully disassembled and annotated. We're now fixing bugs and making
improvements — the original byte-identical version is at git tag `original`.
See [JOURNAL.md](JOURNAL.md) for detailed notes.
