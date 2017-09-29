module sound.apu;

import std.bitmanip;

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
        bool, "leftSoundl1",  1, // Output sound 1 to the left
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

/// Sound processing unit for the Gameboy
class APU {

    private VolumeControlRegister volumes;
    private ChannelEnableRegister enabledChannels;
    private SoundEnableRegister enabledSounds;

}