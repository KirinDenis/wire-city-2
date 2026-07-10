; ============================================================================
;  JET.COM - WIRE CITY engine example 03: the aircraft
;
;  The whole jet is 13 vertices and 8 quad faces (triangles repeat a
;  corner). Every frame: rotate the vertices with the quarter-table sine,
;  average each face's corner depths, bubble-sort the faces far -> near
;  (between two frames the order barely changes, so the bubble is nearly
;  O(n) - and n is 8), then hand each face to the engine pipeline:
;  near-clip -> perspective-project -> scanline-fill. Painter's algorithm:
;  no z-buffer anywhere, the near faces simply paint over the far ones.
;
;  SPACE blows the jet apart: each face gets a random kick (sideways,
;  up and out), rides a straight line bent by gravity every 8th frame,
;  and ~5 seconds later a fresh jet rolls off the line. The explosion
;  maths is all in one place - tune the kicks and the gravity below.
;
;  UP / DOWN cycle through the whole air force - fighter, bomber (four
;  engines), radar picket (rotodome), transport, tanker - with the spec
;  sheet at the bottom drawn straight from the PC's ROM font (F000:FA6E,
;  the same 8x8 glyphs the BIOS boots with).
;
;  Left / Right arrows change the spin, ESC quits. The nozzle burns by
;  DAC cycling: one palette register rewritten every few frames - the
;  pixels never change, the COLOUR does.
;
;  ~3 KB of .COM on the same ENGINE\ modules the game flies on.
; ============================================================================
FOCAL   equ 220                 ; the game's lens
NEARZ   equ 40                  ; near clip plane
MAXF    equ 12                  ; the biggest face count (bomber)
ETIME   equ 350                 ; explosion length in frames (~5 s @ 70 Hz)

        .8086
        LOCALS
        JUMPS
CODE    SEGMENT
        ASSUME cs:CODE, ds:CODE, es:CODE, ss:CODE
        ORG  100h

START:  cld
        mov  ax,cs              ; back buffer: the 64K above the program
        add  ax,1000h
        mov  [bufseg],ax
        push es
        mov  ax,40h             ; seed the LCG (explosion kicks) from the
        mov  es,ax              ; BIOS tick count
        mov  ax,es:[6Ch]
        pop  es
        or   ax,1
        mov  [rseed],ax
        mov  ax,0013h           ; VGA 320x200, 256 colours
        int  10h
        call SETPAL
        call SETTRIG            ; camera trig for a straight, level view
                                ; (heading/pitch/roll all zero)
; ---- one frame -------------------------------------------------------------
@@frame:
        mov  ax,[bufseg]        ; clear the back buffer
        mov  es,ax
        xor  di,di
        xor  ax,ax
        mov  cx,32000
        rep  stosw
        cmp  byte ptr [emode],0
        jne  @@phys
        ; ---- spin, then model yaw -> msin/mcos ----
        mov  ax,[spd]
        add  [mhead],ax
        and  word ptr [mhead],255
        mov  ax,[mhead]
        call SINQ
        mov  [msin],ax
        mov  ax,[mhead]
        add  ax,64
        call SINQ
        mov  [mcos],ax
        ; ---- transform the 13 vertices into the cache (x8 scale) ----
        xor  si,si              ; model table offset (6 bytes/vertex)
        xor  di,di              ; cache offset (2 bytes/vertex)
@@tv:   mov  bx,[mvb]           ; the current aircraft's vertices
        mov  ax,[bx+si]         ; vx = (mx*mcos + mz*msin)/256
        imul word ptr [mcos]
        mov  cx,ax
        mov  bx,[mvb]
        mov  ax,[bx+si+4]
        imul word ptr [msin]
        add  ax,cx
        cwd
        mov  bx,256
        idiv bx
        mov  cl,3
        shl  ax,cl              ; x8: the models ship quarter-scale
        mov  [PVX+di],ax
        mov  bx,[mvb]
        mov  ax,[bx+si+2]       ; vy = my (x8), a bit below the eye
        shl  ax,cl
        sub  ax,20
        mov  [PVY+di],ax
        mov  bx,[mvb]
        mov  ax,[bx+si]         ; vz = (mz*mcos - mx*msin)/256
        imul word ptr [msin]
        mov  cx,ax
        mov  bx,[mvb]
        mov  ax,[bx+si+4]
        imul word ptr [mcos]
        sub  ax,cx
        cwd
        mov  bx,256
        idiv bx
        mov  cl,3
        shl  ax,cl
        add  ax,[pdzc]          ; park it in front of the lens (big
        mov  [PVZ+di],ax        ;  aircraft stand further back)
        add  si,6
        add  di,2
        cmp  si,[mvn]
        jb   @@tv
        ; ---- deal the corners: CA[face][0..3] <- the vertex cache ----
        mov  word ptr [pfc],0
