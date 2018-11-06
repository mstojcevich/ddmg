import clock, graphics, mmu, sound.apu, serial;

/// Handles the updating of clocked components alongside the CPU
class Bus {

    private Clock clk;
    private GPU gpu;
    private MMU mmu;
    private APU apu;
    private Serial serial;

    /// Create a new bus with the specified components
    @safe this(Clock clk, GPU gpu, MMU mmu, APU apu, Serial serial) {
        this.clk = clk;
        this.gpu = gpu;
        this.mmu = mmu;
        this.apu = apu;
        this.serial = serial;
    }

    /// Create a dummy bus for testing (parameterless constructor required for mocking)
    version(test) @safe this() {}

    /// Simulate n cycles of the components on the bus
    @safe void update(uint cyclesExpended) {
        clk.spendCycles(cyclesExpended);
        gpu.execute(cyclesExpended);
        mmu.step(cyclesExpended);

        // TODO verify where serial goes on the chain of components

        for(int i; i < cyclesExpended; i++) {
            serial.tick();
            apu.tick();
        }
    }

}
