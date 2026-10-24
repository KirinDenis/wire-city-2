; ============================================================================
;  K_KEYS.INC - KIT: the keyboard for play. Our own INT 9 handler keeps two
;  tables of 128 bytes, one per scan code:
;     key_held[sc] = 1 while the key is down     - stick, throttle, arrows
;     key_hit[sc]  = 1 from its press until read - switches, menus, "fire"
;  The second is the LATCH: at a low frame rate a key pressed and released
;  between two frames never shows in key_held, and must not be lost.
;  The latch is set on a key's first make only - typematic repeat while it
;  is held does not re-arm it, so a toggle read by KEY_TAP fires once a press.
;
;        call KEY_ON             ; hook INT 9 - AFTER any BIOS-read menu
;        ...  mov al,SC_SPACE / call KEY_TAP / jnz .fire
;        ...  cmp byte [key_held+SC_UP],0 / jne .climb   (a direct read)
;        call KEY_OFF            ; on EVERY way out, before the exit
;
;  While hooked the handler does not chain: the BIOS buffer stays empty
;  (KEY_WAIT/KEY_PEEK then read the latches instead). Grey arrows and the
;  keypad share cells (E0 prefixes are ignored). Ctrl+Break before KEY_ON
;  can still end the program through INT 23h past your exit path.
;  Guide topic INPUT.
; ============================================================================

; ---- scan codes (the codes in key_held / key_hit, and in AH from INT 16h) ---
;@ SC_*       scan-code equates: SC_ESC SC_UP SC_DN SC_LF SC_RT SC_SPACE SC_A..
SC_ESC   = 01h
SC_1     = 02h
SC_2     = 03h
SC_3     = 04h
SC_4     = 05h
SC_5     = 06h
SC_6     = 07h
SC_7     = 08h
SC_8     = 09h
SC_9     = 0Ah
SC_0     = 0Bh
SC_MINUS = 0Ch
SC_EQ    = 0Dh
SC_BS    = 0Eh
SC_TAB   = 0Fh
SC_Q     = 10h
SC_W     = 11h
SC_E     = 12h
SC_R     = 13h
SC_T     = 14h
SC_Y     = 15h
SC_U     = 16h
SC_I     = 17h
SC_O     = 18h
SC_P     = 19h
SC_ENTER = 1Ch
SC_CTRL  = 1Dh
SC_A     = 1Eh
SC_S     = 1Fh
SC_D     = 20h
SC_F     = 21h
SC_G     = 22h
SC_H     = 23h
SC_J     = 24h
SC_K     = 25h
SC_L     = 26h
SC_LSHFT = 2Ah
SC_Z     = 2Ch
SC_X     = 2Dh
SC_C     = 2Eh
SC_V     = 2Fh
SC_B     = 30h
SC_N     = 31h
SC_M     = 32h
SC_RSHFT = 36h
SC_ALT   = 38h
SC_SPACE = 39h
SC_F1    = 3Bh
SC_F2    = 3Ch
SC_F3    = 3Dh
SC_F4    = 3Eh
SC_F5    = 3Fh
SC_F6    = 40h
SC_F7    = 41h
SC_F8    = 42h
SC_F9    = 43h
SC_F10   = 44h
SC_HOME  = 47h
SC_UP    = 48h
SC_PGUP  = 49h
SC_LF    = 4Bh                  ; left arrow
SC_RT    = 4Dh                  ; right arrow
SC_END   = 4Fh
SC_DN    = 50h                  ; down arrow
SC_PGDN  = 51h
SC_INS   = 52h
SC_DEL   = 53h
SC_F11   = 57h
SC_F12   = 58h

; ---- the tables (they exist once anything of the file is used) -------------
if used key_held | used key_hit
key_held db 128 dup(0)          ; 1 = the key is down now
key_hit  db 128 dup(0)          ; 1 = pressed since its consumer last looked
end if
if used key_onf | used key_old9
key_old9 dw 0,0                 ; the BIOS's INT 9, offset and segment
key_onf  db 0                   ; 1 = KEY_ON's handler is in
end if

