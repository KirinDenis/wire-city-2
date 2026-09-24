; ============================================================================
;  FLY.ASM - Lesson 14. FLIGHT: the physics WIRE CITY actually flies on.
;
;      FASM FLY.ASM FLY.COM
;
;      1  the island from above - lesson 0x11's map, and the mark where
;         you are about to be standing. SPACE takes off
;      2  the flight, and it does not wait for you
;
;  THE SOURCE NOW TRAVELS. Lesson 13 was the first one that assembled
;  nothing of its own; this one is the first that starts as a COPY of the
;  lesson before it and grows. FLY.ASM is CLIP.ASM with the game's flight
;  model added, its five teaching stages taken out, and nothing else
;  disturbed. From here on that is the shape: one program, growing.
;
;  WHAT LESSON 13 LEFT BEHIND. Its stages existed to take the two fences
;  down one at a time and let you look at what they were holding back.
;  They have done that. Both fences are up now and stay up, the way the
;  game has them, and `donear` and `doside` are left standing at 1 so that
;  DRAWEDGE3D reads exactly as it does in CITY.ASM.
;
;  THE PHYSICAL FACT THIS LESSON HANDS OVER:
;
;      AN AEROPLANE DOES NOT WAIT FOR YOU. Up to here, every lesson moved
;      the camera one pace per keypress and drew a picture between them.
;      That is a slide show with arrows. A flight model is the other way
;      round: the world advances on its own, every frame, and the keys
;      only lean on it. Nothing in this file asks "has a key been
;      pressed". It asks "is a key being HELD", which is a different
;      question and needs a different piece of machinery.
;
;  THE FOUR RULES, and all four are copied out of INPUT in
;  GAMES\WIRECITY\CITY.ASM (line 1873). There is no fifth:
;
;      1. IT ALWAYS MOVES FORWARD.  camx += SPEEDV*hsin/256
;                                   camz += SPEEDV*hcos/256
;         Every frame, whatever you do. There is no throttle and no brake
;         in this game, and taking them out is what makes the rest simple.
;
;      2. LEFT AND RIGHT TURN IT.   heading = (heading -+ TURNV) & 255
;         A byte is a whole circle, so the turn cannot overflow and needs
;         no range check - lesson 0x0B's table, still paying.
;
;      3. THE TURN BANKS IT.        roll walks toward -+BANKMAX by BANKSTP
;                                   while you turn, and back to 0 when you
;                                   let go.
;         This is the whole of the "feel". It is four compares and two
;         adds, it models nothing - no lift, no mass, no aerodynamics -
;         and it is completely convincing.
;
;      4. PGUP AND PGDN CLIMB.      camy -+ STEPY, clamped to a floor and
;                                   a ceiling.
;
;  AND THE BANK COSTS NOTHING, which is the part worth stopping on. The
;  engine has been banking the picture since lesson 13 and you have never
;  seen it, because `roll` was zero. PROJPT calls APPLYROLL on every
;  projected point already; SETTRIG has been filling rsin/rcos from `roll`
;  every time it ran. Put a number in `roll` and the whole world tilts.
;  The physics did not add a rotation - it switched one on.
;
;  THE KEYBOARD, and this is the second new piece. INT 16h hands you keys
;  one at a time, out of a buffer, AFTER the operating system has decided
;  what they mean - so it can tell you a key was pressed and cannot tell
;  you it is still down, and it cannot tell you that two are down at once.
;  A flight model needs both. So the program takes INT 9 - the interrupt
;  the keyboard hardware itself raises - reads the scan code off port 60h,
;  and keeps its own table of 128 bytes: 1 while a key is held, 0 when it
;  is let go. KBINT below is copied out of CITY.ASM and is twenty
;  instructions.
;
;  That means the BIOS never sees a key while this program runs, so
;  nothing in here can use INT 16h any more - including the "press
;  anything" wait on the map. And it means the vector has to be given back
;  on the way out, exactly like INT 0. Two borrowed vectors now.
;
;  AND ONE WINDOW IS LEFT IN THAT DOOR, which is REMOTE below. Closing the
;  BIOS off closes it to EVERYBODY, and that includes anything driving the
;  program from outside: a macro, a test script, or the resident that types
;  these lessons while they are being recorded. All of those put their keys
;  in the BIOS buffer, because that is where a keystroke normally lands,
;  and nothing in here would ever read them. So once a frame the program
;  looks, and a code it finds is held in the table for RHOLD frames as
;  though a finger had been on it. With nobody driving, nothing arrives.
;
;  WHAT THE NUMBERS ARE. The game's constants, scaled by four, because its
;  world is built on a 256-unit cell and this lattice on a 1024-unit node:
;
;      game            here          what it is
;      SPEEDV 12       48            forward units per frame
;      STEPY  5        20            climb units per frame
;      camy 24..420    96..1680      the floor and the ceiling
;      TURNV  2        2             angles do not scale
;      BANKMAX 30      30
;      BANKSTP 3       3
;
;  STILL NO HOUSES. The lattice is flat and coloured by the Diamond-Square
;  map, exactly as lesson 13 left it. Houses are the lesson after this
;  one, and the relief the one after that.
;
;  WHAT IS STILL BORROWED FROM THE GAME AND THE ENGINE:
;
;      ENGINE\E_8086.INC   keeps FASM inside the 8086 instruction set
;      ENGINE\E_MATH.INC   RND16, the congruential draw of lesson 0x11
;      ENGINE\E_TERR.INC   DSGEN and HGET - lesson 0x11's island, entire
;      ENGINE\E_M3D.INC    SINQ, SETTRIG, ROTXZ, PROJPT, APPLYROLL, CLAMPAX
;      ENGINE\E_RAST.INC   OUTCODE, CLIPLINE, LINE
;
;  and DRAWEDGE3D, NEARCLIP, CLIPP0, CLIPP1, KBINT and the flight model
;  are copied out of GAMES\WIRECITY\CITY.ASM. Open it and read along.
;
;  Owlos - legacy software modernization - https://owlos.sk
; ============================================================================
format binary as 'com'
        org  100h

        ; .8086 in the TASM source. FASM has no such directive - without
        ; this include it silently uses 386 jumps when a target is out of
        ; range, and the lessons up to here did it by hand.
        include '..\..\ENGINE\E_8086.INC'

FOCAL   = 220                 ; the game's lens: ~72 degrees across
NEARZ   = 40                  ; the game's near clip plane
BIAS    = 8192                ; world->cell bias, keeps the cell shift unsigned
NR      = 10                  ; the lattice reaches ten nodes each way...
NSIDE   = 2*NR+1              ; ...so it is twenty one nodes across
CAMY0   = 900                 ; how high the eye starts over the plane

; ---- the flight model. Every one of these is CITY.ASM's, and the three
;      that measure a DISTANCE are multiplied by four, because the game's
;      world is built on a 256-unit cell and this lattice on a 1024-unit
;      node. The three that measure an ANGLE are not touched: a circle is
;      256 steps here and 256 steps there.
SPEEDV  = 48                  ; forward units a frame. There is no throttle
STEPY   = 20                  ; climb/dive units a frame
CAMYMIN = 96                  ; the floor: never through the ground
CAMYMAX = 1680                ; and the ceiling
TURNV   = 2                   ; heading change a frame, of 256 = a whole turn
BANKMAX = 30                  ; how far it leans into a turn, of 256
BANKSTP = 3                   ; and how fast it gets there - and back

; ---- scan codes. Not ASCII: these are what the keyboard hardware itself
;      sends, and what KBINT stores. A released key arrives as the same
;      number with bit 7 set.
SC_ESC  = 01h
SC_SP   = 39h
SC_F    = 21h
SC_UP   = 48h                 ; PgUp/PgDn on the numeric pad, as the game
SC_DN   = 50h                 ;  uses them - the arrows that climb and dive
SC_LF   = 4Bh
SC_RT   = 4Dh

RHOLD   = 20                  ; how many frames a key fed from outside is
                              ;  held - about a third of a second, and the
                              ;  bank needs ten frames in a row to build,
                              ;  so one frame would show nothing at all

CELLW   = 3                   ; the map view: 3x3 pixels a node
ORGX    = 64
ORGY    = 4

