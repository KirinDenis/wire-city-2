; CVGA.ASM - test of KIT\LIB\K_VGA.INC: mode 13h and the buffer, the
; retrace, every palette routine read back from the DAC; bars cycling for
; 1.5 s, a fade to black, text mode back, then the PASS lines.
        org  100h
        include '..\..\ENGINE\E_8086.INC'

; EXPECT v, 'name' - AX must be v: a PASS/FAIL line with what AX was
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
; KEEPS fn, axin, 'name' - fn called with AX = axin must keep BX CX DX SI
; DI BP ES and AX too (for a routine with no answer)
macro KEEPS fn, axin, text
{
        local ..bad, ..done
        mov  ax,axin
        mov  [kax],ax
        mov  ax,[kax]
        mov  bx,0FA0h
        mov  cx,2222h
        mov  dx,3333h
        mov  si,4444h
        mov  di,5555h
        mov  bp,6666h
        push ds
        pop  es
        call fn
        cmp  ax,[kax]
        jne ..bad
        cmp  bx,0FA0h
        jne ..bad
        cmp  cx,2222h
        jne ..bad
        cmp  dx,3333h
        jne ..bad
        cmp  si,4444h
        jne ..bad
        cmp  di,5555h
        jne ..bad
        cmp  bp,6666h
        jne ..bad
        mov  ax,es
        mov  bx,ds
        cmp  ax,bx
        jne ..bad
        xor  ax,ax
        jmp ..done
..bad:    mov  ax,1
..done:   EXPECT 0, text
}

; REC v, 'name' - like EXPECT, but kept for later: in mode 13h nothing is
; printed; PRINTREC prints them all once the text mode is back
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
; SAME fn, 'name' - fn (inputs already set) must keep AX BX CX DX SI DI
; BP ES: a record 0 if it did
macro SAME fn, text
{
        local ..bad, ..done
        mov  [sv],ax
        mov  [sv+2],bx
        mov  [sv+4],cx
        mov  [sv+6],dx
        mov  [sv+8],si
        mov  [sv+10],di
        mov  [sv+12],bp
        mov  [sv+14],es
        call fn
        cmp  ax,[sv]
        jne  ..bad
        cmp  bx,[sv+2]
        jne  ..bad
        cmp  cx,[sv+4]
        jne  ..bad
        cmp  dx,[sv+6]
        jne  ..bad
        cmp  si,[sv+8]
        jne  ..bad
        cmp  di,[sv+10]
        jne  ..bad
        cmp  bp,[sv+12]
        jne  ..bad
        mov  ax,es
        cmp  ax,[sv+14]
        jne  ..bad
        mov  ax,[sv]
        mov  word [sv],0        ; a pass
        jmp  ..done
..bad:  mov  word [sv],1        ; a fail
..done: push ax
        mov  ax,[sv]
        REC  0, text
        pop  ax
}

start:  call GETAUTO
        call VGA_ON             ; before MEM_INIT: DOS has nothing to give
        sbb  ax,ax
        REC  -1, 'VGA_ON before MEM_INIT: CF = 1'
        mov  ah,0Fh
        int  10h                ; AL = the mode now
        xor  ah,ah
        REC  3, 'VGA_ON failing leaves text mode 3'
        call MEM_INIT
        call VGA_ON
        sbb  ax,ax
        REC  0, 'VGA_ON CF = 0'
        mov  ah,0Fh
        int  10h
        xor  ah,ah
        REC  13h, 'VGA_ON mode = 13h'
        mov  ax,[vga_buf]
        or   ax,ax
        mov  ax,0
        jnz  .b1
        inc  ax
