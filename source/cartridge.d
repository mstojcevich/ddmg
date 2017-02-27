import std.file;
import std.stdio;

// TODO support bank-selection

class  Cartridge {

    private const ubyte[] cartridgeROM;
    
    private const ubyte[] nintendoLogo;
    private const char[] title;
    private const ubyte cgbFlag;
    private const ubyte cartridgeType;
    private const ubyte headerRomSize;  // Rom size data, not the exact size, lookup in table
    private const ubyte headerRamSize;  // External ram size data, not the exact size, lookup in table
    private const ubyte destinationCode;
    private const ubyte oldLicenseeCode;
    private const ubyte romVersionNum;
    private const ubyte headerChecksum;
    private const ubyte[] globalChecksum;

    @safe public this(string filePath) {
        // Load in the ROM data
        cartridgeROM = cast(const(ubyte[])) read(filePath, 32_768);  // 32,768 bytes is the max size of a cartridge ROM without bank switching

        // Parse the header info
        nintendoLogo = cartridgeROM[0x0104 .. 0x0134];
        title = cast(const(char[])) cartridgeROM[0x0134 .. 0x0144];
        cgbFlag = cartridgeROM[0x0143];
        cartridgeType = cartridgeROM[0x0147];
        headerRomSize = cartridgeROM[0x0148];
        headerRamSize = cartridgeROM[0x0149];
        destinationCode = cartridgeROM[0x014A];
        oldLicenseeCode = cartridgeROM[0x014B];
        romVersionNum = cartridgeROM[0x014C];
        headerChecksum = cartridgeROM[0x014D];
        globalChecksum = cartridgeROM[0x014E .. 0x0150];

        // TODO check checksums

        writefln("Loaded ROM: %s - %d bytes large", title, cartridgeROM.length);
    }

    @safe public ubyte readROM(size_t addr)
    in {
        assert(addr < 8192);
    }
    body {
        return cartridgeROM[addr];
    }
}