# MEMORY - .COM and .EXE, segments, buffers, what DOS gives you

Where a DOS game's code, data, stack and buffers live: the one 64K segment
that is scarce, the far segments and pages above it, how much memory the
program really owns, and the layouts that broke. FASM syntax for segments
and far calls: FASM.

## The rules you must not break

- You own one block: from your PSP to the paragraph DOS writes at PSP:[2].
  Past it lies video memory (A000h) or another program. OWL FLY III hangs
  its pages off CS without asking; started above a resident shell it wrote
  into A000h - a striped band crawling down the screen, a hang, js-dos
  dying with "unreachable". Ask before you take
  (A:\GAMES\OWLFLY3B\SRC\OWLFLY3B.ASM does):

```
        mov  bx,[es:2]          ; ES = the PSP at entry: before ES moves
        mov  ax,cs
        add  ax,TOP             ; paragraphs used above CS
        jc   .nomem             ; wrapped past 1 MB
        cmp  ax,bx
        ja   .nomem             ; DOS gave less: say so, exit 1
```

- A new or bigger far segment moves everything above it. Pages placed by
  hand at CS+n (back buffer, resource image) must move with it, and all
  that is stacked on them. Missed, it shows as the ground mirrored at the
  top of the cockpit: the moved buffer overlapped the image the panel is
  blitted from - it looks like a deliberate reflection, which is why it
  gets missed. Move every constant above it in one edit, check
  `resseg >= bufseg + 0FA0h`, walk the whole map, and record each move in a
  comment at the constant.
- The stack falls into your data: SP starts at FFFEh and grows down into
  BSS. Make the build refuse to get close (see The main 64K).
- Give back every interrupt vector you took, on every exit path: DOS reuses
  your memory, and the next interrupt jumps into whatever loads there.

## .COM or .EXE

- A .COM is one segment: CS = DS = ES = SS = the PSP, IP = 100h, SP =
  FFFEh. Code, data, BSS and stack share 64K, and the file can be at most
  65280 bytes. It is the house default: A:\EXAMPLES run from under 1 KB to
  16 KB, the biggest lesson (HOUSES.COM) is 49547 bytes.
- Take an MZ .EXE when code and data outgrow 64K (OWL FLY III BOND, for a
  512K 8088: about 98K of code and data plus 20K of BSS and stack). The
  loader sets DS = ES = the PSP and SS:SP from the header, so rebuild the
  COM world first:

```
        mov  ax,cs
        cli                     ; SS first: no stack until it lands
        mov  ss,ax
        mov  sp,0FFFEh
        sti
        mov  ds,ax
        mov  es,ax
```

- EXE size is free; only the main 64K is scarce. Open another far segment
  rather than shave bytes.
- FASM's MZ asks DOS for all free memory (`heap` defaults to 65535
  paragraphs; `heap 0` asks for the image only) and makes a 4096-byte stack
  when there is no `stack` directive.
- Make the main segment the LAST one in the file: reserved bytes at the end
  of the output are not stored, so its BSS and stack cost no file (with
  dead code cut, the BOND went from 128K to about 55K). That tail, like a
  .COM's, arrives as garbage, not zeros: clear it at start (`rep stosw`).
- In a .COM, BSS may be label arithmetic past the image - the COM owns its
  segment. In an EXE claim it with real reserved bytes (`db 22695 dup(?)`),
  or the next segment is laid on top of it.
- Fixed addresses work too: STORY.COM puts its tables at 4000h..F5FFh of
  its own segment (stack F600h..FFFEh) and refuses to assemble when the
  code passes them (`if $ > SECTTAB`): a table in the file is a byte of
  file and a byte less for the stack.

## Segments and far calls

- Physical address = segment*16 + offset. A paragraph is 16 bytes, 64K is
  1000h paragraphs, 64000 bytes 0FA0h, the 640K line A000h. The next 64K
  boundary at or above X is `(X + 0FFFh) and 0F000h`. Check the carry of a
  paragraph add: past FFFFh it wraps.
- A far routine is a door, `NAMEF: call NAME` / `retf`: its own segment
  calls NAME near, everyone else `call SEG:NAMEF` (5 bytes). A near call
  cannot cross a segment.
- Far code is entered with DS = the main segment. Its own variables need
  `cs:`; a value two far segments share is parked in a main-segment word;
  home is reached through far thunks (SINQF, ROTXZF...).
- A routine that reads its tables through DS (SINQ, MODELDRAW) works only
  while DS = the main segment: switch DS to a data page only around the
  actual stamping. Model geometry read through DS costs main-segment bytes;
  boxes drawn from eight parameter words cost none.
- Far segments keep inline copies of small near helpers (a far call home
  costs too much). Overriding the near routine then fixes its callers and
  misses the copies: change the DATA every copy reads.
- Self-modifying code writes through DS: fine where DS = CS (a .COM, an
  EXE that sets DS = CS); inside a far segment patch through `cs:`.
- Each window ends with a guard and claims its whole size, so the next
  segment lands exactly where the code assumes:

```
label SYMBASE byte              ; first line of the segment
        ...
if ($-SYMBASE) > 8176           ; an 8K window: 1FF0h + 16
        display 'SYMSEG overflows its 8K window',13,10
        err
end if
        rb 1FF0h - $
        db 16 dup(0)
```

- When a window is full, move the new code to a segment with room. Widening
  the window moves everything stacked above it.

## The main 64K

- It holds code, data, BSS and stack together, and every far call site
  costs 5 bytes of it. When it is full, evict the COLDEST code - what runs
  once at start-up or once per death: a minimap bake moved out gave back
  116 bytes, a respawn routine about 150.
