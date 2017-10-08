module frontend.sdl;

import derelict.sdl2.sdl;
import frontend;
import frontend.sdl.display;
import frontend.sdl.keypad;
import graphics.display;
import keypad;
import std.stdio;

/// Frontend implementation that does nothing
class SDLFrontend : Frontend {

    private SDLDisplay display;
    private SDLKeypad keypad;
    private bool shouldQuit;

    @trusted override void init() {
        DerelictSDL2.load();

        SDL_Init(SDL_INIT_VIDEO);

        this.display = new SDLDisplay();
        this.keypad = new SDLKeypad();
    }

    @trusted ~this() {
        SDL_Quit();
    }

    @safe override Display getDisplay() {
        return display;
    }

    @safe override KeypadFrontend getKeypad() {
        return keypad;
    }

    @safe override bool shouldProgramTerminate() {
        return shouldQuit;
    }

    @trusted override void update() {
        SDL_Event event;
        SDL_PollEvent(&event);
        if(event.type == SDL_QUIT) {
            shouldQuit = true;
        } else if(event.type == SDL_KEYDOWN) {
            keypad.keyDown(event.key.keysym.sym);
        } else if(event.type == SDL_KEYUP) {
            keypad.keyUp(event.key.keysym.sym);
        }
    }

}