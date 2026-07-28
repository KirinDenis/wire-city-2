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
MINIMAP2F PROC FAR
        call MINIMAP2
        ret
MINIMAP2F ENDP
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
        mov  ax,155
        call UROW
        add  di,144
        push ds                 ; the map lives in the far scratch segment
        mov  ax,[scrseg]
        mov  ds,ax
        xor  si,si
        mov  dx,32              ; dest rows
@@row:  mov  cx,32
@@px:   lodsb                   ; every other source column
        inc  si
        stosb
        loop @@px
        add  si,64              ; skip the odd source row
        add  di,320-32
        dec  dx
        jnz  @@row
        pop  ds
        ; the front line, half scale
        xor  cx,cx
@@bd2:  mov  bx,cx
        shr  bx,1               ; band = (col*2)/4
        add  bx,bx
        mov  ax,[bordz+bx]
        add  ax,24576+BIAS
        push cx
        mov  cl,10
        shr  ax,cl
        and  ax,63
        mov  bx,63
        sub  bx,ax
        shr  bx,1
        mov  ax,bx
        add  ax,155
        call UROW
        pop  cx
        add  di,144
        add  di,cx
        mov  al,19
        mov  es:[di],al
        inc  cx
        cmp  cx,32
        jb   @@bd2
        ; plane blip at node (camx,camz), halved
        mov  ax,[camx]
        add  ax,BIAS
        mov  cl,2
        shr  ax,cl
        mov  cl,8
        shr  ax,cl
        and  ax,63
        shr  ax,1
        mov  bx,ax              ; col/2
        mov  ax,[camz]
        add  ax,BIAS
        mov  cl,2
        shr  ax,cl
        mov  cl,8
        shr  ax,cl
        and  ax,63
        mov  dx,63
        sub  dx,ax              ; row = 63 - node z
        shr  dx,1
        mov  ax,dx
        add  ax,155
        push bx
        call UROW
        pop  bx
        add  di,144
        add  di,bx
        mov  al,8               ; white blip
        mov  es:[di],al
        ; course tick 1-2 px ahead of the blip
        mov  ax,[hsin]
        add  ax,ax              ; hsin*2 -> -2..2 screen px
        mov  bx,256
        cwd
        idiv bx
        mov  si,ax
        mov  ax,[hcos]
        add  ax,ax
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
        ret


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
        mov  [ctx],ax           ; the nominal site
        mov  word ptr [cty],-1  ; best ground so far: none
        mov  word ptr [tpi],0
@@p:    mov  ax,[tpi]
        sub  ax,4
        mov  cl,10
        shl  ax,cl              ; (k-4)*1024
        add  ax,[ctx]
        mov  [ctz],ax           ; this probe's x
        push word ptr [camx]    ; TERRH reads the camera position
        push word ptr [camz]
        mov  [camx],ax
        mov  bx,[rsi]
        add  bx,bx
        mov  ax,[rsz+bx]
        mov  [camz],ax
        call FAR PTR TERRHF
        pop  word ptr [camz]
        pop  word ptr [camx]
        cmp  ax,[cty]
        jle  @@pn
        mov  [cty],ax           ; higher ground: move the station here
        mov  bx,[rsi]
        add  bx,bx
        mov  [rsy+bx],ax
        mov  ax,[ctz]
        mov  [rsx+bx],ax
@@pn:   inc  word ptr [tpi]
        cmp  word ptr [tpi],8
        jb   @@p
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
        cmp  ax,12
        jg   @@n
        cmp  ax,-12
        jl   @@n
        mov  bx,[rcz]
        sar  bx,cl
        cmp  bx,12
        jg   @@n
        cmp  bx,-12
        jl   @@n
        add  ax,[rbcx]
        mov  [dsx],ax
        mov  ax,[rbcy]
        sub  ax,bx              ; ahead = up the screen
        call UROW
        add  di,[dsx]
        mov  al,95              ; ours green, theirs yellow - the IFF
        cmp  word ptr [rsi],0   ; language the blips already speak
        je   @@c
        mov  al,96
