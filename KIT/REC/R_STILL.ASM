; R_STILL.ASM - compressed backgrounds: a level's picture as an OWV still, or picture N of a set
; ============================================================================
;  Recipe: copy after your program's way out (or include it there), with
;  KIT\LIB\K_OWV.INC included too.
;
;  A 320x200 picture is 64000 bytes; as a one-frame OWV (a KEY frame, byte
;  RLE) a drawn background is a few KB. Several backgrounds that look alike
;  (the same room by day and by night, a level and its next) go in ONE
;  file as frames of a clip: each after the first is a DELTA and costs only
;  what differs. Make them with TOOLS\Img2Owv from 8-bit 320x200 BMPs:
;      Img2Owv LEVELS.OWV /key 0 L1.BMP L2.BMP L3.BMP
;  (/key 0: no keyframes after the first). KIT\ART\OWV.TXT says more.
;
;      mov  ax,bufseg / mov es,ax      ; your back buffer
;      mov  dx,bgname                  ; 'ROOM.OWV',0
;      call BG_LOAD                    ; the picture in ES, palette set
;      mov  ax,2                       ; the third picture (from 0)
;      call BG_PICK                    ; ... of a set
;
;  A picture that cannot be loaded never stops the game: the buffer is
;  cleared to colour 0 and CF says why (AL = OWV_E_ code), so a missing
;  file is a black room, not a crash - and the program can say so.
;  The palette: the file's goes to the DAC and stays in [owv_pal]. A game
;  with a palette of its own (its sprites' colours) sets [owv_dac] = 0
;  first and makes its pictures with that palette.
;
;  Define before: -. Memory: OWV_ALLOC (or the segments) once at the start.
;  Calls: OWV_OPEN OWV_FRAME OWV_SHOW OWV_CLOSE OWV_STILL (K_OWV.INC).
;  from: new (OWL NIGHT's rooms are one-frame OWVs: LAB\OWLFLY4\ENGINE
;        BG.OWV, loaded by STORY.ASM's RUNPICKUP)
; ============================================================================

; ----------------------------------------------------------------------
;@ BG_LOAD    a background picture from a one-frame OWV into ES:0
;  in:  DS:DX = the file name; ES = the buffer (64000 bytes)
;  out: AX; CF = 1 error, AL = an OWV_E_ code, the buffer is colour 0
;  needs: K_OWV.INC, OWV_ALLOC done
;  from: new (K_OWV OWV_STILL + a clean failure)
; ----------------------------------------------------------------------
BG_LOAD:
        call OWV_STILL
        jnc  .ok
        call BG_CLEAR
.ok:    ret

; ----------------------------------------------------------------------
;@ BG_PICK    picture AX (from 0) of an OWV set into ES:0
;  in:  AX = which picture; DS:DX = the file name; ES = the buffer
;  out: AX; CF = 1 error (AL = an OWV_E_ code; a picture past the last
;       is OWV_E_SHORT), the buffer is colour 0
;  needs: K_OWV.INC, OWV_ALLOC done
;  from: new (frames of a clip decoded and not shown)
; ----------------------------------------------------------------------
BG_PICK:
        push cx
        mov  cx,ax
        inc  cx                 ; CX = frames to decode: AX + 1
        call OWV_OPEN
        jc   .bad
.f:     call OWV_FRAME
        jc   .bad
        or   al,al
        jz   .past              ; the file ended first
        loop .f
        call OWV_SHOW           ; the last one decoded is the one wanted
        call OWV_CLOSE
        xor  ax,ax              ; CF = 0
        pop  cx
        ret
.past:  mov  al,OWV_E_SHORT
.bad:   call OWV_CLOSE
        call BG_CLEAR
        pop  cx
        ret

; BG_CLEAR - ES:0, 64000 bytes of colour 0; keeps AX and sets CF
BG_CLEAR:
        push ax
        push cx
        push di
        cld
        xor  ax,ax
        xor  di,di
        mov  cx,32000           ; 64000 bytes in words
        rep  stosw
        pop  di
        pop  cx
        pop  ax
        stc
        ret
