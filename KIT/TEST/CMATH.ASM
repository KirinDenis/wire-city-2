; CMATH.ASM - test of KIT\LIB\K_MATH.INC: every routine's numbers checked,
; a PASS or FAIL line each. With /AUTO it quits by itself; without, Esc.
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
; KEPT fn, 'name' - fn must keep BX CX DX SI DI BP (AX is its answer)
macro KEPT fn, text
{
        local ..bad, ..done
        mov  bx,1111h
        mov  cx,2222h
        mov  dx,3333h
        mov  si,4444h
        mov  di,5555h
        mov  bp,6666h
        mov  ax,50
        call fn
        cmp  bx,1111h
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
        xor  ax,ax
        jmp ..done
..bad:    mov  ax,1
..done:   EXPECT 0, text
}

start:  call GETAUTO
        ; ---- random ----
        mov  word [mth_seed],1
        call MTH_RND
        EXPECT 39022, 'MTH_RND after seed 1 = 39022'
        call MTH_SEED
        mov  ax,[mth_seed]
        and  ax,1
        EXPECT 1, 'MTH_SEED leaves an odd seed'
        ; MTH_RANGE 7, a thousand times: never >= 7, and 0 and 6 both seen
        mov  cx,1000
        xor  bx,bx              ; BL = 0 seen, BH = 6 seen
        mov  word [bad],0
.r:     mov  ax,7
        call MTH_RANGE
        cmp  ax,7
        jb   .r1
        inc  word [bad]         ; out of range
.r1:    cmp  ax,0
        jne  .r2
        mov  bl,1
.r2:    cmp  ax,6
        jne  .r3
        mov  bh,1
.r3:    loop .r
        mov  [seen],bx          ; RESULT uses BX: keep the marks
        mov  ax,[bad]
        EXPECT 0, 'MTH_RANGE 7 x1000: never >= 7'
        mov  ax,[seen]
        EXPECT 0101h, 'MTH_RANGE 7: both 0 and 6 come up'
        xor  ax,ax
        call MTH_RANGE
        EXPECT 0, 'MTH_RANGE 0 = 0 (no divide)'
        mov  ax,1
        call MTH_RANGE
        EXPECT 0, 'MTH_RANGE 1 = 0'
        ; ---- sine ----
        xor  ax,ax
        call MTH_SIN
        EXPECT 0, 'MTH_SIN 0 = 0'
        mov  ax,64
        call MTH_SIN
        EXPECT 256, 'MTH_SIN 64 = 256'
        mov  ax,128
        call MTH_SIN
        EXPECT 0, 'MTH_SIN 128 = 0'
        mov  ax,192
        call MTH_SIN
        EXPECT -256, 'MTH_SIN 192 = -256'
        mov  ax,32
        call MTH_SIN
        EXPECT 181, 'MTH_SIN 32 = 181'
        mov  ax,160
        call MTH_SIN
        EXPECT -181, 'MTH_SIN 160 = -181'
        mov  ax,320
        call MTH_SIN
        EXPECT 256, 'MTH_SIN 320 wraps = 256'
        xor  ax,ax
        call MTH_COS
        EXPECT 256, 'MTH_COS 0 = 256'
        mov  ax,128
        call MTH_COS
        EXPECT -256, 'MTH_COS 128 = -256'
        ; ---- atan2: east AX, north BX ----
        xor  ax,ax
        mov  bx,100
        call MTH_ATAN2
        EXPECT 0, 'MTH_ATAN2 north = 0'
        mov  ax,100
        xor  bx,bx
        call MTH_ATAN2
        EXPECT 64, 'MTH_ATAN2 east = 64'
        xor  ax,ax
        mov  bx,-100
        call MTH_ATAN2
        EXPECT 128, 'MTH_ATAN2 south = 128'
        mov  ax,-100
        xor  bx,bx
        call MTH_ATAN2
        EXPECT 192, 'MTH_ATAN2 west = 192'
        mov  ax,100
        mov  bx,100
        call MTH_ATAN2
        EXPECT 32, 'MTH_ATAN2 north-east = 32'
        mov  ax,-30000
        mov  bx,-30000
        call MTH_ATAN2
        EXPECT 160, 'MTH_ATAN2 (-30000,-30000) = 160 (big legs)'
        mov  ax,3000
        mov  bx,-4000
        call MTH_ATAN2
        EXPECT 102, 'MTH_ATAN2 (3000,-4000) = 102 (true 101.8)'
        xor  ax,ax
        xor  bx,bx
        call MTH_ATAN2
        EXPECT 0, 'MTH_ATAN2 (0,0) = 0'
        ; ---- distance, lerp, clamp, abs, sgn ----
        mov  ax,300
        mov  bx,-400
        call MTH_DIST
        EXPECT 512, 'MTH_DIST (300,-400) = 512 (true 500)'
        mov  ax,100
        mov  bx,200
        mov  cx,128
        call MTH_LERP
        EXPECT 150, 'MTH_LERP 100..200 at 128 = 150'
        mov  ax,-100
        mov  bx,100
        mov  cx,256
        call MTH_LERP
        EXPECT 100, 'MTH_LERP -100..100 at 256 = 100'
        mov  ax,-100
        mov  bx,100
        xor  cx,cx
        call MTH_LERP
        EXPECT -100, 'MTH_LERP at 0 = a'
        mov  ax,5
        xor  bx,bx
        mov  cx,3
        call MTH_CLAMP
        EXPECT 3, 'MTH_CLAMP 5 in 0..3 = 3'
        mov  ax,-5
        call MTH_CLAMP
        EXPECT 0, 'MTH_CLAMP -5 in 0..3 = 0'
        mov  ax,-7
        call MTH_ABS
        EXPECT 7, 'MTH_ABS -7 = 7'
        mov  ax,-9
        call MTH_SGN
        EXPECT -1, 'MTH_SGN -9 = -1'
        xor  ax,ax
        call MTH_SGN
        EXPECT 0, 'MTH_SGN 0 = 0'
        mov  ax,5
        call MTH_SGN
        EXPECT 1, 'MTH_SGN 5 = 1'
        ; ---- hash ----
        mov  cx,3
        mov  dx,4
        mov  bx,1
        call MTH_HASH
        mov  [h1],ax
        call MTH_HASH
        cmp  ax,[h1]
        mov  ax,0
        je   .h1
        inc  ax
