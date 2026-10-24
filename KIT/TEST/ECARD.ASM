; ECARD.ASM - test of KIT\LIB\K_CARD.INC: detection, the refusal of an
; absent card, then EGA 0Dh, EGA 640 0Eh, CGA mode 4 and mode 13h each set,
; a 4bpp picture blitted, VRAM read back (EGA through the read map), the
; dirty-row skip proven; the CGA and Hercules tables checked, and the
; Hercules converter run into RAM (the test DOSBox is a VGA: a Hercules
; cannot be shown there). Text mode back, then the PASS lines.
; /AUTO: each picture ~0.6 s. Without it: a key after each picture.
        org  100h
        include '..\..\ENGINE\E_8086.INC'

; REC v, 'name' - AX must be v; kept, printed once text mode is back
macro REC v, text
{
        local ..s, ..k
        push bx
        mov  bx,[nrec]
        mov  [rgot+bx],ax
        mov  word [rwant+bx],v
        mov  word [rname+bx],..s
        add  word [nrec],2      ; one more record
        pop  bx
        jmp  ..k
..s     db   text,0
..k:
}
; KEEPS fn, 'name' - fn must keep AX BX CX DX SI DI BP ES
macro KEEPS fn, text
{
        local ..bad, ..done
        mov  ax,1111h
        mov  bx,2222h
        mov  cx,3333h
        mov  dx,4444h
        mov  si,5555h
        mov  di,6666h
        mov  bp,7777h
        push ds
        pop  es
        call fn
        cmp  ax,1111h
        jne  ..bad
        cmp  bx,2222h
        jne  ..bad
        cmp  cx,3333h
        jne  ..bad
        cmp  dx,4444h
        jne  ..bad
        cmp  si,5555h
        jne  ..bad
        cmp  di,6666h
        jne  ..bad
        cmp  bp,7777h
        jne  ..bad
        mov  ax,es
        mov  bx,ds
        cmp  ax,bx
        jne  ..bad
        xor  ax,ax
        jmp  ..done
..bad:  mov  ax,1
..done: REC  0, text
}

start:  call GETAUTO
        call CRD_DETECT
        mov  al,[crd_card]
        xor  ah,ah
        mov  [found],ax         ; printed at the end, whatever it is
        mov  al,[crd_cap]       ; caps as a number: EGAW EGA CGA HGC VGA
        mov  ah,[crd_cap+1]     ;  -> bits 4..0 (EGAW = 16)
        mov  cl,4
        shl  al,cl              ; EGAW -> bit 4
        mov  bl,ah
        mov  cl,3
        shl  bl,cl              ; EGA -> bit 3
        or   al,bl
        mov  bl,[crd_cap+2]
        shl  bl,1
        shl  bl,1               ; CGA -> bit 2
        or   al,bl
        mov  bl,[crd_cap+3]
        shl  bl,1               ; HGC -> bit 1
        or   al,bl
        or   al,[crd_cap+4]     ; VGA -> bit 0
        xor  ah,ah
        mov  [capbits],ax
        REC  1Dh, 'CRD_DETECT on this VGA: EGA640 EGA CGA VGA, no Hercules (1Dh)'
        mov  al,[crd_card]
        xor  ah,ah
        REC  CRD_EGAW, 'CRD_DETECT best card = EGA 640'
        mov  al,[crd_isvga]
        xor  ah,ah
        REC  1, 'CRD_DETECT crd_isvga = 1'
        KEEPS CRD_DETECT, 'CRD_DETECT keeps registers'

        mov  byte [crd_card],CRD_HGC   ; absent here: refused, nothing set
        call CRD_SET
        sbb  ax,ax
        REC  -1, 'CRD_SET refuses a Hercules on a VGA: CF = 1'
        mov  ah,0Fh
        int  10h
        xor  ah,ah
        REC  3, 'CRD_SET refusing leaves text mode 3'

