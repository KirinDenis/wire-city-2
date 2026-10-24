; NSTATE.ASM - KIT test for REC\R_NETST.ASM: the state-not-events packet,
; fed fake packets from "0186h" while we are 0286h - his state clamped into
; his slot, his hit applied ONCE however often it comes and echoed in our
; state, our own hit repeated until his state shows it, an event for
; someone who left dropped. /AUTO: PASS/FAIL lines and quit; else Esc.
NETSOCK   = 4E4Eh
NETLEN    = 16
PEER_USER = 8                   ; R_NETST's SU_LEN
ST_PROTO  = 1
ST_XMAX   = 308
ST_YMAX   = 188
ST_HPMAX  = 10
ST_NLOOK  = 4
        org  100h
        include '..\..\ENGINE\E_8086.INC'

start:  call PEER_INIT
        mov  word [peer_me],0286h

; ---- his state into his slot, clamped -------------------------------------
        call mkpkt              ; a packet from him, x past the screen
        mov  word [fake+S_X],9999
        mov  byte [fake+S_LOOK],77
        mov  byte [fake+S_HP],200
        mov  ax,0186h
        mov  di,fake
        call STTAKE
        mov  ax,0186h
        call PEER_FIND
        jc   .f1
        cmp  word [bx+SU_X],ST_XMAX
        jne  .f1
        cmp  word [bx+SU_Y],50
        jne  .f1
        cmp  byte [bx+SU_LOOK],ST_NLOOK-1
        jne  .f1
        cmp  byte [bx+SU_HP],ST_HPMAX
        jne  .f1
        clc
        jmp  .r1
.f1:    stc
.r1:    mov  si,t1
        call result

; ---- his hit (3) applied once though it comes three times; echoed --------
        call mkpkt
        mov  word [fake+S_EVTO],0286h
        mov  byte [fake+S_EVSEQ],1
        mov  byte [fake+S_EVARG],3
        mov  cx,3
.h2:    push cx
        mov  ax,0186h
        mov  di,fake
        call STTAKE
        pop  cx
        loop .h2
        cmp  byte [st_hp],ST_HPMAX-3
        jne  .f2
        call STPACK
        cmp  word [st_pkt+S_ACKTO],0186h
        jne  .f2
        cmp  byte [st_pkt+S_ACKSQ],1
        jne  .f2
        mov  byte [fake+S_EVSEQ],2  ; his next hit: applied
        mov  ax,0186h
        mov  di,fake
        call STTAKE
        cmp  byte [st_hp],ST_HPMAX-6
        jne  .f2
        mov  byte [fake+S_EVSEQ],3  ; a hit past our health: 0, not 255
        mov  byte [fake+S_EVARG],50
        mov  ax,0186h
        mov  di,fake
        call STTAKE
        cmp  byte [st_hp],0
        jne  .f2
        clc
        jmp  .r2
.f2:    stc
.r2:    mov  si,t2
        call result

; ---- our hit to him: in every packet until his state shows it ------------
        mov  ax,0186h
        mov  cl,5
        call STEVENT
        mov  byte [st_chg],0
        call mkpkt              ; his state, no echo yet
        mov  ax,0186h
        mov  di,fake
        call STTAKE
        call STPACK
        cmp  word [st_pkt+S_EVTO],0186h
        jne  .f3                ; still riding
        cmp  byte [st_pkt+S_EVARG],5
        jne  .f3
        mov  al,[st_evseq]
        mov  word [fake+S_ACKTO],0286h ; his state: "applied 0286h's N"
        mov  [fake+S_ACKSQ],al
        mov  ax,0186h
        mov  di,fake
        call STTAKE
        call STPACK
        cmp  word [st_pkt+S_EVTO],0
        jne  .f3                ; taken: no more
        clc
        jmp  .r3
.f3:    stc
.r3:    mov  si,t3
        call result

; ---- an event for one who is not here is dropped; a foreign packet too ---
        mov  ax,0999h
        mov  cl,1
        call STEVENT
        call STPACK
        cmp  word [st_pkt+S_EVTO],0
        jne  .f4
        call mkpkt
        mov  byte [fake+S_PROTO],9  ; another version
        mov  word [fake+S_X],100
        mov  ax,0186h
        mov  di,fake
        call STTAKE
        mov  ax,0186h
        call PEER_FIND
        cmp  word [bx+SU_X],40   ; unchanged by it (40 from the last)
        jne  .f4
        clc
        jmp  .r4
.f4:    stc
.r4:    mov  si,t4
        call result

        mov  si,tall
        cmp  byte [fails],0
        je   .sum
        mov  si,tsome
.sum:   mov  dx,si
        mov  ah,9
        int  21h
        call isauto
        je   .x
.k:     xor  ah,ah
        int  16h
        cmp  ah,1
        jne  .k
.x:     mov  ax,4C00h
        int  21h

; mkpkt - fake = a plain state packet from him: x 40, y 50, no event
mkpkt:  mov  di,fake
        mov  cx,NETLEN
.z:     mov  byte [di],0
        inc  di
        loop .z
        mov  byte [fake+S_KIND],'S'
        mov  byte [fake+S_PROTO],ST_PROTO
        mov  word [fake+S_X],40
        mov  word [fake+S_Y],50
        mov  byte [fake+S_HP],ST_HPMAX
        ret

result: mov  dx,tpass
        jnc  .p
        inc  byte [fails]
        mov  dx,tfail
.p:     mov  ah,9
        int  21h
        mov  dx,si
        mov  ah,9
        int  21h
        ret

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
.n:     inc  si
        dec  cx
        jmp  .l
.no:    or   sp,sp
        ret
.yes:   cmp  al,al
        ret

fails   db 0
fake:   db NETLEN dup(0)      ; (a bare label: words and bytes alike)
tpass   db 'PASS $'
tfail   db 'FAIL $'
t1      db 'NSTATE his state clamped into his slot',13,10,'$'
t2      db 'NSTATE his hit applied once of three, echoed; next applied; floor 0',13,10,'$'
t3      db 'NSTATE our hit repeats until his state shows it',13,10,'$'
t4      db 'NSTATE event for one not here dropped; another version ignored',13,10,'$'
tall    db 'NSTATE ALL PASS',13,10,'$'
tsome   db 'NSTATE SOME FAILED',13,10,'$'

        include '..\..\KIT\REC\R_NETST.ASM'
        include '..\..\ENGINE\E_NET.INC'
        include '..\..\KIT\LIB\K_NETX.INC'
        include '..\..\KIT\LIB\K_PEER.INC'
