/**
 * Type for a 16-bit register
 */
alias reg16 = ushort;

/**
 * Type for an 8-bit register
 */
alias reg8 = ubyte;

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
            reg8 " ~ secondHalf ~ ";
            reg8 " ~ firstHalf ~";
        }
    }
    ";
}

/**
 * The registers of a Gameboy CPU
 */
struct Registers {
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
}