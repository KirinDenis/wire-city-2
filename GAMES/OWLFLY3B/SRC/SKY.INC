; SKY.INC - part of WIRE CITY (included from OWLFLY3.ASM, AFTER "CODE ENDS")
; ============================================================================
;  THE NEWTON SKY, living in its own segment.
;
;  This is the first tenant of the land the EXE conversion opened up:
;  everything here - the blue-noise matrix, the ramp tables, the four
;  cloud coats, ninety-six cloud positions and all the code that walks
;  them - sits OUTSIDE the crowded main 64K segment, whose BSS ceiling
;  had about 1.8K of stack headroom left. Only ~90 bytes of hot
;  variables stayed behind in DATA.INC where DS can reach them fast.
;
;  Segmentation contract:
;    DS = SS = the main CODE segment (the game's one-segment world).
;    CS = SKYSEG while any code here runs; TASM's ASSUME emits the CS
;         override on every table access automatically. The one manual
;         override is TSKY via [bp+si] (BP-based defaults to SS).
;    ES = bufseg on entry to SKYFILL and WCLOUDF (the callers' contract,
;         same as RENDER's).
;  Entry points (all FAR): SKYBAKE once at startup after rseed is
;  seeded; SKYFILL from CLEARBUF each frame; WCLOUDF from RENDER after
;  the stars and before the terrain, so a cloud behind a ridge is
;  painted over, as it should be.
;
;  The sky itself is NEWTON's, ported with its geometry intact because
;  the conventions matched exactly: OWLFLY's (rsin,rcos) screen rotate
;  is NEWTON's ROTPT, OWLFLY's ROTXZ is NEWTON's WCAM. The horizon
;  pivot is derived per frame in CLEARBUF: the horizon line sits at
;  v = pofs of the band rotation, so its on-screen anchor is
;  (160 - pofs*sin/256, horiz + pofs*cos/256).
; ============================================================================

segment SKYSEG

; ---- ROWAD: AX = row -> AX = row*320 --------------------------------------
ROWAD:  push bx
        push cx
        mov  bx,ax
        mov  cl,8
        shl  ax,cl
        mov  cl,6
        shl  bx,cl
        add  ax,bx
        pop  cx
        pop  bx
        ret

; ---- WCAM2: world delta (wdx2 east, wdz2 north) -> cldu, cldd -------------
; OWLFLY's ROTXZ with NEWTON's 32-bit middles: d = dz*cos + dx*sin,
; u = dx*cos - dz*sin, exact for any 16-bit delta.
WCAM2:  mov  ax,[wdz2]
        imul word [hcos]
        mov  bx,ax
        mov  cx,dx
        mov  ax,[wdx2]
        imul word [hsin]
        add  bx,ax
        adc  cx,dx
        mov  al,bh
        mov  ah,cl
        mov  [cldd],ax
        mov  ax,[wdx2]
        imul word [hcos]
        mov  bx,ax
        mov  cx,dx
        mov  ax,[wdz2]
        imul word [hsin]
        sub  bx,ax
        sbb  cx,dx
        mov  al,bh
        mov  ah,cl
        mov  [cldu],ax
        ret

; (the 8K window guard moved to NET.INC - it must measure sky + net
; together, and NET.INC appends to this same segment)

