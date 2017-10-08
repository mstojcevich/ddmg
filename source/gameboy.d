import frontend;
import mmu, cpu, clock, cartridge, graphics, keypad, interrupt, bus;
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
    private Bus bus;
    private Frontend frontend;

    @safe this(Frontend frontend, string romPath) {
        this.frontend = frontend;

        this.cartridge = new Cartridge(romPath);

        this.display = frontend.getDisplay();
        this.iuptHandler = new InterruptHandler();
        this.keypad = new Keypad(frontend.getKeypad(), this.iuptHandler);
        this.clock = new Clock(this.iuptHandler);
        this.gpu = new GPU(frontend, this.iuptHandler);
        this.mmu = new MMU(this.cartridge, this.gpu, this.keypad, this.iuptHandler, this.clock);
        this.bus = new Bus(this.clock, this.gpu, this.mmu);
        this.cpu = new CPU(this.mmu, this.bus, this.iuptHandler);
    }

    @safe public void run() {
        while(true) {
            cpu.step();

            if(frontend.shouldProgramTerminate()) {
                break;
            }
        }
    }

}