@@cf:   mov  si,[pfc]
        mov  bx,si
        add  bx,bx
        add  bx,bx
        add  bx,si              ; face record = 5 bytes
        add  bx,[mfb]           ; in this type's face table
        mov  ax,si
        mov  cl,3
        shl  ax,cl
        mov  di,ax              ; corner buffer base = face*8
        xor  cx,cx
@@cc:   mov  si,cx
        mov  al,[bx+si]
        xor  ah,ah
        add  ax,ax
        mov  si,ax
        mov  ax,[PVX+si]
        mov  [CAX+di],ax
        mov  ax,[PVY+si]
        mov  [CAY+di],ax
        mov  ax,[PVZ+si]
        mov  [CAZ+di],ax
        add  di,2
        inc  cx
        cmp  cx,4
        jb   @@cc
        inc  word ptr [pfc]
        mov  ax,[nfc]
        cmp  [pfc],ax
        jb   @@cf
        jmp  @@depth
@@phys: ; ---- the breakup: rigid faces drift apart on their kicks ----
        mov  word ptr [pfc],0
@@pf:   mov  si,[pfc]
        mov  bx,si
        add  bx,bx              ; velocity index (2 bytes/face)
        mov  ax,si
        mov  cl,3
        shl  ax,cl
        mov  di,ax              ; corner base (8 bytes/face)
        mov  cx,4
@@pc:   mov  ax,[FVX+bx]
        add  [CAX+di],ax
        mov  ax,[FVY+bx]
        add  [CAY+di],ax
        mov  ax,[FVZ+bx]
        add  [CAZ+di],ax
        add  di,2
        loop @@pc
        inc  word ptr [pfc]
        mov  ax,[nfc]
        cmp  [pfc],ax
        jb   @@pf
        mov  ax,[etim]          ; gravity: a downward tug every 8th frame
        test ax,7               ; (tune: smaller mask = heavier world)
        jnz  @@ngv
        xor  bx,bx
@@gv:   dec  word ptr [FVY+bx]
        add  bx,2
        mov  ax,[nfc]
        add  ax,ax
        cmp  bx,ax
        jb   @@gv
@@ngv:  dec  word ptr [etim]
        jnz  @@depth
        mov  byte ptr [emode],0 ; ...and a fresh jet rolls off the line
@@depth:
        ; ---- face depths: FCD = avg z of the corner buffer ----
        mov  word ptr [pfc],0
@@fd:   mov  si,[pfc]
        mov  ax,si
        mov  cl,3
        shl  ax,cl
        mov  si,ax              ; corner base
        mov  cx,[CAZ+si]
        add  cx,[CAZ+si+2]
        sar  cx,1
        mov  dx,[CAZ+si+4]
        add  dx,[CAZ+si+6]
        sar  dx,1
        add  cx,dx
        sar  cx,1               ; face average depth
        mov  si,[pfc]
        mov  bx,si
        add  bx,bx
        mov  [FCD+bx],cx
        mov  ax,si
        mov  bx,si
        mov  [FCO+bx],al        ; order starts as identity
        inc  word ptr [pfc]
        mov  ax,[nfc]
        cmp  [pfc],ax
        jb   @@fd
        ; ---- bubble far -> near (descending depth) ----
        mov  cx,[nfc]
        dec  cx
@@bs:   push cx
        xor  si,si
@@bi:   mov  bx,si
        add  bx,bx
        mov  ax,[FCD+bx]
        cmp  ax,[FCD+bx+2]
        jge  @@nsw
        xchg ax,[FCD+bx+2]
        mov  [FCD+bx],ax
        mov  al,[FCO+si]
        xchg al,[FCO+si+1]
        mov  [FCO+si],al
@@nsw:  inc  si
        mov  bx,[nfc]
        dec  bx
        cmp  si,bx
        jb   @@bi
        pop  cx
        loop @@bs
        ; ---- draw the faces in painter order ----
        mov  word ptr [pfc],0
@@df:   mov  si,[pfc]
        mov  al,[FCO+si]
        xor  ah,ah
        mov  si,ax              ; the ordered face id
        mov  bx,ax
        add  bx,bx
        add  bx,bx
        add  ax,bx              ; *5
        mov  bx,ax
        add  bx,[mfb]
        mov  al,[bx+4]
        mov  [COLOR],al
        mov  ax,si
        mov  cl,3
        shl  ax,cl
        mov  si,ax              ; corner base
        xor  di,di
