module frontend.glfw.display;

import derelict.glfw3.glfw3;
import derelict.opengl3.gl;
import graphics.display;
import std.conv;
import std.exception;
import std.stdio;

private const DISPLAY_WIDTH = GB_DISPLAY_WIDTH * 4;
private const DISPLAY_HEIGHT = GB_DISPLAY_HEIGHT * 4;

/// Display implementation using GLFW
class GLFWDisplay : Display {
    private GLFWwindow* window;
    
    private Color[GB_PIXEL_COUNT] pixels;
    private ubyte [GB_PIXEL_COUNT] gbPixels;

    /**
     * THe color palette of the Gameboy
     */
    private Color[4] palette = [
        {255, 255, 255},
        {192, 192, 192},
        {96, 96, 96},
        {0, 0, 0}
    ];

    @safe this() {
        pixels = new Color[GB_PIXEL_COUNT];

        Color white = {255, 255, 255};
        // Initialize the pixels all to white
        for(ubyte x; x < GB_DISPLAY_WIDTH; x++) {
            for(ubyte y; y < GB_DISPLAY_HEIGHT; y++) {
                setPixel(x, y, white);
            }
        }

        initGLFW();
    }

    @trusted ~this() {
        /* 
        Even if the application is terminated and the OS frees resources, 
        the GLFW docs state that system properties may be altered, so
        glfwTerminate needs to be explicitely called 
        */

        glfwTerminate(); // Also frees allocated memory such as the window
    }

    @trusted private void initGLFW() {
        DerelictGLFW3.load(); // Load in the GLFW3 dynamic library
        DerelictGL.load(); // Load GL core and compatibility. TODO change to DerelictGL3 and remove deprecated calls 

        // When an error occurs, handle it our way
        glfwSetErrorCallback(&errorCallback);

        // Initialize glfw
        auto immutable initSuccess = glfwInit();
        enforce!GLFWDisplayInitializeException(initSuccess == GLFW_TRUE,
                "GLFW initialization failed. Make sure you have up-to-date graphics drivers installed.");

        // Set preferences for OpenGl context of the window
        // Requesting 2.1 because we use glDrawPixels, which
        //  is part of the fixed-function pipeline
        glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 2);
        glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 1);

        // Create a window
        window = glfwCreateWindow(DISPLAY_WIDTH, DISPLAY_HEIGHT, "DDMG", null, null); // 160x144 is Gameboy resolution
        enforce!GLFWDisplayInitializeException(window !is null,
                "GLFW window creation failed. Make sure you have up-to-date graphics drivers installed.");
        
        glfwMakeContextCurrent(window);

        DerelictGL.reload(); // Need to reload for full support
    }


    @safe private void resetFrameBuffer() {
        Color white = {255, 255, 255};

        // Initialize the pixels all to white
        for(ubyte x; x < GB_DISPLAY_WIDTH; x++) {
            for(ubyte y; y < GB_DISPLAY_HEIGHT; y++) {
                setPixel(x, y, white);
            }
        }
    }

    @trusted override void drawFrame() {
        glfwPollEvents();

        int width, height;
        glfwGetFramebufferSize(window, &width, &height);
        glPixelZoom(width / GB_DISPLAY_WIDTH, height / GB_DISPLAY_HEIGHT);

        glDrawPixels(GB_DISPLAY_WIDTH, GB_DISPLAY_HEIGHT, GL_RGB, GL_UNSIGNED_BYTE, &pixels[0]);
        
        glfwSwapInterval(1); // Use vsync
        
        glfwSwapBuffers(window);

        // Limit framerate to 15 ms per frame to simulate gameboy
        while(glfwGetTime() < 0.015) {}
        glfwSetTime(0);
    }

    /// Returns whether emulation should be stopped
    @trusted bool shouldProgramTerminate() {
        // Terminate the program if escape was pressed
        if(glfwGetKey(window, GLFW_KEY_ESCAPE) == GLFW_PRESS) {
            return true;
        }

        // Terinate the program if the window was closed
        if(glfwWindowShouldClose(window) == GLFW_TRUE) {
            return true;
        }

        return false;
    }

    @safe ubyte getPixelGB(in ubyte x, in ubyte y)
    in {
        assert(x < GB_DISPLAY_WIDTH);
        assert(y < GB_DISPLAY_HEIGHT);
    }
    body {
        const pixelNum = ((GB_DISPLAY_HEIGHT - y - 1) * GB_DISPLAY_WIDTH) + x;

        return gbPixels[pixelNum];
    }

    @safe private void setPixel(in ubyte x, in ubyte y, in Color c)
    in {
        assert(x < GB_DISPLAY_WIDTH);
        assert(y < GB_DISPLAY_HEIGHT);
    }
    body {
        int pixelNum = ((GB_DISPLAY_HEIGHT - y - 1) * GB_DISPLAY_WIDTH) + x;

        pixels[pixelNum] = c;
    }

    @safe override void setPixelGB(in ubyte x, in ubyte y, in ubyte value)
    in {
        assert(value <= 3);
    }
    body {
        setPixel(x, y, palette[value]);
        int pixelNum = ((GB_DISPLAY_HEIGHT - y - 1) * GB_DISPLAY_WIDTH) + x;
        gbPixels[pixelNum] = value;
    }

    /// Get the window associated with the display
    @safe @property GLFWwindow* glfwWindow() {
        return window;
    }
}

private struct Color {
    align(1):
        ubyte red, green, blue;
}

private extern(C) void errorCallback(int error, const(char)* description) nothrow {
    assumeWontThrow(writefln("GLFW Error %X: %s", error, to!string(description)));
}

/**
 * An exception that is thrown whenever initialization of the display fails
 */
class DisplayInitializeException : Exception {
    mixin basicExceptionCtors;
}

/**
 * DisplayInitializeException terminates GLFW cleanly
 */
private class GLFWDisplayInitializeException : DisplayInitializeException
{

    // From std.exception.basicExceptionCtors
    /++
        Params:
            msg  = The message for the exception.
            file = The file where the exception occurred.
            line = The line number where the exception occurred.
            next = The previous exception in the chain of exceptions, if any.
        +/
    this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable next = null) @nogc nothrow
    {
        super(msg, file, line, next);

        glfwTerminate();
    }

    // From std.exception.basicExceptionCtors
    /++
            Params:
                msg  = The message for the exception.
                next = The previous exception in the chain of exceptions.
                file = The file where the exception occurred.
                line = The line number where the exception occurred.
        +/
    this(string msg, Throwable next, string file = __FILE__, size_t line = __LINE__) @nogc nothrow
    {
        super(msg, file, line, next);

        glfwTerminate();
    }
}
