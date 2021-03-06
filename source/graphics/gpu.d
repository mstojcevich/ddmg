/*
ACCURACY WARNING

This is not particularly accurate as far as timing goes.

I don't emulate the exact timing for the stages which can
vary in timing.
*/

// TODO how do the interrupts specified in LCDC work? I see some sources mentioning you can only select 1 type of interrupt...

module graphics.gpu;

import frontend;
import graphics.display;
import interrupt;

import std.bitmanip;
import std.stdio;

import core.thread;

/// The width and height of the gameboy display in pixels
private const DISPLAY_WIDTH = 160, DISPLAY_HEIGHT = 144;

/// The LCD controller operates for a total of 154 lines (vblank goes through a total of 10 lines)
private const VIRTUAL_HEIGHT = 154;

/// The width of the window in pixels
private const WINDOW_WIDTH = DISPLAY_WIDTH + 7; // Window X is offset by 7, so you can draw 7 more pixels if you set it to 0

/// The height of the window in pixels
private const WINDOW_HEIGHT = DISPLAY_HEIGHT;

/// The size of the background in pixels. This is both the width and the height of the background.
private const BG_SIZE = 256;

/// The size of tiles in pixels. This is both the width and the height of a given tile.
private const TILE_SIZE = 8;

/// The size of the background in tiles. This is both the width and the height.
private const BG_SIZE_TILES = BG_SIZE / TILE_SIZE;

/// VRAM stores a total of 384 different tiles
private const NUM_TILES = 384;

/// Each tile is 16 bytes large because each line is 2 bytes
private const TILE_SIZE_BYTES = 16;

/// The size of sprite attributes in bytes
private const BYTES_PER_SPRITE_ATTR = 4;
/// The number of sprite attribtes in OAM memory
private const NUM_SPRITES = 40;

// Memory mappings
private const BG_MAP_A_BEGIN  = 0x1800; /// Background map A begins at 0x9800, which is 0x1800 in VRAM
private const BG_MAP_A_END    = 0x1BFF; /// Background map A ends at 0x9BFF, which is 0x1BFF in VRAM
private const BG_MAP_B_BEGIN  = 0x1C00; /// Background map B begins at 0x9C00, which is 0x1C00 in VRAM
private const BG_MAP_B_END    = 0x1FFF; /// Background map B ends at 0x9FFF, which is 0x1FFF in VRAM
private const TILE_DATA_BEGIN = 0x0000; /// Tile data begins at 0x8000, which is 0x0000 in VRAM
private const TILE_DATA_END   = 0x17FF; /// Tile data ends at 0x97FF, which is 0x17FF in VRAM

// Timings
private const CYCLES_PER_LINE = 456; // Time to render a single scanline


/**
 * The GPU takes information from VRAM+OAM and processes it.
 * It prepares scanlines and sends them to the display to render.
 */
final class GPU : Fiber {

    /// The LCD control register (LCDC)
    private LCDControl control;

    /// The LCD status register (STAT)
    private LCDStatus status;

    /// The current scanline that is being updated. AKA LY
    private ubyte curScanline;

    /// The scanline to compare with for the conincidence (LY=LYC) interrupt. AKA LYC
    private ubyte scanlineCompare;

    private ubyte bgScrollY; /// SCY register: The y coordinate of the background at the top left of the display
    private ubyte bgScrollX; /// SCX register: The x coordinate of the background at the top left of the display

    /*
    The window works almost identically to the background.
    The main difference is that instead of scrolling the window,
    you specify where the top left of the window is located on the display.

    The window always overlays the background.
    */

    /// WX: The X position of the top left of the window on the screen
    private ubyte windowX;
    /// WY: The Y position of the top left of the window on the screen
    private ubyte windowY;

    /*
    There is a notion of both a tile "set" and a tile "map".
    A tileset is a collection of the pixel data of tiles.
    A tilemap is a mapping from coordinates on the screen to an index in the tileset. These are used for the background and window.
    */

    /// The background map stored at 0x9800-0x9BFF. Can be used by either the background or window.
    private TileMap tileMapA;

    /// The background map stored at 0x9C00-0x9FFF. Can be used by either the background or window.
    private TileMap tileMapB;

    /// The entirity of the tile data stored in VRAM. This is used for the tile sets.
    private ubyte[NUM_TILES * TILE_SIZE_BYTES] tileData;

    /// The tile data decoded into a form that is larger but easier to use
    private ubyte[TILE_SIZE][TILE_SIZE][NUM_TILES] tileSet;

