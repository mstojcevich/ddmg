import core.stdc.stdlib;
import cpu;
import std.stdio;
import gameboy;
import mmu;
import std.algorithm.searching;
import std.ascii;
import std.parallelism;
import std.getopt;
import frontend;
import frontend.glfw;
import frontend.sdl;
import frontend.test;

private enum TestMode { none, blargg_serial, blargg_memory, mooneye }

string romName = "../opus5.gb";
TestMode testMode = TestMode.none;
long maxInstrs = 25_000_000;  // Max instructions to run a test rom for

@safe void main(string[] args) {
    writeln("Starting emulator");

    readArgs(args);

    if (testMode != TestMode.none) {
        runTest();
    } else {
        Frontend frontend = new GLFWFrontend();
        frontend.init();

        Gameboy g = new Gameboy(frontend, romName);
        g.run();
    }
}

@trusted private void runTest() {
    bool passed = false;
    string failReason = "Unexpected failure";

    TestFrontend frontend = new TestFrontend();
    frontend.init();

    Gameboy g = new Gameboy(frontend, romName);
    CPU cpu = g.getCPU();
    while(cpu.instructionCount < maxInstrs) {
        g.step();
        const ubyte opcode = cpu.curOpcode;

        // Mooneye tests indicate that exeution has finished by executing LD B,B
        if (opcode == 0x40 && testMode == TestMode.mooneye) {
            passed = true;
            break;
        }
    }

    string serialOut = frontend.getSerialOutput().toString();
    writefln("FINAL SERIAL OUTPUT: %s", serialOut);

    if (testMode == TestMode.blargg_serial) {
        passed = canFind(serialOut, "Passed");
        if(!passed) {
            failReason = "Didn't pass all tests";
        }
    } else if (testMode == TestMode.blargg_memory) {
        const(MMU) m = g.getMMU();
        ubyte testStatus = m.readByte(0xA000);

        if (m.readByte(0xA001) != 0xDE || m.readByte(0xA002) != 0xB0 || m.readByte(0xA003) != 0x61) {
            passed = false;
            failReason = "Incorrect signature data. Ended too early?";
        } else if (testStatus == 0x80) {
            passed = false;
            failReason = "Test was still running when output was checked.";
        } else {
            writefln("Final status code: %d", testStatus);

            string statusString = "";
            int addr = 0xA004;
            ubyte curChar = m.readByte(addr);
            while(curChar != 0 && isASCII(curChar)) {
                statusString ~= cast(char)(curChar);
                addr++;
                curChar = m.readByte(addr);
            }
            writefln("Final status string: %s", statusString);

            passed = testStatus == 0;
            if(!passed) {
                failReason = "Bad test status code.";
            }
        }
    } else if (testMode == TestMode.mooneye) {
        if(!passed) {
            failReason = "Magic breakpoint never executed";
        } else {
            // Mooneye tests set the registers to certain magic numbers on success
            passed = cpu.registers.b == 0x03 &&
                     cpu.registers.c == 0x05 &&
                     cpu.registers.d == 0x08 &&
                     cpu.registers.e == 0x0D &&
                     cpu.registers.h == 0x15 &&
                     cpu.registers.l == 0x22;
            if (!passed) {
                failReason = "Success value not found in registers";
            }
        }
    }
    
    if (passed) {
        writeln("PASSED!");
    } else {
        stderr.writefln("FAILED: %s", failReason);
        exit(1);
    }
}

@trusted void readArgs(string[] args) {
    getopt(args,
        "rom", &romName,
        "testMode", &testMode,
        "testMaxInstrs", &maxInstrs);
}
