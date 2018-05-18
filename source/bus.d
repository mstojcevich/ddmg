import clock, graphics, mmu, sound.apu;

/// Handles the updating of clocked components alongside the CPU
class Bus {

    private Clock clk;
    private GPU gpu;
    private MMU mmu;
    private APU apu;

    /// Create a new bus with the specified components
    @safe this(Clock clk, GPU gpu, MMU mmu, APU apu) {
        this.clk = clk;
        this.gpu = gpu;
        this.mmu = mmu;
        this.apu = apu;
    }

    version(test) @safe this() {}

    /// Simulate n cycles of the components on the bus
    @safe void update(uint cyclesExpended) {
        clk.spendCycles(cyclesExpended);
        gpu.execute(cyclesExpended);
        mmu.step(cyclesExpended);

        for(int i = 0; i < cyclesExpended; i++) {
            apu.tick();
        }
    }

}