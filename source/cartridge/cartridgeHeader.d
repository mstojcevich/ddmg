module cartridge.header;

/// A representation of the cartridge header for GameBoy ROMs
union CartridgeHeader
{
    /// The raw data of the header. This begins at 0x0100 in the ROM.
    ubyte[80] headerData;

    struct
    {
        /// Entry point of the ROM: the code that runs right after the bootrom
        ubyte[4] entryPoint;

        /// Bitmap of the Nintendo Logo
        ubyte[48] nintendoLogo;

        union
        {
            /// Title of the game in ASCII for older games. Newer games use a shorter title area.
            ubyte[16] oldTitle;

            struct
            {
                /// The title of the game in ASCII for newer games. Only a portion of the old title.
                ubyte[11] newTitle;

                /// In newer cartridges this is a an ASCII manufacturer code
                ubyte[4] manufacturerCode;

                /// In newer cartridges this defines whether the game supports CGB or requires CGB
                ubyte cgbFlag;
            }
        }

        /// 2 character ASCII code indicating the publisher of the game (used for new games post-SGB)
        ubyte[2] newLicenseeCode;

        /// Specifies whether the game supports SGB functions
        ubyte sgbFlag;

        /// Specifies the MBC used in the cartridge and whether other hardware exists
        CartridgeType cartridgeType;

        /** 
         * Specifies how large the ROM is.
         * Size is calculated as (32KB << romSize) except for 0x52,0x53,0x54 which mean 1.1MB,1.2MB,1.5MB respectively.
         */
        RomSize romSize;

        /// Specifies the amount of external RAM in the cartridge
        RamSize ramSize;

        /// Specifies the target market for the ROM
        DestinationCode destCode;

        /// Specifies the game's publisher. 0x33 indicates that newLicenseeCode should be used instead
        ubyte oldLicenseeCode;

        /// Specifies the version number of the game
        ubyte versionNumber;

        /// Checksum of the cartridge bytes (0x0134-0x014C). Actual hardware enforces this.
        ubyte headerChecksum;

        /// Checksum across the entire cartridge. Actual hardware ignores this.
        ushort globalChecksum;
    }
}

/// The size of the ROM of the cartridge
enum RomSize : ubyte {
    KB_32   = 0x00,
    KB_64   = 0x01,
    KB_128  = 0x02,
    KB_256  = 0x03,
    KB_512  = 0x04,
    MB_1    = 0x05,
    MB_2    = 0x06,
    MB_3    = 0x07
}

@safe public size_t sizeBytes(RomSize rs) {
    final switch(rs) {
        case RomSize.KB_32:
            return 32_768;
        case RomSize.KB_64:
            return 32_768 << 1;
        case RomSize.KB_128:
            return 32_768 << 2;
        case RomSize.KB_256:
            return 32_768 << 3;
        case RomSize.KB_512:
            return 32_768 << 4;
        case RomSize.MB_1:
            return 32_768 << 5;
        case RomSize.MB_2:
            return 32_768 << 6;
        case RomSize.MB_3:
            return 32_768 << 7;
    }
}

@safe public size_t sizeBytes(RamSize rs) {
    final switch(rs) {
        case RamSize.NONE:
            return 0;
        case RamSize.KB_2:
            return 2048;
        case RamSize.KB_8:
            return 8192;
        case RamSize.KB_32:
            return 32_768;
    }
}

/// The size of the external RAM in the cartridge
enum RamSize : ubyte {
    NONE    = 0x00,
    KB_2    = 0x01,
    KB_8    = 0x02,
    KB_32   = 0x03
}

/// Specifies whether the game is supposed to be sold in Japan or anywhere else
enum DestinationCode : ubyte {
    JAPAN       = 0x00,
    NOT_JAPAN   = 0x01
}

/// Specifies the type of cartridge hardware (usually MBC type)
enum CartridgeType : ubyte {
    ROM_ONLY                        = 0x00,
    MBC1                            = 0x01,
    MBC1_RAM                        = 0x02,
    MBC1_RAM_BATTERY                = 0x03,
    MBC2                            = 0x05,
    MBC2_BATTERY                    = 0x06,
    ROM_RAM                         = 0x08,
    ROM_RAM_BATTERY                 = 0x09,
    MMM01                           = 0x0B,
    MMM01_RAM                       = 0x0C,
    MMM01_RAM_BATTERY               = 0x0D,
    MBC3_TIMER_BATTERY              = 0x0F,
    MBC3_TIMER_RAM_BATTERY          = 0x10,
    MBC3                            = 0x11,
    MBC3_RAM                        = 0x12,
    MBC3_RAM_BATERY                 = 0x13,
    MBC5                            = 0x19,
    MBC5_RAM                        = 0x1A,
    MBC5_RAM_BATTERY                = 0x1B,
    MBC5_RUMBLE                     = 0x1C,
    MBC5_RUMBLE_RAM                 = 0x1D,
    MBC5_RUMBLE_RAM_BATTERY         = 0x1E,
    MBC6                            = 0x20,
    MBC7_SENSOR_RUMBLE_RAM_BATTERY  = 0x22,
    POCKET_CAMERA                   = 0xFC,
    BANDAI_TAMA5                    = 0xFD,
    HUC3                            = 0xFE,
    HUC1_RAM_BATTERY                = 0xFF
}