.b1:    REC  0, 'VGA_ON vga_buf set'
        mov  es,[vga_buf]
        mov  ax,[es:0]
        or   ax,[es:63998]
        REC  0, 'VGA_ON buffer cleared to 0'
        push ds
        pop  es
        ; ---- the buffer ----
        mov  al,7
        SAME VGA_CLS, 'VGA_CLS keeps registers'
        mov  es,[vga_buf]
        mov  ax,[es:0]
        REC  0707h, 'VGA_CLS fills byte 0'
        mov  ax,[es:63998]
        REC  0707h, 'VGA_CLS fills byte 63999'
        push ds
        pop  es
        mov  ax,100
        call VGA_ROW
        mov  ax,di
        REC  32000, 'VGA_ROW 100 = 32000'
        mov  ax,199
        call VGA_ROW
        mov  ax,di
        REC  63680, 'VGA_ROW 199 = 63680'
        mov  ax,50
        mov  di,1234h
        SAME VGA_WAIT, 'VGA_WAIT keeps registers'
        ; ---- the palette: entries 16..79 a grey ramp, drawn as bars ----
        mov  si,keys2
        mov  cx,1               ; one band
        mov  bl,64              ; of 64 steps
        mov  di,ramp
        call VGA_RAMP
        mov  al,[ramp]
        mov  ah,[ramp+3*32]
        REC  1F00h, 'VGA_RAMP 0..63 in 64: step 0 = 0, step 32 = 31'
        mov  al,[ramp+3*63]
        xor  ah,ah
        REC  62, 'VGA_RAMP stops one short of the end key (62)'
        mov  si,keys4
        mov  cx,1
        mov  bl,4
        mov  di,ramp4
        SAME VGA_RAMP, 'VGA_RAMP keeps registers'
        mov  al,[ramp4+3]
        mov  ah,[ramp4+6]
        REC  1F0Fh, 'VGA_RAMP 0..63 in 4: 15 then 31'
        mov  al,16
        mov  cx,64
        mov  si,ramp
        SAME VGA_PALRUN, 'VGA_PALRUN keeps registers'
        mov  al,16+32
        mov  cx,1
        mov  di,rbk
        SAME VGA_PALGET, 'VGA_PALGET keeps registers'
        mov  al,[rbk]
        xor  ah,ah
        REC  31, 'VGA_PALRUN/PALGET entry 48 = 31 back'
        mov  si,plist
        SAME VGA_PAL, 'VGA_PAL keeps registers'
        mov  al,1
        mov  cx,2
        mov  di,rbk
        call VGA_PALGET
        mov  al,[rbk]
        mov  ah,[rbk+5]
        REC  3F3Fh, 'VGA_PAL entry 1 red 63, entry 2 blue 63'
        ; bars: 64 columns of 5 pixels, colours 16..79, rows 20..179
        mov  es,[vga_buf]
        mov  ax,20
        call VGA_ROW            ; DI = row 20
        mov  dx,160             ; 160 rows
.row:   push di
        mov  al,16              ; the first bar's colour
        mov  bx,64
.bar:   mov  cx,5
        rep  stosb
        inc  al                 ; the next colour
        dec  bx
        jnz  .bar
        pop  di
        add  di,320             ; the next row
        dec  dx
        jnz  .row
        ; entries 1 and 2 as a red and a blue band at the top
        xor  di,di
        mov  cx,3200
        mov  al,1
        rep  stosb
        mov  cx,3200
        mov  al,2
        rep  stosb
        push ds
        pop  es
        SAME VGA_SHOW, 'VGA_SHOW keeps registers'
        mov  ax,0A000h
        mov  es,ax
        mov  ax,[es:20*320+5*10]   ; bar 10 on the screen
        push ds
        pop  es
        REC  1A1Ah, 'VGA_SHOW the buffer is on the screen (colour 26)'
        ; ---- cycle: entries 10..12 = A, B, C -> B, C, A ----
        mov  al,10
        mov  cx,3
        mov  si,abc
        call VGA_PALRUN
        mov  al,10
        mov  cx,3
        SAME VGA_CYCLE, 'VGA_CYCLE keeps registers'
        mov  al,10
        mov  cx,3
        mov  di,rbk
        call VGA_PALGET
        mov  al,[rbk]
        mov  ah,[rbk+3]
        REC  0302h, 'VGA_CYCLE 10..12: 10 = old 11, 11 = old 12'
        mov  al,[rbk+6]
        xor  ah,ah
        REC  1, 'VGA_CYCLE 10..12: 12 = old 10'
        ; ---- glow: entry 3 from a table of three, phase 4 -> colour 1 ----
        mov  al,3
        mov  si,abc
        mov  cx,3
        mov  bx,4
        SAME VGA_GLOW, 'VGA_GLOW keeps registers'
        mov  al,3
        mov  cx,1
        mov  di,rbk
        call VGA_PALGET
        mov  al,[rbk]
        xor  ah,ah
        REC  2, 'VGA_GLOW phase 4 of 3 = colour 1 (red 2)'
        ; ---- palette colours of a made palette ----
        mov  si,pal
        call VGA_PALCOL
        REC  0005h, 'VGA_PALCOL brightest 5, darkest 0'
        mov  al,bl
        xor  ah,ah
        REC  9, 'VGA_PALCOL greyest 9 (38,38,38), not 7 (50,10,10)'
        ; ---- the picture, cycling, for about two seconds ----
        mov  al,0
        mov  cx,256
        mov  di,saved
        call VGA_PALGET         ; the whole palette, for the fade
        call TIM_TICK
        mov  [t0],ax
.show:  mov  al,16
        mov  cx,64
        call VGA_CYCLE          ; the bars run
        call VGA_WAIT
        cmp  byte [auto],0
        je   .key
        call TIM_TICK
        sub  ax,[t0]
        cmp  ax,27              ; 1.5 s
        jb   .show
        jmp  .fade
.key:   mov  ah,1
        int  16h                ; a key?
        jz   .show
        mov  ah,0
        int  16h
        cmp  ah,1               ; Esc ends it
        jne  .show
