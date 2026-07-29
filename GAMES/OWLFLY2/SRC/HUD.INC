; HUD.INC - part of WIRE CITY (included from CITY.ASM)
; ============================================================================
;  HUD - the readouts for the NO-COCKPIT view. It printed them through
;  the BIOS teletype in the 8x8 ROM font: twice the height of the game's
;  own letters, locked to a character grid, and drawn straight to video
;  memory AFTER the blit, so it could never share a row with anything.
;  It hands off to TOPSTRIP/BOTSTRIP now - same words, the game's own 4x6
;  font, into the back buffer like everything else. With the cockpit UP it
;  draws nothing at all: the panel already says it, in its own places.
; ============================================================================
HUD:    cmp  byte ptr [cockpit],0
        je   @@hgo              ; cockpit down: THIS view carries the words
        cmp  word ptr [pimgo],0
        je   @@hgo              ; no panel bitmap: same
        ret                     ; the panel says it all, and better
@@hgo:  call FAR PTR TOPSTRIPF
        call FAR PTR BOTSTRIPF
        ret

; (PRSTR/PRCH/PRNUM below drove the BIOS teletype this used to print with.
;  They are the crash screen's now - see CRASHHANDLE - and nothing else
;  uses INT 10h for text on the flying glass any more.)

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
LADR:   mov  ax,[horiz]        ; the glass centre, not the screen's
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
;  FNUMZ - the same, but padded with LEADING ZEROS to CX digits. The new
;  cockpit bakes '888' under each readout to show how wide the field is, so
;  a bare '0' for heading leaves two of the artist's eights showing through
;  beside it. Leading zeros cover the field exactly - and that is what a
;  seven-segment gauge does anyway. CX 1..5; a value too big for the field
;  simply runs long rather than lie about itself.
; ============================================================================
FNUMZ:  mov  di,offset NB+5
        mov  byte ptr [di],0
        mov  bx,10
@@z:    xor  dx,dx
        div  bx
        add  dl,'0'
        dec  di
        mov  [di],dl
        dec  cx
        test ax,ax
        jnz  @@z
        cmp  cx,0               ; SIGNED: a number wider than its field
        jle  @@zd               ; drives cx below zero, and must not wrap
@@zp:   dec  di                 ; still short of the field: pad it out
        mov  byte ptr [di],'0'
        loop @@zp
@@zd:   mov  si,di
        call FDRAW
        ret


; (TOPSTRIP / BOTSTRIP moved to SYMSEG on 2026-07-29: the stack guard
;  fired and they were the newest, coldest, most self-contained thing in
;  this segment - text for ONE view, calling nothing the far doors do not
;  already carry. HUD reaches them through TOPSTRIPF / BOTSTRIPF.)


; ============================================================================
;  PANELBMP - the photo cockpit (CITY.DAT resource 2) over the rendered
;  world. NO COORDINATE IS TYPED HERE ANY MORE: TOOLS\Panel2Inc finds the
;  three screens in res\cockpit2.png every build and writes PANELZON.INC,
;  and everything that draws on glass reads PZRDR/PZADI/PZMAP from it. Move
;  a screen in the picture and the instruments follow. The rest of the
;  furniture - the digit row, the two annunciator columns, the throttle
;  ladder - is still measured by hand in DATA.INC, because the artwork does
;  not mark it yet; paint those as cyan blocks and the tool will report
;  them too. ES=bufseg, DS=CS.
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
        ; (the title strip moved out of here on 2026-07-29: with the new
        ; panel it sat on the overhead bank, doubling what the readouts
        ; below already said. It is TOPSTRIP now, and only the no-cockpit
        ; view draws it - see HUD.)
        ; ---- afterburner strip ----
        cmp  byte ptr [abon],0
        je   @@ab
        mov  byte ptr [COLOR],97
        mov  word ptr [ftx],149
        mov  word ptr [fty],15
        mov  si,offset MSGABON
        call FDRAW
@@ab:
        ; ---- caution lights, now in the panel's own annunciator stacks.
        ; They used to ride the old cockpit's canopy struts; on this panel
        ; those coordinates are open sky, and a warning lamp hanging in
        ; mid-air is worse than none. LEFT column: fuel, then lock. RIGHT
        ; column, where the artwork already prints its alarm words: stall
        ; and terrain. Single letters still - a slot is 16x10 px and the
        ; font steps four, so five characters is the whole budget and a
        ; blinking letter reads faster than a squeezed word.
        mov  word ptr [lampx],PZLCX
        mov  word ptr [lampy],PZLAMPY+PZLAMPH*3
        mov  word ptr [dsx],PZLCW
        mov  word ptr [dsy],PZLAMPH
        xor  cx,cx
        cmp  word ptr [fuel],1200
        jge  @@lf
        mov  cx,19              ; low fuel: red
