; ============================================================================
;  RTERR.ASM - KIT test: K_TERR.INC (the island).
;
;      RTERR          checks, then shows the map until Esc
;      RTERR /AUTO    the same, holds the map ~2 s, prints PASS/FAIL
;
;  The same seed twice makes the same island (a checksum of all 4096
;  bytes), another seed another; the stretch reaches 0 and 255; TER_H on a
;  node is exactly the node's height, halfway between two it lies between
;  them; the bands, WORLDH, the highest ground, the search for legal
;  ground; then the map is drawn and two of its cells read back.
; ============================================================================
        org  100h
        include '..\..\ENGINE\E_8086.INC'

macro EXPECT v, text
{
        local ..str, ..skip
        mov  [got],ax
        cmp  ax,v
        mov  si, ..str
        call RESULT
        jmp ..skip
..str     db   text,0
..skip:
}
macro CFIS v, text
{
        mov  ax,0
        adc  ax,0               ; AX = CF
        EXPECT v, text
}

start:  cld
        call GETAUTO
        mov  bx,1000h           ; the .COM keeps 64K...
        mov  ah,4Ah
        int  21h
        mov  bx,0FA0h           ; ...and asks DOS for 64000 bytes more
        mov  ah,48h
        int  21h
        jnc  .mem
        mov  dx,t_nomem
        mov  ah,9
        int  21h
        mov  ax,4C01h
        int  21h
.mem:   mov  [buf],ax

        ; ---- the same seed, the same island ----
        mov  ax,1234
        call TER_GEN
        call CSUM
        mov  [csa],ax
        mov  ax,1234
        call TER_GEN
        call CSUM
        sub  ax,[csa]
        EXPECT 0, 'TER_GEN 1234 twice: the same checksum'
        mov  ax,999
        call TER_GEN
        call CSUM
        cmp  ax,[csa]
        mov  ax,1
        je   .s1
        xor  ax,ax
.s1:    EXPECT 0, 'TER_GEN 999: a different island'
        mov  ax,1234
        call TER_GEN            ; back to the first one for the rest
        ; ---- the stretch ----
        mov  si,HMAP
        mov  cx,4096
        mov  bx,00FFh           ; BH = max, BL = min
.mm:    lodsb
        cmp  al,bl
        jae  .m1
        mov  bl,al
.m1:    cmp  al,bh
        jbe  .m2
        mov  bh,al
.m2:    loop .mm
        mov  [mmv],bx
        mov  al,bl
        xor  ah,ah
        EXPECT 0, 'the map is stretched: lowest byte 0'
        mov  al,byte [mmv+1]
        xor  ah,ah
        EXPECT 255, '...highest byte 255'

        ; ---- TER_H on the nodes ----
        mov  word [bad],0
        mov  word [k],0
.nd:    mov  ax,[k]
        mov  bx,37
        mul  bx                 ; AX = k*37: nodes spread over the map
        add  ax,5
        mov  bx,ax
        and  bx,63              ; gi
        mov  cl,3
        shr  ax,cl
        mov  dx,ax
        and  dx,63              ; gj
        mov  [gi],bx
        mov  [gj],dx
        call TER_NODEH
        mov  [hn],ax            ; the node's own height
        mov  ax,[gi]
        mov  cl,10
        shl  ax,cl
        sub  ax,TER_BIAS        ; x = gi*1024 - bias
        mov  bx,[gj]
        shl  bx,cl
        sub  bx,TER_BIAS        ; z = gj*1024 - bias
        call TER_H
        cmp  ax,[hn]
        je   .nok
        inc  word [bad]
.nok:   ; ---- halfway to the next node east: between the two ----
        mov  bx,[gi]
        inc  bx
        mov  dx,[gj]
        call TER_NODEH
        mov  [hn2],ax
        mov  ax,[gi]
        mov  cl,10
        shl  ax,cl
        sub  ax,TER_BIAS-512    ; halfway along
        mov  bx,[gj]
        shl  bx,cl
        sub  bx,TER_BIAS
        call TER_H
        mov  bx,[hn]
        mov  cx,[hn2]
        cmp  bx,cx
        jle  .o
        xchg bx,cx              ; BX = the lower, CX = the higher
.o:     cmp  ax,bx
        jl   .hb
        cmp  ax,cx
        jle  .hk
