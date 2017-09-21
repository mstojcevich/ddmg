import mmu, cpu, clock, cartridge, display, gpu, keypad, interrupt;
import std.stdio;

class Gameboy {
    private Clock clock;
    private MMU mmu;
    private CPU cpu;
    private GPU gpu;
    private const Cartridge cartridge;
    private Display display;
    private Keypad keypad;
    private InterruptHandler iuptHandler;

    this(string romPath) {
        this.cartridge = new Cartridge(romPath);

        this.display = new Display();
        this.keypad = new Keypad(this.display.glfwWindow);
        this.iuptHandler = new InterruptHandler();
        this.clock = new Clock(this.iuptHandler);
        this.gpu = new GPU(this.display, this.clock, this.iuptHandler);
        this.mmu = new MMU(this.cartridge, this.gpu, this.keypad, this.iuptHandler, this.clock);
        this.cpu = new CPU(this.mmu, this.clock, this.iuptHandler);
    }

    public void run() {
        while(true) {
            cpu.step();
            gpu.step();

            if(display.shouldProgramTerminate()) {
                break;
            }
        }
    }

}