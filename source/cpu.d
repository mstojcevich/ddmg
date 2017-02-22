import std.stdio;
import std.format;

import mmu;

alias reg16 = ushort;
alias reg8 = ubyte;

private template Register(string firstHalf, string secondHalf) {
    const char[] Register = 
    "
    union {
        reg16 " ~ firstHalf ~ secondHalf ~ ";

        struct {
            reg8 " ~ secondHalf ~ ";
            reg8 " ~ firstHalf ~";
        }
    }
    ";
}

private enum Flag : ubyte {
    ZERO            = 0b10000000, // Set to 1 when the result of an operation is 0
    SUBTRACTION     = 0b01000000, // Set to 1 following the execution of the subtraction instruction
    HALF_OVERFLOW   = 0b00100000, // Set to 1 when an operation carries from or borrows to bit 3
    OVERFLOW        = 0b00010000  // Set to 1 when an operation carries from or borrows to bit 7
}

struct Instruction {
    string disassembly;
    void delegate() impl;
}

/**
 * Implementation of the GameBoy CPU
 */
class CPU {

    private Instruction[256] instructions;

    private struct Registers {
        mixin(Register!("a", "f"));
        mixin(Register!("b", "c"));
        mixin(Register!("d", "e"));
        mixin(Register!("h", "l"));

        reg16 sp;
        reg16 pc;
    }

    private Registers regs = {};

    private MMU mmu;

