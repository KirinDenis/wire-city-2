; ============================================================================
;  OBJ2DAT.COM - the model precompiler, honestly in 8086 assembly.
;
;  Reads a Wavefront OBJ (as Blender exports it: -Z forward, Y up) and
;  writes the engine's binary model file:
;
;      +0  db 'M','D'          magic
;      +2  dw nverts           (max 255 - face indices are bytes)
;      +4  dw nfaces           (max 300)
;      +6  dw x,y,z            per vertex, engine units, engine axes
;      then db i0,i1,i2,i3,c   per face: corners + palette colour
;
;  Axis map: engine X = obj X, engine Y = obj Y, engine Z = -obj Z.
;  Quads pass through; triangles become quads with the last corner
;  doubled (the scanline filler draws them for free); 5+ corners are
;  refused - subdivide in Blender. Materials named PALnn carry the
;  palette index; any other name falls back to 20.
;
;  Decimal coordinates are parsed in pure integer arithmetic: the
;  fraction is kept as numerator/denominator (4 digits max) and
;  scaled with a 32-bit intermediate, rounding half away from zero.
;
;      OBJ2DAT IN.OBJ OUT.DAT [scale]      (scale = units per metre, 4)
;
;  MTL COLOURS: 'mtllib' is followed; each 'newmtl' + 'Kd r g b' becomes
;  a palette entry (Kd * 63, the VGA DAC range). Faces made of such
;  materials carry 80h + slot; the DAT then ends with a trailer:
;      db 'P', db count, count * (r,g,b)
;  and the game maps slots onto free DAC registers at load time.
;  PALnn material names still mean absolute palette indices, no trailer.
; ============================================================================
BUFSZ   equ 512
MAXV    equ 255
MAXF    equ 300

        .8086
        LOCALS
        JUMPS
CODE    SEGMENT
        ASSUME cs:CODE, ds:CODE, es:CODE, ss:CODE
        ORG  100h

START:  cld
        call PARSECMD
        mov  dx,offset INFILE
        mov  ax,3D00h           ; open input, read only
        int  21h
        jc   @@eop
        mov  [infh],ax
        jmp  MAINLP
@@eop:  mov  dx,offset EOPEN
        jmp  FAIL

; ==================== the line loop: v / f / usemtl ========================
MAINLP: cmp  byte ptr [feof],0
        jne  DONE
        call GETTOK
        jc   DONE
        cmp  cx,1
        jne  @@try6
        mov  al,[TOKBUF]
        cmp  al,'v'
        je   DOVERT
        cmp  al,'f'
        je   DOFACE
        jmp  @@skip
@@try6: cmp  cx,6
        jne  @@skip
        mov  si,offset TOKBUF
        mov  di,offset SUSEM
        mov  cx,6
        repe cmpsb
        je   DOMTL
        mov  si,offset TOKBUF
        mov  di,offset SMTLL
        mov  cx,6
        repe cmpsb
        jne  @@skip
        call DOMTLIB
@@skip: call SKIPLN
        jmp  MAINLP

; ---- v x y z ---------------------------------------------------------------
DOVERT: cmp  word ptr [nv],MAXV
        jb   @@room
        mov  dx,offset EMANY
        jmp  FAIL
@@room: call PARSEF
        mov  [tvx],ax
        call PARSEF
        mov  [tvy],ax
        call PARSEF
        neg  ax                 ; engine Z = -obj Z
        mov  [tvz],ax
        mov  ax,[nv]
        mov  bx,ax
        add  bx,bx
        add  bx,ax
        add  bx,bx              ; *6
        mov  ax,[tvx]
        mov  [VTAB+bx],ax
        mov  ax,[tvy]
        mov  [VTAB+bx+2],ax
        mov  ax,[tvz]
        mov  [VTAB+bx+4],ax
        inc  word ptr [nv]
        call SKIPLN
        jmp  MAINLP

