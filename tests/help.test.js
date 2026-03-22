import { describe, it, expect } from "vitest";
import { bootWithXmos, runCommand } from "./xmos-test-machine.js";

describe("*HELP XMOS", () => {
    it("should list all XMOS commands with descriptions", async () => {
        const machine = await bootWithXmos();
        const output = await runCommand(machine, "*HELP XMOS");

        expect(output).toContain("MOS Extension commands:");
        expect(output).toContain("ALIAS    <alias name> <alias>");
        expect(output).toContain("ALIASES  Shows active aliases");
        expect(output).toContain("ALICLR   Clears all aliases");
        expect(output).toContain("ALILD    Loads alias file");
        expect(output).toContain("ALISV    Saves alias file");
        expect(output).toContain("BAU      Splits to single commands");
        expect(output).toContain("DEFKEYS  Defines new keys");
        expect(output).toContain("DIS      <addr> - disassemble memory");
        expect(output).toContain("KEYON    Enables redefined keys");
        expect(output).toContain("KEYOFF   Disables redefined keys");
        expect(output).toContain("KSTATUS  Displays KEYON status");
        expect(output).toContain("L        Selects mode 128");
        expect(output).toContain("LVAR     Shows current variables");
        expect(output).toContain("MEM      <addr> - memory editor");
        expect(output).toContain("S        Saves BASIC with incore name");
        expect(output).toContain("SPACE    Inserts spaces into programs");
        expect(output).toContain("STORE    Keeps function keys on break");
        expect(output).toContain("XON      Enables extended input");
        expect(output).toContain("XOFF     Disables extended input");
    });
});

describe("*HELP", () => {
    it("should include MOS Extension with XMOS and FEATURES subcommands", async () => {
        const machine = await bootWithXmos();
        const output = await runCommand(machine, "*HELP");

        expect(output).toContain("MOS Extension");
        expect(output).toContain("  XMOS");
        expect(output).toContain("  FEATURES");
    });
});

describe("*HELP FEATURES", () => {
    it("should describe the extended input features", async () => {
        const machine = await bootWithXmos();
        const output = await runCommand(machine, "*HELP FEATURES");

        expect(output).toContain("In addition to the commands shown under *HELP XMOS");
        expect(output).toContain("extended keyboard facilities are available whilst in *XON mode");
        expect(output).toContain("Input can now be edited using the arrow keys");
        expect(output).toContain("COPY  deletes the character under the cursor");
        expect(output).toContain("pressing TAB calls up that line for editing");
        expect(output).toContain("recalled using SHIFT-up and SHIFT-down");
        expect(output).toContain("Typing SAVE while in BASIC will execute the equivalent of *S");
    });
});

describe("abbreviated commands", () => {
    it("*H. XMOS should work as *HELP XMOS", async () => {
        const machine = await bootWithXmos();
        const output = await runCommand(machine, "*H. XMOS");

        expect(output).toContain("MOS Extension commands:");
        expect(output).toContain("ALIAS    <alias name> <alias>");
    });

    it("*HELP X. should match XMOS and show the command listing", async () => {
        const machine = await bootWithXmos();
        const output = await runCommand(machine, "*HELP X.");

        expect(output).toContain("MOS Extension commands:");
        expect(output).toContain("ALIAS    <alias name> <alias>");
    });
});
