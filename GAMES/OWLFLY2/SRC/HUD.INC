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
        je   @@nopanel          ; no CITY.DAT bitmap: fly without a panel
        jmp  PANELBMP           ; the photo cockpit does everything
@@nopanel:
        ret
; (the old drawn three-tier console, its LAMP boxes and LED bars were
;  removed 2026-07-09: the photo cockpit ships in CITY.DAT and the 64K
;  segment needs every byte)

; ============================================================================
;  LADR - the pitch ladder, riding the WORLD (the NEWTON rule, retuned
;  for this projection). Rungs every 10 degrees (7 angle units), placed
;  by TRUE tangent - tan(a)*FOCAL - so the ladder measures the same sky
;  the terrain is projected into (NEWTON's 5.4 px/deg was linear
;  because ITS horizon was; ours is pofs = tan*220, so the rungs obey
;  the same law). Solid above the horizon, dotted below; a centre gap
;  keeps the gunsight clean. The pilot's rule, hard-won in NEWTON:
;  while the REAL horizon crosses the window the rails stay OUT of it -
;  they light up just before it slips away (|f| > 92 px) and then they
;  follow the NOSE, not the long-gone horizon. ES = back buffer;
;  hcur/cx0/sinr/cosr are the frame's horizon pivot from CLEARBUF.
; ============================================================================
LADR:   mov  ax,100
        sub  ax,[hcur]
        imul word ptr [cosr]
        mov  cx,256
        idiv cx
        mov  [lfc],ax           ; f of the screen centre
        or   ax,ax
        jns  @@fc1
        neg  ax
@@fc1:  cmp  ax,92
        jg   @@arm
        ret                     ; the horizon is on the glass: no rails
@@arm:  mov  ax,[lfc]           ; the rung nearest the nose:
        cwd                     ; tan(10 deg)*220 = 38.8 px per rung
        mov  cx,38
        idiv cx
        neg  ax
        dec  ax                 ; four rungs, k0-1 .. k0+2
        mov  [lp],ax
        add  ax,3
        mov  [lke],ax
@@l:    cmp  word ptr [lp],0
        je   @@next             ; zero belongs to the horizon, not us
        cmp  word ptr [lp],-8
        jl   @@next
        cmp  word ptr [lp],8
        jg   @@next
        mov  ax,[lp]            ; a = k*7 units = k*10 degrees
        mov  cx,7
        imul cx
        push ax
        call SINQ
        mov  [lsn],ax           ; sin(a)*256
        pop  ax
        add  ax,64
        call SINQ               ; cos(a)*256
        mov  cx,ax
        mov  ax,[lsn]
        mov  bx,220
        imul bx
        idiv cx                 ; tan(a)*FOCAL, exact
        neg  ax
        mov  bx,ax              ; f: up the sky is negative rows
        xor  ax,ax
        call LROT               ; the rung's centre sits at t = 0
        mov  [lcx],ax
        mov  [lcy],dx
        cmp  dx,-60
        jl   @@next             ; the whole line is off the glass
        cmp  dx,260
        jg   @@next
        mov  ax,[cosr]          ; walk out along the HORIZON direction,
        mov  cx,-60             ; 8.8, starting 60 px to one side
        imul cx
        mov  [lx8],ax
        mov  ax,[sinr]
        mov  cx,-60
        imul cx
        mov  [ly8],ax
        mov  word ptr [li],0
@@pt:   mov  ax,[li]            ; 0..119: the centre gap is 44..76
        cmp  ax,44
        jb   @@vis
        cmp  ax,76
        jb   @@skip
@@vis:  cmp  word ptr [lp],0    ; below the horizon: dotted
        jg   @@draw
        test word ptr [li],1
        jnz  @@skip
@@draw: mov  ax,[lx8]
        mov  cl,8
        sar  ax,cl
        add  ax,[lcx]
        js   @@skip
        cmp  ax,319
        jg   @@skip
        mov  [lpx],ax
        mov  ax,[ly8]
        mov  cl,8
        sar  ax,cl
        add  ax,[lcy]
        js   @@skip
        cmp  ax,199
        jg   @@skip
        call ROW320
        add  di,[lpx]
        mov  byte ptr es:[di],LDIM
