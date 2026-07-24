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
;  UISEG lives at CS+1200h in an 8K window (the buffer moved to
;  CS+1400h to make room); SKYSEG is PADDED to its full 8K so the
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
        add  ax,2200            ; the wingmen hang back
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

; ---- THE WINDOW GUARD ------------------------------------------------------
IF ($-GLIST) GT 8176
        %OUT *** UISEG overflows its 8K window before the buffer ***
        .ERR
ENDIF

UISEG   ENDS