    /// The palette to apply on the background pixels. Just a mapping from one color to another.
    private ubyte backgroundPalette;

    /// One of the two palettes to use for sprites
    private ubyte spritePaletteA, spritePaletteB;

    /// Sprite attribute memory (OAM)
    private ubyte[BYTES_PER_SPRITE_ATTR * NUM_SPRITES] spriteMemory;

    /// Internal STAT interrupt signal. STAT iupt is triggered when this goes from false to true
    private bool iuptSignal;

    /// The display to render onto
    private Display display;

    /// The interrupt handler to fire interrupts with
    private InterruptHandler iuptHandler;

    /// The frontend to update each frame
    private Frontend frontend;
    
    private Fiber fetcherFiber;
    private Fiber writerFiber;

    /**
     * Create a GPU that renders onto the specified display
     * and fires interrupts using the specified interrupt handler
     */
    @trusted this(Frontend frontend, InterruptHandler ih) {
        super(&run);

        this.fetcherFiber = new Fiber(&pixelFetcher);
        this.writerFiber = new Fiber(&pixelWriter);

        this.frontend = frontend;
        this.display = frontend.getDisplay;
        this.iuptHandler = ih;

        // Set the initial values. TODO bootrom support
        bootup();
    }

    // List of the visible sprites, value = sprite memory index, -1 = no sprite
    private int[10] visibleSprites; // filled by oamSearch

    /// Perform the OAM search stage of the line, determining which sprites are visible
    @safe private int oamSearch() { // STAGE 2 (0b10)
        auto cyclesSpent = 0;

        // Search the sprites and determine which are visible
        // NOTE that because the CPU can't access OAM during this stage,
        // our intra-stage timing doesn't matter all that much.
        // If we wanted to, we could probably do all this work in
        // the data transfer stage.
        status.gpuMode = GPUMode.OAM_SEARCH;
        updateStatIupt();

        // Number of visible sprites so far
        int spritesDrawn = 0;

        // It takes two cycles per visible sprite
        for(int i; i < NUM_SPRITES && spritesDrawn < 10; i++) {
            // Fetch attributes
            const attrs = this.sprites[i];

            // Determine if visible
            if (attrs.x != 0 && // x=0 means invisible
                    curScanline + 16 >= attrs.y &&
                    curScanline + 16 < attrs.y + spriteHeight) {
                // The sprite is visible on the current line
                visibleSprites[spritesDrawn] = i;
                spritesDrawn++;

                endCycle(); // lazy but shouldn't matter
                cyclesSpent++;
                endCycle();
                cyclesSpent++;
            }
        }

        // Fill the rest of the array
        for(int i = spritesDrawn; i < 10; i++) {
            visibleSprites[i] = -1;

            endCycle(); // lazy but shouldn't matter
            cyclesSpent++;
            endCycle();
            cyclesSpent++;
        }

        // Yield is guarenteed to be called _exactly_ 20 times, 20*4=80 cycles

        // HACK: Should this really take 84 cycles?? I don't think so??
        endCycle();
        cyclesSpent++;

        return cyclesSpent;
    }

    @safe @property private SpriteAttributes[NUM_SPRITES] sprites() {
        return (cast(SpriteAttributes[NUM_SPRITES]) spriteMemory);
    }