@@lf:   mov  si,offset MSGF2
        call LAMP2
        mov  word ptr [lampx],PZRCX
        mov  word ptr [lampy],PZLAMPY
        mov  word ptr [dsx],PZRCW
        mov  word ptr [dsy],PZLAMPH
        xor  cx,cx
        mov  ax,[vel]
        cmp  ax,VSTALL
        jge  @@ls
        mov  cx,19              ; stall: red
@@ls:   mov  si,offset MSGS2
        call LAMP2
        mov  word ptr [lampx],PZRCX
        mov  word ptr [lampy],PZLAMPY+PZLAMPH
        mov  word ptr [dsx],PZRCW
        mov  word ptr [dsy],PZLAMPH
        xor  cx,cx
        mov  ax,[camy]
        sub  ax,[lgnd]
        cmp  ax,150
        jge  @@lt
        mov  cx,97              ; terrain close: amber
@@lt:   mov  si,offset MSGT2
        call LAMP2
        mov  word ptr [lampx],PZLCX ; lock lamp: left column, top slot
        mov  word ptr [lampy],PZLAMPY
        mov  word ptr [dsx],PZLCW
        mov  word ptr [dsy],PZLAMPH
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
        mov  word ptr [dsx],PZTHRY ; current segment row
        xor  si,si              ; segment index
@@tb:   cmp  si,12
        jae  @@tbd
        cmp  si,dx
        jae  @@tbd              ; above the setting: the artwork shows through
        mov  ax,[dsx]
        call ROW320
        add  di,PZTHRX
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
        ; the frame goes up FIRST now: the range rose reads it too, and it
        ; used to carry the old screen's centre as a pair of immediates
        mov  word ptr [rbcx],PZRDRCX ; the scope frame: centre, reach, zoom
        mov  word ptr [rbcy],PZRDRCY
        mov  word ptr [rbrad],PZRDRR
        mov  word ptr [rbradn],-PZRDRR
        mov  al,[rzsh]
        mov  [rbsh],al
        call FAR PTR BQCITYF    ; the town goes down first, under everything
        call FAR PTR RGRIDF
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
@@live: ; own ship: the same aeroplane symbol, in trim grey, always pointing
        ; up - the scope is heading-up, so our own nose is the reference
        ; every other symbol on the glass is measured against. And it obeys
        ; the SAME zoom ladder as everything else: it used to be an
        ; aeroplane at every setting, which made our own jet the biggest
        ; thing on a scope where every other contact was a dot.
        mov  ax,[rbcx]
        mov  [bqx],ax
        mov  ax,[rbcy]
        mov  [bqy],ax
        mov  word ptr [bqa],0
        mov  byte ptr [COLOR],0
        mov  ax,[rbcy]
        call ROW320
        add  di,[rbcx]
        mov  al,[rbsh]
        cmp  al,BQZICON
        jbe  @@livi
        mov  al,0
        cmp  byte ptr [rbsh],BQZCROS
        ja   @@livd
        mov  es:[di-320],al     ; the middle setting: a cross, like theirs
        mov  es:[di+320],al
        mov  es:[di-1],al
        mov  es:[di+1],al
@@livd: mov  es:[di],al         ; wound right out: one pixel
        jmp  @@livn
@@livi: call FAR PTR BQJETF
@@livn: xor  si,si
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
        cmp  ax,[rbrad]
        jg   @@rn
        cmp  ax,[rbradn]
        jl   @@rn
        mov  bx,[rcz]
        sar  bx,cl
        cmp  bx,[rbrad]
        jg   @@rn
        cmp  bx,[rbradn]
        jl   @@rn
        add  ax,[rbcx]
        mov  [dsx],ax           ; blip column
        mov  ax,[rbcy]
        sub  ax,bx              ; ahead = up the screen
        mov  [dsy],ax           ; keep the row: the letter needs it
        call ROW320
        add  di,[dsx]
        mov  al,95              ; our side: green
        test si,2
        jz   @@fr
        mov  al,19              ; theirs: RED. It was yellow, and yellow is
                                ; a caution colour, not an enemy one
