; ============================================================================
;  VOWV.ASM - KIT test: K_OWV.INC (OWV video and compressed pictures).
;
;      VOWV           plays VTEST.OWV, shows its first frame as a still,
;                     waits for Esc, then prints what it found
;      VOWV /AUTO     the same without the wait: PASS/FAIL lines, then quits
;
;  VTEST.OWV and VTEST.SUM are written by TOOLS\Img2Owv (/test KIT\TEST):
;  a clip that uses every chunk (KEY, DELTA, PALETTE, AUDIO, an unknown
;  one, END) and every block opcode, and the 16-bit sum of every frame as
;  the encoder holds it. The OWV_ONFRAME hook sums each frame the 8086
;  decoder made and compares. VBAD1..VBAD6.OWV are broken files: each must
;  give CF and its error code, never a hang. Last, the decoder runs flat
;  out (no pacing) to say how many frames a second this machine decodes.
; ============================================================================
        org  100h
        include '..\..\ENGINE\E_8086.INC'

start:  cld
        call GETAUTO

; ---- memory -----------------------------------------------------------------
        call OWV_ALLOC
        sbb  ax,ax
        mov  [got],ax
        or   ax,ax
        mov  si,m_alloc
        call RESULT
        cmp  word [fails],0
        je   .unrle
        jmp  quit               ; no memory: nothing else can run

; ---- OWV_UNRLE alone: 82 07 | 02 01 02 03 | 81 09 -> 7 7 7 1 2 3 9 9 -------
.unrle: push ds
        pop  es
        mov  si,rle_in
        mov  di,rle_out
        mov  cx,8
        call OWV_UNRLE
        xor  ax,ax
        cmp  si,rle_in+8        ; read exactly the 8 coded bytes
        jne  .u1
        cmp  di,rle_out+8
        jne  .u1
        or   cx,cx
        jne  .u1
        mov  ax,word [rle_out]
        cmp  ax,0707h
        jne  .u1
        mov  ax,word [rle_out+2]
        cmp  ax,0107h
        jne  .u1
        mov  ax,word [rle_out+4]
        cmp  ax,0302h
        jne  .u1
        mov  ax,word [rle_out+6]
        cmp  ax,0909h
        jne  .u1
        cmp  byte [rle_out+8],0EEh  ; the byte after: untouched
        jne  .u1
        mov  ax,1
.u1:    mov  [got],ax
        cmp  ax,1
        mov  si,m_unrle
        call RESULT

; ---- refused at the door ----------------------------------------------------
        mov  dx,f_none
        call OWV_OPEN
        call ERRCODE
        mov  [got],ax
        cmp  ax,OWV_E_OPEN
        mov  si,m_none
        call RESULT
        mov  dx,f_bad4
        call OWV_OPEN
        call ERRCODE
        mov  [got],ax
        cmp  ax,OWV_E_HDR
        mov  si,m_bad4
        call RESULT
        mov  dx,f_bad5
        call OWV_OPEN
        call ERRCODE
        mov  [got],ax
        cmp  ax,OWV_E_SIZE
        mov  si,m_bad5
        call RESULT
        call OWV_FRAME          ; nothing is open now
        call ERRCODE
        mov  [got],ax
        cmp  ax,OWV_E_SHUT
        mov  si,m_shut
        call RESULT

; ---- broken inside: frames that decoded * 100 + the error -------------------
        mov  dx,f_bad1
        call BADRUN
        mov  [got],ax
        cmp  ax,2*100+OWV_E_SHORT
        mov  si,m_bad1
        call RESULT
        mov  dx,f_bad2
        call BADRUN
        mov  [got],ax
        cmp  ax,1*100+OWV_E_DATA
        mov  si,m_bad2
        call RESULT
        mov  dx,f_bad3
        call BADRUN
        mov  [got],ax
        cmp  ax,0*100+OWV_E_BIG
        mov  si,m_bad3
        call RESULT
        mov  dx,f_bad6
        call BADRUN
        mov  [got],ax
        cmp  ax,1*100+OWV_E_DATA
        mov  si,m_bad6
        call RESULT

; ---- the sums the encoder wrote ---------------------------------------------
        mov  ax,3D00h           ; DOS: open VTEST.SUM
        mov  dx,f_sum
        int  21h
        jc   .nosum
        mov  bx,ax
        mov  cx,2+2*MAXF
        mov  dx,sums
        mov  ah,3Fh             ; DOS: read it
        int  21h
        mov  ah,3Eh             ; DOS: close
        int  21h
