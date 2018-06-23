module frontend.test;

import frontend.dummy;
import serial;
import std.outbuffer;

/// Frontend with useful utilities for automated test roms
class TestFrontend : DummyFrontend {

    private TestSerial serial;

    /// Create a new TestFrontend with default options
    @safe override void init() {
        super.init();
        this.serial = new TestSerial();
    }

    @safe override SerialIO getSerial() {
        return this.serial;
    }

    @safe OutBuffer getSerialOutput() {
        return this.serial.outputBuffer;
    }

}

/// Serial IO with a programatically-readable output
class TestSerial : SerialIO {

    private OutBuffer output = new OutBuffer();

    /// Get the OutputBuffer containing the output from the serial port
    @safe @property OutBuffer outputBuffer() {
        return this.output;
    }

    @safe override void write(ubyte data) {
        output.write(data);
    }

    @safe override ubyte read() { return 0; }

}
