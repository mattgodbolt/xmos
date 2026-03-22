import { describe, it, expect, beforeEach } from "vitest";
import { bootWithXmos, runCommand, captureOutput, typeText } from "./xmos-test-machine.js";

const CAPS_LOCK = 20;

describe("KEYON remapping behaviour", () => {
    let machine;

    beforeEach(async () => {
        machine = await bootWithXmos();
        // Program delays then checks if cursor-left is pressed
        await runCommand(machine, "10 FOR I=1 TO 1000:NEXT");
        await runCommand(machine, "20 PRINT INKEY(-98)");
    });

    async function runWithKeyHeld(keyCode) {
        const getOutput = captureOutput(machine);
        await typeText(machine, "RUN");
        machine.processor.sysvia.keyDown(keyCode);
        await machine.runFor(20_000_000);
        machine.processor.sysvia.keyUp(keyCode);
        return getOutput();
    }

    it("with KEYON, INKEY for cursor-left detects CAPS LOCK", async () => {
        await runCommand(machine, "*KEYON");
        const output = await runWithKeyHeld(CAPS_LOCK);
        expect(output).toContain("-1");
    });

    it("without KEYON, INKEY for cursor-left does NOT detect CAPS LOCK", async () => {
        const output = await runWithKeyHeld(CAPS_LOCK);
        expect(output).toContain("0");
        expect(output).not.toContain("-1");
    });

    it("KEYOFF should restore normal scanning", async () => {
        await runCommand(machine, "*KEYON");
        await runCommand(machine, "*KEYOFF");
        const output = await runWithKeyHeld(CAPS_LOCK);
        expect(output).toContain("0");
        expect(output).not.toContain("-1");
    });
});
