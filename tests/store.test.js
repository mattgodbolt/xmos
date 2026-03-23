import { describe, it, expect, beforeEach } from "vitest";
import { bootWithXmos, runCommand, captureOutput } from "./xmos-test-machine.js";

const CTRL = 17;

// Press BBC f1 (*KEY 1). MCP F0 (PC keycode 112) maps to BBC f1.
async function pressBbcF1(machine) {
    machine.processor.sysvia.keyDown(112);
    await machine.runFor(200000);
    machine.processor.sysvia.keyUp(112);
    await machine.runFor(200000);
}

// Simulate CTRL+BREAK: hold CTRL during a soft reset.
async function ctrlBreak(machine) {
    machine.processor.sysvia.keyDown(CTRL);
    machine.processor.reset(false);
    await machine.runFor(2_000_000);
    machine.processor.sysvia.keyUp(CTRL);
    await machine.runUntilInput();
}

// Work around a bug in the original XMOS ROM: *STORE and alias_init
// write to &FE30 with bit 7 set but don't update the &F4 shadow.
// If an interrupt fires mid-copy, the handler restores ROMSEL from &F4
// (without bit 7), unpaging ANDY. Fix: intercept &FE30 writes and
// mirror them to &F4.
function patchStoreF4Bug(machine) {
    const cpu = machine.processor;
    cpu.debugInstruction.add((addr) => {
        // *STORE: STA &FE30 at &934E (the ORA #&80 path)
        // alias_init: STA &FE30 at &9386 (the ORA #&80 path)
        // At these points, A has the bit-7-set value about to be
        // written. Mirror it to &F4 so the interrupt handler
        // restores the right value.
        if (addr === 0x934e || addr === 0x9386) {
            cpu.writemem(0xf4, cpu.a);
        }
        // *STORE: STA &FE30 at &9370 (the AND #&7F restore path)
        // alias_init: STA &FE30 at &93a2 (the AND #&7F restore path)
        // Restore &F4 too.
        if (addr === 0x9370 || addr === 0x93a2) {
            cpu.writemem(0xf4, cpu.a);
        }
        return false;
    });
}

describe("*STORE — keep function keys on CTRL+BREAK", () => {
    let machine;

    beforeEach(async () => {
        machine = await bootWithXmos();
        patchStoreF4Bug(machine);
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
