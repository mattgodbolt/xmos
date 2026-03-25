import { describe, it, expect } from "vitest";
import { bootWithXmos, runCommand } from "./xmos-test-machine.js";

describe("*S — save with incore name", () => {
    it("should save and print the filename", async () => {
        const machine = await bootWithXmos();
        await runCommand(machine, "10 REM > Prog");
        await runCommand(machine, '20 PRINT "HELLO"');
        const output = await runCommand(machine, "*S", { cycles: 20_000_000 });

        expect(output).toContain("Program saved as 'Prog'");
    });

    it("should handle filenames with leading spaces after >", async () => {
        const machine = await bootWithXmos();
        await runCommand(machine, "10 REM >   MyFile");
        await runCommand(machine, "20 A=1");
        const output = await runCommand(machine, "*S", { cycles: 20_000_000 });

        expect(output).toContain("Program saved as 'MyFile'");
    });

    it("should error with no program loaded", async () => {
        const machine = await bootWithXmos();
        const output = await runCommand(machine, "*S");

        expect(output).toContain("No BASIC program");
    });

    it("should error when first line has no REM >", async () => {
        const machine = await bootWithXmos();
        await runCommand(machine, '10 PRINT "HELLO"');
        const output = await runCommand(machine, "*S");

        expect(output).toContain("No incore filename");
    });

    it("should error when REM has no > marker", async () => {
        const machine = await bootWithXmos();
        await runCommand(machine, "10 REM This has no marker");
        const output = await runCommand(machine, "*S");

        expect(output).toContain("No incore filename");
    });
});
