module cartridge.mbc.dummy;

import cartridge.mbc.generic;
import cartridge.header;

private const size_t BANK_1_BEGIN = BANK_0_END + 1; // Second 16KB are bank 2

/// An dummy MBC for testing that always returns 0
class DummyMBC : MBC {

    @safe this() {
        super(null, CartridgeHeader());
    }
    
    override {
        @safe ubyte readBank1(size_t addr) const {
            return 0;
        }

        @safe public void writeROM(size_t addr, ubyte val) {}

        @safe void writeExtRAM(size_t addr, ubyte val) {}

        @safe ubyte readExtRAM(size_t addr) const {
            return 0;
        }
    }

}