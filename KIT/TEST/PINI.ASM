; ============================================================================
;  PINI.ASM - KIT test: K_INI.INC (INI files: sections, keys, sub-keys,
;  comments, numbers, lists, a missing file, a missing key).
;
;      PINI           runs the checks, prints PASS/FAIL (text mode)
;      PINI /AUTO     the same (it never waits; it reads PINI.INI beside it)
; ============================================================================
        org  100h
        include '..\..\ENGINE\E_8086.INC'

Main:   cld
        call IsAuto

; ---- 1. a file that is not there: CF, an empty text ------------------------
        mov  dx,fNone
        mov  di,buf
        mov  cx,BUFSZ
        call INI_READ
        jnc  .m0
        call INI_NEXT           ; nothing to read
        jnc  .m0
        cmp  ax,ax              ; ZF = 1
        call PassZ
.m0:    mov  si,mMiss
        call ChkOk

; ---- 2. the real file -------------------------------------------------------
        mov  dx,fIni
        mov  di,buf
        mov  cx,BUFSZ
        call INI_READ
        jc   .r0
        cmp  ax,100             ; well over 100 bytes
        jb   .r0
        cmp  ax,ax
        call PassZ
.r0:    mov  si,mRead
        call ChkOk

; ---- 3. the first line: a key, trailing spaces trimmed, no sub-key ---------
        call Regs
        call INI_NEXT
        call RegsSame
        call PassZ
        mov  si,mKeep
        call ChkOk
        cmp  al,2
        jne  .k0
        mov  si,sTITLE
        mov  di,ini_key
        call INI_EQ
        jc   .k0
        cmp  byte [ini_sub],0
        jne  .k0
        mov  si,vTest
        call ValIs
        call PassZ
.k0:    mov  si,mKey
        call ChkOk

; ---- 4. KEY=VALUE with no spaces, a number ----------------------------------
        call INI_NEXT
        call INI_NUM
        jc   .n0
        cmp  ax,7
        call PassZ
.n0:    mov  si,mNum
        call ChkOk

; ---- 5. a comment and a blank passed over, a section -------------------------
        call INI_NEXT
        cmp  al,1
        jne  .s0
        mov  si,sHall
        mov  di,ini_key
        call INI_EQ
        jc   .s0
        cmp  ax,ax
        call PassZ
.s0:    mov  si,mSect
        call ChkOk

; ---- 6. a sub-key and a list of two numbers ---------------------------------
        call INI_NEXT
        cmp  al,2
        jne  .i0
        mov  si,sItem
        mov  di,ini_key
        call INI_EQ
        jc   .i0
        mov  si,sKey
        mov  di,ini_sub
        call INI_EQ
        jc   .i0
        mov  si,[ini_val]
        mov  cx,[ini_vlen]
        call INI_NUMAT
        jc   .i0
        cmp  ax,40
        jne  .i0
        call INI_NUMAT
        jc   .i0
        cmp  ax,60
        jne  .i0
        call INI_NUMAT          ; nothing left: CF
        jnc  .i0
        test cx,cx              ; and CX = 0
        call PassZ
.i0:    mov  si,mSub
        call ChkOk

; ---- 7. a negative number, spaces round the comma ---------------------------
        call INI_NEXT
        mov  si,[ini_val]
        mov  cx,[ini_vlen]
        call INI_NUMAT
        jc   .g0
        cmp  ax,-5
        jne  .g0
        call INI_NUMAT
        jc   .g0
        cmp  ax,12
        call PassZ
.g0:    mov  si,mNeg
        call ChkOk

; ---- 8. the list of words ---------------------------------------------------
        call INI_NEXT           ; TEXT KEY
        call INI_NEXT           ; NEED = KEY LAMP BOOK
        mov  si,[ini_val]
        mov  cx,[ini_vlen]
        mov  di,word1
        mov  bx,16
        call INI_WORD
        jc   .w0
        push si
        mov  si,sKey
        call INI_EQ
        pop  si
        jc   .w0
        call INI_WORD
        jc   .w0
        push si
        mov  si,sLamp
        call INI_EQ
        pop  si
        jc   .w0
        mov  bx,3               ; room for 2 letters: BOOK -> BO
        call INI_WORD
        jc   .w0
        push si
        mov  si,sBo
        call INI_EQ
        pop  si
        jc   .w0
        mov  bx,16
        call INI_WORD           ; none left
        jnc  .w0
        cmp  byte [word1],0
        call PassZ
