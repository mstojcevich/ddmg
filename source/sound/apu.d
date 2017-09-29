module sound.apu;

import std.bitmanip;

/// Representation of the NR50 register
private union VolumeControlRegister {
    ubyte data;
    mixin(bitfields!(
        ubyte, "rightVol", 3, // Right channel volume
        ubyte, "vinRight", 1, // Audio input from the cartridge
        ubyte, "leftVol", 3,  // Left channel volume
        bool, "vinLeft", 1,   // Audio input from the cartridge
    ));
}

// Representation of the NR51 register
private union ChannelEnableRegister {
    ubyte data;
    mixin(bitfields!(
        bool, "rightChannel1", 1, // Output channel 1 to the right
        bool, "rightChannel2", 1, // Output channel 2 to the right
        bool, "rightChannel3", 1, // Output channel 3 to the right
        bool, "rightChannel4", 1, // Output channel 4 to the right
        bool, "leftChannel1",  1, // Output channel 1 to the left
        bool, "leftChannel2",  1, // Output channel 2 to the left
        bool, "leftChannel3",  1, // Output channel 3 to the left
        bool, "leftChannel4",  1, // Output channel 4 to the left
    ));
}

private union SoundEnableRegister {
    ubyte data;
    mixin(bitfields!(
        bool, "channel1Enable", 1, // Whether channel 1 is enabled
        bool, "channel2Enable", 1, // Whether channel 2 is enabled
        bool, "channel3Enable", 1, // Whether channel 3 is enabled
        bool, "channel4Enable", 1, // Whether channel 4 is enabled
        ubyte, "",  3,
        bool, "masterEnable",   1, // Whether sound as a whole should be enabled
    ));
}

/// Sound processing unit for the Gameboy
class APU {

    private VolumeControlRegister volumes;
    private ChannelEnableRegister enabledChannels;
    private SoundEnableRegister enableStatus;

}