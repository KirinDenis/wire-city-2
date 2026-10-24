; ============================================================================
;  FFONT4.ASM - KIT test: K_FONT.INC's second target, the FOUR-BITS-A-PIXEL
;  buffer of K_D4.INC / K_CARD.INC (EGA, EGA 640, CGA, Hercules).
;
;      FFONT4           checks, then the letters on the EGA (0Dh) until Esc
;      FFONT4 /AUTO     the same, the picture ~2 s, PASS/FAIL lines
;      FFONT4 /AUTO 1   the picture on card 1 (1 EGA 640, 2 EGA, 3 CGA,
;                       5 VGA 13h - one this machine has)
;      /S with either   also writes SHOT4.RAW: the 4bpp frame as it was sent
;                       (32000 bytes, or 64000 at EGA 640)
;
;  THE PROOF: one scene of every look, font, scale, ring, shadow, ramp and
;  the four edges is drawn twice - into a mode-13h byte buffer and into a
;  4bpp buffer - and every one of the 64000 pixels is compared, the 4bpp
;  nibbles read back: at 160 bytes a row (EGA, CGA, Hercules), at EGA 640's
;  320 column bytes (both nibbles the colour), and on EGA 640's fine pixels.
;  Then K_D4's own D4_GET reads letters FNT_OND4 put there, the gold ramp of
;  FNT_LTITLE is shown to turn into its 16-colour twin, the fine pixels
;  reach x 639 and never wrap, FNT_TO13 sends the letters back to ES, and
;  the registers come back.
; ============================================================================
        org  100h
        include '..\..\ENGINE\E_8086.INC'

; REC v, 'name' - AX must be v; kept, printed once text mode is back
macro REC v, text
{
        local ..s, ..k
        push bx
        mov  bx,[nrec]
        mov  [rgot+bx],ax
        mov  word [rwant+bx],v
        mov  word [rname+bx],..s
        add  word [nrec],2      ; one more record
        pop  bx
        jmp  ..k
..s     db   text,0
..k:
}

start:  cld
        call GETARGS            ; [auto], [want], [shot]
        call MEM_INIT           ; our 64K, the rest for DOS to give
        mov  bx,0FA0h           ; 64000 bytes: the mode-13h picture
        call MEM_ALLOC
        jc   NOMEM
        mov  [b13],ax
        mov  bx,0FA0h           ; 64000 bytes: the 4bpp one (EGA 640 needs all)
        call MEM_ALLOC
        jc   NOMEM
        mov  [b4],ax

; ---- the scene in mode 13h, the reference ----------------------------------
        call FNT_TO13
        mov  ax,[b13]
        mov  bl,1
        call FILL               ; deep blue: the letters must be transparent
        mov  es,[b13]
        call SCENE
        push ds
        pop  es
        mov  ax,[b13]
        call INKS               ; AX = pixels not blue
        mov  [inks],ax
        cmp  ax,4000
        mov  ax,0
        jb   .few
        inc  ax                 ; enough drawn to mean something
.few:   REC  1, 'the scene draws over 4000 pixels in mode 13h'

; ---- 1. 160 bytes a row: EGA 0Dh, CGA, Hercules ----------------------------
        mov  ax,[b4]
        mov  bl,11h
        call FILL
        mov  ax,[b4]
        xor  bx,bx
        mov  cx,160
        xor  dl,dl
        call FNT_TO4
        call SCENE
        xor  al,al
        call COMPARE            ; AX = pixels that differ
        REC  0, '160 a row: every pixel = the 13h picture (64000 compared)'
        mov  al,[fnt_target]
        xor  ah,ah
        REC  1, 'FNT_TO4 sets fnt_target 1'

; ---- 2. EGA 640, 320 column bytes ------------------------------------------
        mov  ax,[b4]
        mov  bl,11h
        call FILL
        mov  ax,[b4]
        xor  bx,bx
        mov  cx,320
        xor  dl,dl
        call FNT_TO4
        call SCENE
        mov  al,1
        call COMPARE
        REC  0, 'EGA 640 columns: every byte = 11h * the 13h colour'

