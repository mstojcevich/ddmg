import std.conv;
import std.stdio;
import std.bitmanip;

import clock, display, interrupt;

private const CYCLES_PER_HBLANK = 204; // Cycles for a line of hblank
private const CYCLES_PER_VBLANK = 456; // Cycles for a line of vblank
private const CYCLES_PER_VRAM_SCAN = 172;
private const CYCLES_PER_OAM_SCAN = 80;

// Index in VRAM that tiles start at
private const TILE_START_INDEX = 0;

// Number of tiles in the tilemap
// Each tile is sized 8x8 pixels and has a color depth of 4 colors.
// The tiles stored at 8000-8FFF are used for background and sprites. Numbered 0 to 255.
// The tiles stored at 8800-97FF are used for background and window display. Numbered -128 to 127.
private const NUM_TILES = 384;

enum TileMapDisplay : bool {
    BACKGROUND_MAP = false,
    WINDOW_MAP = true
}

enum GPUMode : ubyte
{
    HORIZ_BLANK = 0,
    VERT_BLANK = 1,
    SCANLINE_OAM = 2,
    SCANLINE_VRAM = 3
}

union LCDControl {
    ubyte data;
    mixin(bitfields!(
        bool, "bgDisplay", 1,
        bool, "objEnable", 1,
        bool, "objSize", 1,
        TileMapDisplay, "bgMapSelect", 1,
        bool, "bgDataSelect", 1,
        bool, "windowEnable", 1,
        bool, "windowMapSelect", 1,
        bool, "lcdEnable", 1
    ));
}

union LCDStatus {
    ubyte data;
    mixin(bitfields!(
        GPUMode, "gpuMode", 2,
        bool, "coincidenceFlag", 1,
        bool, "hblankInterrupt", 1,
        bool, "vblankInterrupt", 1,
        bool, "oamInterrupt", 1,
        bool, "coincidenceInterrupt", 1,
        bool, "", 1
    ));
}

enum SpritePriority : bool
{
    ABOVE_BACKGROUND = false,
    BEHIND_BACKGROUND = true
}

struct OAMSprite {
    align(1): // Tightly pack the bytes
        ubyte y;
        ubyte x;
        ubyte tileNum;
        union {
            ubyte options;
            mixin(bitfields!(
                uint, "", 3,        // Color palette: used on CGB only
                bool, "", 1,        // Character bank: used on CGB only
                bool, "palette", 1, // Palette to use: unused on CGB
                bool, "xflip", 1,   // Whether to flip horizontally
                bool, "yflip", 1,   // Whether to flip vertically
                SpritePriority, "priority", 1 // Whether to force above the background
            ));
        }
}

class GPU
{

    private GPUMode state;
    private int stateClock; // Number of cycles have been in current state
    private Clock clock;
    private Display display;
    private InterruptHandler iuptHandler;

    private LCDControl controlRegister;
    private LCDStatus lcdStatusRegister;
    private ubyte curScanline;

    private ubyte scanlineCompare; // Scanline to compare the curScanline with

    private ubyte scrollY, scrollX;

    private ubyte[] vram;
    private ubyte[] oam;

    // This holds the palette number (a number from 0 to 3)
    private ubyte[8][8][NUM_TILES] tileset;

    private ubyte bgPalette; // FF47 BG Palette Data register
    private ubyte objPalette0; // FF48 Object Palette 0 Data
    private ubyte objPalette1; // FF49 Object Palette 1 Data

    @safe this(Display d, Clock clk, InterruptHandler ih)
    {
        setState(GPUMode.HORIZ_BLANK);
        this.clock = clk;
        this.display = d;
        this.vram = new ubyte[8192];
        this.oam = new ubyte[160];
        this.iuptHandler = ih;
        this.controlRegister.data = 0;

        bgPalette = 0b00011011;
    }