@@dc:   mov  ax,[CAX+si]
        mov  [IX+di],ax
        mov  ax,[CAY+si]
        mov  [IY+di],ax
        mov  ax,[CAZ+si]
        mov  [IZ+di],ax
        add  si,2
        add  di,2
        cmp  di,8
        jb   @@dc
        call FACEFILL
        inc  word ptr [pfc]
        mov  ax,[nfc]
        cmp  [pfc],ax
        jb   @@df
        ; ---- the nozzle burns: DAC-cycle colour 94 ----
        inc  word ptr [gcnt]
        test word ptr [gcnt],7
        jnz  @@ng
        mov  bx,[gph]
        add  bx,bx
        add  bx,[gph]           ; *3
        mov  dx,3C8h
        mov  al,94
        out  dx,al
        inc  dx
        mov  al,[GLOWT+bx]
        out  dx,al
        mov  al,[GLOWT+bx+1]
        out  dx,al
        mov  al,[GLOWT+bx+2]
        out  dx,al
        inc  word ptr [gph]
        cmp  word ptr [gph],3
        jb   @@ng
        mov  word ptr [gph],0
@@ng:
        ; ---- the spec sheet at the bottom (ROM font into the buffer) ----
        mov  bx,[cmodel]
        add  bx,bx
        mov  ax,bx
        add  ax,ax
        add  bx,ax              ; *6: three lines per type
        mov  byte ptr [tcol],30 ; amber name
        push bx
        mov  si,[INFTAB+bx]
        mov  ax,168
        mov  bx,16
        call TXT
        pop  bx
        mov  byte ptr [tcol],28 ; grey data
        push bx
        mov  si,[INFTAB+bx+2]
        mov  ax,180
        mov  bx,16
        call TXT
        pop  bx
        mov  si,[INFTAB+bx+4]
        mov  ax,190
        mov  bx,16
        call TXT
        ; ---- vsync, blit, keys ----
        call WAITVR
        push ds
        mov  ax,0A000h
        mov  es,ax
        mov  ds,[bufseg]        ; DS is still ours at this point
        xor  si,si
        xor  di,di
        mov  cx,32000
        rep  movsw
        pop  ds
        mov  ah,1               ; a key?
        int  16h
        jz   @@frame
        xor  ah,ah
        int  16h
        cmp  al,27
        je   @@quit
        cmp  al,' '             ; Space: the jet comes apart
        jne  @@nsp
        cmp  byte ptr [emode],0
        jne  @@frame            ; already in pieces
        mov  byte ptr [emode],1
        mov  word ptr [etim],ETIME
        xor  si,si              ; one kick per face - THE TUNING TABLE:
@@ev:   push si                 ;   sideways -3..4, up -1..6, out -3..4
        call RND16              ; (high byte of the LCG - see TERRA's
        pop  si                 ;  resonance story for why never the low)
        mov  di,si
        add  di,di
        mov  bl,ah
        xor  bh,bh
        and  bx,7
        sub  bx,3               ; sideways kick
        mov  [FVX+di],bx
        push si
        call RND16
        pop  si
        mov  bl,ah
        xor  bh,bh
        and  bx,7
        sub  bx,1               ; upward bias: pieces arc before they fall
        mov  [FVY+di],bx
        push si
        call RND16
        pop  si
        mov  bl,ah
        xor  bh,bh
        and  bx,7
        sub  bx,3               ; toward / away from the lens
        mov  [FVZ+di],bx
        inc  si
        cmp  si,[nfc]
        jb   @@ev
        jmp  @@frame
@@nsp:  or   al,al              ; extended key? AH = scan code
        jnz  @@frame
        cmp  ah,48h             ; Up: the next aircraft
        jne  @@kdn
        inc  word ptr [cmodel]
        cmp  word ptr [cmodel],5
        jb   @@setm
        mov  word ptr [cmodel],0
        jmp  @@setm
@@kdn:  cmp  ah,50h             ; Down: the previous one
        jne  @@klf
        dec  word ptr [cmodel]
        cmp  word ptr [cmodel],0
        jge  @@setm
        mov  word ptr [cmodel],4
@@setm: mov  bx,[cmodel]        ; roll the chosen airframe out
        add  bx,bx
        mov  ax,[MVTAB+bx]
        mov  [mvb],ax
        mov  ax,[MVNTAB+bx]
        mov  [mvn],ax
        mov  ax,[MFTAB+bx]
        mov  [mfb],ax
        mov  ax,[NFCTAB+bx]
        mov  [nfc],ax
        mov  ax,[PDZT+bx]
        mov  [pdzc],ax
        mov  byte ptr [emode],0 ; fresh and in one piece
        jmp  @@frame
