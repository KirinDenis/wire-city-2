; ============================================================================
;@ R_NETST    state-not-events packet: whole state each time, an event repeated until acknowledged
;  A RECIPE: copy it into your program and adapt (or include it, as
;  KIT\TEST\NSTATE.ASM does to prove it). Rename st_/S_/SU_ to your own.
;
;  THE RULE (docs\guide\MULTI.MD "The packet"): every packet carries the
;  sender's WHOLE state - where he is, how he looks, how hurt he is - so a
;  lost packet costs nothing and a newcomer is up to date with the next
;  one. An EVENT ("I hit you for 3") that cannot be a state rides in every
;  packet too, numbered, until the other side's own state shows it was
;  taken: his packet says "the last event I applied was from you, number
;  N". He applies each number once, however often it comes. The victim's
;  machine decides his own health - nobody else may (OWL FLY: NET.MD
;  "A player's life is his own to report").
;
;  DEFINE BEFORE (and the includes):
;    NETSOCK, NETLEN >= S_LEN (15) for E_NET; PEER_USER >= SU_LEN (8) for
;    K_PEER; ST_PROTO (your game's version byte); ST_XMAX, ST_YMAX (the
;    biggest x and y a packet may carry); ST_HPMAX (full health); ST_NLOOK
;    (looks there are).
;  CALLS: K_PEER (PEER_HEARD, PEER_FIND, peer_me), K_NETX (NTX_CLAMPU and,
;    in your loop, NTX_SENDST / NTX_DRAIN), E_NET underneath.
;  YOUR LOOP, once a frame:
;        mov  bx,STTAKE          ; every packet that came
;        call NTX_DRAIN
;        call STPACK             ; our state, whole, into st_pkt
;        mov  si,st_pkt
;        mov  al,[st_chg]        ; changed: at once; else on the heartbeat
;        call NTX_SENDST
;        mov  byte [st_chg],0
;  and to hit someone: AX = his name, CL = how hard, call STEVENT.
;  Your own moves write st_x/st_y/st_look and set st_chg = 1.
;  from: docs\guide\MULTI.MD; NET.MD (OWL FLY 'P' +13 dying +14 killer,
;        'H' hits); new code for the numbered event and its echo.
; ============================================================================

; the packet
S_KIND  = 0                     ; 'S'
S_PROTO = 1                     ; ST_PROTO: another version is not ours
S_X     = 2                     ; word
S_Y     = 4                     ; word
S_LOOK  = 6                     ; byte
S_HP    = 7                     ; byte: his health - his machine's word
S_EVTO  = 8                     ; word: who our event is for, 0 none
S_EVSEQ = 10                    ; byte: its number
S_EVARG = 11                    ; byte: how hard
S_ACKTO = 12                    ; word: whose event we applied last...
S_ACKSQ = 14                    ; byte: ...and its number
S_LEN   = 15

