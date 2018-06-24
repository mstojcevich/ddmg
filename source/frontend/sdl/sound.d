module frontend.sdl.sound;

import derelict.sdl2.sdl;
import sound.frontend;
import timing;

import std.stdio;

class SDLSound : SoundFrontend {

    private int sampleRate;

    private int ticksPerSample;
    private ubyte[] buffer;

    // Position we are currently at in the buffer
    private int bufferPos = 0;

    // Count of how many cycles since the last write to the buffer
    private int bufferWriteAccum = 0;
    
    @trusted this() {
        SDL_AudioSpec prefs;
        prefs.freq = 48_000; // Multiple of gameboy sweep/window updates
        prefs.format = AUDIO_U8;
        prefs.channels = 1; // TODO 2 channels, 1 left 1 right
        prefs.samples = 2048; // Buffer size
        prefs.callback = null;

        SDL_AudioSpec actual;
        
        // TODO error checking
        SDL_OpenAudio(&prefs, &actual);

        // TODO check what we got to make sure it's usable

        this.sampleRate = actual.freq;
        this.buffer = new ubyte[actual.samples];

        this.ticksPerSample = DMG_CLOCKRATE_HZ / sampleRate;

        SDL_PauseAudio(0);
    }

    @trusted ~this() {
        SDL_PauseAudio(1);
        SDL_CloseAudio();
    }

    @trusted override void playAudio(ubyte left, ubyte right) {
        if(true) {
            if(bufferWriteAccum >= ticksPerSample) {
                bufferWriteAccum = 0;
                buffer[bufferPos] = cast(ubyte)(left * (195/15));
                bufferPos++;

                // Write out the buffer if it is full
                if(bufferPos >= buffer.length) {
                    SDL_QueueAudio(1, &buffer, bufferPos);

                    bufferPos = 0;
                }
            }

            bufferWriteAccum++;
        }
    }

}