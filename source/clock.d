import std.bitmanip;

import core.thread;

import timing;
import interrupt;

// TODO verify behavior with http://gbdev.gg8.se/wiki/articles/Timer_Obscure_Behaviour

/**
 * Specifies the rate at which TIMA should increase.
 * Stored in TAC.
 */
private enum ClockRate : ubyte {
    HZ_4096     = 0b00,
    HZ_262144   = 0b01,
    HZ_65536    = 0b10,
    HZ_16384    = 0b11
}

/**
 * Description of the TAC register.
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
 * Keeps track of how many cycles have elapsed.
 */
class Clock : Fiber {

    /**
     * The divider register, increased each clock cycle.
     * Internally this is stored as a 16 bit number which increments at the regular clock rate.
     * The upper 8 bits are used as the value of the DIV register (FF04).
     * Therefore, from the point-of-view of the program, it increases once every 256 cycles.
     */
    private ushort div = 0;

    /**
     * The timer counter register.
     * It is incremented at a frequency defined in the TAC register. 
     * When overflowed an interrupt is requested.
     */
    private ubyte tima;
    private bool lastTimaCheck; // Whether the tima check passed last cycle
    private bool shouldReloadTima;

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
    @trusted this(InterruptHandler iuptHandler) {
        super(&run);

        this.tac.data = 0xF8; // Unused bits to 1, used stuff to 0
        this.iuptHandler = iuptHandler;
        reset();
    }

    /// Run the clock indefinitely
    @trusted private void run() {
        while (true) {
            runTick();
            yield();
        }
    }

    /**
     * Check whether TIMA should be incremented: if so, increment it.
     * Should be called _whenever_ tima's sources change (TAC or DIV).
     */
    @safe private void checkAndIncrTima() {
        // TIMA is incremented if it is enabled and a certain
        // bit (depending on the frequency) is on in DIV.
        const bool timaCheck = tac.timerRun && (this.div & this.timaMask) > 0;

        // Tima in only incremented on the falling edge of the tima check
        if (!timaCheck && lastTimaCheck) {
            ulong newTima = this.tima + 1;

            if(newTima > ubyte.max) { // Overflow
                this.tima = 0; // 0 for 4 cycles
                this.shouldReloadTima = true; // TIMA reload is delayed 4 cycles
            } else {
                this.tima = cast(ubyte)(newTima);
            }
        }

        // Save for falling edge detection
        lastTimaCheck = timaCheck;
    }

    // Run the clock for one "tick" (4 cycles)
    @safe private void runTick() {
        if (this.shouldReloadTima) {
            this.tima = this.tma;
            this.shouldReloadTima = false;
            iuptHandler.fireInterrupt(Interrupts.TIMER_OVERFLOW);
        }
        for (int i; i < 4; i++) {
            // Div in incremented every clock cycle
            this.div++;

            // DIV changed, so update TIMA
            checkAndIncrTima();
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
        this.div = 0; // The entire 16-bits get reset when written
    }

    /**
     * Set the timer control (TAC) register (FF07)
     */
    @safe @property void timerControl(ubyte newTac) {
        this.tac.data = 0b11111000 | (newTac & 0b111); // Only the lower 3 bits can be written
        // TAC changed, so update TIMA
        checkAndIncrTima();
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
     * Tima gets incremented based on a mask of the internal 16-bit div
     * register. This mask depends on the rate set in TAC.
     * This function returns the aforementioned mask.
     */
    @safe private ushort timaMask() {
        final switch (tac.clockSelect) {
            case ClockRate.HZ_262144:
                return 0b1000; // 4th bit
            case ClockRate.HZ_65536:
                return 0b100000; // 6th bit
            case ClockRate.HZ_16384:
                return 0b10000000; // 8th bit
            case ClockRate.HZ_4096:
                return 0b1000000000; // 10th bit
        }
    }

    @safe public void reset() {
        // Initial internal counter value for DIV is 0xABCC
        // This differs between DMG and GBC (GBC is 0x1EA0)
        // This is due to different boot roms probably
        this.div = 0xABCC;
    }

}
