import cartridgeHeader;
import std.file;
import std.stdio;

// TODO support bank-selection

class Cartridge {

    private const ubyte[] cartridgeROM;
    
    private CartridgeHeader header;

    @safe public this(string filePath) {
        // Read enough of the ROM to know more about it
        const ubyte[] beginning = cast(const(ubyte[])) read(filePath, 336); // The header all within the first 336 bytes of the file

        header.headerData = beginning[0x100 .. 0x0150];


        // Load in the ROM data
        cartridgeROM = cast(const(ubyte[])) read(filePath, 32_768);  // 32,768 bytes is the max size of a cartridge ROM without bank switching
        // TODO check checksums

        writefln("Loaded ROM: %s - %d bytes large", cast(const char[11]) header.newTitle, cartridgeROM.length);
    }

    @safe public this() {
        cartridgeROM = new ubyte[32_768];

        header.headerData = new ubyte[80];
    }

    @safe public ubyte readROM(size_t addr) const
    in {
        assert(addr < 32_768); // Max size of a ROM without bank-switching
    }
    body {
        return cartridgeROM[addr];
    }
}