@@fr:   xor  ah,ah
        mov  [dsac],ax          ; the colour must survive the symbol call
        ; The symbol is an AEROPLANE, swung to the contact's own heading -
        ; squares and diamonds said which side but never which way, and a
        ; bandit's heading is the first thing a pilot reads off a scope.
        ; Colour carries the side, and it is NOT overridden for a human
        ; any more: people take sides here too, and painting them white
        ; threw that away. A human gets a pip above the symbol instead.
        mov  [COLOR],al
        ; how much symbol: the SCOPE'S ZOOM decides it, for everything on
        ; the glass at once. Not each contact by its own range - that made
        ; one scope carry three languages and read as a mess.
        mov  al,[rbsh]
        cmp  al,BQZICON
        jbe  @@ricon
        cmp  al,BQZCROS
        jbe  @@rmid
        mov  ax,[dsac]          ; wound right out: one pixel, and no more
        mov  es:[di],al
        jmp  @@vst
@@rmid: mov  ax,[dsac]          ; the middle setting: a cross
        mov  es:[di],al
        mov  es:[di-320],al
        mov  es:[di+320],al
        mov  es:[di-1],al
        mov  es:[di+1],al
        jmp  @@vst
@@ricon:
        mov  ax,[dsx]
        mov  [bqx],ax
        mov  ax,[dsy]
        mov  [bqy],ax
        mov  ax,[pah+si]
        sub  ax,[heading]       ; the scope is heading-up
        and  ax,255
        mov  [bqa],ax
        push si
        push di
        call FAR PTR BQJETF
        pop  di
        pop  si
@@vst:  ; -- altitude tick. Six rows out, not two: the symbol is an
        ; aeroplane now and a tick at two rows would land on its own wing --
        mov  bx,[pay+si]        ; above = higher, below = lower than us
        sub  bx,[camy]          ; (dead band +-200)
        mov  ax,[dsac]
        cmp  bx,200
        jle  @@ral
        mov  es:[di-1920],al
        jmp  @@ltr
@@ral:  cmp  bx,-200
        jge  @@ltr
        mov  es:[di+1920],al
@@ltr:  ; -- the callsign letter beside a human blip. THIS is what marks a
        ; live pilot now; his symbol keeps his side's colour like everyone
        ; else's, because on this wire humans have sides too --
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
        add  ax,6               ; clear of the wing
        mov  [ftx],ax
        mov  ax,[dsy]
        sub  ax,3
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
        call FAR PTR SHKBLIPF   ; the flak, with its barrels where they point
        call FAR PTR RSBLIPF    ; last, over everything: the ground radars
        ret                     ; the blip engine is done
@@rblip:                        ; plot one amber spark from wdx/wdz
        call ROTXZ
        mov  cl,[rbsh]          ; sparks ride the same zoom
        mov  ax,[rcx]
        sar  ax,cl
        cmp  ax,[rbrad]
        jg   @@rbx
        cmp  ax,[rbradn]
        jl   @@rbx
        mov  bx,[rcz]
        sar  bx,cl
        cmp  bx,[rbrad]
        jg   @@rbx
        cmp  bx,[rbradn]
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
RDOUT:  ; ---- the strip under the centre screen: IAS / ALT / HDG / VERT ----
        ; The new panel PRINTS those four words and a row of 8s beneath
        ; them, so this routine no longer draws its own labels - it just
        ; overwrites the placeholders. Green, to read as the seven-segment
        ; display the picture is imitating. (The old S/T/F/H block lived
        ; where the right screen now is; throttle kept its ladder, and
        ; fuel moved onto the status page, which is where status belongs.)
        mov  byte ptr [COLOR],95
        mov  word ptr [fty],PZDIGY
        mov  word ptr [ftx],PZDIG0
        mov  ax,[vel]
        mov  cx,3
        call FNUMZ
        mov  word ptr [ftx],PZDIG1
        mov  ax,[camy]
        mov  cx,5
        call FNUMZ
        mov  word ptr [ftx],PZDIG2
        mov  ax,[heading]
        mov  cx,3
        call FNUMZ
        ; VERT is the only signed one, and it always wears its sign - so
        ; the field is four wide whichever way the jet is going, and the
        ; artist's four eights are covered either way. FNUMZ divides, so
        ; it is handed a magnitude; FDRAW steps ftx by four on its own.
        mov  word ptr [ftx],PZDIG3
        mov  ax,[vvy]
        test ax,ax
        js   @@vdn
        push ax
        mov  si,offset MSGAB    ; climbing: '+'
        call FDRAW
        pop  ax
        jmp  @@vup
@@vdn:  push ax
        mov  si,offset MSGMIN2
        call FDRAW
        pop  ax
        neg  ax
@@vup:  mov  cx,3
        call FNUMZ
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

FNUMZF  PROC FAR
        call FNUMZ
        ret
FNUMZF  ENDP

