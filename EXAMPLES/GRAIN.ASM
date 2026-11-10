; ============================================================================
;  GRAIN.ASM - the grain: a lit aeroplane in 256 colours, with the shades
;  mixed on the screen by a 4x4 Bayer matrix. An 80386 program.
;
;      FASM GRAIN.ASM GRAIN.COM
;
;      G             how it is drawn: 8086 FLAT, 386 FLAT, 386 GRAIN, and
;                    GRAIN + NEON, the look
;      UP / DOWN     the next aeroplane: the F-15, then the hangar's five
;      LEFT / RIGHT  turn it slower, faster, the other way, or not at all
;      V             wait for the retrace, or run flat out to measure
;      ESC           back to DOS
;
;  THE IDEA. A face has one brightness, and the palette has only six shades
;  of a colour. Brightness 2.25 falls between shades 2 and 3 - so paint a
;  quarter of the face's pixels in shade 3 and the rest in shade 2, spread
;  evenly by a fixed matrix, and the eye mixes them. That is ordered
;  dithering. A pixel takes the brighter shade when the fraction is over the
;  matrix's number at that place on the screen:
;
;       0  8  2 10        16 numbers, 0..15, placed so that any fraction
;      12  4 14  6        lights its pixels as far apart as they can be
;       3 11  1  9
;      15  7 13  5
;
;  The grain stays visible on purpose: it is the look, not a flaw. OWL FLY
;  III already dithers its sky and its Hercules picture; the colour model
;  was seen on 3Dos, by M. Sami Gurpinar (github.com/xms0g/3Dos).
;
;  THE PHYSICAL FACT THIS PROGRAM HANDS OVER:
;
;      A ROW OF THE MATRIX IS FOUR PIXELS, AND FOUR PIXELS ARE ONE DOUBLE
;      WORD. 320 divides by four, so a pixel's place in the row is the low
;      two bits of its address. The whole face's grain is four double
;      words, made once a face; a span is then REP STOSD, four pixels a
;      write. Grain is not paid for per pixel: it costs what a flat fill
;      costs.
;
;  THE LIGHT is the 386's work too. A face's normal is a cross product of
;  two edges, in double words with IMUL into any register; BSR finds how
;  far to scale it down; a square root gives its length, and the brightness
;  is its dot product with the light over that length. The normal is turned
;  to face the eye: a face we see is always lit from our side of it.
;
;  WHAT IS BORROWED: the aeroplanes and the pipeline from LESSONS\L30\
;  HANGAR.ASM; ENGINE\E_CPU.INC (lesson 24), E_MATH, E_M3D, E_RAST. E_RAST
;  fills its spans through SPANFILL below because this file says SPANHOOK.
;  ENGINE\E_8086.INC is not here: this is not 8086 code.
;
;  Owlos - legacy software modernization - https://owlos.sk
; ============================================================================
FOCAL   = 220                 ; the game's lens, the island's too
NEARZ   = 40                  ; the near clip plane
MAXF    = 14                  ; the most faces any type has (the F-15)
MAXV    = 25                  ; the most vertices (the bomber)
TCOS    = 241                 ; cos 20 degrees * 256: the stand's tilt
TSIN    = 88                  ; sin 20 degrees * 256
SPANHOOK = 1                  ; E_RAST: fill a span through SPANFILL
NMODEL  = 6                   ; the F-15 and the hangar's five
RBODY   = 32                  ; the body's six shades, DAC 32..37
RWING   = 40                  ; the wings' six, DAC 40..45
RSKY    = 48                  ; the sky's six, DAC 48..53
EDGEB   = 60                  ; the body's neon edge
EDGEW   = 61                  ; the wings' neon edge
TOPT    = 80                  ; the brightest: shade 5 and no fraction
AMBIENT = 8                   ; what a face in shadow still shows
DIFFUSE = TOPT-AMBIENT        ; what the light adds
LIGHTX  = -181                ; towards the light, *256: left, up and
LIGHTY  = 128                 ;  on our side of the aeroplane
LIGHTZ  = -128

format binary as 'com'
        org 100h

START:  call NEED386            ; the first line asks: lesson 24
        cld                     ; STOSD and MOVSD walk up
        mov  ax,cs              ; AX = our segment
        add  ax,1000h           ; AX += 64K: the back buffer, above us
        mov  [bufseg],ax        ; bufseg = it
if defined TESTRUN
        mov  al,[82h]           ; the command line: mode, then model
        sub  al,'0'
        mov  [gmode],al
        mov  al,[84h]
        sub  al,'0'
        mov  byte [cmodel],al
        mov  byte [vsync],0     ; flat out
end if
        mov  ax,0013h           ; VGA 320x200, 256 colours
        int  10h
        call SETPAL             ; the ramps and the words
        call SETTRIG            ; the camera: straight and level
        call SETM               ; the first aeroplane on the stand
        call MKSKY              ; the sky's rows, flat and grained

; ---- one frame ---------------------------------------------------------------
FRAME:  mov  ax,[bufseg]        ; ---- the sky, over the last frame ----
        mov  es,ax              ; ES = the buffer
        call BACKDROP

        ; ---- 1. THE SPIN, and its sine and cosine ----------------------------
        mov  ax,[spd]           ; AX = the spin, steps a frame
        add  [mhead],ax         ; mhead += it
        and  word [mhead],255   ; mhead &= 255: a byte is the whole circle
        mov  ax,[mhead]         ; AX = mhead
        call SINQ               ; AX = sin(mhead)*256
        mov  [msin],ax          ; msin = it
        mov  ax,[mhead]         ; AX = mhead
        add  ax,64              ; a quarter on: the cosine
        call SINQ               ; AX = cos(mhead)*256
        mov  [mcos],ax          ; mcos = it

        ; ---- 2. EVERY VERTEX TURNED, TILTED AND PLACED, into PVX/PVY/PVZ ---
        ;   the spin, about the vertical - the island's rotate:
        ;     x' = (x cos + z sin) * 8/256        a cell is eight units
        ;     z' = (z cos - x sin) * 8/256
        ;     y' =  y * 8
        ;   the stand tilted 20 degrees, so we look a little down on it -
        ;   the same rotate again, about the line of the wings:
        ;     y" = (y' cos20 + z' sin20)/256 - 20    and a little low
        ;     z" = (z' cos20 - y' sin20)/256 + the stand's distance
        ; In C:
        ;   for (i = 0; i < nv; i++) {
        ;       x1 = (vx[i]*mcos + vz[i]*msin) / 32;
        ;       z1 = (vz[i]*mcos - vx[i]*msin) / 32;
        ;       y1 =  vy[i] * 8;
        ;       pvx[i] = x1;
        ;       pvy[i] = ((long)y1*TCOS + (long)z1*TSIN) / 256 - 20;
        ;       pvz[i] = ((long)z1*TCOS - (long)y1*TSIN) / 256 + pdzc;
        ;   }
        xor  si,si              ; SI = the vertex, 6 bytes each in the table
        xor  di,di              ; DI = the vertex, 2 bytes each in the cache
