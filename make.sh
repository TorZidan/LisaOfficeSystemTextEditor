#!/bin/sh
# make.sh -- build LosTextEditor, the Lisa Office System text editor (tool
# 197000, "Text Editor"), on a PC with the Lisa Pascal cross-compiler
# (https://github.com/TorZidan/LisaPascalCrossCompiler: the Workshop 3.0 Pascal
# compiler, Linker, Alert phrase generator and InstallTool, writing the same
# files as the Workshop's).
#
# The steps (the same as LosTextEditorMake.text does on the Lisa):
#   1. check LosTextEditor.text for Lisa Pascal's 8-character identifier rule,
#      also against the units it uses and the libraries it is linked with
#      ($LISA_PASCAL/pascal/audit_8char.py)
#   2. icon2_48x32.png -> build/LosTextEditorIcon.BIN
#      ($LISA_PASCAL/icon-tool/png2lisaicon.py)
#   3. compile LosTextEditor.text        -> build/LOSTEXTEDITOR_COMPILED.OBJ
#   4. link it with IOSPASLIB, SYS1LIB, SYS2LIB and PRLIB
#                                        -> build/LOSTEXTEDITOR.OBJ
#   5. compile LosTextEditorAlerts.text  -> build/{T197000}PHRASE
#   6. put {T197000}Obj / PHRASE / ICON on the floppy image $DC42_IMAGE
#      (default: LosTextEditor.dc42, the image users get the editor from) and
#      run InstallTool on it
#
#   ./make.sh                 build and install
#   ./make.sh clean           delete build/
#
# Environment:
#   LISA_PASCAL   the LisaPascalCrossCompiler folder (default: next to this
#                 project, ../LisaPascalCrossCompiler)
#   LISA_BOOT     the boot volume folder (default: $LISA_PASCAL/libs/workshop3.0)
#   DC42_IMAGE    the floppy image to install the tool on
#   BUILD_DIR     where the outputs go (default: build)
#   LPC_OPTS      more options for pascal/lpc.py, e.g. --2.0 (the 2.0 build)
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
LISA_PASCAL=${LISA_PASCAL:-$HERE/../LisaPascalCrossCompiler}
DC42_IMAGE=${DC42_IMAGE:-$HERE/LosTextEditor.dc42}
BUILD_DIR=${BUILD_DIR:-$HERE/build}
LIBS="IOSPASLIB SYS1LIB SYS2LIB PRLIB"

die() { echo "make.sh: $*" >&2; exit 1; }

cd "$HERE"
case "$1" in
  clean) rm -rf "$BUILD_DIR"; echo "deleted $BUILD_DIR/"; exit 0 ;;
  "")    ;;
  *)     die "unknown argument '$1' (use: clean, or nothing to build)" ;;
esac

[ -d "$LISA_PASCAL" ] || die "no compiler at $LISA_PASCAL (set LISA_PASCAL)"
LISA_PASCAL=$(cd "$LISA_PASCAL" && pwd)
[ -f "$LISA_PASCAL/pascal/lpc.py" ] || die "no pascal/lpc.py in $LISA_PASCAL (set LISA_PASCAL)"
[ -f "$LISA_PASCAL/pascal/audit_8char.py" ] || die "no pascal/audit_8char.py in $LISA_PASCAL"
command -v python3 > /dev/null || die "python3 is needed"
export LISA_BOOT=${LISA_BOOT:-$LISA_PASCAL/libs/workshop3.0}
FS_TOOLS=$LISA_PASCAL/file-system-tools       # LisaFileSystemTool.py, LisaFileSystemToolPerFile.py
ICON_TOOL=$LISA_PASCAL/icon-tool/png2lisaicon.py
[ -f "$FS_TOOLS/LisaFileSystemToolPerFile.py" ] || die "no LisaFileSystemToolPerFile.py in $FS_TOOLS"
[ -f "$ICON_TOOL" ] || die "no $ICON_TOOL"
[ -f "$DC42_IMAGE" ] || die "no disk image at $DC42_IMAGE (set DC42_IMAGE)"
DC42_IMAGE=$(cd "$(dirname "$DC42_IMAGE")" && pwd)/$(basename "$DC42_IMAGE")

