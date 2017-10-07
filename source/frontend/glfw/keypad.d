module frontend.glfw.keypad;

import derelict.glfw3.glfw3;
import keypad;

/// Keypad frontend implementation using GLFW
class GLFWKeypad : KeypadFrontend {

    private GLFWwindow* window;

    @trusted this(GLFWwindow* window) {
        if(window != null) {
            this.window = window;
            
            glfwSetKeyCallback(window, &keyCallback);
        }
    }

    @safe override void setCallback(keypressCallback cbk) {
        callback = cbk;
    }

}

private keypressCallback callback;

private extern(C) void keyCallback(GLFWwindow* window, int key, int scancode, int action, int mods) nothrow {
    try {
        if(action == GLFW_PRESS) {
            switch(key) {
                case GLFW_KEY_Z:
                    callback(true, GameboyKey.A);
                    break;
                case GLFW_KEY_X:
                    callback(true, GameboyKey.B);
                    break;
                case GLFW_KEY_TAB:
                    callback(true, GameboyKey.SELECT);
                    break;
                case GLFW_KEY_ENTER:
                    callback(true, GameboyKey.START);
                    break;
                case GLFW_KEY_LEFT:
                    callback(true, GameboyKey.LEFT);
                    break;
                case GLFW_KEY_RIGHT:
                    callback(true, GameboyKey.RIGHT);
                    break;
                case GLFW_KEY_UP:
                    callback(true, GameboyKey.UP);
                    break;
                case GLFW_KEY_DOWN:
                    callback(true, GameboyKey.DOWN);
                    break;
                default:
                    break;
            }
        } else if(action == GLFW_RELEASE) {
            switch(key) {
                case GLFW_KEY_Z:
                    callback(false, GameboyKey.A);
                    break;
                case GLFW_KEY_X:
                    callback(false, GameboyKey.B);
                    break;
                case GLFW_KEY_TAB:
                    callback(false, GameboyKey.SELECT);
                    break;
                case GLFW_KEY_ENTER:
                    callback(false, GameboyKey.START);
                    break;
                case GLFW_KEY_LEFT:
                    callback(false, GameboyKey.LEFT);
                    break;
                case GLFW_KEY_RIGHT:
                    callback(false, GameboyKey.RIGHT);
                    break;
                case GLFW_KEY_UP:
                    callback(false, GameboyKey.UP);
                    break;
                case GLFW_KEY_DOWN:
                    callback(false, GameboyKey.DOWN);
                    break;
                default:
                    break;
            }
        }
    } catch (Exception ex) {
    }
}