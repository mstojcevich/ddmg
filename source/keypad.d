import derelict.glfw3.glfw3;
import std.stdio;
import std.exception;
import std.typecons;

// Flags for the JOYP register
enum JOYPFlag : ubyte
{
    BUTTON_MODE     = 1 << 5,
    DIRECTION_MODE  = 1 << 4,
    DOWN_OR_START   = 1 << 3,
    UP_OR_SELECT    = 1 << 2,
    LEFT_OR_B       = 1 << 1,
    RIGHT_OR_A      = 1 << 0
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
        return useDirections ? cast(bool) (joypDirections & flag) : cast(bool) (joypButtons & flag);
    }

    @safe const ubyte readJOYP() {
        return useDirections ? cast(ubyte) joypDirections : cast(ubyte) joypButtons;
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
private BitFlags!JOYPFlag joypButtons = JOYPFlag.BUTTON_MODE;
private BitFlags!JOYPFlag joypDirections = JOYPFlag.DIRECTION_MODE;

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