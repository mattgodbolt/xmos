import { describe, it, expect } from "vitest";
import { TestMachine } from "jsbeeb/tests/test-machine.js";
import { setNodeBasePath } from "jsbeeb/src/utils.js";
import * as fdc from "jsbeeb/src/fdc.js";
import * as fs from "fs";
import * as path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const jsbeebBase = path.join(__dirname, "..", "node_modules", "jsbeeb");
setNodeBasePath(jsbeebBase);

async function bootWithXmos() {
    const machine = new TestMachine("Master");
    await machine.initialise();

    // Load disc directly
    const ssdPath = path.join(__dirname, "..", "original.ssd");
    const data = fs.readFileSync(ssdPath);
    machine.processor.fdc.loadDisc(0, fdc.discFor(machine.processor.fdc, "", data));

    await machine.runUntilInput();
    await machine.type("*SRLOAD XMOS 8000 7Q");
    await machine.runUntilInput();

    // Soft reset to make MOS recognise the ROM
    machine.processor.reset(false);
    await machine.runUntilInput();
    return machine;
}

function captureOutput(machine) {
    let output = "";
    machine.captureText((elem) => (output += elem.text));
    return () => output;
}

describe("*HELP XMOS", () => {
    it("should list all XMOS commands", async () => {
        const machine = await bootWithXmos();
        const getOutput = captureOutput(machine);
        await machine.type("*HELP XMOS");
        // Give it plenty of time to process and return
        await machine.runFor(4 * 1000 * 1000);

        const output = getOutput();
        console.log("Captured:", JSON.stringify(output.substring(0, 200)));
        expect(output).toContain("MOS Extension commands:");
        expect(output).toContain("ALIAS");
        expect(output).toContain("XON");
    });
});
