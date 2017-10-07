module graphics.display;

import std.exception;
import std.stdio;
import std.conv;
import std.random;

/**
 * The width of the Gameboy display in pixels
 */
const GB_DISPLAY_WIDTH  = 160;

/**
 * The height of the Gameboy display in pixels
 */
const GB_DISPLAY_HEIGHT = 144;

/**
 * The total number of pixels on the Gameboy display
 *
 * Equivalent to GB_DISPLAY_WIDTH * GB_DISPLAY_HEIGHT
 */
const GB_PIXEL_COUNT = GB_DISPLAY_WIDTH * GB_DISPLAY_HEIGHT;

/**
 * A display to render on
 *
 * This differs from the GPU as it handles the host-specific framebuffer
 * as opposed to the GPU which handles the Gameboy emulation
 */
interface Display {

    /// Set a pixel to a specified gameboy color (1-4)
    @safe void setPixelGB(in ubyte x, in ubyte y, in ubyte value);

    /// Draw a frame (called each vblank)
    @safe void drawFrame();

}
