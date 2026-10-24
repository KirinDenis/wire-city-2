; NPEER.ASM - KIT test for LIB\K_PEER.INC: the player table, fed fake
; packets - heard, full, timeout (by poking the heard tick), host election
; with given names, colours for the relay's names, the heartbeat clock,
; and that the routines keep the registers they promise to keep.
; /AUTO: prints PASS/FAIL lines and quits. Without: waits for Esc after.
PEER_MAX  = 4                   ; small, so "full" is quick to reach
PEER_USER = 3                   ; rounded to 4 in the slot
        org  100h
        include '..\..\ENGINE\E_8086.INC'

start:  call PEER_INIT
        mov  word [peer_me],0286h

; ---- heard: a new slot, then the same slot again --------------------------
        mov  ax,0186h
        call PEER_HEARD
        jc   .f1
        cmp  ax,1               ; new?
        jne  .f1
        mov  [slot1],bx
        cmp  word [bx+PEER_PID],0186h
        jne  .f1
        mov  ax,0186h
        call PEER_HEARD
        jc   .f1
        or   ax,ax              ; known now
        jnz  .f1
        cmp  bx,[slot1]
        jne  .f1
        clc
        jmp  .r1
.f1:    stc
.r1:    mov  si,t1
        call result

; ---- our own name and 0 are not players ------------------------------------
        mov  ax,0286h
        call PEER_HEARD
        jnc  .f2
        xor  ax,ax
        call PEER_HEARD
        jnc  .f2
        clc
        jmp  .r2
.f2:    stc
.r2:    mov  si,t2
        call result

; ---- find: known found, stranger not ---------------------------------------
        mov  ax,0186h
        call PEER_FIND
        jc   .f3
        cmp  bx,[slot1]
        jne  .f3
        mov  ax,0999h
        call PEER_FIND
        jnc  .f3
        clc
        jmp  .r3
.f3:    stc
.r3:    mov  si,t3
        call result

; ---- full: four slots, the fifth refused; count 4 ------------------------
        mov  ax,0386h
        call PEER_HEARD
        mov  [slot3],bx
        mov  ax,0486h
        call PEER_HEARD
        mov  ax,0586h
        call PEER_HEARD
        jc   .f4
        mov  ax,0686h
        call PEER_HEARD
        jnc  .f4                ; must be full
        call PEER_COUNT
        cmp  ax,4
        jne  .f4
        clc
        jmp  .r4
.f4:    stc
.r4:    mov  si,t4
        call result

; ---- timeout: 0386h made old -> freed once, then nobody more -------------
        call now
        sub  ax,PEER_GONE+1     ; heard GONE+1 ticks ago
        mov  bx,[slot3]
        mov  [bx+PEER_TICK],ax
        mov  word [bx+PEER_U],1234h ; his last place, to erase him by
        call PEER_TIMEOUT
        jc   .f5
        cmp  bx,[slot3]
        jne  .f5
        cmp  word [bx+PEER_PID],0
        jne  .f5
        cmp  word [bx+PEER_U],1234h ; still readable after the drop
        jne  .f5
        call PEER_TIMEOUT
        jnc  .f5                ; nobody else is old
        call PEER_COUNT
        cmp  ax,3
        jne  .f5
        clc
        jmp  .r5
.f5:    stc
.r5:    mov  si,t5
        call result

; ---- the freed slot is taken again by a newcomer --------------------------
        mov  ax,0686h
        call PEER_HEARD
        jc   .f6
        cmp  bx,[slot3]
        jne  .f6
        cmp  word [bx+PEER_U],0 ; zeroed for him
        jne  .f6
        clc
        jmp  .r6
.f6:    stc
.r6:    mov  si,t6
        call result

; ---- host: lowest of us (0286h) and 0186h 0486h 0586h 0686h --------------
        xor  dx,dx
        call PEER_HOST
        jz   .f7                ; not us
        cmp  ax,0186h
        jne  .f7
        mov  dx,0186h           ; leave the quiet host out: we are next
        call PEER_HOST
        jnz  .f7
        cmp  ax,0286h
        jne  .f7
        mov  bx,[slot1]         ; 0186h not heard for GONE ticks: not counted
        call now
        sub  ax,PEER_GONE
        mov  [bx+PEER_TICK],ax
        xor  dx,dx
        call PEER_HOST
        jnz  .f7
        cmp  ax,0286h
        jne  .f7
        mov  word [peer_me],0       ; not named: alone, our own host
        call PEER_HOST
        jnz  .f7
        or   ax,ax
        jnz  .f7
        mov  word [peer_me],0586h   ; a second host that hears a lower
        call now                    ;  one: both get the lower - they merge
        mov  bx,[slot1]
        mov  [bx+PEER_TICK],ax
        call PEER_HOST
        jz   .f7
        cmp  ax,0186h
        jne  .f7
        clc
        jmp  .r7