.tv:    mov  bx,[mvb]           ; BX = this type's vertex table
        mov  ax,[bx+si]         ; AX = x
        imul word [mcos]        ; AX = x*cos  (a word: |x| < 32, cos <= 256)
        mov  cx,ax              ; CX = it
        mov  ax,[bx+si+4]       ; AX = z
        imul word [msin]        ; AX = z*sin
        add  ax,cx              ; AX = x cos + z sin
        cwd                     ; DX:AX = it, signed, for IDIV
        mov  cx,32              ; CX = 32: *8 and /256 in one divide
        idiv cx                 ; AX = x', in units
        mov  [PVX+di],ax        ; x' kept: the tilt does not touch it
        mov  ax,[bx+si]         ; AX = x
        imul word [msin]        ; AX = x*sin
        mov  cx,ax              ; CX = it
        mov  ax,[bx+si+4]       ; AX = z
        imul word [mcos]        ; AX = z*cos
        sub  ax,cx              ; AX = z cos - x sin
        cwd                     ; DX:AX = it
        mov  cx,32              ; CX = 32
        idiv cx                 ; AX = z', in units
        mov  [tz],ax            ; tz = it
        mov  ax,[bx+si+2]       ; AX = y
        mov  cl,3               ; CL = 3
        shl  ax,cl              ; AX = y*8 = y'
        mov  [ty],ax            ; ty = it
        ; the tilt. y'*241 + z'*88 can pass 32767, so every product is a
        ; double word - IMUL leaves it in DX:AX - and IDIV takes DX:AX back
        mov  cx,TCOS            ; CX = cos20 * 256
        imul cx                 ; DX:AX = y' cos
        mov  bx,ax              ; BP:BX = it
        mov  bp,dx
        mov  ax,[tz]            ; AX = z'
        mov  cx,TSIN            ; CX = sin20 * 256
        imul cx                 ; DX:AX = z' sin
        add  ax,bx              ; DX:AX = y' cos + z' sin: the low words...
        adc  dx,bp              ; ...and the high, with the low's carry
        mov  cx,256             ; CX = 256
        idiv cx                 ; AX = /256
        sub  ax,20              ; AX -= 20: the aeroplane a little low
        mov  [PVY+di],ax        ; y" kept
        mov  ax,[tz]            ; AX = z'
        mov  cx,TCOS
        imul cx                 ; DX:AX = z' cos
        mov  bx,ax              ; BP:BX = it
        mov  bp,dx
        mov  ax,[ty]            ; AX = y'
        mov  cx,TSIN
        imul cx                 ; DX:AX = y' sin
        sub  bx,ax              ; BP:BX = z' cos - y' sin: the low words...
        sbb  bp,dx              ; ...and the high, with the low's borrow
        mov  ax,bx              ; DX:AX = it, for IDIV
        mov  dx,bp
        mov  cx,256             ; CX = 256
        idiv cx                 ; AX = /256
        add  ax,[pdzc]          ; AX += the stand's distance: in front of us
        mov  [PVZ+di],ax        ; z" kept
        add  si,6               ; the next vertex in the table
        add  di,2               ; and in the cache
        cmp  si,[mvn]           ; all of them?
        jb   .tv                ;   no

        ; ---- 3. THE FACES: corners, depths, and the painter's order --------
        call CORNERS            ; each face's four corners, from the cache
        call DEPTHS             ; each face's depth: the average of them
        call BUBBLE             ; far to near

        ; ---- 4. PAINT ---------------------------------------------------------
        mov  ax,[bufseg]        ; ES = the buffer, for every routine below
        mov  es,ax
        call PAINT              ; the faces, far to near
        call GLOW               ; the nozzle burns
        call SHEET              ; the words

        ; ---- the frame onto the screen ---------------------------------------
        cmp  byte [vsync],0     ; flat out?
        je   .nov
        call WAITVR             ; wait for the beam to go back up
.nov:   push ds                 ; keep DS
        mov  ax,0A000h          ; AX = the screen's segment
        mov  es,ax              ; ES = the screen
        mov  ds,[bufseg]        ; DS = the buffer
        xor  si,si              ; SI = 0
        xor  di,di              ; DI = 0
        mov  cx,16000           ; CX = 16000 double words
        rep  movsd              ; the buffer onto the screen
        pop  ds                 ; DS = ours again
        call COUNTFPS           ; one frame more
if defined TESTRUN
        call TESTEND
end if

        ; ---- the keys ---------------------------------------------------------
        mov  ah,1               ; a key waiting?
        int  16h
        jz   FRAME              ;   no: the next frame
        xor  ah,ah              ; yes: take it - AL = ASCII, AH = scan code
        int  16h
        cmp  al,27              ; ESC?
        je   QUIT
        and  al,0DFh            ; lower case to upper - lesson 1A's AND
        cmp  al,'G'             ; G?
        jne  .nv
        inc  byte [gmode]       ; the next way of drawing it
        cmp  byte [gmode],4     ; past the last?
        jb   FRAME
        mov  byte [gmode],0     ;   back to 8086 FLAT
        jmp  FRAME