; ---- EGA 0Dh -----------------------------------------------------------
        mov  byte [crd_card],CRD_EGA
        call CRD_MEM
        sbb  ax,ax
        REC  0, 'CRD_MEM CF = 0'
        mov  ax,[crd_rowb]
        REC  160, 'CRD_MEM narrow: 160 bytes a row'
        call CRD_SET
        sbb  ax,ax
        REC  0, 'CRD_SET EGA: CF = 0'
        mov  ah,0Fh
        int  10h
        xor  ah,ah
        REC  0Dh, 'CRD_SET EGA: mode 0Dh'
        call BARS               ; the picture: sixteen colour bars
        call PATTERN            ; row 0's test bytes
        KEEPS CRD_BLIT, 'CRD_BLIT (EGA) keeps registers'
        mov  di,0
        mov  al,0
        call RDPL
        REC  0AAh, 'EGA plane 0 byte 0: F0 F0 F0 F0 -> AAh'
        mov  di,1
        mov  al,0
        call RDPL
        REC  0FFh, 'EGA plane 0 byte 1: colour 1 -> FFh'
        mov  di,1
        mov  al,1
        call RDPL
        REC  0, 'EGA plane 1 byte 1: colour 1 -> 0'
        mov  di,1
        mov  al,3
        call RDPL
        REC  0, 'EGA plane 3 byte 1: colour 1 -> 0'
        mov  di,0
        mov  al,3
        call RDPL
        REC  0AAh, 'EGA plane 3 byte 0: colour F -> AAh'
        push es                 ; the dirty skip: a mark straight on the
        mov  ax,0A000h          ;  card in row 5, an unchanged buffer
        mov  es,ax
        mov  byte [es:5*40],5Ah ; (map mask 0Fh: all four planes)
        pop  es
        call CRD_BLIT
        mov  di,5*40
        mov  al,0
        call RDPL
        REC  5Ah, 'CRD_BLIT skips an unchanged row (mark kept)'
        push es
        mov  es,[crd_buf]
        mov  byte [es:5*160],0FFh  ; row 5's first two pixels white
        pop  es
        call CRD_BLIT
        mov  di,5*40
        mov  al,0
        call RDPL
        REC  0C0h, 'CRD_BLIT sends a changed row: C0h'
        call HOLD

; ---- EGA 640, 0Eh --------------------------------------------------------
        mov  byte [crd_card],CRD_EGAW
        call CRD_MEM
        mov  ax,[crd_rowb]
        REC  320, 'CRD_MEM EGA 640: 320 bytes a row'
        call CRD_SET
        mov  ah,0Fh
        int  10h
        xor  ah,ah
        REC  0Eh, 'CRD_SET EGA 640: mode 0Eh'
        call BARS
        call PATTERN
        call CRD_BLIT
        mov  di,0
        mov  al,0
        call RDPL
        REC  0AAh, 'EGA 640 plane 0 byte 0 -> AAh'
        mov  di,80+1            ; row 1, byte 1 (80 a row): bar 0
        mov  al,2
        call RDPL
        REC  0, 'EGA 640 plane 2 row 1 byte 1 (bar 0) -> 0'
        push es
        mov  ax,0A000h
        mov  es,ax
        mov  byte [es:7*80],33h ; a mark in row 7
        pop  es
        call CRD_BLIT
        mov  di,7*80
        mov  al,0
        call RDPL
        REC  33h, 'CRD_BLIT EGA 640 skips an unchanged row (checksum)'
        call HOLD

; ---- CGA, mode 4 ---------------------------------------------------------
        mov  byte [crd_card],CRD_CGA
        call CRD_MEM
        call CRD_SET
        mov  ah,0Fh
        int  10h
        xor  ah,ah
        REC  4, 'CRD_SET CGA: mode 4'
        mov  al,[crd_tab+0FFh]  ; parity 0, byte FFh: left half F0h
        xor  ah,ah
        REC  0F0h, 'CRD_MKTAB CGA: white left half = F0h'
        mov  al,[crd_tab+256+11h]
        xor  ah,ah
        REC  01h, 'CRD_MKTAB CGA: colour 1 right half, even row = 01h'
        call BARS
        call PATTERN
        push es
        mov  es,[crd_buf]
        mov  word [es:160+2],1111h ; row 1, bytes 2,3: colour 1
        pop  es
        call CRD_BLIT
        push es
        mov  ax,0B800h
        mov  es,ax
        mov  al,[es:0]
        mov  bl,[es:2]
        mov  cl,[es:2000h+1]
        pop  es
        xor  ah,ah
        REC  0CCh, 'CGA B800:0 F,0,F,0 -> CCh'
        mov  al,bl
        REC  11h, 'CGA B800:2 colour 1 even row -> 11h'
        mov  al,cl
        REC  0, 'CGA B800:2001 colour 1 odd row -> 0'
        call HOLD