    private bool fetchingWindow = false;
    private bool fetcherSpriteMode = false; // whether the fetcher is fetching a sprite
    private int fetcherSpriteNum = 0; // if the fetcher is fetching the sprite, which one? (visibleSprites index)
    private ubyte fetcherTileX; // which tile we're scrolled onto
    private int fetcherTileY;
    private int fetcherReltY; // Y coordinate within the tile
    private int fetcherSpriteOffset; // HACK: Which position within the sprite to start at (for sprites that begin offscreen)
    @trusted private void pixelFetcher() {
        if (fetcherSpriteMode) {
            /*
            The sprite fetcher mode will fetch a sprite then overlay it onto the first 8 pixels of the FIFO.
             */
            const sprite = sprites[fetcherSpriteNum];

            // The row on the sprite tile that the current scanline represents
            auto rY = (curScanline + 16) - sprite.y; // sprites are offset by 16
            if(sprite.yflip) {
                rY = spriteHeight - 1 - rY;
            }

            // If the sprite is tall then round down to a multiple of 2
            // to get the tile number
            const tileNum =
                control.tallSprites
                ? sprite.tileNum & 0b11111110
                : sprite.tileNum;
            Fiber.yield(); // read tile num

            // If we're on the "tall part" of a tall sprite, use its tile
            const tile = 
                rY < TILE_SIZE
                ? tileSet[tileNum] 
                : tileSet[tileNum + 1];
            Fiber.yield(); // read data 1

            assert(fifoLength >= 8); // we need 8 pixels to overlay the sprite on to

            // Draw each position of the sprite to the fifo
            // Sprites ALWAYS get written to the first 8 pixels
            for (int i = fetcherSpriteOffset; i < TILE_SIZE; i++) {
                auto rX = i; // tile-relative position
                if(sprite.xflip) {
                    rX = TILE_SIZE - 1 - i;
                }

                // The reason we have to apply the palette at this stage
                // is because the writer deoesn't know whether the FIFO entry
                // is part of a sprite or the background, thus wouldn't know
                // which palette to use.
                auto spriteColor = tile[rY % TILE_SIZE][rX]; // rY % TILE_SIZE to support tall sprites
                const ubyte paletted = applyPalette(
                        sprite.palette
                        ? spritePaletteB
                        : spritePaletteA,
                        spriteColor
                );

                if (sprite.belowBG) {
                    // Only draw the pixel if the background is transparent
                    if (pixelFifo[i - fetcherSpriteOffset] == 0) {
                        pixelFifo[i - fetcherSpriteOffset] = spriteColor;
                        pixelFifoPaletted[i - fetcherSpriteOffset] = paletted;
                    }
                } else if (spriteColor != 0) { // This pixel isn't transparent
                    // Draw on top of the background
                    pixelFifo[i - fetcherSpriteOffset] = spriteColor;
                    pixelFifoPaletted[i - fetcherSpriteOffset] = paletted;
                }
            }

            // Return to background mode
            fetcherSpriteMode = false;
            Fiber.yield(); // read data 2 / write to fifo
        }

        const mapSelect = fetchingWindow ? control.windowMapSelect : control.bgMapSelect;
        const bgMap = mapSelect ? tileMapB : tileMapA;

        // Calculate the position of the tile and our relative-position within the tile
        const tY = fetcherTileY; // which tile we're scrolled onto
        const rY = fetcherReltY; // our y position within that tile

        // Now we enter the main tiler loop.
        // For every tile on the line, the tiler repeats a cycle of:
        //  - Read the tile number from tile map
        //  - Load the tile from VRAM
        while (true) {
            // Read the tile # from the map
            const offset = bgMap.tileLocations[tY][fetcherTileX];
            const tileIndex = getTilesetIndex(offset, control.bgTileset);
            Fiber.yield();

            // Read the tile data in from VRAM
            const tile = tileSet[tileIndex];
            Fiber.yield(); // Read data 0

            // We need 8 free entries to place our tile pixels into
            while (fifoLength > 8) {
                Fiber.yield();
            }

            // Put the tile into the pixel FIFO
            for(int rX; rX < 8; rX++) {
                ubyte bgPixel = tile[rY][rX];
                ubyte palettedBgPixel = applyPalette(backgroundPalette, bgPixel);
                if (!control.bgEnabled) {
                    bgPixel = 0;
                    palettedBgPixel = 0;
                }

                pixelFifo[fifoLength] = bgPixel;
                pixelFifoPaletted[fifoLength] = palettedBgPixel;
                fifoLength++;
            }

            // If there's scroll, we may need to loop back to the leftmost tile
            fetcherTileX = (fetcherTileX + 1) % BG_SIZE_TILES; // move onto the next tile

            // XXX do we yield here even if we had to wait for fifoLength > 8?
            Fiber.yield(); // write to FIFO
        }
    }

    /// Consume a pixel from the left of the pixel fifo, returns its paletted color
    @safe private ubyte consumePixelFifo() {
        // Pop a pixel off of the FIFO
        const pixel = pixelFifoPaletted[0];
        for (int i = 1; i < pixelFifo.length; i++) {
            pixelFifo[i-1] = pixelFifo[i];
            pixelFifoPaletted[i-1] = pixelFifoPaletted[i];
        }
        fifoLength -= 1;
        return pixel;
    }

