; HUD.INC - part of WIRE CITY (included from CITY.ASM)
; ============================================================================
;  HUD (BIOS text overlay on top of the frame)
; ============================================================================
HUD:    cmp  byte ptr [cockpit],0
        je   @@hgo
        cmp  word ptr [pimgo],0
        je   @@hgo
        ret                     ; photo cockpit covers the BIOS text rows
@@hgo:  mov  byte ptr [HCOL],8
        mov  ah,02h
        mov  bh,0
        mov  dh,0
        mov  dl,0
        int  10h
        mov  si,offset MSGTITLE
        call PRSTR
        mov  ah,02h
        mov  bh,0
        mov  dh,0
        mov  dl,28
        int  10h
        mov  si,offset MSGALT
        call PRSTR
        mov  ax,[camy]
        call PRNUM
        mov  ah,02h
        mov  bh,0
        mov  dh,24
        mov  dl,0
        int  10h
        cmp  byte ptr [cockpit],0
        jne  @@pantxt
        mov  si,offset MSGHDG
        call PRSTR
        mov  ax,[heading]
        call PRNUM
        mov  si,offset MSGSPD   ; airspeed (vel units, jet-style number)
        call PRSTR
        mov  ax,[vel]
        call PRNUM
        mov  si,offset MSGFUE   ; fuel as 0..100 percent
        call PRSTR
        mov  ax,[fuel]
        xor  dx,dx
        mov  bx,60
        div  bx
        call PRNUM
        mov  si,offset MSGTHR   ; throttle as 0..100 percent
        call PRSTR
        mov  ax,[throt]
        mov  bx,100
        imul bx
        mov  bx,64
        idiv bx
        call PRNUM
        cmp  byte ptr [abon],0  ; '+' marks a lit afterburner
        je   @@nab
        mov  al,'+'
        call PRCH
@@nab:  jmp  @@toprow
@@pantxt:                       ; panel text is drawn by PANEL (font)
@@toprow:
        ; real-time seconds (BIOS tick, 18.2 Hz) - compare against a stopwatch
        mov  ah,02h
        mov  bh,0
        mov  dh,0
        mov  dl,15
        int  10h
        mov  si,offset MSGT
        call PRSTR
        push es
        mov  ax,40h
        mov  es,ax
        mov  ax,es:[6Ch]       ; BIOS tick low word (18.2 Hz)
        pop  es
        xor  dx,dx
        mov  bx,18
        div  bx                ; ax ~= seconds
        call PRNUM
        ret

PRSTR:  lodsb
        test al,al
        jz   @@e
        call PRCH
        jmp  PRSTR
@@e:    ret

PRCH:   mov  ah,0Eh
        mov  bl,[HCOL]
        mov  bh,0
        int  10h
        ret

PRNUM:  mov  cx,0
        mov  bx,10
@@d:    xor  dx,dx
        div  bx
        push dx
        inc  cx
        test ax,ax
        jnz  @@d
@@p:    pop  dx
        add  dl,'0'
        mov  al,dl
        call PRCH
        loop @@p
        ret

; ============================================================================
;  PANEL - the cockpit. Three-tier stepped deck (uneven top reads as a real
;  dash): left pult y146+ (readouts + caution lights), centre console y132+
;  (the ADI ball), right tower y130+ (minimap + vertical LED bars).
;  ES=bufseg. Text uses the CITY.DAT 4x6 font. MINIMAP lands on the tower.
; ============================================================================
PANEL:  cmp  word ptr [pimgo],0
        je   @@classic
        jmp  PANELBMP           ; photo cockpit from CITY.DAT
@@classic:
        cld
        ; ---- deck fills, back to front ----
        mov  ax,147             ; left pult 0..115 x 147..199
        call ROW320
        mov  cx,53
@@lf:   push cx
        mov  al,29
        mov  cx,116
        rep  stosb
        add  di,320-116
        pop  cx
        loop @@lf
        mov  ax,134             ; centre console 116..212 x 134..199
        call ROW320
        add  di,116
        mov  cx,66
@@cf:   push cx
        mov  al,29
        mov  cx,97
        rep  stosb
        add  di,320-97
        pop  cx
        loop @@cf
        mov  ax,132             ; right tower 213..319 x 132..199
        call ROW320
        add  di,213
        mov  cx,68
@@rf:   push cx
        mov  al,29
        mov  cx,107
        rep  stosb
        add  di,320-107
        pop  cx
        loop @@rf
        ; ---- stepped rim: bright top edge + dark trim under it ----
        mov  ax,146             ; left step
        call ROW320
        mov  al,8
        mov  cx,116
        rep  stosb
        mov  ax,147
        call ROW320
        mov  al,30
        mov  cx,116
        rep  stosb
        mov  ax,132             ; centre step
        call ROW320
        add  di,116
        mov  al,8
        mov  cx,97
        rep  stosb
        mov  ax,133
        call ROW320
        add  di,116
        mov  al,30
        mov  cx,97
        rep  stosb
        mov  ax,130             ; tower step
        call ROW320
        add  di,213
        mov  al,8
        mov  cx,107
        rep  stosb
        mov  ax,131
        call ROW320
        add  di,213
        mov  al,30
        mov  cx,107
        rep  stosb
        ; ---- vertical joins between tiers ----
        mov  byte ptr [COLOR],8
        mov  word ptr [sx0],116
        mov  word ptr [sy0],132
        mov  word ptr [sx1],116
        mov  word ptr [sy1],146
        call CLIPLINE
        jc   @@j1
        call LINE
@@j1:   mov  word ptr [sx0],213
        mov  word ptr [sy0],130
        mov  word ptr [sx1],213
        mov  word ptr [sy1],133
        call CLIPLINE
        jc   @@j2
        call LINE
@@j2:   ; bevel cuts on the console shoulders (the "uneven" detail)
        mov  word ptr [sx0],116
        mov  word ptr [sy0],132
        mov  word ptr [sx1],124
        mov  word ptr [sy1],140
        call CLIPLINE
        jc   @@j3
        call LINE
@@j3:   mov  word ptr [sx0],212
        mov  word ptr [sy0],132
        mov  word ptr [sx1],204
        mov  word ptr [sy1],140
        call CLIPLINE
        jc   @@j4
        call LINE
