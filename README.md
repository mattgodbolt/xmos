# XMOS

An extension to the MOS (Machine Operating System) for the BBC Master.
By Richard Talbot-Watkins and Matt Godbolt, circa 1992.

Found on an old disc by Rich, now being reverse engineered back to health by
Matt (and Claude).

## What is XMOS?

XMOS is a sideways ROM for the BBC Master that adds a collection of utility
commands and an extended line editing mode. It provides:

- **Command aliases** — define shorthand names for frequently used commands
- **Key redefinition** — remap the keyboard layout
- **Extended line editing** — cursor-based editing with insert/delete
- **BASIC utilities** — save with incore name, list variables, insert spaces
- **A built-in 6502 disassembler** and **memory editor**

See [USAGE.md](USAGE.md) for full command documentation.

## Building

Requires [beebasm](https://github.com/stardot/beebasm) on your PATH.

```bash
./check.sh          # Assemble and verify against original ROM
```

This assembles `xmos.asm` into `build.rom` and compares it byte-for-byte
against `original.rom`. The build must always match.

## Project structure

| File | Description |
|------|-------------|
| `xmos.asm` | Main assembly source — the annotated disassembly |
| `constants.asm` | System constants: MOS vectors, hardware registers, zero page |
| `original.ssd` | Original BBC Micro disc image |
| `original.rom` | Extracted 16KB ROM binary |
| `check.sh` | Build and verify script |
| `disassemble.py` | Python script that generated the initial disassembly (historical) |
| `JOURNAL.md` | Reverse engineering notes and discoveries |
| `USAGE.md` | Command documentation |

## Reverse engineering status

The ROM is fully disassembled and assembles to a byte-identical copy of the
original. Annotation is ongoing — see [JOURNAL.md](JOURNAL.md) for progress.