.nv:    cmp  al,'V'             ; V?
        jne  .nw
        xor  byte [vsync],1     ; the retrace, on or off
        jmp  FRAME
.nw:    cmp  ah,48h             ; UP: the next aeroplane
        jne  .kdn
        inc  word [cmodel]      ; cmodel++
        cmp  word [cmodel],NMODEL ; past the last?
        jb   .set
        mov  word [cmodel],0    ;   back to the F-15
        jmp  .set
.kdn:   cmp  ah,50h             ; DOWN: the one before
        jne  .klf
        dec  word [cmodel]      ; cmodel--
        jns  .set               ; still nought or more?
        mov  word [cmodel],NMODEL-1 ;   no: the last
.set:   call SETM               ; roll it out
        jmp  FRAME
.klf:   cmp  ah,4Bh             ; LEFT: spin less, or the other way
        jne  .krt
        cmp  word [spd],-4      ; as far as it goes?
        jle  FRAME
        dec  word [spd]         ; spd--
        jmp  FRAME
.krt:   cmp  ah,4Dh             ; RIGHT: spin more
        jne  FRAME
        cmp  word [spd],4
        jge  FRAME
        inc  word [spd]         ; spd++
        jmp  FRAME

QUIT:   mov  ax,0003h           ; text mode again
        int  10h
        mov  ax,4C00h           ; and back to DOS
        int  21h

; ---- SETM: the aeroplane [cmodel] onto the stand - its tables, its sizes ----
SETM:   mov  bx,[cmodel]        ; BX = which
        add  bx,bx              ; BX *= 2: a word a type in each table
        mov  ax,[MVTAB+bx]      ; its vertex table
        mov  [mvb],ax
        mov  ax,[MVNTAB+bx]     ; how many bytes of it
        mov  [mvn],ax
        mov  ax,[MFTAB+bx]      ; its face table
        mov  [mfb],ax
        mov  ax,[NFCTAB+bx]     ; how many faces
        mov  [nfc],ax
        mov  ax,[PDZT+bx]       ; how far back it stands
        mov  [pdzc],ax
        ret

; ---- CORNERS: for each face, its four corners out of the vertex cache ------
;  CAX/CAY/CAZ hold four corners a face, eight bytes; the face table holds
;  five bytes a face - four vertex numbers and a colour.
CORNERS:
        mov  word [pfc],0       ; pfc = the face, from 0
.cf:    mov  si,[pfc]           ; SI = f
        mov  bx,si              ; BX = f
        shl  bx,1               ; BX = f*2
        shl  bx,1               ; BX = f*4
        add  bx,si              ; BX = f*5: five bytes a face
        add  bx,[mfb]           ; BX = &faces[f]
        mov  ax,si              ; AX = f
        mov  cl,3               ; CL = 3
        shl  ax,cl              ; AX = f*8: four words a face
        mov  di,ax              ; DI = the face's corners
        xor  cx,cx              ; CX = k, the corner, 0..3
.cc:    mov  si,cx              ; SI = k
        mov  al,[bx+si]         ; AL = the k-th vertex number of the face
        xor  ah,ah              ; AX = it
        add  ax,ax              ; AX = *2: a word a vertex in the cache
        mov  si,ax              ; SI = it
        mov  ax,[PVX+si]        ; that vertex, into the corner
        mov  [CAX+di],ax
        mov  ax,[PVY+si]
        mov  [CAY+di],ax
        mov  ax,[PVZ+si]
        mov  [CAZ+di],ax
        add  di,2               ; the next corner
        inc  cx                 ; k++
        cmp  cx,4               ; four?
        jb   .cc
        inc  word [pfc]         ; the next face
        mov  ax,[nfc]
        cmp  [pfc],ax           ; all of them?
        jb   .cf
        ret

; ---- DEPTHS: each face's depth = the average z of its corners --------------
;  Halves of halves - (a+b)/2 and (c+d)/2, then their average - so no sum
;  of four ever needs more than a word.
DEPTHS: mov  word [pfc],0       ; pfc = the face
.fd:    mov  si,[pfc]           ; SI = f
        mov  ax,si
        mov  cl,3
        shl  ax,cl              ; AX = f*8
        mov  si,ax              ; SI = the face's corners
        mov  cx,[CAZ+si]        ; CX = z0
        add  cx,[CAZ+si+2]      ; CX = z0 + z1
        sar  cx,1               ; CX = /2
        mov  dx,[CAZ+si+4]      ; DX = z2
        add  dx,[CAZ+si+6]      ; DX = z2 + z3
        sar  dx,1               ; DX = /2
        add  cx,dx              ; CX = both halves
        sar  cx,1               ; CX = /2: the average of the four
        mov  si,[pfc]           ; SI = f
        mov  bx,si
        add  bx,bx              ; BX = f*2
        mov  [FCD+bx],cx        ; depth[f] = it
        mov  ax,si
        mov  [FCO+si],al        ; order[f] = f: start in table order
        inc  word [pfc]
        mov  ax,[nfc]
        cmp  [pfc],ax
        jb   .fd
        ret

; ---- BUBBLE: the faces far to near ------------------------------------------
;  Swap any neighbours that are the wrong way round, and go over the list
;  again, n-1 times. Between two frames the order hardly changes - so the
;  swaps are few, and the passes are short: n is eight, or twelve.
;  In C:
;      for (pass = nfc-1; pass > 0; pass--)
;          for (i = 0; i < nfc-1; i++)
;              if (depth[i] < depth[i+1]) { swap(depth[i], depth[i+1]);
;                                           swap(order[i], order[i+1]); }
BUBBLE: mov  cx,[nfc]           ; CX = n
        dec  cx                 ; CX = n-1 passes
.bs:    push cx
        xor  si,si              ; SI = i
.bi:    mov  bx,si
        add  bx,bx              ; BX = i*2
        mov  ax,[FCD+bx]        ; AX = depth[i]
        cmp  ax,[FCD+bx+2]      ; nearer than depth[i+1]?
        jge  .nsw               ;   no: the right way round
        xchg ax,[FCD+bx+2]      ;   yes: swap the depths...
        mov  [FCD+bx],ax
        mov  al,[FCO+si]        ;   ...and the faces
        xchg al,[FCO+si+1]
        mov  [FCO+si],al
