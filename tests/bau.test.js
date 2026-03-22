import { describe, it, expect } from "vitest";
import { bootWithXmos, runCommand } from "./xmos-test-machine.js";

describe("*BAU — break apart utility", () => {
    it("should split multi-statement lines", async () => {
        const machine = await bootWithXmos();
        await runCommand(machine, '10 PRINT "A":PRINT "B":PRINT "C"');

        await runCommand(machine, "*BAU");
        const output = await runCommand(machine, "LIST");

        // After BAU, each statement should be on its own line
        // The line numbers get renumbered
        expect(output).toContain('PRINT "A"');
        expect(output).toContain('PRINT "B"');
        expect(output).toContain('PRINT "C"');
    });

    it("should not split colons inside strings", async () => {
        const machine = await bootWithXmos();
        await runCommand(machine, '10 PRINT "A:B":PRINT "C"');

        await runCommand(machine, "*BAU");
        const output = await runCommand(machine, "LIST");

        // The colon inside "A:B" should NOT cause a split
        expect(output).toContain('PRINT "A:B"');
        expect(output).toContain('PRINT "C"');
    });
});

describe("*SPACE — insert keyword spaces", () => {
    it("should insert spaces around keywords", async () => {
        const machine = await bootWithXmos();
        await runCommand(machine, "10 FORX=1TO10:PRINTX:NEXT");

        await runCommand(machine, "*SPACE");
        const output = await runCommand(machine, "LIST");

        // SPACE should insert spaces after tokenised keywords
        expect(output).toContain("FOR");
        expect(output).toContain("TO");
        expect(output).toContain("PRINT");
        expect(output).toContain("NEXT");
    });
});