.nosum: mov  ax,[sums]          ; the frame count in the file
        mov  [got],ax
        cmp  ax,24
        mov  si,m_sum
        call RESULT

; ---- play it: every frame summed by the hook --------------------------------
        mov  ax,0013h
        int  10h                ; 320x200, a byte a pixel
        mov  dx,f_test
        call OWV_OPEN
        call ERRCODE
        mov  [openres],ax
        jnz  .noplay
        mov  ax,0A000h
        mov  es,ax                 ; frames to the screen
        call OWV_PLAY
        mov  [playres],ax
        pushf
        pop  ax
        and  ax,1
        mov  [playcf],ax        ; CF from OWV_PLAY
        call OWV_CLOSE
.noplay:
; ---- the first frame again, as a still, straight to the screen --------------
        mov  ax,0A000h
        mov  es,ax
        mov  dx,f_test
        call OWV_STILL
        call ERRCODE
        mov  [stillres],ax
        call SCRSUM
        mov  [stillsum],ax
        cmp  byte [auto],1
        je   .noesc
.k:     xor  ah,ah              ; BIOS: wait for a key
        int  16h
        cmp  al,27
        jne  .k
        jmp  .text
.noesc: mov  cx,18              ; hold the still a second
        call HOLD

; ---- flat out: how fast does this machine decode? ---------------------------
        mov  byte [timing],1
        call OWV_TICK
        mov  [t0],ax
        xor  bp,bp              ; BP = frames decoded
        mov  cx,3               ; the clip three times
.again: push cx
        mov  dx,f_test
        call OWV_OPEN
        jc   .tend
.fr:    call OWV_FRAME
        jc   .tend
        or   al,al
        jz   .tend
        call OWV_SHOW
        inc  bp                 ; one more frame
        jmp  .fr
.tend:  call OWV_CLOSE
        pop  cx
        loop .again
        call OWV_TICK
        sub  ax,[t0]            ; AX = ticks it took
        mov  [tticks],ax
        mov  [tframes],bp

.text:  mov  ax,0003h
        int  10h                ; text mode again
        mov  ax,[openres]
        mov  [got],ax
        or   ax,ax
        mov  si,m_open
        call RESULT
        mov  ax,[playcf]
        mov  [got],ax
        or   ax,ax
        mov  si,m_playcf
        call RESULT
        mov  al,byte [playres]
        xor  ah,ah
        mov  [got],ax
        or   ax,ax
        mov  si,m_play
        call RESULT
        mov  ax,[nframes]
        mov  [got],ax
        cmp  ax,24
        mov  si,m_count
        call RESULT
        ; a line a frame: the sum the decoder made against the encoder's
        xor  bx,bx
.fl:    cmp  bx,[nframes]
        jae  .fdone
        cmp  bx,MAXF
        jae  .fdone
        mov  di,bx
        shl  di,1               ; DI = frame * 2: a word each
        mov  ax,[mysums+di]
        mov  [got],ax
        cmp  ax,[sums+2+di]
        pushf
        mov  ax,bx
        inc  ax                 ; frames counted from 1
        mov  di,m_fnum
        call PUTD2
        popf
        mov  si,m_frame
        call RESULTH
        inc  bx
        jmp  .fl
.fdone: mov  ax,[stillres]
        mov  [got],ax
        or   ax,ax
        mov  si,m_still
        call RESULT
        mov  ax,[stillsum]
        mov  [got],ax
        cmp  ax,[sums+2]
        mov  si,m_stills
        call RESULTH
        cmp  byte [timing],1
        jne  quit
        ; frames a second x 10 = frames * 182 / ticks
        mov  dx,m_rate
        mov  ah,9
        int  21h
        mov  ax,[tframes]
        call PUTN
        mov  dx,m_rate2
        mov  ah,9
        int  21h
        mov  ax,[tticks]
        call PUTN
        mov  dx,m_rate3
        mov  ah,9
        int  21h
        mov  cx,[tticks]
        jcxz .nofps             ; no tick passed: no rate (never divide by 0)
        mov  ax,[tframes]
        mov  bx,182
        mul  bx                 ; DX:AX = frames * 182 (tenths of ticks)
        cmp  dx,cx
        jae  .nofps             ; the quotient would not fit a word
        div  cx                 ; AX = frames a second * 10
        xor  dx,dx
        mov  bx,10
        div  bx                 ; AX = whole frames a second, DX = tenths
        push dx
        call PUTN
        mov  dl,'.'
        mov  ah,2
        int  21h
        pop  ax
        call PUTN