@@j4:
        ; ================= left pult: readouts =================
        mov  byte ptr [COLOR],30
        mov  word ptr [ftx],6
        mov  word ptr [fty],152
        mov  si,offset MSGSPD2
        call FDRAW
        mov  word ptr [ftx],6
        mov  word ptr [fty],164
        mov  si,offset MSGTHR2
        call FDRAW
        mov  word ptr [ftx],6
        mov  word ptr [fty],176
        mov  si,offset MSGFUE2
        call FDRAW
        mov  word ptr [ftx],6
        mov  word ptr [fty],188
        mov  si,offset MSGHDG2
        call FDRAW
        mov  byte ptr [COLOR],8
        mov  word ptr [ftx],34
        mov  word ptr [fty],152
        mov  ax,[vel]
        call FNUM
        mov  word ptr [ftx],34
        mov  word ptr [fty],164
        mov  ax,[throt]
        mov  bx,100
        imul bx
        mov  bx,64
        idiv bx
        call FNUM
        mov  word ptr [ftx],34
        mov  word ptr [fty],176
        cmp  word ptr [fuel],1200
        jae  @@fw
        mov  byte ptr [COLOR],19
@@fw:   mov  ax,[fuel]
        xor  dx,dx
        mov  bx,60
        div  bx
        call FNUM
        mov  byte ptr [COLOR],8
        mov  word ptr [ftx],34
        mov  word ptr [fty],188
        mov  ax,[heading]
        call FNUM
        ; ================= caution lights (blink via BIOS tick) ==========
        ; light 1: STALL (red)  - vel below stall speed
        mov  word ptr [lampx],66
        mov  word ptr [lampy],150
        mov  si,offset MSGSTL
        xor  cx,cx
        cmp  word ptr [vel],VSTALL
        jge  @@l1
        mov  cx,19
@@l1:   call LAMP
        ; light 2: FUEL (amber, red-blinking when nearly dry)
        mov  word ptr [lampx],66
        mov  word ptr [lampy],162
        mov  si,offset MSGFUE2
        xor  cx,cx
        cmp  word ptr [fuel],1200
        jae  @@l2
        mov  cx,5
        cmp  word ptr [fuel],600
        jae  @@l2
        mov  cx,19
@@l2:   call LAMP
        ; light 3: TERR (red) - ground closer than 120 under the jet
        mov  word ptr [lampx],66
        mov  word ptr [lampy],174
        mov  si,offset MSGTER
        xor  cx,cx
        mov  ax,[camy]
        sub  ax,[lgnd]
        cmp  ax,120
        jge  @@l3
        mov  cx,19
@@l3:   call LAMP
        ; light 4: AB (amber) - afterburner lit
        mov  word ptr [lampx],66
        mov  word ptr [lampy],186
        mov  si,offset MSGAB2
        xor  cx,cx
        cmp  byte ptr [abon],0
        je   @@l4
        mov  cx,5
@@l4:   call LAMP
        ; ============ centre console: square ADI, LHX style ============
        ; frame 136..192 x 139..195, dark glass face, roll-rotated pitch
        ; ladder inside, fixed degree scale on the left, roll scale on top.
        mov  ax,139             ; glass face
        call ROW320
        add  di,136
        mov  cx,57
@@glass:
        push cx
        mov  al,3
        mov  cx,57
        rep  stosb
        add  di,320-57
        pop  cx
        loop @@glass
        mov  ax,139             ; frame: top and bottom
        call ROW320
        add  di,136
        mov  al,30
        mov  cx,57
        rep  stosb
        mov  ax,195
        call ROW320
        add  di,136
        mov  al,30
        mov  cx,57
        rep  stosb
        mov  byte ptr [COLOR],30 ; frame: sides
        mov  word ptr [sx0],136
        mov  word ptr [sy0],139
        mov  word ptr [sx1],136
        mov  word ptr [sy1],195
        call CLIPLINE
        jc   @@fs1
        call LINE
@@fs1:  mov  word ptr [sx0],192
        mov  word ptr [sy0],139
        mov  word ptr [sx1],192
        mov  word ptr [sy1],195
        call CLIPLINE
        jc   @@fs2
        call LINE
@@fs2:
        ; ---- pitch ladder: 7 roll-rotated rungs at every 10 degrees ----
        ; rung k (-3..3): angle = k*7 units; offset = (pitch - k*7)*2/3,
        ; sky rungs light blue, ground rungs dark, horizon long and white.
        mov  word ptr [tmpi],-3
@@lad:  mov  ax,[tmpi]
        mov  bx,7
        imul bx                 ; k*7 (10-degree steps in angle units)
        mov  bx,[pitch]
        sub  bx,ax
        mov  ax,bx
        add  ax,ax              ; *2
        mov  bx,3
        cwd
        idiv bx                 ; offset = (pitch-k*7)*2/3
        cmp  ax,26              ; outside the glass: skip the rung
        jg   @@ladn
        cmp  ax,-26
        jl   @@ladn
        mov  [dsx],ax
        mov  ax,[rsin]          ; rung centre = C + perp*offset
        imul word ptr [dsx]
        mov  bx,256
        idiv bx
        neg  ax
        add  ax,164
        mov  [dsy],ax           ; cx
        mov  ax,[rcos]
        imul word ptr [dsx]
        mov  bx,256
        idiv bx
        add  ax,167
        mov  [dsac],ax          ; cy
        mov  bx,9               ; short rung...
        cmp  word ptr [tmpi],0
        jne  @@len
        mov  bx,24              ; ...long horizon bar
@@len:  mov  ax,[rcos]
        imul bx
        push bx
        mov  bx,256
        idiv bx
        pop  bx
        mov  cx,ax              ; dx = rcos*len/256
        mov  ax,[rsin]
        imul bx
        mov  bx,256
        idiv bx                 ; dy = rsin*len/256
        mov  bx,[dsy]
        sub  bx,cx
        mov  [sx0],bx
        mov  bx,[dsac]
        sub  bx,ax
        mov  [sy0],bx
        mov  bx,[dsy]
        add  bx,cx
        mov  [sx1],bx
        mov  bx,[dsac]
        add  bx,ax
        mov  [sy1],bx
        mov  bl,8               ; horizon: white
        cmp  word ptr [tmpi],0
        je   @@col
        mov  bl,27              ; sky rungs: light blue
        jg   @@col
        mov  bl,28              ; ground rungs: dark earth
