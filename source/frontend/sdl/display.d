module frontend.sdl.display;

import derelict.sdl2.sdl;
import graphics.display;
import std.conv;
import std.exception;
import std.stdio;

private const DISPLAY_WIDTH = GB_DISPLAY_WIDTH * 4;
private const DISPLAY_HEIGHT = GB_DISPLAY_HEIGHT * 4;

/// Display implementation using GLFW
class SDLDisplay : Display {

    private SDL_Window* window;
    private SDL_Renderer* renderer;
    private SDL_Texture* renderTexture;
    
    private Color[GB_PIXEL_COUNT] pixels;

    /**
     * THe color palette of the Gameboy
     */
    private Color[4] palette = [
        {255, 255, 255, 255},
        {192, 192, 192, 255},
        {96, 96, 96, 255},
        {0, 0, 0, 255}
    ];

    @safe this() {
        pixels = new Color[GB_PIXEL_COUNT];

        Color white = {255, 255, 255};
        // Initialize the pixels all to white
        for(ubyte x = 0; x < GB_DISPLAY_WIDTH; x++) {
            for(ubyte y = 0; y < GB_DISPLAY_HEIGHT; y++) {
                setPixel(x, y, white);
            }
        }

        initSDL();
    }

    @trusted ~this() {
        SDL_DestroyTexture(renderTexture);
        SDL_DestroyRenderer(renderer);
        SDL_DestroyWindow(window);
    }

    @trusted private void initSDL() {
        window = SDL_CreateWindow("DDMG", SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED,
                DISPLAY_WIDTH, DISPLAY_HEIGHT, SDL_RENDERER_PRESENTVSYNC);
        renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_PRESENTVSYNC);
        renderTexture = SDL_CreateTexture(renderer, SDL_PIXELFORMAT_ARGB8888, 
                SDL_TEXTUREACCESS_STREAMING, GB_DISPLAY_WIDTH, GB_DISPLAY_HEIGHT);
    }

    @trusted override void drawFrame() {
        SDL_UpdateTexture(renderTexture, null, &pixels, cast(int)(GB_DISPLAY_WIDTH * Color.sizeof));
        SDL_RenderCopy(renderer, renderTexture, null, null);
        SDL_RenderPresent(renderer);
    }

    @safe private void setPixel(in ubyte x, in ubyte y, in Color c)
    in {
        assert(x < GB_DISPLAY_WIDTH);
        assert(y < GB_DISPLAY_HEIGHT);
    }
    body {
        int pixelNum = (y * GB_DISPLAY_WIDTH) + x;

        pixels[pixelNum] = c;
    }

    @safe override void setPixelGB(in ubyte x, in ubyte y, in ubyte value)
    in {
        assert(value <= 3);
    }
    body {
        setPixel(x, y, palette[value]);
    }

    @safe @property SDL_Window* sdlWindow() {
        return window;
    }
}

struct Color {
    align(1):
        ubyte red, green, blue, alpha;
}
