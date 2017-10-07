import std.stdio;
import gameboy;
import std.parallelism;
import std.getopt;
import frontend;
import frontend.glfw;

string romName = "../opus5.gb";

@safe void main(string[] args) {
    writeln("Starting emulator");

    readRomName(args);

    Frontend frontend = new GLFWFrontend();
    frontend.init();

    Gameboy g = new Gameboy(frontend, romName);
    g.run();
}

@trusted void readRomName(string[] args) {
    getopt(args, "rom", &romName);
}