@@skip: mov  ax,[cosr]          ; one pixel further along the line
        add  [lx8],ax
        mov  ax,[sinr]
        add  [ly8],ax
        inc  word ptr [li]
        cmp  word ptr [li],120
        jb   @@pt
        mov  ax,[lp]            ; the label, upright at the left end -
        or   ax,ax              ; a 4x6 font has no rotation, and the
        jg   @@l5               ; era's HUDs did not turn their numbers
        neg  ax
        mov  byte ptr [LBUF],'-'
        jmp  @@l6
@@l5:   mov  byte ptr [LBUF],' '
@@l6:   add  al,'0'
        mov  [LBUF+1],al
        mov  byte ptr [LBUF+2],'0'
        mov  ax,[cosr]
        mov  cx,-76
        imul cx
        mov  cl,8
        sar  ax,cl
        add  ax,[lcx]
        js   @@next
        cmp  ax,300
        jg   @@next
        mov  [ftx],ax
        mov  ax,[sinr]
        mov  cx,-76
        imul cx
        mov  cl,8
        sar  ax,cl
        add  ax,[lcy]
        sub  ax,2
        js   @@next
        cmp  ax,193
        jg   @@next
        mov  [fty],ax
        mov  byte ptr [COLOR],LDIM
        mov  si,offset LBUF
        call FDRAW
@@next: inc  word ptr [lp]
        mov  ax,[lp]
        cmp  ax,[lke]
        jle  @@l
        ret

; ---- LROT: horizon-frame (AX=t, BX=f) -> screen (AX=x, DX=y) ---------------
; The sky segment has this same rotate as ROTPT, but a near CALL cannot
; cross segments; thirty bytes can. Clobbers DI.
LROT:   push bx
        push si
        mov  si,ax
        imul word ptr [cosr]
        mov  cx,256
        idiv cx
        mov  di,ax
        mov  ax,bx
        imul word ptr [sinr]
        mov  cx,256
        idiv cx
        sub  di,ax              ; x = cx0 + (t*cos - f*sin)/256
        add  di,[cx0]
        mov  ax,si
        imul word ptr [sinr]
        mov  cx,256
        idiv cx
        mov  si,ax
        mov  ax,bx
        imul word ptr [cosr]
        mov  cx,256
        idiv cx
        add  ax,si              ; y = hcur + (t*sin + f*cos)/256
        add  ax,[hcur]
        mov  dx,ax
        mov  ax,di
        pop  si
        pop  bx
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
        ; the SA redesign: the ADI is gone - the HUD ladder already
        ; said everything it said. The CENTRE MFD pages through
        ; MAP / SIT / TGT on the M key (the F-15 SE II swapped its
        ; MFD the same way); the RIGHT one is pure status.
        mov  al,[mfdmode]
        cmp  al,1
        je   @@psit
        cmp  al,2
        je   @@ptgt
        call FAR PTR MINIMAP2F  ; north-up MAP on the centre MFD
        call FAR PTR MAPHUMF    ; the humans on it: letter + altitude
        jmp  @@pgd
@@psit: call SITPG              ; heading-up close-zoom labeled radar
        jmp  @@pgd
@@ptgt: call FAR PTR TGTVIEWF   ; the locked target's data page
@@pgd:  call FAR PTR STATPGF    ; the right MFD: score and arms
        ; ---- title strip: name, mission time, altitude ----
        mov  byte ptr [COLOR],8
        mov  word ptr [ftx],100
        mov  word ptr [fty],2
        mov  si,offset MSGTITLE
        call FDRAW
        mov  byte ptr [COLOR],97
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
        mov  byte ptr [COLOR],97
        mov  word ptr [ftx],178
        mov  si,offset MSGALT
        call FDRAW
        mov  byte ptr [COLOR],8
        mov  ax,[camy]
        call FNUM
        cmp  byte ptr [mslcam],0 ; missile camera armed: amber M
        je   @@nm5
        mov  byte ptr [COLOR],97
        mov  word ptr [ftx],216
        mov  word ptr [fty],2
        mov  si,offset MSGM2
        call FDRAW
@@nm5:
        cmp  byte ptr [sbok],0  ; sound-mode letter: amber = all sounds,
        je   @@ns5              ; white = effects only, red = silence
        mov  byte ptr [COLOR],97
        mov  al,[sndmod]
        cmp  al,2
        je   @@sc5
        mov  byte ptr [COLOR],8
        cmp  al,1
        je   @@sc5
        mov  byte ptr [COLOR],19
