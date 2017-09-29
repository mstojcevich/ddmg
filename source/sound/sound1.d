module sound.sound1;

import std.bitmanip;

private enum SweepMode : bool {
    ADDITION = false,
    SUBTRACTION = true
}

private enum EnvelopeMode : bool {
    REDUCE = false,
    AMPLIFY = true
}

private enum DutyCycle : ubyte {
    PCT_12_5 = 0x00,   // 12.5%
    PCT_25   = 0x01,   // 25%
    PCT_50   = 0x10,   // 50%
    PCT_75   = 0x11    // 75%
}

// Representation of the NR10 register
private union SweepControl {
    ubyte data;
    mixin(bitfields!(
        ubyte,     "sweepShift", 3, // The frequency change with one shift
        SweepMode, "sweepMode",  1, // Whether frequency should increase or decrease on sweep
        ubyte,     "sweepTime",  3, // The time per sweep shift (in 128ths of a second)
        bool,  "",  1,
    ));
}

// Representation of the NR11 register
private union DutyControl {
    ubyte data;
    mixin(bitfields!(
        ubyte,     "soundLength", 6, // The length of the sound: ((64 - soundLength) / 256) seconds
        DutyCycle, "dutyCycle",   2 // The waveform duty cycle
    ));
}

// Representation of the NR10 register
private union EnvelopeControl {
    ubyte data;
    mixin(bitfields!(
        ubyte,        "stepLength",   3, // Length of each envelope step: (stepLength / 64) seconds
        EnvelopeMode, "envelopeMode", 1, // Whether volume should decrease or increase on envelope
        ubyte,        "defaultValue", 4, // The default value for the envelope
    ));
}

private union NR14 {
    ubyte data;
    mixin(bitfields!(
        ubyte, "higherFreq",  3, // High bits of frequency
        ubyte, "",            3,
        bool,  "counter",     1, // If false, output continuously regardless of NR11's soundLength
        bool,  "initialize",  1, // Settings this to 1 restarts sound
    ));
}

/// The sound1 gameboy sound. Square wave with sweep and envelope.
public class Sound1 {

    private SweepControl sweepCtrl;
    private DutyControl dutyCtrl;
    private EnvelopeControl envelopeCtrl;
    private ubyte lowerFreq; // Low bits of frequency
    private NR14 nr14;

    /// Tick the sweep as if 1/128th of a second has occurred
    void sweepTick() {

    }

    /// Tick the envelope as if 1/64th of a second has occurred
    void envelopeTick() {
        
    }

}