; ---- 3. EGA 640, the fine pixels (the left 320 compared) -------------------
        mov  ax,[b4]
        mov  bl,11h
        call FILL
        mov  ax,[b4]
        xor  bx,bx
        mov  cx,320
        mov  dl,1
        call FNT_TO4
        mov  ax,[fnt_txmax]
        REC  639, 'FNT_TO4 fine: the last x is 639'
        call SCENE
        mov  al,2
        call COMPARE
        REC  0, 'EGA 640 fine pixels 0..319 = the 13h picture'
        mov  ax,[b4]            ; the fine pixels past 319: 'A' at x 600
        mov  bl,11h
        call FILL
        mov  byte [fnt_col],15
        mov  byte [fnt_rc],0
        mov  si,sA
        mov  bx,600
        mov  dx,30
        call FNT_HUD
        mov  si,sAB             ; and 'AB' at 636: cut at 639, never wrapped
        mov  bx,636
        mov  dx,50
        call FNT_HUD
        mov  es,[b4]
        mov  al,[es:30*320+300] ; fine x 600, 601: ring, the A's top
        xor  ah,ah
        REC  0Fh, 'fine: x 600 ring 0, x 601 the A (byte 0Fh)'
        mov  ax,[es:51*320]     ; the row under 'AB''s rows starts clean
        or   ax,[es:52*320]
        REC  1111h, 'fine: AB at x 636 never wraps to the next row'
        mov  al,[es:51*320+318] ; fine x 636, 637: the A's row 1 (X.)
        xor  ah,ah
        REC  0F0h, 'fine: AB at x 636 drawn up to the edge'
        push ds
        pop  es

; ---- 4. K_D4 reads back what FNT_OND4 drew ---------------------------------
        mov  ax,[b4]
        mov  bl,11h
        call FILL
        mov  ax,[b4]
        xor  bl,bl              ; 160 bytes a row
        call D4_INIT
        call FNT_OND4
        mov  ax,[fnt_trowb]
        REC  160, 'FNT_OND4 takes K_D4''s 160 bytes a row'
        mov  byte [fnt_col],14
        mov  byte [fnt_rc],0
        mov  si,sA
        mov  bx,20
        mov  dx,20
        call FNT_HUD            ; the A: row 0 .X. row 2 XXX
        mov  bx,21
        mov  dx,20
        call D4_GET
        xor  ah,ah
        REC  14, 'D4_GET (21,20): the A''s top, colour 14'
        mov  bx,20
        call D4_GET
        xor  ah,ah
        REC  0, 'D4_GET (20,20): its ring, 0'
        mov  bx,21
        mov  dx,19
        call D4_GET
        xor  ah,ah
        REC  0, 'D4_GET (21,19): the ring above, 0'
        mov  bx,22
        mov  dx,22
        call D4_GET
        xor  ah,ah
        REC  14, 'D4_GET (22,22): the bar of the A, 14'
        mov  bx,18
        mov  dx,20
        call D4_GET
        xor  ah,ah
        REC  1, 'D4_GET (18,20): untouched, 1'

; ---- 5. FNT_LTITLE's gold ramp becomes its 16-colour twin ------------------
        mov  ax,[b4]
        mov  bl,11h
        call FILL
        mov  al,FNT_LTITLE
        call FNT_LOOK           ; gtab = fnt_gold (256 colours)
        mov  si,sGold
        mov  bx,10
        mov  dx,10
        call FNT_PUT
        call RAMPCHK            ; AX = nibbles not in 0 1 6 14 15
        REC  0, 'LTITLE on 4bpp: only 15 14 6 (gold4), ring 0, blue 1'
        mov  ax,[seen]
        and  ax,4040h           ; bit 6 = colour 6, bit 14 = colour 14
        REC  4040h, 'LTITLE on 4bpp: gold 14 and brown 6 both there'
        mov  al,FNT_LFIRE
        call FNT_LOOK           ; gtab = fnt_fire
        mov  ax,[b4]
        mov  bl,11h
        call FILL
        mov  si,sGold
        mov  bx,10
        mov  dx,10
        call FNT_PUT
        call RAMPCHK
        mov  ax,[seen]
        and  ax,1000h           ; colour 12: fire4's red (8x16's foot is empty)
        REC  1000h, 'LFIRE on 4bpp: fire4''s red 12 there'
        mov  ax,[seen]
        and  ax,2FECh           ; anything but 0 1 4 12 14 15?
        REC  0, 'LFIRE on 4bpp: no colour outside fire4, ring, blue'

