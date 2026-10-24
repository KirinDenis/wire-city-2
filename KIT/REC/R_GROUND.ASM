; ============================================================================
;  R_GROUND.ASM - recipe: the ground is the GROUND. Under the eye's height
;  plus a clearance the flight ends: the eye is put on the surface, steps
;  back along its heading to look at what it hit, waits, and is set flying
;  again high above the island's highest point.
;
;        call GCSPAWN            ; once at the start: in the air
;  .frame: cmp byte [gcdead],0
;        jne  .nofly
;        call FLIGHT             ; R_FLIGHT (or your own mover)
;  .nofly: call GCCHECK          ; AL = 0 flying, 1 crashed NOW, 2 wreck, 3 up again
;        ...draw; while [gcdead] show a CRASH sign
;
;  copy: GCCHECK GCSPAWN and their words.
;  define before (optional): GCCLEAR (96: how close to the ground you may
;         get), GCBACK (400: how far back the eye steps on a crash), GCWAIT
;         (36 ticks: two seconds of wreck), GCUP (700: how far above the
;         highest point it starts again)
;  calls: K_3D (R3_TRIG, the camera), K_TERR (TER_H, TER_TOP)
;  from: LESSONS\L22\FILL.ASM PHYS's floor:626-648, CRASH:748-789,
;        AIRBORNE:790-826, TOPOFMAP:690-716; the floor is TER_H (bilinear)
;        instead of the node under the eye
; ============================================================================

if ~ defined GCCLEAR | defined gc_d1
GCCLEAR = 96                    ; the clearance
gc_d1   = 1
end if
if ~ defined GCBACK | defined gc_d2
GCBACK  = 400                   ; the step back on a crash
gc_d2   = 1
end if
if ~ defined GCWAIT | defined gc_d3
GCWAIT  = 36                    ; BIOS ticks of wreck
gc_d3   = 1
end if
if ~ defined GCUP | defined gc_d4
GCUP    = 700                   ; respawn this far above the top
gc_d4   = 1
end if

gcdead  db 0                    ; 1 while a wreck
gctick  dw 0                    ; when it crashed
gccount dw 0                    ; crashes so far
gcspx   dw 0                    ; where GCSPAWN puts the eye (world x, z)
gcspz   dw 0
gcsph   dw 0                    ; ...and its heading

;@ GCCHECK    ground collision: AL 0 flying, 1 crashed now, 2 wreck, 3 up again
; ---- GCCHECK: AL = 0 flying, 1 crashed this call, 2 wreck, 3 flying again
GCCHECK:push bx
        push cx
        push dx
        cmp  byte [gcdead],0
        jne  .wreck
        mov  ax,[r3_camx]
        mov  bx,[r3_camz]
        call TER_H              ; AX = the ground under the eye
        add  ax,GCCLEAR         ; the lowest the eye may be
        cmp  [r3_camy],ax
        jge  .fly               ; clear of it
        mov  [r3_camy],ax       ; ---- the crash: on the surface... ----
        mov  byte [gcdead],1
        inc  word [gccount]
        call .tick
        mov  [gctick],ax
        mov  ax,[hsin]          ; ...and stepped back to look at the hill
        mov  bx,GCBACK
        imul bx                 ; DX:AX = hsin * back
        mov  bx,256
        idiv bx                 ; AX = hsin*back/256
        sub  [r3_camx],ax
        mov  ax,[hcos]
        mov  bx,GCBACK
        imul bx                 ; DX:AX = hcos * back
        mov  bx,256
        idiv bx                 ; AX = hcos*back/256
        sub  [r3_camz],ax
        mov  ax,[r3_camx]       ; ...above the ground THERE too
        mov  bx,[r3_camz]
        call TER_H
        add  ax,GCCLEAR
        cmp  [r3_camy],ax
        jge  .c1
        mov  [r3_camy],ax
.c1:    mov  word [roll],0
        call R3_TRIG
        mov  al,1
        jmp  .x
.wreck: call .tick
        sub  ax,[gctick]        ; how long a wreck
        cmp  ax,GCWAIT
        jae  .up
        mov  al,2
        jmp  .x
.up:    call GCSPAWN
        mov  al,3
        jmp  .x
.fly:   xor  al,al
.x:     pop  dx
        pop  cx
        pop  bx
        ret
.tick:  push es
        xor  ax,ax
        mov  es,ax
        mov  ax,[es:046Ch]
        pop  es
        ret

;@ GCSPAWN    the eye in the air again, above the island's highest point
; ---- GCSPAWN: in the air at [gcspx],[gcspz], heading [gcsph], above it all
GCSPAWN:push ax
        mov  ax,[gcspx]
        mov  [r3_camx],ax
        mov  ax,[gcspz]
        mov  [r3_camz],ax
        call TER_TOP            ; the highest ground on the island
        add  ax,GCUP
        mov  [r3_camy],ax
        mov  ax,[gcsph]
        mov  [heading],ax
        mov  word [roll],0
        mov  word [pitch],0
        call R3_TRIG
        mov  byte [gcdead],0
        pop  ax
        ret