.w0:    mov  si,mWord
        call ChkOk

; ---- 9. a key too long is cut at 15, not split into a sub-key ----------------
        call INI_NEXT
        mov  si,sLong
        mov  di,ini_key
        call INI_EQ
        jc   .l0
        cmp  byte [ini_sub],0
        jne  .l0
        call INI_NUM
        jc   .l0
        cmp  ax,3
        call PassZ
.l0:    mov  si,mLong
        call ChkOk

; ---- 10. tabs everywhere ---------------------------------------------------
        call INI_NEXT
        mov  si,sTabbed
        mov  di,ini_key
        call INI_EQ
        jc   .t0
        mov  si,vTab
        call ValIs
        call PassZ
.t0:    mov  si,mTab
        call ChkOk

; ---- 11. the nonsense line passed, a small-letter section -------------------
        call INI_NEXT
        cmp  al,1
        jne  .a0
        mov  si,sAttic          ; 'ATTIC' = 'attic'
        mov  di,ini_key
        call INI_EQ
        jc   .a0
        cmp  ax,ax
        call PassZ
.a0:    mov  si,mNons
        call ChkOk

; ---- 12. INI_FIND keeps the scan; finds across sections ---------------------
        mov  ax,[ini_pos]
        mov  [savepos],ax
        mov  si,sHall           ; [HALL] TEXT KEY
        mov  di,sText
        mov  bx,sKey
        call INI_FIND
        jc   .f0
        mov  ax,[savepos]
        cmp  ax,[ini_pos]
        jne  .f0
        mov  [ini_val],si
        mov  [ini_vlen],cx
        mov  si,vIron
        call ValIs
        call PassZ
.f0:    mov  si,mFind
        call ChkOk

        mov  si,sAttic          ; [attic] CODE = 21
        mov  di,sCode
        xor  bx,bx
        call INI_FIND
        jc   .f1
        call INI_NUM
        jc   .f1
        cmp  ax,21
        call PassZ
.f1:    mov  si,mFind2
        call ChkOk

        mov  si,sEmpty0         ; '' : the top - TITLE = The Test
        mov  di,sTITLE
        xor  bx,bx
        call INI_FIND
        jc   .f2
        mov  si,vTest
        call ValIs
        jne  .f2
        mov  si,sAttic          ; [attic] TITLE = Up here
        mov  di,sTITLE
        call INI_FIND
        jc   .f2
        mov  si,vUp
        call ValIs
        call PassZ
.f2:    mov  si,mFind3
        call ChkOk

        mov  si,sHall           ; missing: a key not there, a sub-key
        mov  di,sCode           ; not there, a section with nothing
        xor  bx,bx
        call INI_FIND
        jnc  .f3
        mov  si,sHall
        mov  di,sItem
        mov  bx,sBo
        call INI_FIND
        jnc  .f3
        mov  si,sEmpty
        mov  di,sTITLE
        xor  bx,bx
        call INI_FIND
        jnc  .f3
        mov  si,sNoSec
        call INI_FIND
        jnc  .f3
        cmp  ax,ax
        call PassZ
.f3:    mov  si,mFind4
        call ChkOk

; ---- 13. the rest: CODE, ENTERS 1 21 300, [EMPTY], then the end (the last
;          line a comment with no line end) ------------------------------------
        call INI_NEXT           ; TITLE
        call INI_NEXT           ; CODE
        call INI_NEXT           ; ENTERS
        mov  si,[ini_val]
        mov  cx,[ini_vlen]
        xor  dx,dx
.e1:    call INI_NUMAT
        jc   .e2
        add  dx,ax              ; sum of the list
        jmp  .e1
.e2:    cmp  dx,1+21+300
        jne  .e0
        call INI_NEXT           ; [EMPTY]
        jc   .e0
        cmp  al,1
        jne  .e0
        call INI_NEXT           ; the end
        jnc  .e0
        test ax,ax
        call PassZ