    this(MMU mmu) {
        this.instructions = [
            Instruction("NOP",          &nop),
            Instruction("LD BC,d16",    null),
            Instruction("LD (BC),A",    null),
            Instruction("INC BC",       null),
            Instruction("INC B",        null),
            Instruction("DEC B",        null),
            Instruction("LD B,d8",      null),
            Instruction("RLCA",         null),
            Instruction("LD (a16),SP",  null),
            Instruction("ADD HL,BC",    {add(regs.hl, regs.bc);}),
            Instruction("LD A,(BC)",    null),
            Instruction("DEC BC",       null),
            Instruction("INC C",        null),
            Instruction("DEC C",        null),
            Instruction("LD C,d8",      null),
            Instruction("RRCA",         null),
            Instruction("STOP 0",       null),
            Instruction("LD DE,d16",    null),
            Instruction("LD (DE),A",	null),
            Instruction("INC DE",		null),
            Instruction("INC D",		null),
            Instruction("DEC D",		null),
            Instruction("LD D,d8",		null),
            Instruction("RLA",		    null),
            Instruction("JR r8",		null),
            Instruction("ADD HL,DE",	{add(regs.hl, regs.de);}),
            Instruction("LD A,(DE)",	null),
            Instruction("DEC DE",		null),
            Instruction("INC E",		null),
            Instruction("DEC E",		null),
            Instruction("LD E,d8",		null),
            Instruction("RRA",		    null),
            Instruction("JR NZ,r8",		null),
            Instruction("LD HL,d16",	null),
            Instruction("LD (HL+),A",	null),
            Instruction("INC HL",		null),
            Instruction("INC H",		null),
            Instruction("DEC H",		null),
            Instruction("LD H,d8",		null),
            Instruction("DAA",		    null),
            Instruction("JR Z,r8",		null),
            Instruction("ADD HL,HL",	{add(regs.hl, regs.hl);}),
            Instruction("LD A,(HL+)",	null),
            Instruction("DEC HL",		null),
            Instruction("INC L",		null),
            Instruction("DEC L",		null),
            Instruction("LD L,d8",		null),
            Instruction("CPL",		    null),
            Instruction("JR NC,r8",		null),
            Instruction("LD SP,d16",	null),
            Instruction("LD (HL-),A",	null),
            Instruction("INC SP",		null),
            Instruction("INC (HL)",		null),
            Instruction("DEC (HL)",		null),
            Instruction("LD (HL),d8",	null),
            Instruction("SCF",		    null),
            Instruction("JR C,r8",		null),
            Instruction("ADD HL,SP",	{add(regs.hl, regs.sp);}),
            Instruction("LD A,(HL-)",	null),
            Instruction("DEC SP",		null),
            Instruction("INC A",		null),
            Instruction("DEC A",		null),
            Instruction("LD A,d8",		{loadImmediate(regs.a);}),
            Instruction("CCF",		    null),
            Instruction("LD B,B",		{load(regs.b, regs.b);}),
            Instruction("LD B,C",		{load(regs.b, regs.c);}),
            Instruction("LD B,D",		{load(regs.b, regs.d);}),
            Instruction("LD B,E",		{load(regs.b, regs.e);}),
            Instruction("LD B,H",		{load(regs.b, regs.h);}),
            Instruction("LD B,L",		{load(regs.b, regs.l);}),
            Instruction("LD B,(HL)",	{loadReference(regs.b);}),
            Instruction("LD B,A",		{load(regs.b, regs.a);}),
            Instruction("LD C,B",		{load(regs.c, regs.b);}),
            Instruction("LD C,C",		{load(regs.c, regs.c);}),
            Instruction("LD C,D",		{load(regs.c, regs.d);}),
            Instruction("LD C,E",		{load(regs.c, regs.e);}),
            Instruction("LD C,H",		{load(regs.c, regs.h);}),
            Instruction("LD C,L",		{load(regs.c, regs.l);}),
            Instruction("LD C,(HL)",	{loadReference(regs.c);}),
            Instruction("LD C,A",		{load(regs.c, regs.a);}),
            Instruction("LD D,B",		{load(regs.d, regs.b);}),
            Instruction("LD D,C",		{load(regs.d, regs.c);}),
            Instruction("LD D,D",		{load(regs.d, regs.d);}),
            Instruction("LD D,E",		{load(regs.d, regs.e);}),
            Instruction("LD D,H",		{load(regs.d, regs.h);}),
            Instruction("LD D,L",		{load(regs.d, regs.l);}),
            Instruction("LD D,(HL)",	{loadReference(regs.d);}),
            Instruction("LD D,A",		{load(regs.d, regs.a);}),
            Instruction("LD E,B",		{load(regs.e, regs.b);}),
            Instruction("LD E,C",		{load(regs.e, regs.c);}),
            Instruction("LD E,D",		{load(regs.e, regs.d);}),
            Instruction("LD E,E",		{load(regs.e, regs.e);}),
            Instruction("LD E,H",		{load(regs.e, regs.h);}),
            Instruction("LD E,L",		{load(regs.e, regs.l);}),
            Instruction("LD E,(HL)",	{loadReference(regs.e);}),
            Instruction("LD E,A",		{load(regs.e, regs.a);}),
            Instruction("LD H,B",		{load(regs.h, regs.b);}),
            Instruction("LD H,C",		{load(regs.h, regs.c);}),
            Instruction("LD H,D",		{load(regs.h, regs.d);}),
            Instruction("LD H,E",		{load(regs.h, regs.e);}),
            Instruction("LD H,H",		{load(regs.h, regs.h);}),
            Instruction("LD H,L",		{load(regs.h, regs.l);}),
            Instruction("LD H,(HL)",	{loadReference(regs.h);}),
            Instruction("LD H,A",		{load(regs.h, regs.a);}),
            Instruction("LD L,B",		{load(regs.l, regs.b);}),
            Instruction("LD L,C",		{load(regs.l, regs.c);}),
            Instruction("LD L,D",		{load(regs.l, regs.d);}),
            Instruction("LD L,E",		{load(regs.l, regs.e);}),
            Instruction("LD L,H",		{load(regs.l, regs.h);}),
            Instruction("LD L,L",		{load(regs.l, regs.l);}),
            Instruction("LD L,(HL)",	{loadReference(regs.l);}),
            Instruction("LD L,A",		{load(regs.l, regs.a);}),
            Instruction("LD (HL),B",	{storeInMemory(regs.b);}),
            Instruction("LD (HL),C",	{storeInMemory(regs.c);}),
            Instruction("LD (HL),D",	{storeInMemory(regs.d);}),
            Instruction("LD (HL),E",	{storeInMemory(regs.e);}),
            Instruction("LD (HL),H",	{storeInMemory(regs.h);}),
            Instruction("LD (HL),L",	{storeInMemory(regs.l);}),
            Instruction("HALT",		    null),
            Instruction("LD (HL),A",	{storeInMemory(regs.a);}),
            Instruction("LD A,B",		{load(regs.a, regs.b);}),
            Instruction("LD A,C",		{load(regs.a, regs.c);}),
            Instruction("LD A,D",		{load(regs.a, regs.d);}),
            Instruction("LD A,E",		{load(regs.a, regs.e);}),
            Instruction("LD A,H",		{load(regs.a, regs.h);}),
            Instruction("LD A,L",		{load(regs.a, regs.l);}),
            Instruction("LD A,(HL)",	{loadReference(regs.a);}),
            Instruction("LD A,A",		{load(regs.a, regs.a);}),
            Instruction("ADD A,B",		{add(regs.b);}),
            Instruction("ADD A,C",		{add(regs.b);}),
            Instruction("ADD A,D",		{add(regs.d);}),
            Instruction("ADD A,E",		{add(regs.e);}),
            Instruction("ADD A,H",		{add(regs.h);}),
            Instruction("ADD A,L",		{add(regs.l);}),
            Instruction("ADD A,(HL)",	{addReference();}),
            Instruction("ADD A,A",		{add(regs.a);}),
            Instruction("ADC A,B",		{adc(regs.b);}),
            Instruction("ADC A,C",		{adc(regs.c);}),
            Instruction("ADC A,D",		{adc(regs.d);}),
            Instruction("ADC A,E",		{adc(regs.e);}),
            Instruction("ADC A,H",		{adc(regs.h);}),
            Instruction("ADC A,L",		{adc(regs.l);}),
            Instruction("ADC A,(HL)",	&adcReference),
            Instruction("ADC A,A",		{adc(regs.a);}),
            Instruction("SUB B",		null),
            Instruction("SUB C",		null),
            Instruction("SUB D",		null),
            Instruction("SUB E",		null),
            Instruction("SUB H",		null),
            Instruction("SUB L",		null),
            Instruction("SUB (HL)",		null),
            Instruction("SUB A",		null),
            Instruction("SBC A,B",		null),
            Instruction("SBC A,C",		null),
            Instruction("SBC A,D",		null),
            Instruction("SBC A,E",		null),
            Instruction("SBC A,H",		null),
            Instruction("SBC A,L",		null),
            Instruction("SBC A,(HL)",	null),
            Instruction("SBC A,A",		null),
            Instruction("AND B",		null),
            Instruction("AND C",		null),
            Instruction("AND D",		null),
            Instruction("AND E",		null),
            Instruction("AND H",		null),
            Instruction("AND L",		null),
            Instruction("AND (HL)",		null),
            Instruction("AND A",		null),
            Instruction("XOR B",		null),
            Instruction("XOR C",		null),
            Instruction("XOR D",		null),
            Instruction("XOR E",		null),
            Instruction("XOR H",		null),
            Instruction("XOR L",		null),
            Instruction("XOR (HL)",		null),
            Instruction("XOR A",		null),
            Instruction("OR B",		    null),
            Instruction("OR C",		    null),
            Instruction("OR D",		    null),
            Instruction("OR E",		    null),
            Instruction("OR H",		    null),
            Instruction("OR L",		    null),
            Instruction("OR (HL)",		null),
            Instruction("OR A",		    null),
            Instruction("CP B",		    null),
            Instruction("CP C",		    null),
            Instruction("CP D",		    null),
            Instruction("CP E",		    null),
            Instruction("CP H",		    null),
            Instruction("CP L",		    null),
            Instruction("CP (HL)",		null),
            Instruction("CP A",		    null),
            Instruction("RET NZ",		null),
            Instruction("POP BC",		null),
            Instruction("JP NZ,a16",	null),
            Instruction("JP a16",		null),
            Instruction("CALL NZ,a16",	null),
            Instruction("PUSH BC",		null),
            Instruction("ADD A,d8",		&addImmediate),
            Instruction("RST 00H",		null),
            Instruction("RET Z",		null),
            Instruction("RET",		    null),
            Instruction("JP Z,a16",		null),
            Instruction("PREFIX CB",	null),
            Instruction("CALL Z,a16",	null),
            Instruction("CALL a16",		null),
            Instruction("ADC A,d8",		&adcImmediate),
            Instruction("RST 08H",		null),
            Instruction("RET NC",		null),
            Instruction("POP DE",		null),
            Instruction("JP NC,a16",	null),
            Instruction("XX",		    null),
            Instruction("CALL NC,a16",	null),
            Instruction("PUSH DE",		null),
            Instruction("SUB d8",		null),
            Instruction("RST 10H",		null),
            Instruction("RET C",		null),
            Instruction("RETI",		    null),
            Instruction("JP C,a16",		null),
            Instruction("XX",		    null),
            Instruction("CALL C,a16",	null),
            Instruction("XX",		    null),
            Instruction("SBC A,d8",		null),
            Instruction("RST 18H",		null),
            Instruction("LDH (a8),A",	null),
            Instruction("POP HL",		null),
            Instruction("LD (C),A",		null),
            Instruction("XX",		    null),
            Instruction("XX",		    null),
            Instruction("PUSH HL",		null),
            Instruction("AND d8",		null),
            Instruction("RST 20H",		null),
            Instruction("ADD SP,r8",	null),
            Instruction("JP (HL)",		null),
            Instruction("LD (a16),A",	null),
            Instruction("XX",		    null),
            Instruction("XX",		    null),
            Instruction("XX",		    null),
            Instruction("XOR d8",		null),
            Instruction("RST 28H",		null),
            Instruction("LDH A,(a8)",	null),
            Instruction("POP AF",		null),
            Instruction("LD A,(C)",		null),
            Instruction("DI",		    null),
            Instruction("XX",		    null),
            Instruction("PUSH AF",		null),
            Instruction("OR d8",		null),
            Instruction("RST 30H",		null),
            Instruction("LD HL,SP+r8",	null),
            Instruction("LD SP,HL",		null),
            Instruction("LD A,(a16)",	null),
            Instruction("EI",		    null),
            Instruction("XX",		    null),
            Instruction("XX",		    null),
            Instruction("CP d8",		null),
            Instruction("RST 38H",		null),
        ];

        this.mmu = mmu;

        // Initialize like the original bootstrap rom
        regs.sp = 0xFFFE;
        regs.af = 0x01B0;
        regs.bc = 0x0013;
        regs.de = 0x00D8;
        regs.hl = 0x014D;
        regs.pc = 0x0100;
        // TODO the rom disable I/O register at memory address 0xFF50 should be set to 1
    
        regs.sp = 10;
        add(regs.sp, cast(short)(cast(byte)(cast(ubyte)(-5))));
        writeln(regs.sp);
    }