.h1:    EXPECT 0, 'MTH_HASH the same cell twice = the same'
        mov  ax,[h1]
        mov  al,0
        EXPECT 0, 'MTH_HASH is 0..255 (AH = 0)'
        mov  cx,4
        call MTH_HASH
        cmp  ax,[h1]
        mov  ax,1
        jne  .h2
        dec  ax
.h2:    EXPECT 1, 'MTH_HASH the next cell differs'
        ; ---- square root ----
        xor  ax,ax
        call MTH_SQRT
        EXPECT 0, 'MTH_SQRT 0 = 0'
        mov  ax,15
        call MTH_SQRT
        EXPECT 3, 'MTH_SQRT 15 = 3'
        mov  ax,16
        call MTH_SQRT
        EXPECT 4, 'MTH_SQRT 16 = 4'
        mov  ax,10000
        call MTH_SQRT
        EXPECT 100, 'MTH_SQRT 10000 = 100'
        mov  ax,65535
        call MTH_SQRT
        EXPECT 255, 'MTH_SQRT 65535 = 255'
        ; ---- muldiv ----
        mov  ax,100
        mov  bx,200
        mov  cx,50
        call MTH_MULDIV
        EXPECT 400, 'MTH_MULDIV 100*200/50 = 400'
        sbb  ax,ax
        EXPECT 0, 'MTH_MULDIV 100*200/50 CF = 0'
        mov  ax,-300
        mov  bx,200
        mov  cx,7
        call MTH_MULDIV
        EXPECT -8571, 'MTH_MULDIV -300*200/7 = -8571'
        mov  ax,30000
        mov  bx,30000
        mov  cx,1
        call MTH_MULDIV
        sbb  ax,ax
        EXPECT -1, 'MTH_MULDIV 30000*30000/1 overflow CF = 1'
        mov  ax,1000
        mov  bx,1000
        xor  cx,cx
        call MTH_MULDIV
        sbb  ax,ax
        EXPECT -1, 'MTH_MULDIV /0 CF = 1'
        mov  ax,-32768
        mov  bx,1
        mov  cx,-1
        call MTH_MULDIV
        sbb  ax,ax
        EXPECT -1, 'MTH_MULDIV -32768/-1 overflow CF = 1'
        mov  ax,-32768
        mov  bx,1
        mov  cx,1
        call MTH_MULDIV
        EXPECT -32768, 'MTH_MULDIV -32768*1/1 = -32768'
        mov  ax,30000
        mov  bx,30000
        mov  cx,30000
        call MTH_MULDIV
        EXPECT 30000, 'MTH_MULDIV 30000*30000/30000 = 30000'
        ; ---- registers kept ----
        KEPT MTH_RND,    'MTH_RND keeps registers'
        KEPT MTH_RANGE,  'MTH_RANGE keeps registers'
        KEPT MTH_SIN,    'MTH_SIN keeps registers'
        KEPT MTH_COS,    'MTH_COS keeps registers'
        KEPT MTH_ATAN2,  'MTH_ATAN2 keeps registers'
        KEPT MTH_DIST,   'MTH_DIST keeps registers'
        KEPT MTH_LERP,   'MTH_LERP keeps registers'
        KEPT MTH_HASH,   'MTH_HASH keeps registers'
        KEPT MTH_SQRT,   'MTH_SQRT keeps registers'
        KEPT MTH_MULDIV, 'MTH_MULDIV keeps registers'
        jmp  FINISH

h1      dw 0
bad     dw 0
seen    dw 0

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

        include '..\..\KIT\LIB\K_MATH.INC'
