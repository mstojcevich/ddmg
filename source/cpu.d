import std.stdio;
import std.format;

import mmu;
import registers;
import instruction;
import clock;

private enum Flag : ubyte {
    ZERO            = 0b10000000, // Set to 1 when the result of an operation is 0
    SUBTRACTION     = 0b01000000, // Set to 1 following the execution of the subtraction instruction
    HALF_OVERFLOW   = 0b00100000, // Set to 1 when an operation carries from or borrows to bit 3
    OVERFLOW        = 0b00010000  // Set to 1 when an operation carries from or borrows to bit 7
}

/**
 * Implementation of the GameBoy CPU
 */
class CPU {

    private Instruction[256] instructions;

    private Registers regs = {};

    private MMU mmu;
    private Clock clk;

    @safe this(MMU mmu, Clock clk) {
        // 0 in the cycle count will mean it's calculated conditionally later
        this.instructions = [
            Instruction("NOP",          4, &nop),
            Instruction("LD BC,d16",    12, {loadImmediate(regs.bc);}),
            Instruction("LD (BC),A",    8, {storeInMemory(regs.bc, regs.a);}),
            Instruction("INC BC",       8, {inc(regs.bc);}),
            Instruction("INC B",        4, {inc(regs.b);}),
            Instruction("DEC B",        4, {dec(regs.b);}),
            Instruction("LD B,d8",      8, {loadImmediate(regs.b);}),
            Instruction("RLCA",         4, &rlca),
            Instruction("LD (a16),SP",  20, {storeInImmediateReference(regs.sp);}),
            Instruction("ADD HL,BC",    8, {add(regs.hl, regs.bc);}),
            Instruction("LD A,(BC)",    8, {loadFromMemory(regs.a, regs.bc);}),
            Instruction("DEC BC",       8, {dec(regs.bc);}),
            Instruction("INC C",        4, {inc(regs.c);}),
            Instruction("DEC C",        4, {dec(regs.c);}),
            Instruction("LD C,d8",      8, {loadImmediate(regs.c);}),
            Instruction("RRCA",         4, &rrca),
            Instruction("STOP 0",       4, null),
            Instruction("LD DE,d16",    12, {loadImmediate(regs.de);}),
            Instruction("LD (DE),A",	8, {storeInMemory(regs.de, regs.a);}),
            Instruction("INC DE",		8, {inc(regs.de);}),
            Instruction("INC D",		4, {inc(regs.d);}),
            Instruction("DEC D",		4, {dec(regs.d);}),
            Instruction("LD D,d8",		8, {loadImmediate(regs.d);}),
            Instruction("RLA",		    4, &rla),
            Instruction("JR r8",		12, &jumpRelativeImmediate),
            Instruction("ADD HL,DE",	8, {add(regs.hl, regs.de);}),
            Instruction("LD A,(DE)",	8, {loadFromMemory(regs.a, regs.de);}),
            Instruction("DEC DE",		8, {dec(regs.de);}),
            Instruction("INC E",		4, {inc(regs.e);}),
            Instruction("DEC E",		4, {dec(regs.e);}),
            Instruction("LD E,d8",		8, {loadImmediate(regs.e);}),
            Instruction("RRA",		    4, &rra),
            Instruction("JR NZ,r8",		0, &jumpRelativeImmediateNZ),
            Instruction("LD HL,d16",	12, {loadImmediate(regs.hl);}),
            Instruction("LD (HL+),A",	8, &storeAInMemoryHLPlus),
            Instruction("INC HL",		8, {inc(regs.hl);}),
            Instruction("INC H",		4, {inc(regs.h);}),
            Instruction("DEC H",		4, {dec(regs.h);}),
            Instruction("LD H,d8",		8, {loadImmediate(regs.h);}),
            Instruction("DAA",		    4, null),
            Instruction("JR Z,r8",		0, &jumpRelativeImmediateZ),
            Instruction("ADD HL,HL",	8, {add(regs.hl, regs.hl);}),
            Instruction("LD A,(HL+)",	8, {loadReferencePlus(regs.a);}),
            Instruction("DEC HL",		8, {dec(regs.hl);}),
            Instruction("INC L",		4, {inc(regs.l);}),
            Instruction("DEC L",		4, {dec(regs.l);}),
            Instruction("LD L,d8",		8, {loadImmediate(regs.l);}),
            Instruction("CPL",		    4, {complement(regs.a);}),
            Instruction("JR NC,r8",		0, &jumpRelativeImmediateNC),
            Instruction("LD SP,d16",	12, {loadImmediate(regs.sp);}),
            Instruction("LD (HL-),A",	8, &storeAInMemoryHLMinus),
            Instruction("INC SP",		8, {inc(regs.sp);}),
            Instruction("INC (HL)",		12, &incReference),
            Instruction("DEC (HL)",		1, &decReference),
            Instruction("LD (HL),d8",	12, {storeImmediateInMemory(regs.hl);}),
            Instruction("SCF",		    4, {setFlag(Flag.OVERFLOW, true);}),
            Instruction("JR C,r8",		0, &jumpRelativeImmediateC),
            Instruction("ADD HL,SP",	8, {add(regs.hl, regs.sp);}),
            Instruction("LD A,(HL-)",	8, {loadReferenceMinus(regs.a);}),
            Instruction("DEC SP",		8, {dec(regs.sp);}),
            Instruction("INC A",		4, {inc(regs.a);}),
            Instruction("DEC A",		4, {dec(regs.a);}),
            Instruction("LD A,d8",		8, {loadImmediate(regs.a);}),
            Instruction("CCF",		    4, {complementFlag(Flag.OVERFLOW);}),
            Instruction("LD B,B",		4, {load(regs.b, regs.b);}),
            Instruction("LD B,C",		4, {load(regs.b, regs.c);}),
            Instruction("LD B,D",		4, {load(regs.b, regs.d);}),
            Instruction("LD B,E",		4, {load(regs.b, regs.e);}),
            Instruction("LD B,H",		4, {load(regs.b, regs.h);}),
            Instruction("LD B,L",		4, {load(regs.b, regs.l);}),
            Instruction("LD B,(HL)",	8, {loadReference(regs.b);}),
            Instruction("LD B,A",		4, {load(regs.b, regs.a);}),
            Instruction("LD C,B",		4, {load(regs.c, regs.b);}),
            Instruction("LD C,C",		4, {load(regs.c, regs.c);}),
            Instruction("LD C,D",		4, {load(regs.c, regs.d);}),
            Instruction("LD C,E",		4, {load(regs.c, regs.e);}),
            Instruction("LD C,H",		4, {load(regs.c, regs.h);}),
            Instruction("LD C,L",		4, {load(regs.c, regs.l);}),
            Instruction("LD C,(HL)",	8, {loadReference(regs.c);}),
            Instruction("LD C,A",		4, {load(regs.c, regs.a);}),
            Instruction("LD D,B",		4, {load(regs.d, regs.b);}),
            Instruction("LD D,C",		4, {load(regs.d, regs.c);}),
            Instruction("LD D,D",		4, {load(regs.d, regs.d);}),
            Instruction("LD D,E",		4, {load(regs.d, regs.e);}),
            Instruction("LD D,H",		4, {load(regs.d, regs.h);}),
            Instruction("LD D,L",		4, {load(regs.d, regs.l);}),
            Instruction("LD D,(HL)",	8, {loadReference(regs.d);}),
            Instruction("LD D,A",		4, {load(regs.d, regs.a);}),
            Instruction("LD E,B",		4, {load(regs.e, regs.b);}),
            Instruction("LD E,C",		4, {load(regs.e, regs.c);}),
            Instruction("LD E,D",		4, {load(regs.e, regs.d);}),
            Instruction("LD E,E",		4, {load(regs.e, regs.e);}),
            Instruction("LD E,H",		4, {load(regs.e, regs.h);}),
            Instruction("LD E,L",		4, {load(regs.e, regs.l);}),
            Instruction("LD E,(HL)",	8, {loadReference(regs.e);}),
            Instruction("LD E,A",		4, {load(regs.e, regs.a);}),
            Instruction("LD H,B",		4, {load(regs.h, regs.b);}),
            Instruction("LD H,C",		4, {load(regs.h, regs.c);}),
            Instruction("LD H,D",		4, {load(regs.h, regs.d);}),
            Instruction("LD H,E",		4, {load(regs.h, regs.e);}),
            Instruction("LD H,H",		4, {load(regs.h, regs.h);}),
            Instruction("LD H,L",		4, {load(regs.h, regs.l);}),
            Instruction("LD H,(HL)",	8, {loadReference(regs.h);}),
            Instruction("LD H,A",		4, {load(regs.h, regs.a);}),
            Instruction("LD L,B",		4, {load(regs.l, regs.b);}),
            Instruction("LD L,C",		4, {load(regs.l, regs.c);}),
            Instruction("LD L,D",		4, {load(regs.l, regs.d);}),
            Instruction("LD L,E",		4, {load(regs.l, regs.e);}),
            Instruction("LD L,H",		4, {load(regs.l, regs.h);}),
            Instruction("LD L,L",		4, {load(regs.l, regs.l);}),
            Instruction("LD L,(HL)",	8, {loadReference(regs.l);}),
            Instruction("LD L,A",		4, {load(regs.l, regs.a);}),
            Instruction("LD (HL),B",	8, {storeInMemory(regs.hl, regs.b);}),
            Instruction("LD (HL),C",	8, {storeInMemory(regs.hl, regs.c);}),
            Instruction("LD (HL),D",	8, {storeInMemory(regs.hl, regs.d);}),
            Instruction("LD (HL),E",	8, {storeInMemory(regs.hl, regs.e);}),
            Instruction("LD (HL),H",	8, {storeInMemory(regs.hl, regs.h);}),
            Instruction("LD (HL),L",	8, {storeInMemory(regs.hl, regs.l);}),
            Instruction("HALT",		    4, null),
            Instruction("LD (HL),A",	8, {storeInMemory(regs.hl, regs.a);}),
            Instruction("LD A,B",		4, {load(regs.a, regs.b);}),
            Instruction("LD A,C",		4, {load(regs.a, regs.c);}),
            Instruction("LD A,D",		4, {load(regs.a, regs.d);}),
            Instruction("LD A,E",		4, {load(regs.a, regs.e);}),
            Instruction("LD A,H",		4, {load(regs.a, regs.h);}),
            Instruction("LD A,L",		4, {load(regs.a, regs.l);}),
            Instruction("LD A,(HL)",	8, {loadReference(regs.a);}),
            Instruction("LD A,A",		4, {load(regs.a, regs.a);}),
            Instruction("ADD A,B",		4, {add(regs.b);}),
            Instruction("ADD A,C",		4, {add(regs.b);}),
            Instruction("ADD A,D",		4, {add(regs.d);}),
            Instruction("ADD A,E",		4, {add(regs.e);}),
            Instruction("ADD A,H",		4, {add(regs.h);}),
            Instruction("ADD A,L",		4, {add(regs.l);}),
            Instruction("ADD A,(HL)",	8, {addReference();}),
            Instruction("ADD A,A",		4, {add(regs.a);}),
            Instruction("ADC A,B",		4, {adc(regs.b);}),
            Instruction("ADC A,C",		4, {adc(regs.c);}),
            Instruction("ADC A,D",		4, {adc(regs.d);}),
            Instruction("ADC A,E",		4, {adc(regs.e);}),
            Instruction("ADC A,H",		4, {adc(regs.h);}),
            Instruction("ADC A,L",		4, {adc(regs.l);}),
            Instruction("ADC A,(HL)",	8, &adcReference),
            Instruction("ADC A,A",		4, {adc(regs.a);}),
            Instruction("SUB B",		4, {sub(regs.b);}),
            Instruction("SUB C",		4, {sub(regs.c);}),
            Instruction("SUB D",		4, {sub(regs.d);}),
            Instruction("SUB E",		4, {sub(regs.e);}),
            Instruction("SUB H",		4, {sub(regs.h);}),
            Instruction("SUB L",		4, {sub(regs.l);}),
            Instruction("SUB (HL)",		8, &subReference),
            Instruction("SUB A",		4, {sub(regs.a);}),
            Instruction("SBC A,B",		4, {sbc(regs.b);}),
            Instruction("SBC A,C",		4, {sbc(regs.c);}),
            Instruction("SBC A,D",		4, {sbc(regs.d);}),
            Instruction("SBC A,E",		4, {sbc(regs.e);}),
            Instruction("SBC A,H",		4, {sbc(regs.h);}),
            Instruction("SBC A,L",		4, {sbc(regs.l);}),
            Instruction("SBC A,(HL)",	8, &sbcReference),
            Instruction("SBC A,A",		4, {sbc(regs.a);}),
            Instruction("AND B",		4, {and(regs.b);}),
            Instruction("AND C",		4, {and(regs.c);}),
            Instruction("AND D",		4, {and(regs.d);}),
            Instruction("AND E",		4, {and(regs.e);}),
            Instruction("AND H",		4, {and(regs.h);}),
            Instruction("AND L",		4, {and(regs.l);}),
            Instruction("AND (HL)",		8, &andReference),
            Instruction("AND A",		4, {and(regs.a);}),
            Instruction("XOR B",		4, {xor(regs.b);}),
            Instruction("XOR C",		4, {xor(regs.c);}),
            Instruction("XOR D",		4, {xor(regs.d);}),
            Instruction("XOR E",		4, {xor(regs.e);}),
            Instruction("XOR H",		4, {xor(regs.h);}),
            Instruction("XOR L",		4, {xor(regs.l);}),
            Instruction("XOR (HL)",		8, &xorReference),
            Instruction("XOR A",		4, {xor(regs.a);}),
            Instruction("OR B",		    4, {or(regs.b);}),
            Instruction("OR C",		    4, {or(regs.c);}),
            Instruction("OR D",		    4, {or(regs.d);}),
            Instruction("OR E",		    4, {or(regs.e);}),
            Instruction("OR H",		    4, {or(regs.h);}),
            Instruction("OR L",		    4, {or(regs.l);}),
            Instruction("OR (HL)",		8, &orReference),
            Instruction("OR A",		    4, {or(regs.a);}),
            Instruction("CP B",		    4, {cp(regs.b);}),
            Instruction("CP C",		    4, {cp(regs.c);}),
            Instruction("CP D",		    4, {cp(regs.d);}),
            Instruction("CP E",		    4, {cp(regs.e);}),
            Instruction("CP H",		    4, {cp(regs.h);}),
            Instruction("CP L",		    4, {cp(regs.l);}),
            Instruction("CP (HL)",		8, &cpReference),
            Instruction("CP A",		    4, {cp(regs.a);}),
            Instruction("RET NZ",		0, {retIfFlag(Flag.ZERO, false);}),
            Instruction("POP BC",		12, {popFromStack(regs.bc);}),
            Instruction("JP NZ,a16",	0, {jumpImmediateIfFlag(Flag.ZERO, false);}),
            Instruction("JP a16",		16, &jumpImmediate),
            Instruction("CALL NZ,a16",	0, {callImmediateIfFlag(Flag.ZERO, false);}),
            Instruction("PUSH BC",		16, {pushToStack(regs.bc);}),
            Instruction("ADD A,d8",		8, &addImmediate),
            Instruction("RST 00H",		16, {rst(0x00);}),
            Instruction("RET Z",		0, {retIfFlag(Flag.ZERO, true);}),
            Instruction("RET",		    16, &ret),
            Instruction("JP Z,a16",		0, {jumpImmediateIfFlag(Flag.ZERO, true);}),
            Instruction("PREFIX CB",	4, null),
            Instruction("CALL Z,a16",	0, {callImmediateIfFlag(Flag.ZERO, true);}),
            Instruction("CALL a16",		24, &callImmediate),
            Instruction("ADC A,d8",		8, &adcImmediate),
            Instruction("RST 08H",		16, {rst(0x08);}),
            Instruction("RET NC",		0, {retIfFlag(Flag.OVERFLOW, false);}),
            Instruction("POP DE",		12, {popFromStack(regs.de);}),
            Instruction("JP NC,a16",	0, {jumpImmediateIfFlag(Flag.OVERFLOW, false);}),
            Instruction("XX",		    0, null),
            Instruction("CALL NC,a16",	0, {callImmediateIfFlag(Flag.OVERFLOW, false);}),
            Instruction("PUSH DE",		16, {pushToStack(regs.de);}),
            Instruction("SUB d8",		8, &subImmediate),
            Instruction("RST 10H",		16, {rst(0x10);}),
            Instruction("RET C",		0, {retIfFlag(Flag.OVERFLOW, true);}),
            Instruction("RETI",		    16, null),
            Instruction("JP C,a16",		0, {jumpImmediateIfFlag(Flag.OVERFLOW, true);}),
            Instruction("XX",		    0, null),
            Instruction("CALL C,a16",	0, {callImmediateIfFlag(Flag.OVERFLOW, true);}),
            Instruction("XX",		    0, null),
            Instruction("SBC A,d8",		8, &sbcImmediate),
            Instruction("RST 18H",		16, {rst(0x18);}),
            Instruction("LDH (a8),A",	12, &ldhAToImmediate),
            Instruction("POP HL",		12, {popFromStack(regs.hl);}),
            Instruction("LD (C),A",		8, &ldCA),
            Instruction("XX",		    0, null),
            Instruction("XX",		    0, null),
            Instruction("PUSH HL",		16, {pushToStack(regs.hl);}),
            Instruction("AND d8",		8, &andImmediate),
            Instruction("RST 20H",		16, {rst(0x20);}),
            Instruction("ADD SP,r8",	16, &offsetStackPointerImmediate),
            Instruction("JP (HL)",		4, &jumpHL),
            Instruction("LD (a16),A",	16, {storeInImmediateReference(regs.a);}),
            Instruction("XX",		    0, null),
            Instruction("XX",		    0, null),
            Instruction("XX",		    0, null),
            Instruction("XOR d8",		8, &xorImmediate),
            Instruction("RST 28H",		16, {rst(0x28);}),
            Instruction("LDH A,(a8)",	12, &ldhImmediateToA),
            Instruction("POP AF",		12, {popFromStack(regs.af);}),
            Instruction("LD A,(C)",		8, &ldAC),
            Instruction("DI",		    4, null),
            Instruction("XX",		    0, null),
            Instruction("PUSH AF",		16, {pushToStack(regs.af);}),
            Instruction("OR d8",		8, &orImmediate),
            Instruction("RST 30H",		16, {rst(0x30);}),
            Instruction("LD HL,SP+r8",	12, &loadSPplusImmediateToHL),
            Instruction("LD SP,HL",		8, {load(regs.sp, regs.hl);}),
            Instruction("LD A,(a16)",	16, {loadFromImmediateReference(regs.a);}),
            Instruction("EI",		    4, null),
            Instruction("XX",		    0, null),
            Instruction("XX",		    0, null),
            Instruction("CP d8",		8, &cpImmediate),
            Instruction("RST 38H",		16, {rst(0x38);}),
        ];

        int totalInstrs = 0;
        int implInstrs = 0;
        foreach(instr; instructions) {
            if(instr.disassembly != "XX") {
                totalInstrs++;

                if(instr.impl != null) {
                    implInstrs++;
                } else {
                    writefln("%s not implemented", instr.disassembly);
                }
            }
        }
        writefln("Initializing CPU with %d%% (%d / %d) regular instruction support", cast(int)((cast(float)implInstrs/totalInstrs)*100), implInstrs, totalInstrs);

        this.mmu = mmu;
        this.clk = clk;

        // Initialize like the original bootstrap rom
        regs.sp = 0xFFFE;
        regs.af = 0x01B0;
        regs.bc = 0x0013;
        regs.de = 0x00D8;
        regs.hl = 0x014D;
        regs.pc = 0x0100;
        // TODO the rom disable I/O register at memory address 0xFF50 should be set to 1
    }

    @safe void step() {
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

    // A debug function for printing the flag statuses
    @safe private void printFlags() {
        writefln("Z = %d, H = %d, N = %d, CY = %d", 
            isFlagSet(Flag.ZERO), isFlagSet(Flag.HALF_OVERFLOW), isFlagSet(Flag.SUBTRACTION), isFlagSet(Flag.OVERFLOW));
    }

    /**
     * Sets a flag on the flag register
     */
    @safe private void setFlag(in Flag f, in bool set) { // TODO make compile-time version for static flag setting
        if(set) {
            regs.f = regs.f | f; // ORing with the flag will set it true
        } else {
            regs.f = regs.f & ~f; // ANDing with the inverse of f will set the flag to 0
        }
    }

    /**
     * If a flag is 0 in the flag register, this will make it 1; if it is 1, this will make it 0
     */
    @safe private void toggleFlag(in Flag f) {
        regs.f = regs.f ^ f; // XOR will invert the bits that are set in the input
    }

    /**
     * Check the status of a flag in the f register
     * If the flag is 1, returns true, else returns false
     */
    @safe private bool isFlagSet(in Flag f) {
        return (regs.f & f) != 0;
    }

    /**
     * Do nothing
     */
    @safe private void nop() {}

    /**
     * Load the value from one register into another register
     */
    @safe private void load(ref reg8 dest, in reg8 src) {
        dest = src;
    }

    /**
     * Load the next 8-bit value (after the opcode) into a register
     */
    @safe private void loadImmediate(ref reg8 dest) {
        dest = mmu.readByte(regs.pc);
        regs.pc += 1;
    }

    /**
     * Load the next 16-bit value (after the opcode) into a register
     */
    @safe private void loadImmediate(ref reg16 dest) {
        dest = mmu.readShort(regs.pc);
        regs.pc += 2;
    }

    /**
     * Load the 8-bit value stored in memory at the address stored in register HL into a register
     */
    @safe private void loadReference(ref reg8 dest) {
        loadFromMemory(dest, regs.hl);
    }

    /**
     * Load the 8-bit value stored in memory at the address stored in register HL,
     * then increment HL
     */
    @safe private void loadReferencePlus(ref reg8 dest) {
        loadFromMemory(dest, regs.hl++);
    }

    /**
     * Load the 8-bit value stored in memory at the address stored in register HL,
     * then decrement HL
     */
    @safe private void loadReferenceMinus(ref reg8 dest) {
        loadFromMemory(dest, regs.hl--);
    }

    /**
     * Load the value from one register into another register
     */
    @safe private void load(ref reg16 dest, in reg16 src) {
        dest = src;
    }

    @safe private void loadSPplusImmediateToHL() {
        setFlag(Flag.ZERO, false);
        setFlag(Flag.SUBTRACTION, false);

        immutable ubyte im = mmu.readByte(regs.pc);
        regs.pc++;

        immutable uint sum = regs.sp + im;
        setFlag(Flag.OVERFLOW, sum > 0xFFFF);

        immutable ushort halfSum = (regs.sp & 0x0F) + (im & 0x0F);
        setFlag(Flag.HALF_OVERFLOW, halfSum > 0x0F);

        regs.hl = cast(ushort) sum;
    }

    /**
     * Store an 8-bit value into memory at the address specified
     */
    @safe private void storeInMemory(in ushort addr, in reg8 src) {
        mmu.writeByte(addr, src);
    }

    /**
     * Store the value of register A into memory at the address in HL,
     * then increment HL
     */
    @safe private void storeAInMemoryHLPlus() {
        storeInMemory(regs.hl++, regs.a);
    }

    /**
     * Store the value of register A into memory at the address in HL,
     * then decrement HL
     */
    @safe private void storeAInMemoryHLMinus() {
        storeInMemory(regs.hl--, regs.a);
    }

    /**
     * Store an 8-bit immediate value into memory at the address specified
     */
    @safe private void storeImmediateInMemory(in ushort addr) {
        storeInMemory(addr, mmu.readByte(regs.pc));
        regs.pc++;
    }

    @safe private void storeInImmediateReference(in reg8 src) {
        storeInMemory(mmu.readShort(regs.pc), src);
        regs.pc += 2;
    }

    @safe private void loadFromMemory(out reg8 dst, in ushort addr) {
        dst = mmu.readByte(addr);
    }

    @safe private void loadFromImmediateReference(out reg8 dst) {
        loadFromMemory(dst, mmu.readShort(regs.pc));
        regs.pc += 2;
    }

    @safe private void storeInMemory(in ushort addr, in reg16 src) {
        mmu.writeShort(addr, src);
    }

    /**
     * Store the value of a 16-bit register at the address specified in the immediate 16-bit address
     */
    @safe private void storeInImmediateReference(in reg16 src) {
        storeInMemory(mmu.readShort(regs.pc), src);
        regs.pc += 2;
    }

    /**
     * Add a 16-bit value to a 16-bit register
     */
    @safe private void add(ref reg16 dst, in ushort src) {
        // TODO is the zero flag actually supposed to be set?

        immutable uint result = dst + src;
        immutable ushort outResult = cast(ushort) result;

        // setFlag(Flag.ZERO, outResult == 0); // The result needs to be cast to a ushort so that a overflow by 1 will still be considered 0. TODO check real hardware

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
    @safe private void offsetStackPointerImmediate() {
        add(regs.sp, cast(short)(cast(byte)(mmu.readByte(regs.sp)))); // Casting twice is so that the sign will carry over to the short

        setFlag(Flag.ZERO, false);

        regs.pc += 1;
    }

    /**
     * Add an 8-bit value to register A
     */
    @safe private void add(in ubyte src) {
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
    @safe unittest { // Unit test for ADD A, n
        CPU c = new CPU(new MMU(), new Clock());

        with(c) {
            // Test 1, 0x3A + 0xC6
            regs.a = 0x3A;
            regs.b = 0xC6;
            add(regs.b);

            assert(regs.a == 0x00);
            assert(isFlagSet(Flag.ZERO));
            assert(isFlagSet(Flag.HALF_OVERFLOW));
            assert(!isFlagSet(Flag.SUBTRACTION));
            assert(isFlagSet(Flag.OVERFLOW));

            // Test 2, 0xFF + 0x33
            regs.a = 0xFF;
            regs.c = 0x33;

            // Set the subtraction flag to make sure it gets reset
            setFlag(Flag.SUBTRACTION, true);

            add(c.regs.c);

            assert(regs.a == 0x32);
            assert(!isFlagSet(Flag.ZERO));
            assert(isFlagSet(Flag.HALF_OVERFLOW));
            assert(!isFlagSet(Flag.SUBTRACTION));
            assert(isFlagSet(Flag.OVERFLOW));
        }
    }

    /**
     * Add the 8-bit value stored in memory at the address stored in register HL to register A
     */
    @safe private void addReference() {
        add(mmu.readByte(regs.hl));
    }

    /**
     * Add the next 8-bit value (after the opcode) to register A
     */
    @safe private void addImmediate() {
        add(mmu.readByte(regs.pc));
        regs.pc++;
    }

    /**
     * Adds ubyte to register A, along with an extra "1" if the carry flag was set.
     *
     * For example, if the carry flag was set before the method call, and the parameter is 5, then 6 is added to A
     */
     @safe private void adc(in ubyte src) {
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
     @safe unittest { // Unit test for ADC A, n
        CPU c = new CPU(new MMU(), new Clock());

        with(c) {
            regs.a = 0xE1;
            regs.b = 0x0F;
            regs.c = 0x3B;
            regs.h = 0x1E;

            setFlag(Flag.OVERFLOW, true);

            adc(regs.b);
            assert(regs.a == 0xF1);
            assert(!isFlagSet(Flag.SUBTRACTION));
            assert(!isFlagSet(Flag.ZERO));
            assert(isFlagSet(Flag.HALF_OVERFLOW));
            assert(!isFlagSet(Flag.OVERFLOW));

            regs.a = 0xE1;
            regs.b = 0x0F;
            regs.c = 0x3B;
            regs.h = 0x1E;

            setFlag(Flag.OVERFLOW, true);

            adc(regs.c);
            assert(regs.a == 0x1D);
            assert(!isFlagSet(Flag.SUBTRACTION));
            assert(!isFlagSet(Flag.ZERO));
            assert(!isFlagSet(Flag.HALF_OVERFLOW));
            assert(isFlagSet(Flag.OVERFLOW));

            regs.a = 0xE1;
            regs.b = 0x0F;
            regs.c = 0x3B;
            regs.h = 0x1E;

            setFlag(Flag.OVERFLOW, true);

            adc(regs.h);
            assert(regs.a == 0x00);
            assert(!isFlagSet(Flag.SUBTRACTION));
            assert(isFlagSet(Flag.ZERO));
            assert(isFlagSet(Flag.HALF_OVERFLOW));
            assert(isFlagSet(Flag.OVERFLOW));
        }
     }

    /**
     * Adc the 8-bit value stored in memory at the address stored in register HL to register A
     */
    @safe private void adcReference() {
        adc(mmu.readByte(regs.hl));
    }

    /**
     * Adc the next 8-bit value (after the opcode) to register A
     */
    @safe private void adcImmediate() {
        adc(mmu.readByte(regs.pc));
        regs.pc++;
    }

    @safe private void sub(ubyte src) {
        setFlag(Flag.SUBTRACTION, true);

        setFlag(Flag.OVERFLOW, src > regs.a); // overflow if reg > a, so subtraction would result in a neg number

        setFlag(Flag.HALF_OVERFLOW, (src & 0x0F) > (regs.a & 0x0F)); // same but for the last nibble

        regs.a -= src;

        setFlag(Flag.ZERO, regs.a == 0);
    }


    /**
     * Subtract the 8-bit value stored in memory at the address stored in register HL from register A
     */
    @safe private void subReference() {
        sub(mmu.readByte(regs.hl));
    }

    /**
     * Subtract the 8-bit immediate value from register A
     */
    @safe private void subImmediate() {
        sub(mmu.readByte(regs.pc));
        regs.pc++;
    }

    @safe private void sbc(ubyte src) {
        // We can't just call sub(src + carry) because if the ubyte overflows to 0 when adding carry, the GB's overflow bit won't get set among other problems
        // TODO check what real hardware does

        immutable ubyte c = isFlagSet(Flag.OVERFLOW) ? 1 : 0;

        immutable ushort subtrahend = src + c;
        
        setFlag(Flag.OVERFLOW, subtrahend > regs.a);

        setFlag(Flag.HALF_OVERFLOW, (subtrahend & 0x0F) > (regs.a & 0x0F));

        setFlag(Flag.SUBTRACTION, true);

        regs.a = cast(ubyte) (regs.a - subtrahend);

        setFlag(Flag.ZERO, regs.a == 0);
    }

    /**
     * SBC the 8-bit value stored in memory at the address stored in register HL from register A
     */
    @safe private void sbcReference() {
        sbc(mmu.readByte(regs.hl));
    }

    /**
     * SBC the 8-bit immediate value from register A
     */
    @safe private void sbcImmediate() {
        sbc(mmu.readByte(regs.pc));
        regs.pc++;
    }

    /**
     * Bitwise and a value with register A and store in register A
     */
    @safe private void and(in ubyte src) {
        regs.a &= src;

        setFlag(Flag.ZERO, regs.a == 0);
        setFlag(Flag.HALF_OVERFLOW, 1);
        setFlag(Flag.SUBTRACTION, 0);
        setFlag(Flag.OVERFLOW, 0);
    }

    @safe private void andReference() {
        and(mmu.readByte(regs.hl));
    }

    @safe private void andImmediate() {
        and(mmu.readByte(regs.pc));
        regs.pc++;
    }

    /**
     * Bitwise xor a value with register A and store in register A
     */
    @safe private void xor(in byte src) {
        regs.a ^= src;
        
        setFlag(Flag.ZERO, regs.a == 0);
        setFlag(Flag.HALF_OVERFLOW, 0);
        setFlag(Flag.SUBTRACTION, 0);
        setFlag(Flag.OVERFLOW, 0);
    }

    @safe private void xorReference() {
        xor(mmu.readByte(regs.hl));
    }

    @safe private void xorImmediate() {
        xor(mmu.readByte(regs.pc));
        regs.pc++;
    }

    /**
     * Bitwise or a value with register A and store in register A
     */
    @safe private void or(in byte src) {
        regs.a |= src;

        setFlag(Flag.ZERO, regs.a == 0);
        setFlag(Flag.HALF_OVERFLOW, 0);
        setFlag(Flag.SUBTRACTION, 0);
        setFlag(Flag.OVERFLOW, 0);
    }

    @safe private void orReference() {
        or(mmu.readByte(regs.hl));
    }

    @safe private void orImmediate() {
        or(mmu.readByte(regs.pc));
        regs.pc++;
    }

    /**
     * Set the flags as if a number was subtracted from A, without actually storing the result of the subtraction
     */
    @safe private void cp(in byte src) {
        setFlag(Flag.ZERO, regs.a == src);
        setFlag(Flag.OVERFLOW, regs.a < src);
        setFlag(Flag.HALF_OVERFLOW, (regs.a & 0x0F) < (src & 0x0F));
        setFlag(Flag.SUBTRACTION, true);
    }

    @safe private void cpReference() {
        cp(mmu.readByte(regs.hl));
    }

    @safe private void cpImmediate() {
        cp(mmu.readByte(regs.pc));
        regs.pc++;
    }
    
    @safe private void inc(ref reg8 reg) {
        setFlag(Flag.SUBTRACTION, true);
        setFlag(Flag.HALF_OVERFLOW, (reg & 0x0F) == 0x0F);
        reg = cast(reg8) (reg + 1);
        setFlag(Flag.ZERO, reg == 0);
    }

    /**
     * Increment the value of the memory pointed at by the address in HL
     */
    @safe private void incReference() {
        ubyte mem = mmu.readByte(regs.hl);
        inc(mem);
        mmu.writeByte(regs.hl, mem);
    }

    @safe private void dec(ref reg8 reg) {
        setFlag(Flag.SUBTRACTION, true);
        setFlag(Flag.HALF_OVERFLOW, (reg & 0x0F) == 0);
        reg = cast(reg8) (reg - 1);
        setFlag(Flag.ZERO, reg == 0);
    }

    /**
     * Decrement the value of the memory pointed at by the address in HL
     */
    @safe private void decReference() {
        ubyte mem = mmu.readByte(regs.hl);
        dec(mem);
        mmu.writeByte(regs.hl, mem);
    }

    @safe private void inc(ref reg16 reg) {
        reg++;
    }

    @safe private void dec(ref reg16 reg) {
        reg--;
    }

    /**
     * Rotate A left, with the previous 8th bit going to both the carry flag
     * and to the new bit 0
     */
    @safe private void rlca() {
        setFlag(Flag.SUBTRACTION, false);
        setFlag(Flag.ZERO, false);
        setFlag(Flag.HALF_OVERFLOW, false);

        immutable bool leftmostBit = regs.a >> 7;

        regs.a = cast(ubyte)((regs.a << 1) + leftmostBit);
        setFlag(Flag.OVERFLOW, leftmostBit);
    }
    @safe unittest {  // Unit tests for RLCA
        CPU c = new CPU(new MMU(), new Clock());
        with(c) {
            regs.a = 0x85;
            setFlag(Flag.OVERFLOW, false);

            rlca();

            assert(regs.a == 0x0B);
            assert(isFlagSet(Flag.OVERFLOW));
            assert(!isFlagSet(Flag.ZERO));
            assert(!isFlagSet(Flag.HALF_OVERFLOW));
            assert(!isFlagSet(Flag.SUBTRACTION));
        }
    }

    /**
     * Rotate A left, with the previous 8th bit going to the carry flag
     * and the previous carry flag going to the new bit 0
     */
    @safe private void rla() {
        setFlag(Flag.SUBTRACTION, false);
        setFlag(Flag.ZERO, false);
        setFlag(Flag.HALF_OVERFLOW, false);

        immutable bool leftmostBit = regs.a >> 7;
        immutable bool carryFlag = isFlagSet(Flag.OVERFLOW);
        
        regs.a = cast(ubyte)((regs.a << 1)) | carryFlag;
        setFlag(Flag.OVERFLOW, leftmostBit);
    }
    @safe unittest {  // Unit tests for RLA
        CPU c = new CPU(new MMU(), new Clock());
        with(c) {
            regs.a = 0x05;
            setFlag(Flag.OVERFLOW, true);

            rla();

            assert(regs.a == 0x0B);
            assert(!isFlagSet(Flag.OVERFLOW));
            assert(!isFlagSet(Flag.ZERO));
            assert(!isFlagSet(Flag.HALF_OVERFLOW));
            assert(!isFlagSet(Flag.SUBTRACTION));
        }
    }

    /**
     * Rotate A right, with the previous 0th bit going to both 
     * the new 8th bit and the carry flag
     */
    @safe private void rrca() {
        setFlag(Flag.SUBTRACTION, false);
        setFlag(Flag.ZERO, false);
        setFlag(Flag.HALF_OVERFLOW, false);

        immutable bool rightmostBit = regs.a & 0b1;

        regs.a = (regs.a >> 1) | (rightmostBit << 7);
        setFlag(Flag.OVERFLOW, rightmostBit);
    }
    @safe unittest {
        CPU c = new CPU(new MMU(), new Clock());
        with(c) {
            regs.a = 0x3B;
            setFlag(Flag.OVERFLOW, false);

            rrca();

            assert(regs.a == 0x9D);
            assert(isFlagSet(Flag.OVERFLOW));
            assert(!isFlagSet(Flag.ZERO));
            assert(!isFlagSet(Flag.HALF_OVERFLOW));
            assert(!isFlagSet(Flag.SUBTRACTION));
        }
    }

    /**
     * Rotate A right, with the carry flag bit going to the new 8th bit
     * and the old 0th bit going to the carry flag
     */
    @safe private void rra() {
        setFlag(Flag.SUBTRACTION, false);
        setFlag(Flag.ZERO, false);
        setFlag(Flag.HALF_OVERFLOW, false);

        immutable bool rightmostBit = regs.a & 0b1;
        immutable bool carryBit = isFlagSet(Flag.OVERFLOW);
        
        regs.a = (regs.a >> 1) | (carryBit << 7);
        setFlag(Flag.OVERFLOW, rightmostBit);
    }
    @safe unittest {
        CPU c = new CPU(new MMU(), new Clock());
        with(c) {
            regs.a = 0x81;
            setFlag(Flag.OVERFLOW, false);

            rra();

            assert(regs.a == 0x40);
            assert(isFlagSet(Flag.OVERFLOW));
            assert(!isFlagSet(Flag.ZERO));
            assert(!isFlagSet(Flag.HALF_OVERFLOW));
            assert(!isFlagSet(Flag.SUBTRACTION));
        }
    }

    @safe private void jumpImmediate() {
        regs.pc = mmu.readShort(regs.pc);
        // No need to increment pc to compensate for the immediate value because we jumped
    }

    /**
     * Jump to the immediate address if the specified flag is set/reset (depending on second parameter)
     */
    @safe private void jumpImmediateIfFlag(in Flag f, in bool set) {
        if(isFlagSet(f) == set) {
            jumpImmediate();

            clk.spendCycles(16);
        } else { // Update PC to account for theoretically reading a 16-bit immediate
            regs.pc += 2;

            clk.spendCycles(12);
        }
    }

    /**
     * Despite the misleading disassembly, this instruction doesn't jump to
     * the address specified by the data referenced by HL,
     * it actually jumps to the address stored in HL
     */
    @safe private void jumpHL() {
        regs.pc = regs.hl;
    }

    /**
     * Add the immediate 8-bit value (interpreted as signed two's complement) to the PC
     */
    @safe private void jumpRelativeImmediate() {
        // Double cast to force a sign extension on the unsigned value
        regs.pc += cast(short)(cast(byte)(mmu.readByte(regs.pc)));
    }

    /**
     * JR if the zero flag is set
     */
    @safe private void jumpRelativeImmediateZ() {
        if(isFlagSet(Flag.ZERO)) {
            jumpRelativeImmediate();
        } else { // Update PC to account for theoretically reading an 8-bit immediate
            regs.pc += 1;
        }
    }

    /**
     * JR if the zero flag is not set
     */
    @safe private void jumpRelativeImmediateNZ() {
        if(!isFlagSet(Flag.ZERO)) {
            jumpRelativeImmediate();
        } else { // Update PC to account for theoretically reading an 8-bit immediate
            regs.pc += 1;
        }
    }

    /**
     * JR if the carry flag is set
     */
    @safe private void jumpRelativeImmediateC() {
        if(isFlagSet(Flag.OVERFLOW)) {
            jumpRelativeImmediate();
        } else { // Update PC to account for theoretically reading an 8-bit immediate
            regs.pc += 1;
        }
    }

    /**
     * JR if the carry flag is not set
     */
    @safe private void jumpRelativeImmediateNC() {
        if(!isFlagSet(Flag.OVERFLOW)) {
            jumpRelativeImmediate();
        } else { // Update PC to account for theoretically reading an 8-bit immediate
            regs.pc += 1;
        }
    }

    /**
     * Calculate the one's complement of the register
     * and store it in itself
     */
    @safe private void complement(ref reg8 src) {
        src = ~src;
    }

    /**
     * Invert the specified flag in the flags register
     */
    @safe private void complementFlag(in Flag f) {
        // You look really nice today Ms. Carry

        toggleFlag(f);
    }

    /**
     * Decrement the stack pointer by 2, then write a 16-bit value to the stack
     */
    @safe private void pushToStack(in ushort src) {
        regs.sp -= 2;
        mmu.writeShort(regs.sp, src);
    }

    /**
     * Read a 16-bit value from the stack into a register, then increment the stack pointer by 2
     */
    @safe private void popFromStack(out reg16 dest) {
        dest = mmu.readShort(regs.sp);
        regs.sp += 2;
    }

    /**
     * Load the content of register A to the memory location at FF00 + (value of register C)
     */
    @safe private void ldCA() {
        storeInMemory(0xFF00 + regs.c, regs.a);
    }

    /**
     * Load the content at memory location FF00 + (value of register C) to register A
     */
    @safe private void ldAC() {
        loadFromMemory(regs.a, 0xFF00 + regs.c);
    }

    /**
     * Load the value in memory at FF00 + (8-bit immediate) to register A
     */
    @safe private void ldhImmediateToA() {
        loadFromMemory(regs.a, 0xFF00 + mmu.readByte(regs.pc));
        regs.pc++;
    }

    /**
     * Save the value in register A to memory at FF00 + (8-bit immediate)
     */
    @safe private void ldhAToImmediate() {
        storeInMemory(0xFF00 + mmu.readByte(regs.pc), regs.a);
        regs.pc++;
    }

    /**
     * Push the current PC to the stack, then jump to 0000 + addr
     */
    @safe private void rst(ubyte addr) {
        pushToStack(regs.pc);
        regs.pc = addr;
    }

    /**
     * Push the current PC to the stack, then jump to addr
     */
    @safe private void call(in ushort addr) {
        pushToStack(regs.pc);
        regs.pc = addr;
    }

    /**
     * Push the PC of the next instruction to the stack, then jump to 16-bit immediate address
     */
    @safe private void callImmediate() {
        immutable ushort toCall = mmu.readShort(regs.pc);
        regs.pc += 2; // Compensate for reading and immediate short
        call(toCall);
    }

    /**
     * Call an immediate 16-bit value if the specified flag is set/reset (depending on second argument)
     */
    @safe private void callImmediateIfFlag(in Flag f, in bool set) {
        if(isFlagSet(f) == set) {
            callImmediate();

            clk.spendCycles(24);
        } else {
            regs.pc += 2; // Compensate for theoretically reading an immediate short
            
            clk.spendCycles(12);
        }
    }

    /**
     * Pop 16 bits from the stack and jump to that address
     */
    @safe private void ret() {
        popFromStack(regs.pc);
    }

    /**
     * RET if the specified flag is set/reset (depending on the second parameter)
     */
    @safe private void retIfFlag(in Flag f, in bool set) {
        if(isFlagSet(f) == set) {
            ret();

            clk.spendCycles(20);
        } else {
            clk.spendCycles(8);
        }
    }

    // TODO use function templates for the functions that are the same between reg8 and reg16

}
