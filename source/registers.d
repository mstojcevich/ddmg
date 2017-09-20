/**
 * Type for a 16-bit register
 */
alias reg16 = ushort;

/**
 * Type for an 8-bit register
 */
alias reg8 = ubyte;

/**
 * Flag bits in the f register
 */
enum Flag : ubyte {
    /**
     * Zero flag (aka "zf")
     * Set to 1 when the result of certain operations is 0, unset otherwise on certain instruction
     * Used for conditional jumps
     */
    ZERO            = 1 << 7,

    /**
     * Subtraction flag (aka "n")
     * Set to 1 when subtraction occurs in certain operations, unset on many other instructions
     * Used for decimal adjust (DAA) for binary coded decimal (BCD)
     */
    SUBTRACTION     = 1 << 6, // Set to 1 following the execution of the subtraction instruction

    /**
     * Half carry flag (aka "h")
     * Set to 1 when certain operations result in a carry from the right nibble to the left
     * Used for decimal adjust (DAA) for binary coded decimal (BCD)
     */
    HALF_OVERFLOW   = 1 << 5, // Set to 1 when an operation carries from or borrows to bit 3

    /**
     * Carry flag (aka "cy")
     */
    OVERFLOW        = 1 << 4  // Set to 1 when an operation carries from or borrows to bit 7
}

/**
 * A specific register pair (16-bit superregister)
 * that can be addressed either singularly or as a group
 */
private template Register(string firstHalf, string secondHalf) {
    const char[] Register = 
    "
    union {
        reg16 " ~ firstHalf ~ secondHalf ~ ";

        struct {
            align(1):  // Pack the bytes right next to each other
                reg8 " ~ secondHalf ~ ";
                reg8 " ~ firstHalf ~";
        }
    }
    ";
}

/**
 * The registers of a Gameboy CPU
 */
class Registers {
    mixin(Register!("a", "f")); // A = accum, F = flags
    mixin(Register!("b", "c")); // General registers
    mixin(Register!("d", "e")); // General registers
    mixin(Register!("h", "l")); // Pair usually used as pointer to memory
    
    /**
     * Stack pointer, determines where the stack sits in memory
     */
    reg16 sp;

    /**
     * Program counter, determines where the current instruction is in memory
     */
    reg16 pc;

    /**
     * Sets a flag on the flag register
     */
    @safe void setFlag(in Flag f, in bool set) {
        if(set) {
            this.f = this.f | f; // ORing with the flag will set it true
        } else {
            this.f = this.f & ~f; // ANDing with the inverse of f will set the flag to 0
        }
    }

    /**
     * Check the status of a flag in the f register
     * If the flag is 1, returns true, else returns false
     */
    @safe bool isFlagSet(in Flag f) {
        return (this.f & f) != 0;
    }

    /**
     * If a flag is 0 in the flag register, this will make it 1; if it is 1, this will make it 0
     */
    @safe void toggleFlag(in Flag f) {
        this.f = this.f ^ f; // XOR will invert the bits that are set in the input
    }

}