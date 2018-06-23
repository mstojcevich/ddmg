module frontend.dummy.serial;

import serial;

/// SerialIO implementation that writes to nowhere and always reads 0
class DummySerial : SerialIO {
    @safe override void write(ubyte data) {}
    @safe override ubyte read() { return 0; }
}