@@sc5:  mov  word ptr [ftx],226
        mov  word ptr [fty],2
        mov  si,offset MSGS3
        call FDRAW
@@ns5:
        ; ---- afterburner strip ----
        cmp  byte ptr [abon],0
        je   @@ab
        mov  byte ptr [COLOR],97
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
        mov  cx,97              ; terrain close: amber
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
        mov  al,97              ; lit amber segment
        mov  cx,5
        rep  stosb
        sub  word ptr [dsx],2
        inc  si
        jmp  @@tb
@@tbd:
        ; ---- radar: heading-up PPI, centre (87,171). The scale is a
        ; LIVE zoom: 1 px = 256/512/1024 world units (Z in, X out, the
        ; manual's keys). Own ship = 2 px tick, traffic = shaped blips,
        ; HUMANS wear white. A compass-true grey grid marches under it
        ; all: dots every 4096 world units, plus two dots up the NORTH
        ; radius - the scope stays tied to the rose at any bank of the
        ; mind.
        ; -- the grid first, under everything (far code: the scope's
        ; grey rose lives in the sky segment, the stack guard's rent) --
        call FAR PTR RGRIDF
        mov  word ptr [rbcx],87 ; the scope frame: centre + live zoom
        mov  word ptr [rbcy],171
        mov  al,[rzsh]
        mov  [rbsh],al
        call RBLIPS
        jmp  RDOUT              ; the readouts, past the blip engine

; ============================================================================
;  RBLIPS - the blip engine: own-ship tick, traffic blips (allegiance
;  shape + velocity stub + callsign letter), missile sparks - on ANY
;  heading-up scope. in: [rbcx]/[rbcy] = scope centre, [rbsh] = zoom
;  shift. ES=bufseg. Serves both the radar and the SIT page.
; ============================================================================
RBLIPS: cmp  byte ptr [rsst],0  ; OUR station down = no returns at all:
        je   @@live             ; the glass goes to snow and says so
        call FAR PTR RSNOISF
        ret
@@live: mov  ax,[rbcy]          ; own ship: the 2 px tick
        inc  ax
        call ROW320
        add  di,[rbcx]
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
        mov  cl,[rbsh]          ; the zoom, then a PIXEL-space clip
        mov  ax,[rcx]
        sar  ax,cl
        cmp  ax,14
        jg   @@rn
        cmp  ax,-14
        jl   @@rn
        mov  bx,[rcz]
        sar  bx,cl
        cmp  bx,14
        jg   @@rn
        cmp  bx,-14
        jl   @@rn
        add  ax,[rbcx]
        mov  [dsx],ax           ; blip column
        mov  ax,[rbcy]
        sub  ax,bx              ; ahead = up the screen
        mov  [dsy],ax           ; keep the row: the letter needs it
        call ROW320
        add  di,[dsx]
        mov  al,95              ; friendly: green
        test si,2
        jz   @@fr
        mov  al,96              ; hostile: yellow
@@fr:   mov  bx,si
        shr  bx,1
        cmp  byte ptr [premote+bx],0
        je   @@iff
        mov  al,8               ; a human wears white - people first
@@iff:  xor  ah,ah
        mov  [dsac],ax          ; the colour must survive SINQ below
        ; allegiance is the SHAPE now (the score legend's language):
        ; friends fly squares, hostiles diamonds. Type shapes retired -
        ; the lock ring names the type in words anyway.
        test si,2
        jnz  @@shd
        mov  es:[di-321],al     ; friend: 3x3 outline square
        mov  es:[di-320],al
        mov  es:[di-319],al
        mov  es:[di-1],al
        mov  es:[di+1],al
        mov  es:[di+319],al
        mov  es:[di+320],al
        mov  es:[di+321],al
        jmp  @@vst
@@shd:  mov  es:[di-320],al     ; hostile: the four diamond points
        mov  es:[di-1],al
        mov  es:[di+1],al
        mov  es:[di+320],al
@@vst:  ; -- velocity stub: two pixels out along the blip's own nose --
        mov  ax,[pah+si]
        sub  ax,[heading]       ; the scope is heading-up
        and  ax,255
        push si                 ; SINQ eats SI
        push ax
        call SINQ
        mov  [wdx],ax           ; screen RIGHT per unit = sin(rel)
        pop  ax
        add  ax,64
        call SINQ
        mov  [wdz],ax           ; screen UP per unit = cos(rel)
        pop  si
        mov  word ptr [tmpi],2  ; pixels 2 and 3 out (clear of the shape)
@@vsp:  mov  ax,[tmpi]
        imul word ptr [wdx]
        add  ax,128             ; round, not truncate: a diagonal stub
        mov  cl,8               ; must actually leave the axis
        sar  ax,cl
        mov  bx,ax              ; px right
        mov  ax,[tmpi]
        imul word ptr [wdz]
        add  ax,128
        sar  ax,cl
        mov  cx,ax              ; px up
        mov  ax,320
        imul cx
        sub  bx,ax              ; bx = dx - 320*dy
        mov  ax,[dsac]
        mov  es:[bx+di],al
        inc  word ptr [tmpi]
        cmp  word ptr [tmpi],4
        jb   @@vsp
        ; -- altitude tick, pushed out past the shape ring --
        mov  bx,[pay+si]        ; above = higher, below = lower than us
        sub  bx,[camy]          ; (dead band +-200)
        mov  ax,[dsac]
        cmp  bx,200
        jle  @@ral
        mov  es:[di-640],al
        jmp  @@ltr
@@ral:  cmp  bx,-200
        jge  @@ltr
        mov  es:[di+640],al
@@ltr:  ; -- the callsign letter beside a human blip --
        mov  bx,si
        shr  bx,1
        cmp  byte ptr [premote+bx],0
        je   @@rn
        mov  al,[pltr+bx]
        or   al,al
        jz   @@rn
        mov  [NB],al            ; a one-letter nameplate, white
        mov  byte ptr [NB+1],0
        mov  ax,[dsx]
        add  ax,3
        mov  [ftx],ax
        mov  ax,[dsy]
        sub  ax,2
        mov  [fty],ax
        mov  byte ptr [COLOR],8
        push si
        mov  si,offset NB
        call FDRAW
        pop  si
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
        call FAR PTR RSBLIPF    ; last, over everything: the ground radars
        ret                     ; the blip engine is done
@@rblip:                        ; plot one amber spark from wdx/wdz
        call ROTXZ
        mov  cl,[rbsh]          ; sparks ride the same zoom
        mov  ax,[rcx]
        sar  ax,cl
        cmp  ax,14
        jg   @@rbx
        cmp  ax,-14
        jl   @@rbx
        mov  bx,[rcz]
        sar  bx,cl
        cmp  bx,14
        jg   @@rbx
        cmp  bx,-14
        jl   @@rbx
        add  ax,[rbcx]
        mov  [dsx],ax
        mov  ax,[rbcy]
        sub  ax,bx
        call ROW320
        add  di,[dsx]
        mov  al,97
        mov  es:[di],al
@@rbx:  ret
; (the scope's furniture - score, pips, rounds - moved to the right
;  MFD: STATPG. Blips fly alone on the glass now.)
RDOUT:  ; ---- readouts right of the map: S/T/F/H rows ----
        mov  byte ptr [COLOR],97
        mov  word ptr [ftx],242
        mov  word ptr [fty],157
        mov  si,offset MSGSPD2
        call FDRAW
        mov  byte ptr [COLOR],8
        mov  word ptr [ftx],256
        mov  ax,[vel]
        call FNUM
        mov  byte ptr [COLOR],97
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
        mov  byte ptr [COLOR],97
        mov  si,offset MSGAB    ; '+' right after the percentage
        call FDRAW
@@nab:  mov  byte ptr [COLOR],97
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
        mov  byte ptr [COLOR],97
        mov  word ptr [ftx],242
        mov  word ptr [fty],181
        mov  si,offset MSGHDG2
        call FDRAW
        mov  byte ptr [COLOR],8
        mov  word ptr [ftx],256
        mov  ax,[heading]
        call FNUM
        ret
        ; (the compact ADI died here 2026-07-27: it duplicated the HUD
        ; ladder and horizon exactly, and the centre MFD carries the
        ; map now - the F-15 SE II swapped its MFD the same way)

; ---- the HUD's font, as a far door: the map pages live in UISEG now -------
FDRAWF  PROC FAR
        call FDRAW
        ret
FDRAWF  ENDP

FNUMF   PROC FAR
        call FNUM
        ret
FNUMF   ENDP

; ============================================================================
;  SITPG - the SIT page: the same blip engine on the centre MFD at a
;  fixed close zoom (1 px = 256 units), heading-up - Falcon's SAD
;  idea on 1990 hardware. ES=bufseg, DS=CS.
; ============================================================================
SITPG:  mov  word ptr [rbcx],160
        mov  word ptr [rbcy],171
        mov  al,8               ; fixed close zoom
        mov  [rbsh],al
        call RBLIPS
        mov  byte ptr [COLOR],97 ; the page name, amber, top left
        mov  word ptr [ftx],138
        mov  word ptr [fty],156
        mov  si,offset MSGSIT
        call FDRAW
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
        cmp  byte ptr [mcact],0
        jne  @@hboff
        cmp  byte ptr [tgtcam],0
        jne  @@hboff
        cmp  byte ptr [dying],0
        je   @@hbon
@@hboff:
        ret                     ; tapes live on the glass, not in the sky
@@hbon: cld
        call LADR               ; the ladder goes down FIRST: the tapes
                                ; and the gunsight draw over its rails
        ; ---- pick the layout ----
        cmp  byte ptr [cockpit],0
        je   @@f2l
        mov  word ptr [hbsx],84   ; cockpit: inside the windshield
        mov  word ptr [hbslb],66  ; scale numbers OUTBOARD (left)
        mov  word ptr [hbst1],85  ; ticks grow INTO the glass
        mov  word ptr [hbst2],85
        mov  word ptr [hbcx],85
        mov  word ptr [hbax],236
        mov  word ptr [hbalb],240 ; scale numbers OUTBOARD (right)
        mov  word ptr [hbat1],230
        mov  word ptr [hbat2],232
        mov  word ptr [hbacx],227
        mov  word ptr [hbscur],94  ; current values INBOARD - the eye
        mov  word ptr [hbacur],206 ; reads them without leaving centre
        jmp  @@lay
@@f2l:  mov  word ptr [hbsx],68   ; F2: the full pane
        mov  word ptr [hbslb],38  ; scale outboard...
        mov  word ptr [hbst1],62
        mov  word ptr [hbst2],64
        mov  word ptr [hbcx],59
        mov  word ptr [hbax],252
        mov  word ptr [hbalb],263
        mov  word ptr [hbat1],253
        mov  word ptr [hbat2],253
        mov  word ptr [hbacx],253
        mov  word ptr [hbscur],72  ; ...current inboard, same law
        mov  word ptr [hbacur],230
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
        mov  ax,16              ; major: LONG, twice the stubs, tall
        mov  cx,8               ; over its number
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
@@cmin: mov  ax,20              ; minor: a short stub, bottom-aligned
        mov  cx,2               ; with the majors
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
        mov  ax,48              ; the spine (12 rows higher: the tapes
        mov  bx,[hbsx]          ; sit UP in the glass, off the nose)
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
        mov  bx,83
        sub  bx,ax
        mov  [cty],bx           ; y
        cmp  bx,48
        jl   @@spn
        cmp  bx,118
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
        call FNUMK
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
        mov  bx,83
        sub  bx,ax
        cmp  bx,48
        jl   @@snc
        cmp  bx,118
        jg   @@snc
        mov  ax,bx
        mov  bx,[hbcx]
        mov  [dsx],bx
        mov  cx,9
        mov  bl,19
        call HLINE2
@@snc:  mov  ax,83              ; the long pointer: from the current
        mov  bx,[hbsx]          ; value, across the spine, toward the
        sub  bx,3               ; scale
        mov  [dsx],bx
        mov  cx,10
        mov  bl,8
        call HLINE2
        mov  ax,83              ; caret + live speed (white, classic)
        call ROW320
        add  di,[hbsx]
        inc  di
        mov  al,8
        mov  es:[di+1-320],al
        mov  es:[di+1+320],al
        mov  ax,[hbscur]        ; the current value INBOARD: read it
        mov  [ftx],ax           ; without leaving the gunsight
        mov  word ptr [fty],80
        mov  byte ptr [COLOR],8
        mov  ax,[vel]
        call FNUM

        ; ================= altitude tape: right =================
        mov  ax,48              ; the spine, 12 rows higher too
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
        mov  bx,83
        sub  bx,ax
        mov  [cty],bx
        cmp  bx,48
        jl   @@apn
        cmp  bx,118
        jg   @@apn
        mov  ax,[ctx]
        xor  dx,dx
        mov  bx,100             ; a number every 100 - every 500 left
        div  bx                 ; the whole tape blank between labels
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
        call FNUMK
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
        mov  bx,83
        sub  bx,ax
        cmp  bx,48
        jl   @@anc
        cmp  bx,118
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
        mov  bx,83
        sub  bx,ax
        cmp  bx,48
        jl   @@anc2
        mov  ax,bx
        mov  bx,[hbacx]
        mov  [dsx],bx
        mov  cx,9
        mov  bl,19
        call HLINE2
@@anc2: mov  ax,83              ; the long pointer: from the current
        mov  bx,[hbax]          ; value, across the spine, toward the
        sub  bx,12              ; scale
        mov  [dsx],bx
        mov  cx,16
        mov  bl,8
        call HLINE2
        mov  ax,83              ; caret + live altitude (white)
        call ROW320
        add  di,[hbax]
        sub  di,2
        mov  al,8
        mov  es:[di-1-320],al
        mov  es:[di-1+320],al
        mov  ax,[hbacur]        ; current value INBOARD
        mov  [ftx],ax
        mov  word ptr [fty],80
        mov  byte ptr [COLOR],8
        mov  ax,[camy]
        call FNUM

        ; ---- IVV: the manual's vertical-speed caret, cyan, sliding
        ; along the altitude spine - one pixel per world unit per tick,
        ; up for a climb, down for a sink
        mov  ax,[vvy]
        cmp  ax,33
        jle  @@iv1
        mov  ax,33
@@iv1:  cmp  ax,-33
        jge  @@iv2
        mov  ax,-33
@@iv2:  neg  ax
        add  ax,83
        mov  bx,[hbax]
        inc  bx
        mov  [dsx],bx
        mov  cx,3
        mov  bl,LCYN
        call HLINE2

        ; ================= the G meter, under the speed tape =========
        ; The manual's readout. This model has no accelerometer, so it
        ; reads what the pilot is DOING: G = 1 + q*vel/512 - the ramped
        ; elevator times airspeed, signed. Hands off = 1.0, a full pull
        ; at combat speed ~ 3.3, a full push goes negative.
        mov  ax,[gq]
        imul word ptr [vel]
        mov  cx,512
        idiv cx
        add  ax,10              ; level flight reads 1.0
        mov  byte ptr [GBUF],' '
        or   ax,ax
        jns  @@gpos
        neg  ax
        mov  byte ptr [GBUF],'-'
@@gpos: cmp  ax,99
        jle  @@gclp
        mov  ax,99
@@gclp: xor  dx,dx
        mov  bx,10
        div  bx
        add  al,'0'
        mov  [GBUF+1],al
        add  dl,'0'
        mov  [GBUF+3],dl
        mov  ax,[hbscur]
        mov  [ftx],ax
        mov  word ptr [fty],123
        mov  byte ptr [COLOR],8
        mov  si,offset GBUF
        call FDRAW
        ret

; FNUMK - FNUM, but past 1000 it reads in K: 1400 -> 1.4K, 2000 -> 2K.
; The scale numbers wear it; the current values keep their full digits.
FNUMK:  cmp  ax,1000
        jb   FNUM
        xor  dx,dx
        mov  bx,100
        div  bx                 ; hundreds, 10..99
        xor  dx,dx
        mov  bx,10
        div  bx                 ; AL = thousands, DL = the odd hundred
        add  al,'0'
        mov  [NB],al
        mov  di,offset NB+1
        or   dl,dl
        jz   @@k
        mov  byte ptr [di],'.'
        add  dl,'0'
        mov  [di+1],dl
        add  di,2
@@k:    mov  byte ptr [di],'K'
        mov  byte ptr [di+1],0
        mov  si,offset NB
        call FDRAW
        ret
