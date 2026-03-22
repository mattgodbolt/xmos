import { describe, it, expect } from "vitest";
import { bootWithXmos, runCommand } from "./xmos-test-machine.js";

describe("*ALIAS / *ALIASES / *ALICLR", () => {
    it("*ALIASES should list nothing on a fresh boot", async () => {
        const machine = await bootWithXmos();
        const output = await runCommand(machine, "*ALIASES");
        expect(output).toBe(">");
    });

    it("*ALIAS should define an alias visible in *ALIASES", async () => {
        const machine = await bootWithXmos();
        await runCommand(machine, "*ALIAS FOO *CAT");
        const output = await runCommand(machine, "*ALIASES");
        expect(output).toContain("FOO = *CAT");
    });

    it("should support multiple aliases", async () => {
        const machine = await bootWithXmos();
        await runCommand(machine, "*ALIAS FOO *CAT");
        await runCommand(machine, "*ALIAS BAR *DIR");
        const output = await runCommand(machine, "*ALIASES");
        expect(output).toContain("FOO = *CAT");
        expect(output).toContain("BAR = *DIR");
    });

    it("*ALICLR should clear all aliases", async () => {
        const machine = await bootWithXmos();
        await runCommand(machine, "*ALIAS FOO *CAT");
        await runCommand(machine, "*ALIAS BAR *DIR");
        await runCommand(machine, "*ALICLR");
        const output = await runCommand(machine, "*ALIASES");
        expect(output).toBe(">");
    });

    it("alias should expand to typed text at the prompt", async () => {
        const machine = await bootWithXmos();
        await runCommand(machine, "*ALIAS LS *CAT");
        const output = await runCommand(machine, "*LS");
        expect(output).toContain("*CAT");
    });
});