; ---- f a b c [d]  (each may be a/b/c groups - the tail is skipped) ---------
DOFACE: cmp  word ptr [nf],MAXF
        jb   @@room
        mov  dx,offset EMANYF
        jmp  FAIL
@@room: mov  word ptr [fcnt],0
@@corn: call SKIPSP
        jc   @@fin
        cmp  al,13
        je   @@fin
        cmp  al,10
        je   @@fin
        cmp  al,'0'
        jb   @@bad
        cmp  al,'9'
        ja   @@bad
        xor  bx,bx              ; the corner index, decimal
@@dig:  sub  al,'0'
        xor  ah,ah
        mov  di,ax
        mov  ax,bx
        mov  bx,10
        mul  bx
        add  ax,di
        mov  bx,ax
        call GETCH
        jc   @@store
        cmp  al,'0'
        jb   @@tail
        cmp  al,'9'
        ja   @@tail
        jmp  @@dig
@@tail: cmp  al,' '             ; swallow /vt/vn until a separator
        je   @@store
        cmp  al,9
        je   @@store
        cmp  al,13
        je   @@eol
        cmp  al,10
        je   @@eol
        call GETCH
        jc   @@store
        jmp  @@tail
@@eol:  mov  [pback],al
@@store:
        dec  bx                 ; OBJ is 1-based; 0 wraps and fails the test
        cmp  bx,[nv]
        jae  @@bad
        mov  ax,[fcnt]
        cmp  ax,4
        jae  @@bad              ; a fifth corner: not our polygon
        mov  di,[nf]
        mov  ax,di
        add  di,di
        add  di,di
        add  di,ax              ; *5
        add  di,[fcnt]
        mov  ax,bx
        mov  [FTAB+di],al
        inc  word ptr [fcnt]
        jmp  @@corn
@@fin:  cmp  word ptr [fcnt],3
        jb   @@bad
        mov  di,[nf]
        mov  ax,di
        add  di,di
        add  di,di
        add  di,ax              ; *5
        cmp  word ptr [fcnt],3
        jne  @@quad
        mov  al,[FTAB+di+2]     ; triangle = quad, last corner doubled
        mov  [FTAB+di+3],al
@@quad: mov  al,[curcol]
        mov  [FTAB+di+4],al
        inc  word ptr [nf]
        jmp  MAINLP
@@bad:  mov  dx,offset EFACE
        jmp  FAIL

; ---- usemtl: PALnn = absolute index, an MTL name = 80h + palette slot ------
DOMTL:  call SKIPSP
        jc   @@dml
        mov  di,offset TOKB2
        xor  cx,cx
@@ac:   cmp  cx,15
        jae  @@nx
        mov  [di],al
        inc  di
        inc  cx
@@nx:   call GETCH
        jc   @@fin
        cmp  al,' '
        je   @@tm
        cmp  al,9
        je   @@tm
        cmp  al,13
        je   @@tm
        cmp  al,10
        je   @@tm
        jmp  @@ac
@@tm:   mov  [pback],al
@@fin:  mov  byte ptr [di],0
        cmp  byte ptr [TOKB2],'P'
        jne  @@srch
        cmp  byte ptr [TOKB2+1],'A'
        jne  @@srch
        cmp  byte ptr [TOKB2+2],'L'
        jne  @@srch
        xor  bx,bx
        mov  si,offset TOKB2+3
@@dig:  lodsb
        or   al,al
        jz   @@setp
        cmp  al,'0'
        jb   @@setp
        cmp  al,'9'
        ja   @@setp
        sub  al,'0'
        xor  ah,ah
        push ax
        mov  ax,bx
        mov  bx,10
        mul  bx
        mov  bx,ax
        pop  ax
        add  bx,ax
        jmp  @@dig
@@setp: cmp  bx,127
        ja   @@dfl
        mov  ax,bx
        mov  [curcol],al
        jmp  @@dml