.nsw:   inc  si                 ; i++
        mov  bx,[nfc]
        dec  bx                 ; BX = n-1
        cmp  si,bx              ; i < n-1?
        jb   .bi
        pop  cx
        loop .bs
        ret

; ---- PAINT: every face, far to near: its shade, its grain, its edge ---------
;  The later face simply overwrites the earlier one - and its edge with it,
;  so a neon line never shows through a nearer face.
PAINT:  mov  word [pfc],0       ; pfc = the place in the order
.df:    mov  si,[pfc]
        mov  al,[FCO+si]        ; AL = the face in this place
        xor  ah,ah              ; AX = f
        mov  si,ax              ; SI = f
        mov  bx,ax
        shl  bx,2               ; BX = f*4
        add  bx,ax              ; BX = f*5
        add  bx,[mfb]           ; BX = &faces[f]
        mov  al,[bx+4]          ; AL = its colour in the table
        mov  [fcol],al          ; fcol = it
        mov  ax,si
        shl  ax,3               ; AX = f*8
        mov  si,ax              ; SI = its corners
        mov  [fco8],ax          ; fco8 = it: SHADE reads them too
        xor  di,di              ; DI = the corner in IX/IY/IZ
.dc:    mov  ax,[CAX+si]        ; four corners into FACEFILL's input
        mov  [IX+di],ax
        mov  ax,[CAY+si]
        mov  [IY+di],ax
        mov  ax,[CAZ+si]
        mov  [IZ+di],ax
        add  si,2
        add  di,2
        cmp  di,8
        jb   .dc
        cmp  byte [fcol],94     ; the nozzle?
        jne  .lit
        mov  eax,5E5E5E5Eh      ;   four pixels of colour 94: it glows by
        mov  dword [PAT],eax    ;   itself, no light falls on it
        mov  dword [PAT+4],eax
        mov  dword [PAT+8],eax
        mov  dword [PAT+12],eax
        jmp  .fill
.lit:   call SHADE              ; AX = the brightness, 0..TOPT
        mov  bl,RBODY           ; BL = the body's ramp...
        call ISWING             ; the wings, or the canopy?
        jne  .mk
        mov  bl,RWING           ;   ...or theirs
.mk:    call MKPAT              ; PAT = this face's grain
.fill:  call FACEFILL           ; clip, project, fill
        cmp  byte [gmode],3     ; the neon?
        jne  .nx
        cmp  word [NPOLY],3     ; and anything left after the clip?
        jl   .nx
        mov  al,EDGEB           ; AL = the body's edge...
        call ISWING             ; the wings, or the canopy?
        jne  .ed
        mov  al,EDGEW           ;   ...or theirs
.ed:    mov  [COLOR],al         ; COLOR = it
        call STROKEPOLY         ; round the face, over its own fill
.nx:    inc  word [pfc]
        mov  ax,[nfc]
        cmp  [pfc],ax
        jb   .df
        ret

; ---- ISWING: ZF = 1 if this face wears the wings' ramp -----------------------
;  27 in the hangar's tables; 0 and 4, the wings and the canopy, in the F-15's.
ISWING: cmp  byte [fcol],27     ; the hangar's wings?
        je   .x
        cmp  byte [fcol],0      ; the F-15's wings?
        je   .x
        cmp  byte [fcol],4      ; its canopy?
.x:     ret

; ---- SHADE: the face at [fco8] -> AX = its brightness, 0..TOPT --------------
;  Two edges from corner 0, their cross product g, scaled down, turned to the
;  eye, and its dot product with the light over its length.
;  In C:
;      u = c1 - c0;  w = c2 - c0;  g = u x w;
;      while (max(|gx|,|gy|,|gz|) >= 8192) g /= 2;     (BSR does it in one)
;      if (g . c0 > 0) g = -g;       c0 is the eye's way to the face
;      d = g . L;  if (d < 0) d = 0;
;      return AMBIENT + d * DIFFUSE / (256 * |g|);
SHADE:  mov  si,[fco8]          ; SI = the face's corners
        movsx ebx,word [CAX+si] ; EBX = c0.x, the sign carried up
        movsx eax,word [CAX+si+2] ; EAX = c1.x
        sub  eax,ebx            ; EAX = u.x
        mov  [ux],eax
        movsx eax,word [CAX+si+4] ; EAX = c2.x
        sub  eax,ebx            ; EAX = w.x
        mov  [wx],eax
        movsx ebx,word [CAY+si] ; the same for y
        movsx eax,word [CAY+si+2]
        sub  eax,ebx            ; EAX = u.y
        mov  [uy],eax
        movsx eax,word [CAY+si+4]
        sub  eax,ebx            ; EAX = w.y
        mov  [wy],eax
        movsx ebx,word [CAZ+si] ; and for z
        movsx eax,word [CAZ+si+2]
        sub  eax,ebx            ; EAX = u.z
        mov  [uz],eax
        movsx eax,word [CAZ+si+4]
        sub  eax,ebx            ; EAX = w.z
        mov  [wz],eax
        mov  eax,[uy]           ; g.x = u.y*w.z - u.z*w.y
        imul eax,[wz]           ; EAX = u.y*w.z
        mov  ebx,[uz]
        imul ebx,[wy]           ; EBX = u.z*w.y
        sub  eax,ebx            ; EAX = g.x
        mov  [gx],eax
        mov  eax,[uz]           ; g.y = u.z*w.x - u.x*w.z
        imul eax,[wx]           ; EAX = u.z*w.x
        mov  ebx,[ux]
        imul ebx,[wz]           ; EBX = u.x*w.z
        sub  eax,ebx            ; EAX = g.y
        mov  [gy],eax
        mov  eax,[ux]           ; g.z = u.x*w.y - u.y*w.x
        imul eax,[wy]           ; EAX = u.x*w.y
        mov  ebx,[uy]
        imul ebx,[wx]           ; EBX = u.y*w.x
        sub  eax,ebx            ; EAX = g.z
        mov  [gz],eax
        ; how big is it? OR the three sizes together: the top bit of the OR
        ; is the top bit of the largest, and BSR finds it
        mov  eax,[gx]           ; EAX = g.x
        cdq                     ; EDX = its sign, 32 times
        xor  eax,edx            ; flip if negative...
        sub  eax,edx            ; ...and add one: EAX = |g.x|
        mov  ebx,eax            ; EBX = it
        mov  eax,[gy]
        cdq
        xor  eax,edx
        sub  eax,edx            ; EAX = |g.y|
        or   ebx,eax            ; EBX |= it
        mov  eax,[gz]
        cdq
        xor  eax,edx
        sub  eax,edx            ; EAX = |g.z|
        or   ebx,eax            ; EBX |= it
        bsr  ecx,ebx            ; ECX = the highest bit set; ZF if none
        jnz  .some
        mov  ax,TOPT/2          ; a face with no area: the middle shade
        ret
