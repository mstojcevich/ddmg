import sound.apu;
import std.conv;
import std.stdio;

import cartridge, graphics, keypad, interrupt, clock, serial;

// TODO move some constants to their relevant modules

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

private const CARTRIDGE_BANK_1_BEGIN    = 0x4000;
private const CARTRIDGE_BANK_1_END      = 0x7FFF;

private const VRAM_BEGIN                = 0x8000;
private const VRAM_END                  = 0x9FFF;

private const OAM_BEGIN                 = 0xFE00;
private const OAM_END                   = 0xFE9F;

private const BGP                       = 0xFF47;
private const OBP0                      = 0xFF48;
private const OBP1                      = 0xFF49;
private const WINDOW_Y                  = 0xFF4A;
private const WINDOW_X                  = 0xFF4B;

private const DMA_TRANSFER_ADDR         = 0xFF46;

private const TIMER_DIV                 = 0xFF04;
private const TIMER_COUNTER             = 0xFF05;
private const TIMER_MODULO              = 0xFF06;
private const TIMER_CONTROL             = 0xFF07;

private const APU_REGISTERS_BEGIN       = 0xFF10;
private const APU_REGISTERS_END         = 0xFF26;

private const WAVE_RAM_BEGIN            = 0xFF30;
private const WAVE_RAM_END              = 0xFF3F;

private const SERIAL_DATA               = 0xFF01;
private const SERIAL_CONTROL            = 0xFF02;

