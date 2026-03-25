import { describe, it, expect } from "vitest";
import { bootWithXmos, readMode7Screen, readMode7ScreenRich, captureOutput } from "./xmos-test-machine.js";

describe("*MEM — memory editor", () => {
    it("should display header with ADDR, HEX CODE, and ASCII labels", async () => {
        const machine = await bootWithXmos();
        await machine.type("*MEM 8000");
        await machine.runFor(8_000_000);

        const screen = readMode7Screen(machine);
        // Header is always at the top of screen memory
        expect(screen[0]).toContain("ADDR");
        expect(screen[0]).toContain("HEX CODE");
        expect(screen[0]).toContain("ASCII");
    });

    it("should colour-code the header in green", async () => {
        const machine = await bootWithXmos();
        await machine.type("*MEM 8000");
        await machine.runFor(8_000_000);

        const rich = readMode7ScreenRich(machine);
        // "ADDR" starts after the &82 (green) control code
        const addrD = rich[0].find((c) => c.ch === "D");
        expect(addrD.fg).toBe("green");
    });

    it("should show hex data somewhere on screen", async () => {
        const machine = await bootWithXmos();
        await machine.type("*MEM 8000");
        await machine.runFor(8_000_000);

        // The screen should contain hex addresses and byte values
        // Due to hardware scrolling, we search all rows
        const screen = readMode7Screen(machine);
        const allText = screen.join("\n");
        // MEM displays 8-byte rows with addresses — should have some hex digits
        expect(allText).toMatch(/[0-9A-F]{4}/);
    });

    it("should return to prompt after ESCAPE", async () => {
        const machine = await bootWithXmos();
        await machine.type("*MEM 8000");
        await machine.runFor(8_000_000);

        // Press ESCAPE to exit MEM
        machine.keyDown(27);
        await machine.runFor(200000);
        machine.keyUp(27);
        await machine.runFor(4_000_000);

        // Should be able to type a command again (back at prompt)
        const getOutput = captureOutput(machine);
        await machine.type("*HELP XMOS");
        machine.keyDown(16); // SHIFT for paging
        await machine.runFor(8_000_000);
        machine.keyUp(16);

        const output = getOutput();
        expect(output).toContain("MOS Extension commands:");
    });
});