    void step() {
        // Fetch the operation in memory
        ubyte opcode = mmu.readByte(regs.pc);

        Instruction instr = instructions[opcode];
        if(instr.impl == null) {
            throw new Exception(format("Emulated code used unimplemented operation 0x%02X @ 0x%04X", opcode, regs.pc));
        }

        // Increment the program counter
        // Done before instruction execution so that jumps are easier. Pretty sure that's how it's done on real hardware too.
        regs.pc++;

        instr.impl(); // Execute the operation
    }

    /**
     * Sets a flag on the flag register
     */
    private void setFlag(in Flag f, in bool set) { // TODO make compile-time version for static flag setting
        if(set) {
            regs.f = regs.f | f; // ORing with the flag will set it true
        } else {
            regs.f = regs.f & ~f; // ANDing with the inverse of f will set the flag to 0
        }
    }

    /**
     * If a flag is 0 in the flag register, this will make it 1; if it is 1, this will make it 0
     */
    private void toggleFlag(in Flag f) {
        regs.f = regs.f ^ f; // XOR will invert the bits that are set in the input
    }

    /**
     * Check the status of a flag in the f register
     * If the flag is 1, returns true, else returns false
     */
    private bool isFlagSet(in Flag f) {
        return (regs.f & f) != 0;
    }

