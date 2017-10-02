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

### mem_timing-2

| Test name             | Status |
|-----------------------|:--------:|
| 01-read_timing        | :x: |
| 02-write_timing       | :x: |
| 03-modify_timing      | :x: |