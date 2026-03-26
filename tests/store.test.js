import { describe, it, expect, beforeEach } from "vitest";
import { restoreOrBoot, runCommand, captureOutput } from "./xmos-test-machine.js";

const CTRL = 17;

// Press BBC f1 (*KEY 1). MCP F0 (PC keycode 112) maps to BBC f1.
async function pressBbcF1(machine) {
    machine.keyDown(112);
    await machine.runFor(200000);
    machine.keyUp(112);
    await machine.runFor(200000);
}

// Simulate CTRL+BREAK: hold CTRL during a soft reset.
async function ctrlBreak(machine) {
    machine.keyDown(CTRL);
    machine.reset(false);
    await machine.runFor(2_000_000);
    machine.keyUp(CTRL);
    await machine.runUntilInput();
}

describe("*STORE — keep function keys on CTRL+BREAK", () => {
    let machine;

    beforeEach(async () => {
        machine = await restoreOrBoot();
    });

    it("function key defined with *KEY should work", async () => {
        await runCommand(machine, "*KEY 1 HELLO");
        const getOutput = captureOutput(machine);
        await pressBbcF1(machine);
        await machine.runFor(2_000_000);
        const output = getOutput();
        expect(output).toContain("HELLO");
    });

    it("function key is lost on CTRL+BREAK without *STORE", async () => {
        await runCommand(machine, "*KEY 1 HELLO");
        await ctrlBreak(machine);

        const getOutput = captureOutput(machine);
        await pressBbcF1(machine);
        await machine.runFor(2_000_000);
        const output = getOutput();
        expect(output).not.toContain("HELLO");
    });

    it("*STORE should preserve function key across CTRL+BREAK", async () => {
        await runCommand(machine, "*KEY 1 HELLO");
        await runCommand(machine, "*STORE");
        await ctrlBreak(machine);

        const getOutput = captureOutput(machine);
        await pressBbcF1(machine);
        await machine.runFor(2_000_000);
        const output = getOutput();
        expect(output).toContain("HELLO");
    });
});
