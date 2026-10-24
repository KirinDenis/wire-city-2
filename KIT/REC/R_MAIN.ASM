; ============================================================================
;@ R_MAIN     the main loop and its ONE way out: init order, exit order, every layer given back
;  A RECIPE THAT IS ALSO A PROGRAM: it builds and runs as it stands
;  (KIT\MAKEWIN REC R_MAIN, then RUNWIN.ps1 REC R_MAIN proves the way out),
;  and a new game copies it whole and deletes the layers it does not use.
;  Every template (KIT\T_*) has this shape.
;
;  THE ORDER IN - each layer only after what it stands on:
;    0. INT 23h -> an IRET     Ctrl+C / Ctrl+Break would end the program
;                              inside a DOS call, past the way out, with the
;                              screen in 13h and the keyboard hooked. DOS
;                              puts INT 23h back by itself on exit (the PSP
;                              keeps the old one): nothing to restore.
;    1. MEM_INIT               a .COM owns ALL memory: shrink to 64K first,
;                              or every allocation after it fails
;    2. VGA_ON                 13h + 64000 bytes of back buffer (CF: none)
;    3. SB_INIT                64K for the card's ring; CF=1 is fine - no
;                              card, no memory, or the player said no: every
;                              SB_ call is then a quiet no-op
;    4. NETOPEN (E_NET)        CF=1: no IPX - play alone
;    5. KEY_ON                 LAST: any question asked through the BIOS
;                              (a name, a menu) comes before it, and a
;                              failure before it leaves the BIOS keyboard
;  THE LOOP: TIM_STEPS ticks -> the rules once a tick (SPK_TICK in them) ->
;    draw -> VGA_SHOW -> SB_HEAL (and NTX_DRAIN / NTX_SENDST when networked)
;  THE ORDER OUT - ONE label, QUIT, for Esc, game over, /AUTO and every
;  error after step 1. Each closer is safe when its layer never opened and
;  safe twice, so QUIT never asks what was opened:
;    SPK_STOP     first: a speaker note keeps sounding in DOS for ever
;    SB_DONE      the DMA stops reading the ring BEFORE its memory is freed
;                 (and freed it is, by SB_DONE itself); the IRQ as found
;    NETCLOSE     IPX's listens point into OUR memory: left posted, the card
;                 writes the next packet into whatever DOS loads there next
;    KEY_OFF      INT 9 back to the BIOS (the next program needs a keyboard)
;    VGA_OFF      text mode 3 and the buffer freed - last, so what is
;                 printed after it is seen
;    then the words (an error, a score, PASS lines), then INT 21h 4Ch
;  /AUTO: runs 1 s with a drone on the speaker, then QUIT; checks after it
;  that INT 9 is the vector found at the start, the speaker gate is shut,
;  the mode is 3, the card and the socket are closed.
;  calls: K_MEM K_VGA K_KEYS K_TIME K_SPK K_SB K_TEXT, ENGINE\E_NET.INC
;  from: KIT\T_BLANK\T_BLANK.ASM (the loop), KIT\T_NET\T_NET.ASM (NETCLOSE
;        on the way out), KIT\README.TXT (the house rules); the order
;        written out and the INT 23h step new
; ============================================================================
        org  100h
        include '..\..\ENGINE\E_8086.INC'

NETSOCK = 4D4Dh                 ; E_NET wants these before its include
NETLEN  = 4
AUTOT   = 18                    ; /AUTO: a second, then out

start:  call GETAUTO
        mov  ax,3509h           ; (for the /AUTO check: INT 9 as found)
        int  21h
        mov  [old9],bx
        mov  [old9+2],es
        push ds
        pop  es                 ; ES = our segment again
        mov  dx,NOBREAK         ; 0. Ctrl+Break does nothing from now on
        mov  ax,2523h
        int  21h
        call MEM_INIT           ; 1. our 64K, the rest DOS's to give
        jc   nomem
        call VGA_ON             ; 2. 13h + the back buffer
        jc   nomem
        call SB_INIT            ; 3. the card, if any (CF=1: silent, fine)
        call NETOPEN            ; 4. the network, if any (CF=1: alone)
        call KEY_ON             ; 5. our keyboard, last
        mov  ax,2712            ; a drone (A4): proves SPK_STOP shuts it
        call SPK_DRONE
        call TIM_TICK
        mov  [t0],ax
        call TIM_STEPS

frame:  mov  al,SC_ESC
        call KEY_TAP            ; Esc: out by the one way
        jnz  quit
        cmp  byte [auto],0
        je   .run
        call TIM_TICK
        sub  ax,[t0]            ; ticks since the start
        cmp  ax,AUTOT
        jae  quit
