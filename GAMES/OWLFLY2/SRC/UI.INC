; UI.INC - part of WIRE CITY (included from CITY.ASM, between SKY.INC
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

UISEG   SEGMENT PARA PUBLIC 'CODE'
        ASSUME  CS:UISEG, DS:CODE, ES:NOTHING, SS:CODE

NGL     equ 8                   ; game list rows
GLSZ    equ 16                  ; entry: gid,seed,nplr,scG,scY,bots,name8

; ---- data (before code: the forward-reference override lesson) -------------
GLIST   db NGL*GLSZ dup(0)      ; the skies on the wire (gid=0: empty)
GLAST   dw NGL dup(0)           ; BIOS tick each ad last landed
prevk   db 128 dup(0)           ; last frame's KEYS (edge detection)
uisel   db 0                    ; menu: selected row
uimode  db 0                    ; 0 = the list, 1 = naming a new sky
uitick  dw 0                    ; last BIOS tick the menu redrew on
unlen   db 0                    ; letters typed into the name so far
sptick  dw 0                    ; splash: frame counter
sptc    dw 0                    ; splash: the rising roar's TC
; scancode -> letter for the name field (0 = not a letter)
SC2CH   db 0,0,'1','2','3','4','5','6','7','8','9','0',0,0,0,0
        db 'Q','W','E','R','T','Y','U','I','O','P',0,0,0,0
        db 'A','S','D','F','G','H','J','K','L',0,0,0,0,0
        db 'Z','X','C','V','B','N','M',0,0,0,0,0,0,0
        db 70 dup(0)            ; 16+14+14+14+70 = the full 128
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
; ---- THE SHILKAS. Every word of their state lives HERE, in UISEG, not in
; the main segment the way the radar stations' did: the two models alone
; cost that segment 403 of its 597 remaining bytes, and a vehicle that will
; grow a course, a target and a magazine cannot also rent space there. The
; price is a cs: on every access - code out here runs with DS = the main
; segment, so an unprefixed [shkx] would read the wrong 64K and say nothing
; about it. If a Shilka ever misbehaves, look for a missing cs: first.
shkx    dw NSHILK dup(0)        ; where each one stands...
shky    dw NSHILK dup(0)        ;  (shky = the ground under its tracks)
shkz    dw NSHILK dup(0)
shkh    db NSHILK dup(0)        ; the hull's heading, 0..255
shkt    db NSHILK dup(0)        ; the turret's bearing - its OWN, and the
                                ;  whole point of the second model
shkd    db NSHILK dup(0)        ; the RADAR's bearing. This is the part that
                                ;  turns by itself; the guns only move when
                                ;  they have somewhere to point
shkel   db NSHILK dup(0)        ; and how high the barrels are pointing
; ---- THE CONTROL LAYER. These are INPUTS, not behaviour: a demanded
; heading, a demanded turret bearing and elevation, and a trigger. SHKAI
; fills them today; the day the pilot climbs into one of these, HIS hands
; fill them instead and nothing below has to change. That is the whole
; reason they are named and separate.
shkhd   db NSHILK dup(0)        ; heading DEMAND - where it wants to be going
shktrg  db NSHILK dup(0)        ; trigger: 1 = firing this tick
shkft   db NSHILK dup(0)        ; ticks until the gun will feed again
shklgt  db NSHILK dup(0)        ; ticks left on this patrol leg
shktgt  dw NSHILK dup(0)        ; who it is shooting at (0FFFFh = the pilot)
shkax   dw NSHILK dup(0)        ; the post it patrols around - it always
shkaz   dw NSHILK dup(0)        ;  comes back to this
mprow   dw 0                    ; the map row a mark landed on. MMPTY hands
                                ;  it back in AX and UROW consumes AX, so a
                                ;  symbol that wants the row as well as the
                                ;  buffer offset has to be given somewhere
                                ;  to keep it
shkst   db NSHILK dup(0)        ; 0 = fighting, 1 = burning
shkhp   db NSHILK dup(SHKHITS)  ; what it has left in it
shki    dw 0                    ; the vehicle being planted, ticked or drawn
shkp    dw 0                    ; SHKGND: probe counter...
shkb    dw 0                    ;  ...the nominal site...
shkc    dw 0                    ;  ...and the best ground found so far
shke    dw 0                    ; SHKAIM: which side we are on...
shkg    dw 0                    ;  ...and the best target it found
shkq    dw 0                    ;  ...its bearing, while the pitch is worked
shkv    dw 0                    ;  ...and our own roof height
; Their sites, as offsets from the map centre (24576,24576) - the same
; spine the squadrons and the radar stations form up on. Ours south of the
; front line, theirs north, mirrored so neither side is handed the ground:
; two flanks 6000 out and a picket pushed forward on the centreline.
; INTERLEAVED: even slots ours, odd slots theirs. This game reads a side
; off the SLOT'S PARITY everywhere - the jets do it, the radar stations do
; it through their lock encoding - and a Shilka that broke the rule would
; need its own IFF test in every place that draws or targets one. So the
; six alternate: 0/2/4 south of the line, 1/3/5 north, mirrored.
; Ten a side, in two belts, interleaved by slot so the parity rule holds.
; The FORWARD belt sits over the towns near the line; the REAR belt sits
; back where each side's radar mast stands, so the mast is never naked.
; Everything is an offset from the map centre, and the two sides mirror.
SHKPX   dw -12000,-12000, -6000,-6000,     0,    0,  6000, 6000
        dw  12000, 12000, -9000,-9000, -3000,-3000,  3000, 3000
        dw   9000,  9000,     0,    0
SHKPZ   dw  -2500,  2500, -2500, 2500, -2500, 2500, -2500, 2500
        dw  -2500,  2500, -6800, 6800, -6800, 6800, -6800, 6800
        dw  -6800,  6800, -7400, 7400
; the strings live HERE and UFDRAW/UBIG read CS:SI - the main segment
; pays nothing for the front door's words (its stack guard insisted)
UWIRE0  db 'NO IPX',0
UWIRE1  db 'WIRE DARK - RUN NETHOST OR NETJOIN',0
UWIRE2  db 'WIRE LIVE',0
UTITLE  db 'OWL FLY II',0
USUB    db 'WIRE CITY SQUADRON',0
UHDR    db 'SKIES ON THE WIRE:',0
UEMPTY  db 'STATIC ONLY - CREATE ONE',0
UCREAT  db 'C  NEW SKY',0
UJOIN   db 'ENTER  FLY    UP DN  PICK',0
UNAME   db 'NAME:',0
UBOTS1  db 'B  BOTS ON   ENTER  GO',0
UBOTS0  db 'B  BOTS OFF  ENTER  GO',0
UPLR    db ' PLR  ',0
UJARR   db '-',0
UCOLN   db ':',0
NBU     db 4 dup(0)             ; UNUM2's digits
unamec  db 9 dup(0)             ; gname's CS-side mirror for drawing

; ============================ the far doors =================================
UISPLASH PROC FAR
        call XSPLASH
        ret
UISPLASH ENDP
UIMENU  PROC FAR
        call XMENU
        ret
UIMENU  ENDP

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
UBLIT:  push ds
        push es
        mov  ax,[bufseg]
        mov  ds,ax
        mov  ax,0A000h
        mov  es,ax
        xor  si,si
        xor  di,di
        mov  cx,32000
        cld
        rep  movsw
        pop  es
        pop  ds
        ret

; ---- UFDRAW: ASCIIZ at CS:SI, position ftx/fty, colour COLOR ---------------
; The main FDRAW's twin, reading OUR OWN segment (all the front
; door's words live here). ES must be the back buffer.
UFDRAW:
@@ch:   mov  al,cs:[si]
        inc  si
        test al,al
        jz   @@done
        cmp  al,' '
        je   @@adv
        cmp  al,':'
        jne  @@nc
        mov  al,38              ; the colon glyph
        jmp  @@dr
@@nc:   cmp  al,'-'
        jne  @@nm
        mov  al,37              ; the minus glyph
        jmp  @@dr
@@nm:   cmp  al,'9'
        ja   @@alf
        sub  al,'0'
        jmp  @@dr
@@alf:  sub  al,'A'-10
@@dr:   push si
        xor  ah,ah
        mov  bx,ax
        add  ax,ax
        add  ax,ax
        add  ax,bx
        add  ax,bx              ; *6
        mov  si,offset FONTBUF
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
@@row:  mov  al,[si]
        mov  ah,[COLOR]
        test al,80h
        jz   @@p1
        mov  es:[di],ah
@@p1:   test al,40h
        jz   @@p2
        mov  es:[di+1],ah
@@p2:   test al,20h
        jz   @@p3
        mov  es:[di+2],ah
@@p3:   inc  si
        add  di,320
        loop @@row
        pop  si
@@adv:  add  word ptr [ftx],4
        jmp  @@ch
@@done: ret

; ---- UBIG: the same string at triple size (each dot a 3x3 block) -----------
UBIG:
@@ch:   mov  al,cs:[si]
        inc  si
        test al,al
        jz   @@done
        cmp  al,' '
        je   @@adv
        cmp  al,'9'
        ja   @@alf
        sub  al,'0'
        jmp  @@dr
@@alf:  sub  al,'A'-10
@@dr:   push si
        xor  ah,ah
        mov  bx,ax
        add  ax,ax
        add  ax,ax
        add  ax,bx
        add  ax,bx
        mov  si,offset FONTBUF
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
@@row:  push cx
        mov  al,[si]
        mov  cx,3               ; three screen rows per glyph row
@@r3:   push cx
        push di
        mov  ah,al
        mov  cl,3
@@bits: test ah,80h
        jz   @@nx
        push ax
        mov  al,[COLOR]
        mov  es:[di],al
        mov  es:[di+1],al
        mov  es:[di+2],al
        pop  ax
@@nx:   add  di,3
        shl  ah,1
        dec  cl
        jnz  @@bits
        pop  di
        add  di,320
        pop  cx
        loop @@r3
        inc  si
        pop  cx
        loop @@row
        pop  si
@@adv:  add  word ptr [ftx],12
        jmp  @@ch
@@done: ret

; ---- ULINE: Bresenham (uilx0,uily0)-(uilx1,uily1), colour COLOR ------------
; Clips by skipping off-glass dots: splash lines are short-lived.
ULINE:  mov  ax,[uilx1]
        sub  ax,[uilx0]
        mov  bx,1
        or   ax,ax
        jns  @@dx1
        neg  ax
        neg  bx
@@dx1:  mov  [uldx],ax          ; |dx|, step
        mov  [ulsx],bx
        mov  ax,[uily1]
        sub  ax,[uily0]
        mov  bx,1
        or   ax,ax
        jns  @@dy1
        neg  ax
        neg  bx
@@dy1:  mov  [uldy],ax
        mov  [ulsy],bx
        mov  ax,[uldx]
        sub  ax,[uldy]
        mov  [ulerr],ax         ; err = dx - dy
@@pt:   mov  ax,[uily0]         ; plot if on glass
        or   ax,ax
        js   @@st
        cmp  ax,199
        jg   @@st
        mov  bx,[uilx0]
        or   bx,bx
        js   @@st
        cmp  bx,319
        jg   @@st
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
        mov  es:[di],al
@@st:   mov  ax,[uilx0]         ; done?
        cmp  ax,[uilx1]
        jne  @@go
        mov  ax,[uily0]
        cmp  ax,[uily1]
        je   @@done
@@go:   mov  ax,[ulerr]
        add  ax,ax
        mov  bx,ax
        mov  ax,[uldy]
        neg  ax
        cmp  bx,ax              ; e2 > -dy ?
        jle  @@sk1
        mov  ax,[uldy]
        sub  [ulerr],ax
        mov  ax,[ulsx]
        add  [uilx0],ax
@@sk1:  mov  ax,[uldx]
        cmp  bx,ax              ; e2 < dx ?
        jge  @@pt
        add  [ulerr],ax
        mov  ax,[ulsy]
        add  [uily0],ax
        jmp  @@pt
@@done: ret

; ---- USBWR: DSP write clone (the roar needs no main-segment help) ----------
USBWR:  push cx
        mov  dx,22Ch
        mov  cx,1000
@@w:    in   al,dx
        test al,80h
        jz   @@go
        loop @@w
@@go:   mov  al,ah
        out  dx,al
        pop  cx
        ret

; ---- UANYK: AL=1 if any key is down ----------------------------------------
UANYK:  push si
        xor  si,si
        xor  al,al
@@s:    cmp  byte ptr [KEYS+si],0
        jne  @@yes
        inc  si
        cmp  si,88h
        jb   @@s
        pop  si
        ret
@@yes:  mov  al,1
        pop  si
        ret

; ---- UEDGE: newly-pressed scancode -> AL (0 none). One per call. -----------
; The second build of this door: everything through DS, scan stops at
; 53h (the last honest scancode), the dumbest possible logic.
UEDGE:  push si
        mov  si,1
@@s:    cmp  byte ptr [KEYS+si],0
        je   @@up
        cmp  byte ptr [kprev+si],0
        jne  @@nx               ; still held from before
        mov  byte ptr [kprev+si],1
        mov  ax,si              ; a fresh press: report it
        pop  si
        ret
@@up:   mov  byte ptr [kprev+si],0
@@nx:   inc  si
        cmp  si,54h
        jb   @@s
        xor  ax,ax
        pop  si
        ret

; ============================================================================
;  XSPLASH - three wireframe F15s out of the horizon, straight at you,
;  under a spooling turbine and the big title. Any key skips.
; ============================================================================
XSPLASH:
        push es
        mov  word ptr [sptick],0
        mov  word ptr [sptc],70
@@fr:   mov  al,UBLACK          ; a true black night
        call UCLS
        mov  bx,[bufseg]
        mov  es,bx
        ; ---- the three-ship: centre jet leads, wingmen trail ----
        mov  ax,[sptick]
        mov  cx,70
        imul cx
        mov  bx,5200
        sub  bx,ax              ; lead z: 5200 -> 300
        cmp  bx,260
        jge  @@z1
        mov  bx,260
@@z1:   mov  [ujz],bx
        mov  word ptr [ujx],0
        call UJET
        mov  ax,[ujz]
        add  ax,600            ; the wingmen hang back
        mov  [ujz],ax
        mov  word ptr [ujx],-1500
        call UJET
        mov  word ptr [ujx],1500
        call UJET
        ; ---- the title, once the jets are rolling in ----
        cmp  word ptr [sptick],18
        jb   @@nt
        mov  word ptr [ftx],100
        mov  word ptr [fty],30
        mov  byte ptr [COLOR],97
        mov  si,offset UTITLE
        call UBIG
        mov  word ptr [ftx],124
        mov  word ptr [fty],58
        mov  byte ptr [COLOR],8
        mov  si,offset USUB
        call UFDRAW
@@nt:   call UBLIT
        ; ---- the roar climbs with them ----
        cmp  byte ptr [sbok],0
        je   @@nsb
        mov  ax,[sptick]
        and  ax,3
        jnz  @@nsb
        inc  word ptr [sptc]
        cmp  word ptr [sptc],150
        jg   @@nsb
        mov  ah,40h
        call USBWR
        mov  ax,[sptc]
        mov  ah,al
        call USBWR
@@nsb:  ; ---- pace on the BIOS tick, ~4 seconds, any key out ----
        push es
        mov  ax,40h
        mov  es,ax
@@tw:   mov  ax,es:[6Ch]
        cmp  ax,cs:[uitick]
        je   @@tw
        mov  cs:[uitick],ax
        pop  es
        call UANYK
        or   al,al
        jnz  @@out
        inc  word ptr [sptick]
        cmp  word ptr [sptick],72
        jb   @@fr
@@out:  pop  es
        ret

; ---- UJET: one wireframe F15 at (ujx, ujz), model x24 ----------------------
; Every face's four edges through the plain gate: sx = 160 + X*220/z.
UJET:   push es
        mov  bx,[bufseg]
        mov  es,bx
        mov  byte ptr [COLOR],8
        xor  si,si              ; face byte index
@@f:    mov  al,[F15FC+si]      ; corner 0 opens the loop...
        call UJPRJ
        mov  ax,[ujsx]
        mov  [uilx1],ax
        mov  ax,[ujsy]
        mov  [uily1],ax
        mov  cx,4
        push si
@@e:    mov  ax,[uilx1]         ; previous corner becomes the tail
        mov  [uilx0],ax
        mov  ax,[uily1]
        mov  [uily0],ax
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
        mov  ax,[ujsx]
        mov  [uilx1],ax
        mov  ax,[ujsy]
        mov  [uily1],ax
        push cx                 ; ULINE eats CL with its shifts - and
        push [uilx0]            ; this loop LIVES on CX (the ninth
        push [uily0]            ; integer trap: a clobbered counter
        push [uilx1]            ; makes an immortal loop)
        push [uily1]
        call ULINE
        pop  [uily1]
        pop  [uilx1]
        pop  [uily0]
        pop  [uilx0]
        pop  cx
        loop @@e
        pop  si
        add  si,5
        cmp  si,F15NF*5
        jb   @@f
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
        add  ax,[ujx]
        mov  cx,220
        imul cx
        idiv word ptr [ujz]
        add  ax,160
        mov  [ujsx],ax
        mov  ax,[F15VT+si+2]    ; y*24, a touch below centre
        mov  cx,24
        imul cx
        sub  ax,120
        mov  cx,220
        imul cx
        idiv word ptr [ujz]
        neg  ax
        add  ax,104
        mov  [ujsy],ax
        pop  si
        ret

; ============================================================================
;  XMENU - the sky list. Lives until the pilot picks: gact 1 = create
;  (gname/gbots ready), 2 = join (rseed/wseed/ggid set).
; ============================================================================
XMENU:
        push es
        mov  byte ptr [uimode],0
        mov  byte ptr [uisel],0
@@loop: call FAR PTR NETPOLLF   ; the wire fills GLIST while we draw
        ; ---- prune skies gone quiet for ~3 s ----
        push es
        mov  ax,40h
        mov  es,ax
        mov  dx,es:[6Ch]
        pop  es
        xor  si,si
@@pr:   mov  bx,si
        mov  cl,4
        shl  bx,cl
        cmp  word ptr cs:[GLIST+bx],0
        je   @@prn
        mov  ax,si
        add  ax,ax
        mov  di,ax
        mov  ax,dx
        sub  ax,cs:[GLAST+di]
        cmp  ax,55
        jb   @@prn
        mov  word ptr cs:[GLIST+bx],0
@@prn:  inc  si
        cmp  si,NGL
        jb   @@pr
        ; ---- draw ----
        mov  al,UBLACK
        call UCLS
        mov  bx,[bufseg]
        mov  es,bx
        mov  word ptr [ftx],100
        mov  word ptr [fty],16
        mov  byte ptr [COLOR],97
        mov  si,offset UTITLE
        call UBIG
        mov  word ptr [ftx],124
        mov  word ptr [fty],44
        mov  byte ptr [COLOR],8
        mov  si,offset USUB
        call UFDRAW
        mov  word ptr [ftx],40
        mov  word ptr [fty],64
        mov  byte ptr [COLOR],106
        mov  si,offset UHDR
        call UFDRAW
        ; the wire verdict, top-left, in its own colour
        mov  word ptr [ftx],4
        mov  word ptr [fty],4
        mov  byte ptr [COLOR],2
        mov  si,offset UWIRE0
        cmp  byte ptr [netup],1
        jb   @@wv
        mov  si,offset UWIRE1
        mov  byte ptr [COLOR],19 ; a dark wire glows warning red
        je   @@wv
        mov  si,offset UWIRE2
        mov  byte ptr [COLOR],95 ; a live one, friendly green
@@wv:   call UFDRAW
        ; the rows
        xor  si,si              ; row = list index
        mov  word ptr [dsy],0   ; rows actually shown
@@row:  mov  bx,si
        mov  cl,4
        shl  bx,cl
        cmp  word ptr cs:[GLIST+bx],0
        je   @@rn
        mov  ax,[dsy]
        mov  cx,10
        imul cx
        add  ax,76
        mov  [fty],ax
        mov  word ptr [ftx],48
        mov  byte ptr [COLOR],8
        mov  al,[uisel]
        xor  ah,ah
        cmp  ax,si
        jne  @@rc
        mov  byte ptr [COLOR],97 ; the picked sky glows amber
        push si
        push bx
        mov  word ptr [ftx],40
        mov  si,offset UJARR
        call UFDRAW
        pop  bx
        pop  si
        mov  word ptr [ftx],48
@@rc:   push si
        push bx
        lea  si,[GLIST+bx+8]    ; the name (8 chars, NUL-padded) lives
        call UFDRAW             ; here with us: plain CS read
        mov  word ptr [ftx],96
        pop  bx
        push bx
        mov  al,cs:[GLIST+bx+4] ; players
        xor  ah,ah
        call UNUM2
        pop  bx
        push bx
        mov  si,offset UPLR
        call UFDRAW
        pop  bx
        push bx
        mov  al,cs:[GLIST+bx+5] ; the war score
        xor  ah,ah
        call UNUM2
        pop  bx
        push bx
        mov  si,offset UCOLN
        call UFDRAW
        pop  bx
        push bx
        mov  al,cs:[GLIST+bx+6]
        xor  ah,ah
        call UNUM2
        pop  bx
        pop  si
        inc  word ptr [dsy]
@@rn:   inc  si
        cmp  si,NGL
        jb   @@row
        cmp  word ptr [dsy],0
        jne  @@hasl
        mov  word ptr [ftx],48  ; an empty wire
        mov  word ptr [fty],80
        mov  byte ptr [COLOR],2
        mov  si,offset UEMPTY
        call UFDRAW
@@hasl:
        ; the footer: create line (with live name in mode 1)
        mov  word ptr [ftx],40
        mov  word ptr [fty],164
        mov  byte ptr [COLOR],8
        cmp  byte ptr [uimode],0
        jne  @@m1
        mov  si,offset UCREAT
        call UFDRAW
        mov  word ptr [ftx],40
        mov  word ptr [fty],176
        mov  byte ptr [COLOR],2
        mov  si,offset UJOIN
        call UFDRAW
        jmp  @@dbl
@@m1:   mov  si,offset UNAME
        call UFDRAW
        mov  word ptr [ftx],68
        push si                 ; the name so far: mirror DS gname into
        xor  si,si              ; our segment for the CS-reading font
@@nmc:  mov  al,[gname+si]
        mov  cs:[unamec+si],al
        inc  si
        cmp  si,9
        jb   @@nmc
        pop  si
        mov  si,offset unamec
        call UFDRAW
        mov  word ptr [ftx],40
        mov  word ptr [fty],176
        mov  si,offset UBOTS1
        cmp  byte ptr [gbots],0
        jne  @@bl
        mov  si,offset UBOTS0
@@bl:   call UFDRAW
@@dbl:  call UBLIT
        ; ---- one redraw per BIOS tick (alive again now that the ESR
        ; bell is masked and the tick actually ticks) ----
        push es
        mov  ax,40h
        mov  es,ax
@@tw:   mov  ax,es:[6Ch]
        cmp  ax,cs:[uitick]
        je   @@tw
        mov  cs:[uitick],ax
        pop  es
        ; ---- keys ----
        call UEDGE
        or   al,al
        jz   @@loop
        cmp  byte ptr [uimode],0
        jne  @@keys1
        cmp  al,48h             ; up
        jne  @@k2
        cmp  byte ptr [uisel],0
        je   @@loop
        dec  byte ptr [uisel]
        jmp  @@loop
@@k2:   cmp  al,50h             ; down
        jne  @@k3
        cmp  byte ptr [uisel],NGL-1
        jae  @@loop
        inc  byte ptr [uisel]
        jmp  @@loop
@@k3:   cmp  al,2Eh             ; C: name a new sky
        jne  @@k4
        mov  byte ptr [uimode],1
        mov  byte ptr [unlen],0
        mov  di,offset gname    ; clean slate
        mov  cx,8
        mov  al,0
        cld
        push es
        push ds
        pop  es
        rep  stosb
        pop  es
        jmp  @@loop
@@k4:   cmp  al,1Ch             ; enter: fly the picked sky
        jne  @@loop
        mov  al,[uisel]
        xor  ah,ah
        mov  bx,ax
        mov  cl,4
        shl  bx,cl
        cmp  word ptr cs:[GLIST+bx],0
        je   @@loop             ; picked an empty row
        mov  ax,word ptr cs:[GLIST+bx]
        mov  [ggid],ax
        mov  ax,word ptr cs:[GLIST+bx+2]
        mov  [rseed],ax
        mov  [wseed],ax
        mov  byte ptr [gact],2
        pop  es
        ret
@@keys1:
        cmp  al,1Ch             ; enter: launch the new sky
        jne  @@n1
        cmp  byte ptr [unlen],0
        je   @@loop             ; a sky needs a name
        mov  byte ptr [gact],1
        pop  es
        ret
@@n1:   cmp  al,30h             ; B: bots on/off
        jne  @@n2
        xor  byte ptr [gbots],1
        jmp  @@loop
@@n2:   cmp  al,0Eh             ; backspace
        jne  @@n3
        cmp  byte ptr [unlen],0
        je   @@loop
        dec  byte ptr [unlen]
        mov  al,[unlen]
        xor  ah,ah
        mov  di,ax
        mov  byte ptr [gname+di],0
        jmp  @@loop
@@n3:   cmp  al,1               ; esc backs out of naming
        jne  @@n4
        mov  byte ptr [uimode],0
        jmp  @@loop
@@n4:   xor  ah,ah              ; a letter?
        mov  si,ax
        mov  al,cs:[SC2CH+si]
        or   al,al
        jz   @@loop
        cmp  byte ptr [unlen],8
        jae  @@loop
        push ax
        mov  al,[unlen]
        xor  ah,ah
        mov  di,ax
        pop  ax
        mov  [gname+di],al
        inc  byte ptr [unlen]
        jmp  @@loop

; ---- UNUM2: AL (0..99) as two digits ---------------------------------------
UNUM2:  xor  ah,ah
        mov  bl,10
        div  bl
        add  al,'0'
        add  ah,'0'
        mov  cs:[NBU],al
        mov  cs:[NBU+1],ah
        mov  byte ptr cs:[NBU+2],0
        push si
        mov  si,offset NBU
        call UFDRAW
        pop  si
        ret

; ============================================================================
; ============================================================================
;  APPLYPALF - the palette loader, far (evicted from the main segment
;  2026-07-27 with both tables: 648 bytes of once-at-startup DAC data
;  paid the stack guard's rent for the SA pages). Reads [daymode],
;  streams the matching table to the DAC. Trashes AX,CX,DX,SI.
; ============================================================================
PALDAY  db 36,37,40          ;0  wall N/S (light grey)
        db 30,32,36          ;1  far stroke (fades to haze)
        db 22,24,28          ;2  mid stroke
        db 12,13,16          ;3  near stroke (dark on light)
        db 16,22,32          ;4  window (dark glass)
        db 24,28,38          ;5  window (lighter glass)
        db 18,32,16          ;6  ground grid
        db 18,32,58          ;7  sky top (blue)
        db 63,63,63          ;8  HUD / white
        db 34,46,62          ;9  sky band (lighter near horizon)
        db 22,38,18          ;10 ground (green)
        db 32,46,28          ;11 field / ground band near horizon
        db 50,56,63          ;12 haze at the horizon (near white)
        db 26,17,10          ;13 mountains/rock (dark brown)
        db 16,32,54          ;14 water
        db 12,27,10          ;15 forest
        db 28,29,33          ;16 wall E/W (shaded side)
        db 44,45,48          ;17 roof (sun-lit)
        db 33,24,14          ;18 minimap city (brown)
        db 63, 6, 6          ;19 red (map course tick)
        db 30,34,48          ;20 blue wall lit
        db 22,26,40          ;21 blue wall shade
        db 46,28,22          ;22 red wall lit
        db 34,20,16          ;23 red wall shade
        db 52,52,54          ;24 white wall lit
        db 40,40,44          ;25 white wall shade
        db 24,38,60          ;26 sky step 2 (F-15 gradient)
        db 42,51,63          ;27 sky step 4, next to the haze
        db 14,26,12          ;28 dark far ground at the horizon
        db 10,10,12          ;29 cockpit panel (dark)
        db 20,20,23          ;30 cockpit panel trim
        include PALPNL.INC   ; 31..93 photo cockpit (generated)
        db 63,34, 6          ;94 engine glow (GAMELOOP cycles this DAC slot)
        db 16,63,16          ;95 IFF friendly (bright green)
        db 63,63, 8          ;96 IFF hostile (bright yellow)
        db 63,44, 6          ;97 UI amber (index 5 is glass by day)
        db 12,22,42          ;98 NEWTON sky ramp: zenith deep...
        db 15,26,48          ;99
        db 18,30,53          ;100
        db 22,35,58          ;101
        db 27,41,62          ;102 ...the haze over the horizon
        db 46,50,60          ;103 cloud ramp: base...
        db 58,59,63          ;104 ...sunlit top
        db 34,36,40          ;105 HUD dim: the pitch ladder - darker
                             ;    than the clouds, lighter than the
                             ;    ground (white vanishes in cumulus)
        db 30,58,63          ;106 HUD cyan: the IVV caret
        db  0, 0, 0          ;107 true black (the front door's night)
        ; ---- THE PANEL'S OWN COLOURS. The legends were being drawn in HUD
        ; colours, and that is why they jumped out of the picture: HUD
        ; colours are made to survive being projected over a bright sky and
        ; have to shout. A legend printed inside a dark cockpit is read at
        ; arm's length off black plastic and should barely glow. Same words,
        ; different job, so: different colours.
        db 22,23,26          ;108 panel legend, the lamp captions
        db 14,14,16          ;109 panel legend, unlit
        db 10,40,12          ;110 panel green: a system is OUT
        db 44,31, 4          ;111 panel amber: a caution
        db 44, 5, 5          ;112 panel red: a warning
        db  5,20, 6          ;113 ...and each one's shadow, for the round
        db 22,15, 2          ;114 lenses on the option-select columns
        db 22, 3, 3          ;115
        db  6, 6, 8          ;116 annunciator glass speckle
        db  8,34,10          ;117 scanline shades - a hair under the
        db 38,26, 3          ;118  core, not the lens shadow
        db 38, 4, 4          ;119
        ; ---- the streets and what drives on them. The city is grey by
        ; design; the traffic is the only thing in it allowed to be a
        ; colour. Each vehicle paint is a lit face and a shaded one, the
        ; same pairing WSCH gives the walls.
        db 17,18,20          ;120 asphalt
        db 52,12,12          ;121 red
        db 34, 7, 7          ;122
        db 16,28,54          ;123 blue
        db 10,18,36          ;124
        db 56,50,14          ;125 yellow - the buses and the odd taxi
        db 38,33, 8          ;126
        db 14,42,22          ;127 green
        db  9,28,14          ;128
        db 56,56,58          ;129 white
        db 38,38,40          ;130
        db 24,25,28          ;131 charcoal
        db 15,16,19          ;132
        db 58,32, 8          ;133 orange
        db 40,21, 5          ;134
        db 12,44,46          ;135 teal
        db  8,30,31          ;136

PALNITE db  2, 3, 9          ;0  wall N/S (dark body)
        db 12,18,40          ;1  far stroke
        db 22,33,58          ;2  mid stroke
        db 40,55,63          ;3  near stroke (bright on dark)
        db 50,60,63          ;4  window (lit cyan)
        db 63,48,20          ;5  window (lit amber)
        db 10,16,34          ;6  ground grid
        db  6, 9,22          ;7  sky top
        db 60,63,63          ;8  HUD / white
        db 12,17,40          ;9  sky band (city glow)
        db  4, 6,16          ;10 ground
        db  7,10,24          ;11 field / ground band
        db 18,24,48          ;12 haze (glow at horizon)
        db 10, 7, 4          ;13 mountains/rock (dark brown)
        db  8,14,38          ;14 water
        db  3, 7,13          ;15 forest
        db  2, 3, 9          ;16 wall E/W (same as body at night)
        db  3, 4,11          ;17 roof
        db 14,10, 6          ;18 minimap city (brown)
        db 52, 5, 5          ;19 red (map course tick)
        db  4, 5,14          ;20 blue wall lit
        db  3, 4,11          ;21 blue wall shade
        db  8, 4, 5          ;22 red wall lit
        db  6, 3, 4          ;23 red wall shade
        db  5, 6,12          ;24 white wall lit
        db  4, 4, 9          ;25 white wall shade
        db  8,12,30          ;26 sky step 2
        db 14,19,44          ;27 sky step 4, next to the haze
        db  2, 4,10          ;28 dark far ground at the horizon
        db  6, 6, 8          ;29 cockpit panel (dark)
        db 12,12,15          ;30 cockpit panel trim
        include PALPNL.INC   ; 31..93 photo cockpit (same lamps at night)
        db 63,34, 6          ;94 engine glow (GAMELOOP cycles this DAC slot)
        db 16,63,16          ;95 IFF friendly (bright green)
        db 63,63, 8          ;96 IFF hostile (bright yellow)
        db 44,30, 4          ;97 UI amber (dimmed for the night)
        db  3, 5,14          ;98 NEWTON sky ramp by night: zenith...
        db  4, 7,18          ;99
        db  6, 9,23          ;100
        db  8,12,28          ;101
        db 10,15,33          ;102 ...the city-glow horizon
        db 14,17,26          ;103 cloud in moonlight: base...
        db 19,22,32          ;104 ...lit top
        db 20,22,27          ;105 HUD dim ladder, night-lit
        db 16,38,48          ;106 HUD cyan IVV, dimmed for the night
        db  0, 0, 0          ;107 true black
        db 13,14,16          ;108 panel legend, the lamp captions - and it
        db  8, 8,10          ;109 panel legend, unlit. Both dimmer again by
        db  6,24, 7          ;110 panel green: a cockpit at night is lit by
        db 26,18, 2          ;111 panel amber: its own instruments and
        db 26, 3, 3          ;112 panel red: nothing else
        db  3,12, 3          ;113 the shadows, dimmer again
        db 13, 9, 1          ;114
        db 13, 2, 2          ;115
        db  3, 3, 4          ;116 speckle, night
        db  5,20, 6          ;117 scanlines, night
        db 22,15, 2          ;118
        db 22, 2, 2          ;119
        ; ---- the streets by night. Tarmac goes nearly black; the paint
        ; keeps its hue but loses its light, because the only thing lighting
        ; a car at night is the city it is driving through.
        db  5, 6, 8          ;120 asphalt
        db 20, 5, 5          ;121 red
        db 13, 3, 3          ;122
        db  7,12,24          ;123 blue
        db  4, 8,16          ;124
        db 24,21, 6          ;125 yellow
        db 16,14, 4          ;126
        db  6,18,10          ;127 green
        db  4,12, 6          ;128
        db 24,24,26          ;129 white
        db 16,16,18          ;130
        db 10,11,13          ;131 charcoal
        db  6, 7, 8          ;132
        db 25,14, 4          ;133 orange
        db 17, 9, 2          ;134
        db  5,19,20          ;135 teal
        db  3,13,14          ;136

APPLYPALF PROC FAR
        push ds
        mov  al,[daymode]       ; read the DS flag before leaving home
        mov  si,offset PALDAY
        or   al,al
        jnz  @@go
        mov  si,offset PALNITE
@@go:   mov  ax,cs
        mov  ds,ax              ; the tables live HERE now
        mov  dx,3C8h
        xor  al,al
        out  dx,al
        mov  dx,3C9h
        mov  cx,NPALC*3
        cld
@@pl:   lodsb
        out  dx,al
        loop @@pl
        pop  ds
        ret
APPLYPALF ENDP

; ============================================================================
;  MINIMAP2F - the half-scale baked map (32x32) on the MFD, evicted
;  from the main segment 2026-07-27: the stack guard fired when the
;  radar grew its SA symbology, and the map only plots pixels - no
;  near calls home - so it pays rent out here. White plane blip, red
;  course tick, the front line in red. ES = bufseg (the caller's).
; ============================================================================
UROWF   PROC FAR                ; SYMSEG draws on the same glass and needs
        call UROW               ; the same row arithmetic; a near call
        ret                     ; cannot cross a segment, six bytes can
UROWF   ENDP
MINIMAP2F PROC FAR
        call MINIMAP2
        ret
MINIMAP2F ENDP

; ============================================================================
;  The scope symbols used to live here. They moved to SYMSEG (SRC\SYM.INC)
;  on 2026-07-29 when UISEG filled its 8K window - they were the cleanest
;  tenants to move, being pure drawing with no CS-relative data of their
;  own. What stays is SHKBLIP, which cannot: it walks the Shilkas' state,
;  and that state IS CS-relative to this segment.
; ============================================================================
SHKBLIPF PROC FAR
        call SHKBLIP
        ret
SHKBLIPF ENDP
SHKLKPOSF PROC FAR
        call SHKLKPOS
        ret
SHKLKPOSF ENDP
SHKLOCKF PROC FAR
        call SHKLOCK
        ret
SHKLOCKF ENDP
SHKHITF PROC FAR
        call SHKHIT
        ret
SHKHITF ENDP
SHKTBRGF PROC FAR               ; in: BX = Shilka index. out: AX = turret
        mov  al,cs:[shkt+bx]    ; bearing, 0..255. The TGT page draws the
        xor  ah,ah              ; model with it, so the page shows where
        ret                     ; the gun actually looks.
SHKTBRGF ENDP

; ---------------------------------------------------------------------------
;  SHKLKPOS - where a locked Shilka is, for the ring, the missile head and
;  the orbit camera. LKPOS lives in the main segment and cannot see this
;  vehicle's position - the state is CS-relative to UISEG - so it knocks
;  here instead. Aimed at half the vehicle's height: the turret, which is
;  what a missile should fly into and what the eye looks for.
;   in: BX = the Shilka's WORD index. Writes lkx/lky/lkz (main segment).
; ---------------------------------------------------------------------------
SHKLKPOS:
        mov  ax,cs:[shkx+bx]
        mov  [lkx],ax
        mov  ax,cs:[shky+bx]
        add  ax,SHKTOP/2
        mov  [lky],ax
        mov  ax,cs:[shkz+bx]
        mov  [lkz],ax
        ret

; ---------------------------------------------------------------------------
;  SHKLOCK - the third leg of the ENTER scan, after the jets and the radar
;  stations, and it plays by the same rule they do: inside 24 px of the
;  ring, NEAREST WINS. So a jet crossing in front of a battery still takes
;  the lock, and picking the gun that is actually shooting at you is a
;  matter of pointing at it. Reads/writes [lockd] like the loops above.
; ---------------------------------------------------------------------------
SHKLOCK:
        mov  word ptr cs:[shki],0
@@sl:   mov  bx,cs:[shki]
        cmp  byte ptr cs:[shkst+bx],0
        jne  @@sln              ; rubble locks nothing
        add  bx,bx
        mov  ax,cs:[shkx+bx]
        sub  ax,[camx]
        mov  [wdx],ax
        mov  ax,cs:[shkz+bx]
        sub  ax,[camz]
        mov  [wdz],ax
        call FAR PTR ROTXZF
        mov  ax,[rcz]
        cmp  ax,NEARZ
        jl   @@sln
        mov  [tpi],ax           ; the range, for the nearest-wins test
        mov  bx,cs:[shki]
        add  bx,bx
        mov  dx,cs:[shky+bx]
        add  dx,SHKTOP/2
        sub  dx,[camy]
        mov  ax,[rcx]
        mov  cx,[rcz]
        call FAR PTR PPOINTF
        jc   @@sln
        sub  ax,160
        jns  @@sl1
        neg  ax
@@sl1:  cmp  ax,24
        jg   @@sln
        sub  dx,[horiz]
        jns  @@sl2
        neg  dx
@@sl2:  cmp  dx,24
        jg   @@sln
        mov  ax,[tpi]
        cmp  ax,[lockd]
        jae  @@sln
        mov  [lockd],ax
        mov  ax,cs:[shki]
        add  ax,ax
        add  ax,SHKLK
        mov  [locki],ax
@@sln:  inc  word ptr cs:[shki]
        cmp  word ptr cs:[shki],NSHILK
        jb   @@sl
        ret

; ---------------------------------------------------------------------------
SHKBLIP:
        cmp  byte ptr [rsst],0  ; our own radar out: no returns at all
        jne  @@sbd
        mov  word ptr [shki],0
@@sb:   mov  bx,cs:[shki]
        cmp  byte ptr cs:[shkst+bx],0
        jne  @@sbn              ; a wreck paints no return
        add  bx,bx
        mov  ax,cs:[shkx+bx]
        sub  ax,[camx]
        mov  [wdx],ax
        mov  ax,cs:[shkz+bx]
        sub  ax,[camz]
        mov  [wdz],ax
        call FAR PTR ROTXZF
        mov  cl,[rbsh]
        mov  ax,[rcx]
        sar  ax,cl
        cmp  ax,[rbrad]
        jg   @@sbn
        cmp  ax,[rbradn]
        jl   @@sbn
        mov  bx,[rcz]
        sar  bx,cl
        cmp  bx,[rbrad]
        jg   @@sbn
        cmp  bx,[rbradn]
        jl   @@sbn
        add  ax,[rbcx]
        mov  [bqx],ax
        mov  [dsx],ax
        mov  ax,[rbcy]
        sub  ax,bx              ; ahead = up the screen
        mov  [bqy],ax
        mov  ax,cs:[shki]       ; even ours, odd theirs - the parity rule
        test ax,1
        mov  al,95
        jz   @@sbc
        mov  al,19
@@sbc:  mov  [COLOR],al
        mov  ah,al
        mov  al,[rbsh]
        cmp  al,BQZICON
        jbe  @@sbi
        mov  al,ah              ; wound out: a dot like everything else
        mov  bx,cs:[shki]
        mov  ax,[bqy]
        call UROW
        add  di,[dsx]
        mov  al,ah
        mov  es:[di],al
        jmp  @@sbn
@@sbi:  mov  bx,cs:[shki]       ; the turret's real bearing, less ours
        mov  al,cs:[shkt+bx]
        xor  ah,ah
        sub  ax,[heading]
        and  ax,255
        mov  [bqa],ax
        call FAR PTR BQSHKF
@@sbn:  inc  word ptr cs:[shki]
        cmp  word ptr cs:[shki],NSHILK
        jb   @@sb
@@sbd:  ret

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
        jnz  @@mz1
        mov  word ptr [mmspx],64
        mov  word ptr [mmspy],64
        xor  ax,ax
        mov  [mmcol0],ax
        mov  [mmrow0],ax
        jmp  @@mtab
@@mz1:  dec  cl                 ; steps 1..3 are 1, 2 and 4 pixels a node
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
@@mtab: xor  bx,bx              ; dest x
@@ct:   mov  ax,bx
        call MMSCL
        add  ax,[mmcol0]
        and  ax,63
        mov  cs:[MMCOLT+bx],al
        inc  bx
        cmp  bx,PZADIW
        jb   @@ct
        ; ---- dest row -> source ROW BASE (node row * 64), ready to index
        xor  bx,bx
@@rt:   mov  ax,bx
        call MMSCL
        add  ax,[mmrow0]
        and  ax,63
        mov  cl,6
        shl  ax,cl              ; *64: the baked map is 64 bytes a row
        mov  si,bx
        add  si,si
        mov  cs:[MMROWT+si],ax
        inc  bx
        cmp  bx,PZADIH
        jb   @@rt
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
        jnz  @@s1
        mov  cx,4               ; *4/3
        imul cx
        mov  cx,3
        cwd
        idiv cx
        pop  cx
        ret
@@s1:   dec  cl
        shr  ax,cl
        pop  cx
        ret
MMSCLI: push cx
        mov  cl,[mmzs]
        or   cl,cl
        jnz  @@i1
        mov  cx,3               ; *3/4
        imul cx
        mov  cx,4
        cwd
        idiv cx
        pop  cx
        ret
@@i1:   dec  cl
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
        jae  @@xoff
        call MMSCLI
        add  ax,PZMMX
        pop  cx
        clc
        ret
@@xoff: pop  cx
        stc
        ret
MMPTY:  push cx
        sub  ax,[mmrow0]
        and  ax,63
        cmp  ax,[mmspy]
        jae  @@yoff
        call MMSCLI
        add  ax,PZMMY
        pop  cx
        clc
        ret
@@yoff: pop  cx
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
@@row:  mov  bx,dx
        add  bx,bx
        mov  si,cs:[MMROWT+bx]  ; this row's base in the baked map
        xor  cx,cx              ; dest column
@@px:   mov  bx,cx
        mov  bl,cs:[MMCOLT+bx]
        xor  bh,bh
        mov  al,[si+bx]
        stosb
        inc  cx
        cmp  cx,PZADIW
        jb   @@px
        add  di,320-PZADIW
        inc  dx
        cmp  dx,PZADIH
        jb   @@row
        pop  ds
        ; the front line, half scale
        ; the front line, a pixel column at a time. The column table already
        ; says which world node each pixel shows, so the band comes straight
        ; off it - and the line wraps with everything else.
        xor  cx,cx
@@bd2:  push cx                 ; CX is the column: nothing below may touch
        mov  bx,cx              ; it, and CL is a shift count twice over
        mov  bl,cs:[MMCOLT+bx]  ; the node under this pixel column
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
        jc   @@bdn              ; this stretch of the line is off the window
        push cx
        call UROW
        pop  cx
        add  di,PZMMX
        add  di,cx
        mov  al,19
        mov  es:[di],al
@@bdn:  inc  cx
        cmp  cx,PZADIW
        jb   @@bd2
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
        jc   @@nbl
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
        jc   @@nbl
        push bx
        call UROW
        pop  bx
        add  di,bx
        mov  al,8               ; white blip. It was briefly an aeroplane at
        mov  es:[di],al         ;  the closest zoom, and went back: a blip
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
        mov  es:[di],al
@@nbl:  ret


; ============================================================================
;  THE GROUND RADAR STATIONS, evicted to UISEG the day they were written:
;  the main segment had ~600 bytes left and the station code alone wanted
;  more. Only the MODELS and the state words stayed home (MODELDRAW reads
;  them with DS = the main segment); everything that only computes lives
;  out here and knocks on the four far doors in PLANES.INC when it needs
;  home. Far doors: RSTAINITF (once, after DSGEN), RSTADRAWF (per frame)
;  and RSBLIPF (the scope mark; the map mark rides out with MAPHUMF).
; ============================================================================
RSTAINITF PROC FAR
        call RSTAINIT
        ret
RSTAINITF ENDP
RSTADRAWF PROC FAR
        call RSTADRAW
        ret
RSTADRAWF ENDP
RSBLIPF PROC FAR
        call RSBLIP
        ret
RSBLIPF ENDP
RSHITF  PROC FAR
        call RSHIT
        ret
RSHITF  ENDP
RSNOISF PROC FAR
        call RSNOISE
        ret
RSNOISF ENDP
RSLOCKF PROC FAR
        call RSLOCK
        ret
RSLOCKF ENDP

; ---------------------------------------------------------------------------
;  RSTAINIT - plant the two ground radar stations. Both stand on the
;  map's north-south spine (x = 24576, where the squadrons form up):
;  OURS 7000 south of the border, THEIRS 7000 north of it - deep in the
;  rear, past the tanker's lane, so reaching the enemy's is a sortie and
;  defending ours is a job. Runs after DSGEN: it needs the heightmap.
; ---------------------------------------------------------------------------
RSTAINIT:
        mov  word ptr [rsi],0
@@s:    mov  bx,[rsi]
        mov  byte ptr [rsst+bx],0
        mov  byte ptr [rshp+bx],RSHITS
        add  bx,bx              ; word index
        mov  word ptr [rsx+bx],24576
        mov  ax,24576
        cmp  word ptr [rsi],0
        jne  @@north
        sub  ax,7000            ; ours: the southern rear
        jmp  @@sz
@@north:
        add  ax,7000            ; theirs: the mirror of it
@@sz:   mov  [rsz+bx],ax
        call RSTAGND
        inc  word ptr [rsi]
        cmp  word ptr [rsi],NRSTA
        jb   @@s
        mov  word ptr [rspin],0
        ret

; ---------------------------------------------------------------------------
;  RSTAGND - a radar wants a hilltop, not a beach. Probe eight spots at
;  1024 apart along the station's own east-west line and keep the highest
;  ground: on an island world that also keeps it out of the sea (WORLDH
;  clamps water to 0). in/out: [rsi] = station; writes rsx and rsy.
; ---------------------------------------------------------------------------
RSTAGND:
        mov  bx,[rsi]
        add  bx,bx
        mov  ax,[rsx+bx]
        mov  [ctx],ax
        mov  ax,[rsz+bx]
        mov  [ctz],ax
        call FINDGND            ; the same rule the batteries follow: a mast
        mov  bx,[rsi]           ; standing in the sea was the old behaviour
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
        mov  word ptr [rsi],0
@@st:   mov  bx,[rsi]
        cmp  byte ptr [rsst+bx],0
        jne  @@nx               ; down: the wreck pool has it now
        add  bx,bx
        mov  ax,[rsx+bx]
        sub  ax,[camx]
        mov  [wdx],ax
        mov  ax,[rsz+bx]
        sub  ax,[camz]
        mov  [wdz],ax
        mov  ax,[wdx]           ; the jets' own world-space box reject
        jns  @@q1
        neg  ax
@@q1:   cmp  ax,13000
        jge  @@nx
        mov  ax,[wdz]
        jns  @@q2
        neg  ax
@@q2:   cmp  ax,13000
        jge  @@nx
        call FAR PTR ROTXZF
        mov  ax,[rcz]
        cmp  ax,-100
        jl   @@nx               ; behind us
        cmp  ax,12500
        jge  @@nx               ; past the leash
        mov  [pdz],ax
        mov  ax,[rcx]
        mov  [pdx],ax
        mov  bx,[rsi]
        add  bx,bx
        mov  ax,[rsy+bx]
        sub  ax,[camy]
        mov  [pdy],ax
        xor  ax,ax              ; the tower stands still: its yaw is ours
        sub  ax,[heading]
        call RSTAYAW
        mov  word ptr [mvb],offset RBASEVT
        mov  word ptr [mvn],RBASENV*6
        mov  word ptr [mfb],offset RBASEFC
        mov  word ptr [nfc],RBASENF
        call FAR PTR MODELDRAWF
        mov  ax,[rspin]         ; the dish, sweeping
        sub  ax,[heading]
        call RSTAYAW
        mov  word ptr [mvb],offset RDISHVT
        mov  word ptr [mvn],RDISHNV*6
        mov  word ptr [mfb],offset RDISHFC
        mov  word ptr [nfc],RDISHNF
        call FAR PTR MODELDRAWF
        mov  bx,[rsi]           ; RELOAD it: MODELDRAW clobbers BX, and this
        add  bx,bx              ; read the station's height through whatever
        mov  ax,[rsy+bx]        ; was left in it - which is why the marker
        add  ax,RSTOP/2         ; jumped above and below the mast instead of
        sub  ax,[camy]          ; sitting on the dish
        mov  [pdy],ax
        mov  byte ptr [COLOR],95
        mov  byte ptr [gmks],0
        cmp  word ptr [rsi],0
        je   @@nmk
        mov  byte ptr [COLOR],96
        mov  byte ptr [gmks],1
@@nmk:  mov  ax,[rsi]           ; and RED once it is the locked one - the
        add  ax,ax              ; world's own language, which the ground
        add  ax,RSLK            ; now speaks too: green ours, yellow theirs,
        cmp  ax,[locki]         ; red the one you have
        jne  @@nmk2
        mov  byte ptr [COLOR],19
@@nmk2: mov  word ptr [gmkn],14000
        call FAR PTR GNDMARKF
@@nx:   inc  word ptr [rsi]
        cmp  word ptr [rsi],NRSTA
        jb   @@st
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
RSBLIP: mov  word ptr [rsi],0
@@l:    mov  bx,[rsi]
        cmp  byte ptr [rsst+bx],0
        jne  @@n                ; a dead station paints no return
        add  bx,bx
        mov  ax,[rsx+bx]
        sub  ax,[camx]
        mov  [wdx],ax
        mov  ax,[rsz+bx]
        sub  ax,[camz]
        mov  [wdz],ax
        call FAR PTR ROTXZF     ; rcx = right of the nose, rcz = ahead
        mov  cl,[rbsh]          ; the scope's live zoom, then a pixel clip
        mov  ax,[rcx]           ; (12, not 14: the arms need the margin)
        sar  ax,cl
        cmp  ax,[rbrad]
        jg   @@n
        cmp  ax,[rbradn]
        jl   @@n
        mov  bx,[rcz]
        sar  bx,cl
        cmp  bx,[rbrad]
        jg   @@n
        cmp  bx,[rbradn]
        jl   @@n
        add  ax,[rbcx]
        mov  [bqx],ax
        mov  ax,[rbcy]
        sub  ax,bx              ; ahead = up the screen
        mov  [bqy],ax
        mov  al,95              ; ours green, theirs RED - the same two
        cmp  word ptr [rsi],0   ; colours the whole scope speaks now
        je   @@c
        mov  al,19
@@c:    mov  [COLOR],al
        call FAR PTR BQSTAF     ; the lozenge with a dish, and it never turns
@@n:    inc  word ptr [rsi]
        cmp  word ptr [rsi],NRSTA
        jb   @@l
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
        mov  word ptr [tpi],0
        ; The snow fills whatever the scope's reach is. It used to be a
        ; fixed +/-13 box, which on this screen would leave a clean border
        ; of glass around the interference - and a radar that is out does
        ; not politely stay off the edges.
@@d:    call RSRND              ; a column...
        mov  cl,3
        shr  ax,cl
        and  ax,63
        imul word ptr [rbrad]
        mov  cl,5
        sar  ax,cl              ; 0..63 -> 0..2*rbrad
        sub  ax,[rbrad]
        add  ax,[rbcx]
        mov  [dsx],ax
        call RSRND              ; ...and a row
        mov  cl,3
        shr  ax,cl
        and  ax,63
        imul word ptr [rbrad]
        mov  cl,5
        sar  ax,cl
        sub  ax,[rbrad]
        add  ax,[rbcy]
        call UROW
        add  di,[dsx]
        call RSRND              ; two greys: dim static with a spark in it
        mov  al,30
        test ah,4
        jz   @@c
        mov  al,8
@@c:    mov  es:[di],al
        inc  word ptr [tpi]
        cmp  word ptr [tpi],150
        jb   @@d
        mov  byte ptr [COLOR],19 ; and the word for it, in red
        mov  ax,[rbcx]
        sub  ax,16
        mov  [ftx],ax
        mov  ax,[rbcy]
        sub  ax,3
        mov  [fty],ax
        mov  si,offset MSGNORAD
        call FAR PTR FDRAWF
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
RSLOCK: mov  word ptr [rsi],0
@@l:    mov  bx,[rsi]
        cmp  byte ptr [rsst+bx],0
        jne  @@n                ; rubble locks nothing
        add  bx,bx
        mov  ax,[rsx+bx]
        sub  ax,[camx]
        mov  [wdx],ax
        mov  ax,[rsz+bx]
        sub  ax,[camz]
        mov  [wdz],ax
        call FAR PTR ROTXZF
        mov  ax,[rcz]
        cmp  ax,NEARZ
        jl   @@n
        mov  [tpi],ax           ; the range, for the nearest-wins test
        mov  bx,[rsi]
        add  bx,bx
        mov  dx,[rsy+bx]
        add  dx,RSTOP/2
        sub  dx,[camy]
        mov  ax,[rcx]
        mov  cx,[rcz]
        call FAR PTR PPOINTF
        jc   @@n
        sub  ax,160
        jns  @@k1
        neg  ax
@@k1:   cmp  ax,24
        jg   @@n
        sub  dx,[horiz]         ; the ring sits on the glass, not the screen
        jns  @@k2
        neg  dx
@@k2:   cmp  dx,24
        jg   @@n
        mov  ax,[tpi]
        cmp  ax,[lockd]
        jae  @@n
        mov  [lockd],ax
        mov  ax,[rsi]
        add  ax,ax
        add  ax,RSLK
        mov  [locki],ax
@@n:    inc  word ptr [rsi]
        cmp  word ptr [rsi],NRSTA
        jb   @@l
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
RSHIT:  mov  word ptr [rsi],0
@@l:    mov  bx,[rsi]
        cmp  byte ptr [rsst+bx],0
        jne  @@n                ; already a ruin: nothing left to break
        add  bx,bx
        mov  ax,[rhx]
        sub  ax,[rsx+bx]
        jns  @@a1
        neg  ax
@@a1:   cmp  ax,RSRAD
        jge  @@n
        mov  ax,[rhz]
        sub  ax,[rsz+bx]
        jns  @@a2
        neg  ax
@@a2:   cmp  ax,RSRAD
        jge  @@n
        mov  ax,[rhy]
        sub  ax,[rsy+bx]        ; height above its own feet
        js   @@n                ; underground: the terrain ate it
        cmp  ax,RSTOP
        jg   @@n                ; over the dish
        call RSDAM
        mov  ax,1
        ret
@@n:    inc  word ptr [rsi]
        cmp  word ptr [rsi],NRSTA
        jb   @@l
        xor  ax,ax
        ret

; ---------------------------------------------------------------------------
;  RSDAM - one hit on station [rsi]. The last one takes it down: the
;  state word flips, and the wreck pool gets it through WRKATF - the
;  same eight tumbling slabs, fire, smoke and distance-scaled bang that
;  a falling building gets, in scheme 0 so the debris is grey steel.
; ---------------------------------------------------------------------------
RSDAM:  mov  bx,[rsi]
        mov  al,[rshp+bx]
        sub  al,[rhdmg]
        jbe  @@dead
        mov  [rshp+bx],al
        ret
@@dead: mov  byte ptr [rshp+bx],0
        mov  byte ptr [rsst+bx],1
        mov  al,bl              ; and tell the wire: one shot, next tick
        inc  al
        mov  [rsnet],al
        add  bx,bx
        mov  ax,bx              ; a lock on rubble is no lock
        add  ax,RSLK
        cmp  ax,[locki]
        jne  @@nolk
        mov  word ptr [locki],0FFFFh
@@nolk:
        mov  ax,[rsx+bx]
        mov  [bpx],ax
        mov  ax,[rsz+bx]
        mov  [bpz],ax
        mov  word ptr [bschm],0 ; grey walls: steel, not brick
        call FAR PTR WRKATF
        ret

; ---------------------------------------------------------------------------
;  RSMAP - the stations on the centre MFD map, so you can see what you are
;  defending without hunting for it. Same cross, one pixel across at this
;  scale, in the owner's colour; a station that is DOWN stays on the map
;  in trim grey - the ruin is information too. No clipping: both stations
;  are planted at fixed coordinates that land well inside the 32x32 glass
;  (rows 167..174, columns 158..162), and RSTAINIT is what keeps it so.
; ---------------------------------------------------------------------------
RSMAP:  mov  word ptr [rsi],0
@@l:    mov  bx,[rsi]
        mov  al,95
        or   bx,bx
        jz   @@c1
        mov  al,19              ; theirs: red, like everywhere else now
@@c1:   cmp  byte ptr [rsst+bx],0
        je   @@c2
        mov  al,30              ; a ruin: grey, and still worth knowing
@@c2:   push ax
        add  bx,bx
        mov  ax,[rsx+bx]        ; the map's own arithmetic, shared
        add  ax,BIAS
        mov  cl,10
        shr  ax,cl
        and  ax,63
        call MMPTX
        jc   @@nx
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
        jc   @@nx
        mov  cs:[mprow],ax      ; the symbol wants the row, UROW eats it
        call UROW
        add  di,dx
        pop  ax
        cmp  byte ptr [mmzs],MMZICO
        jb   @@cr               ; wound out: the plus sign, as before
        mov  [COLOR],al         ; close in: the mast and its dish, the same
        mov  [bqx],dx           ; picture the scope draws
        mov  ax,cs:[mprow]
        mov  [bqy],ax
        call FAR PTR BQSTAF
        jmp  @@nn
@@cr:   mov  es:[di],al
        mov  es:[di-320],al
        mov  es:[di+320],al
        mov  es:[di-1],al
        mov  es:[di+1],al
        jmp  @@nn
@@nx:   pop  ax                 ; this station is off the window: keep the
@@nn:   inc  word ptr [rsi]     ; stack straight and move to the next
        cmp  word ptr [rsi],NRSTA
        jb   @@l
        ret

; ---------------------------------------------------------------------------
;  SHKMAP - the Shilkas on the map. Same two colours as everything else -
;  ours green, theirs red - and the same shape language as the scope: a
;  small solid block, because a battery is a place, not a heading. Close in
;  it is a three-pixel cross with a body; wound out to the whole world it
;  is one pixel, or six of them would smear into a single blob.
; ---------------------------------------------------------------------------
SHKMAP: mov  word ptr cs:[shki],0
@@sm:   mov  bx,cs:[shki]
        cmp  byte ptr cs:[shkst+bx],0
        jne  @@smn              ; a wreck is off the map
        add  bx,bx
        mov  ax,cs:[shkx+bx]
        add  ax,BIAS
        mov  cl,10
        shr  ax,cl
        and  ax,63
        call MMPTX
        jc   @@smn
        mov  dx,ax
        mov  bx,cs:[shki]
        add  bx,bx
        mov  ax,cs:[shkz+bx]
        add  ax,BIAS
        mov  cl,10
        shr  ax,cl
        and  ax,63
        mov  bx,63
        sub  bx,ax
        mov  ax,bx
        push dx
        call MMPTY
        pop  dx
        jc   @@smn
        mov  cs:[mprow],ax
        call UROW
        add  di,dx
        mov  ax,cs:[shki]       ; even ours, odd theirs - the parity rule
        test ax,1
        mov  al,95
        jz   @@smc
        mov  al,19
@@smc:  cmp  byte ptr [mmzs],MMZICO
        jb   @@smb              ; wound out: the block, as before
        mov  [COLOR],al         ; close in: the vehicle from the side, the
        mov  [bqx],dx           ; same picture the scope draws
        mov  ax,cs:[mprow]
        mov  [bqy],ax
        call FAR PTR BQSHKF
        jmp  @@smn
@@smb:  mov  es:[di],al
        cmp  byte ptr [mmzs],MMZALL
        je   @@smn              ; whole world: one pixel is the whole mark
        mov  es:[di-1],al
        mov  es:[di+1],al
        mov  es:[di-320],al
@@smn:  inc  word ptr cs:[shki]
        cmp  word ptr cs:[shki],NSHILK
        jb   @@sm
        ret

; RSTAYAW - model yaw in AX (any sign) -> msin/mcos. SINQ wraps it.
RSTAYAW:
        and  ax,255
        push ax
        call FAR PTR SINQF
        mov  [msin],ax
        pop  ax
        add  ax,64
        call FAR PTR SINQF
        mov  [mcos],ax
        ret

; ============================================================================
;  THE SHILKAS - ZSU-23-4 self-propelled anti-aircraft guns, three a side.
;
;  This is MILESTONE ONE: the vehicle stands in the world and its turret
;  turns. It does not drive yet, it does not track, it does not shoot and
;  it cannot be killed - each of those is its own build, the way the radar
;  station was done. What is settled here is the SHAPE and the SEAM: two
;  models at one world point, the chassis on the driving heading and the
;  turret on its own bearing, so when the tracking arrives it has only to
;  write shkt and the vehicle already knows how to show it.
;
;  It sits below RSTAYAW because it calls it, and a one-pass assembler is
;  happier reading downhill. Everything here is cs:-relative state (see the
;  block up top) plus the far doors home: ROTXZF, SINQF, TERRHF, MODELDRAWF.
;
;  Far doors OUT: SHKINITF (once, after DSGEN - it needs the heightmap),
;  SHKTICKF (the physics clock) and SHKDRAWF (per frame).
; ============================================================================
SHKINITF PROC FAR
        call SHKINIT
        ret
SHKINITF ENDP
SHKTICKF PROC FAR
        call SHKTICK
        ret
SHKTICKF ENDP
SHKDRAWF PROC FAR
        call SHKDRAW
        ret
SHKDRAWF ENDP

; ---------------------------------------------------------------------------
;  SHKINIT - park the six. Site from SHKPX/SHKPZ, ground from SHKGND, and
;  a hull heading and turret bearing fanned out by index so that no two of
;  them stand at the same angle: six identical vehicles all pointing north
;  read as wallpaper, six at their own angles read as a deployment. Runs
;  after DSGEN, beside RSTAINIT.
; ---------------------------------------------------------------------------
SHKINIT:
        mov  word ptr cs:[shki],0
@@v:    mov  bx,cs:[shki]
        mov  ax,bx              ; hull heading = i*43 + 16, turret = i*37:
        mov  cx,43              ; two different strides, so the turret is
        imul cx                 ; never parked square with its own hull
        add  ax,16
        mov  cs:[shkh+bx],al
        mov  ax,bx
        mov  cx,37
        imul cx
        mov  cs:[shkt+bx],al
        add  bx,bx              ; word index
        mov  ax,cs:[SHKPX+bx]
        add  ax,24576
        mov  cs:[shkx+bx],ax
        mov  ax,cs:[SHKPZ+bx]
        add  ax,24576
        mov  cs:[shkz+bx],ax
        call SHKGND
        mov  bx,cs:[shki]       ; the post it will always come back to
        add  bx,bx
        mov  ax,cs:[shkx+bx]
        mov  cs:[shkax+bx],ax
        mov  ax,cs:[shkz+bx]
        mov  cs:[shkaz+bx],ax
        mov  bx,cs:[shki]
        mov  al,cs:[shkh+bx]
        mov  cs:[shkhd+bx],al   ; start out driving the way it is parked
        inc  word ptr cs:[shki]
        cmp  word ptr cs:[shki],NSHILK
        jb   @@v
        ret

; ---------------------------------------------------------------------------
;  SHKGND - a gun wants ground, not sea. Probe eight spots 128 apart along
;  this vehicle's east-west line and keep the HIGHEST: on an island world
;  that also keeps it dry, since WORLDH clamps water to 0. The same trick
;  RSTAGND plays for the stations, at an EIGHTH of the spacing. That is
;  deliberate: a station may hunt four thousand units for a hilltop because
;  nobody has to find it again, but a battery that teleports 130 m off its
;  post is not covering anything, and the pilot who put it there should be
;  able to find his own flak. +/-512 is under six vehicle lengths.
;  in/out: cs:[shki] = the vehicle; writes shkx and shky.
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
        mov  cs:[shkb],ax       ; the nominal centre, kept
        mov  ax,[ctz]
        mov  cs:[shkc],ax
        mov  word ptr cs:[shkq],0       ; best height so far (0 = none)
        mov  word ptr cs:[shkp],0       ; ring step
@@fr:   mov  word ptr cs:[shke],0       ; the eight points of this ring
@@fp:   mov  ax,cs:[shke]       ; a crude compass: dx and dz from a 3x3 box
        and  ax,3
        dec  ax                 ; -1, 0, 1, 2 -> use -1..1
        cmp  ax,2
        jne  @@f1
        xor  ax,ax
@@f1:   mov  dx,cs:[shkp]
        inc  dx
        imul dx
        mov  cx,10
        imul cx                 ; step out 10 world units per ring per unit
        mov  bx,ax
        mov  ax,cs:[shke]
        mov  cl,2
        shr  ax,cl
        and  ax,3
        dec  ax
        cmp  ax,2
        jne  @@f2
        xor  ax,ax
@@f2:   mov  dx,cs:[shkp]
        inc  dx
        imul dx
        mov  cx,10
        imul cx
        push ax                 ; dz
        mov  ax,cs:[shkb]
        add  ax,bx
        mov  [ctx],ax
        pop  ax
        add  ax,cs:[shkc]
        mov  [ctz],ax
        push word ptr [camx]    ; TERRH reads the camera position
        push word ptr [camz]
        mov  ax,[ctx]
        mov  [camx],ax
        mov  ax,[ctz]
        mov  [camz],ax
        call FAR PTR TERRHF
        pop  word ptr [camz]
        pop  word ptr [camx]
        cmp  ax,GNDLO
        jb   @@fn               ; in the sea
        cmp  ax,GNDHI
        ja   @@fn               ; up the mountain
        cmp  ax,cs:[shkq]
        jbe  @@fn
        mov  cs:[shkq],ax       ; the best legal ground so far
        mov  ax,[ctx]
        mov  cs:[shkg],ax
        mov  ax,[ctz]
        mov  cs:[shkv],ax
@@fn:   inc  word ptr cs:[shke]
        cmp  word ptr cs:[shke],16
        jb   @@fp
        cmp  word ptr cs:[shkq],0
        jne  @@fd               ; found something on this ring: stop widening
        inc  word ptr cs:[shkp]
        cmp  word ptr cs:[shkp],40      ; out to 400 units a step, 16 tries
        jb   @@fr
        mov  ax,cs:[shkb]       ; nothing legal anywhere near: leave it where
        mov  [ctx],ax           ; it was and say so
        mov  ax,cs:[shkc]
        mov  [ctz],ax
        xor  ax,ax
        stc
        ret
@@fd:   mov  ax,cs:[shkg]
        mov  [ctx],ax
        mov  ax,cs:[shkv]
        mov  [ctz],ax
        mov  ax,cs:[shkq]
        clc
        ret

SHKGND: mov  bx,cs:[shki]
        add  bx,bx
        mov  ax,cs:[shkx+bx]
        mov  [ctx],ax
        mov  ax,cs:[shkz+bx]
        mov  [ctz],ax
        call FINDGND            ; out of the water, off the mountain
        mov  bx,cs:[shki]
        add  bx,bx
        mov  cs:[shky+bx],ax
        mov  ax,[ctx]
        mov  cs:[shkx+bx],ax
        mov  ax,[ctz]
        mov  cs:[shkz+bx],ax
        ret

; ---------------------------------------------------------------------------
;  SHKTICK - one physics tick. For now the ONLY moving part is the turret,
;  and it sweeps: each vehicle at its own rate, 2..5 of 256 a tick, so the
;  six are never in step and one turn takes 3.5..7 seconds. That rate IS
;  the character of the thing - a turret that snaps to its target is a
;  gun mount, one that lags is a Shilka - so the tracking that replaces
;  this sweep will keep the same ceiling and only change the direction.
; ---------------------------------------------------------------------------
SHKTICK:
        mov  word ptr cs:[shki],0
@@t:    mov  bx,cs:[shki]
        cmp  byte ptr cs:[shkst+bx],0
        jne  @@tn               ; burning: nothing turns any more
        mov  al,cs:[shkd+bx]    ; THE RADAR sweeps, steadily, always. This
        add  al,SHKDSPN         ; is the part that spins - it was the guns
        mov  cs:[shkd+bx],al    ; doing it, which read as a nervous tic
        call SHKAI              ; decide where to drive
        call SHKMOVE            ; ...and drive there
        mov  bx,cs:[shki]
        mov  byte ptr cs:[shktrg+bx],0
        call SHKAIM             ; in reach? -> CX bearing, DX elevation
        jc   @@tn               ; nothing: the guns hold where they are
        push cx
        mov  bx,cs:[shki]       ; the barrels rise or fall toward it, and
        mov  al,cs:[shkel+bx]   ; no faster than SHKELEV either
        xor  ah,ah
        sub  dx,ax
        cmp  dx,SHKELEV
        jle  @@te1
        mov  dx,SHKELEV
@@te1:  cmp  dx,-SHKELEV
        jge  @@te2
        mov  dx,-SHKELEV
@@te2:  add  ax,dx
        jns  @@te3
        xor  ax,ax
@@te3:  cmp  ax,SHKELMX
        jle  @@te4
        mov  ax,SHKELMX
@@te4:  mov  cs:[shkel+bx],al
        pop  cx
        mov  bx,cs:[shki]       ; slew toward it, and no faster than SHKTRAV
        mov  al,cs:[shkt+bx]
        xor  ah,ah
        mov  dx,cx
        sub  dx,ax              ; the shorter way round, signed
        and  dx,255
        cmp  dx,128
        jb   @@tp
        sub  dx,256
@@tp:   cmp  dx,SHKTRAV         ; a full turn takes about seven seconds,
        jle  @@tm               ; and that lag IS the character of the thing
        mov  dx,SHKTRAV
@@tm:   cmp  dx,-SHKTRAV
        jge  @@ta
        mov  dx,-SHKTRAV
@@ta:   add  ax,dx
        mov  cs:[shkt+bx],al
        call SHKGUN             ; on the mark? then fire
@@tn:   inc  word ptr cs:[shki]
        cmp  word ptr cs:[shki],NSHILK
        jb   @@t
        ret

; ---------------------------------------------------------------------------
;  SHKAIM - the nearest ENEMY aircraft this battery can reach.
;   in: cs:[shki] = the vehicle
;   out: CF clear and CX = the bearing to it; CF set if the sky is empty.
;  "Enemy" is the parity rule again: an even slot is ours, so it hunts odd
;  aircraft, and an odd one hunts even. The player counts as slot 0 - he is
;  on the even side - so the odd batteries are the ones that want him.
; ---------------------------------------------------------------------------
SHKAIM: mov  bx,cs:[shki]
        add  bx,bx
        mov  ax,cs:[shkx+bx]
        mov  cs:[shkb],ax       ; our own place, for the range tests
        mov  ax,cs:[shkz+bx]
        mov  cs:[shkc],ax
        mov  ax,cs:[shky+bx]
        add  ax,SHKTOP
        mov  cs:[shkv],ax       ; our own roof: the guns sit up here
        mov  word ptr cs:[shkp],32767   ; best range so far
        mov  word ptr cs:[shkg],0FFFFh  ; ...and who had it
        mov  bx,cs:[shki]
        and  bx,1               ; our side; we want the other one
        mov  cs:[shke],bx
        ; THE PILOT FIRST. He is not in the plane array at all - he is the
        ; camera - so a loop over pst would never have found him, and the
        ; guns would have politely ignored the one aircraft that matters.
        ; He flies for the even side, so the odd batteries want him.
        ;
        ; ...AND SO DO HIS OWN, if he has switched the transponder off. That
        ; is the whole of IFF: the battery does not know a friend from a
        ; target, it only knows what answers the interrogation. Leave the box
        ; off over your own flak and your own flak will shoot you down, and
        ; it will be right to.
        or   bx,bx
        jnz  @@ifok
        cmp  byte ptr [swiff],0
        jne  @@axp              ; transponder up: our own guns leave us be
@@ifok: cmp  byte ptr [dying],0
        jne  @@axp
        mov  ax,[camx]
        sub  ax,cs:[shkb]
        jns  @@ap1
        neg  ax
@@ap1:  cmp  ax,SHKGRNG
        jg   @@axp
        mov  dx,ax
        mov  ax,[camz]
        sub  ax,cs:[shkc]
        jns  @@ap2
        neg  ax
@@ap2:  cmp  ax,SHKGRNG
        jg   @@axp
        add  ax,dx
        mov  cs:[shkp],ax
        mov  word ptr cs:[shkg],0FFFFh
@@axp:  xor  si,si
@@ax:   mov  bx,si              ; the player rides slot 0 like everyone
        shr  bx,1
        cmp  byte ptr [pst+bx],0
        jne  @@axn              ; dead men are not targets
        mov  ax,si
        shr  ax,1
        and  ax,1
        cmp  ax,cs:[shke]
        je   @@axn              ; same side: not ours to shoot
        mov  ax,[pax+si]
        sub  ax,cs:[shkb]
        jns  @@ax1
        neg  ax
@@ax1:  cmp  ax,SHKGRNG
        jg   @@axn
        mov  dx,ax
        mov  ax,[paz+si]
        sub  ax,cs:[shkc]
        jns  @@ax2
        neg  ax
@@ax2:  cmp  ax,SHKGRNG
        jg   @@axn
        add  ax,dx              ; a cheap taxicab range: this is a decision,
        cmp  ax,cs:[shkp]       ; not a firing solution
        jae  @@axn
        mov  cs:[shkp],ax
        mov  cs:[shkg],si
@@axn:  add  si,2
        cmp  si,NPLANE*2
        jb   @@ax
        ; GROUND COMMS. A battery on the pilot's side, with the army net up,
        ; shoots at what HE is pointing at rather than at whatever happens to
        ; be closest to it. That is the entire point of a radio: one man's
        ; eyes become the battery's. The range gate still applies - the net
        ; carries a designation, not a longer barrel - so a call about
        ; something twenty kilometres away is simply not actionable.
        cmp  byte ptr [swgnd],0
        je   @@axf
        cmp  word ptr cs:[shke],0
        jne  @@axf              ; the other side is not on our net
        mov  di,[locki]
        cmp  di,NPLANE*2
        jae  @@axf              ; no lock, or a ground target: nothing to say
        mov  bx,di
        shr  bx,1
        cmp  byte ptr [pst+bx],0
        jne  @@axf              ; already dead: let the battery choose again
        mov  ax,[pax+di]
        sub  ax,cs:[shkb]
        jns  @@ag1
        neg  ax
@@ag1:  cmp  ax,SHKGRNG
        jg   @@axf
        mov  ax,[paz+di]
        sub  ax,cs:[shkc]
        jns  @@ag2
        neg  ax
@@ag2:  cmp  ax,SHKGRNG
        jg   @@axf
        mov  cs:[shkg],di       ; designated: this one, and never mind range
@@axf:  mov  si,cs:[shkg]
        cmp  si,0FFFFh
        jne  @@axw
        cmp  word ptr cs:[shkp],32767   ; FFFF means the pilot - unless
        je   @@axe                      ; nothing was found at all
        mov  ax,[camx]
        sub  ax,cs:[shkb]
        mov  [wdx],ax
        mov  ax,[camz]
        sub  ax,cs:[shkc]
        mov  [wdz],ax
        jmp  @@axb
@@axw:  mov  ax,[pax+si]        ; bearing to him, world frame
        sub  ax,cs:[shkb]
        mov  [wdx],ax
        mov  ax,[paz+si]
        sub  ax,cs:[shkc]
        mov  [wdz],ax
@@axb:
        call FAR PTR SHKBRGF
        mov  cs:[shkq],ax       ; the bearing; now how high to look
        mov  si,cs:[shkg]
        mov  ax,[wdx]           ; the horizontal leg we already have
        or   ax,ax
        jns  @@ah1
        neg  ax
@@ah1:  mov  bx,[wdz]
        or   bx,bx
        jns  @@ah2
        neg  bx
@@ah2:  cmp  ax,bx              ; octagonal ground range: max + half the min
        jge  @@ah3
        xchg ax,bx
@@ah3:  shr  bx,1
        add  ax,bx
        mov  bx,ax
        mov  bx,cs:[shki]       ; remember him for the gun
        add  bx,bx
        mov  cs:[shktgt+bx],si
        cmp  si,0FFFFh
        jne  @@ahp
        mov  ax,[camy]
        jmp  @@ahq
@@ahp:  mov  ax,[pay+si]        ; how far above our own roof he is
@@ahq:  sub  ax,cs:[shkv]
        jg   @@ah4
        xor  ax,ax              ; at or below us: the guns come down flat
@@ah4:  call SHKPITCH           ; -> AX = 0..64
        mov  dx,ax
        mov  cx,cs:[shkq]
        clc
        ret
@@axe:  stc
        ret

; ---------------------------------------------------------------------------
;  SHKPITCH - the angle up to a thing AX high at ground range BX, as 0..64
;  of the compass (0 = level, 64 = straight up). Same table and the same
;  reasoning as the bearing: the smaller leg over the larger picks a row,
;  and which leg was smaller says which half of the quadrant we are in.
; ---------------------------------------------------------------------------
SHKPITCH:
        or   bx,bx
        jnz  @@p1
        mov  ax,64              ; directly overhead
        ret
@@p1:   cmp  ax,bx
        ja   @@psteep
        push cx                 ; shallow: angle = atan(h/range)
        mov  cl,5
        shl  ax,cl
        xor  dx,dx
        div  bx
        mov  bx,ax
        mov  al,cs:[SHKATN+bx]
        xor  ah,ah
        pop  cx
        ret
@@psteep:                       ; steep: 64 - atan(range/h)
        push cx
        xchg ax,bx
        mov  cl,5
        shl  ax,cl
        xor  dx,dx
        div  bx
        mov  bx,ax
        mov  al,cs:[SHKATN+bx]
        xor  ah,ah
        mov  bx,64
        sub  bx,ax
        mov  ax,bx
        pop  cx
        ret


; ---------------------------------------------------------------------------
;  SHKAI - fill the DRIVING inputs for vehicle cs:[shki]. Today this is the
;  only thing that writes them; the day the pilot climbs in, his hands do,
;  and SHKMOVE below never learns the difference.
;  A leg lasts a few seconds and then it picks a new heading. But it is on
;  a LEASH: past SHKLSH from its post it stops choosing and turns for home.
;  It is meant to cover a place, not to go for a drive.
; ---------------------------------------------------------------------------
SHKAI:  mov  bx,cs:[shki]
        add  bx,bx
        mov  ax,cs:[shkx+bx]    ; how far off its post are we?
        sub  ax,cs:[shkax+bx]
        jns  @@a1
        neg  ax
@@a1:   mov  dx,ax
        mov  ax,cs:[shkz+bx]
        sub  ax,cs:[shkaz+bx]
        jns  @@a2
        neg  ax
@@a2:   add  ax,dx
        cmp  ax,SHKLSH
        jb   @@aleg
        mov  ax,cs:[shkax+bx]   ; too far: steer for the post, every tick,
        sub  ax,cs:[shkx+bx]    ; until it is back inside the leash
        mov  [wdx],ax
        mov  ax,cs:[shkaz+bx]
        sub  ax,cs:[shkz+bx]
        mov  [wdz],ax
        call FAR PTR SHKBRGF
        mov  bx,cs:[shki]
        mov  cs:[shkhd+bx],al
        ret
@@aleg: mov  bx,cs:[shki]       ; inside the leash: run the leg out, then
        dec  byte ptr cs:[shklgt+bx]
        jnz  @@ad
        mov  byte ptr cs:[shklgt+bx],SHKLEG
        push bx
        call FAR PTR RND16F
        pop  bx
        and  al,63
        sub  al,32              ; a new leg, up to 45 degrees off this one
        add  al,cs:[shkhd+bx]
        mov  cs:[shkhd+bx],al
@@ad:   ret

; ---------------------------------------------------------------------------
;  SHKMOVE - one tick of driving, from the inputs and nothing else. Turn the
;  hull toward its demanded heading at SHKSTR, roll forward at SHKSPD, and
;  sit down on whatever ground is under the new spot. That last part is why
;  it costs a TERRH a tick: a tracked vehicle floating over a hill looks
;  worse than one that never moved.
; ---------------------------------------------------------------------------
SHKMOVE:
        mov  bx,cs:[shki]
        mov  al,cs:[shkhd+bx]
        xor  ah,ah
        mov  dx,ax
        mov  al,cs:[shkh+bx]
        xor  ah,ah
        sub  dx,ax              ; the shorter way round, signed
        and  dx,255
        cmp  dx,128
        jb   @@m1
        sub  dx,256
@@m1:   cmp  dx,SHKSTR
        jle  @@m2
        mov  dx,SHKSTR
@@m2:   cmp  dx,-SHKSTR
        jge  @@m3
        mov  dx,-SHKSTR
@@m3:   add  ax,dx
        mov  cs:[shkh+bx],al
        and  ax,255             ; forward, along the hull's own nose
        push ax
        call FAR PTR SINQF
        mov  cx,SHKSPD
        imul cx
        mov  cx,256
        idiv cx
        mov  bx,cs:[shki]
        add  bx,bx
        add  cs:[shkx+bx],ax
        pop  ax
        add  ax,64
        call FAR PTR SINQF
        mov  cx,SHKSPD
        imul cx
        mov  cx,256
        idiv cx
        mov  bx,cs:[shki]
        add  bx,bx
        add  cs:[shkz+bx],ax
        push word ptr [camx]    ; and sit down on the new ground
        push word ptr [camz]
        mov  ax,cs:[shkx+bx]
        mov  [camx],ax
        mov  ax,cs:[shkz+bx]
        mov  [camz],ax
        call FAR PTR TERRHF
        pop  word ptr [camz]
        pop  word ptr [camx]
        mov  bx,cs:[shki]
        add  bx,bx
        mov  cs:[shky+bx],ax
        ret

; ---------------------------------------------------------------------------
;  SHKGUN - fire, if the mount has actually arrived. The drum must be inside
;  SHKAPER of where it was asked to point: a gun that shoots while it is
;  still slewing never hits, and one that waits until it is ON the mark is
;  what makes a low pass frightening. Four rounds into the SHARED tracer
;  pool - the same one the jets use, so the rounds fly and draw through
;  machinery that already existed.
;   in: cs:[shki], CX = the demanded bearing; shkel is already slewed.
; ---------------------------------------------------------------------------
SHKGUN: mov  bx,cs:[shki]
        cmp  byte ptr cs:[shkft+bx],0
        je   @@g0
        dec  byte ptr cs:[shkft+bx]
        ret                     ; still feeding
@@g0:   mov  al,cs:[shkt+bx]    ; is the drum on the mark?
        xor  ah,ah
        sub  ax,cx
        and  ax,255
        cmp  ax,128
        jb   @@g1
        sub  ax,256
@@g1:   or   ax,ax
        jns  @@g2
        neg  ax
@@g2:   cmp  ax,SHKAPER
        jg   @@gno
        add  bx,bx              ; shktgt is words
        mov  si,cs:[shktgt+bx]  ; where to send them
        cmp  si,0FFFFh
        jne  @@gai
        mov  ax,[camx]
        mov  [ctx],ax
        mov  ax,[camy]
        mov  [cty],ax
        mov  ax,[camz]
        mov  [ctz],ax
        jmp  @@gd
@@gai:  mov  ax,[pax+si]
        mov  [ctx],ax
        mov  ax,[pay+si]
        mov  [cty],ax
        mov  ax,[paz+si]
        mov  [ctz],ax
@@gd:   mov  bx,cs:[shki]
        add  bx,bx              ; from the muzzles, not from the tracks
        mov  ax,cs:[shkx+bx]
        mov  cs:[shkb],ax
        mov  ax,cs:[shky+bx]
        add  ax,SHKTOP
        mov  cs:[shkv],ax
        mov  ax,cs:[shkz+bx]
        mov  cs:[shkc],ax
        mov  ax,[ctx]
        sub  ax,cs:[shkb]
        mov  [ctx],ax
        mov  ax,[cty]
        sub  ax,cs:[shkv]
        mov  [cty],ax
        mov  ax,[ctz]
        sub  ax,cs:[shkc]
        mov  [ctz],ax
        mov  bx,[ctx]           ; m = the largest leg, for the unit vector
        or   bx,bx
        jns  @@gm1
        neg  bx
@@gm1:  mov  ax,[cty]
        or   ax,ax
        jns  @@gm2
        neg  ax
@@gm2:  cmp  ax,bx
        jle  @@gm3
        mov  bx,ax
@@gm3:  mov  ax,[ctz]
        or   ax,ax
        jns  @@gm4
        neg  ax
@@gm4:  cmp  ax,bx
        jle  @@gm5
        mov  bx,ax
@@gm5:  or   bx,bx
        jz   @@gno
        mov  [wcc],bx
        mov  bx,cs:[shki]
        mov  byte ptr cs:[shkft+bx],SHKFRAT
        mov  byte ptr cs:[shktrg+bx],1
        mov  word ptr [tpi],4   ; a four-round burst, as the jets fire
@@gb:   mov  bx,[trnext]
        inc  word ptr [trnext]
        and  word ptr [trnext],NTRC-1
        mov  byte ptr [trcact+bx],1
        add  bx,bx
        mov  word ptr [trlif+bx],48
        mov  ax,cs:[shkb]
        mov  [tcx+bx],ax
        mov  ax,cs:[shkv]
        mov  [tcy+bx],ax
        mov  ax,cs:[shkc]
        mov  [tcz+bx],ax
        mov  ax,[ctx]
        mov  cx,75
        imul cx
        idiv word ptr [wcc]
        mov  [trvx+bx],ax
        mov  ax,[cty]
        mov  cx,75
        imul cx
        idiv word ptr [wcc]
        mov  [trvy+bx],ax
        mov  ax,[ctz]
        mov  cx,75
        imul cx
        idiv word ptr [wcc]
        mov  [trvz+bx],ax
        push bx                 ; a little spread, or it is a laser
        call FAR PTR RND16F
        pop  bx
        and  ax,7
        sub  ax,3
        add  [trvx+bx],ax
        push bx
        call FAR PTR RND16F
        pop  bx
        and  ax,7
        sub  ax,3
        add  [trvy+bx],ax
        push bx
        call FAR PTR RND16F
        pop  bx
        and  ax,7
        sub  ax,3
        add  [trvz+bx],ax
        ; ---- and START IT CLEAR OF THE GUN. The round used to appear at
        ; the muzzle, which is INSIDE this vehicle's own hit box: 90 across
        ; and 120 tall, against a muzzle barely 50 up. So the first shell of
        ; the first burst hit the thing that fired it, four shells took four
        ; points, and a Shilka blew itself up the moment it opened fire.
        ; Two ticks of flight down the line puts it past its own box on any
        ; bearing, and the tracer still reads as leaving the barrels.
        mov  ax,[trvx+bx]
        add  ax,ax
        add  [tcx+bx],ax
        mov  ax,[trvy+bx]
        add  ax,ax
        add  [tcy+bx],ax
        mov  ax,[trvz+bx]
        add  ax,ax
        add  [tcz+bx],ax
        dec  word ptr [tpi]
        jnz  @@gb
        ; ---- and whether it told: one burst in two, against the jets and
        ; their one in four. A battery that has settled on you SHOULD be
        ; the thing you fly away from.
        call FAR PTR RND16F
        and  ax,1
        cmp  ax,SHKHITC
        jne  @@gno
        mov  bx,cs:[shki]
        add  bx,bx
        mov  si,cs:[shktgt+bx]
        cmp  si,0FFFFh
        jne  @@ghai
        cmp  byte ptr [dying],0
        jne  @@gno              ; he is already going down
        inc  byte ptr [pdam]
        mov  word ptr [phit],9
        cmp  byte ptr [pdam],5
        jb   @@gno
        call FAR PTR CRASHF     ; five hits and the flak got him
        ret
@@ghai: mov  bx,si
        shr  bx,1
        dec  byte ptr [php+bx]
@@gno:  ret

; ---------------------------------------------------------------------------
;  SHKHIT - did something of ours land on a Shilka? Same shape as RSHIT:
;  a box test, not a mesh one. in: rhx/rhy/rhz the point, rhdmg its worth.
;  out: AX = 1 if a LIVE battery took it. No friendly-fire guard - a shell
;  does not read the IFF, and neither does the gun that fired it.
; ---------------------------------------------------------------------------
SHKHIT: mov  word ptr cs:[shki],0
@@h:    mov  bx,cs:[shki]
        cmp  byte ptr cs:[shkst+bx],0
        jne  @@hn               ; already burning
        add  bx,bx
        mov  ax,[rhx]
        sub  ax,cs:[shkx+bx]
        jns  @@h1
        neg  ax
@@h1:   cmp  ax,SHKRAD
        jge  @@hn
        mov  ax,[rhz]
        sub  ax,cs:[shkz+bx]
        jns  @@h2
        neg  ax
@@h2:   cmp  ax,SHKRAD
        jge  @@hn
        mov  ax,[rhy]
        sub  ax,cs:[shky+bx]    ; height above its own tracks
        js   @@hn               ; underground
        cmp  ax,SHKHBOX
        jg   @@hn
        call SHKDAM
        mov  ax,1
        ret
@@hn:   inc  word ptr cs:[shki]
        cmp  word ptr cs:[shki],NSHILK
        jb   @@h
        xor  ax,ax
        ret

; ---------------------------------------------------------------------------
;  SHKDAM - one hit on Shilka cs:[shki]. The last one burns it, through the
;  same wreck pool a building and a radar station use: eight tumbling slabs
;  in grey steel, fire, smoke and a bang scaled by how far away it is.
; ---------------------------------------------------------------------------
SHKDAM: mov  bx,cs:[shki]
        mov  al,cs:[shkhp+bx]
        sub  al,[rhdmg]
        jbe  @@dead
        mov  cs:[shkhp+bx],al
        ret
@@dead: mov  byte ptr cs:[shkhp+bx],0
        mov  byte ptr cs:[shkst+bx],1
        mov  ax,bx              ; a lock on a burning gun is no lock
        add  ax,ax
        add  ax,SHKLK
        cmp  ax,[locki]
        jne  @@nl
        mov  word ptr [locki],0FFFFh
@@nl:   add  bx,bx
        mov  ax,cs:[shkx+bx]
        mov  [bpx],ax
        mov  ax,cs:[shkz+bx]
        mov  [bpz],ax
        mov  word ptr [bschm],0 ; grey walls: steel, not brick
        call FAR PTR WRKATF
        ret

; ---------------------------------------------------------------------------
;  SHKDRAW - the standing vehicles: the chassis at its driving heading and
;  the turret at its bearing, both at the same world point, two MODELDRAW
;  calls each. Drawn with the radar stations - after the buildings, so the
;  jets and the burning debris paint over them. MODELDRAW clobbers SI and
;  DI, which is why the index is re-read from cs:[shki] each time it is
;  wanted. ES = bufseg.
; ---------------------------------------------------------------------------
SHKDRAW:
        mov  word ptr cs:[shki],0
@@v:    mov  bx,cs:[shki]
        cmp  byte ptr cs:[shkst+bx],0
        jne  @@nx               ; burning: the wreck pool has it now
        add  bx,bx
        mov  ax,cs:[shkx+bx]
        sub  ax,[camx]
        mov  [wdx],ax
        mov  ax,cs:[shkz+bx]
        sub  ax,[camz]
        mov  [wdz],ax
        mov  ax,[wdx]           ; the jets' own world-space box reject
        jns  @@q1
        neg  ax
@@q1:   cmp  ax,13000
        jge  @@nx
        mov  ax,[wdz]
        jns  @@q2
        neg  ax
@@q2:   cmp  ax,13000
        jge  @@nx
        call FAR PTR ROTXZF
        mov  ax,[rcz]
        cmp  ax,-100
        jl   @@nx               ; behind us
        cmp  ax,12500
        jge  @@nx               ; past the leash
        mov  [pdz],ax
        mov  ax,[rcx]
        mov  [pdx],ax
        mov  bx,cs:[shki]
        add  bx,bx
        mov  ax,cs:[shky+bx]
        sub  ax,[camy]
        mov  [pdy],ax
        mov  bx,cs:[shki]       ; the chassis, on its driving heading
        mov  al,cs:[shkh+bx]
        xor  ah,ah
        sub  ax,[heading]
        call RSTAYAW
        mov  word ptr [mvb],offset SHULLVT
        mov  word ptr [mvn],SHULLNV*6
        mov  word ptr [mfb],offset SHULLFC
        mov  word ptr [nfc],SHULLNF
        call FAR PTR MODELDRAWF
        mov  bx,cs:[shki]       ; the turret, on its own bearing
        mov  al,cs:[shkt+bx]
        xor  ah,ah
        sub  ax,[heading]
        call RSTAYAW
        mov  word ptr [mvb],offset STURRVT
        mov  word ptr [mvn],STURRNV*6
        mov  word ptr [mfb],offset STURRFC
        mov  word ptr [nfc],STURRNF
        call FAR PTR MODELDRAWF
        mov  bx,cs:[shki]       ; the BARRELS: the turret's bearing again,
        mov  al,cs:[shkt+bx]    ; but pitched at their trunnion on the way
        xor  ah,ah
        sub  ax,[heading]
        call RSTAYAW
        mov  bx,cs:[shki]
        mov  al,cs:[shkel+bx]
        xor  ah,ah
        push ax
        call FAR PTR SINQF
        mov  [mpsn],ax
        pop  ax
        add  ax,64
        call FAR PTR SINQF
        mov  [mpcs],ax
        mov  word ptr [mtpy],SHKTRNY
        mov  word ptr [mtpz],SHKTRNZ
        mov  byte ptr [mpon],1
        mov  word ptr [mvb],offset SBARRVT
        mov  word ptr [mvn],SBARRNV*6
        mov  word ptr [mfb],offset SBARRFC
        mov  word ptr [nfc],SBARRNF
        call FAR PTR MODELDRAWF
        mov  byte ptr [mpon],0  ; nothing else in the game has a second joint
        mov  bx,cs:[shki]       ; and the RADAR, sweeping on its own - the
        mov  al,cs:[shkd+bx]    ; part that is supposed to be turning
        xor  ah,ah
        sub  ax,[heading]
        call RSTAYAW
        mov  word ptr [mvb],offset SDISHVT
        mov  word ptr [mvn],SDISHNV*6
        mov  word ptr [mfb],offset SDISHFC
        mov  word ptr [nfc],SDISHNF
        call FAR PTR MODELDRAWF
        mov  bx,cs:[shki]       ; and its marker - even ours, odd theirs
        add  bx,bx
        mov  ax,cs:[shky+bx]
        add  ax,SHKTOP/2
        sub  ax,[camy]
        mov  [pdy],ax
        mov  byte ptr [COLOR],95
        mov  byte ptr [gmks],0
        test word ptr cs:[shki],1
        jz   @@smk
        mov  byte ptr [COLOR],96
        mov  byte ptr [gmks],1
@@smk:  mov  ax,cs:[shki]       ; red once it is the locked one
        add  ax,ax
        add  ax,SHKLK
        cmp  ax,[locki]
        jne  @@smk2
        mov  byte ptr [COLOR],19
@@smk2: mov  word ptr [gmkn],5000
        call FAR PTR GNDMARKF
@@nx:   inc  word ptr cs:[shki]
        cmp  word ptr cs:[shki],NSHILK
        jb   @@v
        ret

; ============================================================================
;  MAPHUM followed MINIMAP2F out here (2026-07-28, the radar stations):
;  it draws ON that map and only plots glyphs, so it belongs beside it.
;  Far door: MAPHUMF. FDRAW stayed home behind FDRAWF - the strings and
;  NB it reads are main-segment bytes and DS is the main segment here.
; ============================================================================
MAPHUMF PROC FAR
        ; The TRAFFIC is deliberately not here. Aeroplane symbols were drawn
        ; on this map for a day and taken off again: the map answers "what
        ; is on the ground and where am I over it", and the scope beside it
        ; already answers "who is in the air". Two instruments saying the
        ; same thing is one instrument's worth of information and two
        ; instruments' worth of clutter. Ground only: the baked city, the
        ; batteries and the stations.
        call MAPHUM
        call RSMAP              ; the two stations, on the same glass
        call SHKMAP             ; ...and the flak batteries
        ret
MAPHUMF ENDP
; ============================================================================
;  MAPHUM - the humans on the centre map: callsign letter + altitude
;  digit (thousands) at their node, white, over the half-scale map at
;  (144,155). ES=bufseg, DS=CS.
; ============================================================================
MAPHUM: xor  si,si
@@mh:   mov  bx,si
        shr  bx,1
        cmp  byte ptr [premote+bx],0
        je   @@mhn
        cmp  byte ptr [pst+bx],0
        jne  @@mhn
        mov  al,[pltr+bx]
        or   al,al
        jz   @@mhn
        mov  [NB],al
        mov  ax,[pay+si]        ; the altitude digit, thousands
        or   ax,ax
        jns  @@mhp
        xor  ax,ax
@@mhp:  xor  dx,dx
        mov  bx,1000
        div  bx
        cmp  ax,9
        jbe  @@mhd
        mov  ax,9
@@mhd:  add  al,'0'
        mov  [NB+1],al
        mov  byte ptr [NB+2],0
        mov  ax,[pax+si]        ; the map's own arithmetic, shared
        add  ax,BIAS
        mov  cl,10
        shr  ax,cl
        and  ax,63
        call MMPTX
        jc   @@mhn              ; this pilot is off the window
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
        jc   @@mhn
        mov  bx,ax
        sub  bx,3               ; centre the glyph rows on the node...
        cmp  bx,PZMMY
        jge  @@mhy
        mov  bx,PZMMY           ; ...but keep it inside the MFD glass
@@mhy:  cmp  bx,PZMMY+PZADIH-6
        jle  @@mhz
        mov  bx,PZMMY+PZADIH-6
@@mhz:  mov  [fty],bx
        mov  byte ptr [COLOR],8
        push si
        mov  si,offset NB
        call FAR PTR FDRAWF
        pop  si
@@mhn:  add  si,2
        cmp  si,NPLANE*2
        jb   @@mh
        ret

; (MAPJETS lived here for one afternoon: the traffic drawn on the map as
;  aeroplane symbols, north-up. It came off again - see the note in
;  MAPHUMF. The scope carries the air picture; this glass carries the
;  ground. The symbols themselves were fine and are still on the scope.)


STATPGF PROC FAR
        call STATPG
        call WARNLMP            ; ...and the overhead lamps, on the same trip
        call SIDEPNL            ; out, the two word columns beside them,
        call OSBLAMP            ; and the six lamp columns by the screens.
        ret                     ; A far door apiece would have cost five
STATPGF ENDP                    ; bytes each of a segment with eight left

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
SPPLW   equ 23                  ; ...and how wide they are
SPSY0   equ 129                 ; first slot's top row; five of them
SPSH    equ 10                  ; ...pitch...
SPFH    equ 9                   ; ...how much of that is the lit plate...
SPTY    equ 2                   ; ...and the word's own row inside it, so
                                ;  the legend is centred DOWN the slot as
                                ;  well as across it
SPNY0   equ 129                 ; the plate's own top and bottom, for the
SPNY1   equ 180                 ;  speckle that goes down before the words
SPDARK  equ PNLDIM              ; the panel's own set, defined once in
SPGRN   equ PNLGRN              ;  DATA.INC beside the zone constants so
SPAMB   equ PNLAMB              ;  both segments read the same numbers
SPRED   equ PNLRED
; NUL padding, not spaces, so a word can be MEASURED and centred. Five
; letters fill the plate exactly; a four-letter one used to start at the
; same x and sat two pixels left of where it belonged.
SPTXT   db 'FLAPS',0,'GEAR',0,0,'BRAKE',0,'BURN',0,0,0,0,0,0,0,0
        db 'STALL',0,'FUEL',0,0,'TERR',0,0,'FIRE',0,0,'LOCK',0,0
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
SWY     equ 186                 ; the label row, inside the plate
SWTXT   db 'GND',0,'AIR',0,'TAC',0,'IFF',0,'A-A',0,'A-G',0
        db 'A-P',0,'T-R',0,'ECM',0,'JMR',0,'CHF',0,'FLR',0
; What each plate reports. 0 = the master mode, handled apart; 0FFFFh = a
; box that exists on the panel but not yet in the game, and an unlit plate
; is an honest way to say so.
SWLIT   dw offset swgnd, offset swair, offset swtac, offset swiff
        dw 0, 0
        dw offset swap,  offset swtr,  offset swecm, offset swjmr
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
SWNK    equ 12
swprev  db SWNK dup(0)          ; last state of each switch's key
SWKTAB  db SC_F
        dw offset flaps
        db SC_L
        dw offset gear
        db SC_B
        dw offset abrk
        db SC_G
        dw offset swgnd
        db SC_U
        dw offset swair
        db SC_I
        dw offset swiff
        db SC_T
        dw offset swtac
        db SC_O
        dw offset swmode
        db SC_P
        dw offset swap
        db SC_R
        dw offset swtr
        db SC_J
        dw offset swecm
        db SC_Y
        dw offset swjmr

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
OSBLX   equ 4                   ; the lens sits four in from the plate's left
; The CENTRE screen sits three pixels lower than the other two in the
; artwork (129 against 126), and so do the two columns flanking it. One
; table with a per-column offset lands on all six; the first attempt used
; the radar column's rows for everything and missed four columns out of
; six by exactly that three.
OSBDY   db 0,2,3,3,0,0
; Seven plates a column, and the rows are NOT on a regular pitch - the
; artwork drifts, so they were measured off it rather than computed. These
; are the TOP row of each lens; the artwork's own lamp centre is one lower.
OSBYT   dw 132,138,144,149,155,161,167
OSBN    equ 7
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
        jcxz @@bd
        cmp  cx,OSBN
        jbe  @@b1
        mov  cx,OSBN
@@b1:   push cx
@@b2:   stc                     ; a run of CX ones, at the low bits...
        rcl  ax,1
        loop @@b2
        pop  cx
        mov  bx,OSBN            ; ...shifted down to the bottom slots, since
        sub  bx,cx              ;  bit 0 is the TOP lamp of the column
        mov  cx,bx
        jcxz @@bd
        shl  ax,cl
@@bd:   mov  cs:[osbm],ax
        ret

OSBLAMP:
        cld
        mov  word ptr cs:[osbr],0   ; no red and no flash unless a column
        mov  word ptr cs:[osbf],0   ;  asks for them
        ; ---- column 0: the RADAR's zoom. rzsh runs 6 close .. 10 wide, so
        ; a tight scope shows a tall bar - more rungs, more detail ----
        mov  al,11
        sub  al,[rzsh]
        xor  ah,ah
        call OSBBAR
        mov  byte ptr cs:[osbc],PNLAMB
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
        mov  word ptr cs:[osbr],40h ; the bottom lamp, always red
        pop  ax
        cmp  ax,2
        jae  @@ol1
        mov  word ptr cs:[osbf],40h ; ...and flashing, on the last division
@@ol1:  mov  byte ptr cs:[osbc],PNLAMB
        mov  bx,1
        call OSBCOL
        mov  word ptr cs:[osbr],0
        mov  word ptr cs:[osbf],0
        ; ---- column 2: which PAGE the centre screen is showing ----
        mov  al,[mfdmode]
        xor  ah,ah
        mov  cx,ax
        mov  ax,1
        shl  ax,cl              ; one lamp, counted from the top
        mov  cs:[osbm],ax
        mov  byte ptr cs:[osbc],PNLGRN
        mov  bx,2
        call OSBCOL
        ; ---- column 3: the MAP's own zoom, next to the map ----
        mov  al,[mmzs]
        inc  al
        xor  ah,ah
        call OSBBAR
        mov  byte ptr cs:[osbc],PNLAMB
        mov  bx,3
        call OSBCOL
        ; ---- column 4: missiles left on the rails ----
        mov  al,[pammo]
        xor  ah,ah
        call OSBBAR
        mov  byte ptr cs:[osbc],PNLGRN
        mov  bx,4
        call OSBCOL
        ; ---- column 5: damage taken, filling DOWNWARD from the top - a
        ; bar that grows toward you reads as something getting worse ----
        mov  al,[pdam]
        xor  ah,ah
        mov  cx,ax
        xor  ax,ax
        jcxz @@ol5
@@ol4:  stc
        rcl  ax,1
        loop @@ol4
@@ol5:  mov  cs:[osbm],ax
        mov  cs:[osbf],ax       ; damage FLASHES, all of it. A hit you have
        mov  byte ptr cs:[osbc],PNLRED  ; already taken is not news; a hit
        mov  bx,5               ; you are still carrying is
        call OSBCOL
        mov  word ptr cs:[osbf],0
        ret

; OSBCOL - paint one column. in: BX = column 0..5, and cs:[osbm]/[osbr]/
;  [osbf]/[osbc]. Each lamp is a four by three ROUND LENS: the corners are
;  left alone so the silhouette is not a square, the top-left is the core
;  colour and the bottom-right is its shadow. That is what makes something
;  this small look like a piece of moulded plastic with light behind it
;  rather than a coloured brick.
OSBCOL: mov  al,cs:[OSBDY+bx]   ; this column's own vertical offset
        mov  cs:[osbyo],al
        add  bx,bx
        mov  ax,cs:[OSBX+bx]
        add  ax,OSBLX
        mov  [dsx],ax
        xor  si,si              ; slot, 0 = top
@@cl:   mov  cx,si
        mov  ax,1
        shl  ax,cl
        test cs:[osbm],ax
        jz   @@cn
        test cs:[osbf],ax       ; a flashing lamp is dark half the time
        jz   @@ck
        test word ptr [lasttk],PNLBLNK
        jz   @@cn
@@ck:   mov  ah,cs:[osbc]       ; red overrides the column's own colour
        test cs:[osbr],ax
        jz   @@cc
        mov  ah,PNLRED
@@cc:   mov  al,ah
        add  ah,PNLSHAD         ; AL = core, AH = its shadow
        mov  bx,si
        add  bx,bx
        push ax
        mov  ax,cs:[OSBYT+bx]
        mov  bl,cs:[osbyo]
        xor  bh,bh
        add  ax,bx
        call UROW
        pop  ax
        add  di,[dsx]
        mov  es:[di+1],al       ; . C C .
        mov  es:[di+2],al
        mov  es:[di+320],al     ; C C C R
        mov  es:[di+321],al
        mov  es:[di+322],al
        mov  es:[di+323],ah
        mov  es:[di+641],ah     ; . R R .
        mov  es:[di+642],ah
@@cn:   inc  si
        cmp  si,OSBN
        jb   @@cl
        ret

SWKEYSF PROC FAR
        call SWKEYS
        ret
SWKEYSF ENDP
SWKEYS: xor  si,si              ; row index 0..SWNK-1
@@k:    mov  bx,si
        add  bx,bx
        add  bx,si              ; *3 bytes a row
        mov  bl,cs:[SWKTAB+bx]
        xor  bh,bh
        mov  al,[KEYS+bx]       ; KEYS is at home, and DS points home
        mov  bx,si
        cmp  al,cs:[swprev+bx]
        je   @@kn
        mov  cs:[swprev+bx],al
        test al,al
        jz   @@kn               ; key-up edge: nothing happens
        mov  bx,si
        add  bx,bx
        add  bx,si
        mov  di,word ptr cs:[SWKTAB+bx+1]
        xor  byte ptr [di],1
@@kn:   inc  si
        cmp  si,SWNK
        jb   @@k
        ret
spmsk   dw 0                    ; which of the ten are live this frame
spcol   db 0                    ; the slot's BACKGROUND colour (0 = unlit)
spplx   dw 0                    ; ...and the plate's left edge
spwink  db 0                    ; the ink colour for this slot's word

SIDEPNL:
        ; ---- the glass first. A flat black rectangle reads as a hole cut
        ; in the panel; a few barely-lit specks read as glass with a lamp
        ; somewhere behind it, and the words then sit ON something. The
        ; pattern is fixed, not random - noise regenerated every frame
        ; would crawl, and a crawling panel is worse than a flat one. ----
        cld
        xor  si,si
@@nsp:  mov  bx,si
        add  bx,bx
        mov  di,cs:[SPNX+bx]
        mov  word ptr [dsx],SPNY0
@@nsr:  mov  ax,[dsx]
        mov  bx,ax              ; the row's own offset: (y*3) and 3, which
        add  bx,bx              ;  walks 0,3,2,1 down the plate and never
        add  bx,ax              ;  lines the specks up into a stripe
        and  bx,3
        push di
        call UROW
        pop  ax
        add  di,ax
        add  di,bx
        push ax
        mov  al,PNLNOIS
        mov  cx,5
@@nsx:  mov  es:[di],al
        add  di,4
        loop @@nsx
        pop  di
        inc  word ptr [dsx]
        cmp  word ptr [dsx],SPNY1
        jbe  @@nsr
        inc  si
        cmp  si,2
        jb   @@nsp
        mov  word ptr cs:[spmsk],0
        cmp  byte ptr [flaps],0 ; ---- left: what is hanging out ----
        je   @@spg
        or   word ptr cs:[spmsk],1
@@spg:  cmp  byte ptr [gear],0
        je   @@spb
        or   word ptr cs:[spmsk],2
@@spb:  cmp  byte ptr [abrk],0
        je   @@spa
        or   word ptr cs:[spmsk],4
@@spa:  cmp  byte ptr [abon],0
        je   @@sps
        or   word ptr cs:[spmsk],8
@@sps:  mov  ax,[vel]           ; ---- right: what the aeroplane says ----
        cmp  ax,[vstl]
        jge  @@spf
        or   word ptr cs:[spmsk],32
@@spf:  cmp  word ptr [fuel],1200
        jge  @@spt
        or   word ptr cs:[spmsk],64
@@spt:  mov  ax,[camy]
        sub  ax,[lgnd]
        cmp  ax,300
        jge  @@spi
        or   word ptr cs:[spmsk],128
@@spi:  cmp  byte ptr [pdam],4
        jb   @@spk
        or   word ptr cs:[spmsk],256
@@spk:  cmp  word ptr [locki],0FFFFh
        je   @@spd
        or   word ptr cs:[spmsk],512
        ; ---- and paint all ten. A real annunciator does NOT colour its
        ; letters: it lights the whole legend plate from behind and the
        ; printed word stays the dark grey it was printed in. So the SLOT
        ; fills with colour, faintly banded the way a lit panel always is,
        ; a dark line divides one from the next, and the word goes on top
        ; in the same grey whether the lamp is on or off. ----
@@spd:  xor  si,si
@@spl:  mov  cx,si
        mov  ax,1
        shl  ax,cl
        mov  byte ptr cs:[spcol],0      ; 0 = this slot is not lit
        test cs:[spmsk],ax
        jz   @@spp
        test word ptr [lasttk],PNLBLNK
        jz   @@spp              ; live, dark half of the blink
        mov  byte ptr cs:[spcol],SPGRN  ; a system that is OUT reads green
        cmp  si,5
        jb   @@spp
        mov  byte ptr cs:[spcol],SPRED  ; a warning reads red...
        cmp  si,9
        jne  @@spp
        mov  byte ptr cs:[spcol],SPAMB  ; ...but a lock is news, not alarm
@@spp:  mov  di,si              ; MEASURE the word, so it can be centred
        add  di,di
        mov  bx,di
        add  di,di
        add  di,bx              ; *6
        xor  cx,cx
@@spm:  cmp  byte ptr cs:[SPTXT+di],0
        je   @@spw
        inc  di
        inc  cx
        cmp  cx,5
        jb   @@spm
@@spw:  mov  ax,cx              ; ink = len*4 - 1, so the left margin is
        add  ax,ax              ;  (23 - ink) / 2
        add  ax,ax
        dec  ax
        neg  ax
        add  ax,SPPLW
        sar  ax,1
        mov  bx,si              ; which plate
        cmp  bx,5
        jb   @@spx
        sub  bx,5
        mov  bx,2
        jmp  @@spx2
@@spx:  xor  bx,bx
@@spx2: mov  dx,cs:[SPNX+bx]
        mov  cs:[spplx],dx      ; the plate itself, for the lit background
        add  ax,dx
        mov  [ftx],ax
        mov  ax,si
        cmp  ax,5
        jb   @@spy
        sub  ax,5
@@spy:  mov  bx,SPSH
        imul bx
        add  ax,SPSY0           ; the slot's top row
        mov  [dsy],ax
        add  ax,SPTY            ; ...and the word, centred DOWN it too
        mov  [fty],ax
        mov  al,PNLCAP          ; the ink: grey on black, black on colour
        cmp  byte ptr cs:[spcol],0
        je   @@sqt
        mov  al,PNLNOIS
@@sqt:  mov  cs:[spwink],al
        ; ---- the lit plate behind the word, and the dark line dividing
        ; this slot from the next.
        ;
        ; It was BANDED for a while - a darker line every fourth row - and
        ; that was the wrong instinct twice over: at half brightness it was
        ; a zebra, and even at a tenth it still read as stripes rather than
        ; as a surface. Flat colour with a scatter of grey specks does what
        ; the stripes were meant to do. The specks are placed from the row
        ; number, so the pattern is fixed and will not crawl. ----
        cmp  byte ptr cs:[spcol],0
        je   @@sq1
        mov  cx,SPFH
        mov  ax,[dsy]
@@sq0:  push cx
        push ax
        call UROW
        add  di,cs:[spplx]
        push di
        mov  al,cs:[spcol]
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
        mov  byte ptr es:[di+bx],PNLCAP
        mov  bx,ax
        mov  cl,2
        shl  bx,cl
        add  bx,ax
        and  bx,7
        add  bx,14
        mov  byte ptr es:[di+bx],PNLCAP
        pop  ax
        inc  ax
        pop  cx
        loop @@sq0
@@sq1:  mov  ax,[dsy]           ; the divider, lit slot or not
        add  ax,SPFH
        call UROW
        add  di,cs:[spplx]
        mov  al,PNLNOIS
        mov  cx,SPPLW
        rep  stosb
        mov  di,si              ; the string: six bytes a slot
        add  di,di
        mov  bx,di
        add  di,di
        add  di,bx
@@spc:  mov  al,cs:[SPTXT+di]
        test al,al
        jz   @@spn
        ; LETTERS ONLY, and the test is a range, not a check for a space.
        ; The A/B caption carried a slash, and 'A'-10 subtracted off it gave
        ; a glyph index of 248 - six times that is a read a kilobyte and a
        ; half past the end of FONTBUF. It drew nothing visible, which is
        ; the worst way for a bad read to behave. Anything that is not a
        ; capital now simply steps the pen, the way the padding spaces do.
        cmp  al,'A'
        jb   @@spv
        cmp  al,'Z'
        ja   @@spv
        sub  al,'A'-10
        xor  ah,ah
        mov  bx,ax
        add  ax,ax
        add  ax,ax
        add  ax,bx
        add  ax,bx              ; *6 rows a glyph
        push si
        push di
        mov  si,offset FONTBUF
        add  si,ax
        mov  ax,[fty]
        call UROW
        add  di,[ftx]
        mov  cx,6
@@spr:  mov  al,[si]
        mov  ah,cs:[spwink]     ; grey on a dark plate, NEAR BLACK on a lit
                                ;  one. The word is printed on the plate,
                                ;  not made of light - so when the lamp
                                ;  comes on behind it, it goes darker, not
                                ;  brighter, and that is what makes a lit
                                ;  legend readable instead of glaring.
        test al,80h
        jz   @@sp1
        mov  es:[di],ah
@@sp1:  test al,40h
        jz   @@sp2
        mov  es:[di+1],ah
@@sp2:  test al,20h
        jz   @@sp3
        mov  es:[di+2],ah
@@sp3:  inc  si
        add  di,320
        loop @@spr
        pop  di
        pop  si
@@spv:  add  word ptr [ftx],4
        inc  di
        jmp  @@spc
@@spn:  inc  si
        cmp  si,10
        jb   @@spl
        ; ---- and the twelve buttons under the screens ----
        cld
        xor  si,si
@@swl:  xor  al,al              ; is THIS plate lit?
        cmp  si,4
        je   @@swaa
        cmp  si,5
        je   @@swag
        cmp  si,10
        jae  @@swd              ; chaff and flares: on the panel, not yet
        mov  bx,si              ;  in the game, and left honestly dark
        add  bx,bx
        mov  di,cs:[SWLIT+bx]
        mov  al,[di]
        jmp  @@swd
@@swaa: mov  al,[swmode]        ; A-A: lit when the mode is NOT air-to-ground
        xor  al,1
        jmp  @@swd
@@swag: mov  al,[swmode]        ; A-G: the other half of the same switch
@@swd:  mov  byte ptr cs:[spcol],SPDARK
        test al,al
        jz   @@swp
        mov  byte ptr cs:[spcol],SPGRN
@@swp:  mov  bx,si
        add  bx,bx
        mov  ax,cs:[SWX+bx]
        mov  [ftx],ax
        mov  di,si              ; four bytes a label
        add  di,di
        add  di,di
@@swt:  mov  al,cs:[SWTXT+di]
        test al,al
        jz   @@swn
        ; the font keeps its punctuation after the letters: '-' is glyph
        ; 37, and A-A cannot be written without it
        mov  ah,37
        cmp  al,'-'
        je   @@swg
        cmp  al,'A'
        jb   @@swv
        cmp  al,'Z'
        ja   @@swv
        sub  al,'A'-10
        mov  ah,al
@@swg:  mov  al,ah
        xor  ah,ah
        mov  bx,ax
        add  ax,ax
        add  ax,ax
        add  ax,bx
        add  ax,bx              ; *6 rows a glyph
        push si
        push di
        mov  si,offset FONTBUF
        add  si,ax
        mov  ax,SWY
        call UROW
        add  di,[ftx]
        mov  cx,6
@@swr:  mov  al,[si]
        mov  ah,cs:[spcol]
        test al,80h
        jz   @@sw1
        mov  es:[di],ah
@@sw1:  test al,40h
        jz   @@sw2
        mov  es:[di+1],ah
@@sw2:  test al,20h
        jz   @@sw3
        mov  es:[di+2],ah
@@sw3:  inc  si
        add  di,320
        loop @@swr
        pop  di
        pop  si
@@swv:  add  word ptr [ftx],4
        inc  di
        jmp  @@swt
@@swn:  inc  si
        cmp  si,12
        jb   @@swl
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
WLMPY   equ 10                  ; the lens row, in 320x200 panel coords
WLCAPY  equ 4                   ; ...and the caption row above it
; The warning about not taking a colour out of 31..93 now lives with the
; PNL* equs in DATA.INC, where the numbers are.
WLGREY  equ PNLCAP
wlmsk   dw 0                    ; which lamps want to be lit this frame
WLMPX   dw 98,110,121,133,185,197,210
WLMPC   db 97,19,19,97,97,19,19 ; amber for a caution, red for a threat
WLMPB   db 1,1,0,0,0,1,1        ; ...and which of them flash rather than sit
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
        mov  word ptr cs:[wlmsk],0
        xor  si,si              ; MSL: an AI missile is chasing US. amtgt is
@@wms:  mov  bx,si              ;  a plane offset and the pilot is plane 0
        shr  bx,1
        cmp  byte ptr [amact+bx],0
        je   @@wmsn
        cmp  word ptr [amtgt+si],0
        jne  @@wmsn
        or   word ptr cs:[wlmsk],2
@@wmsn: add  si,2
        cmp  si,NAMSL*2
        jb   @@wms
        xor  si,si              ; AAA: a live Shilka has the pilot on its gun
@@waa:  mov  bx,si
        shr  bx,1
        cmp  byte ptr cs:[shkst+bx],0
        jne  @@waan             ; burning: it is not shooting anybody
        cmp  word ptr cs:[shktgt+si],0FFFFh
        jne  @@waan
        or   word ptr cs:[wlmsk],4
@@waan: add  si,2
        cmp  si,NSHILK*2
        jb   @@waa
        cmp  byte ptr [pdam],0  ; DMG: anything broken at all
        je   @@wdm
        or   word ptr cs:[wlmsk],8
@@wdm:  cmp  word ptr [fuel],1200
        jge  @@wfu              ; FUEL: under a fifth of the tank
        or   word ptr cs:[wlmsk],16
@@wfu:  cmp  byte ptr [pdam],4  ; FIRE: four hits of the five that kill -
        jb   @@wfi              ;  the next one is the last one
        or   word ptr cs:[wlmsk],32
@@wfi:  mov  ax,[camy]          ; GND: the ground is coming up
        sub  ax,[lgnd]
        cmp  ax,300
        jge  @@wgn
        or   word ptr cs:[wlmsk],64
@@wgn:  cmp  word ptr cs:[wlmsk],0
        je   @@wdr              ; MSTR: master caution, lit by all the rest
        or   word ptr cs:[wlmsk],1
@@wdr:  xor  si,si
@@wdl:  mov  cx,si
        mov  ax,1
        shl  ax,cl
        test cs:[wlmsk],ax
        jz   @@wdn
        cmp  byte ptr cs:[WLMPB+si],0
        je   @@wdon
        test word ptr [lasttk],PNLBLNK ; the urgent ones flash, about twice a second
        jz   @@wdn
@@wdon: mov  ax,WLMPY
        call UROW
        mov  bx,si
        add  bx,bx
        add  di,cs:[WLMPX+bx]
        mov  al,cs:[WLMPC+si]
        mov  cx,3
@@wdr2: mov  es:[di],al
        mov  es:[di+1],al
        mov  es:[di+2],al
        add  di,320
        loop @@wdr2
@@wdn:  inc  si
        cmp  si,7
        jb   @@wdl
        ; ---- and the captions over them. FDRAW cannot be used: it walks
        ; its string with DS:SI, DS is the MAIN segment in here, and these
        ; words live in UISEG. Moving them home was not on the table - the
        ; main segment has eight bytes left. So the glyph blitter is copied
        ; here instead, reading the SAME FONTBUF (a main-segment buffer, so
        ; plain DS) and costing that segment nothing at all ----
        xor  si,si              ; lamp index
@@wct:  mov  bx,si
        add  bx,bx
        mov  ax,cs:[WLMPX+bx]
        sub  ax,2               ; seven pixels of ink, centred on the lens
        mov  [ftx],ax
        mov  di,si              ; the string cursor: four bytes a caption
        add  di,di
        add  di,di
@@wcc:  mov  al,cs:[WLMPT+di]
        test al,al
        jz   @@wce
        sub  al,'A'-10          ; the font puts the letters after the digits
        xor  ah,ah
        mov  bx,ax
        add  ax,ax
        add  ax,ax
        add  ax,bx
        add  ax,bx              ; *6: six rows a glyph
        push si
        push di
        mov  si,offset FONTBUF
        add  si,ax
        mov  ax,WLCAPY
        call UROW
        add  di,[ftx]
        mov  cx,6
@@wcr:  mov  al,[si]
        mov  ah,WLGREY
        test al,80h
        jz   @@wc1
        mov  es:[di],ah
@@wc1:  test al,40h
        jz   @@wc2
        mov  es:[di+1],ah
@@wc2:  test al,20h
        jz   @@wc3
        mov  es:[di+2],ah
@@wc3:  inc  si
        add  di,320
        loop @@wcr
        pop  di
        pop  si
        add  word ptr [ftx],4
        inc  di
        jmp  @@wcc
@@wce:  inc  si
        cmp  si,7
        jb   @@wct
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
        mov  es:[di],al
        mov  es:[di+1],al
        mov  es:[di+2],al
        mov  es:[di+320],al
        mov  es:[di+322],al
        mov  es:[di+640],al
        mov  es:[di+641],al
        mov  es:[di+642],al
        mov  ax,PZMAPY0+3             ; yellow diamond: kills by theirs
        call UROW
        add  di,PZMAPX0+39
        mov  al,96
        mov  es:[di+1],al
        mov  es:[di+320],al
        mov  es:[di+322],al
        mov  es:[di+641],al
        mov  byte ptr [COLOR],95
        mov  word ptr [ftx],PZMAPX0+8
        mov  word ptr [fty],PZMAPY0+3
        mov  ax,[tscf]
        call FAR PTR FNUMF
        mov  byte ptr [COLOR],8 ; own kills, centre, white
        mov  word ptr [ftx],PZMAPX0+21
        mov  word ptr [fty],PZMAPY0+3
        mov  ax,[psc]
        call FAR PTR FNUMF
        mov  byte ptr [COLOR],96
        mov  word ptr [ftx],PZMAPX0+31
        mov  word ptr [fty],PZMAPY0+3
        mov  ax,[tsch]
        call FAR PTR FNUMF
        mov  byte ptr [COLOR],97 ; cannon rounds
        mov  word ptr [ftx],PZMAPX0+2
        mov  word ptr [fty],PZMAPY0+12
        mov  si,offset MSGGUN
        call FAR PTR FDRAWF
        mov  byte ptr [COLOR],8
        mov  word ptr [ftx],PZMAPX0+20
        mov  ax,[gunam]
        call FAR PTR FNUMF
        mov  byte ptr [COLOR],97 ; missile rails: label + a pip each
        mov  word ptr [ftx],PZMAPX0+2
        mov  word ptr [fty],PZMAPY0+21
        mov  si,offset MSGMSL
        call FAR PTR FDRAWF
        xor  si,si
@@amo:  mov  ax,si
        cmp  al,[pammo]
        jae  @@amn
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
        mov  es:[di],al
        mov  es:[di+1],al
        mov  es:[di+2],al
        mov  es:[di+3],al
        mov  es:[di+320],al
        mov  es:[di+321],al
        mov  es:[di+322],al
        mov  es:[di+323],al
@@amn:  inc  si
        cmp  si,4
        jb   @@amo
        mov  byte ptr [COLOR],97 ; damage: label + red pips
        mov  word ptr [ftx],PZMAPX0+2
        mov  word ptr [fty],PZMAPY0+29
        mov  si,offset MSGDAM
        call FAR PTR FDRAWF
        xor  si,si
@@dmp:  mov  ax,si
        cmp  al,[pdam]
        jae  @@dmn
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
        mov  es:[di],al
        mov  es:[di+1],al
        mov  es:[di+2],al
        mov  es:[di+320],al
        mov  es:[di+321],al
        mov  es:[di+322],al
@@dmn:  inc  si
        cmp  si,5
        jb   @@dmp
        ; ---- fuel, which used to sit in the readout block. That block is
        ; four fields wide now and the artwork names them IAS/ALT/HDG/VERT,
        ; so the tank came here - this page IS the status page, and the new
        ; screen is fifteen rows taller than the one it replaced. Red under
        ; the same 1200 the warning lamp uses, so lamp and number agree.
        mov  byte ptr [COLOR],97
        mov  word ptr [ftx],PZMAPX0+2
        mov  word ptr [fty],PZMAPY0+38
        mov  si,offset MSGFUE2
        call FAR PTR FDRAWF
        mov  byte ptr [COLOR],8
        cmp  word ptr [fuel],1200
        jge  @@fu1
        mov  byte ptr [COLOR],19
@@fu1:  mov  word ptr [ftx],PZMAPX0+20
        mov  ax,[fuel]
        xor  dx,dx
        mov  bx,60
        div  bx
        call FAR PTR FNUMF
        ret


TGTVIEWF PROC FAR
        call TGTVIEW
        ret
TGTVIEWF ENDP
; ---------------------------------------------------------------------------
;  TGTVIEW - the TGT page on the CENTRE MFD: callsign (worn in the
;  IFF colour), type, range, target altitude and a wireframe of the
;  jet (aspect follows its heading). No lock: the page says NO TGT.
; ---------------------------------------------------------------------------
TGTVIEW:
        mov  si,[locki]
        cmp  si,0FFFFh
        jne  @@tgo
        mov  byte ptr [COLOR],97 ; nothing locked: the page says so
        mov  word ptr [ftx],PZADIX0+12
        mov  word ptr [fty],PZADIY0+15
        mov  si,offset MSGNOT
        call FAR PTR FDRAWF
        ret
@@tgo:  mov  byte ptr [COLOR],19 ; the callsign wears the IFF colour
        test si,2
        jnz  @@tgc
        mov  byte ptr [COLOR],95
@@tgc:  mov  word ptr [ftx],PZADIX0+2
        mov  word ptr [fty],PZADIY0+3
        call FAR PTR CSDRAWF
        mov  byte ptr [COLOR],8
        mov  word ptr [ftx],PZADIX0+2
        mov  word ptr [fty],PZADIY0+11
        mov  si,[locki]
        call FAR PTR TYPDRAWF
        mov  byte ptr [COLOR],97 ; range: octagonal max + 3*(min/8)
        mov  word ptr [ftx],PZADIX0+2
        mov  word ptr [fty],PZADIY0+19
        mov  si,offset MSGRNG
        call FAR PTR FDRAWF
        mov  si,[locki]
        call FAR PTR LKPOSF
        mov  ax,[lkx]
        sub  ax,[camx]
        jns  @@tr1
        neg  ax
@@tr1:  mov  bx,[lkz]
        sub  bx,[camz]
        jns  @@tr2
        neg  bx
@@tr2:  cmp  ax,bx
        jae  @@tr3
        xchg ax,bx
@@tr3:  mov  cl,3
        shr  bx,cl
        add  ax,bx              ; max 32767 + 3*4095: read UNSIGNED
        add  ax,bx
        add  ax,bx
        cmp  ax,30000           ; clamp before FNUMK's signed idiv era
        jbe  @@trc
        mov  ax,30000
@@trc:  mov  word ptr [ftx],PZADIX0+18
        mov  byte ptr [COLOR],8
        call FAR PTR FNUMKF
        mov  byte ptr [COLOR],97 ; the target's altitude
        mov  word ptr [ftx],PZADIX0+2
        mov  word ptr [fty],PZADIY0+27
        mov  si,offset MSGALT
        call FAR PTR FDRAWF
        mov  word ptr [ftx],PZADIX0+20
        mov  byte ptr [COLOR],8
        mov  si,[locki]
        call FAR PTR LKPOSF
        mov  ax,[lky]
        or   ax,ax
        jns  @@tr4
        xor  ax,ax
@@tr4:  call FAR PTR FNUMKF
        ; wireframe: rotate the model by its aspect, project small
        mov  si,[locki]         ; FNUMK's font walk ate SI
        cmp  si,RSLK
        jb   @@tshk
        mov  word ptr [mvb],offset RDISHVT ; a station shows its DISH, and
        mov  word ptr [mvn],RDISHNV*6      ; it turns on the page as it
        mov  word ptr [mfb],offset RDISHFC
        mov  word ptr [nfc],RDISHNF
        mov  word ptr [tgzo],400           ; turns out there on the hill.
        mov  word ptr [tgyc],64            ; It is six times a jet's size:
        mov  ax,[rspin]                    ; stand further off, and centre
        jmp  @@tyaw                        ; on the hub, not on the feet
@@tshk: cmp  si,SHKLK
        jb   @@tpl
        mov  word ptr [mvb],offset STURRVT ; a Shilka shows its TURRET, on
        mov  word ptr [mvn],STURRNV*6      ; the bearing it is really at -
        mov  word ptr [mfb],offset STURRFC ; and by its own FACES. It used to
        mov  word ptr [nfc],STURRNF        ; borrow WEDG, the aeroplane edge
        mov  word ptr [tgzo],150           ; list, which indexes vertices up
        mov  word ptr [tgyc],40            ; to the 23rd - and the drum has
        mov  bx,si                         ; EIGHT. The rest of the cache was
                                           ; last frame's aeroplane, so the
                                           ; page drew lines off into stale
                                           ; numbers: the Shilka fell apart
        sub  bx,SHKLK
        shr  bx,1
        call FAR PTR SHKTBRGF   ; its turret bearing lives out in UISEG
        jmp  @@tyaw
@@tpl:  mov  word ptr [tgzo],75
        mov  word ptr [tgyc],0
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
@@tyaw: sub  ax,[heading]
        and  ax,255
        push ax
        call FAR PTR SINQF
        mov  [msin],ax
        pop  ax
        add  ax,64
        call FAR PTR SINQF
        mov  [mcos],ax
        xor  si,si
        xor  di,di
@@tv2:  mov  bx,[mvb]
        mov  ax,[bx+si]         ; vx = (mx*mcos + mz*msin)/256
        imul word ptr [mcos]
        mov  cx,ax
        mov  bx,[mvb]
        mov  ax,[bx+si+4]
        imul word ptr [msin]
        add  ax,cx
        cwd
        mov  bx,256
        idiv bx
        mov  [dsx],ax
        mov  bx,[mvb]
        mov  ax,[bx+si]         ; vz = (mz*mcos - mx*msin)/256 + 300
        imul word ptr [msin]
        mov  cx,ax
        mov  bx,[mvb]
        mov  ax,[bx+si+4]
        imul word ptr [mcos]
        sub  ax,cx
        cwd
        mov  bx,256
        idiv bx
        add  ax,[tgzo]          ; how far the page stands off the model
        mov  [dsac],ax
        mov  ax,[dsx]           ; sx = screen centre + vx*64/vz (centre MFD)
        mov  bx,64
        imul bx
        idiv word ptr [dsac]
        add  ax,PZADICX
        mov  [PVX+di],ax
        mov  bx,[mvb]
        mov  ax,[bx+si+2]       ; sy = screen centre - vy*64/vz
        sub  ax,[tgyc]          ; a mast is modelled from its FEET up
        mov  bx,64
        imul bx
        idiv word ptr [dsac]
        mov  bx,PZADICY
        sub  bx,ax
        mov  [PVY+di],bx
        add  si,6
        add  di,2
        cmp  si,[mvn]
        jb   @@tv2
        cmp  word ptr [locki],SHKLK
        jb   @@tedg
        ; ---- the GROUND models have no edge list: walk their FACES and
        ; close each quad. Four lines a face - the MFD can afford it, and
        ; it saves carrying a second table per page. Driven off mfb/nfc,
        ; so the dish and the gun drum share the one walk; only aeroplanes
        ; still take WEDG below, and WEDG is the only table that ever fit
        ; them ----
        xor  si,si              ; face record (5 bytes)
@@tf:   xor  di,di              ; corner 0..3
@@tfc:  mov  bx,si
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
        mov  byte ptr [COLOR],95
        push si
        push di
        call FAR PTR CLIPLINF
        jc   @@tfn
        call FAR PTR LINEF
@@tfn:  pop  di
        pop  si
        inc  di
        cmp  di,4
        jb   @@tfc
        add  si,5
        mov  ax,[nfc]           ; nfc*5, the length of this face table
        mov  bx,ax
        shl  ax,1
        shl  ax,1
        add  ax,bx
        cmp  si,ax
        jb   @@tf
        ret
@@tedg: xor  si,si              ; sensor-green edges
@@te:   mov  al,[WEDG+si]
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
        mov  byte ptr [COLOR],95
        push si
        call FAR PTR CLIPLINF
        jc   @@ten
        call FAR PTR LINEF
@@ten:  pop  si
        add  si,2
        cmp  si,NWEDG*2
        jb   @@te
        ret


; ---- THE WINDOW GUARD ------------------------------------------------------
IF ($-GLIST) GT 16368
        %OUT *** UISEG overflows its 16K window before the buffer ***
        .ERR
ENDIF
        ORG  3FF0h              ; and CLAIM the window, the way SKYSEG does.
        db   16 dup(0)          ; It never had to before - it was the last
                                ; segment and the buffer simply started past
                                ; it. SYMSEG is behind us now, and the linker
                                ; will only park it at CS+1400h if we take
                                ; every paragraph we were given.

UISEG   ENDS