; ============================================================================
;  SITPG - the SIT page: the same blip engine on the centre MFD at a
;  fixed close zoom (1 px = 256 units), heading-up - Falcon's SAD
;  idea on 1990 hardware. ES=bufseg, DS=CS.
; ============================================================================
SITPG:  mov  word ptr [rbcx],PZADICX
        mov  word ptr [rbcy],PZADICY
        mov  word ptr [rbrad],PZADIR
        mov  word ptr [rbradn],-PZADIR
        mov  al,8               ; fixed close zoom
        mov  [rbsh],al
        call RBLIPS
        mov  byte ptr [COLOR],97 ; the page name, amber, top left
        mov  word ptr [ftx],PZADIX0+2
        mov  word ptr [fty],PZADIY0+2
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


; ---------------------------------------------------------------------------
;  HBLN - lean one element of a tape so the tape follows the canopy bow it
;  lives beside. Only the POSITION leans: the tick is still a level line and
;  the number is still upright. The bow was measured off the artwork at 17
;  pixels across 60 rows; HBLEAN/32 is that slope.
;   in: AX = row, BX = the upright x, [hbslp] = the lean (signed, 0 = none)
;   out: BX = the leaned x. Everything else survives.
; ---------------------------------------------------------------------------
HBLN:   push ax
        push cx
        push dx
        mov  cx,ax
        mov  ax,HBPIV
        sub  ax,cx              ; rows above the tape's middle
        imul word ptr [hbslp]
        mov  cx,32
        idiv cx
        add  bx,ax
        pop  dx
        pop  cx
        pop  ax
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
        mov  word ptr [hbscur],104 ; current values INBOARD - the eye
        mov  word ptr [hbacur],198 ; reads them without leaving centre.
                                   ; Pushed in once the tapes leaned: at
                                   ; row 80 the bows stand at x 87..100 and
                                   ; 218..231 and were eating the digits.
                                   ; Both numbers are drawn LEFT-aligned,
                                   ; so the right one had to be set by its
                                   ; far end: four digits from 198 stop at
                                   ; 214, four clear of the bow - the same
                                   ; gap the speed has on its own side.
        mov  word ptr [hbslp],-HBLEAN  ; the left bow leans this way; the
        jmp  @@lay                     ; altitude tape flips the sign below
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
        mov  word ptr [hbslp],0   ; no cockpit, no bows: tapes stand upright
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
        mov  bx,[hbsx]          ; sit UP in the glass, off the nose) - and
        call HBLN               ; leaning now, along the bow beside it
        mov  [sx0],bx
        mov  word ptr [sy0],48
        mov  ax,118
        mov  bx,[hbsx]
        call HBLN
        mov  [sx1],bx
        mov  word ptr [sy1],118
        mov  byte ptr [COLOR],8
        call CLIPLINE
        jc   @@sspn
        call LINE
@@sspn:
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
        mov  bx,[hbslb]
        mov  ax,[cty]
        call HBLN
        mov  [ftx],bx
        mov  byte ptr [COLOR],8
        mov  ax,[ctx]
        call FNUMK
        jmp  @@spn
@@smin: mov  ax,[cty]           ; minor: same anchor, shorter
        mov  bx,[hbst2]
        call HBLN
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
        call HBLN
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
        mov  word ptr [hbslp],HBLEAN ; the RIGHT bow leans the other way
        cmp  byte ptr [cockpit],0
        jne  @@aspl
        mov  word ptr [hbslp],0
@@aspl: mov  ax,48              ; the spine, 12 rows higher too
        mov  bx,[hbax]
        call HBLN
        mov  [sx0],bx
        mov  word ptr [sy0],48
        mov  ax,118
        mov  bx,[hbax]
        call HBLN
        mov  [sx1],bx
        mov  word ptr [sy1],118
        mov  byte ptr [COLOR],8
        call CLIPLINE
        jc   @@aspn
        call LINE
@@aspn:
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
        call HBLN
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
        mov  bx,[hbalb]
        mov  ax,[cty]
        call HBLN
        mov  [ftx],bx
        mov  byte ptr [COLOR],8
        mov  ax,[ctx]
        call FNUMK
        jmp  @@apn
@@amin: mov  ax,[cty]           ; minor divider
        mov  bx,[hbat2]
        call HBLN
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
        call HBLN
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
        call HBLN
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
        call HBLN               ; it rides the spine, and the spine leans
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
        mov  ax,[hbscur]        ; row 123 vanished under the panel once it
        add  ax,12              ; grew. The glass runs to row 108 across
        mov  [ftx],ax           ; the middle and the bow reaches x 109 by
        mov  word ptr [fty],101 ; then, so: inboard of one, above the other
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
