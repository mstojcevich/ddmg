module frontend.glfw;

import frontend;
import frontend.glfw.display;
import frontend.glfw.keypad;
import graphics.display;
import keypad;

/// Frontend implemented with GLFW
class GLFWFrontend : Frontend {

    private GLFWDisplay display;
    private GLFWKeypad keypad;

    @safe override void init() {
        this.display = new GLFWDisplay();
        this.keypad = new GLFWKeypad(display.glfwWindow);
    }

    @safe override Display getDisplay() {
        return display;
    }

    @safe override KeypadFrontend getKeypad() {
        return keypad;
    }

    @safe override bool shouldProgramTerminate() {
        return display.shouldProgramTerminate();
    }

}