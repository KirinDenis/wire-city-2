; ============================================================================
;  SMOKE.COM - WIRE CITY engine example 06: the fire-and-smoke laboratory
;
;  A particle lab for developing the arcade's fire/smoke tech. In the
;  centre burns a source; FIRE particles (bright, fast, short-lived)
;  age into SMOKE puffs - many-sided random polygons that slowly spin,
;  swell and rise. The gas physics: buoyancy, drag, a gentle vortex
;  swirl and random-walk turbulence (LCG high bits - see TERRA's
;  resonance lesson).
;
;  PHYSICS AND RENDER RUN ON SEPARATE CLOCKS: physics steps on the BIOS
;  18.2 Hz tick (scaled by a speed knob), rendering free-runs on vsync
;  with painter-sorted particles. The readout shows both rates live -
;  that is the point of the lab: tune, discuss, keep what looks right.
;
;  Controls:  Left/Right  orbit the camera around the source
;             Up/Down     raise / lower the camera (it keeps looking in)
;             + / -       more / fewer particles (4..56)
;             W / S       physics speed x0.25 .. x4
;             [ / ]       zoom out / in
;             ESC         quit
; ============================================================================
FOCAL   equ 220
NEARZ   equ 40
NPMAX   equ 56                  ; particle pool
MVERT   equ 6                   ; polygon sides per puff

        .8086
        LOCALS
        JUMPS
CODE    SEGMENT
        ASSUME cs:CODE, ds:CODE, es:CODE, ss:CODE
        ORG  100h

START:  cld
        mov  ax,cs
        add  ax,1000h
        mov  [bufseg],ax
        push es
        mov  ax,40h             ; seed the LCG from the BIOS clock
        mov  es,ax
        mov  ax,es:[6Ch]
        pop  es
        or   ax,1
        mov  [rseed],ax
        mov  ax,0013h
        int  10h
        mov  si,offset PAL      ; palette: fire ramp + smoke greys
@@p:    lodsb
        cmp  al,255
        je   @@pd
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
@@pd:   xor  si,si              ; every slot starts dead and respawns
@@iz:   mov  bx,si
        mov  word ptr [page_+bx],0
        add  bx,bx
        add  si,1
        cmp  si,NPMAX
        jb   @@iz
        push es
        mov  ax,40h
        mov  es,ax
        mov  ax,es:[6Ch]
        pop  es
        mov  [ltick],ax

; ============================ the frame ====================================
@@frame:
        ; ---- PHYSICS CLOCK: BIOS ticks * speed knob, fixed point 8.8 ----
        push es
        mov  ax,40h
        mov  es,ax
        mov  ax,es:[6Ch]
        pop  es
        mov  bx,ax
        sub  ax,[ltick]         ; ticks since last frame
        mov  [ltick],bx
        cmp  ax,4               ; a stall shall not explode the pot
        jle  @@dt1
        mov  ax,4
@@dt1:  mul  word ptr [pspd]    ; * speed (256 = x1)
        add  [pacc],ax          ; accumulate 8.8 steps
@@ph:   cmp  word ptr [pacc],256
        jl   @@phd
        sub  word ptr [pacc],256
        call PHYS               ; one physics step
        inc  word ptr [pcnt2]   ; steps-per-second meter
        jmp  @@ph
@@phd:
        ; ---- camera follows the knobs, always looking at the source ----
        mov  ax,[cama]
        mov  [heading],ax
        mov  ax,[camh]          ; look down when high: pitch = -h/16
        mov  cl,4
        sar  ax,cl
        neg  ax
        cmp  ax,-56
        jge  @@c1
        mov  ax,-56
@@c1:   cmp  ax,20
        jle  @@c2
        mov  ax,20
