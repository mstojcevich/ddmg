/*
ACCURACY WARNING

This is not particularly accurate as far as timing goes.

I don't emulate the exact cycles that things are read.
This is because the CPU isn't alowed to read/write while the
GPU is transferring stuff to the LCD controller.

I need to do more research into what happens during the
OAM_SEARCH mode, since I do all of the reading during
DATA_TRANSFER.
*/

import std.bitmanip;
import std.stdio;

/// The size of the background in pixels. This is both the width and the height of the background.
private const BG_SIZE = 256;

/// The size of tiles in the background and window in pixels. This is both the width and the height of a given tile.
private const BG_TILE_SIZE = 8;

/// The size of the background in tiles. This is both the width and the height.
private const BG_SIZE_TILES = BG_SIZE / BG_TILE_SIZE;

/// VRAM stores a total of 384 different tiles
private const NUM_TILES = 384;

/// Each tile is 16 bytes large because each line is 2 bytes
private const TILE_SIZE_BYTES = 16;

// Memory mappings
private const BG_MAP_A_BEGIN  = 0x1800; /// Background map A begins at 0x9800, which is 0x1800 in VRAM
private const BG_MAP_A_END    = 0x1BFF; /// Background map A ends at 0x9BFF, which is 0x1BFF in VRAM
private const BG_MAP_B_BEGIN  = 0x1C00; /// Background map B begins at 0x9C00, which is 0x1C00 in VRAM
private const BG_MAP_B_END    = 0x1FFF; /// Background map B ends at 0x9FFF, which is 0x1FFF in VRAM
private const TILE_DATA_BEGIN = 0x0000; /// Tile data begins at 0x8000, which is 0x0000 in VRAM
private const TILE_DATA_END   = 0x17FF; /// Tile data ends at 0x97FF, which is 0x17FF in VRAM

/**
 * The GPU takes information from VRAM+OAM and processes it.
 * It prepares scanlines and sends them to the display to render.
 */
class GPU {
    /*
    The background consists of 32x32 8x8 tiles, making 256x256 pixels total.
    When rendered, it is offset by the SCX and SCY registers and wraps around.

    For performance reasons, I keep the current unscrolled background calculated
    ahead of time. This also makes the data read timing slightly more (but not fully) accurate.
    */

    /// y-major representation of the background
    ubyte[BG_SIZE][BG_SIZE] background;

    /**
    * Whether something has been changed since the last DATA_TRANSFER mode 
    * that would require the background to be redrawn.
    *
    * For example, if the tile map or tile data gets changed.
    */
    bool bgChanged;

    ubyte bgScrollY; /// SCY register: The y coordinate of the background at the top left of the display
    ubyte bgScrollX; /// SCX register: The x coordinate of the background at the top left of the display

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

    /// Read VRAM at the specified address (relative to VRAM)
    @safe @property ubyte vram(in ushort addr)
    in {
        // There are 8192 bytes of VRAM
        assert(addr < 8192);
    }
    body {
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

    /// Set VRAM at the specified address
    @safe @property void vram(in ushort addr, in ubyte val)
    in {
        // There are 8192 bytes of VRAM
        assert(addr < 8192);
    }
    body {
        if(addr >= BG_MAP_A_BEGIN && addr <= BG_MAP_A_END) {
            bgChanged = true;
            tileMapA.data[addr - BG_MAP_A_BEGIN] = val;
            return;
        }

        if(addr >= BG_MAP_B_BEGIN && addr <= BG_MAP_B_END) {
            bgChanged = true;
            tileMapB.data[addr - BG_MAP_B_BEGIN] = val;
            return;
        }

        if(addr >= TILE_DATA_BEGIN && addr <= TILE_DATA_END) {
            bgChanged = true;
            tileData[addr - TILE_DATA_BEGIN] = val;
            return;
        }

        debug {
            writefln("Tried to write VRAM at %d, which is unmapped.", addr);
        }
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

    /// Data is transfered to the LCD controller. The CPU is unable to access OAM or VRAM at this time
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
        bool, "bgDataSelect", 1,

        /// Whether the window should be drawn
        bool, "windowEnable", 1,

        /// The tilemap to use for the window
        bool, "windowMapSelect", 1,

        /// Whether the LCD should be enabled. Should only be turned off during VBLANK
        bool, "lcdEnable", 1
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
                bool, "priority", 1 // Whether to force above the background
            ));
        }
}
