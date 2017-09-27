module cartridge.mbc.mbc1;

import std.stdio;
import cartridge.mbc.generic;
import cartridge.header;

private const size_t RAM_ENABLE_BEGIN           = 0x0000;
private const size_t RAM_ENABLE_END             = 0x1FFF;
private const size_t ROM_BANK_SEL_LOWER_BEGIN   = 0x2000;
private const size_t ROM_BANK_SEL_LOWER_END     = 0x3FFF;
private const size_t ROM_BANK_SEL_UPPER_BEGIN   = 0x4000;
private const size_t ROM_BANK_SEL_UPPER_END     = 0x5FFF;
private const size_t ROMRAM_MODE_SELECT_BEGIN   = 0x4000;
private const size_t ROMRAM_MODE_SELECT_END     = 0x5FFF;


private enum BankingMode {
    ROM1_ONLY,
    ALL
}

/// An MBC for a rom with an MBC1 chip
class MBC1 : MBC {

    private bool ramEnabled;
    private BankingMode mode = BankingMode.ROM1_ONLY;

    /// The bank number
    /// Either the whole thing represents the ROM bank,
    /// or bits 5 and 6 represent the RAM bank
    private ubyte bankNum = 0b00000001;

    /// Creates an MBC for a ROM at the specified path with the specified header
    @safe this(string filename, CartridgeHeader header) {
        super(filename, header);
    }

    @safe private ubyte ramBankNum() const {
        final switch(mode) {
            case BankingMode.ROM1_ONLY:
                return 0; // Memory banking is not applied in this case
            case BankingMode.ALL:
                return bankNum >> 5; // Bits 5 and 6 represent RAM bank
        }
    }

    @safe private ubyte rom0BankNum() const {
        // If mode is BankingMode.ALL, the first section of ROM is banked
        // using bits 5 and 6 of the bankNum
        final switch(mode) {
            case BankingMode.ROM1_ONLY:
                return 0; // ROM0 banking is not applied in this case
            case BankingMode.ALL:
                return bankNum & 0b01100000; // Bits 5 and 6 represent ROM0 bank
        }
    }

    @safe private ubyte rom1BankNum() const {
        return bankNum;
    }

    @safe private size_t getBankedRamAddr(size_t addr) const {
        return (0x2000 * ramBankNum()) + addr;
    }
    
    override {
        @safe ubyte readBank0(size_t addr) const {
            size_t absolute = (addr + (0x4000 * rom0BankNum())) % romData.length;
            return romData[absolute];
        }

        @safe ubyte readBank1(size_t addr) const {
            size_t absolute = (addr + (0x4000 * rom1BankNum())) % romData.length;
            return romData[absolute];
        }

        @safe void writeExtRAM(size_t addr, ubyte val) {
            if(!ramEnabled) {
                // When ram is disabled, all writes are ignored
                return;
            }

            size_t bankedAddr = getBankedRamAddr(addr);

            if(bankedAddr < extRAM.length) {
                extRAM[bankedAddr] = val;
            }
        }

        @safe ubyte readExtRAM(size_t addr) const {
            if(!ramEnabled) {
                // When RAM is disabled, reads return 0xFF
                return 0xFF;
            }

            size_t bankedAddr = getBankedRamAddr(addr);

            if(bankedAddr < extRAM.length) {
                return extRAM[bankedAddr];
            } else {
                return 0;
            }
        }

        @safe public void writeROM(size_t addr, ubyte val) {
            // ROM is ready only and there's no control stuff
            if(RAM_ENABLE_BEGIN <= addr && addr <= RAM_ENABLE_END) {
                if((val & 0b1111) == 0x0A) {
                    ramEnabled = true;
                } else {
                    ramEnabled = false;
                }
                
                return;
            }

            if(ROM_BANK_SEL_LOWER_BEGIN <= addr && addr <= ROM_BANK_SEL_LOWER_END) {
                ubyte selection = val & 0b11111; // Lower 5 bits
                if(selection == 0b00000) { // 00, 20, 40, 60 should be 01, 21, 41, 61
                    selection = 0b00001;
                }

                bankNum = (bankNum & 0b01100000) | selection;
                
                return;
            }

            // Can either select RAM bank or bits 5 and 6 of ROM bank
            if(ROM_BANK_SEL_UPPER_BEGIN <= addr && addr <= ROM_BANK_SEL_UPPER_END) {                
                bankNum = (bankNum & 0b00011111) | ((val & 0b11) << 5);
            }

            if(ROMRAM_MODE_SELECT_BEGIN <= addr && addr <= ROMRAM_MODE_SELECT_END) {
                if((val & 0b1) == 1) {
                    mode = BankingMode.ALL;
                } else {
                    mode = BankingMode.ROM1_ONLY;
                }
            }
        }
    }

}