; ---- 6. registers -----------------------------------------------------------
        mov  al,FNT_LTITLE
        call FNT_LOOK
        mov  ax,1111h
        mov  bx,40
        mov  cx,3333h
        mov  dx,30
        mov  si,sGold
        mov  di,6666h
        mov  bp,7777h
        call FNT_PUT
        call REGS               ; AX = 0 if all came back (BX moves on)
        REC  0, 'FNT_PUT on 4bpp keeps AX CX DX SI DI BP ES'
        mov  ax,1111h
        mov  bx,40
        mov  cx,3333h
        mov  dx,30
        mov  si,sGold
        mov  di,6666h
        mov  bp,7777h
        call FNT_HUD
        call REGS
        REC  0, 'FNT_HUD on 4bpp keeps AX CX DX SI DI BP ES'
        mov  ax,1111h
        mov  bx,2222h
        mov  cx,3333h
        mov  dx,30
        mov  si,sGold
        mov  di,6666h
        mov  bp,7777h
        call FNT_OND4
        call REGS
        cmp  bx,2222h
        je   .k1
        inc  ax
.k1:    REC  0, 'FNT_OND4 keeps every register'

; ---- 7. FNT_TO13: back to ES ------------------------------------------------
        call FNT_TO13
        mov  ax,[b13]
        mov  bl,1
        call FILL
        mov  ax,[b4]
        mov  bl,11h
        call FILL
        mov  es,[b13]
        mov  byte [fnt_col],15
        mov  si,sA
        mov  bx,20
        mov  dx,20
        call FNT_HUD
        mov  al,[es:20*320+21]
        xor  ah,ah
        REC  15, 'FNT_TO13: the A lands in ES again (13h byte 15)'
        mov  es,[b4]
        mov  al,[es:20*160+10]
        xor  ah,ah
        REC  11h, 'FNT_TO13: the 4bpp buffer untouched'
        push ds
        pop  es

; ---- the picture: on a real 4bpp card ---------------------------------------
        call CRD_DETECT
        mov  bl,[want]          ; the card asked for, if it is here
        or   bl,bl
        jnz  .wc
        mov  bl,CRD_EGA         ; else the EGA 0Dh
.wc:    xor  bh,bh
        cmp  byte [crd_cap-1+bx],0
        je   .best
        mov  [crd_card],bl
.best:  cmp  byte [crd_card],0
        je   .nopic
        call CRD_MEM
        jc   .nopic
        mov  ax,[crd_buf]
        mov  bl,[crd_wide]
        call D4_INIT
        call FNT_OND4           ; the letters go where K_D4 draws
        call SHOWCASE
        call CRD_SET
        jc   .nopic
        call CRD_BLIT
        call SHOT
        call HOLD
        call CRD_RESET
        mov  al,[crd_card]
        xor  ah,ah
        mov  [card],ax
.nopic: call PRINTREC
        mov  ax,4C00h
        int  21h

NOMEM:  mov  dx,mnomem
        mov  ah,9
        int  21h
        mov  ax,4C01h
        int  21h

