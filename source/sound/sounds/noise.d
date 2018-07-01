module sound.sounds.noice;

import sound.sounds.components;
import std.bitmanip;
import std.stdio;

class NoiseSound {

    /// 256-NR31 register
    private ubyte soundLength;
    private ubyte soundLengthRemaining;

    /// Whether to use the length timer
    private bool counter;

    private Envelope evp = new Envelope();

    private ubyte timerCount;

    private ubyte volume;

    private union {
        ubyte nr43;
        mixin(bitfields!(
            ubyte, "freqDiv",     3, // Frequency divisor
            bool,  "widthMode",   1,
            ubyte, "clockShift",  4,
        ));
    }

    @safe ubyte tick() {
        return 0;
    }

    /// Called each frame update (256Hz) w/ the current frame sequencer frame
    @safe void frameUpdate(ubyte frame)
    in { assert(frame >= 0 && frame <= 7); }
    body {
        if (frame == 7) {
            volume = evp.tick(volume);
        }
    }

    /// Set one of the 5 channel registers
    @safe void setRegister(ushort number, ubyte value) 
    in {
        assert(number <= 4);
    }
    body {
        final switch (number) {
            case 0:
                break;
            case 1:
                // TODO unimplemented
                break;
            case 2:
                evp.writeControlReg(value);
                break;
            case 3:
                // setLowerFreq(value);
                break;
            case 4:
                writeNR44(value);
                break;
        }
    }

    /// Read one of the 5 channel registers
    @safe ubyte readRegister(ushort number) const
    in {
        assert(number <= 4);
    }
    body {
        switch (number) {
            case 1:
                // TODO unimplemented
                return 0xFF;
            case 2:
                return evp.readControlReg();
            case 4:
                return readNR44();
            default:
                writefln("Game tried to read write-only APU register %02X", number);
                return 0xFF;
        }
    }

    /// Write the "length" (shortness) register (NR31)
    @safe private void writeShortness(ubyte val) {
        this.timerCount = cast(ubyte)(64 - val);
    }

    /// Read the "length" (shortness) register (NR31)
    @safe private ubyte readShortness() const {
        return cast(ubyte)(64 - this.timerCount);
    }

    @safe private ubyte readNR44() const {
        return (counter << 6) | 0b1011_1111;
    }

    @safe private void writeNR44(ubyte val) {
        this.counter = (val & 0b0100_0000) > 0;

        const bool initialize = (val & 0b1000_0000) > 0;
        if (initialize) {
            evp.triggerEvent();
            // TODO trigger event
        }
    }

}