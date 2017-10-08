module frontend.dummy;

import frontend;
import frontend.dummy.display;
import frontend.dummy.keypad;
import graphics.display;
import keypad;

/// Frontend implementation that does nothing
class DummyFrontend : Frontend {

    // TODO way to set a terminate condition

    private Display display;
    private KeypadFrontend keypad;

    @safe override void init() {
        this.display = new DummyDisplay();
        this.keypad = new DummyKeypad();
    }

    @safe override Display getDisplay() {
        return display;
    }

    @safe override KeypadFrontend getKeypad() {
        return keypad;
    }

    @safe override bool shouldProgramTerminate() {
        return false;
    }

    @safe override void update() {}

}