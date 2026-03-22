import { describe, it, expect } from "vitest";
import { bootWithXmos, runCommand } from "./xmos-test-machine.js";

describe("*LVAR", () => {
    it("should list nothing when no variables are defined", async () => {
        const machine = await bootWithXmos();
        const output = await runCommand(machine, "*LVAR");
        expect(output).toBe(">");
    });

    it("should list real and string variables but not integer", async () => {
        const machine = await bootWithXmos();
        await runCommand(machine, 'A%=42:B$="hello":C=3.14');
        const output = await runCommand(machine, "*LVAR");

        // LVAR lists heap variables (real and string), not static integer vars
        expect(output).toContain("B$");
        expect(output).toContain("C");
        expect(output).not.toContain("A%");
    });

    it("should list multiple variables", async () => {
        const machine = await bootWithXmos();
        await runCommand(machine, "X=1:Y=2:Z=3");
        const output = await runCommand(machine, "*LVAR");

        expect(output).toContain("X");
        expect(output).toContain("Y");
        expect(output).toContain("Z");
    });
});
