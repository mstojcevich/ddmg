module tests.cpu.arithmetic;

import cpu;
import mmu;
import bus;
import fluent.asserts;
import trial.discovery.testclass;
import dmocks.mocks;
import interrupt;

private const PGM_START = 0xC000;

class ArithmeticTests {
    // TODO we should probably mock the MMU

    private MMU m;
    private CPU c;
    private Mocker mocker = new Mocker();

    this() {
        m = new MMU(null, null, null, null, null, null);
        
        Bus mockBus = mocker.mock!(Bus)(null, null, m, null);

        c = new CPU(m, mockBus, null);
    }

    @Test()
    void addUnsetsSubtraction() {
        c.reset();
        c.registers.pc = 0xC000;
        c.registers.f |= Flag.SUBTRACTION;

        m.writeByte(PGM_START, 0x80); // ADD A,B
        c.step();

        (c.registers.f & Flag.SUBTRACTION).should.equal(0).because(
            "ADD should unset the subtraction flag");
    }

    @Test()
    void addingWithOverflow() {
        c.reset();
        c.registers.pc = 0xC000;

        c.registers.a = 0xFE;
        c.registers.b = 0x03;
        m.writeByte(PGM_START, 0x80); // ADD A,B
        c.step();

        (c.registers.a).should.equal(0x01).because(
            "(0xFE + 0x03) & 0xFF = 0x01");
        (c.registers.f & Flag.OVERFLOW).should.not.equal(0).because(
            "ADD should set the overflow flag when the result > 0xFF");
        (c.registers.f & Flag.HALF_OVERFLOW).should.not.equal(0).because(
            "ADD should set the half-overflow flag when (A & 0xF + B & 0xF) > 0xF");
        (c.registers.f & Flag.ZERO).should.equal(0).because(
            "ADD shouldn't set the zero flag when the result isn't 0");
        (c.registers.f & Flag.SUBTRACTION).should.equal(0).because(
            "ADD should unset the subtraction flag");
    }

    @Test()
    void addingWithOverflowNoHalf() {
        // Add results in overflow but NOT half-overflow

        c.reset();
        c.registers.pc = 0xC000;
        c.registers.a = 0xFE;
        c.registers.b = 0x02;
        m.writeByte(PGM_START, 0x80); // ADD A,B
        c.step();

        (c.registers.f & Flag.OVERFLOW).should.not.equal(0).because(
            "ADD should set the overflow flag when the result > 0xFF");
        (c.registers.f & Flag.HALF_OVERFLOW).should.not.equal(0).because(
            "ADD should set the half-overflow flag when (A & 0xF + B & 0xF) > 0xF");
    }

    @Test()
    void addingWithOverflowBarely() {
        // Add exactly enough to overflow

        c.reset();
        c.registers.pc = 0xC000;

        c.registers.a = 0xFE;
        c.registers.b = 0x02;
        m.writeByte(PGM_START, 0x80); // ADD A,B
        c.step();

        (c.registers.a).should.equal(0x00).because(
            "(0xFE + 0x02) & 0xFF = 0x00");
        (c.registers.f & Flag.OVERFLOW).should.not.equal(0).because(
            "ADD should set the overflow flag when the result > 0xFF");
        (c.registers.f & Flag.HALF_OVERFLOW).should.not.equal(0).because(
            "ADD should set the half-overflow flag when (A & 0xF + B & 0xF) > 0xF");
        (c.registers.f & Flag.ZERO).should.not.equal(0).because(
            "ADD should set the zero flag when the result is 0");
    }
    
}