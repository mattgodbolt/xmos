This is a reverse engineering project to regenerate and then augment XMOS:
an extension for the BBC Micro with a number of handy utility `*` commands,
and extended BASIC editing support.

Use the jsbeeb MCP as necessary to boot and explore the ROM on the original
disc: `original.ssd`.

The disc should contain a ROM that would be loaded into the sideways RAM of a
BBC Master (originally, both Matt and Rich had BBC Masters when they wrote
this), and it should hook into the OS commands and line editing capabilities.

Keep a journal of your work in `./JOURNAL.md`; noting significant discoveries,
issues found, and general notes that would be useful for a human following
along, or for future reference in other BBC Micro reverse engineering projects.

## Project structure
- `original.ssd` — original BBC Micro disc image containing the XMOS ROM
- `original.rom` — extracted 16KB ROM binary (from sector 2 of the SSD)
- `xmos.asm` — beebasm source that assembles to a byte-identical copy of the ROM
- `disassemble.py` — Python script (uses capstone) that generates xmos.asm from original.rom
- `check.sh` — verification script: assembles xmos.asm and compares against original.rom
- `JOURNAL.md` — reverse engineering notes and discoveries

## Building and verifying
Run `./check.sh` to assemble and verify. Requires `beebasm` on PATH.
The disassembler requires a Python venv: `.venv/bin/python3 disassemble.py`.

## Key technical notes
- The ROM is 65C02 (BBC Master). Use `CPU 1` in beebasm.
- Service-only ROM (type &82), service entry at &802B.
- Two inline-string routines at &89F0 and &8A0F: after `JSR` to these,
  the following bytes are a null-terminated string (data), not code.
- beebasm optimizes absolute addressing to zero-page when operand < &100.
  Some instructions use EQUB to preserve the original 3-byte encoding.
- Command table at &8219: null-terminated name, 2-byte handler addr (LE),
  null-terminated help text. Ends with &FF.

