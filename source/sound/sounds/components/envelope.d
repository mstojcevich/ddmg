module sound.sounds.components.envelope;
import sound.consts;
import std.bitmanip;
import timing;

/**
 * The envelope component deals with fading the volume
 * up and down
 */
class Envelope {

    /// The number of frames remaining before a calculation
    private int timeRemaining;

    /// Hardware register for envelope control: This is NR12, NR22, and NR42
    private union {
        ubyte controlReg;
        mixin(bitfields!(
            ubyte,        "stepLength",   3, // Length of each envelope step: (stepLength / 64) seconds
            EnvelopeMode, "mode", 1, // Whether volume should decrease or increase on envelope
            ubyte,        "defaultValue", 4, // The default value for the envelope
        ));
    }

    @safe this() {
        stepLength = 3;
        mode = EnvelopeMode.REDUCE;
        defaultValue = MAX_VOLUME;
    }

    /**
     * Called every relevant frame (64 times a second).
     * @param volume The current volume (value from 0 to 15)
     * @return the new volume (value from 0 to 15) 
     */
    @safe ubyte tick(ubyte volume)
    in { assert(volume >= 0 && volume <= MAX_VOLUME); }
    out (newVolume) { assert(newVolume >= 0 && newVolume <= MAX_VOLUME); }
    body {
        timeRemaining--; // TODO does the first sequence decrement at the beginning or end?

        if (timeRemaining == 0) {
            volume = evpStep(volume);
            timeRemaining = stepLength;
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

    /**
     * Called during the "trigger event" when a channel is enabled
     */
    @safe void triggerEvent() {
        // Volume envelope timer is reloaded
        timeRemaining = stepLength;
    }

    /// Read the value of the envelope control register (used for NR12, NR22, and NR42)
    @safe ubyte readControlReg() const {
        return controlReg;
    }

    /// Write to the envelope control register (used for NR12, NR22, and NR42)
    @safe void writeControlReg(ubyte val) {
        this.controlReg = val;
    }

    /// Get the default volume to start with
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