@@c2:   mov  [pitch],ax
        call SETTRIG
        ; camera position = source - dist along the view direction
        mov  ax,[hsin]
        imul word ptr [camd]
        mov  bx,256
        idiv bx
        neg  ax
        mov  [camx],ax
        mov  ax,[hcos]
        imul word ptr [camd]
        mov  bx,256
        idiv bx
        neg  ax
        mov  [camz],ax
        mov  ax,[camh]
        mov  [camy],ax
        ; ---- clear the buffer ----
        mov  ax,[bufseg]
        mov  es,ax
        xor  di,di
        xor  ax,ax
        mov  cx,32000
        rep  stosw
        call GROUND             ; a reference floor grid
        call RENDER             ; painter-sorted puffs
        call HUDTXT             ; the lab readout
        ; ---- vsync + blit + fps meter ----
        call WAITVR
        push ds
        mov  ax,0A000h
        mov  es,ax
        mov  ds,[bufseg]
        xor  si,si
        xor  di,di
        mov  cx,32000
        rep  movsw
        pop  ds
        inc  word ptr [fcnt2]
        ; once a second: latch the meters
        push es
        mov  ax,40h
        mov  es,ax
        mov  ax,es:[6Ch]
        pop  es
        sub  ax,[mtick]
        cmp  ax,18
        jl   @@nm
        push es
        mov  ax,40h
        mov  es,ax
        mov  ax,es:[6Ch]
        pop  es
        mov  [mtick],ax
        mov  ax,[fcnt2]
        mov  [fps],ax
        mov  word ptr [fcnt2],0
        mov  ax,[pcnt2]
        mov  [pps],ax
        mov  word ptr [pcnt2],0
@@nm:
        ; ---- keys ----
        mov  ah,1
        int  16h
        jz   @@jf
        xor  ah,ah
        int  16h
        cmp  al,27
        je   @@quit
        cmp  al,'+'
        jne  @@k1
        add  word ptr [pmax],4
        cmp  word ptr [pmax],NPMAX
        jle  @@jf
        mov  word ptr [pmax],NPMAX
@@k1:   cmp  al,'-'
        jne  @@k2
        sub  word ptr [pmax],4
        cmp  word ptr [pmax],4
        jge  @@jf
        mov  word ptr [pmax],4
@@k2:   cmp  al,'w'
        jne  @@k3
        mov  ax,[pspd]
        add  ax,ax
        cmp  ax,1024
        jle  @@ws
        mov  ax,1024
@@ws:   mov  [pspd],ax
        jmp  @@jf
@@k3:   cmp  al,'s'
        jne  @@kw1
        mov  ax,[pspd]
        sar  ax,1
        cmp  ax,64
        jge  @@ss
        mov  ax,64
@@ss:   mov  [pspd],ax
        jmp  @@jf
@@kw1:  cmp  al,'f'
        jne  @@kw2
        sub  word ptr [wang],8
@@kw2:  cmp  al,'g'
        jne  @@kw3
        add  word ptr [wang],8
@@kw3:  and  word ptr [wang],255
        cmp  al,'v'
        jne  @@kw4
        sub  word ptr [wfrc],2
        cmp  word ptr [wfrc],0
        jge  @@kw4
        mov  word ptr [wfrc],0
@@kw4:  cmp  al,'b'
        jne  @@kw5
        add  word ptr [wfrc],2
        cmp  word ptr [wfrc],24
        jle  @@kw5
        mov  word ptr [wfrc],24
@@kw5:
@@k4:   cmp  al,'['
        jne  @@k5
        add  word ptr [camd],60
        cmp  word ptr [camd],2200
        jle  @@jf
        mov  word ptr [camd],2200
@@k5:   cmp  al,']'
        jne  @@k6
        sub  word ptr [camd],60
        cmp  word ptr [camd],280
        jge  @@jf
        mov  word ptr [camd],280
@@k6:   or   al,al              ; extended: arrows
        jnz  @@jf
        cmp  ah,4Bh
        jne  @@a1
        sub  word ptr [cama],3
@@a1:   cmp  ah,4Dh
        jne  @@a2
        add  word ptr [cama],3
@@a2:   cmp  ah,48h
        jne  @@a3
        add  word ptr [camh],24
        cmp  word ptr [camh],1400
        jle  @@a3
        mov  word ptr [camh],1400
@@a3:   cmp  ah,50h
        jne  @@jf
        sub  word ptr [camh],24
        cmp  word ptr [camh],40
        jge  @@jf
        mov  word ptr [camh],40
@@jf:   and  word ptr [cama],255
        jmp  @@frame
