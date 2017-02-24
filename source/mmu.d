import std.conv;

private const WORK_RAM_BEGIN        = 0xC000;
private const WORK_RAM_END          = 0xDFFF;
private const WORK_RAM_SHADOW_BEGIN = 0xE000;
private const WORK_RAM_SHADOW_END   = 0xFDFF;

/**
 * Exception to be thrown when a caller tries to access a memory address not mapped by the MMU
 */
class UnmappedMemoryAccessException : Exception {
    @safe this(size_t addr) {
        super("Tried to read unmapped memory at 0x" ~ to!string(addr, 16));
    }
}

/**
 * Memory management unit of the emulator. Deals with mapping memory accesses.
 * Also stores the work RAM
 */
class MMU {

    private ubyte[8192] workRam;

    /**
     * Read a 8-bit value in memory at the specified address
    */
    @safe public const ubyte readByte(in size_t address)
    in {
        assert(address <= 0xFFFF);
    }
    body {
        if(WORK_RAM_BEGIN <= address && address <= WORK_RAM_END) {
            return workRam[address - WORK_RAM_BEGIN];
        }
        if(WORK_RAM_SHADOW_BEGIN <= address && address <= WORK_RAM_SHADOW_END) {
            return workRam[address - WORK_RAM_SHADOW_BEGIN];
        }

        throw new UnmappedMemoryAccessException(address);
    }

    /**
     * Read a 16-bit value in memory at the specified address
     */
    @safe public const ushort readShort(in size_t address)
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
        if(WORK_RAM_BEGIN <= address && address <= WORK_RAM_END) {
            workRam[address - WORK_RAM_BEGIN] = val;
        }
        if(WORK_RAM_SHADOW_BEGIN <= address && address <= WORK_RAM_SHADOW_END) {
            workRam[address - WORK_RAM_SHADOW_BEGIN] = val;
        }

        throw new UnmappedMemoryAccessException(address);
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