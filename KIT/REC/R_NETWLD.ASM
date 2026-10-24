; ============================================================================
;@ R_NETWLD   the host's shared world: WSEND/HSEND/SENDM out, WTAKE/WAPPLY in, all checked
;  A RECIPE: copy it into your program and adapt (or include it, as
;  KIT\TEST\NWORLD.ASM does to prove it). The world here is small and
;  generic - a phase, a clock, a score, up to WMAXIT items on a grid of
;  WCELLS cells, the players' names; make it your game's.
;
;  THE RULE: the host owns the world and sends it WHOLE ('W'), on a change
;  and on the beat, so a newcomer has it with the next packet. A client
;  sends a hello on the beat ('H', its name: "I am still here") and its
;  requests ('M', what it wants done); the host decides and the next world
;  shows the result. EVERYTHING off the wire is checked before it is used
;  (MULTSOK2 WAPPLY): a phase we do not have drops the packet, counts and
;  clocks are clamped, a cell off the grid or named twice is left out, a
;  name is made printable - a packet is someone else's word, and a cell
;  past the grid writes over the program's own data.
;
;  DEFINE BEFORE: WPROTO (version byte), WMAXIT (items, <= 255), WCELLS
;    (grid cells), WPHMAX (the last phase), WCLKMAX (the longest clock),
;    WMAXPL (players listed), and for E_NET NETLEN >= W_LEN.
;  CALLS: K_NETX NTX_SENDST, NTX_CLAMPU, NTX_NAME; E_NET NETSEND;
;    with R_NETHST deciding which worlds are taken.
;  YOUR LOOP (a handler for NTX_DRAIN):
;        packet 'W', WPROTO:  call NHWORLD / jc skip / call WAPPLY
;        packet 'H' or 'M' and nh_mode = NH_HOST:  call WTAKE
;      then, the host:  mov al,[wl_dirty] / call WSEND
;            a client:  call HSEND  (and SENDM when a key asks for a move)
;  from: GAMES\MULTSOK2\MULTSOK2.ASM:88-127 (packet layout), 2800-2895
;        (WSEND HSEND SENDM), 2897-3066 (WAPPLY), 2626-2668 (the host's
;        intake), 3112-3127 (COPYNAME -> K_NETX NTX_NAME).
; ============================================================================
W_KIND  = 0                     ; 'W' world, 'H' hello, 'M' a request
W_PROTO = 1                     ; WPROTO: another version is not ours
W_ARG   = 2                     ; 'H': the name, 8 letters; 'M': what
W_PHASE = 2                     ; 'W': byte, 0..WPHMAX
W_NITEM = 3                     ; byte: items listed at W_ITEMS
W_CLOCK = 4                     ; word: ticks left in the phase
W_SCORE = 6                     ; word
W_ITEMS = 8                     ; WMAXIT words: each item's cell
W_PLAY  = W_ITEMS + WMAXIT*2    ; WMAXPL players: name word, 8 letters
W_LEN   = W_PLAY + WMAXPL*10
WPL     = 10                    ; a player's entry
M_TAKE  = 0                     ; 'M' requests: +2 M_TAKE, +3 the item

; ---- WSEND (host): the world, whole, on a change or on the beat ----------
; AL = 1: it changed. CF as NTX_SENDST. Keeps all but flags.
WSEND:  push ax
        push bx
        push cx
        push si
        push di
        mov  di,wl_pkt          ; zeros first: unlisted items are 0
        mov  cx,W_LEN
.z:     mov  byte [di],0
        inc  di                 ; the next byte
        loop .z
        mov  byte [wl_pkt+W_KIND],'W'
        mov  byte [wl_pkt+W_PROTO],WPROTO
        mov  ah,[wl_phase]
        mov  [wl_pkt+W_PHASE],ah
        mov  ah,[wl_nitem]
        mov  [wl_pkt+W_NITEM],ah
        mov  bx,[wl_clock]
        mov  [wl_pkt+W_CLOCK],bx
        mov  bx,[wl_score]
        mov  [wl_pkt+W_SCORE],bx
        mov  si,wl_items        ; the items and the players, as they are
        mov  di,wl_pkt+W_ITEMS
        mov  cx,WMAXIT*2 + WMAXPL*WPL
.c:     mov  ah,[si]
        mov  [di],ah
        inc  si                 ; the next byte
        inc  di
        loop .c
        mov  si,wl_pkt
        call NTX_SENDST         ; AL: changed - at once, else on the beat
        jc   .out
        mov  byte [wl_dirty],0
.out:   pop  di
        pop  si
        pop  cx
        pop  bx
        pop  ax
        ret

; ---- HSEND (client): hello on the beat - our name, "still here" ---------
HSEND:  push ax
        push si
        mov  byte [wl_pkt+W_KIND],'H'
        mov  byte [wl_pkt+W_PROTO],WPROTO
        mov  si,wl_myname
        push di
        mov  di,wl_pkt+W_ARG
        call NTX_NAME           ; printable on the way out too
        pop  di
        mov  si,wl_pkt
        xor  al,al              ; no change: on the beat only
        call NTX_SENDST
        pop  si
        pop  ax
        ret

; ---- SENDM (client): AL = the request, AH = its argument, to the host ---
; One packet, at once - it may be lost: the next world shows whether it
; was done, and a key held sends it again. A request that MUST arrive is
; an event: send it as R_NETST does. Keeps all but flags.
SENDM:  push ax
        push bx
        push cx
        push dx
        push si
        push di
        mov  byte [wl_pkt+W_KIND],'M'
        mov  byte [wl_pkt+W_PROTO],WPROTO
        mov  [wl_pkt+W_ARG],ax  ; +2 what, +3 its argument
        mov  si,wl_pkt
        call NETSEND
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret

; ---- WTAKE (host): AX = who, DI -> his 'H' or 'M' -----------------------
; 'H': his name, printable, in his place on the list (a newcomer gets the
; first free one). 'M': his request checked and done. Clobbers AX BX CX DX SI.
WTAKE:  cmp  byte [di+W_PROTO],WPROTO
        jne  .r
        mov  dx,ax              ; DX = who
        mov  bx,wl_play         ; his entry, or the first free one
        xor  si,si
.f:     cmp  [bx],dx
        je   .have
        cmp  word [bx],0
        jne  .fn
        or   si,si
        jnz  .fn
        mov  si,bx              ; the first free entry, kept
.fn:    add  bx,WPL             ; the next entry
        cmp  bx,wl_play+WMAXPL*WPL
        jb   .f
        or   si,si
        jz   .r                 ; the list is full: he can only watch
        mov  bx,si
        mov  [bx],dx            ; a newcomer
        mov  byte [wl_dirty],1
.have:  cmp  byte [di+W_KIND],'H'
        jne  .m
        push di
        lea  si,[di+W_ARG]      ; his name, made printable
        lea  di,[bx+2]
        call NTX_NAME
        pop  di
        mov  byte [wl_dirty],1  ; (a name that did not change costs a beat)
        ret
.m:     cmp  byte [di+W_KIND],'M'
        jne  .r
        cmp  byte [di+W_ARG],M_TAKE
        jne  .r                 ; no such request: dropped
        mov  al,[di+W_ARG+1]    ; which item - checked against the world
        xor  ah,ah
        cmp  al,[wl_nitem]
        jae  .r                 ; no such item
        mov  si,ax
        shl  si,1               ; a word an item
        dec  byte [wl_nitem]    ; one item fewer: the last takes its place
        mov  bl,[wl_nitem]
        xor  bh,bh
        shl  bx,1               ; the last one's word
        mov  cx,[wl_items+bx]
        mov  [wl_items+si],cx
        mov  word [wl_items+bx],0
        inc  word [wl_score]    ; a point
        mov  byte [wl_dirty],1
.r:     ret

; ---- WAPPLY (client): the host's world (DI -> it) into ours, checked ----
; CF = 1: not a world of this game (dropped whole, ours unchanged).
; Clobbers AX BX CX DX SI.
WAPPLY: cmp  byte [di+W_KIND],'W'
        jne  .bad
        cmp  byte [di+W_PROTO],WPROTO
        jne  .bad
        mov  al,[di+W_PHASE]
        cmp  al,WPHMAX
        ja   .bad               ; a phase we do not have: not our world
        mov  [wl_phase],al
        mov  ax,[di+W_CLOCK]    ; the clock in its range
        xor  bx,bx
        mov  dx,WCLKMAX
        call NTX_CLAMPU
        mov  [wl_clock],ax
        mov  ax,[di+W_SCORE]
        mov  [wl_score],ax      ; any word is a score
        mov  cl,[di+W_NITEM]    ; the items: no more than we hold
        xor  ch,ch
        cmp  cx,WMAXIT
        jbe  .n
        mov  cx,WMAXIT
.n:     lea  si,[di+W_ITEMS]
        xor  bx,bx              ; items taken so far
        jcxz .pl
.i:     mov  ax,[si]
        add  si,2               ; the next item's word
        cmp  ax,WCELLS
        jae  .ix                ; off the grid: left out
        push si
        mov  si,wl_items        ; named twice: left out
        mov  dx,bx
.dup:   or   dx,dx
        jz   .put
        cmp  [si],ax
        je   .dupx
        add  si,2               ; the next one taken
        dec  dx                 ; one fewer to look at
        jmp  .dup
.dupx:  pop  si
        jmp  .ix
.put:   pop  si
        push bx
        shl  bx,1               ; a word an item
        mov  [wl_items+bx],ax
        pop  bx
        inc  bx                 ; one more taken
.ix:    loop .i
.pl:    mov  [wl_nitem],bl
        shl  bx,1               ; the rest of the list cleared
.cl:    cmp  bx,WMAXIT*2
        jae  .pls
        mov  word [wl_items+bx],0
        add  bx,2               ; the next word
        jmp  .cl
.pls:   lea  si,[di+W_PLAY]     ; the players: names made printable
        mov  bx,wl_play
.p:     mov  ax,[si]
        mov  [bx],ax
        push si
        push di
        add  si,2
        lea  di,[bx+2]
        call NTX_NAME
        pop  di
        pop  si
        add  si,WPL             ; the next entry
        add  bx,WPL
        cmp  bx,wl_play+WMAXPL*WPL
        jb   .p
        clc
        ret
.bad:   stc
        ret

wl_phase  db 0                  ; THE WORLD (the host's, or our copy of it)
wl_nitem  db 0
wl_clock  dw 0
wl_score  dw 0
wl_items  dw WMAXIT dup(0)      ; each item's cell
wl_play   db WMAXPL*WPL dup(0)  ; the players: name word, 8 letters
wl_dirty  db 1                  ; the world changed: send it at once
wl_myname db 'PLAYER',0,0       ; our own name (8)
assert NETLEN >= W_LEN          ; E_NET sends NETLEN bytes from it
wl_pkt:   db NETLEN dup(0)
