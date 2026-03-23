import { describe, it, expect, beforeEach } from "vitest";
import { bootWithXmos, runCommand, captureOutput, typeText } from "./xmos-test-machine.js";

// MCP F0 key maps to BBC f1 (*KEY 1)
async function pressF1(machine) {
    machine.processor.sysvia.keyDown(112); // F1 PC keycode
    await machine.runFor(200000);
    machine.processor.sysvia.keyUp(112);
    await machine.runFor(200000);
}

describe("*STORE — keep function keys on break", () => {
    let machine;

    beforeEach(async () => {
        machine = await bootWithXmos();
    });

    it("function key defined with *KEY should work", async () => {
        await runCommand(machine, "*KEY 1 HELLO");
        const getOutput = captureOutput(machine);
        await pressF1(machine);
        await machine.runFor(2_000_000);
        const output = getOutput();
        expect(output).toContain("HELLO");
    });

    it("function key should be lost after soft reset without *STORE", async () => {
        await runCommand(machine, "*KEY 1 HELLO");
        machine.processor.reset(false);
        await machine.runUntilInput();

        const getOutput = captureOutput(machine);
        await pressF1(machine);
        await machine.runFor(2_000_000);
        const output = getOutput();
        expect(output).not.toContain("HELLO");
    });

    it("*STORE does NOT preserve function keys (despite help text)", async () => {
        // The help text says "Keeps function keys on break" but *STORE
        // saves ANDY (&8000-&83FF via ROMSEL bit 7), while MOS stores
        // function key definitions at &0480 (page 4 RAM). So function
        // keys are lost on reset regardless. What *STORE actually
        // preserves in ANDY is still under investigation.
        await runCommand(machine, "*KEY 1 HELLO");
        await runCommand(machine, "*STORE");
        machine.processor.reset(false);
        await machine.runUntilInput();

        const getOutput = captureOutput(machine);
        await pressF1(machine);
        await machine.runFor(2_000_000);
        const output = getOutput();
        expect(output).not.toContain("HELLO");
    });
});