.nofps: mov  dx,m_rate4
        mov  ah,9
        int  21h

quit:   mov  ax,[fails]
        mov  [got],ax
        or   ax,ax
        mov  si,m_all
        call RESULT
        mov  ax,4C00h
        int  21h

; ============================================================================
;  The hook: every frame OWV_PLAY shows is summed here. Keeps DS and ES.
; ============================================================================
OWV_ONFRAME:
        mov  bx,[owv_frame]
        dec  bx                 ; BX = this frame's index, from 0
        cmp  bx,MAXF
        jae  .x
        call FRSUM
        shl  bx,1               ; a word each
        mov  [mysums+bx],ax
        shr  bx,1
        inc  bx                 ; BX = frames seen
        mov  [nframes],bx
.x:     clc                     ; CF = 0: play on
        ret

; FRSUM - AX = the 16-bit sum of the 64000 bytes of [owv_cur]
FRSUM:  push bx
        push cx
        push si
        push ds
        mov  ds,[owv_cur]
        jmp  SUMDS
; SCRSUM - AX = the 16-bit sum of the screen's 64000 bytes
SCRSUM: push bx
        push cx
        push si
        push ds
        mov  ax,0A000h
        mov  ds,ax
SUMDS:  xor  si,si
        xor  bx,bx              ; BX = the sum
        xor  ah,ah
        mov  cx,64000
.s:     lodsb
        add  bx,ax              ; the sum, mod 65536
        loop .s
        mov  ax,bx
        pop  ds
        pop  si
        pop  cx
        pop  bx
        ret

; BADRUN - open DS:DX and decode until it stops: AX = good frames * 100 +
; the error code, or 9999 if it ended with no error. At most 100 frames.
BADRUN: push bx
        push cx
        call OWV_OPEN
        jc   .e0
        xor  bx,bx              ; BX = frames that decoded
        mov  cx,100
.f:     call OWV_FRAME
        jc   .e
        or   al,al
        jz   .clean
        inc  bx                 ; one more good frame
        loop .f
.clean: mov  ax,9999
        jmp  .o
.e0:    xor  bx,bx
.e:     xor  ah,ah              ; AX = the code
        push ax
        mov  ax,100
        mul  bx                 ; AX = frames * 100 (BX <= 100: fits)
        pop  bx
        add  ax,bx              ; + the code
.o:     call OWV_CLOSE
        pop  cx
        pop  bx
        ret

; ERRCODE - after a call: AX = AL if CF, else 0; ZF = 1 when 0
ERRCODE:
        jc   .c
        xor  ax,ax
        ret
.c:     xor  ah,ah
        or   ax,ax
        ret

; HOLD - wait CX ticks
HOLD:   call OWV_TICK
        mov  bx,ax
.w:     call OWV_TICK
        sub  ax,bx              ; ticks since
        cmp  ax,cx
        jb   .w
        ret

; ---- the command line ---------------------------------------------------------
GETAUTO:mov  si,81h
        xor  ch,ch
        mov  cl,[80h]           ; the tail's length
.s:     jcxz .no
        lodsb
        dec  cx
        cmp  al,'/'
        jne  .s
        cmp  cx,4
        jb   .no
        mov  ax,[si]
        and  ax,0DFDFh          ; upper case
        cmp  ax,'AU'
        jne  .s
        mov  ax,[si+2]
        and  ax,0DFDFh
        cmp  ax,'TO'
        jne  .s
        mov  byte [auto],1
.no:    ret

; RESULT - ZF = 1 pass: "PASS name = got" (decimal), else FAIL and fails++
RESULT: mov  byte [hex],0
        jmp  RES0
RESULTH:mov  byte [hex],1       ; the same, got in hex
RES0:   jnz  .f
        mov  dx,t_pass
        jmp  .p
.f:     mov  dx,t_fail
        inc  word [fails]       ; one more failure
.p:     mov  ah,9
        int  21h
        call PUTS
        mov  dx,t_got
        mov  ah,9
        int  21h
        mov  ax,[got]
        cmp  byte [hex],1
        je   .h
        call PUTN
        jmp  NL
.h:     call PUTH
NL:     mov  dx,t_nl
        mov  ah,9
        int  21h
        ret

PUTS:   lodsb
        or   al,al
        jz   .d
        mov  dl,al
        mov  ah,2
        int  21h
        jmp  PUTS
.d:     ret

; PUTN - AX as a signed decimal number
PUTN:   push bx
        push cx
        push dx
        or   ax,ax
        jns  .p
        push ax
        mov  dl,'-'
        mov  ah,2
        int  21h
        pop  ax
        neg  ax                 ; AX = |AX|
