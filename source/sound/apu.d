module sound.apu;

import sound.frontend;
import sound.sounds;
import std.bitmanip;
import std.stdio;
import timing;

// Memory mappings, inclusive
private const SOUND1_REGISTERS_BEGIN = 0x00;
private const SOUND1_REGISTERS_END   = 0x04;
private const SOUND2_REGISTERS_BEGIN = 0x05;
private const SOUND2_REGISTERS_END   = 0x09;
private const SOUND3_REGISTERS_BEGIN = 0x0A;
private const SOUND3_REGISTERS_END   = 0x0E;

private const TICKS_PER_FRAME = DDMG_TICKS_HZ / 512;  // Frames are clocked @ 512Hz

/// Sound processing unit for the Gameboy
class APU {

    private VolumeControlRegister volumes;
    private ChannelEnableRegister enabledChannels;
    private SoundEnableRegister enabledSounds;

    private SquareSound sound1;
    private SquareSound sound2;
    private WaveSound sound3;

    private SoundFrontend frontend;

    private int frameCycleAccum = 0;
    private ubyte frame = 0;

    @safe this(SoundFrontend frontend) {
        this.frontend = frontend;

        sound1 = new SquareSound(true, DutyCycle.PCT_50);
        sound2 = new SquareSound(false, DutyCycle.PCT_12_5);
        sound3 = new WaveSound();
    }

    /// Run every CPU cycle
    @safe void tick() {
        frameCycleAccum++;
        while (frameCycleAccum >= TICKS_PER_FRAME) {
            sound1.frameUpdate(frame);
            sound2.frameUpdate(frame);
            sound3.frameUpdate(frame);
            frame = (frame + 1) % 8;
            frameCycleAccum -= TICKS_PER_FRAME;
        }

        ubyte s1out = cast(ubyte)(sound1.tick() + sound2.tick() + sound3.tick());
        frontend.playAudio(cast(ubyte) (s1out * volumes.leftVol/7.0), cast(ubyte) (s1out * volumes.rightVol/7.0));

        enabledSounds.sound1Enable = sound1.enabled();
        enabledSounds.sound2Enable = sound2.enabled();
        enabledSounds.sound3Enable = sound3.enabled();
    }

    /**
     * Sets the value of an APU register
     *
     * @param number Number of the register to set. Relative to 0xFF10. Between 0x00 and 0x16.
     */
    @safe void setApuRegister(ushort number, ubyte value)
    in {
        assert(number <= 0x16);
    }
    body {
        if (number >= SOUND1_REGISTERS_BEGIN && number <= SOUND1_REGISTERS_END) {
            sound1.setRegister(cast(ubyte)(number - SOUND1_REGISTERS_BEGIN), value);
            return;
        }

        if (number >= SOUND2_REGISTERS_BEGIN && number <= SOUND2_REGISTERS_END) {
            sound2.setRegister(cast(ubyte)(number - SOUND2_REGISTERS_BEGIN), value);
            return;
        }

        if (number >= SOUND3_REGISTERS_BEGIN && number <= SOUND3_REGISTERS_BEGIN) {
            sound3.writeRegister(cast(ubyte)(number - SOUND3_REGISTERS_BEGIN), value);
            return;
        }

        if (number == 0x14) {
            volumes.data = value;
            return;
        }

        if (number == 0x16) {
            // TODO when powered off, all registers are written to 0
            enabledSounds.data = value;
            sound1.enabled(enabledSounds.sound1Enable);
            sound2.enabled(enabledSounds.sound2Enable);
            sound3.enabled(enabledSounds.sound3Enable);
            return;
        }

        debug {
            writefln("Game tried to write unimplemented APU register %02X", number);
        }
    }

    /**
     * Gets the value of an APU register
     *
     * @param number Number of the register to set. Relative to 0xFF10. Between 0x00 and 0x16.
     */
    @safe ubyte readApuRegister(ushort number) const
    in {
        assert(number <= 0x16);
    }
    body {
        if (number >= SOUND2_REGISTERS_BEGIN && number <= SOUND2_REGISTERS_END) {
            return sound2.readRegister(cast(ubyte)(number - SOUND2_REGISTERS_BEGIN));
        }

        if (number >= SOUND1_REGISTERS_BEGIN && number <= SOUND1_REGISTERS_END) {
            return sound1.readRegister(cast(ubyte)(number - SOUND1_REGISTERS_BEGIN));
        }

        if (number >= SOUND3_REGISTERS_BEGIN && number <= SOUND3_REGISTERS_END) {
            return sound3.readRegister(cast(ubyte)(number - SOUND3_REGISTERS_BEGIN));
        }

        if (number == 0x14) {
            return volumes.data;
        }

        if (number == 0x16) {
            return enabledSounds.data;
        }

        debug {
            writefln("Game tried to read unimplemented APU register %02X", number);
        }
        return 0xFF;
    }

    /// Write a byte to wave RAM
    @safe void writeWaveRAM(ubyte addr, ubyte data)
    in { assert(addr <= 15); }
    body {
        sound3.writeWaveRAM(addr, data);
    }

    /// Read a byte from wave RAM
    @safe ubyte readWaveRAM(ubyte addr) const
    in { assert(addr <= 15); }
    body {
        return sound3.readWaveRAM(addr);
    }

}

/// Representation of the NR50 register
private union VolumeControlRegister {
    ubyte data;
    mixin(bitfields!(
        ubyte, "rightVol", 3,  // Right channel volume
        ubyte, "vinRight", 1,  // Audio input from the cartridge
        ubyte, "leftVol",  3,  // Left channel volume
        bool,  "vinLeft",  1,  // Audio input from the cartridge
    ));
}

// Representation of the NR51 register
private union ChannelEnableRegister {
    ubyte data;
    mixin(bitfields!(
        bool, "rightSound1", 1,  // Output sound 1 to the right
        bool, "rightSound2", 1,  // Output sound 2 to the right
        bool, "rightSound3", 1,  // Output sound 3 to the right
        bool, "rightSound4", 1,  // Output sound 4 to the right
        bool, "leftSound1",  1,  // Output sound 1 to the left
        bool, "leftSound2",  1,  // Output sound 2 to the left
        bool, "leftSound3",  1,  // Output sound 3 to the left
        bool, "leftSound4",  1,  // Output sound 4 to the left
    ));
}

/// Representation of the NR52 register
private union SoundEnableRegister {
    ubyte data;
    mixin(bitfields!(
        bool, "sound1Enable", 1, // Whether sound 1 is enabled
        bool, "sound2Enable", 1, // Whether sound 2 is enabled
        bool, "sound3Enable", 1, // Whether sound 3 is enabled
        bool, "sound4Enable", 1, // Whether sound 4 is enabled
        ubyte, "",  3,
        bool, "masterEnable",   1, // Whether sound as a whole should be enabled
    ));
}