; ----------------------------------------------------------------------
;@ KEY_ON     hook INT 9: from now on key_held / key_hit follow the keys
;  in:  -
;  out: - (a second call does nothing)
;  needs: KEY_OFF on every way out - the vector must be given back
;  from: LESSONS\L11\KEYS.ASM:295-307 (hook); the handler GAMES\OWLFLY3\
;        SRC\KEYB.INC:6-34 (KBINT + KHIT latch), the latch now set on the
;        first make only, E0/E1 prefixes skipped, the XT port-61h ack added
; ----------------------------------------------------------------------
if used KEY_ON
KEY_ON:
        cmp  byte [key_onf],0   ; hooked already?
        jne  .done
        push ax
        push es
        xor  ax,ax
        mov  es,ax              ; ES = 0: the interrupt vector table
        cli                     ; half a vector is a jump into nowhere
        mov  ax,[es:9*4]
        mov  [key_old9],ax      ; the old offset, kept
        mov  ax,[es:9*4+2]
        mov  [key_old9+2],ax    ; the old segment, kept
        mov  word [es:9*4],KEY_INT9
        mov  [es:9*4+2],cs      ; vector 9 = ours
        mov  byte [key_onf],1
        sti
        pop  es
        pop  ax
.done:  ret

; the handler: one scan code a call, from port 60h
KEY_INT9:
        push ax
        push bx
        push ds
        push cs
        pop  ds                 ; DS = ours (the interrupted code's may be any)
        in   al,60h             ; AL = the scan code; bit 7 = released
        mov  ah,al              ; AH = it, kept for bit 7
        in   al,61h             ; acknowledge to an XT's keyboard interface
        or   al,80h             ;  (pulse port 61h bit 7) - harmless on an AT
        out  61h,al
        and  al,7Fh
        out  61h,al
        cmp  ah,0E0h            ; E0 / E1: a prefix, not a key
        jae  .eoi
        mov  bl,ah
        and  bx,7Fh             ; BX = the scan code without bit 7
        test ah,80h             ; released?
        jnz  .brk
        cmp  byte [key_held+bx],0  ; held already: typematic repeat,
        jne  .eoi               ;  no new press to latch
        mov  byte [key_held+bx],1  ; down
        mov  byte [key_hit+bx],1   ; and latched: only its consumer clears it
        jmp  .eoi
.brk:   mov  byte [key_held+bx],0  ; up (the latch stays)
.eoi:   mov  al,20h
        out  20h,al             ; end of interrupt to the PIC
        pop  ds
        pop  bx
        pop  ax
        iret
end if

; ----------------------------------------------------------------------
;@ KEY_OFF    give INT 9 back to the BIOS (safe to call when not hooked)
;  in:  -
;  out: - (the BIOS key buffer is emptied, held keys forgotten)
;  needs: -
;  from: LESSONS\L11\KEYS.ASM:339-346
; ----------------------------------------------------------------------
if used KEY_OFF
KEY_OFF:
        cmp  byte [key_onf],0   ; ours in?
        je   .done
        push ax
        push es
        xor  ax,ax
        mov  es,ax              ; ES = the vector table
        cli
        mov  ax,[key_old9]
        mov  [es:9*4],ax        ; the old offset back
        mov  ax,[key_old9+2]
        mov  [es:9*4+2],ax      ; the old segment back
        mov  byte [key_onf],0
        sti
        pop  es
        pop  ax
        call KEY_FLUSH          ; nothing stale for DOS or the next screen
.done:  ret
end if

; ----------------------------------------------------------------------
;@ KEY_HELD   is the key AL down now?  NZ = held
;  in:  AL = scan code (SC_UP...)
;  out: ZF = 0 held, ZF = 1 not
;  needs: KEY_ON (or KEY_REMOTE feeding the table)
;  from: LESSONS\L11\KEYS.ASM (cmp byte [keys+48h],0)
; ----------------------------------------------------------------------
if used KEY_HELD
KEY_HELD:
        push bx
        mov  bl,al
        and  bx,7Fh             ; BX = the scan code, inside the table
        cmp  byte [key_held+bx],0  ; ZF = 1: up
        pop  bx                 ; (POP keeps the flags)
        ret
end if

; ----------------------------------------------------------------------
;@ KEY_TAP    was key AL pressed since last asked? NZ = yes (latch consumed)
;  in:  AL = scan code
;  out: ZF = 0 pressed (a tap between frames counts), ZF = 1 not
;  needs: KEY_ON; clear old latches (KEY_FLUSH) when a new screen starts
;  from: GAMES\OWLFLY3\SRC\FLIGHT.INC:533-535 (the KHIT consumer)
; ----------------------------------------------------------------------
if used KEY_TAP
KEY_TAP:
        push bx
        mov  bl,al
        and  bx,7Fh             ; BX = the scan code
        cmp  byte [key_hit+bx],0   ; latched?
        je   .no                ;   no: ZF = 1
        mov  byte [key_hit+bx],0   ; consumed
        or   bl,1               ; ZF = 0 (BL is popped next)
.no:    pop  bx
        ret
end if

; ----------------------------------------------------------------------
;@ KEY_NEW    AX = a key newly down since the last call (0 none), one a call
;  in:  -
;  out: AX = scan code (AH = 0), or 0; ZF = 1 when 0
;  needs: KEY_ON. Edge of key_held: misses a tap shorter than a frame
;         (use KEY_ANY / KEY_TAP for those)
;  from: GAMES\OWLFLY3\SRC\UI.INC:439-460 (UEDGE), all 127 codes
; ----------------------------------------------------------------------
if used KEY_NEW
KEY_NEW:
        push si
        mov  si,1               ; from scan code 1 (Esc)
.s:     cmp  byte [key_held+si],0
        je   .up
        cmp  byte [key_prev+si],0
        jne  .nx                ; still held from before
        mov  byte [key_prev+si],1
        mov  ax,si              ; a fresh press: report it
        or   ax,ax              ; ZF = 0
        pop  si
        ret
.up:    mov  byte [key_prev+si],0
.nx:    inc  si
        cmp  si,80h
        jb   .s
        xor  ax,ax              ; none: AX = 0, ZF = 1
        pop  si
        ret
key_prev db 128 dup(0)          ; key_held as KEY_NEW last saw it
end if

; ----------------------------------------------------------------------
;@ KEY_ANY    AL = any key pressed since last asked (0 none); clears all latches
;  in:  -
;  out: AL = the lowest latched scan code, or 0; ZF = 1 when 0
;  needs: KEY_ON. For "press any key": KEY_FLUSH when the screen starts
;  from: new (a sweep of the KHIT latch table)
; ----------------------------------------------------------------------
if used KEY_ANY
KEY_ANY:
        push bx
        push cx
        xor  cx,cx              ; CL = the answer: none yet
        mov  bx,7Fh             ; from the top down: the lowest is kept last
.s:     cmp  byte [key_hit+bx],0
        je   .nx
        mov  byte [key_hit+bx],0   ; consumed
        mov  cl,bl              ; CL = this one
.nx:    dec  bx
        jnz  .s                 ; 7Fh..1 (0 is no key)
        mov  al,cl              ; AL = the answer
        or   al,al              ; ZF = 1 when none
        pop  cx
        pop  bx
        ret
end if

; ----------------------------------------------------------------------
;@ KEY_FLUSH  empty the BIOS key buffer and every latch (a screen starts)
;  in:  -
;  out: -
;  needs: -
;  from: GAMES\MULTSOK2\MULTSOK2.ASM:1627-1635 (FLUSHKB) + the latches
; ----------------------------------------------------------------------
if used KEY_FLUSH
KEY_FLUSH:
        push ax
        push cx
        push di
        push es
        xor  ax,ax
        mov  es,ax              ; ES = 0: the BIOS data at 0000:0400
        cli
        mov  ax,[es:041Ah]      ; the buffer's head
        mov  [es:041Ch],ax      ; its tail = its head: empty
        sti
        push ds
        pop  es                 ; ES = ours
        mov  di,key_hit
        mov  cx,64              ; 128 bytes = 64 words
        xor  ax,ax
        cld
        rep  stosw              ; every latch cleared
        pop  es
        pop  di
        pop  cx
        pop  ax
        ret
end if

; ----------------------------------------------------------------------
;@ KEY_WAIT   wait for a key -> AH = scan code, AL = character (menus)
;  in:  -
;  out: AX = the key. Hooked (KEY_ON): AH = scan, AL = 0 (no characters)
;  needs: - (the BIOS path when not hooked, the latches when hooked)
;  from: INT 16h AH=0 (LESSONS\L20\FLY.ASM:523) + KEY_ANY when hooked
; ----------------------------------------------------------------------
if used KEY_WAIT
KEY_WAIT:
        cmp  byte [key_onf],0   ; is ours in?
        jne  .ours
        mov  ah,0               ; BIOS: wait for a key, take it
        int  16h                ; AH = scan, AL = character
        ret
.ours:  call KEY_ANY            ; AL = a latched press, or 0
        jnz  .got
        sti
        hlt                     ; sleep to the next interrupt: key or tick
        jmp  .ours
.got:   mov  ah,al              ; AH = the scan code
        xor  al,al              ; AL = no character
        ret
end if

; ----------------------------------------------------------------------
;@ KEY_PEEK   is a key waiting? NZ + AX = it, left where it is
;  in:  -
;  out: ZF = 0 a key waits, AX = AH scan / AL character (hooked: AL = 0)
;       ZF = 1 none (AX = 0)
;  needs: -
;  from: INT 16h AH=1 (LESSONS\L20\FLY.ASM:523) + the latch table
; ----------------------------------------------------------------------
if used KEY_PEEK
KEY_PEEK:
        cmp  byte [key_onf],0
        jne  .ours
        mov  ah,1               ; BIOS: anything there? ZF = 1 nothing
        int  16h
        jnz  .yes
        xor  ax,ax              ; none: AX = 0, ZF = 1
        ret
.yes:   ret
.ours:  push bx
        mov  bx,1
.s:     cmp  byte [key_hit+bx],0   ; latched, not consumed
        jne  .hit
        inc  bx
        cmp  bx,80h
        jb   .s
        pop  bx
        xor  ax,ax              ; none: ZF = 1
        ret
.hit:   mov  ah,bl              ; AH = scan
        xor  al,al
        or   ah,ah              ; ZF = 0
        pop  bx
        ret
end if

; ----------------------------------------------------------------------
;@ KEY_REMOTE feed keys from the BIOS buffer into key_held (scripted input)
;  in:  - (call once a frame; a key put in the BIOS buffer - INT 16h 05h,
;        a test rig, a replay - is held for [key_rhold] frames and latched)
;  out: -
;  needs: the tables (KEY_ON or not: hooked, the BIOS buffer only fills
;         by INT 16h 05h)
;  from: LESSONS\L20\FLY.ASM:523-554 (REMOTE), + the latch
; ----------------------------------------------------------------------
if used KEY_REMOTE
KEY_REMOTE:
        push ax
        push bx
        mov  ah,1               ; anything in the BIOS buffer?
        int  16h                ; ZF = 1 nothing
        jz   .hold
        mov  ah,0               ; take it out
        int  16h                ; AH = scan code
        mov  bl,[key_rkey]      ; a key still held from before?
        or   bl,bl
        jz   .new
        xor  bh,bh
        mov  byte [key_held+bx],0  ; let the old one go
.new:   and  ah,7Fh
        mov  [key_rkey],ah      ; the key now fed
        mov  al,[key_rhmax]
        mov  [key_rhold],al     ; held this many frames
        mov  bl,ah
        xor  bh,bh
        mov  byte [key_hit+bx],1   ; latched, like a real press
.hold:  cmp  byte [key_rhold],0 ; still holding one?
        je   .let
        dec  byte [key_rhold]   ; one frame fewer
        mov  bl,[key_rkey]
        xor  bh,bh
        mov  byte [key_held+bx],1  ; held, this frame too
        jmp  .done
.let:   mov  bl,[key_rkey]
        or   bl,bl              ; any at all?
        jz   .done
        xor  bh,bh
        mov  byte [key_held+bx],0  ; let go
        mov  byte [key_rkey],0     ; and forgotten
.done:  pop  bx
        pop  ax
        ret
key_rkey  db 0                  ; the scan code being fed
key_rhold db 0                  ; frames it stays held
key_rhmax db 20                 ; how long a fed key is held (FLY's RHOLD)
end if
