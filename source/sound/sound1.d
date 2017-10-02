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

// TODO verify
immutable bool[8][4] dutyCycles = [
    [false, false, false, true, false, false, false], // 12.5%
    [false, false, true, true, false, false, false, false], // 25%
    [false, false, true, true, true, true, false, false], // 50%
    [true, true, false, false, true, true, true, true], // 75%
];

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

    private int frequency; // Frequency data as defined by NR13 and NR14
    private int realFrequency; // Frequency in Hz

    // 2048 is the amount of precision we need for the highest frequency. Each unit is 1048576hz
    private ushort[2048] outBuffer; // The buffer of sound data to output

    private bool[8] dutyCycle = dutyCycles[0];

    private ushort volume = 65535;

    /// The current location in the duty cycle
    private int dutyLocation;

    // Called 512 times a second to update. Returns the samples for the time.
    ushort[2048] tick() {
        // Update 1/512th a second worth of audio

        immutable ushort unitsPerDuty = cast(ushort)(8 * (frequency / 512));
        
        ushort curAmplitude = dutyCycle[dutyLocation] ? volume : 0;
        for(int i = 0; i < 2048; i++) {
            outBuffer[i] = curAmplitude;

            if(i % unitsPerDuty == 0) {
                dutyLocation = (dutyLocation + 1) % 8;
                curAmplitude = dutyCycle[dutyLocation] ? volume : 0;
            }
        }
        
        return outBuffer;
    }

    /// Tick the sweep as if 1/128th of a second has occurred
    void sweepTick() {

    }

    /// Tick the envelope as if 1/64th of a second has occurred
    void envelopeTick() {
        
    }

    /// Set the lower frequency data (NR13)
    void setLowerFreq(ubyte data) {
        frequency = (frequency & 0xFFFFFF00) | data;
        recalcFrequency();
    }

    /// Set the content of the NR14 register
    void setNR14(ubyte data) {
        nr14.data = data;
        frequency = (frequency & 0xFF) | (nr14.higherFreq << 8);
        recalcFrequency();
    }

    /// Calculate the real frequency from the frequency data
    private void recalcFrequency() {
        realFrequency = 4_194_304 / (4 * 4 * 2 * (2048 * frequency));
    }

}