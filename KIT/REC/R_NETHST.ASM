; ============================================================================
;@ R_NETHST  who hosts the shared world: two hosts merge to the lower, a quiet host is replaced
;  A RECIPE: copy it into your program and adapt (or include it, as
;  KIT\TEST\NWORLD.ASM does to prove it). Rename nh_/NH to your own.
;
;  THE RULE (docs\guide\MULTI.MD "A world they share"): what nobody owns
;  (bots, the score, a ball, a level) ONE machine keeps - the lowest name
;  heard. It sends the world; the others draw it and send requests. No
;  server and no election: every machine works it out from what it hears.
;    - A host that hears a world from a LOWER name gives in and becomes
;      its client: two who started alone at once end as one game.
;    - A client takes the world of its host, or of anyone lower. A higher
;      name's world is taken only once its own host has been quiet for
;      NH_GONE ticks (that one is the new host).
;    - The host quiet NH_GONE ticks: of the names heard lately, the
;      quiet one left out, the lowest carries on - if that is us, we host
;      from the world we last drew; nothing freezes.
;
;  DEFINE BEFORE: NH_GONE (ticks with no world: the host has gone; 36 =
;    2 s); the includes E_NET, K_PEER, K_NETX.
;  CALLS: K_PEER PEER_HOST (with DX = the quiet host) and peer_me.
;  YOUR LOOP: on a world packet from AX:  call NHWORLD / jc .skip / apply
;    it (R_NETWLD WAPPLY). Once a frame:  call NHCLOCK; AL = 1: we host
;    now - restart your per-player clocks (everyone "heard now") and send
;    the world at once. After the join (K_NETX NTX_JOIN): nh_mode = what
;    it answered (NTX_HOST 1 / NTX_CLIENT 2 / NTX_ALONE 0), nh_host = its
;    DX, and call NHHEARD for a client.
;  from: GAMES\MULTSOK2\MULTSOK2.ASM:2671-2694 (NETPOLL .world),
;        2712-2724 (.client), 2761-2796 NEXTHOST.
;
;  THE WORKED EXAMPLE, OWL FLY III's shared war (GAMES\OWLFLY3\SRC\WAR.INC
;  header, lines 1-98), the same pattern grown up:
;    - Host = the lowest name heard within 36 ticks, worked out by every
;      machine from the position packets it already hears.
;    - The host sends the bots every 4 ticks, even alone, on a socket of
;      the war's own (5858h), packets under 512 bytes.
;    - A client stops DECIDING for those bots (no turns, no shots, no
;      deaths of its own making) and flies them on along their heading
;      between packets; a jump of over 2000 units is a respawn.
;    - A client's hit shows on its own screen at once and goes to the host
;      as a request ('X': slot, damage); the host's armour is the one that
;      counts. A bot the client downed stays down 36 ticks whatever comes.
;    - No world for 18 ticks: the client runs its own war again from where
;      it stands, and the next lowest name carries on as host.
;    - The host leashes the bots to the NEAREST player, not its own camera.
;    - Sides are dealt by the host in its world packet; a player takes his
;      at his next life, never in the middle of one.
;    - Listens: count your own echoes too (the host's own 'B' and 'K' came
;      back and filled two listens; six are posted).
; ============================================================================
NH_ALONE  = 0                   ; nh_mode: no wire
NH_HOST   = 1                   ;  we keep the world
NH_CLIENT = 2                   ;  we draw someone's
NH_JOIN   = 3                   ;  joining: the first world heard is ours
if ~ defined NH_GONE | defined nh_gonedef
nh_gonedef = 1
NH_GONE = 36
end if

; ---- NHWORLD: a world came from AX - take it? CF = 0 yes, CF = 1 no -----
; Taking it makes us a client of AX. Keeps all but flags.
NHWORLD:
        push ax
        push bx
        mov  bl,[nh_mode]
        cmp  bl,NH_JOIN
        je   .take              ; joining: the first world heard
        cmp  bl,NH_HOST
        je   .host
        cmp  bl,NH_CLIENT
        jne  .no                ; alone: no world but ours
        cmp  ax,[nh_host]
        jbe  .take              ; our host, or a lower name
        push ax
        call nh_now
        sub  ax,[nh_heard]      ; ticks since our host's last world
        cmp  ax,NH_GONE
        pop  ax
        jae  .take              ; ours has gone: this one carries on
        jmp  .no                ; ours still talks: this one will yield
.host:  cmp  ax,[peer_me]       ; two hosts: the lower name keeps it
        jae  .no
.take:  mov  byte [nh_mode],NH_CLIENT
        mov  [nh_host],ax
        call NHHEARD
        pop  bx
        pop  ax
        clc
        ret
.no:    pop  bx
        pop  ax
        stc
        ret

; ---- NHHEARD: the host's world heard now (the clock restarts) ----------
NHHEARD:
        push ax
        call nh_now
        mov  [nh_heard],ax
        pop  ax
        ret

; ---- NHCLOCK: once a frame. AL = 1: the host went quiet and WE host now
; (carry on from the world last drawn), 0: nothing changed. Keeps the rest.
NHCLOCK:
        push dx
        cmp  byte [nh_mode],NH_CLIENT
        jne  .none
        call nh_now
        sub  ax,[nh_heard]      ; ticks with no world
        cmp  ax,NH_GONE
        jb   .none
        mov  dx,[nh_host]       ; the quiet one left out:
        call PEER_HOST          ;  the lowest heard lately - ZF: us
        jnz  .none              ; another: we wait for its world
        mov  byte [nh_mode],NH_HOST
        mov  ax,[peer_me]
        mov  [nh_host],ax
        mov  al,1
        pop  dx
        ret
.none:  xor  al,al
        pop  dx
        ret

nh_now: push ds                 ; AX = the BIOS tick's low word
        xor  ax,ax
        mov  ds,ax
        mov  ax,[046Ch]
        pop  ds
        ret

nh_mode  db NH_ALONE
         db 0
nh_host  dw 0                   ; the host whose world we draw (ours: us)
nh_heard dw 0                   ; the tick its last world came
