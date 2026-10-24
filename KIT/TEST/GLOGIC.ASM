; ============================================================================
;  GLOGIC.ASM - KIT test of the game-logic recipes REC\R_CAMERA, R_LEVELS,
;  R_TIMERS, R_STATE, R_SCRIPT, R_SPAWN, R_LAND, R_DAMAGE. It writes a
;  little LEVELS.DAT beside itself, reads it back, and deletes it.
;  Text only: PASS/FAIL lines through DOS.
;      GLOGIC /AUTO   checks and quits;   GLOGIC   checks, then waits for Esc
; ============================================================================
        org  100h
        include '..\..\ENGINE\E_8086.INC'

START:  cld
        xor  ax,ax
        mov  es,ax
        mov  ax,[es:046Ch]
        or   ax,1               ; never 0
        mov  [rseed],ax
        push ds
        pop  es
; ---- R_CAMERA ----
        mov  dx,T_CAM
        mov  ax,200             ; a map that fits: centred
        mov  cx,320
        mov  bx,50
        xor  si,si
        mov  dx,0
        call CAMAXIS
        cmp  dx,60
        jne  .x0
        mov  ax,640             ; a wide map, a new level: he in the middle
        mov  bx,320
        mov  si,1
        call CAMAXIS
        cmp  dx,-160
        jne  .x0
        xor  si,si
        mov  bx,420             ; he walks right past the band: it follows
        call CAMAXIS
        cmp  dx,-180
        jne  .x0
        mov  dx,-160
        mov  bx,10              ; far left: the map's edge stops it
        call CAMAXIS
        cmp  dx,0
        jne  .x0
        mov  bx,630             ; far right: the other edge
        call CAMAXIS
        cmp  dx,-320
        jmp  .f0
.x0:    or   sp,sp              ; ZF=0: a fail
.f0:    mov  dx,T_CAM
        call ZREP
; ---- R_LEVELS: write LEVELS.DAT, find our folder, read it back ----
        mov  dx,LEVFNAME
        xor  cx,cx
        mov  ah,3Ch
        int  21h                ; create it, here
        jc   .x1
        mov  bx,ax
        mov  dx,DATIMG
        mov  cx,DATEND-DATIMG
        mov  ah,40h
        int  21h                ; the image
        mov  ah,3Eh
        int  21h                ; closed
        call FINDDIR
        mov  si,levpath         ; it must end in TEST\LEVELS.DAT
.e:     lodsb
        or   al,al
        jnz  .e
        sub  si,1+15            ; the last 15 letters
        cmp  si,levpath
        jb   .x1
        mov  di,T_TAIL
        mov  cx,15
        repe cmpsb
        jne  .x1
        call LEVTABLE
        jc   .x1
        cmp  word [nlev],2
        jne  .x1
        mov  bx,1
        call LEVREAD            ; the second level
        jc   .x1
        mov  si,levbuf
        xor  di,di
        call GRD_LOAD
        jc   .x1
        cmp  byte [grd_w],4
        jne  .x1
        cmp  word [grd_start],1*32+1
        jne  .x1
        mov  bx,2
        call LEVREAD            ; no third level
        jnc  .x1
        cmp  al,al
        jmp  .f1
.x1:    or   sp,sp
.f1:    mov  dx,T_LEV
        call ZREP
        mov  dx,LEVFNAME
        mov  ah,41h
        int  21h                ; deleted
        call LEVTABLE           ; and now it is not there
        mov  dx,T_LEV2
        mov  al,0
        adc  al,0
        cmp  al,1
        call ZREP
; ---- R_TIMERS ----
        mov  word [clocks],3
        mov  word [clocks+2],100
        xor  ax,ax
        mov  es,ax
        mov  ax,[es:046Ch]
        push ds
        pop  es
        sub  ax,5               ; "the last call was 5 ticks ago"
        mov  [tmlast],ax
        call TIMERS
        cmp  ax,1               ; clock 0 ran out, only it
        jne  .x2
        cmp  word [clocks],0
        jne  .x2
        cmp  cx,1               ; clock 1 still runs
        jne  .x2
        cmp  dx,5
        jb   .x2
        cmp  dx,6               ; (a tick may pass meanwhile)
        ja   .x2
        mov  ax,100
        sub  ax,dx
        cmp  [clocks+2],ax
        jne  .x2
        sub  word [tmlast],1000 ; a long stall: counted as 2 s at most
        call TIMERS
        cmp  dx,TMCAP
        jne  .x2
        call TIMOFF             ; paused: nothing counts
        call TIMERS
        cmp  dx,1
        ja   .x2
        cmp  al,al
        jmp  .f2
