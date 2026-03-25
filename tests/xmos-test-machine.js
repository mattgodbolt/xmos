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

const romData = new Uint8Array(fs.readFileSync(path.join(__dirname, "..", "original.rom")));
const ssdData = fs.readFileSync(path.join(__dirname, "..", "original.ssd"));

/**
 * Boot a BBC Master with XMOS loaded and active.
 * Returns a jsbeeb TestMachine ready for command input.
 */
export async function bootWithXmos() {
    const machine = new TestMachine("Master");
    await machine.initialise();

    // Load ROM directly into sideways RAM slot 7
    machine.loadSidewaysRam(7, romData);

    // Hard reset so the MOS re-scans ROM slots and recognises XMOS.
    machine.reset(true);
    await machine.runUntilInput();

    // Re-load disc (hard reset clears the FDC) for commands that
    // need disc access (e.g. *CAT, *S, *ALISV/*ALILD).
    machine.loadDiscData(ssdData);

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
            // Mode 7 ignores bit 7 — strip it for control code detection
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
 * Install a text capture hook that intercepts characters at WRCHV.
 * Re-reads WRCHV on every instruction so it stays correct even if
 * the vector changes. Collects only printable ASCII (0x20-0x7E).
 * Returns a function that returns the captured text so far.
 *
 * Safe to call multiple times on the same machine — each hook is
 * independent and stateless (no VDU state machine to get confused).
 */
export function captureOutput(machine, { raw = false } = {}) {
    let chars = [];
    machine.processor.debugInstruction.add((addr) => {
        const wrchv = machine.readword(0x20e);
        if (addr === wrchv) {
            const ch = machine.processor.a;
            if (raw) {
                chars.push(ch);
            } else if (ch >= 0x20 && ch < 0x7f) {
                chars.push(ch);
            }
        }
        return false;
    });
    return () =>
        chars
            .map((c) => {
                if (c === 10) return "\n";
                if (c === 13) return "";
                if (c >= 0x20 && c < 0x7f) return String.fromCharCode(c);
                return "";
            })
            .join("");
}

/**
 * Type a command, run until output settles, and return the response text.
 * The capture hook is installed before type() because type() runs the CPU
 * and the MOS may start producing output during keystroke processing.
 *
 * SHIFT is held during the output phase so the MOS doesn't pause with
 * "Shift for more" when output fills the screen.
 */
export async function runCommand(machine, command, { cycles = 8_000_000, raw = false } = {}) {
    const getOutput = captureOutput(machine, { raw });
    await machine.type(command);
    machine.keyDown(16);
    await machine.runFor(cycles);
    machine.keyUp(16);
    const output = getOutput();
    const echoEnd = output.indexOf(command);
    if (echoEnd >= 0) {
        return output.slice(echoEnd + command.length);
    }
    return output;
}
