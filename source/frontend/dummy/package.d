module frontend.dummy;

import frontend;
import frontend.dummy.display;
import frontend.dummy.keypad;
import frontend.dummy.sound;
import graphics.display;
import keypad;
import sound.frontend;

/// Frontend implementation that does nothing
class DummyFrontend : Frontend {

    // TODO way to set a terminate condition

    private Display display;
    private KeypadFrontend keypad;
    private SoundFrontend sound;

    @safe override void init() {
        this.display = new DummyDisplay();
        this.keypad = new DummyKeypad();
        this.sound = new DummySound();
    }

    @safe override Display getDisplay() {
        return display;
    }

    @safe override KeypadFrontend getKeypad() {
        return keypad;
    }

    @safe SoundFrontend getSound() {
        return sound;
    }

    @safe override bool shouldProgramTerminate() {
        return false;
    }

    @safe override void update() {}

}