import std.conv;
import std.stdio;

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

/**
 * Control flags for the LCD control register
 */
enum LCDControlFlag : ubyte
{
    BG_DISPLAY = 0b00000001,
    OBJ_ENABLE = 0b00000010,
    OBJ_SIZE = 0b00000100,
    BG_TILE_MAP_SELECT = 0b00001000,
    BG_TILE_DATA_SELECT = 0b00010000,
    WINDOW_ENABLE = 0b00100000,
    WINDOW_MAP_SELECT = 0b01000000,
    LCD_ENABLE = 0b10000000
}

enum LCDStatusFlag : ubyte
{
    HBLANK_INTERRUPT = 0b00001000,
    VBLANK_INTERRUPT = 0b00010000,
    OAM_INTERRUPT = 0b00100000,
    COINCIDENCE_INTERRUPT = 0b01000000,
    COINCIDENCE_FLAG = 0b10000000
}

class GPU
{

    private GPUMode state;
    private int stateClock; // Number of cycles have been in current state
    private Clock clock;
    private Display display;
    private InterruptHandler iuptHandler;

    private ubyte controlRegister;
    private ubyte lcdStatusRegister;
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
        this.lcdStatusRegister = (this.lcdStatusRegister & 0b11111100) | mode;
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

        if(isControlFlagSet(LCDControlFlag.BG_DISPLAY)) {
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
            ubyte[8][8] tile = tilemapLookup(backgroundTileMapMode, tileRow, tileCol);

            // Render out the tile at the current scanline
            ubyte color = tile[scrolledY % 8][scrolledX % 8];

            // Apply the current palette
            color = (bgPalette >> color) & 0b11;
            display.setPixelGB(x, lineNum, color);
        }
    }
 
    @safe bool isLCDEnabled() const
    {
        return isControlFlagSet(LCDControlFlag.LCD_ENABLE);
    }

    /**
     * Returns true if the flag bit is 1, false otherwise
     */
    @safe bool isControlFlagSet(in LCDControlFlag f) const
    {
        return (controlRegister & f) != 0;
    }

    @safe @property ubyte getLCDControl() const
    {
        return this.controlRegister;
    }

    @safe @property void setLCDControl(in ubyte val)
    {
        this.controlRegister = val;
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
        this.lcdStatusRegister = (m & 0b11111000) | (this.lcdStatusRegister & 0b111);
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

    @safe private void setLCDStatusFlag(in LCDStatusFlag f, in bool set)
    {
        if (set)
        {
            lcdStatusRegister = lcdStatusRegister | f; // ORing with the flag will set it true
        }
        else
        {
            lcdStatusRegister = lcdStatusRegister & ~f; // ANDing with the inverse of f will set the flag to 0
        }
    }

    @safe private void checkCoincidence()
    {
        setLCDStatusFlag(LCDStatusFlag.COINCIDENCE_FLAG,
                this.getCurScanline() == this.getScanlineCompare);

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
        updateTile(addr, val);
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

    @safe @property TileMapDisplay backgroundTileMapMode() {
        return isControlFlagSet(LCDControlFlag.BG_TILE_MAP_SELECT) ? TileMapDisplay.WINDOW_MAP : TileMapDisplay.BACKGROUND_MAP;
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