.some:  sub  cl,12              ; CL = how far above bit 12
        jle  .small             ; under it already
        sar  dword [gx],cl      ; g /= 2^CL: the squares must fit below
        sar  dword [gy],cl
        sar  dword [gz],cl
.small: movsx eax,word [CAX+si] ; d = g . c0: which way does it look?
        imul eax,[gx]           ; EAX = c0.x*g.x
        movsx ebx,word [CAY+si]
        imul ebx,[gy]           ; EBX = c0.y*g.y
        add  eax,ebx            ; EAX += it
        movsx ebx,word [CAZ+si]
        imul ebx,[gz]           ; EBX = c0.z*g.z
        add  eax,ebx            ; EAX += it
        jle  .faces             ; negative: it looks at us already
        neg  dword [gx]         ; away from us: turn it round
        neg  dword [gy]
        neg  dword [gz]
.faces: mov  eax,[gx]           ; |g|^2 = g.x^2 + g.y^2 + g.z^2
        imul eax,eax            ; EAX = g.x^2
        mov  ebx,[gy]
        imul ebx,ebx            ; EBX = g.y^2
        add  eax,ebx            ; EAX += it
        mov  ebx,[gz]
        imul ebx,ebx            ; EBX = g.z^2
        add  eax,ebx            ; EAX = |g|^2
        call ISQRT              ; EBX = |g|
        mov  [glen],ebx
        imul eax,[gx],LIGHTX    ; EAX = g.x*L.x
        imul ebx,[gy],LIGHTY    ; EBX = g.y*L.y
        add  eax,ebx            ; EAX += it
        imul ebx,[gz],LIGHTZ    ; EBX = g.z*L.z
        add  eax,ebx            ; EAX = g . L
        jg   .lit               ; turned to the light?
        mov  ax,AMBIENT         ;   no: the shadow's brightness
        ret
.lit:   imul eax,eax,DIFFUSE    ; EAX = d * DIFFUSE
        cdq                     ; EDX:EAX = it, for IDIV
        mov  ecx,[glen]         ; ECX = |g|
        shl  ecx,8              ; ECX = 256*|g|: the light's own scale
        idiv ecx                ; EAX = d*DIFFUSE/(256*|g|)
        add  ax,AMBIENT         ; AX += what the shadow has
        cmp  ax,TOPT            ; rounding past the top?
        jbe  .ok
        mov  ax,TOPT            ;   then the top
.ok:    ret

; ---- ISQRT: EAX -> EBX = its square root, one bit at a time ------------------
;  Digit by digit, as a square root is taken on paper, in binary: no divide
;  at all.
;  In C:
;      for (b = 1<<30, r = 0; b; b >>= 2)
;          if (n >= r + b) { n -= r + b; r = (r >> 1) + b; } else r >>= 1;
ISQRT:  xor  ebx,ebx            ; EBX = r = 0
        mov  ecx,40000000h      ; ECX = b = the top bit pair
.l:     mov  edx,ebx            ; EDX = r
        add  edx,ecx            ; EDX = r + b
        cmp  eax,edx            ; n >= it?
        jb   .no
        sub  eax,edx            ;   n -= r + b
        shr  ebx,1              ;   r >>= 1
        add  ebx,ecx            ;   r += b
        jmp  .s
.no:    shr  ebx,1              ;   else r >>= 1
.s:     shr  ecx,2              ; b >>= 2
        jnz  .l
        ret

; ---- MKPAT: AX = brightness 0..TOPT, BL = the ramp -> PAT, 16 pixels --------
;  Brightness in sixteenths of a shade: the top is the shade, the bottom
;  four bits the fraction. A pixel takes the brighter shade when the
;  fraction is over the matrix's number there. Flat modes round instead:
;  the same PAT, all sixteen bytes alike.
;  In C:
;      lo = ramp + (t >> 4);  frac = t & 15;
;      if (gmode < 2) { if (frac >= 8) lo++; frac = 0; }
;      for (i = 0; i < 16; i++) PAT[i] = lo + (frac > BAYER[i]);
MKPAT:  mov  cx,ax              ; CX = t
        shr  ax,4               ; AX = t/16: the shade
        add  al,bl              ; AL = lo, in the ramp
        and  cl,15              ; CL = frac
        cmp  byte [gmode],2     ; the grain?
        jae  .mix
        cmp  cl,8               ; flat: nearer the next shade?
        jb   .flat
        inc  al                 ;   then that one
.flat:  xor  cl,cl              ; and no fraction left
.mix:   xor  si,si              ; SI = i
.b:     mov  ah,al              ; AH = lo
        cmp  cl,[BAYER+si]      ; frac > the matrix here?
        jbe  .put
        inc  ah                 ;   yes: the brighter shade
.put:   mov  [PAT+si],ah        ; PAT[i] = it
        inc  si                 ; i++
        cmp  si,16              ; all sixteen?
        jb   .b
        ret

