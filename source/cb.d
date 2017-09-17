import registers;
import instruction;

// Portion of the CPU to deal with CB prefix instructions -
// a set of instructions that deals with bit operations

class CB {

    // Instruction table for the CB instructions
    private Instruction[256] instructions;

    private ref Registers regs;
    private ref MMU mmu;

    @safe this(ref Registers registers) {
        this.regs = registers;

        this.instructions = {
            Instruction("RLC B", 8, { rlc(regs.b); });
        }
    }

    /**
     * Handle a CB instruction
     * Assumes that the CB byte has already been read
     * @return How many cycles were elapsed
     */
    public int handle(in ubyte instruction) {
    }

    /**
     * Rotate reg left
     */
    private void rlc(ref reg8 reg) {
        setFlag(Flag.SUBTRACTION, false);
        setFlag(Flag.HALF_OVERFLOW, false);

        immutable bool leftmostBit = reg >> 7;

        reg = cast(ubyte)((reg << 1) + leftmostBit);
        setFlag(Flag.OVERFLOW, leftmostBit);

        setFlag(Flag.ZERO, reg == 0);
    }

}