    @trusted private void pixelWriter() {
        bool partOfWindow = control.windowEnable && curScanline >= windowY;

        // To implement sub-tile background scrolling, we need to discard the "extra" pixels that were fetched
        int toDiscard = bgScrollX % TILE_SIZE;

        ubyte xPosition; // x position on the current line

        // Wait for the fetcher to do something
        while (true) {
            // We can't start to consume the FIFO if it would
            // make us unable to fetch and overlay a sprite.
            while (fifoLength <= 8) {
                Fiber.yield();
            }

            // Either discard it or place it onto the display
            if (toDiscard > 0) {
                consumePixelFifo();
                toDiscard--; // Discard the pixel
            } else {
                // Before we draw, we must check if we just entered the window.
                // If so, we need to trash everything we've fetched and start over.
                if (control.windowEnable && partOfWindow
                        && windowX <= xPosition + 8
                        && !fetchingWindow) {
                    // Trash the rest of the FIFO
                    fifoLength = 0;

                    // Start fetching the window
                    fetchingWindow = true;
                    fetcherTileX = 0;
                    fetcherTileY = (curScanline - windowY) / TILE_SIZE;
                    fetcherReltY = (curScanline - windowY) % TILE_SIZE;
                    fetcherFiber.reset();

                    // Wait for enough pixels to come in to start drawing agian
                    while (fifoLength <= 8) {
                        Fiber.yield();
                    }
                }

                // Before we draw, we must check if any sprite needs to be drawn.
                // If we need to draw a sprite, then we need to pause ourselves until
                // the sprite gets fetched.
                // XXX I'm making a guess here that sprites are checked before
                // making the fetcher fetch one. This would impact timing and also
                // have a visual effect -- for example, if sprites are enabled halfway
                // through a sprite draw, they wouldn't show in this case, but idk
                // if that's what would happen on real hardware. TODO.
                if (control.spritesEnabled) {
                    // Draw all of the slightly-offscreen sprites (INACCURATE)
                    if (xPosition == 0) {
                        for (int i; i < visibleSprites.length; i++) {
                            const spriteNum = visibleSprites[i];
                            if (spriteNum == -1) {
                                // -1 marks the end of the visible sprite list
                                break;
                            }
                            const sprite = sprites[spriteNum];
                            if (sprite.x >= 8) {
                                continue; // fully on screen
                            }
                            // sprite is partially off screen
                            fetcherFiber.reset();
                            fetcherSpriteOffset = 8 - sprite.x;
                            fetcherSpriteMode = true;
                            fetcherSpriteNum = spriteNum;
                            // Wait for the sprite to get drawn
                            while (fetcherSpriteMode) Fiber.yield();
                        }
                    }

                    for (int i; i < visibleSprites.length; i++) {
                        const spriteNum = visibleSprites[i];
                        if (spriteNum == -1) {
                            // -1 marks the end of the visible sprite list
                            break;
                        }
                        const sprite = sprites[spriteNum];
                        if (sprite.x == xPosition + 8) { // XXX What about a sprite that is partially off of the screen? When do we draw it?
                            fetcherFiber.reset();
                            fetcherSpriteMode = true;
                            fetcherSpriteNum = spriteNum;
                            fetcherSpriteOffset = 0;

                            // Wait for the sprite to get drawn
                            while (fetcherSpriteMode) Fiber.yield();
                            break;
                        }
                    }
                }

                // Draw the pixel to the display
                const pixel = consumePixelFifo();
                display.setPixelGB(xPosition, curScanline, pixel);
                xPosition++;
            }

            if (xPosition == GB_DISPLAY_WIDTH) {
                return; // This effectively serves as a yield as well
            }

            // We yield each time we draw a pixel
            Fiber.yield();
        }
    }

    private ubyte[16] pixelFifo;
    private ubyte[16] pixelFifoPaletted; // Whether the pixel FIFO entry is from sprite
    private int fifoLength = 0; // Current number of pixels in the FIFO
    /// Perform the pixel transfer stage of the line, copying pixels to the line
    @trusted private int pixelTransfer() { // STAGE 3 (0b11)
        // Transfer pixels into the backbuffer for the line
        // NOTE that because the CPU can't access either VRAM or OAM during this stage,
        // our intra-stage timing doesn't matter all that much.
        status.gpuMode = GPUMode.DATA_TRANSFER;
        updateStatIupt();

        // Reset the state of the worker fibers
        fifoLength = 0; // Current number of pixels in the FIFO
        fetcherTileX = bgScrollX / TILE_SIZE; // the first tile we need to fetch from
        fetcherSpriteMode = false; // default in tile mode
        fetchingWindow = false; // start out fetching bg
        fetcherTileY = cast(ubyte)(curScanline + bgScrollY) / TILE_SIZE; // which tile we're scrolled onto
        fetcherReltY = cast(ubyte)(curScanline + bgScrollY) % TILE_SIZE; // our y position within that tile
        fetcherFiber.reset();
        writerFiber.reset();

        int cyclesToCompleteLine;
        while (writerFiber.state != Fiber.State.TERM) {
            // Fetcher runs at 2MHz, writer runs at 1MHz
            for(int i; i < 4; i++) { // 4MHz
                // XXX what order should fetcherFiber and writerFiber run in?
                if (i % 2 == 0) { // 2Mhz
                    fetcherFiber.call();
                }
                writerFiber.call();
                if (writerFiber.state == Fiber.State.TERM) {
                    break;
                }
            }

            endCycle(); // 1MHz
            cyclesToCompleteLine++;
        }

        // We have now completed the line
        return cyclesToCompleteLine;
    }