    void step()
    {
        // TODO if LCD isn't disabled, ...

        this.stateClock += clock.getElapsedCycles();

        final switch (state)
        {
        case GPUMode.HORIZ_BLANK:
            if (stateClock >= CYCLES_PER_HBLANK)
            { // It's been long enough for an HBlank to finish
                curScanline++; // Move down a line
                checkCoincidence();

                if (curScanline == GB_DISPLAY_HEIGHT - 1)
                { // Last line, enter vblank
                    updateDisplay();
                    setState(GPUMode.VERT_BLANK);

                    // TODO vblank interrupt
                }
                else
                { // Go to OAM read
                    setState(GPUMode.SCANLINE_OAM);
                }

                stateClock -= CYCLES_PER_HBLANK; // Reset the state clock
            }
            break;

        case GPUMode.VERT_BLANK:
            if (stateClock >= CYCLES_PER_VBLANK)
            {
                curScanline++; // Move down a line

                if (curScanline > GB_DISPLAY_HEIGHT - 1 + 10)
                { // VBlank period is between 144 and 153
                    // Restart
                    setState(GPUMode.SCANLINE_OAM);
                    curScanline = 0;
                }
                checkCoincidence();

                stateClock -= CYCLES_PER_VBLANK; // Reset the state clock
            }
            break;

        case GPUMode.SCANLINE_OAM:
            if (stateClock >= CYCLES_PER_OAM_SCAN)
            {
                setState(GPUMode.SCANLINE_VRAM); // Advance to next state
                stateClock -= CYCLES_PER_OAM_SCAN; // Reset the state clock
            }
            break;

        case GPUMode.SCANLINE_VRAM:
            if (stateClock >= CYCLES_PER_VRAM_SCAN)
            {
                setState(GPUMode.HORIZ_BLANK); // Enter HBlank

                // Draw a line to the display
                updateCurLine();

                stateClock -= CYCLES_PER_VRAM_SCAN; // Reset the state clock
            }
        }
    }

    @safe private void setState(in GPUMode mode)
    {
        this.state = mode;
        this.lcdStatusRegister.gpuMode = mode;
    }

    private void updateDisplay()
    {
        display.drawFrame();
    }

    /**
     *
     */
    @safe private void updateTile(in ushort addr, in ubyte val)
    in
    {
        assert(addr < 8192);
    }
    body
    {
        // Tile data:
        // Byte 0-1 = first line (upper 8 pixels)
        // Byte 2-3 = next line
        // ...

        // Each tile is 16 bytes long (8 lines, each 2 bytes)
        ushort tileNum = (addr - TILE_START_INDEX) / 16;

        if (tileNum >= NUM_TILES)
        {
            return;
        }

        // Y level of the tile being updated
        ubyte y = cast(ubyte)(addr / 2) % 8; // 2 bytes per line

        // The second byte contains the upper bits of the color
        // So this indicates whether this byte contains the upper or lower bits
        bool upperBits = addr % 2 == 1;

        for (ubyte x = 0; x < 8; x++)
        {
            // Inverted X since the bits are read backwards
            ubyte invX = cast(ubyte)(7 - x);

            int bit1 = (vram[upperBits ? (addr - 1) : addr] & (0b1 << invX)) > 0 ? 1 : 0;
            int bit2 = (vram[upperBits ? addr : (addr + 1)] & (0b1 << invX)) > 0 ? 2 : 0;

            tileset[tileNum][y][x] = cast(ubyte)(bit1 + bit2);
        }
    }

    /**
     * Update the current line on the display
     */
    private void updateCurLine()
    {
        // Don't worry about stuff off of the screen
        if(curScanline > GB_DISPLAY_HEIGHT - 1) {
            return;
        }

        if(controlRegister.bgDisplay) {
            renderBackground(curScanline);
        }
    }

    /**
     * Renders the background for a specific line onto the display
     */
    private void renderBackground(ubyte lineNum) {
        // The current Y position, shifted by the scroll register
        ubyte scrolledY = cast(ubyte)(lineNum + scrollY);
        // Because the ubyte cast will wrap past 255, we don't need to manually wrap it
        // This is because the gameboy wraps at 255, not the screen width

        // The number of the row of the current tile
        ubyte tileRow = scrolledY / 8; // 8 pixels per tile

        // Go through the entire width of the scanline
        for(ubyte x = 0; x < GB_DISPLAY_WIDTH; x++) {
            ubyte scrolledX = cast(ubyte)(x + scrollX);
            // Because the ubyte cast will wrap past 255, we don't need to manually wrap it
            // This is because the gameboy wraps at 255, not the screen width

            // The number of the column of the current tile
            ubyte tileCol = scrolledX / 8;
            
            // The current tile, as a 2d array of colors
            ubyte[8][8] tile = tilemapLookup(controlRegister.bgMapSelect, tileRow, tileCol);

            // Render out the tile at the current scanline
            ubyte color = tile[scrolledY % 8][scrolledX % 8];

            // Apply the current palette
            color = (bgPalette >> color) & 0b11;
            display.setPixelGB(x, lineNum, color);
        }
    }
 
