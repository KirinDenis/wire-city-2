# STYLE - the house style of code and text

How a WIRE CITY program is written, laid out, named, commented and handed
over. The site asks it of every program made there; the games, lessons
and engine on A: are written this way, so it also makes their code easy
to take.

## Rules a program must not break

- Flat FASM; a .COM (`format binary as 'com'`, `org 100h`); the 8086 set
  in real mode; VGA mode 13h (320x200x256) for pictures; A:\ENGINE\E_8086.INC
  included so no 386 jump slips in (see FASM). An .EXE only when 64K is
  really full (see MEMORY).
- Esc quits to DOS and gives the machine back as it was lent: every hooked
  vector restored (between CLI and STI), the speaker gate closed, text mode
  3 (AX=0003h, INT 10h), INT 21h AX=4C00h. EVERY exit path does it - the
  "file missing" exit too, which prints the name in text mode and ends
  with AX=4C01h.
- A comment beside every arithmetic instruction (see Comments).
- No dates or years in any text - comments, screens, README - and no
  invented history ("the original", "back then"). Say what the code does
  and what limits it; where age matters, name the hardware (8086, CGA).
- One folder per program on A:, 8.3 names in capitals:
  A:\MY\HELI\HELI.ASM. The site's DOS PC builds on A: only.
- Read A:\LESSONS and A:\ENGINE before writing a routine - the games are
  made of them. A from-scratch lesson once re-did the engine's clip,
  rotate and terrain worse than the engine had them.
