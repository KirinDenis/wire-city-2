# INPUT - the keyboard and the mouse: INT 16h, INT 9, latches, the browser

How a DOS game reads its player: the BIOS for menus, its own INT 9 and a
key table for play, a latch so no tap is lost at a low frame rate, the
mouse, and what a browser does to keys. Working code:
A:\GAMES\OWLFLY3\SRC\KEYB.INC (KBINT), OWLFLY3.ASM (install, the tap
rescue in GAMELOOP), A:\LESSONS\L11\KEYS.ASM (port, BIOS, DOS, INT 9).

## Rules you must not break

- Restore every vector you hooked on EVERY exit path: the quit, the "file
  missing" exit, a fatal-error handler. A vector left pointing into freed
  memory crashes whatever DOS loads there next.
- End your INT 9 with the EOI, `mov al,20h / out 20h,al`, or IRQ 1 never
  rings again: the keyboard is dead until reset.
- In a handler DS is not yours (it fires in the middle of someone else's
  code): push DS and load it from CS, or address with `cs:`. Save every
  register you touch.
- Swap a vector whole: INT 21h AX=3509h (get, into ES:BX) and AX=2509h
  (set, from DS:DX), or write 0000:0024 between CLI and STI. Half a vector
  is a jump into nowhere. Keep it as `old9 dd 0`: FASM takes `lds dx,[old9]`
  only from a dword (else `lds dx,dword [old9]`).
- Never lose a tap: at 1 fps a key pressed and released between two
  frames never shows in a held-key table. Latch it in the handler. A
  "PRESS SPACE" that reads only the live table reads as "the keys are
  broken" at the worst moment.
- Give every action a key the site delivers: digits and letters always
  arrive (see Keys a browser swallows).

## Three floors

- The keyboard sends scan codes (set 1), not letters: W down = 11h, W up
  = 91h (+80h, the break). Port 60h holds the LAST byte; it is no queue.
- BIOS INT 16h: AH=1 asks without waiting (ZF=1: nothing), AH=0 waits;
  both return AH = scan code, AL = ASCII. An extended key gives AL = 0 (E0h
  on some BIOSes: accept both), ESC is AL = 27. When AH=1 says a key is
  there, take it with AH=0 or it stays for ever. Right for menus, prompts
  and step-by-step programs (and a feeder that writes the BIOS buffer can
  drive them).
- The BIOS buffer keeps 15 keys (16 words at 0040:001E; head 001A, tail
  001C). Keys typed during an animation all arrive when it ends, and steps
  skip "in the same place every run". Flush before every wait:

```
Flush:  mov  ah,1
        int  16h                ; ZF = empty
        jz   .done
        mov  ah,0
        int  16h                ; take it
        jmp  Flush
.done:  ret
```

- DOS INT 21h AH=0Ah: a whole edited line (buffer `db max, count, text`,
  the count without the CR). Most features, slowest; in a browser a loop
  blocked in it was deaf (below). AH=08h: one key, no echo.
- Polling port 60h does not stop the BIOS INT 9: it queues the same keys,
  so flush afterwards.

## The game's own INT 9

- A game asks "what is held NOW" - two arrows held is a diagonal - and no
  floor above the wire answers that:

```
KBINT:  push ax
        push bx
        push ds
        mov  ax,cs
        mov  ds,ax
        in   al,60h             ; the scan code
        mov  bl,al
        and  bx,7Fh             ; the key; BH cleared too
        test al,80h
        jnz  .up
        mov  byte [KEYS+bx],1   ; held
        mov  byte [KHIT+bx],1   ; latched: only its consumer clears it
        jmp  .eoi
.up:    mov  byte [KEYS+bx],0
.eoi:   mov  al,20h
        out  20h,al             ; EOI
        pop  ds
        pop  bx
        pop  ax
        iret
KEYS    db 128 dup(0)
KHIT    db 128 dup(0)
```

- It does not chain, so INT 16h hears nothing while it is in: run every
  BIOS-read menu (card, detail, sound) first, then hook. To chain (typing
  a name in play), `pushf / call dword [old9]` (old9 dd the saved vector)
  and let the old handler send the EOI, not you.