;  In C, the boot is:
;
;      int main(void)
;      {
;          bufseg  = cs + 0x1000;                 /* the 64K above us        */
;          rseed   = bios_tick() | 1;             /* never zero              */
;          dsgen();                               /* the island              */
;          oldi0   = int_vector[0];               /* keep DOS's INT 0 ...    */
;          int_vector[0] = trap0;                 /* ... and take it         */
;          set_mode(0x13);  setpal();  settrig();
;          camx = 32*1024;  camz = 26*1024;  camy = CAMY0;  heading = 0;
;          ...the five stages...
;      }
START:  cld                     ; string ops count UP (STOSW, MOVSW, LODSB)
        mov  ax,cs              ; AX = cs
        add  ax,1000h           ; AX = cs + 1000h  - 64K above us, in
        mov  [bufseg],ax        ; bufseg = AX        paragraphs of 16 bytes

        push es                 ; keep ES
        mov  ax,40h             ; AX = 0040h, the BIOS data segment
        mov  es,ax              ; ES = 0040h
        mov  ax,[es:6Ch]        ; AX = the tick count at 0040:006C - the only
        pop  es                 ;  thing on this machine that differs between
        or   ax,1               ; AX |= 1     two runs. Never zero: a seed of
        mov  [rseed],ax         ; rseed = AX  nought would breed noughts
        call DSGEN              ; dsgen()     - the island, in one call

        xor  ax,ax              ; AX = 0                ---- take INT 0 ----
        mov  es,ax              ; ES = 0: the vector table is at 0000:0000
        mov  ax,[es:0]          ; AX = low word of vector 0  (offset)
        mov  [oldi0],ax         ; oldi0.offset = AX
        mov  ax,[es:2]          ; AX = high word of vector 0 (segment)
        mov  [oldi0+2],ax       ; oldi0.segment = AX
        cli                     ; interrupts off: two words, and an interrupt
        mov  word [es:0],TRAP0  ; vector[0].offset  = TRAP0    between them
        mov  [es:2],cs          ; vector[0].segment = cs       would find
        sti                     ; interrupts on               half a vector

        xor  ax,ax              ; AX = 0                ---- and take INT 9
        mov  es,ax              ; ES = 0: the vector table again
        mov  ax,[es:9*4]        ; AX = low word of vector 9  (offset)
        mov  [oldi9],ax         ; oldi9.offset = AX
        mov  ax,[es:9*4+2]      ; AX = high word of vector 9 (segment)
        mov  [oldi9+2],ax       ; oldi9.segment = AX
        cli                     ; interrupts off - and this one matters more
        mov  word [es:9*4],KBINT    ; vector[9].offset  = KBINT   than INT 0:
        mov  [es:9*4+2],cs          ; vector[9].segment = cs      a keystroke
        sti                     ; interrupts on              lands here now

        mov  ax,0013h           ; AX = 13h: VGA 320x200, 256 colours
        int  10h                ; set_mode(0x13)
        call SETPAL             ; setpal()   - the island's six colours
        call SETTRIG            ; settrig()  - hsin/hcos for heading 0

        mov  word [camx],32*1024    ; camx = node 32
        mov  word [camz],26*1024    ; camz = node 26
        mov  word [camy],CAMY0      ; camy = CAMY0
        mov  word [heading],0       ; heading = 0: looking north

; ---- 1. the island from above, and SPACE to take off ---------------------
;      The wait is on OUR key table, not the BIOS: from the moment INT 9 is
;      taken, INT 16h never hears anything again.
        call MAPVIEW            ; mapview()   - the island from above
        call SHOW               ; show()      - onto the screen
.wsp:   call REMOTE                 ; anything fed from outside?
        cmp  byte [KEYS+SC_SP],0    ; is SPACE held?
        je   .wsp                   ;   no: wait for it
        mov  byte [KEYS+SC_SP],0    ; taken. Cleared by hand, or the flight
        mov  byte [rkey],0          ;  would see the same press again - and
        mov  byte [rhold],0         ;  SPACE does nothing once you are up

; ---- 2. the flight. Both fences up, and they stay up ---------------------
        mov  byte [donear],1    ; donear = 1   \  both fences up, as the
        mov  byte [doside],1    ; doside = 1   /  game has them. Lesson 13
                                ;  took them down in turn; that is done
        call FLY                ; fly()  until escape

;  In C:  int_vector[9] = oldi9;  int_vector[0] = oldi0;  set_mode(3);  exit(0);
QUIT:   xor  ax,ax              ; AX = 0          ---- GIVE INT 9 BACK first:
        mov  es,ax              ; ES = 0          until this runs, every key
        cli                     ; interrupts off  on the machine is still
        mov  ax,[oldi9]         ; AX = oldi9.offset      coming to a routine
        mov  [es:9*4],ax        ; vector[9].offset = AX  that is about to
        mov  ax,[oldi9+2]       ; AX = oldi9.segment     stop existing
        mov  [es:9*4+2],ax      ; vector[9].segment = AX
        sti                     ; interrupts on

        xor  ax,ax              ; AX = 0          GIVE INT 0 BACK. A .COM
        mov  es,ax              ; ES = 0          that keeps a vector pointing
        cli                     ; interrupts off  into memory DOS is about to
        mov  ax,[oldi0]         ; AX = oldi0.offset      hand to the next
        mov  [es:0],ax          ; vector[0].offset = AX  program has not
        mov  ax,[oldi0+2]       ; AX = oldi0.segment     finished: the next
        mov  [es:2],ax          ; vector[0].segment = AX divide fault would
        sti                     ; interrupts on          jump into whatever
                                ;                        loads here next
        mov  ax,0003h           ; AX = 3: text mode back, the state we
        int  10h                ;  borrowed the machine in
        mov  ax,4C00h           ; AH = 4Ch exit, AL = 0 the code
        int  21h                ; exit(0)

; ============================================================================
;  FLY - the flight loop. It draws a frame, moves the aeroplane, and goes
;  round again. It never waits for anything.
;
;  Lesson 13's version of this routine asked the BIOS for a key and drew a
;  picture between presses. Everything below the frame counter is new, and
;  all of it is CITY.ASM's GAMELOOP: settrig, draw, then INPUT.
;
;  SETTRIG AT THE TOP, once, because both the heading and the roll change
;  every frame now and every projected point wants their sines. Which also
;  means the step PHYS takes is computed from the trig of the frame BEFORE
;  its turn - one frame stale, exactly as the game does it, and at two
;  parts in two hundred and fifty six of a turn nobody has ever seen it.
; ============================================================================
;  In C:
;
;      void fly(void)
;      {
;          for (;;) {
;              settrig();                               /* heading AND roll */
;              frame();
;              fpsn++;                                  /* frames this second */
;              int tick = bios_tick();                  /* 0040:006C          */
;              if (tick - fpst >= 18) {                 /* ~one second        */
;                  fpst = tick;  fpsv = fpsn;  fpsn = 0;
;              }
;              phys();                                  /* the four rules     */
;              if (KEYS[SC_F] && !fwas) { fastp ^= 1; }  /* on the way down   */
;              fwas = KEYS[SC_F];
;              if (KEYS[SC_ESC]) return;
;          }
;      }
FLY:    call SETTRIG            ; settrig(): hsin/hcos from heading, and
                                ;  rsin/rcos from roll - the bank, which
                                ;  APPLYROLL has been waiting for
        call FRAME              ; frame()
        inc  word [fpsn]        ; fpsn++      ---- the frame counter ------
        push es                 ; (ES is the buffer; borrow it for a moment)
        mov  ax,40h             ; AX = 0040h, the BIOS data segment
        mov  es,ax              ; ES = 0040h
        mov  ax,[es:6Ch]        ; AX = tick, the timer count at 0040:006C
        pop  es                 ; ES = the buffer again
        mov  bx,ax              ; BX = tick   (kept: fpst may take it)
        sub  ax,[fpst]          ; AX = tick - fpst
        cmp  ax,18              ; a second gone by? (18.2 ticks a second)
        jb   .move              ;   no: on with the flight
        mov  [fpst],bx          ; fpst = tick    - a new second starts
        mov  ax,[fpsn]          ; AX = fpsn
        mov  [fpsv],ax          ; fpsv = fpsn    - the number the HUD shows
        mov  word [fpsn],0      ; fpsn = 0

.move:  call REMOTE             ; remote(): anything fed from outside
        call PHYS               ; phys(): the four rules, once a frame

        ; ---- F flips the engine, ON THE WAY DOWN --------------------------
        ; A held key is 1 for as long as it is held, so the flip has to
        ; happen on the change and not on the state, or one press would
        ; flip it sixty times and land wherever it liked.
        cmp  byte [KEYS+SC_F],0 ; is F held?
        je   .fup               ;   no: remember that
        cmp  byte [fwas],0      ; was it held last frame too?
        jne  .esc               ;   yes: nothing to do, it is one press
        xor  byte [fastp],1     ; fastp ^= 1   THE SWITCH. One byte, read by
        mov  byte [fwas],1      ; fwas = 1      ROTXZ and LINE in ENGINE\
        jmp  .esc               ; on to the escape test
.fup:   mov  byte [fwas],0      ; fwas = 0: F is up, the next press counts

.esc:   cmp  byte [KEYS+SC_ESC],0   ; is ESC held?
        je   FLY                    ;   no: another frame
        ret                         ;   yes: land

; ============================================================================
;  PHYS - the flight model. Four rules, out of INPUT in CITY.ASM line 1873.
;
;  It is called once a frame and it is the only thing in the program that
;  moves the camera. Notice what is NOT in it: no speed variable, no
;  acceleration, no mass, no lift, no drag. The aeroplane is a point that
;  travels at a fixed rate along the way it is pointing, and the bank is a
;  number that chases another number. That is the entire model, and in the
;  air it is convincing.
; ============================================================================
;  In C:
;
;      void phys(void)
;      {
;          int turn = 0;
;          if (KEYS[SC_LF]) { heading = (heading - TURNV) & 255;  turn = -1; }
;          if (KEYS[SC_RT]) { heading = (heading + TURNV) & 255;  turn = +1; }
;
;          if (turn < 0)       roll = max(roll - BANKSTP, -BANKMAX);
;          else if (turn > 0)  roll = min(roll + BANKSTP,  BANKMAX);
;          else if (roll < 0)  roll = min(roll + BANKSTP, 0);   /* back level */
;          else if (roll > 0)  roll = max(roll - BANKSTP, 0);
;
;          if (KEYS[SC_UP]) camy += STEPY;
;          if (KEYS[SC_DN]) camy -= STEPY;
;          if (camy < CAMYMIN) camy = CAMYMIN;
;          if (camy > CAMYMAX) camy = CAMYMAX;
;
;          step_xz();                       /* SPEEDV along the heading */
;          camx += wdx;
;          camz += wdz;
;      }
PHYS:   mov  word [turn],0      ; turn = 0: which way the stick is held
        cmp  byte [KEYS+SC_LF],0    ; is LEFT held?
        je   .nl                    ;   no
        mov  ax,[heading]           ; AX = heading
        sub  ax,TURNV               ; AX = heading - TURNV
        and  ax,255                 ; AX &= 255: a byte IS the whole circle,
        mov  [heading],ax           ;  so this cannot go out of range
        mov  word [turn],-1         ; turn = -1
