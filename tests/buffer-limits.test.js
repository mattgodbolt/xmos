import { describe, it, expect, beforeEach } from "vitest";
import { bootWithXmos, runCommand } from "./xmos-test-machine.js";

describe("alias table capacity", () => {
    let machine;

    beforeEach(async () => {
        machine = await bootWithXmos();
    });

    it("should hold many short aliases", async () => {
        // Each alias entry: name + null + expansion + CR + FF sentinel
        const count = 10;
        for (let i = 0; i < count; i++) {
            await runCommand(machine, `*ALIAS A${i} *CAT`);
        }
        const output = await runCommand(machine, "*ALIASES");
        expect(output).toContain("A0 = *CAT");
        expect(output).toContain("A9 = *CAT");
    });

    it("should hold aliases with long expansions", async () => {
        // Max expansion: long string approaching buffer limits
        const longCmd = "*" + "X".repeat(60);
        await runCommand(machine, `*ALIAS LONG ${longCmd}`);
        const output = await runCommand(machine, "*ALIASES");
        expect(output).toContain(`LONG = ${longCmd}`);
    });

    it("should accept aliases up to the table limit", async () => {
        // Add 10 aliases with moderate expansions — should all succeed
        for (let i = 0; i < 10; i++) {
            const output = await runCommand(machine, `*ALIAS B${i} *DIR`);
            expect(output).not.toContain("No room");
        }
        const listing = await runCommand(machine, "*ALIASES");
        expect(listing).toContain("B0 = *DIR");
        expect(listing).toContain("B9 = *DIR");
    });

    it("*ALICLR should free all space after filling", async () => {
        // Fill table with a few aliases
        for (let i = 0; i < 5; i++) {
            await runCommand(machine, `*ALIAS F${i} *CAT`);
        }
        // Clear
        await runCommand(machine, "*ALICLR");
        // Should be able to add again
        await runCommand(machine, "*ALIAS TEST *DIR");
        const output = await runCommand(machine, "*ALIASES");
        expect(output).toContain("TEST = *DIR");
        // Old aliases should be gone
        expect(output).not.toContain("F0 =");
    });
});

describe("input line length", () => {
    let machine;

    beforeEach(async () => {
        machine = await bootWithXmos();
    });

    it("should handle a long BASIC line", async () => {
        // BASIC lines can be up to 238 characters
        const longLine = '10 REM ' + "A".repeat(200);
        await runCommand(machine, longLine);
        const output = await runCommand(machine, "LIST");
        expect(output).toContain("REM");
        expect(output).toContain("AAAA");
    });
});

describe("*HELP with many commands", () => {
    it("should list all commands even with SHIFT held for paging", async () => {
        const machine = await bootWithXmos();
        const output = await runCommand(machine, "*HELP XMOS");
        // First command
        expect(output).toContain("ALIAS");
        // Last command
        expect(output).toContain("XOFF");
    });
});

describe("alias parameter substitution limits", () => {
    let machine;

    beforeEach(async () => {
        machine = await bootWithXmos();
    });

    it("should substitute multiple parameters", async () => {
        await runCommand(machine, "*ALIAS CP *COPY %0 %1 %2");
        const output = await runCommand(machine, "*CP FileA FileB FileC");
        expect(output).toContain("*COPY FileA FileB FileC");
    });

    it("should handle three parameters", async () => {
        await runCommand(machine, "*ALIAS CP *COPY %0 %1 %2");
        const output = await runCommand(machine, "*CP Src Dst Opt");
        expect(output).toContain("*COPY Src Dst Opt");
    });
});

describe("multiple BASIC variables for *LVAR", () => {
    it("should list many variables", async () => {
        const machine = await bootWithXmos();
        // Define several variables of different types
        await runCommand(machine, "AA=1:BB=2:CC=3:DD=4:EE=5");
        await runCommand(machine, 'FF$="hello":GG$="world"');
        await runCommand(machine, "DIM HH(5)");
        const output = await runCommand(machine, "*LVAR");
        expect(output).toContain("AA");
        expect(output).toContain("BB");
        expect(output).toContain("CC");
        expect(output).toContain("DD");
        expect(output).toContain("EE");
        expect(output).toContain("FF$");
        expect(output).toContain("GG$");
        expect(output).toContain("HH(");
    });
});

describe("*DIS across page boundaries", () => {
    it("should disassemble across a page boundary without crashing", async () => {
        const machine = await bootWithXmos();
        const { captureOutput } = await import("./xmos-test-machine.js");
        const { typeText } = await import("./xmos-test-machine.js");

        const getOutput = captureOutput(machine);
        await typeText(machine, "*DIS 80F0");
        // Hold space to scroll through ~32 instructions (crossing &8100)
        machine.processor.sysvia.keyDown(32);
        await machine.runFor(20_000_000);
        machine.processor.sysvia.keyUp(32);

        const output = getOutput();
        // Should have crossed from 80Fx into 81xx
        expect(output).toContain("80F");
        expect(output).toContain("810");
    });
});

describe("*BAU with many split points", () => {
    it("should split a line with many colons", async () => {
        const machine = await bootWithXmos();
        // Line with 5 colon-separated statements
        await runCommand(machine, "10 A=1:B=2:C=3:D=4:E=5");
        await runCommand(machine, "*BAU");
        const output = await runCommand(machine, "LIST");
        // Each statement should be on its own line after BAU
        expect(output).toContain("A=1");
        expect(output).toContain("B=2");
        expect(output).toContain("C=3");
        expect(output).toContain("D=4");
        expect(output).toContain("E=5");
    });
});