.x2:    or   sp,sp
.f2:    mov  dx,T_TIM
        call ZREP
; ---- R_STATE ----
        mov  ah,0
        call STATETICK          ; no key: still the title
        cmp  byte [state],ST_TITLE
        jne  .x3
        call CARDTEXT
        cmp  si,TITLETXT
        jne  .x3
        mov  ah,1Ch
        call STATETICK          ; Enter: a game
        cmp  byte [state],ST_PLAY
        jne  .x3
        cmp  byte [ngames],1
        jne  .x3
        call CARDTEXT
        or   si,si
        jnz  .x3
        mov  byte [playleft],3
        mov  ah,0
        call STATETICK
        call STATETICK
        cmp  byte [state],ST_PLAY
        jne  .x3
        call STATETICK          ; the third: over
        cmp  byte [state],ST_END
        jne  .x3
        call CARDTEXT
        cmp  si,T_OVER
        jne  .x3
        mov  cx,CARDHOLD
.h:     mov  ah,1               ; a key held: the card holds anyway
        call STATETICK
        loop .h
        cmp  byte [state],ST_END
        jne  .x3
        call STATETICK          ; now the key counts
        cmp  byte [state],ST_TITLE
        jmp  .f3
.x3:    or   sp,sp
.f3:    mov  dx,T_STATE
        call ZREP
; ---- R_SCRIPT: (3 ticks +2,-1) then (2 ticks 0,+5) ----
        mov  word [sca],0
        mov  word [scb],0
        mov  word [scpa],sca
        mov  word [scpb],scb
        mov  bx,SHOW
        call SCRSTART
        mov  cx,5
.sc:    call SCRSTEP
        jc   .x4
        loop .sc
        call SCRSTEP            ; the sixth: over
        jnc  .x4
        cmp  word [sca],6
        jne  .x4
        cmp  word [scb],7
        jmp  .f4
.x4:    or   sp,sp
.f4:    mov  dx,T_SCR
        call ZREP
; ---- R_SPAWN: 50 prizes, each on bare floor; none where nothing fits ----
        mov  si,LEVEL
        xor  di,di
        call GRD_LOAD
        mov  bx,[grd_start]
        mov  ax,GRD_WALL*256 + GRD_FLOOR
        call GRD_FLOOD
        mov  cx,50
.sp:    mov  al,GRD_WALL+GRD_BOX+GRD_MAN+GRD_GOAL+GRD_ITEM+GRD_FLOOR
        mov  ah,GRD_FLOOR
        call SPAWNAT
        jc   .x5
        mov  al,[grd_map+bx]
        cmp  al,GRD_FLOOR       ; bare floor and nothing else
        jne  .x5
        loop .sp
        mov  ax,GRD_ITEM*256 + GRD_ITEM
        call SPAWNAT            ; no item anywhere: none
        jnc  .x5
        mov  bx,3*32+3
        call MINESET
        jc   .x5
        call MINESET            ; one at a time
        jnc  .x5
        mov  dx,FUSE-1
        call MINETICK
        jc   .x5                ; not yet
        mov  dx,1
        call MINETICK           ; now
        jnc  .x5
        mov  bx,4*32+4          ; a corner of the nine: caught
        call INBLAST
        jnc  .x5
        mov  bx,3*32+5          ; two away: safe
        call INBLAST
        jc   .x5
        mov  dx,BLASTT
        call MINETICK           ; the blast fades: gone
        jc   .x5
        cmp  word [minecell],0FFFFh
        jmp  .f5
.x5:    or   sp,sp
.f5:    mov  dx,T_SPAWN
        call ZREP
; ---- R_LAND ----
        mov  word [vgear],1
        mov  word [vsink],300
        mov  word [vside],-5
        mov  si,RULES
        call JUDGE
        jnc  .x6
        cmp  si,T_M2            ; the sink broke it
        jne  .x6
        mov  word [vsink],100
        mov  si,RULES
        call JUDGE
        jnc  .x6
        cmp  si,T_M3            ; now the side
        jne  .x6
        mov  word [vside],0
        mov  si,RULES
        call JUDGE              ; all kept
        jc   .x6
        mov  word [vgear],0
        mov  si,RULES
        call JUDGE
        jnc  .x6
        cmp  si,T_M1            ; no gear comes first
        jne  .x6
        mov  word [vgear],62000
        mov  si,RULEU
        call JUDGE              ; unsigned: 62000 > 1000
        jnc  .x6
        cmp  si,T_M1
        jmp  .f6
