module frontend.glfw;

import derelict.sdl2.sdl;
import frontend;
import frontend.dummy.sound;
import frontend.glfw.display;
import frontend.glfw.keypad;
import frontend.sdl.sound;
import graphics.display;
import serial;
import sound.frontend;
import keypad;

/// Frontend implemented with GLFW
class GLFWFrontend : Frontend {

    private GLFWDisplay display;
    private GLFWKeypad keypad;
    private SDLSound sound;
    private SerialIO serial;

    @trusted override void init() {
        // We use SDL for sound for now
        DerelictSDL2.load();
        SDL_Init(SDL_INIT_AUDIO);

        this.display = new GLFWDisplay();
        this.keypad = new GLFWKeypad(display.glfwWindow);
        this.sound = new SDLSound();
        this.serial = new StandardSerialIO();
    }

    @safe override Display getDisplay() {
        return display;
    }

    @safe override KeypadFrontend getKeypad() {
        return keypad;
    }

    @safe override SoundFrontend getSound() {
        return sound;
    }

    @safe override SerialIO getSerial() {
        return serial;
    }

    @safe override bool shouldProgramTerminate() {
        return display.shouldProgramTerminate();
    }

    @safe override void update() {}

}