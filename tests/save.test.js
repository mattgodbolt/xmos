import { describe, it, expect } from "vitest";
import { bootWithXmos, runCommand } from "./xmos-test-machine.js";

describe("*S — save with incore name", () => {
    it("should save and print the filename", async () => {
        const machine = await bootWithXmos();
        await runCommand(machine, "10 REM > Prog");
        await runCommand(machine, '20 PRINT "HELLO"');
        // Disc I/O needs extra cycles
        const output = await runCommand(machine, "*S", 20_000_000);

        expect(output).toContain("Program saved as 'Prog'");
    });

    it("should handle filenames with leading spaces", async () => {
        const machine = await bootWithXmos();
        await runCommand(machine, "10 REM >   MyFile");
        await runCommand(machine, "20 A=1");
        const output = await runCommand(machine, "*S", 20_000_000);

        expect(output).toContain("Program saved as 'MyFile'");
    });
});
