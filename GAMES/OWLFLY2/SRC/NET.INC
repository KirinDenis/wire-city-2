; NET.INC - part of WIRE CITY (included from CITY.ASM, after SKY.INC)
; ============================================================================
;  THE WIRE: IPX multiplayer, 1990 style.
;
;  The whole world is procedural from one 16-bit seed, so "join a
;  game" is a two-byte handshake: the newcomer broadcasts HELLO, the
;  pilot already flying answers SEED, the newcomer runs the same DSGEN
;  and stands in the same world - island, city, clouds and all. After
;  that everyone broadcasts an 11-byte POS each physics tick, and the
;  other pilots fly YOUR sky as jets in the last four AI slots, drawn
;  by PLANESDRAW like any other traffic.
;
;  Transport: real-mode IPX (INT 2F detect, far entry, ECBs) - inside
;  DOSBox that is IPXNET over UDP; over the internet it is the ViewOwl
;  relay's /ipx pipe. The socket is 5757h: a palindrome, so the
;  big-endian-ness of Novell socket numbers can never bite.
;
;  This file APPENDS to SKYSEG: the ECBs, buffers and code all live in
;  the far segment - the main 64K pays for nothing but four far calls
;  and the premote flags. The 8K window guard sits at the end of THIS
;  file now, covering sky + net together.
;
;  Far doors:
;    NETINITF  - detect IPX, open socket, learn our address, post
;                listens. Returns AL=1 (and DX=our pid) or AL=0.
;    NETHELLOF - broadcast HELLO (the joiner's knock)
;    NETPOLLF  - drain arrived packets. Returns AL=1 + DX=seed ONCE
;                when a SEED lands (the joiner's answer); applies POS
;                and answers HELLO (when hosting) as a side effect.
;    NETHOSTF  - the knock went unanswered: we are the host now
;    NETPOSF   - broadcast our POS (self-gated to one per BIOS tick)
; ============================================================================

SKYSEG  SEGMENT PARA PUBLIC 'CODE'
        ASSUME  CS:SKYSEG, DS:CODE, ES:NOTHING, SS:CODE

NETSOCK equ 5757h               ; the palindrome socket
NETSLT  equ 36                  ; remote pilots wear AI slots 36..39
NRMT    equ 4
NLSTN   equ 4                   ; listen ECBs in flight

; ---- ECB field map (one fragment) ------------------------------------------
; THE LAYOUT THAT ACTUALLY FLIES (proven in EXAMPLES\BBS.ASM): the ECB
; starts with a LINK dword, THEN the ESR - InUse is at +8, not +4. The
; textbook 38-byte map put our segment word where DOSBox reads the
; fragment count: 4514 fragments of garbage = the send that never
; returned (postmortem 2026-07-23).
E_LNK   equ 0                   ; link dword
E_ESR   equ 4                   ; ESR far address, 0 = we poll
E_INUSE equ 8                   ; nonzero while the driver owns it
E_CC    equ 9                   ; completion code, 0 = clean
E_SOCK  equ 10                  ; socket, raw
E_IMM   equ 28                  ; immediate address (6)
E_FCNT  equ 34                  ; fragment count
E_F1OF  equ 36                  ; fragment 1: offset, segment, length
E_F1SG  equ 38
E_F1LN  equ 40
ECBSZ   equ 42

; ---- IPX header field map --------------------------------------------------
H_PT    equ 5                   ; packet type (4 = IPX)
H_DNET  equ 6                   ; destination network (4)
H_DNODE equ 10                  ; destination node (6)
H_DSOCK equ 16                  ; destination socket
HDRSZ   equ 30

; ---- the wire's own state (CS-relative, far from the crowded 64K) ----------
ipxep   dd 0                    ; the IPX far entry point
mynode  db 10 dup(0)            ; our internetwork address: net(4)+node(6)
netok   db 0                    ; 1 = IPX up, socket open
nethost db 0                    ; 1 = we answer HELLOs with our seed
mypid   dw 0                    ; our name on the wire (node tail bytes)
sentk   dw 0                    ; last tick a POS went out
rpid    dw NRMT dup(0)          ; who wears remote slot i (0 = nobody)
rlast   dw NRMT dup(0)          ; the tick their last POS arrived
gots    db 0                    ; NETPOLL: a seed landed this drain
gseed   dw 0                    ; ...and this is it
; send: ECB + header + payload, header and payload CONTIGUOUS - the
; one fragment covers both
SECB    db ECBSZ dup(0)
SHDR    db HDRSZ dup(0)
SPAY    db 16 dup(0)
; receive: NLSTN listen ECBs, 64-byte buffers
RECB    db NLSTN*ECBSZ dup(0)
RBUF    db NLSTN*64 dup(0)

; ============================ the far doors =================================
NETINITF PROC FAR
        call NETINIT
        ret
NETINITF ENDP
NETHELLOF PROC FAR
        call NETHELLO
        ret
NETHELLOF ENDP
NETPOLLF PROC FAR
        call NETPOLL
        ret
NETPOLLF ENDP
NETHOSTF PROC FAR
        mov  byte ptr [nethost],1
        ret
NETHOSTF ENDP
NETPOSF PROC FAR
        call NETPOS
        ret
NETPOSF ENDP

; ---- NETINIT: find IPX, open the socket, learn our name --------------------
NETINIT:
        push es
        mov  ax,7A00h
        int  2Fh
        cmp  al,0FFh
        jne  @@no
        mov  word ptr [ipxep],di
        mov  word ptr [ipxep+2],es
        mov  bx,0               ; open socket: DX = number, AL = live
        mov  al,0               ; until program exit
        mov  dx,NETSOCK
        int  7Ah
        or   al,al
        jnz  @@no
        mov  bx,9               ; our internetwork address -> mynode
        mov  ax,SKYSEG
        mov  es,ax
        mov  si,offset mynode
        int  7Ah
        mov  ax,word ptr [mynode+8] ; the node's tail names us on the
        mov  [mypid],ax             ; wire (DOSBox hands out unique
        or   ax,ax                  ; nodes; zero would read as free)
        jnz  @@pid
        inc  ax
        mov  [mypid],ax
@@pid:  xor  si,si              ; post the listens
@@pl:   push si
        call NETLSTN
        pop  si
        inc  si
        cmp  si,NLSTN
        jb   @@pl
        mov  byte ptr [netok],1
        mov  al,1
        mov  dx,[mypid]
        pop  es
        ret
@@no:   mov  byte ptr [netok],0
        xor  al,al
        pop  es
        ret

; ---- NETLSTN: arm listen ECB si (0..NLSTN-1) -------------------------------
NETLSTN:
        push es
        mov  ax,si
        mov  bx,ECBSZ
        mul  bx
        mov  di,offset RECB
        add  di,ax              ; DI -> the ECB
        mov  ax,si
        mov  cl,6
        shl  ax,cl
        add  ax,offset RBUF     ; its 64-byte buffer
        mov  word ptr cs:[di+E_LNK],0
        mov  word ptr cs:[di+E_LNK+2],0
        mov  word ptr cs:[di+E_ESR],0   ; no ESR: we poll
        mov  word ptr cs:[di+E_ESR+2],0
        mov  word ptr cs:[di+E_SOCK],NETSOCK
        mov  word ptr cs:[di+E_FCNT],1
        mov  word ptr cs:[di+E_F1OF],ax
        mov  word ptr cs:[di+E_F1SG],SKYSEG
        mov  word ptr cs:[di+E_F1LN],64
        mov  ax,SKYSEG
        mov  es,ax
        mov  si,di              ; ES:SI -> ECB
        mov  bx,4               ; ListenForPacket
        int  7Ah
        pop  es
        ret

; ---- NETXMIT: broadcast SHDR+SPAY, CX = payload bytes ----------------------
; Quietly drops the packet if the send ECB is still in flight.
NETXMIT:
        cmp  byte ptr [netok],0
        je   @@drop
        cmp  byte ptr [SECB+E_INUSE],0
        jne  @@drop
        push es
        mov  byte ptr [SHDR+H_PT],4
        mov  ax,word ptr [mynode]   ; our own network number: DOSBox
        mov  word ptr [SHDR+H_DNET],ax   ; broadcasts stay on the wire
        mov  ax,word ptr [mynode+2]
        mov  word ptr [SHDR+H_DNET+2],ax
        mov  ax,0FFFFh
        mov  word ptr [SHDR+H_DNODE],ax
        mov  word ptr [SHDR+H_DNODE+2],ax
        mov  word ptr [SHDR+H_DNODE+4],ax
        mov  word ptr [SHDR+H_DSOCK],NETSOCK
        mov  word ptr [SECB+E_LNK],0
        mov  word ptr [SECB+E_LNK+2],0
        mov  word ptr [SECB+E_ESR],0
        mov  word ptr [SECB+E_ESR+2],0
        mov  word ptr [SECB+E_SOCK],NETSOCK
        mov  word ptr [SECB+E_IMM],0FFFFh
        mov  word ptr [SECB+E_IMM+2],0FFFFh
        mov  word ptr [SECB+E_IMM+4],0FFFFh
        mov  word ptr [SECB+E_FCNT],1
        mov  word ptr [SECB+E_F1OF],offset SHDR
        mov  word ptr [SECB+E_F1SG],SKYSEG
        mov  ax,HDRSZ
        add  ax,cx
        mov  word ptr [SECB+E_F1LN],ax
        mov  ax,SKYSEG
        mov  es,ax
        mov  si,offset SECB
        mov  bx,3               ; SendPacket
        int  7Ah
        mov  cx,5000            ; BBS.ASM's manner: give the driver its
@@sw:   cmp  byte ptr [SECB+E_INUSE],0   ; time (bounded - a game frame
        je   @@sd               ; must never wedge on the wire)
        mov  bx,0Ah             ; RelinquishControl
        int  7Ah
        loop @@sw
@@sd:   pop  es
@@drop: ret

; ---- NETHELLO: the joiner's knock ------------------------------------------
NETHELLO:
        mov  byte ptr [SPAY],'H'
        mov  cx,1
        call NETXMIT
        ret

; ---- NETSEED: the host's answer --------------------------------------------
NETSEED:
        mov  byte ptr [SPAY],'S'
        mov  ax,[wseed]         ; the seed the WORLD was built from
        mov  word ptr [SPAY+1],ax
        mov  cx,3
        call NETXMIT
        ret

; ---- NETPOS: our position, one broadcast per BIOS tick ---------------------
NETPOS: cmp  byte ptr [netok],0
        je   @@r
        mov  ax,[lasttk]
        cmp  ax,[sentk]
        je   @@r
        mov  [sentk],ax
        mov  byte ptr [SPAY],'P'
        mov  ax,[mypid]
        mov  word ptr [SPAY+1],ax
        mov  ax,[camx]
        mov  word ptr [SPAY+3],ax
        mov  ax,[camy]
        mov  word ptr [SPAY+5],ax
        mov  ax,[camz]
        mov  word ptr [SPAY+7],ax
        mov  ax,[heading]
        mov  word ptr [SPAY+9],ax
        mov  cx,11
        call NETXMIT
@@r:    ret

; ---- NETPOLL: drain the listens, keep the remote pilots honest -------------
; Returns AL=1 + DX=seed ONCE when a SEED arrives; else AL=0.
NETPOLL:
        xor  ax,ax
        cmp  byte ptr [netok],0
        jne  @@go
        ret
@@go:   mov  byte ptr [gots],0
        xor  si,si              ; walk the listen ECBs
@@e:    push si
        mov  ax,si
        mov  bx,ECBSZ
        mul  bx
        mov  di,offset RECB
        add  di,ax
        cmp  byte ptr cs:[di+E_INUSE],0
        jne  @@next             ; still listening
        cmp  byte ptr cs:[di+E_CC],0
        jne  @@rearm            ; a bad landing: just relisten
        mov  ax,si              ; the packet: RBUF + si*64 + HDRSZ
        mov  cl,6
        shl  ax,cl
        add  ax,offset RBUF+HDRSZ
        mov  bx,ax              ; BX -> payload
        mov  al,cs:[bx]
        cmp  al,'P'
        je   @@pos
        cmp  al,'H'
        je   @@hello
        cmp  al,'S'
        je   @@seed
        jmp  @@rearm
@@hello:
        cmp  byte ptr [nethost],0
        je   @@rearm
        call NETSEED            ; someone knocked: hand them the world
        jmp  @@rearm
@@seed: cmp  byte ptr [nethost],0
        jne  @@rearm            ; hosts keep their own world
        mov  ax,word ptr cs:[bx+1]
        mov  [gseed],ax
        mov  byte ptr [gots],1
        jmp  @@rearm
@@pos:  mov  ax,word ptr cs:[bx+1]  ; whose position?
        cmp  ax,[mypid]
        je   @@rearm            ; our own echo
        or   ax,ax
        jz   @@rearm
        call RSLOT              ; DI = remote index 0..3 or -1
        cmp  di,-1
        je   @@rearm
        push si
        mov  si,di
        add  si,si
        mov  ax,[lasttk]
        mov  [rlast+si],ax
        mov  ax,di
        add  ax,NETSLT          ; the plane slot
        mov  si,ax
        mov  byte ptr [premote+si],1
        mov  byte ptr [pst+si],0
        mov  byte ptr [ptype+si],0
        add  si,si              ; word index
        mov  ax,word ptr cs:[bx+3]
        mov  [pax+si],ax
        mov  ax,word ptr cs:[bx+5]
        mov  [pay+si],ax
        mov  ax,word ptr cs:[bx+7]
        mov  [paz+si],ax
        mov  ax,word ptr cs:[bx+9]
        mov  [pah+si],ax
        pop  si
@@rearm:
        pop  si
        push si
        call NETLSTN            ; back on watch
@@next: pop  si
        inc  si
        cmp  si,NLSTN
        jb   @@e
        ; ---- sweep the ghosts: silence for ~5 s frees the slot ----
        xor  si,si
@@sw:   mov  di,si
        add  di,di
        cmp  word ptr [rpid+di],0
        je   @@swn
        mov  ax,[lasttk]
        sub  ax,[rlast+di]
        cmp  ax,90
        jb   @@swn
        mov  word ptr [rpid+di],0
        mov  bx,si
        add  bx,NETSLT
        mov  byte ptr [pst+bx],1     ; the jet fades from the sky
        mov  byte ptr [premote+bx],0
@@swn:  inc  si
        cmp  si,NRMT
        jb   @@sw
        mov  al,[gots]          ; the verdict for the joiner
        mov  dx,[gseed]
        ret

; ---- RSLOT: pid in AX -> remote index in DI (alloc), -1 if full ------------
RSLOT:  push si
        xor  si,si
@@f:    mov  di,si
        add  di,di
        cmp  [rpid+di],ax
        je   @@got
        inc  si
        cmp  si,NRMT
        jb   @@f
        xor  si,si              ; not seen before: first free bunk
@@a:    mov  di,si
        add  di,di
        cmp  word ptr [rpid+di],0
        je   @@new
        inc  si
        cmp  si,NRMT
        jb   @@a
        mov  di,-1              ; the sky is full
        pop  si
        ret
@@new:  mov  [rpid+di],ax
@@got:  mov  di,si
        pop  si
        ret

; ---- THE WINDOW GUARD (sky + net together) ---------------------------------
; SKYSEG lives at CS+1000h and the back-buffer starts at CS+1200h:
; 8K, not a byte more. The build refuses to overflow instead of
; letting the frame buffer eat the cloud tables (postmortem 2026-07-23).
IF ($-BNOISE) GT 8176
        %OUT *** SKYSEG overflows its 8K window before the buffer ***
        .ERR
ENDIF

SKYSEG  ENDS
