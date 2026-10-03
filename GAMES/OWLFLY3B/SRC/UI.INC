; UI.INC - part of WIRE CITY (included from OWLFLY3.ASM, between SKY.INC
; and NET.INC - NET.INC writes our game list and must see our symbols)
; ============================================================================
;  THE FRONT DOOR: splash and menu, in their own far segment.
;
;  The pilot this game is for has ten minutes, not an evening: launch,
;  see the sky list, pick one, fly. Shot down - SPACE - back in the
;  fight. So the door is short and the list is LIVE: every host on the
;  wire advertises its sky once a second ('G' packets), the menu just
;  listens and draws. Creating a sky is one letter and a name; bots
;  on gives you the 20v20 war to dive into, bots off is a clean PvP
;  arena, Counter-Strike manners.
;
;  UISEG lives at CS+1200h in a SIXTEEN-K window - it outgrew eight on
;  2026-07-29 and the answer in this project is to give a segment more
;  room, not to shave what is in it. Everything behind it simply moved up:
;  SYMSEG to CS+1600h, the buffer to CS+1800h, CITY.DAT to CS+2800h.
;  SKYSEG is PADDED to its full 8K so the
;  linker parks us exactly here. Like the sky segment, code here runs
;  with DS = the main segment: it reads KEYS, FONTBUF, COLOR and
;  writes gname/gact/gbots directly; what it cannot do is near-call
;  main-segment code, so the tiny helpers it needs (font, blit, line,
;  DSP write) live here as clones.
;
;  Far doors:  UISPLASH - the title animation (any key skips)
;              UIMENU   - the sky list; returns with the DS vars set:
;                         gact 1=create (gname/gbots filled)
;                         gact 2=join   (rseed/wseed/ggid set)
; ============================================================================

segment UISEG

NGL     = 8                   ; game list rows
GLSZ    = 16                  ; entry: gid,seed,nplr,scG,scY,bots,name8

; ---- data (before code: the forward-reference override lesson) -------------
GLIST   db NGL*GLSZ dup(0)      ; the skies on the wire (gid=0: empty)
GLAST   dw NGL dup(0)           ; BIOS tick each ad last landed
uitick  dw 0                    ; last BIOS tick the menu redrew on
sptick  dw 0                    ; splash: frame counter
sptc    dw 0                    ; splash: the rising roar's TC
uilx0   dw 0                    ; ULINE: the walking end...
uily0   dw 0
uilx1   dw 0                    ; ...and the fixed one
uily1   dw 0
uldx    dw 0                    ; |dx| |dy|, steps, the error term
uldy    dw 0
ulsx    dw 0
ulsy    dw 0
ulerr   dw 0
ujx     dw 0                    ; the jet being drawn: world x offset
ujz     dw 0                    ; ...and its depth
ujsx    dw 0                    ; projected vertex scratch
ujsy    dw 0
; The map's two lookup tables (see MMSETUP). They are HERE, in UISEG, and
; read through CS: on purpose - the blit runs with DS on the far scratch
; segment that holds the baked world, so a main-segment table would be
; unreachable from the one loop that needs it most.
MMCOLT  db 64 dup(0)            ; dest column -> world node column
MMROWT  dw 64 dup(0)            ; dest row    -> world row base (node*64)
shktgt  dw NSHILK dup(0)        ; who it is shooting at (0FFFFh = the pilot)
mprow   dw 0                    ; the map row a mark landed on. MMPTY hands
                                ;  it back in AX and UROW consumes AX, so a
                                ;  symbol that wants the row as well as the
                                ;  buffer has to be given somewhere
                                ;  to keep it
shkst   db NSHILK dup(0)        ; 0 = fighting, 1 = burning
PSHKMAX = 8                   ; the pedal's stop, forward...
PSHKREV = -3                  ; ...and reverse - tracks, not a gearbox
shkp    dw 0                    ; SHKGND: probe counter...
shkb    dw 0                    ;  ...the nominal site...
shkc    dw 0                    ;  ...and the best ground found so far
shke    dw 0                    ; SHKAIM: which side we are on...
shkg    dw 0                    ;  ...and the best target it found
shkq    dw 0                    ;  ...its bearing, while the pitch is worked
shkv    dw 0                    ;  ...and our own roof height
UWDIAL  db 'WIRE: DIALING',0    ; the address gate's wait, 13 -> 134
uwsp    dw 0                    ; the spinner's phase, 0..3
uwst    dw 0                    ; ...and its stroke, as a buffer step
UWSPD   db  0, 1                ; | / - \ : the direction of each stroke,
        db  1,-1                ;  a quarter turn clockwise at a time.
        db  1, 0                ;  Screen y grows DOWNWARD, which is why
        db  1, 1                ;  the slash's dy is the negative one
UTITLE  db 'OWL FLY III BOND',0
USUB    db 'WIRE CITY SQUADRON',0

; ============================ the far doors =================================
UISPLASH:
        call XSPLASH
        retf
UIMENU:
        call XMENU
        retf

; ---- UCLS: fill the whole back buffer with colour AL -----------------------
UCLS:   push es
        mov  bx,[bufseg]
        mov  es,bx
        mov  ah,al
        xor  di,di
        mov  cx,32000
        cld
        rep  stosw
        pop  es
        ret

; ---- UBLIT: back buffer -> the glass ---------------------------------------
UBLIT:  jmp  .cnv   ; the same gate BLIT wears: VGA/MCGA
                                ; copy straight, older cards convert
.cnv:  call VIDSEG:VBLITF
        ret

; ---- UFDRAW: ASCIIZ at CS:SI, position ftx/fty, colour COLOR ---------------
; The main FDRAW's twin, reading OUR OWN segment (all the front
; door's words live here). ES must be the back buffer.
UFDRAW:
.ch:   mov  al,[cs:si]
        inc  si
        test al,al
        jz   .done
        cmp  al,' '
        je   .adv
        cmp  al,':'
        jne  .nc
        mov  al,38              ; the colon glyph
        jmp  .dr
.nc:   cmp  al,'-'
        jne  .nm
        mov  al,37              ; the minus glyph
        jmp  .dr
.nm:   cmp  al,'9'
        ja   .alf
        sub  al,'0'
        jmp  .dr
.alf:  sub  al,'A'-10
.dr:   push si
        xor  ah,ah
        mov  bx,ax
        add  ax,ax
        add  ax,ax
        add  ax,bx
        add  ax,bx              ; *6
        mov  si,FONTBUF
        add  si,ax
        mov  ax,[fty]           ; base = fty*320+ftx
        mov  bx,ax
        mov  cl,8
        shl  ax,cl
        mov  cl,6
        shl  bx,cl
        add  ax,bx
        add  ax,[ftx]
        mov  di,ax
        mov  cx,6
.row:  mov  al,[si]
        mov  ah,[COLOR]
        test al,80h
        jz   .p1
        mov  [es:di],ah
.p1:   test al,40h
        jz   .p2
        mov  [es:di+1],ah
.p2:   test al,20h
        jz   .p3
        mov  [es:di+2],ah
.p3:   inc  si
        add  di,320
        loop .row
        pop  si
.adv:  add  word [ftx],4
        jmp  .ch
.done: ret

; ---- UBIG: the same string at triple size (each dot a 3x3 block) -----------
UBIG:
.ch:   mov  al,[cs:si]
        inc  si
        test al,al
        jz   .done
        cmp  al,' '
        je   .adv
        cmp  al,'9'
        ja   .alf
        sub  al,'0'
        jmp  .dr
.alf:  sub  al,'A'-10
.dr:   push si
        xor  ah,ah
        mov  bx,ax
        add  ax,ax
        add  ax,ax
        add  ax,bx
        add  ax,bx
        mov  si,FONTBUF
        add  si,ax
        mov  ax,[fty]
        mov  bx,ax
        mov  cl,8
        shl  ax,cl
        mov  cl,6
        shl  bx,cl
        add  ax,bx
        add  ax,[ftx]
        mov  di,ax
        mov  cx,6
.row:  push cx
        mov  al,[si]
        mov  cx,3               ; three screen rows per glyph row
.r3:   push cx
        push di
        mov  ah,al
        mov  cl,3
.bits: test ah,80h
        jz   .nx
        push ax
        mov  al,[COLOR]
        mov  [es:di],al
        mov  [es:di+1],al
        mov  [es:di+2],al
        pop  ax
.nx:   add  di,3
        shl  ah,1
        dec  cl
        jnz  .bits
        pop  di
        add  di,320
        pop  cx
        loop .r3
        inc  si
        pop  cx
        loop .row
        pop  si
.adv:  add  word [ftx],12
        jmp  .ch
.done: ret

; ---- ULINE: Bresenham (uilx0,uily0)-(uilx1,uily1), colour COLOR ------------
; Clips by skipping off-glass dots: splash lines are short-lived.
ULINE:  mov  ax,[cs:uilx1]
        sub  ax,[cs:uilx0]
        mov  bx,1
        or   ax,ax
        jns  .dx1
        neg  ax
        neg  bx
.dx1:  mov  [cs:uldx],ax          ; |dx|, step
        mov  [cs:ulsx],bx
        mov  ax,[cs:uily1]
        sub  ax,[cs:uily0]
        mov  bx,1
        or   ax,ax
        jns  .dy1
        neg  ax
        neg  bx
.dy1:  mov  [cs:uldy],ax
        mov  [cs:ulsy],bx
        mov  ax,[cs:uldx]
        sub  ax,[cs:uldy]
        mov  [cs:ulerr],ax         ; err = dx - dy
.pt:   mov  ax,[cs:uily0]         ; plot if on glass
        or   ax,ax
        js   .st
        cmp  ax,199
        jg   .st
        mov  bx,[cs:uilx0]
        or   bx,bx
        js   .st
        cmp  bx,319
        jg   .st
        push bx
        mov  bx,ax
        mov  cl,8
        shl  ax,cl
        mov  cl,6
        shl  bx,cl
        add  ax,bx
        pop  bx
        add  ax,bx
        mov  di,ax
        mov  al,[COLOR]
        mov  [es:di],al
.st:   mov  ax,[cs:uilx0]         ; done?
        cmp  ax,[cs:uilx1]
        jne  .go
        mov  ax,[cs:uily0]
        cmp  ax,[cs:uily1]
        je   .done
.go:   mov  ax,[cs:ulerr]
        add  ax,ax
        mov  bx,ax
        mov  ax,[cs:uldy]
        neg  ax
        cmp  bx,ax              ; e2 > -dy ?
        jle  .sk1
        mov  ax,[cs:uldy]
        sub  [cs:ulerr],ax
        mov  ax,[cs:ulsx]
        add  [cs:uilx0],ax
.sk1:  mov  ax,[cs:uldx]
        cmp  bx,ax              ; e2 < dx ?
        jge  .pt
        add  [cs:ulerr],ax
        mov  ax,[cs:ulsy]
        add  [cs:uily0],ax
        jmp  .pt
.done: ret

; ---- UANYK: AL=1 if any key is down ----------------------------------------
UANYK:  push si
        xor  si,si
        xor  al,al
.s:    cmp  byte [KEYS+si],0
        jne  .yes
        inc  si
        cmp  si,88h
        jb   .s
        pop  si
        ret
.yes:  mov  al,1
        pop  si
        ret

; ============================================================================
;  XSPLASH - three wireframe F15s out of the horizon, straight at you,
;  under a spooling turbine and the big title. Any key skips.
; ============================================================================
XSPLASH:
        ; BOND: ONE FRAME, THEN A WAIT. v3 flew the three-ship in over 72
        ; frames and read the keyboard once a frame - at 4.77 MHz a frame
        ; is a second or more, so the pilot sat through minutes of it and a
        ; key went unheard. The tick starts MID-FLIGHT (the jets whole, the
        ; title up), that one frame is drawn, and the loop below waits on
        ; the BIOS tick and the keyboard alone - 56 ticks, or any key.
        push es
        mov  word [cs:sptick],41 ; mid-flight: the three-ship whole, the
                                ;  title up (an odd tick: no speaker roar)
        mov  word [cs:sptc],70
.fr:   mov  al,UBLACK          ; a true black night
        call UCLS
        mov  bx,[bufseg]
        mov  es,bx
        ; ---- the three-ship: centre jet leads, wingmen trail ----
        mov  ax,[cs:sptick]
        mov  cx,70
        imul cx
        mov  bx,5200
        sub  bx,ax              ; lead z: 5200 -> 300
        cmp  bx,260
        jge  .z1
        mov  bx,260
.z1:   mov  [cs:ujz],bx
        mov  word [cs:ujx],0
        call UJET
        mov  ax,[cs:ujz]
        add  ax,600            ; the wingmen hang back
        mov  [cs:ujz],ax
        mov  word [cs:ujx],-1500
        call UJET
        mov  word [cs:ujx],1500
        call UJET
        ; ---- the title, once the jets are rolling in ----
        cmp  word [cs:sptick],18
        jb   .nt
        mov  word [ftx],64      ; 16 chars x 12 = 192 wide, centred on 160
        mov  word [fty],30
        mov  byte [COLOR],97
        mov  si,UTITLE
        call UBIG
        mov  word [ftx],124
        mov  word [fty],58
        mov  byte [COLOR],8
        mov  si,USUB
        call UFDRAW
.nt:   call UBLIT
        ; ---- the roar climbs with them ----

        cmp  byte [spkon],0
        je   .nsb
        mov  ax,[cs:sptick]     ; the same climb, on the one wave
        and  ax,3               ;  the speaker has
        jnz  .nsb
        inc  word [cs:sptc]
        cmp  word [cs:sptc],150
        jg   .nsb
        mov  ax,[cs:sptc]
        mov  bx,ax
        mov  cl,6               ; divisor 21500 - climb*64: a 55 Hz
        shl  bx,cl              ;  mutter spooling toward 100 Hz
        mov  ax,21500
        sub  ax,bx
        mov  bx,ax              ; PIT channel 2, inline: UISEG has
        mov  al,0B6h            ;  no near road to SPKOUT
        out  43h,al
        mov  al,bl
        out  42h,al
        mov  al,bh
        out  42h,al
        in   al,61h
        or   al,3
        out  61h,al
        jmp  .nsb
.nsb:  ; ---- pace on the BIOS tick, ~4 seconds, any key out ----
        push es
        mov  ax,40h
        mov  es,ax
.tw:   mov  ax,[es:6Ch]
        cmp  ax,[cs:uitick]
        je   .tw
        mov  [cs:uitick],ax
        pop  es
        call UANYK
        or   al,al
        jnz  .out
        inc  word [cs:sptick]
        cmp  word [cs:sptick],97 ; BOND: 41 + 56 ticks, about 3 s
        jb   .nsb              ;  ...and no redraw: back to the wait only
.out:  pop  es
        ret

; ---- UJET: one wireframe F15 at (ujx, ujz), model x24 ----------------------
; Every face's four edges through the plain gate: sx = 160 + X*220/z.
UJET:   push es
        mov  bx,[bufseg]
        mov  es,bx
        mov  byte [COLOR],8
        xor  si,si              ; face byte index
.f:    mov  al,[F15FC+si]      ; corner 0 opens the loop...
        call UJPRJ
        mov  ax,[cs:ujsx]
        mov  [cs:uilx1],ax
        mov  ax,[cs:ujsy]
        mov  [cs:uily1],ax
        mov  cx,4
        push si
.e:    mov  ax,[cs:uilx1]         ; previous corner becomes the tail
        mov  [cs:uilx0],ax
        mov  ax,[cs:uily1]
        mov  [cs:uily0],ax
        mov  di,4
        sub  di,cx              ; corner 1,2,3,0
        and  di,3
        inc  di
        and  di,3
        pop  si
        push si
        push cx
        mov  bx,si              ; 8086 has no [si+di]: fold by hand
        add  bx,di
        mov  al,[F15FC+bx]      ; corner (k+1) mod 4
        call UJPRJ
        pop  cx
        mov  ax,[cs:ujsx]
        mov  [cs:uilx1],ax
        mov  ax,[cs:ujsy]
        mov  [cs:uily1],ax
        push cx                 ; ULINE eats CL with its shifts - and
        push [cs:uilx0]            ; this loop LIVES on CX (the ninth
        push [cs:uily0]            ; integer trap: a clobbered counter
        push [cs:uilx1]            ; makes an immortal loop)
        push [cs:uily1]
        call ULINE
        pop  [cs:uily1]
        pop  [cs:uilx1]
        pop  [cs:uily0]
        pop  [cs:uilx0]
        pop  cx
        loop .e
        pop  si
        add  si,5
        cmp  si,F15NF*5
        jb   .f
        pop  es
        ret

; ---- UJPRJ: model corner AL -> screen (ujsx,ujsy) --------------------------
UJPRJ:  push si
        xor  ah,ah
        mov  si,ax
        add  si,ax
        add  si,ax
        add  si,si              ; *6
        mov  ax,[F15VT+si]      ; x*24 + jet offset
        mov  cx,24
        imul cx
        add  ax,[cs:ujx]
        mov  cx,220
        imul cx
        idiv word [cs:ujz]
        add  ax,160
        mov  [cs:ujsx],ax
        mov  ax,[F15VT+si+2]    ; y*24, a touch below centre
        mov  cx,24
        imul cx
        sub  ax,120
        mov  cx,220
        imul cx
        idiv word [cs:ujz]
        neg  ax
        add  ax,104
        mov  [cs:ujsy],ax
        pop  si
        ret

; ============================================================================
;  SPECTXTF - the caption over somebody else's fight.
;
;  It lives HERE and not with the rest of the spectator because of UBIG: the
;  double-size font reads its string out of its own code segment, so the
;  words have to sit beside it. That is also what makes the two big lines
;  cost nothing to draw at four pixels each - UBIG was written for the old
;  menu title and it outlived the menu.
;
;  WHITE, all of it. The keys were the panel's green and green is invisible
;  against grass - which is what most of this screen is, most of the time.
;  A caption laid over a live world cannot pick a colour that belongs to the
;  world. Only the invitation blinks; the keys are reference and reference
;  that flashes is just noise.
; ============================================================================
; Centred by hand, and UBIG steps TWELVE pixels a character, not eight - the
; glyph is six wide doubled, plus its gap doubled too. Centre = (320-n*12)/2.
; UFDRAW below still steps four.
SPBLP   = 73                  ; the invitation's cycle, in 18.2 Hz ticks:
SPBLON  = 55                  ;  55 lit is 3.0 s, the other 18 is 0.99 s
SPTITL  db 'HOLDING',0                ; 7  -> 118
SPJOIN  db 'PRESS ENTER TO JOIN',0    ; 19 ->  46
SPKEYS  db 'SPACE NEXT   ARROWS LOOK   Z X ZOOM',0  ; 35 at 4 px -> 90

