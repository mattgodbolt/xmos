/**
 * Shared test helper: boots a BBC Master with XMOS loaded into SWRAM slot 7.
 *
 * Usage:
 *   import { bootWithXmos, runCommand } from "./xmos-test-machine.js";
 *   const machine = await bootWithXmos();
 *   const output = await runCommand(machine, "*HELP XMOS");
 *   expect(output).toContain("MOS Extension");
 */

import { TestMachine } from "jsbeeb/tests/test-machine.js";
import { setNodeBasePath } from "jsbeeb/src/utils.js";
import * as fdc from "jsbeeb/src/fdc.js";
import * as fs from "fs";
import * as path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const jsbeebBase = path.join(__dirname, "..", "node_modules", "jsbeeb");
setNodeBasePath(jsbeebBase);

const ssdPath = path.join(__dirname, "..", "original.ssd");

/**
 * Boot a BBC Master with XMOS loaded and active.
 * Returns a jsbeeb TestMachine ready for command input.
 */
export async function bootWithXmos() {
    const machine = new TestMachine("Master");
    await machine.initialise();

    const data = fs.readFileSync(ssdPath);
    machine.processor.fdc.loadDisc(0, fdc.discFor(machine.processor.fdc, "", data));

    await machine.runUntilInput();
    await machine.type("*SRLOAD XMOS 8000 7Q");
    await machine.runUntilInput();

    // Hard reset (CTRL+BREAK) so the MOS re-scans ROM slots
    // and recognises the newly loaded SWRAM contents.
    // A soft reset (BREAK) skips the ROM scan.
    // The hard reset calls fdc.powerOnReset() which clears the disc,
    // so we re-load it afterwards for commands that need disc access.
    machine.processor.reset(true);
    await machine.runUntilInput();
    machine.processor.fdc.loadDisc(0, fdc.discFor(machine.processor.fdc, "", data));

    return machine;
}

/**
 * Install a text capture hook that intercepts characters at WRCHV.
 * Re-reads WRCHV on every instruction so it stays correct even if
 * the vector changes. Collects only printable ASCII (0x20-0x7E).
 * Returns a function that returns the captured text so far.
 *
 * Safe to call multiple times on the same machine — each hook is
 * independent and stateless (no VDU state machine to get confused).
 */
export function captureOutput(machine) {
    let chars = [];
    machine.processor.debugInstruction.add((addr) => {
        const wrchv = machine.readword(0x20e);
        if (addr === wrchv) {
            const ch = machine.processor.a;
            if (ch >= 0x20 && ch < 0x7f) {
                chars.push(ch);
            }
        }
        return false;
    });
    return () => chars.map((c) => String.fromCharCode(c)).join("");
}

/**
 * Type a command, run until output settles, and return the response text.
 * The capture hook is installed before type() because type() runs the CPU
 * and the MOS may start producing output during keystroke processing.
 *
 * SHIFT is held during the output phase so the MOS doesn't pause with
 * "Shift for more" when output fills the screen.
 */
export async function runCommand(machine, command, cycles = 8_000_000) {
    const getOutput = captureOutput(machine);
    await machine.type(command);
    // Hold SHIFT so paged output scrolls without pausing
    machine.processor.sysvia.keyDown(16);
    await machine.runFor(cycles);
    machine.processor.sysvia.keyUp(16);
    const raw = getOutput();
    // Strip the typed echo from the start of the output
    const echoEnd = raw.indexOf(command);
    if (echoEnd >= 0) {
        return raw.slice(echoEnd + command.length);
    }
    return raw;
}
