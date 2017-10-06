module cpu.cpu;

import std.stdio;
import std.format;
import std.exception;
import std.traits;

import core.bitop;

import mmu;
import cpu.registers;
import cpu.instruction;
import cartridge;
import graphics;
import interrupt;
import keypad;
import cpu.cb;
import bus;

/**
 * The type of halt the CPU is in
 * This differs based on conditions when the HALT instruction was run
 */
enum HaltMode {
    NO_HALT,
    NORMAL,
    NO_INTERRUPT_JUMP,
    HALT_BUG
}

/**
 * Implementation of the GameBoy CPU
 */
class CPU {

    private Instruction[256] instructions;

    private Registers regs = new Registers();

    private MMU mmu;
    private Bus bus;
    private InterruptHandler iuptHandler;
	private CB cbBlock;

    // Whether the CPU is halted (not executing until interrupt)
    private HaltMode haltMode;

    @safe this(MMU mmu, Bus bus, InterruptHandler ih) {
        this.mmu = mmu;
        this.bus = bus;
        this.iuptHandler = ih;
		this.cbBlock = new CB(regs, mmu, bus);

        // 0 in the cycle count will mean it's calculated conditionally later
        this.instructions = [
            Instruction("NOP",          &nop),
            Instruction("LD BC,d16",    {loadImmediate(regs.bc);}),
            Instruction("LD (BC),A",    {storeInMemory(regs.bc, regs.a);}),
            Instruction("INC BC",       {inc(regs.bc);}),
            Instruction("INC B",        {inc(regs.b);}),
            Instruction("DEC B",        {dec(regs.b);}),
            Instruction("LD B,d8",      {loadImmediate(regs.b);}),
            Instruction("RLCA",         &rlca),
            Instruction("LD (a16),SP",  {storeInImmediateReference(regs.sp);}),
            Instruction("ADD HL,BC",    {add(regs.hl, regs.bc);}),
            Instruction("LD A,(BC)",    {loadFromMemory(regs.a, regs.bc);}),
            Instruction("DEC BC",       {dec(regs.bc);}),
            Instruction("INC C",        {inc(regs.c);}),
            Instruction("DEC C",        {dec(regs.c);}),
            Instruction("LD C,d8",      {loadImmediate(regs.c);}),
            Instruction("RRCA",         &rrca),
            Instruction("STOP 0",       null),
            Instruction("LD DE,d16",    {loadImmediate(regs.de);}),
            Instruction("LD (DE),A",	{storeInMemory(regs.de, regs.a);}),
            Instruction("INC DE",		{inc(regs.de);}),
            Instruction("INC D",		{inc(regs.d);}),
            Instruction("DEC D",		{dec(regs.d);}),
            Instruction("LD D,d8",		{loadImmediate(regs.d);}),
            Instruction("RLA",		    &rla),
            Instruction("JR r8",		&jumpRelativeImmediate),
            Instruction("ADD HL,DE",	{add(regs.hl, regs.de);}),
            Instruction("LD A,(DE)",	{loadFromMemory(regs.a, regs.de);}),
            Instruction("DEC DE",		{dec(regs.de);}),
            Instruction("INC E",		{inc(regs.e);}),
            Instruction("DEC E",		{dec(regs.e);}),
            Instruction("LD E,d8",		{loadImmediate(regs.e);}),
            Instruction("RRA",		    &rra),
            Instruction("JR NZ,r8",		{jumpRelativeImmediateIfFlag(Flag.ZERO, false);}),
            Instruction("LD HL,d16",	{loadImmediate(regs.hl);}),
            Instruction("LD (HL+),A",	&storeAInMemoryHLPlus),
            Instruction("INC HL",		{inc(regs.hl);}),
            Instruction("INC H",		{inc(regs.h);}),
            Instruction("DEC H",		{dec(regs.h);}),
            Instruction("LD H,d8",		{loadImmediate(regs.h);}),
            Instruction("DAA",		    &daa),
            Instruction("JR Z,r8",		{jumpRelativeImmediateIfFlag(Flag.ZERO, true);}),
            Instruction("ADD HL,HL",	{add(regs.hl, regs.hl);}),
            Instruction("LD A,(HL+)",	{loadReferencePlus(regs.a);}),
            Instruction("DEC HL",		{dec(regs.hl);}),
            Instruction("INC L",		{inc(regs.l);}),
            Instruction("DEC L",		{dec(regs.l);}),
            Instruction("LD L,d8",		{loadImmediate(regs.l);}),
            Instruction("CPL",		    {complement(regs.a);}),
            Instruction("JR NC,r8",		{jumpRelativeImmediateIfFlag(Flag.OVERFLOW, false);}),
            Instruction("LD SP,d16",	{loadImmediate(regs.sp);}),
            Instruction("LD (HL-),A",	&storeAInMemoryHLMinus),
            Instruction("INC SP",	    {inc(regs.sp);}),
            Instruction("INC (HL)",		&incReference),
            Instruction("DEC (HL)",		&decReference),
            Instruction("LD (HL),d8",	{storeImmediateInMemory(regs.hl);}),
            Instruction("SCF",		    &scf),
            Instruction("JR C,r8",		{jumpRelativeImmediateIfFlag(Flag.OVERFLOW, true);}),
            Instruction("ADD HL,SP",	{add(regs.hl, regs.sp);}),
            Instruction("LD A,(HL-)",	{loadReferenceMinus(regs.a);}),
            Instruction("DEC SP",		{dec(regs.sp);}),
            Instruction("INC A",		{inc(regs.a);}),
            Instruction("DEC A",		{dec(regs.a);}),
            Instruction("LD A,d8",		{loadImmediate(regs.a);}),
            Instruction("CCF",		    {complementFlag(Flag.OVERFLOW);}),
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
            Instruction("LD (HL),B",	{storeInMemory(regs.hl, regs.b);}),
            Instruction("LD (HL),C",	{storeInMemory(regs.hl, regs.c);}),
            Instruction("LD (HL),D",	{storeInMemory(regs.hl, regs.d);}),
            Instruction("LD (HL),E",	{storeInMemory(regs.hl, regs.e);}),
            Instruction("LD (HL),H",	{storeInMemory(regs.hl, regs.h);}),
            Instruction("LD (HL),L",	{storeInMemory(regs.hl, regs.l);}),
            Instruction("HALT",		    &halt),
            Instruction("LD (HL),A",	{storeInMemory(regs.hl, regs.a);}),
            Instruction("LD A,B",		{load(regs.a, regs.b);}),
            Instruction("LD A,C",		{load(regs.a, regs.c);}),
            Instruction("LD A,D",		{load(regs.a, regs.d);}),
            Instruction("LD A,E",		{load(regs.a, regs.e);}),
            Instruction("LD A,H",		{load(regs.a, regs.h);}),
            Instruction("LD A,L",		{load(regs.a, regs.l);}),
            Instruction("LD A,(HL)",	{loadReference(regs.a);}),
            Instruction("LD A,A",		{load(regs.a, regs.a);}),
            Instruction("ADD A,B",		{add(regs.b);}),
            Instruction("ADD A,C",		{add(regs.c);}),
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
            Instruction("SUB B",		{sub(regs.b);}),
            Instruction("SUB C",		{sub(regs.c);}),
            Instruction("SUB D",		{sub(regs.d);}),
            Instruction("SUB E",		{sub(regs.e);}),
            Instruction("SUB H",		{sub(regs.h);}),
            Instruction("SUB L",		{sub(regs.l);}),
            Instruction("SUB (HL)",		&subReference),
            Instruction("SUB A",		{sub(regs.a);}),
            Instruction("SBC A,B",		{sbc(regs.b);}),
            Instruction("SBC A,C",		{sbc(regs.c);}),
            Instruction("SBC A,D",		{sbc(regs.d);}),
            Instruction("SBC A,E",		{sbc(regs.e);}),
            Instruction("SBC A,H",		{sbc(regs.h);}),
            Instruction("SBC A,L",		{sbc(regs.l);}),
            Instruction("SBC A,(HL)",	&sbcReference),
            Instruction("SBC A,A",		{sbc(regs.a);}),
            Instruction("AND B",		{and(regs.b);}),
            Instruction("AND C",		{and(regs.c);}),
            Instruction("AND D",		{and(regs.d);}),
            Instruction("AND E",		{and(regs.e);}),
            Instruction("AND H",		{and(regs.h);}),
            Instruction("AND L",		{and(regs.l);}),
            Instruction("AND (HL)",		&andReference),
            Instruction("AND A",		{and(regs.a);}),
            Instruction("XOR B",		{xor(regs.b);}),
            Instruction("XOR C",		{xor(regs.c);}),
            Instruction("XOR D",		{xor(regs.d);}),
            Instruction("XOR E",		{xor(regs.e);}),
            Instruction("XOR H",		{xor(regs.h);}),
            Instruction("XOR L",		{xor(regs.l);}),
            Instruction("XOR (HL)",		&xorReference),
            Instruction("XOR A",		{xor(regs.a);}),
            Instruction("OR B",		    {or(regs.b);}),
            Instruction("OR C",		    {or(regs.c);}),
            Instruction("OR D",		    {or(regs.d);}),
            Instruction("OR E",		    {or(regs.e);}),
            Instruction("OR H",		    {or(regs.h);}),
            Instruction("OR L",		    {or(regs.l);}),
            Instruction("OR (HL)",		&orReference),
            Instruction("OR A",		    {or(regs.a);}),
            Instruction("CP B",		    {cp(regs.b);}),
            Instruction("CP C",		    {cp(regs.c);}),
            Instruction("CP D",		    {cp(regs.d);}),
            Instruction("CP E",		    {cp(regs.e);}),
            Instruction("CP H",		    {cp(regs.h);}),
            Instruction("CP L",		    {cp(regs.l);}),
            Instruction("CP (HL)",		&cpReference),
            Instruction("CP A",		    {cp(regs.a);}),
            Instruction("RET NZ",		{retIfFlag(Flag.ZERO, false);}),
            Instruction("POP BC",		{popFromStack(regs.bc);}),
            Instruction("JP NZ,a16",	{jumpImmediateIfFlag(Flag.ZERO, false);}),
            Instruction("JP a16",		&jumpImmediate),
            Instruction("CALL NZ,a16",	{callImmediateIfFlag(Flag.ZERO, false);}),
            Instruction("PUSH BC",		{pushToStack(regs.bc);}),
            Instruction("ADD A,d8",		&addImmediate),
            Instruction("RST 00H",		{rst(0x00);}),
            Instruction("RET Z",		{retIfFlag(Flag.ZERO, true);}),
            Instruction("RET",		    &ret),
            Instruction("JP Z,a16",		{jumpImmediateIfFlag(Flag.ZERO, true);}),
            Instruction("PREFIX CB",	&cb),
            Instruction("CALL Z,a16",	{callImmediateIfFlag(Flag.ZERO, true);}),
            Instruction("CALL a16",		&callImmediate),
            Instruction("ADC A,d8",		&adcImmediate),
            Instruction("RST 08H",		{rst(0x08);}),
            Instruction("RET NC",		{retIfFlag(Flag.OVERFLOW, false);}),
            Instruction("POP DE",		{popFromStack(regs.de);}),
            Instruction("JP NC,a16",	{jumpImmediateIfFlag(Flag.OVERFLOW, false);}),
            Instruction("XX",		    null),
            Instruction("CALL NC,a16",	{callImmediateIfFlag(Flag.OVERFLOW, false);}),
            Instruction("PUSH DE",		{pushToStack(regs.de);}),
            Instruction("SUB d8",		&subImmediate),
            Instruction("RST 10H",		{rst(0x10);}),
            Instruction("RET C",		{retIfFlag(Flag.OVERFLOW, true);}),
            Instruction("RETI",		    {ret(); iuptHandler.masterToggle = true;}),
            Instruction("JP C,a16",		{jumpImmediateIfFlag(Flag.OVERFLOW, true);}),
            Instruction("XX",		    null),
            Instruction("CALL C,a16",	{callImmediateIfFlag(Flag.OVERFLOW, true);}),
            Instruction("XX",		    null),
            Instruction("SBC A,d8",		&sbcImmediate),
            Instruction("RST 18H",		{rst(0x18);}),
            Instruction("LDH (a8),A",	&ldhAToImmediate),
            Instruction("POP HL",		{popFromStack(regs.hl);}),
            Instruction("LD (C),A",		&ldCA),
            Instruction("XX",		    null),
            Instruction("XX",		    null),
            Instruction("PUSH HL",		{pushToStack(regs.hl);}),
            Instruction("AND d8",		&andImmediate),
            Instruction("RST 20H",		{rst(0x20);}),
            Instruction("ADD SP,r8",	&offsetStackPointerImmediate),
            Instruction("JP (HL)",		&jumpHL),
            Instruction("LD (a16),A",	{storeInImmediateReference(regs.a);}),
            Instruction("XX",		    null),
            Instruction("XX",		    null),
            Instruction("XX",		    null),
            Instruction("XOR d8",		&xorImmediate),
            Instruction("RST 28H",		{rst(0x28);}),
            Instruction("LDH A,(a8)",	&ldhImmediateToA),
            Instruction("POP AF",		{
                popFromStack(regs.af);
                regs.f &= 0b11110000; // The last 4 bits cannot be written to and should be forced 0
            }),
            Instruction("LD A,(C)",		&ldAC),
            Instruction("DI",		    {iuptHandler.masterToggle = false;}),
            Instruction("XX",		    null),
            Instruction("PUSH AF",		{pushToStack(regs.af);}),
            Instruction("OR d8",		&orImmediate),
            Instruction("RST 30H",		{rst(0x30);}),
            Instruction("LD HL,SP+r8",	&loadSPplusImmediateToHL),
            Instruction("LD SP,HL",		{load(regs.sp, regs.hl);}),
            Instruction("LD A,(a16)",	{loadFromImmediateReference(regs.a);}),
            Instruction("EI",		    {iuptHandler.masterToggle = true;}),
            Instruction("XX",		    null),
            Instruction("XX",		    null),
            Instruction("CP d8",		&cpImmediate),
            Instruction("RST 38H",		{rst(0x38);}),
        ];

        int totalInstrs = 0;
        int implInstrs = 0;
        foreach(instr; instructions) {
            if(instr.disassembly != "XX") {
                totalInstrs++;

                if(instr.impl !is null) {
                    implInstrs++;
                } else {
                    writefln("%s not implemented", instr.disassembly);
                }
            }
        }
        writefln("Initializing CPU with %d%% (%d / %d) regular instruction support", cast(int)((cast(float)implInstrs/totalInstrs)*100), implInstrs, totalInstrs);

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
        if(haltMode == HaltMode.NO_HALT || haltMode == HaltMode.HALT_BUG) { // If the CPU is halted, stop execution
            // Fetch the operation in memory
            immutable ubyte opcode = mmu.readByte(regs.pc);

            Instruction instr = instructions[opcode];

            if(false) {
                writefln("A: %02X\tF: %02X\tB: %02X\tC: %02X\tD: %02X\tE: %02X\tH: %02X\tL: %02X", regs.a, regs.f, regs.b, regs.c, regs.d, regs.e, regs.h, regs.l);
                writefln("PC: %04X\tSP: %04X", regs.pc, regs.sp);
                writefln("@ %04X: %02X -> %s", regs.pc, opcode, instr.disassembly);
                writeln();
            }

            //enforce(instr.impl !is null,
            //    format("Emulated code used unimplemented operation 0x%02X @ 0x%04X", opcode, regs.pc));

            // Increment the program counter
            // Done before instruction execution so that jumps are easier. Pretty sure that's how it's done on real hardware too.
            if(haltMode != HaltMode.HALT_BUG) { // The halt bug causes the next instruction to repeat twice
                regs.pc++;
            } else {
                haltMode = HaltMode.NO_HALT;
            }

            if(instr.impl !is null) {
                try {
                    bus.update(4); // Decode

                    instr.impl(); // Execute the operation
                } catch (Exception e) {
                    writefln("Instruction failed with exception \"%s\"", e.msg);
                    writefln("A: %02X\tF: %02X\tB: %02X\tC: %02X\tD: %02X\tE: %02X\tH: %02X\tL: %02X", regs.a, regs.f, regs.b, regs.c, regs.d, regs.e, regs.h, regs.l);
                    writefln("PC: %04X\tSP: %04X", regs.pc, regs.sp);
                    writefln("@ %04X: %02X -> %s", regs.pc, opcode, instr.disassembly);
                    writeln();

                    throw e;
                }
            } else {
                writefln("Program tried to execute instruction %s at %02X, which isn't defined", instr.disassembly, regs.pc - 1);
                writefln("The execution is probably tainted");
            }
        } else { // halted
            // TODO how many cycles??
            // Does this need to be a separate clock?
           bus.update(4);
        }

        // TODO move everything from here on down in this fucntion
        // to its own interrupthandler method
        
        // Handle any interrupts that were triggered
        foreach(iupt; EnumMembers!Interrupts) {
            if(iuptHandler.shouldHandle(iupt)) {
                if(haltMode != HaltMode.NO_INTERRUPT_JUMP) {
                    call(iupt.address);
                    iuptHandler.markHandled(iupt);
                    iuptHandler.masterToggle = false;

                    // It takes 20 clocks to dispatch an interrupt. 8 if you account for the CALL 
                    bus.update(8);

                    if(haltMode == HaltMode.NORMAL) {
                        // If the CPU is in HALT mode, another 4 clocks are needed
                        bus.update(4);
                        haltMode = HaltMode.NO_HALT;
                    }
                } else {
                    // No interrupt jump halt mode continues execution but doesn't handle the interrupt
                    haltMode = HaltMode.NO_HALT;
                    iuptHandler.masterToggle = false;
                }

                break;
            }
        }
    }