@@klf:  cmp  ah,4Bh             ; Left: spin slower / the other way
        jne  @@kr
        dec  word ptr [spd]
        cmp  word ptr [spd],-4
        jge  @@frame
        mov  word ptr [spd],-4
        jmp  @@frame
@@kr:   cmp  ah,4Dh             ; Right: spin faster
        jne  @@frame
        inc  word ptr [spd]
        cmp  word ptr [spd],4
        jle  @@frame
        mov  word ptr [spd],4
        jmp  @@frame
@@quit: mov  ax,0003h
        int  10h
        mov  ax,4C00h
        int  21h

; ---- TXT: ASCIIZ at SI -> back buffer at (BX,AX), colour [tcol] -----------
; The glyphs come from the PC's ROM font at F000:FA6E - 8x8, the very
; characters the machine boots with. No font resource needed.
TXT:    push es
        push dx
        mov  cx,ax
        mov  ax,[bufseg]
        mov  es,ax
        mov  ax,cx
        mov  cx,320
        mul  cx
        add  ax,bx
        mov  di,ax              ; destination top-left
@@ch:   lodsb
        or   al,al
        jz   @@done
        push si
        xor  ah,ah
        mov  cl,3
        shl  ax,cl              ; glyph offset = char*8
        mov  si,0FA6Eh
        add  si,ax
        push ds
        mov  ax,0F000h
        mov  ds,ax
        mov  cx,8
        push di
@@row:  lodsb                   ; one row of bits, MSB = left pixel
        mov  ah,al
        push cx
        mov  cx,8
@@px:   shl  ah,1
        jnc  @@np
        mov  al,cs:[tcol]
        mov  es:[di],al
@@np:   inc  di
        loop @@px
        add  di,320-8
        pop  cx
        loop @@row
        pop  di
        pop  ds
        pop  si
        add  di,8               ; the next character cell
        jmp  @@ch
@@done: pop  dx
        pop  es
        ret

; ---- wait for the vertical retrace edge ------------------------------------
WAITVR: mov  dx,3DAh
@@w1:   in   al,dx
        test al,8
        jnz  @@w1
@@w2:   in   al,dx
        test al,8
        jz   @@w2
        ret

; ---- the few DAC entries this model wears ----------------------------------
SETPAL: mov  si,offset PAL
@@p:    lodsb
        cmp  al,255
        je   @@done
        mov  dx,3C8h
        out  dx,al
        inc  dx
        lodsb
        out  dx,al
        lodsb
        out  dx,al
        lodsb
        out  dx,al
        jmp  @@p
@@done: ret
PAL     db   0,  2, 4,12        ; backdrop: night blue
        db  16, 20,20,22        ; body shade
        db  24, 52,52,56        ; body sun-lit
        db  25, 34,34,38        ; body sides / fin
        db  27, 44,44,46        ; wings
        db  94, 63,34, 6        ; nozzle (cycled)
        db  28, 56,56,56        ; spec sheet text
        db  30, 63,42,10        ; spec sheet heading (amber)
        db 255

