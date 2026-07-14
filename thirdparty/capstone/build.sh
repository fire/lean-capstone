#!/usr/bin/env bash
# Build the vendored multi-arch Capstone static lib (libcapstone.a) FROM SOURCE
# using only a C compiler + ar — NO cmake, NO make. Capstone ships all its
# instruction tables as checked-in .inc files (no code generation), so the whole
# multi-arch library is just a glob of C translation units compiled with one
# -DCAPSTONE_HAS_<ARCH> per architecture. This lets `lake build` provision the
# archive one-stop through the Lean/Lake build system (see lakefile.lean's
# `capstoneArchive` target) on any host with cc — cmake is not required.
#
# The .a (~41 MB) is gitignored. Idempotent: re-invoked on every `lake build`,
# it only does work when lib/libcapstone.a is missing.
# Override: CAPSTONE_REF (git ref, default: default branch), CC, CAPSTONE_OPT.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
CC="${CC:-cc}"
OPT="${CAPSTONE_OPT:--O3}"

if [ -f "$here/lib/libcapstone.a" ] && [ -d "$here/include/capstone" ]; then
  echo "capstone: static archive already present ($here/lib/libcapstone.a)"
  exit 0
fi

src="$(mktemp -d)"; trap 'rm -rf "$src"' EXIT
echo "capstone: cloning source"
if [ -n "${CAPSTONE_REF:-}" ]; then
  git clone --depth 1 --branch "$CAPSTONE_REF" https://github.com/capstone-engine/capstone "$src"
else
  git clone --depth 1 https://github.com/capstone-engine/capstone "$src"
fi

# One -DCAPSTONE_HAS_<ARCH> per architecture directory present in the checkout
# (future-proof: derived from the tree, not a hardcoded list). Names match the
# arch source guards, e.g. arch/AArch64 -> CAPSTONE_HAS_AARCH64.
ARCHDEFS=()
for d in "$src"/arch/*/; do
  a="$(basename "$d")"
  ARCHDEFS+=("-DCAPSTONE_HAS_$(echo "$a" | tr '[:lower:]' '[:upper:]')")
done
CF=(-std=gnu99 "$OPT" -fPIC -I"$src/include" -I"$src" -DCAPSTONE_USE_SYS_DYN_MEM "${ARCHDEFS[@]}")

# Compile every core + arch TU. Exclude non-library trees (tests/tooling/bindings)
# and platform-specific Windows-kernel sources that need the WDK.
obj="$src/obj"; mkdir -p "$obj"
mapfile -t SRCS < <(find "$src" -name '*.c' \
  | grep -vE "/tests/|/suite/|/cstool/|/bindings/|/windows/|/contrib/")
echo "capstone: compiling ${#SRCS[@]} translation units ($OPT, ${#ARCHDEFS[@]} architectures)"
pids=(); fail=0
for s in "${SRCS[@]}"; do
  o="$obj/$(printf '%s' "$s" | md5sum | cut -c1-10)_$(basename "$s").o"
  "$CC" "${CF[@]}" -c "$s" -o "$o" &
  pids+=($!)
  if (( ${#pids[@]} >= $(nproc) )); then wait "${pids[0]}" || fail=1; pids=("${pids[@]:1}"); fi
done
for p in "${pids[@]}"; do wait "$p" || fail=1; done
[ "$fail" -eq 0 ] || { echo "capstone: compile failed"; exit 1; }

mkdir -p "$here/lib" "$here/include"
ar rcs "$here/lib/libcapstone.a" "$obj"/*.o
cp -r "$src/include/capstone" "$here/include/"
echo "capstone: built $here/lib/libcapstone.a ($(du -h "$here/lib/libcapstone.a" | cut -f1)) — full multi-arch, cmake-free"
