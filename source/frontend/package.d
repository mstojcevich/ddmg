module frontend;

import graphics.display;
import keypad;
import serial;
import sound;

interface Frontend {
    
    @safe void init();

    @safe Display getDisplay();

    @safe KeypadFrontend getKeypad();

    @safe SoundFrontend getSound();

    @safe bool shouldProgramTerminate();

    @safe void update();

    @safe SerialIO getSerial();

}