; ---- SPANFILL: E_RAST's span: ES:DI, CX pixels, row [scy], grain PAT ---------
;  Up to three single pixels until DI divides by four, then REP STOSD, then
;  the last few. EAX is turned a byte at a time so that AL is always the
;  pixel at DI: after four turns it is back as it began.
;  320 divides by four, so DI's low two bits are x's low two bits.
SPANFILL:
        cmp  byte [gmode],0     ; the 8086's way?
        jne  .d
        mov  al,[PAT]           ; AL = the face's one colour
        rep  stosb              ; a pixel a write
        ret
.d:     mov  bx,[scy]           ; BX = y
        and  bx,3               ; BX = y & 3: the matrix's row
        shl  bx,2               ; BX *= 4: four bytes a row
        mov  eax,dword [PAT+bx] ; EAX = this row's four pixels
        mov  bx,cx              ; BX = the count, kept
        mov  cx,di              ; CX = the address
        and  cx,3               ; CX = x & 3
        shl  cx,3               ; CX *= 8: bits
        ror  eax,cl             ; AL = the pixel at x
        mov  cx,bx              ; CX = the count again
.head:  test di,3               ; on a double word?
        jz   .body
        jcxz .x                 ; the span ended first
        stosb                   ; one pixel
        ror  eax,8              ; AL = the next one
        dec  cx                 ; count--
        jmp  .head
.body:  mov  bx,cx              ; BX = what is left
        shr  cx,2               ; CX = /4: whole double words
        rep  stosd              ; four pixels a write
        mov  cx,bx              ; CX = what was left
        and  cx,3               ; CX = the last 0..3
        jcxz .x
.tail:  stosb                   ; one pixel
        ror  eax,8              ; AL = the next one
        loop .tail
.x:     ret

; ---- MKSKY: the sky's 200 rows, once: SKYF flat, SKYG grained ----------------
;  Row y has brightness y*TOPT/199, top to foot. MKPAT makes sixteen pixels,
;  and only the four of row y&3 are wanted.
MKSKY:  mov  al,[gmode]
        mov  [gmode0],al        ; gmode0 = the real mode, kept
        mov  word [skyy],0      ; skyy = the row
.r:     mov  byte [gmode],0     ; flat
        call SKYPAT
        mov  bx,[skyy]
        shl  bx,2               ; BX = y*4
        mov  eax,dword [PAT]    ; any row: all alike
        mov  [SKYF+bx],eax
        mov  byte [gmode],2     ; grained
        call SKYPAT
        mov  bx,[skyy]
        and  bx,3               ; BX = y & 3
        shl  bx,2               ; BX = its row in PAT
        mov  eax,dword [PAT+bx]
        mov  bx,[skyy]
        shl  bx,2               ; BX = y*4
        mov  [SKYG+bx],eax
        inc  word [skyy]
        cmp  word [skyy],200    ; all the rows?
        jb   .r
        mov  al,[gmode0]
        mov  [gmode],al         ; the real mode back
        ret
SKYPAT: mov  ax,[skyy]          ; AX = y
        mov  bx,TOPT            ; BX = the top
        mul  bx                 ; DX:AX = y*TOPT
        mov  bx,199             ; BX = the last row
        div  bx                 ; AX = y*TOPT/199
        mov  bl,RSKY            ; BL = the sky's ramp
        call MKPAT
        ret

; ---- BACKDROP: the sky into the buffer, row by row, over the last frame ------
BACKDROP:
        xor  di,di              ; DI = the buffer's start
        xor  bx,bx              ; BX = the row, four bytes each
        mov  si,SKYG            ; SI = the grained rows...
        cmp  byte [gmode],2     ; the grain?
        jae  .r
        mov  si,SKYF            ;   ...or the flat ones
.r:     mov  eax,[si+bx]        ; EAX = this row's four pixels
        cmp  byte [gmode],0     ; the 8086's way?
        jne  .d
        mov  cx,320             ; CX = 320 bytes
        rep  stosb              ; a pixel a write
        jmp  .n
.d:     mov  cx,80              ; CX = 80 double words
        rep  stosd              ; four pixels a write
.n:     add  bx,4               ; the next row
        cmp  bx,800             ; all 200?
        jb   .r
        ret

; ---- COUNTFPS: every second of ticks, frames*18.2 / ticks -> fps10 -----------
COUNTFPS:
        inc  word [frames]      ; frames++
        push es
        mov  ax,40h             ; the BIOS's data
        mov  es,ax
        mov  eax,[es:6Ch]       ; EAX = its clock
        pop  es
        mov  ecx,eax            ; ECX = now
        sub  ecx,[tick0]        ; ECX = ticks since the last count
        cmp  ecx,18             ; a second yet?
        jb   .x
        mov  [tick0],eax        ; tick0 = now
        movzx eax,word [frames] ; EAX = the frames
        imul eax,eax,182        ; EAX *= 182: 18.2 ticks a second, *10
        xor  edx,edx            ; EDX:EAX = it
        div  ecx                ; EAX = frames*182/ticks: tenths a second
        cmp  eax,2559           ; past what SHEET's byte divide can take?
        jbe  .keep
        mov  eax,2559           ;   then that: a divide must never overflow
.keep:  mov  [fps10],ax         ; kept
        mov  word [frames],0    ; start again
.x:     ret

; ---- GLOW: the nozzle burns - one DAC entry rewritten, no pixel touched ----
GLOW:   inc  word [gcnt]        ; gcnt++
        test word [gcnt],7      ; every eighth frame
        jnz  .ng
        mov  bx,[gph]           ; BX = the phase
        add  bx,bx
        add  bx,[gph]           ; BX = phase*3: three bytes a colour
        mov  dx,3C8h            ; the DAC's write index
        mov  al,94              ; colour 94, the nozzle
        out  dx,al
        inc  dx                 ; the DAC's data port
        mov  al,[GLOWT+bx]      ; red
        out  dx,al
        mov  al,[GLOWT+bx+1]    ; green
        out  dx,al
        mov  al,[GLOWT+bx+2]    ; blue
        out  dx,al
        inc  word [gph]         ; the next phase
        cmp  word [gph],3
        jb   .ng
        mov  word [gph],0
.ng:    ret