SPECTXTF:
        cmp  byte [spect],0
        je   .sx
        mov  byte [COLOR],8
        mov  word [ftx],118
        mov  word [fty],10
        mov  si,SPTITL
        call UBIG
        ; ---- only the INVITATION blinks, and it breathes rather than
        ; flashes: three seconds lit, one dark. That is deliberately NOT a
        ; bit of the tick counter - a bit gives you equal halves and this
        ; wants three to one, so it is a real modulo. Cheap enough once a
        ; frame, and safe: lasttk over 73 cannot overflow a word.
        mov  ax,[lasttk]
        xor  dx,dx
        mov  bx,SPBLP
        div  bx
        cmp  dx,SPBLON
        jae  .sk               ; the dark second
        mov  byte [COLOR],8
        mov  word [ftx],46
        mov  word [fty],150
        mov  si,SPJOIN
        call UBIG
.sk:   mov  byte [COLOR],8
        mov  word [ftx],90
        mov  word [fty],172
        mov  si,SPKEYS
        call UFDRAW
.sx:   retf

; ============================================================================
;  XMENU - and there is no menu any more. It LISTENS instead of asking.
;
;  The sky list is gone: no rows to read, no C to create, no choosing
;  between rooms. There is ONE sky. Poll the wire for a couple of seconds -
;  every sky advertises itself once a second, so that is long enough to hear
;  one - and the first that answers is the one we join. Silence means nobody
;  is up, so we mint the sky ourselves. Either way the pilot pressed nothing.
;
;  Out, exactly as before, so OWLFLY3.ASM did not change: gact 2 = join, with
;  ggid and the seed adopted from the advertisement; gact 1 = create, and the
;  caller mints a fresh seed. The 270 lines of list, cursor, name entry and
;  bot toggle that used to live here are DELETED, not bypassed.
;
;  The bot war is now always on. That is not an oversight of removing the
;  toggle - it is what makes the arrival screen have a war on it. An empty
;  sky with nothing to watch is the thing this whole change exists to kill.
; ============================================================================
XLISTEN = 36                  ; BIOS ticks: two seconds, and ads are 1/s
WIREWT  = 270                 ; 15 s: how long a browser page may still be
                              ;  dialing the relay while we stand here

; ---------------------------------------------------------------------------
;  UWWAIT - THE WAITING LINE, AND THE ONE THING IT HAS TO DO IS MOVE.
;
;  After the splash this game can stand still for up to seventeen seconds:
;  fifteen at the address gate (WIREWT) while the wire hands out a node,
;  two more listening for a sky's advertisement (XLISTEN). Both are honest
;  waits and neither had anything alive on the glass. Worse, the one static
;  line the gate did print was written STRAIGHT AT 0A000h - so on a CGA,
;  EGA or Hercules card there was no line either, and a healthy boot was
;  indistinguishable from a hang. It was reported as one.
;
;  So: through the BACK BUFFER and UBLIT, like everything else the front
;  door draws, which makes it appear on every card the game supports; and
;  with the spinner every DOS program that ever waited for something had -
;  | / - \, a stroke turning a quarter clockwise a frame. A moving picture
;  is the whole message: this is working, keep sitting there.
;
;  One line for both waits on purpose. To the pilot they are one wait, and
;  a caption that changes halfway reads as something having gone wrong.
;  ES is preserved; AX/BX/CX/SI/DI are not.
; ---------------------------------------------------------------------------
UWPLX   = 128                 ; the plate: the words are 13 glyphs of 4
UWPLW   = 72                  ;  from 134, the spinner turns at 192
UWPLY   = 184                 ; four rows of headroom over the glyphs: the
UWPLH   = 14                  ;  splash's wireframe reaches down to here,
                                ;  and two stray dots left standing over the
                                ;  word read as dirt on the screen
UWSPC   = 192*320+192         ; the spinner's centre, as a buffer offset

UWWAIT: push es
        mov  ax,[bufseg]
        mov  es,ax
        mov  di,UWPLY*320+UWPLX ; blank the line's own plate first: the
        mov  bx,UWPLH           ;  stroke turns IN PLACE, and one drawn
        cld                     ;  over the last is a star, not a spinner
.rw:   mov  cx,UWPLW
        mov  al,UBLACK
        rep  stosb
        add  di,320-UWPLW
        dec  bx
        jnz  .rw
        mov  byte [COLOR],8
        mov  word [ftx],134
        mov  word [fty],190
        mov  si,UWDIAL
        call UFDRAW
        mov  si,[cs:uwsp]       ; the stroke: five dots along this
        inc  word [cs:uwsp]     ;  phase's direction, through the centre
        and  si,3
        add  si,si              ; two bytes a phase
        mov  al,[cs:UWSPD+si+1] ; dy first - a row is 320 bytes
        cbw
        mov  cx,320
        imul cx
        mov  bx,ax
        mov  al,[cs:UWSPD+si]   ; ...then dx
        cbw
        add  ax,bx
        mov  [cs:uwst],ax       ; one step of the stroke
        mov  di,UWSPC
        sub  di,ax              ; back up two steps: the dots run -2..+2
        sub  di,ax
        mov  cx,5
        mov  al,[COLOR]
.dt:   mov  [es:di],al
        add  di,[cs:uwst]
        loop .dt
        pop  es
        call UBLIT              ; ...and onto the glass, whatever card
        ret                     ;  this pilot picked

XMENU:  push es
        cmp  byte [netup],0     ; BOND: no wire at all (no IPX, or DOS 2) -
        jne  .wire             ;  no address to wait for and no sky to hear:
        mov  byte [gact],1      ;  mint our own at once, no DIALING spinner
        pop  es
        ret
.wire:
        ; ---- THE ADDRESS GATE (2026-08-25). Wait for the wire to hand
        ; out our node BEFORE minting a name or listening for ads: the
        ; page's websocket races the pilot through the front step, and
        ; the loser of that race used to become "pilot 1, sky 1" -
        ; invisible to every other fast starter, who was also pilot 1,
        ; and deaf through a listen window that closed on a dark wire.
        ; NETADDRF answers instantly on real iron and on a wire that is
        ; already up, so nobody waits who does not have to.
        push cx
        call SKYSEG:NETADDRF
        or   al,al
        jnz  .up0              ; the common case: no gate at all
        mov  word [cs:uwsp],0   ; the wait is real: say so on the glass,
        mov  cx,WIREWT          ;  and say it MOVING - see UWWAIT
.adr:  push cx
        call SKYSEG:NETADDRF
        pop  cx
        or   al,al
        jnz  .up               ; the node is real: mypid is reminted
        mov  ax,cx
        and  ax,3               ; the spinner steps four times a second.
        jnz  .anp              ;  Faster is a blur; slower is a thing
        push cx                ;  the pilot waits for, which is the one
        call UWWAIT            ;  feeling this screen must not create
        pop  cx
.anp:  push cx
        push es                 ; one-tick nap, the file's own idiom
        mov  ax,40h
        mov  es,ax
        mov  ax,[es:6Ch]
.np:   cmp  ax,[es:6Ch]
        je   .np
        pop  es
        pop  cx
        loop .adr
        jmp  .gap              ; capped out: the wire stays dark, solo
.up0:
.up:   mov  [netpid],dx        ; the caller's boot copy was minted
                                ;  BEFORE the wire answered - refresh
                                ;  it, or a created sky still flies
                                ;  under gid 1
.gap:  pop  cx
        push es                 ; when to stop listening
        mov  ax,40h
        mov  es,ax
        mov  ax,[es:6Ch]
        pop  es
        add  ax,XLISTEN
        mov  [uidl],ax
.lis:  call SKYSEG:NETPOLLF   ; the wire fills GLIST while we wait
        push es
        mov  ax,40h
        mov  es,ax
        mov  ax,[es:6Ch]
        pop  es
        cmp  ax,[cs:uitick]     ; the same spinner keeps turning through
        je   .lsn              ;  the listen window - to a pilot these
        mov  [cs:uitick],ax    ;  two seconds are the same wait, and a
        push ax                ;  caption that changed halfway would
        and  ax,3              ;  read as something going wrong
        jnz  .lsp
        call UWWAIT
.lsp:  pop  ax
.lsn:  sub  ax,[uidl]
        js   .lis              ; still listening
        ; ---- who answered? the first live row wins ----
        xor  si,si
.sc:   mov  bx,si
        mov  cl,4
        shl  bx,cl
        cmp  word [cs:GLIST+bx],0
        jne  .join
        inc  si
        cmp  si,NGL
        jb   .sc
        mov  byte [gact],1  ; nobody up: this sky is ours to mint
        pop  es
        ret
.join: mov  ax,word [cs:GLIST+bx]
        mov  [ggid],ax
        mov  ax,word [cs:GLIST+bx+2]
        mov  [rseed],ax
        mov  [wseed],ax
        mov  byte [gact],2
        pop  es
        ret

; ---- APPLYPALF: day or night. v3 streamed PALDAY or PALNITE into the
; DAC here; the BOND has no DAC to stream to - a CGA or Hercules card has
; none, and a VGA playing mode 4 routes the four colours through its own
; (PALDAY entry 0 once turned the sky grey). Day and night are the lookup
; bank the converter reads. The two palettes live on in
; GAMES\OWLFLY3\SRC\UI.INC, which TOOLS\VidRig reads to build VIDLUT.INC.
APPLYPALF:
        call VIDSEG:VPALSWF
        retf                     ; day/night switch on every card