@@col:  mov  [COLOR],bl
        call CLIPLINE
        jc   @@ladn
        call LINE
@@ladn: inc  word ptr [tmpi]
        cmp  word ptr [tmpi],3
        jle  @@lad
        ; ---- fixed red aircraft symbol in the centre of the glass ----
        mov  ax,167
        call ROW320
        add  di,164
        mov  al,19
        mov  es:[di],al         ; nose dot
        mov  es:[di-320],al
        mov  cx,6               ; left and right wing bars
        push di
        sub  di,12
@@wngl: mov  es:[di],al
        inc  di
        loop @@wngl
        pop  di
        mov  cx,6
        add  di,7
@@wngr: mov  es:[di],al
        inc  di
        loop @@wngr
        ; ---- fixed pitch scale, left of the frame, with degree numbers ----
        mov  byte ptr [COLOR],30
        mov  word ptr [ftx],122
        mov  word ptr [fty],148
        mov  si,offset MSGD20   ; '20' above
        call FDRAW
        mov  word ptr [ftx],122
        mov  word ptr [fty],181
        mov  si,offset MSGD20   ; '20' below
        call FDRAW
        mov  word ptr [ftx],122
        mov  word ptr [fty],164
        mov  si,offset MSGD0    ; '0' at the horizon
        call FDRAW
        ; tick marks on the left frame every 10 degrees (offset step ~5px)
        mov  word ptr [sy0],167-19
        mov  word ptr [sy1],167-19
        call @@tick
        mov  word ptr [sy0],167-9
        mov  word ptr [sy1],167-9
        call @@tick
        mov  word ptr [sy0],167
        mov  word ptr [sy1],167
        call @@tick
        mov  word ptr [sy0],167+9
        mov  word ptr [sy1],167+9
        call @@tick
        mov  word ptr [sy0],167+19
        mov  word ptr [sy1],167+19
        call @@tick
        ; amber pitch bug riding the left frame: y = 167 + pitch*2/3
        mov  ax,[pitch]
        add  ax,ax
        mov  bx,3
        cwd
        idiv bx
        cmp  ax,26
        jle  @@pb1
        mov  ax,26
@@pb1:  cmp  ax,-26
        jge  @@pb2
        mov  ax,-26
@@pb2:  add  ax,167
        call ROW320
        add  di,133
        mov  al,5
        mov  es:[di],al
        mov  es:[di+1],al
        mov  es:[di+2],al
        mov  es:[di+320],al
        mov  es:[di+321],al
        mov  es:[di-320],al
        mov  es:[di-319],al
        ; ---- roll scale on top: ticks at 0/45/90, amber roll bug ----
        mov  ax,137
        call ROW320
        mov  al,30
        mov  byte ptr es:[di+138],al ; -90
        mov  byte ptr es:[di+151],al ; -45
        mov  al,8
        mov  byte ptr es:[di+164],al ; wings level
        mov  al,30
        mov  byte ptr es:[di+177],al ; +45
        mov  byte ptr es:[di+190],al ; +90
        mov  ax,[roll]          ; signed roll: >128 means negative
        cmp  ax,128
        jl   @@rs1
        sub  ax,256
@@rs1:  mov  bx,24
        imul bx
        mov  bx,64
        idiv bx                 ; -48..48 -> clamp to the scale
        cmp  ax,26
        jle  @@rs2
        mov  ax,26
@@rs2:  cmp  ax,-26
        jge  @@rs3
        mov  ax,-26
@@rs3:  add  ax,164
        mov  [dsx],ax           ; ROW320 clobbers BX: park x in memory
        mov  ax,136
        call ROW320
        add  di,[dsx]
        mov  al,5               ; amber roll bug (2x2)
        mov  es:[di],al
        mov  es:[di+1],al
        mov  es:[di+320],al
        mov  es:[di+321],al
        jmp  @@adidone
@@tick: mov  word ptr [sx0],131 ; small tick crossing the left frame
        mov  word ptr [sx1],136
        mov  byte ptr [COLOR],30
        call CLIPLINE
        jc   @@tk
        call LINE
@@tk:   ret
@@adidone:
        ; ================= tower: vertical LED bars ======================
        ; THR bar at x=218 (amber), FUEL bar at x=232 (blue/red). Twelve
        ; 4-row segments from y=192 upward, lit bottom-up.
        mov  ax,[throt]
        mov  bx,12
        imul bx
        mov  bx,64
        idiv bx                 ; lit segments 0..12
        mov  [lampx],ax
        mov  word ptr [lampy],218 ; bar x (reuse scratch)
        mov  bl,5
        call LEDBAR
        mov  ax,[fuel]
        xor  dx,dx
        mov  bx,500
        div  bx                 ; 0..12
        mov  [lampx],ax
        mov  word ptr [lampy],232
        mov  bl,14
        cmp  word ptr [fuel],1200
        jae  @@fb
        mov  bl,19
@@fb:   call LEDBAR
        ; bar captions
        mov  byte ptr [COLOR],30
        mov  word ptr [ftx],218
        mov  word ptr [fty],135
        mov  si,offset MSGT2
        call FDRAW
        mov  word ptr [ftx],232
        mov  word ptr [fty],135
        mov  si,offset MSGF2
        call FDRAW
        ret

; ---- LAMP: caution light at [lampx],[lampy]; SI=label, CX=lit colour (0=off)
;  27x10 box: dim frame, dark face when off, coloured when lit (blink fast
;  colours by the BIOS tick so a stall really shouts).
LAMP:   push cx
        mov  ax,[lampy]         ; top border
        call ROW320
        add  di,[lampx]
        mov  al,30
        mov  cx,27
        rep  stosb
        mov  ax,[lampy]
        add  ax,9
        call ROW320
        add  di,[lampx]
        mov  al,30
        mov  cx,27
        rep  stosb
        pop  cx
        ; face fill: off = near-black, on = CX colour (blinking)
        mov  al,3
        jcxz @@face
        push es                 ; blink: swap colour/dark at ~4.5 Hz
        mov  ax,40h
        mov  es,ax
        mov  ax,es:[6Ch]
        pop  es
        test ax,2
        jz   @@dark
        mov  ax,cx
        jmp  @@face
