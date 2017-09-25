module cartridge.cartridge;

import std.file;
import std.stdio;

import cartridge.header;
import cartridge.mbc;

// TODO support bank-selection

class Cartridge {
    
    private const CartridgeHeader header;
    private MBC mbc;

    @safe public this(string filePath) {
        // Read enough of the ROM to know more about it
        const ubyte[] beginning = cast(const(ubyte[])) read(filePath, 336); // The header all within the first 336 bytes of the file

        header.headerData = beginning[0x100 .. 0x0150];

        // Load in the ROM data
        if(header.cartridgeType == CartridgeType.ROM_ONLY) {
            mbc = new MBCNone(filePath, header);
        } else if(header.cartridgeType == CartridgeType.MBC1
                || header.cartridgeType == CartridgeType.MBC1_RAM
                || header.cartridgeType == CartridgeType.MBC1_RAM_BATTERY) {
            mbc = new MBC1(filePath, header);
        } else if(header.cartridgeType == CartridgeType.MBC3
                || header.cartridgeType == CartridgeType.MBC3_RAM
                || header.cartridgeType == CartridgeType.MBC3_TIMER_RAM_BATTERY
                || header.cartridgeType == CartridgeType.MBC3_RAM_BATTERY
                || header.cartridgeType == CartridgeType.MBC3_TIMER_BATTERY) {
            mbc = new MBC3(filePath, header);
        } else {
            writefln("Unknown MBC type 0x%02X. Using MBC1. Problems will almost surely occur.", header.cartridgeType);
            mbc = new MBC1(filePath, header);
        }

        writefln("Loaded ROM: %s (type %02X)", 
                cast(const char[11]) header.newTitle,
                header.cartridgeType);
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

    /// Write a value to an address in ROM (used for MBC control)
    @safe public void writeROM(size_t addr, ubyte val) {
        mbc.writeROM(addr, val);
    }

    /// Read a value from external RAM
    @safe ubyte readExtRAM(size_t addr) const {
        return mbc.readExtRAM(addr);
    }

    /// Write a value to external RAM
    @safe void writeExtRAM(size_t addr, ubyte val) {
        mbc.writeExtRAM(addr, val);
    }

}