@@quit: mov  ax,0003h
        int  10h
        mov  ax,4C00h
        int  21h

; ============================================================================
;  PHYS - one gas step for every live particle; respawn the dead while
;  the pool is under the knob. Positions are 12.4 fixed (world*16).
; ============================================================================
PHYS:   mov  ax,[wang]          ; the wind vector for this step
        call SINQ
        imul word ptr [wfrc]
        mov  bx,256
        idiv bx
        mov  [wvz],ax
        mov  ax,[wang]
        add  ax,64
        call SINQ
        imul word ptr [wfrc]
        mov  bx,256
        idiv bx
        mov  [wvx],ax
        mov  word ptr [spwn],1  ; ONE birth per step: a steady
        xor  si,si              ; thread of smoke, not tufts
@@pp:   mov  bx,si
        add  bx,bx              ; word index
        cmp  word ptr [page_+bx],0
        jne  @@live
        ; dead: respawn if the knob allows it (index < pmax)
        cmp  si,[pmax]
        jae  @@nx
        cmp  word ptr [spwn],0
        je   @@nx
        dec  word ptr [spwn]
        call SPAWN
        jmp  @@nx
@@live: inc  word ptr [page_+bx]
        mov  ax,[plife+bx]      ; a personal lifetime: deaths come
        cmp  [page_+bx],ax      ; one by one, spread ~3.5 s
        jb   @@ph1
        mov  word ptr [page_+bx],0  ; faded out for good
        jmp  @@nx
@@ph1:  ; ---- buoyancy: hot young gas climbs harder ----
        mov  ax,[page_+bx]
        cmp  ax,48
        jae  @@bs
        add  word ptr [pvy+bx],3    ; fire: a low flame, not a rocket
        jmp  @@bd
@@bs:   add  word ptr [pvy+bx],8    ; smoke: the column climbs
@@bd:   ; ---- drag: velocity decays by 1/16 ----
        mov  ax,[pvx+bx]
        mov  cx,ax
        mov  cl,4
        sar  ax,cl
        sub  [pvx+bx],ax
        mov  ax,[pvy+bx]
        sar  ax,cl
        sub  [pvy+bx],ax
        mov  ax,[pvz+bx]
        sar  ax,cl
        sub  [pvz+bx],ax
        ; ---- vortex swirl about the plume axis ----
        mov  ax,[ppz+bx]
        sar  ax,cl              ; /16: world units
        mov  cx,3
        imul cx
        mov  cl,5
        sar  ax,cl
        sub  [pvx+bx],ax        ; vx -= z*k
        mov  ax,[ppx+bx]
        mov  cl,4
        sar  ax,cl
        mov  cx,3
        imul cx
        mov  cl,5
        sar  ax,cl
        add  [pvz+bx],ax        ; vz += x*k
        ; ---- turbulence: a random-walk kick (HIGH LCG bits) ----
        push bx
        call RND16
        pop  bx
        mov  al,ah
        cbw
        mov  cl,4
        sar  ax,cl              ; -8..7
        add  [pvx+bx],ax
        push bx
        call RND16
        pop  bx
        mov  al,ah
        cbw
        sar  ax,cl
        add  [pvz+bx],ax
        cmp  word ptr [page_+bx],48 ; wind grips only the smoke
        jl   @@nw
        mov  ax,[wvx]
        add  [pvx+bx],ax
        mov  ax,[wvz]
        add  [pvz+bx],ax
@@nw:
        ; ---- integrate (velocity is per-step, positions 12.4) ----
        mov  ax,[pvx+bx]
        mov  cl,3
        sar  ax,cl
        add  [ppx+bx],ax
        mov  ax,[pvy+bx]
        mov  cl,2               ; the vertical climbs harder
        sar  ax,cl
        add  [ppy+bx],ax
        mov  cl,3
        mov  ax,[pvz+bx]
        sar  ax,cl
        add  [ppz+bx],ax
        ; ---- the puff swells and slowly spins ----
        cmp  word ptr [page_+bx],48 ; the flame keeps its size -
        jl   @@sw               ; only SMOKE swells
        mov  ax,[psz+bx]
        cmp  ax,220             ; full-grown puff cap
        jge  @@sw
        add  ax,2
        mov  [psz+bx],ax
