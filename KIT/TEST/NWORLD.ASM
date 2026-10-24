; NWORLD.ASM - KIT test for REC\R_NETWLD.ASM and REC\R_NETHST.ASM: the
; host's world checked on the way in (bad phase dropped whole, clock and
; count clamped, cells off the grid or twice left out, names printable),
; the host's intake of hellos and requests, the world sent and read back,
; and who hosts: two hosts merge to the lower, a quiet host replaced.
; Fake packets only - no wire. /AUTO: PASS/FAIL lines and quit; else Esc.
NETSOCK = 4E4Eh
NETLEN  = 60                    ; R_NETWLD's W_LEN for these sizes
WPROTO  = 2
WMAXIT  = 6
WCELLS  = 100
WPHMAX  = 2
WCLKMAX = 500
WMAXPL  = 4
NH_GONE = 36
        org  100h
        include '..\..\ENGINE\E_8086.INC'

start:  call PEER_INIT
        mov  word [peer_me],0286h

; ---- WAPPLY: a world with traps in it --------------------------------------
        call mkw
        mov  byte [fake+W_PHASE],1
        mov  word [fake+W_CLOCK],9999   ; past the longest clock
        mov  word [fake+W_SCORE],7
        mov  byte [fake+W_NITEM],5
        mov  word [fake+W_ITEMS],10
        mov  word [fake+W_ITEMS+2],250  ; off the grid
        mov  word [fake+W_ITEMS+4],10   ; named twice
        mov  word [fake+W_ITEMS+6],20
        mov  word [fake+W_ITEMS+8],30
        mov  word [fake+W_PLAY],0186h
        mov  byte [fake+W_PLAY+2],'A'
        mov  byte [fake+W_PLAY+3],7     ; a control code in a name
        mov  byte [fake+W_PLAY+4],'B'
        mov  di,fake
        call WAPPLY
        jc   .f1
        cmp  byte [wl_phase],1
        jne  .f1
        cmp  word [wl_clock],WCLKMAX
        jne  .f1
        cmp  word [wl_score],7
        jne  .f1
        cmp  byte [wl_nitem],3
        jne  .f1
        cmp  word [wl_items],10
        jne  .f1
        cmp  word [wl_items+2],20
        jne  .f1
        cmp  word [wl_items+4],30
        jne  .f1
        cmp  word [wl_items+6],0
        jne  .f1
        cmp  word [wl_play],0186h
        jne  .f1
        cmp  byte [wl_play+3],'?'
        jne  .f1
        cmp  byte [wl_play+5],0
        jne  .f1
        clc
        jmp  .r1
.f1:    stc
.r1:    mov  si,t1
        call result

; ---- WAPPLY: a phase we do not have drops it whole; a huge count clamped --
        call mkw
        mov  byte [fake+W_PHASE],9
        mov  byte [fake+W_NITEM],1
        mov  word [fake+W_ITEMS],55
        mov  di,fake
        call WAPPLY
        jnc  .f2
        cmp  byte [wl_nitem],3      ; ours unchanged
        jne  .f2
        call mkw
        mov  byte [fake+W_NITEM],200
        mov  di,fake+W_ITEMS        ; six good distinct cells
        mov  ax,1
        mov  cx,WMAXIT
.c2:    mov  [di],ax
        add  di,2
        inc  ax
        loop .c2
        mov  di,fake
        call WAPPLY
        jc   .f2
        cmp  byte [wl_nitem],WMAXIT
        jne  .f2
        clc
        jmp  .r2
.f2:    stc
.r2:    mov  si,t2
        call result

; ---- WTAKE (host): a hello listed, requests checked -----------------------
        mov  di,wl_play             ; nobody listed
        mov  cx,WMAXPL*WPL
.z3:    mov  byte [di],0
        inc  di
        loop .z3
        call mkw
        mov  byte [fake+W_KIND],'H'
        mov  word [fake+W_ARG],'Zo'
        mov  byte [fake+W_ARG+2],200 ; a high byte
        mov  ax,0386h
        mov  di,fake
        call WTAKE
        cmp  word [wl_play],0386h
        jne  .f3
        cmp  word [wl_play+2],'Zo'
        jne  .f3
        cmp  byte [wl_play+4],'?'
        jne  .f3
        mov  word [wl_score],0      ; six items 1..6: take item 1 (cell 2)
        mov  byte [fake+W_KIND],'M'
        mov  byte [fake+W_ARG],M_TAKE
        mov  byte [fake+W_ARG+1],1
        mov  ax,0386h
        mov  di,fake
        call WTAKE
        cmp  byte [wl_nitem],WMAXIT-1
        jne  .f3
        cmp  word [wl_items+2],6    ; the last took its place
        jne  .f3
        cmp  word [wl_score],1
        jne  .f3
        mov  byte [fake+W_ARG+1],99 ; no such item
        mov  ax,0386h
        mov  di,fake
        call WTAKE
        cmp  byte [wl_nitem],WMAXIT-1
        jne  .f3
        mov  byte [fake+W_ARG+1],0  ; another version's request
        mov  byte [fake+W_PROTO],7
        mov  ax,0386h
        mov  di,fake
        call WTAKE
        cmp  byte [wl_nitem],WMAXIT-1
        jne  .f3
        clc
        jmp  .r3
