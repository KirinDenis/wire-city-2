; ============================================================================
;  K_UI.INC - KIT: the point-and-click screen's furniture: inventory slots
;  (an outline until the thing is taken, then in colour), a caption band
;  that comes down by itself, a message box, a numbered question whose
;  answer is a code, and fades by the tick.
;
;        mov  si,things                  ; K_HOT's table
;        mov  cx,3
;        call UI_PANEL                   ; a slot each, outlines
;        ...a thing taken:
;        call UI_SLOT                    ; BX = it: its slot in colour now
;        mov  si,sKeyText                ; db 'An old iron key.',0
;        call UI_CAPTION                 ; a band at the foot, under it kept
;        ...every frame:
;        call UI_CAPCHECK                ; its time up: the band put back
;
;  Everything draws into ES (320 bytes a row). The question and the message
;  box wait for a key: if ES is a back buffer, put your "copy it to the
;  screen" routine in [ui_show] first (mov [ui_show],Show) and they call it.
;  Letters come from K_TEXT (its font, scale and style as set), boxes from
;  K_DRAW. Include K_DRAW.INC and K_TEXT.INC; UI_PANEL/UI_SLOT need
;  K_HOT.INC and K_SPR's compiled sprites; UI_FADEUP/DN need K_VGA.INC.
; ============================================================================

; the look and the places: always here (a few bytes), set them before drawing
ui_show   dw 0                  ; a routine that shows ES's picture (0: ES is the screen)
ui_grey   db 7                  ; the outline of a thing not yet taken
ui_txtc   db 15                 ; the letters of the boxes and the caption
ui_boxc   db 0                  ; the box / band behind them
ui_boxfr  db 7                  ; the box's frame
ui_slotx  dw 8                  ; UI_PANEL: the first slot's left
ui_sloty  dw 176                ;  its top
ui_slotw  dw 24                 ;  a slot's width (the next one starts here)
ui_sloth  dw 20                 ;  its height
ui_slotbg db 0                  ;  inside a slot
ui_slotfr db 8                  ;  its frame
ui_capy   dw 160                ; UI_CAPTION: the band's top
ui_caph   dw 12                 ;  its height (at most 16 rows)
ui_caphold dw 27                ;  ticks it stays up (27 = 1.5 s)
ui_msgy   dw 70                 ; UI_MSGBOX: the box's top
ui_lvl    db 64                 ; UI_FADE*: the DAC's level now (0..64)
ui_fstep  db 8                  ;  levels a tick (8: a fade in 8 ticks)

; ---- UI_TICK (inside the kit): AX = the BIOS tick (low word).
if used UI_TICK
UI_TICK:
        push ds
        xor  ax,ax
        mov  ds,ax
        mov  ax,[46Ch]
        pop  ds
        ret
end if

; ---- UI_SHOW (inside the kit): call [ui_show] if set. All kept.
if used UI_SHOW
UI_SHOW:
        cmp  word [ui_show],0
        je   .o
        push ax
        push bx
        push cx
        push dx
        push si
        push di
        push bp
        call word [ui_show]
        pop  bp
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
.o:     ret
end if

; ----------------------------------------------------------------------
;@ UI_ICON    a compiled sprite at (BX,DX) in colour (AL=1) or as its outline (AL=0)
;  in:  SI = the compiled sprite (K_SPR: db w,h, w*h bytes, 255 the hole),
;       BX = x, DX = y, AL = 1 colour, 0 outline in [ui_grey]
;  out: - (clipped to the screen)
;  needs: -
;  from: LAB\OWLFLY4\ENGINE\STORY.ASM:2898-2971 DRAWICO (outline = an
;        opaque pixel at the picture's edge or with a see-through neighbour
;        left, right, above or below), ported to 8086, clipped
; ----------------------------------------------------------------------
if used UI_ICON
UI_ICON:
        push ax
        push bx
        push cx
        push dx
        push si
        push di
        push bp
        mov  [ui_imode],al
        mov  [ui_ix],bx
        mov  [ui_iy],dx
        xor  ah,ah
        mov  al,[si]
        mov  [ui_iw],ax         ; width
        mov  al,[si+1]
        mov  [ui_ih],ax         ; height
        add  si,2               ; SI = the first pixel
        xor  dx,dx              ; DX = row