    @safe private int hblank(int cyclesLeft) {
        // HBLANK does nothing, just waits to make up for leftover time
        auto cyclesToHblank = 0;

        status.gpuMode = GPUMode.HORIZ_BLANK;
        updateStatIupt();

        for (int i; i < cyclesLeft; i++) {
            endCycle();
            cyclesToHblank++;
        }

        return cyclesToHblank;
    }

    bool shouldVblank = false;
    @safe final void vblankIfNeeded() {
        if (shouldVblank) {
            display.drawFrame();
            frontend.update();
            shouldVblank = false;
        }
    }

    @safe private int vblank() {
        // vblank initially gets called with one "free" scanline (we need to account for that with yields later)
        assert(curScanline == DISPLAY_HEIGHT);

        status.gpuMode = GPUMode.VERT_BLANK;
        updateStatIupt();

        shouldVblank = true;
        iuptHandler.fireInterrupt(Interrupts.VBLANK);

        auto cyclesSpent = 0;
        while(true) {
            // it's ok that we don't increment scanline first, due to the "free" scanline
            for(int i; i < CYCLES_PER_LINE / 4; i++) {
                endCycle();

                // Every cycle after the first cycle of 153 should report as scanline 0
                if (curScanline == VIRTUAL_HEIGHT - 1) {
                    curScanline = 0; // move on early
                }

                cyclesSpent++;
            }

            if (curScanline == 0) { // past line 153 now
                break;
            }
            curScanline++;
        }
        assert(cyclesSpent == (CYCLES_PER_LINE / 4) * 10); // VBlank should take the time of 10 lines

        return cyclesSpent;
    }

    @safe private void updateStatIupt() {
        const statInterrupt =
            control.lcdEnable && (
            (status.coincidenceInterrupt && status.coincidenceFlag) ||
            (status.oamInterrupt && status.gpuMode == GPUMode.VERT_BLANK) ||
            (status.oamInterrupt && status.gpuMode == GPUMode.OAM_SEARCH) ||
            (status.hblankInterrupt && status.gpuMode == GPUMode.HORIZ_BLANK) ||
            (status.vblankInterrupt && status.gpuMode == GPUMode.VERT_BLANK));

        if (statInterrupt && !iuptSignal) {
            iuptHandler.fireInterrupt(Interrupts.LCD_STATUS);
        }

        iuptSignal = statInterrupt;
    }

    /// Run the PPU indefinitely, yielding each 4 cycles
    @safe private void run() {
        while (true) {
            if (!control.lcdEnable) {
                endCycle();
                continue;
            }

            auto cyclesPerFrame = 0;

            // Render each of the visible scanlines
            for(curScanline = 0; curScanline < DISPLAY_HEIGHT; curScanline++) {
                // We start out in OAM search mode
                const cyclesToOamSearch = oamSearch();
                assert(cyclesToOamSearch >= 20);

                // Then move on to pixel transfer
                const cyclesToPixelTransfer = pixelTransfer();
                assert(cyclesToPixelTransfer >= 43);

                // And now hblank
                // (should take up the remainder of the cycles)
                const cyclesToHblank = hblank(
                        CYCLES_PER_LINE/4 - cyclesToOamSearch - cyclesToPixelTransfer
                );

                // 114 cycles per line
                cyclesPerFrame += cyclesToOamSearch + cyclesToPixelTransfer + cyclesToHblank;
                assert(cyclesToOamSearch + cyclesToPixelTransfer + cyclesToHblank == 114);
            }

            // We're in vblank for the remainder of the time
            cyclesPerFrame += vblank();

            assert(cyclesPerFrame == CYCLES_PER_LINE/4 * VIRTUAL_HEIGHT);
        }
    }