# The sources go into the build folder, as on one Lisa volume.
mkdir -p "$BUILD_DIR"
BUILD_DIR=$(cd "$BUILD_DIR" && pwd)
cp "$HERE"/*.text "$BUILD_DIR/"

# audit <program>: the 8-character identifier rule (the program, the units it
# uses, found through the boot volume's INTRINSIC.LIB, and the libraries)
audit() {
  echo "checking 8-character identifier rules in $1.text (audit_8char.py)"
  ( cd "$BUILD_DIR" && python3 "$LISA_PASCAL/pascal/audit_8char.py" -q --fail-on-warn \
      --libs "$(echo $LIBS | tr ' ' ',')" --boot "$LISA_BOOT" "$1" ) ||
    die "audit_8char.py found identifier collisions in $1.text"
}

# compile <program> <output>: front end and code generator, with checks
compile() {
  echo "compiling $1.text"
  log="$BUILD_DIR/compile-$1.log"
  ( cd "$BUILD_DIR" && rm -f "$2.OBJ" PROGCOMM.TEXT ./*.I &&
    python3 "$LISA_PASCAL/pascal/lpc.py" $LPC_OPTS "$1" '' "$2" < /dev/null > "$log" 2>&1 &&
    [ -f "$2.OBJ" ] ) ||
    { tail -40 "$log"; die "the compilation failed (see $log)"; }
  echo "  $(grep 'Compilation complete' "$log" | sed 's/^ *//')"
  echo "  $(grep 'Total code size' "$log" | sed 's/^ *//')"
}

# link <output> <inputs...>
link() {
  out=$1; shift
  echo "linking $out with $*"
  ( cd "$BUILD_DIR" && rm -f "$out.OBJ" &&
    python3 "$LISA_PASCAL/linker/lisalinker.py" -o "$out" -m "$out.map" "$@" > "link-$out.log" 2>&1 ) ||
    { cat "$BUILD_DIR/link-$out.log"; die "the link failed (see $BUILD_DIR/link-$out.log)"; }
  echo "  $(sed -n 's/^\([0-9]* jump table.*\)/\1/p' "$BUILD_DIR/link-$out.log")"
  echo "  $BUILD_DIR/$out.OBJ: $(wc -c < "$BUILD_DIR/$out.OBJ") bytes"
}

echo "=== LosTextEditor (Lisa Office System)"
audit LosTextEditor
echo "converting the png icon to a Lisa icon"
python3 "$ICON_TOOL" "$HERE/icon2_48x32.png" "$BUILD_DIR/LosTextEditorIcon.BIN"
compile LosTextEditor LOSTEXTEDITOR_COMPILED
link LOSTEXTEDITOR LOSTEXTEDITOR_COMPILED $LIBS

echo "compiling LosTextEditorAlerts.text"
( cd "$BUILD_DIR" && rm -f '{T197000}PHRASE' &&
  python3 "$LISA_PASCAL/alert/alert.py" "$HERE/LosTextEditorAlerts.text" '{T197000}' > alert.log 2>&1 ) ||
  { cat "$BUILD_DIR/alert.log"; die "alert failed (see $BUILD_DIR/alert.log)"; }
echo "  $(grep 'All .* alerts read' "$BUILD_DIR/alert.log")  $(grep 'All .* menus read' "$BUILD_DIR/alert.log")"
echo "  $BUILD_DIR/{T197000}PHRASE: $(wc -c < "$BUILD_DIR/{T197000}PHRASE") bytes"

echo "installing {T197000} onto $DC42_IMAGE"
{
  python3 "$FS_TOOLS/LisaFileSystemToolPerFile.py" put "$DC42_IMAGE" "$BUILD_DIR/LOSTEXTEDITOR.OBJ" '{T197000}Obj'
  python3 "$FS_TOOLS/LisaFileSystemToolPerFile.py" put "$DC42_IMAGE" "$BUILD_DIR/{T197000}PHRASE" '{T197000}PHRASE'
  python3 "$FS_TOOLS/LisaFileSystemToolPerFile.py" put "$DC42_IMAGE" "$BUILD_DIR/LosTextEditorIcon.BIN" '{T197000}ICON'
  python3 "$LISA_PASCAL/installtool/installtool.py" --fs-tool "$FS_TOOLS" \
    --image "$DC42_IMAGE" Y '' 197000 N N 'Text Editor'
} < /dev/null > "$BUILD_DIR/installtool.log" 2>&1 || { cat "$BUILD_DIR/installtool.log"; die "installtool failed on $DC42_IMAGE (see $BUILD_DIR/installtool.log)"; }
echo "  $(grep 'successfully installed' "$BUILD_DIR/installtool.log")"