@@dark: mov  al,3
@@face: mov  [lampc],al
        mov  ax,[lampy]
        inc  ax
        call ROW320
        add  di,[lampx]
        mov  cx,8
@@lrow: push cx
        mov  al,[lampc]
        mov  cx,27
        rep  stosb
        add  di,320-27
        pop  cx
        loop @@lrow
        ; label text, centred-ish
        mov  ax,[lampx]
        add  ax,3
        mov  [ftx],ax
        mov  ax,[lampy]
        add  ax,2
        mov  [fty],ax
        mov  byte ptr [COLOR],8
        call FDRAW
        ret

; ---- LEDBAR: vertical 12-segment bar. [lampx]=lit count, [lampy]=x, BL=colour
LEDBAR: mov  [lampc],bl
        mov  word ptr [tmpi],0
@@seg:  mov  ax,192             ; segment k top row = 192 - k*5
        mov  bx,[tmpi]
        mov  cx,bx
        add  bx,bx
        add  bx,bx
        add  bx,cx              ; *5
        sub  ax,bx
        call ROW320
        add  di,[lampy]
        mov  al,30              ; unlit slot colour
        mov  bx,[tmpi]
        cmp  bx,[lampx]
        jae  @@dim
        mov  al,[lampc]
@@dim:  mov  cx,10              ; 10 wide x 4 tall
        push ax
        rep  stosb
        pop  ax
        add  di,320-10
        mov  cx,10
        push ax
        rep  stosb
        pop  ax
        add  di,320-10
        mov  cx,10
        push ax
        rep  stosb
        pop  ax
        add  di,320-10
        mov  cx,10
        rep  stosb
        inc  word ptr [tmpi]
        cmp  word ptr [tmpi],12
        jl   @@seg
        ret

; ============================================================================
;  FDRAW - draw an ASCIIZ string with the 4x6 CITY.DAT font into the back
;  buffer. in: SI -> string (DS), [ftx]/[fty] = position, COLOR = colour.
;  ES=bufseg. Advances ftx by 4 per glyph. Supports 0-9 A-Z + - : % . space.
; ============================================================================
FDRAW:  cld
@@ch:   lodsb
        test al,al
        jz   @@done
        cmp  al,' '
        je   @@adv
        cmp  al,'9'
        ja   @@alpha
        cmp  al,'0'
        jb   @@punct
        sub  al,'0'             ; digits -> glyph 0..9
        jmp  @@draw
@@alpha:
        cmp  al,'A'
        jb   @@punct
        cmp  al,'Z'
        ja   @@adv
        sub  al,'A'-10          ; letters -> glyph 10..35
        jmp  @@draw
@@punct:
        mov  ah,36              ; '+'
        cmp  al,'+'
        je   @@pg
        inc  ah                 ; '-'
        cmp  al,'-'
        je   @@pg
        inc  ah                 ; ':'
        cmp  al,':'
        je   @@pg
        inc  ah                 ; '%'
        cmp  al,'%'
        je   @@pg
        inc  ah                 ; '.'
        cmp  al,'.'
        je   @@pg
        jmp  @@adv              ; unknown: just advance
@@pg:   mov  al,ah
@@draw: push si
        xor  ah,ah              ; glyph base = FONTBUF + idx*6
        mov  bx,ax
        add  ax,ax
        add  ax,ax
        add  ax,bx
        add  ax,bx              ; *6
        mov  si,offset FONTBUF  ; offset strips the label type -> plain number
        add  si,ax
        mov  ax,[fty]           ; screen base = fty*320 + ftx
        call ROW320
        add  di,[ftx]
        mov  cx,6               ; six rows
@@row:  mov  al,[si]
        mov  ah,[COLOR]
        test al,80h
        jz   @@p1
        mov  es:[di],ah
@@p1:   test al,40h
        jz   @@p2
        mov  es:[di+1],ah
@@p2:   test al,20h
        jz   @@p3
        mov  es:[di+2],ah
@@p3:   inc  si
        add  di,320
        loop @@row
        pop  si
@@adv:  add  word ptr [ftx],4
        jmp  @@ch
@@done: ret

; FNUM - draw AX as an unsigned decimal with FDRAW at [ftx]/[fty].
FNUM:   mov  di,offset NB+5
        mov  byte ptr [di],0
        mov  bx,10
@@d:    xor  dx,dx
        div  bx
        add  dl,'0'
        dec  di
        mov  [di],dl
        test ax,ax
        jnz  @@d
        mov  si,di
        call FDRAW
        ret

; ============================================================================
;  PANELBMP - the photo cockpit (CITY.DAT resource 2) over the rendered
;  world, instruments placed by the res\panel2.bmp markup (run
;  res\mkpanel.py to reprint the zones after moving them):
;    radar 51..123 x 153..188      ADI 136..183 x 155..187 (centre 160,171)
;    map 195..239 x 153..188       readouts 241..272 x 156..188
;    title strip 96..223 x 0..9    AB strip 141..176 x 14..20
;    lamps: FUEL 3,2 13x8  STALL 7,107 10x10  TERR 19,123 10x10
;    throttle ladder 43..49 x 162..187.  ES=bufseg, DS=CS.
; ============================================================================
PANELBMP:
        cld
        mov  si,offset PSPAN
@@sp:   mov  ax,[si]            ; span start (0FFFFh = end of table)
        cmp  ax,0FFFFh
        je   @@spd
        mov  cx,[si+2]          ; span length
        mov  di,ax              ; dest = same offset in the back buffer
        add  ax,[pimgo]
        push si
        push ds
        mov  si,ax
        mov  ax,[resseg]
        mov  ds,ax              ; DS:SI = pixels inside CITY.DAT image
        rep  movsb
        pop  ds
        pop  si
        add  si,4
        jmp  @@sp
@@spd:
        cmp  byte ptr [mfdmode],0
        je   @@mmap
        cmp  word ptr [locki],0FFFFh
        jne  @@tcam
@@mmap: call MINIMAP2           ; half-scale map on the green MFD
        jmp  @@mfdd
