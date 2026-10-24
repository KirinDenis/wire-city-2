; ED4.ASM - test of KIT\LIB\K_D4.INC: every routine draws into a 4bpp
; buffer in RAM (no card needed), the nibbles are read back. Narrow
; (160 bytes a row) first, then EGA 640's wide layout (320).
        org  100h
        include '..\..\ENGINE\E_8086.INC'

; REC v, 'name' - AX must be v; a PASS/FAIL line at the end
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
; KEEPS fn, 'name' - fn (BX, DX, AL given by the caller in bx_, dx_, al_)
; must keep AX BX CX DX SI DI BP ES
macro KEEPS fn, text
{
        local ..bad, ..done
        mov  ax,[k_ax]
        mov  bx,[k_bx]
        mov  cx,[k_cx]
        mov  dx,[k_dx]
        mov  si,[k_si]
        mov  di,6666h
        mov  bp,7777h
        push ds
        pop  es
        call fn
        cmp  ax,[k_ax]
        jne  ..bad
        cmp  bx,[k_bx]
        jne  ..bad
        cmp  cx,[k_cx]
        jne  ..bad
        cmp  dx,[k_dx]
        jne  ..bad
        cmp  si,[k_si]
        jne  ..bad
        cmp  di,6666h
        jne  ..bad
        cmp  bp,7777h
        jne  ..bad
        mov  ax,es
        mov  bx,ds
        cmp  ax,bx
        jne  ..bad
        xor  ax,ax
        jmp  ..done
..bad:  mov  ax,1
..done: REC  0, text
}
; KSET ax, bx, cx, dx, si - the registers KEEPS hands in
macro KSET a, b, c, d, s
{
        mov  word [k_ax],a
        mov  word [k_bx],b
        mov  word [k_cx],c
        mov  word [k_dx],d
        mov  word [k_si],s
}
; PEEK off - AX = the frame's byte at offset off
macro PEEK off
{
        push es
        mov  es,[frame]
        mov  al,[es:off]
        xor  ah,ah
        pop  es
}

start:  push cs
        pop  es
        mov  bx,1000h           ; DOS: our block down to 64K...
        mov  ah,4Ah
        int  21h
        mov  bx,0FA0h           ; ...then a frame and a background
        mov  ah,48h
        int  21h
        jc   .nomem
        mov  [frame],ax
        mov  bx,0FA0h
        mov  ah,48h
        int  21h
        jnc  .mem
.nomem: mov  dx,mnomem
        mov  ah,9
        int  21h
        mov  ax,4C01h
        int  21h
.mem:   mov  [back],ax

