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

        @safe void writeExtRAM(size_t addr, ubyte val) {
            if(addr < extRAM.length) {
                extRAM[addr] = val;
            }
        }

        @safe ubyte readExtRAM(size_t addr) const {
            if(addr >= extRAM.length) {
                return 0;
            }

            return extRAM[addr];
        }

        @safe void writeROM(size_t addr, ubyte val) {
            // ROM is read only and there's no special control values
        }
    }

}