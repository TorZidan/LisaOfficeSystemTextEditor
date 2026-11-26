#!/bin/sh
# make.sh -- build LosTextEditor on a PC with the Lisa Pascal cross-compiler
# (https://github.com/TorZidan/LisaPascalCrossCompiler: the Workshop 3.0
# compiler, and a Linker that writes the same program file as the Workshop's).
#
# It does steps 1 and 2 of LosTextEditorMake.text:
#   1. compile LosTextEditor.text        -> build/LOSTEXTEDITOR_COMPILED.OBJ
#   2. link it with IOSPASLIB, SYS1LIB, SYS2LIB and PRLIB
#                                        -> build/LOSTEXTEDITOR.OBJ
# Steps 3-5 (copy to T197000Obj, the phrase file with Alert, InstallTool)
# run Lisa programs: do them on the Lisa, with LOSTEXTEDITOR.OBJ copied there.
#
#   ./make.sh                 build
#   ./make.sh --compare       build, then compare LOSTEXTEDITOR.OBJ with the
#                             tool on LosTextEditor.dc42 (the same when the
#                             image was built from the same source)
#   ./make.sh clean           delete build/
#
# Environment:
#   LISA_PASCAL   the LisaPascalCrossCompiler folder (default: next to this
#                 project, ../LisaPascalCrossCompiler)
#   LISA_BOOT     the boot volume folder (default: its boot-workshop3.0)
#   BUILD_DIR     where the outputs go (default: build)
#   LPC_OPTS      more options for lpc.py, e.g. --2.0
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
LISA_PASCAL=${LISA_PASCAL:-$HERE/../LisaPascalCrossCompiler}
BUILD_DIR=${BUILD_DIR:-build}
LIBS="IOSPASLIB SYS1LIB SYS2LIB PRLIB"

die() { echo "make.sh: $*" >&2; exit 1; }

cd "$HERE"
case "$1" in
  clean)     rm -rf "$BUILD_DIR"; echo "deleted $BUILD_DIR/"; exit 0 ;;
  --compare) COMPARE=yes ;;
  "")        ;;
  *)         die "unknown argument '$1' (use: --compare, clean)" ;;
esac

[ -d "$LISA_PASCAL" ] || die "no compiler at $LISA_PASCAL (set LISA_PASCAL)"
LISA_PASCAL=$(cd "$LISA_PASCAL" && pwd)
[ -f "$LISA_PASCAL/pascal/lpc.py" ] \
  || die "no compiler at $LISA_PASCAL/pascal/lpc.py (set LISA_PASCAL)"
command -v python3 > /dev/null || die "python3 is needed"
export LISA_BOOT=${LISA_BOOT:-$LISA_PASCAL/boot-workshop3.0}

echo "auditing 8-char identifiers in LosTextEditor.text"
python3 "$LISA_PASCAL/pascal/audit_8char.py" --fail-on-warn --libs "$LIBS" "$HERE/LosTextEditor.text"

mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"
# delete stale outputs first: a stale .OBJ silently poisons a build
rm -f LOSTEXTEDITOR_COMPILED.OBJ LOSTEXTEDITOR.OBJ LOSTEXTEDITOR_COMPILED.I PROGCOMM.TEXT

# 1. compile: source / no listing / object
echo "compiling LosTextEditor.text"
python3 "$LISA_PASCAL/pascal/lpc.py" $LPC_OPTS "$HERE/LosTextEditor" '' LOSTEXTEDITOR_COMPILED \
  < /dev/null > compile.log 2>&1 || true
if ! grep -q 'Compilation complete - no errors found' compile.log; then
  grep -B2 -A3 '\*\*\*' compile.log | head -40
  die "the compiler reported errors (see $BUILD_DIR/compile.log)"
fi
if grep -q '\*\*\*' compile.log || [ ! -f LOSTEXTEDITOR_COMPILED.OBJ ]; then
  die "the code generator failed (see $BUILD_DIR/compile.log)"
fi
echo "  $(grep 'Compilation complete' compile.log | sed 's/^ *//')"
echo "  $(grep 'Total code size' compile.log | sed 's/^ *//')"

# 2. link
echo "linking with $LIBS"
python3 "$LISA_PASCAL/linker/lisalinker.py" -o LOSTEXTEDITOR -m LOSTEXTEDITOR.map \
  LOSTEXTEDITOR_COMPILED $LIBS > link.log 2>&1 \
  || { cat link.log; die "the link failed (see $BUILD_DIR/link.log)"; }
echo "  $(sed -n 's/^\([0-9]* jump table.*\)/\1/p' link.log)"
echo "  $BUILD_DIR/LOSTEXTEDITOR.OBJ: $(wc -c < LOSTEXTEDITOR.OBJ) bytes"

if [ "$COMPARE" = yes ]; then
  python3 -I -c '
import sys
sys.path.insert(0, sys.argv[1])
from lisafiles import files
for fid, (pages, data) in sorted(files(sys.argv[2]).items()):
    if data[:1] == b"\x99" and b"LTEUtil " in data:
        open(sys.argv[3], "wb").write(data)
        break
else:
    sys.exit("no linked LosTextEditor program on the disk image")
' "$LISA_PASCAL/tools" "$HERE/LosTextEditor.dc42" DISK_IMAGE.OBJ || die "cannot read LosTextEditor.dc42"
  if cmp -s LOSTEXTEDITOR.OBJ DISK_IMAGE.OBJ; then
    echo "identical to the tool on LosTextEditor.dc42"
  else
    echo "DIFFERENT from the tool on LosTextEditor.dc42 (extracted to $BUILD_DIR/DISK_IMAGE.OBJ)"
    exit 1
  fi
fi
