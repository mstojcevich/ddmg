import std.traits;
import std.typecons;

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
    private ubyte interruptEnable;

    // Keeps track of if an interrupt signal has happened but the interrupt hasn't yet been processed
    private ubyte interruptFlags;

    // Check whether an interrupt is enabled
    @safe bool isInterruptEnabled(Interrupts iupt) const {
        return (interruptEnable & iupt.flagBit) != 0;
    }

    @safe @property ubyte interruptFlagRegister() const {
        return interruptFlags;
    }

    @safe @property void interruptFlagRegister(ubyte iflags) {
        interruptFlags = iflags;
    }

    @safe @property ubyte interruptEnableRegister() const {
        return interruptEnable;
    }

    @safe @property void interruptEnableRegister(ubyte ienable) {
        interruptEnable = ienable;
    }

    @safe @property void masterToggle(bool enabled) {
        masterEnable = enabled;
    }
    
    @safe @property bool masterToggle() const {
        return masterEnable;
    }

    @safe bool shouldHandle(Interrupts iupt) const {
        return masterEnable && (interruptFlags & iupt.flagBit) != 0 && isInterruptEnabled(iupt);
    }

    @safe void markHandled(Interrupts iupt) {
        interruptFlags &= ~iupt.flagBit;
    }
    
    @safe void fireInterrupt(Interrupts iupt) {
        interruptFlags |= iupt.flagBit;
    }
}