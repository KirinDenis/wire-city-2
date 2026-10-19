; ============================================================================
;  E_NET.INC - the network for a small game: everyone in the room hears
;  everyone. IPX, the recipe the OWL FLY games proved (their NET.INC), cut
;  down to five calls.
;
;  WHERE IT MEETS. On the WIRE CITY site a program's IPX card reaches the
;  server's relay when it is started with --net: `build A:\MY\TAG\TAG.ASM
;  --net` or `run A:\MY\TAG\TAG.COM --net` - every program run so from the
;  folder TAG meets in the room "tag" (--net=ROOM names another). In
;  desktop DOSBox the same code talks over ipxnet. A broadcast reaches
;  every machine in the room - and, in DOSBox and on the relay, comes back
;  to its sender too: NETRECV drops our own.
;
;  THE INCLUDER DEFINES, before the include:
;    NETSOCK   the socket: a palindrome (4E4Eh), so its byte order cannot
;              bite. Never 5757h or 5858h - OWL FLY's.
;    NETLEN    the bytes of every packet's payload, 1..482 (with the
;              30-byte header, 512 is the most an old relay passes).
;    NETRX     listen buffers in flight; 6 if not defined. Our own echo
;              takes one each time we send - with too few, a busy room's
;              packets are lost.
;
;  THE CALLS - a .COM: DS = CS. Each sets ES itself and gives it back; each
;  keeps BP and the segment registers, nothing else.
;    NETOPEN   CF=1: no IPX here - play alone. CF=0: the socket is open
;              and the listens are posted.
;    NETPID    AX = our name on the wire (the node's last two bytes), or 0
;              while the address has not come: in the browser it arrives
;              seconds after the start. Ask every frame until it is not 0.
;    NETSEND   SI -> NETLEN bytes: broadcast them to the room. A send still
;              in flight is waited for a bounded while; CF=1: dropped.
;    NETRECV   CF=0: DI -> NETIN, NETLEN bytes from someone else, AX = his
;              name. CF=1: nothing more now. Call it until CF=1, every
;              frame; copy what you need before the next call.
;    NETCLOSE  the socket closed. Before the program ends, on every way out.
;
;  Include it after the main loop's way out - it is code and data, and the
;  CPU must never run into it - and after E_8086.INC.
; ============================================================================

; The default, the FASM way: a bare `if ~ defined NETRX` sees the NETRX it
; made itself on the next pass, takes it away, and FASM never settles
; ("code cannot be generated"); the marker keeps the answer the same.
if ~ defined NETRX | defined net_rxdefault
net_rxdefault = 1
NETRX = 6
end if
NET_HDR = 30                    ; the IPX header
NET_BUF = NET_HDR + NETLEN      ; a packet: the header, then the payload
NET_ECB = 42                    ; an ECB of one fragment: InUse at +8

; ---- NETOPEN: IPX there? the socket, and the listens posted ----------------
NETOPEN:
        push es
        push cs
        pop  es                 ; ES = CS: the ECBs are ours
        mov  ax,7A00h           ; is an IPX driver there? AL = FFh
        int  2Fh
        cmp  al,0FFh
        jne  .no
        xor  bx,bx              ; open a socket: DX its number,
        xor  al,al              ;  AL 0 - until we close it
        mov  dx,NETSOCK
        int  7Ah
        sti                     ; the driver may hand IF back off - and a
                                ;  frozen BIOS tick starves every wait
        or   al,al
        jnz  .no                ; taken, or none left
        mov  byte [net_ok],1
        call NETPID             ; the address, as far as it is known yet
        xor  si,si              ; post the listens, one a buffer
.post: push si
        call net_listen
        pop  si
        inc  si                 ; the next buffer
        cmp  si,NETRX
        jb   .post
        pop  es
        clc
        ret
.no:   pop  es
        stc
        ret

; ---- NETPID: AX = our name, 0 while the address has not come --------------
NETPID:
        xor  ax,ax
        cmp  byte [net_ok],0
        je   .done              ; no IPX: no name
        push es
        push si
        push cs
        pop  es
        mov  si,net_addr        ; ES:SI -> 10 bytes: network 4, node 6
        mov  bx,9               ; our internetwork address
        int  7Ah
        sti
        mov  ax,word [net_addr+4] ; the node's six bytes - all zero until
        or   ax,word [net_addr+6] ;  the relay has answered (the network
        or   ax,word [net_addr+8] ;  number comes first, the node later)
        jz   .back
        mov  ax,word [net_addr+8] ; its last two bytes name us
        or   ax,ax
        jnz  .back
        inc  ax                 ; never 0 - 0 says "not yet"
.back: pop  si
        pop  es
.done: mov  [net_pid],ax
        ret

; ---- net_listen: buffer SI listens again (ES = CS) -------------------------
net_listen:
        mov  ax,si
        mov  bx,NET_ECB
        mul  bx                 ; AX = SI x 42: its ECB's offset (DX lost)
        mov  di,net_ecbs
        add  di,ax              ; DI -> the ECB
        push di
        mov  cx,NET_ECB/2       ; 21 words: the ECB cleared
        xor  ax,ax
        rep  stosw
        pop  di
        mov  ax,si
        mov  bx,NET_BUF
        mul  bx                 ; AX = SI x a packet's size (DX lost)
        add  ax,net_bufs        ; AX -> its buffer
        mov  word [di+10],NETSOCK ; the socket
        mov  word [di+34],1     ; one fragment:
        mov  [di+36],ax         ;  its offset,
        mov  [di+38],cs         ;  its segment,
        mov  word [di+40],NET_BUF ;  its length
        mov  si,di              ; ES:SI -> the ECB
        mov  bx,4               ; listen for a packet
        int  7Ah
        sti
        ret

; ---- NETSEND: SI -> NETLEN bytes, to everyone in the room -----------------
NETSEND:
        cmp  byte [net_ok],0
        je   .drop
        push es
        push cs
        pop  es
        mov  cx,2000            ; the last send still in flight: a bounded
.busy: cmp  byte [net_secb+8],0 ;  wait - a frame must never wedge on the
        je   .free              ;  wire
        push cx
        mov  bx,0Ah             ; give the driver its time
        int  7Ah
        sti
        pop  cx
        loop .busy
        pop  es
.drop: stc
        ret
.free: mov  di,net_spay         ; the payload into the packet
        mov  cx,NETLEN
        rep  movsb
        mov  byte [net_shdr+5],4  ; packet type: IPX
        mov  ax,word [net_addr]   ; to our own network: a broadcast stays
        mov  word [net_shdr+6],ax ;  on our wire
        mov  ax,word [net_addr+2]
        mov  word [net_shdr+8],ax
        mov  ax,0FFFFh            ; to every node
        mov  word [net_shdr+10],ax
        mov  word [net_shdr+12],ax
        mov  word [net_shdr+14],ax
        mov  word [net_shdr+16],NETSOCK
        mov  di,net_secb          ; the send ECB, cleared
        mov  cx,NET_ECB/2
        xor  ax,ax
        rep  stosw
        mov  di,net_secb
        mov  word [di+10],NETSOCK
        mov  ax,0FFFFh            ; the immediate address: broadcast
        mov  [di+28],ax
        mov  [di+30],ax
        mov  [di+32],ax
        mov  word [di+34],1       ; one fragment: the header and payload
        mov  word [di+36],net_shdr
        mov  [di+38],cs
        mov  word [di+40],NET_BUF
        mov  si,di                ; ES:SI -> the ECB
        mov  bx,3                 ; send the packet
        int  7Ah
        sti
        pop  es
        clc
        ret

; ---- NETRECV: CF=0: DI -> NETIN, AX = who sent it; CF=1: nothing ----------
NETRECV:
        cmp  byte [net_ok],0
        je   .none
        push es
        push cs
        pop  es
        mov  bx,0Ah             ; let the driver deliver what came
        int  7Ah
        sti
        xor  si,si              ; walk the buffers
.e:    push si
        mov  ax,si
        mov  bx,NET_ECB
        mul  bx                 ; AX = SI x 42 (DX lost)
        mov  di,net_ecbs
        add  di,ax              ; DI -> its ECB
        cmp  byte [di+8],0      ; still listening?
        jne  .next
        cmp  byte [di+9],0      ; a clean landing?
        jne  .again             ; no: listen again
        mov  bx,[di+36]         ; BX -> the packet: its header first
        push di
        lea  si,[bx+22]         ; its source node (+22, six bytes)...
        mov  di,net_addr+4      ; ...against ours
        mov  cx,3
        repe cmpsw
        pop  di
        je   .again             ; our own echo: listen again
        mov  ax,[bx+26]         ; the sender's name: his node's last two
        or   ax,ax              ;  bytes, as NETPID names us
        jnz  .named
        inc  ax                 ; never 0
.named: mov  [net_from],ax
        lea  si,[bx+NET_HDR]    ; its payload into NETIN
        mov  di,NETIN
        mov  cx,NETLEN
        rep  movsb
        pop  si                 ; this buffer's number
        call net_listen         ; it listens again
        pop  es
        mov  ax,[net_from]
        mov  di,NETIN
        clc
        ret
.again: pop  si
        push si
        call net_listen
.next: pop  si
        inc  si                 ; the next buffer
        cmp  si,NETRX
        jb   .e
        pop  es
.none: stc
        ret

; ---- NETCLOSE: the socket closed ---------------------------------------------
NETCLOSE:
        cmp  byte [net_ok],0
        je   .done
        mov  bx,1               ; close the socket
        mov  dx,NETSOCK
        int  7Ah
        sti
        mov  byte [net_ok],0
.done: ret

; ---- its data ----------------------------------------------------------------
net_ok   db 0                   ; 1: IPX there, the socket open
net_pid  dw 0                   ; our name, 0 until the address comes
net_from dw 0                   ; the last packet's sender
net_addr db 10 dup(0)           ; our address: network 4, node 6
net_secb db NET_ECB dup(0)      ; the send ECB...
net_shdr db NET_HDR dup(0)      ; ...its header,
net_spay db NETLEN dup(0)       ;  and its payload right behind it
NETIN    db NETLEN dup(0)       ; what NETRECV hands over
net_ecbs db NET_ECB*NETRX dup(0) ; the listen ECBs
net_bufs db NET_BUF*NETRX dup(0) ; and their packets