@@sw:   mov  ax,[pspin+bx]
        add  [pphi+bx],ax
@@nx:   inc  si
        cmp  si,NPMAX
        jb   @@pp
        ret

; ---- SPAWN: light a fresh fire particle at the source ----------------------
SPAWN:  mov  word ptr [page_+bx],1
        push bx
        call RND16
        pop  bx
        mov  dx,ax              ; random bits: dl offset x, dh offset z
        mov  al,dl
        cbw
        mov  cl,1
        sar  ax,cl              ; -64..63 (12.4: +-4 units)
        mov  [ppx+bx],ax
        mov  al,dh
        cbw
        sar  ax,cl
        mov  [ppz+bx],ax
        mov  word ptr [ppy+bx],48   ; 3 units above the floor
        mov  word ptr [pvx+bx],0
        mov  word ptr [pvz+bx],0
        push bx
        call RND16
        pop  bx
        mov  al,ah              ; kick 28..59: beads never line up
        xor  ah,ah
        and  ax,31
        add  ax,28
        mov  [pvy+bx],ax
        mov  word ptr [psz+bx],60   ; small and hot
        push bx
        call RND16
        pop  bx
        mov  [pphi+bx],ax           ; random facing
        mov  al,ah
        cbw
        mov  cl,5
        sar  ax,cl                  ; -4..3 spin per step
        jnz  @@s1
        inc  ax
@@s1:   mov  [pspin+bx],ax
        push bx
        call RND16
        pop  bx
        and  ax,7*2
        mov  [pshp+bx],ax           ; one of 8 radius profiles
        push bx
        call RND16
        pop  bx
        mov  al,ah              ; a personal grey 4..7: one puff-
        xor  ah,ah
        and  ax,3
        add  ax,4
        mov  [psh+bx],ax        ; cluster, four different smokes
        push bx
        call RND16
        pop  bx
        mov  al,ah              ; lifetime 190..253 steps: the
        xor  ah,ah
        and  ax,63
        add  ax,190
        mov  [plife+bx],ax      ; column top frays, never chops
        ret

; ============================================================================
;  RENDER - project every live puff, painter-sort by depth, draw far
;  to near as filled star polygons (even-odd scanline fill).
; ============================================================================
RENDER: mov  word ptr [lcnt],0  ; live count (memory: CL is for shifts)
        xor  si,si
@@rp:   mov  bx,si
        add  bx,bx
        cmp  word ptr [page_+bx],0
        je   @@rn
        ; world -> camera space
        mov  ax,[ppx+bx]
        mov  cl,4
        sar  ax,cl              ; 12.4 -> units
        sub  ax,[camx]
        mov  [wdx],ax
        mov  ax,[ppz+bx]
        sar  ax,cl
        sub  ax,[camz]
        mov  [wdz],ax
        push bx
        push si
        call ROTXZ
        pop  si
        pop  bx
        mov  ax,[rcz]
        cmp  ax,NEARZ
        jle  @@rn
        ; store depth + index for the painter
        mov  di,[lcnt]
        add  di,di
        mov  [SRTD+di],ax       ; depth
        mov  ax,si
        mov  [SRTI+di],ax       ; particle index
        inc  word ptr [lcnt]
@@rn:   inc  si
        cmp  si,NPMAX
        jb   @@rp
        mov  cx,[lcnt]
        jcxz @@rdone
        ; ---- insertion sort far -> near (list is nearly sorted) ----
        mov  si,2
@@is:   cmp  si,cx
        jae  @@isd
        mov  di,si
        add  di,di
        mov  ax,[SRTD+di]
        mov  dx,[SRTI+di]
@@iw:   cmp  di,2
        jb   @@ip
        cmp  ax,[SRTD+di-2]
        jle  @@ip
        push ax
        mov  ax,[SRTD+di-2]
        mov  [SRTD+di],ax
        mov  ax,[SRTI+di-2]
        mov  [SRTI+di],ax
        pop  ax
        sub  di,2
        jmp  @@iw
@@ip:   mov  [SRTD+di],ax
        mov  [SRTI+di],dx
        inc  si
        jmp  @@is
