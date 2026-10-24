; NNETX.ASM - KIT test for LIB\K_NETX.INC: clamps, the name made printable,
; and the wire's absent path - the test DOSBox normally has no IPX, so
; NETOPEN says so and NTX_JOIN must come back NTX_ALONE at once, the name
; never comes, a state send is refused, a drain finds nothing.
; /AUTO: prints PASS/FAIL lines and quits. Without: waits for Esc after.
NETSOCK = 4E4Eh                 ; a palindrome socket (E_NET's rule)
NETLEN  = 16                    ; the packet's payload
NTX_WIREWT = 36                 ; short waits: a test must end in seconds
        org  100h
        include '..\..\ENGINE\E_8086.INC'

start:
; ---- NTX_CLAMP, signed ------------------------------------------------------
        mov  bx,0
        mov  dx,308
        mov  ax,500
        call NTX_CLAMP
        jnc  .f1
        cmp  ax,308
        jne  .f1
        mov  ax,-5
        call NTX_CLAMP
        jnc  .f1
        or   ax,ax
        jnz  .f1
        mov  ax,100
        call NTX_CLAMP
        jc   .f1
        cmp  ax,100
        jne  .f1
        mov  bx,-50             ; a signed range
        mov  dx,50
        mov  ax,-80
        call NTX_CLAMP
        cmp  ax,-50
        jne  .f1
        clc
        jmp  .r1
.f1:    stc
.r1:    mov  si,t1
        call result

; ---- NTX_CLAMPU, unsigned: FFFBh is big, not -5 ------------------------------
        mov  bx,0
        mov  dx,308
        mov  ax,0FFFBh
        call NTX_CLAMPU
        jnc  .f2
        cmp  ax,308
        jne  .f2
        mov  bx,10
        mov  ax,3               ; a byte under the lowest
        call NTX_CLAMPU
        jnc  .f2
        cmp  ax,10
        jne  .f2
        mov  ax,200
        call NTX_CLAMPU
        jc   .f2
        clc
        jmp  .r2
.f2:    stc
.r2:    mov  si,t2
        call result

; ---- NTX_NAME: printable copy, zeros after the first zero, in place too ----
        mov  si,rawname
        mov  di,outname
        mov  bp,5555h
        call NTX_NAME
        cmp  si,rawname         ; registers kept
        jne  .f3
        cmp  di,outname
        jne  .f3
        cmp  bp,5555h
        jne  .f3
        mov  si,outname
        mov  di,wantnm
        mov  cx,8
.c3:    mov  al,[si]
        cmp  al,[di]
        jne  .f3
        inc  si                 ; the next letter
        inc  di
        loop .c3
        mov  si,inplace         ; SI = DI
        mov  di,si
        call NTX_NAME
        cmp  byte [inplace+2],'?'
        jne  .f3
        cmp  byte [inplace+7],'?'
        jne  .f3
        clc
        jmp  .r3
.f3:    stc
.r3:    mov  si,t3
        call result

; ---- the wire: NETOPEN in the test DOSBox -----------------------------------
        call NETOPEN
        mov  dx,tnoipx
        jc   .say
        mov  dx,tipx
        mov  byte [hasipx],1
.say:   mov  ah,9
        int  21h
        cmp  byte [hasipx],0
        je   .alone
        mov  byte [net_ok],0    ; an IPX here after all: the absent path is
        mov  dx,tforce          ;  tested by switching it off (no listens
        mov  ah,9               ;  are read after this, and NETCLOSE is
        int  21h                ;  done for it below)
.alone:
; ---- NTX_JOIN with no IPX: NTX_ALONE at once, no name -----------------------
        call now
        mov  [t0],ax
        mov  ax,'W'             ; a world packet 'W', protocol 1
        mov  ah,1
        mov  bx,status          ; never called alone
        call NTX_JOIN
        cmp  al,NTX_ALONE
        jne  .f4
        or   dx,dx
        jnz  .f4
        cmp  word [ntx_pid],0
        jne  .f4
        cmp  byte [statn],0
        jne  .f4
        call now
        sub  ax,[t0]            ; ticks it took
        cmp  ax,2
        ja   .f4                ; it must not wait for an absent wire
        clc
        jmp  .r4
.f4:    stc
.r4:    mov  si,t4
        call result

; ---- no name, no send, nothing to drain --------------------------------------
        call NTX_WAITNAME
        jnz  .f5                ; never named
        or   ax,ax
        jnz  .f5
        mov  si,pkt
        mov  al,1
        call NTX_SENDST
        jnc  .f5                ; unnamed: refused
        mov  bx,handler
        call NTX_DRAIN
        or   ax,ax
        jnz  .f5
        cmp  byte [handn],0
        jne  .f5
        clc
        jmp  .r5
.f5:    stc
.r5:    mov  si,t5
        call result

; ---- named (poked) but the wire is absent: the send is dropped, kept dirty --
        mov  word [ntx_pid],1234h
        call waittk
        mov  si,pkt
        mov  al,1
        call NTX_SENDST
        jnc  .f6                ; E_NET drops it: no IPX
        cmp  byte [ntx_dirty],1 ; and it is still to go
        jne  .f6
        call now
        cmp  ax,[ntx_sent]      ; the attempt was this tick's
        jne  .f6
        clc
        jmp  .r6
.f6:    stc
.r6:    mov  word [ntx_pid],0
        mov  si,t6
        call result

; ---- with an IPX here: the real wait ends (alone or host), the caption moves
        cmp  byte [hasipx],0
        je   .r7x
        mov  byte [net_ok],1
        mov  byte [statn],0
        call now
        mov  [t0],ax
        mov  ax,0157h           ; 'W', protocol 1
        mov  bx,status
        call NTX_JOIN
        mov  [jres],al
        mov  [jdx],dx
        call now
        sub  ax,[t0]            ; ticks it took
        cmp  ax,NTX_WIREWT+NTX_JOINT+4
        ja   .f7                ; every wait is bounded
        cmp  byte [statn],0
        je   .f7                ; the caption was shown
        cmp  byte [jres],NTX_HOST
        je   .h7
        cmp  byte [jres],NTX_ALONE
        jne  .f7
        mov  dx,tj0             ; no name came: alone
        jmp  .s7
.h7:    mov  ax,[jdx]
        cmp  ax,[ntx_pid]
        jne  .f7                ; the host is us
        mov  dx,tj1             ; named, nobody answered: we host
.s7:    mov  ah,9
        int  21h
        clc
        jmp  .r7
.f7:    stc
.r7:    mov  si,t7
        call result
        mov  byte [net_ok],0
.r7x:

        cmp  byte [hasipx],0
        je   .nc
        mov  byte [net_ok],1    ; give the socket back
.nc:    call NETCLOSE

        mov  si,tall            ; the summary
        cmp  byte [fails],0
        je   .sum
        mov  si,tsome
.sum:   mov  dx,si
        mov  ah,9
        int  21h
        call isauto
        je   .x
.k:     xor  ah,ah              ; a person looks: Esc to leave
        int  16h
        cmp  ah,1
        jne  .k
.x:     mov  ax,4C00h
        int  21h

status: inc  byte [statn]       ; NTX_JOIN's caption: counted only
        ret
handler:inc  byte [handn]       ; NTX_DRAIN's: counted only
        ret

; result - CF = 0 PASS, 1 FAIL; SI -> the test's name ($)
result: mov  dx,tpass
        jnc  .p
        inc  byte [fails]       ; one more failed
        mov  dx,tfail
.p:     mov  ah,9
        int  21h
        mov  dx,si
        mov  ah,9
        int  21h
        ret

; isauto - ZF = 1 when the command line holds /AUTO
isauto: mov  si,81h
        mov  cl,[80h]
        xor  ch,ch
.l:     cmp  cx,5
        jb   .no
        cmp  word [si],'/A'
        jne  .n
        cmp  word [si+2],'UT'
        jne  .n
        cmp  byte [si+4],'O'
        je   .yes
.n:     inc  si                 ; the next character
        dec  cx                 ; one fewer left
        jmp  .l
.no:    or   sp,sp              ; ZF = 0
        ret
.yes:   cmp  al,al              ; ZF = 1
        ret

now:    push ds
        xor  ax,ax
        mov  ds,ax
        mov  ax,[046Ch]
        pop  ds
        ret
waittk: call now
        mov  bx,ax
.w:     call now
        cmp  ax,bx
        je   .w
        ret

t0      dw 0
hasipx  db 0
jres    db 0
jdx     dw 0
statn   db 0
handn   db 0
fails   db 0
rawname db 'A','B',7,'C',200,0,'x','y'
wantnm  db 'A','B','?','C','?',0,0,0
outname db 8 dup(0FFh)
inplace db 'OK',1,'GOOD',255
pkt     db NETLEN dup(0)
tpass   db 'PASS $'
tfail   db 'FAIL $'
t1      db 'NNETX clamp signed: 500->308, -5->0, 100 kept, -80->-50',13,10,'$'
t2      db 'NNETX clamp unsigned: FFFBh->308, 3->10, 200 kept',13,10,'$'
t3      db 'NNETX name: printable, zero-padded, in place, registers kept',13,10,'$'
t4      db 'NNETX join with no IPX: alone at once, no name, no caption',13,10,'$'
t5      db 'NNETX no name: waitname ZF, sendst refused, drain 0',13,10,'$'
t6      db 'NNETX a dropped send stays to go',13,10,'$'
tnoipx  db 'NNETX NETOPEN: no IPX - alone (the test DOSBox has none)',13,10,'$'
tipx    db 'NNETX NETOPEN: an IPX driver answered',13,10,'$'
t7      db 'NNETX join with IPX: the waits end, the caption moves',13,10,'$'
tj0     db 'NNETX   no address came: alone',13,10,'$'
tj1     db 'NNETX   named, nobody answered: we host',13,10,'$'
tforce  db 'NNETX (net_ok switched off to test the absent path)',13,10,'$'
tall    db 'NNETX ALL PASS',13,10,'$'
tsome   db 'NNETX SOME FAILED',13,10,'$'

        include '..\..\ENGINE\E_NET.INC'
        include '..\..\KIT\LIB\K_NETX.INC'
