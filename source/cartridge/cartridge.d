module cartridge.cartridge;

import std.file;
import std.stdio;

import cartridge.header;
import cartridge.mbc;

// TODO support bank-selection

class Cartridge {
    
    private const CartridgeHeader header;
    private const MBC mbc;

    @safe public this(string filePath) {
        // Read enough of the ROM to know more about it
        const ubyte[] beginning = cast(const(ubyte[])) read(filePath, 336); // The header all within the first 336 bytes of the file

        header.headerData = beginning[0x100 .. 0x0150];

        // Load in the ROM data
        mbc = new MBCNone(filePath, header);

        writefln("Loaded ROM: %s", 
                cast(const char[11]) header.newTitle);
    }

    @safe public this() {
        mbc = new DummyMBC();

        header.headerData = new ubyte[80];
    }

    /// Read data at addr in bank 0
    @safe public ubyte readBank0(size_t addr) const {
        return mbc.readBank0(addr);
    }

    /// Read data at addr in bank 1
    @safe public ubyte readBank1(size_t addr) const {
        return mbc.readBank1(addr);
    }

}