@@c:    mov  es:[di],al
        mov  es:[di-640],al
        mov  es:[di+640],al
        mov  es:[di-2],al
        mov  es:[di+2],al
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
@@d:    call RSRND              ; a column...
        mov  cl,3
        shr  ax,cl
        and  ax,26
        sub  ax,13
        add  ax,[rbcx]
        mov  [dsx],ax
        call RSRND              ; ...and a row
        mov  cl,3
        shr  ax,cl
        and  ax,26
        sub  ax,13
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
        sub  dx,100
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
        mov  al,96
@@c1:   cmp  byte ptr [rsst+bx],0
        je   @@c2
        mov  al,30              ; a ruin: grey, and still worth knowing
@@c2:   push ax
        add  bx,bx
        mov  ax,[rsx+bx]        ; node col/2 - MINIMAP2's own arithmetic
        add  ax,BIAS
        mov  cl,10
        shr  ax,cl
        and  ax,63
        shr  ax,1
        mov  dx,ax
        mov  ax,[rsz+bx]
        add  ax,BIAS
        mov  cl,10
        shr  ax,cl
        and  ax,63
        mov  bx,63
        sub  bx,ax              ; row = 63 - node z, halved
        shr  bx,1
        mov  ax,bx
        add  ax,155
        call UROW
        add  di,144
        add  di,dx
        pop  ax
        mov  es:[di],al
        mov  es:[di-320],al
        mov  es:[di+320],al
        mov  es:[di-1],al
        mov  es:[di+1],al
        inc  word ptr [rsi]
        cmp  word ptr [rsi],NRSTA
        jb   @@l
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
;  MAPHUM followed MINIMAP2F out here (2026-07-28, the radar stations):
;  it draws ON that map and only plots glyphs, so it belongs beside it.
;  Far door: MAPHUMF. FDRAW stayed home behind FDRAWF - the strings and
;  NB it reads are main-segment bytes and DS is the main segment here.
; ============================================================================
MAPHUMF PROC FAR
        call MAPHUM
        call RSMAP              ; ...and the two stations, on the same glass
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
        mov  ax,[pax+si]        ; node col/2 on the half-scale map
        add  ax,BIAS
        mov  cl,10
        shr  ax,cl
        and  ax,63
        shr  ax,1
        add  ax,144-1
        mov  [ftx],ax
        mov  ax,[paz+si]
        add  ax,BIAS
        mov  cl,10
        shr  ax,cl
        and  ax,63
        mov  bx,63
        sub  bx,ax
        shr  bx,1
        add  bx,155-3           ; centre the glyph rows on the node...
        cmp  bx,155
        jge  @@mhy
        mov  bx,155             ; ...but keep it inside the MFD glass
@@mhy:  cmp  bx,181
        jle  @@mhz
        mov  bx,181
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


STATPGF PROC FAR
        call STATPG
        ret
STATPGF ENDP
; ============================================================================
;  STATPG - the right (green) MFD as pure status: the war score row,
;  gun rounds, missile rails, damage pips - everything the scope used
;  to carry. ES=bufseg, DS=CS.
; ============================================================================
STATPG: mov  ax,156             ; green square: kills by our team
        call UROW
        add  di,197
        mov  al,95
        mov  es:[di],al
        mov  es:[di+1],al
        mov  es:[di+2],al
        mov  es:[di+320],al
        mov  es:[di+322],al
        mov  es:[di+640],al
        mov  es:[di+641],al
        mov  es:[di+642],al
        mov  ax,156             ; yellow diamond: kills by theirs
        call UROW
        add  di,234
        mov  al,96
        mov  es:[di+1],al
        mov  es:[di+320],al
        mov  es:[di+322],al
        mov  es:[di+641],al
        mov  byte ptr [COLOR],95
        mov  word ptr [ftx],203
        mov  word ptr [fty],156
        mov  ax,[tscf]
        call FAR PTR FNUMF
        mov  byte ptr [COLOR],8 ; own kills, centre, white
        mov  word ptr [ftx],216
        mov  word ptr [fty],156
        mov  ax,[psc]
        call FAR PTR FNUMF
        mov  byte ptr [COLOR],96
        mov  word ptr [ftx],226
        mov  word ptr [fty],156
        mov  ax,[tsch]
        call FAR PTR FNUMF
        mov  byte ptr [COLOR],97 ; cannon rounds
        mov  word ptr [ftx],197
        mov  word ptr [fty],165
        mov  si,offset MSGGUN
        call FAR PTR FDRAWF
        mov  byte ptr [COLOR],8
        mov  word ptr [ftx],215
        mov  ax,[gunam]
        call FAR PTR FNUMF
        mov  byte ptr [COLOR],97 ; missile rails: label + a pip each
        mov  word ptr [ftx],197
        mov  word ptr [fty],174
        mov  si,offset MSGMSL
        call FAR PTR FDRAWF
        xor  si,si
