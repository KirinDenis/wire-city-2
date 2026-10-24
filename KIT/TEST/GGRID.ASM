; ============================================================================
;  GGRID.ASM - KIT test of LIB\K_GRID.INC: load a small level, read cells,
;  flood the floor, the nearest goal (BFS), an enemy's next step (PATH),
;  the walking keys. Text only: PASS/FAIL lines through DOS.
;      GGRID /AUTO   checks and quits;   GGRID   checks, then waits for Esc
; ============================================================================
        org  100h
        include '..\..\ENGINE\E_8086.INC'

START:  cld
; ---- load ----
        mov  si,LEVEL
        xor  di,di              ; Sokoban's letters
        call GRD_LOAD
        mov  dx,T_LOAD
        jc   .x1                ; refused: a fail
        cmp  byte [grd_w],7
        jne  .f1
        cmp  byte [grd_h],6
        jne  .f1
        cmp  word [grd_start],1*32+1
        jne  .f1
        cmp  word [grd_nbox],2
        jne  .f1
        cmp  word [grd_ngood],0
        jmp  .f1
.x1:    or   sp,sp              ; ZF=0: a fail
.f1:    call ZREP
; ---- a too-wide level is refused ----
        mov  si,WIDE
        xor  di,di
        call GRD_LOAD
        mov  dx,T_WIDE
        mov  al,0
        adc  al,0               ; AL = 1 if refused
        cmp  al,1
        call ZREP
        mov  si,LEVEL           ; the good one back
        xor  di,di
        call GRD_LOAD
; ---- GRD_AT: off the level reads as a wall ----
        mov  dx,T_AT
        mov  bx,-1
        call GRD_AT
        cmp  al,GRD_WALL
        jne  .f2
        mov  bx,7               ; column 7: past the width
        call GRD_AT
        cmp  al,GRD_WALL
        jne  .f2
        mov  bx,6*32+1          ; row 6: past the height
        call GRD_AT
        cmp  al,GRD_WALL
        jne  .f2
        mov  bx,1*32+1          ; the man
        call GRD_AT
        cmp  al,GRD_MAN
        jne  .f2
        mov  bx,1*32+4          ; a crate
        call GRD_AT
        cmp  al,GRD_BOX
.f2:    call ZREP
; ---- GRD_CELL / GRD_XY ----
        mov  dx,T_CELL
        mov  ax,0305h           ; column 5, row 3
        call GRD_CELL
        cmp  bx,3*32+5
        jne  .f3
        xor  ax,ax
        call GRD_XY
        cmp  ax,0305h
.f3:    call ZREP
; ---- GRD_FLOOD: 17 floor cells ----
        mov  bx,[grd_start]
        mov  ax,GRD_WALL*256 + GRD_FLOOR
        call GRD_FLOOD
        xor  cx,cx
        xor  bx,bx
.cnt:   test byte [grd_map+bx],GRD_FLOOR
        jz   .cn
        inc  cx                 ; one more floor cell
.cn:    inc  bx                 ; the next cell
        cmp  bx,GRD_CELLS
        jb   .cnt
        mov  dx,T_FLOOD
        cmp  cx,17
        call ZREP
; ---- GRD_BFS: the nearest goal through crates: (5,1), 4 steps ----
        mov  bx,[grd_start]
        mov  ax,GRD_GOAL*256 + GRD_GOAL
        mov  dx,GRD_WALL*256 + GRD_FLOOR
        mov  si,QUEUE
        call GRD_BFS
        mov  dx,T_BFS1
        jc   .x4
        cmp  bx,1*32+5
        jne  .f4
        cmp  cx,4
        jmp  .f4
.x4:    or   sp,sp              ; ZF=0: a fail
.f4:    call ZREP
; ---- GRD_BFS with crates blocking: (5,3), 6 steps ----
        mov  bx,[grd_start]
        mov  ax,GRD_GOAL*256 + GRD_GOAL
        mov  dx,(GRD_WALL+GRD_BOX)*256 + GRD_FLOOR
        mov  si,QUEUE
        call GRD_BFS
        mov  dx,T_BFS2
        jc   .x5
        cmp  bx,3*32+5
        jne  .f5
        cmp  cx,6
        jmp  .f5
.x5:    or   sp,sp              ; ZF=0: a fail
.f5:    call ZREP
; ---- GRD_BFS: no free cell left uncleaned (GRD_SEEN gone) ----
        xor  bx,bx
.sn:    test byte [grd_map+bx],GRD_SEEN
        jnz  .sf
        inc  bx                 ; the next cell
        cmp  bx,GRD_CELLS
        jb   .sn