.hb:    inc  word [bad2]
.hk:    inc  word [k]
        cmp  word [k],40
        jb   .nd
        mov  ax,[bad]
        EXPECT 0, 'TER_H on 40 nodes = TER_NODEH of each'
        mov  ax,[bad2]
        EXPECT 0, 'TER_H halfway to the next node lies between the two'
        mov  ax,(63 shl 10) - TER_BIAS + 1024   ; past node 63: wraps to 0
        xor  bx,bx
        sub  bx,TER_BIAS
        call TER_H
        mov  [hn],ax
        mov  bx,0
        mov  dx,0
        call TER_NODEH
        sub  ax,[hn]
        EXPECT 0, 'TER_H past the last node wraps to node 0'

        ; ---- bands and heights ----
        mov  al,0
        call TER_BAND
        xor  ah,ah
        EXPECT 1, 'TER_BAND 0 = 1 (sea)'
        mov  al,88
        call TER_BAND
        xor  ah,ah
        EXPECT 2, 'TER_BAND 88 = 2 (sand)'
        mov  al,167
        call TER_BAND
        xor  ah,ah
        EXPECT 3, 'TER_BAND 167 = 3 (grass)'
        mov  al,199
        call TER_BAND
        xor  ah,ah
        EXPECT 4, 'TER_BAND 199 = 4 (woods)'
        mov  al,229
        call TER_BAND
        xor  ah,ah
        EXPECT 5, 'TER_BAND 229 = 5 (rock)'
        mov  al,255
        call TER_BAND
        xor  ah,ah
        EXPECT 6, 'TER_BAND 255 = 6 (snow)'
        mov  ax,87
        call TER_WH
        EXPECT 0, 'TER_WH 87 (sea) = 0'
        mov  ax,100
        call TER_WH
        EXPECT 120, 'TER_WH 100 = (100-88)*5*2 = 120'
        call TER_TOP
        EXPECT 2220, 'TER_TOP = TER_WH 255 = 2220 (the stretch reaches 255)'

        ; ---- registers kept ----
        mov  bx,3
        mov  cx,1234h
        mov  dx,4
        mov  si,4444h
        mov  di,5555h
        mov  bp,6666h
        call TER_RAW
        xor  ax,ax
        cmp  cx,1234h           ; HGET eats CL: TER_RAW must not
        jne  .k1
        cmp  bx,3
        jne  .k1
        cmp  dx,4
        jne  .k1
        mov  ax,500
        mov  bx,700
        call TER_H
        xor  ax,ax
        cmp  bx,700
        jne  .k1
        cmp  cx,1234h
        jne  .k1
        cmp  dx,4
        jne  .k1
        cmp  si,4444h
        jne  .k1
        cmp  di,5555h
        jne  .k1
        cmp  bp,6666h
        jne  .k1
        jmp  .k2
.k1:    mov  ax,1
.k2:    EXPECT 0, 'TER_RAW and TER_H keep their registers (CL too)'

        ; ---- the search for ground ----
        xor  ax,ax
        xor  bx,bx
        call TER_FINDGND
        mov  [fx],ax
        mov  [fz],bx
        mov  [hn],cx
        CFIS 0, 'TER_FINDGND near 0,0 finds ground (CF 0)'
        mov  ax,[hn]
        cmp  ax,[ter_glo]
        jb   .g1
        cmp  ax,[ter_ghi]
        ja   .g1
        mov  ax,[fx]
        mov  bx,[fz]
        call TER_H
        sub  ax,[hn]
        jmp  .g2
.g1:    mov  ax,1
.g2:    EXPECT 0, '...its height is legal and is TER_H there'
        mov  word [ter_glo],60000   ; nothing is that high
        xor  ax,ax
        xor  bx,bx
        call TER_FINDGND
        CFIS 1, 'TER_FINDGND with nothing legal: CF = 1'
        mov  word [ter_glo],1

        ; ---- the map, drawn and read back ----
        mov  ax,0013h
        int  10h
        call TER_PAL
        mov  es,[buf]
        xor  di,di
        xor  ax,ax
        mov  cx,32000
        rep  stosw
        mov  ax,64
        mov  bx,4
        mov  cx,3
        call TER_MAP
        mov  bx,0               ; node (0,63) is the top-left cell
        mov  dx,63
        call TER_RAW
        call TER_BAND
        mov  [b1],al
        mov  al,[es:4*320+64+1]
        mov  [p1],al
        mov  bx,10              ; node (10,20): where TER_MAPPT says
        mov  dx,20
        call TER_RAW
        call TER_BAND
        mov  [b2],al
        mov  ax,10*1024-TER_BIAS
        mov  bx,20*1024-TER_BIAS
        call TER_MAPPT
        mov  [mpx],ax
        mov  [mpy],bx
        mov  di,bx
        mov  ax,320
        mul  di
        add  ax,[mpx]
        mov  di,ax
        mov  al,[es:di]
        mov  [p2],al
        push ds                 ; onto the screen
        mov  ax,0A000h
        mov  es,ax
        mov  ds,[buf]
        xor  si,si
        xor  di,di
        mov  cx,32000
        rep  movsw
        pop  ds
        call TICK
        mov  [t0],ax
