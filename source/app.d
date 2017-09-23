import std.stdio;
import gameboy;
import std.parallelism;
import std.getopt;

// mixin APP_ENTRY_POINT;

// extern (C) int UIAppMain(string[] args) {
//     // Set preferences for OpenGl context of the window
//     // Requesting 3.0 because we use glDrawPixels, which
//     //  is part of the fixed-function pipeline
//     Platform.instance.GLVersionMajor = 3;
//     Platform.instance.GLVersionMinor = 0;

//     Window window = Platform.instance.createWindow("DDMG", null);

//     window.mainWidget = (new Button()).text("Hello world!"d).margins(Rect(20, 20, 20, 20));

//     window.show();

//     auto t = task!startGB;
//     t.executeInNewThread();

//     return Platform.instance.enterMessageLoop();
// }

// void startGB() {
//     Gameboy g = new Gameboy();
//     g.run();
// }

void main(string[] args) {
    writeln("Starting emulator");

    string romName = "../opus5.gb";
    getopt(args, "rom", &romName);

    Gameboy g = new Gameboy(romName);
    g.run();
}