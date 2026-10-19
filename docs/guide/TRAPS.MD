# TRAPS - what cost hours: symptom -> cause -> fix

Scan it before you build, and again when something "cannot happen":
what you see -> why -> what to do, and where the right code is. A topic
in brackets has the detail.

## Arithmetic

- Hang mid-frame; the js-dos page stops drawing -> DIV/IDIV faulted
  (divisor 0 OR a quotient too big for AL/AX) and the fault returns to the
  divide, for ever -> never divide by what can be 0 or small: shift, a
  reciprocal table (A:\LESSONS\L15\RECIP.INC), clamp first; an own INT 0
  that ends or longjmps, never IRETs (A:\LESSONS\L15\PERSP.ASM Trap,
  A:\EXAMPLES\RELIEF.ASM TRAP0).
- Freezes only at top speed -> `vel*sin/32` passed 32767 at vel 4096 ->
  shift first: `(vel>>5)*sin/256` has 8x the headroom; clamp at the door.
- Far points flip sides, a cube folds -> byte IMUL/IDIV operands are
  SIGNED: a depth of 163 is -93, and `db 270/2` (135) is -121 once a
  constant grows -> byte operands in -128..127, else CBW and word ops.
- Steering reverses past some speed -> IMUL never traps; an overflowed
  low word just has the wrong sign (18*vel past 1820) -> clamp the input.
- A value kept in DX comes back 0 or -1 -> MUL/IMUL/DIV/IDIV write DX:AX
  -> keep it in BX, SI, DI, BP or on the stack.
- `jns` after `mov ax,di` misfires -> MOV sets no flags -> `or ax,ax`.
- Garbage, no fault -> the /256 by middle bytes (`mov al,ah`/`mov ah,dl`)
  drops DH silently, and rounds down -> clamp first; a negative may come
  out 1 low.
- A wait ends at once or never -> `now - start` tested unsigned (`jb`)
  while it can be negative, or the tick word wrapped -> test the signed
  difference (`jl`) against the interval.
- "Nearest" picks a far object -> differences of coordinates up to 49152
  wrap in 16 bits -> shift both right 4 before subtracting.
- A turned square shears -> y' used the NEW x -> keep the old x aside.
- Every island alike, or repeating every 8 -> LCG low bits cycle fast
  (bit k every 2^(k+1)), and 4096 draws a map divide the 65536 period ->
  use the HIGH byte; an odd number of draws per map
  (A:\ENGINE\E_TERR.INC DSGEN).
- A small force never acts; 2 units of pitch climb 0 -> truncation -> a
  fraction byte carried with ADC (A:\LESSONS\L24\FORCES.ASM velf), or 8.8.
- An immortal enemy, armour 255 -> a byte counted past 0 wrapped -> `dec`
  and branch on that very result (`jg alive`).

## Jumps and FASM

- Runs on every emulator, dies on a real 8086 -> FASM silently emits the
  386 long Jcc `0F 8x` -> include `..\..\ENGINE\E_8086.INC` after
  `org 100h`. A byte scan for 0F 8x proves nothing (data matches it).
- "relative jump out of range" on LOOP or JCXZ -> no long form exists ->
  `dec cx`/`jnz` (E_8086 expands them as well).
- "reserved word used as symbol" -> a name like rb rw dt dh dr1 rcx spl,
  NEAR, PAUSE -> a longer name [STYLE].
- One constant, two values -> `=` may be redefined, and each line sees the
  last one above it -> define once; grep before adding.
- Patched code runs its old bytes -> the prefetch queue -> patch, then
  JMP; the placeholder must assemble to the size you patch (`add di,320`
  is imm16, `add di,1` is a byte) (A:\ENGINE\E_RAST.INC LINE).
- (MZ) FASM stops at a segment line, or segments slide down -> `entry`
  must precede its `segment`; `org` in a segment emits nothing (use
  `rb X-$`); `call far ptr X` is INDIRECT, write `call SEG:X` [FASM].

## Memory and segments

- A striped band crawls down the screen, then a crash (js-dos:
  "unreachable"), only when run from a shell -> buffers at CS+n taken
  without asking DOS ran into A000h -> check the top of memory at PSP:[2]
  and refuse, or INT 21h AH=4Ah/48h [MEMORY].
- Tables hold garbage at start -> trailing `rb` and an EXE's BSS are not
  stored and not zeroed -> clear them with `rep stosw`.
