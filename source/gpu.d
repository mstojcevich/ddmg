import std.conv;
import std.stdio;

import clock, display;

private const CYCLES_PER_HBLANK = 204; // Cycles for a line of hblank
private const CYCLES_PER_VBLANK = 456; // Cycles for a line of vblank
private const CYCLES_PER_VRAM_SCAN = 172;
private const CYCLES_PER_OAM_SCAN = 80;

enum GPUMode : ubyte {
    HORIZ_BLANK     = 0,
    VERT_BLANK      = 1,
    SCANLINE_OAM    = 2,
    SCANLINE_VRAM   = 3
}

/**
 * Control flags for the LCD control register
 */
enum LCDControlFlag : ubyte {
    BG_DISPLAY          = 0b00000001,
    OBJ_ENABLE          = 0b00000010,
    OBJ_SIZE            = 0b00000100,
    BG_TILE_MAP_SELECT  = 0b00001000,
    BG_TILE_DATA_SELECT = 0b00010000,
    WINDOW_ENABLE       = 0b00100000,
    WINDOW_MAP_SELECT   = 0b01000000,
    LCD_ENABLE          = 0b10000000
}

enum LCDStatusFlag : ubyte {
    HBLANK_INTERRUPT        = 0b00001000,
    VBLANK_INTERRUPT        = 0b00010000,
    OAM_INTERRUPT           = 0b00100000,
    COINCIDENCE_INTERRUPT   = 0b01000000,
    COINCIDENCE_FLAG        = 0b10000000
}

class GPU {

    private GPUMode state;
    private int stateClock; // Number of cycles have been in current state
    private Clock clock;
    private Display display;

    private ubyte controlRegister;
    private ubyte lcdStatusRegister;
    private ubyte curScanline;

    private ubyte scanlineCompare; // Scanline to compare the curScanline with

    private ubyte scrollY, scrollX;

    private ubyte[] vram;
    private ubyte[] oam;

    @safe this(Display d, Clock clk) {
        setState(GPUMode.HORIZ_BLANK);
        this.clock = clk;
        this.display = d;
        this.vram = new ubyte[8192];
        this.oam = new ubyte[160];
    }

    void step() {
        // TODO if LCD isn't disabled, ...

        this.stateClock += clock.getElapsedCycles();

        final switch(state) {
            case GPUMode.HORIZ_BLANK:
            if(stateClock >= CYCLES_PER_HBLANK) { // It's been long enough for an HBlank to finish
                curScanline++; // Move down a line
                checkCoincidence();

                if(curScanline == GB_DISPLAY_HEIGHT - 1) { // Last line, enter vblank
                    updateDisplay();
                    setState(GPUMode.VERT_BLANK);

                    // TODO flag vblank interrupt
                } else { // Go to OAM read
                    setState(GPUMode.SCANLINE_OAM);
                }

                updateDisplay();

                stateClock -= CYCLES_PER_HBLANK; // Reset the state clock
            }
            break;

            case GPUMode.VERT_BLANK:
            if(stateClock >= CYCLES_PER_VBLANK) {
                curScanline++; // Move down a line

                if(curScanline > GB_DISPLAY_HEIGHT - 1 + 10) { // VBlank period is between 144 and 153
                    // Restart
                    setState(GPUMode.SCANLINE_OAM);
                    curScanline = 0;
                }
                checkCoincidence();

                stateClock -= CYCLES_PER_VBLANK; // Reset the state clock
            }
            break;

            case GPUMode.SCANLINE_OAM:
            if(stateClock >= CYCLES_PER_OAM_SCAN) {
                setState(GPUMode.SCANLINE_VRAM); // Advance to next state
                stateClock -= CYCLES_PER_OAM_SCAN; // Reset the state clock
            }
            break;

            case GPUMode.SCANLINE_VRAM:
            if(stateClock >= CYCLES_PER_VRAM_SCAN) {
                setState(GPUMode.HORIZ_BLANK); // Enter HBlank

                // Draw a line to the display
                updateCurLine();
                
                stateClock -= CYCLES_PER_VRAM_SCAN; // Reset the state clock
            }
        }
    }

