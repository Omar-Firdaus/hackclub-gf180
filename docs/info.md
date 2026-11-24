<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works

16-bit single-cycle CPU. Four 16-bit registers, and r0 reads as 0. Instruction memory holds 8 words. Data memory holds 2 words.

Opcodes: add, sub, xor, or, addi, lw, sw, jump.

`ui_in[7] = 0` loads instructions. `ui_in[7] = 1` runs one instruction per clock. The ALU result is split across `uo_out` (low byte) and `uio_out` (high byte).

## How to test

1. Set `ui_in[7]` to 0.
2. Put the instruction address on `ui_in[2:0]`.
3. `ui_in[6] = 0` writes the low byte from `uio_in`. `ui_in[6] = 1` writes the high byte.
4. Set `ui_in[7]` to 1 to run.

From `test/`, run `make`. The waveform is `test/tb.fst`.

## External hardware

None.
