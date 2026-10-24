; ============================================================================
;  GMOTION.ASM - KIT test of the moving-things recipes REC\R_PARTIC,
;  R_DEBRIS, R_BLAST, R_TRACER, R_PATROL, R_AIGUN. Mode 13h: the checks,
;  then about two seconds of smoke, a wreck falling, a fireball and its
;  cook-offs, tracer bursts; text mode 3 again, then the PASS/FAIL lines.
;      GMOTION /AUTO   checks, shows, quits;   GMOTION   shows until Esc
; ============================================================================
        org  100h
        include '..\..\ENGINE\E_8086.INC'

NEN     = 1                     ; one enemy: R_PATROL, R_AIGUN
ENBIT   = GRD_OUT               ; the bit an enemy stands on
BL_HOT  = 15                    ; R_BLAST's colours (VGA default palette)
BL_AMB  = 14
BL_RED  = 40
BL_SMK  = 24

START:  cld
        xor  ax,ax
        mov  es,ax
        mov  ax,[es:046Ch]
        or   ax,1               ; never 0
        mov  [rseed],ax
        mov  ax,13h
        int  10h                ; 320x200, 256 colours
        mov  ax,0A000h
        mov  es,ax              ; ES = the screen (the recipes draw at ES)
        xor  di,di
; ---- 0: R_PARTIC - 80 ticks: many alive, the highest well above the source
        mov  cx,80
.p0:    call PSTEP
        loop .p0
        xor  cx,cx              ; CX = alive
        mov  dx,7FFFh           ; DX = the highest (least y)
        xor  bx,bx
.p1:    cmp  word [page+bx],0
        je   .p2
        inc  cx                 ; one more alive
        mov  ax,[page+bx]
        cmp  ax,[plife+bx]
        jae  .x0                ; older than its life: wrong
        mov  ax,[ppy+bx]
        cmp  ax,dx
        jge  .p2
        mov  dx,ax              ; a new highest
.p2:    add  bx,2               ; the next one
        cmp  bx,NPART*2
        jb   .p1
        cmp  cx,20
        jb   .x0
        cmp  dx,(180-30)*16     ; 30 pixels above the source at least
        jg   .x0
        cmp  al,al
        jmp  .f0
.x0:    or   sp,sp              ; ZF=0: a fail
.f0:    call RES
; ---- 1: R_DEBRIS - 150 ticks: every piece rests on the ground, spread out
        mov  word [dbgnd],150
        mov  ax,160
        mov  bx,100
        mov  dx,0C04h
        call DEBRISAT
        mov  cx,150
.d0:    call DEBRISSTEP
        loop .d0
        xor  si,si
        xor  dx,dx              ; DX = the widest throw
.d1:    cmp  word [dby+si],150*16
        jne  .x1
        cmp  word [dbvx+si],0
        jne  .x1
        cmp  word [dbvy+si],0
        jne  .x1
        mov  ax,[dbx+si]
        sub  ax,160*16
        jns  .d2
        neg  ax
.d2:    cmp  ax,dx
        jbe  .d3
        mov  dx,ax
.d3:    add  si,2               ; the next piece
        cmp  si,NPIECE*2
        jb   .d1
        cmp  dx,3*16            ; thrown 3 pixels at least
        jb   .x1
        cmp  al,al
        jmp  .f1
.x1:    or   sp,sp
.f1:    call RES
; ---- 2: R_BLAST's schedule ----
        mov  ax,0
        call BLASTSTAGE
        jc   .x2
        cmp  cx,4
        jne  .x2
        cmp  bl,BL_HOT
        jne  .x2
        mov  ax,10
        call BLASTSTAGE
        cmp  bl,BL_AMB
        jne  .x2
        mov  ax,25
        call BLASTSTAGE         ; between the ball and the first cook-off
        jc   .x2
        or   cx,cx
        jnz  .x2
        mov  ax,30
        call BLASTSTAGE         ; the first cook-off
        jc   .x2
        cmp  si,1
        jne  .x2
        jcxz .x2
        mov  ax,200
        call BLASTSTAGE         ; long over
        jnc  .x2
        cmp  al,al
        jmp  .f2