    @safe private void setState(in GPUMode mode) {
        this.state = mode;
        this.lcdStatusRegister = (this.lcdStatusRegister & 0b11111100) | mode;
    }

    private void updateDisplay() {
        // Just draw VRAM to the display to make me happy that someting shows

        writeln("Update display!");

        for(int i = 0; i < 8192; i++) {
            ubyte x = cast(ubyte)((i*2) % 128);
            ubyte y = cast(ubyte)((i*2) / 128);

            ubyte x2 = cast(ubyte)((i*2+1) % 128);
            ubyte y2 = cast(ubyte)((i*2+1) / 128);

            display.setPixelGB(x, y, vram[i] & 0b11);
            display.setPixelGB(x2, y2, (vram[i] & 0b110000) >> 4);
        }
    }

    /**
     * Update the current line on the display
     */
    private void updateCurLine() {
    }

    @safe bool isLCDEnabled() const {
        return isControlFlagSet(LCDControlFlag.LCD_ENABLE);
    }

    /**
     * Returns true if the flag bit is 1, false otherwise
     */
    @safe bool isControlFlagSet(in LCDControlFlag f) const {
        return (controlRegister & f) != 0;
    }

    @safe @property ubyte getLCDControl() const {
        return this.controlRegister;
    }

    @safe @property void setLCDControl(in ubyte val) {
        this.controlRegister = val;
    }

    @safe @property ubyte getCurScanline() const {
        return this.curScanline;
    }

    @safe void resetCurScanline() {
        this.curScanline = 0;
        checkCoincidence();
    }

    @safe @property GPUMode getLCDStatus() const {
        return this.state;
    }

    @safe @property void setLCDStatus(in ubyte m) {
        this.lcdStatusRegister = (m & 0b11111000) | (this.lcdStatusRegister & 0b111);
        this.state = to!GPUMode(m & 0b11);
    }

    @safe @property void setScanlineCompare(in ubyte c) {
        this.scanlineCompare = c;
        checkCoincidence();
    }

    @safe @property ubyte getScanlineCompare() const {
        return this.scanlineCompare;
    }

    @safe private void setLCDStatusFlag(in LCDStatusFlag f, in bool set) {
        if(set) {
            lcdStatusRegister = lcdStatusRegister | f; // ORing with the flag will set it true
        } else {
            lcdStatusRegister = lcdStatusRegister & ~f; // ANDing with the inverse of f will set the flag to 0
        }
    }

    @safe private void checkCoincidence() {
        setLCDStatusFlag(LCDStatusFlag.COINCIDENCE_FLAG, this.getCurScanline() == this.getScanlineCompare);

        // TODO interrupt handing
    }

    @safe @property ubyte getScrollX() const {
        return this.scrollX;
    }

    @safe @property ubyte getScrollY() const {
        return this.scrollY;
    }

    @safe @property void setScrollX(in ubyte val) {
        this.scrollX = val;
    }

    @safe @property void setScrollY(in ubyte val) {
        this.scrollY = val;
    }

    @safe void setVRAM(in ushort addr, in ubyte val)
    in {
        assert(addr < 8192);
    }
    body {
        this.vram[addr] = val;
    }

    @safe ubyte getVRAM(in ushort addr) const 
    in {
        assert(addr < 8192);
    }
    body {
        return this.vram[addr];
    }

    @safe void setOAM(in ushort addr, in ubyte val)
    in {
        assert(addr < 160);
    }
    body {
        this.oam[addr] = val;
    }

    @safe ubyte getOAM(in ushort addr) const 
    in {
        assert(addr < 160);
    }
    body {
        return this.oam[addr];
    }

}