@@srch: xor  bx,bx              ; look the name up in the MTL table
@@s1:   cmp  bx,[nmtl]
        jae  @@dfl
        mov  ax,bx
        mov  cl,4
        shl  ax,cl
        mov  si,offset MTLN
        add  si,ax
        mov  di,offset TOKB2
@@s2:   mov  al,[si]
        cmp  al,[di]
        jne  @@s3
        or   al,al
        jz   @@hit
        inc  si
        inc  di
        jmp  @@s2
@@s3:   inc  bx
        jmp  @@s1
@@hit:  mov  ax,bx
        or   al,80h
        mov  [curcol],al
        jmp  @@dml
@@dfl:  mov  byte ptr [curcol],20
@@dml:  call SKIPLN
        jmp  MAINLP

; ---- mtllib: parse the palette out of the material library -----------------
DOMTLIB:
        mov  si,offset INFILE   ; the MTL sits next to the OBJ
        mov  di,offset MTLF
        mov  bx,di
@@cp:   lodsb
        or   al,al
        jz   @@cpd
        mov  [di],al
        inc  di
        cmp  al,'\'
        jne  @@cp
        mov  bx,di
        jmp  @@cp
@@cpd:  mov  di,bx
        call SKIPSP
        jc   @@out
@@nc:   mov  [di],al
        inc  di
        call GETCH
        jc   @@nz
        cmp  al,' '
        je   @@nz
        cmp  al,9
        je   @@nz
        cmp  al,13
        je   @@nz0
        cmp  al,10
        je   @@nz0
        jmp  @@nc
@@nz0:  mov  [pback],al
@@nz:   mov  byte ptr [di],0
        mov  ax,[infh]          ; park the OBJ stream: remember the
        mov  [sinfh],ax         ; FILE position (the buffer will hold
        mov  bx,ax              ; MTL bytes) and seek back later
        mov  ax,4201h
        xor  cx,cx
        xor  dx,dx
        int  21h
        mov  cx,[blen]
        sub  cx,[bpos]
        sub  ax,cx
        sbb  dx,0
        mov  [sblen],ax         ; reused as pos.lo
        mov  [sbpos],dx         ; reused as pos.hi
        mov  al,[pback]
        mov  [spback],al
        mov  al,[feof]
        mov  [sfeof],al
        mov  byte ptr [pback],0
        mov  byte ptr [feof],0
        xor  ax,ax
        mov  [blen],ax
        mov  [bpos],ax
        mov  dx,offset MTLF
        mov  ax,3D00h
        int  21h
        jc   @@rst
        mov  [infh],ax
        mov  ax,[scale]         ; Kd floats are 0..1: scale by 63
        mov  [sscale],ax
        mov  word ptr [scale],63
@@mt:   cmp  byte ptr [feof],0
        jne  @@mfin
        call GETTOK
        jc   @@mfin
        cmp  cx,6
        jne  @@kd
        mov  si,offset TOKBUF
        mov  di,offset SNEWM
        mov  cx,6
        repe cmpsb
        jne  @@skl
        cmp  word ptr [nmtl],16
        jae  @@skl
        call SKIPSP
        jc   @@mfin
        push ax
        mov  ax,[nmtl]
        mov  cl,4
        shl  ax,cl
        mov  di,offset MTLN
        add  di,ax
        pop  ax
        mov  cx,15
@@n1:   mov  [di],al
        inc  di
        call GETCH
        jc   @@n2
        cmp  al,' '
        je   @@n2
        cmp  al,9
        je   @@n2
        cmp  al,13
        je   @@n3
        cmp  al,10
        je   @@n3
        loop @@n1
@@n3:   mov  [pback],al
@@n2:   mov  byte ptr [di],0
        inc  word ptr [nmtl]
        jmp  @@skl
