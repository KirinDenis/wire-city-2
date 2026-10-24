; ============================================================================
;  VCUT.ASM - KIT test: the recipes REC\R_CUTSC.ASM (a cutscene inside a
;  game) and REC\R_STILL.ASM (compressed backgrounds), on VTEST.OWV.
;
;      VCUT           a "game" (stripes, its own grey palette), the clip
;                     faded in and out, the game back; Esc at the end
;      VCUT /AUTO     the same without the wait, then PASS/FAIL lines
;
;  Checked: CUTSCENE ran the clip to its end, called CUT_REDRAW once, and
;  left the DAC exactly the game's palette; a missing clip gives CF 1 and
;  the game's palette back; BG_LOAD puts frame 1 in a buffer (its sum as
;  VTEST.SUM says), BG_PICK 4 the fifth frame, BG_PICK 99 and a missing
;  file a clean CF and a cleared buffer.
; ============================================================================
        org  100h
        include '..\..\ENGINE\E_8086.INC'

start:  cld
        call GETAUTO
        call OWV_ALLOC
        jnc  .mem
        jmp  quit
.mem:   mov  bx,0FA0h           ; a back buffer for the backgrounds
        mov  ah,48h             ; DOS: allocate
        int  21h
        jnc  .buf
        jmp  quit
.buf:   mov  [buf],ax
        mov  ax,3D00h           ; DOS: open VTEST.SUM
        mov  dx,f_sum
        int  21h
        jc   .nos
        mov  bx,ax
        mov  cx,12
        mov  dx,sums
        mov  ah,3Fh             ; DOS: read the count and 5 sums
        int  21h
        mov  ah,3Eh
        int  21h
.nos:
        mov  ax,0013h
        int  10h                ; 320x200, a byte a pixel
        mov  si,gamepal         ; the game's palette: a grey ramp
        xor  bx,bx
.gp:    mov  al,bl
        shr  al,1
        shr  al,1               ; 0..63
        mov  [si],al
        mov  [si+1],al
        mov  [si+2],al
        add  si,3               ; the next entry
        inc  bl
        jnz  .gp
        mov  si,gamepal
        mov  al,16
        call CUT_PAL            ; the game's colours, full
        mov  word [redraws],0
        call CUT_REDRAW
        mov  word [redraws],0
        mov  cx,18
        call HOLD               ; the game, a second

; ---- the cutscene -------------------------------------------------------------
        mov  dx,f_test
        call CUTSCENE
        call ERRCODE
        mov  [cutres],ax
        call DACSAME
        mov  [dac1],ax
        mov  cx,18
        call HOLD
        mov  dx,f_none          ; a clip that is not there
        call CUTSCENE
        call ERRCODE
        mov  [cutnone],ax
        call DACSAME
        mov  [dac2],ax

; ---- backgrounds --------------------------------------------------------------
        mov  es,[buf]
        mov  dx,f_test
        call BG_LOAD
        call ERRCODE
        mov  [bg1],ax
        call BUFSUM
        mov  [bg1s],ax
        mov  ax,4
        mov  dx,f_test
        call BG_PICK
        call ERRCODE
        mov  [bg5],ax
        call BUFSUM
        mov  [bg5s],ax
        call SHOWBUF            ; the fifth frame on the screen
        mov  ax,99
        mov  dx,f_test
        call BG_PICK
        call ERRCODE
        mov  [bg99],ax
        call BUFSUM
        mov  [bg99s],ax
        mov  es,[buf]
        mov  dx,f_none
        call BG_LOAD
        call ERRCODE
        mov  [bgno],ax
        push ds
        pop  es
        cmp  byte [auto],1
        je   .text
.k:     xor  ah,ah              ; BIOS: wait for Esc
        int  16h
        cmp  al,27
        jne  .k

.text:  mov  ax,0003h
        int  10h
        mov  ax,[cutres]
        mov  [got],ax
        or   ax,ax
        mov  si,m_cut
        call RESULT
        mov  ax,[redraws]
        mov  [got],ax
        cmp  ax,1
        mov  si,m_redraw
        call RESULT
        mov  ax,[dac1]
        mov  [got],ax
        or   ax,ax
        mov  si,m_dac1
        call RESULT
        mov  ax,[cutnone]
        mov  [got],ax
        cmp  ax,OWV_E_OPEN
        mov  si,m_none
        call RESULT
        mov  ax,[dac2]
        mov  [got],ax
        or   ax,ax
        mov  si,m_dac2
        call RESULT
        mov  ax,[bg1]
        mov  [got],ax
        or   ax,ax
        mov  si,m_bg1
        call RESULT
        mov  ax,[bg1s]
        mov  [got],ax
        cmp  ax,[sums+2]
        mov  si,m_bg1s
        call RESULT
        mov  ax,[bg5]
        mov  [got],ax
        or   ax,ax
        mov  si,m_bg5
        call RESULT
        mov  ax,[bg5s]
        mov  [got],ax
        cmp  ax,[sums+2+8]
        mov  si,m_bg5s
        call RESULT
        mov  ax,[bg99]
        mov  [got],ax
        cmp  ax,OWV_E_SHORT
        mov  si,m_bg99
        call RESULT
        mov  ax,[bg99s]
        mov  [got],ax
        or   ax,ax
        mov  si,m_bg99s
        call RESULT
        mov  ax,[bgno]
        mov  [got],ax
        cmp  ax,OWV_E_OPEN
        mov  si,m_bgno
        call RESULT