.x6:    or   sp,sp
.f6:    mov  dx,T_JUDGE
        call ZREP
; ---- R_DAMAGE ----
        xor  bx,bx              ; cell 0 (the table's trap)
        mov  al,2
        call HIT                ; fresh: 2 more to go
        jc   .x7
        call RUINED
        jnz  .x7
        call HIT
        jc   .x7
        call HIT                ; the last
        jnc  .x7
        call RUINED
        jz   .x7
        inc  bx
        call RUINED             ; cell 1 stands
        jnz  .x7
        dec  bx
        call HIT                ; rubble is not hit again
        jc   .x7
        mov  al,1
        mov  bx,10
        call HIT
        mov  bx,11
        call HIT
        mov  bx,12
        call HIT
        mov  bx,13
        call HIT
        mov  bx,14
        call HIT                ; the fifth wound: the oldest (10) forgotten
        mov  bx,10
        call HIT                ; so 10 starts again
        jc   .x7
        mov  bx,12
        call HIT                ; 12 is still remembered: it falls
        jnc  .x7
        cmp  al,al
        jmp  .f7
.x7:    or   sp,sp
.f7:    mov  dx,T_DMG
        call ZREP
        jmp  DONE

; the stubs R_STATE calls
NEWGAME:inc  byte [ngames]      ; one more game begun
        ret
PLAYTICK:
        dec  byte [playleft]    ; one tick of the game fewer
        jnz  .on
        mov  si,T_OVER
        stc
        ret
.on:    clc
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
T_ALL   db 'GLOGIC: ALL PASS',13,10,'$'
T_SOME  db 'GLOGIC: SOME FAILED',13,10,'$'
T_CAM   db 'GLOGIC R_CAMERA centre a small map, follow past the band, stop at both edges$'
T_LEV   db 'GLOGIC R_LEVELS our folder, the table, level 2 read and loaded, no level 3$'
T_LEV2  db 'GLOGIC R_LEVELS no file: refused$'
T_TIM   db 'GLOGIC R_TIMERS a clock runs out once, a stall capped, pause counts nothing$'
T_STATE db 'GLOGIC R_STATE title, Enter, play, the end card holds, a key back$'
T_SCR   db 'GLOGIC R_SCRIPT two segments played, then over$'
T_SPAWN db 'GLOGIC R_SPAWN 50 prizes on bare floor, none where none fits, the mine$'
T_JUDGE db 'GLOGIC R_LAND the first broken rule names the verdict$'
T_DMG   db 'GLOGIC R_DAMAGE hits, rubble, the round robin forgets the oldest$'
T_TAIL  db 'TEST\LEVELS.DAT'
T_OVER  db 'GAME OVER',0
T_M1    db 'NO GEAR',0
T_M2    db 'BROKEN',0
T_M3    db 'GRASS',0
ngames  db 0
playleft db 0
sca     dw 0
scb     dw 0
rseed   dw 1
vgear   dw 0
vsink   dw 0
vside   dw 0
SHOW    dw 3, 2,-1
        dw 2, 0, 5
        dw 0
RULES   dw vgear, 0
        db J_ZERO
        dw T_M1
        dw vsink, 256
        db J_GT
        dw T_M2
        dw vside, 0
        db J_LT
        dw T_M3
        dw 0
RULEU   dw vgear, 1000
        db J_UGT
        dw T_M1
        dw 0
LEVEL   db 7,5
        db '#######'
        db '#@$.  #'
        db '#     #'
        db '#$    #'
        db '#######'
; the level file's image, written to LEVELS.DAT
DATIMG: db 'MYGAMLEV'
        dw DTAB-DATIMG, 2
DL1:    db 3,3
        db '###','#@#','###'
DL2:    db 4,3
        db '####','#@.#','####'
DTAB:   dw DL1-DATIMG, DL2-DATIMG
DATEND:

        include '..\..\ENGINE\E_MATH.INC'
        include '..\..\KIT\LIB\K_GRID.INC'
        include '..\..\KIT\REC\R_CAMERA.ASM'
        include '..\..\KIT\REC\R_LEVELS.ASM'
        include '..\..\KIT\REC\R_TIMERS.ASM'
        include '..\..\KIT\REC\R_STATE.ASM'
        include '..\..\KIT\REC\R_SCRIPT.ASM'
        include '..\..\KIT\REC\R_SPAWN.ASM'
        include '..\..\KIT\REC\R_LAND.ASM'
        include '..\..\KIT\REC\R_DAMAGE.ASM'
