import { describe, it, expect, beforeEach } from "vitest";
import { bootWithXmos, runCommand, captureOutput } from "./xmos-test-machine.js";

/**
 * Install a BRK error capture hook. Returns a function that returns
 * the last error message (or null if no error occurred).
 */
function captureBrkError(machine) {
    let errorMsg = null;
    machine.processor.debugInstruction.add((addr) => {
        const brkv = machine.readword(0x0202);
        if (addr === brkv) {
            // The error block is at the address on the stack.
            // The MOS BRK handler reads the error number at (PC)+1
            // and the message at (PC)+2 onwards. But by the time
            // we're at BRKV, the PC that caused the BRK is saved
            // at &FD/&FE. The error block follows the BRK.
            const errPC = machine.readword(0xfd);
            const errNum = machine.readbyte(errPC);
            let msg = "";
            let i = 1;
            while (true) {
                const ch = machine.readbyte(errPC + i);
                if (ch === 0) break;
                msg += String.fromCharCode(ch);
                i++;
            }
            errorMsg = msg;
        }
        return false;
    });
    return () => errorMsg;
}

describe("alias table capacity", () => {
    let machine;

    beforeEach(async () => {
        machine = await bootWithXmos();
    });

    it("should fill the alias table and report overflow", async () => {
        // Table: &B165 to ~&BDFF = 3226 bytes.
        // Entry: name(2) + null(1) + expansion(230) + CR(1) = 234 bytes.
        // 3226 / 234 = 13.8 → 14 entries should fit, 15th overflows.
        const expansion = "X".repeat(230);
        const getError = captureBrkError(machine);

        for (let i = 0; i < 16; i++) {
            await runCommand(machine, `*ALIAS A${i.toString(16).toUpperCase()} ${expansion}`);
            if (getError()) break;
        }

        expect(getError()).toBe("No room for alias");
    });

    it("aliases before the overflow should all be listed", async () => {
        const expansion = "X".repeat(230);
        const getError = captureBrkError(machine);

        let addedCount = 0;
        for (let i = 0; i < 16; i++) {
            await runCommand(machine, `*ALIAS A${i.toString(16).toUpperCase()} ${expansion}`);
            if (getError()) break;
            addedCount++;
        }

        // All aliases added before the error should be in the listing
        const listing = await runCommand(machine, "*ALIASES");
        expect(listing).toContain("A0 = ");
        expect(listing).toContain("XXXXXXXXXX");
        expect(addedCount).toBeGreaterThan(10);
        expect(addedCount).toBeLessThan(16);
    });

    it("*ALICLR should free the entire table", async () => {
        // Fill with several aliases
        for (let i = 0; i < 5; i++) {
            await runCommand(machine, `*ALIAS F${i} *CAT`);
        }
        await runCommand(machine, "*ALICLR");

        // Should be able to add a large alias now
        const bigExpansion = "Y".repeat(200);
        await runCommand(machine, `*ALIAS BIG ${bigExpansion}`);
        const listing = await runCommand(machine, "*ALIASES");
        expect(listing).toContain("BIG = " + bigExpansion);
        expect(listing).not.toContain("F0");
    });
});

describe("alias expansion buffer", () => {
    let machine;

    beforeEach(async () => {
        machine = await bootWithXmos();
    });

    it("should expand a long alias with parameters", async () => {
        await runCommand(machine, "*ALIAS CP *COPY %0 %1 %2");
        const output = await runCommand(machine, "*CP Src Dst Opt");
        expect(output).toContain("*COPY Src Dst Opt");
    });

    it("should handle a long expansion text", async () => {
        const longCmd = "*" + "Z".repeat(80);
        await runCommand(machine, `*ALIAS LONG ${longCmd}`);
        const output = await runCommand(machine, "*LONG");
        expect(output).toContain(longCmd);
    });
});

describe("input line limits", () => {
    it("should handle a long BASIC line", async () => {
        const machine = await bootWithXmos();
        const longLine = "10 REM " + "A".repeat(200);
        await runCommand(machine, longLine);
        const output = await runCommand(machine, "LIST");
        expect(output).toContain("REM");
        expect(output).toContain("AAAA");
    });
});

describe("*LVAR with many variables", () => {
    it("should list many variables of different types", async () => {
        const machine = await bootWithXmos();
        await runCommand(machine, "AA=1:BB=2:CC=3:DD=4:EE=5");
        await runCommand(machine, 'FF$="hello":GG$="world"');
        await runCommand(machine, "DIM HH(5)");
        const output = await runCommand(machine, "*LVAR");
        expect(output).toContain("AA");
        expect(output).toContain("EE");
        expect(output).toContain("FF$");
        expect(output).toContain("GG$");
        expect(output).toContain("HH(");
    });
});

describe("*DIS across page boundaries", () => {
    it("should disassemble across a page boundary", async () => {
        const machine = await bootWithXmos();
        const getOutput = captureOutput(machine);
        await machine.type("*DIS 80F0");
        machine.keyDown(32);
        await machine.runFor(20_000_000);
        machine.keyUp(32);
        const output = getOutput();
        expect(output).toContain("80F");
        expect(output).toContain("810");
    });
});

describe("*BAU with many split points", () => {
    it("should split a line with 5 colon-separated statements", async () => {
        const machine = await bootWithXmos();
        await runCommand(machine, "10 A=1:B=2:C=3:D=4:E=5");
        await runCommand(machine, "*BAU");
        const output = await runCommand(machine, "LIST");
        expect(output).toContain("A=1");
        expect(output).toContain("B=2");
        expect(output).toContain("C=3");
        expect(output).toContain("D=4");
        expect(output).toContain("E=5");
    });
});
