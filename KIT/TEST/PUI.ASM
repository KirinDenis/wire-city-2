; ============================================================================
;  PUI.ASM - KIT test: K_UI.INC (slots as outlines or in colour, the caption
;  band put back exactly, the message box, the question, the fades).
;
;      PUI            checks, then shows the panel, a caption and a question
;                     until Esc
;      PUI /AUTO      the same, the picture held ~2 s, PASS/FAIL printed
; ============================================================================
        org  100h
        include '..\..\ENGINE\E_8086.INC'

Main:   cld
        call IsAuto
        mov  ax,0013h
        int  10h
        mov  ax,0A000h
        mov  es,ax
        mov  si,SOLID
        mov  di,solidc
        call SPR_COMPILE
        mov  si,GEM
        mov  di,gemc
        call SPR_COMPILE

; ---- 1. an outline is the edge, colour is the whole; clipped ----------------
        call Clear
        mov  si,solidc
        mov  bx,20
        mov  dx,20
        xor  al,al              ; outline
        call Regs
        call UI_ICON
        call RegsSame
        jne  .o0
        mov  al,7               ; [ui_grey]
        call Count
        cmp  ax,20              ; a 6x6 square's edge
        jne  .o0
        mov  al,14
        call Count
        cmp  ax,0               ; and nothing in colour
        jne  .o0
        mov  al,1
        mov  bx,40
        call UI_ICON            ; in colour
        mov  al,14
        call Count
        cmp  ax,36
        jne  .o0
        mov  al,1
        mov  bx,-3              ; half off the left: 18 in colour more
        call UI_ICON
        mov  al,14
        call Count
        cmp  ax,36+18
        jne  .o0
        call Clear              ; the gem: its hole has an edge too
        mov  si,gemc
        mov  bx,100
        mov  dx,100
        xor  al,al
        call UI_ICON
        mov  al,7
        call Count
        cmp  ax,44              ; 28 outside + 16 round the 4x4 hole
        call PassZ
.o0:    mov  si,mIcon
        call ChkOk

; ---- 2. the panel: a thing in the room is an outline, a taken one colour ----
        call Clear
        mov  di,things
        mov  si,solidc
        mov  bx,50
        mov  dx,50
        call HOT_PUT
        add  di,HOT_SIZE
        call HOT_PUT
        or   byte [di+HOT_FLAGS],HOT_TAKEN ; the second is taken
        mov  si,things
        mov  cx,2
        call UI_PANEL           ; slots at x 8 and 32, y 176, 22x20
        mov  ax,8
        mov  bl,7
        call CountIn            ; slot 0: grey outline pixels
        cmp  ax,20              ; the 6x6 square's edge
        jne  .s0
        mov  ax,8
        mov  bl,14
        call CountIn
        cmp  ax,0               ; nothing in colour in slot 0
        jne  .s0
        mov  ax,32
        mov  bl,14
        call CountIn            ; slot 1: the whole square in colour
        cmp  ax,36
        call PassZ
.s0:    mov  si,mPanel
        call ChkOk

; ---- 3. the caption: up, the band changed and only it; down, exact -----------
        call Pattern
        mov  si,sCap
        call Regs
        call UI_CAPTION
        call RegsSame
        jne  .c0
        cmp  byte [ui_capon],1
        jne  .c0
        mov  ax,0
        mov  bx,[ui_capy]
        call Peek
        cmp  al,[ui_boxc]       ; the band's left end: the box colour
        jne  .c0
        call SameOut            ; outside the band: untouched
        jne  .c0
        call UI_CAPHIDE
        call Same
        jne  .c0
        mov  si,sCap
        call UI_CAPTION
        mov  si,sCap2
        call UI_CAPTION         ; a second over it: the first comes down
        call UI_CAPHIDE
        call Same
        call PassZ
.c0:    mov  si,mCap
        call ChkOk

        mov  word [ui_caphold],0
        call UI_CAPCHECK        ; none up: CF 0
        jc   .d0
        mov  si,sCap
        call UI_CAPTION
        call UI_CAPCHECK        ; held 0 ticks: down at once
        jnc  .d0
        call Same
        jne  .d0
        mov  word [ui_caphold],3
        mov  word [ui_capy],192 ; low: the band is cut at the bottom
        mov  word [ui_caph],12
        mov  si,sCap
        call UI_CAPTION
        cmp  word [ui_caph],8   ; 8 rows left
        jne  .d0
        call UI_TICK
        mov  [t0],ax
        call UI_CAPWAIT         ; its 3 ticks, then down
        call UI_TICK
        sub  ax,[t0]
        cmp  ax,3
        jb   .d0
        call Same
        call PassZ
