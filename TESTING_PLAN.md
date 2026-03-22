# XMOS Testing Plan

## Goal
Write automated tests for XMOS ROM commands so we can refactor with
confidence. Tests should verify observable behaviour (screen output,
memory state) not implementation details.

## Approach: jsbeeb TestMachine

Use jsbeeb's `TestMachine` class as a BBC Master emulator, running
XMOS commands and verifying output. jsbeeb is available locally at
`../jsbeeb` and can be consumed as a git submodule or local dependency.

### How it works

```javascript
const testMachine = new TestMachine("Master");
await testMachine.initialise();
// Load XMOS ROM into sideways RAM slot 7
await loadXmosRom(testMachine);
// Boot and wait for command prompt
await testMachine.runUntilInput();
// Type a * command
await testMachine.type("*HELP XMOS");
// Capture output
let output = "";
testMachine.captureText((elem) => output += elem.text);
await testMachine.runUntilInput();
// Verify
expect(output).toContain("MOS Extension commands:");
```

### Loading XMOS into sideways RAM

jsbeeb's `loadOs()` skips swram slots (4-7), so we can't use the
normal extra ROM mechanism. Two options:

**Option A: Write ROM data directly into RAM after boot**
```javascript
async function loadXmosRom(machine) {
    const rom = await fs.readFile("original.rom");
    // Sideways RAM slot 7 is at a specific offset in ramRomOs
    const slotOffset = machine.processor.romOffset + 7 * 16384;
    for (let i = 0; i < rom.length; i++) {
        machine.processor.ramRomOs[slotOffset + i] = rom[i];
    }
    // *SRLOAD equivalent: tell the MOS about the ROM
    // May need to trigger a reset or manually poke the ROM table
}
```

**Option B: Build an SSD with XMOS and use *SRLOAD**
```javascript
await testMachine.loadDisc("original.ssd");
await testMachine.runUntilInput();
await testMachine.type("*SRLOAD XMOS 8000 7");
await testMachine.runUntilInput();
// Reset to activate the ROM
```

Option B is more realistic (matches how a user would install it) but
slower. Option A is faster for unit-style tests. We could support both.

### Capturing output

`captureText()` hooks WRCHV to intercept all character output. This
gives us the text content without needing to parse screen memory.
Works for all XMOS commands that produce text output.

For commands that modify memory (*MEM) or key definitions (*DEFKEYS),
we can use `readbyte()` to inspect state directly.

## Test structure

```
xmos/
  tests/
    xmos-test-machine.js    -- TestMachine wrapper with XMOS loading
    help.test.js            -- *HELP, *HELP XMOS, *HELP FEATURES, *HELP <cmd>
    alias.test.js           -- *ALIAS, *ALIASES, *ALICLR
    xon.test.js             -- *XON, *XOFF
    save.test.js            -- *S (needs BASIC program loaded)
    dis.test.js             -- *DIS (verify disassembly output)
    lvar.test.js            -- *LVAR (needs BASIC variables set up)
    store.test.js           -- *STORE (verify key persistence)
    keys.test.js            -- *KEYON, *KEYOFF, *KSTATUS
    service.test.js         -- ROM header, service calls
  vitest.config.js
  package.json
```

### Test runner
- **vitest** (same as jsbeeb's test infrastructure)
- Run with `npm test`
- Each test boots a fresh BBC Master, loads XMOS, and runs commands

## What to test first (priority order)

1. **Service registration** — ROM appears in *HELP, responds to *commands
2. **Help system** — *HELP, *HELP XMOS, *HELP FEATURES, *HELP <command>
3. **XON/XOFF** — flag toggling, cursor key mode changes
4. **Alias system** — define, list, clear, expand with parameters
5. **Save** — *S with a BASIC program that has an incore filename
6. **Disassembler** — *DIS output matches expected disassembly
7. **LVAR** — variable listing after setting up BASIC variables

## Dependencies

- `jsbeeb` (published on npm)
- `vitest`
- Node.js 18+

## Open questions

- Should we use `build.rom` (assembled from our source) or `original.rom`?
  Using `build.rom` tests our assembly. Using `original.rom` tests against
  the known-good binary. Probably both — `original.rom` for regression,
  `build.rom` for verifying our assembly works.

## jsbeeb TestMachine improvements needed

- **`type()` cannot produce lowercase**: `_charToKey` does
  `ch.toUpperCase()` and sends `shift: false`, so every letter is
  uppercase. With CAPS LOCK on (default), SHIFT inverts case — so
  lowercase input should set `shift: true`. This is a real bug: any
  test involving lowercase variable names, strings, or keywords that
  collide when uppercased (e.g. `total` → `TOTAL` → `TO` token) will
  fail silently.
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