    /**
     * Do nothing
     */
    private void nop() {}

    /**
     * Load the value from one register into another register
     */
    private void load(ref reg8 dest, in reg8 src) {
        dest = src;
    }

    /**
     * Load the next 8-bit value (after the opcode) into a register
     */
    private void loadImmediate(ref reg8 dest) {
        dest = mmu.readByte(regs.pc);
        regs.pc += 1;
    }

    /**
     * Load the next 16-bit value (after the opcode) into a register
     */
    private void loadImmediate(ref reg16 dest) {
        dest = mmu.readShort(regs.pc);
        regs.pc += 2;
    }

    /**
     * Load the 8-bit value stored in memory at the address stored in register HL into a register
     */
    private void loadReference(ref reg8 dest) {
        dest = mmu.readByte(regs.hl);
    }

    /**
     * Store an 8-bit value into memory at the address stored in register HL
     */
    private void storeInMemory(in reg8 src) {
        mmu.writeByte(regs.hl, src);
    }

    /**
     * Add a 16-bit value to a 16-bit register
     */
    private void add(ref reg16 dst, in ushort src) {
        immutable uint result = dst + src;
        immutable ushort outResult = cast(ushort) result;

        setFlag(Flag.ZERO, outResult == 0); // The result needs to be cast to a ushort so that a overflow by 1 will still be considered 0. TODO check real hardware

        // If the result went outside the rightmost 16 bits, there was overflow
        setFlag(Flag.OVERFLOW, result > 0x0000FFFF);

        // Add the last nibbles of src and dst, and see if it overflows into the next nibble
        setFlag(Flag.HALF_OVERFLOW, ((dst & 0x000F) + (src & 0x000F)) > 0x000F);

        setFlag(Flag.SUBTRACTION, false);

        dst = outResult;
    }

