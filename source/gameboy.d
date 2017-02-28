import mmu, cpu, clock, cartridge, display;

class Gameboy {
    private Clock clock;
    private MMU mmu;
    private CPU cpu;
    private const Cartridge cartridge;
    private Display display;

    this() {
        this.cartridge = new Cartridge("/home/marcusant/tetris.gb");

        this.display = new Display();

        this.clock = new Clock();
        this.mmu = new MMU(this.cartridge);
        this.cpu = new CPU(this.mmu, this.clock);

        while(true) {
            cpu.step();

            display.drawFrame();

            if(display.shouldProgramTerminate()) {
                break;
            }
        }
    }
}