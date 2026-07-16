; ============================================================================
;  F_PLANE.INC - the aircraft: DAT model loader and renderer
; ============================================================================
; ============================================================================
;  PLANE3D - the aircraft in the chase view: the model loaded from
;  PLANE1.DAT, painter sort, plus the gear struts when they are down.
; ============================================================================
PLANE3D:
        mov  ax,[hdg]           ; the model wears its true attitude:
        and  ax,255             ; yaw...
        push ax
        call SINQ
        mov  [msin],ax
        pop  ax
        add  ax,64
        call SINQ
        mov  [mcos],ax
        mov  ax,[rol]           ; ...roll...
        and  ax,255
        push ax
        call SINQ
        mov  [rsn],ax
        pop  ax
        add  ax,64
        call SINQ
        mov  [rcs],ax
        mov  ax,[pit]           ; ...and pitch, worn WITH the angle
        add  ax,[aoa]           ; of attack: slow flight rides nose-high
        and  ax,255
        push ax
        call SINQ
        mov  [psn],ax
        pop  ax
        add  ax,64
        call SINQ
        mov  [pcs],ax
        xor  si,si
        xor  di,di
@@tv:   mov  ax,[MDLVT+si]
        mov  [mx],ax
        mov  ax,[MDLVT+si+2]
        mov  [my],ax
        mov  ax,[MDLVT+si+4]
        mov  [mz],ax
        call MXFORM             ; roll -> pitch -> yaw -> world
        mov  ax,[wx]
        mov  [PVX+di],ax
        mov  ax,[wy]
        mov  [PVY+di],ax
        mov  ax,[wz]
        mov  [PVZ+di],ax
        add  si,6
        add  di,2
        cmp  si,[mvend]
        jb   @@tv
        ; faces far -> near, then fill (world verts -> camera per corner)
        xor  si,si
@@fd:   mov  bx,si
        add  bx,bx
        add  bx,bx
        add  bx,si
        push si
        mov  al,[MDLFC+bx]
        xor  ah,ah
        add  ax,ax
        mov  si,ax
        mov  ax,[PVX+si]
        sub  ax,[camx]
        mov  [wdx],ax
        mov  ax,[PVZ+si]
        sub  ax,[camz]
        mov  [wdz],ax
        call ROTXZ
        pop  si
        mov  ax,[rcz]
        mov  bx,si
        add  bx,bx
        mov  [FCD+bx],ax
        mov  ax,si
        mov  [FCO+bx],ax
        inc  si
        cmp  si,[mdlnf]
        jb   @@fd
        mov  cx,[nfm1]          ; bubble far -> near
        jcxz @@nsrt
@@bs:   push cx
        xor  si,si
@@bi:   mov  bx,si
        add  bx,bx
        mov  ax,[FCD+bx]
        cmp  ax,[FCD+bx+2]
        jge  @@ns
        xchg ax,[FCD+bx+2]
        mov  [FCD+bx],ax
        mov  ax,[FCO+bx]
        xchg ax,[FCO+bx+2]
        mov  [FCO+bx],ax
@@ns:   inc  si
        cmp  si,[nfm1]
        jb   @@bi
        pop  cx
        loop @@bs
@@nsrt: mov  word ptr [pfc],0
@@df:   mov  bx,[pfc]
        add  bx,bx
        mov  ax,[FCO+bx]
        mov  bx,ax
        add  bx,bx
        add  bx,bx
        add  bx,ax              ; *5
        push bx
        mov  al,[MDLFC+bx+4]
        mov  [COLOR],al
        xor  cx,cx
