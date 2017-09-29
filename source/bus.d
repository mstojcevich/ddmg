import graphics, clock;

/// Handles the updating of clocked components alongside the CPU
class Bus {

    private Clock clk;
    private GPU gpu;

    /// Create a new bus with the specified components
    @safe this(Clock clk, GPU gpu) {
        this.clk = clk;
        this.gpu = gpu;
    }

    /// Simulate n cycles of the components on the bus
    void update(uint cyclesExpended) {
        clk.spendCycles(cyclesExpended);
        gpu.step(cyclesExpended);
    }

}