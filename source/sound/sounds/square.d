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
        bool,  "initialize",  1, // Setting this to 1 restarts the sound
    ));
}

/// The amount of CPU cycles before the timer is updates
const CYCLES_PER_TIMER    = DDMG_TICKS_HZ / 256; // Updated 256 times a second

// TODO some documentation mentions timers getting "reloaded w/ period"
// does that mean that if the period gets changed midway that they'll restart?

/// The sound1/sound2 gameboy sound. Square wave with envelope and optional sweep.
public class SquareSound {

    /// Whether sound1 is enabled
    private bool enable;

    /// Whether the dac is off
    private bool dacOff; // TODO is the sound2 DAC off by default?

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

    /// The amount of timer cycles (1/256th of a second) remaining on the timer
    private int timerCount;

    /// Whether this square channel has sweep support (sound1 does, sound2 does not)
    private bool hasSweep;

    /// Current frame sequencer frame
    private ubyte frame;

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
        // Update 1/4194304th of a second worth of audio

        // Move forward in the duty cycle if needed
        // TODO Probably change to precalculate period instead of each tick
        // because it could change too often based on frequency changes!!
        const period = (2048 - frequency) * 4;
        this.cycleAccum++;
        while (cycleAccum >= period) {
            this.dutyLocation = (dutyLocation + 1) % 8;
            this.cycleAccum -= period;
        }

        immutable ubyte curAmplitude = dutyCycle[dutyLocation] ? volume : 0;
        
        if(!enable) {
            return 0;
        }

        return curAmplitude;
    }

    /// Called each frame update (256Hz) w/ the current frame sequencer frame
    @safe void frameUpdate(ubyte frame)
    in { assert(frame >= 0 && frame <= 7); }
    body {
        if (frame == 2 || frame == 6) {
            freqUpdate();
        }
        if (frame % 2 == 0) {
            timerTick();
        }
        if (frame == 7) {
            volume = evp.tick(volume);
        }
    }

    @safe private void freqUpdate() {
        // Do one tick's worth of frequency update 

        if(hasSweep) {
            int newFreq = sweep.tick(frequency);
            if(newFreq > MAX_FREQUENCY) { // TODO verify that overflow down doesn't result in channel disable
                enable = false;
            } else if (newFreq >= 0 && sweep.effective) { 
                frequency = newFreq;

                // Update the registers with the newly calculated frequency
                lowerFreq = frequency & 0xFF;
                nr14.higherFreq = cast(ubyte)(frequency >> 8);

                // This seems a bit odd, but the overflow check happens
                // again on the new value
                newFreq = sweep.sweepCalculation(frequency);
                if(newFreq > MAX_FREQUENCY) {
                    enable = false;
                }
            }
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
        if (!hasSweep) {
            frequency &= 0b111_0000_0000;
            frequency |= data;
        }
    }

    /// Set the content of the NR14 register
    @safe void setNR14(ubyte data) {
        nr14.data = data;

        if(nr14.initialize) {
            triggerEvent();
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

        // Write frequency to the shadow register
        this.frequency = (nr14.higherFreq << 8) | lowerFreq;

        sweep.triggerEvent();

        // This seems a bit odd, but the calculation and overflow check happens
        // I THINK the resulting frequency is just thrown away.
        if (hasSweep && sweep.effective) {
            const newFreq = sweep.sweepCalculation(frequency);
            if(newFreq > MAX_FREQUENCY) {
                enable = false;
            }
        }

        // If the channel's DAC is off, the channel will be
        // disabled again
        if (dacOff) {
            enable = false;
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

    /// Set one of the 5 channel registers
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

                this.dacOff = (value & 0b11111000) == 0;
                if(this.dacOff) {
                    enable = false;
                }
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