.p:     xor  cx,cx              ; CX = digits stacked
        mov  bx,10
.d:     xor  dx,dx
        div  bx                 ; AX = AX / 10, DX = the digit (BX = 10)
        push dx
        inc  cx                 ; one more digit
        or   ax,ax
        jnz  .d
.o:     pop  dx
        add  dl,'0'             ; the digit as a character
        mov  ah,2
        int  21h
        loop .o
        pop  dx
        pop  cx
        pop  bx
        ret

; PUTH - AX as four hex digits
PUTH:   push cx
        push dx
        mov  cx,4
.h:     push cx
        mov  cl,4
        rol  ax,cl              ; the top nibble to the bottom
        pop  cx
        push ax
        and  al,0Fh
        add  al,'0'             ; 0..9
        cmp  al,'9'
        jbe  .o
        add  al,7               ; A..F
.o:     mov  dl,al
        mov  ah,2
        int  21h
        pop  ax
        loop .h
        pop  dx
        pop  cx
        ret

; PUTD2 - AX (0..99) as two digits at DS:DI
PUTD2:  push ax
        push bx
        mov  bl,10
        div  bl                 ; AL = tens, AH = ones (AX < 100: fits)
        add  ax,'00'            ; both as characters
        mov  [di],ax
        pop  bx
        pop  ax
        ret

MAXF     = 64
auto     db   0
hex      db   0
timing   db   0
got      dw   0
fails    dw   0
openres  dw   0
playres  dw   0
playcf   dw   0
stillres dw   0
stillsum dw   0
nframes  dw   0
t0       dw   0
tticks   dw   0
tframes  dw   0
rle_in   db   82h,7, 02h,1,2,3, 81h,9, 0AAh,0BBh
rle_out  db   9 dup (0EEh)
f_test   db   'VTEST.OWV',0
f_sum    db   'VTEST.SUM',0
f_none   db   'NOFILE.OWV',0
f_bad1   db   'VBAD1.OWV',0
f_bad2   db   'VBAD2.OWV',0
f_bad3   db   'VBAD3.OWV',0
f_bad4   db   'VBAD4.OWV',0
f_bad5   db   'VBAD5.OWV',0
f_bad6   db   'VBAD6.OWV',0
m_alloc  db   'OWV_ALLOC gets 2 frames + a 64K buffer (CF = 0)',0
m_unrle  db   'OWV_UNRLE 82 07 02 01 02 03 81 09 -> 7 7 7 1 2 3 9 9, SI DI CX right',0
m_none   db   'OWV_OPEN of a missing file: CF, AL = 1',0
m_bad4   db   'OWV_OPEN of VBAD4 (not OWV1): CF, AL = 2',0
m_bad5   db   'OWV_OPEN of VBAD5 (640x400): CF, AL = 3',0
m_shut   db   'OWV_FRAME with no file open: CF, AL = 8',0
m_bad1   db   'VBAD1 (cut inside frame 3): 2 frames, then CF 5 = 205',0
m_bad2   db   'VBAD2 (opcode 90h): 1 frame, then CF 6 = 106',0
m_bad3   db   'VBAD3 (a 70000-byte chunk): CF 4 at once = 4',0
m_bad6   db   'VBAD6 (COPY from outside the frame): 1 frame, then CF 6 = 106',0
m_sum    db   'VTEST.SUM read: frames',0
m_open   db   'OWV_OPEN VTEST.OWV: CF = 0',0
m_playcf db   'OWV_PLAY: CF = 0',0
m_play   db   'OWV_PLAY: AL = 0, the clip ran to its END',0
m_count  db   'OWV_ONFRAME saw 24 frames',0
m_frame  db   'frame '
m_fnum   db   '00 sum as the encoder made it',0
m_still  db   'OWV_STILL VTEST.OWV: CF = 0',0
m_stills db   'OWV_STILL: the screen sums as frame 1',0
m_all    db   'VOWV failures',0
m_rate   db   'decode flat out (FRAME + SHOW to A000h): $'
m_rate2  db   ' frames in $'
m_rate3  db   ' ticks = $'
m_rate4  db   ' frames a second',13,10,'$'
t_pass   db   'PASS $'
t_fail   db   'FAIL $'
t_got    db   ' = $'
t_nl     db   13,10,'$'
sums     dw   0
         dw   MAXF dup (0)
mysums   dw   MAXF dup (0)

        include '..\..\KIT\LIB\K_OWV.INC'
