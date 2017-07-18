import derelict.glfw3.glfw3;
import std.stdio;
import std.exception;

// Flags for the JOYP register
enum JOYPFlag : ubyte
{
    UNUSED_1 = 0b10000000,
    UNUSED_2 = 0b01000000,
    BUTTON_MODE = 0b00100000,
    DIRECTION_MODE = 0b00010000,
    DOWN_OR_START = 0b00001000,
    UP_OR_SELECT = 0b00000100,
    LEFT_OR_B = 0b00000010,
    RIGHT_OR_A = 0b00000001
}

class Keypad {
    // Whether to use the directions
    private bool useDirections;

    // TODO figure out what the priority is if both button and direction are selected and if neither are selected
    // TODO handle the read only bits

    private GLFWwindow* window;

    this(GLFWwindow* w) {
        this.window = w;
        
        glfwSetKeyCallback(window, &keyCallback);
    }

    @safe bool isJOYPFlagSet(JOYPFlag flag) {
        return useDirections ? (joypDirections & flag) != 0 : (joypButtons & flag) != 0;
    }

    @safe const ubyte readJOYP() {
        return useDirections ? joypDirections : joypButtons;
    }

    @safe void writeJOYP(ubyte joyp) {
        // Since the buttons are read only, we only need to handle the directions part

        bool buttons = (joyp & JOYPFlag.BUTTON_MODE) != 0;
        bool directions = (joyp & JOYPFlag.DIRECTION_MODE) != 0;
        
        useDirections = directions;
    }
}

// Keep two copies of the current input, one for button selected, one for direction selected
// These need to be outside of the class file since they're set by a c callback
private ubyte joypButtons = JOYPFlag.BUTTON_MODE;
private ubyte joypDirections = JOYPFlag.DIRECTION_MODE;

private extern(C) void keyCallback(GLFWwindow* window, int key, int scancode, int action, int mods) nothrow {
    if(action == GLFW_PRESS) {
        switch(key) {
            case GLFW_KEY_Z:
                joypButtons |= JOYPFlag.RIGHT_OR_A;
                break;
            case GLFW_KEY_X:
                joypButtons |= JOYPFlag.LEFT_OR_B;
                break;
            case GLFW_KEY_TAB:
                joypButtons |= JOYPFlag.UP_OR_SELECT;
                break;
            case GLFW_KEY_ENTER:
                joypButtons |= JOYPFlag.DOWN_OR_START;
                break;
            case GLFW_KEY_LEFT:
                joypDirections |= JOYPFlag.LEFT_OR_B;
                break;
            case GLFW_KEY_RIGHT:
                joypDirections |= JOYPFlag.RIGHT_OR_A;
                break;
            case GLFW_KEY_UP:
                joypDirections |= JOYPFlag.UP_OR_SELECT;
                break;
            case GLFW_KEY_DOWN:
                joypDirections |= JOYPFlag.DOWN_OR_START;
                break;
            default:
                break;
        }
    } else if(action == GLFW_RELEASE) {
        switch(key) {
            case GLFW_KEY_Z:
                joypButtons &= ~JOYPFlag.RIGHT_OR_A;
                break;
            case GLFW_KEY_X:
                joypButtons &= ~JOYPFlag.LEFT_OR_B;
                break;
            case GLFW_KEY_TAB:
                joypButtons &= ~JOYPFlag.UP_OR_SELECT;
                break;
            case GLFW_KEY_ENTER:
                joypButtons &= ~JOYPFlag.DOWN_OR_START;
                break;
            case GLFW_KEY_LEFT:
                joypDirections &= ~JOYPFlag.LEFT_OR_B;
                break;
            case GLFW_KEY_RIGHT:
                joypDirections &= ~JOYPFlag.RIGHT_OR_A;
                break;
            case GLFW_KEY_UP:
                joypDirections &= ~JOYPFlag.UP_OR_SELECT;
                break;
            case GLFW_KEY_DOWN:
                joypDirections &= ~JOYPFlag.DOWN_OR_START;
                break;
            default:
                break;
        }
    }
}