; ============================================================================
;  MINIMAP2F - the half-scale baked map (32x32) on the MFD, evicted
;  from the main segment 2026-07-27: the stack guard fired when the
;  radar grew its SA symbology, and the map only plots pixels - no
;  near calls home - so it pays rent out here. White plane blip, red
;  course tick, the front line in red. ES = bufseg (the caller's).
; ============================================================================
UROWF:   ; SYMSEG draws on the same glass and needs
        call UROW               ; the same row arithmetic; a near call
        retf                     ; cannot cross a segment, six bytes can
MINIMAP2F:
        call MINIMAP2
        retf

; ---------------------------------------------------------------------------
;  MMSETUP - decide the window and build the two lookup tables the map and
;  everything drawn on it walk. Centres the window on the jet, in NODE
;  space, and lets it run off the world: every index is masked to 0..63, so
;  the map wraps and there is never a margin to leave grey. The tables live
;  in UISEG and are read with a CS override, which matters - the blit runs
;  with DS pointing at the far scratch segment where the baked map lives,
;  and could not reach a main-segment table at all.
; ---------------------------------------------------------------------------
MMSETUP:
        ; how many nodes the glass covers. On the whole-world step there is
        ; no window at all - the map IS the world, all 64 of it, and every
        ; mark on it is in view by definition.
        mov  cl,[mmzs]
        or   cl,cl
        jnz  .mz1
        mov  word [mmspx],64
        mov  word [mmspy],64
        xor  ax,ax
        mov  [mmcol0],ax
        mov  [mmrow0],ax
        jmp  .mtab
.mz1:  dec  cl                 ; steps 1..3 are 1, 2 and 4 pixels a node
        mov  ax,PZADIW
        shr  ax,cl
        mov  [mmspx],ax
        mov  bx,ax
        shr  bx,1
        mov  ax,[camx]          ; the jet's own node column
        add  ax,BIAS
        mov  cl,2
        shr  ax,cl
        mov  cl,8
        shr  ax,cl
        sub  ax,bx              ; ...half a window to its left
        and  ax,63
        mov  [mmcol0],ax
        mov  cl,[mmzs]
        dec  cl
        mov  ax,PZADIH
        shr  ax,cl
        mov  [mmspy],ax
        mov  bx,ax
        shr  bx,1
        mov  ax,[camz]
        add  ax,BIAS
        mov  cl,2
        shr  ax,cl
        mov  cl,8
        shr  ax,cl
        and  ax,63
        mov  dx,63
        sub  dx,ax              ; screen rows run south, the world runs north
        mov  ax,dx
        sub  ax,bx
        and  ax,63
        mov  [mmrow0],ax
        ; ---- dest column -> source node column
.mtab: xor  bx,bx              ; dest x
.ct:   mov  ax,bx
        call MMSCL
        add  ax,[mmcol0]
        and  ax,63
        mov  [cs:MMCOLT+bx],al
        inc  bx
        cmp  bx,PZADIW
        jb   .ct
        ; ---- dest row -> source ROW BASE (node row * 64), ready to index
        xor  bx,bx
.rt:   mov  ax,bx
        call MMSCL
        add  ax,[mmrow0]
        and  ax,63
        mov  cl,6
        shl  ax,cl              ; *64: the baked map is 64 bytes a row
        cmp  byte [mmzs],MMZALL
        jne  .rt1              ; the whole-world step reads the OTHER baked
        add  ax,MMWIDE          ; page, the one whose towns are cities. One
                                ; add, here, and the blit never learns of it
.rt1:  mov  si,bx
        add  si,si
        mov  [cs:MMROWT+si],ax
        inc  bx
        cmp  bx,PZADIH
        jb   .rt
        ret

; ---------------------------------------------------------------------------
;  MMSCL / MMSCLI - screen pixel <-> world node, at the current zoom step.
;  Step 0 is the odd one: four nodes to three pixels, so the whole 64-node
;  world lands on a 48-pixel side and the glass is filled by wrapping. The
;  rest are plain powers of two. Both directions live here so they cannot
;  disagree - the map is drawn through one and every mark on it through the
;  other, and a disagreement would float the marks off the ground.
;   MMSCL:  AX = pixel  -> AX = node offset
;   MMSCLI: AX = node   -> AX = pixel offset
; ---------------------------------------------------------------------------
MMSCL:  push cx
        mov  cl,[mmzs]
        or   cl,cl
        jnz  .s1
        mov  cx,4               ; *4/3
        imul cx
        mov  cx,3
        cwd
        idiv cx
        pop  cx
        ret
.s1:   dec  cl
        shr  ax,cl
        pop  cx
        ret
MMSCLI: push cx
        mov  cl,[mmzs]
        or   cl,cl
        jnz  .i1
        mov  cx,3               ; *3/4
        imul cx
        mov  cx,4
        cwd
        idiv cx
        pop  cx
        ret
.i1:   dec  cl
        shl  ax,cl
        pop  cx
        ret

; ---------------------------------------------------------------------------
;  MMPTX / MMPTY - one world node to its pixel on the map, or CARRY SET if
;  that node is not in the window. Every mark goes through these: the front
;  line, the two radar stations, the human nameplates and the jet's own
;  blip. They used to each do their own shift, and the day the scale changed
;  was the day they would have quietly drifted off the terrain.
;   in: AX = node column (MMPTX) or node row (MMPTY), 0..63
; ---------------------------------------------------------------------------
;  They PRESERVE CX. That is not politeness: the front line walks the glass
;  with CX as its column counter, and a helper that quietly loaded CL with a
;  shift count turned that loop into an infinite one.
MMPTX:  push cx
        sub  ax,[mmcol0]
        and  ax,63
        cmp  ax,[mmspx]
        jae  .xoff
        call MMSCLI
        add  ax,PZMMX
        pop  cx
        clc
        ret
.xoff: pop  cx
        stc
        ret
MMPTY:  push cx
        sub  ax,[mmrow0]
        and  ax,63
        cmp  ax,[mmspy]
        jae  .yoff
        call MMSCLI
        add  ax,PZMMY
        pop  cx
        clc
        ret
.yoff: pop  cx
        stc
        ret
; UROW - AX = row -> DI = row*320 (the main segment's ROW320, cloned:
; a near CALL cannot cross segments; nine bytes can)
UROW:   mov  di,ax
        mov  bx,ax
        mov  cl,8
        shl  di,cl
        mov  cl,6
        shl  bx,cl
        add  di,bx
        ret
MINIMAP2:
        cld
        call MMSETUP            ; window, zoom and the two lookup tables
        mov  ax,PZMMY
        call UROW
        add  di,PZMMX
        push ds                 ; the baked world lives in the far scratch
        mov  ax,[scrseg]        ; segment; the tables it is read through are
        mov  ds,ax              ; in UISEG and reached with CS:
        xor  dx,dx              ; dest row
.row:  mov  bx,dx
        add  bx,bx
        mov  si,[cs:MMROWT+bx]  ; this row's base in the baked map
        xor  cx,cx              ; dest column
.px:   mov  bx,cx
        mov  bl,[cs:MMCOLT+bx]
        xor  bh,bh
        mov  al,[si+bx]
        stosb
        inc  cx
        cmp  cx,PZADIW
        jb   .px
        add  di,320-PZADIW
        inc  dx
        cmp  dx,PZADIH
        jb   .row
        pop  ds
        ; the front line, half scale
        ; the front line, a pixel column at a time. The column table already
        ; says which world node each pixel shows, so the band comes straight
        ; off it - and the line wraps with everything else.
        xor  cx,cx
.bd2:  push cx                 ; CX is the column: nothing below may touch
        mov  bx,cx              ; it, and CL is a shift count twice over
        mov  bl,[cs:MMCOLT+bx]  ; the node under this pixel column
        xor  bh,bh
        shr  bx,1
        shr  bx,1               ; four nodes to a border band
        add  bx,bx
        mov  ax,[bordz+bx]
        add  ax,24576+BIAS
        mov  cl,10
        shr  ax,cl
        and  ax,63
        mov  bx,63
        sub  bx,ax
        mov  ax,bx
        call MMPTY
        pop  cx
        jc   .bdn              ; this stretch of the line is off the window
        push cx
        call UROW
        pop  cx
        add  di,PZMMX
        add  di,cx
        mov  al,19
        mov  [es:di],al
.bdn:  inc  cx
        cmp  cx,PZADIW
        jb   .bd2
        ; the jet's own blip. The window is centred on it, so this lands in
        ; the middle of the glass and stays there - the map moves under the
        ; aeroplane now, which is the whole point of a moving map.
        mov  ax,[camx]
        add  ax,BIAS
        mov  cl,2
        shr  ax,cl
        mov  cl,8
        shr  ax,cl
        and  ax,63
        call MMPTX
        jc   .nbl
        mov  bx,ax              ; the jet's own column
        mov  ax,[camz]
        add  ax,BIAS
        mov  cl,2
        shr  ax,cl
        mov  cl,8
        shr  ax,cl
        and  ax,63
        mov  dx,63
        sub  dx,ax              ; row = 63 - node z
        mov  ax,dx
        push bx
        call MMPTY
        pop  bx
        jc   .nbl
        push bx
        call UROW
        pop  bx
        add  di,bx
        mov  al,8               ; white blip. It was briefly an aeroplane at
        mov  [es:di],al         ;  the closest zoom, and went back: a blip
                                ;  with a course tick is the clearer thing
                                ;  to look for when what you want off a map
                                ;  is "where am I", not "what am I"
        ; course tick a couple of pixels up the nose - and it grows with the
        ; zoom, or at four pixels to a node it would sit inside the blip
        mov  cl,[mmzs]
        inc  cl
        mov  ax,[hsin]
        shl  ax,cl
        mov  bx,256
        cwd
        idiv bx
        mov  si,ax
        mov  cl,[mmzs]
        inc  cl
        mov  ax,[hcos]
        shl  ax,cl
        cwd
        idiv bx                 ; dz -> minus one row per unit (+Z is up)
        mov  cx,320
        imul cx
        mov  cx,ax
        mov  ax,si
        sub  ax,cx
        add  di,ax
        mov  al,19              ; red course tick
        mov  [es:di],al
.nbl:  ret

; ============================================================================
;  THE GROUND RADAR STATIONS, evicted to UISEG the day they were written:
;  the main segment had ~600 bytes left and the station code alone wanted
;  more. Only the MODELS and the state words stayed home (MODELDRAW reads
;  them with DS = the main segment); everything that only computes lives
;  out here and knocks on the four far doors in PLANES.INC when it needs
;  home. Far doors: RSTAINITF (once, after DSGEN), RSTADRAWF (per frame)
;  and RSBLIPF (the scope mark; the map mark rides out with MAPHUMF).
; ============================================================================
; ============================================================================
;  AFINITF - site the four aerodromes and FLATTEN THE GROUND UNDER THEM.
;
;  Runs ONCE, immediately after DSGEN and BEFORE anything is baked off the
;  heightmap - the block table and the minimap both read HMAP, and both have
;  to see the concrete. That ordering is the whole feature: flatten the
;  heightmap and the terrain mesh, TERRH, the road walk and the collision
;  test all agree about the strip with no special case in any of them.
;
;  The site is found the way a radar mast finds its site (FINDGND spirals out
;  until it is out of the sea and off the mountain), and then the height is
;  CLAMPED into the plains band. That second part is not tidiness: the city
;  zone is a band of heights, so a strip left at its natural height could be
;  zoned built-up and the town would plant houses down the runway. Clamped
;  low, the aerodrome cannot be a city block whatever the world does.
;
;  DS = the main segment (HMAP lives there and is written here).
; ============================================================================
AFSITX   dw 24576-4000, 24576-4000, 24576+4000, 24576+4000
AFSITZ   dw 24576-9500, 24576+9500, 24576-11500, 24576+11500

; ---- AFPATCH - judge one candidate patch, its top-left node in afcx/afcz.
; out: CF=1 the ground is impossible, else AX = the SPREAD of its heights.
; A strip does not want a legal point, it wants a legal PATCH: this is the
; whole difference from FINDGND, which asks whether ONE spot is out of the
; sea and searches +-200 world units for it - a fifth of a single node. It
; can step off a shoreline and nothing else. Measured over forty worlds, the
; fixed sites put a third of the aerodromes in the water or up a mountain.
AFPATCH:
        mov  byte [cs:aflo],255
        mov  byte [cs:afhi],0
        mov  word [cs:afu],0
.pu:   mov  word [cs:afv],0
.pv:   mov  ax,[cs:afcx]
        add  ax,[cs:afu]
        and  ax,63
        mov  cl,6
        shl  ax,cl
        mov  bx,ax
        mov  ax,[cs:afcz]
        add  ax,[cs:afv]
        and  ax,63
        add  bx,ax
        mov  al,[HMAP+bx]
        cmp  al,[cs:aflo]
        jae  .p1
        mov  [cs:aflo],al
.p1:   cmp  al,[cs:afhi]
        jbe  .p2
        mov  [cs:afhi],al
.p2:   inc  word [cs:afv]
        cmp  word [cs:afv],AFNL
        jb   .pv
        inc  word [cs:afu]
        cmp  word [cs:afu],AFNW
        jb   .pu
        mov  al,[cs:aflo]
        cmp  al,AFSEA
        jb   .pbad             ; a corner of it is in the water
        mov  al,[cs:afhi]
        cmp  al,AFTOP
        ja   .pbad             ; ...or up the mountain
        mov  al,[cs:afhi]
        sub  al,[cs:aflo]
        xor  ah,ah
        clc
        ret
.pbad: stc
        ret

AFINITF:
        mov  word [afi],0
.f:    mov  bx,[afi]
        add  bx,bx
        mov  ax,[cs:AFSITX+bx]  ; the nominal site, as a heightmap node
        add  ax,BIAS
        mov  cl,10
        shr  ax,cl
        mov  [cs:afnx],ax
        mov  ax,[cs:AFSITZ+bx]
        add  ax,BIAS
        mov  cl,10
        shr  ax,cl
        mov  [cs:afnz],ax
        ; ---- walk out in rings until the flattest legal patch is found.
        ; Flattest wins, plus the ring number: a patch one unit flatter is
        ; worth exactly one node of walking, so a field stays in the quarter
        ; of the map it was designed to hold. Over forty worlds this places
        ; all one hundred and sixty strips, mean ground spread nine units. ----
        mov  word [cs:afbest],7FFFh
        mov  word [cs:afr],0
.rr:   mov  ax,[cs:afr]
        neg  ax
        mov  [cs:afdu],ax
.ru:   mov  ax,[cs:afr]
        neg  ax
        mov  [cs:afdv],ax
.rv:   mov  ax,[cs:afdu]       ; a RING, not a square: |du| or |dv| is r
        or   ax,ax
        jns  .r1
        neg  ax
.r1:   mov  dx,[cs:afdv]
        or   dx,dx
        jns  .r2
        neg  dx
.r2:   cmp  ax,dx
        jae  .r3
        mov  ax,dx
.r3:   cmp  ax,[cs:afr]
        jne  .rn
        mov  ax,[cs:afnx]       ; the candidate's top-left node
        add  ax,[cs:afdu]
        sub  ax,AFNW/2
        mov  [cs:afcx],ax
        mov  ax,[cs:afnz]
        add  ax,[cs:afdv]
        sub  ax,AFNL/2
        mov  [cs:afcz],ax
        call AFPATCH
        jc   .rn
        add  ax,[cs:afr]        ; ...and the walk it cost to get here
        cmp  ax,[cs:afbest]
        jae  .rn
        mov  [cs:afbest],ax
        mov  ax,[cs:afnx]
        add  ax,[cs:afdu]
        mov  [cs:afbx],ax
        mov  ax,[cs:afnz]
        add  ax,[cs:afdv]
        mov  [cs:afbz],ax
.rn:   inc  word [cs:afdv]
        mov  ax,[cs:afr]
        cmp  [cs:afdv],ax
        jle  .rv
        inc  word [cs:afdu]
        mov  ax,[cs:afr]
        cmp  [cs:afdu],ax
        jle  .ru
        inc  word [cs:afr]
        cmp  word [cs:afr],AFREACH
        jbe  .rr
        ; ---- where that put it, in the world: the middle of the node ----
        mov  ax,[cs:afbx]
        and  ax,63
        mov  cl,10
        shl  ax,cl
        sub  ax,BIAS
        add  ax,512
        mov  [ctx],ax
        mov  ax,[cs:afbz]
        and  ax,63
        mov  cl,10
        shl  ax,cl
        sub  ax,BIAS
        add  ax,512
        mov  [ctz],ax
        mov  bx,[afi]
        add  bx,bx
        mov  ax,[ctx]
        mov  [afx+bx],ax
        mov  ax,[ctz]
        mov  [afz+bx],ax
        ; ---- the height every node of this strip will carry ----
        mov  ax,[cs:afbx]
        and  ax,63
        mov  cl,6
        shl  ax,cl              ; node row base
        mov  bx,ax
        mov  ax,[cs:afbz]
        and  ax,63
        add  bx,ax
        mov  al,[HMAP+bx]
        cmp  al,AFHLO
        jae  .h1
        mov  al,AFHLO
.h1:   cmp  al,AFHHI
        jbe  .h2
        mov  al,AFHHI
.h2:   mov  [cs:afh],al
        ; ---- STAMP AFSW x AFSL NODES FLAT - one node WIDER, on every side,
        ; than the patch that was judged. The two sizes are separate on
        ; purpose and the difference is the whole fix.
        ;
        ; TERRH does not read A node, it BILINEARLY INTERPOLATES the four
        ; nodes around the point - tta,tta+1 and ttb,ttb+1. Ironing exactly
        ; the judged patch left the node just past its edge untouched, so
        ; every height under the concrete was a blend of flat runway and
        ; whatever hill stood beyond it. The strip was never level: it read
        ; 250-odd on the altimeter where the stamped value says 140 at the
        ; very most, and it sloped. The far threshold was the worst of it -
        ; the strip is 3000 units long against a 1024-unit node, so its ends
        ; reach two nodes out from the centre and the interpolation there
        ; reached three.
        ;
        ; AFPATCH still scores AFNW x AFNL, so nothing about WHERE a field
        ; may stand has changed - ironing more ground is always safe, and it
        ; is only the judging that has to stay strict.
        mov  ax,[ctx]           ; the node the centre sits in
        add  ax,BIAS
        mov  cl,10
        shr  ax,cl
        mov  [cs:afnodx],ax
        mov  ax,[ctz]
        add  ax,BIAS
        mov  cl,10
        shr  ax,cl
        mov  [cs:afnodz],ax
        mov  word [cs:afu],0
.su:   mov  word [cs:afv],0
.sv:   mov  ax,[cs:afnodx]      ; the patch is centred on the node, so it
        add  ax,[cs:afu]       ;  reaches back as far as it reaches forward
        sub  ax,AFSW/2
        and  ax,63
        mov  cl,6
        shl  ax,cl
        mov  bx,ax
        mov  ax,[cs:afnodz]
        add  ax,[cs:afv]
        sub  ax,AFSL/2
        and  ax,63
        add  bx,ax
        mov  al,[cs:afh]
        mov  [HMAP+bx],al
        inc  word [cs:afv]
        cmp  word [cs:afv],AFSL
        jb   .sv
        inc  word [cs:afu]
        cmp  word [cs:afu],AFSW
        jb   .su
        ; ---- and the world height of the concrete, once it is flat ----
        push word [camx]
        push word [camz]
        mov  ax,[ctx]
        mov  [camx],ax
        mov  ax,[ctz]
        mov  [camz],ax
        call CODE:TERRHF
        pop  word [camz]
        pop  word [camx]
        mov  bx,[afi]
        add  bx,bx
        mov  [afy+bx],ax
        inc  word [afi]
        cmp  word [afi],NAF
        jb   .f
        retf
afh    db 0                    ; this strip's stamped heightmap value
afnodx   dw 0                    ; ...the node it is centred on...
afnodz   dw 0
afu    dw 0                    ; ...and the walk over its patch
afv    dw 0
afcx    dw 0                    ; AFPATCH's candidate, its top-left node...
afcz    dw 0
aflo    db 0                    ; ...and the range of ground it found there
afhi    db 0
afnx    dw 0                    ; the nominal node the ring walk starts from
afnz    dw 0
afbest  dw 0                    ; best score so far, and where it was
afbx    dw 0
afbz    dw 0
afr     dw 0                    ; the ring being walked, and the point on it
afdu    dw 0
afdv    dw 0

RSTAINITF:
        call RSTAINIT
        retf
RSTADRAWF:
        call RSTADRAW
        retf
RSBLIPF:
        call RSBLIP
        retf
RSHITF:
        call RSHIT
        retf
RSNOISF:
        call RSNOISE
        retf
RSLOCKF:
        call RSLOCK
        retf

; ---------------------------------------------------------------------------
;  RSTAINIT - plant the two ground radar stations. Both stand on the
;  map's north-south spine (x = 24576, where the squadrons form up):
;  OURS 7000 south of the border, THEIRS 7000 north of it - deep in the
;  rear, past the tanker's lane, so reaching the enemy's is a sortie and
;  defending ours is a job. Runs after DSGEN: it needs the heightmap.
; ---------------------------------------------------------------------------
RSTAINIT:
        mov  word [rs_i],0
.s:    mov  bx,[rs_i]
        mov  byte [rsst+bx],0
        mov  byte [rshp+bx],RSHITS
        add  bx,bx              ; word index
        ; ---- THE RADAR STANDS ON THE AERODROME. It used to be planted on
        ; the spine at its own fixed offset, 7000 back from the line, which
        ; put the two of them in unrelated fields - and a mast in the middle
        ; of nowhere is not what a radar is. A station belongs to an air
        ; base: same apron, same defences, one thing to find and one thing
        ; to lose. The dependency runs THIS way round because the strip is
        ; the fussy one - it has to walk until it finds ground flat enough
        ; to land on, and the mast does not care what it stands on. So the
        ; strip chooses, and the mast follows it out. Station 0 is ours and
        ; so is field 0; 1 is theirs and so is field 1 - the same parity
        ; that carries IFF everywhere else lines them up for free. ----
        mov  ax,[afx+bx]
        add  ax,RSAPRON         ; beside the concrete, not on it
        mov  [rsx+bx],ax
        mov  ax,[afz+bx]
        mov  [rsz+bx],ax
        call RSTAGND
        inc  word [rs_i]
        cmp  word [rs_i],NRSTA
        jb   .s
        mov  word [rspin],0
        ret

; ---------------------------------------------------------------------------
;  RSTAGND - a radar wants a hilltop, not a beach. Probe eight spots at
;  1024 apart along the station's own east-west line and keep the highest
;  ground: on an island world that also keeps it out of the sea (WORLDH
;  clamps water to 0). in/out: [rs_i] = station; writes rsx and rsy.
; ---------------------------------------------------------------------------
RSTAGND:
        mov  bx,[rs_i]
        add  bx,bx
        mov  ax,[rsx+bx]
        mov  [ctx],ax
        mov  ax,[rsz+bx]
        mov  [ctz],ax
        call FINDGND            ; the same rule the batteries follow: a mast
        mov  bx,[rs_i]           ; standing in the sea was the old behaviour
        add  bx,bx
        mov  [rsy+bx],ax
        mov  ax,[ctx]
        mov  [rsx+bx],ax
        mov  ax,[ctz]
        mov  [rsz+bx],ax
        ret

; ---------------------------------------------------------------------------
;  RSTADRAW - the standing stations: the lattice tower welded to the
;  ground (its model yaw is simply minus ours) and the dish on top at the
;  spin angle. Two MODELDRAW calls each, drawn after the buildings so the
;  jets and the burning debris paint over them. ES=bufseg.
; ---------------------------------------------------------------------------
RSTADRAW:
        mov  word [rs_i],0
.st:   mov  bx,[rs_i]
        cmp  byte [rsst+bx],0
        jne  .nx               ; down: the wreck pool has it now
        add  bx,bx
        mov  ax,[rsx+bx]
        sub  ax,[camx]
        mov  [wdx],ax
        mov  ax,[rsz+bx]
        sub  ax,[camz]
        mov  [wdz],ax
        mov  ax,[wdx]           ; the jets' own world-space box reject
        jns  .q1
        neg  ax
.q1:   cmp  ax,BONDLSH 
        jge  .nx
        mov  ax,[wdz]
        jns  .q2
        neg  ax
.q2:   cmp  ax,BONDLSH 
        jge  .nx
        call CODE:ROTXZF
        mov  ax,[rc_z]
        cmp  ax,-100
        jl   .nx               ; behind us
        cmp  ax,BONDLSH 
        jge  .nx               ; past the leash
        mov  [pdz],ax
        mov  ax,[rc_x]
        mov  [pdx],ax
        mov  bx,[rs_i]
        add  bx,bx
        mov  ax,[rsy+bx]
        sub  ax,[camy]
        mov  [pdy],ax
        jmp  .bmark             ; BOND: no models - the marker IS the station
                                ;  (it still transmits: the radar picture and
                                ;  the AI's eyes come from it; 130 ms a frame)
.bmark: mov  bx,[rs_i]           ; RELOAD it: MODELDRAW clobbers BX, and this
        add  bx,bx              ; read the station's height through whatever
        mov  ax,[rsy+bx]        ; was left in it - which is why the marker
        add  ax,RSTOP/2         ; jumped above and below the mast instead of
        sub  ax,[camy]          ; sitting on the dish
        mov  [pdy],ax
        mov  byte [COLOR],95
        mov  byte [gmks],0
        cmp  word [rs_i],0
        je   .nmk
        mov  byte [COLOR],96
        mov  byte [gmks],1
.nmk:  mov  ax,[rs_i]           ; and RED once it is the locked one - the
        add  ax,ax              ; world's own language, which the ground
        add  ax,RSLK            ; now speaks too: green ours, yellow theirs,
        cmp  ax,[locki]         ; red the one you have
        jne  .nmk2
        mov  byte [COLOR],19
.nmk2: mov  word [gmkn],14000
        call SYMSEG:GNDMARKF
.nx:   inc  word [rs_i]
        cmp  word [rs_i],NRSTA
        jb   .st
        ret

; ---------------------------------------------------------------------------
;  RSBLIP - the stations on the cockpit scope, and they are NOT aircraft:
;  a CROSS WITH A HOLE (centre dot plus four arms two pixels out) in the
;  owner's colour - green ours, yellow theirs. No velocity stub, because
;  it does not fly; no blink, because it is not a warning; and nothing at
;  all once it is down, since a wrecked antenna returns no echo. The
;  shape cannot be read as a jet: friends are 3x3 squares, hostiles are
;  four-point diamonds, and both of those are solid where this has a gap.
;  Rides RBLIPS' own frame ([rbcx]/[rbcy]/[rbsh]), so it lands on the
;  radar and on the SIT page alike. ES = bufseg.
; ---------------------------------------------------------------------------
RSBLIP: mov  word [rs_i],0
.l:    mov  bx,[rs_i]
        cmp  byte [rsst+bx],0
        jne  .n                ; a dead station paints no return
        add  bx,bx
        mov  ax,[rsx+bx]
        sub  ax,[camx]
        mov  [wdx],ax
        mov  ax,[rsz+bx]
        sub  ax,[camz]
        mov  [wdz],ax
        call CODE:ROTXZF   ; rc_x = right of the nose, rc_z = ahead
        mov  cl,[rbsh]          ; the scope's live zoom, then a pixel clip
        mov  ax,[rc_x]           ; (12, not 14: the arms need the margin)
        sar  ax,cl
        cmp  ax,[rbrad]
        jg   .n
        cmp  ax,[rbradn]
        jl   .n
        mov  bx,[rc_z]
        sar  bx,cl
        cmp  bx,[rbrad]
        jg   .n
        cmp  bx,[rbradn]
        jl   .n
        add  ax,[rbcx]
        mov  [bqx],ax
        mov  ax,[rbcy]
        sub  ax,bx              ; ahead = up the screen
        mov  [bqy],ax
        mov  al,95              ; ours green, theirs RED - the same two
        cmp  word [rs_i],0   ; colours the whole scope speaks now
        je   .c
        mov  al,19
.c:    mov  [COLOR],al
        call SYMSEG:BQSTAF   ; the lozenge with a dish, and it never turns
.n:    inc  word [rs_i]
        cmp  word [rs_i],NRSTA
        jb   .l
        ret

; ---------------------------------------------------------------------------
;  RSNOISE - what the scope shows once OUR station is rubble: snow over
;  the glass and NO RADAR across it. 150 dots of static in two greys,
;  reseeded every BIOS tick so it crawls, scattered inside the same
;  +-13 px the blips used; the seed is nudged by [rbcx] so the radar and
;  the SIT page do not show the identical storm. Takes RBLIPS' place
;  entirely - a blind set draws no returns, not even the stations.
; ---------------------------------------------------------------------------
RSNOISE:
        mov  ax,[lasttk]
        add  ax,[rbcx]
        or   ax,1
        mov  [tmpi],ax          ; the walking seed
        mov  word [tpi],0
        ; The snow fills whatever the scope's reach is. It used to be a
        ; fixed +/-13 box, which on this screen would leave a clean border
        ; of glass around the interference - and a radar that is out does
        ; not politely stay off the edges.
.d:    call RSRND              ; a column...
        mov  cl,3
        shr  ax,cl
        and  ax,63
        imul word [rbrad]
        mov  cl,5
        sar  ax,cl              ; 0..63 -> 0..2*rbrad
        sub  ax,[rbrad]
        add  ax,[rbcx]
        mov  [dsx],ax
        call RSRND              ; ...and a row
        mov  cl,3
        shr  ax,cl
        and  ax,63
        imul word [rbrad]
        mov  cl,5
        sar  ax,cl
        sub  ax,[rbrad]
        add  ax,[rbcy]
        call UROW
        add  di,[dsx]
        call RSRND              ; two greys: dim static with a spark in it
        mov  al,30
        test ah,4
        jz   .c
        mov  al,8
.c:    mov  [es:di],al
        inc  word [tpi]
        cmp  word [tpi],150
        jb   .d
        mov  byte [COLOR],19 ; and the word for it, in red
        mov  ax,[rbcx]
        sub  ax,16
        mov  [ftx],ax
        mov  ax,[rbcy]
        sub  ax,3
        mov  [fty],ax
        mov  si,MSGNORAD
        call CODE:FDRAWF
        ret
; RSRND - the snow's own LCG on [tmpi] (the scope's scratch word)
RSRND:  mov  ax,[tmpi]
        mov  bx,25173
        imul bx
        add  ax,13849
        mov  [tmpi],ax
        ret

; ---------------------------------------------------------------------------
;  RSLOCK - the second half of the ENTER lock scan: the stations. Runs
;  after the jets and plays by the same rule - inside 24 px of the ring
;  centre, NEAREST WINS - so it competes with the traffic honestly and a
;  jet crossing in front of the antenna still takes the lock. A station
;  is aimed at half its height, which is where the dish is. The winner
;  goes into locki as RSLK + index*2. Reads/writes [lockd] like the jet
;  loop above it. ES is whatever INPUT had; we only compute here.
; ---------------------------------------------------------------------------
RSLOCK: mov  word [rs_i],0
.l:    mov  bx,[rs_i]
        cmp  byte [rsst+bx],0
        jne  .n                ; rubble locks nothing
        add  bx,bx
        mov  ax,[rsx+bx]
        sub  ax,[camx]
        mov  [wdx],ax
        mov  ax,[rsz+bx]
        sub  ax,[camz]
        mov  [wdz],ax
        call CODE:ROTXZF
        mov  ax,[rc_z]
        cmp  ax,NEARZ
        jl   .n
        mov  [tpi],ax           ; the range, for the nearest-wins test
        mov  bx,[rs_i]
        add  bx,bx
        mov  dx,[rsy+bx]
        add  dx,RSTOP/2
        sub  dx,[camy]
        mov  ax,[rc_x]
        mov  cx,[rc_z]
        call CODE:PPOINTF
        jc   .n
        sub  ax,160
        jns  .k1
        neg  ax
.k1:   cmp  ax,24
        jg   .n
        sub  dx,[horiz]         ; the ring sits on the glass, not the screen
        jns  .k2
        neg  dx
.k2:   cmp  dx,24
        jg   .n
        mov  ax,[tpi]
        cmp  ax,[lockd]
        jae  .n
        mov  [lockd],ax
        mov  ax,[rs_i]
        add  ax,ax
        add  ax,RSLK
        mov  [locki],ax
.n:    inc  word [rs_i]
        cmp  word [rs_i],NRSTA
        jb   .l
        ret

; ---------------------------------------------------------------------------
;  RSHIT - did something of ours land on a station? in: rhx/rhy/rhz = the
;  point in the world, rhdmg = what it is worth (1 a cannon shell, 4 a
;  missile). out: AX = 1 if a STANDING station took it, and it took the
;  damage with it; AX = 0 if the shot flew past. A box test, not a mesh
;  one: a lattice tower is mostly air and hunting its facets with an
;  8086 would be a joke. No friendly-fire guard - shells do not read the
;  IFF, and a pilot who strafes his own antenna has earned the snow.
; ---------------------------------------------------------------------------
RSHIT:  mov  word [rs_i],0
.l:    mov  bx,[rs_i]
        cmp  byte [rsst+bx],0
        jne  .n                ; already a ruin: nothing left to break
        add  bx,bx
        mov  ax,[rhx]
        sub  ax,[rsx+bx]
        jns  .a1
        neg  ax
.a1:   cmp  ax,RSRAD
        jge  .n
        mov  ax,[rhz]
        sub  ax,[rsz+bx]
        jns  .a2
        neg  ax
.a2:   cmp  ax,RSRAD
        jge  .n
        mov  ax,[rhy]
        sub  ax,[rsy+bx]        ; height above its own feet
        js   .n                ; underground: the terrain ate it
        cmp  ax,RSTOP
        jg   .n                ; over the dish
        call RSDAM
        mov  ax,1
        ret
.n:    inc  word [rs_i]
        cmp  word [rs_i],NRSTA
        jb   .l
        xor  ax,ax
        ret

; ---------------------------------------------------------------------------
;  RSDAM - one hit on station [rs_i]. The last one takes it down: the
;  state word flips, and the wreck pool gets it through WRKATF - the
;  same eight tumbling slabs, fire, smoke and distance-scaled bang that
;  a falling building gets, in scheme 0 so the debris is grey steel.
; ---------------------------------------------------------------------------
RSDAM:  mov  bx,[rs_i]
        mov  al,[rshp+bx]
        sub  al,[rhdmg]
        jbe  .dead
        mov  [rshp+bx],al
        ret
.dead: mov  byte [rshp+bx],0
        mov  byte [rsst+bx],1
        mov  al,bl              ; and tell the wire: one shot, next tick
        inc  al
        mov  [rsnet],al
        add  bx,bx
        mov  ax,bx              ; a lock on rubble is no lock
        add  ax,RSLK
        cmp  ax,[locki]
        jne  .nolk
        mov  word [locki],0FFFFh
.nolk:
        mov  ax,[rsx+bx]
        mov  [bpx],ax
        mov  ax,[rsz+bx]
        mov  [bpz],ax
        mov  word [bschm],0 ; grey walls: steel, not brick
        call CODE:WRKATF
        ret

; ---------------------------------------------------------------------------
;  RSMAP - the stations on the centre MFD map, so you can see what you are
;  defending without hunting for it. Same cross, one pixel across at this
;  scale, in the owner's colour; a station that is DOWN stays on the map
;  in trim grey - the ruin is information too. No clipping: both stations
;  are planted at fixed coordinates that land well inside the 32x32 glass
;  (rows 167..174, columns 158..162), and RSTAINIT is what keeps it so.
; ---------------------------------------------------------------------------
RSMAP:  mov  word [rs_i],0
.l:    mov  bx,[rs_i]
        mov  al,95
        or   bx,bx
        jz   .c1
        mov  al,19              ; theirs: red, like everywhere else now
.c1:   cmp  byte [rsst+bx],0
        je   .c2
        mov  al,30              ; a ruin: grey, and still worth knowing
.c2:   push ax
        add  bx,bx
        mov  ax,[rsx+bx]        ; the map's own arithmetic, shared
        add  ax,BIAS
        mov  cl,10
        shr  ax,cl
        and  ax,63
        call MMPTX
        jc   .nx
        mov  dx,ax
        mov  ax,[rsz+bx]
        add  ax,BIAS
        mov  cl,10
        shr  ax,cl
        and  ax,63
        mov  bx,63
        sub  bx,ax              ; row = 63 - node z
        mov  ax,bx
        push dx
        call MMPTY
        pop  dx
        jc   .nx
        mov  [cs:mprow],ax      ; the symbol wants the row, UROW eats it
        call UROW
        add  di,dx
        pop  ax
        cmp  byte [mmzs],MMZICO
        jb   .cr               ; wound out: the plus sign, as before
        mov  [COLOR],al         ; close in: the mast and its dish, the same
        mov  [bqx],dx           ; picture the scope draws
        mov  ax,[cs:mprow]
        mov  [bqy],ax
        call SYMSEG:BQSTAF
        jmp  .nn
.cr:   mov  [es:di],al
        mov  [es:di-320],al
        mov  [es:di+320],al
        mov  [es:di-1],al
        mov  [es:di+1],al
        jmp  .nn
.nx:   pop  ax                 ; this station is off the window: keep the
.nn:   inc  word [rs_i]     ; stack straight and move to the next
        cmp  word [rs_i],NRSTA
        jb   .l
        ret

; ---------------------------------------------------------------------------
;  THE CABIN'S INSTRUMENTS (2026-08-27). Drawn OVER the blitted artwork,
;  ES = the back buffer. The zones were measured off shilka_art.bmp once -
;  the cabin is committed art, the numbers move with it if it ever does:
;    red screen    39..84  x 122..159   the tactical map (a 46x38 node
;                                       window of the baked 64x64 world)
;    green screen 125..194 x 108..167   the ROUND RADAR: a sweeping beam
;                                       off the dish bearing, blips for
;                                       every living aircraft
;    grey screen  235..278 x 122..159   status: fuel, ammo, magazines,
;                                       damage - the vehicle's own
;    digit plates y179..187             AZIMUTH / ELEVATION / RANGE
;    lamp strip   y9..11, 4px each      PWR RADAR READY FIRE  TRACK WARN
;                                       LOCK ENG
; ---------------------------------------------------------------------------
SZMAPX  = 39                  ; the red screen
SZMAPY  = 122
SZMAPW  = 46
SZMAPH  = 38
SZRDCX  = 159                 ; the green scope's centre and radius
SZRDCY  = 137
SZRDR   = 27
SZSTX   = 238                 ; the status screen's text column
SZSTY   = 125
RDRRNG  = 9                   ; blip scale: world units >> 9 = pixels,
                                ;  so the 27-px radius reads ~13800 units -
                                ;  SHKGRNG sits a third of the way out
LMPY    = 9                   ; the lamp strip
LMPON   = 110                 ; a green system speaking (PNLGRN)
LMPRED  = 19                  ; a red one
LMPOFF  = 33                  ; a lamp with nothing to say

; ---------------------------------------------------------------------------
;  SHKGND - a gun wants ground, not sea. Probe eight spots 128 apart along
;  this vehicle's east-west line and keep the HIGHEST: on an island world
;  that also keeps it dry, since WORLDH clamps water to 0. The same trick
;  RSTAGND plays for the stations, at an EIGHTH of the spacing. That is
;  deliberate: a station may hunt four thousand units for a hilltop because
;  nobody has to find it again, but a battery that teleports 130 m off its
;  post is not covering anything, and the pilot who put it there should be
;  able to find his own flak. +/-512 is under six vehicle lengths.
;  in/out: [cs:shki] = the vehicle; writes shkx and shky.
; ---------------------------------------------------------------------------
; ---------------------------------------------------------------------------
;  FINDGND - walk out from a nominal spot until the ground is worth standing
;  on: out of the water, off the mountain. Sixteen candidates on a widening
;  ring, and it keeps the BEST one it saw rather than the first, so a site
;  lands on a rise instead of the first patch of legal dirt.
;   in:  [ctx]/[ctz] the nominal spot
;   out: [ctx]/[ctz] moved to the chosen spot, AX = its height,
;        CF set if nothing legal was found at all (open sea).
; ---------------------------------------------------------------------------
FINDGND:
        mov  ax,[ctx]
        mov  [cs:shkb],ax       ; the nominal centre, kept
        mov  ax,[ctz]
        mov  [cs:shkc],ax
        mov  word [cs:shkq],0       ; best height so far (0 = none)
        mov  word [cs:shkp],0       ; ring step
.fr:   mov  word [cs:shke],0       ; the eight points of this ring
.fp:   mov  ax,[cs:shke]       ; a crude compass: dx and dz from a 3x3 box
        and  ax,3
        dec  ax                 ; -1, 0, 1, 2 -> use -1..1
        cmp  ax,2
        jne  .f1
        xor  ax,ax
.f1:   mov  dx,[cs:shkp]
        inc  dx
        imul dx
        mov  cx,10
        imul cx                 ; step out 10 world units per ring per unit
        mov  bx,ax
        mov  ax,[cs:shke]
        mov  cl,2
        shr  ax,cl
        and  ax,3
        dec  ax
        cmp  ax,2
        jne  .f2
        xor  ax,ax
.f2:   mov  dx,[cs:shkp]
        inc  dx
        imul dx
        mov  cx,10
        imul cx
        push ax                 ; dz
        mov  ax,[cs:shkb]
        add  ax,bx
        mov  [ctx],ax
        pop  ax
        add  ax,[cs:shkc]
        mov  [ctz],ax
        push word [camx]    ; TERRH reads the camera position
        push word [camz]
        mov  ax,[ctx]
        mov  [camx],ax
        mov  ax,[ctz]
        mov  [camz],ax
        call CODE:TERRHF
        pop  word [camz]
        pop  word [camx]
        cmp  ax,GNDLO
        jb   .fn               ; in the sea
        cmp  ax,GNDHI
        ja   .fn               ; up the mountain
        cmp  ax,[cs:shkq]
        jbe  .fn
        mov  [cs:shkq],ax       ; the best legal ground so far
        mov  ax,[ctx]
        mov  [cs:shkg],ax
        mov  ax,[ctz]
        mov  [cs:shkv],ax
.fn:   inc  word [cs:shke]
        cmp  word [cs:shke],16
        jb   .fp
        cmp  word [cs:shkq],0
        jne  .fd               ; found something on this ring: stop widening
        inc  word [cs:shkp]
        cmp  word [cs:shkp],40      ; out to 400 units a step, 16 tries
        jb   .fr
        mov  ax,[cs:shkb]       ; nothing legal anywhere near: leave it where
        mov  [ctx],ax           ; it was and say so
        mov  ax,[cs:shkc]
        mov  [ctz],ax
        xor  ax,ax
        stc
        ret
.fd:   mov  ax,[cs:shkg]
        mov  [ctx],ax
        mov  ax,[cs:shkv]
        mov  [ctz],ax
        mov  ax,[cs:shkq]
        clc
        ret

; ============================================================================
;  MAPHUM followed MINIMAP2F out here (2026-07-28, the radar stations):
;  it draws ON that map and only plots glyphs, so it belongs beside it.
;  Far door: MAPHUMF. FDRAW stayed home behind FDRAWF - the strings and
;  NB it reads are main-segment bytes and DS is the main segment here.
; ============================================================================
MAPHUMF:
        ; The TRAFFIC is deliberately not here. Aeroplane symbols were drawn
        ; on this map for a day and taken off again: the map answers "what
        ; is on the ground and where am I over it", and the scope beside it
        ; already answers "who is in the air". Two instruments saying the
        ; same thing is one instrument's worth of information and two
        ; instruments' worth of clutter. Ground only: the baked city, the
        ; batteries and the stations.
        call MAPHUM
        call RSMAP              ; the two stations, on the same glass
        retf
; ============================================================================
;  MAPHUM - the humans on the centre map: callsign letter + altitude
;  digit (thousands) at their node, white, over the half-scale map at
;  (144,155). ES=bufseg, DS=CS.
; ============================================================================
MAPHUM: xor  si,si
.mh:   mov  bx,si
        shr  bx,1
        cmp  byte [premote+bx],0
        je   .mhn
        cmp  byte [pst+bx],0
        jne  .mhn
        mov  al,[pltr+bx]
        or   al,al
        jz   .mhn
        mov  [NB],al
        mov  ax,[pay+si]        ; the altitude digit, thousands
        or   ax,ax
        jns  .mhp
        xor  ax,ax
.mhp:  xor  dx,dx
        mov  bx,1000
        div  bx
        cmp  ax,9
        jbe  .mhd
        mov  ax,9
.mhd:  add  al,'0'
        mov  [NB+1],al
        mov  byte [NB+2],0
        mov  ax,[pax+si]        ; the map's own arithmetic, shared
        add  ax,BIAS
        mov  cl,10
        shr  ax,cl
        and  ax,63
        call MMPTX
        jc   .mhn              ; this pilot is off the window
        dec  ax
        mov  [ftx],ax
        mov  ax,[paz+si]
        add  ax,BIAS
        mov  cl,10
        shr  ax,cl
        and  ax,63
        mov  bx,63
        sub  bx,ax
        mov  ax,bx
        call MMPTY
        jc   .mhn
        mov  bx,ax
        sub  bx,3               ; centre the glyph rows on the node...
        cmp  bx,PZMMY
        jge  .mhy
        mov  bx,PZMMY           ; ...but keep it inside the MFD glass
.mhy:  cmp  bx,PZMMY+PZADIH-6
        jle  .mhz
        mov  bx,PZMMY+PZADIH-6
.mhz:  mov  [fty],bx
        mov  byte [COLOR],8
        push si
        mov  si,NB
        call CODE:FDRAWF
        pop  si
.mhn:  add  si,2
        cmp  si,NPLANE*2
        jb   .mh
        ret

; (MAPJETS lived here for one afternoon: the traffic drawn on the map as
;  aeroplane symbols, north-up. It came off again - see the note in
;  MAPHUMF. The scope carries the air picture; this glass carries the
;  ground. The symbols themselves were fine and are still on the scope.)

STATPGF:
        call STATPG
        call WARNLMP            ; ...and the overhead lamps, on the same trip
        call SIDEPNL            ; out, the two word columns beside them,
        call OSBLAMP            ; and the six lamp columns by the screens.
        call NETLAMP            ; ...and the WIRE, in the overhead plate
        retf                     ; A far door apiece would have cost five

; ===========================================================================
;  SIDEPNL - the two ANNUNCIATOR COLUMNS, in whole words.
;
;  They used to be four blinking single letters, F L S T, because the slot
;  was written down as 16 px wide. It is not: 16 px is the bezel, and the
;  black plate inside it runs x 10..32 on the left and 286..308 on the
;  right - 23 px both, which is FIVE characters of this font with a pixel
;  to spare. So STALL is STALL now, and FLAPS is FLAPS.
;
;  Every caption is always readable, dark grey, the way a real annunciator
;  is a printed legend that happens to light up. When its condition comes
;  true it goes to colour and BLINKS, so the eye is caught by the change
;  and not asked to notice an absence.
;
;  LEFT is what the pilot has DONE - the things hanging in the airstream,
;  green when they are out. RIGHT is what the aeroplane has to SAY - the
;  warnings, red, except the target call which is only ever information.
;   ES = bufseg, DS = the main segment (UISEG's own words take cs:).
; ===========================================================================
SPNX    dw 10,286               ; the two black plates inside their bezels
SPPLW   = 23                  ; ...and how wide they are
SPSY0   = 129                 ; first slot's top row; five of them
SPSH    = 10                  ; ...pitch...
SPFH    = 9                   ; ...how much of that is the lit plate...
SPTY    = 2                   ; ...and the word's own row inside it, so
                                ;  the legend is centred DOWN the slot as
                                ;  well as across it
SPNY0   = 129                 ; the plate's own top and bottom, for the
SPNY1   = 180                 ;  speckle that goes down before the words
SPDARK  = PNLDIM              ; the panel's own set, defined once in
SPGRN   = PNLGRN              ;  DATA.INC beside the zone constants so
SPAMB   = PNLAMB              ;  both segments read the same numbers
SPRED   = PNLRED
; NUL padding, not spaces, so a word can be MEASURED and centred. Five
; letters fill the plate exactly; a four-letter one used to start at the
; same x and sat two pixels left of where it belonged.
SPTXT   db 'FLAPS',0,'GEAR',0,0,'BRAKE',0,'BURN',0,0,0,0,0,0,0,0
        db 'STALL',0,'FUEL',0,0,'TERR',0,0,'FIRE',0,0,'LOCK',0,0
; ---- TEN LAMPS, TEN BULBS. --------------------------------------------
; They used to wink off one bit of the tick counter, all ten together, and
; the note beside PNLBLNK said that was deliberate: "two rates would be
; chaos". It is the right instinct about RATES and the wrong one about
; LAMPS. Ten things moving in perfect lockstep do not read as ten lamps,
; they read as one timer driving ten holes - which is exactly what it was.
; A real annunciator has ten independent bulbs behind ten independent
; relays, and no two of them have ever agreed about anything.
;
; So each slot gets its own phase and its own period, and the spread is
; deliberately narrow - this is meant to read as bulbs that do not agree,
; not as a christmas tree. Most sit on the old 8 (about a second); three
; are on 16, which is half the rate and reads as a slower, heavier lamp.
; The phases are spread WITHIN each column, not across all ten - the two
; columns are at opposite edges of the screen and never share a glance, so
; what matters is that no lamp agrees with the ones it sits next to. Left
; column is 0..3, right is 5..9; the slow ones spread over 32 instead of 16.
SPBPH   db 0,4,20,12,0,2,9,6,14,25 ; phase offset, in ticks
SPBMK   db 8,8,16,8,8,8,16,8,8,16  ; which bit of the tick: the period
; ---- and they are not all the same BRIGHTNESS either. The palette already
; carries this: PNLBAND is the "hair darker than the core" shade of each
; lamp colour, cut for the scanline banding that was tried and dropped. It
; is the same hue one step down, which is precisely a bulb that has been in
; longer than its neighbour. Zero is full, PNLBAND is tired.
SPBDIM  db 0,PNLBAND,0,PNLBAND,0,PNLBAND,0,0,PNLBAND,0
; ---- the bottom switch row: the three radios ------------------------------
; The artwork's buttons are ~11 px of black between bright dividers at
; x 53/65/76/88/99/111. Three characters ink eleven pixels, which FILLS a
; button - tried it on three neighbouring plates and the row read as one
; word, GNDAIRIFF, exactly the way the overhead captions did at three
; letters. So they sit on every OTHER button: a whole empty plate between
; words, thirteen clear pixels, and the three spare buttons are there for
; the next three switches anyway.
; Green when the box is up, panel grey when it is not, so the row reads as
; a state and not as a legend.
; Twelve buttons, six a side. The left row is the up-front control panel -
; the radios, the beacon, the transponder and the master mode; the right is
; the self-protection suite. Two of them are not toggles at all: A-A and
; A-G are one mode switch shown on two plates, so exactly one is ever lit.
; The plates, measured off the artwork's own dividers. Left row starts at
; 42, right row at 210; both are pitched about 11.6 px.
;
; Each plate carries its own WORD, in our font: three letters ink eleven
; pixels and a plate is eleven pixels, so a label fills its plate exactly
; and the artwork's divider is all that separates one from the next. That
; is tight - the row was tried this way once and read as GNDAIRIFF - but
; the colours are the panel's dim set now rather than the HUD's, which
; takes most of the shout out of it, and the pilot is retouching the plates
; anyway. Widen them in the picture and there is nothing to change here.
SWX     dw 42,54,66,77,89,100
        dw 210,221,233,244,256,267
SWY     = 186                 ; the label row, inside the plate
SWTXT   db 'GND',0,'AIR',0,'TAC',0,'IFF',0,'A-A',0,'A-G',0
        db 'A-P',0,'T-R',0,'ECM',0,'JMR',0,'CHF',0,'FLR',0
; What each plate reports. 0 = the master mode, handled apart; 0FFFFh = a
; box that exists on the panel but not yet in the game, and an unlit plate
; is an honest way to say so.
SWLIT   dw swgnd, swair, swtac, swiff
        dw 0, 0
        dw swap,  swtr,  swecm, swjmr
        dw 0FFFFh, 0FFFFh

; ---------------------------------------------------------------------------
;  SWKEYS - every plain on/off switch on the aeroplane, off one table.
;
;  Written out longhand a switch is twenty bytes, and twelve of them is a
;  hundred and forty in a segment that had TEN left. Out here the loop and
;  the table together cost nothing that matters and the thirteenth switch is
;  a five-byte row. The FLAGS stayed in the main segment - half the game
;  reads them with DS pointing there - so this writes home through DS and
;  keeps only the table and the key-edge bytes in its own segment.
;   Each row: scancode, the cs:-relative edge byte, the DS-relative flag.
; ---------------------------------------------------------------------------
SWNK    = 12
SWKTAB  db SC_F
        dw flaps
        db SC_L
        dw gear
        db SC_B
        dw abrk
        db SC_G
        dw swgnd
        db SC_U
        dw swair
        db SC_I
        dw swiff
        db SC_T
        dw swtac
        db SC_O
        dw swmode
        db SC_P
        dw swap
        db SC_R
        dw swtr
        db SC_J
        dw swecm
        db SC_Y
        dw swjmr

; ===========================================================================
;  OSBLAMP - the six columns of little buttons flanking the three screens.
;
;  On a real aeroplane these are the Option Select Buttons and their legends
;  are printed INSIDE the glass beside each key. We have no room for that at
;  320x200, so they do the other job a column of small lamps does well:
;  each one reports something about the screen it stands next to, as a bar
;  you read without focusing. Zoom is the obvious one - it is a setting with
;  no number anywhere on the panel, and it changes what every symbol means.
;
;  Eight slots a column, pitch six, a lamp four by three inside the plate.
;  Amber for a setting, green for a stores count, red for damage - the
;  panel's own dim set, so they sit down at night with everything else.
; ===========================================================================
; Measured off the artwork, then corrected by eye against the running game -
; the brightness scan found the columns but put four of the six a pixel or
; three out, and at this size that is the difference between a lamp in its
; socket and a lamp beside one.
OSBX    dw 41,103,122,185,204,267
OSBLX   = 4                   ; the lens sits four in from the plate's left
; The CENTRE screen sits three pixels lower than the other two in the
; artwork (129 against 126), and so do the two columns flanking it. One
; table with a per-column lands on all six; the first attempt used
; the radar column's rows for everything and missed four columns out of
; six by exactly that three.
OSBDY   db 0,2,3,3,0,0
; Seven plates a column, and the rows are NOT on a regular pitch - the
; artwork drifts, so they were measured off it rather than computed. These
; are the TOP row of each lens; the artwork's own lamp centre is one lower.
OSBYT   dw 132,138,144,149,155,161,167
OSBN    = 7
osbm    dw 0                    ; which lamps are lit
osbr    dw 0                    ; ...which of them are RED whatever the
                                ;  column's colour is - the bottom division
                                ;  of a fuel gauge is painted red on every
                                ;  aeroplane ever built
osbf    dw 0                    ; ...and which of them FLASH
osbc    db 0                    ; the column's own colour
osbyo   db 0                    ; ...and how far down the artwork put it.
                                ;  NOT 'osbdy': TASM folds case, and that
                                ;  is the OSBDY table three lines up

; BAR - AX slots lit, counted UP from the bottom of the column, into osbm.
OSBBAR: mov  cx,ax
        xor  ax,ax
        jcxz .bd
        cmp  cx,OSBN
        jbe  .b1
        mov  cx,OSBN
.b1:   push cx
.b2:   stc                     ; a run of CX ones, at the low bits...
        rcl  ax,1
        loop .b2
        pop  cx
        mov  bx,OSBN            ; ...shifted down to the bottom slots, since
        sub  bx,cx              ;  bit 0 is the TOP lamp of the column
        mov  cx,bx
        jcxz .bd
        shl  ax,cl
.bd:   mov  [cs:osbm],ax
        ret

OSBLAMP:
        cld
        mov  word [cs:osbr],0   ; no red and no flash unless a column
        mov  word [cs:osbf],0   ;  asks for them
        ; ---- column 0: the RADAR's zoom. rzsh runs 6 close .. 10 wide, so
        ; a tight scope shows a tall bar - more rungs, more detail ----
        mov  al,11
        sub  al,[rzsh]
        xor  ah,ah
        call OSBBAR
        mov  byte [cs:osbc],PNLAMB
        xor  bx,bx
        call OSBCOL
        ; ---- column 1: FUEL, beside the scope where the eye already is.
        ; The bottom division is red the way it is red on a real gauge, and
        ; it FLASHES once it is the only one left - which is the moment the
        ; number stops being information and starts being a decision ----
        mov  ax,[fuel]
        mov  bx,7
        imul bx                 ; seven divisions of tank
        mov  bx,FUELMAX
        xor  dx,dx
        div  bx
        push ax
        call OSBBAR
        mov  word [cs:osbr],40h ; the bottom lamp, always red
        pop  ax
        cmp  ax,2
        jae  .ol1
        mov  word [cs:osbf],40h ; ...and flashing, on the last division
.ol1:  mov  byte [cs:osbc],PNLAMB
        mov  bx,1
        call OSBCOL
        mov  word [cs:osbr],0
        mov  word [cs:osbf],0
        ; ---- column 2: which PAGE the centre screen is showing ----
        mov  al,[mfdmode]
        xor  ah,ah
        mov  cx,ax
        mov  ax,1
        shl  ax,cl              ; one lamp, counted from the top
        mov  [cs:osbm],ax
        mov  byte [cs:osbc],PNLGRN
        mov  bx,2
        call OSBCOL
        ; ---- column 3: the MAP's own zoom, next to the map ----
        mov  al,[mmzs]
        inc  al
        xor  ah,ah
        call OSBBAR
        mov  byte [cs:osbc],PNLAMB
        mov  bx,3
        call OSBCOL
        ; ---- column 4: missiles left on the rails ----
        mov  al,[pammo]
        xor  ah,ah
        call OSBBAR
        mov  byte [cs:osbc],PNLGRN
        mov  bx,4
        call OSBCOL
        ; ---- column 5: damage taken, filling DOWNWARD from the top - a
        ; bar that grows toward you reads as something getting worse ----
        mov  al,[pdam]
        xor  ah,ah
        mov  cx,ax
        xor  ax,ax
        jcxz .ol5
.ol4:  stc
        rcl  ax,1
        loop .ol4
.ol5:  mov  [cs:osbm],ax
        mov  [cs:osbf],ax       ; damage FLASHES, all of it. A hit you have
        mov  byte [cs:osbc],PNLRED  ; already taken is not news; a hit
        mov  bx,5               ; you are still carrying is
        call OSBCOL
        mov  word [cs:osbf],0
        ret

; OSBCOL - paint one column. in: BX = column 0..5, and [cs:osbm]/[cs:osbr]/
;  [cs:osbf]/[cs:osbc]. Each lamp is a four by three ROUND LENS: the corners are
;  left alone so the silhouette is not a square, the top-left is the core
;  colour and the bottom-right is its shadow. That is what makes something
;  this small look like a piece of moulded plastic with light behind it
;  rather than a coloured brick.
OSBCOL: mov  al,[cs:OSBDY+bx]   ; this column's own vertical offset
        mov  [cs:osbyo],al
        add  bx,bx
        mov  ax,[cs:OSBX+bx]
        add  ax,OSBLX
        mov  [dsx],ax
        xor  si,si              ; slot, 0 = top
.cl:   mov  cx,si
        mov  ax,1
        shl  ax,cl
        test [cs:osbm],ax
        jz   .cn
        test [cs:osbf],ax       ; a flashing lamp is dark half the time -
        jmp  .ck                ;  BOND: no lamp flashes, lit is lit (was jz)
.ck:   mov  ah,[cs:osbc]       ; red overrides the column's own colour
        test [cs:osbr],ax
        jz   .cc
        mov  ah,PNLRED
.cc:   mov  al,ah
        add  ah,PNLSHAD         ; AL = core, AH = its shadow
        mov  bx,si
        add  bx,bx
        push ax
        mov  ax,[cs:OSBYT+bx]
        mov  bl,[cs:osbyo]
        xor  bh,bh
        add  ax,bx
        call UROW
        pop  ax
        add  di,[dsx]
        mov  [es:di+1],al       ; . C C .
        mov  [es:di+2],al
        mov  [es:di+320],al     ; C C C R
        mov  [es:di+321],al
        mov  [es:di+322],al
        mov  [es:di+323],ah
        mov  [es:di+641],ah     ; . R R .
        mov  [es:di+642],ah
.cn:   inc  si
        cmp  si,OSBN
        jb   .cl
        ret

SWKEYSF:
        call SWKEYS
        retf
SWKEYS: xor  si,si              ; row index 0..SWNK-1
.k:    mov  bx,si
        add  bx,bx
        add  bx,si              ; *3 bytes a row
        mov  bl,[cs:SWKTAB+bx]
        xor  bh,bh
        ; THE LATCH, not the live key. Comparing KEYS against last frame was
        ; right while a frame was a fiftieth of a second; at one frame a
        ; second the whole press happens between two looks and the switch
        ; never throws. KHIT remembers the key-down until somebody takes it -
        ; and taking it is the line below, so one tap is one throw.
        mov  al,[KHIT+bx]       ; KHIT is at home, and DS points home
        test al,al
        jz   .kn
        mov  byte [KHIT+bx],0   ; consumed
        mov  bx,si
        add  bx,bx
        add  bx,si
        mov  di,word [cs:SWKTAB+bx+1]
        xor  byte [di],1
.kn:   inc  si
        cmp  si,SWNK
        jb   .k
        ; ---- and the GEAR'S OWN TRAVEL, which the lever does not have.
        ; Six steps, one every fourth tick: about a second from the lever to
        ; down and locked, and the same coming up. It rides here because
        ; SWKEYS is the one routine called every tick from INPUT that does
        ; not live in the main segment, and the main segment has 180 bytes.
        ; The DRAG still switches with the lever, not with the legs - that is
        ; deliberate. You pay for the gear the moment you ask for it. ----
        call WINDDRF            ; the breeze, while we are out here anyway
        call APPRCH             ; ...and the settle, if he is on approach
        ; ---- Ctrl+D: show the diagnostic marks, or hide them. It rides here
        ; for the same reason the gear travel does - SWKEYS is the one
        ; per-tick routine that is NOT in the main segment, so an edge
        ; detector costs that segment nothing. Ctrl and not a bare D because
        ; a bare letter is a key a player finds by accident. ----
        cmp  byte [KHIT+SC_D],0   ; the LATCH, not the live key: a tap between
        je   .dbx                 ;  two frames must not vanish (see KHIT)
        mov  byte [KHIT+SC_D],0   ; consumed
        cmp  byte [KEYS+SC_CTL],0
        je   .dbx
        xor  byte [dbgm],1
.dbx:
        test word [lasttk],3
        jnz  .gx
        mov  al,[gearp]
        cmp  byte [gear],0
        je   .gup
        cmp  al,GEARNS-1
        jae  .gx               ; down and locked
        inc  al
        jmp  .gst
.gup:  or   al,al
        jz   .gx               ; stowed
        dec  al
.gst:  mov  [gearp],al
.gx:   ret
spmsk   dw 0                    ; which of the ten are live this frame
spcol   db 0                    ; the slot's BACKGROUND colour (0 = unlit)
spplx   dw 0                    ; ...and the plate's left edge
spwink  db 0                    ; the ink colour for this slot's word

; ===========================================================================
;  WINDDRF - the wind, and why it had to stop being a constant.
;
;  It used to be two adds in INPUT: camx += 2, camz -= 1, every tick, for
;  ever. At cruise that is a small correction nobody notices. On APPROACH it
;  is the main thing happening to the aeroplane - at landing speed the drift
;  is a large fraction of the airspeed, so the jet crabs sideways across the
;  strip, and with the airspeed almost gone it is carried bodily backwards
;  while still pointing forwards. Two pilots reported the same thing in the
;  same words: "I tried to land and I was blown away."
;
;  The fix is the one the air actually uses: THE WIND DIES AT THE SURFACE.
;  Friction against the ground drags the bottom of the atmosphere to a stop,
;  which is why real aeroplanes can be landed at all. Full breeze above
;  WINDH, tapering linearly to nothing on the deck.
;
;  Done in FIXED POINT, because the honest scale of this is a fraction of a
;  unit a tick: the drift is accumulated at 512ths and only whole units are
;  handed to the position. Truncating per tick instead would round the wind
;  to zero for the whole approach and to full strength one unit higher.
;
;  It lives out here because the main segment has five bytes - and moving it
;  GAVE that segment eight back, which is the whole reason this could be
;  fixed properly rather than gated with a compare.
; ===========================================================================
; ===========================================================================
;  THE APPROACH, and the arrival.
;
;  Altitude in this model comes from ONE place: camy += vel/32 * sin(pitch).
;  Level, and you hold height exactly - the jet hangs over the runway. Nose
;  down, and pitching down also buys speed, so you do not sink, you dive.
;  There was no way to come down GENTLY, which is the only way anybody has
;  ever landed anything.
;
;  So: flaps out and below VAPP is an APPROACH. The aeroplane settles at a
;  steady rate whatever the pitch is doing - which is what an aeroplane on
;  the back of the drag curve actually does. Clean it up or push the speed
;  back over VAPP and the sink stops at once.
;
;  LANDF then decides whether meeting the ground is an arrival or an
;  accident, and it is called from the ONE place a crash was decided before.
;  The gate is the pilot's: flaps down, gear down, slow, and over concrete.
;  Miss any of the four and it is still a crash - he asked for consequences,
;  not a forgiving box.
; ===========================================================================
VAPP    = 170                 ; approach speed: under this, with the boards
                                ;  out, the jet is coming down
VSINK   = 3                   ; ...at this many units a tick
LANDW   = 260                 ; how far off the centreline still counts -
                                ;  the concrete is AFW=150, and a wheel on
                                ;  the paint is a landing
APPRCH:
        cmp  byte [dying],0
        jne  .ax
        cmp  byte [flaps],0
        je   .ax
        cmp  word [vel],VAPP
        jae  .ax
        mov  ax,[camy]          ; settle, and let the ground arrive
        sub  ax,VSINK
        mov  [camy],ax
.ax:   ret

; ---- ONPAVE - CF=0 if the wheels are on somebody's concrete, CF=1 if they
; are in the grass beside it. Walks all four fields, and THEIRS COUNT: the
; pilot's ruling is that you may put down on the enemy's strip and work the
; place over, you simply get no fuel and no rearm for it.
ONPAVE: mov  word [afi],0
.l:    mov  bx,[afi]
        add  bx,bx
        mov  ax,[camx]
        sub  ax,[afx+bx]
        or   ax,ax
        jns  .l1
        neg  ax
.l1:   cmp  ax,LANDW
        jg   .ln
        mov  ax,[camz]
        sub  ax,[afz+bx]
        or   ax,ax
        jns  .l2
        neg  ax
.l2:   cmp  ax,AFLEN
        jg   .ln
        clc
        ret
.ln:   inc  word [afi]
        cmp  word [afi],NAF
        jb   .l
        stc
        ret

; ---- LANDF - CF=1 if the ground under us is a runway and we belong on it.
; Called at the instant the hull would have hit the terrain.
;
; THE FIRST TEST IS THE NEW ONE AND IT IS LOAD-BEARING. This routine is
; reached every tick the wheels are on the deck, not only at the arrival -
; COLLIDE fires it whenever camy is under the ground, and GNDSCH deliberately
; holds camy exactly there for the whole roll. A takeoff accelerates STRAIGHT
; THROUGH VAPP with the flaps still out, which is precisely the state the
; gate below refuses. Without the first three lines the jet would be ruled a
; crash halfway down its own runway, every time, at about 170 knots.
LANDF:
        cmp  byte [onrwy],0
        je   .judge
        jmp  .rolling          ; already on her wheels: this is the roll
.judge:
        cmp  byte [gear],0
        je   .no               ; a belly arrival is an accident
        cmp  byte [flaps],0
        je   .no
        cmp  word [vel],VAPP
        jae  .no               ; arriving at cruise speed is not landing
        call ONPAVE             ; ...and it has to be OVER a strip
        jc   .no
        ; ---- AND NOW THE SINK RATE, which is the whole of a landing and
        ; was the one thing this gate did not ask about. Gear, flaps, slow
        ; and over the concrete described an aeroplane in the right PLACE;
        ; none of the four says anything about how hard it arrived, so a
        ; vertical dive onto the numbers passed all of them. ----
        mov  ax,[vsp8]
        cmp  ax,TDSLAM
        jle  .no               ; slammed in: the gear goes through the wing
        mov  byte [onrwy],1
        mov  word [hdgr],0
        mov  byte [dirtd],0
        mov  word [roll],0
        cmp  ax,TDFIRM
        jg   .grs
        add  word [pitch],2 ; firm: she sits back on her heels.
                                ;  The trainer BOUNCES here - apy=2 and
                                ;  airborne again. Not ported, and
                                ;  deliberately: at these speeds the climb
                                ;  from two units of pitch rounds to zero, so
                                ;  she would re-contact on the next tick and
                                ;  bounce for ever. A nose-up nudge says the
                                ;  same thing and cannot loop.
        jmp  .rolling
.grs:  mov  word [pitch],0 ; greased on
.rolling:
        mov  ax,[lgnd]          ; on the wheels, and staying there
        add  ax,14
        mov  [camy],ax
        stc
        retf
.no:   clc
        retf

; ===========================================================================
;  GNDSCH - THE GROUND SCHOOL, ported from the TRAINER (F_PHYS.INC, the
;  "ON THE GROUND" branch and the arrival below it).
;
;  WHY THIS COULD BE PORTED WITHOUT THE APPROACH MODEL, which the plan said
;  had to come first: the plan's premise was that the trainer "carries vsp
;  as STATE with GRAV acting on it" and that the vertical axis therefore had
;  to be restructured before anything else could land. It does not. The
;  trainer writes vsp in exactly two places and both are derived -
;  vsp = spd*sin(pitch), and then the ground cushion damps it - which is the
;  SAME LAW this game already uses for vvy. GRAV acts on the airspeed, along
;  the flight path: dive buys speed, climb spends it. OWLFLY2 has had that
;  line since it was written, with 24 where the trainer has 4.
;
;  So the two models are the same model, and the school is a self-contained
;  branch hanging off it. Nothing here needs a vertical axis that does not
;  exist yet.
;
;  WHERE IT RUNS: once a tick, from INPUT, straight AFTER the 3-D advance -
;  which is one far call and no restructuring of the airborne code at all.
;  The airborne code runs first and this OVERRIDES it, which composes
;  correctly on every axis: the elevator's pitch is replaced by the rotation
;  rule, the ailerons' roll by the fact that a wheel on each side holds the
;  wings level, and the advance's climb by the pin to the concrete. The one
;  thing it does NOT override is thrust and drag, and it must not - the
;  engine pushes and the boards bite exactly as hard standing still as they
;  do at height.
;
;  Reading the advance's own answer is what decides the takeoff. There is no
;  separate test for "has she flown": the advance ran a few instructions ago
;  with the pitch this routine set LAST tick, and if that carried her above
;  the wheels then she is flying. One compare, and it cannot disagree with
;  the physics because it IS the physics.
; ===========================================================================
GNDSCHF:
        call GNDSCH
        retf

GNDSCH: ; ---- the sink rate, kept every tick whether she is up or down,
        ; because the one tick it is READ is the tick she arrives. 8.8, the
        ; trainer's own scale: vel*sin(pitch)/32 is exactly vvy*256.
        ;
        ; THE CLAMP IS NOT A TIDY-UP, IT IS THE WHOLE ROUTINE'S LICENCE TO
        ; EXIST. idiv takes a 32-bit dividend and a 16-bit divisor and traps
        ; INT 0 if the QUOTIENT will not fit in a word - and nothing catches
        ; INT 0 here, so the machine stops dead, mid-frame, looking exactly
        ; like a hang. vel*256/32 passes 32767 at vel 4096, and this jet gets
        ; there: dive at full burner and the energy term keeps adding 24 a
        ; tick until the drag catches up somewhere past 4600. Reported as
        ; "took off, flew a bit, and it froze", which is precisely the shape
        ; of it - you have to be fast before you can be fast enough.
        ;
        ; The advance twenty lines above does the same sum and is safe purely
        ; because it SHIFTS FIRST: (vel>>5)*psin/256 has eight times the
        ; headroom. This one divides by 32 to keep the fraction, so it has to
        ; buy the headroom back at the door. 2048 is twelve times any speed
        ; anybody arrives at, and the only tick this number is ever READ is
        ; the tick the wheels touch.
        mov  ax,[vel]
        cmp  ax,2048
        jle  .v8
        mov  ax,2048
.v8:   imul word [psin]
        mov  bx,32
        idiv bx
        mov  [vsp8],ax
        cmp  byte [dying],0
        jne  .x                ; a wreck is not taxiing
        cmp  byte [onrwy],0
        je   .x
        ; ---- has she flown off? The advance already answered. ----
        mov  ax,[lgnd]
        add  ax,14
        cmp  [camy],ax
        jle  .roll
        mov  byte [onrwy],0
        ret
.roll: mov  [camy],ax          ; still on her wheels
        cmp  byte [gear],0
        jne  .gok
        jmp  .wreck            ; the legs came up while she was standing on
                                ;  them. Nothing forbids the lever - the
                                ;  panel refuses nothing anywhere - and this
                                ;  is what it costs
.gok:  ; ---- the brakes. THE AIRBRAKE LEVER IS THE WHEEL BRAKES down here.
        ; It is the same lever asking the same question - take speed off -
        ; and giving it a second meaning on the ground costs the pilot no
        ; new finger and no new plate on the panel. ----
        cmp  byte [abrk],0
        je   .nbr
        mov  ax,[vel]
        mov  cl,5
        sar  ax,cl
        add  ax,3
        sub  [vel],ax
        jns  .nbr
        mov  word [vel],0
.nbr:  mov  ax,[vel]           ; rolling resistance of the wheels: she does
        mov  cl,8               ;  not coast for ever, and at idle she comes
        sar  ax,cl              ;  to a stop on her own
        inc  ax
        sub  [vel],ax
        jns  .rr1
        mov  word [vel],0
.rr1:  ; ---- NOSE-WHEEL STEERING, AND THE RATE GROWS WITH GROUND SPEED.
        ; That is the whole character of taxiing a jet and it is why the
        ; first attempt at a takeoff run wanders: at walking pace the thing
        ; barely answers, and by the time it does you are going fast enough
        ; for the answer to put you in the grass. Arrows steer, the rudder
        ; pedals trim. ----
        xor  ax,ax
        cmp  byte [KEYS+SC_LF],0
        je   .s1
        sub  ax,12
.s1:   cmp  byte [KEYS+SC_RT],0
        je   .s2
        add  ax,12
.s2:   cmp  byte [KEYS+SC_Z],0
        je   .s3
        sub  ax,6
.s3:   cmp  byte [KEYS+SC_C],0
        je   .s4
        add  ax,6
.s4:   mov  bx,[vel]           ; same family as the vsp8 clamp above, and
        cmp  bx,1800            ;  worth closing while the lesson is fresh:
        jle  .s4a              ;  18*vel runs out of a WORD past 1820. imul
        mov  bx,1800            ;  does not trap, it just hands back a
.s4a:  imul bx                 ;  wrong-signed low word - so the nose wheel
        cmp  ax,512             ;  would steer the wrong way instead of
        jle  .s5               ;  stopping the machine. The clamp is far
                                ;  above any speed a wheel is still on the
                                ;  ground at, and it costs a far segment
                                ;  eight bytes to never think about again
        mov  ax,512
.s5:   cmp  ax,-512
        jge  .s6
        mov  ax,-512
.s6:   add  [hdgr],ax          ; the 8.8 residue: a slow turn still counts
        mov  ax,[hdgr]
        mov  cl,8
        sar  ax,cl
        add  [heading],ax
        and  word [heading],255
        mov  cl,8
        shl  ax,cl
        sub  [hdgr],ax
        ; ---- ROTATION: past VR the pull raises the nose; below it the nose
        ; is on the deck whatever the stick is doing. ----
        mov  bx,VRSPD
        cmp  byte [flaps],0
        je   .vr1
        sub  bx,VRFLAP          ; flaps buy an earlier rotation
.vr1:  push bx
        cmp  [vel],bx
        jl   .pdn
        cmp  byte [KEYS+SC_DN],0
        je   .pdn
        mov  ax,[pitch]
        inc  ax
        cmp  ax,14
        jle  .pst
        mov  ax,14
.pst:  mov  [pitch],ax
        jmp  .flt
.pdn:  mov  ax,[pitch]         ; below VR she comes back down to level, one
        or   ax,ax              ;  unit a tick, and stays there
        jle  .pz
        dec  ax
        mov  [pitch],ax
        jmp  .flt
.pz:   mov  word [pitch],0
.flt:  pop  bx                 ; past VLOF lift wins: she floats off whether
        add  bx,VLOFD           ;  or not anybody asked her to
        cmp  [vel],bx
        jl   .pave
        cmp  word [pitch],VLOFP
        jge  .pave
        mov  word [pitch],VLOFP
.pave: ; ---- the concrete, or the grass beside it ----
        call ONPAVE
        jc   .dirt
        mov  word [roll],0  ; a wheel on each side holds the wings level
        mov  byte [dirtd],0
        ret
.dirt: cmp  word [vel],GNDDIRT
        jge  .wreck            ; dirt at speed is a wreck, not an excursion
        mov  ax,[lasttk]        ; ...and below it she is merely being shaken.
        and  ax,7               ;  The shake is off the tick and not off
        sub  ax,4               ;  RND16, which lives in the main segment and
        and  ax,255             ;  is not worth a far door to be random at
        mov  [roll],ax
        cmp  word [vel],8
        jl   .x
        inc  byte [dirtd]   ; ...and ground, for as long as she rolls
        cmp  byte [dirtd],GNDGRND
        jb   .x
.wreck:call CODE:CRASHHANDLEF
        mov  byte [onrwy],0
.x:    ret

; ===========================================================================
;  AFSPAWN - put the jet on the concrete: fuelled, towed out, made ready.
;  The pilot's words, and the reason the landing gear was built at all.
;  Field 0 is ours (the same even/odd parity that carries IFF everywhere
;  else), and she stands at the near threshold facing up the strip - which
;  is heading 0, because the runways were laid north-south so that ours
;  point at the war and a takeoff needs no navigation.
; ===========================================================================
AFSPAWN:
        mov  ax,[netpid]        ; pilots of one wire line up ALONG the strip
        and  ax,3               ;  now, not fanned out east: four jets abreast
        mov  cx,AFSPACE         ;  on a 150-unit runway would be four jets in
        imul cx                 ;  the grass
        add  ax,AFSTART
        sub  ax,AFLEN
        add  ax,[afz]
        mov  [camz],ax
        mov  ax,[afx]
        mov  [camx],ax
        mov  ax,[afy]
        mov  [lgnd],ax          ; SEED THE GROUND, and it is not optional.
                                ;  lgnd is written by COLLIDE, which runs
                                ;  AFTER the physics - so on the first tick
                                ;  of a life it still holds whatever was
                                ;  under the LAST one (zero at startup, the
                                ;  crash site after a death). GNDSCH's very
                                ;  first question is whether camy has risen
                                ;  above lgnd+14, and against a stale zero
                                ;  the answer is yes: she would be declared
                                ;  airborne while standing on the concrete
                                ;  and drop out of the sky from her own ramp
        add  ax,14              ; standing on her wheels
        mov  [camy],ax
        mov  word [heading],0
        mov  word [roll],0
        mov  word [pitch],0
        mov  word [vel],0   ; STOPPED. The first thing any flight
                                ;  contains is now a takeoff.
        mov  word [throt],AFIDLE ; ...but the ENGINE IS RUNNING. A jet
                                ;  towed out and made ready is handed over
                                ;  turning and burning, not dead - and a dead
                                ;  panel gives a pilot who has never seen this
                                ;  screen nothing at all to push against. At
                                ;  idle she leans on the brakes and holds;
                                ;  let them go and she creeps, which is the
                                ;  aeroplane inviting the next input instead
                                ;  of waiting to be guessed at.
        mov  byte [abon],0
        mov  byte [gear],1  ; down, and already finished travelling
        mov  byte [gearp],GEARNS-1
        mov  byte [flaps],1 ; set for takeoff: they buy VRFLAP off VR
        mov  byte [abrk],1  ; PARKED. It is the same lever as the
                                ;  airbrake and down here it is the wheel
                                ;  brakes, so a jet handed over "made ready"
                                ;  is handed over standing on them. With the
                                ;  throttle at zero they hold her absolutely;
                                ;  open the taps without releasing and she
                                ;  will creep, which is a jet overpowering
                                ;  its own brakes and is allowed to happen
        mov  word [vstl],VSTALL*3/4
        mov  byte [onrwy],1
        mov  word [hdgr],0
        mov  word [vsp8],0
        mov  byte [dirtd],0
        ret
AFSPAWNF:
        call AFSPAWN
        retf

; ===========================================================================
;  PLAYERRESETF - Space pressed during the fall: take a fresh jet.
;  EVICTED FROM THE MAIN SEGMENT 2026-08-06. It runs once per death, which
;  made it the coldest thing left in there, and the ~150 bytes it gave back
;  are what the ground school's call site is standing on. It had one caller.
;
;  AND EVERY LIFE NOW COSTS A TAKEOFF. A fresh jet arrives stopped on its
;  own concrete instead of at 1450 doing cruise speed. This is the question
;  LANDTASK.md wrote down rather than answered - it changes what dying feels
;  like more than anything else on the list - and it is one line to undo:
;  drop the AFSPAWN call and put back the four words that follow it.
; ===========================================================================
PLAYERRESETF:
        mov  byte [dying],0
        ; ---- and GIVE THE PILOT HIS AEROPLANE BACK. Neither cinema camera
        ; was being switched off here. Take a fresh jet while F4 was orbiting
        ; something and the new jet arrives with no cockpit drawn (the panel
        ; is skipped whenever tgtcam is up), no view of itself, and the arrow
        ; keys still steering the CAMERA - which reads exactly like the game
        ; has hung, because there is nothing left that answers. Same trap
        ; rides on the missile camera. ----
        mov  byte [tgtcam],0
        mov  byte [mcact],0
        mov  word [lastklr],0   ; a fresh jet owes nobody a kill
        mov  word [dytick],0
        call AFSPAWN            ; on the strip: position, attitude, speed,
                                ;  gear, flaps and the ground state, all of it
        mov  word [fuel],FUELMAX
        mov  byte [pammo],4
        mov  byte [msact],0
        call SYMSEG:MSLCLRF   ; four EMPTY rails on a fresh jet
        mov  word [gunam],250
        mov  byte [pdam],0
        mov  word [flbcnt],0
        call CODE:FLBSEEDF   ; a fresh black box for a fresh jet
        retf

WINDH   = 512                 ; the height the breeze is fully grown at
wacx    dw 0                    ; the 512ths not yet spent
wacz    dw 0
WINDDRF:
        ; ---- WHEELS ON THE GROUND, NO DRIFT. The taper below is honest -
        ; the breeze dies at the surface - but it dies to what the SURFACE
        ; is, and the surface here is fourteen units up, because that is
        ; where the undercarriage holds the hull. Fourteen times WINDX is 28
        ; of the 512ths a whole unit takes, so a parked jet was earning one
        ; unit of sideways drift every eighteen ticks and sliding off its own
        ; apron at a unit a second. Reported exactly as "it slowly creeps to
        ; the right", which is what it was doing.
        ;
        ; Tapering to zero at 14 instead would be arithmetic hiding a
        ; category error: wind does not push an aeroplane that is standing on
        ; rubber, friction does not care how hard it blows, and the jet is
        ; not IN the moving air at all. Same reason the sway is switched off
        ; down here - both are the airframe riding air it is not riding. ----
        cmp  byte [onrwy],0
        jne  .wx
        mov  ax,[camy]          ; height above the ground under us, which
        sub  ax,[lgnd]          ;  the sway already keeps for its own use
        jns  .w1
        xor  ax,ax
.w1:   cmp  ax,WINDH
        jle  .w2
        mov  ax,WINDH           ; above the boundary layer: the full breeze
.w2:   mov  [cs:wach],ax
        mov  bx,WINDX           ; each axis: WIND * agl, into 512ths
        imul bx
        add  ax,[cs:wacx]
        mov  [cs:wacx],ax
        mov  cl,9
        sar  ax,cl              ; whole units earned so far
        mov  bx,ax
        mov  cl,9
        shl  ax,cl
        sub  [cs:wacx],ax       ; ...and keep the change
        add  [camx],bx
        mov  ax,[cs:wach]
        mov  bx,WINDZ
        imul bx
        add  ax,[cs:wacz]
        mov  [cs:wacz],ax
        mov  cl,9
        sar  ax,cl
        mov  bx,ax
        mov  cl,9
        shl  ax,cl
        sub  [cs:wacz],ax
        add  [camz],bx
.wx:   ret
wach    dw 0                    ; this tick's height factor, 0..WINDH

; ===========================================================================
;  NETLAMP - THE WIRE, on the overhead plate.
;
;  There was no way to see the state of the network from the cockpit at all.
;  A pilot disconnected mid-sortie and the only symptom was that the sky went
;  quiet - which is indistinguishable from nobody being near you. An
;  aeroplane that fights over a datalink should say whether it HAS one.
;
;  It goes in the black plate between the two lamp clusters, the slot the
;  artwork left for exactly this kind of legend - and the burner strip owns
;  the same slot. That is not a clash, it is a priority: PANELBMP draws AB ON
;  AFTER this, so lighting the burner shouts over the wire count for as long
;  as it is lit, and the count comes straight back when it is not.
;
;  The number is REMOTE PILOTS, not a connection flag: netok says the socket
;  opened, which it did even when the man on the other end walked away. What
;  a pilot wants to know is how many people are actually out there.
;
;  Drawn from UISEG, and that is the point: the main segment has five bytes.
;  The string is built in NB - a MAIN-segment scratch, so FDRAW can walk it
;  with DS - and NB is exactly six bytes, which is what "NET n" needs.
; ===========================================================================
NETLAMP:
        xor  cx,cx              ; how many real pilots are on the wire
        xor  si,si
.nl:   cmp  byte [premote+si],0
        je   .nln
        inc  cx
.nln:  inc  si
        cmp  si,NPLANE
        jb   .nl
        mov  byte [NB],'N'
        mov  byte [NB+1],'E'
        mov  byte [NB+2],'T'
        mov  byte [NB+3],' '
        mov  al,cl
        cmp  al,9
        jbe  .nd
        mov  al,9               ; one digit is all the plate has room for
.nd:   add  al,'0'
        mov  [NB+4],al
        mov  byte [NB+5],0
        mov  byte [COLOR],PNLGRN
        or   cx,cx
        jnz  .nc
        mov  byte [COLOR],PNLAMB ; alone up here, for whatever reason
.nc:   mov  word [ftx],PZABX
        mov  word [fty],PZABY
        mov  si,NB
        call CODE:FDRAWF
        ret

SIDEPNL:
        ; ---- the glass first. A flat black rectangle reads as a hole cut
        ; in the panel; a few barely-lit specks read as glass with a lamp
        ; somewhere behind it, and the words then sit ON something. The
        ; pattern is fixed, not random - noise regenerated every frame
        ; would crawl, and a crawling panel is worse than a flat one. ----
        cld
        xor  si,si
.nsp:  mov  bx,si
        add  bx,bx
        mov  di,[cs:SPNX+bx]
        mov  word [dsx],SPNY0
.nsr:  mov  ax,[dsx]
        mov  bx,ax              ; the row's own offset: (y*3) and 3, which
        add  bx,bx              ;  walks 0,3,2,1 down the plate and never
        add  bx,ax              ;  lines the specks up into a stripe
        and  bx,3
        push bx                 ; UROW CLOBBERS BX - it builds row*64 in there
        push di                 ;  on its way to row*320, and this was
        call UROW               ;  being added back AFTERWARDS. The specks
        pop  ax                 ;  were landing at row*384 + x: sixty-four
        pop  bx                 ;  pixels further right every row, marching
        add  di,ax              ;  diagonally across the whole panel, over
        add  di,bx              ;  both MFDs and the map, and wrapping off the
                                ;  top of the buffer past row 170. That is the
                                ;  speckle the pilot kept seeing on his map,
                                ;  and it is the SAME trap ROW320 and VLINE2
                                ;  already carry notes about.
        push ax
        mov  al,PNLNOIS
        mov  cx,5
.nsx:  mov  [es:di],al
        add  di,4
        loop .nsx
        pop  di
        inc  word [dsx]
        cmp  word [dsx],SPNY1
        jbe  .nsr
        inc  si
        cmp  si,2
        jb   .nsp
        mov  word [cs:spmsk],0
        cmp  byte [flaps],0 ; ---- left: what is hanging out ----
        je   .spg
        or   word [cs:spmsk],1
.spg:  cmp  byte [gear],0
        je   .spb
        or   word [cs:spmsk],2
.spb:  cmp  byte [abrk],0
        je   .spa
        or   word [cs:spmsk],4
.spa:  cmp  byte [abon],0
        je   .sps
        or   word [cs:spmsk],8
.sps:  mov  ax,[vel]           ; ---- right: what the aeroplane says ----
        cmp  ax,[vstl]
        jge  .spf
        or   word [cs:spmsk],32
.spf:  cmp  word [fuel],1200
        jge  .spt
        or   word [cs:spmsk],64
.spt:  mov  ax,[camy]
        sub  ax,[lgnd]
        cmp  ax,300
        jge  .spi
        or   word [cs:spmsk],128
.spi:  cmp  byte [pdam],4
        jb   .spk
        or   word [cs:spmsk],256
.spk:  cmp  word [locki],0FFFFh
        je   .spd
        or   word [cs:spmsk],512
        ; ---- and paint all ten. A real annunciator does NOT colour its
        ; letters: it lights the whole legend plate from behind and the
        ; printed word stays the dark grey it was printed in. So the SLOT
        ; fills with colour, faintly banded the way a lit panel always is,
        ; a dark line divides one from the next, and the word goes on top
        ; in the same grey whether the lamp is on or off. ----
.spd:  xor  si,si
.spanl:  mov  cx,si
        mov  ax,1
        shl  ax,cl
        mov  byte [cs:spcol],0      ; 0 = this slot is not lit
        test [cs:spmsk],ax
        jz   .spp
        mov  bx,si              ; THIS lamp's own phase and own period -
        mov  ax,[lasttk]        ;  see SPBPH/SPBMK. Only the low byte is
        add  al,[cs:SPBPH+bx]   ;  ever looked at, so byte arithmetic is
        mov  ah,[cs:SPBMK+bx]   ;  the whole of it and the wrap is free
        test ah,ah              ; BOND: never zero - a live slot is lit, all
        jz   .spp              ;  the time (was test al,ah: the blink)
        mov  byte [cs:spcol],SPGRN  ; a system that is OUT reads green
        cmp  si,3
        jne  .spbrn
        mov  byte [cs:spcol],SPRED  ; ...except BURN. The other three on
        jmp  .spp                      ; that side are configuration - flaps
                                        ; out, gear down, boards out - and
                                        ; green is right for those. The
                                        ; burner is not a configuration, it
                                        ; is fuel going up the stack at four
                                        ; times the rate, and the lamp should
                                        ; say so (the pilot's call).
.spbrn:
        cmp  si,5
        jb   .spp
        mov  byte [cs:spcol],SPRED  ; a warning reads red...
        cmp  si,9
        jne  .spp
        mov  byte [cs:spcol],SPAMB  ; ...but a lock is news, not alarm
.spp:  cmp  byte [cs:spcol],0
        je   .spp0             ; dark: nothing to shade
        mov  bx,si              ; ...lit: and this bulb's own brightness.
        mov  al,[cs:SPBDIM+bx]  ;  Safe to add straight onto the colour -
        add  [cs:spcol],al      ;  nothing downstream derives a shade from
                                ;  spcol, it is only ever a flat fill
.spp0: mov  di,si              ; MEASURE the word, so it can be centred
        add  di,di
        mov  bx,di
        add  di,di
        add  di,bx              ; *6
        xor  cx,cx
.spm:  cmp  byte [cs:SPTXT+di],0
        je   .spw
        inc  di
        inc  cx
        cmp  cx,5
        jb   .spm
.spw:  mov  ax,cx              ; ink = len*4 - 1, so the left margin is
        add  ax,ax              ;  (23 - ink) / 2
        add  ax,ax
        dec  ax
        neg  ax
        add  ax,SPPLW
        sar  ax,1
        mov  bx,si              ; which plate
        cmp  bx,5
        jb   .spx
        sub  bx,5
        mov  bx,2
        jmp  .spx2
.spx:  xor  bx,bx
.spx2: mov  dx,[cs:SPNX+bx]
        mov  [cs:spplx],dx      ; the plate itself, for the lit background
        add  ax,dx
        mov  [ftx],ax
        mov  ax,si
        cmp  ax,5
        jb   .spy
        sub  ax,5
.spy:  mov  bx,SPSH
        imul bx
        add  ax,SPSY0           ; the slot's top row
        mov  [dsy],ax
        add  ax,SPTY            ; ...and the word, centred DOWN it too
        mov  [fty],ax
        mov  al,PNLCAP          ; the ink: grey on black, black on colour
        cmp  byte [cs:spcol],0
        je   .sqt
        mov  al,PNLNOIS
.sqt:  mov  [cs:spwink],al
        ; ---- the lit plate behind the word, and the dark line dividing
        ; this slot from the next.
        ;
        ; It was BANDED for a while - a darker line every fourth row - and
        ; that was the wrong instinct twice over: at half brightness it was
        ; a zebra, and even at a tenth it still read as stripes rather than
        ; as a surface. Flat colour with a scatter of grey specks does what
        ; the stripes were meant to do. The specks are placed from the row
        ; number, so the pattern is fixed and will not crawl. ----
        cmp  byte [cs:spcol],0
        je   .sq1
        mov  cx,SPFH
        mov  ax,[dsy]
.sq0:  push cx
        push ax
        call UROW
        add  di,[cs:spplx]
        push di
        mov  al,[cs:spcol]
        mov  cx,SPPLW
        rep  stosb              ; flat, no banding
        pop  di
        pop  ax
        push ax
        mov  bx,ax              ; two specks, at y*7 and y*5 folded into
        mov  cl,3               ;  the plate's width - cheap, and scattered
        shl  bx,cl              ;  enough that no two rows agree
        sub  bx,ax
        and  bx,15
        mov  byte [es:di+bx],PNLCAP
        mov  bx,ax
        mov  cl,2
        shl  bx,cl
        add  bx,ax
        and  bx,7
        add  bx,14
        mov  byte [es:di+bx],PNLCAP
        pop  ax
        inc  ax
        pop  cx
        loop .sq0
.sq1:  mov  ax,[dsy]           ; the divider, lit slot or not
        add  ax,SPFH
        call UROW
        add  di,[cs:spplx]
        mov  al,PNLNOIS
        mov  cx,SPPLW
        rep  stosb
        mov  di,si              ; the string: six bytes a slot
        add  di,di
        mov  bx,di
        add  di,di
        add  di,bx
.spc:  mov  al,[cs:SPTXT+di]
        test al,al
        jz   .spn
        ; LETTERS ONLY, and the test is a range, not a check for a space.
        ; The A/B caption carried a slash, and 'A'-10 subtracted off it gave
        ; a glyph index of 248 - six times that is a read a kilobyte and a
        ; half past the end of FONTBUF. It drew nothing visible, which is
        ; the worst way for a bad read to behave. Anything that is not a
        ; capital now simply steps the pen, the way the padding spaces do.
        cmp  al,'A'
        jb   .spv
        cmp  al,'Z'
        ja   .spv
        sub  al,'A'-10
        xor  ah,ah
        mov  bx,ax
        add  ax,ax
        add  ax,ax
        add  ax,bx
        add  ax,bx              ; *6 rows a glyph
        push si
        push di
        mov  si,FONTBUF
        add  si,ax
        mov  ax,[fty]
        call UROW
        add  di,[ftx]
        mov  cx,6
.spr:  mov  al,[si]
        mov  ah,[cs:spwink]     ; grey on a dark plate, NEAR BLACK on a lit
                                ;  one. The word is printed on the plate,
                                ;  not made of light - so when the lamp
                                ;  comes on behind it, it goes darker, not
                                ;  brighter, and that is what makes a lit
                                ;  legend readable instead of glaring.
        test al,80h
        jz   .sp1
        mov  [es:di],ah
.sp1:  test al,40h
        jz   .sp2
        mov  [es:di+1],ah
.sp2:  test al,20h
        jz   .sp3
        mov  [es:di+2],ah
.sp3:  inc  si
        add  di,320
        loop .spr
        pop  di
        pop  si
.spv:  add  word [ftx],4
        inc  di
        jmp  .spc
.spn:  inc  si
        cmp  si,10
        jb   .spanl
        ; ---- and the twelve buttons under the screens ----
        cld
        xor  si,si
.swl:  xor  al,al              ; is THIS plate lit?
        cmp  si,4
        je   .swaa
        cmp  si,5
        je   .swag
        cmp  si,10
        jae  .swd              ; chaff and flares: on the panel, not yet
        mov  bx,si              ;  in the game, and left honestly dark
        add  bx,bx
        mov  di,[cs:SWLIT+bx]
        mov  al,[di]
        jmp  .swd
.swaa: mov  al,[swmode]        ; A-A: lit when the mode is NOT air-to-ground
        xor  al,1
        jmp  .swd
.swag: mov  al,[swmode]        ; A-G: the other half of the same switch
.swd:  mov  byte [cs:spcol],SPDARK
        test al,al
        jz   .swp
        mov  byte [cs:spcol],SPGRN
.swp:  mov  bx,si
        add  bx,bx
        mov  ax,[cs:SWX+bx]
        mov  [ftx],ax
        mov  di,si              ; four bytes a label
        add  di,di
        add  di,di
.swt:  mov  al,[cs:SWTXT+di]
        test al,al
        jz   .swn
        ; the font keeps its punctuation after the letters: '-' is glyph
        ; 37, and A-A cannot be written without it
        mov  ah,37
        cmp  al,'-'
        je   .swg
        cmp  al,'A'
        jb   .swv
        cmp  al,'Z'
        ja   .swv
        sub  al,'A'-10
        mov  ah,al
.swg:  mov  al,ah
        xor  ah,ah
        mov  bx,ax
        add  ax,ax
        add  ax,ax
        add  ax,bx
        add  ax,bx              ; *6 rows a glyph
        push si
        push di
        mov  si,FONTBUF
        add  si,ax
        mov  ax,SWY
        call UROW
        add  di,[ftx]
        mov  cx,6
.swr:  mov  al,[si]
        mov  ah,[cs:spcol]
        test al,80h
        jz   .sw1
        mov  [es:di],ah
.sw1:  test al,40h
        jz   .sw2
        mov  [es:di+1],ah
.sw2:  test al,20h
        jz   .sw3
        mov  [es:di+2],ah
.sw3:  inc  si
        add  di,320
        loop .swr
        pop  di
        pop  si
.swv:  add  word [ftx],4
        inc  di
        jmp  .swt
.swn:  inc  si
        cmp  si,12
        jb   .swl
        ret

; ===========================================================================
;  WARNLMP - the OVERHEAD ANNUNCIATOR STRIP: seven lamps across the top of
;  the panel, four to the left of the blank display and three to the right.
;  Dead paint until now - the artwork drew some of them lit and some dark
;  and the game never touched one of them.
;
;  The picture draws every lens DARK; we only ever LIGHT one. That way the
;  artwork owns the off state, the bezel and the caption plate, and the
;  code owns nothing but the three-by-three of colour - there is no unlit
;  shade to keep in step between a .png and an .INC.
;
;  The captions are the picture's job too: a lens is three pixels wide and
;  the font steps four, so no word fits here. Left to right they read
;  MSTR MSL AAA DMG | FUEL FIRE GND, and every one of them is wired to
;  state the game already keeps - nothing here is a light that lies.
;   ES = bufseg, DS = the main segment (UISEG's own words take cs:).
; ===========================================================================
WLMPY   = 10                  ; the lens row, in 320x200 panel coords
WLCAPY  = 4                   ; ...and the caption row above it
; The warning about not taking a colour out of 31..93 now lives with the
; PNL* equs in DATA.INC, where the numbers are.
WLGREY  = PNLCAP
wlmsk   dw 0                    ; which lamps want to be lit this frame
WLMPX   dw 98,110,121,133,185,197,210
WLMPC   db 97,19,19,97,97,19,19 ; amber for a caution, red for a threat
WLMPB   db 0,0,0,0,0,0,0        ; ...and which of them flash rather than sit.
                                ;  BOND: none - v3 flashed 1,1,0,0,0,1,1
; The captions, in OUR font, over the artwork's own unreadable ones. TWO
; letters, and that is the hard ceiling: the glyph is three pixels and the
; step is four, the caption plate is nine wide and the lamps are pitched
; twelve apart. Three letters ink eleven pixels, which fits the pitch but
; leaves ONE pixel between one word and the next - tried it, and the strip
; read as MSTMSLAAADMG in one breath. Two letters ink seven and land inside
; the plate with two clear pixels of bezel either side. Widen the plates in
; the picture and these strings can grow; until then, short is legible and
; long is not. Drawn every frame, so the artwork can lose its own baked-in
; lettering completely and these become the only words up there.
WLMPT   db 'MC',0,0,'MW',0,0,'AA',0,0,'DM',0,0,'FU',0,0,'FR',0,0,'GD',0,0

WARNLMP:
        mov  word [cs:wlmsk],0
        xor  si,si              ; MSL: an AI missile is chasing US. amtgt is
.wms:  mov  bx,si              ;  a plane and the pilot is plane 0
        shr  bx,1
        cmp  byte [amact+bx],0
        je   .wmsn
        cmp  word [amtgt+si],0
        jne  .wmsn
        or   word [cs:wlmsk],2
.wmsn: add  si,2
        cmp  si,NAMSL*2
        jb   .wms
        xor  si,si              ; AAA: a live Shilka has the pilot on its gun
.waa:  mov  bx,si
        shr  bx,1
        cmp  byte [cs:shkst+bx],0
        jne  .waan             ; burning: it is not shooting anybody
        cmp  word [cs:shktgt+si],0FFFFh
        jne  .waan
        or   word [cs:wlmsk],4
.waan: add  si,2
        cmp  si,NSHILK*2
        jb   .waa
        cmp  byte [pdam],0  ; DMG: anything broken at all
        je   .wdm
        or   word [cs:wlmsk],8
.wdm:  cmp  word [fuel],1200
        jge  .wfu              ; FUEL: under a fifth of the tank
        or   word [cs:wlmsk],16
.wfu:  cmp  byte [pdam],4  ; FIRE: four hits of the five that kill -
        jb   .wfi              ;  the next one is the last one
        or   word [cs:wlmsk],32
.wfi:  mov  ax,[camy]          ; GND: the ground is coming up
        sub  ax,[lgnd]
        cmp  ax,300
        jge  .wgn
        or   word [cs:wlmsk],64
.wgn:  cmp  word [cs:wlmsk],0
        je   .wdr              ; MSTR: master caution, lit by all the rest
        or   word [cs:wlmsk],1
.wdr:  xor  si,si
.wdl:  mov  cx,si
        mov  ax,1
        shl  ax,cl
        test [cs:wlmsk],ax
        jz   .wdn
        cmp  byte [cs:WLMPB+si],0
        je   .wdon
        test word [lasttk],PNLBLNK ; the urgent ones flash, about twice a second
        jz   .wdn
.wdon: mov  ax,WLMPY
        call UROW
        mov  bx,si
        add  bx,bx
        add  di,[cs:WLMPX+bx]
        mov  al,[cs:WLMPC+si]
        mov  cx,3
.wdr2: mov  [es:di],al
        mov  [es:di+1],al
        mov  [es:di+2],al
        add  di,320
        loop .wdr2
.wdn:  inc  si
        cmp  si,7
        jb   .wdl
        ; ---- and the captions over them. FDRAW cannot be used: it walks
        ; its string with DS:SI, DS is the MAIN segment in here, and these
        ; words live in UISEG. Moving them home was not on the table - the
        ; main segment has eight bytes left. So the glyph blitter is copied
        ; here instead, reading the SAME FONTBUF (a main-segment buffer, so
        ; plain DS) and costing that segment nothing at all ----
        xor  si,si              ; lamp index
.wct:  mov  bx,si
        add  bx,bx
        mov  ax,[cs:WLMPX+bx]
        sub  ax,2               ; seven pixels of ink, centred on the lens
        mov  [ftx],ax
        mov  di,si              ; the string cursor: four bytes a caption
        add  di,di
        add  di,di
.wcc:  mov  al,[cs:WLMPT+di]
        test al,al
        jz   .wce
        sub  al,'A'-10          ; the font puts the letters after the digits
        xor  ah,ah
        mov  bx,ax
        add  ax,ax
        add  ax,ax
        add  ax,bx
        add  ax,bx              ; *6: six rows a glyph
        push si
        push di
        mov  si,FONTBUF
        add  si,ax
        mov  ax,WLCAPY
        call UROW
        add  di,[ftx]
        mov  cx,6
.wcr:  mov  al,[si]
        mov  ah,WLGREY
        test al,80h
        jz   .wc1
        mov  [es:di],ah
.wc1:  test al,40h
        jz   .wc2
        mov  [es:di+1],ah
.wc2:  test al,20h
        jz   .wc3
        mov  [es:di+2],ah
.wc3:  inc  si
        add  di,320
        loop .wcr
        pop  di
        pop  si
        add  word [ftx],4
        inc  di
        jmp  .wcc
.wce:  inc  si
        cmp  si,7
        jb   .wct
        ret
; ============================================================================
;  STATPG - the right (green) MFD as pure status: the war score row,
;  gun rounds, missile rails, damage pips - everything the scope used
;  to carry. ES=bufseg, DS=CS.
; ============================================================================
STATPG: mov  ax,PZMAPY0+3             ; green square: kills by our team
        call UROW
        add  di,PZMAPX0+2
        mov  al,95
        mov  [es:di],al
        mov  [es:di+1],al
        mov  [es:di+2],al
        mov  [es:di+320],al
        mov  [es:di+322],al
        mov  [es:di+640],al
        mov  [es:di+641],al
        mov  [es:di+642],al
        mov  ax,PZMAPY0+3             ; yellow diamond: kills by theirs
        call UROW
        add  di,PZMAPX0+39
        mov  al,96
        mov  [es:di+1],al
        mov  [es:di+320],al
        mov  [es:di+322],al
        mov  [es:di+641],al
        mov  byte [COLOR],95
        mov  word [ftx],PZMAPX0+8
        mov  word [fty],PZMAPY0+3
        mov  ax,[tscf]
        call CODE:FNUMF
        mov  byte [COLOR],8 ; own kills, centre, white
        mov  word [ftx],PZMAPX0+21
        mov  word [fty],PZMAPY0+3
        mov  ax,[psc]
        call CODE:FNUMF
        mov  byte [COLOR],96
        mov  word [ftx],PZMAPX0+31
        mov  word [fty],PZMAPY0+3
        mov  ax,[tsch]
        call CODE:FNUMF
        mov  byte [COLOR],97 ; cannon rounds
        mov  word [ftx],PZMAPX0+2
        mov  word [fty],PZMAPY0+12
        mov  si,MSGGUN
        call CODE:FDRAWF
        mov  byte [COLOR],8
        mov  word [ftx],PZMAPX0+20
        mov  ax,[gunam]
        call CODE:FNUMF
        mov  byte [COLOR],97 ; missile rails: label + a pip each
        mov  word [ftx],PZMAPX0+2
        mov  word [fty],PZMAPY0+21
        mov  si,MSGMSL
        call CODE:FDRAWF
        xor  si,si
.amo:  mov  ax,si
        cmp  al,[pammo]
        jae  .amn
        mov  ax,PZMAPY0+22
        call UROW
        add  di,PZMAPX0+20
        mov  ax,si
        add  ax,ax
        mov  bx,ax
        add  ax,ax
        add  ax,bx              ; k*6
        add  di,ax
        mov  al,97
        mov  [es:di],al
        mov  [es:di+1],al
        mov  [es:di+2],al
        mov  [es:di+3],al
        mov  [es:di+320],al
        mov  [es:di+321],al
        mov  [es:di+322],al
        mov  [es:di+323],al
.amn:  inc  si
        cmp  si,4
        jb   .amo
        mov  byte [COLOR],97 ; damage: label + red pips
        mov  word [ftx],PZMAPX0+2
        mov  word [fty],PZMAPY0+29
        mov  si,MSGDAM
        call CODE:FDRAWF
        xor  si,si
.dmp:  mov  ax,si
        cmp  al,[pdam]
        jae  .dmn
        mov  ax,PZMAPY0+30
        call UROW
        add  di,PZMAPX0+20
        mov  ax,si
        add  ax,ax
        mov  bx,ax
        add  ax,ax
        add  ax,bx              ; k*6
        add  di,ax
        mov  al,19
        mov  [es:di],al
        mov  [es:di+1],al
        mov  [es:di+2],al
        mov  [es:di+320],al
        mov  [es:di+321],al
        mov  [es:di+322],al
.dmn:  inc  si
        cmp  si,5
        jb   .dmp
        ; ---- fuel, which used to sit in the readout block. That block is
        ; four fields wide now and the artwork names them IAS/ALT/HDG/VERT,
        ; so the tank came here - this page IS the status page, and the new
        ; screen is fifteen rows taller than the one it replaced. Red under
        ; the same 1200 the warning lamp uses, so lamp and number agree.
        mov  byte [COLOR],97
        mov  word [ftx],PZMAPX0+2
        mov  word [fty],PZMAPY0+38
        mov  si,MSGFUE2
        call CODE:FDRAWF
        mov  byte [COLOR],8
        cmp  word [fuel],1200
        jge  .fu1
        mov  byte [COLOR],19
.fu1:  mov  word [ftx],PZMAPX0+20
        mov  ax,[fuel]
        xor  dx,dx
        mov  bx,60
        div  bx
        call CODE:FNUMF
        ret

TGTVIEWF:
        call TGTVIEW
        retf
; ---------------------------------------------------------------------------
;  TGTVIEW - the TGT page on the CENTRE MFD: callsign (worn in the
;  IFF colour), type, range, target altitude and a wireframe of the
;  jet (aspect follows its heading). No lock: the page says NO TGT.
; ---------------------------------------------------------------------------
TGTVIEW:
        mov  si,[locki]
        cmp  si,0FFFFh
        jne  .tgo
        mov  byte [COLOR],97 ; nothing locked: the page says so
        mov  word [ftx],PZADIX0+12
        mov  word [fty],PZADIY0+15
        mov  si,MSGNOT
        call CODE:FDRAWF
        ret
.tgo:  mov  byte [COLOR],19 ; the callsign wears the IFF colour
        test si,2
        jnz  .tgc
        mov  byte [COLOR],95
.tgc:  mov  word [ftx],PZADIX0+2
        mov  word [fty],PZADIY0+3
        call CODE:CSDRAWF
        mov  byte [COLOR],8
        mov  word [ftx],PZADIX0+2
        mov  word [fty],PZADIY0+11
        mov  si,[locki]
        call CODE:TYPDRAWF
        mov  byte [COLOR],97 ; range: octagonal max + 3*(min/8)
        mov  word [ftx],PZADIX0+2
        mov  word [fty],PZADIY0+19
        mov  si,MSGRNG
        call CODE:FDRAWF
        mov  si,[locki]
        call CODE:LKPOSF
        mov  ax,[lkx]
        sub  ax,[camx]
        jns  .tr1
        neg  ax
.tr1:  mov  bx,[lkz]
        sub  bx,[camz]
        jns  .tr2
        neg  bx
.tr2:  cmp  ax,bx
        jae  .tr3
        xchg ax,bx
.tr3:  mov  cl,3
        shr  bx,cl
        add  ax,bx              ; max 32767 + 3*4095: read UNSIGNED
        add  ax,bx
        add  ax,bx
        cmp  ax,30000           ; clamp before FNUMK's signed idiv era
        jbe  .trc
        mov  ax,30000
.trc:  mov  word [ftx],PZADIX0+18
        mov  byte [COLOR],8
        call CODE:FNUMKF
        mov  byte [COLOR],97 ; the target's altitude
        mov  word [ftx],PZADIX0+2
        mov  word [fty],PZADIY0+27
        mov  si,MSGALT
        call CODE:FDRAWF
        mov  word [ftx],PZADIX0+20
        mov  byte [COLOR],8
        mov  si,[locki]
        call CODE:LKPOSF
        mov  ax,[lky]
        or   ax,ax
        jns  .tr4
        xor  ax,ax
.tr4:  call CODE:FNUMKF
        ; wireframe: rotate the model by its aspect, project small
        mov  si,[locki]         ; FNUMK's font walk ate SI
        cmp  si,RSLK
        jb   .tpl
        mov  word [mvb],RDISHVT ; a station shows its DISH, and
        mov  word [mvn],RDISHNV*6      ; it turns on the page as it
        mov  word [mfb],RDISHFC
        mov  word [nfc],RDISHNF
        mov  word [tgzo],400           ; turns out there on the hill.
        mov  word [tgyc],64            ; It is six times a jet's size:
        mov  ax,[rspin]                    ; stand further off, and centre
        jmp  .tyaw                        ; on the hub, not on the feet
.tpl:  mov  word [tgzo],75
        mov  word [tgyc],0
        mov  bx,si
        shr  bx,1
        mov  al,[ptype+bx]
        xor  ah,ah
        add  ax,ax
        mov  bx,ax
        mov  ax,[MVTAB+bx]
        mov  [mvb],ax
        mov  ax,[MVNTAB+bx]
        mov  [mvn],ax
        mov  ax,[pah+si]
.tyaw: sub  ax,[heading]
        and  ax,255
        push ax
        call CODE:SINQF
        mov  [msin],ax
        pop  ax
        add  ax,64
        call CODE:SINQF
        mov  [mcos],ax
        xor  si,si
        xor  di,di
.tv2:  mov  bx,[mvb]
        mov  ax,[bx+si]         ; vx = (mx*mcos + mz*msin)/256
        imul word [mcos]
        mov  cx,ax
        mov  bx,[mvb]
        mov  ax,[bx+si+4]
        imul word [msin]
        add  ax,cx
        cwd
        mov  bx,256
        idiv bx
        mov  [dsx],ax
        mov  bx,[mvb]
        mov  ax,[bx+si]         ; vz = (mz*mcos - mx*msin)/256 + 300
        imul word [msin]
        mov  cx,ax
        mov  bx,[mvb]
        mov  ax,[bx+si+4]
        imul word [mcos]
        sub  ax,cx
        cwd
        mov  bx,256
        idiv bx
        add  ax,[tgzo]          ; how far the page stands off the model
        mov  [dsac],ax
        mov  ax,[dsx]           ; sx = screen centre + vx*64/vz (centre MFD)
        mov  bx,64
        imul bx
        idiv word [dsac]
        add  ax,PZADICX
        mov  [PVX+di],ax
        mov  bx,[mvb]
        mov  ax,[bx+si+2]       ; sy = screen centre - vy*64/vz
        sub  ax,[tgyc]          ; a mast is modelled from its FEET up
        mov  bx,64
        imul bx
        idiv word [dsac]
        mov  bx,PZADICY
        sub  bx,ax
        mov  [PVY+di],bx
        add  si,6
        add  di,2
        cmp  si,[mvn]
        jb   .tv2
        cmp  word [locki],RSLK
        jb   .tedg
        ; ---- the GROUND models have no edge list: walk their FACES and
        ; close each quad. Four lines a face - the MFD can afford it, and
        ; it saves carrying a second table per page. Driven off mfb/nfc,
        ; so the dish and the gun drum share the one walk; only aeroplanes
        ; still take WEDG below, and WEDG is the only table that ever fit
        ; them ----
        xor  si,si              ; face record (5 bytes)
.tf:   xor  di,di              ; corner 0..3
.tfc:  mov  bx,si
        add  bx,di
        add  bx,[mfb]
        mov  al,[bx]            ; corner k...
        xor  ah,ah
        mov  bx,ax
        add  bx,bx
        mov  ax,[PVX+bx]
        mov  [sx0],ax
        mov  ax,[PVY+bx]
        mov  [sy0],ax
        mov  bx,di              ; ...to corner k+1, wrapping to close it
        inc  bx
        and  bx,3
        add  bx,si
        add  bx,[mfb]
        mov  al,[bx]
        xor  ah,ah
        mov  bx,ax
        add  bx,bx
        mov  ax,[PVX+bx]
        mov  [sx1],ax
        mov  ax,[PVY+bx]
        mov  [sy1],ax
        mov  byte [COLOR],95
        push si
        push di
        call CODE:CLIPLINF
        jc   .tfn
        call CODE:LINEF
.tfn:  pop  di
        pop  si
        inc  di
        cmp  di,4
        jb   .tfc
        add  si,5
        mov  ax,[nfc]           ; nfc*5, the length of this face table
        mov  bx,ax
        shl  ax,1
        shl  ax,1
        add  ax,bx
        cmp  si,ax
        jb   .tf
        ret
.tedg: xor  si,si              ; sensor-green edges
.te:   mov  al,[WEDG+si]
        xor  ah,ah
        add  ax,ax
        mov  bx,ax
        mov  ax,[PVX+bx]
        mov  [sx0],ax
        mov  ax,[PVY+bx]
        mov  [sy0],ax
        mov  al,[WEDG+si+1]
        xor  ah,ah
        add  ax,ax
        mov  bx,ax
        mov  ax,[PVX+bx]
        mov  [sx1],ax
        mov  ax,[PVY+bx]
        mov  [sy1],ax
        mov  byte [COLOR],95
        push si
        call CODE:CLIPLINF
        jc   .ten
        call CODE:LINEF
.ten:  pop  si
        add  si,2
        cmp  si,NWEDG*2
        jb   .te
        ret

