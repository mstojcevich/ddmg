module sound.sounds.noise;

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

    private int timerCount;

    private ubyte volume;

    /// Linear feedback shift register for generating pseudorandom bits
    private ushort lfsr = 0b111_1111_1111;

    /// Number of cycles since the last frequency update
    private int cycleAccum;

    /// Whether the channel is enabled
    private bool enable;

    private union {
        ubyte nr43;
        mixin(bitfields!(
            ubyte, "freqDiv",     3, // Frequency divisor
            bool,  "widthMode",   1,
            ubyte, "clockShift",  4,
        ));
    }

    /// Called every cpu cycle (4_194_304 times a second) to update. Returns the volume that should be played at this time.
    @safe ubyte tick() {
        // Update 1/4194304th of a second worth of audio

        // Move forward in the duty cycle if needed
        // TODO Probably change to precalculate period instead of each tick
        // because it could change too often based on frequency changes!!
        const period = divisor(freqDiv);
        this.cycleAccum++;
        while (cycleAccum >= period) {
            // Update the LFSR
            const x = (lfsr & 0b1) ^ ((lfsr & 0b10) >> 1);
            lfsr >>= 1;
            lfsr |= (x << (widthMode ? 9 : 10));

            this.cycleAccum -= period;
        }

        if (!enable) {
            return 0;
        }
        return ((lfsr & 0b1) > 0) ? 0 : volume;
    }

    /// Called each frame update (256Hz) w/ the current frame sequencer frame
    @safe void frameUpdate(ubyte frame)
    in { assert(frame >= 0 && frame <= 7); }
    body {
        if (frame == 7) {
            volume = evp.tick(volume);
        }
        if (frame % 2 == 0) {
            timerTick();
        }
    }

    /// Tick the timer as if 1/256th of a second has passed
    @safe private void timerTick() {
        if(counter && timerCount != 0) {
            immutable int newTimerCount = timerCount - 1;
            if(newTimerCount == 0) {
                enable = false;
            }
            timerCount = newTimerCount;
        }
    }

    @safe private void triggerEvent() {
        this.enable = true;

        // If the length counter is 0, it is set to 64
        if (this.timerCount == 0) {
            this.timerCount = 64;
        }

        // Frequency timer is reloaded
        this.cycleAccum = 0;
        
        evp.triggerEvent();
        this.volume = evp.defaultVolume;

        // If the channel's DAC is off, the channel will be
        // disabled again
        // if (dacOff) {
        //     enable = false;
        // }
    }

    /// Set one of the 5 channel registers
    @safe void writeRegister(ushort number, ubyte value) 
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
                this.nr43 = value;
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
            triggerEvent();
        }
    }

    /// Whether the channel should be enabled
    @safe bool enabled() {
        return enable;
    }

    /// Enable/disable the channel
    @safe void enabled(bool enabled) {
        // TODO we don't need this once the power control reg is properly implemented
        if (enabled) {
            triggerEvent();
        } else {
            enable = false;
        }
    }

    @safe private ubyte divisor(ubyte code) {
        switch (code) {
            case 0:
                return 8;
            case 1:
                return 16;
            case 2:
                return 32;
            case 3:
                return 48;
            case 4:
                return 64;
            case 5:
                return 80;
            case 6:
                return 96;
            case 7:
                return 112;
            default:
                return 16;
        }
    }

}