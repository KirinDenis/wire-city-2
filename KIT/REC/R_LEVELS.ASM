; ============================================================================
;  R_LEVELS.ASM - recipe: levels in a file beside the game, one read a level.
;
;  Guide TILES: "Levels live in a file, one read at each level change": 60
;  Sokoban levels were 17 KB of a 64 KB .COM. The file is made by FASM from
;  a source of its own, and the game finds it in the folder it was started
;  from (the program's own path is in its environment), else the current
;  one - so `C:\GAMES\MINE\MINE.COM` run from anywhere still finds it.
;
;  THE FILE (MYGAME.ASM -> FASM MYLEVS.ASM MYLEVS.DAT):
;        format binary as 'DAT'
;                db 'MYGAMLEV'           ; 8 letters: the magic, LEVMAGIC
;                dw LEVTAB, NLEV         ; where the table is, how many
;        LEV1:   db 7,5                  ; a level: width, height, the rows
;                db '#######'            ;  (GRD_LOAD's format)
;                ...
;        LEVTAB  dw LEV1, LEV2, ...      ; where each one begins
;        NLEV    = ($ - LEVTAB) / 2
;
;        call FINDDIR            ; once, at the start: levpath = our folder
;        call LEVTABLE           ; CF=1: no file, a wrong one - say so, quit
;        ...each level:
;        mov  bx,[level]
;        call LEVREAD            ; CF=1 it would not read
;        mov  si,levbuf
;        xor  di,di
;        call GRD_LOAD           ; K_GRID
;
;  copy: FINDDIR, LEVOPEN, LEVTABLE, LEVREAD and the words at the end;
;        change LEVFNAME, LEVMAGIC, MAXLEV.
;  define before: -   calls: DOS only   needs: nothing from the kit
;  from: GAMES\MULTSOK2\MULTSOK2.ASM:498-530 (FINDDAT), 540-612 (LEVFILE,
;        LOADLEVS, LEVREAD); GAMES\MULTSOK2\LEVELS.ASM (the file). The count
;        is read from the file here (MULTSOK2 demands its own NLEVELS).
; ============================================================================
MAXLEV  = 100                   ; the most levels the table holds
LEVSIZE = 2 + 32*32             ; the most one level can be (31 x 32 and more)

; ----------------------------------------------------------------------
;@ FINDDIR    levpath = the folder this program was started from (+ file name)
;  in:  -
;  out: -  levpath = 'C:\GAMES\MINE\' + LEVFNAME, zero ended (or just the
;       name if DOS gave no path)
; ----------------------------------------------------------------------
FINDDIR:push ax
        push bx
        push cx
        push si
        push di
        push es
        push ds
        pop  es                 ; ES = DS = CS: levpath is ours
        cld
        mov  di,levpath
        mov  bx,di              ; BX = where the file name goes
        mov  ax,[2Ch]           ; PSP:2Ch, the environment's segment
        or   ax,ax
        jz   .name
        push ds
        mov  ds,ax
        xor  si,si
.scan:  cmp  word [si],0        ; the double zero ends the variables
        je   .end
        inc  si                 ; the next byte
        cmp  si,32000
        jb   .scan
        pop  ds                 ; no end found: no path
        jmp  .name
.end:   add  si,4               ; past it and the count: our own path
        mov  cx,100
.copy:  lodsb
        mov  [es:di],al
        inc  di                 ; the next place
        or   al,al
        jz   .done
        cmp  al,'\'
        je   .sl
        cmp  al,':'
        jne  .nx
.sl:    mov  bx,di              ; the name goes after the last \ or :
.nx:    loop .copy
.done:  pop  ds
.name:  mov  di,bx
        mov  si,LEVFNAME
.c:     lodsb
        stosb
        or   al,al
        jnz  .c
        pop  es
        pop  di
        pop  si
        pop  cx
        pop  bx
        pop  ax
        ret

; ----------------------------------------------------------------------
;@ LEVOPEN    open the level file: our folder first, then the current one
;  in:  levpath from FINDDIR
;  out: CF=0 BX = the handle (close it: AH=3Eh INT 21h); CF=1 not there
; ----------------------------------------------------------------------
LEVOPEN:push ax
        push dx
        mov  dx,levpath
        mov  ax,3D00h
        int  21h                ; open for reading
        jnc  .ok
        mov  dx,LEVFNAME        ; not there: the current folder
        mov  ax,3D00h
        int  21h
.ok:    mov  bx,ax              ; (an error code if CF=1)
        pop  dx
        pop  ax
        ret

; ----------------------------------------------------------------------
;@ LEVTABLE   read the file's magic, count and table into levtab, nlev
;  in:  levpath from FINDDIR
;  out: CF=1 no file, a wrong magic or a broken table; CF=0 [nlev] levels
; ----------------------------------------------------------------------
LEVTABLE:
        push ax
        push bx
        push cx
        push dx
        push si
        push di
        push es
        push ds
        pop  es
        call LEVOPEN
        jc   .err
        mov  dx,levbuf
        mov  cx,12
        mov  ah,3Fh
        int  21h                ; the magic, where the table is, how many
        jc   .cerr
        cmp  ax,12
        jne  .cerr
        mov  si,levbuf
        mov  di,LEVMAGIC
        mov  cx,8
        cld
        repe cmpsb
        jne  .cerr              ; not our file
        mov  ax,word [levbuf+10]
        or   ax,ax
        jz   .cerr              ; no levels
        cmp  ax,MAXLEV
        ja   .cerr              ; more than the table holds
        mov  [nlev],ax
        mov  dx,word [levbuf+8]
        xor  cx,cx
        mov  ax,4200h
        int  21h                ; to the table
        jc   .cerr
        mov  cx,[nlev]
        shl  cx,1               ; a word a level
        mov  dx,levtab
        mov  ah,3Fh
        int  21h
        jc   .cerr
        cmp  ax,cx
        jne  .cerr              ; short: broken
        mov  ah,3Eh
        int  21h                ; closed
        clc
        jmp  .r
.cerr:  mov  ah,3Eh
        int  21h                ; closed
.err:   mov  word [nlev],0
        stc
.r:     pop  es
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret

; ----------------------------------------------------------------------
;@ LEVREAD    level BX (0..nlev-1) from the file into levbuf
;  in:  BX = the level's number
;  out: CF=0 levbuf = db w,h, the rows (GRD_LOAD it); CF=1 no such level,
;       or it would not read
; ----------------------------------------------------------------------
LEVREAD:push ax
        push bx
        push cx
        push dx
        cmp  bx,[nlev]
        jae  .bad               ; past the last (unsigned: no negatives)
        shl  bx,1               ; a word a level
        mov  dx,[levtab+bx]     ; DX = where it begins in the file
        call LEVOPEN            ; BX = the handle
        jc   .bad
        xor  cx,cx
        mov  ax,4200h
        int  21h                ; to the level
        jc   .c
        mov  dx,levbuf
        mov  cx,LEVSIZE         ; it, and whatever follows: enough for the largest
        mov  ah,3Fh
        int  21h
        jc   .c
        cmp  ax,2
.c:     pushf                   ; (CF=1: fewer than 2 bytes, or an error)
        mov  ah,3Eh
        int  21h                ; closed
        popf
        jmp  .r
.bad:   stc
.r:     pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret

LEVFNAME db 'LEVELS.DAT',0      ; the file's name: change it
LEVMAGIC db 'MYGAMLEV'          ; its first 8 bytes: change them
nlev    dw 0                    ; levels in the file
levtab  rw MAXLEV               ; where each one begins in it
levpath rb 128                  ; FINDDIR: our folder and the name
levbuf  rb LEVSIZE              ; one level, as read
