import { describe, it, expect, beforeEach } from "vitest";
import { bootWithXmos, runCommand, captureOutput } from "./xmos-test-machine.js";

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
        await machine.type("10\t");
        await machine.runFor(4_000_000);

        const output = getOutput();
        // Should NOT contain the contents of line 10
        expect(output).not.toContain("HELLO");
    });

    it("with XON, TAB after line number recalls that line", async () => {
        await runCommand(machine, "*XON");

        const getOutput = captureOutput(machine);
        // Type "20" then TAB — should recall line 20
        await machine.type("20\t");
        await machine.runFor(4_000_000);

        const output = getOutput();
        // Line 20 should be expanded with its tokenised content
        expect(output).toContain('PRINT "WORLD"');
    });

    it("with XON, TAB for a non-existent line does nothing", async () => {
        await runCommand(machine, "*XON");

        const getOutput = captureOutput(machine);
        // Type "15" then TAB — line 15 doesn't exist
        await machine.type("15\t");
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
        await machine.type("10\t:REM EXTRA");
        await machine.runFor(4_000_000);

        const output = getOutput();
        // Should have the original line content AND the appended text
        expect(output).toContain('PRINT "HELLO"');
        expect(output).toContain("REM EXTRA");
    });

    it("with XON, left arrow then typing should insert before end", async () => {
        await runCommand(machine, "*XON");

        const getOutput = captureOutput(machine);
        // Recall line 10, press left arrow, then type X
        await machine.type("10\t");
        await machine.runFor(2_000_000);
        // Press left arrow
        machine.keyDown(37);
        await machine.runFor(80000);
        machine.keyUp(37);
        await machine.runFor(80000);
        // Type X — should insert before the last character
        await machine.type("X");
        await machine.runFor(2_000_000);

        const output = getOutput();
        // X should appear before the closing quote
        expect(output).toContain("X");
        expect(output).toContain("HELLO");
    });

    it("with XON, COPY key should delete character under cursor", async () => {
        await runCommand(machine, "*XON");

        // Recall line 10
        await machine.type("10\t");
        await machine.runFor(2_000_000);
        // Press COPY (END key = 35) — should delete character at cursor
        machine.keyDown(35);
        await machine.runFor(80000);
        machine.keyUp(35);
        await machine.runFor(80000);

        // Submit the modified line and LIST to see the result
        const getOutput = captureOutput(machine);
        await machine.type("");
        await machine.runFor(4_000_000);
        await machine.type("LIST");
        await machine.runFor(4_000_000);

        const output = getOutput();
        // One character should be deleted from the line
        expect(output).toContain("PRINT");
    });

    it("with XON, Ctrl-U should clear the current line", async () => {
        await runCommand(machine, "*XON");

        // Start typing something
        const getOutput = captureOutput(machine);
        await machine.type("PRINT 42");
        await machine.runFor(2_000_000);
        // Press Ctrl-U (character code 21, keycode for U=85 with CTRL)
        machine.keyDown(17); // CTRL
        machine.keyDown(85); // U
        await machine.runFor(80000);
        machine.keyUp(85);
        machine.keyUp(17);
        await machine.runFor(2_000_000);
        // Now type something else and submit
        await machine.type("PRINT 99");
        await machine.runFor(4_000_000);

        const output = getOutput();
        // Should see 99, not 42 (line was cleared before retyping)
        expect(output).toContain("99");
    });

    it("cursor key on blank line enters split cursor mode", async () => {
        await runCommand(machine, "*XON");

        // Press cursor right on a blank line — enters BBC cursor editing
        // for one keypress, then returns to extended input
        const getOutput = captureOutput(machine);
        machine.keyDown(39); // RIGHT
        await machine.runFor(200000);
        machine.keyUp(39);
        await machine.runFor(2_000_000);

        // Extended input is still active — TAB still recalls lines
        await machine.type("20\t");
        await machine.runFor(4_000_000);

        const output = getOutput();
        expect(output).toContain("WORLD");
    });

    it("typing SAVE in BASIC should execute *S", async () => {
        await runCommand(machine, "NEW");
        await runCommand(machine, "10 REM > Test");
        await runCommand(machine, '20 PRINT "HI"');
        await runCommand(machine, "*XON");

        const getOutput = captureOutput(machine);
        await machine.type("SAVE");
        await machine.runFor(20_000_000);

        const output = getOutput();
        expect(output).toContain("Program saved as");
    });

    it("*XOFF should disable TAB recall", async () => {
        await runCommand(machine, "*XON");
        await runCommand(machine, "*XOFF");

        const getOutput = captureOutput(machine);
        await machine.type("10\t");
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

    it("*KEYON twice should warn already executed", async () => {
        const machine = await bootWithXmos();
        await runCommand(machine, "*KEYON");
        const output = await runCommand(machine, "*KEYON");
        expect(output).toContain("already executed");
    });

    it("*KSTATUS after *KEYON then *KEYOFF should report off", async () => {
        const machine = await bootWithXmos();
        await runCommand(machine, "*KEYON");
        await runCommand(machine, "*KEYOFF");
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
