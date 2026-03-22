import { describe, it, expect, beforeEach } from "vitest";
import { bootWithXmos, runCommand, captureOutput, typeText } from "./xmos-test-machine.js";

describe("*XON / *XOFF — extended input", () => {
    let machine;

    beforeEach(async () => {
        machine = await bootWithXmos();
        await runCommand(machine, '10 PRINT "HELLO"');
        await runCommand(machine, '20 PRINT "WORLD"');
    });

    it("without XON, TAB after a line number does nothing special", async () => {
        await runCommand(machine, "*XOFF");

        const getOutput = captureOutput(machine);
        // Type "10" then TAB — without XON, TAB is just a regular key
        await typeText(machine,"10\t");
        await machine.runFor(4_000_000);

        const output = getOutput();
        // Should NOT contain the contents of line 10
        expect(output).not.toContain("HELLO");
    });

    it("with XON, TAB after line number recalls that line", async () => {
        await runCommand(machine, "*XON");

        const getOutput = captureOutput(machine);
        // Type "20" then TAB — should recall line 20
        await typeText(machine,"20\t");
        await machine.runFor(4_000_000);

        const output = getOutput();
        // Line 20 should be expanded with its tokenised content
        expect(output).toContain('PRINT "WORLD"');
    });

    it("with XON, TAB for a non-existent line does nothing", async () => {
        await runCommand(machine, "*XON");

        const getOutput = captureOutput(machine);
        // Type "15" then TAB — line 15 doesn't exist
        await typeText(machine,"15\t");
        await machine.runFor(4_000_000);

        const output = getOutput();
        // Should not recall any line content
        expect(output).not.toContain("HELLO");
        expect(output).not.toContain("WORLD");
    });

    it("with XON, recalled line can be appended to", async () => {
        await runCommand(machine, "*XON");

        const getOutput = captureOutput(machine);
        // Recall line 10 then type extra text at the end
        await typeText(machine,"10\t:REM EXTRA");
        await machine.runFor(4_000_000);

        const output = getOutput();
        // Should have the original line content AND the appended text
        expect(output).toContain('PRINT "HELLO"');
        expect(output).toContain("REM EXTRA");
    });

    it("*XOFF should disable TAB recall", async () => {
        await runCommand(machine, "*XON");
        await runCommand(machine, "*XOFF");

        const getOutput = captureOutput(machine);
        await typeText(machine,"10\t");
        await machine.runFor(4_000_000);

        const output = getOutput();
        // TAB should no longer recall lines
        expect(output).not.toContain("HELLO");
    });
});

describe("*KEYON / *KEYOFF / *KSTATUS", () => {
    it("*KEYON should report keys are redefined", async () => {
        const machine = await bootWithXmos();
        const output = await runCommand(machine, "*KEYON");
        expect(output).toBe("Keys now redefined>");
    });

    it("*KEYOFF should report keys are off", async () => {
        const machine = await bootWithXmos();
        const output = await runCommand(machine, "*KEYOFF");
        expect(output).toBe("Redefined keys off>");
    });

    it("*KSTATUS should report off by default", async () => {
        const machine = await bootWithXmos();
        const output = await runCommand(machine, "*KSTATUS");
        expect(output).toBe("Redefined keys off>");
    });

    it("*KSTATUS after *KEYON should list key definitions", async () => {
        const machine = await bootWithXmos();
        await runCommand(machine, "*KEYON");
        const output = await runCommand(machine, "*KSTATUS");

        expect(output).toContain("Redefined keys on, and are:");
        expect(output).toContain("Left : CAPS LOCK");
        expect(output).toContain("Right : CTRL");
        expect(output).toContain("Up : :");
        expect(output).toContain("Down : /");
        expect(output).toContain("Jump/fire : RETURN");
    });
});