; ---- the air force (from the game's DATA.INC; wings recoloured 27 for
; this example's palette). Types share the first 13 vertices / 8 faces
; of topology; engines and domes are extra vertices and faces.
MVTAB   dw MVERT,MVERT1,MVERT2,MVERT3,MVERT4
MVNTAB  dw 13*6,25*6,19*6,13*6,19*6
MFTAB   dw MFACE,MFACE1,MFACE2,MFACE3,MFACE4
NFCTAB  dw 8,12,10,8,10
PDZT    dw 300,560,420,400,460  ; camera distance: big birds stand back
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
        db 13,14,15,13, 16
        db 16,17,18,16, 16
        db 19,20,21,19, 16
        db 22,23,24,22, 16
MVERT2  dw   0,  2, 20          ; RADAR PICKET: the rotodome
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
MVERT4  dw   0,  2, 26          ; TANKER: the fat fuel truck
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
GLOWT   db 63,52,12             ; nozzle DAC cycle: yellow
        db 63,34, 6             ; orange
        db 56,14, 4             ; red
; ---- the spec sheets (type, weight, speed, role, hits to kill) -------------
INF0A   db 'FIGHTER',0
INF0B   db 'WEIGHT 18T   SPEED 950 KM/H',0
INF0C   db 'AIR SUPERIORITY        2-5 HITS TO KILL',0
INF1A   db 'BOMBER',0
INF1B   db 'WEIGHT 110T  SPEED 700 KM/H',0
INF1C   db 'LEVELS ENEMY CITY BLOCKS    6 HITS',0
INF2A   db 'RADAR PICKET',0
INF2B   db 'WEIGHT 78T   SPEED 650 KM/H',0
INF2C   db 'THE EYES OF THE TEAM        5 HITS',0
INF3A   db 'TRANSPORT',0
INF3B   db 'WEIGHT 92T   SPEED 600 KM/H',0
INF3C   db 'DROPS PARATROOPERS          5 HITS',0
INF4A   db 'TANKER',0
INF4B   db 'WEIGHT 140T  SPEED 600 KM/H',0
INF4C   db 'THE FLYING FUEL STATION     5 HITS',0
INFTAB  dw INF0A,INF0B,INF0C, INF1A,INF1B,INF1C, INF2A,INF2B,INF2C
        dw INF3A,INF3B,INF3C, INF4A,INF4B,INF4C

; ---- engine contract: E_M3D + E_RAST (see the module headers) --------------
bufseg  dw 0
mhead   dw 0                    ; model heading (the spin)
cmodel  dw 0                    ; which aircraft is on the stand
mvb     dw MVERT                ; current vertex table
mvn     dw 13*6                 ; current vertex bytes
mfb     dw MFACE                ; current face table
nfc     dw 8                    ; current face count
pdzc    dw 300                  ; current camera distance
tcol    db 28                   ; TXT colour
rseed   dw 1                    ; LCG state (explosion kicks)
emode   db 0                    ; 0 = flying, 1 = in pieces
etim    dw 0                    ; explosion frames left
CAX     dw MAXF*4 dup(0)        ; face corners, absolute camera space
CAY     dw MAXF*4 dup(0)        ;  (flying refills them from the model,
CAZ     dw MAXF*4 dup(0)        ;   the breakup just moves them)
FVX     dw MAXF dup(0)          ; face velocities
FVY     dw MAXF dup(0)
FVZ     dw MAXF dup(0)
spd     dw 1                    ; spin per frame (arrows, -4..4)
gcnt    dw 0                    ; glow frame counter
gph     dw 0                    ; glow phase 0..2
heading dw 0                    ; camera: straight, level, still
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
rcx     dw 0
rcz     dw 0
rddx    dw 0
rddy    dw 0
rsxo    dw 0
ptmp    dw 0
msin    dw 0                    ; model yaw sin/cos
mcos    dw 0
pfc     dw 0                    ; face draw counter
PVX     dw 25 dup(0)            ; camera-space vertex cache (max: bomber)
PVY     dw 25 dup(0)
PVZ     dw 25 dup(0)
FCD     dw MAXF dup(0)          ; face depths for the painter sort
FCO     db MAXF dup(0)          ; face draw order
IX      dw 4 dup(0)             ; face input verts (3D)
IY      dw 4 dup(0)
IZ      dw 4 dup(0)
OX      dw 6 dup(0)             ; near-clipped verts
OY      dw 6 dup(0)
OZ      dw 6 dup(0)
PX      dw 6 dup(0)             ; projected verts (screen)
PY      dw 6 dup(0)
NPOLY   dw 0
oc      dw 0
ci      dw 0
ni      dw 0
pk      dw 0
pminy   dw 0
pmaxy   dw 0
scy     dw 0                    ; scanline filler state
scymax  dw 0
scxl    dw 0
scxr    dw 0
tnum    dw 0                    ; clip interpolation scratch
tden    dw 0
cdx     dw 0                    ; line clip deltas / new point
cdy     dw 0
nx      dw 0
ny      dw 0
oc0     db 0                    ; Cohen-Sutherland outcodes
oc1     db 0
ocsel   db 0
lx      dw 0                    ; Bresenham state (LINE)
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
; quarter sine table: SINT[i] = round(256*sin(i*90/64 deg)), i=0..64
SINT    dw 0,6,13,19,25,31,38,44,50,56,62,68,74,80,86,92,98,104,109,115
        dw 121,126,132,137,142,147,153,157,162,167,172,177,181,185,190,194
        dw 198,202,206,209,213,216,220,223,226,229,231,234,237,239,241,243
        dw 245,247,248,250,251,252,253,254,255,255,256,256,256

        INCLUDE ..\ENGINE\E_MATH.INC
        INCLUDE ..\ENGINE\E_M3D.INC
        INCLUDE ..\ENGINE\E_RAST.INC

CODE    ENDS
        END START