@@isd:  ; ---- draw in order ----
        mov  word ptr [rdi],0
@@dl:   mov  ax,[rdi]
        cmp  ax,[lcnt]
        jae  @@rdone
        add  ax,ax
        mov  di,ax
        mov  ax,[SRTI+di]
        call PUFF
        inc  word ptr [rdi]
        jmp  @@dl
@@rdone:ret

; ---- PUFF: draw one particle (AX = index) as a filled star polygon --------
PUFF:   mov  si,ax
        mov  bx,ax
        add  bx,bx
        ; re-project (cheap; keeps the sort table small)
        mov  ax,[ppx+bx]
        mov  cl,4
        sar  ax,cl
        sub  ax,[camx]
        mov  [wdx],ax
        mov  ax,[ppz+bx]
        sar  ax,cl
        sub  ax,[camz]
        mov  [wdz],ax
        push bx
        call ROTXZ
        pop  bx
        mov  ax,[rcz]
        cmp  ax,NEARZ
        jle  @@x
        mov  [prz],ax
        mov  ax,[ppy+bx]
        mov  cl,4
        sar  ax,cl
        sub  ax,[camy]
        mov  dx,ax
        mov  ax,[rcx]
        mov  cx,[prz]
        push bx
        call PROJPT
        pop  bx
        mov  [pcx],ax           ; projected centre
        mov  [pcy],dx
        ; screen radius = size*FOCAL/rz (12.4 size)
        mov  ax,[psz+bx]
        mov  cx,FOCAL
        imul cx
        idiv word ptr [prz]
        mov  cl,2               ; 12.4 folded by /4 only: a grown
        sar  ax,cl              ; puff is ~13 px at ring distance
        cmp  ax,1
        jge  @@r1
        mov  ax,1
@@r1:   cmp  ax,70
        jle  @@r2
        mov  ax,70
@@r2:   mov  [prad],ax
        ; colour by age: fire ramp then smoke greys
        mov  ax,[page_+bx]
        mov  dl,3               ; yellow heart
        cmp  ax,16
        jb   @@cd
        mov  dl,2               ; orange
        cmp  ax,32
        jb   @@cd
        mov  dl,1               ; red
        cmp  ax,48
        jb   @@cd
        mov  dx,[psh+bx]        ; the personal shade...
        cmp  ax,150
        jb   @@cd
        dec  dl                 ; ...fading darker with age
        cmp  dl,4
        jge  @@cd
        mov  dl,4
@@cd:   mov  [pcol],dl
        ; ---- build MVERT screen vertices around the centre ----
        mov  di,[pshp+bx]       ; profile base (word offset)
        mov  word ptr [vk],0
@@vv:   mov  ax,[vk]
        mov  cx,256/MVERT
        imul cx
        add  ax,[pphi+bx]       ; spin
        push bx
        push ax
        call SINQ               ; sin
        mov  [tsin],ax
        pop  ax
        add  ax,64
        call SINQ               ; cos
        mov  [tcos],ax
        pop  bx
        ; radius = prad * profile/32  (profile bytes 22..40)
        mov  ax,[pshp+bx]
        shr  ax,1               ; profile start slot
        add  ax,[vk]
        and  ax,15              ; the 16-byte table wraps
        push bx
        mov  bx,ax
        mov  al,[PROF+bx]
        xor  ah,ah
        pop  bx
        mul  word ptr [prad]
        mov  cx,32
        div  cx
        mov  [trr],ax           ; r (<= ~90: products fit 16 bits)
        mov  ax,[tcos]
        imul word ptr [trr]
        mov  cl,8
        sar  ax,cl              ; * r / 256
        add  ax,[pcx]
        push bx
        mov  bx,[vk]
        add  bx,bx
        mov  [VXX+bx],ax
        pop  bx
        mov  ax,[tsin]
        imul word ptr [trr]
        sar  ax,cl
        ; squash y for the isometric look
        mov  dx,ax
        sar  ax,1
        add  ax,dx
        sar  ax,1               ; *3/4
        add  ax,[pcy]
        push bx
        mov  bx,[vk]
        add  bx,bx
        mov  [VYY+bx],ax
        pop  bx
        inc  word ptr [vk]
        cmp  word ptr [vk],MVERT
        jb   @@vv
        call FILLP              ; even-odd scanline fill, clamped