    // A debug function for printing the flag statuses
    @safe private void printFlags() {
        writefln("Z = %d, H = %d, N = %d, CY = %d", 
            regs.isFlagSet(Flag.ZERO), regs.isFlagSet(Flag.HALF_OVERFLOW), regs.isFlagSet(Flag.SUBTRACTION), regs.isFlagSet(Flag.OVERFLOW));
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
        dest = readByte(regs.pc);
        regs.pc += 1;
    }

    /**
     * Load the next 16-bit value (after the opcode) into a register
     */
    @safe private void loadImmediate(ref reg16 dest) {
        readShort(regs.pc, dest);
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

        bus.update(4);
    }

    @safe private void loadSPplusImmediateToHL() {
        regs.setFlag(Flag.ZERO, false);
        regs.setFlag(Flag.SUBTRACTION, false);

        immutable ubyte im = readByte(regs.pc);
        regs.pc++;

        // lots of casts for sign extension
        immutable uint sum = regs.sp + cast(ushort)(cast(short)(cast(byte)(im)));
        regs.setFlag(Flag.OVERFLOW, (im + (regs.sp & 0xFF)) > 0xFF);

        immutable ushort halfSum = (regs.sp & 0x0F) + (im & 0x0F);
        regs.setFlag(Flag.HALF_OVERFLOW, halfSum > 0x0F);

        regs.hl = cast(ushort) sum;

        bus.update(4); // Not sure where these come from
    }

