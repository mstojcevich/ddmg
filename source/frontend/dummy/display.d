module frontend.dummy.display;

import graphics.display;

/// Display that does nothing
class DummyDisplay : Display {

    @safe override void setPixelGB(in ubyte x, in ubyte y, in ubyte value) {}

    @safe override void drawFrame() {}

}