    /// Update the internal tile representation given new tile data
    @safe private void updateTileData(in ushort addr) {
        /* Tile data:
         * Byte 0-1 = first line (upper 8 pixels)
         * Byte 2-3 = next line
         * ...
         *
         * Each pixel is 2 bits large, so each byte holds 4 pixels (although it's interleaved)
         */

        /*
         * Each line is represented as two bytes with bits:
         * ABCDEFGH abcdefgh
         * 
         * where the 8th pixel is the two bit long number Aa,
         * the 7th pixel is Bb, etc.
         */

        // The number of the tile in the tileset
        immutable tileNum = addr / TILE_SIZE_BYTES;

        // The current row being updated
        immutable tileRow = (addr / 2) % TILE_SIZE;

        // The second byte contains the upper bits of the color
        // So this indicates whether this byte contains the upper or lower bits
        immutable bool upperBits = (addr % 2) == 1;

        // Update each X position in the row
        for(ubyte x = 0; x < TILE_SIZE; x++) {
            // Invert X since the bits are read backwards
            immutable invX = TILE_SIZE - 1 - x;

            immutable bit1addr = upperBits ? (addr - 1) : addr;
            immutable bit2addr = upperBits ? addr : (addr + 1);
            immutable bit1 = (tileData[bit1addr] & (0b1 << invX)) > 0 ? 1 : 0;
            immutable bit2 = (tileData[bit2addr] & (0b1 << invX)) > 0 ? 2 : 0;

            tileSet[tileNum][tileRow][x] = cast(ubyte)(bit1 + bit2);
        }
    }

    /// Get the corrected index in the tilset for the specific indexing type
    @safe private ushort getTilesetIndex(ubyte value, TilesetIndexing indexingType) {
        return indexingType == TilesetIndexing.SIGNED ? (cast(byte)(value) + 256) : value;
    }

    @safe @property private ubyte spriteHeight() {
        return control.tallSprites ? TILE_SIZE * 2 : TILE_SIZE;
    }

    /// Apply the specified palette to the specified gameboy color
    @safe private ubyte applyPalette(ubyte palette, ubyte color)
    in {
        assert(color < 4); // There are 4 colors total
    }
    out(output) {
        assert(output < 4); // There are 4 possible output colors
    }
    body {
        // Each color is represented by 2 bits in the palette
        return (palette >> (color * 2)) & 0b11;
    }

    /// Sets the initial state of the GPU
    @safe private void bootup() {
        control.data = 0x91;

        bgScrollX = 0;
        bgScrollY = 0;

        scanlineCompare = 0;

        backgroundPalette = 0b11111100;
        spritePaletteA    = 0b11111111;
        spritePaletteB    = 0b11111111;

        curScanline = 0;
        status.data = 0x85;
        // control.data = 0x90;
        
        // TODO WX, WY, clocks spent in current cycle
    }

    /// Set VRAM at the specified address
    @safe @property void vram(in ushort addr, in ubyte val)
    in {
        // There are 8192 bytes of VRAM
        assert(addr < 8192);
    }
    body {
        if (control.lcdEnable && status.gpuMode == GPUMode.DATA_TRANSFER) {
            writeln("WRITE TO VRAM DURING DATA TRANSFER");
            return;
        }

        if(addr >= BG_MAP_A_BEGIN && addr <= BG_MAP_A_END) {
            tileMapA.data[addr - BG_MAP_A_BEGIN] = val;
            return;
        }

        if(addr >= BG_MAP_B_BEGIN && addr <= BG_MAP_B_END) {
            tileMapB.data[addr - BG_MAP_B_BEGIN] = val;
            return;
        }

        if(addr >= TILE_DATA_BEGIN && addr <= TILE_DATA_END) {
            tileData[addr - TILE_DATA_BEGIN] = val;
            updateTileData(addr - TILE_DATA_BEGIN);
            return;
        }

        debug {
            writefln("Tried to write VRAM at %d, which is unmapped.", addr);
        }
    }

    /// Read VRAM at the specified address (relative to VRAM)
    @safe @property ubyte vram(in ushort addr) const
    in {
        // There are 8192 bytes of VRAM
        assert(addr < 8192);
    }
    body {
        if (control.lcdEnable && status.gpuMode == GPUMode.DATA_TRANSFER) {
            writeln("READ FROM VRAM DURING DATA TRANSFER");
            return 0xFF;
        }

        if(addr >= BG_MAP_A_BEGIN && addr <= BG_MAP_A_END) {
            return tileMapA.data[addr - BG_MAP_A_BEGIN];
        }

        if(addr >= BG_MAP_B_BEGIN && addr <= BG_MAP_B_END) {
            return tileMapB.data[addr - BG_MAP_B_BEGIN];
        }

        if(addr >= TILE_DATA_BEGIN && addr <= TILE_DATA_END) {
            return tileData[addr - TILE_DATA_BEGIN];
        }

        // Unmapped, return 0. This shouldn't happen since everything is mapped.
        debug {
            writefln("Tried to read VRAM at %d, which is unmapped.", addr);
        }
        return 0;
    }