.fade:  mov  al,0
        mov  cx,256
        mov  di,saved
        call VGA_PALGET         ; as it is now
        mov  bl,64
.f:     mov  al,bl
        mov  si,saved
        call VGA_FADE           ; down to black, two levels a frame
        call VGA_WAIT
        sub  bl,2
        jnc  .f
        mov  al,32
        mov  si,saved
        SAME VGA_FADE, 'VGA_FADE keeps registers'
        mov  al,1
        mov  cx,1
        mov  di,rbk
        call VGA_PALGET
        mov  al,[rbk]
        xor  ah,ah
        REC  31, 'VGA_FADE level 32: red 63 -> 31'
        xor  al,al
        mov  si,saved
        call VGA_FADE
        mov  al,1
        mov  cx,1
        mov  di,rbk
        call VGA_PALGET
        mov  al,[rbk]
        xor  ah,ah
        REC  0, 'VGA_FADE level 0: black'
        mov  ax,1234h
        SAME VGA_OFF, 'VGA_OFF keeps registers'
        mov  ah,0Fh
        int  10h
        xor  ah,ah
        push ax
        call PRINTREC           ; text mode again: the records
        pop  ax
        EXPECT 3, 'VGA_OFF mode = 3'
        mov  ax,[vga_buf]
        EXPECT 0, 'VGA_OFF vga_buf = 0'
        mov  bx,0FA0h
        call MEM_ALLOC          ; the freed buffer is there to take again
        sbb  ax,ax
        EXPECT 0, 'VGA_OFF gave the buffer back'
        mov  byte [auto],1      ; the picture was the look: no second Esc
        jmp  FINISH

; PRINTREC - every REC as a PASS/FAIL line
PRINTREC:
        xor  bx,bx
.n:     cmp  bx,[nrec]
        jae  .d
        mov  ax,[rgot+bx]
        mov  [got],ax
        mov  si,[rname+bx]
        push bx
        cmp  ax,[rwant+bx]
        call RESULT
        pop  bx
        add  bx,2
        jmp  .n
.d:     ret

keys2   db   0,0,0, 63,63,63    ; black to white
keys4   db   0,0,0, 63,63,63
plist   db   1, 63,0,0          ; entry 1 red
        db   2, 0,0,63          ; entry 2 blue
        db   255
abc     db   1,0,0, 2,0,0, 3,0,0  ; three colours told apart by red
pal     db   0,0,0              ; 0: the darkest
        db   4 dup(1,1,1)
        db   63,63,63           ; 5: the brightest
        db   2,2,2
        db   50,10,10           ; 7: as bright as grey, but red
        db   1,1,1
        db   38,38,38           ; 9: the grey
        db   246*3 dup(1)
t0      dw   0
kax     dw   0
sv      dw   8 dup(0)
nrec    dw   0
rgot    dw   64 dup(0)
rwant   dw   64 dup(0)
rname   dw   64 dup(0)
rbk      db   12 dup(0)
ramp    db   64*3 dup(0)
ramp4   db   4*3 dup(0)
saved   db   768 dup(0)

; ============================================================================
;  the test's own helpers (not kit blocks)
; ============================================================================
; FINISH - the summary line; without /AUTO wait for Esc; exit
FINISH: mov  ax,[fails]
        or   ax,ax
        jnz  .f
        mov  dx,t_all
        mov  ah,9
        int  21h
        jmp  .w
.f:     call PUTN
        mov  dx,t_nf
        mov  ah,9
        int  21h
.w:     cmp  byte [auto],0
        jne  .x
        mov  dx,t_esc
        mov  ah,9
        int  21h
.k:     mov  ah,0
        int  16h
        cmp  ah,1               ; Esc?
        jne  .k
.x:     mov  ax,4C00h
        int  21h

; GETAUTO - [auto] = 1 if the command line holds /AUTO
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

; RESULT - ZF = 1 pass: "PASS name = got", else "FAIL ..." and fails++
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
        call NL
        ret

; PUTS - the 0-ended string at SI
PUTS:   lodsb
        or   al,al
        jz   .d
        mov  dl,al
        mov  ah,2
        int  21h
        jmp  PUTS
.d:     ret

; PUTN - AX as a signed decimal number
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

NL:     mov  dx,t_nl
        mov  ah,9
        int  21h
        ret

auto    db   0
got     dw   0
fails   dw   0
t_pass  db   'PASS $'
t_fail  db   'FAIL $'
t_got   db   '  got $'
t_nl    db   13,10,'$'
t_all   db   'ALL PASS',13,10,'$'
t_nf    db   ' FAILED',13,10,'$'
t_esc   db   'Esc quits.',13,10,'$'

        include '..\..\KIT\LIB\K_VGA.INC'
        include '..\..\KIT\LIB\K_MEM.INC'
        include '..\..\KIT\LIB\K_TIME.INC'
