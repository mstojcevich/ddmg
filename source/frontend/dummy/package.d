module frontend.dummy;

import frontend;
import frontend.dummy.display;
import frontend.dummy.keypad;
import frontend.dummy.serial;
import frontend.dummy.sound;
import graphics.display;
import keypad;
import serial;
import sound.frontend;

/// Frontend implementation that does nothing
class DummyFrontend : Frontend {

    // TODO way to set a terminate condition

    private Display display;
    private KeypadFrontend keypad;
    private SoundFrontend sound;
    private SerialIO serial;

    @safe override void init() {
        this.display = new DummyDisplay();
        this.keypad = new DummyKeypad();
        this.sound = new DummySound();
        this.serial = new DummySerial();
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

    @safe override SerialIO getSerial() {
        return this.serial;
    }

    @safe override bool shouldProgramTerminate() {
        return false;
    }

    @safe override void update() {}

}