@@x:    ret

; ============================================================================
;  FILLP - fill the MVERT-gon in VXX/VYY with colour [pcol] into ES buffer.
;  Even-odd rule per scanline; every write clamped to 320x200.
; ============================================================================
FILLP:  mov  ax,32767           ; y range of the polygon
        mov  dx,-32768
        xor  si,si
@@mm:   mov  bx,si
        add  bx,bx
        mov  cx,[VYY+bx]
        cmp  cx,ax
        jge  @@m1
        mov  ax,cx
@@m1:   cmp  cx,dx
        jle  @@m2
        mov  dx,cx
@@m2:   inc  si
        cmp  si,MVERT
        jb   @@mm
        cmp  ax,0               ; clamp to screen rows
        jge  @@m3
        xor  ax,ax
@@m3:   cmp  dx,199
        jle  @@m4
        mov  dx,199
@@m4:   cmp  ax,dx
        jg   @@fx
        mov  [fy],ax
        mov  [fy2],dx
@@row:  mov  ax,[fy]
        ; collect edge intersections with this row
        mov  word ptr [xn],0
        xor  si,si
@@ee:   mov  bx,si
        add  bx,bx
        mov  cx,[VYY+bx]        ; y0
        mov  di,si
        inc  di
        cmp  di,MVERT
        jb   @@e0
        xor  di,di
@@e0:   add  di,di
        mov  dx,[VYY+di]        ; y1
        cmp  cx,dx
        je   @@en               ; horizontal edge: skip
        ; does the row cross [min,max) ?
        cmp  cx,dx
        jl   @@e1
        xchg cx,dx              ; cx=min dx=max, swap ends too
        push word ptr [VXX+bx]
        mov  ax,[VXX+di]
        mov  [tx0],ax
        pop  ax
        mov  [tx1],ax
        push word ptr [VYY+di]
        pop  word ptr [ty0]
        jmp  @@e2
@@e1:   mov  ax,[VXX+bx]
        mov  [tx0],ax
        mov  ax,[VXX+di]
        mov  [tx1],ax
        push cx
        pop  word ptr [ty0]
@@e2:   mov  ax,[fy]
        cmp  ax,cx
        jl   @@en
        cmp  ax,dx
        jge  @@en
        ; x = x0 + (x1-x0)*(y-y0)/(y1-y0)
        sub  ax,[ty0]           ; y - ymin
        mov  bx,dx
        sub  bx,cx              ; dy (>0)
        push bx
        mov  bx,[tx1]
        sub  bx,[tx0]
        imul bx
        pop  bx
        idiv bx
        add  ax,[tx0]
        mov  bx,[xn]
        add  bx,bx
        mov  [XS+bx],ax
        inc  word ptr [xn]
@@en:   inc  si
        cmp  si,MVERT
        jb   @@ee
        ; sort the (few) intersections ascending
        mov  cx,[xn]
        cmp  cx,2
        jl   @@rn2
@@sx:   xor  dx,dx              ; bubbled flag
        xor  si,si
@@sxi:  mov  bx,si
        add  bx,bx
        mov  ax,[XS+bx]
        cmp  ax,[XS+bx+2]
        jle  @@sxn
        xchg ax,[XS+bx+2]
        mov  [XS+bx],ax
        mov  dx,1
@@sxn:  inc  si
        mov  ax,[xn]
        dec  ax
        cmp  si,ax
        jb   @@sxi
        or   dx,dx
        jnz  @@sx
        ; fill pairs
        xor  si,si
@@fp:   mov  bx,si
        add  bx,bx
        mov  ax,[XS+bx]         ; left
        mov  dx,[XS+bx+2]       ; right
        cmp  ax,0
        jge  @@f1
        xor  ax,ax
@@f1:   cmp  dx,319
        jle  @@f2
        mov  dx,319
@@f2:   cmp  ax,dx
        jg   @@fn
        push si
        mov  cx,dx
        sub  cx,ax
        inc  cx
        mov  si,ax
        mov  ax,[fy]
        push cx
        call ROW320
        pop  cx
        add  di,si
        mov  al,[pcol]
        rep  stosb
        pop  si