.x2:    or   sp,sp
.f2:    call RES
; ---- 3: R_BLAST's BLDISC: round, and clipped without wrapping ----
        call CLS
        mov  ax,100
        mov  bx,100
        mov  cx,5
        mov  dl,9
        call BLDISC
        cmp  byte [es:100*320+100],9
        jne  .x3
        cmp  byte [es:100*320+105],9
        jne  .x3
        cmp  byte [es:100*320+106],0
        jne  .x3
        cmp  byte [es:94*320+100],0
        jne  .x3
        mov  ax,2
        mov  bx,2
        mov  cx,10
        call BLDISC             ; over the top left corner
        cmp  byte [es:0],9
        jne  .x3
        cmp  byte [es:1*320+319],0   ; nothing wrapped onto the right edge
        jne  .x3
        cmp  byte [es:199*320+319],0
        jmp  .f3
.x3:    or   sp,sp
.f3:    call RES
; ---- 4: R_TRACER - flight, a wall that spends it, the pool's size ----
        call TRCLR
        mov  ax,10
        mov  bx,50
        mov  cx,64              ; 4 pixels a tick
        xor  dx,dx
        call TRFIRE
        mov  si,10
.t0:    mov  dx,1               ; (no droop: tick 1)
        call TRSTEP
        dec  si
        jnz  .t0
        cmp  cx,1
        jne  .x4
        mov  bx,[trnext]
        dec  bx
        and  bx,NTRC-1
        shl  bx,1
        cmp  word [trx+bx],(10+40)*16
        jne  .x4
        call TRCLR
        mov  ax,290             ; at the wall (TRHIT: x >= 300)
        mov  bx,50
        mov  cx,64
        xor  dx,dx
        call TRFIRE
        mov  si,3
.t1:    mov  dx,1
        call TRSTEP
        dec  si
        jnz  .t1
        jcxz .t2
        jmp  .x4                ; it should be spent on the wall
.t2:    mov  si,40              ; 40 rounds into a pool of 32
.t3:    mov  ax,50
        mov  bx,100
        mov  cx,16
        mov  dx,-16
        call TRFIRE
        dec  si
        jnz  .t3
        mov  dx,1
        call TRSTEP
        cmp  cx,NTRC
        jmp  .f4
.x4:    or   sp,sp
.f4:    call RES
; ---- 5: R_PATROL - off its leash it walks home; seeing the man it hunts ----
        mov  si,PLEVEL
        xor  di,di
        call GRD_LOAD
        mov  bx,[grd_start]
        mov  [mancell],bx
        mov  ax,GRD_WALL*256 + GRD_FLOOR
        call GRD_FLOOD
        mov  bx,3*32+17
        mov  [encell],bx
        mov  word [enpost],3*32+10
        mov  byte [enon],1
        mov  al,ENBIT
        call GRD_SET
        call PATROLAI           ; the man is 18 away: no chase; post 7: home
        cmp  byte [endem],3
        jne  .x5
        mov  bx,[mancell]       ; the man walks to (17,1)
        mov  al,GRD_MAN
        call GRD_CLR
        mov  bx,1*32+17
        call GRD_SET
        mov  [mancell],bx
        mov  word [enpost],3*32+17   ; and the enemy's post is where it is
        call PATROLAI           ; 2 away: it hunts - up
        cmp  byte [endem],0
        jne  .x5
        mov  dx,ENSTEP
        call PATROLMOVE         ; one step: (17,2)
        jc   .x5
        cmp  word [encell],2*32+17
        jne  .x5
        test byte [grd_map+2*32+17],ENBIT
        jz   .x5
        test byte [grd_map+3*32+17],ENBIT
        jnz  .x5                ; its old cell let go
        call PATROLAI
        mov  dx,ENSTEP
        call PATROLMOVE         ; it walks into him
        jnc  .x5
        cmp  al,0
        jmp  .f5
