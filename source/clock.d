/**
 * Keeps track of how many cycles have elapsed
 */
class Clock {
    
    /**
     * The numbers of cycles that have elapsed so far
     */
    private int cyclesElapsed = 0;

    /**
     * Get the number of cycles that have elapsed so far
     */
    public int getElapsedCycles() {
        return cyclesElapsed;
    }

    /**
     * Cause the specified number of cycles to be elapsed
     */
    public void spendCycles(int num)
    in {
        assert(num >= 0);
    }
    body {
        this.cyclesElapsed += num;
    }
}