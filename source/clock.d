/**
 * The amount to divide the clock by to get the divider
 * register value.
 */
private const ubyte DIVIDER_AMT = 16;

/**
 * Keeps track of how many cycles have elapsed
 */
class Clock {
    
    /**
     * The numbers of cycles that have elapsed so far
     */
    private ulong elapsedCycles = 0;

    /**
     * The div register, incremented at 1/16th the rate of the clock.
     * Internally we keep the true value of the clock (except reset whenever div resets).
     * this is so that it's easier to incrememnt it properly;
     */
     private ulong div = 0;

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
    }

    /**
     * Get the value of the divider register (FF04)
     */
    @safe @property public ubyte divider() const {
        return cast(ubyte)(div / DIVIDER_AMT);
    }

    /**
     * Resets the divider register (FF04)
     */
    @safe void resetDivider() {
        this.div = 0;
    }

}