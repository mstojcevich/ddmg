import core.stdc.stdlib;
import std.stdio;
import gameboy;
import std.algorithm.searching;
import std.parallelism;
import std.getopt;
import frontend;
import frontend.sdl;
import frontend.test;

private enum TestMode { none, blargg }

string romName = "../opus5.gb";
TestMode testMode = TestMode.none;
long maxInstrs = 25_000_000;  // Max instructions to run a test rom for

@safe void main(string[] args) {
    writeln("Starting emulator");

    readArgs(args);

    if (testMode == TestMode.blargg) {
        runBlarggTest();
    } else {
        Frontend frontend = new SDLFrontend();
        frontend.init();

        Gameboy g = new Gameboy(frontend, romName);
        g.run();
    }
}

@trusted private void runBlarggTest() {
    TestFrontend frontend = new TestFrontend();
    frontend.init();

    Gameboy g = new Gameboy(frontend, romName);
    g.run(maxInstrs);

    string serialOut = frontend.getSerialOutput().toString();
    writefln("FINAL SERIAL OUTPUT: %s", serialOut);

    if(!canFind(serialOut, "Passed")) {
        stderr.writeln("FAILED: Didn't pass all tests");
        exit(1);
    } else {
        writeln("PASSED!");
    }
}

@trusted void readArgs(string[] args) {
    getopt(args,
        "rom", &romName,
        "testMode", &testMode,
        "testMaxInstrs", &maxInstrs);
}
