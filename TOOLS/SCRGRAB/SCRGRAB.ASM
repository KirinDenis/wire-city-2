; ============================================================================
;  SCRGRAB - capture DOS text screens from a running program.
;
;  WHAT IT IS FOR. Reconstructing a text-mode interface from screenshots is
;  archaeology: you squint at a JPEG and argue about which blue that is. But
;  the machine already knows. Every cell on an 80x25 screen is two bytes in
;  video memory - a glyph index and an attribute - and those two bytes are
;  the answer, exactly, with nothing to interpret.
;
;  So this goes resident, watches for a hotkey, and copies 4000 bytes out of
;  B800 into memory of its own. Run it, start whatever program you want to
;  study, arrange the screen, press the hotkey. Afterwards SCRGRAB /U writes
;  everything captured to disk and unloads.
;
;  HOTKEY: both Shift keys at once.
;
;  WHY BOTH SHIFTS AND NOT SOMETHING WITH A LETTER IN IT. A resident that
;  wants a letter has to read the keyboard port itself, and then it owns the
;  scancode - if it decides the key was not for it, the handler it passes
;  control to reads a port that has already been drained. Every TSR that does
;  this gets away with it, and every one of them is relying on the hardware
;  being forgiving.
;
;  There is nothing to get away with here. This handler calls the BIOS first
;  and only then looks at the shift-state byte the BIOS maintains at
;  0040:0017. The keyboard is handled exactly as it would have been if we
;  were not installed, and both Shift keys together is a combination no
;  program uses for anything.
;
;  WHY IT DOES NOT WRITE THE FILE WHEN YOU PRESS THE KEY. DOS is not
;  reentrant: a resident woken by an interrupt may be standing inside a DOS
;  call already, and calling DOS again from there corrupts it. The usual cure
;  is the InDOS flag and a wait for INT 28h - real work, and needless here.
;  Capturing is a `rep movsw` into our own memory and touches nothing. The
;  disk writing happens in /U, which is an ordinary program in an ordinary
;  context, where DOS is nobody's problem.
;
;  OUTPUT. SHOT00.BIN .. SHOT07.BIN in the current directory, 4000 bytes
;  each: 2000 cells of glyph byte then attribute byte, straight from B800.
;
;  Assemble with MAKE.BAT. 8086 only - see the include below.
; ============================================================================

        format  binary as 'COM'
        org     100h

        include '..\..\ENGINE\E_8086.INC'

MAXFRAMES = 8
FRAMESIZE = 4000                ; 80 * 25 * 2

        jmp     install

; ============================================================================
;  RESIDENT PART - everything from here to imagend stays in memory.
; ============================================================================

; --- the block another copy of this program looks for ------------------------
sig     db      'OWLSCRGRAB1'   ; found through INT 2Fh, see mpx below
count   dw      0               ; frames captured so far
old09   dd      0
old2f   dd      0
armed   db      1               ; shifts must be released before firing again

; ----------------------------------------------------------------------------
;  INT 09h - keyboard.
;
;  The BIOS goes first. By the time we look, 0040:0017 already describes the
;  key that just happened, and the application's keyboard is untouched.
; ----------------------------------------------------------------------------
int09:
        pushf
        call    dword [cs:old09]

        push    ax
        push    ds
        mov     ax, 40h
        mov     ds, ax
        mov     al, [17h]               ; BIOS shift flags
        and     al, 3                   ; bit 0 right shift, bit 1 left shift
        cmp     al, 3
        je      .both

        mov     byte [cs:armed], 1      ; let go - ready for the next one
        jmp     .out

.both:
        cmp     byte [cs:armed], 0
        je      .out                    ; still held down from last time
        mov     byte [cs:armed], 0
        call    capture

.out:
        pop     ds
        pop     ax
        iret

; ----------------------------------------------------------------------------
;  Copy the screen into the next free slot, then beep.
; ----------------------------------------------------------------------------
capture:
        push    bx
        push    cx
        push    dx
        push    si
        push    di
        push    es

        mov     ax, cs
        mov     ds, ax
        mov     bx, [count]
        cmp     bx, MAXFRAMES
        jae     .full

        mov     ax, FRAMESIZE
        mul     bx                      ; dx:ax - the frames all fit in 64K
        mov     di, frames
        add     di, ax
        mov     es, [cs:zero_cs]        ; ES = CS, set up at install time

        mov     ax, 0B800h
        mov     ds, ax
        xor     si, si
        mov     cx, FRAMESIZE / 2
        cld
        rep     movsw

        mov     ax, cs
        mov     ds, ax
        inc     word [count]
        call    beep

