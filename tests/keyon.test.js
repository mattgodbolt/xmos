import { describe, it, expect } from "vitest";
import { bootWithXmos, runCommand, captureOutput, typeText } from "./xmos-test-machine.js";

describe("KEYON remapping behaviour", () => {
    it("with KEYON, INKEY for cursor-left detects CAPS LOCK", async () => {
        const machine = await bootWithXmos();
        await runCommand(machine, "*KEYON");

        // Program delays then checks if cursor-left is pressed
        await runCommand(machine, "10 FOR I=1 TO 1000:NEXT");
        await runCommand(machine, "20 PRINT INKEY(-98)");

        const getOutput = captureOutput(machine);
        await typeText(machine, "RUN");

        // Hold CAPS LOCK while program runs — with KEYON, the KEYV
        // intercept remaps cursor-left scans to check CAPS LOCK
        machine.processor.sysvia.keyDown(20);
        await machine.runFor(20_000_000);
        machine.processor.sysvia.keyUp(20);

        const output = getOutput();
        expect(output).toContain("-1");
    });

    it("without KEYON, INKEY for cursor-left does NOT detect CAPS LOCK", async () => {
        const machine = await bootWithXmos();

        await runCommand(machine, "10 FOR I=1 TO 1000:NEXT");
        await runCommand(machine, "20 PRINT INKEY(-98)");

        const getOutput = captureOutput(machine);
        await typeText(machine, "RUN");

        // Hold CAPS LOCK — without KEYON, cursor-left scan ignores it
        machine.processor.sysvia.keyDown(20);
        await machine.runFor(20_000_000);
        machine.processor.sysvia.keyUp(20);

        const output = getOutput();
        expect(output).toContain("0");
        expect(output).not.toContain("-1");
    });

    it("KEYOFF should restore normal scanning", async () => {
        const machine = await bootWithXmos();
        await runCommand(machine, "*KEYON");
        await runCommand(machine, "*KEYOFF");

        await runCommand(machine, "10 FOR I=1 TO 1000:NEXT");
        await runCommand(machine, "20 PRINT INKEY(-98)");

        const getOutput = captureOutput(machine);
        await typeText(machine, "RUN");

        machine.processor.sysvia.keyDown(20);
        await machine.runFor(20_000_000);
        machine.processor.sysvia.keyUp(20);

        const output = getOutput();
        // After KEYOFF, remapping is gone — should be 0 again
        expect(output).toContain("0");
        expect(output).not.toContain("-1");
    });
});