.x5:    or   sp,sp
.f5:    call RES
; ---- 6: R_AIGUN - in range a 4-round burst; out of range nothing ----
        call TRCLR
        mov  word [enx],100
        mov  word [eny],100
        mov  word [plx],150
        mov  word [ply],100
        mov  dx,AIGT
        call AIGUN
        mov  dx,1
        call TRSTEP
        cmp  cx,4
        jne  .x6
        call TRCLR
        mov  word [plx],300     ; too far
        mov  dx,AIGT
        call AIGUN
        jc   .x6
        mov  dx,1
        call TRSTEP
        jcxz .f6
.x6:    or   sp,sp
.f6:    call RES

; ---- the show: about 2 s (until Esc without /AUTO) ----
        call AUTO
        mov  al,0
        adc  al,0
        mov  [manual],al        ; 1: a person watches
        call TRCLR
        mov  word [blage],1
        mov  ax,80
        mov  bx,120
        mov  dx,0C04h
        call DEBRISAT
        call TICKNOW
        mov  [t0],ax
        mov  [tlast],ax
.show:  call TICKNOW
        cmp  ax,[tlast]
        je   .draw
        mov  [tlast],ax
        mov  dx,ax
        call PSTEP              ; one tick of everything
        call DEBRISSTEP
        call TRSTEP
        inc  word [blage]
        test dx,7
        jnz  .draw
        mov  ax,40              ; a burst now and then
        mov  bx,190
        mov  cx,48
        mov  dx,-80
        call TRFIRE
        add  cx,8
        call TRFIRE
        add  cx,8
        call TRFIRE
.draw:  call WAITVR
        call CLS
        call PDRAW
        call DEBRISDRAW
        call TRDRAW
        mov  ax,240
        mov  bx,120
        mov  cx,[blage]
        call BLASTDRAW
        jnc  .k
        mov  word [blage],1     ; over: another
        mov  ax,80
        mov  bx,120
        mov  dx,0C04h
        call DEBRISAT
.k:     mov  ah,1
        int  16h
        jz   .tm
        mov  ah,0
        int  16h
        cmp  ah,1
        je   .end               ; Esc
.tm:    cmp  byte [manual],0
        jne  .show
        call TICKNOW
        sub  ax,[t0]
        cmp  ax,36              ; two seconds by the BIOS tick
        jb   .show
.end:   xor  di,di              ; 7: the last frame drew something
        xor  dx,dx
        mov  cx,64000
.cnt:   cmp  byte [es:di],0
        je   .cn
        inc  dx                 ; one more lit pixel
.cn:    inc  di
        loop .cnt
        cmp  dx,60
        mov  al,0
        adc  al,0               ; AL = 1 if fewer than 60
        or   al,al
        call RES
        mov  ax,3
        int  10h                ; text mode again
        push ds
        pop  es
; ---- the lines ----
        xor  si,si
.l:     mov  bx,si
        shl  bx,1
        mov  dx,[NAMES+bx]
        or   dx,dx
        jz   .ld
        mov  al,[results+si]
        or   al,al
        call ZREP
        inc  si
        jmp  .l
.ld:    jmp  DONE

; RES - result ZF (1 pass) into results[nres]
RES:    push bx
        mov  bx,[nres]
        mov  byte [results+bx],0
        jz   .p
        mov  byte [results+bx],1
.p:     inc  word [nres]        ; the next check's place
        pop  bx
        ret
; TRCLR - no round in the air
TRCLR:  push bx
        xor  bx,bx
.c:     mov  word [trlif+bx],0
        add  bx,2               ; the next round
        cmp  bx,NTRC*2
        jb   .c
        pop  bx
        ret
; TRHIT - R_TRACER's question: a wall at x >= 300
TRHIT:  cmp  ax,300             ; CF=1 if x < 300...
        cmc                     ; ...so CF=1 if x >= 300: a hit
        ret
; CLS - the screen black
CLS:    push ax
        push cx
        push di
        xor  di,di
        xor  ax,ax
        mov  cx,32000
        rep  stosw
        pop  di
        pop  cx
        pop  ax
        ret
; WAITVR - the start of the vertical retrace
WAITVR: push ax
        push dx
        mov  dx,3DAh