; ---- narrow ---------------------------------------------------------------
        mov  ax,[frame]
        mov  bl,0
        call D4_INIT
        mov  ax,[d4_rowtab+200]
        REC  16000, 'D4_INIT rowtab[100] = 16000'
        mov  ax,[d4_rowb]
        REC  160, 'D4_INIT narrow: 160 bytes a row'
        mov  al,[d4_dimtab+0AFh]
        xor  ah,ah
        REC  27h, 'D4_INIT dimtab: AF -> 27'
        xor  ax,ax
        mov  dx,200
        mov  bl,0
        call D4_ROWS            ; all black
        mov  ax,198
        mov  dx,500             ; past the end: clamped
        mov  bl,6
        call D4_ROWS
        PEEK 199*160+159
        REC  66h, 'D4_ROWS rows 198..(clamped) colour 6'
        PEEK 197*160+159
        REC  0, 'D4_ROWS row 197 untouched'
        mov  ax,50
        mov  dx,40              ; backwards: nothing
        mov  bl,9
        call D4_ROWS
        PEEK 45*160
        REC  0, 'D4_ROWS backwards draws nothing'

        mov  al,9
        mov  bx,5
        mov  dx,3
        call D4_PSET
        mov  al,0Ch
        mov  bx,4
        call D4_PSET
        PEEK 3*160+2
        REC  0C9h, 'D4_PSET x 4 = C (high), x 5 = 9 (low)'
        mov  bx,5
        mov  dx,3
        call D4_GET
        xor  ah,ah
        REC  9, 'D4_GET (5,3) = 9'
        KSET 0Eh, -1, 3333h, 3, 5555h
        KEEPS D4_PSET, 'D4_PSET off the left keeps registers'
        KSET 0Eh, 10, 3333h, 200, 5555h
        KEEPS D4_PSET, 'D4_PSET below the bottom keeps registers'
        PEEK 2*160+159
        REC  0, 'D4_PSET off the left wrote nothing'
        KSET 7, 10, 4, 10, 2
        KEEPS D4_FILL, 'D4_FILL keeps registers'
        PEEK 10*160+5
        REC  77h, 'D4_FILL box x 10 w 4: byte 5'
        PEEK 11*160+6
        REC  77h, 'D4_FILL box: row 11 byte 6'
        PEEK 11*160+7
        REC  0, 'D4_FILL box: byte 7 untouched'
        PEEK 12*160+5
        REC  0, 'D4_FILL box: row 12 untouched'
        mov  al,0Ah
        mov  bx,-4
        mov  dx,14
        mov  cx,8
        mov  si,1
        call D4_FILL            ; half off the left
        PEEK 14*160+1
        REC  0AAh, 'D4_FILL clipped left: byte 1 filled'
        PEEK 13*160+159
        REC  0, 'D4_FILL clipped left: nothing before the row'

        mov  ax,15              ; a backdrop for the pictures
        mov  dx,30
        mov  bl,0Eh
        call D4_ROWS
        mov  si,PICH            ; 4x2, one see-through pixel
        mov  di,comp
        call D4_COMP
        mov  ax,di
        sub  ax,comp
        REC  10, 'D4_COMP holed 4x2: 2 + 8 bytes'
        mov  ax,si
        sub  ax,PICH
        REC  10, 'D4_COMP SI past the picture (2 + 8)'
        mov  ax,word [comp]
        REC  0202h, 'D4_COMP header: 2 rows, 2 bytes'
        mov  ax,cs
        mov  si,comp
        mov  bx,20
        mov  dx,20
        call D4_SPR
        PEEK 20*160+10
        REC  1Eh, 'D4_SPR see-through keeps the backdrop: 1E'
        PEEK 20*160+11
        REC  23h, 'D4_SPR row 0 byte 1: 23'
        PEEK 21*160+10
        REC  45h, 'D4_SPR row 1 byte 0: 45'
        mov  ax,cs
        mov  si,comp
        mov  bx,-2              ; half off the left
        mov  dx,24
        call D4_SPR
        PEEK 24*160
        REC  23h, 'D4_SPR clipped left: byte 1 at column 0'
        PEEK 23*160+159
        REC  0EEh, 'D4_SPR clipped left: the row before untouched'
        mov  word [d4_clipt],27
        mov  ax,cs
        mov  si,comp
        mov  bx,0
        mov  dx,26              ; row 26 clipped away, 27 drawn
        call D4_SPR
        mov  word [d4_clipt],0
        PEEK 26*160
        REC  0EEh, 'D4_SPR d4_clipt: the row above it skipped'
        PEEK 27*160
        REC  45h, 'D4_SPR d4_clipt: the row below drawn'
        mov  ax,cs
        mov  si,comp
        mov  [k_ax],ax
        KSET cs, 100, 3333h, 180, comp
        KEEPS D4_SPR, 'D4_SPR keeps registers'
        mov  si,PICS            ; solid 2x2
        mov  di,comp
        call D4_COMP
        mov  ax,word [comp]
        REC  8102h, 'D4_COMP solid: 2 rows, 1 byte + 80h'
        mov  ax,di
        sub  ax,comp
        REC  4, 'D4_COMP solid 2x2: 2 + 2 bytes'
        mov  ax,cs
        mov  si,comp
        mov  bx,30
        mov  dx,16
        call D4_SPR
        PEEK 17*160+15
        REC  34h, 'D4_SPR solid row 1: 34'
        mov  si,PICT            ; 2x1 "1." doubled
        mov  di,comp
        call D4_COMP2
        mov  ax,word [comp]
        REC  0202h, 'D4_COMP2 1x: 2 rows, 2 bytes'
        mov  ax,cs
        mov  si,comp
        mov  bx,40
        mov  dx,18
        call D4_SPR
        PEEK 19*160+20
        REC  11h, 'D4_COMP2 doubled pixel, second row'
        PEEK 19*160+21
        REC  0EEh, 'D4_COMP2 see-through pixel kept'
        mov  al,[d4_look]
        mov  byte [d4_look],5   ; 'S' = 5
        mov  si,PICL
        mov  di,comp
        call D4_COMP
        mov  [d4_look],al
        mov  al,[comp+2]        ; the first ink (solid)
        xor  ah,ah
        REC  5Ah, 'D4_COMP the look: S = d4_look'

        mov  ax,40              ; D4_DIM: a row of AF
        mov  dx,41
        mov  bl,0Fh
        call D4_ROWS
        mov  al,0Ah
        mov  bx,1
        mov  dx,40
        call D4_PSET            ; F A F F ...
        mov  bx,40
        mov  dx,41
        call D4_DIM
        PEEK 40*160
        REC  72h, 'D4_DIM F A -> 7 2'
        PEEK 41*160
        REC  0, 'D4_DIM stops at DX'

        push es                 ; the background: colour 3 all over
        mov  es,[back]
        xor  di,di
        mov  ax,3333h
        mov  cx,16000
        rep  stosw
        pop  es
        mov  ax,[back]
        mov  bx,50
        mov  dx,52
        call D4_COPYBG
        PEEK 51*160+159
        REC  33h, 'D4_COPYBG row 51 copied'
        PEEK 52*160
        REC  0, 'D4_COPYBG row 52 not'

        mov  word [d4_tx],60
        mov  word [d4_ty],60
        mov  byte [d4_tclr],0Fh
        mov  si,TXT1
        call D4_PRINT4
        mov  ax,si
        sub  ax,TXT1
        REC  2, 'D4_PRINT4 SI past the zero'
        mov  ax,[d4_tx]
        REC  64, 'D4_PRINT4 tx on by 4'
        mov  bx,61
        mov  dx,60
        call D4_GET
        xor  ah,ah
        REC  0Fh, 'D4_PRINT4 "1": (61,60) lit'
        mov  bx,60
        call D4_GET
        xor  ah,ah
        REC  0, 'D4_PRINT4 "1": (60,60) dark'
        mov  bx,62
        mov  dx,64
        call D4_GET
        xor  ah,ah
        REC  0Fh, 'D4_PRINT4 "1": (62,64) lit'
        mov  ax,7
        mov  cl,3
        call D4_NUM
        mov  ax,[d4_tx]
        REC  76, 'D4_NUM 7, 3 digits: 007'
        mov  bx,65
        mov  dx,62
        call D4_GET             ; '0''s middle row: 1 0 1
        xor  ah,ah
        REC  0, 'D4_NUM first digit 0: its middle hollow'
        mov  ax,-5
        mov  cl,1
        call D4_SNUM
        mov  ax,[d4_tx]
        REC  84, 'D4_SNUM -5: two letters'
        mov  word [d4_tx],100
        mov  word [d4_ty],100
        mov  si,TXT8
        call D4_PRINT8
        mov  ax,[d4_tx]
        REC  108, 'D4_PRINT8 tx on by 8'
        xor  cx,cx              ; the lit pixels in the 8x8 cell
        mov  dx,100
