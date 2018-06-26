module sound.sounds.square;

import sound.consts;
import sound.sounds.components;
import std.algorithm.comparison;
import std.bitmanip;
import std.stdio;
import timing;

// Representation of the NR11 register
private union NR11 {
    ubyte data;
    mixin(bitfields!(
        ubyte,     "soundLength", 6, // The length of the sound: ((64 - soundLength) / 256) seconds
        DutyCycle, "dutyCycle",   2 // The waveform duty cycle
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

/// The amount of CPU cycles before the timer is updates
const CYCLES_PER_TIMER    = DDMG_TICKS_HZ / 256; // Updated 256 times a second

// TODO what happens when the different registers are read? Do they return the last written, 00, FF, or the actual value??

/// The sound1/sound2 gameboy sound. Square wave with envelope and optional sweep.
public class SquareSound {

    /// Whether sound1 is enabled
    private bool enable;

    // TODO I don't like how the registers are dealt with here.
    // Maybe make an anonymous struct for "state" and then have a bunch of anonymous unions.
    private NR11 nr11;
    private ubyte lowerFreq; // Low bits of frequency
    private NR14 nr14;

    private Envelope evp = new Envelope();
    private Sweep sweep = new Sweep();

    /// Internal effective frequency
    private int frequency;

    private bool[8] dutyCycle = dutyCycles[2];

    /// Number from 0-15 representing volume
    private ubyte volume = MAX_VOLUME;

    /// The current location in the duty cycle
    private int dutyLocation;

    /// Counts how many cpu cycles have occurred since the last bit change in the waveform
    private int cycleAccum;

    /// The amount of cpu cycles since the last timer update
    private int timerAccum;

    /// The amount of timer cycles (1/256th of a second) remaining on the timer
    private int timerCount;

    /// Whether this square channel has sweep support (sound1 does, sound2 does not)
    private bool hasSweep;

    /**
     * @param hasSweep Whether this square voice has a sweep module
     * @param defaultDuty Default duty cycle to use
     */
    @safe this(bool hasSweep, DutyCycle defaultDuty) {
        this.nr11.dutyCycle = defaultDuty;
        this.hasSweep = hasSweep;
    }

    // Called every cpu cycle (4_194_304 times a second) to update. Returns the volume that should be played at this time.
    @safe ubyte tick() {
        // Update the envelope/sweep
        volume = evp.tick(volume);

        freqUpdate();

        timerAccum++;
        if(timerAccum > CYCLES_PER_TIMER) {
            timerTick();
            timerAccum = 0;
        }

        // Update 1/4194304th of a second worth of audio

        const timerPeriod = (2048 - frequency) * 4;
        // switch which bit in the duty cycle we use each passing timerPeriod
        cycleAccum++;
        while (cycleAccum >= timerPeriod) {
            dutyLocation = (dutyLocation + 1) % 8;
            cycleAccum -= timerPeriod;
        }

        immutable ubyte curAmplitude = dutyCycle[dutyLocation] ? volume : 0;
        
        if(!enable) {
            return 0;
        }

        return curAmplitude;
    }

    @safe private void freqUpdate() {
        // Do one tick's worth of frequency update

        if(hasSweep) {
            int newFreq = sweep.tick(frequency);
            if(newFreq > MAX_FREQUENCY) {
                enable = false;
            }
            if(sweep.effective) {
                frequency = newFreq & 0b1111_1111_111;

                // Update the registers with the newly calculated frequency
                lowerFreq = frequency & 0b11;
                nr14.higherFreq = cast(ubyte)(frequency >> 8);

                // This seems a bit odd, but the overflow check happens
                // again on the new value
                newFreq = sweep.sweepCalculation(frequency);
                if(newFreq > MAX_FREQUENCY) {
                    enable = false;
                }
            }
        }
        if(!sweep.effective || !hasSweep) {
            frequency = (nr14.higherFreq << 8) | lowerFreq;
        }
    }

    /// Tick the timer as if 1/256th of a second has passed
    @safe private void timerTick() {
        if(nr14.counter && timerCount != 0) {
            immutable int newTimerCount = timerCount - 1;
            if(newTimerCount == 0) {
                enable = false;
            }
            timerCount = newTimerCount;
        }
    }
    
    @safe void setNR11(ubyte nr11) {
        this.nr11.data = nr11;
        this.timerCount = 64 - this.nr11.soundLength;
        this.dutyCycle = dutyCycles[this.nr11.dutyCycle];
    }

    /// Set the lower frequency data (NR13)
    @safe void setLowerFreq(ubyte data) {
        lowerFreq = data;
    }

    /// Set the content of the NR14 register
    @safe void setNR14(ubyte data) {
        nr14.data = data;

        if(nr14.initialize) {
            enable = true;
            if(timerCount == 0) {
                timerCount = 64;
            }
            cycleAccum = 0;
            volume = evp.defaultVolume;
            // TODO Square 1's sweep does several things

            // If the DAC power is 0 (controlled by NR12 volume), channel is diabled again
            if(volume == 0) {
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

    /// Whether sound1 should be enabled
    @safe bool enabled() {
        return enable;
    }

    /// Enable/disable sound1
    @safe void enabled(bool enabled) {
        this.enable = enabled;
        frequency = (nr14.higherFreq << 8) | lowerFreq;
    }

    /// Set one of the 4 sound1 registers
    @safe void setRegister(ushort number, ubyte value) 
    in {
        assert(number <= 4);
    }
    body {
        final switch (number) {
            case 0:
                sweep.writeControlReg(value);
                break;
            case 1:
                setNR11(value);
                break;
            case 2:
                evp.writeControlReg(value);
                break;
            case 3:
                setLowerFreq(value);
                break;
            case 4:
                setNR14(value);
                break;
        }
    }
    
    @safe ubyte readRegister(ushort number) const
    in {
        assert(number <= 4);
    }
    body {
        switch (number) {
            case 0: // NR10
                return hasSweep ? sweep.readControlReg() : 0xFF;
            case 1:
                return nr11.data | 0b00111111;
            case 2:
                return evp.readControlReg();
            case 4:
                return nr14.data | 0b10111111;
            default:
                writefln("Game tried to read write-only APU register %02X", number);
                return 0xFF;
        }
    }

}

enum DutyCycle : ubyte {
    PCT_12_5 = 0b00,   // 12.5%
    PCT_25   = 0b01,   // 25%
    PCT_50   = 0b10,   // 50%
    PCT_75   = 0b11    // 75%
}