; ---- mode 13h --------------------------------------------------------------
        mov  byte [crd_card],CRD_VGA
        call CRD_MEM
        call CRD_SET
        mov  ah,0Fh
        int  10h
        xor  ah,ah
        REC  13h, 'CRD_SET VGA: mode 13h'
        call BARS
        call PATTERN
        call CRD_BLIT
        push es
        mov  ax,0A000h
        mov  es,ax
        mov  ax,[es:0]          ; pixels 0, 1
        mov  bx,[es:8]          ; pixels 8, 9
        pop  es
        REC  000Fh, 'VGA 13h pixels 0,1 = F, 0'
        mov  ax,bx
        REC  0101h, 'VGA 13h pixels 8,9 = 1, 1'
        mov  dx,3C7h
        mov  al,9
        out  dx,al              ; read DAC 9
        mov  dx,3C9h
        in   al,dx              ; red
        in   al,dx              ; green
        in   al,dx              ; blue
        xor  ah,ah
        REC  63, 'CRD_SET VGA: DAC 9 blue = 63 (crd_pal)'
        call HOLD

; ---- Hercules: the tables, and the converter into RAM ---------------------
        mov  byte [crd_card],CRD_HGC
        KEEPS CRD_MKTAB, 'CRD_MKTAB keeps registers'
        mov  al,[crd_tab+0FFh]
        xor  ah,ah
        REC  0F0h, 'CRD_MKTAB HGC: white even row left half = F0h'
        mov  al,[crd_tab+512+77h]
        xor  ah,ah
        REC  50h, 'CRD_MKTAB HGC: grey (3) odd row left half = 50h'
        mov  bx,800h            ; 32K for a pretend Hercules page
        mov  ah,48h
        int  21h
        jnc  .hm
        xor  ax,ax
.hm:    mov  [hpage],ax
        or   ax,ax
        jz   .nohg
        mov  [crd_hgcseg],ax
        push es
        mov  es,ax
        xor  di,di
        xor  ax,ax
        mov  cx,4000h
        rep  stosw              ; the page clear
        pop  es
        mov  byte [crd_full],1
        call CRD_BLIT           ; (the screen stays mode 13h: RAM only)
        push es
        mov  es,[hpage]
        mov  al,[es:545]        ; row 24 = bank 0, 6*90 + 5
        mov  bl,[es:547]
        mov  cl,[es:2000h+547]  ; row 25 = bank 1
        pop  es
        xor  ah,ah
        REC  0CCh, 'HGC row 24 byte 545: F,0,F,0 -> CCh'
        mov  al,bl
        REC  0AAh, 'HGC row 24 byte 547: colour 1 even -> AAh'
        mov  al,cl
        REC  0, 'HGC row 25 byte 547: colour 1 odd -> 0'
.nohg:  mov  ax,[hpage]
        or   ax,ax
        mov  ax,0
        jnz  .hok
        dec  ax                 ; none: -1
.hok:
        REC  0, 'Hercules page in RAM allocated'
        mov  word [crd_hgcseg],0B000h

        mov  byte [crd_card],CRD_VGA   ; the mode up is 13h's
        KEEPS CRD_RESET, 'CRD_RESET keeps registers'
        mov  ah,0Fh
        int  10h
        xor  ah,ah
        REC  3, 'CRD_RESET: text mode 3 back'
        call PRINTREC
        mov  ax,4C00h
        int  21h

; BARS - the buffer: sixteen colour bars, 20 columns each (narrow or wide)
BARS:   push ax
        push bx
        push cx
        push dx
        push di
        push es
        mov  es,[crd_buf]
        xor  di,di
        xor  dx,dx              ; DX = y
.row:   xor  bx,bx              ; BX = byte in the row
.b:     mov  ax,bx
        cmp  byte [crd_wide],0
        jne  .w
        shl  ax,1               ; narrow: a byte is 2 columns
.w:     mov  cl,20
        div  cl                 ; AL = column / 20 (CL is never 0)
        and  al,0Fh
        mov  ah,11h
        mul  ah                 ; both nibbles
        stosb
        inc  bx                 ; the next byte
        cmp  bx,[crd_rowb]
        jb   .b
        inc  dx                 ; the next row
        cmp  dx,200
        jb   .row
        pop  es
        pop  di
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret

; PATTERN - row 0: bytes 0..3 F0h (white, black...), 4..7 11h (colour 1)
PATTERN:push es
        mov  es,[crd_buf]
        mov  word [es:0],0F0F0h
        mov  word [es:2],0F0F0h
        mov  word [es:4],1111h
        mov  word [es:6],1111h
        pop  es
        ret

