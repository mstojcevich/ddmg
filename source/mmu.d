import std.conv;
import std.stdio;

import cartridge, gpu, keypad, interrupt;

private const WORK_RAM_BEGIN            = 0xC000;
private const WORK_RAM_END              = 0xDFFF;

private const WORK_RAM_SHADOW_BEGIN     = 0xE000;
private const WORK_RAM_SHADOW_END       = 0xFDFF;

private const ZERO_PAGE_BEGIN           = 0xFF80;
private const ZERO_PAGE_END             = 0xFFFE;

private const EXTERNAL_RAM_BEGIN        = 0xA000;
private const EXTERNAL_RAM_END          = 0xBFFF;

private const CARTRIDGE_BANK_0_BEGIN    = 0x0000;
private const CARTRIDGE_BANK_0_END      = 0x3FFF;
private const CARTRIDGE_BANK_0_SIZE     = (CARTRIDGE_BANK_0_END - CARTRIDGE_BANK_0_BEGIN) + 1;

private const CARTRIDGE_BANK_1_BEGIN    = 0x4000;
private const CARTRIDGE_BANK_1_END      = 0x7FFF;

private const VRAM_BEGIN                = 0x8000;
private const VRAM_END                  = 0x9FFF;

private const OAM_BEGIN                 = 0xFE00;
private const OAM_END                   = 0xFE9F;

private const BGP                       = 0xFF47;
private const OBP0                      = 0xFF48;
private const OBP1                      = 0xFF49;

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
    private GPU gpu;
    private Keypad keypad;
    private InterruptHandler iuptHandler;

    @safe this(const Cartridge c, GPU g, Keypad k, InterruptHandler ih) {
        this.cartridge = c;
        this.gpu = g;
        this.keypad = k;
        this.iuptHandler = ih;
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

        if(VRAM_BEGIN <= address && address <= VRAM_END) {
            return gpu.getVRAM(cast(ushort)(address - VRAM_BEGIN));
        }
        
        if(OAM_BEGIN <= address && address <= OAM_END) {
            return gpu.getOAM(cast(ushort)(address - OAM_BEGIN));
        }

        if(address == 0xFF40) {
            return gpu.getLCDControl();
        }
        if(address == 0xFF44) { // Reset the current scanline if the CPU tries to write to it
            return gpu.getCurScanline();
        }
        if(address == 0xFF45) {
            return gpu.getScanlineCompare();
        }
        if(address == 0xFF41) {
            return gpu.getLCDStatus();
        }
        if(address == 0xFF42) {
            return gpu.getScrollY();
        }
        if(address == 0xFF43) {
            return gpu.getScrollX();
        }
        if(address == BGP) {
            return gpu.backgroundPalette;
        }
        if(address == OBP0) {
            return gpu.obp0;
        }
        if(address == OBP1) {
            return gpu.obp1;
        }

        if(address == 0xFF00) {
            return keypad.readJOYP();
        }

        if(address == 0xFFFF) {
            return iuptHandler.interruptEnableRegister;
        }

        debug {
            writefln("UNIMPLEMENTED : Reading address %04X", address);
            return 0;
        } else {
            throw new UnmappedMemoryAccessException(address);
        }
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
        } else 

        if(VRAM_BEGIN <= address && address <= VRAM_END) {
            gpu.setVRAM(cast(ushort)(address - VRAM_BEGIN), val);
        } else
        
        if(OAM_BEGIN <= address && address <= OAM_END) {
            gpu.setOAM(cast(ushort)(address - OAM_BEGIN), val);
        } else

        if(address == 0xFF40) {
            gpu.setLCDControl(val);
        } else if(address == 0xFF44) { // Reset the current scanline if the CPU tries to write to it
            gpu.resetCurScanline();
        } else if(address == 0xFF45) {
            gpu.setScanlineCompare(val);
        } else if(address == 0xFF41) {
            gpu.setLCDStatus(val);
        } else if(address == 0xFF42) {
            gpu.setScrollX(val);
        } else if(address == 0xFF43) {
            gpu.setScrollY(val);
        } else if(address == BGP) {
            gpu.backgroundPalette = val;
        } else if(address == OBP0) {
            gpu.obp0 = val;
        } else if(address == OBP1) {
            gpu.obp1 = val;

        } else if(address == 0xFF00) { 
            keypad.writeJOYP(val);

        } else if(address == 0xFFFF) {
            iuptHandler.interruptEnableRegister = val;

        } else {
            debug {
                writefln("UNIMPLEMENTED : Writing %02X at address %04X", val, address);
            }

            //throw new UnmappedMemoryAccessException(address);
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