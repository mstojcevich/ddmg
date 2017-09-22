import core.bitop;

import registers;
import instruction;
import mmu;

// Portion of the CPU to deal with CB prefix instructions -
// a set of instructions that deals with bit operations

alias Operation = void delegate(ref reg8 reg) @safe;

private struct Destination {
	// The name of the destination for use in debugging
	string name;

	// The amount of cycles it takes to apply a CB operation w/ the destination
	uint cycles;

	// How to apply an operation to the destination
	@safe void delegate(Operation op) apply;
}

class CB {

    // Instruction table for the CB instructions
    private Instruction[256] instructions;

    private Registers regs;
	private MMU mmu;

	// Lookup tables for op and destination
	// Probably a perf penalty but at least I don't have to write a 256 item long table again
    // This is possible because each operation occurs exactly 8 times so we can do actual instruction decoding
	private @safe Operation[32] ops;
	private @safe Destination[8] destinations;

    @safe this(ref Registers registers, ref MMU mmu) {
        this.regs = registers;
		this.mmu = mmu;

		this.destinations = [
			Destination("B", 8, (Operation op) @safe => op(regs.b)),
			Destination("C", 8, (Operation op) @safe => op(regs.c)),
			Destination("D", 8, (Operation op) @safe => op(regs.d)),
			Destination("E", 8, (Operation op) @safe => op(regs.e)),
			Destination("H", 8, (Operation op) @safe => op(regs.h)),
			Destination("L", 8, (Operation op) @safe => op(regs.l)),
			Destination("(HL)", 16, (Operation op) @safe {
				ubyte hlVal = this.mmu.readByte(this.regs.hl);
				op(hlVal);
				this.mmu.writeByte(this.regs.hl, hlVal);
			}),
			Destination("A", 8, (Operation op) => op(regs.a))
		];

		this.ops = [
			&rlc, &rrc, &rl, &rr, 
			&sla, &sra, &swap, &srl,
			(ref reg8 reg) => bit(0, reg),
			(ref reg8 reg) => bit(1, reg),
			(ref reg8 reg) => bit(2, reg),
			(ref reg8 reg) => bit(3, reg),
			(ref reg8 reg) => bit(4, reg),
			(ref reg8 reg) => bit(5, reg),
			(ref reg8 reg) => bit(6, reg),
			(ref reg8 reg) => bit(7, reg),
			(ref reg8 reg) => res(0, reg),
			(ref reg8 reg) => res(1, reg),
			(ref reg8 reg) => res(2, reg),
			(ref reg8 reg) => res(3, reg),
			(ref reg8 reg) => res(4, reg),
			(ref reg8 reg) => res(5, reg),
			(ref reg8 reg) => res(6, reg),
			(ref reg8 reg) => res(7, reg),
			(ref reg8 reg) => set(0, reg),
			(ref reg8 reg) => set(1, reg),
			(ref reg8 reg) => set(2, reg),
			(ref reg8 reg) => set(3, reg),
			(ref reg8 reg) => set(4, reg),
			(ref reg8 reg) => set(5, reg),
			(ref reg8 reg) => set(6, reg),
			(ref reg8 reg) => set(7, reg),
		];
    }

    /**
     * Handle a CB instruction
     * @return How many cycles were elapsed
     */
    @safe public int handle(in ubyte instruction) {
		immutable ubyte destination = instruction & 0b111;
		immutable ubyte op = instruction >> 3;

		immutable Destination dest = destinations[destination];
		dest.apply(ops[op]);

        // Hacky fix, but it works
        // BIT (HL) is special in that it takes 12 cycles not 16
        if(destination == 6 && (op >= 8 && op <= 15)) {
            return 12;
        }

        return dest.cycles;
    }

    /**
     * Rotate reg left.
     * Puts the old bit 7 in the carry flag.
     */
    @safe private void rlc(ref reg8 reg) {
        regs.setFlag(Flag.SUBTRACTION, false);
        regs.setFlag(Flag.HALF_OVERFLOW, false);

        immutable bool leftmostBit = reg >> 7;

        reg = rol(reg, 1);
        regs.setFlag(Flag.OVERFLOW, leftmostBit);

        regs.setFlag(Flag.ZERO, reg == 0);
    }

    /**
     * Rotate reg right.
     * Puts the old bit 0 in the carry flag
     */
    @safe private void rrc(ref reg8 reg) {
        regs.setFlag(Flag.SUBTRACTION, false);
        regs.setFlag(Flag.HALF_OVERFLOW, false);

        immutable bool rightmostBit = reg & 0b1;

        reg = ror(reg, 1);
        regs.setFlag(Flag.OVERFLOW, rightmostBit);

        regs.setFlag(Flag.ZERO, reg == 0);
    }

