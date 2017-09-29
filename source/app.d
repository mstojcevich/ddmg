import std.stdio;
import gameboy;
import std.parallelism;
import std.getopt;

string romName = "../opus5.gb";

@safe void main(string[] args) {
    writeln("Starting emulator");

    readRomName(args);

    Gameboy g = new Gameboy(romName);
    g.run();
}

@trusted void readRomName(string[] args) {
    getopt(args, "rom", &romName);
}