- E0-prefixed keys: this handler ignores the prefix (E0 has bit 7 set and
  just clears KEYS[60h]), so grey arrows share the keypad arrows' cells
  and Right Ctrl is 1Dh; keypad 8 is Up whatever NumLock says. With
  NumLock on, a real keyboard wraps grey keys in a fake Shift (E0 2A ...
  E0 AA): if Shift matters, ignore a 2Ah/AAh that follows an E0.
- Real PC/XT iron: its BIOS also pulses port 61h bit 7 after reading 60h,
  which frees the keyboard interface for the next byte. These handlers do
  not, and DOSBox does not need it; for an XT keep the scan code aside and
  add `in al,61h` / `or al,80h` / `out 61h,al` / `and al,7Fh` /
  `out 61h,al` (harmless on an AT).
- Before the hook DOS still sees the keys: Ctrl+C or Ctrl+Break can end
  the program through INT 23h past your exit path. Hook other vectors
  after the menus, or point INT 23h at your own exit.

## Scan codes

- Esc 01h, 1..9 0 = 02h..0Bh, - 0Ch, = 0Dh, Backspace 0Eh, Tab 0Fh,
  Q W E R T Y 10h..15h, Enter 1Ch, Ctrl 1Dh, A S D F 1Eh..21h, L 26h,
  LShift 2Ah, Z X C V 2Ch..2Fh, N 31h, M 32h, RShift 36h, Alt 38h, Space
  39h, F1..F10 3Bh..44h, F11 57h, F12 58h; keypad - 4Ah, + 4Eh.
- Arrows: Up 48h, Left 4Bh, Right 4Dh, Down 50h. PgUp is 49h and PgDn
  51h - a lesson once called the arrows PgUp/PgDn throughout; check codes
  against the source. Home 47h, End 4Fh, Ins 52h, Del 53h.

## The latch: taps between frames

- KEYS says what is held now; KHIT is set on every make and cleared only
  by the code that acts on it. Switches, toggles, menus, prompts and
  "press Space" read KHIT; held controls (stick, throttle, modifiers) read
  KEYS. Comparing KEYS with last frame's works at 50 fps and fails at 1.
- Clear a screen's latches when it is entered: the last screen's Enter
  still sits in KHIT and acts on the new one. Hence no "press any key to
  skip" right after a screen left with Enter: name the key, clear it first.
- Typematic repeat re-arms KHIT for as long as a key is held, so a toggle
  read from KHIT alone fires again while held (a synthetic 0 held 350 ms
  seated AND unseated the gunner). Act on a latch only if the key was not
  held at the previous look; consume it either way.
- Held keys at low fps, the tap rescue (OWLFLY3.ASM `.tg`): just before a
  physics burst, for each flight key take KHIT (clearing it) and grant a
  one-tick `tap` only if the key is not held now AND was not held at the
  last frame's look (`pvk`). The step reads `KEYS OR tap`; the taps are
  cleared after the FIRST step (TapClr). One tick per tap, never none and
  never six; a tap in a frame with no step stays latched. Rescued (TAPSC):
  48h 50h 4Bh 4Dh, 11h W, 1Fh S, 39h Space.
- Without the not-held test every release left a phantom tick (the
  typematic echo) that kept the stick ramp from resetting: "smoothness
  broken, worst in yaw". Without any rescue, lost taps plus six-step
  catch-up bursts felt like "input lag, could not hold level flight".
- Very slow frames (an XT at 0.7 s): keep HOW LONG each flight key was
  held. INT 9 stamps the tick on make and adds the held ticks on break; at
  the burst turn held time into a share of the steps (held*n/elapsed, at
  least one) and hold the key down in KEYS for exactly those steps. Do the
  read and write of KEYS under CLI, or an INT 9 between them is
  overwritten. Replay only flight keys: a switch acts once, on its latch.

## Where to read keys

