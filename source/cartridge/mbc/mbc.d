module cartridge.mbc.generic;

import cartridge.header;
import std.file;

/// The last address in (fixed) ROM bank 0
const size_t BANK_0_END = 0x3FFF;

/// A memory bank controller used to handle large cartridges
abstract class MBC {

    /// The data read from the ROM file
    protected const ubyte[] romData;

    /**
     * Creates an MBC for a ROM at the given path
     * with the given header
     */
    @safe this(string filePath, CartridgeHeader header) {
        if(filePath == null) {
            romData = new ubyte[BANK_0_END + 1];
        } else {
            romData = cast(const(ubyte[])) read(filePath, sizeBytes(header.romSize));
        }
    }

    /// Read the data at addr in bank 0
    @safe ubyte readBank0(size_t addr) const {
        // Bank 0 is fixed, so we'll implement it here
        return romData[addr];
    }

    /// Read the data at addr in bank 1
    @safe ubyte readBank1(size_t addr) const;

}