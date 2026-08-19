; ============================================================================
;  DRAW7.INC - the small routines lesson 7 leans on.
;
;  Two screens, and the same idea twice. The text screen at B800 holds TWO
;  bytes a cell - the character and its colour - so a row of it is 160 bytes
;  and not 80. The graphics screen at A000 holds ONE byte a pixel, so a row
;  is 320. Both fold; only the number differs.
;
;  Everything here writes through ES:DI, so whoever calls it has already
;  pointed ES at the screen it means.
; ============================================================================

attr    db 07h                  ; the colour the next character is written in
rows    dw 0                    ; how many rows a box or a frame has
lsave   dw 0

; ---- one character at ES:DI, in [attr], and DI moves on --------------------
PutC:   mov  ah, [attr]
        stosw                   ; character AND colour, in one instruction
        ret

; ---- an asciiz string at ES:DI ---------------------------------------------
PutS:   lodsb
        or   al, al
        jz   .done
        mov  ah, [attr]
        stosw
        jmp  PutS
.done:  ret

; ---- a number 0..99, right-aligned in two characters -----------------------
PutN:   xor  ah, ah
        mov  bl, 10
        div  bl                 ; AL = tens, AH = units (lesson 4's trick)
        mov  bh, ah             ; keep the units, DIV has just eaten AH
        or   al, al
        jz   .space             ; no leading zero: a nine is " 9", not "09"
        add  al, '0'
        jmp  .put
.space: mov  al, ' '
.put:   call PutC
        mov  al, bh
        add  al, '0'
        call PutC
        ret

; ---- the whole text screen, blank -------------------------------------------
TClear: xor  di, di
        mov  cx, 80*25
        mov  ax, 0720h          ; a space, in grey on black
        rep  stosw
        ret

; ---- the whole graphics screen, black --------------------------------------
GClear: xor  di, di
        xor  ax, ax
        mov  cx, W*H/2          ; words, because STOSW writes two bytes
        rep  stosw
        ret

; ---- no cursor, so nothing blinks through the explanation ------------------
TextOff:
        mov  ah, 1
        mov  cx, 2000h          ; bit 5 of CH turns it off
        int  10h
        ret

; ---- wait for a key, and wait a moment -------------------------------------
Key:    mov  ah, 0
        int  16h
        ret

; A fifth of a second, off the BIOS tick at 0040:006C - the same clock the
; whole PC counts on, eighteen and a bit times a second. (It wraps at
; midnight; nothing here is running at midnight.)
Hold:   push es
        mov  ax, 0040h
        mov  es, ax
        mov  bx, [es:6Ch]
        add  bx, 4
.wait:  mov  ax, [es:6Ch]
        cmp  ax, bx
        jb   .wait
        pop  es
        ret

; ---- a horizontal line: lx, ly, llen, col ----------------------------------
;  THE POINT OF THE LESSON. The bytes of this line are NEIGHBOURS, so the
;  whole run is one REP STOSB - the processor writes it without the loop
;  ever coming back to us.
HLine:  mov  ax, [ly]
        mov  bx, W
        mul  bx                 ; y * 320 ...
        add  ax, [lx]           ; ... + x
        mov  di, ax
        mov  cx, [llen]
        mov  al, [col]
        rep  stosb
        ret

; ---- a vertical line: lx, ly, llen, col ------------------------------------
;  The same number of pixels, and never neighbours: each is 320 bytes past
;  the last. So there is no REP to be had - it is a loop, and an ADD.
VLine:  mov  ax, [ly]
        mov  bx, W
        mul  bx
        add  ax, [lx]
        mov  di, ax
        mov  cx, [llen]
        mov  al, [col]
.down:  mov  [es:di], al
        add  di, W              ; the pixel below is 320 bytes further on
        loop .down
        ret

; ---- a filled box: a horizontal line, done CX times ------------------------
Box:    mov  [rows], cx
.r:     call HLine
        inc  word [ly]
        dec  word [rows]
        jnz  .r
        ret

; ---- and a window is a box with four lines round it ------------------------
Frame:  mov  [rows], cx
        mov  ax, [llen]
        mov  [lsave], ax
        call HLine              ; the top
        mov  bx, [ly]
        mov  ax, bx
        add  ax, [rows]
        dec  ax
        mov  [ly], ax
        call HLine              ; the bottom
        mov  [ly], bx           ; back up to the top for the sides
        mov  ax, [rows]
        mov  [llen], ax
        call VLine              ; the left
        mov  ax, [lx]
        add  ax, [lsave]
        dec  ax
        mov  [lx], ax
        call VLine              ; the right
        ret
