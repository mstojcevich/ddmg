module cartridge.mbc.mbc1;

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
    private ubyte bankNum = 1;
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
                return bankNum >> 6;
        }
    }

    @safe private ubyte romBankNum() const {
        // When in RAM mode, the upper 2 bits of the ROM bank
        // are used instead to specify the RAM bank

        final switch(mode) {
            case BankingMode.ROM_BANKING_MODE:
                return bankNum;
            case BankingMode.RAM_BANKING_MODE:
                return bankNum & 0b111111; // Lower 6 bits only
        }
    }

    @safe private size_t getBankedMemoryAddr(size_t addr) const {
        if(mode == BankingMode.ROM_BANKING_MODE) {
            // RAM banking not enabled
            return addr;
        } else {
            // The top two bits represent the memory bank
            immutable ubyte bank = bankNum >> 6;

            return (0x2000 * bank) + addr;
        }
    }
    
    override {
        @safe ubyte readBank1(size_t addr) const {
            return romData[addr + (0x4000 * romBankNum())];
        }

        @safe void writeExtRAM(size_t addr, ubyte val) {
            if(!ramEnabled) {
                return;
            }

            size_t bankedAddr = getBankedMemoryAddr(addr);

            if(bankedAddr < extRAM.length) {
                extRAM[bankedAddr] = val;
            }
        }

        @safe ubyte readExtRAM(size_t addr) const {
            if(!ramEnabled) {
                return 0;
            }

            size_t bankedAddr = getBankedMemoryAddr(addr);

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
                if(selection == 0) {
                    selection = 1;
                }

                bankNum = (bankNum & 0b11100000) | selection;

                return;
            }

            // Can either select RAM bank or upper 2 bits of ROM bank
            if(ROM_BANK_SEL_UPPER_BEGIN <= addr && addr <= ROM_BANK_SEL_UPPER_END) {
                bankNum = cast(ubyte)((bankNum & 0b00111111) | ((val & 0b11) << 6));
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