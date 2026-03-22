import { describe, it, expect } from "vitest";
import { bootWithXmos, captureOutput, typeText } from "./xmos-test-machine.js";

describe("*DIS", () => {
    it("should disassemble the ROM service entry point", async () => {
        const machine = await bootWithXmos();
        const getOutput = captureOutput(machine);

        // DIS shows one line then waits for a keypress
        await typeText(machine,"*DIS 802B");
        await machine.runFor(4_000_000);

        const output = getOutput();
        // &802B is CMP #&04 (the service entry)
        expect(output).toContain("802B");
        expect(output).toContain("CMP #&04");
        expect(output).toContain("C9 04");
    });

    it("should show multiple lines when space is held", async () => {
        const machine = await bootWithXmos();
        const getOutput = captureOutput(machine);

        await typeText(machine,"*DIS 802B");
        // Hold space to scroll through multiple lines
        machine.processor.sysvia.keyDown(32); // SPACE
        await machine.runFor(8_000_000);
        machine.processor.sysvia.keyUp(32);

        const output = getOutput();
        // Should have advanced past &802B
        expect(output).toContain("802B");
        expect(output).toContain("802D");
    });

    it("should show JMP at &8003 (service entry jump)", async () => {
        const machine = await bootWithXmos();
        const getOutput = captureOutput(machine);

        await typeText(machine,"*DIS 8003");
        await machine.runFor(4_000_000);

        const output = getOutput();
        expect(output).toContain("8003");
        expect(output).toContain("JMP &802B");
        expect(output).toContain("4C 2B 80");
    });
});