.f7:    stc
.r7:    mov  word [peer_me],0286h
        mov  si,t7
        call result

; ---- colours: 0186h 0286h 0386h distinct, 0..7, as stored in the slot -----
        mov  ax,0186h
        call PEER_COLOR
        mov  bl,al
        mov  ax,0286h
        call PEER_COLOR
        mov  bh,al
        mov  ax,0386h
        call PEER_COLOR
        cmp  al,7
        ja   .f8
        cmp  bl,7
        ja   .f8
        cmp  bh,7
        ja   .f8
        cmp  al,bl
        je   .f8
        cmp  al,bh
        je   .f8
        cmp  bl,bh
        je   .f8
        mov  si,[slot1]         ; 0186h's slot carries the same
        cmp  [si+PEER_CI],bl
        jne  .f8
        clc
        jmp  .r8
.f8:    stc
.r8:    mov  si,t8
        call result

; ---- beat: a change goes at once, not twice a tick, then on the beat ------
        mov  word [peer_me],0
        mov  al,1
        call PEER_BEAT
        jnc  .f9                ; unnamed: never
        mov  word [peer_me],0286h
        call waittk             ; a fresh tick
        mov  al,1
        call PEER_BEAT
        jc   .f9                ; changed: now
        mov  al,1
        call PEER_BEAT
        jnc  .f9                ; the same tick: not again
        call waittk
        xor  al,al
        call PEER_BEAT
        jc   .f9                ; the change kept: it goes on the next tick
        call waittk
        xor  al,al
        call PEER_BEAT
        jnc  .f9                ; nothing changed, beat not due
        call now
        sub  ax,PEER_EVERY      ; the last send a beat ago
        mov  [peer_sent],ax
        xor  al,al
        call PEER_BEAT
        jc   .f9                ; the heartbeat
        clc
        jmp  .r9
.f9:    stc
.r9:    mov  si,t9
        call result

; ---- registers kept: CX DX SI DI BP across HEARD, HOST, TIMEOUT, BEAT ----
        mov  cx,1111h
        mov  dx,2222h
        mov  si,3333h
        mov  di,4444h
        mov  bp,5555h
        mov  ax,0186h
        call PEER_HEARD
        call PEER_TIMEOUT
        mov  dx,2222h           ; (DX is PEER_HOST's input: it must stay)
        call PEER_HOST
        call PEER_BEAT
        call PEER_COUNT
        cmp  cx,1111h
        jne  .fa
        cmp  dx,2222h
        jne  .fa
        cmp  si,3333h
        jne  .fa
        cmp  di,4444h
        jne  .fa
        cmp  bp,5555h
        jne  .fa
        clc
        jmp  .ra
.fa:    stc
.ra:    mov  si,ta
        call result

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

; now - AX = the BIOS tick; waittk - until it moves on
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

slot1   dw 0
slot3   dw 0
fails   db 0
tpass   db 'PASS $'
tfail   db 'FAIL $'
t1      db 'NPEER heard: a new slot, the same slot again',13,10,'$'
t2      db 'NPEER heard: our own name and 0 are refused',13,10,'$'
t3      db 'NPEER find: known found, a stranger not',13,10,'$'
t4      db 'NPEER full: 4 slots taken, the fifth refused, count 4',13,10,'$'
t5      db 'NPEER timeout: the old one freed once, his data readable',13,10,'$'
t6      db 'NPEER a freed slot taken again, zeroed',13,10,'$'
t7      db 'NPEER host: lowest heard; quiet one left out; old not counted; merge',13,10,'$'
t8      db 'NPEER colour: 0186h 0286h 0386h distinct in 0..7',13,10,'$'
t9      db 'NPEER beat: change at once, once a tick, kept, then the heartbeat',13,10,'$'
ta      db 'NPEER registers kept: CX DX SI DI BP',13,10,'$'
tall    db 'NPEER ALL PASS',13,10,'$'
tsome   db 'NPEER SOME FAILED',13,10,'$'

        include '..\..\KIT\LIB\K_PEER.INC'