; ---- SHEET: the words: the speed and the mode on top, the name at the foot ---
SHEET:  mov  ax,[fps10]         ; AX = tenths of a frame a second
        mov  bl,10              ; BL = 10
        div  bl                 ; AL = whole ones, AH = the tenth
        add  ah,'0'             ; AH = its character
        mov  [FPSB+8],ah        ; into the text
        xor  ah,ah              ; AX = whole ones
        div  bl                 ; AL = /10, AH = the units
        add  ah,'0'
        mov  [FPSB+6],ah
        xor  ah,ah
        div  bl                 ; AL = hundreds, AH = the tens
        add  ah,'0'
        mov  [FPSB+5],ah
        add  al,'0'
        mov  [FPSB+4],al
        mov  byte [tcol],30     ; amber
        mov  si,FPSB
        mov  ax,4               ; row 4
        mov  bx,8               ; column 8
        call TXT
        mov  bl,[gmode]         ; the mode's name
        xor  bh,bh
        add  bx,bx
        mov  si,[GMTAB+bx]
        mov  byte [tcol],28     ; white
        mov  ax,14              ; row 14
        mov  bx,8
        call TXT
        mov  bx,[cmodel]        ; the aeroplane's name
        add  bx,bx
        mov  si,[NAMTAB+bx]
        mov  byte [tcol],28
        mov  ax,188
        mov  bx,8
        call TXT
        ret

; ---- TXT: ASCIIZ at SI -> the buffer at (BX, AX), colour [tcol] ------------
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
        mov  di,ax              ; DI = the first cell's top-left
.ch:    lodsb                   ; AL = the next character
        or   al,al
        jz   .done
        push si
        xor  ah,ah
        mov  cl,3
        shl  ax,cl              ; AX = char*8: its glyph
        mov  si,0FA6Eh
        add  si,ax              ; SI = F000:FA6E + char*8
        push ds
        mov  ax,0F000h
        mov  ds,ax              ; DS = the ROM
        mov  cx,8               ; eight rows
        push di
.row:   lodsb                   ; AL = a row of bits
        mov  ah,al
        push cx
        mov  cx,8               ; eight columns
.px:    shl  ah,1               ; CF = the next pixel
        jnc  .np
        mov  al,[cs:tcol]       ; ([cs:] because DS is the ROM)
        mov  [es:di],al
.np:    inc  di
        loop .px
        add  di,320-8           ; the next row of the cell
        pop  cx
        loop .row
        pop  di
        pop  ds
        pop  si
        add  di,8               ; the next cell
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

; ---- SETPAL: the ramps and the words -----------------------------------------
SETPAL: mov  si,PAL
.p:     lodsb                   ; AL = the colour number
        cmp  al,255             ; the end?
        je   .done
        mov  dx,3C8h            ; DAC write index
        out  dx,al
        inc  dx                 ; DAC data
        lodsb                   ; red, green, blue
        out  dx,al
        lodsb
        out  dx,al
        lodsb
        out  dx,al
        jmp  .p
.done:  ret
PAL     db  32, 10, 4,24        ; THE BODY: violet...
        db  33, 24, 6,40
        db  34, 42, 8,48        ; ...magenta...
        db  35, 58,16,46
        db  36, 63,36,44        ; ...pink...
        db  37, 63,56,50        ; ...and the sun on it
        db  40,  2, 6,20        ; THE WINGS: navy...
        db  41,  4,14,34
        db  42,  6,26,46        ; ...teal...
        db  43, 10,42,54
        db  44, 24,56,60        ; ...cyan...
        db  45, 50,63,63        ; ...and the sun on it
        db  48,  3, 1,12        ; THE SKY: night, at the top...
        db  49,  8, 2,22
        db  50, 18, 4,32        ; ...violet...
        db  51, 34, 6,38
        db  52, 52,14,34        ; ...rose...
        db  53, 63,34,24        ; ...and the last of the sun, at the foot
        db  60, 20,63,63        ; the neon: cyan, on the body
        db  61, 63,24,56        ; the neon: pink, on the wings
        db  94, 63,34, 6        ; the nozzle (cycled by GLOW)
        db  28, 60,60,60        ; white words
        db  30, 63,42,10        ; amber words
        db 255

BAYER   db  0, 8, 2,10          ; the matrix: row y&3, column x&3
        db 12, 4,14, 6
        db  3,11, 1, 9
        db 15, 7,13, 5

; ---- THE AIR FORCE: the game's F-15, then LESSONS\L30\HANGAR.ASM's five ------
        include '..\GAMES\OWLFLY3\SRC\F15M.INC'
MVTAB   dw F15VT,MVERT,MVERT1,MVERT2,MVERT3,MVERT4
MVNTAB  dw F15NV*6,13*6,25*6,19*6,13*6,19*6     ; vertex bytes: six a vertex
MFTAB   dw F15FC,MFACE,MFACE1,MFACE2,MFACE3,MFACE4
NFCTAB  dw F15NF,8,12,10,8,10                   ; faces
PDZT    dw 380,300,560,420,400,460      ; how far back each one stands
MVERT   dw   0,  1, 16          ; FIGHTER                 0  the nose
        dw  -2,  2,-11          ;                         1  tail, top left
        dw   2,  2,-11          ;                         2  tail, top right
        dw  -2, -2,-11          ;                         3  tail, low left
        dw   2, -2,-11          ;                         4  tail, low right
        dw -13,  1, -8          ;                         5  left wing tip
        dw  13,  1, -8          ;                         6  right wing tip
        dw   0,  1,  6          ;                         7  the wing root
        dw  -2,  1,-11          ;                         8  wing, rear left
        dw   2,  1,-11          ;                         9  wing, rear right
        dw   0,  2, -5          ;                        10  fin, front
        dw   0,  7,-13          ;                        11  fin, top
        dw   0,  2,-11          ;                        12  fin, rear
MFACE   db 0,1,2,0, 24          ; the top: nose to the tail's top edge
        db 0,3,4,0, 16          ; the belly
        db 0,1,3,0, 25          ; the left side
        db 0,2,4,0, 25          ; the right side
        db 7,5,8,7, 27          ; the left wing
        db 7,6,9,7, 27          ; the right wing
        db 10,11,12,10, 25      ; the fin
        db 1,2,4,3, 94          ; the nozzle: the tail's square