- Geometry tears into shards, or a grey hang -> the stack (from FFFEh) ran
  into the data -> guard: `if $ > 0FE00h` / `err` / `end if` (512 bytes).
- Keyboard dead, or the next program crashes -> INT 9 without EOI
  (`mov al,20h`/`out 20h,al`), or a vector not given back -> EOI every
  interrupt; restore every vector on every exit path.
- A handler corrupts memory -> its DS is the interrupted code's -> `cs:`,
  or push DS and load it from CS; save every register touched.
- Crash at install -> a half-written vector -> CLI/STI around both words,
  or INT 21h AH=25h.
- Specks march across the screen; a parser stops after one item -> a
  helper clobbered BX/SI/CX that its caller kept -> each banner says what
  it keeps; push across calls.
- A wild write 32K away, palette garbage -> a sentinel (0FFFEh) reached
  code that knew only 0FFFFh and used it as an index -> check every
  sentinel at every consumer.
- IDs decode as the wrong kind once a count grows -> a hand-typed base
  -> derive it, assert no overlap at assemble time [STYLE].
- (EXE) Ground mirrored at the top of the cockpit -> a grown far segment
  moved the back buffer over loaded data -> every paragraph computed from
  CS in one place; new pages on top [MEMORY].
- Sound crackles at one spot -> the DMA buffer crosses a 64K physical page
  -> 64K-align its segment, or take twice the room and a straight half.

## Video and drawing

- Retrace wait never ends on Hercules -> no port 3DAh (it reads FFh) ->
  skip the wait there.
- A wait screen or text missing on CGA/EGA/Hercules -> written to A000h or
  by the BIOS after the blit -> everything into the back buffer first.
- Half a picture at low cycles -> wiping and redrawing the visible buffer
  -> a back buffer.
- FPS reads only 70, 35, 23 -> the retrace wait counts whole retraces ->
  measure with the wait off.
- Debug pixels read inverted -> the palette is the program's own (OWL FLY
  III: 8 is white, 15 green) -> a known constant (0A5h) beside each probe.
- 16-colour VGA ignores your colours 8..15 -> they live at DAC 56..63 ->
  write DAC c+48.
- Grey sky in a CGA mode on a VGA -> the VGA takes CGA colours from its
  DAC (and ignores 3D9h) -> no 256-colour DAC writes in retro modes [VIDEO].
- A real Hercules dies at the menu -> it has no mode 3 -> re-enter the
  mode DOS handed over (INT 10h AH=0Fh, then AH=0).
- Blinking cursor, invisible game -> a card the machine lacks -> detect
  (0040:0063, INT 10h AX=1A00h, AH=12h BL=10h) and refuse.
- The world behind you, mirrored above the horizon -> no near-plane clip
  -> clip at z >= NEAR before projecting.
- A frame takes a minute -> unclipped +-4000-px lines -> clip to the
  screen first (A:\ENGINE\E_RAST.INC CLIPLINE).
- Lines swing; one big quad floods the sky -> the +-4000 projection clamp
  moves endpoints -> ground quads cell-sized (256), cull on |dx| and |dz|
  before rotating [RENDER].
- Far cells overdraw near ones -> drawn by rings -> sort by squared
  distance, far to near.
- Lines and faces part when pitching -> two paths with two transforms, or
  an in-place rotate run twice on one face -> one transform for both;
  stash the face before the first pass, restore it for the second.
- A target answers where the beam is not -> two drawers with opposite
  axis signs (north up, north down) -> one sign convention per frame.

## Input

- Taps missed at low frame rates -> press and release fell between two
  polls -> INT 9 also sets a latch KHIT[scan]=1 on make; the consumer
  clears it (A:\GAMES\OWLFLY3\SRC\KEYB.INC).
- Phantom taps; a toggle fires twice -> typematic repeat re-arms the latch
  -> a tap counts only if the key is not held now nor last frame; consume
  the latch either way.
- A new screen acts on the last one's Enter -> stale latch -> clear
  latches on entry; no "press any key" right after Enter.
- "PRESS SPACE" ignored on a slow machine -> it read the held table ->
  read the latch.
- Steps skip after an animation -> keys queued in the BIOS buffer -> flush
  (INT 16h AH=1 until ZF, take each with AH=0) before each wait.
- Menus deaf once the game runs -> your INT 9 starves INT 16h -> run BIOS
  menus before hooking.