@@dc:   pop  bx
        push bx
        mov  si,cx
        mov  al,[MDLFC+bx+si]
        xor  ah,ah
        add  ax,ax
        mov  si,ax
        push cx
        mov  ax,[PVX+si]
        sub  ax,[camx]
        mov  [wdx],ax
        mov  ax,[PVZ+si]
        sub  ax,[camz]
        mov  [wdz],ax
        mov  ax,[PVY+si]
        sub  ax,[camy]
        mov  [t1],ax
        call ROTXZ
        pop  cx
        mov  di,cx
        add  di,di
        mov  ax,[rcx]
        mov  [IX+di],ax
        mov  ax,[rcz]
        mov  [IZ+di],ax
        mov  ax,[t1]
        mov  [IY+di],ax
        inc  cx
        cmp  cx,4
        jb   @@dc
        pop  bx
        call FACEFILL
        inc  word ptr [pfc]
        mov  ax,[pfc]
        cmp  ax,[mdlnf]
        jb   @@df
        ; ---- the gear: three dark struts under the belly ----
        cmp  word ptr [gear],1
        jne  @@ng
        mov  byte ptr [COLOR],16
        mov  si,offset GSTRUT
        mov  cx,3
@@gs:   push cx
        push si
        lodsw
        mov  [gu],ax            ; strut u (left-right)
        lodsw
        mov  [gv],ax            ; strut v (fore-aft)
        ; the strut is a thin MODEL-space quad through the same attitude
        ; matrix as the airframe - banked wings carry their wheels along
        mov  ax,[gu]
        mov  [mx],ax
        mov  word ptr [my],-1
        mov  ax,[gv]
        mov  [mz],ax
        call MXFORM
        mov  ax,[wy]
        mov  [vwy],ax
        mov  ax,[wx]
        mov  dx,[wz]
        call PUTV0
        mov  ax,[gu]
        add  ax,2
        mov  [mx],ax
        mov  word ptr [my],-1
        mov  ax,[gv]
        mov  [mz],ax
        call MXFORM
        mov  ax,[wy]
        mov  [vwy],ax
        mov  ax,[wx]
        mov  dx,[wz]
        call PUTV1
        mov  ax,[gu]
        add  ax,2
        mov  [mx],ax
        mov  word ptr [my],-4
        mov  ax,[gv]
        mov  [mz],ax
        call MXFORM
        mov  ax,[wy]
        mov  [vwy],ax
        mov  ax,[wx]
        mov  dx,[wz]
        call PUTV2
        mov  ax,[gu]
        mov  [mx],ax
        mov  word ptr [my],-4
        mov  ax,[gv]
        mov  [mz],ax
        call MXFORM
        mov  ax,[wy]
        mov  [vwy],ax
        mov  ax,[wx]
        mov  dx,[wz]
        call PUTV3
        call FACEFILL
        pop  si
        add  si,4
        pop  cx
        loop @@gs
@@ng:   ret

GSTRUT  dw   0, 14              ; nose strut (u,v in MODEL units)
        dw  -6, -2              ; main left
        dw   6, -2              ; main right

; ============================================================================
;  MXFORM - model space [mx],[my],[mz] through roll -> pitch -> yaw
;  (sines set up by PLANE3D) plus the aircraft position -> [wx],[wy],[wz].
;  GH lifts the airframe onto its gear.
; ============================================================================
GH      equ 4
MXFORM: mov  ax,[mx]            ; roll about the fuselage axis
        imul word ptr [rcs]
        mov  cx,ax
        mov  ax,[my]
        imul word ptr [rsn]
        add  ax,cx
        cwd
        mov  bx,256
        idiv bx
        mov  [m1],ax            ; x'
        mov  ax,[my]
        imul word ptr [rcs]
        mov  cx,ax
        mov  ax,[mx]
        imul word ptr [rsn]
        sub  cx,ax
        mov  ax,cx
        cwd
        mov  bx,256
        idiv bx
        mov  [m2],ax            ; y'
        mov  ax,[m2]            ; pitch about the wing axis
        imul word ptr [pcs]
        mov  cx,ax
        mov  ax,[mz]
        imul word ptr [psn]
        add  ax,cx
        cwd
        mov  bx,256
        idiv bx
        mov  [m3],ax            ; y''
        mov  ax,[mz]
        imul word ptr [pcs]
        mov  cx,ax
        mov  ax,[m2]
        imul word ptr [psn]
        sub  cx,ax
        mov  ax,cx
        cwd
        mov  bx,256
        idiv bx
        mov  [m2],ax            ; z'
        mov  ax,[m1]            ; yaw into the world
        imul word ptr [mcos]
        mov  cx,ax
        mov  ax,[m2]
        imul word ptr [msin]
        add  ax,cx
        cwd
        mov  bx,256
        idiv bx
        add  ax,[apx]
        mov  [wx],ax
        mov  ax,[m3]
        add  ax,[apy]
        add  ax,GH
        mov  [wy],ax
        mov  ax,[m1]
        imul word ptr [msin]
        mov  cx,ax
        mov  ax,[m2]
        imul word ptr [mcos]
        sub  ax,cx
        cwd
        mov  bx,256
        idiv bx
        add  ax,[apz]
        mov  [wz],ax
        ret