    /**
     * Rotates reg left, using the carry flag as a 9th bit.
     */
    @safe private void rl(ref reg8 reg) {
        regs.setFlag(Flag.SUBTRACTION, false);
        regs.setFlag(Flag.HALF_OVERFLOW, false);

        immutable bool leftmostBit = reg >> 7;
        immutable bool carryFlag = regs.isFlagSet(Flag.OVERFLOW);
        
        reg = cast(ubyte)((reg << 1)) | carryFlag;
        regs.setFlag(Flag.OVERFLOW, leftmostBit);

        regs.setFlag(Flag.ZERO, reg == 0);
    }

    /**
     * Rotates reg right, using the carry flag as a 9th bit.
     */
    @safe private void rr(ref reg8 reg) {
        regs.setFlag(Flag.SUBTRACTION, false);
        regs.setFlag(Flag.HALF_OVERFLOW, false);

        immutable bool rightmostBit = reg & 0b1;
        immutable bool carryBit = regs.isFlagSet(Flag.OVERFLOW);
        
        reg = (reg >> 1) | (carryBit << 7);
        regs.setFlag(Flag.OVERFLOW, rightmostBit);

        regs.setFlag(Flag.ZERO, reg == 0);
    }

    /**
     * Shifts reg left, with leftmost bit going into carry
     */
    @safe private void sla(ref reg8 reg) {
        regs.setFlag(Flag.SUBTRACTION, false);
        regs.setFlag(Flag.HALF_OVERFLOW, false);

        immutable bool leftmostBit = reg >> 7;

        reg = cast(ubyte) (reg << 1);
        regs.setFlag(Flag.OVERFLOW, leftmostBit);

        regs.setFlag(Flag.ZERO, reg == 0);
    }

    /**
     * Arithmetic shifts reg right, with rightmost bit going into carry
     */
    @safe private void sra(ref reg8 reg) {
        regs.setFlag(Flag.SUBTRACTION, false);
        regs.setFlag(Flag.HALF_OVERFLOW, false);

        immutable bool rightmostBit = reg & 0b1;
        immutable ubyte leftmostBit = reg & 0b10000000;

        reg = (reg >> 1) | leftmostBit;
        regs.setFlag(Flag.OVERFLOW, rightmostBit);

        regs.setFlag(Flag.ZERO, reg == 0);
    }

    /**
     * Swap the two nibbles of reg
     */
    @safe private void swap(ref reg8 reg) {
        regs.setFlag(Flag.SUBTRACTION, false);
        regs.setFlag(Flag.HALF_OVERFLOW, false);
        regs.setFlag(Flag.OVERFLOW, false);

        immutable ubyte leftNibble = reg >> 4;
        immutable ubyte rightNibble = (reg & 0b1111);
        reg = (rightNibble << 4) | leftNibble;

        regs.setFlag(Flag.ZERO, reg == 0);
    }

    /**
     * Logical shifts reg right, with rightmost bit going into carry
     */
    @safe private void srl(ref reg8 reg) {
        regs.setFlag(Flag.SUBTRACTION, false);
        regs.setFlag(Flag.HALF_OVERFLOW, false);

        immutable bool rightmostBit = reg & 0b1;

        reg = reg >> 1;
        regs.setFlag(Flag.OVERFLOW, rightmostBit);

        regs.setFlag(Flag.ZERO, reg == 0);
    }

    /**
     * Sets ZERO flag true if the bit "num" from the right is 0, false otherwise.
     */
    @safe void bit(in ubyte num, in reg8 reg)
    in {
        assert(num < 8);
    } body {
        regs.setFlag(Flag.SUBTRACTION, false);
        regs.setFlag(Flag.HALF_OVERFLOW, true);

        if((reg & (1 << num)) == 0) {
            regs.setFlag(Flag.ZERO, true);
        } else {
            regs.setFlag(Flag.ZERO, false);
        }
    }

    /**
     * Unsets the bit "num" from the right in reg
     */
    @safe void res(in ubyte num, ref reg8 reg)
    in {
        assert(num < 8);
    } body {
        reg = reg & ~(1 << num);
    }

    /**
     * Sets the bit "num" from the right in reg
     */
    @safe void set(in ubyte num, ref reg8 reg)
    in {
        assert(num < 8);
    } body {
        reg = reg | cast(ubyte)(1 << num);
    }

}