.nl:    cmp  byte [KEYS+SC_RT],0    ; is RIGHT held?
        je   .nr                    ;   no
        mov  ax,[heading]           ; AX = heading
        add  ax,TURNV               ; AX = heading + TURNV
        and  ax,255                 ; AX &= 255
        mov  [heading],ax           ; heading = AX
        mov  word [turn],1          ; turn = +1

        ; ---- the bank. roll chases the turn, and falls back to level -----
        ; Four compares and two adds, and this is the whole "feel" of the
        ; aeroplane. It models nothing at all.
.nr:    mov  ax,[turn]          ; AX = turn
        test ax,ax              ; turn == 0 ?
        jz   .decay             ;   yes: fall back toward level
        jg   .bankr             ;   turn > 0: bank right
        mov  ax,[roll]          ; AX = roll            ---- bank left
        sub  ax,BANKSTP         ; AX = roll - BANKSTP
        cmp  ax,-BANKMAX        ; AX >= -BANKMAX ?
        jge  .bset              ;   yes: that is the new roll
        mov  ax,-BANKMAX        ;   no: pinned at the limit
        jmp  .bset              ; and store it
.bankr: mov  ax,[roll]          ; AX = roll            ---- bank right
        add  ax,BANKSTP         ; AX = roll + BANKSTP
        cmp  ax,BANKMAX         ; AX <= BANKMAX ?
        jle  .bset              ;   yes
        mov  ax,BANKMAX         ;   no: pinned
        jmp  .bset              ; and store it
.decay: mov  ax,[roll]          ; AX = roll            ---- back to level
        test ax,ax              ; roll == 0 ?
        jz   .bset              ;   yes: already level
        jg   .dpos              ;   roll > 0: come down
        add  ax,BANKSTP         ; AX = roll + BANKSTP   (roll was negative)
        cmp  ax,0               ; overshot past level?
        jle  .bset              ;   no
        xor  ax,ax              ;   yes: AX = 0, stop exactly level
        jmp  .bset              ; and store it
.dpos:  sub  ax,BANKSTP         ; AX = roll - BANKSTP
        cmp  ax,0               ; overshot past level?
        jge  .bset              ;   no
        xor  ax,ax              ;   yes: AX = 0
.bset:  mov  [roll],ax          ; roll = AX. SETTRIG turns this into
                                ;  rsin/rcos at the top of the next frame,
                                ;  and APPLYROLL tilts every point by it

        ; ---- climb and dive, between a floor and a ceiling ---------------
        cmp  byte [KEYS+SC_UP],0    ; is PgUp held?
        je   .nu                    ;   no
        mov  ax,[camy]              ; AX = camy
        add  ax,STEPY               ; AX = camy + STEPY
        mov  [camy],ax              ; camy = AX
.nu:    cmp  byte [KEYS+SC_DN],0    ; is PgDn held?
        je   .nd                    ;   no
        mov  ax,[camy]              ; AX = camy
        sub  ax,STEPY               ; AX = camy - STEPY
        mov  [camy],ax              ; camy = AX
.nd:    mov  ax,[camy]          ; AX = camy
        cmp  ax,CAMYMIN         ; camy >= the floor?
        jge  .y1                ;   yes
        mov  ax,CAMYMIN         ;   no: stand on it. There is no crash in
.y1:    cmp  ax,CAMYMAX         ;    this lesson - the ground is a floor
        jle  .y2                ; camy <= the ceiling?
        mov  ax,CAMYMAX         ;   no: pinned
.y2:    mov  [camy],ax          ; camy = AX

        ; ---- and it always moves forward ---------------------------------
        call STEPXZ             ; wdx, wdz = one frame's travel along heading
        mov  ax,[wdx]           ; AX = wdx
        add  [camx],ax          ; camx += wdx
        mov  ax,[wdz]           ; AX = wdz
        add  [camz],ax          ; camz += wdz
        ret                     ; return

; ============================================================================
;  KBINT - our own INT 9. Copied out of CITY.ASM line 259.
;
;  The keyboard raises this interrupt itself, on every press AND on every
;  release. The scan code is waiting on port 60h: the key's number, with
;  bit 7 set if it is coming up rather than going down. We write 1 or 0
;  into our own table and tell the interrupt controller we are finished.
;
;  It does NOT chain to the handler it replaced, so the BIOS never learns
;  that a key happened and INT 16h stays empty for as long as this program
;  runs. That is the price of the table, it is what the game pays, and it
;  is why the map screen above waits on KEYS and not on the BIOS.
;
;  A HANDLER OWNS NOTHING. It can fire between any two instructions of the
;  program it interrupts, so every register it touches is pushed first -
;  including DS, because the program it interrupted may have had its own.
; ============================================================================
;  In C:
;
;      void interrupt kbint(void)
;      {
;          unsigned char code = inp(0x60);
;          KEYS[code & 0x7F] = (code & 0x80) ? 0 : 1;
;          outp(0x20, 0x20);                    /* end of interrupt */
;      }
KBINT:  push ax                 ; save every register this touches...
        push bx                 ; keep BX
        push di                 ; keep DI
        push ds                 ; ...DS included: whoever we interrupted
        mov  ax,cs              ; AX = cs       had its own
        mov  ds,ax              ; DS = cs: now KEYS means our KEYS
        in   al,60h             ; AL = the scan code, straight off the port
        mov  ah,al              ; AH = a copy, with bit 7 still on it
        and  al,7Fh             ; AL = the key itself, bit 7 cleared
        mov  bl,al              ; BL = the key
        xor  bh,bh              ; BH = 0: BX = the key, as an index
        mov  di,KEYS            ; DI = &KEYS[0]
        add  di,bx              ; DI = &KEYS[key]
        test ah,80h             ; bit 7 set = the key came UP
        jnz  .brk               ;   yes: it was released
        mov  byte [di],1        ; KEYS[key] = 1: held down
        jmp  .eoi               ; and finish
.brk:   mov  byte [di],0        ; KEYS[key] = 0: let go
.eoi:   mov  al,20h             ; AL = 20h, "end of interrupt"
        out  20h,al             ; tell the controller, or nothing fires again
        pop  ds                 ; everything back, exactly as it was found
        pop  di                 ; DI back
        pop  bx                 ; BX back
        pop  ax                 ; AX back
        iret                    ; return from interrupt

; ============================================================================
;  REMOTE - the one window left in the BIOS door.
;
;  Taking INT 9 shut the BIOS keyboard off, and it shut it off for
;  EVERYONE, not only for a person at the keyboard. Anything that drives
;  this program from outside puts its keys in the BIOS buffer, because
;  that is where a keystroke normally lands - and after INT 9 was taken,
;  nothing in here would ever read them.
;
;  So once a frame we look. A scan code found there is written into the
;  key table and HELD for RHOLD frames, as though a finger had been on
;  it. Held, not tapped: the bank needs ten frames in a row to build, and
;  a key that lasted one frame would move it three and let it fall
;  straight back. Each new code refreshes the hold, so a stream of them
;  is one long press.
;
;  The real keyboard never comes through here. KBINT does not pass a key
;  on, so the BIOS buffer only ever holds what somebody else put in it.
; ============================================================================
;  In C:
;
;      void remote(void)
;      {
;          if (key_waiting()) { rkey = scan_of(get_key());  rhold = RHOLD; }
;          if (rhold)     { rhold--;  KEYS[rkey] = 1; }
;          else if (rkey) { KEYS[rkey] = 0;  rkey = 0; }
;      }
REMOTE: mov  ah,1               ; AH = 1: is anything in the BIOS buffer?
        int  16h                ; ZF set = nothing there
        jz   .hold              ;   nothing fed: on to the hold
        mov  ah,0               ; AH = 0: take it out of the buffer
        int  16h                ; AH = the scan code, AL the character
        mov  [rkey],ah          ; rkey = the scan code
        mov  byte [rhold],RHOLD ; rhold = RHOLD - a new one refreshes it
.hold:  cmp  byte [rhold],0     ; still holding one?
        je   .let               ;   no: let it go
        dec  byte [rhold]       ; rhold--
        mov  bl,[rkey]          ; BL = rkey
        xor  bh,bh              ; BX = rkey, as an index into the table
        mov  byte [KEYS+bx],1   ; KEYS[rkey] = 1: held, this frame too
        ret                     ; return
