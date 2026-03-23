import { describe, it, expect, beforeEach } from "vitest";
import { bootWithXmos, runCommand, captureOutput } from "./xmos-test-machine.js";

// Press BBC f1 (*KEY 1). MCP F0 (PC keycode 112) maps to BBC f1.
async function pressBbcF1(machine) {
    machine.processor.sysvia.keyDown(112);
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
        await pressBbcF1(machine);
        await machine.runFor(2_000_000);
        const output = getOutput();
        expect(output).toContain("HELLO");
    });

    it("function key should be lost after soft reset without *STORE", async () => {
        await runCommand(machine, "*KEY 1 HELLO");
        machine.processor.reset(false);
        await machine.runUntilInput();

        const getOutput = captureOutput(machine);
        await pressBbcF1(machine);
        await machine.runFor(2_000_000);
        const output = getOutput();
        expect(output).not.toContain("HELLO");
    });

    // *STORE should preserve function keys across soft reset by copying
    // ANDY (&8000-&83FF, the Master's function key buffer) to HAZEL
    // store buffers, then alias_init restores them on reset.
    //
    // However, jsbeeb doesn't correctly emulate the ANDY split: on real
    // hardware, ROMSEL bit 7 routes data reads to ANDY while instruction
    // fetches still come from the ROM. jsbeeb routes both to ANDY, so
    // *STORE reads ROM data instead of function key data. This means
    // *STORE cannot be properly tested until jsbeeb is fixed.
    //
    // See JOURNAL.md for full investigation.
    it.skip("*STORE should preserve function key across soft reset (jsbeeb ANDY bug)", async () => {
        await runCommand(machine, "*KEY 1 HELLO");
        await runCommand(machine, "*STORE");
        machine.processor.reset(false);
        await machine.runUntilInput();

        const getOutput = captureOutput(machine);
        await pressBbcF1(machine);
        await machine.runFor(2_000_000);
        const output = getOutput();
        expect(output).toContain("HELLO");
    });
});