.d0:    mov  si,mCapT
        call ChkOk
        mov  word [ui_capy],160
        mov  word [ui_caph],12
        mov  word [ui_caphold],27

; ---- 4. waiting: the time runs out with no key ------------------------------
        call UI_TICK
        mov  [t0],ax
        mov  ax,4
        call UI_WAITKEY
        test ax,ax
        jnz  .w0
        call UI_TICK
        sub  ax,[t0]
        cmp  ax,4
        jb   .w0
        cmp  ax,10
        jae  .w0
        cmp  ax,ax
        call PassZ
.w0:    mov  si,mWaitK
        call ChkOk

; ---- 5. the message box ------------------------------------------------------
        call Clear
        mov  si,sMsg1
        mov  dx,sMsg2
        mov  ax,2
        call UI_MSGBOX
        test ax,ax
        jnz  .m0
        mov  ax,160
        mov  bx,[ui_msgy]       ; the box's top edge: the frame
        call Peek
        cmp  al,[ui_boxfr]
        jne  .m0
        mov  al,15
        call Count
        cmp  ax,20              ; letters were drawn (white)
        jb   .m0
        cmp  ax,ax
        call PassZ
.m0:    mov  si,mMsg
        call ChkOk

; ---- 6. the question: no answer in time takes the first's code ---------------
        call Clear
        mov  si,quiz
        mov  bx,2
        call UI_QUIZ
        cmp  ax,21
        jne  .q0
        cmp  cx,0
        jne  .q0
        mov  ax,0
        mov  bx,199
        call Peek
        cmp  al,[ui_boxfr]      ; the box at the foot
        call PassZ
.q0:    mov  si,mQuiz
        call ChkOk

; ---- 7. fades: down to black, up to the palette -------------------------------
        mov  si,pal
        mov  byte [ui_lvl],64
        call UI_FADEDN
        cmp  byte [ui_lvl],0
        jne  .f0
        mov  al,4
        call Dac                ; AH = red of entry 4
        cmp  ah,0
        jne  .f0
        call UI_FADEUP
        cmp  byte [ui_lvl],64
        jne  .f0
        mov  al,4
        call Dac
        cmp  ah,42              ; the palette's red 4
        call PassZ
.f0:    mov  si,mFade
        call ChkOk

; ---- the picture ---------------------------------------------------------------
        call Clear
        mov  si,things
        mov  cx,2
        call UI_PANEL
        mov  si,sCap
        call UI_CAPTION
        mov  si,quiz
        mov  bx,1
        call UI_QUIZ
        mov  si,sMsg1
        xor  dx,dx
        mov  ax,1
        call UI_MSGBOX
        call Hold
        mov  ax,0003h
        int  10h
        call Report
        mov  ax,4C00h
        int  21h

; Clear - the screen to 0
Clear:  push ax
        push cx
        push di
        xor  di,di
        mov  cx,32000
        xor  ax,ax
        rep  stosw
        pop  di
        pop  cx
        pop  ax
        ret

; Pattern / Same - every pixel = its offset's low + high byte; ZF = still so
Pattern:
        xor  di,di
        mov  cx,64000
.l:     mov  ax,di
        add  al,ah
        stosb
        loop .l
        ret
Same:   push ax
        push cx
        push di
        xor  di,di
        mov  cx,64000
.l:     mov  ax,di
        add  al,ah
        cmp  al,[es:di]
        jne  .o
        inc  di
        loop .l
        cmp  ax,ax
.o:     pop  di
        pop  cx
        pop  ax
        ret
; SameOut - ZF = the pattern holds everywhere but rows 160..171 (the band)
SameOut:
        push ax
        push cx
        push di
        xor  di,di
        mov  cx,64000
.l:     cmp  di,160*320
        jb   .c
        cmp  di,172*320
        jb   .n
.c:     mov  ax,di
        add  al,ah
        cmp  al,[es:di]
        jne  .o
