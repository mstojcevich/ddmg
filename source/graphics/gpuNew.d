/*
ACCURACY WARNING

This is not particularly accurate as far as timing goes.

All of the interupts and such should be timed correctly,
but because reads from VRAM are not properly timed there
may be some visual discrepencies with real hardware, but
only if games try to do some weird tricks or rely on the timing
in some other way.
 */

 import std.bitmanip;

/// The size of the background in pixels. This is both the width and the height of the background.
private const BG_SIZE = 256;

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
    A tilemap is a mapping from coordinates on the screen to an index in the tileset
    */

    

}

/// A representation of the different modes that the GameBoy GPU can be in
enum GPUMode : ubyte
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
union LCDControl {
    ubyte data;
    mixin(bitfields!(
        /// Whether the background should be drawn
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