.run:   call TIM_STEPS          ; ticks gone by
        mov  cx,ax
        jcxz .draw
.step:  call SPK_TICK           ; ...the game's rules go here, once a tick
        inc  word [steps]       ; (one more tick of rules)
        loop .step
.draw:  push es                 ; ...the picture
        mov  es,[vga_buf]
        mov  al,byte [steps]    ; a colour that changes: it runs
        call VGA_CLS
        pop  es
        call VGA_SHOW
        call SB_HEAL            ; the card's ring renewed
        jmp  frame

nomem:  mov  word [why],t_nomem ; an error: say why after the screen is back
quit:   call SPK_STOP           ; silence first
        call SB_DONE            ; DMA stopped, IRQ as found, ring freed
        call NETCLOSE           ; IPX's listens out of our memory
        call KEY_OFF            ; INT 9 back to the BIOS
        call VGA_OFF            ; text mode 3, the buffer freed
        mov  dx,[why]           ; ...now the words can be read
        or   dx,dx
        jz   .ok
        call TXT_DOS
        mov  ax,4C01h           ; errorlevel 1: it did not run
        int  21h
.ok:    cmp  byte [auto],0
        je   .bye
        call CHECKS
.bye:   mov  ax,4C00h
        int  21h

NOBREAK:iret                    ; INT 23h: Ctrl+Break ignored

; ---- CHECKS (/AUTO): every layer really given back -----------------------
CHECKS: mov  ax,3509h           ; INT 9 is the one found at the start?
        int  21h
        mov  ax,es
        push ds
        pop  es
        mov  si,c_key
        cmp  bx,[old9]
        jne  .k
        cmp  ax,[old9+2]
.k:     call PFE
        in   al,61h             ; the speaker gate: bits 0 and 1 shut?
        and  al,3
        mov  si,c_spk
        cmp  al,0
        call PFE
        mov  ah,0Fh             ; the video mode now
        int  10h
        mov  si,c_mode
        cmp  al,3
        call PFE
        mov  si,c_sb            ; the card closed (or never there)
        cmp  byte [sb_ok],0
        call PFE
        mov  si,c_net           ; the socket closed (or never opened)
        cmp  byte [net_ok],0
        call PFE
        mov  si,c_buf           ; the back buffer given back
        cmp  word [vga_buf],0
        call PFE
        mov  si,c_ran           ; and the loop did run its ticks
        cmp  word [steps],0
        mov  dx,t_pass
        jne  .s
        mov  dx,t_fail
.s:     jmp  PFS
; PFE: PASS if the last compare said equal; SI = the words
PFE:    mov  dx,t_pass
        je   PFS
        mov  dx,t_fail
PFS:    call TXT_DOS
        call TXT_DOSZ
        call TXT_DOSCR
        ret

; ---- GETAUTO: [auto] = 1 if the command line holds /AUTO -----------------
GETAUTO:mov  si,81h
        xor  ch,ch
        mov  cl,[80h]           ; the command line's length
.s:     jcxz .no
        lodsb
        dec  cx                 ; one character read
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

auto    db 0
t0      dw 0
steps   dw 0
why     dw 0                    ; an error's words, 0 none
old9    dw 0,0
t_nomem db 'Not enough memory for the screen buffer.',13,10,'$'
t_pass  db 'PASS R_MAIN $'
t_fail  db 'FAIL R_MAIN $'
c_key   db 'KEY_OFF: INT 9 is the vector found at the start',0
c_spk   db 'SPK_STOP: the speaker gate (port 61h bits 0,1) is shut',0
c_mode  db 'VGA_OFF: the screen is in text mode 3',0
c_sb    db 'SB_DONE: the card is closed (sb_ok 0)',0
c_net   db 'NETCLOSE: the socket is closed (net_ok 0)',0
c_buf   db 'VGA_OFF: the back buffer was given back',0
c_ran   db 'the loop ran its ticks before the way out',0

        include '..\..\KIT\LIB\K_MEM.INC'
        include '..\..\KIT\LIB\K_VGA.INC'
        include '..\..\KIT\LIB\K_KEYS.INC'
        include '..\..\KIT\LIB\K_TIME.INC'
        include '..\..\KIT\LIB\K_TEXT.INC'
        include '..\..\KIT\LIB\K_SPK.INC'
        include '..\..\KIT\LIB\K_SB.INC'
        include '..\..\ENGINE\E_NET.INC'