@@kd:   cmp  cx,2
        jne  @@skl
        cmp  word ptr [TOKBUF],644Bh    ; 'K','d'
        jne  @@skl
        mov  ax,[nmtl]
        or   ax,ax
        jz   @@skl
        dec  ax
        mov  bx,ax
        add  bx,ax
        add  bx,ax
        add  bx,offset MRGB
        push bx
        call PARSEF
        call CLAMP63
        pop  bx
        push bx
        mov  [bx],al
        call PARSEF
        call CLAMP63
        pop  bx
        push bx
        mov  [bx+1],al
        call PARSEF
        call CLAMP63
        pop  bx
        mov  [bx+2],al
@@skl:  call SKIPLN
        jmp  @@mt
@@mfin: mov  bx,[infh]
        mov  ah,3Eh
        int  21h
        mov  ax,[sscale]
        mov  [scale],ax
@@rst:  mov  ax,[sinfh]
        mov  [infh],ax
        mov  bx,ax
        mov  dx,[sblen]         ; pos.lo
        mov  cx,[sbpos]         ; pos.hi
        mov  ax,4200h           ; seek back where the OBJ paused
        int  21h
        xor  ax,ax
        mov  [blen],ax
        mov  [bpos],ax
        mov  al,[spback]
        mov  [pback],al
        mov  al,[sfeof]
        mov  [feof],al
@@out:  ret

CLAMP63:
        or   ax,ax
        jns  @@c1
        xor  ax,ax
@@c1:   cmp  ax,63
        jle  @@c2
        mov  ax,63
@@c2:   ret

; =================== write the DAT and report =============================
DONE:   mov  dx,offset OUTFILE
        xor  cx,cx
        mov  ah,3Ch             ; create output
        int  21h
        jc   WFAIL
        mov  [outfh],ax
        mov  ax,[nv]
        mov  [HDRNV],ax
        mov  ax,[nf]
        mov  [HDRNF],ax
        mov  bx,[outfh]
        mov  cx,6
        mov  dx,offset HDRMAG
        call WRITE
        mov  ax,[nv]
        mov  cx,6
        mul  cx
        mov  cx,ax
        mov  dx,offset VTAB
        call WRITE
        mov  ax,[nf]
        mov  cx,5
        mul  cx
        mov  cx,ax
        mov  dx,offset FTAB
        call WRITE
        mov  ax,[nmtl]
        or   ax,ax
        jz   @@npal
        mov  byte ptr [PHDR],'P'
        mov  [PHDR+1],al
        mov  cx,2
        mov  dx,offset PHDR
        call WRITE
        mov  ax,[nmtl]
        mov  cx,ax
        add  cx,ax
        add  cx,ax
        mov  dx,offset MRGB
        call WRITE
@@npal: mov  ah,3Eh
        int  21h
        mov  dx,offset RPT1
        mov  ah,9
        int  21h
        mov  ax,[nv]
        call PDEC
        mov  dx,offset RPT2
        mov  ah,9
        int  21h
        mov  ax,[nf]
        call PDEC
        mov  dx,offset RPT3
        mov  ah,9
        int  21h
        mov  ax,4C00h
        int  21h

WRITE:  mov  ah,40h             ; write CX bytes at DX, die on short write
        int  21h
        jc   WFAIL
        cmp  ax,cx
        jne  WFAIL
        ret
WFAIL:  mov  dx,offset EWRITE
FAIL:   mov  ah,9
        int  21h
        mov  ax,4C01h
        int  21h

; ==================== the input machinery ==================================
; GETCH - next byte in AL, honouring one pushed-back char; CF=1 at EOF
GETCH:  mov  al,[pback]
        or   al,al
        jz   @@rd
        mov  byte ptr [pback],0
        clc
        ret
@@rd:   push bx
        mov  bx,[bpos]
        cmp  bx,[blen]
        jb   @@have
        push cx
        push dx
        mov  ah,3Fh
        mov  bx,[infh]
        mov  cx,BUFSZ
        mov  dx,offset FBUF
        int  21h
        pop  dx
        pop  cx
        jc   @@eof
        or   ax,ax
        jz   @@eof
        mov  [blen],ax
        xor  bx,bx
