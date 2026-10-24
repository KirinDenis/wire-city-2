; EMENU.ASM - test of KIT\LIB\K_MENU.INC. /AUTO: keys are put into the
; BIOS keyboard buffer (INT 16h AH=05h) before each call, so the menus run
; by themselves; the choices and the typed name are checked. Without
; /AUTO: the same menu and the name entry for a person, the answers printed.
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
; SHOW start, keys - MNU_SHOW of MENU1 with these keys waiting
macro SHOW start, keys
{
        mov  si,keys
        call FEED
        mov  si,MENU1
        mov  al,start
        mov  bx,2222h           ; (kept?)
        mov  bp,7777h
        call MNU_SHOW
        call HOLD
}

start:  call GETAUTO
        cmp  byte [auto],0
        jne  .auto
        mov  si,MENU1           ; a person: the menu, then the name
        xor  al,al
        call MNU_SHOW
        mov  [pick],ax
        mov  dx,0C04h
        mov  si,MPROMPT
        mov  di,myname
        call MNU_NAME
        mov  ax,0003h
        int  10h
        mov  dx,mpick
        mov  ah,9
        int  21h
        mov  ax,[pick]
        call PNUM
        mov  dx,mname
        mov  ah,9
        int  21h
        mov  si,myname
        call PSTR
        mov  dx,crlf
        mov  ah,9
        int  21h
        mov  ax,4C00h
        int  21h

.auto:  SHOW 0, KEY1              ; Down (skips the greyed 2), Enter
        call GRAB
        REC  3, 'MNU_SHOW Down skips a greyed item, Enter: 3'
        cmp  bx,2222h
        jne  .bad
        cmp  bp,7777h
        jne  .bad
        xor  ax,ax
        jmp  .kp
.bad:   mov  ax,1
.kp:    REC  0, 'MNU_SHOW keeps BX, BP'
        SHOW 2, KEY2              ; starts greyed -> 1; Up stays; 2 5 9 refused; 4
        REC  4, 'MNU_SHOW greyed and absent digits refused, 4 taken'
        SHOW 1, KEY3              ; Esc
        REC  0, 'MNU_SHOW Esc -> 0'
        SHOW 4, KEY4              ; Down below the last offered: stays
        REC  4, 'MNU_SHOW Down past the last offered stays: 4'
        SHOW 0, KEY5              ; '1' at once
        REC  1, 'MNU_SHOW digit 1 takes item 1'
        mov  si,KEY6
        call FEED
        mov  dx,0C04h
        mov  si,MPROMPT
        mov  di,myname          ; 'PL' in it
        mov  bx,2222h
        call MNU_NAME
        REC  13, 'MNU_NAME ends on Enter: AX = 13'
        mov  ax,cx
        REC  8, 'MNU_NAME eight letters at most'
        mov  ax,bx
        REC  2222h, 'MNU_NAME keeps BX'
        mov  si,myname          ; 'PAB1-XYZ'?
        mov  di,WANT
        mov  cx,9
        repe cmpsb
        mov  ax,0
        je   .same
        inc  ax                 ; differs: 1
.same:  REC  0, 'MNU_NAME typed PAB1-XYZ (BS, a b 1, ? refused, - x y z, q r refused)'
        call HOLD
        mov  si,KEY7
        call FEED
        mov  dx,0D04h
        mov  si,MPROMPT
        mov  di,myname
        call MNU_NAME
        REC  27, 'MNU_NAME Esc: AX = 27'
        mov  ax,0003h
        int  10h
        call PGRAB
        call PRINTREC
        mov  ax,4C00h
        int  21h

MENU1   db 'EMENU - THE PICTURE',0
        db 1,'ONE        offered',0
        db 0,'TWO        greyed',0
        db 1,'THREE      offered',0
        db 1,'FOUR       offered',0
        db 0,'FIVE       greyed',0
        db 0FFh
MPROMPT db 'YOUR NAME  ',0
WANT    db 'PAB1-XYZ',0
myname  db 'PL',0,0,0,0,0,0,0
; the keys: scan code * 256 + character, 0 ends
KEY1      dw 5000h, 1C0Dh, 0
KEY2      dw 4800h, 0332h, 0635h, 0A39h, 0534h, 0
KEY3      dw 011Bh, 0
KEY4      dw 5000h, 1C0Dh, 0
KEY5      dw 0231h, 0
KEY6      dw 0E08h, 1E61h, 3062h, 0231h, 353Fh, 0C2Dh, 2D78h, 1579h, 2C7Ah
        dw 1071h, 1372h, 1C0Dh, 0
KEY7      dw 011Bh, 0

; GRAB - the text screen's first 10 rows, characters only, into scr
GRAB:   push ax
        push cx
        push si
        push di
        push ds
        push es
        push cs
        pop  es
        mov  ax,0B800h
        mov  ds,ax
        xor  si,si
        mov  di,scr
        mov  cx,800
.g:     lodsw
        stosb
        loop .g
        pop  es
        pop  ds
        pop  di
        pop  si
        pop  cx
        pop  ax
        ret
; PGRAB - those rows to DOS, a line each
PGRAB:  mov  si,scr
        mov  bx,10
.r:     mov  cx,80
.c:     lodsb
        mov  dl,al
        mov  ah,2
        int  21h
        loop .c
        mov  dx,crlf
        mov  ah,9
        int  21h
        dec  bx
        jnz  .r
        ret

; FEED - the keys at SI into the BIOS keyboard buffer (INT 16h AH=05h)
FEED:   push ax
        push cx
        push si
.f:     lodsw
        or   ax,ax
        jz   .e
        mov  cx,ax              ; CH = scan code, CL = character
        mov  ah,05h
        int  16h
        jmp  .f
.e:     pop  si
        pop  cx
        pop  ax
        ret

; HOLD - /AUTO: 0.3 s by the BIOS tick, so the screen can be seen
HOLD:   push ax
        push cx
        push es
        xor  ax,ax
        mov  es,ax
        mov  cx,6               ; ticks
.t:     mov  ax,[es:046Ch]
.w:     cmp  ax,[es:046Ch]
        je   .w                 ; the next tick
        loop .t
        pop  es
        pop  cx
        pop  ax
        ret

; GETAUTO - [auto] = 1 if the command tail holds /AUTO
GETAUTO:mov  si,81h
        mov  cl,[80h]
        xor  ch,ch
.s:     cmp  cx,5
        jb   .no
        mov  ax,[si]
        and  ax,0DFFFh          ; 'a' -> 'A' ('/' unchanged)
        cmp  ax,'/A'
        jne  .n
        mov  ax,[si+2]
        and  ax,0DFDFh
        cmp  ax,'UT'
        jne  .n
        mov  al,[si+4]
        and  al,0DFh
        cmp  al,'O'
        jne  .n
        mov  byte [auto],1
        ret
.n:     inc  si
        dec  cx
        jmp  .s
.no:    ret

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

auto    db 0
allok   db 0
pick    dw 0
nrec    dw 0
mpick   db 'MNU_SHOW took item $'
mname   db ', the name typed: $'
mpass   db 'PASS $'
mfail   db 'FAIL $'
mgot    db '  got $'
mall    db 'ALL PASS',13,10,'$'
mnot    db 'SOME FAILED',13,10,'$'
crlf    db 13,10,'$'
scr     rb 800
rgot    rw 32
rwant   rw 32
rname   rw 32

        include '..\..\KIT\LIB\K_MENU.INC'
