; ============================================================================
;  R_DEBRIS.ASM - recipe: a thing breaks apart - pieces thrown out and up,
;  falling under gravity, coming to rest on the ground, burning a while.
;
;  OWL FLY III's wreck, flattened to 2D: a kill claims a wreck slot (round
;  robin: the oldest wreck is the one recycled), its pieces fly radially
;  out from the centre with a random jitter and up, gravity pulls each
;  tick, and a piece that reaches the ground rests there and stops - the
;  ruin stays on the map as information (guide GAMEPLAY). While the wreck
;  is young it burns: a flicker over every piece; smoke outlasts the fire.
;  Positions 12.4 (pixels x16), speeds 16ths of a pixel a tick; up is -y.
;
;        mov  ax,[ex]            ; where it broke, pixels
;        mov  bx,[ey]
;        mov  dx,0C04h           ; its two colours (DL, DH)
;        call DEBRISAT
;        ...each tick:   call DEBRISSTEP
;        ...each frame:  call DEBRISDRAW     ; ES = the buffer, 320 a row
;
;  copy: DEBRISAT, DEBRISSTEP, DEBRISDRAW and the arrays.
;  define before: rseed dw; dbgnd dw (the ground's y, pixels - or make
;        DEBRISSTEP ask a height routine per piece: the SAME one the
;        drawing uses, guide PHYSICS)
;  needs: ENGINE\E_MATH.INC (RND16)
;  from: GAMES\OWLFLY3\SRC\PLANES.INC:1760-1943 (WRKFILL), 1972-2049
;        (WRECKUPD: fx += vx, vy -= 3, at the ground rest and stop),
;        4055-4200 (WRKAT: slabs radial out, vy 5..12 up); 3D to 2D, the
;        "a falling piece brings a building down" domino left out
; ============================================================================
NWRK    = 4                     ; wrecks at once (round robin)
NPIECE  = 8                     ; pieces a wreck
DBGRAV  = 6                     ; gravity, 16ths of a pixel a tick, a tick
DBBURN  = 160                   ; ticks it burns (OWL FLY: 600 world ticks)

; ----------------------------------------------------------------------
;@ DEBRISAT   break a thing at pixel (AX,BX) into NPIECE flying pieces
;  in:  AX = x, BX = y (pixels), DL, DH = its two colours (pieces alternate)
;  out: -  (the oldest wreck slot is reused)
; ----------------------------------------------------------------------
DEBRISAT:
        push ax
        push bx
        push cx
        push dx
        push si
        push di
        mov  cl,4
        shl  ax,cl              ; the centre x * 16
        mov  [dbcx],ax
        shl  bx,cl              ; the centre y * 16
        mov  [dbcy],bx
        mov  [dbc0],dx
        mov  di,[dbnext]        ; DI = the wreck slot * 2
        add  word [dbnext],2
        cmp  word [dbnext],NWRK*2
        jb   .s
        mov  word [dbnext],0    ; round robin: the oldest goes
.s:     mov  word [dbage+di],1  ; alive and burning
        mov  ax,di
        mov  cl,3
        shl  ax,cl              ; * NPIECE (8): the first piece's word index
        mov  si,ax
        xor  cx,cx              ; CX = the piece
.p:     call RND16
        mov  dx,ax
        and  ax,127
        sub  ax,64              ; -64..63: +-4 pixels round the centre
        mov  bx,ax
        add  ax,[dbcx]
        mov  [dbx+si],ax
        sar  bx,1               ; out from the centre: the offset / 2 ...
        mov  ax,dx
        mov  al,ah
        and  ax,15
        sub  ax,8               ; ... + a jitter -8..7
        add  ax,bx
        mov  [dbvx+si],ax
        mov  ax,dx
        and  ax,0F0h
        shr  ax,1
        shr  ax,1
        shr  ax,1
        shr  ax,1               ; 0..15
        add  ax,[dbcy]
        mov  [dby+si],ax
        call RND16
        and  ax,63              ; 0..63
        add  ax,40              ; 40..103: up and out
        neg  ax
        mov  [dbvy+si],ax
        mov  al,byte [dbc0]
        test cl,1
        jz   .c
        mov  al,byte [dbc0+1]        ; every other piece the second colour
