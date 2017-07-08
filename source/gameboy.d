import mmu, cpu, clock, cartridge, display, gpu;

class Gameboy {
    private Clock clock;
    private MMU mmu;
    private CPU cpu;
    private GPU gpu;
    private const Cartridge cartridge;
    private Display display;

    this() {
        this.cartridge = new Cartridge("/home/marcusant/Downloads/opus5.gb");

        this.display = new Display();
        this.clock = new Clock();
        this.gpu = new GPU(this.display, this.clock);
        this.mmu = new MMU(this.cartridge, this.gpu);
        this.cpu = new CPU(this.mmu, this.clock);

        while(true) {
            cpu.step();
            gpu.step();

            if(display.shouldProgramTerminate()) {
                break;
            }
        }
    }
}