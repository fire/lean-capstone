import Lake
open Lake DSL System

package «lean-capstone» where
  -- moreLeancArgs / moreLinkArgs left default

/-! ## Capstone disassembler FFI (multi-arch).
    Headers live in `thirdparty/capstone/include` (BSD-3-Clause); the static
    `libcapstone.a` is produced by `thirdparty/capstone/build.sh` (gitignored).
    `ffi/capstone_shim.c` is the C glue; `Capstone.lean` is the typed wrapper.

    Downstream packages: `require «lean-capstone» from git …`, then in any
    executable that calls `Capstone.disasm`, link the vendored archive:
      `moreLinkArgs := #["-Wl,--start-group",
         ".lake/packages/lean-capstone/thirdparty/capstone/lib/libcapstone.a",
         "-Wl,--end-group"]`
    (The `capstoneshim` glue is linked transitively as an `extern_lib`.) -/

@[default_target] lean_lib Capstone

target capstoneShimO pkg : FilePath := do
  let oFile := pkg.buildDir / "ffi" / "capstone_shim.o"
  let srcJob ← inputTextFile <| pkg.dir / "ffi" / "capstone_shim.c"
  let weakArgs := #["-I", (← getLeanIncludeDir).toString,
                    "-I", (pkg.dir / "thirdparty" / "capstone" / "include").toString]
  buildO oFile srcJob weakArgs #["-fPIC", "-O2"] "cc" getLeanTrace

extern_lib libcapstoneshim pkg := do
  let name := nameToStaticLib "capstoneshim"
  let oJob ← capstoneShimO.fetch
  buildStaticLib (pkg.staticLibDir / name) #[oJob]