.c:     push si
        shr  si,1
        mov  [dbcol+si],al
        pop  si
        add  si,2               ; the next piece
        inc  cx
        cmp  cx,NPIECE
        jb   .p
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret

; ----------------------------------------------------------------------
;@ DEBRISSTEP one tick of every wreck: pieces fly, fall, rest on the ground
;  in:  [dbgnd] = the ground's y in pixels
;  out: -
; ----------------------------------------------------------------------
DEBRISSTEP:
        push ax
        push bx
        push cx
        push di
        push si
        mov  bx,[dbgnd]
        mov  cl,4
        shl  bx,cl              ; BX = the ground, 12.4
        xor  di,di              ; DI = the wreck * 2
.w:     cmp  word [dbage+di],0
        je   .wn                ; no wreck in this slot
        cmp  word [dbage+di],30000
        jae  .old
        inc  word [dbage+di]    ; one tick older
.old:   mov  ax,di
        mov  cl,3
        shl  ax,cl              ; its first piece's word index
        mov  si,ax
        mov  cx,NPIECE
.p:     mov  ax,[dbvx+si]
        add  [dbx+si],ax        ; x += vx
        add  word [dbvy+si],DBGRAV   ; gravity
        mov  ax,[dbvy+si]
        add  [dby+si],ax        ; y += vy
        cmp  [dby+si],bx
        jl   .pn                ; still in the air (signed)
        mov  [dby+si],bx        ; on the ground: rest and stop
        xor  ax,ax
        mov  [dbvx+si],ax
        mov  [dbvy+si],ax
.pn:    add  si,2               ; the next piece
        loop .p
.wn:    add  di,2               ; the next wreck
        cmp  di,NWRK*2
        jb   .w
        pop  si
        pop  di
        pop  cx
        pop  bx
        pop  ax
        ret

; ----------------------------------------------------------------------
;@ DEBRISDRAW every piece a 2x2 block; a flicker of flame while it burns
;  in:  ES = the buffer (320 a row)
;  out: -
; ----------------------------------------------------------------------
DEBRISDRAW:
        push ax
        push bx
        push cx
        push dx
        push si
        push di
        xor  bx,bx              ; BX = the wreck * 2
.w:     cmp  word [dbage+bx],0
        je   .wn
        mov  ax,bx
        mov  cl,3
        shl  ax,cl
        mov  si,ax              ; its first piece
        mov  cx,NPIECE
.p:     push cx
        mov  ax,[dbx+si]
        mov  cl,4
        sar  ax,cl              ; x, pixels
        cmp  ax,318
        jae  .pn                ; off the screen (unsigned: both sides)
        mov  dx,[dby+si]
        sar  dx,cl              ; y, pixels
        cmp  dx,198
        jae  .pn
        cmp  dx,1
        jb   .pn                ; (room for the flame above)
        mov  di,dx
        mov  cl,8
        shl  di,cl              ; y*256
        mov  cl,6
        shl  dx,cl              ; y*64
        add  di,dx
        add  di,ax              ; y*320 + x
        push si
        shr  si,1
        mov  al,[dbcol+si]
        pop  si
        mov  [es:di],al
        mov  [es:di+1],al
        mov  [es:di+320],al
        mov  [es:di+321],al     ; the piece
        cmp  word [dbage+bx],DBBURN
        jae  .pn                ; burnt out
        call RND16
        test al,1
        jz   .pn                ; it flickers
        mov  byte [es:di-320],DBFIRE   ; a lick of flame above it
.pn:    pop  cx
        add  si,2
        loop .p
.wn:    add  bx,2
        cmp  bx,NWRK*2
        jb   .w
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret

DBFIRE  = 42                    ; the flame's colour (VGA default: orange)
dbnext  dw 0                    ; the next wreck slot * 2
dbcx    dw 0                    ; DEBRISAT's centre, 12.4
dbcy    dw 0
dbc0    dw 0                    ; its two colours
dbage   rw NWRK                 ; ticks since it broke, 0 = no wreck
dbx     rw NWRK*NPIECE          ; the pieces: position 12.4
dby     rw NWRK*NPIECE
dbvx    rw NWRK*NPIECE          ; speed, 16ths of a pixel a tick
dbvy    rw NWRK*NPIECE
dbcol   rb NWRK*NPIECE          ; colour
