import mmu, cpu;

class Gameboy {
    private MMU mmu;
    private const CPU cpu;

    this() {
        this.mmu = new MMU();
        this.cpu = new CPU(this.mmu);
    }
}