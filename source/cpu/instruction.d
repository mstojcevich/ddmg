module cpu.instruction;

struct Instruction {
    string disassembly;
    uint cycles;
    void delegate() impl;
}