@@tcam: call TGTVIEW            ; sensor view of the locked target
@@mfdd:
        ; ---- title strip: name, mission time, altitude ----
        mov  byte ptr [COLOR],8
        mov  word ptr [ftx],100
        mov  word ptr [fty],2
        mov  si,offset MSGTITLE
        call FDRAW
        mov  byte ptr [COLOR],5
        mov  word ptr [ftx],146
        mov  si,offset MSGT2
        call FDRAW
        mov  byte ptr [COLOR],8
        mov  word ptr [ftx],154
        mov  ax,[lasttk]        ; BIOS ticks -> seconds
        xor  dx,dx
        mov  bx,18
        div  bx
        call FNUM
        mov  byte ptr [COLOR],5
        mov  word ptr [ftx],178
        mov  si,offset MSGALT
        call FDRAW
        mov  byte ptr [COLOR],8
        mov  ax,[camy]
        call FNUM
        ; ---- afterburner strip ----
        cmp  byte ptr [abon],0
        je   @@ab
        mov  byte ptr [COLOR],5
        mov  word ptr [ftx],149
        mov  word ptr [fty],15
        mov  si,offset MSGABON
        call FDRAW
@@ab:
        ; ---- caution lights: FUEL (top left), STALL and TERR (left strut)
        mov  word ptr [lampx],3
        mov  word ptr [lampy],2
        mov  word ptr [dsx],13
        mov  word ptr [dsy],8
        xor  cx,cx
        cmp  word ptr [fuel],1200
        jge  @@lf
        mov  cx,19              ; low fuel: red
@@lf:   mov  si,offset MSGF2
        call LAMP2
        mov  word ptr [lampx],7
        mov  word ptr [lampy],107
        mov  word ptr [dsx],10
        mov  word ptr [dsy],10
        xor  cx,cx
        mov  ax,[vel]
        cmp  ax,VSTALL
        jge  @@ls
        mov  cx,19              ; stall: red
@@ls:   mov  si,offset MSGS2
        call LAMP2
        mov  word ptr [lampx],19
        mov  word ptr [lampy],123
        mov  word ptr [dsx],10
        mov  word ptr [dsy],10
        xor  cx,cx
        mov  ax,[camy]
        sub  ax,[lgnd]
        cmp  ax,150
        jge  @@lt
        mov  cx,5               ; terrain close: amber
@@lt:   mov  si,offset MSGT2
        call LAMP2
        mov  word ptr [lampx],289 ; lock lamp: top right strut square
        mov  word ptr [lampy],1
        mov  word ptr [dsx],10
        mov  word ptr [dsy],9
        xor  cx,cx
        mov  ax,[locki]
        cmp  ax,0FFFFh
        je   @@llk
        mov  cx,95              ; friendly under lock: green warning
        test ax,2
        jz   @@llk
        mov  cx,19              ; hostile locked: red
@@llk:  mov  si,offset MSGL2
        call LAMP2
        ; ---- throttle ladder: 12 segments up from y=186 at x=44 ----
        mov  ax,[throt]
        mov  bx,3
        imul bx
        mov  cl,4
        shr  ax,cl              ; lit segments = throt*3/16 (0..12)
        mov  dx,ax
        mov  word ptr [dsx],186 ; current segment row
        xor  si,si              ; segment index
@@tb:   cmp  si,12
        jae  @@tbd
        cmp  si,dx
        jae  @@tbd              ; above the setting: the artwork shows through
        mov  ax,[dsx]
        call ROW320
        add  di,44
        mov  al,5               ; lit amber segment
        mov  cx,5
        rep  stosb
        sub  word ptr [dsx],2
        inc  si
        jmp  @@tb
@@tbd:
        ; ---- radar: heading-up PPI, centre (87,171), 1 px = 512 world
        ; units (~7.7k range). Own ship = 2 px tick, traffic = 2x1 blips.
        mov  ax,172
        call ROW320
        add  di,87
        mov  al,8
        mov  es:[di],al
        mov  es:[di-320],al
        xor  si,si
@@rdr:  mov  bx,si              ; the dead do not paint on the radar
        shr  bx,1
        cmp  byte ptr [pst+bx],0
        jne  @@rn
        mov  ax,[pax+si]
        sub  ax,[camx]
        mov  [wdx],ax
        mov  ax,[paz+si]
        sub  ax,[camz]
        mov  [wdz],ax
        push si
        call ROTXZ              ; rcx = right of the nose, rcz = ahead
        pop  si
        mov  ax,[rcx]
        cmp  ax,7680
        jge  @@rn
        cmp  ax,-7680
        jle  @@rn
        mov  bx,[rcz]
        cmp  bx,7680
        jge  @@rn
        cmp  bx,-7680
        jle  @@rn
        mov  cl,9
        sar  ax,cl              ; -15..15 px
        sar  bx,cl
        add  ax,87
        mov  [dsx],ax           ; blip column
        mov  ax,171
        sub  ax,bx              ; ahead = up the screen
        call ROW320
        add  di,[dsx]
        mov  al,95              ; friendly: green
        test si,2
        jz   @@fr
        mov  al,96              ; hostile: yellow
@@fr:   mov  es:[di],al
        mov  es:[di+1],al
        mov  bx,[pay+si]        ; altitude tick: above = higher, below =
        sub  bx,[camy]          ; lower than us (dead band +-200)
        cmp  bx,200
        jle  @@ral
        mov  es:[di-320],al
        jmp  @@rn
@@ral:  cmp  bx,-200
        jge  @@rn
        mov  es:[di+320],al
@@rn:   add  si,2
        cmp  si,NPLANE*2
        jb   @@rdr
        ; missiles on the scope: amber sparks (player's and the AI's)
        cmp  byte ptr [msact],0
        je   @@rms
        mov  ax,[msx]
        sub  ax,[camx]
        mov  [wdx],ax
        mov  ax,[msz]
        sub  ax,[camz]
        mov  [wdz],ax
        call @@rblip
@@rms:  xor  si,si
@@rml:  mov  bx,si
        cmp  byte ptr [amact+bx],0
        je   @@rmn
        add  bx,bx
        mov  ax,[amx+bx]
        sub  ax,[camx]
        mov  [wdx],ax
        mov  ax,[amz+bx]
        sub  ax,[camz]
        mov  [wdz],ax
        push si
        call @@rblip
        pop  si
@@rmn:  inc  si
        cmp  si,NAMSL
        jb   @@rml
        jmp  @@rsc
