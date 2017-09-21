/**
 * Keeps track of how many cycles have elapsed
 */
class Clock {
    
    /**
     * The numbers of cycles that have elapsed so far
     */
    private ulong elapsedCycles = 0;

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
    }
}