    /// Set OAM at the specified address
    @safe @property void oam(in ushort addr, in ubyte val)
    in {
        assert(addr < BYTES_PER_SPRITE_ATTR * NUM_SPRITES);
    }
    body {
        spriteMemory[addr] = val;
    }

    /// Read OAM at the specified address
    @safe @property ubyte oam(in ushort addr) const
    in {
        assert(addr < BYTES_PER_SPRITE_ATTR * NUM_SPRITES);
    }
    body {
        if (control.lcdEnable && (status.gpuMode == GPUMode.OAM_SEARCH
                || status.gpuMode == GPUMode.DATA_TRANSFER)) {
            writeln("Read from OAM occurred during search or transfer");
            return 0xFF;
        }
        return spriteMemory[addr];
    }

    /// Write to the LCD status register (STAT)
    @safe @property void statRegister(in ubyte stat) {
        // The first bit is always 1, and the user cannot write the last two bits
        // TODO According to the official docs, executing a write instruction forthe match flag resets that flag. Is this true?
        status.data = (status.data & 0b10000011) | (stat & 0b01111100);
        // updateStatIupt();
    }

    /// Read from the LCD status register (STAT)
    @safe @property ubyte statRegister() const {
        if(control.lcdEnable == 0) {
            return status.data & 0b11111000;
        }

        return status.data;
    }

    /// Write to the LCD control register (LCDC)
    @trusted @property void lcdcRegister(in ubyte lcdc) {
        LCDControl newControl;
        newControl.data = lcdc;
        
        // The display is turning off
        if(!newControl.lcdEnable && control.lcdEnable) {
            // When the display is turned off, LY immediately becomes 0
            this.reset(); // reset our state machine
            curScanline = 0;
            // updateStatIupt(); // internal flag becomes false
            // XXX Do we fire interrupts here for the line changing?
            
            // TODO does mode immediately get set to OAM_SEARCH here? Or stick with what we have
        }

        if(newControl.lcdEnable && !control.lcdEnable) {
            status.gpuMode = GPUMode.OAM_SEARCH;
            curScanline = 0;

            // HACK: After LCD enable, we start partway through the first scanline
            // We're confident this won't cause an iupt, so we can simulate regularly here regardless
            // of what the actual hardware behavior is here.
            control.data = lcdc;
            this.call();
            this.call();
        }

        control.data = lcdc;
    }

    /// Read from the LCD control register (LCDC)
    @safe @property ubyte lcdcRegister() const {
        // TODO "On DMG, the LCDC should be off during VBLANK". Is this advice for programs or hardware behavior?? TEST
        return control.data;
    }

    /// Read from the background scroll x register (SCX)
    @safe @property ubyte scxRegister() const {
        return bgScrollX;
    }

    /// Write to the background scroll x register (SCX)
    @safe @property void scxRegister(ubyte scx) {
        bgScrollX = scx;
    }

    /// Read from the background scroll y register (SCY)
    @safe @property const ubyte scyRegister() {
        return bgScrollY;
    }

    /// Write to the background scroll y register (SCY)
    @safe @property void scyRegister(ubyte scy) {
        bgScrollY = scy;
    }

    /// Read from the window x register (WX)
    @safe @property ubyte wxRegister() const {
        return windowX;
    }

    /// Write to the window x register (WX)
    @safe @property void wxRegister(ubyte wx) {
        windowX = wx;
    }

    /// Read from the window y register (WY)
    @safe @property ubyte wyRegister() const {
        return windowY;
    }

    /// Write to the window y register (WY)
    @safe @property void wyRegister(ubyte wy) {
        windowY = wy;
    }

    /// Write to the background palette register
    @safe @property void bgpRegister(ubyte bgp) {
        backgroundPalette = bgp;
    }

    /// Read from the background palette register
    @safe @property ubyte bgpRegister() const {
        return backgroundPalette;
    }

    /// Write to the first sprite palette register
    @safe @property void obp0Register(ubyte obp0) {
        spritePaletteA = obp0;
    }

    /// Read from the first sprite palette register
    @safe @property ubyte obp0Register() const {
        return spritePaletteA;
    }

    /// Write to the second sprite palette register
    @safe @property void obp1Register(ubyte obp1) {
        spritePaletteB = obp1;
    }

    /// Read from the second sprite palette register
    @safe @property ubyte obp1Register() const {
        return spritePaletteB;
    }