- Start with a small program that builds and runs, then grow it. Fix the
  lines at fault with an edit; never write the file again (one whole
  rewrite after one FASM error spent a model's whole budget).

## Comments

- Beside every arithmetic instruction (ADD SUB INC DEC NEG, MUL DIV and
  their I-forms, shifts and rotates, AND OR XOR, CMP, a MOV or LEA that
  builds an address) say what the numbers ARE and why this instruction:

      add  al,64              ; +64 = a quarter turn: cos from the sine table
      and  ax,63              ; mod 64: the map is a torus, it wraps
      sar  ax,1               ; /2, rounding DOWN: keeps the divisor < 128

- Code meant to be read (lessons, examples) comments EVERY instruction in
  the C it computes (`; AL = inp(0x60): the byte off the wire`), and puts
  an "In C:" block in each routine's banner, with the code's own names.
- Say WHY, with the measured number and the failure it prevents, beside
  the constant it governs: `VLOFP = 5` explains that the climb is computed
  in whole units and 2 units of pitch truncate to zero climb.
- Keep the scar: where a bug was fixed, say what it looked like and why
  (OWL FLY III's stack guard says the jets tore into giant shards). The
  next reader is about to make the same change.
- Say what is NOT modelled or exact: "no sideslip" (A:\LESSONS\L29\WING.ASM);
  "rounds down where IDIV rounds toward zero - a pixel, sometimes, not a
  bug" (A:\ENGINE\E_M3D.INC ROTXZ).
- A routine's banner is its contract: what comes in (registers, ranges),
  what goes out, what it clobbers or keeps ("preserves BX,DX - MUL
  clobbers DX"). Most register bugs here were a helper clobbering a value
  its caller kept.
- A module header (A:\ENGINE\E_*.INC): what goes wrong without it, what it
  does, how, and its CONTRACT - the symbols the includer defines.
- Scaffolding is marked `*** TEMP ***`; code kept for later sits in
  `if 0` ... `end if`; a generated file names the tool and command that
  made it and says "DO NOT EDIT BY HAND".
- A comment the code has outgrown is a bug: change a number, change every
  comment quoting it (a "vel/16" outlived the code's vel/32).
- Hardware numbers stay in hex: port 3DAh, A000h, scan code 48h, 0AAh.

## Names

- Constants in capitals with `=` (FOCAL); variables lower case (camx);
  routines in capitals in game and engine code (PROJPT), Boot/PutS/Rot2
  in the lessons - one style per program. `.local` labels belong to the
  last plain label.
- Never a FASM word: data directives (db dw dd dp df dq dt du, rb rw rd
  rp rf rq rt), any register of any later CPU (di dh dl rcx spl dr1),
  NEAR, PAUSE (a lesson's Pause became Hold). Longer names never collide.
- Names one letter apart that both assemble get swapped (missiles read the
  turret's mtpy for their own mpy): one prefix per subsystem (trnpy).
- Derive constants and let the assembler check them; never retype a
  literal: `SHKLK = RSLK - NSHILK*2` plus `if` ... `err` guards. A typed
  number outgrows its shelf in silence.
- A routine called from another segment has a far door: `NAMEF: call NAME`
  then `retf`.
- One routine per question ("what does this stand on"): two answers drift
  apart, and the picture and the collision test stop agreeing.

## The layout of a program

This skeleton assembles to 67 bytes, 8086-clean:

    ; ==================================================================
    ;  HELI.ASM - a helicopter over a night city.
    ;      build A:\MY\HELI\HELI.ASM      (the site: FASM, then it runs)
    ;      LEFT/RIGHT turn   DOWN climbs   SPACE fires   ESC to DOS
    ;  THE ONE FACT: the screen is memory - 64000 bytes at A000h.
    ; ==================================================================
    format binary as 'com'
            org  100h               ; DOS loads a .COM at offset 100h
            include '..\..\ENGINE\E_8086.INC'  ; jumps an 8086 can run

    START:  cld                     ; string ops count UP
            mov  ax,0013h           ; AX = 13h: 320x200, 256 colours
            int  10h                ; set_mode(0x13); hook vectors here
    .frame: mov  ah,1               ; a key waiting?  ZF set = no
            int  16h                ;  BIOS keyboard, without waiting
            jz   .frame             ;   no: the next frame
            mov  ah,0               ; take the key, or it waits for ever
            int  16h                ;  AL = ASCII, AH = scan code
            cmp  al,27              ; ESC ?
            jne  .frame             ;   no: the next frame
    QUIT:   mov  ax,0003h           ; (vectors back first) text mode 3
            int  10h                ; set_mode(3)
            mov  ax,4C00h           ; AH = 4Ch exit, AL = 0: all went well
            int  21h                ; exit(0)

    ; ------------------------------------------------------------------
    ;  PLOT - one pixel.  in: BX = x 0..319, AX = y 0..199, DL = colour,
    ;  ES = screen or back buffer.  clobbers AX, DI.
    ;  In C:   buf[y*320 + x] = colour;
    ; ------------------------------------------------------------------
    PLOT:   xchg al,ah              ; AX = y*256: y < 256, AH was 0 - no MUL
            mov  di,ax              ; DI = y*256
            shr  ax,1               ; AX = y*128  (8086: shift by 1 or CL)
            shr  ax,1               ; AX = y*64
            add  di,ax              ; DI = y*320, the row
            add  di,bx              ; DI = y*320 + x, the pixel
            mov  [es:di],dl         ; buf[DI] = colour
            ret

    rseed   dw   1                  ; E_MATH's CONTRACT: LCG state, not 0
            include '..\..\ENGINE\E_MATH.INC'  ; RND16
    hmap    rb   4096               ; not in the file, NOT zero: clear it
    if $ > 0FE00h                   ; the stack falls from FFFEh: leave it
            err                     ;  512 bytes, or it eats the tables
    end if

- Entry at the top (A:\EXAMPLES), or `jmp Boot` over the routines with
  Boot at the bottom (A:\LESSONS). Pick one.
- The header is the manual: what it is, the build line, every key, the
  stages, and the ONE physical fact it rests on (the screen is memory; the
  keyboard sends key numbers, not letters; the prefetch queue still holds
  the old bytes).
- From A:\MY\NAME\ the engine is `'..\..\ENGINE\E_x.INC'`, included after
  your own code; define what its CONTRACT asks (FASM resolves forward).
- Big zero buffers go LAST as `rb`: a trailing `rb 4096` adds nothing to
  the file (`db 4096 dup(0)` adds 4096) but holds old memory - clear it.
- Data the program reads is INI-like text - blank, `; comment`,
  `[SECTION]`, `KEY = VALUE` to the end of the line, nothing quoted or
  nested. Never JSON: this parser is twenty lines.
- When the main 64K runs short, do not shave bytes: move cold code (run
  once at start or once per death) to a far segment (see MEMORY).

## Files

- 8.3 names, capitals, ASCII. Every text file (.ASM .INC .BAT .TXT .CFG
  .INF .INI) ends its lines with CR LF, or DOS editors show one endless
  line; the site's write_file converts. Convert by extension, never over a
  folder: that turned every 0Ah inside an .EXE into 0Dh 0Ah and it hung.
- Batch files are COMMAND.COM batch: no `call :label`, no cmd-style FOR
  (a batch can CALL itself with an argument); paths relative to its folder.

## Programs that teach (the course's way)

- Name the one physical fact first; show it in stages the reader watches.
- Open up each new mnemonic at its first use: what it does, an example,
  the flags and registers it touches, what it is confused with ("IRET
  pops the flags too").
- Take earlier code and say so: include the helpers an earlier lesson
  built (A:\LESSONS\L11\DRAW11.INC carries lesson 8's PutB) instead of
  retyping them; later code practises what earlier code argued for.
- Walk into a trap on purpose and explain it in words:
  A:\LESSONS\L15\PERSP.ASM drives a corner past the near plane, and its
  own INT 0 handler says what happened.
- Prove a fast version by drawing it over the trusted one: trusted in
  grey, fast in white, a red dot where they differ by more than a pixel
  (PERSP.ASM Differ). "Is it right?" becomes counting red dots.
- A helper leaves alone what it was not asked to change: a dot routine
  that left its colour set painted seven of eight rays orange.

## Handing a visitor's game over

What `zip A:\MY\NAME` gives the visitor, and what it must do:

- NAME.ASM (and its .INC parts), the built NAME.COM, and a README.TXT of a
  few lines: what it is, the keys, how to build (on the site
  `build A:\MY\NAME\NAME.ASM`; elsewhere CWSDPMI, then
  `FASM NAME.ASM NAME.COM`). The site's BUILD.BAT, GO.BAT, BUILD.TXT may
  stay.
- It builds from that line with no error, 8086-clean.
- It opens on its own picture: name and keys on the first screen, play on
  a key; surprising controls said there ("DOWN climbs - a control column").
- Same speed at fixed 30000 cycles (what `build` runs it at) and at max
  (the site's DOS prompt): time from the BIOS tick or retrace, never from
  loop counts (see TIME).
- Every key it needs reaches DOS in a browser: nothing on Right Ctrl (the
  page takes it), a digit or letter twin for Tab and F-keys, debug on
  Ctrl+letter, never a bare letter a player hits by accident.
- Menus: numbered rows, a digit picks at once, arrows and Enter; each row
  says what it is ("EGA 640x350 16 COLORS"); what the machine lacks is
  listed as such and cannot be picked.
- No silent wait: a missing optional file switches its feature off and
  play goes on; nothing waits for a key the screen has not asked for.
- Before handing over: build, run, look with `screen`, play with `keys`
  (hold game keys 300 ms: `Up*300`), press Esc and see a clean prompt.
