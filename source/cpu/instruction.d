module cpu.instruction;

struct Instruction {
    string disassembly;
    uint cycles;
    @safe void delegate() impl;
}