; ----------------------------------------------------------------------------
; SCENE - every look, the ramps in colours 0..15 (the same on both targets),
; letters off all four edges. Draws into the current target (ES for 13h).
SCENE:  push ax
        push bx
        push cx
        push dx
        push si
        mov  al,FNT_LTITLE      ; 8x8 x4 smooth, proportional, ring 2 + shadow
        call FNT_LOOK
        mov  word [fnt_gtab],r16
        mov  byte [fnt_gn],R16N
        mov  si,sTitle
        mov  bx,8
        mov  dx,4
        call FNT_PUT
        mov  al,FNT_LSUB        ; 8x8 x2 smooth, ringed
        call FNT_LOOK
        mov  byte [fnt_col],11
        mov  si,sSub
        mov  bx,8
        mov  dx,44
        call FNT_PUT
        mov  al,FNT_LMENU       ; 8x16 shadowed
        call FNT_LOOK
        mov  si,sMenu
        mov  bx,8
        mov  dx,64
        call FNT_PUT
        mov  al,FNT_LSCORE      ; bold digits, ringed
        call FNT_LOOK
        mov  ax,120
        mov  cl,5
        mov  bx,230
        mov  dx,68
        call FNT_NUMZ
        mov  al,FNT_LBIG        ; 4x6 x3 blocks, ring + shadow
        call FNT_LOOK
        mov  si,sBig
        mov  bx,8
        mov  dx,88
        call FNT_PUT
        mov  al,FNT_LFIRE       ; 8x16 x2 smooth, a ramp, ring 2 + shadow
        call FNT_LOOK
        mov  word [fnt_gtab],r16b
        mov  byte [fnt_gn],R16BN
        mov  si,sFire
        mov  bx,150
        mov  dx,84
        call FNT_PUT
        mov  al,FNT_LBODY       ; 8x8 x3 smooth (Scale3x), ringed
        call FNT_LOOK
        mov  byte [fnt_scale],3
        mov  byte [fnt_smooth],1
        mov  byte [fnt_style],FNT_RING
        mov  byte [fnt_col],10
        mov  si,sX3
        mov  bx,262
        mov  dx,120
        call FNT_PUT
        mov  al,FNT_LBODY       ; 8x8 plain-shadowed
        call FNT_LOOK
        mov  si,sBody
        mov  bx,8
        mov  dx,124
        call FNT_PUT
        mov  byte [fnt_col],15  ; FNT_HUD, the fast 4x6
        mov  byte [fnt_rc],0
        mov  si,sHud
        mov  bx,8
        mov  dx,140
        call FNT_HUD
        mov  al,FNT_LSUB        ; ---- the four edges
        call FNT_LOOK
        mov  byte [fnt_col],14
        mov  si,sEdge
        mov  bx,296
        mov  dx,150
        call FNT_PUT            ; off the right
        mov  bx,-10
        mov  dx,150
        call FNT_PUT            ; off the left
        mov  bx,120
        mov  dx,193
        call FNT_PUT            ; off the bottom
        mov  bx,120
        mov  dx,-6
        call FNT_PUT            ; off the top
        mov  byte [fnt_col],15
        mov  byte [fnt_rc],4
        mov  si,sClip
        mov  bx,310
        mov  dx,180
        call FNT_HUD            ; the fast one off the right,
        mov  bx,-2
        mov  dx,196
        call FNT_HUD            ;  the left and the bottom,
        mov  bx,150
        mov  dx,-3
        call FNT_HUD            ;  and the top
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret

; SHOWCASE - the picture for the card: bands, the title card's looks
SHOWCASE:
        push ax
        push bx
        push cx
        push dx
        push si
        xor  ax,ax              ; the sky: blue, then teal, then green
        mov  dx,70
        mov  bl,9
        call D4_ROWS
        mov  ax,70
        mov  dx,130
        mov  bl,3
        call D4_ROWS
        mov  ax,130
        mov  dx,200
        mov  bl,2
        call D4_ROWS
        mov  al,FNT_LTITLE      ; the name, gold (the 16-colour twin by itself)
        call FNT_LOOK
        mov  si,sName
        mov  bx,160
        mov  dx,14
        call FNT_CENTER
        mov  al,FNT_LSUB
        call FNT_LOOK
        mov  si,sSub2
        mov  bx,160
        mov  dx,54
        call FNT_CENTER
        mov  al,FNT_LMENU
        call FNT_LOOK
        mov  byte [fnt_style],FNT_RING
        mov  si,sMenu1
        mov  bx,40
        mov  dx,80
        call FNT_PUT
        mov  byte [fnt_col],14
        mov  si,sMenu2
        mov  bx,40
        mov  dx,98
        call FNT_PUT
        mov  al,FNT_LFIRE
        call FNT_LOOK
        mov  si,sFire
        mov  bx,180
        mov  dx,82
        call FNT_PUT
        mov  al,FNT_LBIG
        call FNT_LOOK
        mov  si,sBig
        mov  bx,20
        mov  dx,140
        call FNT_PUT
        mov  al,FNT_LSCORE
        call FNT_LOOK
        mov  ax,4520
        mov  cl,5
        mov  bx,240
        mov  dx,142
        call FNT_NUMZ
        mov  byte [fnt_col],15
        mov  byte [fnt_rc],0
        mov  si,sHud
        mov  bx,8
        mov  dx,170
        call FNT_HUD
        mov  si,sHud2
        mov  bx,8
        mov  dx,184
        call FNT_HUD
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret

; FILL - all 64000 bytes of segment AX with BL
FILL:   push ax
        push cx
        push di
        push es
        mov  es,ax
        xor  di,di
        mov  al,bl
        mov  ah,bl
        mov  cx,32000
        rep  stosw
        pop  es
        pop  di
        pop  cx
        pop  ax
        ret

; INKS - AX = bytes of segment AX that are not 1
INKS:   push cx
        push si
        push ds
        mov  ds,ax
        xor  si,si
        xor  ax,ax              ; AX = the count
        mov  cx,64000
.l:     cmp  byte [si],1
        je   .n
        inc  ax                 ; one more ink pixel
.n:     inc  si
        loop .l
        pop  ds
        pop  si
        pop  cx
        ret

; COMPARE - AX = pixels where [b4] differs from [b13]; AL = 0 160 a row,
; 1 EGA 640 column bytes (both nibbles), 2 EGA 640 fine pixels 0..319
COMPARE:push bx
        push cx
        push dx
        push si
        push di
        push bp
        push ds
        push es
        mov  ah,al              ; AH = the layout
        mov  es,[b4]
        mov  ds,[b13]           ; (our variables unreachable until popped)
        xor  si,si              ; SI = the 13h pixel
        xor  bp,bp              ; BP = how many differ
        xor  dx,dx              ; DX = y
.y:     xor  bx,bx              ; BX = x
        mov  di,dx              ; DI = this row's start in the 4bpp buffer:
        mov  cl,5
        shl  di,cl              ;  y * 32
        mov  cx,di
        shl  di,1
        shl  di,1               ;  y * 128
        add  di,cx              ;  y * 160
        cmp  ah,0
        je   .x
        add  di,di              ;  y * 320 (EGA 640)
.x:     mov  al,[si]            ; AL = the 13h colour
        cmp  ah,1
        je   .col
        push bx
        shr  bx,1               ; the byte: x / 2
        mov  cl,[es:di+bx]
        pop  bx
        test bl,1
        jnz  .odd
        shr  cl,1
        shr  cl,1
        shr  cl,1
        shr  cl,1               ; even x: the high nibble
.odd:   and  cl,0Fh
        cmp  cl,al
        je   .ok
        inc  bp                 ; differs
        jmp  .ok
.col:   mov  cl,[es:di+bx]      ; EGA 640: the column's byte
        mov  ch,al
        shl  ch,1
        shl  ch,1
        shl  ch,1
        shl  ch,1               ; the colour in the high nibble
        or   ch,al              ;  and the low
        cmp  cl,ch
        je   .ok
        inc  bp                 ; differs
.ok:    inc  si
        inc  bx                 ; x++
        cmp  bx,320
        jb   .x
        inc  dx                 ; y++
        cmp  dx,200
        jb   .y
        mov  ax,bp
        pop  es
        pop  ds
        pop  bp
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        ret