.cy:    mov  bx,100
.cx:    call D4_GET
        or   al,al
        jz   .cn
        inc  cx                 ; one lit
.cn:    inc  bx
        cmp  bx,108
        jb   .cx
        inc  dx
        cmp  dx,108
        jb   .cy
        mov  ax,1
        cmp  cx,8               ; a letter has more than eight
        ja   .lit
        xor  ax,ax
.lit:   REC  1, 'D4_PRINT8 "A" from the BIOS font: lit pixels'
        mov  ax,cx
        mov  [alit],ax
        mov  si,TXT8
        mov  dx,150
        call D4_BANNER
        mov  bx,153             ; inside the box, left of the letter
        mov  dx,148
        call D4_GET
        xor  ah,ah
        mov  [bancol],ax
        REC  1, 'D4_BANNER box colour 1 (centred)'

; ---- wide (EGA 640) -------------------------------------------------------
        mov  ax,[frame]
        mov  bl,1
        call D4_INIT
        mov  ax,[d4_rowb]
        REC  320, 'D4_INIT wide: 320 bytes a row'
        xor  ax,ax
        mov  dx,200
        mov  bl,0
        call D4_ROWS
        PEEK 199*320+319
        REC  0, 'D4_ROWS wide: the last byte'
        mov  al,9
        mov  bx,5
        mov  dx,3
        call D4_PSET
        PEEK 3*320+5
        REC  99h, 'D4_PSET wide: the column byte, both halves'
        mov  al,4
        mov  bx,11
        call D4_PSETF
        PEEK 3*320+5
        REC  94h, 'D4_PSETF wide: fine x 11 = byte 5 low'
        mov  si,PICT
        mov  di,comp
        call D4_COMP
        mov  ax,word [comp+2]   ; the first pixel: mask 0, ink 11h
        REC  1100h, 'D4_COMP wide: a byte a pixel, 11h'
        mov  ax,word [comp+4]
        REC  00FFh, 'D4_COMP wide: see-through keeps the byte'
        mov  al,0Eh
        mov  bx,10
        mov  dx,10
        mov  cx,3
        mov  si,1
        call D4_FILL
        PEEK 10*320+12
        REC  0EEh, 'D4_FILL wide: 3 columns = 3 bytes'
        PEEK 10*320+13
        REC  0, 'D4_FILL wide: the 4th untouched'

        call PRINTREC
        mov  ax,4C00h
        int  21h

