import std.conv;
import std.stdio;

import cartridge;

private const WORK_RAM_BEGIN            = 0xC000;
private const WORK_RAM_END              = 0xDFFF;

private const WORK_RAM_SHADOW_BEGIN     = 0xE000;
private const WORK_RAM_SHADOW_END       = 0xFDFF;

private const ZERO_PAGE_BEGIN           = 0xFF80;
private const ZERO_PAGE_END             = 0xFFFF;

private const EXTERNAL_RAM_BEGIN        = 0xA000;
private const EXTERNAL_RAM_END          = 0xBFFF;

private const CARTRIDGE_BANK_0_BEGIN    = 0x0000;
private const CARTRIDGE_BANK_0_END      = 0x3FFF;
private const CARTRIDGE_BANK_0_SIZE     = (CARTRIDGE_BANK_0_END - CARTRIDGE_BANK_0_BEGIN) + 1;

private const CARTRIDGE_BANK_1_BEGIN    = 0x4000;
private const CARTRIDGE_BANK_1_END      = 0x7FFF;

/**
 * Exception to be thrown when a caller tries to access a memory address not mapped by the MMU
 */
class UnmappedMemoryAccessException : Exception {
    @safe this(size_t addr) {
        super("Tried to access unmapped memory at 0x" ~ to!string(addr, 16));
    }
}

/**
 * Memory management unit of the emulator. Deals with mapping memory accesses.
 * Also stores the work RAM
 */
class MMU {

    private ubyte[WORK_RAM_END - WORK_RAM_BEGIN + 1] workRam;

    private ubyte[ZERO_PAGE_END - ZERO_PAGE_BEGIN + 1] zeroPage;

    // External RAM provided by the cartridge
    // Not sure if this should be here or in a cartridge class...
    private ubyte[EXTERNAL_RAM_END - EXTERNAL_RAM_BEGIN + 1] externalRAM;

    private const Cartridge cartridge;

    @safe this(const Cartridge c) {
        this.cartridge = c;
    }

    /**
     * Read a 8-bit value in memory at the specified address
    */
    @safe public ubyte readByte(in size_t address) const
    in {
        assert(address <= 0xFFFF);
    }
    body {
        if(ZERO_PAGE_BEGIN <= address && address <= ZERO_PAGE_END) {
            return zeroPage[address - ZERO_PAGE_BEGIN];
        }

        if(WORK_RAM_BEGIN <= address && address <= WORK_RAM_END) {
            return workRam[address - WORK_RAM_BEGIN];
        }
        if(WORK_RAM_SHADOW_BEGIN <= address && address <= WORK_RAM_SHADOW_END) {
            return workRam[address - WORK_RAM_SHADOW_BEGIN];
        }

        if(EXTERNAL_RAM_BEGIN <= address && address <= EXTERNAL_RAM_END) {
            return externalRAM[address - EXTERNAL_RAM_BEGIN];
        }

        if(CARTRIDGE_BANK_0_BEGIN <= address && address <= CARTRIDGE_BANK_0_END) {
            return cartridge.readROM(address - CARTRIDGE_BANK_0_BEGIN);
        }

        if(CARTRIDGE_BANK_1_BEGIN <= address && address <= CARTRIDGE_BANK_1_END) {
            return cartridge.readROM(address - CARTRIDGE_BANK_1_BEGIN + CARTRIDGE_BANK_0_SIZE);
        }

        throw new UnmappedMemoryAccessException(address);
    }

    /**
     * Read a 16-bit value in memory at the specified address
     */
    @safe public ushort readShort(in size_t address) const
    in {
        assert(address <= 0xFFFF);
    }
    body {
        // Read from memory and correct for endianness, so the bytes are swapped
        // TODO On little endian hosts, we can treat the array as an array of shorts and don't have to do bit operations like crazy
        return (readByte(cast(ushort)(address+1)) << 8) | readByte(address);
    }

    @safe public void writeByte(in size_t address, in ubyte val) 
    in {
        assert(address <= 0xFFFF);
    }
    body {
        if(ZERO_PAGE_BEGIN <= address && address <= ZERO_PAGE_END) {
            zeroPage[address - ZERO_PAGE_BEGIN] = val;
        } else

        if(WORK_RAM_BEGIN <= address && address <= WORK_RAM_END) {
            workRam[address - WORK_RAM_BEGIN] = val;
        } else
        if(WORK_RAM_SHADOW_BEGIN <= address && address <= WORK_RAM_SHADOW_END) {
            workRam[address - WORK_RAM_SHADOW_BEGIN] = val;
        } else

        if(EXTERNAL_RAM_BEGIN <= address && address <= EXTERNAL_RAM_END) {
            externalRAM[address - EXTERNAL_RAM_BEGIN] = val;
        } else {
            throw new UnmappedMemoryAccessException(address);
        }
    }

    @safe public void writeShort(in size_t address, in ushort val)
    in {
        assert(address <= 0xFFFF);
    }
    body {
        // TODO On little endian hosts, we can treat the array as an array of shorts and don't have to do a two-part save
        
        // Bytes are swapped to correct for endianness
        writeByte(address, val & 0x00FF);
        writeByte(address + 1, val >> 8);
    }

}