; RAMPCHK - the 160-a-row [b4], rows 0..63: AX = nibbles not 0 1 6 14 15
; (gold4, the ring, the blue); [seen] bit c = colour c was there
RAMPCHK:push bx
        push cx
        push si
        push es
        mov  es,[b4]
        xor  si,si
        xor  ax,ax              ; AX = the bad ones
        mov  word [seen],0
        mov  cx,64*160
.l:     mov  bl,[es:si]
        push cx
        mov  cl,4
        shr  bl,cl              ; the left pixel
        call .one
        mov  bl,[es:si]
        and  bl,0Fh             ; the right
        call .one
        pop  cx
        inc  si
        loop .l
        pop  es
        pop  si
        pop  cx
        pop  bx
        ret
.one:   push bx
        push cx
        mov  cl,bl
        mov  bx,1
        shl  bx,cl              ; BX = the colour's bit
        or   [seen],bx
        test bx,1100000001000011b ; 15 14 6 1 0 are allowed
        jnz  .ok
        inc  ax                 ; one not in the ramp
.ok:    pop  cx
        pop  bx
        ret

; REGS - after a call set up with AX 1111 CX 3333 DX 30 SI sGold DI 6666 BP 7777:
; AX = how many did not come back (ES = DS counted too); BX is the caller's
REGS:   push bx
        mov  bx,0
        cmp  dx,30
        je   .dd
        inc  bx
.dd:    cmp  si,sGold
        je   .ss
        inc  bx
.ss:    cmp  ax,1111h
        je   .a
        inc  bx
.a:     cmp  cx,3333h
        je   .c
        inc  bx
.c:     cmp  di,6666h
        je   .d
        inc  bx
.d:     cmp  bp,7777h
        je   .e
        inc  bx
.e:     push ax
        mov  ax,es
        push cx
        mov  cx,ds
        cmp  ax,cx
        pop  cx
        pop  ax
        je   .f
        inc  bx
.f:     mov  ax,bx              ; AX = how many did not come back
        pop  bx
        ret

; SHOT - under /S: the 4bpp frame into SHOT4.RAW
SHOT:   cmp  byte [shot],0
        je   .r
        push ax
        push bx
        push cx
        push dx
        push ds
        mov  dx,fShot
        xor  cx,cx
        mov  ah,3Ch
        int  21h                ; create SHOT4.RAW
        jc   .x
        mov  bx,ax
        mov  cx,32000
        cmp  byte [crd_wide],0
        je   .n
        mov  cx,64000           ; EGA 640: 320 bytes a row
.n:     mov  ds,[crd_buf]
        xor  dx,dx
        mov  ah,40h
        int  21h
        pop  ds
        push ds
        mov  ah,3Eh
        int  21h
.x:     pop  ds
        pop  dx
        pop  cx
        pop  bx
        pop  ax
.r:     ret

; HOLD - /AUTO: about 2 s by the BIOS tick; else until Esc
HOLD:   push ax
        push cx
        push es
        cmp  byte [auto],0
        jne  .tick
.key:   xor  ah,ah
        int  16h
        cmp  al,27
        jne  .key
        jmp  .out
.tick:  xor  ax,ax
        mov  es,ax
        mov  cx,36              ; ticks: 2 s
.t:     mov  ax,[es:046Ch]
.w:     cmp  ax,[es:046Ch]
        je   .w                 ; the next tick
        loop .t
.out:   pop  es
        pop  cx
        pop  ax
        ret

; GETARGS - /AUTO: [auto] = 1, a digit after it: [want]; /S: [shot] = 1
GETARGS:mov  si,81h
        mov  cl,[80h]
        xor  ch,ch
.s:     jcxz .no
        lodsb
        dec  cx
        cmp  al,'/'
        jne  .dig
        jcxz .no
        mov  al,[si]
        and  al,0DFh            ; capital
        cmp  al,'A'
        jne  .sh
        mov  byte [auto],1
.sh:    cmp  al,'S'
        jne  .s
        mov  byte [shot],1
        jmp  .s