.row:   cmp  dx,[ui_ih]
        jae  .done
        xor  cx,cx              ; CX = column
.col:   cmp  cx,[ui_iw]
        jae  .nrow
        mov  al,[si]
        cmp  al,255
        je   .next              ; a hole
        cmp  byte [ui_imode],1
        je   .put
        ; an outline pixel?
        test cx,cx
        jz   .edge
        cmp  byte [si-1],255
        je   .edge
        mov  bp,cx
        inc  bp                 ; the column to the right
        cmp  bp,[ui_iw]
        jae  .edge
        cmp  byte [si+1],255
        je   .edge
        test dx,dx
        jz   .edge
        mov  bp,si
        sub  bp,[ui_iw]         ; the pixel above
        cmp  byte [ds:bp],255
        je   .edge
        mov  bp,dx
        inc  bp                 ; the row below
        cmp  bp,[ui_ih]
        jae  .edge
        mov  bp,si
        add  bp,[ui_iw]         ; the pixel below
        cmp  byte [ds:bp],255
        je   .edge
        jmp  .next              ; inside the shape: not drawn
.edge:  mov  al,[ui_grey]
.put:   mov  bx,[ui_ix]
        add  bx,cx              ; screen x
        cmp  bx,320
        jae  .next              ; (negative is above 320 unsigned)
        mov  bp,[ui_iy]
        add  bp,dx              ; screen y
        cmp  bp,200
        jae  .next
        push ax
        mov  ax,bp
        push cx
        mov  cl,6
        shl  ax,cl              ; y * 64
        mov  di,ax
        shl  ax,1               ; y * 128
        shl  ax,1               ; y * 256
        add  di,ax              ; y * 320
        pop  cx
        add  di,bx              ; + x
        pop  ax
        mov  [es:di],al
.next:  inc  si                 ; the next pixel
        inc  cx                 ; its column
        jmp  .col
.nrow:  inc  dx                 ; the next row
        jmp  .row
.done:  pop  bp
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret
end if

if used ui_imode
ui_imode db 0                   ; UI_ICON's working values
ui_ix    dw 0
ui_iy    dw 0
ui_iw    dw 0
ui_ih    dw 0
end if

; ----------------------------------------------------------------------
;@ UI_SLOT    draw slot BX of the panel: its box, and thing BX outlined or in colour
;  in:  SI = K_HOT's table, BX = the thing (= its slot), [ui_slotx..]
;  out: - (an empty box if the thing is not LOADED or has no sprite;
;       outline while it is not TAKEN, colour once it is; centred)
;  needs: K_HOT.INC, K_DRAW.INC
;  from: LAB\OWLFLY4\ENGINE\STORY.ASM:2868-2896 DRAWPANEL/SLOTON (the
;        converter placed the slot pictures there; here the slots are laid
;        in a row by rule)
; ----------------------------------------------------------------------
if used UI_SLOT
UI_SLOT:
        push ax
        push bx
        push cx
        push dx
        push si
        push di
        push bp
        call HOT_ENTRY          ; DI = the thing
        mov  ax,[ui_slotw]
        mul  bx                 ; AX = slot * width (DX = 0 for sane sizes)
        add  ax,[ui_slotx]      ; the slot's left
        mov  [ui_sx],ax
        mov  bx,[ui_sloty]
        mov  cx,[ui_slotw]
        sub  cx,2               ; a gap of 2 between slots
        mov  dx,[ui_sloth]
        mov  bp,ax
        mov  al,[drw_col]
        push ax
        mov  al,[ui_slotbg]
        mov  [drw_col],al
        mov  ax,bp
        call DRW_RECT           ; the slot's inside
        mov  al,[ui_slotfr]
        mov  [drw_col],al
        mov  ax,bp
        call DRW_FRAME          ; its frame
        pop  ax
        mov  [drw_col],al
        test byte [di+HOT_FLAGS],HOT_LOADED
        jz   .out
        mov  si,[di+HOT_SPR]
        test si,si
        jz   .out
        ; centred in the slot
        xor  ah,ah
        mov  al,[si]
        neg  ax                 ; - the sprite's width
        add  ax,cx              ; slot width - sprite width
        sar  ax,1               ; half of it (negative: it hangs over)
        add  ax,[ui_sx]         ; + the slot's left
        mov  bx,ax              ; x
        xor  ah,ah
        mov  al,[si+1]
        neg  ax                 ; - the sprite's height
        add  ax,[ui_sloth]      ; slot height - sprite height
        sar  ax,1               ; half of it
        add  ax,[ui_sloty]      ; + the slot's top
        mov  dx,ax              ; y
        mov  al,[di+HOT_FLAGS]
        shr  al,1               ; bit 1 (TAKEN) to bit 0
        and  al,1               ; TAKEN -> 1 colour, else 0 outline
        call UI_ICON