PICH    db 4,2, '1.23'
        db      '4567'
PICS    db 2,2, '12'
        db      '34'
PICT    db 2,1, '1.'
PICL    db 2,1, 'SA'
TXT1    db '1',0
TXT8    db 'A',0

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
.end:   mov  dx,mall
        cmp  byte [allok],0
        jne  .a
        mov  dx,mnot
.a:     mov  ah,9
        int  21h
        ret
PSTR:   lodsb
        or   al,al
        jz   .e
        mov  dl,al
        mov  ah,2
        int  21h
        jmp  PSTR
.e:     ret
PNUM:   push bx
        or   ax,ax
        jns  .p
        push ax
        mov  dl,'-'
        mov  ah,2
        int  21h
        pop  ax
        neg  ax                 ; its size
.p:     xor  cx,cx
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

allok   db 0
frame   dw 0
back    dw 0
alit    dw 0
bancol  dw 0
k_ax    dw 0
k_bx    dw 0
k_cx    dw 0
k_dx    dw 0
k_si    dw 0
nrec    dw 0
mnomem  db 'FAIL no memory for the buffers',13,10,'$'
mpass   db 'PASS $'
mfail   db 'FAIL $'
mgot    db '  got $'
mall    db 'ALL PASS',13,10,'$'
mnot    db 'SOME FAILED',13,10,'$'
crlf    db 13,10,'$'
comp    rb 64
rgot    rw 80
rwant   rw 80
rname   rw 80

        include '..\..\KIT\LIB\K_D4.INC'