.hold:  cmp  byte [auto],0
        je   .key
        call TICK
        sub  ax,[t0]
        cmp  ax,36
        jb   .hold
        jmp  .end
.key:   mov  ah,0
        int  16h
        cmp  ah,1
        jne  .key
.end:   mov  ax,0003h
        int  10h
        mov  al,[p1]
        sub  al,[b1]
        xor  ah,ah
        EXPECT 0, 'TER_MAP: the top-left cell is node (0,63) by its band'
        mov  ax,[mpx]
        EXPECT 64+10*3+1, 'TER_MAPPT node 10: x = 64 + 10*3 + 1'
        mov  ax,[mpy]
        EXPECT 4+(63-20)*3+1, 'TER_MAPPT node 20: y = 4 + 43*3 + 1'
        mov  al,[p2]
        sub  al,[b2]
        xor  ah,ah
        EXPECT 0, 'TER_MAP: the pixel TER_MAPPT names is node (10,20)'
        mov  es,[buf]
        mov  ah,49h
        int  21h
        mov  ax,[fails]
        or   ax,ax
        jnz  .bad
        mov  dx,t_ok
        mov  ah,9
        int  21h
        mov  ax,4C00h
        int  21h
.bad:   mov  dx,t_bad
        mov  ah,9
        int  21h
        mov  ax,4C01h
        int  21h

; CSUM - AX = a checksum of HMAP (rotate and add, order matters)
CSUM:   mov  si,HMAP
        mov  cx,4096
        xor  bx,bx
.c:     lodsb
        xor  ah,ah
        rol  bx,1
        add  bx,ax
        loop .c
        mov  ax,bx
        ret

TICK:   push es
        xor  ax,ax
        mov  es,ax
        mov  ax,[es:046Ch]
        pop  es
        ret

GETAUTO:mov  si,81h
        xor  ch,ch
        mov  cl,[80h]           ; the tail's length
.s:     jcxz .no
        lodsb
        dec  cx
        cmp  al,'/'
        jne  .s
        cmp  cx,4
        jb   .no
        mov  ax,[si]
        and  ax,0DFDFh          ; upper case
        cmp  ax,'AU'
        jne  .s
        mov  ax,[si+2]
        and  ax,0DFDFh
        cmp  ax,'TO'
        jne  .s
        mov  byte [auto],1
.no:    ret

RESULT: jnz  .f
        mov  dx,t_pass
        jmp  .p
.f:     mov  dx,t_fail
        inc  word [fails]       ; one more failure
.p:     mov  ah,9
        int  21h
        call PUTS
        mov  dx,t_got
        mov  ah,9
        int  21h
        mov  ax,[got]
        call PUTN
        mov  dx,t_nl
        mov  ah,9
        int  21h
        ret

PUTS:   lodsb
        or   al,al
        jz   .d
        mov  dl,al
        mov  ah,2
        int  21h
        jmp  PUTS
.d:     ret

PUTN:   or   ax,ax
        jns  .p
        push ax
        mov  dl,'-'
        mov  ah,2
        int  21h
        pop  ax
        neg  ax                 ; AX = |AX|
.p:     xor  cx,cx              ; CX = digits stacked
        mov  bx,10
.d:     xor  dx,dx
        div  bx                 ; AX = AX / 10, DX = the digit (BX = 10)
        push dx
        inc  cx                 ; one more digit
        or   ax,ax
        jnz  .d
.o:     pop  dx
        add  dl,'0'             ; the digit as a character
        mov  ah,2
        int  21h
        loop .o
        ret

auto    db   0
got     dw   0
fails   dw   0
buf     dw   0
csa     dw   0
mmv     dw   0
bad     dw   0
bad2    dw   0
k       dw   0
gi      dw   0
gj      dw   0
hn      dw   0
hn2     dw   0
fx      dw   0
fz      dw   0
mpx     dw   0
mpy     dw   0
t0      dw   0
b1      db   0
b2      db   0
p1      db   0
p2      db   0
t_pass  db   'PASS $'
t_fail  db   'FAIL $'
t_got   db   '  got $'
t_nl    db   13,10,'$'
t_ok    db   'RTERR: all PASS',13,10,'$'
t_bad   db   'RTERR: FAILED',13,10,'$'
t_nomem db   'RTERR: no memory for the buffer',13,10,'$'

        include '..\..\KIT\LIB\K_TERR.INC'
