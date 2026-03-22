import { describe, it, expect } from "vitest";
import { bootWithXmos, readMode7Screen, typeText } from "./xmos-test-machine.js";

describe("*MEM — memory editor", () => {
    it("should display hex and ASCII at the given address", async () => {
        const machine = await bootWithXmos();
        await typeText(machine, "*MEM 8000");
        await machine.runFor(8_000_000);

        const screen = readMode7Screen(machine);
        const text = screen.join("\n");

        // Should show the address column
        expect(text).toContain("8000");
        // Should show the header
        expect(text).toContain("ADDR");
        expect(text).toContain("HEX CODE");
        expect(text).toContain("ASCII");
    });

    it("should show ROM header bytes at &8000", async () => {
        const machine = await bootWithXmos();
        await typeText(machine, "*MEM 8000");
        await machine.runFor(8_000_000);

        const screen = readMode7Screen(machine);
        const text = screen.join("\n");

        // &8003 is JMP &802B — bytes 4C 2B 80
        expect(text).toContain("4C");
    });

    it("should exit on ESCAPE and return to prompt", async () => {
        const machine = await bootWithXmos();
        await typeText(machine, "*MEM 8000");
        await machine.runFor(8_000_000);

        // Press ESCAPE to exit
        machine.processor.sysvia.keyDown(27); // ESCAPE
        await machine.runFor(200000);
        machine.processor.sysvia.keyUp(27);
        await machine.runFor(4_000_000);

        const screen = readMode7Screen(machine);
        const text = screen.join("\n");

        // Should be back at the BASIC prompt
        expect(text).toContain(">");
    });
});
