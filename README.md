# DDMG

DDMG is an emulator for the Nintendo Game Boy (DMG) written in [D](https://dlang.org). The goal of DDMG is to create a well-documented emulator with clear and concise code. These goals are not quite met yet.

Because of these goals, there are times where I will sacrifice performance for readability and understanding. I still make an effort to ensure that the compiler will optimize the code in a decent way.

### Completed Features
- Boots and runs commercial games
- Video output
- CPU instructions are pretty accurate in results (not timing yet)

### Unfinished Features (vaguely in order of importance)
- Memory timing
- Sound
- Improved MBC accuracy (requires hardware to test)
- Save states
- Battery saves
- Gameboy color support
- Multicart ROM support
- MBC2, MBC5, MBC6, MBC7, HuC3, HuC1, TAMA5
- Debugger
- Gameboy camera
- Gameboy printer

# Tests
These are DDMG's results on different test ROMs. I'll add more in the future.

## Blargg's Tests
Blargg has several test ROMs mostly revolving around cpu timings and sound along with the OAM and HALT bugs.

None of the Blargg sound tests are included in this README as sound is not implemented.

### cpu_instrs

| Test name             | Status |
|-----------------------|:--------:|
| 01-special            | :white_check_mark: |
| 02-interrupts         | :white_check_mark: |
| 03-op sp,hl           | :white_check_mark: |
| 04-op r,imm           | :white_check_mark: |
| 05-op rp              | :white_check_mark: |
| 06-ld r,r             | :white_check_mark: |
| 07-jr,jp,call,ret,rst | :white_check_mark: |
| 08-misc instrs        | :white_check_mark: |
| 09-op r,r             | :white_check_mark: |
| 10-bit ops            | :white_check_mark: |
| 11-op a,(hl)          | :white_check_mark: |

### halt_bug :white_check_mark:

### instr_timing :white_check_mark:

### interrupt_time :x:

This fails because CGB double-speed mode is not implemented. It should work once CGB support is added.

### mem_timing-2

| Test name             | Status |
|-----------------------|:--------:|
| 01-read_timing        | :white_check_mark: |
| 02-write_timing       | :white_check_mark: |
| 03-modify_timing      | :white_check_mark: |

## Gekkio's Tests
Gekkio has many acceptance tests he's written for his emulator [mooneye-gb](https://github.com/Gekkio/mooneye-gb). These cover many different areas.

### acceptance tests

| Test name            | Status |
|----------------------|:------:|
| add sp e timing          | :white_check_mark: |
| boot hwio dmg0           | :x: |
| boot hwio dmgABCXmgb     | :x: |
| boot regs dmg0           | :x: |
| boot regs dmgABCX        | :white_check_mark: |
| call timing              | :white_check_mark: |
| call timing 2            | :white_check_mark: |
| call cc timing           | :white_check_mark: |
| call cc timing 2         | :white_check_mark: |
| di timing GS             | :x: |
| div timing               | :white_check_mark: |
| ei timing                | :x: |
| halt ime0 ei             | :white_check_mark: |
| halt ime0 noinstr timing | :x: |
| halt ime1 timing         | :white_check_mark: |
| halt ime1 timing2 GS     | :x: |
| if ie registers          | :white_check_mark: |
| intr timing              | :white_check_mark: |
| jp cc timing             | :white_check_mark: |
| jp timing                | :white_check_mark: |
| ld hl sp e timing        | :white_check_mark: |
| oam dma restart          | :white_check_mark: |
| oam dma start            | :x: |
| oam dma timing           | :white_check_mark: |
| pop timing               | :white_check_mark: |
| push timing              | :white_check_mark: |
| rapid di ei              | :x: |
| ret cc timing            | :white_check_mark: |
| ret timing               | :white_check_mark: |
| reti intr timing         | :x: |
| reti timing              | :white_check_mark: |
| rst timing               | :white_check_mark: |