@@fn:   add  si,2
        mov  ax,[xn]
        cmp  si,ax
        jb   @@fp
@@rn2:  inc  word ptr [fy]
        mov  ax,[fy]
        cmp  ax,[fy2]
        jle  @@row
@@fx:   ret

; ---- GROUND: a faint reference grid on the floor ---------------------------
GROUND: mov  word ptr [gi],-4
@@gg:   mov  word ptr [gj],-4
@@gh:   mov  ax,[gi]
        mov  cx,120
        imul cx
        sub  ax,[camx]
        mov  [wdx],ax
        mov  ax,[gj]
        imul cx
        sub  ax,[camz]
        mov  [wdz],ax
        call ROTXZ
        mov  ax,[rcz]
        cmp  ax,NEARZ
        jle  @@gn
        mov  cx,ax
        xor  ax,ax
        sub  ax,[camy]          ; floor y = 0
        mov  dx,ax
        mov  ax,[rcx]
        call PROJPT
        cmp  ax,1
        jl   @@gn
        cmp  ax,318
        jg   @@gn
        cmp  dx,1
        jl   @@gn
        cmp  dx,198
        jg   @@gn
        push ax
        mov  ax,dx
        call ROW320
        pop  ax
        add  di,ax
        mov  al,8               ; dim green dot
        mov  es:[di],al
@@gn:   inc  word ptr [gj]
        cmp  word ptr [gj],5
        jle  @@gh
        inc  word ptr [gi]
        cmp  word ptr [gi],5
        jle  @@gg
        ret

; ---- HUDTXT: the lab readout ------------------------------------------------
HUDTXT: mov  byte ptr [tcol],9
        mov  si,offset MSGT
        mov  ax,4
        mov  bx,8
        call TXT
        mov  si,offset MSGN     ; PART=
        mov  ax,186
        mov  bx,8
        call TXT
        mov  ax,[pmax]
        mov  bx,56
        mov  dx,186
        call TXTNUM
        mov  si,offset MSGS     ; SPD%=
        mov  ax,186
        mov  bx,92
        call TXT
        mov  ax,[pspd]
        mov  cx,100
        mul  cx
        mov  cx,256
        div  cx
        mov  bx,132
        mov  dx,186
        call TXTNUM
        mov  si,offset MSGP     ; PHY/S=
        mov  ax,186
        mov  bx,170
        call TXT
        mov  ax,[pps]
        mov  bx,218
        mov  dx,186
        call TXTNUM
        mov  si,offset MSGW     ; WIND=
        mov  ax,176
        mov  bx,8
        call TXT
        mov  ax,[wfrc]
        mov  bx,56
        mov  dx,176
        call TXTNUM
        mov  si,offset MSGF     ; FPS=
        mov  ax,186
        mov  bx,252
        call TXT
        mov  ax,[fps]
        mov  bx,286
        mov  dx,186
        call TXTNUM
        ret

; ---- ROW320 / TXTNUM / TXT / WAITVR (the AVIO kit) --------------------------
ROW320: mov  bx,ax
        mov  cl,6
        shl  ax,cl
        mov  cl,8
        shl  bx,cl
        add  ax,bx
        mov  di,ax
        ret

TXTNUM: push bx
        push dx
        mov  di,offset NBUF+5
        mov  byte ptr [di],0
        mov  cx,10
@@d:    dec  di
        xor  dx,dx
        div  cx
        add  dl,'0'
        mov  [di],dl
        or   ax,ax
        jnz  @@d
        mov  si,di
        pop  ax
        pop  bx
        call TXT
        ret
NBUF    db 6 dup(0)

TXT:    push es
        push dx
        mov  cx,ax
        mov  ax,[bufseg]
        mov  es,ax
        mov  ax,cx
        mov  cx,320
        mul  cx
        add  ax,bx
        mov  di,ax
@@ch:   lodsb
        or   al,al
        jz   @@done
        push si
        xor  ah,ah
        mov  cl,3
        shl  ax,cl
        mov  si,0FA6Eh
        add  si,ax
        push ds
        mov  ax,0F000h
        mov  ds,ax
        mov  cx,8
        push di