private enum OamTransferState {
    NO_TRANSFER,
    SETUP,
    TRANSFER
}

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

    private Cartridge cartridge;
    private GPU gpu;
    private Keypad keypad;
    private InterruptHandler iuptHandler;
    private Clock clock;
    private APU apu;
    private Serial serial;

    private OamTransferState oamTransferState;
    private uint oamCycleAccum; // Leftover cycles since the last transfered bytes
    private ushort oamTransferToAddr; // The current address to transfer to
    private ushort oamTransferFromAddr; // The current address to transfer from

    /// Create a new MMU connected to the specified components
    @safe this(Cartridge c, GPU g, Keypad k, InterruptHandler ih, Clock clk, APU apu, Serial serial) {
        this.cartridge = c;
        this.gpu = g;
        this.keypad = k;
        this.iuptHandler = ih;
        this.clock = clk;
        this.apu = apu;
        this.serial = serial;
    }

    /// Simulate n cycles of the MMU running. Currently used for simulating OAM transfer
    @safe void step(uint cyclesElapsed) {
        if(oamTransferState != OamTransferState.NO_TRANSFER) {
            oamCycleAccum += cyclesElapsed;
        }

        final switch(oamTransferState) {
            case OamTransferState.NO_TRANSFER:
                break;
            case OamTransferState.SETUP:
                // TODO this should maybe start after the CPU finishes an instruction
                // TODO The OAM transfer takes 4 cycles to setup. Not sure why I need to spend 8
                if(oamCycleAccum >= 8) {
                    oamCycleAccum -= 8;
                    oamTransferState = OamTransferState.TRANSFER;
                    goto case OamTransferState.TRANSFER;
                }

                break;
            case OamTransferState.TRANSFER:
                while(oamCycleAccum >= 4) {
                    oamCycleAccum -= 4;

                    gpu.oam(cast(ushort)(oamTransferToAddr - OAM_BEGIN), readByte(oamTransferFromAddr));
                    oamTransferToAddr++;
                    oamTransferFromAddr++;

                    if(oamTransferToAddr > OAM_END) {
                        oamTransferState = OamTransferState.NO_TRANSFER;
                        break;
                    }
                }
                break;
        }
    }

    /**
     * Read a 8-bit value in memory at the specified address
    */
    @safe public ubyte readByte(in size_t address) const
    in {
        assert(address <= 0xFFFF);
    }
    body {
        // Cancel out certain reads if OAM DMA is occurring
        if(oamTransferState == OamTransferState.TRANSFER && address >= OAM_BEGIN && address <= OAM_END) {
            return 0xFF;
        }

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
            return cartridge.readExtRAM(address - EXTERNAL_RAM_BEGIN);
        }

        if(CARTRIDGE_BANK_0_BEGIN <= address && address <= CARTRIDGE_BANK_0_END) {
            return cartridge.readBank0(address - CARTRIDGE_BANK_0_BEGIN);
        }

        if(CARTRIDGE_BANK_1_BEGIN <= address && address <= CARTRIDGE_BANK_1_END) {
            return cartridge.readBank1(address - CARTRIDGE_BANK_1_BEGIN);
        }

        if(VRAM_BEGIN <= address && address <= VRAM_END) {
            return gpu.vram(cast(ushort)(address - VRAM_BEGIN));
        }
        
        if(OAM_BEGIN <= address && address <= OAM_END) {
            return gpu.oam(cast(ushort)(address - OAM_BEGIN));
        }

        if(address == 0xFF40) {
            return gpu.lcdcRegister;
        }
        if(address == 0xFF44) {
            return gpu.lyRegister;
        }
        if(address == 0xFF45) {
            return gpu.lycRegister;
        }
        if(address == 0xFF41) {
            return gpu.statRegister;
        }
        if(address == 0xFF42) {
            return gpu.scyRegister;
        }
        if(address == 0xFF43) {
            return gpu.scxRegister;
        }
        if(address == 0xFF4F) {
            // TODO CGB vram banks
            return 0xFF;
        }
        if(address == WINDOW_Y) {
            return gpu.wyRegister;
        }
        if(address == WINDOW_X) {
            return gpu.wxRegister;
        }
        if(address == BGP) {
            return gpu.bgpRegister;
        }
        if(address == OBP0) {
            return gpu.obp0Register;
        }
        if(address == OBP1) {
            return gpu.obp1Register;
        }

        if(address == 0xFF00) {
            return keypad.readJOYP();
        }

        if(address == 0xFFFF) {
            return iuptHandler.interruptEnableRegister;
        }
        if(address == 0xFF0F) {
            return iuptHandler.interruptFlagRegister;
        }

        if(address == TIMER_DIV) {
            return clock.divider;
        }
        if(address == TIMER_COUNTER) {
            return clock.timerCounter;
        }
        if(address == TIMER_MODULO) {
            return clock.timerModulo;
        }
        if(address == TIMER_CONTROL) {
            return clock.timerControl;
        }

        if(address == SERIAL_CONTROL) {
            return serial.control;
        }
        if(address == SERIAL_DATA) {
            return serial.data;
        }

        if(address >= APU_REGISTERS_BEGIN && address <= APU_REGISTERS_END) {
            return apu.readApuRegister(cast(ushort)(address - APU_REGISTERS_BEGIN));
        }
        if(address >= WAVE_RAM_BEGIN && address <= WAVE_RAM_END) {
            return apu.readWaveRAM(cast(ubyte)(address - WAVE_RAM_BEGIN));
        }

        if (address >= 0xFEA0 && address <= 0xFEFF) {
            // Unused memory area
            return 0x00;
        }

        debug {
            writefln("UNIMPLEMENTED : Reading address %04X", address);
            return 0xFF;
        } else {
            // Silently fail
            return 0xFF;
        }
    }

    /**
     * Read a two-byte little endian value in memory at the specified address
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
    /// Write an 8-bit value to memory at the specified address
    @safe public void writeByte(in size_t address, in ubyte val) 
    in {
        assert(address <= 0xFFFF);
    }
    body {
        // Cancel out certain writes if OAM DMA is occurring
        if(oamTransferState == OamTransferState.TRANSFER && address >= OAM_BEGIN && address <= OAM_END) {
            return;
        }

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
            cartridge.writeExtRAM(address - EXTERNAL_RAM_BEGIN, val);
        } else 

        if(VRAM_BEGIN <= address && address <= VRAM_END) {
            gpu.vram(cast(ushort)(address - VRAM_BEGIN), val);
        } else
        
        if(OAM_BEGIN <= address && address <= OAM_END) {
            gpu.oam(cast(ushort)(address - OAM_BEGIN), val);
        } else

        if(CARTRIDGE_BANK_0_BEGIN <= address && address <= CARTRIDGE_BANK_1_END) {
            cartridge.writeROM(address - CARTRIDGE_BANK_0_BEGIN, val);
        } else

        if(address == 0xFF40) {
            gpu.lcdcRegister = val;
        } else if(address == 0xFF45) {
            gpu.lycRegister = val;
        } else if(address == 0xFF41) {
            gpu.statRegister = val;
        } else if(address == 0xFF42) {
            gpu.scyRegister = val;
        } else if(address == 0xFF43) {
            gpu.scxRegister = val;
        } else if(address == WINDOW_Y) {
            gpu.wyRegister = val;
        } else if(address == WINDOW_X) {
            gpu.wxRegister = val;
        } else if(address == BGP) {
            gpu.bgpRegister = val;
        } else if(address == OBP0) {
            gpu.obp0Register = val;
        } else if(address == OBP1) {
            gpu.obp1Register = val;

        } else if(address == DMA_TRANSFER_ADDR) {
            // Transfer from RAM to OAM
            oamCycleAccum = 0;
            oamTransferFromAddr = val << 8;
            oamTransferToAddr = OAM_BEGIN;
            oamTransferState = OamTransferState.SETUP;
        } else if(address == 0xFF00) { 
            keypad.writeJOYP(val);

        } else if(address == 0xFFFF) {
            iuptHandler.interruptEnableRegister = val;
        } else if(address == 0xFF0F) {
            iuptHandler.interruptFlagRegister = val;

        } else if(address == TIMER_DIV) {
            clock.resetDivider();
        } else if(address == TIMER_COUNTER) {
            clock.timerCounter = val;
        } else if(address == TIMER_MODULO) {
            clock.timerModulo = val;
        } else if(address == TIMER_CONTROL) {
            clock.timerControl = val;

        } else if(address >= APU_REGISTERS_BEGIN && address <= APU_REGISTERS_END) {
            apu.setApuRegister(cast(ushort)(address - APU_REGISTERS_BEGIN), val);
        } else if(address >= WAVE_RAM_BEGIN && address <= WAVE_RAM_END) {
            apu.writeWaveRAM(cast(ubyte)(address - WAVE_RAM_BEGIN), val);

        } else if(address == SERIAL_CONTROL) {
            serial.control = val;
        } else if(address == SERIAL_DATA) {
            serial.data = val;

        } else if(address < 0xFEA0 || address > 0xFEFF) { // Unimplemented but don't want to crash for unmapped
            debug {
                writefln("UNIMPLEMENTED : Writing %02X at address %04X", val, address);
            }
        } else {
            debug {
                writefln("UNMAPPED : Writing %02X at address %04X", val, address);
                return;
            } else {
                // Silently fail
            }
        }
    }

    /// Write a two-byte little endian value to memory
    @safe public void writeShort(in size_t address, in ushort val)
    in {
        assert(address <= 0xFFFF);
    }
    body {        
        // Bytes are swapped to correct for endianness
        writeByte(address, val & 0x00FF);
        writeByte(address + 1, val >> 8);
    }

}