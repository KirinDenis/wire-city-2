; ============================================================================
;  BBS.COM - WIRE CITY 86 BBS terminal
;
;  Multi-user IPX broadcast chat, written against the REAL IPX API of
;  1986 (INT 7Ah entry, ECBs, broadcast packets). Inside desktop
;  DOSBox it talks over ipxnet; inside the browser the emulator
;  tunnels the same packets through WebSocket.
;
;  No nick prompt: this is byte-for-byte the CHAT.COM v1 shape - the
;  one program whose typing provably worked in every browser. The
;  receive ECB is armed BEFORE the loop and polled every iteration,
;  every iteration yields to the IPX driver (function 0Ah), keys come
;  from polled INT 16h inside that same loop.
;
;  Type a line, Enter broadcasts it; incoming lines print as they
;  arrive. ESC quits. Requires ipx=true in the DOSBox config.
; ============================================================================
SOCKN   equ 3986h               ; our socket number (big-endian on the wire)

        .8086
        LOCALS
        JUMPS
CODE    SEGMENT
        ASSUME cs:CODE, ds:CODE, es:CODE, ss:CODE
        ORG  100h

START:  cld
        mov  ax,7A00h           ; is IPX there?
        int  2Fh
        cmp  al,0FFh
        je   @@have
        mov  dx,offset MSGNO
        mov  ah,9
        int  21h
        mov  ax,4C01h
        int  21h
@@have: mov  [rseg],cs          ; fragment segments: a .COM only knows
        mov  [sseg],cs          ; its segment at run time
        mov  word ptr [ipxep],di   ; far entry point from ES:DI
        mov  word ptr [ipxep+2],es
        push ds
        pop  es
        mov  bx,0               ; open socket (AL=0: until close)
        xor  al,al
        mov  dx,SOCKN
        call dword ptr [ipxep]
        or   al,al
        jz   @@sok
        mov  dx,offset MSGSF
        mov  ah,9
        int  21h
        mov  ax,4C01h
        int  21h
@@sok:  mov  si,offset myaddr   ; who am I? (net 4 + node 6)
        mov  bx,9
        call dword ptr [ipxep]
        call LISTEN             ; arm the receive ECB
        mov  dx,offset MSGHI
        mov  ah,9
        int  21h
; ---- the main loop ---------------------------------------------------------
@@loop: mov  ax,1680h           ; release the time slice: without a real
        int  2Fh                ;  host sleep the loop starves the emulator
        mov  bx,0Ah             ; let the driver breathe
        call dword ptr [ipxep]
        cmp  byte ptr [rinuse],0 ; receive ECB completed?
        jne  @@key
        cmp  byte ptr [rcc],0    ; completion code 0 = a packet
        jne  @@rearm
        mov  si,offset myaddr   ; refresh our own address first: it only
        mov  bx,9               ;  becomes real after relay registration,
        call dword ptr [ipxep]  ;  and a stale one lets own echoes through
        mov  si,offset rhdr+22  ; our own echo? src node vs my node
        mov  di,offset mynode
        mov  cx,6
        repe cmpsb
        je   @@rearm
        mov  si,offset rpay     ; print the incoming line
        mov  dx,offset MSGRE
        mov  ah,9
        int  21h
@@pr:   lodsb
        or   al,al
        jz   @@prd
        mov  dl,al
        mov  ah,2
        int  21h
        jmp  @@pr
@@prd:  mov  dx,offset MSGNL
        mov  ah,9
        int  21h
@@rearm:call LISTEN
@@key:  mov  ah,1               ; a key?
        int  16h
        jz   @@loop
        xor  ah,ah
        int  16h
        cmp  al,27
        je   @@quit
        cmp  al,13              ; Enter: broadcast the line
        je   @@send
        cmp  al,8               ; backspace
        jne  @@ch
        cmp  word ptr [llen],0
        je   @@loop
        dec  word ptr [llen]
        mov  dx,offset MSGBS
        mov  ah,9
        int  21h
        jmp  @@loop
