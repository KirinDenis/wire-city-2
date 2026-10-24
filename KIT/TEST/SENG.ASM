; SENG.ASM - test of REC\R_ENGINE.ASM and ART\SHIPS.TXT.
;  The ships: each drawn with SPR_TEXT on a black screen must light exactly
;  as many pixels as its picture has non-'.' characters (counted here from
;  the text itself). The sounds: the engine for 5 ticks, then the chime and
;  the crash each run out to eng_t = 0, the gate shut after SPK_STOP.
;  Quits by itself (with or without /AUTO) and prints PASS/FAIL lines.
        org  100h
        include '..\..\ENGINE\E_8086.INC'
START:  mov  ax,13h
        int  10h                ; mode 13h, screen cleared to colour 0
        mov  ax,0A000h
        mov  es,ax
        mov  si,LANDER
        call SHIPCHK
        mov  si,LFLAME1
        call SHIPCHK
        mov  si,LFLAME2
        call SHIPCHK
        mov  si,FIGHTER
        call SHIPCHK
        mov  cx,18
        call WAITT              ; a second to see them
        mov  ax,3
        int  10h
        ; the sounds - the test DOSBox is silent, the PIT is real
        mov  cx,5
.eng:   mov  al,1
        call ENG_TICK           ; the rumble
        loop .eng
        call ENG_CHIME
        mov  cx,ENG_CHLEN
.ch:    xor  al,al
        call ENG_TICK
        loop .ch
        cmp  word [eng_t],0
        mov  dx,m_chime
        call RESULT
        call ENG_CRASH
        mov  cx,ENG_CRLEN
.cr:    mov  al,1               ; the crash wins over the engine
        call ENG_TICK
        loop .cr
        cmp  word [eng_t],0
        mov  dx,m_crash
        call RESULT
        call SPK_STOP
        in   al,61h
        test al,3               ; the gate bits
        mov  dx,m_gate
        call RESULT
        mov  dx,[fails]
        or   dx,dx
        mov  dx,m_all
        jz   .ok
        mov  dx,m_bad
.ok:    mov  ah,9
        int  21h
        mov  ax,4C00h
        int  21h

; SHIPCHK: SI = a text-art picture. Draws it at (150,90) on a cleared
; screen and compares the lit pixels with its non-'.' characters.
SHIPCHK:
        push si
        xor  di,di
        mov  cx,32000
        xor  ax,ax
        rep  stosw              ; clear the screen
        pop  si
        push si
        mov  bx,150
        mov  dx,90
        call SPR_TEXT
        pop  si
        lodsb
        mov  cl,al              ; width
        lodsb
        mul  cl                 ; AX = width * height
        mov  cx,ax
        xor  bx,bx              ; the picture's solid characters
.c:     lodsb
        cmp  al,'.'
        je   .n
        inc  bx                 ; one more solid
.n:     loop .c
        xor  di,di
        mov  cx,64000
        xor  dx,dx              ; the screen's lit pixels
.s:     cmp  byte [es:di],0
        je   .z
        inc  dx                 ; one more lit
.z:     inc  di
        loop .s
        cmp  bx,dx
        mov  dx,m_ship
        call RESULT
        ret

; RESULT: ZF from the caller's compare; DX = the check's name ($)
RESULT: push dx                 ; flags untouched by push
        jz   .p
        inc  word [fails]       ; one more failure
        mov  dx,m_fail
        jmp  .w
.p:     mov  dx,m_pass
.w:     mov  ah,9
        int  21h
        pop  dx
        mov  ah,9
        int  21h
        ret

WAITT:  push es
        xor  ax,ax
        mov  es,ax
.t:     mov  ax,[es:046Ch]
.u:     cmp  ax,[es:046Ch]
        je   .u
        loop .t
        pop  es
        ret

fails   dw 0
m_pass  db 'PASS $'
m_fail  db 'FAIL $'
m_ship  db 'SHIPS picture lights exactly its solid characters',13,10,'$'
m_chime db 'ENG_CHIME runs out to eng_t 0',13,10,'$'
m_crash db 'ENG_CRASH runs out to eng_t 0, over the engine',13,10,'$'
m_gate  db 'SPK_STOP shuts the gate after ENG_TICK',13,10,'$'
m_all   db 'SENG ALL PASS',13,10,'$'
m_bad   db 'SENG FAILED',13,10,'$'

        include '..\REC\R_ENGINE.ASM'
        include '..\..\KIT\LIB\K_SPK.INC'
        include '..\..\KIT\LIB\K_MATH.INC'
        include '..\..\KIT\LIB\K_SPR.INC'
        include '..\ART\SHIPS.TXT'
