module graphics.gpu;

// TODO sprites can be 16x8

import std.conv;
import std.stdio;
import std.bitmanip;
import std.algorithm.comparison;

import graphics.display, interrupt;

private const CYCLES_PER_OAM_SEARCH = 80; // Searching OAM RAM
private const CYCLES_PER_DATA_TRANSFER = 172; // Transfering data to LCD driver
private const CYCLES_PER_HBLANK = 204;
private const CYCLES_PER_VBLANK_LINE = 456; // Cycles for a line of vblank

// Index in VRAM that tiles start at
private const TILE_START_INDEX = 0;

// Number of tiles in the tilemap
// Each tile is sized 8x8 pixels and has a color depth of 4 colors.
// The tiles stored at 8000-8FFF are used for background and sprites. Numbered 0 to 255.
// The tiles stored at 8800-97FF are used for background and window display. Numbered -128 to 127.
private const NUM_TILES = 384;

// Size of sprites in pixels. Sprites are 8x8
private const TILE_SIZE = 8;

enum TileMapDisplay : bool {
    BACKGROUND_MAP = false,
    WINDOW_MAP = true
}

enum GPUMode : ubyte
{
    HORIZ_BLANK = 0,
    VERT_BLANK = 1,
    OAM_SEARCH = 2,
    DATA_TRANSFER = 3
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
        TileMapDisplay, "windowMapSelect", 1,
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

enum SpritePriority : bool {
    ABOVE_BACKGROUND = false,
    BEHIND_BACKGROUND = true
}

/**
 * The palette to use when drawing a sprite.
 * A sprite can specify whether it wants to use OBP0 (0xFF48) or OBP1 (0xFF49)
 */
enum SpritePalette : bool {
    OBP0 = false,
    OBP1 = true
}

struct SpriteAttributes {
    align(1): // Tightly pack the bytes
        ubyte y;
        ubyte x;
        ubyte tileNum;
        union {
            ubyte options;
            mixin(bitfields!(
                uint, "", 3,        // Color palette: used on CGB only
                bool, "", 1,        // Character bank: used on CGB only
                SpritePalette, "palette", 1, // Palette to use: unused on CGB
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
    private Display display;
    private InterruptHandler iuptHandler;

    private LCDControl controlRegister;
    private LCDStatus lcdStatusRegister;
    private ubyte curScanline;

    private ubyte scanlineCompare; // Scanline to compare the curScanline with

    private ubyte scrollY, scrollX;

    /// The position of the window on screen
    private ubyte wX, wY;

    private ubyte[] vram;
    private ubyte[] oam;

    // This holds the palette number (a number from 0 to 3)
    private ubyte[TILE_SIZE][TILE_SIZE][NUM_TILES] tileset;

    private ubyte bgPalette; // FF47 BG Palette Data register
    private ubyte objPalette0; // FF48 Object Palette 0 Data
    private ubyte objPalette1; // FF49 Object Palette 1 Data

    @safe this(Display d, InterruptHandler ih)
    {
        setState(GPUMode.HORIZ_BLANK);
        this.display = d;
        
        this.vram = new ubyte[8192];
        this.oam = new ubyte[160];

        this.iuptHandler = ih;
        this.controlRegister.data = 0x90;
        this.lcdStatusRegister.data = 0x85;

        bgPalette = 0b11111100;
        objPalette0 = 0b11111111;
        objPalette1 = 0b11111111;
    }

    @safe void step(uint cyclesElapsed)
    {
        this.stateClock += cyclesElapsed;

        final switch (state)
        {
        case GPUMode.OAM_SEARCH:
            if (stateClock >= CYCLES_PER_OAM_SEARCH)
            {
                setState(GPUMode.DATA_TRANSFER); // Advance to next state
                stateClock -= CYCLES_PER_OAM_SEARCH; // Reset the state clock
            }
            break;

        case GPUMode.DATA_TRANSFER:
            if (stateClock >= CYCLES_PER_DATA_TRANSFER)
            {
                if(lcdStatusRegister.hblankInterrupt) {
                    iuptHandler.fireInterrupt(Interrupts.LCD_STATUS);
                }
                setState(GPUMode.HORIZ_BLANK); // Enter HBlank

                // Draw a line to the display
                updateCurLine();

                stateClock -= CYCLES_PER_DATA_TRANSFER; // Reset the state clock
            }
            break;

        case GPUMode.HORIZ_BLANK:
            if (stateClock >= CYCLES_PER_HBLANK)
            { // It's been long enough for an HBlank to finish
                curScanline++; // Move down a line
                checkCoincidence();

                if (curScanline == GB_DISPLAY_HEIGHT - 1)
                { // Last line, enter vblank
                    if(controlRegister.lcdEnable) {
                        iuptHandler.fireInterrupt(Interrupts.VBLANK);
                    }

                    if(lcdStatusRegister.vblankInterrupt || lcdStatusRegister.oamInterrupt) {
                        iuptHandler.fireInterrupt(Interrupts.LCD_STATUS);
                    }

                    setState(GPUMode.VERT_BLANK);
                }
                else
                { // Go to OAM read
                    if(lcdStatusRegister.oamInterrupt) {
                        iuptHandler.fireInterrupt(Interrupts.LCD_STATUS);
                    }

                    setState(GPUMode.OAM_SEARCH);
                }

                stateClock -= CYCLES_PER_HBLANK; // Reset the state clock
            }
            break;

        case GPUMode.VERT_BLANK:
            if (stateClock >= CYCLES_PER_VBLANK_LINE)
            {
                curScanline++; // Move down a line

                if (curScanline >= GB_DISPLAY_HEIGHT + 10)
                { // VBlank period is between 144 and 153
                    // Restart
                    if(lcdStatusRegister.oamInterrupt) {
                        iuptHandler.fireInterrupt(Interrupts.LCD_STATUS);
                    }
                    setState(GPUMode.OAM_SEARCH);
                    curScanline = 0;
                    
                    updateDisplay();
                }
                checkCoincidence();

                stateClock -= CYCLES_PER_VBLANK_LINE; // Reset the state clock
            }
            break;
        }
    }

    @safe private void setState(in GPUMode mode)
    {
        this.state = mode;
        this.lcdStatusRegister.gpuMode = mode;
    }

    @safe private void updateDisplay()
    {
        if(!controlRegister.lcdEnable) {
            return;
        }

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
        ubyte y = cast(ubyte)(addr / 2) % TILE_SIZE; // 2 bytes per line

        // The second byte contains the upper bits of the color
        // So this indicates whether this byte contains the upper or lower bits
        bool upperBits = addr % 2 == 1;

        for (ubyte x = 0; x < TILE_SIZE; x++)
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
    @safe private void updateCurLine()
    {
        // Don't worry about stuff off of the screen
        if(curScanline > GB_DISPLAY_HEIGHT - 1) {
            return;
        }

        if(!controlRegister.lcdEnable) {
            return;
        }

        if(controlRegister.bgDisplay) {
            renderBackground(curScanline);
        }
        if(controlRegister.windowEnable) {
            renderWindow(curScanline);
        }
        if(controlRegister.objEnable) {
            renderSprites(curScanline);
        }
    }

    /**
     * Renders sprites for a specific line onto the display
     */
    @safe private void renderSprites(ubyte lineNum) {
        // TODO "Because of a limitation of hardware, only ten sprites can be displayed per scan line"

        for(int i = 0; i < 40; i++) { // There are 40 different sprites
            SpriteAttributes attrs = (cast(SpriteAttributes[]) oam)[i];

            // Row on the sprite that this scanline represents
            int tileRow = lineNum - attrs.y + 16;

            // Ensure that some part of the sprite lies on the current scanline
            if(tileRow >= 0 && tileRow < TILE_SIZE) {
                ubyte palette = attrs.palette == SpritePalette.OBP0 ? obp0 : obp1;
                
                ubyte[TILE_SIZE][TILE_SIZE] tile = tileset[attrs.tileNum];
                ubyte[TILE_SIZE] row = tile[attrs.yflip ? TILE_SIZE - 1 - tileRow : tileRow];

                for(ubyte x = cast(ubyte) min(attrs.x, GB_DISPLAY_WIDTH + TILE_SIZE); 
                    x < min(attrs.x + TILE_SIZE, GB_DISPLAY_WIDTH + TILE_SIZE); x++) {
                    if(cast(ubyte)(x - TILE_SIZE) >= GB_DISPLAY_WIDTH) {
                        continue;
                    } 

                    // Get the color of the pixel in the tile
                    ubyte color = row[attrs.xflip ? TILE_SIZE - 1 - (x - attrs.x) : (x - attrs.x)];

                    // Don't draw invisible pixels
                    // Don't draw pixels behind the background
                    if(color == 0 || (attrs.priority == SpritePriority.BEHIND_BACKGROUND 
                        && display.getPixelGB(cast(ubyte)(x - TILE_SIZE), lineNum) != 0)) {
                        continue;
                    }

                    // Apply the current palette
                    color = (palette >> (color * 2)) & 0b11;
                    display.setPixelGB(cast(ubyte)(x - TILE_SIZE), lineNum, color);
                }
            }
        }
    }

    /// Renders the window at the current scanline
    @safe private void renderWindow(ubyte lineNum) {
        // Check if the window is visible at the scanline
        if(lineNum >= wY && lineNum < wY + GB_DISPLAY_HEIGHT) {
            ubyte tileRow = cast(ubyte)(lineNum - wY) / TILE_SIZE;

            // Go through the entire width of the scanline
            for(ubyte x = 0; x < GB_DISPLAY_WIDTH; x++) {
                // The number of the column of the current tile
                ubyte tileCol = x / TILE_SIZE;
                
                // The current tile, as a 2d array of colors
                ubyte[TILE_SIZE][TILE_SIZE] tile = tilemapLookup(controlRegister.windowMapSelect, tileRow, tileCol);

                // Render out the tile at the current scanline
                ubyte color = tile[lineNum % TILE_SIZE][x % TILE_SIZE];

                // Apply the current palette
                color = (bgPalette >> (color * 2)) & 0b11;

                ubyte effX = cast(ubyte)(x + wX - 7);
                if(effX < GB_DISPLAY_WIDTH) {
                    display.setPixelGB(effX, lineNum, color);
                }
            }
        }
    }

    /**
     * Renders the background for a specific line onto the display
     */
    @safe private void renderBackground(ubyte lineNum) {
        // The current Y position, shifted by the scroll register
        ubyte scrolledY = cast(ubyte)(lineNum + scrollY);
        // Because the ubyte cast will wrap past 255, we don't need to manually wrap it
        // This is because the gameboy wraps at 255, not the screen width

        // The number of the row of the current tile
        ubyte tileRow = scrolledY / TILE_SIZE; // 8 pixels per tile

        // Go through the entire width of the scanline
        for(ubyte x = 0; x < GB_DISPLAY_WIDTH; x++) {
            ubyte scrolledX = cast(ubyte)(x + scrollX);
            // Because the ubyte cast will wrap past 255, we don't need to manually wrap it
            // This is because the gameboy wraps at 255, not the screen width

            // The number of the column of the current tile
            ubyte tileCol = scrolledX / TILE_SIZE;
            
            // The current tile, as a 2d array of colors
            ubyte[TILE_SIZE][TILE_SIZE] tile = tilemapLookup(controlRegister.bgMapSelect, tileRow, tileCol);

            // Render out the tile at the current scanline
            ubyte color = tile[scrolledY % TILE_SIZE][scrolledX % TILE_SIZE];

            // Apply the current palette
            color = (bgPalette >> (color * 2)) & 0b11;
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
        bool lcdWasOn = this.controlRegister.lcdEnable;

        this.controlRegister.data = val;

        /*
        When the LCD is turned on, the controller goes to
        the beginning of the first scanline.
         */
        if(!lcdWasOn && this.controlRegister.lcdEnable) {
            resetCurScanline();
        }
    }

    @safe @property ubyte getCurScanline() const
    {
        return this.curScanline;
    }

    @safe void resetCurScanline()
    {
        this.curScanline = 0;
        checkCoincidence();

        // Start one clock cycle into the line
        setState(GPUMode.OAM_SEARCH);
        stateClock = 4;
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

        // TODO is this right? There's something about LYC00 or something
        if(lcdStatusRegister.coincidenceInterrupt) {
            iuptHandler.fireInterrupt(Interrupts.LCD_STATUS);
        }
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

    @safe @property void windowX(in ubyte val) {
        this.wX = val;
    }

    @safe @property ubyte windowX() const {
        return this.wX;
    }

    @safe @property void windowY(in ubyte val) {
        this.wY = val;
    }

    @safe @property ubyte windowY() const {
        return this.wY;
    }

    @safe void setVRAM(in ushort addr, in ubyte val)
    in
    {
        assert(addr < 8192);
    }
    body
    {
        this.vram[addr] = val;

        if(addr >= 0x0000 && addr <= 0x17FF) {
            updateTile(addr, val);

            // TODO BG can have super priority
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

    @safe @property ubyte obp0() const {
        return objPalette0;
    }

    @safe @property ubyte obp0(ubyte obp0) {
        return objPalette0 = obp0;
    }

    @safe @property ubyte obp1() const {
        return objPalette1;
    }

    @safe @property ubyte obp1(ubyte obp1) {
        return objPalette1 = obp1;
    }

    /**
     * Looks up a tile using the tilemap for the given row and column
     *
     * @param row Row (y-value) of the tile to look up. Between 0 and 31 inclusive
     * @parma col Column (x-value) of the tile to look up. Between 0 and 31 inclusive
     * @returns An 8x8 ubyte array representing the tile's colors
     */
    @safe ubyte[TILE_SIZE][TILE_SIZE] tilemapLookup(TileMapDisplay mapType, ubyte row, ubyte col)
    in {
        assert(row < 32);
        assert(col < 32);
    }
    body {
        // If the background map is used, the index of the map is 0x1800.
        // If the window tile map is used, the index is 0x1C00
        uint mapLocation = mapType == TileMapDisplay.BACKGROUND_MAP ? 0x1800 : 0x1C00;
        
        // Offset in the tile map for the current tile. The map is y-major.
        uint tileMapOffset = row * 32 + col; // 256/8 = 32 tiles per row

        // The index of the tile in the tileset. Pulled from the tilemap.
        ubyte tileIndex = vram[mapLocation + tileMapOffset];

        return tileset[controlRegister.bgDataSelect ? tileIndex : cast(byte)(tileIndex) + 256];
    }

}
