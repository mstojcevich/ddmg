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

## Tests
These are DDMG's results on different test ROMs. I'll add more in the future.

### Blargg's Tests
Blargg has several test ROMs mostly revolving around cpu timings and sound along with the OAM and HALT bugs.

**cgb_sound** (note: cgb and sound both aren't implemented yet)

| Test name                | Status | Details                                                                    |
|--------------------------|:--------:|----------------------------------------------------------------------------|
| 01-registers             | :x:      | NR10-NR51 and wave RAM write/read. Failed #2                               |
| 02-len ctr               | :x:      | Length becoming 0 should clear status. Failed #2                           |
| 03-trigger               | :x:      | Enabling in second half of length period shouldn't clock length. Failed #2 |
| 04-sweep                 | :x:      | If shift=0, doesn't calculate on trigger. Failed #3                        |
| 05-sweep details         | :x:      | Timer treats period 0 as 8. Failed #2                                      |
| 06-overflow on trigger   | :x:      | 7FFF 7FFF 7FFF 7FFF 7FFF 7FFF Failed                                       |
| 07-len sweep period sync | :x:      | Length period is wrong. Failed #2                                          |
| 08-len ctr during power  | :x:      | 00 00 00 00 Failed                                                         |
| 09-wave read while on    | :x:      | Lots of 00. Last byte is 7A. Failed                                        |
| 10-wave trigger while on | :x:      | Lots of 00. Failed                                                         |
| 11-regs after power      | :x:      | Powering off should clear NR13. Failed #3                                  |
| 12-wave                  | :x:      | Hangs, never finishes                                                      |



**cpu_instrs**

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