.out:   pop  bp
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret
end if

if used ui_sx
ui_sx   dw 0                    ; UI_SLOT: the slot's left
end if

; ----------------------------------------------------------------------
;@ UI_PANEL   draw every slot: one per thing of K_HOT's table
;  in:  SI = the table, CX = things, [ui_slotx] [ui_sloty] [ui_slotw]
;       [ui_sloth] [ui_slotbg] [ui_slotfr] [ui_grey]
;  out: -
;  needs: K_HOT.INC, K_DRAW.INC; UI_SLOT redraws one after a take
;  from: LAB\OWLFLY4\ENGINE\STORY.ASM:2868-2885 DRAWPANEL
; ----------------------------------------------------------------------
if used UI_PANEL
UI_PANEL:
        push bx
        push cx
        xor  bx,bx
        jcxz .out
.l:     call UI_SLOT
        inc  bx                 ; the next slot
        loop .l
.out:   pop  cx
        pop  bx
        ret
end if

; ----------------------------------------------------------------------
;@ UI_CAPTION a line of text in a band at [ui_capy] for [ui_caphold] ticks; under it kept
;  in:  SI = the text (0-ended), ES = where it is drawn; [ui_capy]
;       [ui_caph] (<= 16) [ui_boxc] [ui_txtc], K_TEXT's font/scale/style
;  out: - (a caption already up is taken down first)
;  needs: UI_CAPCHECK every frame takes it down when its time is up;
;         nothing else may draw in the band while it is up (it is put back
;         as it was); the pointer hidden while it goes up or down
;  from: LAB\OWLFLY4\ENGINE\STORY.ASM:2979-3073 CAPTION/CAPTHIDE (there
;        the band came back from the room's frame; here from a save)
; ----------------------------------------------------------------------
if used UI_CAPTION
UI_CAPTION:
        push ax
        push bx
        push cx
        push dx
        push si
        push di
        cmp  byte [ui_capon],1
        jne  .c1
        call UI_CAPHIDE         ; the last one comes down first
.c1:    push si
        ; keep the band
        call UI_CAPBOX          ; DI = its first byte, CX = its bytes
        push ds
        push es
        mov  si,di              ; from ES:DI ...
        mov  di,ui_capbuf       ; ... to DS:ui_capbuf
        push es
        push ds
        pop  es                 ; ES = DS
        pop  ds                 ; DS = the picture
        cld
        rep  movsb
        pop  es
        pop  ds
        ; the band
        mov  al,[drw_col]
        push ax
        mov  al,[ui_boxc]
        mov  [drw_col],al
        xor  ax,ax
        mov  bx,[ui_capy]
        mov  cx,320
        mov  dx,[ui_caph]
        call DRW_RECT
        pop  ax
        mov  [drw_col],al
        ; the letters, centred both ways
        pop  si
        mov  al,[txt_col]
        push ax
        mov  al,[ui_txtc]
        mov  [txt_col],al
        call UI_GLYPHH          ; AX = a letter's height
        neg  ax                 ; - the letter's height
        add  ax,[ui_caph]       ; + the band's
        sar  ax,1               ; (band - letter) / 2
        add  ax,[ui_capy]       ; + the band's top
        mov  dx,ax
        mov  bx,160
        call TXT_CENTER
        pop  ax
        mov  [txt_col],al
        mov  byte [ui_capon],1
        call UI_TICK
        mov  [ui_capt],ax
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret
end if

if used ui_capon
ui_capon db 0                   ; 1 = a caption is up
ui_capt  dw 0                   ; the tick it went up
ui_capbuf db 320*16 dup(0)      ; the band under it
end if

; ---- UI_GLYPHH (inside the kit): AX = the height of a letter in K_TEXT's
;  current font and scale (8 or 6, times the scale).
if used UI_GLYPHH
UI_GLYPHH:
        mov  ax,8
        cmp  byte [txt_font],0
        je   .s
        mov  ax,6
.s:     cmp  byte [txt_scale],2
        jne  .o
        shl  ax,1               ; twice as big
.o:     ret
end if

; ---- UI_CAPBOX (inside the kit): DI = the band's first byte, CX = its
;  bytes (rows clamped to 1..16 and to the screen). AX changed.
if used UI_CAPBOX
UI_CAPBOX:
        mov  ax,[ui_caph]
        cmp  ax,16
        jbe  .h
        mov  ax,16
        mov  [ui_caph],ax       ; the save holds 16 rows
.h:     mov  cx,200
        sub  cx,[ui_capy]       ; rows left below the band's top
        cmp  ax,cx
        jbe  .h2
        mov  ax,cx
        mov  [ui_caph],ax
.h2:    push dx
        mov  dx,ax
        mov  cl,6
        shl  dx,cl              ; rows * 64
        mov  cx,dx
        shl  dx,1               ; rows * 128
        shl  dx,1               ; rows * 256
        add  cx,dx              ; CX = rows * 320, the bytes
        mov  ax,[ui_capy]
        mov  dx,cx
        mov  cl,6
        shl  ax,cl              ; y * 64
        mov  di,ax
        shl  ax,1               ; y * 128
        shl  ax,1               ; y * 256
        add  di,ax              ; DI = y * 320
        mov  cx,dx
        pop  dx
        ret
end if

; ----------------------------------------------------------------------
;@ UI_CAPHIDE take the caption down now: the band exactly as it was before
;  in:  ES = where it was drawn
;  out: - (nothing if none is up)
;  needs: -
;  from: LAB\OWLFLY4\ENGINE\STORY.ASM:3053-3073 CAPTHIDE
; ----------------------------------------------------------------------
if used UI_CAPHIDE
UI_CAPHIDE:
        cmp  byte [ui_capon],1
        jne  .o
        push ax
        push cx
        push si
        push di
        call UI_CAPBOX          ; DI, CX
        mov  si,ui_capbuf
        cld
        rep  movsb              ; DS:SI -> ES:DI
        mov  byte [ui_capon],0
        pop  di
        pop  si
        pop  cx
        pop  ax
.o:     ret
end if

; ----------------------------------------------------------------------
;@ UI_CAPCHECK from the loop: a caption whose [ui_caphold] ticks are up comes down
;  in:  ES = where it was drawn
;  out: CF = 1 it came down just now (show the picture again)
;  needs: -
;  from: LAB\OWLFLY4\ENGINE\STORY.ASM:3021-3032 CAPTCHECK
; ----------------------------------------------------------------------
if used UI_CAPCHECK
UI_CAPCHECK:
        cmp  byte [ui_capon],1
        jne  .no
        push ax
        call UI_TICK
        sub  ax,[ui_capt]       ; ticks it has been up
        cmp  ax,[ui_caphold]
        pop  ax
        jb   .no
        call UI_CAPHIDE
        stc
        ret
.no:    clc
        ret
end if

; ----------------------------------------------------------------------
;@ UI_CAPWAIT let the caption have its time, then take it down (the last word read)
;  in:  ES = where it was drawn
;  out: - (at once if none is up)
;  needs: show the picture afterwards if ES is a back buffer
;  from: LAB\OWLFLY4\ENGINE\STORY.ASM:3035-3049 CAPTWAIT
; ----------------------------------------------------------------------
if used UI_CAPWAIT
UI_CAPWAIT:
.w:     call UI_CAPCHECK
        jc   .o
        cmp  byte [ui_capon],1
        jne  .o
        call UI_YIELD
        jmp  .w
.o:     ret
end if

; ---- UI_YIELD (inside the kit): give the time slice back (INT 2Fh
;  AX=1680h: DOSBox, Windows, the browser stay awake to keys). All kept.
if used UI_YIELD
UI_YIELD:
        push ax
        mov  ax,1680h
        int  2Fh
        pop  ax
        ret
end if

; ----------------------------------------------------------------------
;@ UI_WAITKEY wait for a key, or AX ticks (0: no limit); the BIOS keys emptied first
;  in:  AX = the most ticks to wait (18 = a second; 0 = for ever)
;  out: AX = the key (AH scan code, AL character), 0 = the time ran out
;  needs: INT 9 not hooked (K_KEYS's KEY_ON hides the BIOS keys: then
;         only the time ends it)
;  from: LAB\OWLFLY4\ENGINE\STORY.ASM:1986-2008 WAITKEY (a second in
;        /AUTO); the flush as docs\guide\INPUT.MD
; ----------------------------------------------------------------------
if used UI_WAITKEY
UI_WAITKEY:
        push bx
        push cx
        mov  cx,ax              ; CX = the limit
.fl:    mov  ah,1
        int  16h                ; anything typed before?
        jz   .go
        xor  ah,ah
        int  16h                ; thrown away
        jmp  .fl
.go:    call UI_TICK
        mov  bx,ax              ; BX = the start
.l:     mov  ah,1
        int  16h
        jnz  .key
        call UI_YIELD
        jcxz .l                 ; no limit
        call UI_TICK
        sub  ax,bx              ; ticks gone
        cmp  ax,cx
        jb   .l
        xor  ax,ax              ; the time ran out
        jmp  .o
.key:   xor  ah,ah
        int  16h                ; AX = the key
        test ax,ax
        jnz  .o
        inc  ax                 ; (a key that reads 0000 is still a key)
.o:     pop  cx
        pop  bx
        ret
end if

; ----------------------------------------------------------------------
;@ UI_MSGBOX  one or two lines in a framed box, shown, then a key or AX ticks
;  in:  SI = the first line, DX = the second (0: none), both 0-ended;
;       AX = ticks to wait (0: until a key); [ui_msgy] [ui_boxc]
;       [ui_boxfr] [ui_txtc], K_TEXT's look; [ui_show] if ES is a buffer
;  out: AX = the key (UI_WAITKEY), 0 = the time ran out. The box stays
;       drawn: draw the picture again after it
;  needs: K_DRAW.INC, K_TEXT.INC
;  from: LAB\OWLFLY4\ENGINE\STORY.ASM:1945-1972 MSGBOX (a band at the
;        top there; a centred box here)
; ----------------------------------------------------------------------
if used UI_MSGBOX
UI_MSGBOX:
        push bx
        push cx
        push dx
        push si
        push di
        push ax                 ; the wait
        mov  di,dx              ; DI = the second line
        call TXT_WIDTH          ; CX = the first's width
        mov  ax,cx
        test di,di
        jz   .w1
        push si
        mov  si,di
        call TXT_WIDTH
        pop  si
        cmp  cx,ax
        jbe  .w1
        mov  ax,cx              ; the wider of the two
.w1:    add  ax,16              ; 8 a side
        cmp  ax,320
        jbe  .w2
        mov  ax,320
.w2:    mov  [ui_bw],ax
        call UI_GLYPHH
        mov  [ui_gh],ax
        mov  cx,ax
        add  cx,8               ; one line and the margins
        test di,di
        jz   .h1
        add  cx,ax              ; + the first line
        add  cx,2               ; and a second line
.h1:    mov  [ui_bh],cx
        mov  ax,320
        sub  ax,[ui_bw]         ; - the box's width
        shr  ax,1               ; centred across
        mov  [ui_bx],ax
        call UI_BOX             ; the box and its frame
        mov  al,[txt_col]
        push ax
        mov  al,[ui_txtc]
        mov  [txt_col],al
        mov  bx,160
        mov  dx,[ui_msgy]
        add  dx,4               ; 4 below the box's top
        call TXT_CENTER         ; SI
        test di,di
        jz   .t2
        add  dx,[ui_gh]         ; a line further
        add  dx,2               ; and a gap
        mov  si,di
        call TXT_CENTER
.t2:    pop  ax
        mov  [txt_col],al
        call UI_SHOW
        pop  ax
        call UI_WAITKEY
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        ret
end if

if used ui_bx
ui_bx   dw 0                    ; UI_BOX: left, top, width, height
ui_by   dw 0
ui_bw   dw 0
ui_bh   dw 0
ui_gh   dw 8                    ; a letter's height
end if

; ---- UI_BOX (inside the kit): [ui_bx],[ui_msgy] (or [ui_by] for the quiz,
;  see UI_BOXAT), [ui_bw] x [ui_bh] in [ui_boxc], framed in [ui_boxfr].
if used UI_BOX
UI_BOX:
        push ax
        mov  ax,[ui_msgy]
        mov  [ui_by],ax
        pop  ax
        call UI_BOXAT
        ret
end if
if used UI_BOXAT
UI_BOXAT:
        push ax
        push bx
        push cx
        push dx
        mov  al,[drw_col]
        push ax
        mov  al,[ui_boxc]
        mov  [drw_col],al
        mov  ax,[ui_bx]
        mov  bx,[ui_by]
        mov  cx,[ui_bw]
        mov  dx,[ui_bh]
        call DRW_RECT
        mov  al,[ui_boxfr]
        mov  [drw_col],al
        mov  ax,[ui_bx]
        call DRW_FRAME
        pop  ax
        mov  [drw_col],al
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret
end if

; ----------------------------------------------------------------------
;@ UI_QUIZ    a question and its answers 1..9 in a box at the foot; the answer's CODE
;  in:  SI = the question: db 'text',0, then each answer dw code, db
;       'text',0, the list ended by dw -1 (at most 9 answers); BX = ticks
;       to wait (0: until answered; when they run out, or Esc, the first
;       answer is taken); [ui_boxc] [ui_boxfr] [ui_txtc]; [ui_show]
;  out: AX = the chosen answer's code, CX = its number (0 = the first)
;  needs: K_DRAW.INC, K_TEXT.INC. The box stays drawn
;  from: LAB\OWLFLY4\ENGINE\STORY.ASM:1527-1640 RUNQUIZ (the number
;        pressed is the code the scene ends with; Esc takes the first)
; ----------------------------------------------------------------------
if used UI_QUIZ
UI_QUIZ:
        push bx
        push dx
        push si
        push di
        mov  [ui_qwait],bx
        mov  [ui_qsrc],si
        ; count the answers
        call TXT_LEN            ; CX = the question's length
        add  si,cx              ; past the question's letters
        inc  si                 ; past its 0
        mov  [ui_qans],si
        xor  dx,dx              ; DX = answers
.c1:    cmp  word [si],-1
        je   .c2
        cmp  dx,9
        jae  .c2
        inc  dx                 ; one answer more
        add  si,2               ; past the code
        call TXT_LEN
        add  si,cx              ; past its letters
        inc  si                 ; past the text
        jmp  .c1
.c2:    mov  [ui_qn],dx
        ; the box: the question and a line an answer
        call UI_GLYPHH
        add  ax,3               ; a line
        mov  [ui_gh],ax
        mov  cx,dx
        inc  cx                 ; lines = answers + 1
        mul  cx                 ; AX = their height (DX = 0)
        add  ax,8               ; margins
        mov  [ui_bh],ax
        mov  word [ui_bx],0
        mov  word [ui_bw],320
        neg  ax                 ; - the box's height
        add  ax,200             ; at the foot
        mov  [ui_by],ax
        call UI_BOXAT
        mov  al,[txt_col]
        push ax
        mov  al,[ui_txtc]
        mov  [txt_col],al
        mov  si,[ui_qsrc]
        mov  bx,8
        mov  dx,[ui_by]
        add  dx,4               ; 4 below the box's top
        call TXT_PUT            ; the question
        mov  si,[ui_qans]
        xor  cx,cx              ; CX = the answer's number
.a1:    cmp  cx,[ui_qn]
        jae  .a2
        add  dx,[ui_gh]         ; a line further
        mov  bx,16
        mov  al,cl
        add  al,'1'             ; its digit
        call TXT_CHAR
        mov  al,' '
        call TXT_CHAR           ; a space
        add  si,2               ; past the code
        call TXT_PUT            ; its text
        push cx
        call TXT_LEN
        add  si,cx              ; past its letters
        inc  si                 ; past its 0
        pop  cx
        inc  cx                 ; the next answer's number
        jmp  .a1
.a2:    pop  ax
        mov  [txt_col],al
        call UI_SHOW
        ; the answer
        call UI_TICK
        mov  [ui_qt],ax
.k1:    mov  ah,1
        int  16h
        jz   .k3
        xor  ah,ah
        int  16h
        cmp  al,27              ; Esc: the first
        je   .first
        sub  al,'1'             ; AL = the answer, 0..
        jb   .k1
        xor  ah,ah
        cmp  ax,[ui_qn]
        jae  .k1
        mov  cx,ax
        jmp  .pick
.k3:    call UI_YIELD
        cmp  word [ui_qwait],0
        je   .k1
        call UI_TICK
        sub  ax,[ui_qt]         ; ticks waited
        cmp  ax,[ui_qwait]
        jb   .k1
.first: xor  cx,cx
.pick:  mov  si,[ui_qans]       ; answer CX -> its code
        mov  dx,cx
.p1:    test dx,dx
        jz   .p2
        add  si,2               ; past the code
        push cx
        call TXT_LEN
        add  si,cx              ; past its letters
        inc  si                 ; past its 0
        pop  cx
        dec  dx                 ; one answer fewer to pass
        jmp  .p1
.p2:    mov  ax,[si]
        pop  di
        pop  si
        pop  dx
        pop  bx
        ret
end if

if used ui_qn
ui_qn    dw 0                   ; UI_QUIZ: the answers
ui_qwait dw 0                   ;  the ticks it waits
ui_qt    dw 0                   ;  the tick it started
ui_qsrc  dw 0                   ;  the question
ui_qans  dw 0                   ;  the first answer
end if

; ----------------------------------------------------------------------
;@ UI_FADEUP  bring the DAC up from [ui_lvl] to the full palette SI, [ui_fstep] levels a tick
;  in:  SI = the palette (768 bytes, 0..63 each), [ui_lvl] [ui_fstep]
;  out: - ([ui_lvl] = 64)
;  needs: K_VGA.INC (VGA_FADE); set [ui_lvl] to 0 and the DAC black
;         (VGA_FADE AL=0) before drawing a picture that comes up
;  from: LAB\OWLFLY4\ENGINE\STORY.ASM:3297-3348 FADEUP (a level a tick),
;        through K_VGA's VGA_FADE (64 levels)
; ----------------------------------------------------------------------
if used UI_FADEUP
UI_FADEUP:
        push ax
.l:     mov  al,[ui_lvl]
        cmp  al,64
        jae  .o
        add  al,[ui_fstep]      ; the next level
        cmp  al,64
        jbe  .s
        mov  al,64
.s:     mov  [ui_lvl],al
        call UI_TICKW           ; one tick
        call VGA_FADE
        jmp  .l
.o:     pop  ax
        ret
end if

; ----------------------------------------------------------------------
;@ UI_FADEDN  take the DAC down from [ui_lvl] to black, [ui_fstep] levels a tick
;  in:  SI = the palette (768 bytes), [ui_lvl] [ui_fstep]
;  out: - ([ui_lvl] = 0: the screen is black, the picture still in memory)
;  needs: K_VGA.INC (VGA_FADE)
;  from: LAB\OWLFLY4\ENGINE\STORY.ASM:3350-3359 FADEDN, through VGA_FADE
; ----------------------------------------------------------------------
if used UI_FADEDN
UI_FADEDN:
        push ax
.l:     mov  al,[ui_lvl]
        test al,al
        jz   .o
        sub  al,[ui_fstep]      ; the next level down
        jnc  .s
        xor  al,al              ; not below black
.s:     mov  [ui_lvl],al
        call UI_TICKW
        call VGA_FADE
        jmp  .l
.o:     pop  ax
        ret
end if

; ---- UI_TICKW (inside the kit): wait for the tick to change. All kept.
if used UI_TICKW
UI_TICKW:
        push ax
        push bx
        call UI_TICK
        mov  bx,ax
.w:     call UI_TICK
        cmp  ax,bx
        je   .w
        pop  bx
        pop  ax
        ret
end if
