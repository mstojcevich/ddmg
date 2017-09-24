module cartridge.mbc.none;

import cartridge.mbc.generic;
import cartridge.header;

private const size_t BANK_1_BEGIN = BANK_0_END + 1; // Second 16KB are bank 2

/// An MBC for a rom without an MBC chip
class MBCNone : MBC {

    /// Creates an MBC for a ROM at the specified path with the specified header
    @safe this(string filename, CartridgeHeader header) {
        super(filename, header);
    }
    
    override {
        @safe ubyte readBank1(size_t addr) const {
            return romData[addr + BANK_1_BEGIN];
        }

        @safe public void writeROM(size_t addr, ubyte val) {
            // ROM is ready only and there's no control stuff
        }
    }

}