    @safe bool isLCDEnabled() const
    {
        return this.controlRegister.lcdEnable;
    }

    @safe @property ubyte getLCDControl() const
    {
        return this.controlRegister.data;
    }

    @safe @property void setLCDControl(in ubyte val)
    {
        this.controlRegister.data = val;
    }

    @safe @property ubyte getCurScanline() const
    {
        return this.curScanline;
    }

    @safe void resetCurScanline()
    {
        this.curScanline = 0;
        checkCoincidence();
    }

    @safe @property GPUMode getLCDStatus() const
    {
        return this.state;
    }

    @safe @property void setLCDStatus(in ubyte m)
    {
        this.lcdStatusRegister.data = (m & 0b11111000) | (this.lcdStatusRegister.data & 0b111);
        this.state = to!GPUMode(m & 0b11);
    }

    @safe @property void setScanlineCompare(in ubyte c)
    {
        this.scanlineCompare = c;
        checkCoincidence();
    }

    @safe @property ubyte getScanlineCompare() const
    {
        return this.scanlineCompare;
    }

    @safe private void checkCoincidence()
    {
        lcdStatusRegister.coincidenceFlag = getCurScanline() == getScanlineCompare();

        // TODO interrupt handing
    }

    @safe @property ubyte getScrollX() const
    {
        return this.scrollX;
    }

    @safe @property ubyte getScrollY() const
    {
        return this.scrollY;
    }

    @safe @property void setScrollX(in ubyte val)
    {
        this.scrollX = val;
    }

    @safe @property void setScrollY(in ubyte val)
    {
        this.scrollY = val;
    }

    @safe void setVRAM(in ushort addr, in ubyte val)
    in
    {
        assert(addr < 8192);
    }
    body
    {
        this.vram[addr] = val;

        // TODO support the 8800-97ff tile data
        if(addr >= 0x0000 && addr <= 0x0FFF) {
            updateTile(addr, val);
        }
    }

    @safe ubyte getVRAM(in ushort addr) const
    in
    {
        assert(addr < 8192);
    }
    body
    {
        return this.vram[addr];
    }

    @safe void setOAM(in ushort addr, in ubyte val)
    in
    {
        assert(addr < 160);
    }
    body
    {
        this.oam[addr] = val;
    }

    @safe ubyte getOAM(in ushort addr) const
    in
    {
        assert(addr < 160);
    }
    body
    {
        return this.oam[addr];
    }

    @safe @property ubyte backgroundPalette() const
    {
        return bgPalette;
    }

    @safe @property ubyte backgroundPalette(ubyte bp)
    {
        return bgPalette = bp;
    }

    /**
     * Looks up a tile using the tilemap for the given row and column
     *
     * @param row Row (y-value) of the tile to look up. Between 0 and 31 inclusive
     * @parma col Column (x-value) of the tile to look up. Between 0 and 31 inclusive
     * @returns An 8x8 ubyte array representing the tile's colors
     */
    @safe ubyte[8][8] tilemapLookup(TileMapDisplay mapType, ubyte row, ubyte col)
    in {
        assert(row < 32);
        assert(col < 32);
    }
    body {
        // If the background map is used, the index of the map is 0x9800.
        // If the window tile map is used, the index is 0x1C00
        uint mapLocation = mapType == TileMapDisplay.BACKGROUND_MAP ? 0x1800 : 0x1C00;
        
        // Offset in the tile map for the current tile. The map is y-major.
        uint tileMapOffset = row * 32 + col; // 256/8 = 32 tiles per row

        // The index of the tile in the tileset. Pulled from the tilemap.
        ubyte tileIndex = vram[mapLocation + tileMapOffset];

        return tileset[tileIndex];
    }

}
