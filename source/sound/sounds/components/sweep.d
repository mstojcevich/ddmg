module sound.sounds.components.sweep;

import sound.consts;
import std.bitmanip;
import timing;

class Sweep {

    /// Internal enabled flag
    private bool enabled;

    /// Number of frames remaining before a calculation
    private int timeRemaining;

    // Hardware register for sweep control: This is NR10
    private union {
        ubyte controlReg;
        mixin(bitfields!(
            ubyte,     "shift", 3, // The frequency change with one shift
            SweepMode, "mode",  1, // Whether frequency should increase or decrease on sweep
            ubyte,     "stepLength", 3, // The time per sweep shift (in 128ths of a second)
            bool,  "",  1,
        ));
    }

    /**
     * Called every sweep update frame.
     * @param frequency The current frequency (value of the 11 bit "shadow register")
     * @return the new frequency (value of the 11 bit "shadow register"). Note that
     *   the returned value may be greater than the max frequency: this is because overflow
     *   handling needs to be handled by the channel itself (it needs to turn itself off)!
     */
    @safe int tick(int frequency)
    in { assert(frequency >= 0 && frequency <= MAX_FREQUENCY); }
    body {
        if (enabled) {
            timeRemaining--; // TODO does the first sequence decrement at the beginning or end?

            if (timeRemaining == 0) {
                if (stepLength != 0) {
                    frequency = sweepCalculation(frequency);
                }

                if (frequency <= MAX_FREQUENCY) {
                    timeRemaining = sweepTime;
                }
            }
        }

        return frequency;
    }

    /**
     * Called during the "trigger event" when a channel is enabled
     */
    @safe void triggerEvent() {
        // The internal enabled flag is set if either the sweep period or shift
        // are non-zero, cleared otherwise
        this.enabled = stepLength != 0 || shift != 0;

        // The sweep timer is reloaded
        this.timeRemaining = sweepTime;
    }

    /**
     * Do sweep calculation on a frequency, this should happen each
     * sweep period
     */
    @safe int sweepCalculation(int frequency)
    in { assert(frequency >= 0 && frequency <= MAX_FREQUENCY); }
    body {
        const freqChange = frequency >> shift;
        const newFreq = (mode == SweepMode.ADDITION) 
            ? frequency + freqChange 
            : frequency - freqChange;
        return newFreq;
    }

    /**
     * This must be checked to determine whether the effective frequency is able to be updated.
     * This determines whether the sweep frequency should be written back or thrown away.
     */
    @safe @property bool effective() const {
        // TODO verify that writeback always occurs in subtraction mode
        return shift != 0 || (mode == SweepMode.SUBTRACTION);
    }

     /// Read the value of the sweep control register (used for NR10)
    @safe ubyte readControlReg() const {
        return controlReg | 0b10000000; // First bit is unused
    }

    /// Write to the envelope control register (used for NR10)
    @safe void writeControlReg(ubyte val) {
        this.controlReg = val;
    }

    @safe @property private ubyte sweepTime() {
        return stepLength == 0 ? 8 : stepLength; 
    }

}

private enum SweepMode : bool {
    ADDITION = false,
    SUBTRACTION = true
}