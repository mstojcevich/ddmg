module frontend.sdl.keypad;

import derelict.sdl2.sdl;
import keypad;

/// Keypad frontend implementation using SDL
class SDLKeypad : KeypadFrontend {

    private keypressCallback callback;

    @safe override void setCallback(keypressCallback cbk) {
        callback = cbk;
    }

    @trusted void keyDown(int key) {
        switch(key) {
            case SDLK_z:
                callback(true, GameboyKey.A);
                break;
            case SDLK_x:
                callback(true, GameboyKey.B);
                break;
            case SDLK_TAB:
                callback(true, GameboyKey.SELECT);
                break;
            case SDLK_RETURN:
                callback(true, GameboyKey.START);
                break;
            case SDLK_LEFT:
                callback(true, GameboyKey.LEFT);
                break;
            case SDLK_RIGHT:
                callback(true, GameboyKey.RIGHT);
                break;
            case SDLK_UP:
                callback(true, GameboyKey.UP);
                break;
            case SDLK_DOWN:
                callback(true, GameboyKey.DOWN);
                break;
            default:
                break;
        }
    }

    @trusted void keyUp(int key) {
        switch(key) {
            case SDLK_z:
                callback(false, GameboyKey.A);
                break;
            case SDLK_x:
                callback(false, GameboyKey.B);
                break;
            case SDLK_TAB:
                callback(false, GameboyKey.SELECT);
                break;
            case SDLK_RETURN:
                callback(false, GameboyKey.START);
                break;
            case SDLK_LEFT:
                callback(false, GameboyKey.LEFT);
                break;
            case SDLK_RIGHT:
                callback(false, GameboyKey.RIGHT);
                break;
            case SDLK_UP:
                callback(false, GameboyKey.UP);
                break;
            case SDLK_DOWN:
                callback(false, GameboyKey.DOWN);
                break;
            default:
                break;
        }
    }

}
