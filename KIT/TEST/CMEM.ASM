; CMEM.ASM - test of KIT\LIB\K_MEM.INC: shrink, allocate, fill, free, and
; the failures. With /AUTO it quits by itself; without, Esc.
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

start:  call GETAUTO
        ; before MEM_INIT the .COM owns every paragraph: DOS has none to give
        mov  bx,100h
        call MEM_ALLOC
        sbb  ax,ax
        EXPECT -1, 'MEM_ALLOC before MEM_INIT fails (CF = 1)'
        call MEM_INIT
        sbb  ax,ax
        EXPECT 0, 'MEM_INIT CF = 0'
        mov  bx,0FA0h
        call MEM_ALLOC          ; a back buffer's worth
        mov  [seg1],ax
        sbb  ax,ax
        EXPECT 0, 'MEM_ALLOC 0FA0h CF = 0'
        mov  ax,cs
        add  ax,1000h           ; the first paragraph past our 64K
        mov  bx,[seg1]
        cmp  bx,ax
        mov  ax,0
        jae  .a1
        inc  ax
.a1:    EXPECT 0, 'MEM_ALLOC block lies above our 64K'
        ; fill it with 5Ah, then 3 bytes (odd) of 11h
        mov  ax,[seg1]
        mov  cx,64000
        mov  bl,5Ah
        call MEM_CLEAR
        mov  cx,3
        mov  bl,11h
        call MEM_CLEAR
        mov  es,[seg1]
        mov  ax,[es:0]
        EXPECT 1111h, 'MEM_CLEAR bytes 0,1 = 11h'
        mov  ax,[es:2]
        EXPECT 5A11h, 'MEM_CLEAR byte 2 = 11h, byte 3 = 5Ah (odd count)'
        mov  al,[es:63999]
        xor  ah,ah
        EXPECT 5Ah, 'MEM_CLEAR byte 63999 = 5Ah'
        push ds
        pop  es
        xor  cx,cx
        mov  ax,[seg1]
        mov  bl,0
        call MEM_CLEAR          ; CX = 0: nothing
        mov  es,[seg1]
        mov  ax,[es:2]
        push ds
        pop  es
        EXPECT 5A11h, 'MEM_CLEAR CX = 0 writes nothing'
        ; a second block, freed and taken again
        mov  bx,1000h
        call MEM_ALLOC
        mov  [seg2],ax
        sbb  ax,ax
        EXPECT 0, 'MEM_ALLOC a second 64K CF = 0'
        mov  ax,[seg2]
        cmp  ax,[seg1]
        mov  ax,0
        ja   .a2
        inc  ax
.a2:    EXPECT 0, 'MEM_ALLOC second block above the first'
        mov  ax,[seg1]
        call MEM_FREE
        mov  bx,0FA0h
        call MEM_ALLOC
        cmp  ax,[seg1]
        mov  ax,0
        je   .a3
        inc  ax
.a3:    EXPECT 0, 'MEM_FREE then MEM_ALLOC gets the same block back'
        mov  bx,0FFFFh
        call MEM_ALLOC          ; more than there is
        mov  [big],ax
        sbb  ax,ax
        EXPECT -1, 'MEM_ALLOC 0FFFFh fails (CF = 1)'
        mov  ax,[big]
        cmp  ax,100h
        mov  ax,0
        ja   .a4
        inc  ax
.a4:    EXPECT 0, 'MEM_ALLOC failure: AX = the largest block (> 100h)'
        xor  ax,ax
        call MEM_FREE           ; 0: ignored
        EXPECT 0, 'MEM_FREE 0 is ignored'
        KEEPS MEM_INIT, 1234h, 'MEM_INIT keeps registers'
        KEEPS MEM_FREE, 0, 'MEM_FREE keeps registers'
        KEEPS MEM_CLEAR, [seg1], 'MEM_CLEAR keeps registers'
        mov  bx,0FA0h
        call MEM_ALLOC
        cmp  bx,0FA0h
        mov  ax,0
        je   .a5
        inc  ax
.a5:    EXPECT 0, 'MEM_ALLOC keeps BX'
        jmp  FINISH

seg1    dw 0
seg2    dw 0
big     dw 0
kax     dw 0

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

        include '..\..\KIT\LIB\K_MEM.INC'
