module serial.serial;

import std.bitmanip;
import std.outbuffer;
import std.stdio;
import interrupt;

/// GameBoy serial communication module
class Serial {

    // TODO implement reading from somewhere
    // TODO what happens when serialData is written mid-transfer?
    // TODO what happens when the transfer is stopped midway / resumed?? 

    private InterruptHandler iuptHandler;

    private OutBuffer output;

    /// FF01 - SB - Serial transfer data
    private ubyte serialData;

    /// FF02 - SC - Serial transfer control
    private SerialControl serialControl;

    /// Byte that will be output next (after 8 cycles have finished)
    private ubyte outByte;

    /// The current number of bits written to the wire
    private int wireBit;

    /// Create a new serial module with the specified interrupt handler and output buffer
    @safe this(InterruptHandler ih, OutBuffer output) {
        this.iuptHandler = ih;
        this.output = output;
    }

    /// Set the value of the serial transfer data register
    @safe @property void data(ubyte val) {
        this.serialData = val;
    }

    /// Read the value of the serial data register
    @safe @property ubyte data() const {
        return this.serialData;
    }

    /// Set the value of the serial control register
    @safe @property void control(ubyte val) {
        this.serialControl.data = val;
    }

    /// Read the value of the serial control register
    @safe @property ubyte control() const {
        return this.serialControl.data;
    }

    /// Emulate 1 cycle of work
    @safe void tick() {
        // Each cycle the leftmost bit is sent over the wire
        // and the incoming bit is shifted in from the other side

        // TODO simulate input too

        if (this.serialControl.inProgress) {
            // Write out one bit
            this.outByte |= (this.serialData & 0b10000000) >> wireBit;
            this.serialData <<= 1;
            // TODO this is where we'd probably read in the input
            this.wireBit++;

            if (wireBit == 8) {
                // Transfer complete, actually do something
                writeByte(outByte);
                this.wireBit = 0;
                this.outByte = 0;
                this.serialControl.inProgress = false;
                iuptHandler.fireInterrupt(Interrupts.SERIAL_LINK);
            }
        }
    }

    /// Write a byte over the "wire"
    @safe private void writeByte(ubyte val) {
        // TODO use some more generic stream type
        // for output so that custom output behavior
        // can be defined
        if (output !is null) {
            output.write(val);
        }
    }

    private enum ShiftClock : bool {
        /// We're the client, use the other device's clock
        EXTERNAL = false,
        /// We're the host, use our own clock
        INTERNAL = true
    }

    /// A representation of the serial transfer control register (SC)
    private union SerialControl {
        ubyte data;
        mixin(bitfields!(
            /// The current mode that the lcd controller is in
            ShiftClock, "shiftClock", 1,

            /// Clock speed (Only used on CGB)
            bool, "", 1,

            /// Unused
            bool, "", 5,

            /// Current stautus of the serial transfer
            bool, "inProgress", 1
        ));
    }

}