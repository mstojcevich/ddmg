import std.traits;

private struct Interrupt {
    ubyte flagBit; // Flag bit used for interruptEnable and interruptFlags registers
    ubyte address; // Address to jump to
    ubyte toHandleCode; // Emulator-internal code for handling fired interrupts. Affects priority of processing.
}

enum Interrupts : Interrupt
{
    VBLANK          = Interrupt(1 << 0, 0x0040, 0),
    LCD_STATUS      = Interrupt(1 << 1, 0x0048, 1),
    TIMER_OVERFLOW  = Interrupt(1 << 2, 0x0050, 2),
    SERIAL_LINK     = Interrupt(1 << 3, 0x0058, 3),
    JOYPAD_PRESS    = Interrupt(1 << 4, 0x0060, 4),
}

// TODO emulate the delay bug for EI and DI instructions

class InterruptHandler {

    // Master enable - Whether interrupts should be processed in general
    private bool masterEnable = true;

    // Whether certain interrupts should be processed
    private ubyte interruptEnable = 0x0000;

    // Keeps track of if an interrupt has happened TODO not sure when this is reset
    private ubyte interruptFlags;

    // Emulator-internal variable to keep track of what interrupts have been requested during the current cycle
    // Size 5 because of 5 different interrupts
    bool[(EnumMembers!Interrupts).length] toHandle;

    // Check whether an interrupt is enabled
    @safe bool isInterruptEnabled(Interrupts iupt) {
        return (interruptEnable & iupt.flagBit) != 0;
    }

    @safe @property const ubyte interruptEnableRegister() {
        return interruptEnable;
    }

    @safe @property void interruptEnableRegister(ubyte ienable) {
        interruptEnable = ienable;
    }

    @safe @property void masterToggle(bool enabled) {
        masterEnable = enabled;
    }
    
    @safe @property const bool masterToggle() {
        return masterEnable;
    }

    @safe const bool shouldHandle(Interrupts iupt) {
        return toHandle[iupt.toHandleCode];
    }

    @safe void markHandled(Interrupts iupt) {
        toHandle[iupt.toHandleCode] = false;
    }
    
    @safe void fireInterrupt(Interrupts iupt) {
        if(masterEnable && isInterruptEnabled(iupt)) {
            toHandle[iupt.toHandleCode] = true;
        }
    }
}