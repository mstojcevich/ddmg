struct Instruction {
    string disassembly;
    uint mCycles;
    uint tCycles;
    @safe void delegate() impl;
}