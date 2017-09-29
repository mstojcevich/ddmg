import std.stdio;
import gameboy;
import std.parallelism;
import std.getopt;

void main(string[] args) {
    writeln("Starting emulator");

    string romName = "../opus5.gb";
    getopt(args, "rom", &romName);

    Gameboy g = new Gameboy(romName);
    g.run();
}
