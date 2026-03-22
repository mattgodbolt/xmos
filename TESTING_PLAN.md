# XMOS Testing Plan

## Goal
Automated tests for XMOS ROM commands so we can refactor with
confidence. Tests verify observable behaviour (screen output,
memory state) not implementation details.

## Approach: jsbeeb TestMachine

Use jsbeeb's `TestMachine` class (from npm) as a BBC Master emulator.
The shared helper `tests/xmos-test-machine.js` handles boot, ROM
loading, output capture, and case-correct typing.

### Boot sequence

```javascript
import { bootWithXmos, runCommand } from "./xmos-test-machine.js";
const machine = await bootWithXmos();
const output = await runCommand(machine, "*HELP XMOS");
expect(output).toContain("MOS Extension commands:");
```

`bootWithXmos()`:
1. Boot a BBC Master
2. Load `original.ssd` and `*SRLOAD XMOS 8000 7Q`
3. Hard reset (CTRL+BREAK) so the MOS re-scans ROM slots
4. Re-load disc (cleared by `fdc.powerOnReset()`)
5. Toggle CAPS LOCK off for correct case handling

### Output capture

`captureOutput()` installs a raw WRCHV hook that collects printable
characters. Simpler and more robust than `TestMachine.captureText()`
which uses a VDU state machine that breaks with multiple hooks.

### Case handling

`typeText()` wraps `TestMachine.type()` to handle case correctly.
With CAPS LOCK off, uppercase letters need SHIFT held (SHIFT inverts
CAPS LOCK on the BBC). This means `typeText("Hello")` produces
`Hello` on screen, not `HELLO`.

## Test structure

```
tests/
  xmos-test-machine.js  -- shared boot/capture/typing helpers
  help.test.js          -- *HELP XMOS, *HELP, *HELP FEATURES, abbreviation
  xon-xoff.test.js      -- *XON TAB recall, *XOFF, *KEYON/OFF, *KSTATUS
  alias.test.js         -- *ALIAS, *ALIASES, *ALICLR, expansion
  save.test.js          -- *S (save with incore filename)
  dis.test.js           -- *DIS (disassembly output)
  lvar.test.js          -- *LVAR (variable listing)
  bau.test.js           -- *BAU (line splitting), *SPACE (keyword spacing)
```

### Running tests
- `npm test` — runs all tests via vitest
- `./check.sh` — assembles xmos.asm and verifies byte-identical to original.rom
- Both run as pre-commit hooks and in GitHub CI

## jsbeeb TestMachine improvements needed

- **`type()` cannot produce lowercase**: `_charToKey` does
  `ch.toUpperCase()` and sends `shift: false`, so every letter is
  uppercase. Workaround: toggle CAPS LOCK off and use `typeText()`
  wrapper. Proper fix: `type()` should handle case natively.
- **`keyDown()`/`keyUp()` methods**: currently have to reach through
  `processor.sysvia.keyDown(keyCode)` with raw key codes. TestMachine
  should expose these directly, ideally accepting key names.
- **Reusable capture API**: `captureText()` installs a new VDU state
  machine per call. Multiple hooks on the same machine desync on
  control codes. Need either a single resettable capture, or a simpler
  raw-character API.
- **`snapshotState()`/`restoreState()` including SWRAM**: currently
  only saves main RAM (up to `romOffset`). Including the ROM area
  would allow snapshotting after boot+load for much faster tests.
- **`loadSidewaysRam(slot, data)`**: convenience method to write ROM
  data directly into a SWRAM slot, avoiding the *SRLOAD dance.