- View keys (cameras, zoom, map, palette) once per FRAME, so they work
  while paused; world keys (fire, lock, throttle, switches) in the physics
  step. Keep the old gates when moving them: a camera key read per frame
  without its "not spectating" gate fought the spectator camera one flip a
  frame - a violent shake.
- A chord's modifier suppresses the plain meaning: Ctrl+arrow looks, so the
  arrow must not also roll. When the modifier is released clear the
  arrows' edge memory, or the next chord swallows an edge.
- Debug switches on a chord (Ctrl+D), never a bare letter: players find
  bare letters by accident. At low fps hold the modifier and tap once.
- Check what is taken before binding. The site's house rule: Esc quits to
  DOS and restores text mode 3. A long game may make Esc pause and quit on
  a chord (OWL FLY: Alt+Q), so a reflex never ends a sortie.
- Flight convention: the pitch keys work like a yoke, Down climbs. Say so
  in the help.

## Keys a browser swallows

- Right Ctrl never reaches DOS on the site or the course page: it is the
  host key that hands the keyboard back to the page. F9 and Ctrl+F9 are
  the pages' build and run, taken even while DOS has the keys. The browser
  keeps F11 and its own Ctrl+W, Ctrl+T, Ctrl+N: bind none of them.
- In js-dos tests injected Tab, Esc and F8 never reached the game while
  digits, letters, Enter, Space, the arrows, F2 and F7 did (a physical
  keyboard was not checked). Give every vital action a digit or letter
  door too: OWL FLY's seat change answers Tab, F8 and 0.
- DOS has the keys only with the focus: a click on the picture gives them
  back; while a menu or dialog is over it DOS gets nothing, and keys typed
  elsewhere on the page do not reach it. A key pressed while DOS had the
  focus still gets its key-up: nothing stays held.
- A loop that never yields is deaf in the browser: a tight INT 16h poll
  or INT 21h AH=0Ah missed real keystrokes. One main loop that yields each
  pass (INT 2Fh AX=1680h) and polls INT 16h AH=1; a prompt is a state of
  that loop, not a loop of its own (A:\EXAMPLES\BBS.ASM).
- Never wait silently for a key: a visitor whose keys are elsewhere sees a
  hang. Say on screen what is awaited.
- Phones: js-dos's own touch buttons show one letter and cut the stick
  into eight equal sectors; the site builds its touch layer in the page.

## Keys from a test or an agent

- `ci.sendKeyEvent(code, down)` takes GLFW codes: Esc 256, Enter 257, Tab
  258, Backspace 259, Right 262, Left 263, Down 264, Up 265, F1..F12
  290..301, Shift 340, Ctrl 341, Alt 342, letters upper-case ASCII, Space
  32. The site's `keys` tool holds a key 120 ms unless told (`Up*800`).
- A game reading its table once a frame misses a short press at low fps
  (at `auto` OWL FLY III ran at a frame a second): hold level keys 300 ms or
  more, tap toggles ~150 ms. An INT 16h reader may get several keystrokes
  from a 100 ms+ hold; ~50 ms gives one.
- Count scripted keys exactly: one Esc too many fell through to the DOS
  prompt and every later command failed.

## The mouse

- INT 33h AX=0: AX = FFFFh if a driver is there (BX = buttons). AX=3:
  BX = buttons (bit 0 left), CX = x, DX = y. AX=4 places the cursor,
  AX=7/8 set the x and y ranges.
- In mode 13h the driver counts x in 640 columns: shift x right by one.
- A click shorter than one poll is lost when only the button state (AX=3)
  is read; functions 5 and 6 return press and release COUNTS since the
  last call (BX = which button) and keep it.
- The driver draws no cursor in VESA modes: draw your own, save what is
  under it, put it back. With the driver's own cursor, hide it (AX=2)
  before copying a back buffer to the screen and show it (AX=1) after.
- Give every mouse screen a keyboard path (arrows move the same cursor,
  Enter or Space clicks): in a browser the emulator may not have the
  mouse yet.
- Hit-test from the topmost thing down: first a thing with an opaque pixel
  within 3 px of the click, then one whose rectangle holds the point (the
  clear middle of a glass ashtray is still the ashtray).
