; R_CUTSC.ASM - a cutscene or title clip in the middle of a game: fade out, play an OWV, fade back
; ============================================================================
;  Recipe: copy after your program's way out (or include it there), with
;  KIT\LIB\K_OWV.INC included too.
;
;      mov  dx,clipname        ; 'INTRO.OWV',0 - a 320x200 OWV
;      call CUTSCENE           ; AL = 0 it ran out, 27/32 skipped; CF = error
;
;  What it does, in order:
;   1. reads the game's palette out of the DAC (so nothing has to be kept);
;   2. fades the game to black, a step a tick (16 steps, under a second);
;   3. opens the clip with [owv_dac] = 0, so its palette waits in owv_pal,
;      decodes and shows the first frame on the black screen, and fades it
;      up from black - no flash of the game in the clip's colours;
;   4. OWV_PLAY plays the rest (Esc or Space skip it);
;   5. fades the clip down to black, closes it, calls CUT_REDRAW (yours:
;      draw the game's screen again - the clip has painted over A000h),
;      and fades the game's own palette back up.
;  A clip that cannot be opened (no file, not 320x200...) costs nothing:
;  the game's palette comes straight back and CF says why (AL = OWV_E_).
;
;  Define before: CUT_REDRAW - a routine that redraws the game into A000h
;  (it may change AX BX CX DX SI DI BP, must keep DS ES). Memory: OWV_ALLOC
;  (or the three segments) once at the start of the game.
;  Calls: OWV_OPEN OWV_FRAME OWV_SHOW OWV_PLAY OWV_CLOSE (K_OWV.INC).
;  A key handler of your own on INT 9: define OWV_KEY (K_OWV.INC's header)
;  or the clip cannot be skipped.
;  from: LAB\OWLFLY4\ENGINE\STORY.ASM PALSET/FADEUP/FADEDN 3297-3333 and
;        its OWV_PALETTE/OWV_FINISH hooks 3343-3374 (the clip opens on
;        black and goes down to black) - ported to 8086, a level a tick
; ============================================================================

; ----------------------------------------------------------------------
;@ CUTSCENE   play an OWV clip inside a game: fade out, play, fade back
;  in:  DS:DX = the clip's file name; mode 13h; CUT_REDRAW defined
;  out: AX: AL = 0 ran out, 27 Esc / 32 Space skipped; CF = 1 error,
;       AL = an OWV_E_ code (the game's palette is back either way)
;  needs: K_OWV.INC, OWV_ALLOC done
;  from: LAB\OWLFLY4\ENGINE\STORY.ASM 3297-3374 (ported)
; ----------------------------------------------------------------------
CUTSCENE:
        push bx
        push cx
        push dx
        push si
        push es
        cld
        mov  [cut_name],dx
        mov  dx,3C7h            ; DAC: the read index
        xor  al,al
        out  dx,al
        mov  dx,3C9h
        mov  si,cut_game
        mov  cx,768
.rd:    in   al,dx              ; the game's palette, as the DAC has it
        mov  [si],al
        inc  si
        loop .rd
        mov  si,cut_game
        call CUT_DOWN           ; the game to black
        mov  dx,[cut_name]
        mov  byte [owv_dac],0   ; the clip's palette waits in owv_pal
        call OWV_OPEN
        jc   .fail
        call OWV_FRAME
        jc   .fail2
        mov  ax,0A000h
        mov  es,ax
        call OWV_SHOW           ; the first frame, on a black DAC
        mov  si,owv_pal
        call CUT_UP             ; up from black
        mov  byte [owv_dac],1   ; PALETTE chunks straight to the DAC now
        call OWV_PLAY
        pushf
        push ax
        mov  si,owv_pal
        call CUT_DOWN           ; the clip to black
        call OWV_CLOSE
        call CUT_REDRAW         ; yours: the game's screen again
        mov  si,cut_game
        call CUT_UP             ; and its colours
        pop  ax
        popf
        jmp  .out
.fail2: call OWV_CLOSE
.fail:  mov  byte [owv_dac],1
        push ax
        mov  si,cut_game        ; nothing was drawn: the colours back
        mov  al,16
        call CUT_PAL
        pop  ax
        stc
.out:   pop  es
        pop  si
        pop  dx
        pop  cx
        pop  bx
        ret

; CUT_UP / CUT_DOWN - the palette at DS:SI (768 bytes, 6-bit) from black
; up to full, or from full down to black: 17 levels, one a BIOS tick.
CUT_UP: push ax
        xor  al,al
.u:     call CUT_PAL
        call CUT_TICK
        inc  al                 ; one level up
        cmp  al,16
        jbe  .u
        pop  ax
        ret
CUT_DOWN:
        push ax
        mov  al,16
.d:     call CUT_PAL
        call CUT_TICK
        sub  al,1               ; one level down
        jnc  .d                 ; ...through 0
        pop  ax
        ret

; CUT_PAL - the DAC = the palette at DS:SI times AL/16 (AL = 0..16)
CUT_PAL:
        push ax
        push bx
        push cx
        push dx
        push si
        mov  bl,al              ; BL = the level
        mov  dx,3C8h            ; DAC: the write index
        xor  al,al
        out  dx,al
        inc  dx                 ; 3C9h: the data
        mov  cx,768
.p:     lodsb
        mul  bl                 ; AX = value * level (63 * 16 at most)
        shr  ax,1
        shr  ax,1
        shr  ax,1
        shr  ax,1               ; / 16: never a divide
        out  dx,al
        loop .p
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret

; CUT_TICK - wait for the next BIOS tick (1/18.2 s)
CUT_TICK:
        push ax
        push bx
        push ds
        mov  ax,40h
        mov  ds,ax
        mov  bx,[6Ch]           ; the tick now
.w:     cmp  bx,[6Ch]
        je   .w                 ; until it moves
        pop  ds
        pop  bx
        pop  ax
        ret

cut_name dw  0                  ; the clip's name
cut_game db  768 dup (0)        ; the game's palette while the clip plays
