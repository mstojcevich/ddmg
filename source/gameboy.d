import frontend;
import sound.apu;
import mmu, cpu, clock, cartridge, graphics, keypad, interrupt, bus, serial;
import std.stdio;

class Gameboy {

    private Clock clock;
    private MMU mmu;
    private CPU cpu;
    private GPU gpu;
    private APU apu;
    private Cartridge cartridge;
    private Display display;
    private Keypad keypad;
    private InterruptHandler iuptHandler;
    private Bus bus;
    private Frontend frontend;
    private Serial serial;

    @safe this(Frontend frontend, string romPath) {
        this.frontend = frontend;

        this.cartridge = new Cartridge(romPath);

        this.display = frontend.getDisplay();
        this.iuptHandler = new InterruptHandler();
        this.keypad = new Keypad(frontend.getKeypad(), this.iuptHandler);
        this.clock = new Clock(this.iuptHandler);
        this.serial = new Serial(this.iuptHandler, this.frontend.getSerial());
        this.gpu = new GPU(frontend, this.iuptHandler);
        this.apu = new APU(frontend.getSound());
        this.mmu = new MMU(this.cartridge, this.gpu, this.keypad, this.iuptHandler, this.clock, this.apu, this.serial);
        this.bus = new Bus(this.clock, this.gpu, this.mmu, this.apu, this.serial);
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

    @safe public const(MMU) getMMU() const {
        return this.mmu;
    }

    @safe public CPU getCPU() {
        return this.cpu;
    }

}