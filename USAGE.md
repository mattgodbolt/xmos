# XMOS Command Reference

XMOS is a sideways ROM for the BBC Master that provides utility commands
and extended BASIC editing. Enable it with `*XON`, disable with `*XOFF`.

## Commands

### Extended Input

| Command | Description |
|---------|-------------|
| `*XON` | Enable extended input mode (cursor editing, insert/delete) |
| `*XOFF` | Disable extended input mode |
| `*FEATURES` | Display documentation for extended input features |

### Alias Management

| Command | Description |
|---------|-------------|
| `*ALIAS <name> <expansion>` | Define a command alias |
| `*ALIASES` | Show all active aliases |
| `*ALICLR` | Clear all aliases |
| `*ALILD` | Load aliases from file |
| `*ALISV` | Save aliases to file |

Aliases allow you to define shorthand names for frequently used commands.
The `;` character can be used to split multiple commands on one line.

### Key Redefinition

| Command | Description |
|---------|-------------|
| `*DEFKEYS` | Enter interactive key redefinition mode |
| `*KEYON` | Enable redefined key mappings |
| `*KEYOFF` | Disable redefined key mappings |
| `*KSTATUS` | Display current KEYON/KEYOFF status and mappings |

### BASIC Utilities

| Command | Description |
|---------|-------------|
| `*S` | Save the current BASIC program using its incore filename |
| `*BAU` | Save BASIC with incore name (alternative entry point) |
| `*L` | Select MODE 128 and set up function key definitions |
| `*LVAR` | List all current BASIC variables and their values |
| `*SPACE` | Insert spaces into BASIC programs (reformatting) |
| `*STORE` | Preserve function key definitions across BREAK |

The `*S` command looks for a `REM > Filename` line at the start of
your BASIC program and uses that as the save filename.

### Development Tools

| Command | Description |
|---------|-------------|
| `*DIS <addr>` | Disassemble 6502 code starting at the given address |
| `*MEM <addr>` | Interactive hex memory editor at the given address |

## Help

Type `*HELP XMOS` to see all available commands.
Type `*HELP FEATURES` to see extended input documentation.
Type `*HELP <command>` for help on a specific command.
