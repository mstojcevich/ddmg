module frontend.glfw;

import frontend;
import frontend.dummy.sound;
import frontend.glfw.display;
import frontend.glfw.keypad;
import graphics.display;
import serial;
import sound.frontend;
import keypad;

/// Frontend implemented with GLFW
class GLFWFrontend : Frontend {

    private GLFWDisplay display;
    private GLFWKeypad keypad;
    private DummySound sound;
    private SerialIO serial;

    @safe override void init() {
        this.display = new GLFWDisplay();
        this.keypad = new GLFWKeypad(display.glfwWindow);
        this.sound = new DummySound();
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