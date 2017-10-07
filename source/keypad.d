import std.stdio;
import std.exception;
import std.typecons;

import interrupt;

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

    private InterruptHandler iuptHandler;

    private KeypadFrontend frontend;

    // Keep two copies of the current input, one for button selected, one for direction selected
    // These need to be outside of the class file since they're set by a c callback
    private BitFlags!JOYPFlag joypButtons = JOYPFlag.BUTTON_MODE;
    private BitFlags!JOYPFlag joypDirections = JOYPFlag.DIRECTION_MODE;

    // Request for an interrupt fire
    private bool iupt;

    @trusted this(KeypadFrontend frontend, InterruptHandler iuptHandler) {
        this.iuptHandler = iuptHandler;

        this.frontend = frontend;
        this.frontend.setCallback(&kpCallback);
    }

    @safe bool isJOYPFlagSet(JOYPFlag flag) {
        return useDirections ? cast(bool) (joypDirections & flag) : cast(bool) (joypButtons & flag);
    }

    @safe const ubyte readJOYP() {
        return ~(useDirections ? cast(ubyte) joypDirections : cast(ubyte) joypButtons);
    }

    @safe void writeJOYP(ubyte joyp) {
        // Since the buttons are read only, we only need to handle the directions part
        
        bool buttons = (joyp & JOYPFlag.BUTTON_MODE) == 0;
        bool directions = (joyp & JOYPFlag.DIRECTION_MODE) == 0;
        
        useDirections = directions;
    }

    /**
     * Checks for the keypad interrupt and fires it if necessary
     */
    @safe void update() {
        if(iupt) {
            iuptHandler.fireInterrupt(Interrupts.JOYPAD_PRESS);
            iupt = false;
        }
    }

    @safe void kpCallback(bool pressed, GameboyKey key) {
        final switch(key) {
            case GameboyKey.A:
                if(pressed) {
                    joypButtons |= JOYPFlag.RIGHT_OR_A;
                    iupt = true;
                } else {
                    joypButtons &= ~JOYPFlag.RIGHT_OR_A;
                }
                break;
            case GameboyKey.B:
                if(pressed) {
                    joypButtons |= JOYPFlag.LEFT_OR_B;
                    iupt = true;
                } else {
                    joypButtons &= ~JOYPFlag.LEFT_OR_B;
                }
                break;
            case GameboyKey.SELECT:
                if(pressed) {
                    joypButtons |= JOYPFlag.UP_OR_SELECT;
                    iupt = true;
                } else {
                    joypButtons &= ~JOYPFlag.UP_OR_SELECT;
                }
                break;
            case GameboyKey.START:
                if(pressed) {
                    joypButtons |= JOYPFlag.DOWN_OR_START;
                    iupt = true;
                } else {
                    joypButtons &= ~JOYPFlag.DOWN_OR_START;
                }
                break;
            
            case GameboyKey.RIGHT:
                if(pressed) {
                    joypDirections |= JOYPFlag.RIGHT_OR_A;
                    iupt = true;
                } else {
                    joypDirections &= ~JOYPFlag.RIGHT_OR_A;
                }
                break;
            case GameboyKey.LEFT:
                if(pressed) {
                    joypDirections |= JOYPFlag.LEFT_OR_B;
                    iupt = true;
                } else {
                    joypDirections &= ~JOYPFlag.LEFT_OR_B;
                }
                break;
            case GameboyKey.UP:
                if(pressed) {
                    joypDirections |= JOYPFlag.UP_OR_SELECT;
                    iupt = true;
                } else {
                    joypDirections &= ~JOYPFlag.UP_OR_SELECT;
                }
                break;
            case GameboyKey.DOWN:
                if(pressed) {
                    joypDirections |= JOYPFlag.DOWN_OR_START;
                    iupt = true;
                } else {
                    joypDirections &= ~JOYPFlag.DOWN_OR_START;
                }
                break;
        }
    }

}

/// The collection of keys on a Gameboy
enum GameboyKey {
    A, B, SELECT, START, UP, DOWN, LEFT, RIGHT
}

alias keypressCallback = @safe void delegate(bool down, GameboyKey key);

/// A frontend implementation of the keypad
interface KeypadFrontend {
    /// Set the callback to run when a key is pressed
    @safe void setCallback(keypressCallback callback);
}
