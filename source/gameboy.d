import mmu, cpu;
import clock;

class Gameboy {
    private Clock clock;
    private MMU mmu;
    private const CPU cpu;

    this() {
        this.clock = new Clock();
        this.mmu = new MMU();
        this.cpu = new CPU(this.mmu, this.clock);
    }
}