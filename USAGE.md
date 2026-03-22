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

Use `*STORE` to preserve the ROM state across soft resets (BREAK).

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
- **Pressing a cursor key on a blank line** exits extended input mode
  and returns to normal BBC cursor editing
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
*ALIAS L *LOAD %0
*L myfile        → types "*LOAD myfile" at the prompt
```

**`*ALIASES`** — List all defined aliases in `name = expansion`
format. Produces no output if no aliases are defined.

**`*ALICLR`** — Clear all aliases.

**`*ALILD <filename>`** — Load alias definitions from a file
(previously saved with `*ALISV`).

**`*ALISV <filename>`** — Save current alias definitions to a file.

### Key Redefinition

Remaps cursor keys and a fire button to different physical keys,
primarily for games. Instead of using the cursor keys as a joystick,
you can map Left/Right/Up/Down/Fire to a more comfortable cluster
of keys on the keyboard.

**`*DEFKEYS`** — Enter interactive mode to choose which physical key
maps to each of the five directions (Left, Right, Up, Down,
Jump/Fire). Follow the on-screen prompts to press the desired key
for each.

**`*KEYON`** — Activate the remapped keys by intercepting the
keyboard vector (KEYV). Prints `Keys now redefined`. If already
active, prints `'KEYON' already executed!`.

**`*KEYOFF`** — Deactivate the remapping and restore normal cursor
keys. Prints `Redefined keys off`.

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

The defaults map to a left-hand cluster on the BBC keyboard.

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
inside quoted strings and after `REM` are preserved. Must be called
from BASIC.

**`*SPACE`** — Insert spaces around tokenised BASIC keywords to
improve readability. Must be called from BASIC.

**`*LVAR`** — List the names of all BASIC variables currently
defined on the heap (real numbers and strings). Does not list static
integer variables (`A%` to `Z%`) or their values. Must be called
from BASIC — produces the error `VAR works only in BASIC` otherwise.

**`*L`** — Set up MODE 128 (shadow screen mode) with function key
definitions for the editing environment.

**`*STORE`** — Save your current XMOS configuration (aliases, key
definitions, XON state) so it survives BREAK. Without `*STORE`,
a reset reinitialises these to their defaults. The typical workflow
is: set up your aliases and key mappings, then `*STORE` to keep
them.

### Development Tools

**`*DIS <addr>`** — Disassemble 6502/65C02 machine code starting at
the given hex address. Shows one instruction per line with address,
mnemonic, hex bytes, and ASCII representation:

```
*DIS 802B
802B CMP #&04C9 04 I.
```

Press SPACE to show the next instruction, or any other key to exit.

**`*MEM <addr>`** — Interactive hex/ASCII memory editor. Opens a
full-screen Mode 7 display showing memory contents. Navigation:

- **Cursor keys** move byte by byte
- **SHIFT+cursor** scrolls by page
- **TAB** toggles between hex entry and ASCII entry mode
- **ESCAPE** exits the editor

## Help System

- `*HELP` — lists all ROMs including XMOS with its sub-topics
- `*HELP XMOS` — lists all XMOS commands with descriptions
- `*HELP FEATURES` — describes the extended input features
- BBC dot-abbreviation works (e.g. `*H. XMOS`, `*HELP X.`)