@@rblip:                        ; plot one amber spark from wdx/wdz
        call ROTXZ
        mov  ax,[rcx]
        cmp  ax,7680
        jge  @@rbx
        cmp  ax,-7680
        jle  @@rbx
        mov  bx,[rcz]
        cmp  bx,7680
        jge  @@rbx
        cmp  bx,-7680
        jle  @@rbx
        mov  cl,9
        sar  ax,cl
        sar  bx,cl
        add  ax,87
        mov  [dsx],ax
        mov  ax,171
        sub  ax,bx
        call ROW320
        add  di,[dsx]
        mov  al,5
        mov  es:[di],al
@@rbx:  ret
@@rsc:  ; scoreboard on the scope: green team, yellow team, own kills
        mov  byte ptr [COLOR],95
        mov  word ptr [ftx],53
        mov  word ptr [fty],155
        mov  ax,[tscf]
        call FNUM
        mov  byte ptr [COLOR],96
        mov  word ptr [ftx],110
        mov  word ptr [fty],155
        mov  ax,[tsch]
        call FNUM
        mov  byte ptr [COLOR],8
        mov  word ptr [ftx],106
        mov  word ptr [fty],182
        mov  ax,[psc]
        call FNUM
        mov  byte ptr [COLOR],19 ; damage taken, red, top centre
        mov  word ptr [ftx],84
        mov  word ptr [fty],155
        mov  al,[pdam]
        xor  ah,ah
        call FNUM
        mov  byte ptr [COLOR],5 ; cannon rounds, amber
        mov  word ptr [ftx],92
        mov  word ptr [fty],182
        mov  ax,[gunam]
        call FNUM
        ; missile pips along the radar's bottom edge
        xor  si,si
@@amo:  mov  ax,si
        cmp  al,[pammo]
        jae  @@amn
        mov  ax,184
        call ROW320
        add  di,55
        mov  ax,si
        add  ax,ax
        add  ax,ax
        add  ax,ax              ; k*8
        add  di,ax
        mov  al,5
        mov  es:[di],al
        mov  es:[di+1],al
        mov  es:[di+2],al
        mov  es:[di+3],al
        mov  es:[di+320],al
        mov  es:[di+321],al
        mov  es:[di+322],al
        mov  es:[di+323],al
@@amn:  inc  si
        cmp  si,4
        jb   @@amo
        ; ---- readouts right of the map: S/T/F/H rows ----
        mov  byte ptr [COLOR],5
        mov  word ptr [ftx],242
        mov  word ptr [fty],157
        mov  si,offset MSGSPD2
        call FDRAW
        mov  byte ptr [COLOR],8
        mov  word ptr [ftx],256
        mov  ax,[vel]
        call FNUM
        mov  byte ptr [COLOR],5
        mov  word ptr [ftx],242
        mov  word ptr [fty],165
        mov  si,offset MSGTHR2
        call FDRAW
        mov  byte ptr [COLOR],8
        mov  word ptr [ftx],256
        mov  ax,[throt]
        mov  bx,100
        imul bx
        mov  bx,64
        idiv bx
        call FNUM
        cmp  byte ptr [abon],0
        je   @@nab
        mov  byte ptr [COLOR],5
        mov  si,offset MSGAB    ; '+' right after the percentage
        call FDRAW
@@nab:  mov  byte ptr [COLOR],5
        cmp  word ptr [fuel],1200
        jge  @@fok
        mov  byte ptr [COLOR],19
@@fok:  mov  word ptr [ftx],242
        mov  word ptr [fty],173
        mov  si,offset MSGFUE2
        call FDRAW
        mov  word ptr [ftx],260
        mov  byte ptr [COLOR],8
        cmp  word ptr [fuel],1200
        jge  @@fv
        mov  byte ptr [COLOR],19
@@fv:   mov  ax,[fuel]
        xor  dx,dx
        mov  bx,60
        div  bx
        call FNUM
        mov  byte ptr [COLOR],5
        mov  word ptr [ftx],242
        mov  word ptr [fty],181
        mov  si,offset MSGHDG2
        call FDRAW
        mov  byte ptr [COLOR],8
        mov  word ptr [ftx],256
        mov  ax,[heading]
        call FNUM
        ; ---- compact ADI on the blue MFD: roll-rotated pitch ladder ----
        ; rung k = -2..2 at 10-degree steps; offset = (pitch-k*7)/2, +-13.
        mov  word ptr [tmpi],-2
@@cl:   mov  ax,[tmpi]
        mov  bx,7
        imul bx
        mov  bx,[pitch]
        sub  bx,ax
        mov  ax,bx
        cwd
        mov  bx,2
        idiv bx
        cmp  ax,13
        jg   @@cn
        cmp  ax,-13
        jl   @@cn
        mov  [dsx],ax
        mov  ax,[rsin]          ; rung centre = C + perp*offset
        imul word ptr [dsx]
        mov  bx,256
        idiv bx
        neg  ax
        add  ax,160
        mov  [dsy],ax
        mov  ax,[rcos]
        imul word ptr [dsx]
        mov  bx,256
        idiv bx
        add  ax,171
        mov  [dsac],ax
        mov  bx,6               ; short rung...
        cmp  word ptr [tmpi],0
        jne  @@cln
        mov  bx,[rsin]          ; ...horizon: 20 - |rsin|/16 stays on
        test bx,bx              ; the glass at any bank angle
        jns  @@cp
        neg  bx
@@cp:   mov  cl,4
        shr  bx,cl
        neg  bx
        add  bx,20
@@cln:  mov  ax,[rcos]
        imul bx
        push bx
        mov  bx,256
        idiv bx
        pop  bx
        mov  cx,ax              ; dx = rcos*len/256
        mov  ax,[rsin]
        imul bx
        mov  bx,256
        idiv bx                 ; dy = rsin*len/256
        mov  bx,[dsy]
        sub  bx,cx
        mov  [sx0],bx
        mov  bx,[dsac]
        sub  bx,ax
        mov  [sy0],bx
        mov  bx,[dsy]
        add  bx,cx
        mov  [sx1],bx
        mov  bx,[dsac]
        add  bx,ax
        mov  [sy1],bx
        mov  bl,8               ; horizon: white
        cmp  word ptr [tmpi],0
        je   @@cc
        mov  bl,27              ; sky rungs: light blue
        jg   @@cc
        mov  bl,28              ; ground rungs: dark earth