.dig:   cmp  al,'1'
        jb   .s
        cmp  al,'5'
        ja   .s
        sub  al,'0'             ; the card's number
        mov  [want],al
        jmp  .s
.no:    ret

; PRINTREC - every record: PASS/FAIL name got N; then ALL PASS or not
PRINTREC:
        xor  bx,bx
        mov  byte [allok],1
.r:     cmp  bx,[nrec]
        jae  .end
        mov  ax,[rgot+bx]
        mov  dx,mpass
        cmp  ax,[rwant+bx]
        je   .p
        mov  dx,mfail
        mov  byte [allok],0
.p:     mov  ah,9
        int  21h
        mov  si,[rname+bx]
        call PSTR
        mov  dx,mgot
        mov  ah,9
        int  21h
        mov  ax,[rgot+bx]
        call PNUM
        mov  dx,crlf
        mov  ah,9
        int  21h
        add  bx,2               ; the next record
        jmp  .r
.end:   mov  dx,mcard
        mov  ah,9
        int  21h
        mov  ax,[card]
        call PNUM
        mov  dx,minks
        mov  ah,9
        int  21h
        mov  ax,[inks]
        call PNUM
        mov  dx,crlf
        mov  ah,9
        int  21h
        mov  dx,mall
        cmp  byte [allok],0
        jne  .a
        mov  dx,mnot
.a:     mov  ah,9
        int  21h
        ret
; PSTR - the zero-ended string SI to DOS
PSTR:   lodsb
        or   al,al
        jz   .e
        mov  dl,al
        mov  ah,2
        int  21h
        jmp  PSTR
.e:     ret
; PNUM - AX unsigned in decimal to DOS
PNUM:   push bx
        xor  cx,cx
        mov  bx,10
.d:     xor  dx,dx
        div  bx                 ; AX = /10, DX = the digit (BX = 10)
        push dx
        inc  cx                 ; one more digit
        or   ax,ax
        jnz  .d
.o:     pop  dx
        add  dl,'0'
        mov  ah,2
        int  21h
        loop .o
        pop  bx
        ret

R16N    = 6
r16     db 15,14,14,12,4,4      ; a ramp in 16 colours, the same on both targets
R16BN   = 5
r16b    db 15,11,9,9,1
auto    db 0
shot    db 0
want    db 0
allok   db 0
b13     dw 0
b4      dw 0
inks    dw 0
seen    dw 0
card    dw 0
nrec    dw 0
sA      db 'A',0
sAB     db 'AB',0
sGold   db 'GOLD',0
sTitle  db 'Owl 4bpp',0
sSub    db 'Smooth x2 ringed',0
sMenu   db '8x16 menu, shadow',0
sBig    db 'UBIG X3',0
sFire   db 'Fire',0
sX3     db 'x3',0
sBody   db '8x8 body text',0
sHud    db 'FNT_HUD 4X6 RINGED, FAST: SCORE 120  HI 4520',0
sHud2   db 'EVERY FONT, SCALE AND RING ON EGA, CGA AND HERCULES',0
sEdge   db 'EDGE',0
sClip   db 'CLIP',0
sName   db 'EGA Fonts',0
sSub2   db '16 colours, ringed',0
sMenu1  db '1  New game',0
sMenu2  db '2  Options',0
fShot   db 'SHOT4.RAW',0
mnomem  db 'FFONT4: DOS has no 2 x 64000 bytes.',13,10,'$'
mpass   db 'PASS $'
mfail   db 'FAIL $'
mgot    db '  got $'
mcard   db 'the picture went to card $'
minks   db ', the scene has ink pixels: $'
mall    db 'FFONT4: ALL PASS',13,10,'$'
mnot    db 'FFONT4: SOME FAILED',13,10,'$'
crlf    db 13,10,'$'
rgot    rw 40
rwant   rw 40
rname   rw 40

        include '..\..\KIT\LIB\K_MEM.INC'
        include '..\..\KIT\LIB\K_FONT.INC'
        include '..\..\KIT\LIB\K_D4.INC'
        include '..\..\KIT\LIB\K_CARD.INC'
