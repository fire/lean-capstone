import Lake
open Lake DSL System

package «lean-capstone» where
  -- moreLeancArgs / moreLinkArgs left default

/-! ## Capstone disassembler FFI (multi-arch).
    The static multi-arch `libcapstone.a` is built FROM SOURCE by the Lean/Lake
    build system on a plain `lake build` — one-stop, with only a C compiler + ar
    (NO cmake, NO make). `thirdparty/capstone/build.sh` clones capstone and
    compiles its checked-in instruction tables directly (see the script); the
    `capstoneShimO` target below invokes it automatically because the C glue
    (`ffi/capstone_shim.c`) needs capstone's headers, which the same from-source
    step provisions. Both the archive and the copied headers are gitignored.
    `Capstone.lean` is the typed wrapper.

    Downstream packages: `require «lean-capstone» from git …`, then in any
    executable that calls `Capstone.disasm`, link the archive (which the shim
    target has already built from source):
      `moreLinkArgs := #["-Wl,--start-group",
         ".lake/packages/lean-capstone/thirdparty/capstone/lib/libcapstone.a",
         "-Wl,--end-group"]`
    (The `capstoneshim` glue is linked transitively as an `extern_lib`.) -/

@[default_target] lean_lib Capstone

target capstoneShimO pkg : FilePath := do
  -- One-stop: build the multi-arch capstone archive + headers from source (cc +
  -- ar, no cmake) before compiling the shim, which #include's capstone/capstone.h.
  -- Idempotent — build.sh no-ops once lib/libcapstone.a + include/capstone exist.
  let capDir := pkg.dir / "thirdparty" / "capstone"
  let capA := capDir / "lib" / "libcapstone.a"
  let capH := capDir / "include" / "capstone"
  unless (← capA.pathExists) && (← capH.pathExists) do
    logInfo "lean-capstone: building libcapstone.a from source (cc + ar, no cmake)"
    let out ← IO.Process.output { cmd := "bash", args := #[(capDir / "build.sh").toString] }
    unless out.exitCode == 0 do
      error s!"lean-capstone: build.sh failed (exit {out.exitCode}):\n{out.stdout}\n{out.stderr}"
    logInfo out.stdout
  let oFile := pkg.buildDir / "ffi" / "capstone_shim.o"
  let srcJob ← inputTextFile <| pkg.dir / "ffi" / "capstone_shim.c"
  let weakArgs := #["-I", (← getLeanIncludeDir).toString,
                    "-I", (capDir / "include").toString]
  buildO oFile srcJob weakArgs #["-fPIC", "-O2"] "cc" getLeanTrace

extern_lib libcapstoneshim pkg := do
  let name := nameToStaticLib "capstoneshim"
  let oJob ← capstoneShimO.fetch
  buildStaticLib (pkg.staticLibDir / name) #[oJob]