@@cc:   mov  [COLOR],bl
        call CLIPLINE
        jc   @@cn
        call LINE
@@cn:   inc  word ptr [tmpi]
        cmp  word ptr [tmpi],2
        jle  @@cl
        ; fixed red wings in the middle of the glass
        mov  ax,171
        call ROW320
        add  di,160
        mov  al,19
        mov  es:[di],al         ; nose dot
        push di
        sub  di,8
        mov  cx,4
@@wl:   mov  es:[di],al
        inc  di
        loop @@wl
        pop  di
        add  di,5
        mov  cx,4
@@wr:   mov  es:[di],al
        inc  di
        loop @@wr
        ret

; ============================================================================
;  LAMP2 - caution light as a bare blinking letter. in: [lampx]/[lampy] =
;  zone top-left, [dsx]/[dsy] = zone size (the letter is centred in it),
;  CX = colour (0 = off, draws nothing), SI -> one-letter label. The
;  artwork provides the socket; the game only lights the glyph up.
; ============================================================================
LAMP2:  jcxz @@no
        mov  ax,[lasttk]
        test ax,2               ; blink: dark phase shows the artwork
        jz   @@no
        mov  [dsac],cx
        mov  ax,[lampx]         ; centre the letter in the zone
        mov  bx,[dsx]
        sub  bx,4
        shr  bx,1
        add  ax,bx
        mov  [ftx],ax
        mov  ax,[lampy]
        mov  bx,[dsy]
        sub  bx,6
        shr  bx,1
        add  ax,bx
        mov  [fty],ax
        mov  ax,[dsac]
        mov  [COLOR],al
        call FDRAW
@@no:   ret

; ============================================================================
;  HUD tapes (F-15 style, projected on the glass). Compass on top, speed
;  tape left, altitude right - all white, classic; critical marks in red
;  (stall speed, the terrain below us, the ceiling). Two layouts: the F2
;  view uses the full screen, the cockpit tucks the tapes and numbers
;  inside the windshield (ticks flip to the glass side of the spine).
; ============================================================================
; VLINE2 - vertical line: AX=y0, [dsx]=x, CX=len, BL=colour
VLINE2: push bx                 ; ROW320 clobbers BX (the colour!)
        call ROW320
        pop  bx
        add  di,[dsx]
        mov  al,bl
@@v:    mov  es:[di],al
        add  di,320
        loop @@v
        ret
; HLINE2 - horizontal line: AX=y, [dsx]=x, CX=len, BL=colour
HLINE2: push bx                 ; ROW320 clobbers BX (the colour!)
        call ROW320
        pop  bx
        add  di,[dsx]
        mov  al,bl
        rep  stosb
        ret
; FNUM3 - AX (0..999) as three padded digits at ftx/fty
FNUM3:  xor  dx,dx
        mov  bx,100
        div  bx
        add  al,'0'
        mov  [NB],al
        mov  ax,dx
        xor  dx,dx
        mov  bx,10
        div  bx
        add  al,'0'
        mov  [NB+1],al
        add  dl,'0'
        mov  [NB+2],dl
        mov  byte ptr [NB+3],0
        mov  si,offset NB
        call FDRAW
        ret

HUDBARS:
        cmp  byte ptr [chsview],0
        jne  @@hboff
        cmp  byte ptr [dying],0
        je   @@hbon
@@hboff:
        ret                     ; tapes live on the glass, not in the sky
@@hbon: cld
        ; ---- pick the layout ----
        cmp  byte ptr [cockpit],0
        je   @@f2l
        mov  word ptr [hbsx],84   ; cockpit: inside the windshield
        mov  word ptr [hbslb],94
        mov  word ptr [hbst1],85  ; ticks grow INTO the glass
        mov  word ptr [hbst2],85
        mov  word ptr [hbcx],85
        mov  word ptr [hbax],236
        mov  word ptr [hbalb],206
        mov  word ptr [hbat1],230
        mov  word ptr [hbat2],232
        mov  word ptr [hbacx],227
        jmp  @@lay
@@f2l:  mov  word ptr [hbsx],68   ; F2: the full pane
        mov  word ptr [hbslb],38
        mov  word ptr [hbst1],62
        mov  word ptr [hbst2],64
        mov  word ptr [hbcx],59
        mov  word ptr [hbax],252
        mov  word ptr [hbalb],263
        mov  word ptr [hbat1],253
        mov  word ptr [hbat2],253
        mov  word ptr [hbacx],253
@@lay:
        ; ================= compass tape: top centre =================
        mov  ax,[heading]
        add  ax,219             ; heading-40, +3 to round, +256 bias
        and  ax,0FFFCh          ; first tick: multiple of 4
        mov  [ctx],ax
@@cp:   mov  ax,[ctx]
        sub  ax,256
        sub  ax,[heading]       ; signed offset from the nose
        cmp  ax,40
        jg   @@cpd
        mov  bx,ax              ; x = 160 + off*3/2
        add  ax,ax
        add  ax,bx
        sar  ax,1
        add  ax,160
        mov  [dsx],ax
        cmp  ax,102
        jl   @@cpn
        cmp  ax,218
        jg   @@cpn
        mov  ax,[ctx]
        and  ax,31              ; every 32 units = 45 degrees: major
        jnz  @@cmin
        mov  ax,18
        mov  cx,2
        mov  bl,8
        call VLINE2
        mov  ax,[ctx]
        and  ax,255
        mov  bx,45
        imul bx
        mov  cl,5
        shr  ax,cl              ; degrees = units*45/32
        mov  bx,[dsx]
        sub  bx,6
        mov  [ftx],bx
        mov  word ptr [fty],27
        mov  byte ptr [COLOR],8
        call FNUM3
        jmp  @@cpn
@@cmin: mov  ax,18
        mov  cx,1
        mov  bl,8
        call VLINE2
@@cpn:  add  word ptr [ctx],4
        jmp  @@cp
@@cpd:  mov  ax,36              ; the caret under the tape
        call ROW320
        add  di,160
        mov  al,8
        mov  es:[di],al
        mov  es:[di-321],al
        mov  es:[di-319],al

        ; ================= speed tape: left =================
        mov  ax,60              ; the spine
        mov  bx,[hbsx]
        mov  [dsx],bx
        mov  cx,71
        mov  bl,8
        call VLINE2
        mov  ax,[vel]           ; first tick: multiple of 25 >= vel-140
        sub  ax,140
        jns  @@s0
        xor  ax,ax
