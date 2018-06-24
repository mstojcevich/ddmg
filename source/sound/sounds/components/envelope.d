module sound.sounds.components.envelope;
import sound.consts;
import std.bitmanip;
import timing;

/// The amount of CPU cycles before envelope is updated
private const CYCLES_PER_ENVELOPE = DDMG_TICKS_HZ / 64; // Updated 64 times a second

/**
 * The envelope component deals with fading the volume
 * up and down
 */
class Envelope {

    /// The number of cycles since the last envelope update
    private int cycleAccum;

    /// Hardware register for envelope control: This is NR12, NR22, and NR42
    private union {
        ubyte controlReg;
        mixin(bitfields!(
            ubyte,        "stepLength",   3, // Length of each envelope step: (stepLength / 64) seconds
            EnvelopeMode, "mode", 1, // Whether volume should decrease or increase on envelope
            ubyte,        "defaultValue", 4, // The default value for the envelope
        ));
    }

    /**
     * Called every cpu cycle (4_194_304 times a second) to update.
     * @param volume The current volume (value from 0 to 15)
     * @return the new volume (value from 0 to 15) 
     */
    @safe ubyte tick(ubyte volume)
    in { assert(volume >= 0 && volume <= MAX_VOLUME); }
    out (newVolume) { assert(newVolume >= 0 && newVolume <= MAX_VOLUME); }
    body {
        cycleAccum++;

        const cyclesPerStep = CYCLES_PER_ENVELOPE * stepLength;
        if(cycleAccum > cyclesPerStep) {
            cycleAccum -= cyclesPerStep;
            volume = evpStep(volume);
        }

        return volume;
    }

    @safe private ubyte evpStep(ubyte volume) 
    in { assert(volume >= 0 && volume <= MAX_VOLUME); }
    out (newVolume) { assert(newVolume >= 0 && newVolume <= MAX_VOLUME); }
    body {
        if(stepLength == 0) {
            return volume;
        }

        if(volume == 0 && mode == EnvelopeMode.REDUCE) {
            return volume;
        }
        if(volume == MAX_VOLUME && mode == EnvelopeMode.AMPLIFY) {
            return volume;
        }

        volume += mode == EnvelopeMode.AMPLIFY ? 1 : -1;
        return volume;
    }

    /// Read the value of the envelope control register (used for NR12, NR22, and NR42)
    @safe ubyte readControlReg() const {
        return controlReg;
    }

    /// Write to the envelope control register (used for NR12, NR22, and NR42)
    @safe void writeControlReg(ubyte val) {
        this.controlReg = val;
    }

    @safe @property ubyte defaultVolume()
    out (vol) { assert(vol <= MAX_VOLUME); }
    body {
        return defaultValue;
    }

}

private enum EnvelopeMode : bool {
    REDUCE = false,
    AMPLIFY = true
}