; RDPL - AL = the EGA plane AL's byte at A000:DI (read map, 3CEh index 4)
RDPL:   push dx
        push es
        mov  ah,al
        mov  al,4               ; graphics register 4: the read map
        mov  dx,3CEh
        out  dx,ax
        mov  ax,0A000h
        mov  es,ax
        mov  al,[es:di]
        xor  ah,ah
        pop  es
        pop  dx
        ret

; HOLD - /AUTO: about 0.6 s by the BIOS tick; else a key
HOLD:   push ax
        push cx
        push es
        cmp  byte [auto],0
        jne  .tick
        xor  ah,ah
        int  16h
        jmp  .out
.tick:  xor  ax,ax
        mov  es,ax
        mov  cx,11              ; ticks: 0.6 s
.t:     mov  ax,[es:046Ch]
.w:     cmp  ax,[es:046Ch]
        je   .w                 ; the next tick
        loop .t
.out:   pop  es
        pop  cx
        pop  ax
        ret

; GETAUTO - [auto] = 1 if the command tail holds /AUTO
GETAUTO:mov  si,81h
        mov  cl,[80h]
        xor  ch,ch
.s:     cmp  cx,5
        jb   .no
        mov  ax,[si]
        and  ax,0DFFFh          ; 'a'..'u' up ('/' unchanged)
        cmp  ax,'/A'
        jne  .n
        mov  ax,[si+2]
        and  ax,0DFDFh
        cmp  ax,'UT'
        jne  .n
        mov  al,[si+4]
        and  al,0DFh
        cmp  al,'O'
        jne  .n
        mov  byte [auto],1
        ret
.n:     inc  si
        dec  cx
        jmp  .s
.no:    ret

; PRINTREC - every record: PASS/FAIL name got N; then ALL PASS or not
PRINTREC:
        mov  dx,mfound
        mov  ah,9
        int  21h
        mov  ax,[found]
        call PNUM
        mov  dx,mcaps
        mov  ah,9
        int  21h
        mov  ax,[capbits]
        call PNUM
        mov  dx,crlf
        mov  ah,9
        int  21h
        xor  bx,bx
        mov  byte [allok],1
.r:     cmp  bx,[nrec]
        jae  .end
        mov  ax,[rgot+bx]
        mov  dx,mpass
        cmp  ax,[rwant+bx]
        je   .p
        mov  dx,mfail
        mov  byte [allok],0
.p:     mov  ah,9
        int  21h
        mov  si,[rname+bx]
        call PSTR
        mov  dx,mgot
        mov  ah,9
        int  21h
        mov  ax,[rgot+bx]
        call PNUM
        mov  dx,crlf
        mov  ah,9
        int  21h
        add  bx,2               ; the next record
        jmp  .r
.end:   mov  dx,mall
        cmp  byte [allok],0
        jne  .a
        mov  dx,mnot
.a:     mov  ah,9
        int  21h
        ret
; PSTR - the zero-ended string SI to DOS
PSTR:   lodsb
        or   al,al
        jz   .e
        mov  dl,al
        mov  ah,2
        int  21h
        jmp  PSTR
.e:     ret
; PNUM - AX as a signed decimal to DOS
PNUM:   push bx
        or   ax,ax
        jns  .p
        push ax
        mov  dl,'-'
        mov  ah,2
        int  21h
        pop  ax
        neg  ax                 ; its size
.p:     xor  cx,cx
        mov  bx,10
.d:     xor  dx,dx
        div  bx                 ; AX = /10, DX = the digit (BX = 10)
        push dx
        inc  cx                 ; one more digit
        or   ax,ax
        jnz  .d
.o:     pop  dx
        add  dl,'0'
        mov  ah,2
        int  21h
        loop .o
        pop  bx
        ret

auto    db 0
allok   db 0
found   dw 0
capbits dw 0
hpage   dw 0
nrec    dw 0
mfound  db 'CRD_DETECT: crd_card = $'
mcaps   db '  caps (EGA640 EGA CGA HGC VGA as bits 4..0) = $'
mpass   db 'PASS $'
mfail   db 'FAIL $'
mgot    db '  got $'
mall    db 'ALL PASS',13,10,'$'
mnot    db 'SOME FAILED',13,10,'$'
crlf    db 13,10,'$'
rgot    rw 48
rwant   rw 48
rname   rw 48

        include '..\..\KIT\LIB\K_CARD.INC'