.full:
        pop     es
        pop     di
        pop     si
        pop     dx
        pop     cx
        pop     bx
        ret

; ----------------------------------------------------------------------------
;  A short note on the speaker. Without it there is no way to tell a capture
;  from a mistyped shift, and you find out you have eight copies of the same
;  screen only at /U.
; ----------------------------------------------------------------------------
beep:
        push    ax
        push    cx
        mov     al, 0B6h                ; timer 2, square wave
        out     43h, al
        mov     ax, 2280                ; 1193182 / 2280 = about 523 Hz
        out     42h, al
        mov     al, ah
        out     42h, al
        in      al, 61h
        push    ax
        or      al, 3                   ; speaker on, gated by the timer
        out     61h, al
        mov     cx, 0A000h
.wait:  loop    .wait
        pop     ax
        out     61h, al                 ; back exactly as it was
        pop     cx
        pop     ax
        ret

; ----------------------------------------------------------------------------
;  INT 2Fh - how the second copy of this program finds the first.
;
;  AH = MPXID, AL = 0 asks "are you there". We answer AL = FFh and hand back
;  our own segment in ES, which is all /U needs: the frames, the saved
;  vectors and the count all live in it at known offsets.
;
;  Multiplex is the right door for this. Taking an interrupt of our own would
;  mean guessing which one nobody else wanted.
; ----------------------------------------------------------------------------
MPXID = 0C9h

mpx:
        cmp     ah, MPXID
        je      .ours
        jmp     dword [cs:old2f]
.ours:
        or      al, al
        jne     .back
        mov     al, 0FFh
        mov     es, [cs:zero_cs]
.back:
        iret

zero_cs dw      0               ; our own segment, filled in at install

; ============================================================================
;  TRANSIENT PART - runs once, then becomes part of the resident image only
;  because keeping it costs a kilobyte and dropping it costs an argument.
; ============================================================================
install:
        mov     ax, cs
        mov     [zero_cs], ax

        ; Already installed?
        mov     ah, MPXID
        xor     al, al
        int     2Fh
        cmp     al, 0FFh
        je      .present

        ; Unload asked for, but nothing is loaded.
        call    wants_unload
        jc      .not_loaded

        ; --- install ---------------------------------------------------------
        mov     ax, 3509h               ; get INT 09
        int     21h
        mov     word [old09], bx
        mov     word [old09 + 2], es

        mov     ax, 352Fh
        int     21h
        mov     word [old2f], bx
        mov     word [old2f + 2], es

        push    ds
        mov     ax, cs
        mov     ds, ax
        mov     dx, int09
        mov     ax, 2509h
        int     21h
        mov     dx, mpx
        mov     ax, 252Fh
        int     21h
        pop     ds

        mov     dx, msg_in
        call    say

        ; Let go of the handles DOS gave us. A resident keeps its PSP for
        ; ever, and every handle still open in it stays open for ever too -
        ; including the one behind a redirected `>` on the command line, which
        ; is how a resident silently ends up owning somebody's log file. The
        ; message above is already printed, so there is nothing left to say.
        mov     bx, 4
.shut:
        mov     ah, 3Eh
        int     21h
        dec     bx
        jns     .shut

        mov     ax, 3100h               ; terminate, stay resident
        mov     dx, imagend + 15
        mov     cl, 4
        shr     dx, cl
        int     21h

.present:
        ; ES now points at the resident copy.
        call    wants_unload
        jnc     .already
        jmp     unload

.already:
        mov     dx, msg_dup
        call    say
        ret

.not_loaded:
        mov     dx, msg_none
        call    say
        ret

; ----------------------------------------------------------------------------
;  Carry set if the command line asked for /U.
; ----------------------------------------------------------------------------
wants_unload:
        push    si
        push    cx
        mov     si, 81h                 ; command tail in the PSP
        mov     cl, [80h]
        xor     ch, ch
        jcxz    .no
.scan:
        mov     al, [si]
        cmp     al, 'u'
        je      .yes
        cmp     al, 'U'
        je      .yes
        inc     si
        loop    .scan
.no:
        clc
        pop     cx
        pop     si
        ret
.yes:
        stc
        pop     cx
        pop     si
        ret