    /**
     * Store an 8-bit value into memory at the address specified
     */
    @safe private void storeInMemory(in ushort addr, in reg8 src) {
        writeByte(addr, src);
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
        storeInMemory(addr, readByte(regs.pc));
        regs.pc++;
    }

    @safe private void storeInImmediateReference(in reg8 src) {
        // TODO timing
        ushort storeAddr;
        readShort(regs.pc, storeAddr);
        storeInMemory(storeAddr, src);
        regs.pc += 2;
    }

    @safe private void loadFromMemory(out reg8 dst, in ushort addr) {
        dst = readByte(addr);
    }

    @safe private void loadFromImmediateReference(out reg8 dst) {
        ushort loadAddr;
        readShort(regs.pc, loadAddr);
        loadFromMemory(dst, loadAddr);
        regs.pc += 2;
    }

    @safe private void storeInMemory(in ushort addr, in reg16 src) {
        writeShort(addr, src);
    }

    /**
     * Store the value of a 16-bit register at the address specified in the immediate 16-bit address
     */
    @safe private void storeInImmediateReference(in reg16 src) {
        ushort toStore;
        readShort(regs.pc, toStore);
        storeInMemory(toStore, src);
        regs.pc += 2;
    }

    /**
     * Add a 16-bit value to a 16-bit register
     */
    @safe private void add(ref reg16 dst, in ushort src) {
        immutable uint result = dst + src;
        immutable ushort outResult = cast(ushort) result;

        // If the result went outside the rightmost 16 bits, there was overflow
        regs.setFlag(Flag.OVERFLOW, result > 0x0000FFFF);

        // Half overflow acts kind of unexpected here and checks the overflow onto the 12th bit
        regs.setFlag(Flag.HALF_OVERFLOW, ((dst & 0x0FFF) + (src & 0x0FFF)) > 0x0FFF);

        regs.setFlag(Flag.SUBTRACTION, false);

        dst = outResult;

        bus.update(4); // 16-bit math takes time. Not sure where this goes.
    }

    /**
     * Add the next 8-bit value to the stack pointer
     */
    @safe private void offsetStackPointerImmediate() {
        immutable short toAdd = cast(short)(cast(byte)(readByte(regs.pc)));
        regs.pc += 1;

        immutable ushort result = cast(ushort)(regs.sp + toAdd);

        regs.setFlag(Flag.OVERFLOW, ((toAdd & 0xFF) + (regs.sp & 0xFF)) > 0xFF);
        regs.setFlag(Flag.HALF_OVERFLOW, ((toAdd & 0xF) + (regs.sp & 0xF)) > 0xF);

        regs.sp = result;

        regs.setFlag(Flag.ZERO, false);
        regs.setFlag(Flag.SUBTRACTION, false);
        
        bus.update(8); // No idea where these come from
    }

    /**
     * Add an 8-bit value to register A
     */
    @safe private void add(in ubyte src) {
        immutable ushort result = regs.a + src; // Storing in a short so overflow can be checked
        immutable ubyte outResult = cast(ubyte) result; // The result that actually goes into the output register
        
        regs.setFlag(Flag.ZERO, outResult == 0); // The result needs to be cast to a ubyte so that a overflow by 1 will still be considered 0. TODO check real hardware

        // If the first byte is nonzero, then there was a carry from the 7th bit
        regs.setFlag(Flag.OVERFLOW, result > 0x00FF);

        // Add the last nibbles of the src and dst, and see if it overflows into the leftmost nibble
        regs.setFlag(Flag.HALF_OVERFLOW, ((regs.a & 0x0F) + (src & 0x0F)) > 0x0F);

        regs.setFlag(Flag.SUBTRACTION, false);

        // Result with the extra bits dropped
        regs.a = outResult;
    }
    
    /**
     * Add the 8-bit value stored in memory at the address stored in register HL to register A
     */
    @safe private void addReference() {
        add(readByte(regs.hl));
    }

    /**
     * Add the next 8-bit value (after the opcode) to register A
     */
    @safe private void addImmediate() {
        add(readByte(regs.pc));
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

        immutable ubyte c = regs.isFlagSet(Flag.OVERFLOW) ? 1 : 0;
         
        immutable ushort result = regs.a + src + c; // Storing in a short so overflow can be checked
        immutable ubyte outResult = cast(ubyte) result; // The result that actually goes into the output register

        regs.setFlag(Flag.ZERO, outResult == 0); // The result needs to be cast to a ubyte so that a overflow by 1 will still be considered 0. TODO check real hardware

        // If the first byte is nonzero, then there was a carry from the 7th bit
        regs.setFlag(Flag.OVERFLOW, result > 0x00FF);

        // Add the last nibbles of the src, dst, and carry and see if it overflows into the leftmost nibble
        regs.setFlag(Flag.HALF_OVERFLOW, ((regs.a & 0x0F) + (src & 0x0F) + c) > 0x0F);

        regs.setFlag(Flag.SUBTRACTION, false);

        // Result with the extra bits dropped
        regs.a = outResult;
     }
     
    /**
     * Adc the 8-bit value stored in memory at the address stored in register HL to register A
     */
    @safe private void adcReference() {
        adc(readByte(regs.hl));
    }

    /**
     * Adc the next 8-bit value (after the opcode) to register A
     */
    @safe private void adcImmediate() {
        adc(readByte(regs.pc));
        regs.pc++;
    }

    @safe private void sub(ubyte src) {
        regs.setFlag(Flag.SUBTRACTION, true);

        regs.setFlag(Flag.OVERFLOW, src > regs.a); // overflow if reg > a, so subtraction would result in a neg number

        regs.setFlag(Flag.HALF_OVERFLOW, (src & 0x0F) > (regs.a & 0x0F)); // same but for the last nibble

        regs.a -= src;

        regs.setFlag(Flag.ZERO, regs.a == 0);
    }


    /**
     * Subtract the 8-bit value stored in memory at the address stored in register HL from register A
     */
    @safe private void subReference() {
        sub(readByte(regs.hl));
    }

    /**
     * Subtract the 8-bit immediate value from register A
     */
    @safe private void subImmediate() {
        sub(readByte(regs.pc));
        regs.pc++;
    }

    @safe private void sbc(ubyte src) {
        // We can't just call sub(src + carry) because if the ubyte overflows to 0 when adding carry, the GB's overflow bit won't get set among other problems

        immutable ubyte c = regs.isFlagSet(Flag.OVERFLOW) ? 1 : 0;

        immutable ushort subtrahend = src + c;
        
        regs.setFlag(Flag.OVERFLOW, subtrahend > regs.a);

        regs.setFlag(Flag.HALF_OVERFLOW, ((src & 0x0F) + c) > (regs.a & 0x0F));

        regs.setFlag(Flag.SUBTRACTION, true);

        regs.a = cast(ubyte) (regs.a - subtrahend);

        regs.setFlag(Flag.ZERO, regs.a == 0);
    }

    /**
     * SBC the 8-bit value stored in memory at the address stored in register HL from register A
     */
    @safe private void sbcReference() {
        sbc(readByte(regs.hl));
    }

    /**
     * SBC the 8-bit immediate value from register A
     */
    @safe private void sbcImmediate() {
        sbc(readByte(regs.pc));
        regs.pc++;
    }

    /**
     * Bitwise and a value with register A and store in register A
     */
    @safe private void and(in ubyte src) {
        regs.a &= src;

        regs.setFlag(Flag.ZERO, regs.a == 0);
        regs.setFlag(Flag.HALF_OVERFLOW, 1);
        regs.setFlag(Flag.SUBTRACTION, 0);
        regs.setFlag(Flag.OVERFLOW, 0);
    }

    @safe private void andReference() {
        and(readByte(regs.hl));
    }

    @safe private void andImmediate() {
        and(readByte(regs.pc));
        regs.pc++;
    }

    /**
     * Bitwise xor a value with register A and store in register A
     */
    @safe private void xor(in ubyte src) {
        regs.a ^= src;
        
        regs.setFlag(Flag.ZERO, regs.a == 0);
        regs.setFlag(Flag.HALF_OVERFLOW, 0);
        regs.setFlag(Flag.SUBTRACTION, 0);
        regs.setFlag(Flag.OVERFLOW, 0);
    }

    @safe private void xorReference() {
        xor(readByte(regs.hl));
    }

    @safe private void xorImmediate() {
        xor(readByte(regs.pc));
        regs.pc++;
    }

    /**
     * Bitwise or a value with register A and store in register A
     */
    @safe private void or(in ubyte src) {
        regs.a |= src;

        regs.setFlag(Flag.ZERO, regs.a == 0);
        regs.setFlag(Flag.HALF_OVERFLOW, 0);
        regs.setFlag(Flag.SUBTRACTION, 0);
        regs.setFlag(Flag.OVERFLOW, 0);
    }

    @safe private void orReference() {
        or(readByte(regs.hl));
    }

    @safe private void orImmediate() {
        or(readByte(regs.pc));
        regs.pc++;
    }

    /**
     * Set the flags as if a number was subtracted from A, without actually storing the result of the subtraction
     */
    @safe private void cp(in ubyte src) {
        regs.setFlag(Flag.ZERO, regs.a == src);
        regs.setFlag(Flag.OVERFLOW, regs.a < src);
        regs.setFlag(Flag.HALF_OVERFLOW, (regs.a & 0x0F) < (src & 0x0F));
        regs.setFlag(Flag.SUBTRACTION, true);
    }

    @safe private void cpReference() {
        cp(readByte(regs.hl));
    }

    @safe private void cpImmediate() {
        cp(readByte(regs.pc));
        regs.pc++;
    }
    
    @safe private void inc(ref reg8 reg) {
        regs.setFlag(Flag.SUBTRACTION, false);
        regs.setFlag(Flag.HALF_OVERFLOW, (reg & 0x0F) == 0x0F);
        reg = cast(reg8) (reg + 1);
        regs.setFlag(Flag.ZERO, reg == 0);
    }

    /**
     * Increment the value of the memory pointed at by the address in HL
     */
    @safe private void incReference() {
        ubyte mem = readByte(regs.hl);
        inc(mem);
        writeByte(regs.hl, mem);
    }

    @safe private void dec(ref reg8 reg) {
        regs.setFlag(Flag.SUBTRACTION, true);
        regs.setFlag(Flag.HALF_OVERFLOW, (reg & 0x0F) == 0);
        reg = cast(reg8) (reg - 1);
        regs.setFlag(Flag.ZERO, reg == 0);
    }

    /**
     * Decrement the value of the memory pointed at by the address in HL
     */
    @safe private void decReference() {
        ubyte mem = readByte(regs.hl);
        dec(mem);
        writeByte(regs.hl, mem);
    }

    @safe private void inc(ref reg16 reg) {
        reg++;
        bus.update(4); // Takes time to do 16 bit math. Not sure where this goes.
    }

    @safe private void dec(ref reg16 reg) {
        reg--;
        bus.update(4); // Takes time to do 16 bit math. Not sure where this goes.
    }

    /**
     * Rotate A left, with the previous 8th bit going to both the carry flag
     * and to the new bit 0
     */
    @safe private void rlca() {
        regs.setFlag(Flag.SUBTRACTION, false);
        regs.setFlag(Flag.ZERO, false);
        regs.setFlag(Flag.HALF_OVERFLOW, false);

        immutable bool leftmostBit = regs.a >> 7;

        regs.a = rol(regs.a, 1);
        regs.setFlag(Flag.OVERFLOW, leftmostBit);
    }

    /**
     * Rotate A left, with the previous 8th bit going to the carry flag
     * and the previous carry flag going to the new bit 0
     */
    @safe private void rla() {
        regs.setFlag(Flag.SUBTRACTION, false);
        regs.setFlag(Flag.ZERO, false);
        regs.setFlag(Flag.HALF_OVERFLOW, false);

        immutable bool leftmostBit = regs.a >> 7;
        immutable bool carryFlag = regs.isFlagSet(Flag.OVERFLOW);
        
        regs.a = cast(ubyte)((regs.a << 1)) | carryFlag;
        regs.setFlag(Flag.OVERFLOW, leftmostBit);
    }
    
    /**
     * Rotate A right, with the previous 0th bit going to both 
     * the new 8th bit and the carry flag
     */
    @safe private void rrca() {
        regs.setFlag(Flag.SUBTRACTION, false);
        regs.setFlag(Flag.ZERO, false);
        regs.setFlag(Flag.HALF_OVERFLOW, false);

        immutable bool rightmostBit = regs.a & 0b1;

        regs.a = ror(regs.a, 1);
        regs.setFlag(Flag.OVERFLOW, rightmostBit);
    }
    
    /**
     * Rotate A right, with the carry flag bit going to the new 8th bit
     * and the old 0th bit going to the carry flag
     */
    @safe private void rra() {
        regs.setFlag(Flag.SUBTRACTION, false);
        regs.setFlag(Flag.ZERO, false);
        regs.setFlag(Flag.HALF_OVERFLOW, false);

        immutable bool rightmostBit = regs.a & 0b1;
        immutable bool carryBit = regs.isFlagSet(Flag.OVERFLOW);
        
        regs.a = (regs.a >> 1) | (carryBit << 7);
        regs.setFlag(Flag.OVERFLOW, rightmostBit);
    }
    
    @safe private void jumpImmediate() {
        readShort(regs.pc, regs.pc);
        // No need to increment pc to compensate for the immediate value because we jumped

        bus.update(4); // No idea where these come from
    }

