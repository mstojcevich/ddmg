import mmu, cpu;
import clock;
import cartridge;

class Gameboy {
    private Clock clock;
    private MMU mmu;
    private const CPU cpu;
    private const Cartridge cartridge;

    @safe this() {
        this.cartridge = new Cartridge("/home/marcusant/tetris.gb");

        this.clock = new Clock();
        this.mmu = new MMU();
        this.cpu = new CPU(this.mmu, this.clock);
    }
}