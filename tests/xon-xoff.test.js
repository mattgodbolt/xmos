import { describe, it, expect } from "vitest";
import { bootWithXmos, runCommand } from "./xmos-test-machine.js";

describe("*XON / *XOFF", () => {
    it("*XON should produce no output", async () => {
        const machine = await bootWithXmos();
        const output = await runCommand(machine, "*XON");
        expect(output).toBe(">");
    });

    it("*XOFF should produce no output", async () => {
        const machine = await bootWithXmos();
        const output = await runCommand(machine, "*XOFF");
        expect(output).toBe(">");
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