@@ch:   cmp  al,32
        jb   @@loop
        mov  bx,[llen]
        cmp  bx,100
        jae  @@loop
        mov  [line+bx],al
        inc  word ptr [llen]
        mov  dl,al              ; echo
        mov  ah,2
        int  21h
        jmp  @@loop
@@send: mov  bx,[llen]
        or   bx,bx
        jz   @@loop
        mov  byte ptr [line+bx],0
        mov  dx,offset MSGNL
        mov  ah,9
        int  21h
        ; payload = the line; fragment = header 30 + text + NUL
        mov  ax,[llen]
        add  ax,31
        mov  [sfrsz],ax
        mov  si,offset line
        mov  di,offset spay
        mov  cx,[llen]
        inc  cx
        rep  movsb
        mov  si,offset secb
        push ds
        pop  es
        mov  bx,3               ; send
        call dword ptr [ipxep]
@@wait: mov  bx,0Ah             ; wait it out
        call dword ptr [ipxep]
        cmp  byte ptr [sinuse],0
        jne  @@wait
        mov  word ptr [llen],0
        jmp  @@loop
@@quit: mov  bx,1               ; close the socket like a good citizen
        mov  dx,SOCKN
        call dword ptr [ipxep]
        mov  ax,4C00h
        int  21h

; ---- LISTEN: (re)arm the receive ECB ---------------------------------------
LISTEN: mov  di,offset rpay     ; clean the payload
        mov  cx,128
        xor  al,al
        rep  stosb
        mov  si,offset recb
        push ds
        pop  es
        mov  bx,4               ; listen
        call dword ptr [ipxep]
        ret

; ---- data ------------------------------------------------------------------
MSGNO   db 'No IPX. Run with ipx=true (DOSBox) or the js-dos net tab.',13,10,'$'
MSGSF   db 'IPX socket open failed.',13,10,'$'
MSGHI   db 'WIRE CITY 86 BBS / IPX broadcast on socket 3986h',13,10
        db 'type a line, Enter posts, ESC quits',13,10,'$'
MSGRE   db 13,10,'>> ','$'
MSGNL   db 13,10,'$'
MSGBS   db 8,' ',8,'$'
ipxep   dd 0                    ; the IPX far entry point
llen    dw 0
line    db 122 dup(0)
; receive ECB + IPX header + payload
recb    dd 0                    ; link
        dd 0                    ; ESR: none, we poll
rinuse  db 0                    ; InUse
rcc     db 0                    ; completion code
        dw SOCKN                ; socket (big-endian byte order matches)
        db 4 dup(0)             ; IPX workspace
        db 12 dup(0)            ; driver workspace
        db 6 dup(0)             ; immediate address
        dw 1                    ; fragment count
        dw rhdr                 ; fragment 1: offset...
rseg    dw 0                    ; ...segment (CS, patched at START)
        dw 158                  ; fragment size: header 30 + payload 128
rhdr    db 30 dup(0)            ; incoming IPX header
rpay    db 128 dup(0)           ; incoming text
; send ECB + IPX header + payload
secb    dd 0                    ; link
        dd 0                    ; ESR
sinuse  db 0
        db 0
        dw SOCKN
        db 4 dup(0)
        db 12 dup(0)
        db 6 dup(0FFh)          ; immediate address: broadcast
        dw 1
        dw shdr                 ; fragment 1: offset...
sseg    dw 0                    ; ...segment (CS, patched at START)
sfrsz   dw 0                    ; fragment size (30 + line)
shdr    dw 0                    ; IPX header: checksum
        dw 0                    ; length (driver fills)
        db 0                    ; transport control
        db 4                    ; packet type: IPX
        db 4 dup(0)             ; dest network: this one
        db 6 dup(0FFh)          ; dest node: BROADCAST
        dw SOCKN                ; dest socket
        db 4 dup(0)             ; src network (driver fills)
        db 6 dup(0)             ; src node (driver fills)
        dw SOCKN                ; src socket
spay    db 128 dup(0)
myaddr  db 4 dup(0)             ; my network...
mynode  db 6 dup(0)             ; ...and node (IPX function 9)

CODE    ENDS
        END START
