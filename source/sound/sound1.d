module sound.sound1;

import std.algorithm.comparison;
import std.bitmanip;
import timing;

/// The amount of CPU cycles before sweep is updated
private const CYCLES_PER_SWEEP    = DMG_CLOCKRATE_HZ / 128; // Updated 128 times a second
/// The amount of CPU cycles before envelope is updated
private const CYCLES_PER_ENVELOPE = DMG_CLOCKRATE_HZ / 64; // Updated 64 times a second
/// The amount of CPU cycles before the timer is updates
private const CYCLES_PER_TIMER    = DMG_CLOCKRATE_HZ / 256; // Updated 256 times a second

/// The maximum value possible for the envelope to set
private const MAX_VOLUME = 15;

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
        ubyte,     "stepLength", 3, // The time per sweep shift (in 128ths of a second)
        bool,  "",  1,
    ));
}

// Representation of the NR11 register
private union NR11 {
    ubyte data;
    mixin(bitfields!(
        ubyte,     "soundLength", 6, // The length of the sound: ((64 - soundLength) / 256) seconds
        DutyCycle, "dutyCycle",   2 // The waveform duty cycle
    ));
}

// Representation of the NR12 register
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

// TODO what happens when the different registers are read? Do they return the last written, 00, FF, or the actual value??

/// The sound1 gameboy sound. Square wave with sweep and envelope.
public class Sound1 {

    /// Whether sound1 is enabled
    private bool enable;

    private SweepControl sweepCtrl;
    private NR11 nr11;
    private EnvelopeControl envelopeCtrl;
    private ubyte lowerFreq; // Low bits of frequency
    private NR14 nr14;

    /// Frequency data as defined by NR13 and NR14
    private int frequency; 

    private bool[8] dutyCycle = dutyCycles[0];

    /// Number from 0-15 representing volume
    private ubyte volume = MAX_VOLUME;

    /// The current location in the duty cycle
    private int dutyLocation;

    /// The CPU cycles remaining on the current part of the duty cycle
    private int dutyCyclesRemaining;

    /// The amount of cpu cycles since the last sweep update
    private int sweepAccum;

    /// The amount of cpu cycles since the last envelope update
    private int envelopeAccum;

    /// The amount of cpu cycles since the last timer update
    private int timerAccum;

    /// The amount of timer cycles (1/256th of a second) remaining on the timer
    private int timerCount;

    // Called every cpu cycle (4_194_304 times a second) to update. Returns the volume that should be played at this time.
    @safe ubyte tick() {
        // Update the envelope/sweep
        if(envelopeAccum > CYCLES_PER_ENVELOPE * envelopeCtrl.stepLength) {
            envelopeTick();
            envelopeAccum = 0;
        }
        if(sweepAccum > CYCLES_PER_SWEEP * sweepCtrl.stepLength) {
            sweepTick();
            sweepAccum = 0;
        }
        if(timerAccum > CYCLES_PER_TIMER) {
            timerTick();
            timerAccum = 0;
        }

        // Update 1/4194304th of a second worth of audio
        
        if(dutyCyclesRemaining == 0) {
            dutyLocation = (dutyLocation + 1) % 8;
            resetRemainingDutyCycles();
        }

        immutable ubyte curAmplitude = dutyCycle[dutyLocation] ? volume : 0;

        dutyCyclesRemaining--;
        envelopeAccum++;
        sweepAccum++;
        
        if(!enable) {
            return 0;
        }

        return curAmplitude;
    }

    /// Tick the sweep when its period is up
    @safe void sweepTick() {
        if(sweepCtrl.stepLength == 0) {
            return;
        }

        // TODO better documentation here
        int freq = frequency >> sweepCtrl.sweepShift;
        if(sweepCtrl.sweepMode == SweepMode.SUBTRACTION) {
            freq = -freq;
        }

        immutable bool overflow = freq >= 2048; // Can't fit in the 11 bits of frequency data
        
        if(sweepCtrl.sweepShift != 0 && !overflow) {
            setFrequency(freq);
        }

        if(overflow) {
            enable = false;
        }
    }

    /// Tick the envelope when its period is up
    @safe void envelopeTick() {
        if(envelopeCtrl.stepLength == 0) {
            return;
        }

        if(volume == 0 && envelopeCtrl.envelopeMode == EnvelopeMode.REDUCE) {
            return;
        }
        if(volume == MAX_VOLUME && envelopeCtrl.envelopeMode == EnvelopeMode.AMPLIFY) {
            return;
        }

        volume += envelopeCtrl.envelopeMode == EnvelopeMode.AMPLIFY ? 1 : -1;
    }

    /// Tick the timer as if 1/256th of a second has passed
    @safe void timerTick() {
        if(nr14.counter && timerCount != 0) {
            immutable int newTimerCount = timerCount - 1;
            if(newTimerCount == 0) {
                enable = false;
            }
        }
    }
    
    @safe void setNR11(ubyte nr11) {
        this.nr11.data = nr11;
        this.timerCount = 64 - this.nr11.soundLength;
        this.dutyCycle = dutyCycles[this.nr11.dutyCycle];
    }

    /// Set the lower frequency data (NR13)
    @safe void setLowerFreq(ubyte data) {
        frequency = (frequency & 0xFFFFFF00) | data;
    }

    /// Set the content of the NR14 register
    @safe void setNR14(ubyte data) {
        nr14.data = data;
        frequency = (frequency & 0xFF) | (nr14.higherFreq << 8);

        if(nr14.initialize) {
            enable = true;
            if(timerCount == 0) {
                timerCount = 64;
            }
            resetRemainingDutyCycles();
            volume = envelopeCtrl.defaultValue;
            // TODO Square 1's sweep does several things

            // If the DAC power is 0 (controlled by NR12 volume), channel is diabled again
            if(envelopeCtrl.defaultValue == 0) {
                // TODO what if you want to envelope up? Do you have to start at 1?
                enable = false;
            }
        }
    }

    /// Set the frequency to the specified value
    @safe private void setFrequency(int frequency)
    in {
        assert(frequency < 2048);
    }
    body {
        frequency = min(frequency, 0);
        this.frequency = frequency;
        nr14.higherFreq = (frequency >> 8) & 0b111;
    }

    /// Reset the amount of cycles remaining for the current period of the duty cycles
    @safe private void resetRemainingDutyCycles() {
        // Calculate the period (in CPU cycles) of 1/8th of a duty cycle

        dutyCyclesRemaining = 2048 - frequency;
    }

    /// Whether sound1 should be enabled
    @safe bool enabled() {
        return enable;
    }

    /// Enable/disable sound1
    @safe void enabled(bool enabled) {
        this.enable = enabled;
    }

    /// Set one of the 4 sound1 registers
    @safe void setRegister(ushort number, ubyte value) 
    in {
        assert(number <= 4);
    }
    body {
        final switch(number) {
            case 0:
                sweepCtrl.data = value;
                break;
            case 1:
                setNR11(value);
                break;
            case 2:
                envelopeCtrl.data = value;
                break;
            case 3:
                setLowerFreq(value);
                break;
            case 4:
                setNR14(value);
                break;
        }
    }

    // TODO the frequency sweep has a shadow frequency so writing a
    // new frequency will get undone by the sweep

}