.e0:    mov  si,mEnd
        call ChkOk

; ---- 14. the count, from the start again: 14 lines say something -----------
        call INI_REWIND
        xor  cx,cx
.c1:    call INI_NEXT
        jc   .c2
        inc  cx
        jmp  .c1
.c2:    cmp  cx,14
        call PassZ
        mov  si,mCount
        call ChkOk

; ---- 15. a text in memory, no line end at its end -----------------------------
        mov  si,memIni
        call INI_TEXT
        mov  si,sA
        mov  di,sX
        xor  bx,bx
        call INI_FIND
        jc   .x0
        call INI_NUM
        jc   .x0
        cmp  ax,1
        call PassZ
.x0:    mov  si,mMem
        call ChkOk

; ---- 16. INI_COPY cuts to the room, INI_EQ is blind to case ------------------
        mov  si,vTest
        mov  cx,8
        mov  di,word1
        mov  bx,4               ; 3 letters and the 0
        call INI_COPY
        mov  si,sThe
        call INI_EQ             ; 'The' = 'tHE'
        jc   .q0
        mov  si,sKey
        call INI_EQ             ; 'KEY' <> 'The'
        cmc
        jc   .q0
        cmp  ax,ax
        call PassZ
.q0:    mov  si,mCopy
        call ChkOk

        call Report
        mov  ax,4C00h
        int  21h

; ValIs - ZF = 1 if the value ([ini_val], [ini_vlen]) is exactly the
; 0-ended string SI
ValIs:  push cx
        push si
        push di
        mov  di,[ini_val]
        mov  cx,[ini_vlen]
.l:     jcxz .end
        mov  al,[si]
        cmp  al,[di]
        jne  .o
        inc  si
        inc  di
        dec  cx
        jmp  .l
.end:   cmp  byte [si],0        ; the string ends too
.o:     pop  di
        pop  si
        pop  cx
        ret

BUFSZ   = 2048
fNone   db 'NOSUCH.INI',0
fIni    db 'PINI.INI',0
sTITLE  db 'title',0
sHall   db 'Hall',0
sItem   db 'ITEM',0
sKey    db 'KEY',0
sLamp   db 'lamp',0
sBo     db 'BO',0
sLong   db 'VERYLONGKEYNAME',0
sTabbed db 'TABBED',0
sAttic  db 'ATTIC',0
sText   db 'TEXT',0
sCode   db 'CODE',0
sEmpty  db 'EMPTY',0
sNoSec  db 'CELLAR',0
sEmpty0 db 0
sA      db 'A',0
sX      db 'X',0
sThe    db 'tHE',0
vTest   db 'The Test',0
vTab    db 'tab value',0
vIron   db 'An old iron key.',0
vUp     db 'Up here',0
memIni  db '; in memory',13,10,'[A]',13,10,'X = 1',0
mMiss   db 'INI_READ a missing file: CF, and the text is empty$'
mRead   db 'INI_READ PINI.INI: CF = 0, the bytes read$'
mKeep   db 'INI_NEXT keeps BX CX DX SI DI BP ES$'
mKey    db 'INI_NEXT the first key: TITLE = "The Test" (trailing spaces cut)$'
mNum    db 'INI_NUM SPEED=7 (no spaces round =)$'
mSect   db 'INI_NEXT a comment (#) and a blank passed, [HALL]$'
mSub    db 'INI_NEXT ITEM KEY = 40,60: the sub-key, INI_NUMAT twice, then CF$'
mNeg    db 'INI_NUMAT -5 , 12$'
mWord   db 'INI_WORD KEY LAMP BOOK (BO in 3 bytes), then CF$'
mLong   db 'INI_NEXT a 19-letter key cut at 15, not a sub-key$'
mTab    db 'INI_NEXT tabs round the key, the = and the value$'
mNons   db 'INI_NEXT a line with no = passed; [attic] = ATTIC$'
mFind   db 'INI_FIND [HALL] TEXT KEY, the scan position kept$'
mFind2  db 'INI_FIND [attic] CODE = 21$'
mFind3  db 'INI_FIND TITLE at the top and in [attic]: two values$'
mFind4  db 'INI_FIND missing key / sub-key / empty section / no section: CF$'
mEnd    db 'INI_NEXT ENTERS 1 21 300, [EMPTY], then the end on a comment$'
mCount  db 'INI_REWIND then 14 lines that say something$'
mMem    db 'INI_TEXT an INI in memory with no last line end: X = 1$'
mCopy   db 'INI_COPY cut to the room; INI_EQ blind to case$'
savepos dw 0
word1   db 16 dup(0)

