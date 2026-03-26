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
import * as fs from "fs";
import * as path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const jsbeebBase = path.join(__dirname, "..", "node_modules", "jsbeeb");
setNodeBasePath(jsbeebBase);

const romData = new Uint8Array(fs.readFileSync(path.join(__dirname, "..", "build.rom")));
const ssdData = fs.readFileSync(path.join(__dirname, "..", "original.ssd"));

/**
 * Boot a BBC Master with XMOS loaded and active.
 * Returns a jsbeeb TestMachine ready for command input.
 */
export async function bootWithXmos() {
    const machine = new TestMachine("Master");
    await machine.initialise();

    machine.loadSidewaysRam(7, romData);
    machine.reset(true);
    await machine.runUntilInput();
    machine.loadDiscData(ssdData);

    // Install the capture hook once — use drainText() to read output
    machine.startCapture();

    return machine;
}

let _cachedSnapshot = null;
let _cachedMachine = null;

/**
 * Boot once and cache a snapshot. Subsequent calls restore from the
 * snapshot instead of re-booting — much faster for per-test setup.
 * Returns the same TestMachine instance each time (state is reset).
 */
export async function restoreOrBoot() {
    if (_cachedSnapshot) {
        _cachedMachine.restore(_cachedSnapshot);
        _cachedMachine.drainText();
        return _cachedMachine;
    }
    const machine = await bootWithXmos();
    _cachedSnapshot = machine.snapshot();
    _cachedMachine = machine;
    return machine;
}

/**
 * Mode 7 teletext colour names (control codes &00-&07 set alpha colour).
 */
const MODE7_COLOURS = ["black", "red", "green", "yellow", "blue", "magenta", "cyan", "white"];

/**
 * Read Mode 7 screen memory (&7C00, 40×25) and return it as an array
 * of 25 strings (plain text, control codes replaced with spaces).
 */
export function readMode7Screen(machine) {
    return readMode7ScreenRich(machine).map((row) => row.map((c) => c.ch).join("").trimEnd());
}

/**
 * Read Mode 7 screen and return rich data: an array of 25 rows, each
 * an array of 40 { ch, fg } objects. Interprets teletext control codes
 * minimally: &01-&07 set foreground alpha colour, &10-&17 set foreground
 * graphics colour. All control codes render as a space character.
 */
export function readMode7ScreenRich(machine) {
    const rows = [];
    for (let row = 0; row < 25; row++) {
        let fg = "white";
        const cols = [];
        for (let col = 0; col < 40; col++) {
            const raw = machine.readbyte(0x7c00 + row * 40 + col);
            const byte = raw & 0x7f;
            if (byte >= 0x01 && byte <= 0x07) {
                fg = MODE7_COLOURS[byte];
                cols.push({ ch: " ", fg });
            } else if (byte >= 0x10 && byte <= 0x17) {
                fg = MODE7_COLOURS[byte - 0x10];
                cols.push({ ch: " ", fg });
            } else if (byte >= 0x20 && byte < 0x7f) {
                cols.push({ ch: String.fromCharCode(byte), fg });
            } else {
                cols.push({ ch: " ", fg });
            }
        }
        rows.push(cols);
    }
    return rows;
}

/**
 * Capture output using the TestMachine's built-in capture API.
 * Returns a function that, when called, returns all text captured
 * since this captureOutput call was made.
 */
export function captureOutput(machine, { raw = false } = {}) {
    // Drain any accumulated text from before this call
    machine.drainText();
    return () => machine.drainText({ raw });
}

/**
 * Type a command, run until the prompt returns, and return the
 * response text. SHIFT is held during execution to prevent
 * "Shift for more" paging pauses.
 */
export async function runCommand(machine, command, { raw = false } = {}) {
    machine.drainText(); // clear any prior output
    await machine.type(command);
    machine.keyDown(16);
    await machine.runUntilInput();
    machine.keyUp(16);
    const output = machine.drainText({ raw });
    const echoEnd = output.indexOf(command);
    if (echoEnd >= 0) {
        return output.slice(echoEnd + command.length);
    }
    return output;
}