    /// Read from the current scanline register
    @safe @property ubyte lyRegister() const {
        return curScanline;
    }

    // TODO does writing to LY reset it? For whatever reason the old GPU code did that

    /// Read from the scanline compare register
    @safe @property ubyte lycRegister() const {
        return scanlineCompare;
    }

    /// Write to the scanline compare register
    @safe @property void lycRegister(ubyte lyc) {
        scanlineCompare = lyc;

        // TODO check conincidence. Also can the coincidence interrupt happen here?
    }

    @trusted private void endCycle() {
        if (control.lcdEnable) {
            updateCoincidence();
        }
        updateStatIupt();
        yield();
    }

    /// Update the coincidence flag. Should be called every scanline change.
    @safe private void updateCoincidence() {
        status.coincidenceFlag = curScanline == scanlineCompare;
    }
    
}

/// A representation of the different modes that the GameBoy GPU can be in
private enum GPUMode : ubyte
{
    /// Drawing of a single scanline. The CPU is able to access both OAM and VRAM.
    HORIZ_BLANK = 0,

    /// Update of the display (at 60ish hz). The CPU is able to access both OAM and VRAM.
    VERT_BLANK = 1,
    
    // TODO what actually happens during this state?
    /// The CPU is unable to access OAM at this time but can access VRAM
    OAM_SEARCH = 2,

    /// Pixel data is transfered to the LCD controller. The CPU is unable to access OAM or VRAM at this time.
    DATA_TRANSFER = 3
}

/// A representation of the LCD control register (LCDC)
private union LCDControl {
    ubyte data;
    mixin(bitfields!(
        /// Whether the background should be drawn. On CGB this is instead superpriority for sprites
        bool, "bgEnabled", 1,

        /// Whether sprites should be drawn
        bool, "spritesEnabled", 1,

        /// If true, use 8x16 sprites. Otherwise 8x8
        bool, "tallSprites", 1,

        /// The tilemap to use for the background
        bool, "bgMapSelect", 1,

        /// The tileset to use for the background and window
        TilesetIndexing, "bgTileset", 1,

        /// Whether the window should be drawn
        bool, "windowEnable", 1,

        /// The tilemap to use for the window
        bool, "windowMapSelect", 1,

        /// Whether the LCD should be enabled. Should only be turned off during VBLANK
        bool, "lcdEnable", 1
    ));
}

/// A representation of the LCD status register (STAT)
union LCDStatus {
    ubyte data;
    mixin(bitfields!(
        /// The current mode that the lcd controller is in
        GPUMode, "gpuMode", 2,

        /// Set when LY (the current Y coordinate) and LYC are equal
        bool, "coincidenceFlag", 1,

        /// Set if the user wants HBlanks to create STAT interrupts
        bool, "hblankInterrupt", 1,

        /// Set if the user wants VBlanks to create STAT interrupts
        bool, "vblankInterrupt", 1,

        /// Set if the user wants a STAT interrupt when we enter the OAM search state
        bool, "oamInterrupt", 1,

        /// Set if the user wants a STAT interrupt when LY=LYC
        bool, "coincidenceInterrupt", 1,

        bool, "", 1
    ));
}

private union TileMap {
    /// Row-major locations of the tiles
    private ubyte[BG_SIZE_TILES][BG_SIZE_TILES] tileLocations;

    /// The raw data backing the tile map
    private ubyte[BG_SIZE_TILES * BG_SIZE_TILES] data;
}

/// Data about a sprite. Stored in OAM RAM.
private struct SpriteAttributes {
    align(1): // Tightly pack the bytes
        /// The X position of the sprite on the screen (minus 16)
        ubyte y;

        /// The Y position of the sprite on the screen (minus 8)
        ubyte x;

        /// The unsigned tile number to use for the sprite
        ubyte tileNum;

        union {
            ubyte options;
            mixin(bitfields!(
                /// Color palette: used on CGB only
                uint, "", 3,

                /// Character bank: used on CGB only
                bool, "", 1,

                /// Palette to use: unused on CGB
                bool, "palette", 1,

                /// Whether to flip horizontally
                bool, "xflip", 1,

                /// Whether to flip vertically
                bool, "yflip", 1,

                /// Whether to force above the background
                bool, "belowBG", 1
            ));
        }
}

/// Type of indexing of the tileset
private enum TilesetIndexing : bool {
    /// Use the signed tileset from 0x8800-0x97FF
    SIGNED = false,

    /// Use the unsigned tileset from 0x8000-0x8FFF
    UNSIGNED = true
}