@@have: mov  al,[FBUF+bx]
        inc  bx
        mov  [bpos],bx
        pop  bx
        clc
        ret
@@eof:  mov  byte ptr [feof],1
        pop  bx
        stc
        ret

; SKIPSP - skip blanks, first other char in AL; CF=1 at EOF
SKIPSP: call GETCH
        jc   @@out
        cmp  al,' '
        je   SKIPSP
        cmp  al,9
        je   SKIPSP
        clc
@@out:  ret

; SKIPLN - consume up to and including the next LF
SKIPLN: call GETCH
        jc   @@out
        cmp  al,10
        jne  SKIPLN
@@out:  ret

; GETTOK - next token at a line start into TOKBUF (CX = length, CF = EOF);
; the terminating char is pushed back
GETTOK: call GETCH
        jc   @@eof
        cmp  al,' '
        je   GETTOK
        cmp  al,9
        je   GETTOK
        cmp  al,13
        je   GETTOK
        cmp  al,10
        je   GETTOK
        mov  di,offset TOKBUF
        xor  cx,cx
@@acc:  cmp  cx,15
        jae  @@next
        mov  [di],al
        inc  di
        inc  cx
@@next: call GETCH
        jc   @@fin
        cmp  al,' '
        je   @@term
        cmp  al,9
        je   @@term
        cmp  al,13
        je   @@term
        cmp  al,10
        je   @@term
        jmp  @@acc
@@term: mov  [pback],al
@@fin:  mov  byte ptr [di],0
        clc
        ret
@@eof:  stc
        ret

; PARSEF - one signed decimal number, AX = round(value * scale).
; Fraction kept as numerator SI / denominator DI, 4 digits max, then
; scaled through a 32-bit intermediate: (frac*scale + den/2) / den.
PARSEF: call SKIPSP
        jc   @@zero
        mov  byte ptr [fneg],0
        cmp  al,'-'
        jne  @@int0
        mov  byte ptr [fneg],1
        call GETCH
        jc   @@zero
@@int0: xor  bx,bx              ; integer part
        xor  si,si              ; fraction numerator
        mov  di,1               ; fraction denominator
@@idig: cmp  al,'0'
        jb   @@iend
        cmp  al,'9'
        ja   @@iend
        sub  al,'0'
        xor  ah,ah
        push ax
        mov  ax,bx
        mov  bx,10
        mul  bx
        mov  bx,ax
        pop  ax
        add  bx,ax
        call GETCH
        jc   @@calc
        jmp  @@idig
@@iend: cmp  al,'.'
        jne  @@push
@@fdig: call GETCH
        jc   @@calc
        cmp  al,'0'
        jb   @@push
        cmp  al,'9'
        ja   @@push
        cmp  di,10000
        jae  @@fdig             ; digits past four: noise, ignored
        sub  al,'0'
        xor  ah,ah
        push ax
        mov  ax,si
        mov  cx,10
        mul  cx
        mov  si,ax
        pop  ax
        add  si,ax
        mov  ax,di
        mul  cx
        mov  di,ax
        jmp  @@fdig
@@push: mov  [pback],al
@@calc: mov  ax,bx
        mul  word ptr [scale]
        or   dx,dx
        jnz  @@ovf
        mov  cx,ax
        cmp  di,1
        je   @@sign
        mov  ax,si
        mul  word ptr [scale]
        mov  bx,di
        shr  bx,1
        add  ax,bx              ; round half away from zero
        adc  dx,0
        div  di
        add  cx,ax
@@sign: cmp  cx,32000
        ja   @@ovf
        mov  ax,cx
        cmp  byte ptr [fneg],0
        je   @@out
        neg  ax
@@out:  ret
@@zero: xor  ax,ax
        ret
@@ovf:  mov  dx,offset EOVF
        jmp  FAIL

; PDEC - AX in decimal to the console
PDEC:   xor  cx,cx
        mov  bx,10
@@div:  xor  dx,dx
        div  bx
        push dx
        inc  cx
        or   ax,ax
        jnz  @@div
