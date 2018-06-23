module tests.cpu.arithmetic;

import cpu;
import mmu;
import bus;
import dunit;
import interrupt;

import unit_threaded.mock;
import unit_threaded.should;

private const PGM_START = 0xC000;

class ArithmeticTests {
    mixin UnitTest;

    // TODO we should probably mock the MMU

    private MMU m;
    private CPU c;

    this() {
        m = new MMU(null, null, null, null, null, null, null);
        
        Bus mockBus = mock!Bus;

        c = new CPU(m, mockBus, null);
    }

    @Test
    void addUnsetsSubtraction() {
        c.reset();
        c.registers.pc = 0xC000;
        c.registers.f |= Flag.SUBTRACTION;

        m.writeByte(PGM_START, 0x80); // ADD A,B
        c.step();

        // ADD should unset the subtraction flag
        (c.registers.f & Flag.SUBTRACTION).shouldEqual(0);
    }

    @Test
    void addingWithOverflow() {
        c.reset();
        c.registers.pc = 0xC000;

        c.registers.a = 0xFE;
        c.registers.b = 0x03;
        m.writeByte(PGM_START, 0x80); // ADD A,B
        c.step();

        // (0xFE + 0x03) & 0xFF = 0x01
        (c.registers.a).shouldEqual(0x01);

        // ADD should set the overflow flag when the result > 0xFF
        (c.registers.f & Flag.OVERFLOW).shouldNotEqual(0);

        // ADD should set the half-overflow flag when (A & 0xF + B & 0xF) > 0xF
        (c.registers.f & Flag.HALF_OVERFLOW).shouldNotEqual(0);

        // ADD shouldn't set the zero flag when the result isn't 0
        (c.registers.f & Flag.ZERO).shouldEqual(0);

        // ADD should unset the subtraction flag
        (c.registers.f & Flag.SUBTRACTION).shouldEqual(0);
    }

    @Test
    void addingWithOverflowNoHalf() {
        // Add results in overflow but NOT half-overflow

        c.reset();
        c.registers.pc = 0xC000;
        c.registers.a = 0xFE;
        c.registers.b = 0x02;
        m.writeByte(PGM_START, 0x80); // ADD A,B
        c.step();

        // ADD should set the overflow flag when the result > 0xFF
        (c.registers.f & Flag.OVERFLOW).shouldNotEqual(0);

        // ADD should set the half-overflow flag when (A & 0xF + B & 0xF) > 0xF
        (c.registers.f & Flag.HALF_OVERFLOW).shouldNotEqual(0);
    }

    @Test
    void addingWithOverflowBarely() {
        // Add exactly enough to overflow

        c.reset();
        c.registers.pc = 0xC000;

        c.registers.a = 0xFE;
        c.registers.b = 0x02;
        m.writeByte(PGM_START, 0x80); // ADD A,B
        c.step();

        // (0xFE + 0x02) & 0xFF = 0x00
        (c.registers.a).shouldEqual(0x00);

        // ADD should set the overflow flag when the result > 0xFF
        (c.registers.f & Flag.OVERFLOW).shouldNotEqual(0);

        // ADD should set the half-overflow flag when (A & 0xF + B & 0xF) > 0xF
        (c.registers.f & Flag.HALF_OVERFLOW).shouldNotEqual(0);

        // ADD should set the zero flag when the result is 0
        (c.registers.f & Flag.ZERO).shouldNotEqual(0);
    }
    
}

mixin Main;