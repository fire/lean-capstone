# lean-capstone

Decode raw machine-code bytes into structured instructions (address, mnemonic,
operands) for any architecture Capstone supports, directly from Lean.

## RISC-V gotcha

`Mode.riscv32`/`Mode.riscv64` alone are not enough to decode real-world
RISC-V code produced by `-march=rv*gc`-style toolchains: GCC/Clang's
default codegen routinely emits compressed ("C" extension) and float/
double ("F"/"D" extension) instructions, and Capstone needs an explicit
mode bit for each (`Mode.riscvC`, `Mode.riscvFD`) to decode them.
Omitting either is not an error -- `cs_disasm` just silently stops at
the first instruction it can't decode and returns whatever it managed
before that point (an empty array, if the very first instruction needs
the missing bit). Combine what your input actually uses:

```lean
let mode := Mode.riscv64 ||| Mode.riscvC ||| Mode.riscvFD
Capstone.disasm .riscv mode code addr
```
