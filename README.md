# lean-capstone

**Multi-architecture disassembler for Lean 4 — a typed wrapper over [Capstone](https://github.com/capstone-engine/capstone).**

Decode raw machine-code bytes into structured instructions (address, mnemonic,
operands) for any architecture Capstone supports, directly from Lean.

## API

```lean
import Capstone
open Capstone

-- disasm (arch : Arch) (mode : Mode := {}) (code : ByteArray) (addr : Nat := 0) : Array Insn
#eval do
  let code := ⟨#[0x55, 0x48, 0x8b, 0x05, 0xb8, 0x13, 0x00, 0x00]⟩
  for i in disasm .x86 .b64 code 0x1000 do
    IO.println s!"0x{i.addr |> toString}: {i.mnemonic} {i.ops}"
```

`Insn` carries `addr`, `mnemonic`, and `ops`. `Arch` and `Mode` cover the
common targets (x86 16/32/64, ARM/AArch64, PowerPC 32/64, MIPS, …); combine
mode flags with `|||` and use `Mode.bigEndian` / `Mode.raw` as needed.

## Build

```bash
thirdparty/capstone/build.sh   # clone + build libcapstone.a once (needs git, cmake, a C compiler)
lake build                     # compiles the Capstone wrapper library
```

The Lean wrapper compiles without the static archive; the archive is only
needed when *linking an executable* that calls `disasm`.

## Using it as a dependency

```lean
-- lakefile.lean
require «lean-capstone» from git "https://github.com/fire/lean-capstone" @ "main"
```

In each executable that calls `Capstone.disasm`, link the vendored archive
(the C glue is linked transitively as an `extern_lib`):

```lean
lean_exe my_tool where
  root := `Main
  moreLinkArgs := #[
    "-Wl,--start-group",
    ".lake/packages/lean-capstone/thirdparty/capstone/lib/libcapstone.a",
    "-Wl,--end-group"]
```

After `lake update`, run `.lake/packages/lean-capstone/thirdparty/capstone/build.sh`
once to produce the archive in the fetched package.

## License

`lean-capstone` (the Lean wrapper and C glue) is MIT-licensed (see `LICENSE`).
The vendored Capstone headers under `thirdparty/capstone/include` are
BSD-3-Clause (© the Capstone authors); the build script fetches the matching
Capstone sources at build time.
