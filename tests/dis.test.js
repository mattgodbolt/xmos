import { describe, it, expect } from "vitest";
import { bootWithXmos, captureOutput } from "./xmos-test-machine.js";

describe("*DIS", () => {
    it("should disassemble the ROM service entry point", async () => {
        const machine = await bootWithXmos();
        const getOutput = captureOutput(machine);

        await machine.type("*DIS 802B");
        await machine.runFor(4_000_000);

        const output = getOutput();
        // &802B is CMP #&04 (the service entry)
        expect(output).toContain("802B");
        expect(output).toContain("CMP #&04");
        expect(output).toContain("C9 04");
    });

    it("should show JMP at &8003 (service entry jump)", async () => {
        const machine = await bootWithXmos();
        const getOutput = captureOutput(machine);

        await machine.type("*DIS 8003");
        await machine.runFor(4_000_000);

        const output = getOutput();
        expect(output).toContain("8003");
        expect(output).toContain("JMP &802B");
        expect(output).toContain("4C 2B 80");
    });

    it("should show multiple lines when space is held", async () => {
        const machine = await bootWithXmos();
        const getOutput = captureOutput(machine);

        await machine.type("*DIS 802B");
        // Hold space to scroll through multiple lines
        machine.keyDown(32); // SPACE
        await machine.runFor(8_000_000);
        machine.keyUp(32);

        const output = getOutput();
        // Should have advanced past &802B to show several instructions
        expect(output).toContain("802B");
        expect(output).toContain("802D");
    });

    it("should disassemble zero page as BRK instructions", async () => {
        const machine = await bootWithXmos();
        const getOutput = captureOutput(machine);

        // Zero page will contain whatever values are there, but &00 = BRK
        await machine.type("*DIS 0000");
        await machine.runFor(4_000_000);

        const output = getOutput();
        expect(output).toContain("0000");
    });

    it("should disassemble MOS code at high addresses", async () => {
        const machine = await bootWithXmos();
        const getOutput = captureOutput(machine);

        // &FFE3 is OSASCI — CMP #&0D (check for carriage return)
        await machine.type("*DIS FFE3");
        await machine.runFor(4_000_000);

        const output = getOutput();
        expect(output).toContain("FFE3");
        expect(output).toContain("CMP #&0D");
    });
});
