module cartridge.mbc.mbc3;

import std.stdio;
import cartridge.mbc.generic;
import cartridge.header;

private const size_t RAM_ENABLE_BEGIN           = 0x0000;
private const size_t RAM_ENABLE_END             = 0x1FFF;
private const size_t ROM_BANK_SEL_LOWER_BEGIN   = 0x2000;
private const size_t ROM_BANK_SEL_LOWER_END     = 0x3FFF;
private const size_t RAM_BANK_SEL_BEGIN         = 0x4000;
private const size_t RAM_BANK_SEL_END           = 0x5FFF;

private enum BankingMode {
    ROM_BANKING_MODE,
    RAM_BANKING_MODE
}

/// An MBC for a rom with an MBC3 chip
class MBC3 : MBC {

    private bool ramEnabled;
    private ubyte bankNum = 1;
    private ubyte ramBank = 0;

    /// Creates an MBC for a ROM at the specified path with the specified header
    @safe this(string filename, CartridgeHeader header) {
        super(filename, header);
    }

    @safe private ubyte ramBankNum() const {
        return ramBankNum;
    }

    @safe private ubyte romBankNum() const {
        if(bankNum == 0x00) {
            return 0x01;
        }

        return bankNum;
    }

    @safe private size_t getBankedRamAddr(size_t addr) const {
        return (0x2000 * ramBank) + addr;
    }
    
    override {
        @safe ubyte readBank1(size_t addr) const {
            return romData[addr + (0x4000 * romBankNum())];
        }

        @safe void writeExtRAM(size_t addr, ubyte val) {
            if(!ramEnabled) {
                return;
            }

            // When a RAM bank in the range 0x00-0x07 is selected,
            // that RAM bank in the cartridge will be mapped to this area.
            // When RAM banks in the range 0x09-0x0C are selected, a single RTC
            // register will be mapped instead.
            if(ramBank > 0x07) {
                // TODO realtime clock
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

            // When a RAM bank in the range 0x00-0x07 is selected,
            // that RAM bank in the cartridge will be mapped to this area.
            // When RAM banks in the range 0x09-0x0C are selected, a single RTC
            // register will be mapped instead.
            if(ramBank > 0x07) {
                // TODO realtime clock
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
                    if(ramEnabled) {
                        saveExtRAM();
                    }
                    ramEnabled = false;
                }
                
                return;
            }

            if(ROM_BANK_SEL_LOWER_BEGIN <= addr && addr <= ROM_BANK_SEL_LOWER_END) {
                immutable ubyte selection = val & 0b1111111; // Lower 7 bits

                bankNum = (bankNum & 0b10000000) | selection;

                return;
            }

            if(RAM_BANK_SEL_BEGIN <= addr && addr <= RAM_BANK_SEL_END) {
                ramBank = val;
            }
        }
    }

    // TODO real time clock

}