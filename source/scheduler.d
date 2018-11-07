import std.stdio;

import clock, graphics, mmu, sound.apu, serial, cpu;

/// Handles the updating of clocked components
class Scheduler {

    private CPU cpu;
    private Clock clk;
    private GPU gpu;
    private MMU mmu;
    private APU apu;
    private Serial serial;

    /// Create a new bus with the specified components
    @safe this(CPU cpu, Clock clk, GPU gpu, MMU mmu, APU apu, Serial serial) {
        this.cpu = cpu;
        this.clk = clk;
        this.gpu = gpu;
        this.mmu = mmu;
        this.apu = apu;
        this.serial = serial;
    }

    /// Create a dummy bus for testing (parameterless constructor required for mocking)
    version(test) @safe this() {}

    /// Simulate the Gameboy
    @trusted final void step() {
        cpu.call(); 
        clk.spendCycles(4);
        gpu.execute(4);
        mmu.step(4);
    
        // TODO verify where serial goes on the chain of components
    
        for(int i; i < 4; i++) {
            serial.tick();
            apu.tick();
        }
    }

}
