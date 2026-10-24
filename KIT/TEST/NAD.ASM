; NAD.ASM - KIT test for REC\R_NETAD.ASM: games announced inside a room.
; Fake ads into the list (refreshed by gid, gid 0 and other versions passed
; by, heads clamped, names printable, the list full), silent games
; dropped, the pick - join the first heard, else create - and the ad as it
; goes out. NETOPEN is never called: the wire is absent, so ADLISTEN must
; return at once. /AUTO: PASS/FAIL lines and quit; else Esc.
NETSOCK  = 4E4Eh
NETLEN   = 16
AD_PROTO = 3
        org  100h
        include '..\..\ENGINE\E_8086.INC'

start:
; ---- ads into the list --------------------------------------------------------
        mov  ax,0186h
        mov  bx,1234h
        call mkad
        mov  byte [fake+A_HEADS],0  ; 0 heads: at least 1
        mov  di,fake
        call ADTAKE
        mov  ax,0386h
        mov  bx,4321h
        call mkad
        mov  byte [fake+A_HEADS],99 ; more than a room holds: 16
        mov  di,fake
        call ADTAKE
        mov  ax,0186h               ; 0186h again: refreshed, not doubled
        mov  bx,5555h
        call mkad
        mov  byte [fake+A_NAME],9   ; a tab in the name
        mov  di,fake
        call ADTAKE
        xor  ax,ax                  ; gid 0: no game
        call mkad
        mov  di,fake
        call ADTAKE
        mov  ax,0777h               ; another version: passed by
        call mkad
        mov  byte [fake+A_PROTO],9
        mov  di,fake
        call ADTAKE
        cmp  word [ad_list+AR_GID],0186h
        jne  .f1
        cmp  word [ad_list+AR_SEED],5555h
        jne  .f1
        cmp  byte [ad_list+AR_HEAD],2
        jne  .f1
        cmp  byte [ad_list+AR_NAME],'?'
        jne  .f1
        cmp  word [ad_list+AR_SIZE+AR_GID],0386h
        jne  .f1
        cmp  byte [ad_list+AR_SIZE+AR_HEAD],16
        jne  .f1
        cmp  word [ad_list+2*AR_SIZE+AR_GID],0
        jne  .f1
        clc
        jmp  .r1
.f1:    stc
.r1:    mov  si,t1
        call result

; ---- full: two more fill the board, a fifth passes --------------------------
        mov  ax,0486h
        call mkad
        mov  di,fake
        call ADTAKE
        mov  ax,0586h
        call mkad
        mov  di,fake
        call ADTAKE
        mov  ax,0686h
        call mkad
        mov  di,fake
        call ADTAKE
        mov  bx,ad_list
        mov  cx,AD_MAX
.c2:    cmp  word [bx+AR_GID],0686h
        je   .f2
        cmp  word [bx+AR_GID],0
        je   .f2
        add  bx,AR_SIZE
        loop .c2
        clc
        jmp  .r2
.f2:    stc
.r2:    mov  si,t2
        call result

; ---- a game silent AD_GONE ticks leaves the list; the pick takes the first --
        call now
        sub  ax,AD_GONE
        mov  word [ad_list+AR_TICK],ax   ; 0186h gone quiet
        call ADSTALE
        cmp  word [ad_list+AR_GID],0
        jne  .f3
        cmp  word [ad_list+AR_SIZE+AR_GID],0386h
        jne  .f3                ; the others stay
        call ADPICK
        cmp  al,1
        jne  .f3                ; joined...
        cmp  word [ad_gid],0386h
        jne  .f3                ; ...the first row heard
        cmp  word [ad_seed],4321h
        jne  .f3
        clc
        jmp  .r3
.f3:    stc
.r3:    mov  si,t3
        call result

; ---- listening on an absent wire: at once, the list empty; then create ------
        call now
        mov  [t0],ax
        xor  bx,bx
        call ADLISTEN
        or   al,al
        jnz  .f4
        call now
        sub  ax,[t0]
        cmp  ax,1
        ja   .f4                ; no waiting for nobody
        cmp  word [ad_list+AR_SIZE+AR_GID],0
        jne  .f4
        mov  word [ntx_pid],0A86h
        call ADPICK
        or   al,al
        jnz  .f4                ; created...
        cmp  word [ad_gid],0A86h
        jne  .f4                ; ...under our own name
        test byte [ad_seed],1
        jz   .f4                ; a seed never 0
        clc
        jmp  .r4
.f4:    stc
.r4:    mov  si,t4
        call result

; ---- the ad as it goes: built whole; once in AD_EVERY ticks ----------------
        mov  word [ad_sent],0
        mov  al,3
        call ADSEND             ; due - built, then dropped by the absent wire
        call now
        cmp  ax,[ad_sent]
        jne  .f5
        cmp  byte [ad_pkt+A_KIND],'G'
        jne  .f5
        cmp  byte [ad_pkt+A_PROTO],AD_PROTO
        jne  .f5
        cmp  word [ad_pkt+A_GID],0A86h
        jne  .f5
        cmp  byte [ad_pkt+A_HEADS],3
        jne  .f5
        cmp  byte [ad_pkt+A_NAME],'M'
        jne  .f5
        mov  byte [ad_pkt+A_KIND],0
        mov  al,3
        call ADSEND             ; not due: not built again
        jnc  .f5
        cmp  byte [ad_pkt+A_KIND],0
        jne  .f5
        clc
        jmp  .r5
.f5:    stc
.r5:    mov  si,t5
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

; mkad - fake = an ad: gid AX, seed BX, 2 heads, the name GAME
mkad:   mov  di,fake
        mov  cx,NETLEN
.z:     mov  byte [di],0
        inc  di
        loop .z
        mov  byte [fake+A_KIND],'G'
        mov  byte [fake+A_PROTO],AD_PROTO
        mov  [fake+A_GID],ax
        mov  [fake+A_SEED],bx
        mov  byte [fake+A_HEADS],2
        mov  word [fake+A_NAME],'GA'
        mov  word [fake+A_NAME+2],'ME'
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
t0      dw 0
fake:   db NETLEN dup(0)      ; (a bare label: words and bytes alike)
tpass   db 'PASS $'
tfail   db 'FAIL $'
t1      db 'NAD intake: refreshed by gid, gid 0 and other versions passed, clamps, name',13,10,'$'
t2      db 'NAD the list full: the fifth game passes by',13,10,'$'
t3      db 'NAD a silent game dropped; the pick joins the first heard',13,10,'$'
t4      db 'NAD absent wire: listen returns at once; create under our name, odd seed',13,10,'$'
t5      db 'NAD the ad built whole when due, not before',13,10,'$'
tall    db 'NAD ALL PASS',13,10,'$'
tsome   db 'NAD SOME FAILED',13,10,'$'

        include '..\..\KIT\REC\R_NETAD.ASM'
        include '..\..\ENGINE\E_NET.INC'
        include '..\..\KIT\LIB\K_NETX.INC'