MVERT1  dw   0,  1, 34          ; BOMBER: four engines under the wings
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
        db 13,14,15,13, 16      ; the four engines: a triangle each
        db 16,17,18,16, 16
        db 19,20,21,19, 16
        db 22,23,24,22, 16
MVERT2  dw   0,  2, 20          ; RADAR PICKET: the rotodome on top
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
        db 13,14,15,16, 24      ; the dome: a flat diamond...
        db 13,17,15,18, 16      ; ...and its edge, standing up
MVERT3  dw   0,  2, 18          ; TRANSPORT: fat and slow
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
MVERT4  dw   0,  2, 26          ; TANKER: the fuel truck of the air
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
        db 13,14,15,13, 16      ; two engines under the wings
        db 16,17,18,16, 16
GLOWT   db 63,52,12             ; the nozzle: yellow...
        db 63,34, 6             ; ...orange...
        db 56,14, 4             ; ...red
; ---- the words ---------------------------------------------------------------
FPSB    db 'FPS 000.0',0
GMTAB   dw GM0,GM1,GM2,GM3
GM0     db 'G: 8086 FLAT, STOSB',0
GM1     db 'G: 386 FLAT, STOSD',0
GM2     db 'G: 386 GRAIN, STOSD',0
GM3     db 'G: GRAIN + NEON',0
NAMTAB  dw NM0,NM1,NM2,NM3,NM4,NM5
NM0     db 'F-15',0
NM1     db 'FIGHTER',0
NM2     db 'BOMBER',0
NM3     db 'RADAR PICKET',0
NM4     db 'TRANSPORT',0
NM5     db 'TANKER',0

; ---- the state ---------------------------------------------------------------
bufseg  dw 0
mhead   dw 40                   ; the spin's angle: a three-quarter view
spd     dw 1                    ; the spin a frame, -4..4
cmodel  dw 0                    ; which aeroplane: the F-15 first
mvb     dw F15VT                ; its vertex table...
mvn     dw F15NV*6              ; ...its bytes...
mfb     dw F15FC                ; ...its face table...
nfc     dw F15NF                ; ...its faces...
pdzc    dw 380                  ; ...and how far back it stands
gmode   db 3                    ; G: 0 8086 flat, 1 386 flat, 2 grain, 3 neon
gmode0  db 0                    ; MKSKY: the mode, kept
vsync   db 1                    ; V: wait for the retrace
fcol    db 0                    ; the face's colour in the table
tcol    db 28                   ; TXT's colour
fco8    dw 0                    ; the face's corners, f*8
skyy    dw 0                    ; MKSKY: the row
frames  dw 0                    ; COUNTFPS: frames since the last count
fps10   dw 0                    ; tenths of a frame a second
rseed   dw 1                    ; RND16's state (E_MATH wants it)
gcnt    dw 0                    ; GLOW's frame count
gph     dw 0                    ; GLOW's phase
        align 4
tick0   dd 0                    ; COUNTFPS: the clock at the last count
ux      dd 0                    ; SHADE: the two edges...
uy      dd 0
uz      dd 0
wx      dd 0
wy      dd 0
wz      dd 0
gx      dd 0                    ; ...their cross product...
gy      dd 0
gz      dd 0
glen    dd 0                    ; ...and its length
PAT     db 16 dup(0)            ; this face's grain: four rows of four pixels
SKYF    dd 200 dup(0)           ; the sky's rows, flat...
SKYG    dd 200 dup(0)           ; ...and grained
CAX     dw MAXF*4 dup(0)        ; every face's four corners
CAY     dw MAXF*4 dup(0)
CAZ     dw MAXF*4 dup(0)
PVX     dw MAXV dup(0)          ; every vertex, turned and placed
PVY     dw MAXV dup(0)
PVZ     dw MAXV dup(0)
FCD     dw MAXF dup(0)          ; every face's depth
FCO     db MAXF dup(0)          ; the painter's order
heading dw 0                    ; ---- the camera: straight and level ----
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
ty      dw 0                    ; a vertex's y' and z', before the tilt
tz      dw 0
msin    dw 0                    ; the spin's sine and cosine
mcos    dw 0
pfc     dw 0                    ; the face being worked on
IX      dw 4 dup(0)             ; FACEFILL: a face's four corners in...
IY      dw 4 dup(0)
IZ      dw 4 dup(0)
OX      dw 6 dup(0)             ; ...clipped by the near plane...
OY      dw 6 dup(0)
OZ      dw 6 dup(0)
PX      dw 6 dup(0)             ; ...and on the screen
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

if defined TESTRUN
TESTEND:
        inc  word [tfr]         ; tfr++
        push es
        mov  ax,40h
        mov  es,ax
        mov  eax,[es:6Ch]       ; EAX = the clock
        pop  es
        cmp  word [tfr],1       ; the first frame?
        jne  .n
        mov  [tt0],eax          ; the clock starts here
.n:     cmp  word [tfr],101     ; a hundred frames later?
        jb   .x
        sub  eax,[tt0]          ; EAX = the ticks they took
        mov  [tt0],eax
        call SHOT_SAVE          ; the picture, for the runner
        mov  ax,0003h
        int  10h
        mov  eax,[tt0]
        call PUTN               ; the ticks a hundred frames took
        mov  ax,4C00h
        int  21h
.x:     ret
PUTN:   mov  ebx,10             ; EAX in decimal, DOS's way
        xor  cx,cx
.d:     xor  edx,edx
        div  ebx
        push dx
        inc  cx
        or   eax,eax
        jnz  .d
.p:     pop  dx
        add  dl,'0'
        mov  ah,2
        int  21h
        loop .p
        ret
tfr     dw 0
tt0     dd 0
        include 'SHOT.INC'
end if

        include '..\ENGINE\E_CPU.INC'
        include '..\ENGINE\E_MATH.INC'
        include '..\ENGINE\E_M3D.INC'
        include '..\ENGINE\E_RAST.INC'