; ============================================================================
;  LOADMDL - pull PLANE1.DAT (made by \TOOLS\OBJ2DAT.COM) into the model
;  tables. Runs before the video mode switch so a missing file can speak.
;  Layout: 'M','D', dw nverts, dw nfaces, dw x,y,z each, db i0..i3,colour.
; ============================================================================
MAXMV   equ 255
MAXMF   equ 300
LOADMDL:
        mov  dx,offset MDLNAME
        mov  ax,3D00h
        int  21h
        jc   @@fail
        mov  bx,ax
        mov  dx,offset MHDR
        mov  cx,6
        mov  ah,3Fh
        int  21h
        jc   @@fail
        cmp  ax,6
        jne  @@fail
        cmp  word ptr [MHDR],444Dh  ; 'M','D' little-endian
        jne  @@fail
        mov  ax,[mdlnv]
        or   ax,ax
        jz   @@fail
        cmp  ax,MAXMV
        ja   @@fail
        mov  cx,6
        mul  cx
        mov  [mvend],ax         ; the vertex loop limit, nv*6
        mov  cx,ax
        mov  dx,offset MDLVT
        mov  ah,3Fh
        int  21h
        jc   @@fail
        cmp  ax,cx
        jne  @@fail
        mov  ax,[mdlnf]
        or   ax,ax
        jz   @@fail
        cmp  ax,MAXMF
        ja   @@fail
        dec  ax
        mov  [nfm1],ax
        mov  ax,[mdlnf]
        mov  cx,5
        mul  cx
        mov  cx,ax
        mov  dx,offset MDLFC
        mov  ah,3Fh
        int  21h
        jc   @@fail
        cmp  ax,cx
        jne  @@fail
        mov  ah,3Eh
        int  21h
        mov  dx,offset RBNAME   ; the radar: tower and dish
        mov  di,offset RBBUF
        call MLOAD
        mov  dx,offset RDNAME
        mov  di,offset RDBUF
        call MLOAD
        mov  dx,offset TWNAME
        mov  di,offset TWBUF
        call MLOAD
        mov  dx,offset CKNAME
        mov  di,offset CKBUF
        call MLOAD
        mov  dx,offset CNNAME
        mov  di,offset CNBUF
        call MLOAD
        call PNLLOAD
        ret
@@fail: mov  dx,offset EMDL
        mov  ah,9
        int  21h
        mov  ax,4C01h
        int  21h

; ============================================================================
;  MLOAD - read a small model DAT whole into a buffer (DX=name, DI=buf)
; ============================================================================
MLOAD:  mov  ax,3D00h
        int  21h
        jc   @@mf
        mov  bx,ax
        mov  dx,di
        mov  cx,1400
        mov  ah,3Fh
        int  21h
        jc   @@mf
        mov  ah,3Eh
        int  21h
        cmp  word ptr [di],444Dh
        jne  @@mf
        mov  ax,[di+2]
        or   ax,ax
        jz   @@mf
        cmp  ax,120
        ja   @@mf
        mov  ax,[di+4]
        or   ax,ax
        jz   @@mf
        cmp  ax,150
        ja   @@mf
        mov  ax,[di+2]          ; palette trailer? base goes to buf[1]
        mov  bx,6
        mul  bx
        mov  si,ax
        mov  ax,[di+4]
        mov  bx,5
        mul  bx
        add  si,ax
        add  si,di
        add  si,6
        cmp  byte ptr [si],'P'
        jne  @@mnp
        mov  al,[mpnext]
        mov  [di+1],al
        add  al,[si+1]
        mov  [mpnext],al
