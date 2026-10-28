# XMOS User Guide

XMOS is a sideways ROM for the BBC Master that adds utility commands
and an extended line editing mode. Written by Richard Talbot-Watkins
and Matt Godbolt, circa 1992.

## Installation

Load the ROM into sideways RAM:

```
*SRLOAD XMOS 8000 7Q
```

Then press CTRL+BREAK to activate it. Type `*HELP XMOS` to verify
it's working.

Use `*STORE` to keep function key definitions across CTRL+BREAK.

To try it without a real Master,
[this link](https://bbc.xania.org/?model=Master&rom.7=github:mattgodbolt/xmos@build/xmos.rom&autotype=*HELP%20XMOS%0a)
boots the latest build in jsbeeb, already loaded into sideways RAM.

## Extended Input Mode

Enable with `*XON`, disable with `*XOFF`. When enabled, the command
line gains cursor-based editing features:

- **Left/Right arrows** move the cursor within the line for
  insert/delete editing
- **COPY** deletes the character under the cursor
- **Ctrl-U** clears the current line
- **SHIFT-Up/Down** scroll through input history
- **TAB** after a line number recalls that BASIC program line for
  editing (e.g. type `10` then TAB to edit line 10)
- **Up/Down** without SHIFT move the cursor a screen line within a long line
- **Pressing a cursor key on a blank line** switches to normal BBC
  cursor editing for the rest of that line
- **Typing SAVE** in BASIC executes `*S` (save with incore name)

Type `*HELP FEATURES` for the built-in feature summary.

## Commands

### Alias Management

**`*ALIAS <name> <expansion>`** — Define a command alias. When you
type `*name` at the prompt, XMOS types the expansion text for you
(without pressing RETURN), so you can review or edit before
executing. Aliases support parameter substitution:

- `%0` to `%9` — positional parameters from the command line
- `%%` — literal percent sign
- `%U` — emit VDU 11 (cursor up) and VDU 21 (disable display)

Example:
```
*ALIAS LD *LOAD %0
*LD myfile       → types "*LOAD myfile" at the prompt
```

Built-in XMOS commands are matched first, so an alias with the same name
as one (such as `L`) never runs.

**`*ALIASES`** — List all defined aliases in `name = expansion`
format. Produces no output if no aliases are defined.

**`*ALICLR`** — Clear all aliases.

**`*ALILD <filename>`** — Load alias definitions from a file
(previously saved with `*ALISV`).

**`*ALISV <filename>`** — Save current alias definitions to a file.

### Key Redefinition

Lets five keys of your choice stand in for the usual game keys: Z
(left), X (right), : (up), / (down) and RETURN (fire). While active, a
program that tests the keyboard with negative `INKEY` (OSBYTE &81) or
OSBYTE &79 sees the chosen key (e.g. CAPS LOCK) as the game key it
replaces (e.g. Z), and testing for the game key itself no longer finds
it.

**`*DEFKEYS`** — Enter interactive mode to choose which physical key
maps to each of the five labels. Follow the on-screen prompts to
press the desired key for each.

**`*KEYON`** — Activate the remapped keys. Prints
`Keys now redefined`. If already active, prints
`'KEYON' already executed!`.

**`*KEYOFF`** — Deactivate the remapping and restore normal keyboard
behaviour. Prints `Redefined keys off`.

**`*KSTATUS`** — Show whether remapping is active and the current
key assignments:

```
Redefined keys on, and are:
     Left : CAPS LOCK
    Right : CTRL
       Up : :
     Down : /
Jump/fire : RETURN
```

### BASIC Utilities

**`*S`** — Save the current BASIC program using the filename
embedded in the first line. The first line must contain a `REM`
statement with `>` followed by the filename:

```
10 REM > MyProg
20 PRINT "Hello"
*S
Program saved as 'MyProg'
```

**`*BAU`** — Break Apart Utility. Splits multi-statement BASIC lines
(separated by colons) into individual lines, then renumbers. Colons
inside quoted strings, and anywhere after `IF`, `DATA`, `ON` or `REM`,
are preserved. A line starting with an assembler label (`.name`) is split
after the label. Must be called from BASIC.

**`*SPACE`** — Insert spaces around tokenised BASIC keywords to
improve readability. Must be called from BASIC.

**`*LVAR`** — List the names of everything on BASIC's heap: variables
(real, string and integer), arrays, and PROC and FN names, which show
with a `{` or `|` in front (`{foo` for `PROCfoo`). Does not list static
integer variables (`A%` to `Z%`) or any values. Must be called
from BASIC — produces the error `VAR works only in BASIC` otherwise.

**`*L`** — Define f0 to run `LISTO 1`, `OLD` and `MODE 128` (shadow
screen mode) and set the colours and cursor, then press it.

**`*STORE`** — Save function key definitions so they survive
CTRL+BREAK (hard reset). The MOS clears function key storage (ANDY)
on CTRL+BREAK, so without `*STORE` your `*KEY` definitions are lost.
The typical workflow is: set up your function keys, then `*STORE` to
keep them across resets.

### Development Tools

**`*DIS <addr>`** — Disassemble 6502/65C02 machine code starting at
the given hex address. Shows one instruction per line with address,
mnemonic, hex bytes, and ASCII representation:

```
*DIS 802B
802B CMP #&04C9 04 I.
```

Press any key to show the next instruction, or ESCAPE to exit. `*DIS`
with no address carries on from where the last one stopped.

**`*MEM <addr>`** — Interactive hex/ASCII memory editor. Opens a
full-screen Mode 7 display showing memory contents. Navigation:

- **Left/Right** move a byte at a time
- **Up/Down** move a row (8 bytes); with SHIFT, 22 rows
- **TAB** toggles between hex entry and ASCII entry mode
- **ESCAPE** exits the editor

## Help System

- `*HELP` — lists all ROMs including XMOS with its sub-topics
- `*HELP XMOS` — lists all XMOS commands with descriptions
- `*HELP FEATURES` — describes the extended input features
- BBC dot-abbreviation works (e.g. `*H. XMOS`, `*HELP X.`)
