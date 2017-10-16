module frontend.glfw;

import frontend;
import frontend.dummy.sound;
import frontend.glfw.display;
import frontend.glfw.keypad;
import graphics.display;
import sound.frontend;
import keypad;

/// Frontend implemented with GLFW
class GLFWFrontend : Frontend {

    private GLFWDisplay display;
    private GLFWKeypad keypad;
    private DummySound sound;

    @safe override void init() {
        this.display = new GLFWDisplay();
        this.keypad = new GLFWKeypad(display.glfwWindow);
        this.sound = new DummySound();
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

    @safe override bool shouldProgramTerminate() {
        return display.shouldProgramTerminate();
    }

    @safe override void update() {}

}