@@out:  pop  dx
        add  dl,'0'
        mov  ah,2
        int  21h
        loop @@out
        ret

; ==================== the command line =====================================
PARSECMD:
        mov  si,81h
        mov  di,offset INFILE
        call CPTOK
        or   cx,cx
        jz   @@use
        mov  di,offset OUTFILE
        call CPTOK
        or   cx,cx
        jz   @@use
@@sksp: lodsb                   ; optional third token: the scale
        cmp  al,' '
        je   @@sksp
        cmp  al,9
        je   @@sksp
        cmp  al,13
        je   @@dflt
        xor  bx,bx
@@dig:  cmp  al,'0'
        jb   @@set
        cmp  al,'9'
        ja   @@set
        sub  al,'0'
        xor  ah,ah
        push ax
        mov  ax,bx
        mov  bx,10
        mul  bx
        mov  bx,ax
        pop  ax
        add  bx,ax
        lodsb
        jmp  @@dig
@@set:  or   bx,bx
        jz   @@use
        cmp  bx,999
        ja   @@use
        mov  [scale],bx
@@dflt: ret
@@use:  mov  dx,offset EUSAGE
        jmp  FAIL

; CPTOK - copy one blank-delimited token from SI to DI, CX = length
CPTOK:  xor  cx,cx
@@skip: lodsb
        cmp  al,' '
        je   @@skip
        cmp  al,9
        je   @@skip
        cmp  al,13
        je   @@none
@@copy: mov  [di],al
        inc  di
        inc  cx
        lodsb
        cmp  al,' '
        je   @@stop
        cmp  al,9
        je   @@stop
        cmp  al,13
        je   @@stop
        jmp  @@copy
@@stop: dec  si                 ; the terminator stays for the next token
        mov  byte ptr [di],0
        ret
@@none: dec  si
        mov  byte ptr [di],0
        ret

; ==================== state and tables =====================================
scale   dw 4
nv      dw 0
nf      dw 0
fcnt    dw 0
infh    dw 0
outfh   dw 0
blen    dw 0
bpos    dw 0
pback   db 0
feof    db 0
fneg    db 0
curcol  db 20
tvx     dw 0
tvy     dw 0
tvz     dw 0
HDRMAG  db 'M','D'
HDRNV   dw 0
HDRNF   dw 0
SUSEM   db 'usemtl'
SMTLL   db 'mtllib'
SNEWM   db 'newmtl'
EUSAGE  db 'USAGE: OBJ2DAT IN.OBJ OUT.DAT [SCALE]',13,10,'$'
EOPEN   db 'CANNOT OPEN INPUT',13,10,'$'
EWRITE  db 'CANNOT WRITE OUTPUT',13,10,'$'
EMANY   db 'TOO MANY VERTS (MAX 255)',13,10,'$'
EMANYF  db 'TOO MANY FACES (MAX 300)',13,10,'$'
EFACE   db 'BAD FACE (3..4 CORNERS OF KNOWN VERTS)',13,10,'$'
EOVF    db 'COORDINATE OVERFLOW - LOWER THE SCALE',13,10,'$'
RPT1    db 'OBJ2DAT: $'
RPT2    db ' VERTS, $'
RPT3    db ' FACES',13,10,'$'
TOKBUF  db 16 dup(0)
TOKB2   db 16 dup(0)
MTLF    db 80 dup(0)
MTLN    db 256 dup(0)
MRGB    db 48 dup(0)
nmtl    dw 0
sinfh   dw 0
sblen   dw 0
sbpos   dw 0
spback  db 0
sfeof   db 0
sscale  dw 0
PHDR    db 2 dup(0)
INFILE  db 64 dup(0)
OUTFILE db 64 dup(0)
FBUF    db BUFSZ dup(0)
VTAB    dw MAXV*3 dup(0)
FTAB    db MAXF*5 dup(0)

CODE    ENDS
        END START