.a:     in   al,dx
        test al,8
        jnz  .a                 ; in one: let it end
.b:     in   al,dx
        test al,8
        jz   .b                 ; the next one begins
        pop  dx
        pop  ax
        ret
; TICKNOW - AX = the BIOS tick
TICKNOW:push es
        xor  ax,ax
        mov  es,ax
        mov  ax,[es:046Ch]
        pop  es
        ret

; ---- the test's frame: ZREP, DONE ------------------------------------------
; ZREP - PASS if ZF=1, else FAIL, then the name at DX ('$' ended)
ZREP:   mov  bx,T_PASS
        jz   .p
        mov  bx,T_FAIL
        inc  byte [fails]       ; one more failed
.p:     push dx
        mov  dx,bx
        mov  ah,9
        int  21h
        pop  dx
        mov  ah,9
        int  21h
        mov  dx,T_CRLF
        mov  ah,9
        int  21h
        ret

DONE:   mov  dx,T_ALL
        cmp  byte [fails],0
        je   .p
        mov  dx,T_SOME
.p:     mov  ah,9
        int  21h
        call AUTO
        jnc  .q                 ; /AUTO: quit now
.k:     mov  ah,0
        int  16h                ; wait for a key
        cmp  ah,1
        jne  .k                 ; Esc only
.q:     mov  ax,3
        int  10h                ; text mode 3 (we never left it)
        mov  ax,4C00h
        int  21h

; AUTO - CF=0 if the command line holds /AUTO
AUTO:   mov  si,81h
        mov  cl,[80h]
        xor  ch,ch              ; CX = the tail's length
.a:     jcxz .no
        cmp  byte [si],'/'
        jne  .n
        cmp  byte [si+1],'A'
        je   .yes
.n:     inc  si                 ; the next letter
        dec  cx                 ; one fewer
        jmp  .a
.yes:   clc
        ret
.no:    stc
        ret

fails   db 0
T_PASS  db 'PASS $'
T_FAIL  db 'FAIL $'
T_CRLF  db 13,10,'$'
T_ALL   db 'GMOTION: ALL PASS',13,10,'$'
T_SOME  db 'GMOTION: SOME FAILED',13,10,'$'
T_0     db 'GMOTION R_PARTIC 80 ticks: a thread of smoke risen 30 px, none past its life$'
T_1     db 'GMOTION R_DEBRIS every piece thrown, fallen and resting on the ground$'
T_2     db 'GMOTION R_BLAST the schedule: hot ball, cooling, a gap, a cook-off, over$'
T_3     db 'GMOTION R_BLAST BLDISC round, clipped at the corner, nothing wrapped$'
T_4     db 'GMOTION R_TRACER flies 4 px a tick, spent on a wall, a pool of 32$'
T_5     db 'GMOTION R_PATROL off the leash home, then hunts by the path and reaches him$'
T_6     db 'GMOTION R_AIGUN a 4-round burst in range, nothing out of range$'
T_7     db 'GMOTION the show drew smoke, wreck, fireball, tracers (60+ pixels)$'
NAMES   dw T_0, T_1, T_2, T_3, T_4, T_5, T_6, T_7, 0
results rb 8
nres    dw 0
manual  db 0
t0      dw 0
tlast   dw 0
blage   dw 0
mancell dw 0
rseed   dw 1
enx     dw NEN dup 0
eny     dw NEN dup 0
plx     dw 0
ply     dw 0
PLEVEL  db 20,5
        db '####################'
        db '#@                 #'
        db '#                  #'
        db '#                  #'
        db '####################'

        include '..\..\ENGINE\E_MATH.INC'
        include '..\..\KIT\LIB\K_GRID.INC'
        include '..\..\KIT\REC\R_PARTIC.ASM'
        include '..\..\KIT\REC\R_DEBRIS.ASM'
        include '..\..\KIT\REC\R_BLAST.ASM'
        include '..\..\KIT\REC\R_TRACER.ASM'
        include '..\..\KIT\REC\R_AIGUN.ASM'
        include '..\..\KIT\REC\R_PATROL.ASM'
dbgnd   dw 150
