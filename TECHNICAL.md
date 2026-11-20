# Text Editor — technical notes

How the Text Editor is built and how the code in `LosTextEditor.text` works. For using the editor, see
[README.md](README.md).

## Contents

1. [Files](#1-files)
2. [Building and installing](#2-building-and-installing)
3. [Lisa Pascal rules that matter here](#3-lisa-pascal-rules-that-matter-here)
4. [Program structure](#4-program-structure)
5. [Life of the tool under the Office System](#5-life-of-the-tool-under-the-office-system)
6. [The text in memory](#6-the-text-in-memory)
7. [Display](#7-display)
8. [Editing and Undo](#8-editing-and-undo)
9. [Markers](#9-markers)
10. [Search](#10-search)
11. [The `.TEXT` file format](#11-the-text-file-format)
12. [The working copy (saved-text data segment)](#12-the-working-copy-saved-text-data-segment)
13. [Printing](#13-printing)
14. [Menus and the phrase file](#14-menus-and-the-phrase-file)
15. [The dialog bar](#15-the-dialog-bar)
16. [The desktop icon](#16-the-desktop-icon)
17. [Checking and verifying changes](#17-checking-and-verifying-changes)

---

## 1. Files

| File | Purpose |
|---|---|
| `LosTextEditor.text` | The whole program: one Lisa Pascal source file (about 5,500 lines). |
| `LosTextEditorAlerts.text` | Phrase-file source: the six menus and the two alerts the Alert Manager requires. |
| `LosTextEditorMake.text` | Workshop exec file: compile, link, install the files under the tool number, compile the phrase file, run InstallTool. |
| `ICON.BIN` | The desktop icon (a QuickDraw font, see [§16](#16-the-desktop-icon)). |
| `icon2_48x32.png` | The icon picture at Lisa size, 48 × 32, black and white. |
| `png2lisaicon.py` | Converts a 48 × 32 PNG into an icon file such as `ICON.BIN`. |
| `audit_8char.py` | Checks the program for identifier clashes (see [§3](#3-lisa-pascal-rules-that-matter-here)). |

The Python tools use only the Python 3 standard library.

## 2. Building and installing



Requirements: Lisa Workshop 3.0 with the Office System 3.1 libraries (`IOSPASLIB`, `SYS1LIB`,
`SYS2LIB`, `PRLIB` and `INTRINSIC.LIB`).

The Text Editor is built with the Lisa Workshop 3.0 and installed as Office System tool number
**197000**. Copy these files to the Workshop disk:

| File | What it is |
|---|---|
| `LosTextEditor.text` | the program |
| `LosTextEditorAlerts.text` | the menus (the "phrase file") |
| `LosTextEditorMake.text` | the build script |
| `ICON.BIN` | the desktop icon (copy it unchanged, as a binary file) |

Then, in the Workshop, choose **R**un and type `<LosTextEditorMake` to run it as a "macro".

`<LosTextEditorMake` (`LosTextEditorMake.text`) runs the following steps, in order:

1. Deletes stale `LOSTEXTEDITOR_COMPILED.OBJ` and `LOSTEXTEDITOR.OBJ`.
2. Compiles `LOSTEXTEDITOR.TEXT` to `LOSTEXTEDITOR_COMPILED.OBJ`.
3. Links it with `IOSPASLIB`, `SYS1LIB`, `SYS2LIB`, `PRLIB` into `LOSTEXTEDITOR.OBJ`. The intrinsic
   units (QuickDraw, the Window Manager, the scroll-bar library, AlertMgr, FilerComm, the Print
   Manager declarations …) are resolved through `INTRINSIC.LIB`.
4. Copies the executable to `{T197000}Obj` and `ICON.BIN` to `{T197000}ICON`.
5. Runs the Alert tool on `LOSTEXTEDITORALERTS.TEXT`, producing `{T197000}PHRASE`.
6. Runs InstallTool: tool 197000, no documents, default window, name "Text Editor". This produces the LOS executable file {T197000}Obj ;
oce you reboot into LOS, it will automatically show up as a separate icon labeled "Text Editor" on the ProFile hard drive.

**The tool number appears only in `LosTextEditorMake.text`.** At run time the program reads its own pathname
(`Info_Process`), keeps everything up to the closing brace (`<volume>-{T197000}`), and derives all its
file names from that prefix: the phrase file, the working-copy data segment and the scratch data
segment. Renumbering the tool therefore needs no change to the program. Tool numbers are long
integers in the Filer, and InstallTool accepts numbers above 32767.

Exec-file pitfalls: curly braces are comments in exec files (write `~{` and `~}` to pass a brace on),
comments do not nest (`${ … {T197000} … }` breaks the line), and a line holding only a comment emits a
bare RETURN, which the script uses on purpose for "no listing" and "default device" answers.


## 3. Lisa Pascal rules that matter here

- **Identifiers are significant to 8 characters**, case-insensitively. `CheckMarks` and the Menus
  unit's `CheckMark` are the *same* identifier. Run `python3 audit_8char.py` after every change: it
  compares every program-level name against each other and against the interfaces of the 18 units in
  the `uses` list (read from the Computer History Museum Lisa sources).
- **A `var` parameter needs exactly the declared type.** Two separately declared `string[255]` types
  are different types; therefore `FileStr = str` is declared as an alias of `str`.
- **4-digit hex constants are 16-bit integers**: `$8000` is −32768. Long constants are written with 8
  hex digits (`$00008000`) or in decimal.
- **Code segments** are limited to 32 KB. The program is split with `{$S name}` into: the resident
  main segment (event loop, callbacks, text addressing, display, selection), `LTEUtil`, `LTEErr`,
  `LTEDlg`, `LTEEdit`, `LTEMisc`, `LTESrch`, `LTEFile`, `LTECmd`, `LTEPrnt`, `LTEMenu`, `LTELife`,
  `LTEInit`. The termination handler and the heap callbacks stay in the main segment.
- `{$R-}`: range checks are off; the page code indexes one past the end of a page in a few
  read-only comparisons.

## 4. Program structure

The source file is ordered so that every routine is declared before use (a few `forward`
declarations remain). In order:

| Section | Contents |
|---|---|
| Constants, types, globals | page and line limits, LDSNs, menu ids/items, the document record `The`, undo record `Last` |
| Helpers (`LTEUtil`) | `NumToStr`, `StrToNum`, `UpStr`, `TrimStr`, `BeginIO`/`EndIO` |
| Heap growth (`LTEErr`), callbacks | `GrowHeap`/`StoreError`, `OutOfHeapSpace`, `AlertFailed`, `LastWishes` |
| Dialog bar (`LTEDlg`) | `ReadCh`, `GetReply`, `DrawTheBox`, `Confirm`, `Error`, `Warning`, `GetNumber` |
| Pages, geometry, display | `NewPage`, `FreeUp`, `FindLine`, `GenLine`, `FindChar`, `FindPoint`, `Repaint`, scrolling, caret, selection highlighting, status line, title, line-number margin |
| Selection | `Select`, `Drag`, `ExtendSelect`, `SelectAll` |
| Editing (`LTEEdit`) | marker bookkeeping, `Cut`, `Copie`, `Deletion`, `Paste`, `Insertion`, Shift Left/Right |
| Fonts (`LTEMisc`) | `OpenMainFont`, `FamilyOf`, `StyleOf`, `ChangeFont` |
| Search, Go to, markers (`LTESrch`) | `FindNext`, `DoFind`, `DoFindAll`, `DoGoTo`, `SetMarker`, `GoToMarker` … |
| Files (`LTEFile`) | `.TEXT` read/write, New/Open/Save/Revert, working copy `SaveWork`/`LoadWork` |
| Commands (`LTECmd`) | `Do…`/`Undo…` pairs, `DoUndo`, `DoTypeIn`, arrow keys `DoCmdChr`, grow, scroll |
| Printing (`LTEPrnt`) | `DoFormatPr`, `DoPrintText` |
| Menus (`LTEMenu`) | `RefreshMenuState`, `PutUpMenus`, `ReadyMenus`, `MenuCommand` |
| Life cycle (`LTELife`) | `InitNewDoc`, `PutAwayDoc`, `HandleFilerOp`, `ProcessEvent` |
| Start-up (`LTEInit`) | `Initialize` |
| Main program | `InitGraf`, `OpenWM`, `Initialize`, the event loop, shutdown |

## 5. Life of the tool under the Office System

The Text Editor is a **tool without documents** (InstallTool question 4 answered N): the Filer starts
the process and lends it one window.

**Start-up** (`Initialize`), in this order — every failure answers the Filer with
`TellFiler(initFailed, …)` and halts, because the desktop waits for the tool:

1. `Declare_Excep_Hdl` installs `LastWishes` for `SYS_TERMINATE` first, so even a crash during start-up
   calls `ImDying` (until `ImDying` the Filer is blocked).
2. Globals are set to known values.
3. `InitHeap` on a static array (`myZone`, 20 KB): menus, the alert cache, scroll-bar lists and
   regions live there.
4. `Info_Process` → the tool prefix (see [§2](#2-building-and-installing)).
5. `InitMP` loads `<prefix>PHRASE`: menus into `myMenus[1..6]` and the alerts.
6. `PrMgrInit` (needs the Alert Manager), `InitWmlCrs` (cursors), `InitWmlSb` (scroll bars).
7. The **Store**: a scratch data segment `<prefix>text store` (LDSN 3, 32 KB, grows on demand) turned
   into a heap zone with `HzInit`; all text pages live there.
8. A scratch page for typed characters.

**The window.** The Filer sends a filer event with `fcNone` and the window in `theEvent.who`.
`HandleFilerOp` answers it by calling **`InitNewDoc`**, which:

- calls **`TakeWindow(myWindow)`** so the window's events come to this process,
- remembers the Filer's window title (`GetFldrTitle`) to restore it later,
- gets the text: the copy still in memory, else the working copy from disk (`LoadWork`), else a
  fresh empty text; a text that is linked to a file and has no unsaved changes is replaced by a fresh
  text,
- creates the scroll bars once, paints everything, and — because no `folderActivate` arrives for the
  first activation — puts up the menus itself when the window is already active,
- sets `PendingOpen` when the text is empty and unnamed: the main loop then shows the
  *Open text file* question on its first idle pass (not inside the Filer handshake).

**The event loop** (main program) has two phases:

- *Phase A* — not active: `GetEvent` blocks (the process may be suspended) and every event goes to
  `ProcessEvent`.
- *Phase B* — active: poll `EventAvail`; when idle, track the cursor (I-beam over the text), blink the
  caret, redraw the status line if the selection moved, resize the line-number margin if needed, open
  a pending *Open* question, and always call `LetOthersRun`.

`ProcessEvent` handles: `buttonDown` (menu bar → `MenuSelect`; window → selection, size box, scroll
bar), `buttonUp` (multi-click timing), `keyDown` (Apple keys → `MenuKey`; arrows → `DoCmdChr`; typing →
`DoTypeIn`), `folderActivate` (`TakeControl`, rebuild the menu bar, show scroll bars and highlight),
`folderDeactivate` (hide highlight and scroll bars, then the mandatory `GiveControl`), `folderUpdate`
(repaint inside `BeginUpdate`/`EndUpdate`; updates for windows that are no longer ours are consumed
empty), and filer events.

**Filer commands** (`HandleFilerOp`, after `GetAddParms` exactly once per event):

| Command | Answer |
|---|---|
| `fcNone` | the launch: `InitNewDoc` |
| `fcResume` | refused (`docClosd`, `internalError`): a tool has no documents |
| `fcClose`, `fcSuspend`, `fcShred` | save the working copy, give the window back (title restored), `TellFiler(docClosd, allOK)` |
| `fcCopy`, `fcPut` | refused (`docNotXfered`) |
| `fcDfClose` | `dfClosed, allOK` (no disk files are kept open) |
| `fcTerminate` | ends the main loop; the program then saves the working copy, closes and kills the Store, and falls off the end, which runs `LastWishes` → `ImDying` |

**Put away** (`PutAwayDoc`, used by *Save & Put Away* and *Exit Editor*): if there are unsaved
changes, ask; **Y** saves to the `.TEXT` file (asking for a name if needed), **N** deletes the working
copy and frees the in-memory text so it cannot come back, a click cancels. Then the window title is
restored and the window handed back with `TellFiler(docClosd, docPutBack)`. The window is lent, never
disposed of.

**Blocking OS calls.** A process started by the Window Manager runs non-preemptively; every OS call
that can wait for the disk (data segments, file I/O, `Info_Process`, heap growth) is bracketed by
`BeginIO`/`EndIO`, which call `Sched_Class(false)` … `Sched_Class(true)` (nesting is counted).

**LDSNs used:** 1 — Print Manager spool segment (`PrDocStart`); 2 — working copy (opened only while
saving/loading); 3 — the Store. The Print Manager itself uses 9 and 12, the Window Manager 15.

## 6. The text in memory

**Pages.** The text is a doubly linked list of 1 KB pages (`page`: `prvpage`, `nxtpage`, `linesinp`,
`p: packed array [0..1023] of char`), allocated in the Store. The first page of the list
(`The.HeadList`) is the **header page** of the `.TEXT` file and holds no text; text pages follow.

- Each line ends with CR (`chr(13)`); unused bytes at the end of a page are NUL. At least one NUL
  always remains at the end of a page.
- Lines never cross pages: pages are split at line boundaries (`BreakPg`).
- `linesinp` counts the line ends in a page (`KntLines`); `The.LinesTot` is their sum (`TotalKnt`).
- **Invariant:** the text always ends with a CR (`FixDocEnd`, run after cuts and loads). The position
  after the last CR is line `LinesTot`, an empty line where typing at the end of the text goes.
- A line holds at most 255 characters; Cut and Paste refuse to build longer lines.
- Tabs are never stored: typed tabs become spaces up to the next tab stop.

**Places.** A position is a `Place` (`Ln`, 0-based line; `Ch`, 1-based column). The variant field
`LnCh` overlays both as one long integer, so positions compare with a single `<`. A selection is a
`Range` (`Left`, `Right`); an insertion point has `Left = Right`.

**Addressing.** `FindLine(pp, ndx, Ln)` walks the page list using `linesinp`, then the characters, to
the start of line `Ln`. `MarkPos` turns a column into an index (and clamps the column to the line).
`GenLine` copies one line into a string, with a one-line cache.

**The Store** grows through its heap zone's error procedure: `StoreError` → `GrowHeap`, which enlarges
the data segment with `Size_DataSeg`, keeping a working set of free swap space. Freed pages shrink it
again (`CbShrinkHz`).

## 7. Display

All drawing is QuickDraw in the lent window's port.

- **Geometry:** `BodyRect` is the window minus scroll bar and size box; `TextRect` is that, inset, and
  shifted right by `MarginW` when line numbers are shown. Everything that converts between pixels and
  places (`FindChar`, `FindPoint`), draws (`Repaint`) or highlights (`InvText`) goes through
  `TextRect`, so the margin moves all of it at once.
- **Font metrics:** `OpenMainFont` reads `FMFontMetrics`/`FMFontWidths` for the chosen family and sets
  the line height (`VertSp`), ascent/descent and the width of a space.
- **Painting:** `Repaint(First, Count)` erases the rows and draws each line with `DrawText`, the line
  numbers (when on) right-aligned in the margin, then re-inverts the visible part of the selection.
  `ClipToText` clips to whole lines (including the margin).
- **Scrolling:** `ScrollUpDown` uses `ScrollRect` and repaints only the uncovered lines; `UpdateDoc`
  repaints fully for long jumps. The scroll range allows the empty last line to be shown
  (`MaxPosn`). The elevator position is kept in thousandths (`CalcElevPosn`/`CalcDocPosn`).
- **Caret and selection:** the caret is an XOR line (`CaretVis`) blinking at the Window Manager's
  caret rates; the selection is shown by `InvertRect` (`InvText`), so drawing it twice removes it.
- **Status line:** drawn in the bottom bar where a horizontal scroll bar would be (`DrawStatus`, small
  15-pitch font); redrawn only when the selection changed.
- **Title:** `ShowTitle` sets the window title to the file name or "New text file" (`SetFldrTitle`);
  `RestoreTitle` gives the window its Filer title back before it is returned.
- **Line-number margin:** `WantMarginW` computes the width for the largest visible line number
  (digits × width of "0" + gap); `FitMargin` resizes and repaints when it changes — after every scroll
  and on idle passes.
- **Size box / scroll bars:** WMLgrow and WMLsb (`FGrowHit`, `DragFrame`, `FSbHit`, `DragThumb`,
  `PaintSb`, `PaintArw`, `MoveThumb`).

## 8. Editing and Undo

- **`Cut(var junk)`** removes the selection into a separate page list (one page if within a page,
  otherwise the middle pages are spliced out whole), joins the two line halves, removes emptied pages,
  and repaints — a single-line cut just scrolls the rest of the line left.
- **`Copie`** copies the selection into a page list.
- **`Paste(list)`** inserts a page list at the insertion point: into the same page (opening a gap) if
  it fits, otherwise via `PasteChars`, which splits pages at line boundaries. Text inserted at the end
  gets its final CR.
- **Typing** (`DoTypeIn`) collects keystrokes already waiting in the queue, then performs backspaces
  (`Deletion`, which uses `Cut` across line ends and `SmallDelete` within a line) and one `Insertion`
  (which expands tabs and adds the auto-indent after Return) — so fast typing is one paste.
- **Clipboard:** `scraplist`, a page list private to the process.

**Undo** keeps exactly one command in `Last` (`CmdInfo`, a variant record keyed by the command):
`Cmd` is the last command, `Data` the command whose data is held (they differ after an Undo), and the
variant parts hold what is needed to reverse it — the cut text (`List`), the previous selection,
the previous tab setting, font, scroll position, search target, and so on. `StartCmd` begins every
command and frees data that can no longer be undone. `DoUndo` dispatches to the `Undo…` routine, and
an Undo of an Undo re-runs the `Do…` routine (redo).

## 9. Markers

Up to 18 markers (`The.Markers`, each a 14-character name and a `Range`).

- **Following edits:** `CutMarks(range, remove)` moves every marker place for a removal (unchanged
  before it, to its start inside it, shifted back after it); with `remove`, markers lying wholly inside
  a cut are deleted and the user is told. `PasteMarks(at, lines, chars)` shifts places at or after an
  insertion by the number of line breaks inserted and, on the insertion line, by the characters after
  the last break. `SmallDelete` (backspace within a line) moves markers too.
- **Validation:** `ValidMarks` drops markers that do not fit a loaded text.
- **Storage:** in the `.TEXT` header (§11) and in the working copy (§12).
- **Go to Marker** finds the marker whose start is the nearest after the insertion point (wrapping
  around) as the default answer; it is undoable through the same mechanism as Go to Line.

## 10. Search

`FindNext` scans the page list forward from the end of the selection, comparing the first character
fast and the rest in `Match`. Without *Match Case* both sides are upper-cased. *Whole Words Only*
rejects matches that start or end inside an identifier (letters, digits, `_`, `$`); a target of 8 or
more identifier characters is treated as a prefix (it also matches longer identifiers that begin with
it — the 8-character rule of Lisa Pascal). *Wrap Around* continues from line 0 once. *Find & Paste All*
loops `FindNext` → `Cut` → `Paste(scraplist)`; Apple-period (`AbortFlag`) stops the unverified mode.

## 11. The `.TEXT` file format

A Workshop text file is a sequence of 1 KB pages (two 512-byte blocks each):

- **Page 0 — header page.** At byte offset 512 inside it lies the `Header` record:

  | Field | Meaning |
  |---|---|
  | `Version` | 51 … 57 accepted; 57 is written; markers exist from 57 on |
  | `FontId` | font family of the type style (mapped back by `StyleOf`) |
  | `FontName`, `Dummy1`, `LMargin`, `RMargin`, `ParaMargin`, `CmdChar` | unused here; preserved |
  | `TabsIncr` | tab setting |
  | `DocPosn`, `ElevPosn`, `Select` | scroll position and selection at the last save (restored on open) |
  | `Dirty`, `TimeWritten` | `Dirty` is set on save, `TimeWritten` is kept as read; neither is used on read |
  | `NumMarkers`, `Markers[1..18]` | named markers (name up to 14 characters + range) |

  The rest of the header page is kept as read, so data written there by other programs survives a save.

- **Text pages.** Lines end with CR; no line crosses a page; the page is padded with NUL. Leading
  blanks are compressed: **DLE** (`chr(16)`) followed by `chr(32 + n)` stands for n spaces. Trailing
  blanks are dropped on write.

`ReadFile` reads 4 pages at a time with `blockread`, expands DLE, forces a CR at line ends and builds
the page list (`AppendLn`/`EndChain`). `WriteFile` updates the header in the header page, compresses
leading blanks and writes with `blockwrite`; the file is closed with `CRUNCH` (or `PURGE` after an
error). File names get `.TEXT` appended when missing (`CheckTitle`).

## 12. The working copy (saved-text data segment)

`<prefix>work text` is a shared data segment holding a `WorkHdr` followed by the text:

| Field | Meaning |
|---|---|
| `Version` | `WorkVersion` (2); anything else is ignored |
| `HasFile`, `FileName`, `Changed` | the link to the `.TEXT` file and whether it has unsaved changes |
| `Select`, `DocPosn` | selection and scroll position |
| `TabsIncr`, `FontStyle`, `FontSize` | settings |
| `NumMarkers`, `Markers` | markers |
| `TextLen` | number of text bytes that follow |

The text is stored as plain characters, lines separated by CR. `SaveWork` deletes and re-creates the
segment at the exact size (on Set Aside, put away, `fcClose`/`fcSuspend`/`fcShred` and
`fcTerminate`); `LoadWork` validates every field, splits over-long lines, rebuilds the page list and
closes the segment. `KillWork` deletes it (after "N" at Exit). Restoring follows the rule in
`InitNewDoc` (§5): only texts with unsaved work are brought back.

## 13. Printing

Through the Office System Print Manager (`PrPublic`, linked from `PRLIB`):

- `prRec` (`TPrRec`) is left invalid at start-up and defaulted on the first print command
  (`EnsurePrRec`: `FPrPrfValid` / `PrPrfDefault`).
- *Format for Printer* → `PrPrfDlg(prRec, fNewStl, true)`.
- *Print* / *Print Selection* → `FPrInsDlg(prRec, fNewStl, ePrNormal)` (copies and page range), then
  `PrDocStart(prRec, prPort, 1, true)`; per page `PrPageStart` (false for pages outside the requested
  range: nothing is drawn) and `PrPageEnd` (true after the last requested page); finally
  `PrDocEnd`, always.
- On each page the text font is set in the printer port and measured with `GetFontInfo`, so the
  line height is the printer's; lines are drawn with `DrawText` and the printer's own font strike is
  used at its natural size. Half-inch margins (`PrInfo.HRes/VRes`) inside `PrInfo.rPrintable`, two
  lines reserved for the footer.
- *Monitor the Printer* → `PrBgdDlg`.

## 14. Menus and the phrase file

`LosTextEditorAlerts.text` is compiled by the Alert tool into `{T197000}PHRASE`; `InitMP` reads it.

- Line 1 is the version stamp; it must equal `alertVerNum` (3) in the program.
- Required: the button and icon strings, alert 1 (fallback) and alert 2 (disk trouble), then `0`.
- Menus 1–6 (File, Edit, Search, Type Style, Print, Markers), each block ended by a blank line, then
  `0`. `/X` after an item is its Apple-key equivalent.
- **Item numbers count separator lines (`-`).** The `mi…` constants in the program must match the
  positions in the phrase file; the Type Style items are the font constants `FModern` … `F18PtPS`.
- `PutUpMenus` rebuilds the bar on every activation; `ReadyMenus` enables/disables items just before
  a menu is pulled; `RefreshMenuState` sets the check marks.

## 15. The dialog bar

Questions and messages use the Window Manager's dialog band (`DialogHeight`, `dialogFolder`).
`DrawTheBox` shows a prompt, `GetReply` reads a line (Return accepts, the default is shown in
brackets, Clear cancels), `Confirm` reads Y/N, `Error`/`Warning` wait for Space. `ReadCh` waits with
`LetOthersRun`, services update events, and gives up on anything else (a click, an Apple key, a filer
event, a deactivation) without removing it from the queue — so a click both cancels a question and
then acts normally, and Filer commands are never held up by an open question.

## 16. The desktop icon

The Filer loads `{T<tool number>}ICON` with `FMAddFont`: the icon file is a **QuickDraw font** with
three 48 × 32 characters:

| Char | Filer name | Use |
|---|---|---|
| 0 | `overlayCode` | drawn over the standard shapes (tools that make documents) |
| 1 | `dataCode` | the icon picture (tools without documents, like this one) |
| 2 | `maskCode` | the mask; the Filer also takes the icon's clickable box from it |

plus a missing-character glyph (a gray pattern). Font header: first char 0, last char 2, glyph
rectangle 48 × 32, ascent 0, descent 32, 12 words per bitmap row; then the 32 × 24-byte strike, the
location table and the offset/width table; padded to 1024 bytes. 1 bits are black.

- **The picture.** `icon2_48x32.png` is the icon at Lisa size, black and white (dark pixels are
  ink). A 48 × 32 icon is square on the screen, because Lisa screen pixels are taller than wide
  (1.5 pixels across per pixel down): square artwork fills the whole box, and anything drawn on a
  modern screen must be made 1.5 times wider to keep its shape.
- `python3 png2lisaicon.py icon2_48x32.png ICON.BIN [mask.png]` builds the icon file; without a
  mask PNG the mask is computed as everything not reachable from the image border through white
  pixels (the outline, filled).
- The Filer reads a tool's icon once and keeps it until the Office System is restarted.

## 17. Checking and verifying changes

- `python3 audit_8char.py` — run after every change to the program (see §3).
- The interfaces of all units used are in the Computer History Museum release of the Lisa sources
  (`LISA_OS/LIBS/…`; the Filer is `APPS/APDM`). Check new library calls there.
- In LisaEm, displayed screenshots are stretched vertically (364 → 500 rows), so one-pixel lines can
  look unevenly thick; there is no printer emulation, so printing can only be tested on hardware.