    /**
     * Jump to the immediate address if the specified flag is set/reset (depending on second parameter)
     */
    @safe private void jumpImmediateIfFlag(in Flag f, in bool set) {
        if(regs.isFlagSet(f) == set) {
            jumpImmediate();
        } else { // Update PC to account for theoretically reading a 16-bit immediate
            regs.pc += 2;

            bus.update(8); // Pretend to read an immediate short
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
        regs.pc += cast(byte)(readByte(regs.pc)) + 1; // Casting to signed

        bus.update(4); // Not sure where these come from
    }

    /**
     * JR if the specified flag is set/unset
     */
    @safe private void jumpRelativeImmediateIfFlag(Flag f, bool set) {
        if(regs.isFlagSet(f) == set) {
            jumpRelativeImmediate();
        } else {
            regs.pc += 1;

            bus.update(4); // Pretend to read an immediate byte
        }
    }

    /**
     * Calculate the one's complement of the register
     * and store it in itself
     */
    @safe private void complement(ref reg8 src) {
        src = ~src;

        regs.setFlag(Flag.SUBTRACTION, 1);
        regs.setFlag(Flag.HALF_OVERFLOW, 1);
    }

    /**
     * Invert the specified flag in the flags register
     */
    @safe private void complementFlag(in Flag f) {
        // You look really nice today Ms. Carry

        regs.toggleFlag(f);

        regs.setFlag(Flag.SUBTRACTION, 0);
        regs.setFlag(Flag.HALF_OVERFLOW, 0);
    }

    /**
     * Decrement the stack pointer by 2, then write a 16-bit value to the stack
     */
    @safe private void pushToStack(in ushort src) {
        bus.update(4); // Internal delay comes before write

        regs.sp -= 2;
        writeShortBackwards(regs.sp, src);
    }

    /**
     * Read a 16-bit value from the stack into a register, then increment the stack pointer by 2
     */
    @safe private void popFromStack(out reg16 dest) {
        readShort(regs.sp, dest);
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
        loadFromMemory(regs.a, 0xFF00 + readByte(regs.pc));
        regs.pc++;
    }

    /**
     * Save the value in register A to memory at FF00 + (8-bit immediate)
     */
    @safe private void ldhAToImmediate() {
        storeInMemory(0xFF00 + readByte(regs.pc), regs.a);
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
        ushort toCall;
        readShort(regs.pc, toCall);
        regs.pc += 2; // Compensate for reading an immediate short
        call(toCall);
    }

    /**
     * Call an immediate 16-bit value if the specified flag is set/reset (depending on second argument)
     */
    @safe private void callImmediateIfFlag(in Flag f, in bool set) {
        if(regs.isFlagSet(f) == set) {
            callImmediate();
        } else {
            regs.pc += 2; // Compensate for theoretically reading an immediate short
            
            bus.update(8); // spend time to read the immediate even though we don't
        }
    }

    /**
     * Pop 16 bits from the stack and jump to that address
     */
    @safe private void ret() {
        popFromStack(regs.pc);
        bus.update(4); // Not sure where these come from
    }

    /**
     * RET if the specified flag is set/reset (depending on the second parameter)
     */
    @safe private void retIfFlag(in Flag f, in bool set) {
        bus.update(4); // Internal delay
        
        if(regs.isFlagSet(f) == set) {
            ret();
        }
    }

	@safe private void cb() {
		immutable ubyte subop = readByte(regs.pc);
        regs.pc += 1;

		cbBlock.handle(subop);
	}

    /**
     * Decimal adjusts A after operations involving multiple decimal encoded binary operations
     * This also does some weird stuff to emulate how the GB deals with invalid decimal encoded values
     */
    @safe private void daa() {
        // I apologize for the confusing and undocumented implementation.
        // It's based on the implementation in MGBA here: https://github.com/mgba-emu/mgba/blob/master/src/lr35902/isa-lr35902.c

        if(regs.isFlagSet(Flag.SUBTRACTION)) {
            if(regs.isFlagSet(Flag.HALF_OVERFLOW)) {
                regs.a += 0xFA;
            }
            if(regs.isFlagSet(Flag.OVERFLOW)) {
                regs.a += 0xA0;
            }
        } else { // addition
            int a = regs.a; // Make regs.a bigger so we don't overflow the byte
            if((regs.a & 0xF) > 0x9 || regs.isFlagSet(Flag.HALF_OVERFLOW)) {
                a += 0x06;
            }
            if((a & 0x1F0) > 0x90 || regs.isFlagSet(Flag.OVERFLOW)) {
                a += 0x60;
                regs.setFlag(Flag.OVERFLOW, 1);
            } else {
                regs.setFlag(Flag.OVERFLOW, 0);
            }
            regs.a = cast(ubyte) a;
        }

        regs.setFlag(Flag.HALF_OVERFLOW, 0);
        regs.setFlag(Flag.ZERO, regs.a == 0);
    }

    /**
     * Sets the carry flag to 1
     */
    @safe private void scf() {
        regs.setFlag(Flag.OVERFLOW, true);

        regs.setFlag(Flag.SUBTRACTION, 0);
        regs.setFlag(Flag.HALF_OVERFLOW, 0);
    }

    /**
     * Halt execution until an interrupt happens
     * A power saving measure
     */
    @safe private void halt() {
        // The HALT instruction has different behaviors based on IME, IE, and IF

        // If IME is 1 it halts CPU execution until an interrupt happens
        if(iuptHandler.masterToggle) {
            this.haltMode = HaltMode.NORMAL;
        } else { // If IME is 0
            immutable bool someInterruptReady = (iuptHandler.interruptEnableRegister & iuptHandler.interruptFlagRegister & 0b00011111) != 0;
            if(someInterruptReady) {
                // If there is an interrupt ready, HALT is not entered.
                // Instead there is a bug that occurs causing the next instruction to be executed twice.
                this.haltMode = HaltMode.HALT_BUG;
            } else {
                // If IME is 0 and no interrupt is ready, HALT works as normal 
                // except when an interrupt is fired, the CPU unhalts but doesn't
                // handle the interrupt. It also doesn't clear the IF flags.
                this.haltMode = HaltMode.NO_INTERRUPT_JUMP;
                iuptHandler.masterToggle = true;
            }
        }
    }

    @safe private ubyte readByte(ushort addr) {
        immutable ubyte read = mmu.readByte(addr);
        bus.update(4); // 4 cycles to read a byte
        return read;
    }

    @safe private void writeByte(ushort addr, ubyte val) {
        mmu.writeByte(addr, val);
        bus.update(4);
    }

    @safe private void readShort(ushort addr, out ushort dst) {
        dst = mmu.readByte(addr);
        bus.update(4);
        dst |= mmu.readByte(addr + 1) << 8;
        bus.update(4);
    }

    @safe private void writeShort(ushort addr, ushort toWrite) {
        mmu.writeByte(addr, toWrite & 0xFF);
        bus.update(4);
        mmu.writeByte(addr + 1, toWrite >> 8);
        bus.update(4);
    }

    @safe private void writeShortBackwards(ushort addr, ushort toWrite) {
        mmu.writeByte(addr + 1, toWrite >> 8);
        bus.update(4);
        mmu.writeByte(addr, toWrite & 0xFF);
        bus.update(4);
    }

    // TODO use function templates for the functions that are the same between reg8 and reg16

}
