module sound.sounds.components.sweep;

import sound.consts;
import std.bitmanip;
import timing;

/// The amount of CPU cycles before sweep is updated
private const CYCLES_PER_SWEEP = DDMG_TICKS_HZ / 256; // Updated 128 times a second

class Sweep {

    /// The number of cycles since the last sweep update
    private int cycleAccum;

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
     * Called every cpu cycle (4_194_304 times a second) to update.
     * @param frequency The current frequency (value of the 11 bit "shadow register")
     * @return the new frequency (value of the 11 bit "shadow register"). Note that
     *   the returned value may be greater than the max frequency: this is because overflow
     *   handling needs to be handled by the channel itself (it needs to turn itself off)!
     */
    @safe int tick(int frequency)
    in { assert(frequency >= 0 && frequency <= MAX_FREQUENCY); }
    out (outfreq) { assert(outfreq >= 0); }
    body {
        cycleAccum++;

        const cyclesPerStep = CYCLES_PER_SWEEP * stepLength;
        if(cycleAccum > cyclesPerStep) {
            cycleAccum -= cyclesPerStep;
            frequency = sweepCalculation(frequency);
        }

        return frequency;
    }

    /**
     * Do sweep calculation on a frequency, this should happen each
     * sweep period
     */
    @safe int sweepCalculation(int frequency)
    in { assert(frequency >= 0 && frequency <= MAX_FREQUENCY); }
    out (outfreq) { assert(outfreq >= 0); }
    body {
        if(active) {
            const freqChange = frequency >> shift;
            const newFreq = (mode == SweepMode.ADDITION) 
                ? frequency + freqChange 
                : frequency - freqChange;
            return newFreq;       
        } else {
            return frequency;
        }
    }

    /**
     * Whether sweeping is currently active.
     * Note that this is different than effective.
     * This should be used to determine whether writes to
     * NR14 and NR14 change the real frequency.
     */
    @safe @property bool active() const {
        // The internal enabled flag is set if either the sweep period
        // or shift are non-zero, cleared otherwise
        return stepLength != 0 || shift != 0;
    }

    /**
     * This must be checked to determine whether the effective
     * frequency is able to be updated.
     * This is different than active because overflow checks
     * should still happen even if the sweep isn't effective.
     */
    @safe @property bool effective() const {
        return shift != 0;
    }

     /// Read the value of the sweep control register (used for NR10)
    @safe ubyte readControlReg() const {
        return controlReg;
    }

    /// Write to the envelope control register (used for NR10)
    @safe void writeControlReg(ubyte val) {
        this.controlReg = val;
    }

}

private enum SweepMode : bool {
    ADDITION = false,
    SUBTRACTION = true
}