import { describe, it, expect } from "vitest";
import { bootWithXmos, runCommand } from "./xmos-test-machine.js";

describe("*STORE — preserve state across reset", () => {
    it("aliases survive soft reset after *STORE", async () => {
        const machine = await bootWithXmos();
        await runCommand(machine, "*ALIAS FOO *CAT");
        await runCommand(machine, "*STORE");

        machine.processor.reset(false);
        await machine.runUntilInput();

        const output = await runCommand(machine, "*ALIASES");
        expect(output).toContain("FOO = *CAT");
    });

    it("aliases survive soft reset even without *STORE", async () => {
        const machine = await bootWithXmos();
        await runCommand(machine, "*ALIAS FOO *CAT");

        machine.processor.reset(false);
        await machine.runUntilInput();

        const output = await runCommand(machine, "*ALIASES");
        expect(output).toContain("FOO = *CAT");
    });
});
