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

    it("%0 should substitute the first argument", async () => {
        const machine = await bootWithXmos();
        await runCommand(machine, "*ALIAS LD *LOAD %0");
        const output = await runCommand(machine, "*LD MyFile");
        expect(output).toContain("*LOAD MyFile");
    });

    it("multiple parameters %0 %1 should substitute positionally", async () => {
        const machine = await bootWithXmos();
        await runCommand(machine, "*ALIAS CP *COPY %0 %1");
        const output = await runCommand(machine, "*CP FileA FileB");
        expect(output).toContain("*COPY FileA FileB");
    });

    it("%% should produce a literal percent sign", async () => {
        const machine = await bootWithXmos();
        await runCommand(machine, "*ALIAS PCT 100%%");
        const output = await runCommand(machine, "*PCT");
        expect(output).toContain("100%");
    });

    it("missing parameter should expand to nothing", async () => {
        const machine = await bootWithXmos();
        await runCommand(machine, "*ALIAS LD *LOAD %0");
        // No argument given — %0 should expand to empty
        const output = await runCommand(machine, "*LD");
        expect(output).toContain("*LOAD");
        // Should not contain any stray parameter text
        expect(output).not.toContain("%");
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

describe("*ALISV / *ALILD — save and load alias files", () => {
    it("should save and reload aliases", async () => {
        const machine = await bootWithXmos();
        await runCommand(machine, "*ALIAS FOO *CAT");
        await runCommand(machine, "*ALIAS BAR *DIR");

        // Save to file
        await runCommand(machine, "*ALISV Aliases", { cycles: 20_000_000 });

        // Clear and verify they're gone
        await runCommand(machine, "*ALICLR");
        const cleared = await runCommand(machine, "*ALIASES");
        expect(cleared).toBe(">");

        // Reload and verify they're back
        await runCommand(machine, "*ALILD Aliases", { cycles: 20_000_000 });
        const reloaded = await runCommand(machine, "*ALIASES");
        expect(reloaded).toContain("FOO = *CAT");
        expect(reloaded).toContain("BAR = *DIR");
    });
});