    /**
     * Add the next 8-bit value to the stack pointer
     */
    private void offsetStackPointerImmediate(ref reg8 dst) {
        add(regs.sp, cast(short)(cast(byte)(mmu.readByte(regs.sp)))); // Casting twice is so that the sign will carry over to the short

        regs.pc += 1;
    }

    /**
     * Add a ubyte to register A
     */
    private void add(in ubyte src) {
        immutable ushort result = regs.a + src; // Storing in a short so overflow can be checked
        immutable ubyte outResult = cast(ubyte) result; // The result that actually goes into the output register
        
        setFlag(Flag.ZERO, outResult == 0); // The result needs to be cast to a ubyte so that a overflow by 1 will still be considered 0. TODO check real hardware

        // If the first byte is nonzero, then there was a carry from the 7th bit
        setFlag(Flag.OVERFLOW, result > 0x00FF);

        // Add the last nibbles of the src and dst, and see if it overflows into the leftmost nibble
        setFlag(Flag.HALF_OVERFLOW, ((regs.a & 0x0F) + (src & 0x0F)) > 0x0F);

        setFlag(Flag.SUBTRACTION, false);

        // Result with the extra bits dropped
        regs.a = outResult;
    }

    /**
     * Add the 8-bit value stored in memory at the address stored in register HL to register A
     */
    private void addReference() {
        add(mmu.readByte(regs.hl));
    }

    /**
     * Add the next 8-bit value (after the opcode) to register A
     */
    private void addImmediate() {
        add(mmu.readByte(regs.sp));
        regs.sp++;
    }

    /**
     * Adds ubyte to register A, along with an extra "1" if the carry flag was set.
     *
     * For example, if the carry flag was set before the method call, and the parameter is 5, then 6 is added to A
     */
     private void adc(in ubyte src) {
        // We can't just call add(src + carry) because if the ubyte overflows to 0 when adding carry, the GB's overflow bit won't get set among other problems
        // TODO check what real hardware does

        immutable ubyte c = isFlagSet(Flag.OVERFLOW) ? 1 : 0;
         
        immutable ushort result = regs.a + src + c; // Storing in a short so overflow can be checked
        immutable ubyte outResult = cast(ubyte) result; // The result that actually goes into the output register

        setFlag(Flag.ZERO, outResult == 0); // The result needs to be cast to a ubyte so that a overflow by 1 will still be considered 0. TODO check real hardware

        // If the first byte is nonzero, then there was a carry from the 7th bit
        setFlag(Flag.OVERFLOW, result > 0x00FF);

        // Add the last nibbles of the src, dst, and carry and see if it overflows into the leftmost nibble
        setFlag(Flag.HALF_OVERFLOW, ((regs.a & 0x0F) + (src & 0x0F) + c) > 0x0F);

        setFlag(Flag.SUBTRACTION, false);

        // Result with the extra bits dropped
        regs.a = outResult;
     }

    /**
     * Adc the 8-bit value stored in memory at the address stored in register HL to register A
     */
    private void adcReference() {
        adc(mmu.readByte(regs.hl));
    }

    /**
     * Adc the next 8-bit value (after the opcode) to register A
     */
    private void adcImmediate() {
        adc(mmu.readByte(regs.sp));
        regs.sp++;
    }

}