- Stack guard: refuse to assemble when `(BSSEND-START) > 0FDEEh`. That
  leaves 512 bytes of fall below FFFEh; typical depth is under 300. Without
  it BSS crept up and SP shredded the model tables: jets drawn as giant
  shards, or a grey-screen hang.
- Claim the segment to the top (`rb 0FFF0h - $` / `db 14 dup(?)`) so the
  first far segment starts at CS+1000h.
- Measure what is left: a zero-cost `label XEND byte` at the end of each
  window, read from FASM's `-s` symbols, or a `display` ladder (FASM).

## Where buffers go

- The back buffer is 64000 bytes = 0FA0h paragraphs. A .COM puts it in the
  64K above itself, `bufseg = CS + 1000h` (A:\EXAMPLES\JET.ASM); an EXE puts
  it past its last far segment. Draw with ES = bufseg, then copy 32000
  words to A000h.
- Drawing straight to the screen, ES = A000h and a 16-bit DI make every
  stray write land in video memory, never in the code.
- One DOS read (AH=3Fh) fills one segment at most - the games ask for
  CX = 0FFF0h - so a resource file read that way stays under 64K. The
  64000-byte cockpit filled most of one, so the side views got a file and
  a page of their own.
- A DMA buffer must not cross a 64K physical page (the 8237 counts 16 bits
  and latches the page apart): put the ring in a 64K-aligned segment,
  `(CS + 4FFFh) and 0F000h`, or take twice the size and use a straight
  stretch of it.
- New data pages go ON TOP, past the last page, where nothing is stacked on
  them. Compute them from DS at run time; hand-typed paragraph constants
  went stale twice.
- Spare room in a page beats a new page: put new data in page tails, cap
  every loader's read at the next shelf's offset, refuse a file bigger than
  its shelf (at bake time too).
- Optional files fail soft: check a magic word after the load (`'CP'` reads
  as 5043h) and on any failure leave the page 0 and the feature off. Only
  an essential file is fatal: restore the vectors, say why, exit 1.

## Worked example: OWL FLY III's map

```
CS+0000h   CODE: code, data, BSS, stack at FFFEh            64K
CS+1000h   SKYSEG 8K   CS+1200h UISEG 16K   CS+1600h SYMSEG 8K
CS+1800h   TOWNSEG 8K  CS+1A00h VIDSEG 24K (the last segment)
CS+2000h   bufseg, the back buffer (to CS+2FA0h)
CS+3000h   resseg, CITY.DAT (ends CS+3FB1h: this shelf is full)
(CS+4FFFh) and 0F000h   sndseg, the sound ring
(CS+5FFFh) and 0F000h   scrseg: minimaps, retro bake; +1000h side
           views, +2000h effects bank, +3000h cabin (the last 64K)
```

The buffer pair moved 200h five times: opening SYMSEG, TOWNSEG and VIDSEG,
and VIDSEG growing to 16K and to 24K. The map fits only with CS at or below
1000h, loaded low (A:\GAMES\OWLFLY3\SRC\OWLFLY3.ASM, the note at resseg).

## Loading low, DOS memory, EXEC

- A program that takes memory above itself without asking DOS must start
  with nothing resident ("loaded low"). The site starts games from its
  start-up lines, and its file manager runs with /STEP: it exits, a batch
  loop runs the program, then restarts it.
- The DOS way instead: shrink your block, then allocate.

```
        mov  bx,1000h           ; keep 64K: a .COM's segment (ES = PSP)
        mov  ah,4Ah             ; resize the block at ES
        int  21h
        mov  bx,0FA0h           ; 64000 bytes, in paragraphs
        mov  ah,48h             ; allocate: AX = its segment
        int  21h
        jc   .nomem             ; BX = the largest block there is
        mov  [bufseg],ax
```

- EXEC (INT 21h AX=4B00h) hands the child every free paragraph: shrink
  before it, and allocate before it whatever you will need afterwards; a
  block asked for later fails (a resident's clipboard did, silently).
- DPMI programs (FASM under CWSDPMI) need XMS and memsize 16 MB or more:
  with xms=false CWSDPMI takes its memory from the 640K and the program
  fails to load with DOS error 8.
- The vector table is 0000:0000, four bytes a vector (offset, then
  segment). Swap one with INT 21h AH=35h/25h, or write both words between
  CLI and STI: an interrupt that finds half a vector jumps into nowhere.

## Stacks

- An interrupt handler runs on whatever stack it lands on and starts with
  the interrupted code's DS: set DS from CS (or use `cs:`), save every
  register it touches, and keep the guard's headroom for it.
- To survive a fault inside a drawing call, save SP before the call; the
  INT 0 handler reloads DS and SP, counts the fault, STI, RET - back into
  the caller with one edge lost (A:\EXAMPLES\RELIEF.ASM TRAP0).
- Word MUL and DIV clobber DX, the games' row helpers (ROW320, UROW) BX
  and CX: push a live value across a call, pop it on every exit path.

## Past 1 MB (386 programs only)

- Plain DOSBox and js-dos grant unreal mode: A20 on (INT 15h AX=2401h),
  LGDT, two instructions in protected mode to load FS with a 4 GB limit,
  back to real mode; then `[fs:edi]` reaches all memory. Prove it (write
  5Ah, read it back) first (LAB\OWLFLY4\VIDEO\OWV.INC, repository only).
- Make only FS flat: DOS and the BIOS never touch FS. A flat ES drew the
  right picture while BIOS interrupts flooded DOSBox's log, 12 s a frame.
  Reload FS after anything that may touch it, never before LGDT has run.
- DOS reads files only into conventional memory: read 4 KB at a time into a
  low buffer and copy it up through FS. With no memory manager loaded the
  engine takes memory outright (its sprites at 400000h).
