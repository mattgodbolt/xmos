import { describe, it, expect } from "vitest";
import { bootWithXmos, runCommand } from "./xmos-test-machine.js";

describe("*LVAR", () => {
    it("should list nothing when no variables are defined", async () => {
        const machine = await bootWithXmos();
        const output = await runCommand(machine, "*LVAR");
        expect(output).toBe(">");
    });

    it("should list real and string variable names", async () => {
        const machine = await bootWithXmos();
        await runCommand(machine, 'X=3.14:G$="HI"');
        const output = await runCommand(machine, "*LVAR");

        // LVAR prints variable names only (no values)
        expect(output).toContain("G$");
        expect(output).toContain("X");
    });

    it("should not list static integer variables", async () => {
        const machine = await bootWithXmos();
        await runCommand(machine, "A%=42:B%=99:SCORE=100");
        const output = await runCommand(machine, "*LVAR");

        // Integer variables (%) are stored statically, not on the heap
        expect(output).not.toContain("A%");
        expect(output).not.toContain("B%");
        // But the real variable should be listed
        expect(output).toContain("SCORE");
    });
});