.sf:    mov  dx,T_SEEN
        cmp  bx,GRD_CELLS
        call ZREP
; ---- GRD_PATH: from (5,3) to the man, crates blocking: left, 6 ----
        mov  bx,3*32+5
        mov  di,[grd_start]
        mov  dx,(GRD_WALL+GRD_BOX)*256 + GRD_FLOOR
        mov  si,QUEUE
        call GRD_PATH
        mov  dx,T_PATH1
        jc   .x6
        cmp  ax,3
        jne  .f6
        cmp  cx,6
        jmp  .f6
.x6:    or   sp,sp              ; ZF=0: a fail
.f6:    call ZREP
; ---- GRD_PATH: from (1,4) up to the man: up, 3 ----
        mov  bx,4*32+1
        mov  di,[grd_start]
        mov  dx,(GRD_WALL+GRD_BOX)*256 + GRD_FLOOR
        mov  si,QUEUE
        call GRD_PATH
        mov  dx,T_PATH2
        jc   .x7
        cmp  ax,0
        jne  .f7
        cmp  cx,3
        jmp  .f7
.x7:    or   sp,sp              ; ZF=0: a fail
.f7:    call ZREP
; ---- GRD_PATH: (5,1) is shut in by its crate: no path ----
        mov  bx,1*32+5
        mov  di,[grd_start]
        mov  dx,(GRD_WALL+GRD_BOX)*256 + GRD_FLOOR
        mov  si,QUEUE
        call GRD_PATH
        mov  dx,T_PATH3
        mov  al,0
        adc  al,0               ; AL = 1: no path, as it should be
        cmp  al,1
        call ZREP
; ---- GRD_KEYDIR / GRD_STEP ----
        mov  dx,T_KEYS
        mov  ah,11h             ; W
        call GRD_KEYDIR
        jc   .x8
        cmp  al,0
        jne  .f8
        mov  ah,4Bh             ; Left
        call GRD_KEYDIR
        jc   .x8
        cmp  al,3
        jne  .f8
        mov  ah,10h             ; Q: not a walking key
        call GRD_KEYDIR
        jnc  .f8n
        mov  al,2
        call GRD_STEP
        cmp  dx,32
        jne  .f8
        mov  al,3
        call GRD_STEP
        cmp  dx,-1
        jmp  .f8
.f8n:   or   al,1               ; ZF clear: a fail
        jmp  .f8
.x8:    or   sp,sp              ; ZF=0: a fail
.f8:    mov  dx,T_KEYS          ; (GRD_STEP took DX)
        call ZREP
; ---- GRD_SET / GRD_CLR ----
        mov  dx,T_SET
        mov  bx,2*32+1
        mov  al,GRD_ITEM
        call GRD_SET
        test byte [grd_map+bx],GRD_ITEM
        jz   .f9n
        call GRD_CLR
        test byte [grd_map+bx],GRD_ITEM
        jmp  .f9
.f9n:   or   al,1
.f9:    call ZREP
        jmp  DONE

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
T_ALL   db 'GGRID: ALL PASS',13,10,'$'
T_SOME  db 'GGRID: SOME FAILED',13,10,'$'
T_LOAD  db 'GGRID load: 7x6, start, 2 crates$'
T_WIDE  db 'GGRID load refuses a level 32 wide$'
T_AT    db 'GGRID GRD_AT: off the level reads wall, cells read right$'
T_CELL  db 'GGRID GRD_CELL / GRD_XY round trip$'
T_FLOOD db 'GGRID GRD_FLOOD: 17 floor cells$'
T_BFS1  db 'GGRID GRD_BFS nearest goal through crates: (5,1) in 4$'
T_BFS2  db 'GGRID GRD_BFS crates blocking: (5,3) in 6$'
T_SEEN  db 'GGRID GRD_BFS leaves no GRD_SEEN behind$'
T_PATH1 db 'GGRID GRD_PATH (5,3) to the man: left, 6 steps$'
T_PATH2 db 'GGRID GRD_PATH (1,4) to the man: up, 3 steps$'
T_PATH3 db 'GGRID GRD_PATH shut in: no path$'
T_KEYS  db 'GGRID GRD_KEYDIR W/Left/Q, GRD_STEP down/left$'
T_SET   db 'GGRID GRD_SET / GRD_CLR$'

LEVEL   db 7,6
        db '#######'
        db '#@  $.#'
        db '# ## ##'
        db '#    .#'
        db '#  $  #'
        db '#######'
WIDE    db 32,1
        db '################################'

        include '..\..\KIT\LIB\K_GRID.INC'
QUEUE   rw GRD_CELLS            ; the searches' queue: 2 bytes a cell
