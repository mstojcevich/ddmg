import std.bitmanip;

import interrupt;

// TODO verify behavior with http://gbdev.gg8.se/wiki/articles/Timer_Obscure_Behaviour

/**
 * Specifies the rate at which TIMA should increase
 * Stored in TAC
 */
private enum ClockRate : ubyte {
    HZ_4096     = 0b00,
    HZ_262144   = 0b01,
    HZ_65536    = 0b10,
    HZ_16384    = 0b11
}

/**
 * Description of the TAC register
 */
private union TimerControl {
    ubyte data;
    mixin(bitfields!(
        ClockRate, "clockSelect", 2,
        bool, "timerRun", 1,  // 0 = stop, 1 = start
        bool, "", 5
    ));
}

/**
 * Keeps track of how many cycles have elapsed
 */
class Clock {
    
    /**
     * The numbers of cycles that have elapsed so far
     */
    private ulong elapsedCycles = 0;

    /**
     * The divider register, incremented at 1/256th the rate of the clock.
     * Internally this is stored as a 16 bit number which increments at the regular clock rate.
     * The upper 8 bits are used as the value of DIV.
     */
    private ushort div = 0;

    /**
     * The timer counter register.
     * It is incremented at a frequency defined in the TAC register. 
     * When overflowed an interrupt is requested.
     */
    private ubyte tima;
    private ulong sinceTimaIncr; // The amount of CPU cycles since the last TIMA increase

    /**
     * The timer modulo register.
     * When TIMA overflows, this is the value that is loaded.
     */
    private ubyte tma;

    /**
     * The TAC register at FF07
     * Used to determine traits of TIMA
     */
    private TimerControl tac;

    private InterruptHandler iuptHandler;

    /**
     * Params:
     *  iuptHandler = Interrupt handler to flag the timer overflow iupt with
     */
    @safe this(InterruptHandler iuptHandler) {
        this.tac.data = 0xF8; // Unused bits to 1, used stuff to 0
        this.iuptHandler = iuptHandler;
        reset();
    }

    /**
     * Get the number of cycles that have elapsed so far
     */
    @safe @property public ulong getElapsedCycles() {
        return elapsedCycles;
    }

    /**
     * Cause the specified number of cycles to be elapsed
     */
    @safe public void spendCycles(int num)
    in {
        assert(num >= 0);
    }
    body {
        this.elapsedCycles += num;
        this.div += num;

        if(tac.timerRun) {
            sinceTimaIncr += num;
            updateTima();
        }
    }

    /**
     * Get the value of the divider register (FF04)
     */
    @safe @property public ubyte divider() const {
        return cast(ubyte)(div >> 8); // Return the upper 8 bits of the internal DIV clock
    }

    /**
     * Reset the divider register (FF04)
     */
    @safe void resetDivider() {
        this.div = 0;
    }

    /**
     * Set the timer control (TAC) register (FF07)
     */
    @safe @property void timerControl(ubyte newTac) {
        this.tac.data = 0b11111000 | (newTac & 0b111); // Only the lower 3 bits can be written
    }

    /**
     * Get the timer control (TAC) register (FF07)
     */
    @safe @property ubyte timerControl() const {
        return tac.data;
    }

    /**
     * Set the timer counter (TIMA) register (FF05)
     */
    @safe @property void timerCounter(ubyte newTima) {
        this.tima = newTima;
    }

    /**
     * Get the timer counter (TIMA) register (FF05)
     */
    @safe @property ubyte timerCounter() const {
        return tima;
    }

    /**
     * Set the timer modulo (TMA) register (FF06)
     */
    @safe @property void timerModulo(ubyte newTma) {
        this.tma = newTma;
    }

    /**
     * Get the timer modulo (TMA) register (FF06)
     */
    @safe @property ubyte timerModulo() const {
        return tma;
    }

    /**
     * Updates the TIMA register based on
     * the clock ticks since the last TIMA
     * update
     */
    @safe private void updateTima() {        
        // The number of cycles to increment tima by 1
        immutable uint cyclesRequired = numCycles(tac.clockSelect);

        // How many time units to increment tima by
        immutable ulong incrs = sinceTimaIncr / cyclesRequired;

        ulong newTima = this.tima + incrs;
        if(newTima > ubyte.max) { // Overflow
            this.tima = this.tma;
            
            iuptHandler.fireInterrupt(Interrupts.TIMER_OVERFLOW);
        } else {
            this.tima = cast(ubyte)(newTima);
        }

        /*
          Don't just set to 0 because due to integer 
          division we may not have spent all of 
          the cylces
         */
        this.sinceTimaIncr -= incrs * cyclesRequired;
    }

    /**
     * Get the number of CPU cycles between cycles
     * at the specified clock rate
     */
    @safe private uint numCycles(ClockRate rate) {
        final switch(rate) {
            case ClockRate.HZ_4096:
            return 1024;

            case ClockRate.HZ_262144:
            return 16;

            case ClockRate.HZ_65536:
            return 64;

            case ClockRate.HZ_16384:
            return 256;
        }
    }

    @safe public void reset() {
        // Initial internal counter value for DIV is 0xABCC
        // This differs between DMG and GBC (GBC is 0x1EA0)
        // This is due to different boot roms probably
        div = 0xABCC;
    }

}