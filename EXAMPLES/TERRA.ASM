; ============================================================================
;  TERRA.COM - WIRE CITY engine example 01: the island factory
;
;  Every island in WIRE CITY is born here: Diamond-Square midpoint
;  displacement on a 64x64 torus, integer only, seeded from the BIOS clock
;  so no two runs match. This example draws the raw heightmap as a colour
;  map (the same height bands the game zones the world with) and lets you
;  mint fresh islands with a keypress.
;
;  ~2 KB of .COM. Build: see EXAMPLES\README.md. Any key = a new island,
;  ESC = back to DOS.
;
;  What to notice:
;   - DSGEN works on a TORUS (HGET wraps x and y with AND 63), so the
;     diamond and square steps never special-case the map edges.
;   - Plain Diamond-Square averaging flattens toward the middle grey, so
;     DSGEN finishes with a histogram stretch to win the full 0..255 range.
;   - The whole generator costs ~150 instructions and 4 KB of state; the
;     game ships the recipe, not the world (The Sentinel, 1986, sends its
;     regards).
; ============================================================================
        .8086
        LOCALS
        JUMPS                   ; auto-extend long conditional jumps
CODE    SEGMENT
        ASSUME cs:CODE, ds:CODE, es:CODE, ss:CODE
        ORG  100h

START:  cld
        push es
        mov  ax,40h             ; seed the LCG from the BIOS tick count:
        mov  es,ax              ; launch a second later, get another world
        mov  ax,es:[6Ch]
        pop  es
        or   ax,1               ; the LCG must not start at 0
        mov  [rseed],ax
        mov  ax,0013h           ; VGA 320x200, 256 colours
        int  10h
        call SETPAL
@@next: call DSGEN              ; one fresh island, please
        call DRAW
        xor  ah,ah              ; wait for a key
        int  16h
        cmp  al,27              ; ESC leaves, anything else re-rolls
        jne  @@next
        mov  ax,0003h           ; text mode back
        int  10h
        mov  ax,4C00h
        int  21h

; ---- the island colours, written straight into the VGA DAC ----------------
SETPAL: mov  dx,3C8h
        mov  al,1               ; colours 1..6, three 0..63 channels each
        out  dx,al
        inc  dx
        mov  si,offset PAL
        mov  cx,6*3
@@p:    lodsb
        out  dx,al
        loop @@p
        ret
PAL     db  4,10,28             ; 1 sea
        db 16,38,10             ; 2 plains
        db 34,26,14             ; 3 city lowlands
        db 10,26, 8             ; 4 woods
        db 26,24,22             ; 5 rock
        db 46,48,50             ; 6 snow

; ---- draw the 64x64 map as 3x3 blocks, north (+y) up ----------------------
DRAW:   push es
        mov  ax,0A000h
        mov  es,ax
        mov  word ptr [dsx],0   ; node i (world X, screen column)
@@i:    mov  word ptr [dsy],0   ; node j (world Y, screen row 63-j)
@@j:    mov  bx,[dsx]
        mov  dx,[dsy]
        call HGET               ; AL = height 0..255
        ; height -> colour band (the exact bands GETZONE uses)
        mov  ah,1               ; sea
        cmp  al,88
        jb   @@put
        mov  ah,2               ; plains
        cmp  al,120
        jb   @@put
        mov  ah,3               ; city lowlands
        cmp  al,168
        jb   @@put
        mov  ah,4               ; woods
        cmp  al,200
        jb   @@put
        mov  ah,5               ; rock
        cmp  al,230
        jb   @@put
        mov  ah,6               ; snow
@@put:  mov  byte ptr [dsac],ah ; park the colour (MUL is about to eat AX)
        mov  ax,63              ; screen row = 63 - j (north up)
        sub  ax,[dsy]
        mov  bx,3
        mul  bx
        add  ax,4               ; 4 px top margin
        mov  bx,320
        mul  bx
        mov  di,ax
        mov  ax,[dsx]
        mov  bx,3
        mul  bx
        add  di,ax
        add  di,64              ; centre the 192 px map on the 320 px screen
        mov  al,byte ptr [dsac]
        mov  cx,3               ; a 3x3 block per node
@@r3:   mov  es:[di],al
        mov  es:[di+1],al
        mov  es:[di+2],al
        add  di,320
        loop @@r3
        inc  word ptr [dsy]
        cmp  word ptr [dsy],64
        jb   @@j
        inc  word ptr [dsx]
        cmp  word ptr [dsx],64
        jb   @@i
        pop  es
        ret

; ---- engine contract (see ENGINE\E_MATH.INC / E_TERR.INC) ------------------
rseed   dw 1                    ; LCG state
dss     dw 0                    ; DS: current side length
dsh     dw 0                    ; DS: half side
dsx     dw 0                    ; DS: loop x / scratch
dsy     dw 0                    ; DS: loop y / scratch
dsamp   dw 0                    ; DS: noise amplitude (power of two)
dsac    dw 0                    ; DS: accumulator / scratch

        INCLUDE ..\ENGINE\E_MATH.INC
        INCLUDE ..\ENGINE\E_TERR.INC

HMAP    db 4096 dup(0)          ; the 64x64 heightmap the generator fills

CODE    ENDS
        END START