@@row:  lodsb
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
        add  di,8
        jmp  @@ch
@@done: pop  dx
        pop  es
        ret

WAITVR: mov  dx,3DAh
@@w1:   in   al,dx
        test al,8
        jnz  @@w1
@@w2:   in   al,dx
        test al,8
        jz   @@w2
        ret

; ---- data ------------------------------------------------------------------
PAL     db   1, 50,10, 4        ; fire: red
        db   2, 60,28, 6        ;       orange
        db   3, 63,52,16        ;       yellow
        db   4, 12,12,13        ; smoke: near-gone
        db   5, 18,18,20        ;        old
        db   6, 26,26,29        ;        middle
        db   7, 34,34,38        ;        young
        db   8,  8,20,10        ; floor grid
        db   9, 63,42,10        ; readout amber
        db 255
MSGT    db 'FIRE+SMOKE  arrows=orbit +-=count W/S=speed F/G/V/B=wind [ ]=zoom',0
MSGN    db 'PART=',0
MSGS    db 'SPD%=',0
MSGP    db 'PHY/S=',0
MSGF    db 'FPS=',0
MSGW    db 'WIND=',0
PROF    db 32,30,34,31,29,33,30,32   ; gentle radius profiles: puffs,
        db 31,33,29,34,30,32,28,33   ; not hedgehogs
rseed   dw 1
ltick   dw 0                    ; physics clock
pacc    dw 0
pspd    dw 256                  ; speed knob (256 = x1)
mtick   dw 0                    ; meters
fcnt2   dw 0
pcnt2   dw 0
fps     dw 0
pps     dw 0
pmax    dw 32                   ; particle knob
lcnt    dw 0
spwn    dw 0
wang    dw 64                   ; wind direction
wfrc    dw 0                    ; wind force 0..24
wvx     dw 0
wvz     dw 0
rdi     dw 0
cama    dw 32                   ; camera knobs
camh    dw 420
camd    dw 900
; particle pool (word arrays)
page_   dw NPMAX dup(0)         ; 0 = dead, else age
ppx     dw NPMAX dup(0)         ; position 12.4
ppy     dw NPMAX dup(0)
ppz     dw NPMAX dup(0)
pvx     dw NPMAX dup(0)         ; velocity
pvy     dw NPMAX dup(0)
pvz     dw NPMAX dup(0)
psz     dw NPMAX dup(0)         ; puff size 12.4
pphi    dw NPMAX dup(0)         ; spin phase
pspin   dw NPMAX dup(0)         ; spin rate
pshp    dw NPMAX dup(0)         ; profile offset
psh     dw NPMAX dup(0)         ; personal grey shade
plife   dw NPMAX dup(0)         ; personal lifetime
; render scratch
SRTD    dw NPMAX dup(0)
SRTI    dw NPMAX dup(0)
VXX     dw 8 dup(0)
VYY     dw 8 dup(0)
XS      dw 10 dup(0)
prz     dw 0
pcx     dw 0
pcy     dw 0
prad    dw 0
pcol    db 0
vk      dw 0
tsin    dw 0
tcos    dw 0
fy      dw 0
fy2     dw 0
xn      dw 0
trr     dw 0
tx0     dw 0
tx1     dw 0
ty0     dw 0
gi      dw 0
gj      dw 0
tcol    db 9
bufseg  dw 0
; ---- engine contract (E_M3D) ----
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
camx    dw 0
camy    dw 0
camz    dw 0
wdx     dw 0
wdz     dw 0
rcx     dw 0
rcz     dw 0
rddx    dw 0
rddy    dw 0
rsxo    dw 0
ptmp    dw 0
SINT    dw 0,6,13,19,25,31,38,44,50,56,62,68,74,80,86,92,98,104,109,115
        dw 121,126,132,137,142,147,153,157,162,167,172,177,181,185,190,194
        dw 198,202,206,209,213,216,220,223,226,229,231,234,237,239,241,243
        dw 245,247,248,250,251,252,253,254,255,255,256,256,256

        INCLUDE ..\ENGINE\E_MATH.INC
        INCLUDE ..\ENGINE\E_M3D.INC

CODE    ENDS
        END START
