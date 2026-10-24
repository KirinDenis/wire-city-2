KIT - proven blocks for making a DOS game here
=============================================

The games, lessons and examples on this disk were built from the same few
hundred pieces of 8086 assembly. The kit is those pieces, cut out, given a
clean contract and tested, so a new game is glued from blocks instead of
written from nothing. START FROM A TEMPLATE (KIT\T_*), never from an empty
file, and keep its loop, its back buffer and its way out. Read
CATALOG.TXT first: one line a file. Open a file only for the block you
use, and in a LIB file only its header.

WHAT IS WHERE
  KIT\CATALOG.TXT    one line a file: what it is for, and the names of its blocks
  KIT\CATFULL.TXT    one line a block: name, file, what it does
  KIT\LIB\K_*.INC    the library: include it, call it, never read its body
  KIT\REC\*.ASM      recipes: a piece of a game to copy and adapt
  KIT\ART\*.TXT      how to draw things by rule (trees, water, walls...)
  KIT\T_*\T_*.ASM    templates: whole small games that build and run -
                     copy one to A:\MY\NAME\ and grow it
  KIT\TEST\*.ASM     one small program per LIB file, proving it builds and works

THE HOUSE RULES EVERY BLOCK KEEPS
  - 8086 real mode, flat FASM, a .COM: org 100h, DS = CS = SS.
  - A program includes ..\..\ENGINE\E_8086.INC right after org 100h (FASM
    would emit 386 long jumps otherwise), and the KIT files it needs AFTER
    its own way out - they are code and data, the CPU must never run into
    them:
        org  100h
        include '..\..\ENGINE\E_8086.INC'
        ... the program, its main loop, its way out ...
        include '..\..\KIT\LIB\K_VGA.INC'
    These paths work from any A:\FOLDER\SUB\PROG.ASM - the kit's own tests
    and templates sit two levels deep for that reason.
  - Every routine KEEPS EVERY REGISTER except those its header lists under
    "out:". Flags are not kept unless the header says so. ES too is kept.
  - Drawing routines draw into the segment in ES, 320 bytes a row (mode
    13h layout), unless the header says otherwise. The program decides
    whether ES is the back buffer or the screen (A000h).
  - Names: a LIB file's routines are CAPITALS with the file's prefix
    (VGA_SHOW, KEY_HELD); its variables are small letters with the same
    prefix (vga_buf). A program never names its own things with a kit
    prefix. Inside a routine, local labels start with a dot.
  - Each routine sits inside  if used NAME ... end if  so a program only
    pays bytes for what it calls.
  - Nothing ever divides by what can be 0 or overflow (a divide fault in
    DOSBox loops for ever). Esc quits and restores text mode 3, every
    interrupt vector taken is given back, on every way out.
  - Time by the BIOS tick (0040:006Ch, 18.2 a second), never by CPU speed.
  - Sound is never required: with no card a block stays silent, it never
    stops the game.

A BLOCK'S HEADER (the catalog is made from the ;@ lines)
  ; ----------------------------------------------------------------------
  ;@ VGA_SHOW   copy the back buffer to the screen after the retrace
  ;  in:  [vga_buf] = the back buffer's segment
  ;  out: -
  ;  needs: K_VGA's VGA_ON first
  ;  from: EXAMPLES\RELIEF.ASM:1624-1657 (proven there)
  ; ----------------------------------------------------------------------
  The ;@ line is: name, then what it does in one line. Everything a
  caller must know is in the header; the body is nobody's business.

BUILDING
  On the site:  build A:\MY\GAME\GAME.ASM
  In DOS here:  cd KIT  then  MAKE TEST T_VGA   (assembles TEST\T_VGA.ASM)
  From Windows: KIT\MAKEWIN.BAT TEST T_VGA      (DOSBox, closes itself)
  FASM's words land in the folder as NAME.LOG.