; ---- the test's own harness ---------------------------------------------
; PassZ - ZF = 1: this check passed so far ([okf] = 1). All kept.
PassZ:  jnz  .o
        mov  byte [okf],1
.o:     ret

; ChkOk - record [okf] as the result (SI = its name), then [okf] = 0
ChkOk:  cmp  byte [okf],1
        mov  byte [okf],0       ; (flags kept)
        jmp  Chk

; Chk - record one result: ZF = 1 PASS, SI = its name ($-ended). All kept.
Chk:    push ax
        push bx
        mov  al,0
        jnz  .f
        mov  al,1
.f:     mov  bx,[nres]
        shl  bx,1
        shl  bx,1               ; four bytes a result
        mov  [res+bx],si
        mov  byte [res+bx+2],al
        inc  word [nres]
        pop  bx
        pop  ax
        ret

; Report - the PASS/FAIL lines by DOS (to NAME.OUT under RUNWIN)
Report: mov  si,res
        mov  cx,[nres]
        jcxz .sum
.l:     mov  dx,sPass
        cmp  byte [si+2],1
        je   .p
        mov  dx,sFail
        mov  byte [bad],1
.p:     mov  ah,9
        int  21h
        mov  dx,[si]
        mov  ah,9
        int  21h
        mov  dx,sCrlf
        mov  ah,9
        int  21h
        add  si,4
        loop .l
.sum:   mov  dx,sAll
        cmp  byte [bad],0
        je   .s
        mov  dx,sSome
.s:     mov  ah,9
        int  21h
        ret

; IsAuto - [auto] = 1 if the command line holds /A (/AUTO)
IsAuto: mov  si,81h
        mov  cl,[80h]
        xor  ch,ch              ; CX = the tail's length
        jcxz .no
.l:     lodsb
        cmp  al,'/'
        jne  .n
        mov  al,[si]
        and  al,0DFh            ; capital
        cmp  al,'A'
        jne  .n
        mov  byte [auto],1
.n:     loop .l
.no:    ret

; Hold - ~2 s by the BIOS tick under /AUTO; else until Esc
Hold:   cmp  byte [auto],0
        je   .key
        push es
        xor  ax,ax
        mov  es,ax
        mov  bx,[es:046Ch]      ; BX = the tick now
.t:     mov  ax,[es:046Ch]
        sub  ax,bx              ; AX = ticks gone
        cmp  ax,36              ; ~2 s?
        jb   .t
        pop  es
        ret
.key:   xor  ah,ah
        int  16h                ; wait for a key
        cmp  al,27              ; Esc?
        jne  .key
        ret

; Regs / RegsSame - snapshot BX CX DX SI DI BP ES, compare: ZF = 1 same
Regs:   mov  [rg],bx
        mov  [rg+2],cx
        mov  [rg+4],dx
        mov  [rg+6],si
        mov  [rg+8],di
        mov  [rg+10],bp
        mov  [rg+12],es
        ret
RegsSame:
        cmp  [rg],bx
        jne  .o
        cmp  [rg+2],cx
        jne  .o
        cmp  [rg+4],dx
        jne  .o
        cmp  [rg+6],si
        jne  .o
        cmp  [rg+8],di
        jne  .o
        cmp  [rg+10],bp
        jne  .o
        push ax
        mov  ax,es
        cmp  [rg+12],ax
        pop  ax
.o:     ret

auto    db 0
okf     db 0
bad     db 0
nres    dw 0
rg      dw 7 dup(0)
res     dw 2*80 dup(0)
sPass   db 'PASS $'
sFail   db 'FAIL $'
sCrlf   db 13,10,'$'
sAll    db 'ALL PASS',13,10,'$'
sSome   db 'SOME FAILED',13,10,'$'

        include '..\..\KIT\LIB\K_INI.INC'

buf     rb BUFSZ
