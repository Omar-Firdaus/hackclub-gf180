<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works

16-bit CPU with 4 registers. r0 reads as 0. The program and data live in an external SRAM.

`uo_out[6:0]` is the address. `uo_out[7]` is the write strobe. `uio[7:0]` is the data byte. A read leaves `uio` as inputs. A write drives `uio` and raises the strobe.

Addresses `0x00` to `0x7E` are SRAM. A load from `0x7F` returns `ui_in` in the low byte.

Instructions are two bytes, little endian. Opcodes: add, sub, xor, or, addi, lw, sw, jump, beq. jump and beq use a byte address in the low 7 bits.

## How to test

Put a program in the SRAM and release reset. Each instruction takes several clocks.

From `test/`, run `make`. The waveform is `test/tb.fst`.

## External hardware

128-byte SRAM. `uo_out[6:0]` to the address, `uo_out[7]` to write enable, `uio[7:0]` to the data pins. `ui_in` can be switches.
