module frontend;

import graphics.display;
import keypad;

interface Frontend {
    
    @safe void init();

    @safe Display getDisplay();

    @safe KeypadFrontend getKeypad();

    @safe bool shouldProgramTerminate();

}