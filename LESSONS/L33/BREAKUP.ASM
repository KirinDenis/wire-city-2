; ============================================================================
;  BREAKUP.ASM - Lesson 21. THE BREAKUP: an aeroplane hit by a shell comes
;  apart, and every piece obeys the same few laws.
;
;      FASM BREAKUP.ASM BREAKUP.COM
;
;      SPACE         fire: the shell comes in along the yellow line
;      LEFT / RIGHT  where the shell comes from, round the aeroplane
;      W / S         how fast the aeroplane flies, 0 to 6
;      UP / DOWN     the next aeroplane: fighter, bomber, radar picket,
;                    transport, tanker
;      P             slow: physics a frame in four
;      R             a new aeroplane
;      ESC           back to DOS
;
;  A TEST STAND, as the hangar was. The aeroplane flies across in front of
;  you over a floor ruled in 200-unit squares, 250 under the eye, so that where every piece
;  goes can be read off the floor. Lesson 1E's air force, every number.
;
;  AN AEROPLANE IS ALREADY ITS PIECES. Each face of the model is a piece:
;  a centre, four corners measured from it, a velocity, a mass and a spin.
;  Flying, all of them have the same velocity and no spin, and that is all
;  "in one piece" means. The shell changes the numbers; the drawing does
;  not know.
;
;  THE LAWS, all of them in FIRE and STEP:
;
;      mass      a piece's mass is its AREA - the aeroplane is taken as one
;                sheet of one thickness. The area is half the cross product
;                of the face's diagonals, and its length is a square root:
;                lesson 1D's Newton, on a double word
;      the blast pushes each piece away from where the shell struck, the
;                harder the nearer, and the push is shared by mass: the
;                same push moves a small piece fast and a wing slowly -
;                dv = J/m
;      no net push   a blast is the aeroplane pushing on itself. Whatever
;                it pushes one way it pushes back the other: the sum of all
;                the pushes is taken out again, by mass
;      the shell brings its own momentum, along its own path, and that is
;                the only push the whole has from outside
;      the spin  a push that misses a piece's centre turns it, and a big
;                piece turns slowly: spin = J / (m * size)
;      falling   gravity on every piece the same; the air takes 1/128 of
;                the speed a frame; the floor stops a piece dead
;
;  THE PHYSICAL FACT THIS LESSON HANDS OVER:
;
;      AN EXPLOSION HAS NO MOMENTUM OF ITS OWN. Every push inside the
;      aeroplane has an equal push back, so the CENTRE OF MASS of all the
;      pieces flies on along the path the whole aeroplane would have
;      flown - moved only by the shell's own momentum, which came from
;      outside. The red cross is the centre of mass; the amber dots are a
;      whole aeroplane, flown by the same laws from the moment of the hit.
;      They stay together until the first piece touches the floor - the
;      floor is a push from outside too.
;
;  AND NOT HONEST, SAID SO: the air here slows every piece by the same
;  share, which is right for sheets of one thickness at these speeds only
;  roughly; the lever of the spin is taken as the piece's size, not worked
;  out from where on it the push lands; pieces pass through each other and
;  through the floor's edge; nothing burns.
;
;  WHAT IS BORROWED FROM THE ENGINE:
;
;      ENGINE\E_8086.INC   keeps FASM inside the 8086 instruction set
;      ENGINE\E_M3D.INC    SINQ, PROJPT - the sine and the lens
;      ENGINE\E_RAST.INC   FACEFILL, CLIPLINE, LINE
;      ENGINE\E_MATH.INC   (RND16, which E_RAST's callers expect to exist)
;
;  Owlos - legacy software modernization - https://owlos.sk
; ============================================================================
FOCAL   = 220                 ; the game's lens
NEARZ   = 40                  ; the near clip plane
MAXP    = 12                  ; the most pieces: the bomber's twelve faces
FLOOR   = -250                ; the floor, 250 under the eye
PLANEY  = -40                 ; the aeroplane flies 40 under the eye...
PLANEZ  = 700                 ; ...700 in front of it...
XSTART  = -450                ; ...from here, east, to XSTOP - both
XSTOP   = 650                 ;  just inside the picture's edges
GRAV    = 12                  ; gravity: 12/256 of a unit a frame, a frame
KBLAST  = 40920               ; the blast's strength - see FIRE
D0SQ    = 64                  ; the blast's softening, in (units/8)^2
KSHELL  = 675                 ; the shell's momentum, *256, in mass*units/frame
HITR    = 60                  ; the shell strikes this far out from the centre
SPINMAX = 48                  ; the fastest a piece may turn, 16ths a frame
RESET   = 600                 ; frames after the hit before a new aeroplane
SKYC    = 1                   ; THE COLOURS, set in SETPAL
FLOORC  = 2
GRIDC   = 3
CMCOL     = 4                   ; the centre of mass: red
GHOSTC  = 5                   ; the whole aeroplane's path: amber
SHELLC  = 6                   ; the shell's line: yellow

format binary as 'com'
        org 100h

        include '..\..\ENGINE\E_8086.INC'

START:  cld                     ; STOSW and MOVSW walk up
        mov  ax,cs              ; AX = our segment
        add  ax,1000h           ; AX += 64K: the back buffer, above us
        mov  [bufseg],ax
        mov  ax,0013h           ; VGA 320x200, 256 colours
        int  10h
        mov  si,PAL             ; the colours
        call SETPAL
        call NEWPLANE           ; the first aeroplane

; ---- one frame ---------------------------------------------------------------
FRAME:  mov  ax,[bufseg]        ; ---- the sky and the floor ----
        mov  es,ax
        xor  di,di
        mov  ax,SKYC*257        ; the top half: sky, both bytes
        mov  cx,100*320/2       ; 100 rows of words
        rep  stosw
        mov  ax,FLOORC*257      ; the bottom half: the floor - its horizon
        mov  cx,100*320/2       ;  is row 100, because the eye is level
        rep  stosw
        call GRID               ; the floor's squares

        ; ---- the physics: every frame, or one in four when slow ----------
        inc  word [fcount]      ; the frame count
        cmp  byte [slow],0      ; slow?
        je   .step
        test word [fcount],3    ;   then only every fourth frame
        jnz  .nostep
.step:  call STEP
.nostep:
        call DRAWALL            ; the pieces, far to near
        call MARKS              ; the shell's line, the centre of mass, the path
        call WORDS              ; what is on the stand

        call WAITVR             ; ---- the frame onto the screen ----
        cmp  byte [flash],0     ; THE FLASH: lesson 1F's trick - the DAC,
        je   .nfl               ;  not a pixel. Sky and floor white for
        dec  byte [flash]       ;  three frames, then their own colours
        jnz  .nfl
        mov  si,PAL             ;  back
        call SETPAL
.nfl:   push ds
        mov  ax,0A000h
        mov  es,ax              ; ES = the screen
        mov  ds,[bufseg]        ; DS = the buffer
        xor  si,si
        xor  di,di
        mov  cx,32000
        rep  movsw
        pop  ds

        cmp  byte [mode],1      ; ---- broken, and long enough? ----
        jne  .keys
        dec  word [timer]       ; timer--
        jnz  .keys
        call NEWPLANE           ;   a new aeroplane by itself
.keys:  mov  ah,1               ; ---- the keys ----
        int  16h
        jz   FRAME
        xor  ah,ah
        int  16h                ; AL = ASCII, AH = scan code
        cmp  al,27              ; ESC?
        je   QUIT
        cmp  al,' '             ; SPACE: fire
        jne  .k1
        call FIRE
        jmp  FRAME
.k1:    and  al,0DFh            ; lower case to upper
        cmp  al,'R'             ; R: a new one
        jne  .k2
        call NEWPLANE
        jmp  FRAME
.k2:    cmp  al,'P'             ; P: slow, or not
        jne  .k3
        xor  byte [slow],1
        jmp  FRAME
.k3:    cmp  al,'W'             ; W: faster
        jne  .k4
        cmp  word [spd],6
        jae  FRAME
        inc  word [spd]
        call SETSPD
        jmp  FRAME
.k4:    cmp  al,'S'             ; S: slower
        jne  .k5
        cmp  word [spd],0
        je   FRAME
        dec  word [spd]
        call SETSPD
        jmp  FRAME
.k5:    cmp  ah,4Bh             ; LEFT: the shell comes from further round
        jne  .k6
        sub  word [theta],16    ; a sixteenth of a circle
        and  word [theta],255
        jmp  FRAME
.k6:    cmp  ah,4Dh             ; RIGHT: the other way round
        jne  .k7
        add  word [theta],16
        and  word [theta],255
        jmp  FRAME
.k7:    cmp  ah,48h             ; UP: the next aeroplane
        jne  .k8
        inc  word [cmodel]
        cmp  word [cmodel],5
        jb   .new
        mov  word [cmodel],0
        jmp  .new
.k8:    cmp  ah,50h             ; DOWN: the one before
        jne  FRAME
        dec  word [cmodel]
        jns  .new
        mov  word [cmodel],4
.new:   call NEWPLANE
        jmp  FRAME

QUIT:   mov  ax,0003h           ; text mode again
        int  10h
        mov  ax,4C00h           ; and back to DOS
        int  21h

; ============================================================================
;  NEWPLANE - the aeroplane [cmodel] as its pieces, whole, at the start.
;
;  For each face: its corners from the model, times 8 (lesson 1E's cell);
;  its centre, the average of the four; the corners again, measured from
;  that centre; and its mass, the face's area. Then every piece is moved to
;  the start and given the aeroplane's velocity, and no spin.
;  In C:
;      for (f = 0; f < nfc; f++) {
;          for (k = 0; k < 4; k++) c[k] = vertex[face[f][k]] * 8;
;          centre = (c[0] + c[1] + c[2] + c[3]) / 4;
;          for (k = 0; k < 4; k++) off[f][k] = c[k] - centre;
;          mass[f] = max(|(V[c]-V[a]) x (V[d]-V[b])| / 2, 8);
;          pos[f] = start + centre;  vel[f] = (spd, 0, 0);  spin[f] = 0;
;      }
; ============================================================================
NEWPLANE:
        mov  bx,[cmodel]        ; the type's tables, as SETM in 1E
        add  bx,bx
        mov  ax,[MVTAB+bx]
        mov  [mvb],ax
        mov  ax,[MFTAB+bx]
        mov  [mfb],ax
        mov  ax,[NFCTAB+bx]
        mov  [nfc],ax
        mov  byte [mode],0      ; whole
        mov  word [msum],0      ; the total mass, about to be counted
        mov  word [ntrail],0    ; no path yet
        xor  bp,bp              ; BP = the piece
.pc:    mov  bx,bp
        shl  bx,1
        shl  bx,1               ; BX = f*4
        add  bx,bp              ; BX = f*5: five bytes a face
        add  bx,[mfb]           ; BX = &faces[f]
        mov  [fptr],bx
        mov  word [sumx],0      ; ---- the centre: the four corners summed
        mov  word [sumy],0
        mov  word [sumz],0
        xor  cx,cx              ; CX = the corner
.c1:    mov  bx,[fptr]
        add  bx,cx
        call VERT8              ; AX, DX, DI = that corner, times 8
        add  [sumx],ax          ; summed
        add  [sumy],dx
        add  [sumz],di
        inc  cx
        cmp  cx,4
        jb   .c1
        mov  ax,[sumx]          ; ...and over four: SAR 2, keeping the sign
        sar  ax,1
        sar  ax,1
        mov  [cenx],ax
        mov  ax,[sumy]
        sar  ax,1
        sar  ax,1
        mov  [ceny],ax
        mov  ax,[sumz]
        sar  ax,1
        sar  ax,1
        mov  [cenz],ax
        xor  cx,cx              ; ---- the corners, from the centre ----
.c2:    mov  bx,[fptr]
        add  bx,cx
        call VERT8              ; AX, DX, DI = the corner, times 8
        mov  si,bp
        shl  si,1
        shl  si,1
        add  si,cx              ; SI = f*4 + k
        add  si,si              ; SI = (f*4 + k)*2: a word a corner
        sub  ax,[cenx]          ; x - the centre's
        mov  [ROX+si],ax
        sub  dx,[ceny]
        mov  [ROY+si],dx
        sub  di,[cenz]
        mov  [ROZ+si],di
        inc  cx
        cmp  cx,4
        jb   .c2
        call AREA               ; AX = the face's area, in cells
        cmp  ax,8               ; never lighter than 8: a sliver of a face
        jge  .m1                ;  must not fly off at the speed of light
        mov  ax,8
.m1:    mov  si,bp
        add  si,si              ; SI = f*2
        mov  [PM+si],ax         ; mass[f] = it
        add  [msum],ax          ; the total
        call ISQRT              ; AX = its square root: the piece's size
        mov  [PSZ+si],ax
        mov  ax,XSTART          ; ---- the piece where the aeroplane starts
        add  ax,[cenx]
        mov  [QX+si],ax
        mov  ax,PLANEY
        add  ax,[ceny]
        mov  [QY+si],ax
        mov  ax,PLANEZ
        add  ax,[cenz]
        mov  [QZ+si],ax
        mov  byte [QFX+bp],0    ; no fractions
        mov  byte [QFY+bp],0
        mov  byte [QFZ+bp],0
        mov  word [PVYW+si],0   ; flying level
        mov  word [PVZW+si],0
        mov  word [PA+si],0     ; no turn, no spin
        mov  word [PB+si],0
        mov  word [PWA+si],0
        mov  word [PWB+si],0
        mov  byte [PLAND+bp],0  ; in the air
        mov  bx,[fptr]
        mov  al,[bx+4]          ; its colour
        mov  [PCOL+bp],al
        inc  bp                 ; the next piece
        cmp  bp,[nfc]
        jb   .pc
        call SETSPD             ; and all of them the aeroplane's speed
        ret

; ---- SETSPD: while whole, every piece flies at spd units a frame, east ---
SETSPD: cmp  byte [mode],0      ; only while whole: a broken one keeps
        jne  .x                 ;  the velocities the shell gave it
        mov  ax,[spd]           ; AX = spd
        mov  ah,al              ; AX = spd*256: in 256ths of a unit
        xor  al,al
        xor  si,si
.s:     mov  [PVXW+si],ax       ; vel.x = it
        add  si,2
        mov  bx,[nfc]
        add  bx,bx
        cmp  si,bx
        jb   .s
.x:     ret

; ---- VERT8: BX = &face[f][k] -> AX, DX, DI = that vertex, times 8 ---------
;  Clobbers SI. (Lesson 1E's cell is eight units.)
VERT8:  mov  al,[bx]            ; AL = the vertex number
        xor  ah,ah
        mov  si,ax
        shl  si,1
        add  si,ax              ; SI = v*3
        add  si,si              ; SI = v*6: six bytes a vertex
        add  si,[mvb]           ; SI = &vertex[v]
        push cx                 ; THE MODEL FACES NORTH, the stand flies it
        mov  cl,3               ;  EAST: east is the model's z, and north is
        mov  ax,[si+2]          ;  minus its x - the right wing to the south,
        shl  ax,cl              ;  towards you. CL = 3: times 8
        mov  dx,ax              ; DX = y*8
        mov  ax,[si]            ; x
        shl  ax,cl
        neg  ax
        mov  di,ax              ; DI = -x*8: north
        mov  ax,[si+4]          ; z
        shl  ax,cl              ; AX = z*8: east
        pop  cx
        ret

; ---- VERTC: BX = &face[f][k] -> AX, DX, DI = that vertex in CELLS --------
VERTC:  mov  al,[bx]
        xor  ah,ah
        mov  si,ax
        shl  si,1
        add  si,ax
        add  si,si              ; SI = v*6
        add  si,[mvb]
        mov  ax,[si]            ; x
        mov  dx,[si+2]          ; y
        mov  di,[si+4]          ; z
        ret

; ============================================================================
;  AREA - the face at [fptr]: AX = its area, in squares of the paper.
;
;  A four-sided face's area is half the length of the cross product of its
;  two diagonals - and a triangle, a face with one corner twice, comes out
;  right by the same sum. The length is a square root of a double word:
;  x*x + y*y + z*z can be 150 million.
;  In C:
;      d1 = V[c] - V[a];  d2 = V[d] - V[b];
;      n  = cross(d1, d2);
;      return isqrt32(n.x*n.x + n.y*n.y + n.z*n.z) / 2;
; ============================================================================
AREA:   mov  bx,[fptr]
        add  bx,2               ; ---- d1 = c - a ----
        call VERTC
        mov  [d1x],ax
        mov  [d1y],dx
        mov  [d1z],di
        mov  bx,[fptr]
        call VERTC
        sub  [d1x],ax
        sub  [d1y],dx
        sub  [d1z],di
        mov  bx,[fptr]          ; ---- d2 = d - b ----
        add  bx,3
        call VERTC
        mov  [d2x],ax
        mov  [d2y],dx
        mov  [d2z],di
        mov  bx,[fptr]
        inc  bx
        call VERTC
        sub  [d2x],ax
        sub  [d2y],dx
        sub  [d2z],di
        mov  ax,[d1y]           ; ---- n.x = d1y*d2z - d1z*d2y ----
        imul word [d2z]
        mov  cx,ax
        mov  ax,[d1z]
        imul word [d2y]
        sub  cx,ax
        mov  [nxx],cx
        mov  ax,[d1z]           ; ---- n.y = d1z*d2x - d1x*d2z ----
        imul word [d2x]
        mov  cx,ax
        mov  ax,[d1x]
        imul word [d2z]
        sub  cx,ax
        mov  [nyy],cx
        mov  ax,[d1x]           ; ---- n.z = d1x*d2y - d1y*d2x ----
        imul word [d2y]
        mov  cx,ax
        mov  ax,[d1y]
        imul word [d2x]
        sub  cx,ax
        mov  [nzz],cx
        mov  ax,[nxx]           ; ---- n.x^2 + n.y^2 + n.z^2, a double word
        imul ax                 ; DX:AX = n.x^2
        mov  [t32],ax
        mov  [t32+2],dx
        mov  ax,[nyy]
        imul ax                 ; DX:AX = n.y^2
        add  [t32],ax           ; added: the low words...
        adc  [t32+2],dx         ; ...and the high, with the carry
        mov  ax,[nzz]
        imul ax                 ; DX:AX = n.z^2
        add  [t32],ax
        adc  [t32+2],dx
        call ISQRT32            ; AX = the square root
        shr  ax,1               ; AX = /2: the area
        ret

; ---- ISQRT32: AX = the square root of the double word [t32] ---------------
;  Newton, lesson 1D's: a guess too big, then the average of the guess and
;  T over the guess, ten times. Start at 16384: past every root here, and
;  T/16384 fits a word, so DIV cannot fault.
ISQRT32:
        mov  ax,[t32]
        or   ax,[t32+2]         ; T = 0?
        jz   .x                 ;   then the root is 0 (AX = 0)
        mov  bx,16384           ; BX = g, the guess
        mov  cx,10              ; ten rounds
.r:     mov  ax,[t32]           ; DX:AX = T
        mov  dx,[t32+2]
        div  bx                 ; AX = T/g
        add  ax,bx              ; AX = g + T/g  (a word: both are < 32768)
        shr  ax,1               ; AX = the average: the next guess
        jz   .x                 ; (never 0 for T > 0, but a DIV by 0 hangs)
        mov  bx,ax              ; g = it
        loop .r
        mov  ax,bx              ; AX = g
.x:     ret

; ---- ISQRT: AX = n -> AX = the smallest s with s*s >= n (n < 2000) -------
ISQRT:  push bx
        push dx
        mov  bx,ax              ; BX = n
        xor  ax,ax              ; AX = s, from 0
.l:     inc  ax                 ; s++
        push ax
        mul  ax                 ; AX = s*s
        cmp  ax,bx              ; past n?
        pop  ax
        jb   .l
        pop  dx
        pop  bx
        ret

; ============================================================================
;  FIRE - the shell strikes. Everything the breakup will ever do is decided
;  here, in two passes over the pieces.
;
;  THE SHELL comes along the direction theta, (sin, 0, cos), and strikes
;  HITR short of the aeroplane's centre of mass, on the side it comes from:
;      P = cm - dir * HITR
;
;  PASS 1, THE BLAST. Each piece is pushed away from P, along d = centre - P,
;  by an amount that falls with the distance:
;      s = KBLAST / ((|d|/8)^2 + D0SQ)          J = s * d
;  (the /8 keeps the square in a word; D0SQ keeps a piece AT the hit from
;  being pushed infinitely hard). The pushes are summed - a double word.
;
;  THE NO-NET-PUSH. A blast is the aeroplane pushing on itself, so the sum
;  of all its pushes must be nothing. It is not, as computed - so the sum
;  is shared back out by mass, and taken off:
;      dv_i = J_i/m_i - SUM(J)/M
;  Multiply by m_i and add over the pieces: SUM(m dv) = SUM(J) - SUM(J) = 0.
;
;  THE SHELL'S OWN MOMENTUM is the only push from outside, and every piece
;  gets an equal share per unit of mass - so the whole moves by p/M:
;      dv += KSHELL * dir / M
;
;  PASS 2 adds all that to each piece, and spins it: the push's sideways
;  part, over m times the piece's size, clamped to SPINMAX.
; ============================================================================
FIRE:   cmp  byte [mode],0      ; whole?
        je   .go
        ret                     ;   no: a shell for a wreck is wasted
.go:    call CMASS              ; cmx, cmy, cmz = the centre of mass now
        mov  ax,[theta]         ; ---- the shell's direction ----
        call SINQ
        mov  [dsin],ax          ; dsin = sin(theta)*256
        mov  ax,[theta]
        add  ax,64
        call SINQ
        mov  [dcos],ax          ; dcos = cos(theta)*256
        mov  ax,[dsin]          ; ---- P = cm - dir*HITR ----
        mov  bx,HITR
        imul bx
        mov  al,ah              ; /256
        mov  ah,dl
        neg  ax
        add  ax,[cmx]
        mov  [hpx],ax
        mov  ax,[cmy]
        mov  [hpy],ax
        mov  ax,[dcos]
        mov  bx,HITR
        imul bx
        mov  al,ah
        mov  ah,dl
        neg  ax
        add  ax,[cmz]
        mov  [hpz],ax
        mov  word [sjx],0       ; ---- PASS 1: the pushes, summed ----
        mov  word [sjx+2],0
        mov  word [sjy],0
        mov  word [sjy+2],0
        mov  word [sjz],0
        mov  word [sjz+2],0
        xor  si,si              ; SI = the piece, a word each
.p1:    mov  ax,[QX+si]         ; d = centre - P
        sub  ax,[hpx]
        mov  [DJX+si],ax
        mov  ax,[QY+si]
        sub  ax,[hpy]
        mov  [DJY+si],ax
        mov  ax,[QZ+si]
        sub  ax,[hpz]
        mov  [DJZ+si],ax
        mov  ax,[DJX+si]        ; (|d|/8)^2 = (dx/8)^2 + (dy/8)^2 + (dz/8)^2
        mov  cl,3
        sar  ax,cl              ; AX = dx/8
        imul ax                 ; AX = its square (a word: |dx/8| < 60)
        mov  bx,ax
        mov  ax,[DJY+si]
        sar  ax,cl
        imul ax
        add  bx,ax
        mov  ax,[DJZ+si]
        sar  ax,cl
        imul ax
        add  bx,ax              ; BX = (|d|/8)^2
        add  bx,D0SQ            ; BX += the softening
        mov  ax,KBLAST          ; DX:AX = KBLAST
        xor  dx,dx
        div  bx                 ; AX = s = KBLAST / it
        mov  [PS+si],ax         ; kept for pass 2
        mov  cx,ax              ; CX = s
        mov  ax,[DJX+si]        ; J = s * d, each part, into the sums
        imul cx                 ; DX:AX = s*dx (a word in fact, < 21000)
        mov  [DJX+si],ax        ; DJX = Jx from here on
        add  [sjx],ax           ; sum += it: the low words...
        adc  [sjx+2],dx         ; ...and the high, with the carry
        mov  ax,[DJY+si]
        imul cx
        mov  [DJY+si],ax
        add  [sjy],ax
        adc  [sjy+2],dx
        mov  ax,[DJZ+si]
        imul cx
        mov  [DJZ+si],ax
        add  [sjz],ax
        adc  [sjz+2],dx
        add  si,2
        mov  bx,[nfc]
        add  bx,bx
        cmp  si,bx
        jb   .p1
        mov  bx,[msum]          ; ---- SUM(J)/M, to be taken off ----
        mov  ax,[sjx]
        mov  dx,[sjx+2]
        idiv bx                 ; AX = SUM(Jx)/M
        mov  [cjx],ax
        mov  ax,[sjy]
        mov  dx,[sjy+2]
        idiv bx
        mov  [cjy],ax
        mov  ax,[sjz]
        mov  dx,[sjz+2]
        idiv bx
        mov  [cjz],ax
        mov  ax,KSHELL          ; ---- the shell's share: KSHELL*dir/M ----
        imul word [dsin]        ; DX:AX = KSHELL*sin*256... /256 below
        idiv bx                 ; AX = KSHELL*sin/M  (sin is *256, and so
        mov  [shx],ax           ;  is a velocity: the 256s agree)
        mov  ax,KSHELL
        imul word [dcos]
        idiv bx
        mov  [shz],ax
        xor  si,si              ; ---- PASS 2: each piece's new velocity
        xor  di,di              ; DI = the piece, a byte each
.p2:    mov  bx,[PM+si]         ; BX = m
        mov  ax,[DJX+si]        ; vx += Jx/m - SUM(Jx)/M + shell
        cwd
        idiv bx
        sub  ax,[cjx]
        add  ax,[shx]
        add  [PVXW+si],ax
        mov  ax,[DJY+si]        ; vy += Jy/m - SUM(Jy)/M
        cwd
        idiv bx
        sub  ax,[cjy]
        add  [PVYW+si],ax
        mov  ax,[DJZ+si]        ; vz += Jz/m - SUM(Jz)/M + shell
        cwd
        idiv bx
        sub  ax,[cjz]
        add  ax,[shz]
        add  [PVZW+si],ax
        mov  ax,bx              ; ---- the spin: J / (m * size) ----
        mul  word [PSZ+si]      ; AX = m*size (a word: < 400*20)
        mov  bx,ax              ; BX = it
        mov  ax,[DJZ+si]        ; about the piece's own x: from Jz
        call SPINOF             ; AX = Jz/(m*size), clamped
        mov  [PWA+si],ax
        mov  ax,[DJX+si]        ; about its own y: from Jx
        call SPINOF
        mov  [PWB+si],ax
        add  si,2
        inc  di
        cmp  di,[nfc]
        jb   .p2
        mov  ax,[cmx]           ; ---- the whole aeroplane, for the path:
        mov  [GX],ax            ;  where the centre of mass is, at the
        mov  ax,[cmy]           ;  aeroplane's speed plus the shell's share
        mov  [GY],ax
        mov  ax,[cmz]
        mov  [GZ],ax
        mov  byte [GFX],0
        mov  byte [GFY],0
        mov  byte [GFZ],0
        mov  ax,[spd]
        mov  ah,al
        xor  al,al              ; AX = spd*256
        add  ax,[shx]
        mov  [GVX],ax
        mov  word [GVY],0
        mov  ax,[shz]
        mov  [GVZ],ax
        mov  byte [mode],1      ; broken
        mov  word [timer],RESET
        mov  byte [flash],3     ; and the flash: three frames
        mov  si,PALFL
        call SETPAL
        ret

; ---- SPINOF: AX = a push part, BX = m*size -> AX = the spin, clamped ------
SPINOF: cwd
        idiv bx                 ; AX = J/(m*size)
        cmp  ax,SPINMAX
        jle  .a
        mov  ax,SPINMAX
.a:     cmp  ax,-SPINMAX
        jge  .b
        mov  ax,-SPINMAX
.b:     ret

; ============================================================================
;  STEP - one frame of the laws.
;  In C:
;      for each piece not on the floor, and the whole aeroplane too:
;          if (broken) { v.y -= GRAV;  v -= v/128; }
;          pos += v;                         /* 16.8 fixed point, by ADC */
;          if (broken) { a += wa;  b += wb; }
;          if (pos.y <= FLOOR) { pos.y = FLOOR;  v = 0;  w = 0;  landed; }
;      while whole: past XSTOP, the whole aeroplane goes back to XSTART
; ============================================================================
STEP:   xor  si,si              ; SI = the piece, a word each
        xor  di,di              ; DI = the piece, a byte each
.s:     cmp  byte [PLAND+di],0  ; on the floor?
        jne  .nx                ;   it stays there
        cmp  byte [mode],0      ; whole?
        je   .mv                ;   then no gravity and no air: the wing
                                ;   holds it up and the engine pays for it
        sub  word [PVYW+si],GRAV    ; gravity, the same for every piece
        lea  bx,[PVXW+si]       ; the air, on all three parts
        call DRAG
        lea  bx,[PVYW+si]
        call DRAG
        lea  bx,[PVZW+si]
        call DRAG
        mov  ax,[PWA+si]        ; the turn goes on: a += wa, b += wb
        add  [PA+si],ax
        and  word [PA+si],4095  ; a circle is 256 steps of 16ths
        mov  ax,[PWB+si]
        add  [PB+si],ax
        and  word [PB+si],4095
.mv:    mov  ax,[PVXW+si]       ; ---- pos += v, three times: 16.8 ----
        add  [QFX+di],al        ;  the fraction byte takes the low byte...
        mov  al,ah
        cbw                     ;  ...and the high byte, signed,
        adc  [QX+si],ax         ;  goes to the units with the carry
        mov  ax,[PVYW+si]
        add  [QFY+di],al
        mov  al,ah
        cbw
        adc  [QY+si],ax
        mov  ax,[PVZW+si]
        add  [QFZ+di],al
        mov  al,ah
        cbw
        adc  [QZ+si],ax
        cmp  word [QY+si],FLOOR ; ---- the floor ----
        jg   .nx
        mov  word [QY+si],FLOOR ; on it...
        xor  ax,ax
        mov  [PVXW+si],ax       ; ...stopped dead...
        mov  [PVYW+si],ax
        mov  [PVZW+si],ax
        mov  [PWA+si],ax        ; ...and still
        mov  [PWB+si],ax
        mov  byte [PLAND+di],1
.nx:    add  si,2
        inc  di
        cmp  di,[nfc]
        jb   .s
        cmp  byte [mode],0      ; ---- whole: round again at the edge ----
        jne  .ghost
        mov  ax,[QX]            ; the first piece says where it is
        cmp  ax,XSTOP
        jl   .x
        xor  si,si              ; all of them back by the width of the stand
.w:     sub  word [QX+si],XSTOP-XSTART
        add  si,2
        mov  bx,[nfc]
        add  bx,bx
        cmp  si,bx
        jb   .w
.x:     ret
.ghost: cmp  word [GY],FLOOR    ; ---- the whole aeroplane's path ----
        jle  .x                 ; it stops on the floor too
        sub  word [GVY],GRAV    ; the same laws, the same numbers
        mov  bx,GVX
        call DRAG
        mov  bx,GVY
        call DRAG
        mov  bx,GVZ
        call DRAG
        mov  ax,[GVX]
        add  [GFX],al
        mov  al,ah
        cbw
        adc  [GX],ax
        mov  ax,[GVY]
        add  [GFY],al
        mov  al,ah
        cbw
        adc  [GY],ax
        mov  ax,[GVZ]
        add  [GFZ],al
        mov  al,ah
        cbw
        adc  [GZ],ax
        test word [fcount],7    ; every eighth frame, a dot of its path
        jnz  .x
        mov  bx,[ntrail]
        cmp  bx,64              ; room for 64
        jae  .x
        add  bx,bx
        mov  ax,[GX]
        mov  [TRX+bx],ax
        mov  ax,[GY]
        mov  [TRY+bx],ax
        mov  ax,[GZ]
        mov  [TRZ+bx],ax
        inc  word [ntrail]
        ret

; ---- DRAG: the word at BX loses 1/128 of itself --------------------------
;  SAR 7 rounds down, so a small negative speed would never reach nought:
;  -1 SAR 7 is -1 for ever. Round towards nought instead: add 127 first
;  when it is negative.
DRAG:   mov  ax,[bx]            ; AX = v
        or   ax,ax
        jns  .p
        add  ax,127             ; negative: round towards nought
.p:     mov  cl,7
        sar  ax,cl              ; AX = v/128
        sub  [bx],ax            ; v -= it
        ret

; ---- CMASS: cmx, cmy, cmz = the centre of mass of every piece ------------
;  SUM(m * pos) / SUM(m): three double-word sums and three divides.
CMASS:  xor  ax,ax
        mov  [smx],ax
        mov  [smx+2],ax
        mov  [smy],ax
        mov  [smy+2],ax
        mov  [smz],ax
        mov  [smz+2],ax
        xor  si,si
.c:     mov  bx,[PM+si]         ; BX = m
        mov  ax,[QX+si]
        imul bx                 ; DX:AX = m*x
        add  [smx],ax
        adc  [smx+2],dx
        mov  ax,[QY+si]
        imul bx
        add  [smy],ax
        adc  [smy+2],dx
        mov  ax,[QZ+si]
        imul bx
        add  [smz],ax
        adc  [smz+2],dx
        add  si,2
        mov  bx,[nfc]
        add  bx,bx
        cmp  si,bx
        jb   .c
        mov  bx,[msum]          ; and over the total mass
        mov  ax,[smx]
        mov  dx,[smx+2]
        idiv bx
        mov  [cmx],ax
        mov  ax,[smy]
        mov  dx,[smy+2]
        idiv bx
        mov  [cmy],ax
        mov  ax,[smz]
        mov  dx,[smz+2]
        idiv bx
        mov  [cmz],ax
        ret

; ============================================================================
;  DRAWALL - every piece's four corners in the world, then the painter.
;
;  A corner is the piece's centre plus its offset, turned by the piece's
;  two angles: a about its own x (the offset's y and z), then b about its
;  own y (x and z). Lesson 1E's rotate, twice. Whole, both angles are
;  nought and the turn changes nothing - the corners are the model's.
; ============================================================================
DRAWALL:
        xor  bp,bp              ; BP = the piece
.pc:    mov  si,bp
        add  si,si              ; SI = f*2
        mov  ax,[PA+si]         ; the two angles' sines and cosines
        mov  cl,4
        shr  ax,cl              ; AX = a, in steps
        push ax
        call SINQ
        mov  [sa],ax
        pop  ax
        add  ax,64
        call SINQ
        mov  [ca],ax
        mov  si,bp
        add  si,si
        mov  ax,[PB+si]
        mov  cl,4
        shr  ax,cl
        push ax
        call SINQ
        mov  [sb],ax
        pop  ax
        add  ax,64
        call SINQ
        mov  [cb],ax
        xor  cx,cx              ; CX = the corner
.k:     mov  si,bp
        shl  si,1
        shl  si,1
        add  si,cx
        add  si,si              ; SI = (f*4 + k)*2
        push cx
        mov  ax,[ROY+si]        ; y' = (y ca - z sa)/256
        imul word [ca]
        mov  al,ah
        mov  ah,dl
        mov  bx,ax
        mov  ax,[ROZ+si]
        imul word [sa]
        mov  al,ah
        mov  ah,dl
        sub  bx,ax
        mov  [ry1],bx
        mov  ax,[ROY+si]        ; z' = (y sa + z ca)/256
        imul word [sa]
        mov  al,ah
        mov  ah,dl
        mov  bx,ax
        mov  ax,[ROZ+si]
        imul word [ca]
        mov  al,ah
        mov  ah,dl
        add  bx,ax
        mov  [rz1],bx
        mov  ax,[ROX+si]        ; x" = (x cb + z' sb)/256
        imul word [cb]
        mov  al,ah
        mov  ah,dl
        mov  bx,ax
        mov  ax,[rz1]
        imul word [sb]
        mov  al,ah
        mov  ah,dl
        add  bx,ax
        mov  [rx2],bx
        mov  ax,[rz1]           ; z" = (z' cb - x sb)/256
        imul word [cb]
        mov  al,ah
        mov  ah,dl
        mov  bx,ax
        mov  ax,[ROX+si]
        imul word [sb]
        mov  al,ah
        mov  ah,dl
        sub  bx,ax
        mov  [rz2],bx
        mov  di,bp
        add  di,di              ; DI = f*2: the piece's centre
        mov  ax,[QX+di]         ; the corner, in the world
        add  ax,[rx2]
        mov  [CAX+si],ax
        mov  ax,[QY+di]
        add  ax,[ry1]
        mov  [CAY+si],ax
        mov  ax,[QZ+di]
        add  ax,[rz2]
        mov  [CAZ+si],ax
        pop  cx
        inc  cx
        cmp  cx,4
        jb   .k
        inc  bp
        cmp  bp,[nfc]
        jb   .pc
        xor  si,si              ; ---- each piece's depth: halves of halves
.fd:    mov  ax,si
        mov  cl,3
        shl  ax,cl              ; AX = f*8: its four corners
        mov  bx,ax
        mov  cx,[CAZ+bx]
        add  cx,[CAZ+bx+2]
        sar  cx,1
        mov  dx,[CAZ+bx+4]
        add  dx,[CAZ+bx+6]
        sar  dx,1
        add  cx,dx
        sar  cx,1               ; CX = the average of four
        mov  bx,si
        add  bx,bx
        mov  [FCD+bx],cx
        mov  ax,si
        mov  [FCO+si],al
        inc  si
        cmp  si,[nfc]
        jb   .fd
        mov  cx,[nfc]           ; ---- the bubble, far to near ----
        dec  cx
.bs:    push cx
        xor  si,si
.bi:    mov  bx,si
        add  bx,bx
        mov  ax,[FCD+bx]
        cmp  ax,[FCD+bx+2]
        jge  .nsw
        xchg ax,[FCD+bx+2]
        mov  [FCD+bx],ax
        mov  al,[FCO+si]
        xchg al,[FCO+si+1]
        mov  [FCO+si],al
.nsw:   inc  si
        mov  bx,[nfc]
        dec  bx
        cmp  si,bx
        jb   .bi
        pop  cx
        loop .bs
        mov  ax,[bufseg]        ; ---- paint, far to near ----
        mov  es,ax
        mov  word [pfc],0
.df:    mov  si,[pfc]
        mov  al,[FCO+si]        ; AL = the piece in this place
        xor  ah,ah
        mov  di,ax
        mov  bl,[PCOL+di]
        mov  [COLOR],bl         ; its colour
        mov  cl,3
        shl  ax,cl              ; AX = f*8
        mov  si,ax
        xor  di,di
.dc:    mov  ax,[CAX+si]
        mov  [IX+di],ax
        mov  ax,[CAY+si]
        mov  [IY+di],ax
        mov  ax,[CAZ+si]
        mov  [IZ+di],ax
        add  si,2
        add  di,2
        cmp  di,8
        jb   .dc
        call FACEFILL
        inc  word [pfc]
        mov  ax,[nfc]
        cmp  [pfc],ax
        jb   .df
        ret

; ---- GRID: the floor's squares, every 200 units -----------------------------
GRID:   mov  byte [COLOR],GRIDC
        mov  word [gk],-2000    ; ---- the lines running away from you ----
.ga:    mov  ax,[gk]
        mov  [w0x],ax
        mov  [w1x],ax
        mov  word [w0z],400
        mov  word [w1z],3000
        mov  word [w0y],FLOOR
        mov  word [w1y],FLOOR
        call WLINE
        add  word [gk],200
        cmp  word [gk],2000
        jle  .ga
        mov  word [gk],400      ; ---- and across ----
.gb:    mov  ax,[gk]
        mov  [w0z],ax
        mov  [w1z],ax
        mov  word [w0x],-2000
        mov  word [w1x],2000
        mov  word [w0y],FLOOR
        mov  word [w1y],FLOOR
        call WLINE
        add  word [gk],200
        cmp  word [gk],3000
        jle  .gb
        ret

; ---- WLINE: a line in the world, w0 to w1, through the lens -------------
WLINE:  mov  ax,[w0x]
        mov  dx,[w0y]
        mov  cx,[w0z]
        call PROJPT             ; AX, DX = the screen
        mov  [sx0],ax
        mov  [sy0],dx
        mov  ax,[w1x]
        mov  dx,[w1y]
        mov  cx,[w1z]
        call PROJPT
        mov  [sx1],ax
        mov  [sy1],dx
        mov  ax,[bufseg]
        mov  es,ax
        call CLIPLINE           ; on the screen at all?
        jc   .x
        call LINE
.x:     ret

; ============================================================================
;  MARKS - the shell's line before the hit; after it, the whole aeroplane's
;  path in amber dots and the centre of mass as a red cross.
; ============================================================================
MARKS:  cmp  byte [mode],0
        jne  .broken
        call CMASS              ; ---- whole: where the shell will come from
        mov  ax,[theta]
        call SINQ
        mov  [dsin],ax
        mov  ax,[theta]
        add  ax,64
        call SINQ
        mov  [dcos],ax
        mov  byte [COLOR],SHELLC
        mov  bx,240             ; from 240 out...
        call SHPT
        mov  [w0x],ax
        mov  [w0z],dx
        mov  bx,HITR            ; ...to where it strikes
        call SHPT
        mov  [w1x],ax
        mov  [w1z],dx
        mov  ax,[cmy]
        mov  [w0y],ax
        mov  [w1y],ax
        call WLINE
        ret
.broken:
        mov  byte [COLOR],GHOSTC    ; ---- the path: a dot each ----
        xor  si,si
.t:     cmp  si,[ntrail]
        jae  .cm
        push si
        add  si,si
        mov  ax,[TRX+si]
        mov  dx,[TRY+si]
        mov  cx,[TRZ+si]
        call DOT2
        pop  si
        inc  si
        jmp  .t
.cm:    mov  ax,[GX]            ; the whole aeroplane, now
        mov  dx,[GY]
        mov  cx,[GZ]
        call DOT2
        call CMASS              ; ---- the centre of mass: a red cross ----
        mov  ax,[cmx]
        mov  dx,[cmy]
        mov  cx,[cmz]
        call PROJPT
        mov  [msx],ax
        mov  [msy],dx
        mov  byte [COLOR],CMCOL
        mov  ax,[msx]           ; across
        sub  ax,5
        mov  [sx0],ax
        add  ax,10
        mov  [sx1],ax
        mov  ax,[msy]
        mov  [sy0],ax
        mov  [sy1],ax
        call CLIPLINE
        jc   .c2
        call LINE
.c2:    mov  ax,[msx]           ; and down
        mov  [sx0],ax
        mov  [sx1],ax
        mov  ax,[msy]
        sub  ax,5
        mov  [sy0],ax
        add  ax,10
        mov  [sy1],ax
        call CLIPLINE
        jc   .c3
        call LINE
.c3:    ret

; ---- SHPT: BX = how far out -> AX, DX = cm - dir*BX, x and z -------------
SHPT:   mov  ax,[dsin]
        imul bx                 ; DX:AX = sin*256*r
        mov  al,ah              ; /256
        mov  ah,dl
        neg  ax
        add  ax,[cmx]
        push ax
        mov  ax,[dcos]
        imul bx
        mov  al,ah
        mov  ah,dl
        neg  ax
        add  ax,[cmz]
        mov  dx,ax
        pop  ax
        ret

; ---- DOT2: AX, DX, CX = a world point -> a 2x2 dot in [COLOR] ------------
DOT2:   call PROJPT
        cmp  ax,1
        jl   .x
        cmp  ax,318
        jg   .x
        cmp  dx,1
        jl   .x
        cmp  dx,198
        jg   .x
        mov  bx,ax
        mov  ax,dx
        mov  cx,320
        mul  cx                 ; AX = y*320
        add  ax,bx
        mov  di,ax
        mov  ax,[bufseg]
        mov  es,ax
        mov  al,[COLOR]
        mov  [es:di],al
        mov  [es:di+1],al
        mov  [es:di+320],al
        mov  [es:di+321],al
.x:     ret

; ============================================================================
;  WORDS - the stand's card: what flies, how fast, where the shell comes
;  from, the mass; and the legend.
; ============================================================================
WORDS:  mov  bx,[cmodel]        ; the type's name
        add  bx,bx
        mov  si,[TNAME+bx]
        mov  byte [tcol],28
        mov  ax,4
        mov  bx,8
        call TXT
        mov  ax,[spd]           ; SPEED n
        add  al,'0'
        mov  [MSPD+6],al
        mov  si,MSPD
        mov  ax,4
        mov  bx,128
        call TXT
        mov  ax,[msum]          ; MASS nnnn
        mov  di,MMAS+8
        call NUM4
        mov  si,MMAS
        mov  ax,4
        mov  bx,216
        call TXT
        mov  bx,[theta]         ; SHELL FROM ...: sixteen names, one a step
        mov  cl,4
        shr  bx,cl              ; BX = theta/16
        add  bx,bx
        mov  si,MSHF
        mov  byte [tcol],30
        mov  ax,14
        mov  bx,8
        call TXT
        mov  bx,[theta]
        mov  cl,4
        shr  bx,cl
        add  bx,bx
        mov  si,[FROMN+bx]
        mov  ax,14
        mov  bx,96
        call TXT
        mov  byte [tcol],28
        cmp  byte [slow],0
        je   .ns
        mov  si,MSLOW
        mov  ax,14
        mov  bx,264
        call TXT
.ns:    cmp  byte [mode],0
        je   .keys
        mov  byte [tcol],CMCOL    ; the legend, once it is broken
        mov  si,MLEG1
        mov  ax,180
        mov  bx,8
        call TXT
        mov  byte [tcol],GHOSTC
        mov  si,MLEG2
        mov  ax,190
        mov  bx,8
        call TXT
        ret
.keys:  mov  byte [tcol],28
        mov  si,MKEYS
        mov  ax,190
        mov  bx,8
        call TXT
        ret

; ---- NUM4: AX -> four places, right-aligned, ending at DI ---------------
NUM4:   mov  byte [di],' '
        mov  byte [di-1],' '
        mov  byte [di-2],' '
        mov  bx,10
.d:     xor  dx,dx
        div  bx                 ; AX = n/10, DX = the last digit
        add  dl,'0'
        mov  [di],dl
        dec  di
        or   ax,ax
        jnz  .d
        ret

; ---- TXT: ASCIIZ at SI -> the buffer at (BX, AX), colour [tcol] ----------
;  The PC's ROM font at F000:FA6E - lesson 1A's first kind of letters.
TXT:    push es
        push dx
        mov  cx,ax
        mov  ax,[bufseg]
        mov  es,ax
        mov  ax,cx
        mov  cx,320
        mul  cx                 ; AX = y*320
        add  ax,bx              ; AX = y*320 + x
        mov  di,ax
.ch:    lodsb
        or   al,al
        jz   .done
        push si
        xor  ah,ah
        mov  cl,3
        shl  ax,cl              ; AX = char*8
        mov  si,0FA6Eh
        add  si,ax
        push ds
        mov  ax,0F000h
        mov  ds,ax              ; DS = the ROM
        mov  cx,8
        push di
.row:   lodsb
        mov  ah,al
        push cx
        mov  cx,8
.px:    shl  ah,1
        jnc  .np
        mov  al,[cs:tcol]
        mov  [es:di],al
.np:    inc  di
        loop .px
        add  di,320-8
        pop  cx
        loop .row
        pop  di
        pop  ds
        pop  si
        add  di,8
        jmp  .ch
.done:  pop  dx
        pop  es
        ret

; ---- WAITVR: the vertical retrace's start ----------------------------------
WAITVR: mov  dx,3DAh
.w1:    in   al,dx
        test al,8
        jnz  .w1
.w2:    in   al,dx
        test al,8
        jz   .w2
        ret

; ---- SETPAL: [colour, r, g, b] ... 255 at SI into the DAC ------------------
SETPAL: lodsb
        cmp  al,255
        je   .done
        mov  dx,3C8h
        out  dx,al
        inc  dx
        lodsb
        out  dx,al
        lodsb
        out  dx,al
        lodsb
        out  dx,al
        jmp  SETPAL
.done:  ret
PAL     db SKYC,   34,46,58     ; the sky
        db FLOORC, 22,26,20     ; the floor
        db GRIDC,  30,34,26     ; its squares
        db CMCOL,    63,12, 8     ; the centre of mass: red
        db GHOSTC, 63,42,10     ; the whole aeroplane's path: amber
        db SHELLC, 63,60,16     ; the shell: yellow
        db 16, 20,20,22         ; the aeroplanes: 1E's colours
        db 24, 52,52,56
        db 25, 34,34,38
        db 27, 44,44,46
        db 94, 63,40,10         ; the nozzle
        db 28, 56,56,56         ; grey words
        db 30, 63,42,10         ; amber words
        db 255
PALFL   db SKYC,   63,63,60     ; THE FLASH: two DAC entries, white
        db FLOORC, 50,50,46
        db 255

; ---- the words -------------------------------------------------------------
TNAME   dw TN0,TN1,TN2,TN3,TN4
TN0     db 'FIGHTER',0
TN1     db 'BOMBER',0
TN2     db 'RADAR PICKET',0
TN3     db 'TRANSPORT',0
TN4     db 'TANKER',0
MSPD    db 'SPEED 0',0
MMAS    db 'MASS     ',0
MSHF    db 'SHELL FROM',0
FROMN   dw FR0,FR1,FR2,FR3,FR4,FR5,FR6,FR7,FR8,FR9,FR10,FR11,FR12,FR13,FR14,FR15
FR0     db 'THE RIGHT',0        ; flying east: south is its right
FR1     db 'RIGHT, AFT',0
FR2     db 'BEHIND, RIGHT',0
FR3     db 'BEHIND, A BIT RIGHT',0
FR4     db 'BEHIND',0
FR5     db 'BEHIND, A BIT LEFT',0
FR6     db 'BEHIND, LEFT',0
FR7     db 'LEFT, AFT',0
FR8     db 'THE LEFT',0
FR9     db 'LEFT, FORWARD',0
FR10    db 'AHEAD, LEFT',0
FR11    db 'AHEAD, A BIT LEFT',0
FR12    db 'AHEAD',0
FR13    db 'AHEAD, A BIT RIGHT',0
FR14    db 'AHEAD, RIGHT',0
FR15    db 'RIGHT, FORWARD',0
MSLOW   db 'SLOW',0
MKEYS   db 'SPACE FIRE  ARROWS  W S  P  R',0
MLEG1   db '+ THE CENTRE OF MASS',0
MLEG2   db '. A WHOLE AEROPLANE, SAME LAWS',0

; ---- THE AIR FORCE: lesson 1E's tables, every number -----------------------
MVTAB   dw MVERT,MVERT1,MVERT2,MVERT3,MVERT4
MFTAB   dw MFACE,MFACE1,MFACE2,MFACE3,MFACE4
NFCTAB  dw 8,12,10,8,10
MVERT   dw   0,  1, 16          ; FIGHTER
        dw  -2,  2,-11
        dw   2,  2,-11
        dw  -2, -2,-11
        dw   2, -2,-11
        dw -13,  1, -8
        dw  13,  1, -8
        dw   0,  1,  6
        dw  -2,  1,-11
        dw   2,  1,-11
        dw   0,  2, -5
        dw   0,  7,-13
        dw   0,  2,-11
MFACE   db 0,1,2,0, 24
        db 0,3,4,0, 16
        db 0,1,3,0, 25
        db 0,2,4,0, 25
        db 7,5,8,7, 27
        db 7,6,9,7, 27
        db 10,11,12,10, 25
        db 1,2,4,3, 94
MVERT1  dw   0,  1, 34          ; BOMBER
        dw  -5,  5,-22
        dw   5,  5,-22
        dw  -5, -4,-22
        dw   5, -4,-22
        dw -28,  1, -6
        dw  28,  1, -6
        dw   0,  1, 10
        dw  -5,  1,-20
        dw   5,  1,-20
        dw   0,  5,-10
        dw   0, 13,-26
        dw   0,  5,-22
        dw -10,  0,  6
        dw -10,  0, -2
        dw -10, -4,  2
        dw -19,  0,  2
        dw -19,  0, -6
        dw -19, -4, -2
        dw  10,  0,  6
        dw  10,  0, -2
        dw  10, -4,  2
        dw  19,  0,  2
        dw  19,  0, -6
        dw  19, -4, -2
MFACE1  db 0,1,2,0, 24
        db 0,3,4,0, 16
        db 0,1,3,0, 25
        db 0,2,4,0, 25
        db 7,5,8,7, 27
        db 7,6,9,7, 27
        db 10,11,12,10, 25
        db 1,2,4,3, 94
        db 13,14,15,13, 16
        db 16,17,18,16, 16
        db 19,20,21,19, 16
        db 22,23,24,22, 16
MVERT2  dw   0,  2, 20          ; RADAR PICKET
        dw  -4,  5,-14
        dw   4,  5,-14
        dw  -4, -3,-14
        dw   4, -3,-14
        dw -18,  2, -2
        dw  18,  2, -2
        dw   0,  2,  6
        dw  -4,  2,-12
        dw   4,  2,-12
        dw   0,  5, -6
        dw   0,  9,-14
        dw   0,  5,-14
        dw   0, 10,  2
        dw   4, 10, -4
        dw   0, 10,-10
        dw  -4, 10, -4
        dw   0, 12, -4
        dw   0,  8, -4
MFACE2  db 0,1,2,0, 24
        db 0,3,4,0, 16
        db 0,1,3,0, 25
        db 0,2,4,0, 25
        db 7,5,8,7, 27
        db 7,6,9,7, 27
        db 10,11,12,10, 25
        db 1,2,4,3, 94
        db 13,14,15,16, 24
        db 13,17,15,18, 16
MVERT3  dw   0,  2, 18          ; TRANSPORT
        dw  -5,  6,-14
        dw   5,  6,-14
        dw  -5, -4,-14
        dw   5, -4,-14
        dw -20,  3, -2
        dw  20,  3, -2
        dw   0,  3,  6
        dw  -5,  3,-12
        dw   5,  3,-12
        dw   0,  6, -6
        dw   0, 12,-16
        dw   0,  6,-14
MFACE3  db 0,1,2,0, 24
        db 0,3,4,0, 16
        db 0,1,3,0, 25
        db 0,2,4,0, 25
        db 7,5,8,7, 27
        db 7,6,9,7, 27
        db 10,11,12,10, 25
        db 1,2,4,3, 94
MVERT4  dw   0,  2, 26          ; TANKER
        dw  -7,  7,-18
        dw   7,  7,-18
        dw  -7, -5,-18
        dw   7, -5,-18
        dw -22,  2, -4
        dw  22,  2, -4
        dw   0,  2,  8
        dw  -7,  2,-16
        dw   7,  2,-16
        dw   0,  7, -8
        dw   0, 13,-20
        dw   0,  7,-18
        dw -11,  1,  6
        dw -11,  1, -2
        dw -11, -4,  2
        dw  11,  1,  6
        dw  11,  1, -2
        dw  11, -4,  2
MFACE4  db 0,1,2,0, 24
        db 0,3,4,0, 16
        db 0,1,3,0, 25
        db 0,2,4,0, 25
        db 7,5,8,7, 27
        db 7,6,9,7, 27
        db 10,11,12,10, 25
        db 1,2,4,3, 94
        db 13,14,15,13, 16
        db 16,17,18,16, 16

; ---- the state ---------------------------------------------------------------
bufseg  dw 0
cmodel  dw 0                    ; which aeroplane: the fighter first
spd     dw 3                    ; its speed, units a frame
theta   dw 32                   ; where the shell travels: 32, from behind right
slow    db 0                    ; P
mode    db 0                    ; 0 whole, 1 broken
flash   db 0                    ; frames of white left
timer   dw 0                    ; frames till a new aeroplane
fcount  dw 0                    ; frames
tcol    db 28                   ; TXT's colour
rseed   dw 1                    ; RND16's state (E_MATH wants it)
mvb     dw MVERT                ; the type's tables
mfb     dw MFACE
nfc     dw 8
msum    dw 0                    ; the total mass
fptr    dw 0                    ; NEWPLANE, AREA: the face
sumx    dw 0                    ; NEWPLANE: a centre, being summed
sumy    dw 0
sumz    dw 0
cenx    dw 0                    ; ...and found
ceny    dw 0
cenz    dw 0
d1x     dw 0                    ; AREA: the diagonals...
d1y     dw 0
d1z     dw 0
d2x     dw 0
d2y     dw 0
d2z     dw 0
nxx     dw 0                    ; ...their cross product...
nyy     dw 0
nzz     dw 0
t32     dw 0,0                  ; ...and its length squared
dsin    dw 0                    ; the shell's direction, *256
dcos    dw 0
hpx     dw 0                    ; where it strikes
hpy     dw 0
hpz     dw 0
sjx     dw 0,0                  ; FIRE: the pushes, summed
sjy     dw 0,0
sjz     dw 0,0
cjx     dw 0                    ; ...and over M
cjy     dw 0
cjz     dw 0
shx     dw 0                    ; the shell's share of velocity
shz     dw 0
smx     dw 0,0                  ; CMASS: sum m*pos
smy     dw 0,0
smz     dw 0,0
cmx     dw 0                    ; the centre of mass
cmy     dw 0
cmz     dw 0
GX      dw 0                    ; THE WHOLE AEROPLANE, flown on by the same
GY      dw 0                    ;  laws from the hit: where...
GZ      dw 0
GFX     db 0                    ; ...its fractions...
GFY     db 0
GFZ     db 0
GVX     dw 0                    ; ...and its velocity
GVY     dw 0
GVZ     dw 0
ntrail  dw 0                    ; the dots of its path so far
TRX     dw 64 dup(0)
TRY     dw 64 dup(0)
TRZ     dw 64 dup(0)
sa      dw 0                    ; DRAWALL: a piece's angles, sin and cos
ca      dw 0
sb      dw 0
cb      dw 0
ry1     dw 0                    ; ...and a corner on its way round
rz1     dw 0
rx2     dw 0
rz2     dw 0
gk      dw 0                    ; GRID's line
w0x     dw 0                    ; WLINE's two ends
w0y     dw 0
w0z     dw 0
w1x     dw 0
w1y     dw 0
w1z     dw 0
msx     dw 0                    ; the cross on the screen
msy     dw 0
; ---- THE PIECES: twelve at most, every number a piece has ----------------
QX      dw MAXP dup(0)          ; where: units
QY      dw MAXP dup(0)
QZ      dw MAXP dup(0)
QFX     db MAXP dup(0)          ; ...and 256ths
QFY     db MAXP dup(0)
QFZ     db MAXP dup(0)
PVXW    dw MAXP dup(0)          ; its velocity, 256ths of a unit a frame
PVYW    dw MAXP dup(0)
PVZW    dw MAXP dup(0)
PA      dw MAXP dup(0)          ; its two angles, 16ths of a step
PB      dw MAXP dup(0)
PWA     dw MAXP dup(0)          ; ...and how fast they turn
PWB     dw MAXP dup(0)
PM      dw MAXP dup(0)          ; its mass: its area
PSZ     dw MAXP dup(0)          ; its size: the root of that
PS      dw MAXP dup(0)          ; FIRE: the blast's strength at it
DJX     dw MAXP dup(0)          ; FIRE: d, then the push J
DJY     dw MAXP dup(0)
DJZ     dw MAXP dup(0)
PLAND   db MAXP dup(0)          ; on the floor
PCOL    db MAXP dup(0)          ; its colour
ROX     dw MAXP*4 dup(0)        ; its four corners, from its centre
ROY     dw MAXP*4 dup(0)
ROZ     dw MAXP*4 dup(0)
CAX     dw MAXP*4 dup(0)        ; ...and in the world, this frame
CAY     dw MAXP*4 dup(0)
CAZ     dw MAXP*4 dup(0)
FCD     dw MAXP dup(0)          ; the painter's depths
FCO     db MAXP dup(0)          ; ...and order
; ---- the engine's contract: the camera straight and level -----------------
heading dw 0
pitch   dw 0
roll    dw 0
hsin    dw 0
hcos    dw 256
rsin    dw 0
rcos    dw 256
psin    dw 0
pcos    dw 256
pofs    dw 0
horiz   dw 100
swayx   dw 0
swayy   dw 0
wdx     dw 0
wdz     dw 0
rc_x    dw 0
rc_z    dw 0
rddx    dw 0
rddy    dw 0
rsxo    dw 0
ptmp    dw 0
pfc     dw 0
IX      dw 4 dup(0)
IY      dw 4 dup(0)
IZ      dw 4 dup(0)
OX      dw 6 dup(0)
OY      dw 6 dup(0)
OZ      dw 6 dup(0)
PX      dw 6 dup(0)
PY      dw 6 dup(0)
NPOLY   dw 0
oc      dw 0
ci      dw 0
ni      dw 0
pk      dw 0
pminy   dw 0
pmaxy   dw 0
scy     dw 0
scymax  dw 0
scxl    dw 0
scxr    dw 0
tnum    dw 0
tden    dw 0
cdx     dw 0
cdy     dw 0
nx      dw 0
ny      dw 0
oc0     db 0
oc1     db 0
ocsel   db 0
lx      dw 0
ly      dw 0
ldx     dw 0
ldy     dw 0
lsx     dw 0
lsy     dw 0
lerr    dw 0
sx0     dw 0
sy0     dw 0
sx1     dw 0
sy1     dw 0
COLOR   db 0
; the quarter sine: SINT[i] = round(256*sin(i*90/64 deg)), i = 0..64
SINT    dw 0,6,13,19,25,31,38,44,50,56,62,68,74,80,86,92,98,104,109,115
        dw 121,126,132,137,142,147,153,157,162,167,172,177,181,185,190,194
        dw 198,202,206,209,213,216,220,223,226,229,231,234,237,239,241,243
        dw 245,247,248,250,251,252,253,254,255,255,256,256,256

        include '..\..\ENGINE\E_MATH.INC'
        include '..\..\ENGINE\E_M3D.INC'
        include '..\..\ENGINE\E_RAST.INC'
