import derelict.opengl3.gl;
import derelict.glfw3.glfw3;
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
 *
 * Because of the use of system libraries, most of this is unsafe
 */
class Display {

    private GLFWwindow* window;
    
    private Color[GB_PIXEL_COUNT] pixels;

    this() {
        pixels = new Color[GB_PIXEL_COUNT];

        // Initialize the pixels all to white
        for(ubyte x = 0; x < GB_DISPLAY_WIDTH; x++) {
            for(ubyte y = 0; y < GB_DISPLAY_HEIGHT; y++) {
                setPixel(x, y, 255, 255, 255);
            }
        }

        DerelictGLFW3.load(); // Load in the GLFW3 dynamic library
        DerelictGL.load(); // Load GL core and compatibility. TODO change to DerelictGL3 and remove deprecated calls 

        // When an error occurs, handle it our way
        glfwSetErrorCallback(&errorCallback);

        // Initialize glfw
        auto immutable initSuccess = glfwInit();
        enforce!GLFWDisplayInitializeException(initSuccess == GLFW_TRUE,
                "GLFW initialization failed. Make sure you have up-to-date graphics drivers installed.");

        // Set preferences for OpenGl context of the window
        // Requesting 3.0 because we use glDrawPixels, which
        //  is part of the fixed-function pipeline
        glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
        glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 0);

        // Create a window
        window = glfwCreateWindow(160, 144, "DDMG", null, null); // 160x144 is Gameboy resolution
        enforce!GLFWDisplayInitializeException(window !is null,
                "GLFW window creation failed. Make sure you have up-to-date graphics drivers installed.");
        
        glfwMakeContextCurrent(window);

        DerelictGL.reload(); // Need to reload for full support
    }

    ~this() {
        /* 
        Even if the application is terminated and the OS frees resources, 
        the GLFW docs state that system properties may be altered, so
        glfwTerminate needs to be explicitely called 
        */

        glfwTerminate(); // Also frees allocated memory such as the window
    }

    void drawFrame() {
        glfwPollEvents();

        glDrawPixels(GB_DISPLAY_WIDTH, GB_DISPLAY_HEIGHT, GL_RGB, GL_UNSIGNED_BYTE, &pixels);
        
        glfwSwapBuffers(window);
    }

    bool shouldProgramTerminate() {
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

    @safe void setPixel(ubyte x, ubyte y, ubyte r, ubyte g, ubyte b) {
        int pixelNum = (y * GB_DISPLAY_WIDTH) + x;

        pixels[pixelNum].red = r;
        pixels[pixelNum].green = g;
        pixels[pixelNum].blue = b;
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
