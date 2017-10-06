import graphics, clock, mmu;

/// Handles the updating of clocked components alongside the CPU
class Bus {

    private Clock clk;
    private GPU gpu;
    private MMU mmu;

    /// Create a new bus with the specified components
    @safe this(Clock clk, GPU gpu, MMU mmu) {
        this.clk = clk;
        this.gpu = gpu;
        this.mmu = mmu;
    }

    /// Simulate n cycles of the components on the bus
    @safe void update(uint cyclesExpended) {
        clk.spendCycles(cyclesExpended);
        gpu.execute(cyclesExpended);
        mmu.step(cyclesExpended);
    }

}