@@mnp:  ret
@@mf:   mov  dx,offset EMDL
        mov  ah,9
        int  21h
        mov  ax,4C01h
        int  21h

; ============================================================================
;  MPALS - after the video mode is set: walk the model buffers and
;  program their palette trailers into the DAC at their bases
; ============================================================================
MPALS:  mov  di,offset RBBUF
        call MPAL1
        mov  di,offset RDBUF
        call MPAL1
        mov  di,offset TWBUF
        call MPAL1
        mov  di,offset CKBUF
        call MPAL1
        mov  di,offset CNBUF
        call MPAL1
        call PNLPAL
        ret
MPAL1:  mov  ax,[di+2]
        mov  bx,6
        mul  bx
        mov  si,ax
        mov  ax,[di+4]
        mov  bx,5
        mul  bx
        add  si,ax
        add  si,di
        add  si,6
        cmp  byte ptr [si],'P'
        jne  @@no
        mov  cl,[si+1]
        xor  ch,ch
        jcxz @@no
        mov  al,[di+1]          ; the base assigned at load
        add  si,2
@@lp:   push ax
        mov  dx,3C8h
        out  dx,al
        inc  dx
        mov  al,[si]
        out  dx,al
        mov  al,[si+1]
        out  dx,al
        mov  al,[si+2]
        out  dx,al
        pop  ax
        inc  al
        add  si,3
        loop @@lp
@@no:   ret

; ============================================================================
;  MDRAW - draw the DAT model in [mbuf] at [mox/moy/moz], spun [myaw].
;  Yaw-only orientation through the same painter pipeline as everything.
; ============================================================================
MDRAW:  mov  bx,[mbuf]
        mov  al,[bx+1]
        mov  [mpb],al           ; this model's palette base
        mov  ax,[myaw]
        and  ax,255
        push ax
        call SINQ
        mov  [msin],ax
        pop  ax
        add  ax,64
        call SINQ
        mov  [mcos],ax
        mov  si,[mbuf]
        mov  ax,[si+2]
        mov  [mnv],ax
        mov  ax,[si+4]
        mov  [mnf],ax
        mov  bx,ax
        dec  bx
        mov  [mnf1],bx
        mov  ax,[mnv]
        mov  bx,6
        mul  bx
        add  ax,[mbuf]
        add  ax,6
        mov  [mfc0],ax          ; the face table inside the buffer
        mov  si,[mbuf]
        add  si,6
        xor  di,di
        mov  cx,[mnv]
@@v:    push cx
        lodsw
        mov  [mx],ax
        lodsw
        mov  [my],ax
        lodsw
        mov  [mz],ax
        push si
        mov  ax,[mx]
        imul word ptr [mcos]
        mov  cx,ax
        mov  ax,[mz]
        imul word ptr [msin]
        add  ax,cx
        cwd
        mov  bx,256
        idiv bx
        add  ax,[mox]
        mov  [PVX+di],ax
        mov  ax,[my]
        add  ax,[moy]
        mov  [PVY+di],ax
        mov  ax,[mx]
        imul word ptr [msin]
        mov  cx,ax
        mov  ax,[mz]
        imul word ptr [mcos]
        sub  ax,cx
        cwd
        mov  bx,256
        idiv bx
        add  ax,[moz]
        mov  [PVZ+di],ax
        pop  si
        add  di,2
        pop  cx
        loop @@v
MDFACES:
        xor  si,si              ; face depths from corner 0
