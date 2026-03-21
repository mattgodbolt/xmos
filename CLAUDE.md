This is a reverse engineering project to regenerate and then augment XMOS:
an extension for the BBC Micro with a number of handy utility `*` commands,
and extended BASIC editing support.

Use the jsbeeb MCP as necessary to boot and explore the ROM on the original
disc: `original.ssd`. If more comprehensive disassembly is needed, use Radare2
(`r2`).

The disc should contain a ROM that would be loaded into the sideways RAM of a
BBC Master (originally, both Matt and Rich had BBC Masters when they wrote
this), and it should hook into the OS commands and line editing capabilities.

Keep a journal of your work in `./JOURNAL.md`; noting significant discoveries,
issues found, and general notes that would be useful for a human following
along, or for future reference in other BBC Micro reverse engineering projects.