quit:   mov  ax,[fails]
        mov  [got],ax
        or   ax,ax
        mov  si,m_all
        call RESULT
        mov  ax,4C00h
        int  21h

; CUT_REDRAW - the "game": 16 bands of greys. Counts its calls.
CUT_REDRAW:
        push es
        mov  ax,0A000h
        mov  es,ax
        xor  di,di
        xor  dx,dx              ; DX = the row
.r:     mov  al,dl
        and  al,0F0h            ; a band of 16 rows, one grey
        mov  ah,al
        mov  cx,160             ; 320 bytes in words
        rep  stosw
        inc  dx                 ; the next row
        cmp  dx,200
        jb   .r
        inc  word [redraws]     ; one more redraw
        pop  es
        ret

; DACSAME - AX = 0 if the DAC holds gamepal exactly, else the entries off
DACSAME:
        push bx
        push cx
        push dx
        push si
        mov  dx,3C7h            ; DAC: the read index
        xor  al,al
        out  dx,al
        mov  dx,3C9h
        mov  si,gamepal
        mov  cx,768
        xor  bx,bx              ; BX = bytes that differ
.c:     in   al,dx
        cmp  al,[si]
        je   .s
        inc  bx                 ; one more off
.s:     inc  si
        loop .c
        mov  ax,bx
        pop  si
        pop  dx
        pop  cx
        pop  bx
        ret

; BUFSUM - AX = the 16-bit sum of the 64000 bytes at [buf]
BUFSUM: push bx
        push cx
        push si
        push ds
        mov  ds,[buf]
        xor  si,si
        xor  bx,bx
        xor  ah,ah
        mov  cx,64000
.s:     lodsb
        add  bx,ax              ; the sum, mod 65536
        loop .s
        mov  ax,bx
        pop  ds
        pop  si
        pop  cx
        pop  bx
        ret

; SHOWBUF - [buf] to the screen
SHOWBUF:push ds
        push es
        mov  ax,0A000h
        mov  es,ax
        mov  ds,[buf]
        xor  si,si
        xor  di,di
        mov  cx,32000           ; 64000 bytes in words
        rep  movsw
        pop  es
        pop  ds
        ret

; ERRCODE - after a call: AX = AL if CF, else 0
ERRCODE:
        jc   .c
        xor  ax,ax
        ret
.c:     xor  ah,ah
        ret

; HOLD - wait CX ticks
HOLD:   call CUT_TICK
        loop HOLD
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
.l:     lodsb
        or   al,al
        jz   .e
        mov  dl,al
        mov  ah,2
        int  21h
        jmp  .l
.e:     mov  dx,t_got
        mov  ah,9
        int  21h
        mov  ax,[got]
        xor  cx,cx              ; CX = digits stacked
        mov  bx,16              ; in hex
.d:     xor  dx,dx
        div  bx                 ; AX = AX / 16, DX = the digit (BX = 16)
        push dx
        inc  cx                 ; one more digit
        or   ax,ax
        jnz  .d
.o:     pop  dx
        add  dl,'0'             ; the digit as a character
        cmp  dl,'9'
        jbe  .o1
        add  dl,7               ; A..F
.o1:    mov  ah,2
        int  21h
        loop .o
        mov  dx,t_nl
        mov  ah,9
        int  21h
        ret

auto     db   0
got      dw   0
fails    dw   0
buf      dw   0
redraws  dw   0
cutres   dw   0
cutnone  dw   0
dac1     dw   0
dac2     dw   0
bg1      dw   0
bg1s     dw   0
bg5      dw   0
bg5s     dw   0
bg99     dw   0
bg99s    dw   0
bgno     dw   0
sums     dw   6 dup (0)
f_test   db   'VTEST.OWV',0
f_sum    db   'VTEST.SUM',0
f_none   db   'NOFILE.OWV',0
m_cut    db   'CUTSCENE VTEST.OWV: CF = 0, AL = 0 (ran to its end)',0
m_redraw db   'CUTSCENE called CUT_REDRAW once',0
m_dac1   db   'after CUTSCENE the DAC is the game palette (bytes off)',0
m_none   db   'CUTSCENE of a missing clip: CF, AL = 1',0
m_dac2   db   'after it too the DAC is the game palette (bytes off)',0
m_bg1    db   'BG_LOAD VTEST.OWV: CF = 0',0
m_bg1s   db   'BG_LOAD: the buffer sums as frame 1 (hex)',0
m_bg5    db   'BG_PICK 4: CF = 0',0
m_bg5s   db   'BG_PICK 4: the buffer sums as frame 5 (hex)',0
m_bg99   db   'BG_PICK 99 of 24: CF, AL = 5',0
m_bg99s  db   'BG_PICK 99: the buffer cleared (sum)',0
m_bgno   db   'BG_LOAD of a missing file: CF, AL = 1',0
m_all    db   'VCUT failures',0
t_pass   db   'PASS $'
t_fail   db   'FAIL $'
t_got    db   ' = $'
t_nl     db   13,10,'$'
gamepal  db   768 dup (0)

        include '..\..\KIT\REC\R_CUTSC.ASM'
        include '..\..\KIT\REC\R_STILL.ASM'
        include '..\..\KIT\LIB\K_OWV.INC'