@@amo:  mov  ax,si
        cmp  al,[pammo]
        jae  @@amn
        mov  ax,175
        call UROW
        add  di,215
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
        mov  word ptr [ftx],197
        mov  word ptr [fty],182
        mov  si,offset MSGDAM
        call FAR PTR FDRAWF
        xor  si,si
@@dmp:  mov  ax,si
        cmp  al,[pdam]
        jae  @@dmn
        mov  ax,183
        call UROW
        add  di,215
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
        mov  word ptr [ftx],148
        mov  word ptr [fty],168
        mov  si,offset MSGNOT
        call FAR PTR FDRAWF
        ret
@@tgo:  mov  byte ptr [COLOR],19 ; the callsign wears the IFF colour
        test si,2
        jnz  @@tgc
        mov  byte ptr [COLOR],95
@@tgc:  mov  word ptr [ftx],138
        mov  word ptr [fty],156
        call FAR PTR CSDRAWF
        mov  byte ptr [COLOR],8
        mov  word ptr [ftx],138
        mov  word ptr [fty],164
        mov  si,[locki]
        call FAR PTR TYPDRAWF
        mov  byte ptr [COLOR],97 ; range: octagonal max + 3*(min/8)
        mov  word ptr [ftx],138
        mov  word ptr [fty],172
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
@@trc:  mov  word ptr [ftx],154
        mov  byte ptr [COLOR],8
        call FAR PTR FNUMKF
        mov  byte ptr [COLOR],97 ; the target's altitude
        mov  word ptr [ftx],138
        mov  word ptr [fty],180
        mov  si,offset MSGALT
        call FAR PTR FDRAWF
        mov  word ptr [ftx],156
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
        jb   @@tpl
        mov  word ptr [mvb],offset RDISHVT ; a station shows its DISH, and
        mov  word ptr [mvn],RDISHNV*6      ; it turns on the page as it
        mov  word ptr [tgzo],400           ; turns out there on the hill.
        mov  word ptr [tgyc],64            ; It is six times a jet's size:
        mov  ax,[rspin]                    ; stand further off, and centre
        jmp  @@tyaw                        ; on the hub, not on the feet
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
        mov  ax,[dsx]           ; sx = 160 + vx*64/vz (centre MFD)
        mov  bx,64
        imul bx
        idiv word ptr [dsac]
        add  ax,160
        mov  [PVX+di],ax
        mov  bx,[mvb]
        mov  ax,[bx+si+2]       ; sy = 170 - vy*64/vz
        sub  ax,[tgyc]          ; a mast is modelled from its FEET up
        mov  bx,64
        imul bx
        idiv word ptr [dsac]
        mov  bx,170
        sub  bx,ax
        mov  [PVY+di],bx
        add  si,6
        add  di,2
        cmp  si,[mvn]
        jb   @@tv2
        cmp  word ptr [locki],RSLK
        jb   @@tedg
        ; ---- the dish has no edge list: walk its FACES and close each
        ; quad. Fourteen faces, four lines apiece - the MFD can afford it,
        ; and it saves carrying a second table for one page ----
        xor  si,si              ; face record (5 bytes)
@@tf:   xor  di,di              ; corner 0..3
@@tfc:  mov  bx,si
        add  bx,di
        mov  al,[RDISHFC+bx]    ; corner k...
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
        mov  al,[RDISHFC+bx]
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
        cmp  si,RDISHNF*5
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
IF ($-GLIST) GT 8176
        %OUT *** UISEG overflows its 8K window before the buffer ***
        .ERR
ENDIF

UISEG   ENDS