- Arrows do nothing -> arrows are 48h 50h 4Bh 4Dh, PgUp/PgDn 49h/51h;
  INT 16h gives AL=0 or E0h with the scan code in AH.
- Looking around also banks the jet -> a modifier must cancel the key's
  old meaning; clear its edge memory on release.
- Quick clicks lost -> INT 33h fn 3 is state only -> read the counts
  (fn 5, 6); in mode 13h mouse x runs 0..639: shift right 1.
- Deaf to real keys in the browser -> a loop that never yields (INT 21h
  AH=0Ah, a tight poll) -> one main loop: INT 2Fh AX=1680h, INT 16h AH=1.

## Timing and game state

- Hang after hooking the timer -> INT 8 hooks and PIT reprogramming hung
  in the emulator -> read the BIOS tick at 0040:006Ch (18.2 Hz).
- Too fast, or a crawl -> paced by loops: `build` runs at fixed 30000
  cycles, the prompt at max, `auto` at ~3000 cycles/ms (one frame a
  second) -> one physics step per tick passed, at most 6 a frame; decay
  and animation by ticks too [TIME].
- A lurch after pause -> catch-up burst -> while paused count 0 ticks but
  keep updating the last tick; gate every clock read from it.
- The craft flies where the camera looked -> a render-only view changed
  the angles AND their sines -> restore both after every render.
- Falls out of the sky on a life's first tick -> state written by a later
  stage still holds the last life's value -> seed it at spawn.
- "Frozen" after respawn -> a camera mode left on -> reset every mode at
  spawn; first ask whether anything on screen still moves.
- A parked plane creeps, hovers, sways -> air effects tapered, not gated
  -> gate on "on the ground"; in a new regime list every force and
  re-check every per-tick constant at low speed.
- Shells pass through a target -> a round steps ~150 units a tick, the
  box was thinner -> boxes wider than one step.
- You fly through what you see, or hit nothing -> drawing and collision
  read different data -> one routine answers both; change the data.
- A stopwatch says minutes -> DOSBox idled after the program -> time it
  inside, with the BIOS tick.

## DOSBox and the browser

- Paused game, or a net pilot gone, when the tab is hidden -> js-dos runs
  on requestAnimationFrame; hidden timers crawl -> never trust timings
  from a hidden page.
- DOS cannot see a file the page wrote -> only floppy mounts are re-read
  -> shared files and builds on A:.
- A saved edit is lost -> same-size rewrites are seen only every ~7.5 s
  and under 256 KB -> change the size, or give it time.
- A deleted file comes back -> the site refuses DOS-side deletions ->
  overwrite or truncate state files instead.
- `RuntimeError: unreachable`, or a black screen with the window alive ->
  a stray write or wild jump; or FASM on core=auto -> hunt the write. On
  the site up to 1 build in 10 dies anyway: build again.
- A key never arrives -> Right Ctrl is the page's host key; synthetic Tab,
  Esc and F8 were lost in one js-dos page while digits got through -> no
  Right Ctrl; a digit twin for vital keys.
- An agent's key does nothing, or skips stages -> a once-a-frame table
  needs a hold (`Up*300`); a BIOS reader may take a long hold as several
  keys; a toggle wants ~150 ms.
- Stuck on a box waiting for a key -> the page had no focus -> no silent
  waits; optional files fail soft.
- A networked game restarts by itself -> the server's new map at :00, :30.
- Every browser player is "pilot 1" -> the IPX node is zero until the
  relay answers -> re-ask INT 7Ah BX=9 until the 6 node bytes are
  non-zero; `sti` after every INT 7Ah [NET].
- IPX send never returns -> wrong ECB map: InUse +8, fragment count +34,
  42 bytes [NET].
- Packets lost -> your own broadcasts echo into your listen ECBs, or a
  buffer is smaller than the biggest packet -> 6 listens; size for it.

## The build

- "Built" but 0 bytes, or yesterday's binary -> a killed DOSBox's lock, a
  lost write -> delete the output first; check errorlevel, existence AND
  size.
- A file shows as one endless line -> LF endings -> CR LF on text files;
  never convert binaries or a whole folder.
- `-c` lines after a batch never run -> a batch from `-c` swallows the
  rest -> the batch closes DOSBox (`MAKE EXIT`); -noautoexec; no `-c`
  ending in `\`.
- A symbol that plainly exists is "undefined" -> an editor truncated the
  file -> compare its length with what you wrote.
