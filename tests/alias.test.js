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

    it("*ALIAS with no arguments should show syntax error", async () => {
        const machine = await bootWithXmos();
        const output = await runCommand(machine, "*ALIAS");
        expect(output).toContain("Syntax : ALIAS <alias name> <alias>");
    });

    it("*ALIAS with only a name and no expansion should show syntax error", async () => {
        const machine = await bootWithXmos();
        const output = await runCommand(machine, "*ALIAS FOO");
        expect(output).toContain("Syntax : ALIAS <alias name> <alias>");
    });

    it("redefining an alias should replace the old one", async () => {
        const machine = await bootWithXmos();
        await runCommand(machine, "*ALIAS FOO *CAT");
        await runCommand(machine, "*ALIAS FOO *DIR");
        const output = await runCommand(machine, "*ALIASES");
        expect(output).toContain("FOO = *DIR");
        expect(output).not.toContain("FOO = *CAT");
    });

    it("alias names should be case-insensitive", async () => {
        const machine = await bootWithXmos();
        // Type lowercase — but the BBC with CAPS LOCK off still
        // stores what we type. The compare_string match is
        // case-insensitive, so *foo should match alias FOO.
        await runCommand(machine, "*ALIAS FOO *CAT");
        const output = await runCommand(machine, "*foo");
        expect(output).toContain("*CAT");
    });
});
