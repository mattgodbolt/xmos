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
- `xmos.asm` — beebasm source (no longer byte-identical to original; see `original` tag)
- `disassemble.py` — Python script (uses capstone) that generated the initial xmos.asm
- `JOURNAL.md` — reverse engineering notes and discoveries

## Building and verifying
Run `beebasm -i xmos.asm -o build.rom` to assemble. Requires `beebasm` on PATH.
Run `npm test` to run the automated test suite (requires Node.js).
The original byte-identical ROM is preserved at git tag `original`.

## Assembly style
Follow `STYLE.md` for all assembly code. Key points:
- Use named constants for ALL addresses — no raw hex in instructions
- Use real 65C02 instructions (`LDA (&a8)`, `PHX`, etc.), not EQUB workarounds
- Use `EQUS 13, "text", 0` not separate EQUB/EQUS lines
- Lowercase hex consistently
- Compact logically related instructions onto one line with `:`
- Scope `{ }` around whole routines, not individual loops
- Comments describe what/why, never reference specific addresses

## Key technical notes
- The ROM is 65C02 (BBC Master). Use `CPU 1` in beebasm.
- Service-only ROM (type &82).
- Two inline-string routines (`print_inline` and `copy_inline_to_stack`):
  after `JSR` to these, the following bytes are data, not code.