@@fd:   mov  bx,si
        add  bx,bx
        add  bx,bx
        add  bx,si
        add  bx,[mfc0]
        push si
        mov  al,[bx]
        xor  ah,ah
        add  ax,ax
        mov  si,ax
        mov  ax,[PVX+si]
        sub  ax,[camx]
        mov  [wdx],ax
        mov  ax,[PVZ+si]
        sub  ax,[camz]
        mov  [wdz],ax
        call ROTXZ
        pop  si
        mov  ax,[rcz]
        mov  bx,si
        add  bx,bx
        mov  [FCD+bx],ax
        mov  ax,si
        mov  [FCO+bx],ax
        inc  si
        cmp  si,[mnf]
        jb   @@fd
        mov  cx,[mnf1]          ; bubble far -> near
        jcxz @@nos
@@bs:   push cx
        xor  si,si
@@bi:   mov  bx,si
        add  bx,bx
        mov  ax,[FCD+bx]
        cmp  ax,[FCD+bx+2]
        jge  @@ns
        xchg ax,[FCD+bx+2]
        mov  [FCD+bx],ax
        mov  ax,[FCO+bx]
        xchg ax,[FCO+bx+2]
        mov  [FCO+bx],ax
@@ns:   inc  si
        cmp  si,[mnf1]
        jb   @@bi
        pop  cx
        loop @@bs
@@nos:  mov  word ptr [pfc],0
@@df:   mov  bx,[pfc]
        add  bx,bx
        mov  ax,[FCO+bx]
        mov  bx,ax
        add  bx,bx
        add  bx,bx
        add  bx,ax
        add  bx,[mfc0]
        push bx
        mov  al,[bx+4]
        test al,80h             ; MTL colour: slot + the model's base
        jz   @@cab
        and  al,7Fh
        add  al,[mpb]
@@cab:  mov  [COLOR],al
        xor  cx,cx
@@dc:   pop  bx
        push bx
        mov  si,cx
        add  si,bx
        mov  al,[si]
        xor  ah,ah
        add  ax,ax
        mov  si,ax
        push cx
        mov  ax,[PVX+si]
        sub  ax,[camx]
        mov  [wdx],ax
        mov  ax,[PVZ+si]
        sub  ax,[camz]
        mov  [wdz],ax
        mov  ax,[PVY+si]
        sub  ax,[camy]
        mov  [t1],ax
        call ROTXZ
        pop  cx
        mov  di,cx
        add  di,di
        mov  ax,[rcx]
        mov  [IX+di],ax
        mov  ax,[rcz]
        mov  [IZ+di],ax
        mov  ax,[t1]
        mov  [IY+di],ax
        inc  cx
        cmp  cx,4
        jb   @@dc
        pop  bx
        call FACEFILL
        inc  word ptr [pfc]
        mov  ax,[pfc]
        cmp  ax,[mnf]
        jb   @@df
        ret

; ============================================================================
;  COCKPIT - the 3-D cockpit around the first-person eye: the rigid tub
;  (CKPT1.DAT) plus the canopy (CNPY1.DAT) swung by [cnp] on its rear
;  hinge. Both wear the aircraft's full attitude; the camera's own
;  head-look then pans across them naturally. Drawn LAST = nearest.
; ============================================================================
COCKPIT:
        mov  ax,[hdg]
        and  ax,255
        push ax
        call SINQ
        mov  [msin],ax
        pop  ax
        add  ax,64
        call SINQ
        mov  [mcos],ax
        mov  ax,[rol]
        and  ax,255
        push ax
        call SINQ
        mov  [rsn],ax
        pop  ax
        add  ax,64
        call SINQ
        mov  [rcs],ax
        mov  ax,[pit]
        add  ax,[aoa]
        and  ax,255
        push ax
        call SINQ
        mov  [psn],ax
        pop  ax
        add  ax,64
        call SINQ
        mov  [pcs],ax
        mov  word ptr [cpre],0
        mov  word ptr [mbuf],offset CKBUF
        call CKDRAW
        mov  ax,[cnp]
        mov  [cpre],ax
        mov  word ptr [mbuf],offset CNBUF
        call CKDRAW
        ret

