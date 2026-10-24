; ============================================================================
;@ R_NETAD    announce a game inside a room: an ad a second, a list of games heard, join the first or create
;  A RECIPE: copy it into your program and adapt (or include it, as
;  KIT\TEST\NAD.ASM does to prove it). Rename ad_/AD to your own.
;
;  WHAT IT IS FOR: one room, several games in it at once (two pairs of
;  players, or a game restarted). Each game has a number of its own, the
;  gid, and EVERY packet of the game carries it - a packet of another gid
;  is passed by. The host of each game sends an ad ('G') once a second:
;  its gid, the seed its world is built from (joining is learning the
;  seed: no map transfer), how many play, its name. A newcomer listens
;  AD_LISTEN ticks after the wire named him and takes the FIRST game heard;
;  nothing heard - he creates one: seed = the tick OR 1, gid = his own name.
;  The player presses nothing. Only inside a room: nothing announces a game
;  across rooms (the room is the --net=ROOM the players gave).
;  Whatever shapes the world must travel in the ad, or be equal everywhere
;  (OWL FLY III's detail level built other terrain from the same seed).
;
;  DEFINE BEFORE: AD_PROTO (version byte), AD_MAX (games listed, 4),
;    AD_EVERY (ticks between ads, 18), AD_LISTEN (ticks a join listens, 36),
;    AD_GONE (ticks before a silent game leaves the list, 54); for E_NET
;    NETLEN >= A_LEN (15).
;  CALLS: E_NET NETSEND NETRECV net_ok; K_NETX NTX_NAME, NTX_CLAMPU,
;    ntx_pid (after NTX_WAITNAME / NTX_JOIN named us).
;  YOUR GAME:  after the name -  mov bx,status_or_0 / call ADLISTEN /
;    call ADPICK  (AL = 1 joined: ad_gid, ad_seed are the game's; 0
;    created: we host - build from ad_seed). The host, once a frame:
;    mov al,heads / call ADSEND. Everyone: 'G' packets through ADTAKE.
;  from: GAMES\OWLFLY3\SRC\NET.INC:398-458 NETADS (the ad), 485-557 the
;        'G' intake into GLIST; UI.INC:793-870 XMENU (listen, first row
;        wins, else mint); docs\guide\NET.MD "Who hosts what".
; ============================================================================
A_KIND  = 0                     ; 'G'
A_PROTO = 1                     ; AD_PROTO
A_GID   = 2                     ; word: the game's number, never 0
A_SEED  = 4                     ; word: its world's seed
A_HEADS = 6                     ; byte: players in it
A_NAME  = 7                     ; 8 letters
A_LEN   = 15
; a row of the list of games heard
AR_GID  = 0                     ; word, 0 = an empty row
AR_SEED = 2
AR_HEAD = 4                     ; byte
AR_TICK = 6                     ; word: when its ad came
AR_NAME = 8                     ; 8 letters, printable
AR_SIZE = 16

if ~ defined AD_MAX | defined ad_maxdef
ad_maxdef = 1
AD_MAX = 4
end if
if ~ defined AD_EVERY | defined ad_everydef
ad_everydef = 1
AD_EVERY = 18
end if
if ~ defined AD_LISTEN | defined ad_listendef
ad_listendef = 1
AD_LISTEN = 36
end if
if ~ defined AD_GONE | defined ad_gonedef
ad_gonedef = 1
AD_GONE = 54
end if

; ---- ADSEND (host): the ad, every AD_EVERY ticks. AL = heads ------------
; CF = 1: not sent (not due, or dropped). Keeps all but flags.
ADSEND: push ax
        push bx
        push cx
        push dx
        push si
        push di
        mov  [ad_pkt+A_HEADS],al
        call ad_now
        mov  bx,ax
        sub  bx,[ad_sent]       ; ticks since the last ad
        cmp  bx,AD_EVERY
        jb   .no
        mov  [ad_sent],ax
        mov  byte [ad_pkt+A_KIND],'G'
        mov  byte [ad_pkt+A_PROTO],AD_PROTO
        mov  ax,[ad_gid]
        mov  [ad_pkt+A_GID],ax
        mov  ax,[ad_seed]
        mov  [ad_pkt+A_SEED],ax
        mov  si,ad_name
        mov  di,ad_pkt+A_NAME
        call NTX_NAME
        mov  si,ad_pkt
        call NETSEND
        jmp  .out
.no:    stc
.out:   pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret

; ---- ADTAKE: DI -> a packet; a 'G' goes into the list (an NTX_DRAIN
; handler). A known gid is refreshed, a new one takes an empty row; the
; list full - passed by. Clobbers AX BX CX DX SI.
ADTAKE: cmp  byte [di+A_KIND],'G'
        jne  .r
        cmp  byte [di+A_PROTO],AD_PROTO
        jne  .r
        mov  dx,[di+A_GID]
        or   dx,dx
        jz   .r                 ; 0 is no game
        mov  bx,ad_list
        xor  si,si              ; the first empty row
.f:     cmp  [bx+AR_GID],dx
        je   .up                ; known: refreshed
        cmp  word [bx+AR_GID],0
        jne  .fn
        or   si,si
        jnz  .fn
        mov  si,bx
.fn:    add  bx,AR_SIZE         ; the next row
        cmp  bx,ad_list+AD_MAX*AR_SIZE
        jb   .f
        or   si,si
        jz   .r                 ; the board is full: let it pass
        mov  bx,si
.up:    mov  [bx+AR_GID],dx
        mov  ax,[di+A_SEED]
        mov  [bx+AR_SEED],ax
        mov  al,[di+A_HEADS]    ; heads 1..16: a room holds 16
        xor  ah,ah
        push bx
        mov  bx,1
        mov  dx,16
        call NTX_CLAMPU
        pop  bx
        mov  [bx+AR_HEAD],al
        call ad_now
        mov  [bx+AR_TICK],ax
        push di
        lea  si,[di+A_NAME]
        lea  di,[bx+AR_NAME]
        call NTX_NAME           ; printable: it will be shown
        pop  di
.r:     ret

; ---- ADSTALE: games not heard for AD_GONE ticks off the list -----------
; Keeps all but flags.
ADSTALE:push ax
        push bx
        push cx
        call ad_now
        mov  cx,ax
        mov  bx,ad_list
.l:     cmp  word [bx+AR_GID],0
        je   .n
        mov  ax,cx
        sub  ax,[bx+AR_TICK]    ; ticks since its ad
        cmp  ax,AD_GONE
        jb   .n
        mov  word [bx+AR_GID],0 ; gone quiet: off the board
.n:     add  bx,AR_SIZE         ; the next row
        cmp  bx,ad_list+AD_MAX*AR_SIZE
        jb   .l
        pop  cx
        pop  bx
        pop  ax
        ret

; ---- ADLISTEN: the list emptied, then AD_LISTEN ticks of ads heard ------
; BX = a status routine (AL = ticks left) or 0; it may change any register
; but SP and the segments. Other packets are dropped. AL = 1: Esc pressed
; (you quit), else 0. With no IPX it returns at once. Clobbers the rest
; but BP and the segments.
ADLISTEN:
        mov  [ad_stat],bx
        mov  di,ad_list         ; nothing heard yet
        mov  cx,AD_MAX*AR_SIZE
.z:     mov  byte [di],0
        inc  di                 ; the next byte
        loop .z
        cmp  byte [net_ok],0
        je   .done              ; no IPX: nobody to hear
        call ad_now
        mov  [ad_t0],ax
.l:     mov  ax,1680h           ; the time slice back (NET.MD: a waiting
        int  2Fh                ;  loop yields, or the browser starves)
.rx:    call NETRECV            ; CF=0: DI -> NETIN
        jc   .key
        call ADTAKE
        jmp  .rx
.key:   mov  ah,1               ; Esc?
        int  16h
        jz   .clk
        xor  ah,ah
        int  16h
        cmp  al,27
        jne  .clk
        mov  al,1
        ret
.clk:   call ad_now
        sub  ax,[ad_t0]         ; ticks listened
        cmp  ax,AD_LISTEN
        jae  .done
        cmp  word [ad_stat],0
        je   .l
        mov  cx,AD_LISTEN
        sub  cx,ax              ; ticks left, above 0
        mov  al,cl
        push bp
        call word [ad_stat]
        pop  bp
        jmp  .l
.done:  xor  al,al
        ret

; ---- ADPICK: join the first game listed, else create one ---------------
; AL = 1 joined (ad_gid, ad_seed: the game's - build its world from the
; seed), 0 created (ad_gid = our name, ad_seed = the tick OR 1, we host
; and send the ad). Keeps all but AX and flags.
ADPICK: push bx
        mov  bx,ad_list
.l:     cmp  word [bx+AR_GID],0
        jne  .join              ; the first row heard wins
        add  bx,AR_SIZE         ; the next row
        cmp  bx,ad_list+AD_MAX*AR_SIZE
        jb   .l
        call ad_now             ; nobody: ours to make
        or   ax,1               ; a seed, never 0
        mov  [ad_seed],ax
        mov  ax,[ntx_pid]       ; the gid: our own name (never another's)
        or   ax,ax
        jnz  .g
        inc  ax                 ; alone: 1
.g:     mov  [ad_gid],ax
        xor  al,al
        pop  bx
        ret
.join:  mov  ax,[bx+AR_GID]
        mov  [ad_gid],ax
        mov  ax,[bx+AR_SEED]
        mov  [ad_seed],ax
        mov  al,1
        pop  bx
        ret

ad_now: push ds                 ; AX = the BIOS tick's low word
        xor  ax,ax
        mov  ds,ax
        mov  ax,[046Ch]
        pop  ds
        ret

ad_gid   dw 0                   ; OUR game: its number,
ad_seed  dw 0                   ;  its seed,
ad_name  db 'MY GAME',0         ;  its name (8)
ad_sent  dw 0                   ; the tick of the last ad
ad_t0    dw 0
ad_stat  dw 0
ad_list  db AD_MAX*AR_SIZE dup(0) ; the games heard
assert NETLEN >= A_LEN           ; E_NET sends NETLEN bytes from it
ad_pkt:  db NETLEN dup(0)