.let:   mov  bl,[rkey]          ; BL = rkey
        or   bl,bl              ; was there one at all?
        jz   .none              ;   no: nothing to let go of
        xor  bh,bh              ; BX = rkey
        mov  byte [KEYS+bx],0   ; KEYS[rkey] = 0: let go
        mov  byte [rkey],0      ; rkey = 0: and forgotten
.none:  ret                     ; return

; ---- STEPXZ: one pace along the way the camera is facing ------------------
;  The heading's own sine and cosine are already in hsin/hcos, put there by
;  SETTRIG once a turn, so a pace is two multiplies and no table lookup.
;  In C:
;
;      void step_xz(void)
;      {
;          wdx = SPEEDV * hsin / 256;    /* hsin, hcos are sin/cos * 256 */
;          wdz = SPEEDV * hcos / 256;
;      }
STEPXZ: mov  ax,[hsin]          ; AX = hsin
        mov  bx,SPEEDV          ; BX = SPEEDV
        imul bx                 ; DX:AX = hsin * SPEEDV
        mov  bx,256             ; BX = 256
        idiv bx                 ; AX = hsin * SPEEDV / 256
        mov  [wdx],ax           ; wdx = AX
        mov  ax,[hcos]          ; AX = hcos
        mov  bx,SPEEDV          ; BX = SPEEDV
        imul bx                 ; DX:AX = hcos * SPEEDV
        mov  bx,256             ; BX = 256
        idiv bx                 ; AX = hcos * SPEEDV / 256
        mov  [wdz],ax           ; wdz = AX
        ret                     ; return

; ============================================================================
;  FRAME - clear, draw the lattice, show it.
; ============================================================================
FRAME:  mov  ax,cs              ; AX = cs
        add  ax,1000h           ; AX = cs + 1000h: the back buffer...
        cmp  byte [doside],0    ; doside ?
        jne  .buf               ;   yes: draw there
        mov  ax,0A000h          ; AX = A000h: ...UNLESS the glass is not clipped,
                                ;  and then we take the back buffer away and
                                ;  draw on the screen itself. Not for effect:
                                ;  E_RAST's LINE walks every pixel of a line
                                ;  whether the pixel is on the screen or not,
                                ;  and with CLAMPAX handing it four thousand
                                ;  a frame is seven million pixels and the
                                ;  best part of a minute. Behind a buffer
                                ;  that is a black screen and a mystery. On
                                ;  the screen it is a thing you can watch.
;  In C:
;
;      void frame(void)
;      {
;          bufseg = doside ? cs + 0x1000 : 0xA000;
;          memset(buf, 0, 64000);           /* clear   */
;          faults = 0;  gridc();  tally();  hud();
;          if (!doside) return;             /* drawn straight on: done */
;          wait_retrace();
;          memcpy(screen, buf, 64000);      /* blit    */
;      }
.buf:   mov  [bufseg],ax        ; bufseg = AX
        mov  es,ax              ; ES = bufseg           \  memset(buf,0,64000):
        xor  di,di              ; DI = 0                 > 32000 words of 0,
        xor  ax,ax              ; AX = 0                /  written by STOSW
        mov  cx,32000           ; CX = 32000
        rep  stosw              ; while (cx--) *es:di++ = ax
                                ;
                                ; AND NOTHING ELSE IS PAINTED. Lesson 13 drew
                                ; a grey line across the middle here, to mark
                                ; where a flat plane meets the eye's axis, and
                                ; it was worth having while the camera stayed
                                ; level. An aeroplane does not. The moment the
                                ; world banks, a line pinned to row 100 says
                                ; "the ground is tilted and you are not",
                                ; which is exactly backwards.
                                ;
                                ; The game has no such line either. It fills
                                ; the top half with sky and the bottom with
                                ; ground - and if you look at its palette,
                                ; those two colours are 6,9,22 and 4,6,16.
                                ; The same dark blue twice. WIRE CITY has no
                                ; visible horizon at all, and that is why its
                                ; level split never argues with its bank.
                                ;
                                ; A sky that banks with the world is a filled
                                ; polygon, and SCANPOLY in E_RAST.INC would
                                ; draw it today. It belongs to the lesson that
                                ; earns it.
        mov  word [faults],0    ; faults = 0
        call GRIDC              ; gridc()    - the lattice
        call TALLY              ; tally()    - the red pixels
        call HUD                ; hud()      - the frame rate
        cmp  byte [doside],0    ; if (!doside)
        je   .out               ;     return;   drawn straight on: no blit
        call WAITVR             ; wait_retrace()
        push ds                 ; keep DS
        mov  ax,0A000h          ; AX = the screen segment
        mov  es,ax              ; ES = screen           \  memcpy(screen,
        mov  ds,[bufseg]        ; DS = bufseg            > buf, 64000) with
        xor  si,si              ; SI = 0                /  MOVSW, 32000 words
        xor  di,di              ; DI = 0
        mov  cx,32000           ; CX = 32000
        rep  movsw              ; while (cx--) *es:di++ = *ds:si++
        pop  ds                 ; DS = ours again
.out:   ret

; ---- TALLY: one red pixel along the top row for every caught divide -------
;  Nothing to read on a good frame, because there is nothing to count. On
;  stage 2 it is a red bar as wide as the trouble.
;  In C:
;
;      void tally(void)
;      {
;          int n = faults;  if (n > 320) n = 320;
;          for (int i = 0; i < n; i++) buf[i] = 12;      /* row 0, red */
;      }
TALLY:  mov  cx,[faults]        ; CX = n = faults
        jcxz  .none             ; if (n == 0) return
        cmp  cx,320             ; n > 320 ?
        jbe  .fit               ;   no: n fits
        mov  cx,320             ;   n = 320   (one row is all we have)
.fit:   mov  ax,[bufseg]        ; AX = bufseg
        mov  es,ax              ; ES = bufseg
        xor  di,di              ; DI = 0      - row 0, column 0
        mov  al,12              ; AL = 12, red out of the default palette:
        rep  stosb              ; while (cx--) *es:di++ = al   instrumentation,
.none:  ret                     ;                              not scenery

; ---- HUD: the frame rate and which engine drew it, top left ---------------
;  Two digits: one DIV, once a frame, on a number under a hundred. The
;  lesson has nothing against dividing; it has something against dividing
;  a hundred and sixty thousand times a second.
;  In C:
;
;      void hud(void)
;      {
;          int n = fpsv;  if (n > 99) n = 99;
;          char *s = fastp ? HUDF : HUDC;          /* "00 FPS   FAST  (F)" */
;          s[0] = '0' + n / 10;
;          s[1] = '0' + n % 10;
;          txt(4, 8, s);                            /* row 4, column 8 */
;      }
HUD:    mov  ax,[fpsv]          ; AX = n = fpsv
        cmp  ax,99              ; n > 99 ?
        jbe  .two               ;   no: n fits
        mov  ax,99              ;   n = 99   (the corner holds two digits)
.two:   mov  bl,10              ; BL = 10
        div  bl                 ; AL = n / 10, AH = n % 10  (byte DIV: both)
        add  ax,'00'            ; AL += '0', AH += '0'  - one ADD, both digits,
                                ;  because '00' is 3030h and neither can carry
        mov  si,HUDF            ; SI = HUDF
        cmp  byte [fastp],0     ; fastp ?
        jne  .put               ;   yes: FAST
        mov  si,HUDC            ;   no: SI = HUDC
.put:   mov  [si],al            ; s[0] = tens
        mov  [si+1],ah          ; s[1] = units
        mov  ax,4               ; AX = row 4: under the tally bar
        mov  bx,8               ; BX = column 8
        call TXT                ; txt(4, 8, s)
        ret                     ; return

HUDF    db '00 FPS   FAST  (F)',0
HUDC    db '00 FPS   CLASSIC  (F)',0

; ---- TXT: AX = y, BX = x, SI = the string; the PC's own 8x8 font ---------
;  Straight from EXAMPLES\JET.ASM. The glyphs live at F000:FA6E in every
;  PC's ROM - the same ones the BIOS boots with - so a program that wants
;  to write a number needs no font of its own.
;  In C:
;
;      void txt(int y, int x, char *s)
;      {
;          unsigned char *rom = (unsigned char far *)0xF000FA6E;  /* 8x8 glyphs */
;          int at = y * 320 + x;
;          for (; *s; s++, at += 8) {                  /* one character cell */
;              unsigned char *g = rom + *s * 8;        /* its eight rows     */
;              for (int r = 0; r < 8; r++) {
;                  unsigned char bits = g[r];
;                  for (int c = 0; c < 8; c++, bits <<= 1)
;                      if (bits & 0x80) buf[at + r * 320 + c] = tcol;
;              }
;          }
;      }
TXT:    push es                 ; keep ES and DX for the caller
        push dx                 ; keep DX
        mov  cx,ax              ; CX = y      (AX is needed for MUL)
        mov  ax,[bufseg]        ; AX = bufseg
        mov  es,ax              ; ES = bufseg
        mov  ax,cx              ; AX = y
        mov  cx,320             ; CX = 320
        mul  cx                 ; AX = y * 320
        add  ax,bx              ; AX = y * 320 + x
        mov  di,ax              ; DI = at      - the top-left of the first cell
