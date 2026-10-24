; ============================================================================
;  R_PARTIC.ASM - recipe: a particle pool - fire that ages into smoke, or
;  sparks that fall - for a 2D screen.
;
;  EXAMPLES\SMOKE.ASM's gas, flattened: a pool of particles; each tick the
;  live ones age, feel buoyancy (hot young gas climbs gently, smoke harder)
;  or gravity, lose 1/16 of their speed to drag, take a random kick from the
;  HIGH bits of the LCG (its low bits repeat), feel the wind once they are
;  smoke, and move. ONE birth a tick at the source: a steady thread, not
;  tufts. Each has its own lifetime, so they die one by one.
;  Positions are 12.4 (pixels x16), speeds 16ths of a pixel; up is -y.
;  Everything counts ticks, never frames (guide TIME).
;
;        mov  word [psrcx],160   ; the source, pixels
;        mov  word [psrcy],180
;        ...each tick:   call PSTEP
;        ...each frame:  call PDRAW          ; ES = the buffer, 320 a row
;  Sparks instead of smoke: pfire = 6, psmoke = 6 (positive: they fall),
;  pkick = 40 (thrown up harder), pwind = 0.
;
;  copy: PSTEP, PSPAWN, PDRAW, the words and arrays at the end; the ramp
;        PRAMP is colours by age (the default palette: yellow to greys).
;  define before: rseed dw (seed it from the tick, OR 1)
;  needs: ENGINE\E_MATH.INC (RND16)
;  from: EXAMPLES\SMOKE.ASM:270-452 (PHYS, SPAWN): 3D to 2D, the vortex
;        swirl, spin and puff polygons left out; PDRAW new (SMOKE draws
;        painter-sorted polygons)
; ============================================================================
NPART   = 48                    ; the pool
FIREAGE = 12                    ; ticks a particle is fire before it is smoke

; ----------------------------------------------------------------------
;@ PSTEP      one tick of the particle pool: age, buoyancy, drag, kick, move
;  in:  [psrcx], [psrcy] the source; [pmax] how many may live (1..NPART)
;  out: -
; ----------------------------------------------------------------------
PSTEP:  push ax
        push bx
        push cx
        push si
        mov  byte [pbirth],1    ; one birth this tick
        xor  si,si              ; SI = the particle
.p:     mov  bx,si
        shl  bx,1               ; BX = its word index
        cmp  word [page+bx],0
        jne  .live
        cmp  si,[pmax]
        jae  .nx                ; above the knob: stays dead
        cmp  byte [pbirth],0
        je   .nx
        dec  byte [pbirth]      ; the birth is spent
        call PSPAWN
        jmp  .nx
.live:  inc  word [page+bx]     ; one tick older
        mov  ax,[plife+bx]
        cmp  [page+bx],ax
        jb   .ph
        mov  word [page+bx],0   ; its time is up
        jmp  .nx
.ph:    mov  ax,[pfire]         ; buoyancy (negative: up) or gravity
        cmp  word [page+bx],FIREAGE
        jb   .b
        mov  ax,[psmoke]
.b:     add  [pvy+bx],ax        ; vy += the lift of its age
        mov  cl,4
        mov  ax,[pvx+bx]
        sar  ax,cl              ; drag: v/16...
        sub  [pvx+bx],ax        ; ...off
        mov  ax,[pvy+bx]
        sar  ax,cl
        sub  [pvy+bx],ax
        call RND16
        mov  al,ah              ; the HIGH byte: the good bits
        cbw
        sar  ax,cl              ; -8..7
        add  [pvx+bx],ax        ; a random kick sideways
        cmp  word [page+bx],FIREAGE
        jb   .mv
        mov  ax,[pwind]
        add  [pvx+bx],ax        ; the wind grips only the smoke
.mv:    mov  ax,[pvx+bx]
        mov  cl,3
        sar  ax,cl              ; a tick moves v/8 (x)
        add  [ppx+bx],ax
        mov  ax,[pvy+bx]
        mov  cl,2
        sar  ax,cl              ; and v/4 (y: it climbs harder)
        add  [ppy+bx],ax