; what we keep of each other player (K_PEER's slot, from PEER_U)
SU_X    = PEER_U                ; word
SU_Y    = PEER_U+2              ; word
SU_LOOK = PEER_U+4              ; byte
SU_HP   = PEER_U+5              ; byte
SU_SEQ  = PEER_U+6              ; byte: the last event of his we applied
SU_LEN  = 8

; ---- STEVENT: AX = whom, CL = how hard: a new event, sent until shown ----
; One in flight: a second replaces an unacknowledged first (queue them if
; your game needs every one). Keeps all but flags.
STEVENT:
        mov  [st_evto],ax
        inc  byte [st_evseq]    ; a new number: he applies it once
        jnz  .n
        inc  byte [st_evseq]    ; never 0 - a fresh slot remembers 0
.n:     mov  [st_evarg],cl
        mov  byte [st_chg],1    ; out at once
        ret

; ---- STPACK: our whole state into st_pkt. Keeps all but flags -----------
STPACK: push ax
        push bx
        mov  ax,[st_evto]       ; an event for someone who has gone: dropped
        or   ax,ax
        jz   .p
        call PEER_FIND
        jnc  .p
        mov  word [st_evto],0
.p:     mov  byte [st_pkt+S_KIND],'S'
        mov  byte [st_pkt+S_PROTO],ST_PROTO
        mov  ax,[st_x]
        mov  [st_pkt+S_X],ax
        mov  ax,[st_y]
        mov  [st_pkt+S_Y],ax
        mov  al,[st_look]
        mov  [st_pkt+S_LOOK],al
        mov  al,[st_hp]
        mov  [st_pkt+S_HP],al
        mov  ax,[st_evto]
        mov  [st_pkt+S_EVTO],ax
        mov  al,[st_evseq]
        mov  [st_pkt+S_EVSEQ],al
        mov  al,[st_evarg]
        mov  [st_pkt+S_EVARG],al
        mov  ax,[st_ackto]
        mov  [st_pkt+S_ACKTO],ax
        mov  al,[st_acksq]
        mov  [st_pkt+S_ACKSQ],al
        pop  bx
        pop  ax
        ret

; ---- STTAKE: AX = who, DI -> his packet (an NTX_DRAIN handler) ----------
; His state into his slot, clamped; his event for us applied once and
; acknowledged; our event to him ended when his state shows it.
; Clobbers AX BX DX SI (keeps DI).
STTAKE: cmp  byte [di+S_KIND],'S'
        jne  .r
        cmp  byte [di+S_PROTO],ST_PROTO
        jne  .r                 ; another version of the game
        mov  [st_from],ax
        call PEER_HEARD         ; BX -> his slot; CF: full
        jc   .r
        mov  si,bx
        mov  ax,[di+S_X]        ; everything clamped: someone else's word
        xor  bx,bx
        mov  dx,ST_XMAX
        call NTX_CLAMPU
        mov  [si+SU_X],ax
        mov  ax,[di+S_Y]
        mov  dx,ST_YMAX
        call NTX_CLAMPU
        mov  [si+SU_Y],ax
        mov  al,[di+S_LOOK]
        xor  ah,ah
        mov  dx,ST_NLOOK-1
        call NTX_CLAMPU
        mov  [si+SU_LOOK],al
        mov  al,[di+S_HP]
        xor  ah,ah
        mov  dx,ST_HPMAX
        call NTX_CLAMPU
        mov  [si+SU_HP],al
        mov  ax,[di+S_EVTO]     ; an event for us?
        cmp  ax,[peer_me]
        jne  .ack
        or   ax,ax
        jz   .ack
        mov  al,[di+S_EVSEQ]
        cmp  al,[si+SU_SEQ]
        je   .echo              ; that number applied already: only echo it
        mov  [si+SU_SEQ],al
        mov  al,[di+S_EVARG]    ; THE EVENT, applied once - here a hit:
        sub  [st_hp],al         ;  our health down by its strength
        jnc  .echo
        mov  byte [st_hp],0     ;  (not below 0)
.echo:  mov  ax,[st_from]       ; our state says we took it
        mov  [st_ackto],ax
        mov  al,[di+S_EVSEQ]
        mov  [st_acksq],al
        mov  byte [st_chg],1    ; the echo goes at once
.ack:   mov  ax,[st_evto]       ; our event to him: does his state show it?
        or   ax,ax
        jz   .r
        cmp  ax,[st_from]
        jne  .r
        mov  ax,[di+S_ACKTO]
        cmp  ax,[peer_me]
        jne  .r
        mov  al,[di+S_ACKSQ]
        cmp  al,[st_evseq]
        jne  .r
        mov  word [st_evto],0   ; taken: no more repeats
        mov  byte [st_chg],1
.r:     ret

st_x     dw 0                   ; OUR state - your game writes it
st_y     dw 0
st_look  db 0
st_hp    db ST_HPMAX
st_chg   db 1                   ; it changed: send at once
st_evseq db 0                   ; our event: its number,
st_evarg db 0                   ;  its strength,
         db 0
st_evto  dw 0                   ;  whom it is for (0: none in flight)
st_ackto dw 0                   ; the last event we applied: whose,
st_acksq db 0                   ;  its number
st_from  dw 0                   ; (STTAKE's sender)
assert NETLEN >= S_LEN           ; E_NET sends NETLEN bytes from it
st_pkt:  db NETLEN dup(0)