.ch:    lodsb                   ; AL = *s++
        or   al,al              ; end of string?
        jz   .done              ;   yes: return
        push si                 ; keep s
        xor  ah,ah              ; AX = the character
        mov  cl,3               ; CL = 3   (shift count: * 8)
        shl  ax,cl              ; AX = char * 8     - offset of its glyph
        mov  si,0FA6Eh          ; SI = FA6Eh        \  g = rom + char*8
        add  si,ax              ; SI = FA6Eh + char*8 /
        push ds                 ; keep DS
        mov  ax,0F000h          ; AX = F000h
        mov  ds,ax              ; DS = F000h        - now DS:SI is the ROM
        mov  cx,8               ; CX = 8 rows
        push di                 ; keep at
.row:   lodsb                   ; AL = bits = g[r]  - MSB is the left pixel
        mov  ah,al              ; AH = bits
        push cx                 ; keep the row count
        mov  cx,8               ; CX = 8 columns
.px:    shl  ah,1               ; bits <<= 1; CF = the pixel that fell off
        jnc  .np                ; if (bit was 0) skip
        mov  al,[cs:tcol]       ; AL = tcol   ([cs:] because DS is the ROM)
        mov  [es:di],al         ; buf[at] = tcol
.np:    inc  di                 ; at++  (next column)
        loop .px                ; 8 columns
        add  di,320-8           ; at += 320 - 8   (next row, same column)
        pop  cx                 ; the row count again
        loop .row               ; 8 rows
        pop  di                 ; DI = at, the cell's top-left again
        pop  ds                 ; DS = ours again
        pop  si                 ; SI = s
        add  di,8               ; at += 8   - the next character cell
        jmp  .ch                ; next character
.done:  pop  dx
        pop  es                 ; ES back
        ret                     ; return


; ============================================================================
;  GRIDC - WIRE CITY's ground lattice, one SQUARE at a time.
;
;  The game drew it as long lines: twelve across and twelve down, each one
;  running the whole width of the grid, because its ground was one colour
;  and a long line is cheaper than the squares it is made of. Ours is not
;  one colour. Every square is painted by the height of the Diamond-Square
;  node at its corner, so every square has to be its own two edges - the
;  one going east and the one going north - and the node at the far corner
;  is another square's business.
;
;  That is the only thing about this routine that is not the game's, and it
;  costs exactly what you would think: the game rotated two endpoints per
;  long line, and we rotate two per SEGMENT, so every node goes through
;  ROTXZ four times instead of once. The game has an answer to that and its
;  name is TERRPREP. It belongs to the next lesson, with the relief that
;  makes it worth having.
;
;  A node is 1024 world units from its neighbour - the heightmap's own
;  pitch, four of the game's building cells - and the map is 64 nodes
;  square, so 64 times 1024 is 65536, which is exactly one word. The torus
;  needs no arithmetic at all here: the subtraction wraps by itself.
; ============================================================================
;  In C:
;
;      void gridc(void)
;      {
;          camgi = (camx + BIAS) >> 10;             /* the node under the eye */
;          camgj = (camz + BIAS) >> 10;
;          for (gj = camgj - NR; gj <= camgj + NR; gj++)
;              for (gi = camgi - NR; gi <= camgi + NR; gi++) {
;                  band(gi, gj);                    /* COLOR = this square's */
;                  nodev(gi, gj, &x0, &z0);         /* its corner            */
;                  y0 = y1 = -camy;                 /* the plane is at y = 0 */
;                  nodev(gi + 1, gj, &x1, &z1);     /* east                  */
;                  draw_edge_3d();
;                  nodev(gi, gj, &x0, &z0);         /* the corner AGAIN -    */
;                  y0 = y1 = -camy;                 /*  draw_edge_3d cut it  */
;                  nodev(gi, gj + 1, &x1, &z1);     /* north                 */
;                  draw_edge_3d();
;              }
;      }
GRIDC:  mov  ax,[camx]          ; AX = camx
        add  ax,BIAS            ; AX = camx + BIAS
        mov  cl,2               ; CL = 2   (shift count)
        shr  ax,cl              ; AX >>= 2   \  >> 10 in two goes: the 8086
        mov  cl,8               ;             > shifts by 1 or by CL, and
        shr  ax,cl              ; AX >>= 8   /  CL cannot be 10 in one CL
        mov  [camgi],ax         ; camgi = (camx + BIAS) >> 10
        mov  ax,[camz]          ; AX = camz
        add  ax,BIAS            ; AX = camz + BIAS
        mov  cl,2               ; CL = 2
        shr  ax,cl              ; AX >>= 2
        mov  cl,8               ; CL = 8
        shr  ax,cl              ; AX >>= 8
        mov  [camgj],ax         ; camgj = (camz + BIAS) >> 10

        mov  ax,[camgj]         ; AX = camgj
        sub  ax,NR              ; AX = camgj - NR
        mov  [gj],ax            ; gj = camgj - NR           (outer for)
.rz:    mov  ax,[camgi]         ; AX = camgi
        sub  ax,NR              ; AX = camgi - NR
        mov  [gi],ax            ; gi = camgi - NR           (inner for)

.rx:    mov  ax,[gi]            ; AX = gi   \  band(gi, gj)
        mov  bx,[gj]            ; BX = gj   /
        call BAND               ; COLOR = the band of the height at (gi,gj)

        mov  ax,[gi]            ; AX = gi   \  nodev(gi, gj, &x0, &z0)
        mov  bx,[gj]            ; BX = gj    >
        mov  di,x0              ; DI = &x0  /  (x0 and z0 sit side by side)
        call NODEV              ; x0, z0 = the corner, from the eye
        mov  ax,[camy]          ; AX = camy
        neg  ax                 ; AX = -camy: the plane is at y = 0, so the
        mov  [y0],ax            ; y0 = -camy   eye sees it camy below.
        mov  [y1],ax            ; y1 = -camy   GRID's own two lines

        mov  ax,[gi]            ; AX = gi
        inc  ax                 ; AX = gi + 1   \  nodev(gi+1, gj, &x1, &z1)
        mov  bx,[gj]            ; BX = gj        >
        mov  di,x1              ; DI = &x1      /
        call NODEV              ; x1, z1 = the corner to the east
        call DRAWEDGE3D         ; draw_edge_3d()   - the edge going east

        mov  ax,[gi]            ; AX = gi   \  nodev(gi, gj, &x0, &z0) AGAIN:
        mov  bx,[gj]            ; BX = gj    > DRAWEDGE3D CUTS, and what it
        mov  di,x0              ; DI = &x0  /  cut was this same corner
        call NODEV              ; x0, z0 = the corner, fresh
        mov  ax,[camy]          ; AX = camy
        neg  ax                 ; AX = -camy
        mov  [y0],ax            ; y0 = -camy   (the cut moved y0 too)
        mov  [y1],ax            ; y1 = -camy
        mov  ax,[gi]            ; AX = gi   \
        mov  bx,[gj]            ; BX = gj    > nodev(gi, gj+1, &x1, &z1)
        inc  bx                 ; BX = gj+1 /
        mov  di,x1              ; DI = &x1
        call NODEV              ; x1, z1 = the corner to the north
        call DRAWEDGE3D         ; draw_edge_3d()   - the edge going north

        inc  word [gi]          ; gi++
        mov  ax,[camgi]         ; AX = camgi
        add  ax,NR              ; AX = camgi + NR
        cmp  ax,[gi]            ; gi <= camgi + NR ?
        jl   .ez                ;   no: this row is done
        jmp  .rx                ;   yes: next square   (over a JMP: the
.ez:    inc  word [gj]          ; gj++                  body is > 127 bytes)
        mov  ax,[camgj]         ; AX = camgj
        add  ax,NR              ; AX = camgj + NR
        cmp  ax,[gj]            ; gj <= camgj + NR ?
        jl   .done              ;   no: all rows done
        jmp  .rz                ;   yes: next row
.done:  ret