; CKDRAW - model pre-hinged by [cpre] about the X axis through
; (y=CHY, z=CHZ), then roll->pitch->yaw via MXFORM, placed at the eye
CHY     equ 6
CHZ     equ -42
CKDRAW: mov  bx,[mbuf]
        mov  al,[bx+1]
        mov  [mpb],al
        mov  si,[mbuf]
        mov  ax,[si+2]
        mov  [mnv],ax
        mov  ax,[si+4]
        mov  [mnf],ax
        mov  bx,ax
        dec  bx
        mov  [mnf1],bx
        mov  ax,[mnv]
        mov  bx,6
        mul  bx
        add  ax,[mbuf]
        add  ax,6
        mov  [mfc0],ax
        mov  ax,[cpre]
        and  ax,255
        push ax
        call SINQ
        mov  [csn],ax
        pop  ax
        add  ax,64
        call SINQ
        mov  [ccs],ax
        mov  si,[mbuf]
        add  si,6
        xor  di,di
        mov  cx,[mnv]
@@v:    push cx
        lodsw
        mov  [mx],ax
        lodsw
        mov  [my],ax
        lodsw
        mov  [mz],ax
        push si
        push di
        cmp  word ptr [cpre],0
        je   @@nhg
        mov  ax,[my]            ; swing about the hinge
        sub  ax,CHY
        mov  [m2],ax
        mov  ax,[mz]
        sub  ax,CHZ
        mov  [m1],ax
        mov  ax,[m2]
        imul word ptr [ccs]
        mov  cx,ax
        mov  ax,[m1]
        imul word ptr [csn]
        add  ax,cx
        cwd
        mov  bx,256
        idiv bx
        add  ax,CHY
        mov  [my],ax
        mov  ax,[m1]
        imul word ptr [ccs]
        mov  cx,ax
        mov  ax,[m2]
        imul word ptr [csn]
        sub  cx,ax
        mov  ax,cx
        cwd
        mov  bx,256
        idiv bx
        add  ax,CHZ
        mov  [mz],ax
@@nhg:  call MXFORM             ; attitude + position (adds GH=4)
        pop  di
        mov  ax,[wx]
        mov  [PVX+di],ax
        mov  ax,[wy]
        add  ax,2               ; the eye rides at +6
        mov  [PVY+di],ax
        mov  ax,[wz]
        mov  [PVZ+di],ax
        pop  si
        add  di,2
        pop  cx
        loop @@v
        call MDFACES
        ret

; ============================================================================
;  The pre-rendered instrument panel (res/mkpanel.py -> PANEL1.RAW):
;  loaded into its own segment, palette at DAC 96+, blitted in the
;  first-person view when the head is near centre; live needles ride
;  on top (ASI from vel, compass from hdg, ALT from apy).
; ============================================================================
PNLLOAD:
        mov  ax,cs
        add  ax,2000h           ; past the back buffer at CS+1000h
        mov  [pnlseg],ax
        mov  dx,offset PNNAME
        mov  ax,3D00h
        int  21h
        jc   @@no
        mov  bx,ax
        push ds
        mov  ds,[cs:pnlseg]
        xor  dx,dx
        mov  cx,6000h
        mov  ah,3Fh
        int  21h
        pop  ds
        pushf
        mov  ah,3Eh
        int  21h
        popf
        jc   @@no
        push es
        mov  es,[pnlseg]
        cmp  word ptr es:[0],4250h  ; 'P','B'
        pop  es
        jne  @@no
        mov  byte ptr [pnlon],1
        ret
@@no:   mov  byte ptr [pnlon],0
        ret

PNLPAL: cmp  byte ptr [pnlon],0
        je   @@no
        push es
        mov  es,[pnlseg]
        mov  cl,es:[2]
        xor  ch,ch
        jcxz @@pop
        mov  si,3
        mov  al,96
