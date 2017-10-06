module cpu.instruction;

struct Instruction {
    string disassembly;
    @safe void delegate() impl;
}