; ---- NODEV: node (AX = gi, BX = gj) into camera space, at [di] and [di+2] -
;  Straight out of GRID: the node's world position, minus where the camera
;  stands, through ROTXZ. The shift is the game's - two then eight, because
;  the 8086 shifts by one or by CL and 1024 is ten places.
;  In C:
;
;      void nodev(int gi, int gj, int *px, int *pz)
;      {
;          wdx = gi * 1024 - BIAS - camx;       /* the node, from the eye  */
;          wdz = gj * 1024 - BIAS - camz;
;          rotxz();                              /* turn by the heading:    */
;          *px = rc_x;                           /*  wdx,wdz -> rc_x,rc_z   */
;          *pz = rc_z;
;      }
;
;  AX = gi, BX = gj, DI = px on entry; pz is px + 2 because x0/z0 and x1/z1
;  are declared side by side. ROTXZ is ENGINE\E_M3D.INC and clobbers AX,
;  BX, DX - not DI, but DI is pushed anyway: a routine that relies on what
;  a neighbour happens not to touch breaks the day the neighbour changes.
NODEV:  push di                 ; keep px
        mov  cl,2               ; CL = 2   (shift count)
        shl  ax,cl              ; AX = gi << 2   \  * 1024, in two shifts
        mov  cl,8               ;                 >
        shl  ax,cl              ; AX = gi << 10  /
        sub  ax,BIAS            ; AX = gi*1024 - BIAS
        sub  ax,[camx]          ; AX = gi*1024 - BIAS - camx
        mov  [wdx],ax           ; wdx = that     (ROTXZ's input)
        mov  ax,bx              ; AX = gj
        mov  cl,2               ; CL = 2
        shl  ax,cl              ; AX = gj << 2
        mov  cl,8               ; CL = 8
        shl  ax,cl              ; AX = gj << 10
        sub  ax,BIAS            ; AX = gj*1024 - BIAS
        sub  ax,[camz]          ; AX = gj*1024 - BIAS - camz
        mov  [wdz],ax           ; wdz = that
        call ROTXZ              ; rc_x, rc_z = (wdx, wdz) turned by heading
        pop  di                 ; DI = px again
        mov  ax,[rc_x]          ; AX = rc_x
        mov  [di],ax            ; *px = rc_x
        mov  ax,[rc_z]          ; AX = rc_z
        mov  [di+2],ax          ; *pz = rc_z
        ret                     ; return

; ---- BAND: COLOR from the height at node (AX = gi, BX = gj) ---------------
;  The boundaries are lesson 0x11's and the engine's - the same numbers
;  GETZONE sorts the world by. The six colours are the island's, so a
;  square here is the colour that square was on the map in stage 1.
;  In C:
;
;      void band(int gi, int gj)
;      {
;          int h = hget(gi & 63, gj & 63);      /* HGET does the & 63 itself */
;          if      (h <  88) COLOR = 1;         /* sea   */
;          else if (h < 120) COLOR = 2;         /* sand  */
;          else if (h < 168) COLOR = 3;         /* grass */
;          else if (h < 200) COLOR = 4;         /* woods */
;          else if (h < 230) COLOR = 5;         /* rock  */
;          else              COLOR = 6;         /* snow  */
;      }
;
;  The assembly keeps the answer in AH and OVERWRITES it on the way down:
;  every `mov ah,n` is "the answer so far", and the first `jb .set` that
;  fires is the `else if` that won.
BAND:   mov  dx,bx              ; DX = gj   \  HGET wants x in BX, y in DX
        mov  bx,ax              ; BX = gi   /
        call HGET               ; AL = h, 0..255; HGET does the wrapping
        mov  ah,1               ; AH = 1 (sea)      - if nothing below fires
        cmp  al,88              ; h < 88 ?
        jb   .set               ;   yes: sea
        mov  ah,2               ; AH = 2 (sand)
        cmp  al,120             ; h < 120 ?
        jb   .set               ;   yes: sand
        mov  ah,3               ; AH = 3 (grass)
        cmp  al,168             ; h < 168 ?
        jb   .set               ;   yes: grass
        mov  ah,4               ; AH = 4 (woods)
        cmp  al,200             ; h < 200 ?
        jb   .set               ;   yes: woods
        mov  ah,5               ; AH = 5 (rock)
        cmp  al,230             ; h < 230 ?
        jb   .set               ;   yes: rock
        mov  ah,6               ; AH = 6 (snow)     - the else
.set:   mov  [COLOR],ah         ; COLOR = AH
        ret                     ; return

; ============================================================================
;  THE GAME'S OWN CLIPPING, from GAMES\WIRECITY\CITY.ASM line 818.
;
;  Copied, not rewritten. The only thing added is the two flags, and they
;  exist so the stages can take a fence down and let you look.
; ============================================================================
;  In C, the whole routine is this:
;
;      void draw_edge_3d(void)              /* x0,y0,z0 .. x1,y1,z1 are globals */
;      {
;          savesp = sp;                     /* for the trap - see TRAP0 */
;          if (donear && !near_clip()) return;     /* behind the eye: nothing */
;          proj2();                                /* x0,y0,z0 -> sx0,sy0 etc */
;          if (doside && !clip_line()) return;     /* off the screen: nothing */
;          line();                                 /* pixels, at last */
;      }
;
;  Every `jc .skip` is a `return`. The routines hand their yes/no back in
;  the carry flag, which is the 8086's cheapest boolean: it costs no
;  register and `jc` reads it directly.
DRAWEDGE3D:
        mov  [savesp],sp        ; savesp = sp  - WHERE THE TRAP COMES BACK TO.
                                ;  At this instant the top of the stack is the
                                ;  return address into GRIDC, so a handler that
                                ;  restores SP and does a plain RET lands exactly
                                ;  where a finished edge would have
        cmp  byte [donear],0    ; if (donear)
        je   .noz               ;   no: skip the near clip
        call NEARCLIP           ;     if (!near_clip())
        jc   .skip              ;         return;     (carry = "rejected")
.noz:   call PROJ2              ; proj2();
        cmp  byte [doside],0    ; if (doside)
        je   .no2               ;   no: skip the screen clip
        call CLIPLINE           ;     if (!clip_line())
        jc   .skip              ;         return;
.no2:   mov  ax,[bufseg]        ; ES = the buffer LINE draws into
        mov  es,ax              ; ES = bufseg
        call LINE               ; line();
.skip:  ret

; ============================================================================
;  TRAP0 - INT 0, and lesson 0x0F is the reason this program can be filmed.
;
;  Take NEARCLIP away and a node behind your eye reaches PROJPT with z at or
;  below nought. `idiv cx` with cx = 0 is a divide fault; `idiv cx` with a
;  quotient too big for AX is ALSO a divide fault, because on the 8086 INT 0
;  is both. DOS's own handler prints a line and takes the program away, and
;  stage 2 is a black screen and nothing to teach with.
;
;  So we take the vector. The handler throws away whatever PROJPT had pushed,
;  puts the stack back to where DRAWEDGE3D started, counts the fault, and
;  RETURNS - into GRIDC, at the instruction after the call, as though that
;  edge had simply been drawn. STI because an INT clears the flag on its way
;  in and nothing else will put it back.
;
;  Every red pixel along the top of stage 2 is one of these. That is not a
;  wrong picture - it is a machine that stopped, caught.
; ============================================================================
;  There is no C for this one, and that is worth saying: C has no way to
;  say "abandon the function that is running and continue from the caller
;  of the function that called it". The nearest is setjmp/longjmp, and this
;  is exactly what longjmp does under the hood - restore the stack pointer
;  and jump.
;
;      void trap0(void)             /* entered by the CPU, not by a call */
;      {
;          sp = savesp;             /* everything PROJPT pushed: gone      */
;          faults++;
;          enable_interrupts();     /* INT turned them off on the way in   */
;          return;                  /* ...to GRIDC, after `call DRAWEDGE3D` */
;      }
TRAP0:  mov  ax,cs              ; AX = our segment
        mov  ds,ax              ; DS = AX: data is ours again, whatever the
                                ;  faulting code had it set to. SS is ours
                                ;  already: a .COM is one segment
        mov  sp,[savesp]        ; sp = savesp: back to the top of DRAWEDGE3D
        inc  word [faults]      ; faults++
        sti                     ; interrupts back on
        ret                     ; return - into GRIDC

; ----- near Z-plane clipping ------------------------------------------------
;  In C:
;
;      int near_clip(void)                  /* 1 = keep (maybe cut), 0 = drop */
;      {
;          if (z0 < NEARZ) {
;              if (z1 < NEARZ) return 0;    /* both behind the eye: no image */
;              clip_p0();                   /* pull end 0 onto the plane */
;              return 1;
;          }
;          if (z1 < NEARZ) clip_p1();       /* end 0 is in front; is end 1? */
;          return 1;
;      }
;
;  `return 0` is `stc` (set carry), `return 1` is `clc` (clear it).
NEARCLIP:
        mov  ax,[z0]            ; AX = z0
        cmp  ax,NEARZ           ; if (z0 < NEARZ) {
        jge  .p0in              ;   no: end 0 is in front
        mov  bx,[z1]            ; BX = z1
        cmp  bx,NEARZ           ;     if (z1 < NEARZ)
        jl   .rej               ;         return 0;
        call CLIPP0             ;     clip_p0();
        clc                     ;     return 1;
        ret                     ; return
.p0in:  mov  bx,[z1]            ; } else {
        cmp  bx,NEARZ           ;     if (z1 < NEARZ)
        jge  .both              ;   no: end 1 is in front too
        call CLIPP1             ;         clip_p1();
        clc                     ;     return 1;
        ret                     ; return
.both:  clc                     ; }  return 1;
        ret                     ; return
.rej:   stc                     ; return 0;
        ret                     ; return

; ----- and the cut itself, which is the lesson ------------------------------
;  t = (NEARZ - z0) / (z1 - z0), spent on x and on y. What makes it fit an
;  8086 with no fractions at all is that IMUL leaves a THIRTY-TWO bit
;  product in DX:AX and IDIV takes a thirty-two bit dividend back:
;
;      (x1-x0) * num / den
;
;  is exact, in two instructions, with nothing rounded in between. No fixed
;  point, no scaling by 256, no shifts. That is the whole reason this
;  routine is twenty instructions and not sixty.
;
;  z is not computed at the end. It is ASSIGNED: the point now sits exactly
;  on the plane, and an answer that missed it by one would leave the vertex
;  outside and the test would throw the edge away.
;  In C:
;
;      void clip_p0(void)
;      {
;          int num = NEARZ - z0;            /* from end 0 to the plane      */
;          int den = z1 - z0;               /* from end 0 to end 1          */
;          x0 = x0 + (long)(x1 - x0) * num / den;
;          y0 = y0 + (long)(y1 - y0) * num / den;
;          z0 = NEARZ;                      /* ON the plane, by definition  */
;      }
;
;  The `(long)` is the point. In C you have to ask for the wide product or
;  it overflows at 32767. On the 8086 you cannot avoid it: IMUL always
;  leaves 32 bits in DX:AX, and IDIV always divides all 32 of them.
CLIPP0: mov  bx,[z1]
        sub  bx,[z0]            ; BX = den = z1 - z0
        mov  ax,NEARZ           ; AX = NEARZ
        sub  ax,[z0]            ; AX = num = NEARZ - z0
        mov  [tnum],ax          ; tnum = num   (IMUL wants it in memory, and
        mov  [tden],bx          ; tden = den    y needs both again below)
        mov  ax,[x1]            ; AX = x1
        sub  ax,[x0]            ; AX = x1 - x0
        imul word [tnum]        ; DX:AX = (x1 - x0) * num     (32 bits)
        idiv word [tden]        ; AX = that / den             (fits: t <= 1)
        add  ax,[x0]            ; AX = x0 + (x1 - x0) * num / den
        mov  [x0],ax            ; x0 = the crossing
        mov  ax,[y1]            ; AX = y1
        sub  ax,[y0]            ; AX = y1 - y0
        imul word [tnum]        ; DX:AX = (y1 - y0) * num
        idiv word [tden]        ; AX = that / den
        add  ax,[y0]            ; AX = y0 + (y1 - y0) * num / den
        mov  [y0],ax            ; y0 = the crossing
        mov  word [z0],NEARZ    ; z0 = NEARZ
        ret                     ; return

;  In C: clip_p0 with the two ends swapped - end 1 is pulled onto the
;  plane, end 0 stays where it is.
;
;      void clip_p1(void)
;      {
;          int num = NEARZ - z1;
;          int den = z0 - z1;
;          x1 = x1 + (long)(x0 - x1) * num / den;
;          y1 = y1 + (long)(y0 - y1) * num / den;
;          z1 = NEARZ;
;      }
CLIPP1: mov  bx,[z0]            ; BX = z0
        sub  bx,[z1]            ; BX = den = z0 - z1
        mov  ax,NEARZ           ; AX = NEARZ
        sub  ax,[z1]            ; AX = num = NEARZ - z1
        mov  [tnum],ax          ; tnum = num
        mov  [tden],bx          ; tden = den
        mov  ax,[x0]            ; AX = x0
        sub  ax,[x1]            ; AX = x0 - x1
        imul word [tnum]        ; DX:AX = (x0 - x1) * num
        idiv word [tden]        ; AX = that / den
        add  ax,[x1]            ; AX = x1 + (x0 - x1) * num / den
        mov  [x1],ax            ; x1 = the crossing
        mov  ax,[y0]            ; AX = y0
        sub  ax,[y1]            ; AX = y0 - y1
        imul word [tnum]        ; DX:AX = (y0 - y1) * num
        idiv word [tden]        ; AX = that / den
        add  ax,[y1]            ; AX = y1 + (y0 - y1) * num / den
        mov  [y1],ax            ; y1 = the crossing
        mov  word [z1],NEARZ    ; z1 = NEARZ
        ret                     ; return

; ----- project both points --------------------------------------------------
;  In C:
;
;      void proj2(void)
;      {
;          proj_pt(x0, y0, z0, &sx0, &sy0);   /* sx = 160 + x*FOCAL/z      */
;          proj_pt(x1, y1, z1, &sx1, &sy1);   /* sy = horiz - y*FOCAL/z    */
;      }
;
;  PROJPT (ENGINE\E_M3D.INC) takes its point in AX, DX, CX and hands the two
;  screen numbers back in AX and DX. That is the whole calling convention:
;  registers in, registers out, nothing on the stack.
PROJ2:  mov  ax,[x0]            ; AX = x0        \
        mov  dx,[y0]            ; DX = y0         > the point, in registers
        mov  cx,[z0]            ; CX = z0        /
        call PROJPT             ; AX = sx, DX = sy
        mov  [sx0],ax           ; sx0 = AX
        mov  [sy0],dx           ; sy0 = DX
        mov  ax,[x1]            ; AX = x1
        mov  dx,[y1]            ; DX = y1
        mov  cx,[z1]            ; CX = z1
        call PROJPT             ; AX = sx, DX = sy
        mov  [sx1],ax           ; sx1 = AX
        mov  [sy1],dx           ; sy1 = DX
        ret                     ; return

; ============================================================================
;  Stage 1: the island from above, and where you are about to stand.
;  Lesson 0x11's picture, redrawn from the same map the flight reads.
; ============================================================================
;  In C:
;
;      void mapview(void)
;      {
;          memset(buf, 0, 64000);
;          for (gj = 63; gj >= 0; gj--)                /* top row = highest z: */
;              for (gi = 0; gi < 64; gi++) {           /*  north up            */
;                  band(gi, gj);
;                  int at = (ORGY + (63 - gj) * 3) * 320 + ORGX + gi * 3;
;                  for (int r = 0; r < 3; r++)         /* a 3x3 block a node   */
;                      buf[at + r*320] = buf[at + r*320 + 1]
;                                      = buf[at + r*320 + 2] = COLOR;
;              }
;          int mx = ((camx + BIAS) >> 10) & 63,  mz = ((camz + BIAS) >> 10) & 63;
;          sx0 = sx1 = ORGX + mx * 3;                  /* the mark: a line   */
;          sy0 = ORGY + (63 - mz) * 3;  sy1 = sy0 - 24; /*  eight nodes long, */
;          COLOR = 15;  line();                        /*  pointing north    */
;      }
MAPVIEW:
        mov  ax,[bufseg]        ; AX = bufseg
        mov  es,ax              ; ES = bufseg           \  memset(buf,0,64000)
        xor  di,di              ; DI = 0                 >
        xor  ax,ax              ; AX = 0                /
        mov  cx,32000           ; CX = 32000 words
        rep  stosw              ; while (cx--) *es:di++ = ax
        mov  word [gj],63       ; gj = 63     - the TOP row is the HIGHEST z:
.row:   mov  word [gi],0        ; gi = 0        north up, like every map printed
.col:   mov  ax,[gi]            ; AX = gi   \  band(gi, gj)
        mov  bx,[gj]            ; BX = gj   /
        call BAND               ; COLOR = the band
        mov  ax,[gj]            ; AX = gj
        mov  bx,63              ; BX = 63
        sub  bx,ax              ; BX = 63 - gj      - rows count down from top
        mov  ax,bx              ; AX = 63 - gj
        mov  bx,320*CELLW       ; BX = 960: one node-row of the picture
        mul  bx                 ; AX = (63 - gj) * 960
        add  ax,ORGY*320        ; AX += ORGY * 320  - the map's top margin
        mov  di,ax              ; DI = the row's start
        mov  ax,[gi]            ; AX = gi
        mov  bx,CELLW           ; BX = 3
        mul  bx                 ; AX = gi * 3
        add  di,ax              ; DI += gi * 3
        add  di,ORGX            ; DI += ORGX        - now DI = at
        mov  al,[COLOR]         ; AL = COLOR
        mov  cx,CELLW           ; CX = 3 rows
.r3:    mov  [es:di],al         ; buf[at]   = COLOR  \  a 3x3 block a node,
        mov  [es:di+1],al       ; buf[at+1] = COLOR   > the way lesson 0x11
        mov  [es:di+2],al       ; buf[at+2] = COLOR  /  painted it
        add  di,320             ; at += 320  (next pixel row)
        loop .r3                ; 3 rows
        inc  word [gi]          ; gi++
        cmp  word [gi],64       ; gi < 64 ?
        jb   .col               ;   yes: next node
        dec  word [gj]          ; gj--
        jns  .row               ; gj >= 0 ? next row  (JNS: -1 sets the sign)

        mov  ax,[camx]          ; AX = camx             ---- the mark ----
        add  ax,BIAS            ; AX = camx + BIAS
        mov  cl,2               ; CL = 2   (shift count)
        shr  ax,cl              ; AX >>= 2   \  >> 10
        mov  cl,8               ;             >
        shr  ax,cl              ; AX >>= 8   /
        and  ax,63              ; AX &= 63          - mx, the node's column
        mov  bx,CELLW           ; BX = 3
        mul  bx                 ; AX = mx * 3
        add  ax,ORGX            ; AX = ORGX + mx * 3
        mov  [sx0],ax           ; sx0 = AX   \  a vertical line
        mov  [sx1],ax           ; sx1 = AX   /
        mov  ax,[camz]          ; AX = camz
        add  ax,BIAS            ; AX = camz + BIAS
        mov  cl,2               ; CL = 2
        shr  ax,cl              ; AX >>= 2
        mov  cl,8               ; CL = 8
        shr  ax,cl              ; AX >>= 8
        and  ax,63              ; AX &= 63          - mz, the node's row
        mov  bx,63              ; BX = 63
        sub  bx,ax              ; BX = 63 - mz
        mov  ax,bx              ; AX = 63 - mz
        mov  bx,CELLW           ; BX = 3
        mul  bx                 ; AX = (63 - mz) * 3
        add  ax,ORGY            ; AX = ORGY + (63 - mz) * 3
        mov  [sy0],ax           ; sy0 = AX          - where you stand
        sub  ax,8*CELLW         ; AX -= 24
        mov  [sy1],ax           ; sy1 = sy0 - 24    - eight nodes north
        mov  byte [COLOR],15    ; COLOR = 15, white
        call LINE               ; line()
        ret                     ; return

; ---- SHOW: the back buffer onto the screen --------------------------------
;  In C:  wait_retrace();  memcpy(screen, buf, 64000);
SHOW:   call WAITVR             ; wait_retrace()
        push ds                 ; keep DS
        mov  ax,0A000h          ; AX = A000h
        mov  es,ax              ; ES = the screen     \  memcpy(screen, buf,
        mov  ds,[bufseg]        ; DS = bufseg          > 64000): 32000 words
        xor  si,si              ; SI = 0              /  through MOVSW
        xor  di,di              ; DI = 0
        mov  cx,32000           ; CX = 32000
        rep  movsw              ; while (cx--) *es:di++ = *ds:si++
        pop  ds                 ; DS = ours again
        ret                     ; return

; ---- WAITVR: wait for the beam to fly home --------------------------------
;  Port 3DAh, bit 3: the VERTICAL RETRACE. Wait OUT any retrace already
;  running, then wait for the next one to begin - a whole frame, every time.
;  In C:
;
;      void wait_retrace(void)
;      {
;          while ( inp(0x3DA) & 8) ;     /* wait OUT any retrace running */
;          while (!(inp(0x3DA) & 8)) ;   /* wait for the next to begin   */
;      }
WAITVR: push ax                 ; keep AX and DX for the caller
        push dx                 ; keep DX
        mov  dx,3DAh            ; DX = 3DAh, the VGA status port
.o:     in   al,dx              ; AL = inp(0x3DA)
        test al,8               ; bit 3 = the beam is in vertical retrace
        jnz  .o                 ; while (retrace) ;   - wait it out
.i:     in   al,dx              ; AL = inp(0x3DA)
        test al,8               ; bit 3 again
        jz   .i                 ; while (!retrace) ;  - wait for the next
        pop  dx                 ; DX back
        pop  ax                 ; AX back
        ret                     ; return

; ---- SETPAL: the island's six colours, written into the VGA DAC -----------
;  Port 3C8h takes the colour NUMBER to start at, then 3C9h takes red,
;  green and blue - 0..63 each, and the index steps on by itself after
;  every third write. Lesson 0x11's ramp, unchanged, so a square in the
;  air is the colour it was on the map.
;  In C:
;
;      void setpal(void)
;      {
;          outp(0x3C8, 1);                        /* start at colour 1   */
;          for (int i = 0; i < 6 * 3; i++)
;              outp(0x3C9, PAL[i]);               /* r, g, b, r, g, b... */
;      }
SETPAL: mov  dx,3C8h            ; DX = 3C8h, the DAC index port
        mov  al,1               ; AL = 1
        out  dx,al              ; outp(0x3C8, 1): start at colour 1
        inc  dx                 ; DX = 3C9h, the DAC data port
        mov  si,PAL             ; SI = PAL
        mov  cx,6*3             ; CX = 18 bytes: six colours, r g b each
.p:     lodsb                   ; AL = *si++
        out  dx,al              ; outp(0x3C9, AL)   - the index steps on by
        loop .p                 ;  itself after every third write
        ret                     ; return

PAL     db  4,10,28             ; 1 sea
        db 46,42,26             ; 2 sand
        db 16,38,10             ; 3 grass
        db 10,26, 8             ; 4 woods
        db 26,24,22             ; 5 rock
        db 46,48,50             ; 6 snow

; ============================================================================
;  State: the lesson's own, then the contract the engine modules expect.
; ============================================================================
camx    dw 0                    ; where the eye stands, in world units
camy    dw CAMY0                ; how high over the plane
camz    dw 0
camgi   dw 0                    ; ...and which node that is
camgj   dw 0
gi      dw 0                    ; the lattice's own counters
gj      dw 0

x0      dw 0                    ; the edge, and the names are the game's.
z0      dw 0                    ;  x0/z0 and x1/z1 sit in pairs so that
x1      dw 0                    ;  NODEV can fill either one through a
z1      dw 0                    ;  single pointer
y0      dw 0
y1      dw 0

savesp  dw 0                    ; where TRAP0 puts the stack back to
faults  dw 0                    ; ...and how many times it had to, this frame
oldi0   dw 0,0                  ; the INT 0 vector we borrowed...
oldi9   dw 0,0                  ; ...and the INT 9 one. Both go back at QUIT

turn    dw 0                    ; which way the stick is held: -1, 0 or +1
fwas    db 0                    ; was F held last frame? - so one press is
                                ;  one flip and not sixty
rkey    db 0                    ; REMOTE: the code fed from outside, 0 = none
rhold   db 0                    ; ...and how many frames it is still held for

fastp   db 1                    ; WHICH ENGINE: 1 = the lessons' way (no
                                ;  divide in ROTXZ, lesson 8's Line), 0 =
                                ;  the classic the game shipped with. F
                                ;  flips it in flight; ENGINE\E_M3D.INC
                                ;  and E_RAST.INC read it and nothing else
fpsn    dw 0                    ; frames counted this second...
fpst    dw 0                    ; ...since this BIOS tick...
fpsv    dw 0                    ; ...and the number the HUD shows
tcol    db 15                   ; TXT's colour

donear  db 0                    ; THE TWO FENCES, as two bytes. Lesson 13
doside  db 0                    ;  took them down one at a time to show
                                ;  what each was holding back. Both are up
                                ;  from the boot now and never move again,
                                ;  so DRAWEDGE3D reads as CITY.ASM's does

KEYS    db 128 dup(0)           ; THE KEY TABLE. KBINT writes it, PHYS reads
                                ;  it, and nothing else in the program knows
                                ;  the keyboard exists. One byte a scan code:
                                ;  1 while held, 0 when let go

; ---- engine contract: E_MATH + E_TERR ------------------------------------
rseed   dw 1                    ; LCG state
dss     dw 0                    ; DS: current side length
dsh     dw 0                    ; DS: half side
dsx     dw 0                    ; DS: loop x / scratch
dsy     dw 0                    ; DS: loop y / scratch
dsamp   dw 0                    ; DS: noise amplitude (power of two)
dsac    dw 0                    ; DS: accumulator / scratch

; ---- engine contract: E_M3D + E_RAST -------------------------------------
bufseg  dw 0
heading dw 0                    ; the camera: turned by the arrows...
pitch   dw 0                    ; ...level...
roll    dw 0                    ; ...and not banked
hsin    dw 0
hcos    dw 256
rsin    dw 0
rcos    dw 256
psin    dw 0
pcos    dw 256
pofs    dw 0
horiz   dw 100                  ; where the eye's axis meets the glass
swayx   dw 0
swayy   dw 0
wdx     dw 0                    ; ROTXZ in...
wdz     dw 0
rc_x    dw 0                    ; ...and out
rc_z    dw 0
ptmp    dw 0                    ; projection scratch
rddx    dw 0
rddy    dw 0
rsxo    dw 0
tnum    dw 0                    ; clip interpolation scratch
tden    dw 0
cdx     dw 0                    ; line clip deltas / new point
cdy     dw 0
nx      dw 0
ny      dw 0
IX      dw 4 dup(0)             ; the polygon path's face buffers. This
IY      dw 4 dup(0)             ;  lesson draws no faces - the relief in
IZ      dw 4 dup(0)             ;  the next one does - but E_RAST.INC is
OX      dw 6 dup(0)             ;  one file and it is assembled whole, so
OY      dw 6 dup(0)             ;  the names it uses have to exist
OZ      dw 6 dup(0)
PX      dw 6 dup(0)
PY      dw 6 dup(0)
NPOLY   dw 0
oc      dw 0
ci      dw 0
ni      dw 0
pk      dw 0
pminy   dw 0
pmaxy   dw 0
scy     dw 0                    ; scanline filler state
scymax  dw 0
scxl    dw 0
scxr    dw 0
oc0     db 0                    ; Cohen-Sutherland outcodes
oc1     db 0
ocsel   db 0
lx      dw 0                    ; Bresenham state (LINE)
ly      dw 0
ldx     dw 0
ldy     dw 0
lsx     dw 0
lsy     dw 0
lerr    dw 0
sx0     dw 0
sy0     dw 0
sx1     dw 0
sy1     dw 0
COLOR   db 0

; quarter sine table: SINT[i] = round(256*sin(i*90/64 deg)), i=0..64
SINT    dw 0,6,13,19,25,31,38,44,50,56,62,68,74,80,86,92,98,104,109,115
        dw 121,126,132,137,142,147,153,157,162,167,172,177,181,185,190,194
        dw 198,202,206,209,213,216,220,223,226,229,231,234,237,239,241,243
        dw 245,247,248,250,251,252,253,254,255,255,256,256,256

        include '..\..\ENGINE\E_MATH.INC'
        include '..\..\ENGINE\E_TERR.INC'
        include '..\..\ENGINE\E_M3D.INC'
        include '..\..\ENGINE\E_RAST.INC'

HMAP    db 4096 dup(0)          ; the 64x64 heightmap DSGEN fills
