import mmu, cpu, clock, cartridge, graphics, keypad, interrupt;
import std.stdio;

class Gameboy {
    private Clock clock;
    private MMU mmu;
    private CPU cpu;
    private GPU gpu;
    private Cartridge cartridge;
    private Display display;
    private Keypad keypad;
    private InterruptHandler iuptHandler;

    this(string romPath) {
        this.cartridge = new Cartridge(romPath);

        this.display = new Display();
        this.iuptHandler = new InterruptHandler();
        this.keypad = new Keypad(this.display.glfwWindow, this.iuptHandler);
        this.clock = new Clock(this.iuptHandler);
        this.gpu = new GPU(this.display, this.clock, this.iuptHandler);
        this.mmu = new MMU(this.cartridge, this.gpu, this.keypad, this.iuptHandler, this.clock);
        this.cpu = new CPU(this.mmu, this.clock, this.iuptHandler);
    }

    public void run() {
        while(true) {
            keypad.update();
            cpu.step();
            gpu.step();

            if(display.shouldProgramTerminate()) {
                break;
            }
        }
    }

}