# IMEM Test Sequence (for imem_hex_file.hex)

This sequence focuses on U/J/B-type control and PC-relative instructions,
while still using ADDI for setup/check points.

## Program Listing
1. `00100093` -> `addi  x1,  x0, 1`            // x1 = 1
2. `00000117` -> `auipc x2,  0`                // x2 = PC_of_instr2
3. `008001ef` -> `jal   x3,  +8`               // x3 = PC+4, skip next instr
4. `06300213` -> `addi  x4,  x0, 99`           // skipped by jal
5. `00700213` -> `addi  x4,  x0, 7`            // x4 = 7
6. `03800293` -> `addi  x5,  x0, 56`           // x5 = 56 (target PC for jalr)
7. `00028367` -> `jalr  x6,  x5, 0`            // x6 = PC+4, jump to PC=56
8. `00100a13` -> `addi  x20, x0, 1`            // skipped by jalr
9. `00200a13` -> `addi  x20, x0, 2`            // skipped by jalr
10. `00300a13` -> `addi x20, x0, 3`            // skipped by jalr
11. `00400a13` -> `addi x20, x0, 4`            // skipped by jalr
12. `00500a13` -> `addi x20, x0, 5`            // skipped by jalr
13. `00600a13` -> `addi x20, x0, 6`            // skipped by jalr
14. `00700a13` -> `addi x20, x0, 7`            // skipped by jalr
15. `00300393` -> `addi  x7,  x0, 3`           // x7 = 3
16. `00300413` -> `addi  x8,  x0, 3`           // x8 = 3
17. `00838463` -> `beq   x7,  x8, +8`          // taken, skip next
18. `00100493` -> `addi  x9,  x0, 1`           // skipped by beq
19. `00839463` -> `bne   x7,  x8, +8`          // not taken
20. `00200493` -> `addi  x9,  x0, 2`           // x9 = 2
21. `fff00513` -> `addi  x10, x0, -1`          // x10 = 0xffffffff
22. `00100593` -> `addi  x11, x0, 1`           // x11 = 1
23. `00b54463` -> `blt   x10, x11, +8`         // taken (signed)
24. `00100613` -> `addi  x12, x0, 1`           // skipped by blt
25. `00a5d463` -> `bge   x11, x10, +8`         // taken (signed)
26. `00200613` -> `addi  x12, x0, 2`           // skipped by bge
27. `00a5e463` -> `bltu  x11, x10, +8`         // taken (unsigned 1 < 0xffffffff)
28. `00100693` -> `addi  x13, x0, 1`           // skipped by bltu
29. `00b57463` -> `bgeu  x10, x11, +8`         // taken (unsigned)
30. `00200693` -> `addi  x13, x0, 2`           // skipped by bgeu
31. `00900713` -> `addi  x14, x0, 9`           // x14 = 9
32. `00000013` -> `addi  x0,  x0, 0`           // NOP

## Load/Store Test Sequence (DMEM RTL Verification)

This sequence tests the new data memory (DMEM) integration with load/store instructions.

### Program Listing (Starting at instr 33)

33. `04200093` -> `addi  x1,  x0, 66`           // x1 = 0x42 (test data)
34. `00000113` -> `addi  x2,  x0, 0`            // x2 = 0 (DMEM address)
35. `00112023` -> `sw    x1,  0(x2)`            // Store word: DMEM[0] = 0x42
36. `00012783` -> `lw    x15, 0(x2)`            // Load word: x15 = DMEM[0]
37. `04600093` -> `addi  x1,  x0, 70`           // x1 = 0x46 (new test data)
38. `00400113` -> `addi  x2,  x0, 4`            // x2 = 4 (next word address)
39. `00112023` -> `sw    x1,  0(x2)`            // Store word: DMEM[4] = 0x46
40. `00012783` -> `lw    x15, 0(x2)`            // Load word: x15 = DMEM[4]
41. `05000093` -> `addi  x1,  x0, 80`           // x1 = 0x50 (byte test data)
42. `00010203` -> `lb    x4,  0(x2)`            // Load byte signed: x4 = DMEM[4][7:0]
43. `00010283` -> `lb    x5,  0(x2)`            // Load byte signed: x5 = DMEM[4][7:0]
44. `00114303` -> `lbu   x6,  1(x2)`            // Load byte unsigned: x6 = DMEM[5][7:0]
45. `00000a13` -> `addi  x20, x0, 0`            // x20 = 0 (NOP/checkpoint)

## Hazard Stress Sequence

This sequence extends functional coverage on data hazards.

### Program Listing (Starting at instr 46)

46. `00500813` -> `addi  x16, x0, 5`            // x16 = 5
47. `00380893` -> `addi  x17, x16, 3`           // EX->EX hazard, x17 = 8
48. `00288913` -> `addi  x18, x17, 2`           // EX->EX chain, x18 = 10
49. `00900993` -> `addi  x19, x0, 9`            // x19 = 9
50. `00000013` -> `addi  x0,  x0, 0`            // NOP (create one-cycle gap)
51. `00198a13` -> `addi  x20, x19, 1`           // WB->EX hazard, x20 = 10
52. `07800a93` -> `addi  x21, x0, 120`          // x21 = 0x78
53. `00800b13` -> `addi  x22, x0, 8`            // x22 = 8 (DMEM address)
54. `015b2023` -> `sw    x21, 0(x22)`           // DMEM[8] = 0x00000078
55. `000b2b83` -> `lw    x23, 0(x22)`           // x23 = DMEM[8]
56. `001b8c13` -> `addi  x24, x23, 1`           // Load-use hazard (handled by 1-cycle interlock)
57. `000b2c83` -> `lw    x25, 0(x22)`           // x25 = DMEM[8]
58. `00000013` -> `addi  x0,  x0, 0`            // NOP (workaround for load-use)
59. `001c8d13` -> `addi  x26, x25, 1`           // x26 = 121 (expected to pass)

## Expected Final Register Values
- x1  = 0x00000050
- x2  = 0x00000004
- x3  = 0x0000000c   // JAL link address
- x4  = 0x00000046
- x5  = 0x00000046
- x6  = 0x00000000   // LBU from DMEM[5] (upper byte after SW is zero)
- x7  = 0x00000003
- x8  = 0x00000003
- x9  = 0x00000002
- x10 = 0xffffffff
- x11 = 0x00000001
- x12 = 0x00000000
- x13 = 0x00000000
- x14 = 0x00000009
- x15 = 0x00000046   // Last LW result from DMEM[4]
- x16 = 0x00000005
- x17 = 0x00000008   // EX->EX forwarded
- x18 = 0x0000000a   // EX->EX chained forwarding
- x19 = 0x00000009
- x20 = 0x0000000a   // overwritten by hazard sequence WB->EX test
- x21 = 0x00000078
- x22 = 0x00000008
- x23 = 0x00000078
- x24 = 0x00000079   // load-use fixed by interlock
- x25 = 0x00000078
- x26 = 0x00000079   // expected pass due to inserted NOP after load

### DMEM State After Test

- DMEM[0] = 0x00000042  // SW at instr 35
- DMEM[4] = 0x00000046  // SW at instr 39
- DMEM[8] = 0x00000078  // SW at instr 54