@@lp:   push ax
        mov  dx,3C8h
        out  dx,al
        inc  dx
        mov  al,es:[si]
        out  dx,al
        mov  al,es:[si+1]
        out  dx,al
        mov  al,es:[si+2]
        out  dx,al
        pop  ax
        inc  al
        add  si,3
        loop @@lp
@@pop:  pop  es
@@no:   ret

; PNLDRW - blit the panel into the frame and draw the needles
PNLDRW: cmp  byte ptr [pnlon],0
        je   @@no
        mov  ax,[hy]            ; only when the head is near centre
        cmp  ax,-12
        jl   @@no
        cmp  ax,12
        jg   @@no
        mov  ax,[hp]
        cmp  ax,10
        jg   @@no
        push ds
        mov  ax,[bufseg]
        mov  es,ax
        mov  si,cs:[pnlseg]
        mov  ds,si
        mov  al,ds:[2]          ; npal -> pixel offset 3+npal*3
        xor  ah,ah
        mov  si,ax
        add  si,si
        add  si,ax
        add  si,3
        mov  di,128*320
        mov  cx,11520           ; 320x72 in words
        rep  movsw
        pop  ds
        ; ---- needles ----
        mov  byte ptr [COLOR],14
        mov  ax,[vel]           ; ASI: 0..800 over a 270-degree sweep
        cmp  ax,800
        jle  @@a1
        mov  ax,800
@@a1:   mov  bx,192
        imul bx
        mov  bx,800
        idiv bx
        add  ax,160
        mov  bx,60
        mov  cx,163
        call NEEDLE
        mov  ax,[hdg]           ; the compass
        mov  bx,160
        mov  cx,163
        call NEEDLE
        mov  ax,[apy]           ; ALT: 0..3000 over the sweep
        cmp  ax,3000
        jle  @@a2
        mov  ax,3000
@@a2:   mov  bx,192
        imul bx
        mov  bx,3000
        idiv bx
        add  ax,160
        mov  bx,260
        mov  cx,163
        call NEEDLE
@@no:   ret

; NEEDLE - angle AX (256 = circle, 0 = up), centre BX,CX; 20 px long
NEEDLE: mov  [sx0],bx
        mov  [sy0],cx
        push ax
        and  ax,255
        call SINQ
        mov  bx,20
        imul bx
        mov  bx,256
        idiv bx
        add  ax,[sx0]
        mov  [sx1],ax
        pop  ax
        add  ax,64
        and  ax,255
        call SINQ
        mov  bx,20
        imul bx
        mov  bx,256
        idiv bx
        mov  bx,[sy0]
        sub  bx,ax
        mov  [sy1],bx
        call CLIPLINE
        jc   @@no
        call LINE
@@no:   ret

pnlseg  dw 0
pnlon   db 0
PNNAME  db 'PANEL1.RAW',0
csn     dw 0
ccs     dw 256
cpre    dw 0
CKNAME  db 'CKPT1.DAT',0
CNNAME  db 'CNPY1.DAT',0
mbuf    dw 0
mox     dw 0
moy     dw 0
moz     dw 0
myaw    dw 0
mnv     dw 0
mnf     dw 0
mnf1    dw 0
mfc0    dw 0
mpnext  db 32
mpb     db 0
TWNAME  db 'TWR1.DAT',0
RBNAME  db 'RBASE1.DAT',0
RDNAME  db 'RDISH1.DAT',0
CKBUF   db 1400 dup(0)
CNBUF   db 1400 dup(0)
TWBUF   db 1400 dup(0)
RBBUF   db 1400 dup(0)
RDBUF   db 1400 dup(0)
MDLNAME db 'PLANE1.DAT',0
EMDL    db 'CANNOT LOAD PLANE1.DAT (run the build)',13,10,'$'
MHDR    db 0,0
mdlnv   dw 0
mdlnf   dw 0
mvend   dw 0
nfm1    dw 0
MDLVT   dw MAXMV*3 dup(0)
MDLFC   db MAXMF*5 dup(0)
