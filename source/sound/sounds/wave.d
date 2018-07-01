module sound.sounds.wave;

import std.bitmanip;
import std.stdio;

/// The sound3 gameboy sound. Programmable wave.
public class WaveSound {

    /// Internal enable flag
    private bool enable;

    /// NR30 register, whether channel DAC has power
    private bool dacPower;
    
    /// 256-NR31 register
    private ushort soundLength;
    private ushort soundLengthRemaining;

    /// Amount to shift the output volume
    private ubyte shiftAmt;

    /// Lower 8 bits of the 11-bit frequency
    private ubyte lowerFreq;

    /// Amount of time remaining on the current sample
    private int sampleTimer;

    /// Effective frequency
    private int frequency;

    private union {
        ubyte nr34;
        mixin(bitfields!(
            ubyte, "higherFreq",  3, // High bits of frequency
            ubyte, "",            3,
            bool,  "counter",     1, // If false, output continuously regardless of NR31's soundLength
            bool,  "initialize",  1, // Setting this to 1 restarts the sound
        ));
    }

    private ubyte[16] waveRam;

    /// Position in the wave RAM (sample #)
    private int position;

    /// Current sample from the wave RAM
    private ubyte sampleBuffer;

    /// Time remaining (in length update frames)
    private ushort lengthCounter;

    @safe this() {
        for (int i; i < waveRam.length; i++) {
            waveRam[i] = (i % 2 == 0) ? 0 : 0xFF;
        }
    }

    /// Called every cpu cycle (4_194_304 times a second) to update. Returns the volume that should be played at this time.
    @safe ubyte tick() {
        this.sampleTimer--;

        if (sampleTimer == 0) {
            position = (position + 1) % (waveRam.length * 2);
            sampleBuffer = waveRam[position >> 1];
            if (position % 2 == 0) {
                sampleBuffer >>= 4;
            }

            sampleBuffer &= 0xF;

            sampleTimer = (2048 - frequency) * 2;
        }

        return sampleBuffer >> shiftAmt;
    }

    /// Called each frame update (256Hz) w/ the current frame sequencer frame
    @safe void frameUpdate(ubyte frame)
    in { assert(frame >= 0 && frame <= 7); }
    body {
        if (frame % 2 == 0) {
            timerTick();
        }
    }

    /// Write one of the 5 channel registers
    @safe void writeRegister(ushort number, ubyte value) 
    in {
        assert(number <= 4);
    }
    body {
        final switch (number) {
            case 0:
                writePower(value);
                break;
            case 1:
                writeShortness(value);
                break;
            case 2:
                writeOutputLevel(value);
                break;
            case 3:
                lowerFreq = value;
                frequency = (frequency & 0b111_0000_0000) | lowerFreq;
                break;
            case 4:
                writeNR34(value);
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
            case 0:
                return readPower();
            case 1:
                return readShortness();
            case 2:
                return readOutputLevel();
            case 4:
                return readNR34();
            default:
                writefln("Game tried to read write-only APU register %02X", number);
                return 0xFF;
        }
    }

    /// Whether the channel should be enabled
    @safe @property bool enabled() const {
        return enable;
    }

    /// Enable/disable the channel
    @safe @property void enabled(bool val) {
        this.enable = val;
    }

    /// Write a byte to wave RAM
    @safe void writeWaveRAM(ubyte addr, ubyte data)
    in { assert(addr <= 15); }
    body {
        waveRam[addr] = data;
    }

    /// Read a byte from wave RAM
    @safe ubyte readWaveRAM(ubyte addr) const
    in { assert(addr <= 15); }
    body {
        return waveRam[addr];
    }

    /// Write to the DAC power register (NR30)
    @safe void writePower(ubyte power) {
        dacPower = (power & 0b1000_0000) > 0;
    }

    /// Read the DAC power register (NR30)
    @safe ubyte readPower() const {
        return (dacPower << 7) | 0b0111_1111;
    }

    /// Write the "length" (shortness) register (NR31)
    @safe void writeShortness(ubyte shortness) {
        soundLength = cast(ubyte)(256 - shortness);
        soundLengthRemaining = cast(ubyte)(256 - shortness);
    }

    /// Read the "length" (shortness) register (NR31)
    @safe ubyte readShortness() const {
        return cast(ubyte)(256 - soundLength);
    }

    /// Write the output level register (NR32)
    @safe void writeOutputLevel(ubyte level) {
        level >>= 5;
        if (level == 0) {
            shiftAmt = 4;
        } else {
            shiftAmt = cast(ubyte)(level - 1);
        }
    }

    /// Read the output level register (NR32)
    @safe ubyte readOutputLevel() const {
        return ((shiftAmt + 1) % 4) << 5;
    }

    /// Write to the NR34 register
    @safe void writeNR34(ubyte val) {
        this.nr34 = val;
        this.frequency = (frequency & 0xFF) | (higherFreq << 7);

        if (initialize) {
            // Reset the position of the current sample
            this.position = 0;
            // Note that the sample buffer isn't reloaded

            // Reset the length counter if finished
            if (this.lengthCounter == 0) {
                this.lengthCounter = 256;
            }

            // Frequency timer is reloaded
            this.sampleTimer = (2048 - frequency) * 4;
        }
    }

    /// Read from the NR34 register
    @safe ubyte readNR34() const {
        return nr34 | 0b1011_1111;
    }

    /// Tick the timer as if 1/256th of a second has passed
    @safe private void timerTick() {
        if(counter && soundLengthRemaining != 0) {
            immutable int newTimerCount = soundLengthRemaining - 1;
            if(newTimerCount == 0) {
                enable = false;
            }
            soundLengthRemaining = cast(ushort)(newTimerCount);
        }
    }

}
