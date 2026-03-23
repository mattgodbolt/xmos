import { describe, it, expect, beforeEach } from "vitest";
import { bootWithXmos, runCommand, readMode7Screen, typeText } from "./xmos-test-machine.js";

const CAPS_LOCK = 20;

/**
 * Press a key briefly.
 */
async function pressKey(machine, keyCode, cycles = 200000) {
    machine.processor.sysvia.keyDown(keyCode);
    await machine.runFor(cycles);
    machine.processor.sysvia.keyUp(keyCode);
    await machine.runFor(cycles);
}

describe("*DEFKEYS — interactive key definition", () => {
    it("should show the key redefiner screen", async () => {
        const machine = await bootWithXmos();
        await typeText(machine, "*DEFKEYS");
        await machine.runFor(4_000_000);

        const screen = readMode7Screen(machine);
        const text = screen.join("\n");
        expect(text).toContain("Left");
    });

    it("should accept 5 keypresses and activate KEYON", async () => {
        const machine = await bootWithXmos();
        await typeText(machine, "*DEFKEYS");
        await machine.runFor(4_000_000);

        // Press 5 keys for left, right, up, down, fire
        // Use Z, X, :, /, RETURN (common game layout)
        await pressKey(machine, 90);  // Z
        await pressKey(machine, 88);  // X
        await pressKey(machine, 186); // ; (colon on BBC)
        await pressKey(machine, 191); // / (slash)
        await pressKey(machine, 13);  // RETURN

        await machine.runFor(4_000_000);

        // After DEFKEYS, KEYON should be active
        const output = await runCommand(machine, "*KSTATUS");
        expect(output).toContain("Redefined keys on, and are:");
    });
});
