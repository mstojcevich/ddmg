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
    ROM_BANKING_MODE,
    RAM_BANKING_MODE
}

/// An MBC for a rom without an MBC chip
class MBC1 : MBC {

    private bool ramEnabled;
    private ubyte romBank = 1;
    private ubyte ramBank = 0;
    private BankingMode mode = BankingMode.ROM_BANKING_MODE;

    /// Creates an MBC for a ROM at the specified path with the specified header
    @safe this(string filename, CartridgeHeader header) {
        super(filename, header);
    }

    @safe private ubyte ramBankNum() const {
        final switch(mode) {
            case BankingMode.ROM_BANKING_MODE:
                return 0;
            case BankingMode.RAM_BANKING_MODE:
                return ramBank;
        }
    }

    @safe private ubyte romBankNum() const {
        if((romBank & 0b00011111) == 0) {
            return romBank | 0b00000001;
        }

        return romBank;
    }

    @safe private size_t getBankedRamAddr(size_t addr) const {
        return (0x2000 * ramBankNum()) + addr;
    }
    
    override {
        @safe ubyte readBank1(size_t addr) const {
            size_t absolute = (addr + (0x4000 * romBankNum())) % romData.length;

            return romData[absolute];
        }

        @safe void writeExtRAM(size_t addr, ubyte val) {
            if(!ramEnabled) {
                return;
            }

            size_t bankedAddr = getBankedRamAddr(addr);

            if(bankedAddr < extRAM.length) {
                extRAM[bankedAddr] = val;
            }
        }

        @safe ubyte readExtRAM(size_t addr) const {
            if(!ramEnabled) {
                return 0;
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
                immutable ubyte selection = val & 0b11111; // Lower 5 bits

                if(mode == BankingMode.ROM_BANKING_MODE) {
                    romBank = (romBank & 0b01100000) | selection;
                } else {
                    romBank = selection;
                }

                return;
            }

            // Can either select RAM bank or bits 5 and 6 of ROM bank
            if(ROM_BANK_SEL_UPPER_BEGIN <= addr && addr <= ROM_BANK_SEL_UPPER_END) {                
                if(mode == BankingMode.ROM_BANKING_MODE) {
                    romBank = (romBank & 0b00011111) | ((val & 0b11) << 5);
                } else {
                    ramBank = val & 0b11;
                }
            }

            if(ROMRAM_MODE_SELECT_BEGIN <= addr && addr <= ROMRAM_MODE_SELECT_END) {
                if((val & 0b1) == 1) {
                    mode = BankingMode.RAM_BANKING_MODE;
                } else {
                    mode = BankingMode.ROM_BANKING_MODE;
                }
            }
        }
    }


    // TODO I'm not sure what this means: "If other ROM bank is selected, ROM bank will be changed to the corresponding in 01h-1Fh by clearing the upper 2 bits."
    // TODO are previous rom upper bits preserved or are the same bits used for RAM

}