.f3:    stc
.r3:    mov  si,t3
        call result

; ---- WSEND builds the world whole; read back it is the same --------------
        mov  al,1
        call WSEND              ; unnamed: not sent, but built
        mov  al,[wl_nitem]
        mov  [keepn],al
        mov  ax,[wl_score]
        mov  [keeps],ax
        mov  byte [wl_nitem],0
        mov  word [wl_score],0
        mov  di,wl_pkt
        call WAPPLY
        jc   .f4
        mov  al,[keepn]
        cmp  al,[wl_nitem]
        jne  .f4
        mov  ax,[keeps]
        cmp  ax,[wl_score]
        jne  .f4
        cmp  word [wl_play],0386h
        jne  .f4
        clc
        jmp  .r4
.f4:    stc
.r4:    mov  si,t4
        call result

; ---- NHWORLD: whose world is taken -----------------------------------------
        mov  byte [nh_mode],NH_HOST
        mov  ax,0386h           ; a host hears a higher one: keeps its own
        call NHWORLD
        jnc  .f5
        mov  ax,0186h           ; ...a lower one: gives in, its client
        call NHWORLD
        jc   .f5
        cmp  byte [nh_mode],NH_CLIENT
        jne  .f5
        cmp  word [nh_host],0186h
        jne  .f5
        mov  ax,0386h           ; a client of a talking host: not a higher
        call NHWORLD
        jnc  .f5
        call now                ; our host quiet NH_GONE: the higher carries on
        sub  ax,NH_GONE
        mov  [nh_heard],ax
        mov  ax,0386h
        call NHWORLD
        jc   .f5
        cmp  word [nh_host],0386h
        jne  .f5
        mov  byte [nh_mode],NH_JOIN ; joining: the first world heard
        mov  ax,0999h
        call NHWORLD
        jc   .f5
        mov  byte [nh_mode],NH_ALONE ; alone: none
        mov  ax,0186h
        call NHWORLD
        jnc  .f5
        clc
        jmp  .r5
.f5:    stc
.r5:    mov  si,t5
        call result

; ---- NHCLOCK: the host goes quiet - the next lowest carries on -----------
        mov  ax,0186h           ; heard: the host 0186h, and 0386h
        call PEER_HEARD
        mov  ax,0386h
        call PEER_HEARD
        mov  byte [nh_mode],NH_CLIENT
        mov  word [nh_host],0186h
        call NHHEARD
        call NHCLOCK            ; the host talks: nothing
        or   al,al
        jnz  .f6
        call now
        sub  ax,NH_GONE
        mov  [nh_heard],ax
        mov  ax,0106h           ; one lower than us heard too: he is next
        call PEER_HEARD
        call NHCLOCK
        or   al,al
        jnz  .f6
        cmp  byte [nh_mode],NH_CLIENT
        jne  .f6
        mov  ax,0106h           ; he leaves too: now it is us
        call PEER_FIND
        call PEER_DROP
        call NHCLOCK
        cmp  al,1
        jne  .f6
        cmp  byte [nh_mode],NH_HOST
        jne  .f6
        cmp  word [nh_host],0286h
        jne  .f6
        clc
        jmp  .r6
.f6:    stc
.r6:    mov  si,t6
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

; mkw - fake = an empty world packet of this game
mkw:    mov  di,fake
        mov  cx,NETLEN
.z:     mov  byte [di],0
        inc  di
        loop .z
        mov  byte [fake+W_KIND],'W'
        mov  byte [fake+W_PROTO],WPROTO
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

now:    push ds
        xor  ax,ax
        mov  ds,ax
        mov  ax,[046Ch]
        pop  ds
        ret

fails   db 0
keepn   db 0
keeps   dw 0
fake:   db NETLEN dup(0)      ; (a bare label: words and bytes alike)
tpass   db 'PASS $'
tfail   db 'FAIL $'
t1      db 'NWORLD apply: clock clamped, off-grid and twice left out, names printable',13,10,'$'
t2      db 'NWORLD apply: a bad phase drops it whole; a huge count clamped',13,10,'$'
t3      db 'NWORLD host intake: hello listed; take checked; bad item, version ignored',13,10,'$'
t4      db 'NWORLD send builds the whole world; read back the same',13,10,'$'
t5      db 'NWORLD who: hosts merge to the lower; a talking host kept; a quiet one replaced',13,10,'$'
t6      db 'NWORLD hand-over: host quiet, the next lowest heard carries on - then us',13,10,'$'
tall    db 'NWORLD ALL PASS',13,10,'$'
tsome   db 'NWORLD SOME FAILED',13,10,'$'

        include '..\..\KIT\REC\R_NETWLD.ASM'
        include '..\..\KIT\REC\R_NETHST.ASM'
        include '..\..\ENGINE\E_NET.INC'
        include '..\..\KIT\LIB\K_NETX.INC'
        include '..\..\KIT\LIB\K_PEER.INC'
