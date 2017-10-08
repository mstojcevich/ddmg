module cartridge.mbc.generic;

import cartridge.header;
import std.file;
import std.format;

/// The last address in (fixed) ROM bank 0
const size_t BANK_0_END = 0x3FFF;

/// A memory bank controller used to handle large cartridges
abstract class MBC {

    /// The data read from the ROM file
    protected const ubyte[] romData;

    /// The external RAM of the cartridge
    protected ubyte[] extRAM;

    /// Header of the cartridge
    private CartridgeHeader header;

    /**
     * Creates an MBC for a ROM at the given path
     * with the given header
     */
    @safe this(string filePath, CartridgeHeader header) {
        this.header = header;

        if(filePath == null) {
            romData = new ubyte[BANK_0_END + 1];
        } else {
            romData = cast(const(ubyte[])) read(filePath, sizeBytes(header.romSize));
        }

        extRAM = new ubyte[sizeBytes(header.ramSize)];
        loadExtRAM();
    }

    /// Read the data at addr in bank 0
    @safe ubyte readBank0(size_t addr) const {
        // Bank 0 is fixed, so we'll implement it here
        return romData[addr];
    }

    /// Read the data at addr in bank 1
    @safe ubyte readBank1(size_t addr) const;

    /// Write a value to an address in ROM (used for MBC control)
    @safe void writeROM(size_t addr, ubyte val);

    /// Read a value from external RAM
    @safe ubyte readExtRAM(size_t addr) const;

    /// Write a value to external RAM
    @safe void writeExtRAM(size_t addr, ubyte val);

    @safe protected void loadExtRAM() {
        if(!hasBattery(header.cartridgeType)) {
            return;
        }

        try {
            char[11 + ".sav".length] filename;
            sformat(filename, "%s.sav", (cast(const char[11]) header.newTitle));
            const ubyte[] readRAM = cast(const(ubyte[])) read(filename);
            for(int i = 0; i < readRAM.length; i++) {
                extRAM[i] = readRAM[i];
            }
        } catch(FileException ex) {}
    }

    @safe protected void saveExtRAM() {
        if(!hasBattery(header.cartridgeType)) {
            return;
        }

        char[11 + ".sav".length] filename;
        sformat(filename, "%s.sav", (cast(const char[11]) header.newTitle));
        write(filename, extRAM);
    }

}