@@s0:   add  ax,24
        xor  dx,dx
        mov  bx,25
        div  bx
        mul  bx
        mov  [ctx],ax
@@sp:   mov  ax,[ctx]
        sub  ax,[vel]
        cmp  ax,140
        jg   @@spd
        mov  [dsac],ax          ; keep the offset (label crowding test)
        sar  ax,1
        sar  ax,1
        mov  bx,95
        sub  bx,ax
        mov  [cty],bx           ; y
        cmp  bx,60
        jl   @@spn
        cmp  bx,130
        jg   @@spn
        mov  ax,[ctx]
        xor  dx,dx
        mov  bx,100
        div  bx
        test dx,dx
        jnz  @@smin
        mov  ax,[cty]           ; major: a touch longer (it carries the
        mov  bx,[hbst1]         ; number), still flush at the spine
        mov  [dsx],bx
        mov  cx,6
        mov  bl,8
        call HLINE2
        mov  ax,[dsac]          ; the centre shows the live value
        cmp  ax,25
        jg   @@slb
        cmp  ax,-25
        jge  @@spn
@@slb:  mov  ax,[cty]
        sub  ax,2
        mov  [fty],ax
        mov  ax,[hbslb]
        mov  [ftx],ax
        mov  byte ptr [COLOR],8
        mov  ax,[ctx]
        call FNUM
        jmp  @@spn
@@smin: mov  ax,[cty]           ; minor: same anchor, shorter
        mov  bx,[hbst2]
        mov  [dsx],bx
        mov  cx,4
        mov  bl,8
        call HLINE2
@@spn:  add  word ptr [ctx],25
        jmp  @@sp
@@spd:  mov  ax,VSTALL          ; the stall line, red
        sub  ax,[vel]
        cmp  ax,140
        jg   @@snc
        cmp  ax,-140
        jl   @@snc
        sar  ax,1
        sar  ax,1
        mov  bx,95
        sub  bx,ax
        cmp  bx,60
        jl   @@snc
        cmp  bx,130
        jg   @@snc
        mov  ax,bx
        mov  bx,[hbcx]
        mov  [dsx],bx
        mov  cx,9
        mov  bl,19
        call HLINE2
@@snc:  mov  ax,95              ; caret + live speed (white, classic)
        call ROW320
        add  di,[hbsx]
        inc  di
        mov  al,8
        mov  es:[di],al
        mov  es:[di+1-320],al
        mov  es:[di+1+320],al
        mov  ax,[hbslb]
        mov  [ftx],ax
        mov  word ptr [fty],92
        mov  byte ptr [COLOR],8
        mov  ax,[vel]
        call FNUM

        ; ================= altitude tape: right =================
        mov  ax,60              ; the spine
        mov  bx,[hbax]
        mov  [dsx],bx
        mov  cx,71
        mov  bl,8
        call VLINE2
        mov  ax,[camy]          ; first tick: multiple of 50 >= camy-280
        sub  ax,280
        jns  @@a0
        xor  ax,ax
@@a0:   add  ax,49
        xor  dx,dx
        mov  bx,50
        div  bx
        mul  bx
        mov  [ctx],ax
@@ap:   mov  ax,[ctx]
        sub  ax,[camy]
        cmp  ax,280
        jg   @@apd
        mov  [dsac],ax
        sar  ax,1
        sar  ax,1
        sar  ax,1
        mov  bx,95
        sub  bx,ax
        mov  [cty],bx
        cmp  bx,60
        jl   @@apn
        cmp  bx,130
        jg   @@apn
        mov  ax,[ctx]
        xor  dx,dx
        mov  bx,500
        div  bx
        test dx,dx
        jnz  @@amin
        mov  ax,[cty]           ; major divider (a touch longer)
        mov  bx,[hbat1]
        mov  [dsx],bx
        mov  cx,6
        mov  bl,8
        call HLINE2
        mov  ax,[dsac]
        cmp  ax,70
        jg   @@alb
        cmp  ax,-70
        jge  @@apn
@@alb:  mov  ax,[cty]
        sub  ax,2
        mov  [fty],ax
        mov  ax,[hbalb]
        mov  [ftx],ax
        mov  byte ptr [COLOR],8
        mov  ax,[ctx]
        call FNUM
        jmp  @@apn
@@amin: mov  ax,[cty]           ; minor divider
        mov  bx,[hbat2]
        mov  [dsx],bx
        mov  cx,4
        mov  bl,8
        call HLINE2
@@apn:  add  word ptr [ctx],50
        jmp  @@ap
@@apd:  mov  ax,[lgnd]          ; the ground below us, red on the tape
        sub  ax,[camy]
        cmp  ax,280
        jg   @@anc
        cmp  ax,-280
        jl   @@anc
        sar  ax,1
        sar  ax,1
        sar  ax,1
        mov  bx,95
        sub  bx,ax
        cmp  bx,60
        jl   @@anc
        cmp  bx,130
        jg   @@anc
        mov  ax,bx
        mov  bx,[hbacx]
        mov  [dsx],bx
        mov  cx,9
        mov  bl,19
        call HLINE2
@@anc:  mov  ax,CEIL            ; the service ceiling, red too
        sub  ax,[camy]
        cmp  ax,280
        jg   @@anc2
        sar  ax,1
        sar  ax,1
        sar  ax,1
        mov  bx,95
        sub  bx,ax
        cmp  bx,60
        jl   @@anc2
        mov  ax,bx
        mov  bx,[hbacx]
        mov  [dsx],bx
        mov  cx,9
        mov  bl,19
        call HLINE2
@@anc2: mov  ax,95              ; caret + live altitude (white)
        call ROW320
        add  di,[hbax]
        sub  di,2
        mov  al,8
        mov  es:[di],al
        mov  es:[di-1-320],al
        mov  es:[di-1+320],al
        mov  ax,[hbalb]
        mov  [ftx],ax
        mov  word ptr [fty],92
        mov  byte ptr [COLOR],8
        mov  ax,[camy]
        call FNUM
        ret