.nx:    inc  si                 ; the next particle
        cmp  si,NPART
        jb   .p
        pop  si
        pop  cx
        pop  bx
        pop  ax
        ret

; ----------------------------------------------------------------------
;@ PSPAWN     a fresh particle in slot BX/2 at the source, thrown up
;  in:  BX = the slot * 2
;  out: -
; ----------------------------------------------------------------------
PSPAWN: push ax
        push cx
        push dx
        mov  word [page+bx],1
        call RND16
        mov  dx,ax              ; random bits: DL the x offset
        mov  al,dl
        cbw
        sar  ax,1
        sar  ax,1               ; -32..31: +-2 pixels in 12.4
        mov  cx,[psrcx]
        shl  cx,1
        shl  cx,1
        shl  cx,1
        shl  cx,1               ; the source x * 16
        add  ax,cx
        mov  [ppx+bx],ax
        mov  ax,[psrcy]
        mov  cl,4
        shl  ax,cl              ; the source y * 16
        mov  [ppy+bx],ax
        mov  word [pvx+bx],0
        mov  al,dh
        xor  ah,ah
        and  ax,31              ; 0..31...
        add  ax,[pkick]         ; ...plus the kick
        neg  ax                 ; up the screen
        mov  [pvy+bx],ax
        call RND16
        mov  al,ah
        xor  ah,ah
        and  ax,63              ; a lifetime of its own: they die one by one
        add  ax,[plifemin]
        mov  [plife+bx],ax
        pop  dx
        pop  cx
        pop  ax
        ret

; ----------------------------------------------------------------------
;@ PDRAW      draw every live particle: a dot of fire, a 2x2 puff of smoke
;  in:  ES = the buffer (320 bytes a row, 200 rows)
;  out: -  (off-screen ones are skipped)
; ----------------------------------------------------------------------
PDRAW:  push ax
        push bx
        push cx
        push dx
        push si
        push di
        xor  si,si
.p:     mov  bx,si
        shl  bx,1               ; word index
        cmp  word [page+bx],0
        je   .nx
        mov  ax,[ppx+bx]
        mov  cl,4
        sar  ax,cl              ; x in pixels
        cmp  ax,319
        jae  .nx                ; (unsigned: off either side)
        mov  dx,[ppy+bx]
        sar  dx,cl              ; y in pixels
        cmp  dx,199
        jae  .nx
        mov  di,dx
        mov  cl,8
        shl  di,cl              ; y*256
        mov  cl,6
        shl  dx,cl              ; y*64
        add  di,dx              ; y*320
        add  di,ax              ; + x
        mov  ax,[page+bx]
        mov  cl,3
        shr  ax,cl              ; the age in eighths of its ramp
        cmp  ax,PRAMPN-1
        jbe  .c
        mov  ax,PRAMPN-1        ; the end of the ramp
.c:     push bx
        mov  bx,ax
        mov  al,[PRAMP+bx]      ; AL = its colour
        pop  bx
        mov  [es:di],al
        cmp  word [page+bx],FIREAGE
        jb   .nx                ; fire: a dot
        mov  [es:di+1],al       ; smoke: a puff of four
        mov  [es:di+320],al
        mov  [es:di+321],al
.nx:    inc  si
        cmp  si,NPART
        jb   .p
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret

PRAMP   db 15,14,43,42,41,40,28,27,26,25,24,23,22,21,20,19   ; white, yellow,
PRAMPN  = $ - PRAMP             ;  orange, red, then greys darkening (VGA default)
psrcx   dw 160                  ; the source, pixels
psrcy   dw 180
pmax    dw NPART                ; how many may live
pfire   dw -3                   ; vy += this a tick while fire (negative: rises)
psmoke  dw -8                   ; ...and while smoke
pwind   dw 1                    ; vx += this a tick, smoke only
pkick   dw 28                   ; the throw up at birth: 28..59
plifemin dw 50                  ; lifetimes: 50..113 ticks
pbirth  db 0
page    rw NPART                ; age in ticks, 0 = dead
plife   rw NPART                ; each one's lifetime
ppx     rw NPART                ; position, 12.4
ppy     rw NPART
pvx     rw NPART                ; speed, 16ths of a pixel
pvy     rw NPART
