import { describe, it, expect } from "vitest";
import { restoreOrBoot, runCommand } from "./xmos-test-machine.js";

const VduStatus = 0xd0;
const VduDisabled = 0x80;

describe("*BAU — break apart utility", () => {
    it("should split multi-statement lines", async () => {
        const machine = await restoreOrBoot();
        await runCommand(machine, '10 PRINT "A":PRINT "B":PRINT "C"');

        await runCommand(machine, "*BAU");
        const output = await runCommand(machine, "LIST");

        // After BAU, each statement should be on its own line
        expect(output).toContain('PRINT "A"');
        expect(output).toContain('PRINT "B"');
        expect(output).toContain('PRINT "C"');
    });

    it("should not split colons inside strings", async () => {
        const machine = await restoreOrBoot();
        await runCommand(machine, '10 PRINT "A:B":PRINT "C"');

        await runCommand(machine, "*BAU");
        const output = await runCommand(machine, "LIST");

        // The colon inside "A:B" should NOT cause a split
        expect(output).toContain('PRINT "A:B"');
        expect(output).toContain('PRINT "C"');
    });

    it("should leave single-statement lines unchanged", async () => {
        const machine = await restoreOrBoot();
        await runCommand(machine, '10 PRINT "HELLO"');

        await runCommand(machine, "*BAU");
        const output = await runCommand(machine, "LIST");

        expect(output).toContain('PRINT "HELLO"');
    });

    it("should renumber the split lines and leave the screen on", async () => {
        const machine = await restoreOrBoot();
        await runCommand(machine, '10 PRINT "A":PRINT "B"');
        await runCommand(machine, '20 PRINT "C"');

        const bau = await runCommand(machine, "*BAU");
        await machine.runUntilInput();
        const output = await runCommand(machine, "LIST");

        expect(bau).not.toContain("Bad");
        expect(output).toMatch(/10 PRINT "A"\s+20 ?PRINT "B"\s+30 PRINT "C"/);
        expect(machine.readbyte(VduStatus) & VduDisabled).toBe(0);
    });

    it("should not split after REM", async () => {
        const machine = await restoreOrBoot();
        await runCommand(machine, "10 REM this:has:colons");

        await runCommand(machine, "*BAU");
        const output = await runCommand(machine, "LIST");

        // REM consumes the rest of the line — colons are part of the comment
        expect(output).toContain("REM this:has:colons");
    });
});

describe("*SPACE — insert keyword spaces", () => {
    it("should insert spaces around keywords", async () => {
        const machine = await restoreOrBoot();
        await runCommand(machine, "10 FORX=1TO10:PRINTX:NEXT");

        await runCommand(machine, "*SPACE");
        const output = await runCommand(machine, "LIST");

        // SPACE should insert spaces after tokenised keywords
        expect(output).toContain("FOR");
        expect(output).toContain("TO");
        expect(output).toContain("PRINT");
        expect(output).toContain("NEXT");
    });

    it("should not modify an empty program", async () => {
        const machine = await restoreOrBoot();
        // No program loaded
        await runCommand(machine, "*SPACE");
        const output = await runCommand(machine, "LIST");

        // LIST of empty program just shows the prompt
        expect(output).toBe(">");
    });
});