.n:     inc  di
        loop .l
        cmp  ax,ax
.o:     pop  di
        pop  cx
        pop  ax
        ret

; Count - AX = pixels of colour AL on the whole screen
Count:  push cx
        push dx
        push di
        xor  di,di
        xor  dx,dx
        mov  cx,64000
.l:     cmp  [es:di],al
        jne  .n
        inc  dx
.n:     inc  di
        loop .l
        mov  ax,dx
        pop  di
        pop  dx
        pop  cx
        ret

; CountIn - AX = pixels of colour BL in the 22x20 box at (AX, 176)
CountIn:
        push cx
        push dx
        push di
        push si
        mov  di,176*320
        add  di,ax
        xor  dx,dx
        mov  si,20              ; rows
.r:     mov  cx,22
.l:     cmp  [es:di],bl
        jne  .n
        inc  dx
.n:     inc  di
        loop .l
        add  di,320-22
        dec  si
        jnz  .r
        mov  ax,dx
        pop  si
        pop  di
        pop  dx
        pop  cx
        ret

; Peek - AL = the pixel at (AX,BX)
Peek:   push bx
        push cx
        push di
        mov  di,bx
        mov  cl,8
        shl  di,cl              ; y * 256
        mov  cl,6
        shl  bx,cl              ; y * 64
        add  di,bx              ; y * 320
        add  di,ax              ; + x
        mov  al,[es:di]
        pop  di
        pop  cx
        pop  bx
        ret

; Dac - AH = the red of DAC entry AL
Dac:    push dx
        mov  dx,3C7h
        out  dx,al              ; read from entry AL
        mov  dx,3C9h
        in   al,dx              ; red
        mov  ah,al
        in   al,dx              ; green, blue: read and dropped
        in   al,dx
        pop  dx
        ret

; the palette for the fades: entry 4 red 42 (as the VGA's own), the rest grey
pal:    repeat 256
          if % = 5
            db 42,0,0
          else
            db (%-1)/4,(%-1)/4,(%-1)/4
          end if
        end repeat

SOLID   db 6,6
        db 'EEEEEE'
        db 'EEEEEE'
        db 'EEEEEE'
        db 'EEEEEE'
        db 'EEEEEE'
        db 'EEEEEE'
GEM     db 8,8
        db 'BBBBBBBB'
        db 'BBBBBBBB'
        db 'BB....BB'
        db 'BB....BB'
        db 'BB....BB'
        db 'BB....BB'
        db 'BBBBBBBB'
        db 'BBBBBBBB'
quiz    db 'WHICH DOOR?',0
        dw 21
        db 'THE RED ONE',0
        dw 22
        db 'THE BLUE ONE',0
        dw 23
        db 'NEITHER',0
        dw -1
sCap    db 'An old iron key.',0
sCap2   db 'A second line, longer than the first one.',0
sMsg1   db 'THE ROOM IS EMPTY NOW.',0
sMsg2   db 'Press a key.',0
mIcon   db 'UI_ICON outline = the edge (20 of 6x6, 44 of a ring), colour all, clipped$'
mPanel  db 'UI_PANEL outline in the room, colour once taken$'
mCap    db 'UI_CAPTION only the band changes; UI_CAPHIDE exact, twice over$'
mCapT   db 'UI_CAPCHECK at its time; cut at the bottom; UI_CAPWAIT waits$'
mWaitK   db 'UI_WAITKEY 4 ticks, no key: AX = 0 after 4..9 ticks$'
mMsg    db 'UI_MSGBOX framed, letters drawn, the time runs out: AX = 0$'
mQuiz   db 'UI_QUIZ no answer in time: the first, code 21; box at the foot$'
mFade   db 'UI_FADEDN to black, UI_FADEUP to the palette (VGA_FADE)$'
t0      dw 0
things  db 2*HOT_SIZE dup(0)
solidc  db 2+36 dup(0)
gemc    db 2+64 dup(0)

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

        include '..\..\KIT\LIB\K_UI.INC'
        include '..\..\KIT\LIB\K_HOT.INC'
        include '..\..\KIT\LIB\K_SPR.INC'
        include '..\..\KIT\LIB\K_DRAW.INC'
        include '..\..\KIT\LIB\K_TEXT.INC'
        include '..\..\KIT\LIB\K_VGA.INC'
