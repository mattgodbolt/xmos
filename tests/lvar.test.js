import { describe, it, expect } from "vitest";
import { restoreOrBoot, runCommand } from "./xmos-test-machine.js";

describe("*LVAR", () => {
    it("should list nothing when no variables are defined", async () => {
        const machine = await restoreOrBoot();
        const output = await runCommand(machine, "*LVAR");
        expect(output).toBe(">");
    });

    it("should list real and string variable names", async () => {
        const machine = await restoreOrBoot();
        await runCommand(machine, 'X=3.14:G$="HI"');
        const output = await runCommand(machine, "*LVAR", { raw: true });
        // LVAR prints variable names only (no values), one per line
        expect(output).toBe("\nG$\nX\n>");
    });

    it("should not list static integer variables", async () => {
        const machine = await restoreOrBoot();
        await runCommand(machine, "A%=42:B%=99:SCORE=100");
        const output = await runCommand(machine, "*LVAR", { raw: true });
        // Only heap variables listed — integer vars (A%, B%) excluded
        expect(output).toBe("\nSCORE\n>");
    });

    it("should list array variables", async () => {
        const machine = await restoreOrBoot();
        await runCommand(machine, "DIM D(10)");
        const output = await runCommand(machine, "*LVAR", { raw: true });
        expect(output).toBe("\nD(\n>");
    });

    it("should still work after an alias is defined", async () => {
        const machine = await restoreOrBoot();
        await runCommand(machine, "*ALIAS LS *CAT");
        await runCommand(machine, 'X=3.14:G$="HI"');
        const output = await runCommand(machine, "*LVAR", { raw: true });
        expect(output).toBe("\nG$\nX\n>");
    });
});
