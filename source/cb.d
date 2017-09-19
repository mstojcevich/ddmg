import core.bitop;

import registers;
import instruction;

// Portion of the CPU to deal with CB prefix instructions -
// a set of instructions that deals with bit operations

class CB {

    // Instruction table for the CB instructions
    private Instruction[256] instructions;

    private Registers regs;

    private @safe void delegate(ref reg8 reg)[32] ops;

    @safe this(ref Registers registers) {
        this.regs = registers;

        // ops = [
        //     &rlc, &rrc, &rl, &rr, 
        //     &sla, &sra, &swap, &srl,
        //     (ref reg8 reg) => bit(0, reg),
        //     (ref reg8 reg) => bit(1, reg),
        //     (ref reg8 reg) => bit(2, reg),
        //     (ref reg8 reg) => bit(3, reg),
        //     (ref reg8 reg) => bit(4, reg),
        //     (ref reg8 reg) => bit(5, reg),
        //     (ref reg8 reg) => bit(6, reg),
        //     (ref reg8 reg) => bit(7, reg),
        //     (ref reg8 reg) => res(0, reg),
        //     (ref reg8 reg) => res(1, reg),
        //     (ref reg8 reg) => res(2, reg),
        //     (ref reg8 reg) => res(3, reg),
        //     (ref reg8 reg) => res(4, reg),
        //     (ref reg8 reg) => res(5, reg),
        //     (ref reg8 reg) => res(6, reg),
        //     (ref reg8 reg) => res(7, reg),
        //     (ref reg8 reg) => set(0, reg),
        //     (ref reg8 reg) => set(1, reg),
        //     (ref reg8 reg) => set(2, reg),
        //     (ref reg8 reg) => set(3, reg),
        //     (ref reg8 reg) => set(4, reg),
        //     (ref reg8 reg) => set(5, reg),
        //     (ref reg8 reg) => set(6, reg),
        //     (ref reg8 reg) => set(7, reg),
        // ];

        this.instructions = [
            Instruction("RLC B",    8, { rlc(regs.b); }),
            Instruction("RLC C",    8, { rlc(regs.c); }),
            Instruction("RLC D",    8, { rlc(regs.d); }),
            Instruction("RLC E",    8, { rlc(regs.e); }),
            Instruction("RLC H",    8, { rlc(regs.h); }),
            Instruction("RLC L",    8, { rlc(regs.l); }),
            Instruction("RLC (HL)", 16, null),
            Instruction("RLC A",    8, { rlc(regs.a); }),
            Instruction("RRC B",    8, { rrc(regs.b); }),
            Instruction("RRC C",    8, { rrc(regs.c); }),
            Instruction("RRC D",    8, { rrc(regs.d); }),
            Instruction("RRC E",    8, { rrc(regs.e); }),
            Instruction("RRC H",    8, { rrc(regs.h); }),
            Instruction("RRC L",    8, { rrc(regs.l); }),
            Instruction("RRC (HL)", 16, null),
            Instruction("RRC A",    8, { rrc(regs.a); }),
            Instruction("RL B",     8, { rl(regs.b); }),
            Instruction("RL C",     8, { rl(regs.c); }),
            Instruction("RL D",     8, { rl(regs.d); }),
            Instruction("RL E",     8, { rl(regs.e); }),
            Instruction("RL H",     8, { rl(regs.h); }),
            Instruction("RL L",     8, { rl(regs.l); }),
            Instruction("RL (HL)",  16, null),
            Instruction("XX",       8, null),
            Instruction("XX",       8, null),
            Instruction("XX",       8, null),
            Instruction("XX",       8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null),
            Instruction("XX", 8, null)
        ];
    }

    /**
     * Handle a CB instruction
     * Assumes that the CB byte has already been read
     * @return How many cycles were elapsed
     */
    @safe public int handle(in ubyte instruction) {
        return 0;
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