; ----------------------------------------------------------------------------
;  /U - write every captured frame, put the vectors back, give the memory up.
;
;  ES arrives pointing at the resident copy. Nothing here runs in an
;  interrupt, so DOS may be called freely.
; ----------------------------------------------------------------------------
unload:
        mov     [resseg], es

        ; Refuse if somebody hooked INT 09 after us - putting the old vector
        ; back would cut their handler out of the chain, and they are almost
        ; certainly still running.
        mov     ax, 3509h
        int     21h                     ; ES:BX = current INT 09
        mov     ax, es
        cmp     ax, [resseg]
        jne     .hooked
        cmp     bx, int09
        jne     .hooked

        mov     es, [resseg]
        mov     cx, [es:count]
        mov     [nframes], cx
        jcxz    .empty          ; say so, then unload anyway - see below

        mov     word [frameix], 0
.next:
        mov     bx, [frameix]
        cmp     bx, [nframes]
        jae     .written

        ; SHOTnn.BIN
        mov     al, bl
        add     al, '0'
        mov     [fname + 5], al

        mov     ah, 3Ch                 ; create
        xor     cx, cx
        mov     dx, fname
        int     21h
        jc      .ioerr
        mov     [handle], ax

        ; Where this frame sits inside the resident block.
        mov     ax, FRAMESIZE
        mul     word [frameix]          ; dx:ax - eight frames fit inside 64K
        mov     dx, frames
        add     dx, ax

        push    ds
        mov     ds, [cs:resseg]         ; the bytes live over there, not here
        mov     bx, [cs:handle]
        mov     cx, FRAMESIZE
        mov     ah, 40h                 ; write
        int     21h
        pop     ds
        jc      .ioerr

        mov     bx, [handle]
        mov     ah, 3Eh                 ; close
        int     21h

        mov     dx, fname
        call    say_line

        inc     word [frameix]
        jmp     .next

.written:
        ; Vectors back, memory back.
        mov     es, [resseg]
        push    ds
        mov     ds, [cs:resseg]
        mov     dx, word [old09]
        mov     ax, word [old09 + 2]
        mov     ds, ax
        mov     ax, 2509h
        int     21h
        pop     ds

        push    ds
        mov     ds, [cs:resseg]
        mov     dx, word [old2f]
        mov     ax, word [old2f + 2]
        mov     ds, ax
        mov     ax, 252Fh
        int     21h
        pop     ds

        mov     es, [resseg]
        mov     ah, 49h                 ; free the resident block
        int     21h

        mov     dx, msg_out
        call    say
        ret

; Nothing was captured. Say so and carry on into the unload: /U must always
; leave the machine clean, or a mistyped session ends with a resident nobody
; can get rid of short of rebooting.
.empty:
        mov     dx, msg_empty
        call    say
        jmp     .written

.hooked:
        mov     dx, msg_busy
        call    say
        ret

.ioerr:
        mov     dx, msg_ioerr
        call    say
        ret

; ----------------------------------------------------------------------------
say:
        push    ax
        mov     ah, 9
        int     21h
        pop     ax
        ret

; Print an ASCIIZ name followed by a newline.
say_line:
        push    ax
        push    si
        mov     si, dx
.ch:
        mov     dl, [si]
        or      dl, dl
        jz      .eol
        mov     ah, 2
        int     21h
        inc     si
        jmp     .ch
.eol:
        mov     dl, 13
        mov     ah, 2
        int     21h
        mov     dl, 10
        mov     ah, 2
        int     21h
        pop     si
        pop     ax
        ret

; --- transient data ----------------------------------------------------------
resseg  dw      0
handle  dw      0
nframes dw      0
frameix dw      0
fname   db      'SHOT0 .BIN', 0

msg_in  db      'SCRGRAB resident.  Both Shift keys = capture.', 13, 10
        db      'Up to 8 screens.  SCRGRAB /U writes them out and unloads.', 13, 10, '$'
msg_dup db      'SCRGRAB is already resident.  Use SCRGRAB /U.', 13, 10, '$'
msg_none db     'SCRGRAB is not resident, so there is nothing to unload.', 13, 10, '$'
msg_out db      'Written and unloaded.', 13, 10, '$'
msg_empty db    'No screens were captured.', 13, 10, '$'
msg_busy db     'Another program hooked the keyboard after SCRGRAB.', 13, 10
        db      'Unloading now would cut it out of the chain.  Close it first.', 13, 10, '$'
msg_ioerr db    'Could not write the file - disk full, or read-only?', 13, 10, '$'

; --- the captures ------------------------------------------------------------
; Reserved, not emitted: the .COM on disk stays a couple of kilobytes and the
; room is claimed from DOS by the paragraph count handed to INT 21h/31h.
frames  rb      MAXFRAMES * FRAMESIZE
imagend:
