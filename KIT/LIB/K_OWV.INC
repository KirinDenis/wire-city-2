; ============================================================================
;  K_OWV.INC - KIT: OWV video and compressed pictures, mode 13h, 8086.
;
;  OWV is OWL FLY 4's video format (KIT\ART\OWV.TXT says it in plain words):
;  an 800-byte header with the palette, then chunks - a KEY frame (byte
;  RLE), DELTA frames (the frame before, shifted, then 8x8 block changes),
;  PALETTE runs, AUDIO, END. This is the decoder of LAB\OWLFLY4\VIDEO\
;  OWV.INC (386, unreal mode, 640x400) PORTED to the 8086 in real mode for
;  a 320x200 file: the algorithms are the same, the code is new 16-bit code.
;
;  MEMORY: two frame segments (64000 bytes each: the frame being built and
;  the one before it) and a payload segment (64K: one chunk is read whole).
;        call OWV_ALLOC          ; asks DOS (INT 21h 4Ah, 48h) - CF = none
;  or set [owv_seg0] [owv_seg1] (0FA0h paragraphs each) and [owv_bseg]
;  (1000h paragraphs) yourself before OWV_OPEN.
;
;  USE:  a clip        mov dx,name / call OWV_OPEN / ES = 0A000h (the
;                      screen) / call OWV_PLAY / call OWV_CLOSE
;        a background  ES = your back buffer / mov dx,name / call OWV_STILL
;        a frame at a time: OWV_OPEN, then OWV_FRAME + OWV_SHOW in your loop
;        any RLE data  OWV_UNRLE (DS:SI -> ES:DI, CX bytes out)
;
;  ERRORS: CF = 1 and AL =
;     1 OWV_E_OPEN  the file is not there      5 OWV_E_SHORT the file ends inside a chunk
;     2 OWV_E_HDR   not an OWV1 header          6 OWV_E_DATA  a frame's bytes make no sense
;     3 OWV_E_SIZE  not 320x200                 7 OWV_E_MEM   no segments (OWV_ALLOC first)
;     4 OWV_E_BIG   a chunk over 64K (refused)  8 OWV_E_SHUT  no file open
;  A broken file never hangs and never writes outside the three segments:
;  every block opcode is checked against what is left of its chunk.
;
;  HOOKS - define a routine of this name in your program and it is called
;  (the OWL FLY 4 player's OWV_* hook idea). Each may change AX BX CX DX SI
;  DI BP, and must keep DS ES SS SP:
;     OWV_ONFRAME  OWV_PLAY, after each frame is shown; [owv_frame] = frames
;                  so far (1 = the first). CF = 1 stops the clip, AL = the
;                  answer OWV_PLAY then gives.
;     OWV_AUDIO    each AUDIO chunk of a file whose header says audio:
;                  [owv_bseg]:0, CX bytes, [owv_hdr+9] bit 1 = 16-bit
;                  signed (else 8-bit unsigned), [owv_hdr+12] = the rate.
;                  Without it audio is stepped over and time is the tick.
;     OWV_WAIT     replaces OWV_PLAY's wait for the frame's tick (a sound
;                  card's position as the clock): [owv_frame] is due.
;     OWV_KEY      replaces OWV_PLAY's INT 16h look: AL = an ASCII key or 0
;                  (for a program that holds INT 9 itself).
;  The header is in [owv_hdr] (800 bytes as in the file): +8 fps (byte),
;  +9 flags, +10 frames (word), +12 audio rate; [owv_pal] = owv_hdr+32 =
;  the palette now (768 bytes, 6-bit), PALETTE chunks included.
;  [owv_dac] = 1 (the start): palettes go to the DAC; 0: only to owv_pal
;  (a fade of your own brings it up - REC\R_CUTSC.ASM).
; ============================================================================

OWV_E_OPEN  = 1
OWV_E_HDR   = 2
OWV_E_SIZE  = 3
OWV_E_BIG   = 4
OWV_E_SHORT = 5
OWV_E_DATA  = 6
OWV_E_MEM   = 7
OWV_E_SHUT  = 8

; ----------------------------------------------------------------------
;@ OWV_ALLOC  ask DOS for OWV's 3 segments: 2 frames + a 64K chunk buffer
;  in:  - (a .COM; it shrinks itself to 64K first, as K_MEM's MEM_INIT)
;  out: AX; CF = 1 no memory (AL = OWV_E_MEM) - 192K of DOS memory needed
;  needs: -
;  from: new (guide rule 7, INT 21h 4Ah/48h; KITTASK "8086 port")
; ----------------------------------------------------------------------
if used OWV_ALLOC
OWV_ALLOC:
        push bx
        push es
        push cs
        pop  es                 ; ES = our PSP: the .COM's own block
        mov  bx,1000h           ; 64K, all a .COM needs
        mov  ah,4Ah             ; DOS: resize (refused only if already done
        int  21h                ; another way - 48h below tells the truth)
        mov  bx,0FA0h           ; 64000 bytes = 0FA0h paragraphs
        mov  ah,48h             ; DOS: allocate BX paragraphs -> AX
        int  21h
        jc   .no
        mov  [owv_seg0],ax
        mov  bx,0FA0h
        mov  ah,48h
        int  21h
        jc   .no
        mov  [owv_seg1],ax
        mov  bx,1000h           ; the payload: a whole 64K segment
        mov  ah,48h
        int  21h
        jc   .no
        mov  [owv_bseg],ax
        clc
        jmp  .out
.no:    mov  al,OWV_E_MEM
        stc
.out:   pop  es
        pop  bx
        ret
end if

; ----------------------------------------------------------------------
;@ OWV_OPEN   open a 320x200 OWV: header read, palette to the DAC, frames cleared
;  in:  DS:DX = the file name, 0-ended; the 3 segments set (OWV_ALLOC)
;  out: AX; CF = 1 error, AL = OWV_E_OPEN/HDR/SIZE/MEM (the file is closed)
;  needs: OWV_ALLOC (or the segments); an open file is closed first
;  from: LAB\OWLFLY4\VIDEO\OWV.INC OWVPLAY 246-275, SETPAL 1057-1066 (ported)
; ----------------------------------------------------------------------
if used OWV_OPEN
OWV_OPEN:
        push bx
        push cx
        push dx
        push di
        push es
        call OWV_CLOSE          ; one file at a time
        mov  al,OWV_E_MEM
        cmp  word [owv_seg0],0
        je   .err
        cmp  word [owv_seg1],0
        je   .err
        cmp  word [owv_bseg],0
        je   .err
        mov  ax,3D00h           ; DOS: open DS:DX for reading
        int  21h
        mov  bx,ax
        mov  al,OWV_E_OPEN
        jc   .err
        mov  [owv_fh],bx
        mov  cx,800             ; the header, the palette in it
        mov  dx,owv_hdr
        mov  ah,3Fh             ; DOS: read CX bytes from BX to DS:DX
        int  21h
        jc   .bad
        cmp  ax,800
        jne  .bad
        cmp  word [owv_hdr],'OW'
        jne  .bad
        cmp  word [owv_hdr+2],'V1'
        jne  .bad
        cmp  byte [owv_hdr+8],0 ; no frames a second: nothing to pace by
        je   .bad
        mov  al,OWV_E_SIZE
        cmp  word [owv_hdr+4],320
        jne  .shut
        cmp  word [owv_hdr+6],200
        jne  .shut
        mov  ax,[owv_seg0]
        mov  [owv_cur],ax
        mov  ax,[owv_seg1]
        mov  [owv_prev],ax
        mov  word [owv_frame],0
        cld
        mov  es,[owv_seg0]      ; both frames black (index 0): a DELTA
        xor  di,di              ; with no KEY before it starts from there
        xor  ax,ax
        mov  cx,32000           ; 64000 bytes in words
        rep  stosw
        mov  es,[owv_seg1]
        xor  di,di
        mov  cx,32000
        rep  stosw
        cmp  byte [owv_dac],0
        je   .ok
        xor  al,al              ; from entry 0
        mov  cx,256             ; all of them
        call OWV_DACOUT
.ok:    xor  ax,ax
        clc
        jmp  .out
.bad:   mov  al,OWV_E_HDR
.shut:  call OWV_CLOSE
.err:   stc
.out:   pop  es
        pop  di
        pop  dx
        pop  cx
        pop  bx
        ret

; OWV_DACOUT (inside): CX entries of owv_pal from entry AL to the DAC
OWV_DACOUT:
        push ax
        push cx
        push dx
        push si
        mov  dx,3C8h            ; DAC: the write index
        out  dx,al
        xor  ah,ah
        mov  si,ax
        shl  si,1               ; SI = entry * 2
        add  si,ax              ; SI = entry * 3: its place in owv_pal
        add  si,owv_pal
        mov  ax,cx
        shl  cx,1               ; CX = entries * 2
        add  cx,ax              ; CX = entries * 3 bytes
        inc  dx                 ; 3C9h: the data
        cld
.p:     lodsb
        out  dx,al
        loop .p
        pop  si
        pop  dx
        pop  cx
        pop  ax
        ret
end if

; ----------------------------------------------------------------------
;@ OWV_CLOSE  close the OWV file (nothing if none is open)
;  in:  -
;  out: -
;  needs: -
;  from: LAB\OWLFLY4\VIDEO\OWV.INC OWVCLOSE 787-796 (ported)
; ----------------------------------------------------------------------
if used OWV_CLOSE
OWV_CLOSE:
        push ax
        push bx
        mov  bx,[owv_fh]
        or   bx,bx
        jz   .d
        mov  ah,3Eh             ; DOS: close handle BX
        int  21h
        mov  word [owv_fh],0
.d:     pop  bx
        pop  ax
        ret
end if

; ----------------------------------------------------------------------
;@ OWV_FRAME  decode the next frame of the open OWV into [owv_cur]
;  in:  - (OWV_OPEN first)
;  out: AX: AL = 1 a frame is ready in [owv_cur] (64000 bytes, mode 13h
;       layout), [owv_frame] counted; AL = 0 the clip's end (END or end of
;       file). CF = 1 error, AL = OWV_E_BIG/SHORT/DATA/SHUT.
;       PALETTE chunks on the way go to owv_pal (and the DAC if [owv_dac]);
;       AUDIO to the hook OWV_AUDIO or stepped over; unknown chunks stepped.
;  needs: OWV_OPEN
;  from: LAB\OWLFLY4\VIDEO\OWV.INC NEXTCHUNK..BLKDONE 350-595, SHIFTFRAME
;        967-1029, RLEOUT 930-962 (ported to 16 bits, fences added)
; ----------------------------------------------------------------------
if used OWV_FRAME
OWV_FRAME:
        push bx
        push cx
        push dx
        push si
        push di
        push bp
        push es
        cld
        mov  al,OWV_E_SHUT
        cmp  word [owv_fh],0
        je   .err
.next:  mov  bx,[owv_fh]
        mov  cx,6               ; the chunk's head: type, 0, dword length
        mov  dx,owv_chd
        mov  ah,3Fh             ; DOS: read
        int  21h
        jc   .short
        or   ax,ax
        jz   .end               ; no more file: the end, cleanly
        cmp  ax,6
        jne  .short
        mov  al,[owv_chd]
        cmp  al,0FFh            ; END
        je   .end
        cmp  al,1               ; KEY
        je   .key
        cmp  al,2               ; DELTA
        je   .delta
        cmp  al,4               ; PALETTE
        je   .pal
if defined OWV_AUDIO
        cmp  al,3               ; AUDIO
        jne  .skip
        test byte [owv_hdr+9],1 ; does the header say the file has sound?
        jz   .skip
        call OWV_GET
        jc   .err
        mov  cx,[owv_len]
        call OWV_AUDIO          ; the program's: [owv_bseg]:0, CX bytes
        jmp  .next
end if
.skip:  mov  dx,word [owv_chd+2]     ; CX:DX = the length, high:low
        mov  cx,word [owv_chd+4]
        mov  bx,[owv_fh]
        mov  ax,4201h           ; DOS: seek from here; past the end is
        int  21h                ; allowed, the next read then says end
        jmp  .next

; ---- palette: first entry, count-1, 3 bytes an entry ------------------
.pal:   call OWV_GET
        jc   .err
        mov  cx,[owv_len]
        cmp  cx,2
        jb   .data
        push ds
        mov  ds,[owv_bseg]
        mov  bx,[0]             ; BL = the first entry, BH = count - 1
        pop  ds
        mov  al,bh
        xor  ah,ah
        inc  ax                 ; AX = the entries, 1..256
        mov  dx,ax
        shl  dx,1               ; DX = entries * 2
        add  dx,ax              ; DX = entries * 3 bytes
        sub  cx,2               ; CX = the bytes after the two
        cmp  cx,dx
        jb   .data              ; the chunk is shorter than it says
        mov  dl,bl
        xor  dh,dh              ; DX = the first entry
        mov  cx,256
        sub  cx,dx              ; CX = entries there are from it
        cmp  ax,cx
        jbe  .p1
        mov  ax,cx              ; never past entry 255
.p1:    mov  cx,ax              ; CX = entries to take
        mov  di,dx
        shl  di,1               ; DI = first * 2
        add  di,dx              ; DI = first * 3
        add  di,owv_pal
        push cx
        mov  ax,cx
        shl  cx,1               ; CX = entries * 2
        add  cx,ax              ; CX = entries * 3 bytes
        push ds
        pop  es                 ; ES = here (owv_pal)
        push ds
        mov  ds,[owv_bseg]
        mov  si,2
        rep  movsb
        pop  ds
        pop  cx
        cmp  byte [owv_dac],0
        je   .next
        mov  al,bl              ; from the first entry
        call OWV_DACOUT
        jmp  .next

; ---- key: the whole frame, RLE -----------------------------------------
.key:   call OWV_GET
        jc   .err
        call OWV_SWAP
        mov  es,[owv_cur]
        xor  di,di
        mov  cx,64000           ; a whole frame out
        push ds
        mov  ds,[owv_bseg]
        xor  si,si
        call OWV_UNRLE
        pop  ds
        cmp  si,[owv_len]       ; it read more than the chunk had
        ja   .data
        jmp  .done

; ---- delta: the frame before, shifted, then the 8x8 blocks -------------
.delta: call OWV_GET
        jc   .err
        cmp  word [owv_len],2
        jb   .data
        call OWV_SWAP
        push ds
        mov  ds,[owv_bseg]
        mov  ax,[0]             ; AL = dx, AH = dy: the global shift
        pop  ds
        call OWV_SHIFT
        mov  es,[owv_cur]
        xor  di,di              ; DI = the block's top-left in the frame
        xor  dx,dx              ; DX = the block's column, 0..39
        mov  [owv_by],dx        ; its row, 0..24
        mov  bp,1000            ; BP = blocks still to place (40 x 25)
        mov  si,2               ; the opcodes start after dx, dy
        mov  ds,[owv_bseg]      ; DS = the chunk now: our data is CS:
.blk:   or   bp,bp
        jz   .dend              ; every block placed
        mov  cx,[cs:owv_len]
        sub  cx,si              ; CX = bytes left in the chunk
        jbe  .dend              ; none: the rest are skips
        lodsb                   ; the opcode
        dec  cx                 ; CX = bytes left after it
        cmp  al,0FFh            ; end of frame
        je   .dend
        test al,80h
        jnz  .op
        xor  ah,ah
        mov  cx,ax
        inc  cx                 ; skip n+1 blocks
.sk:    call .adv
        jz   .dend
        loop .sk
        jmp  .blk
.op:    cmp  al,80h
        je   .fill
        cmp  al,81h
        je   .lit
        cmp  al,82h
        je   .copy
        cmp  al,83h
        je   .rle
        jmp  .bad               ; nonsense: stop, do not scribble

.fill:  jcxz .bad
        lodsb                   ; the colour
        mov  ah,al
        mov  bx,di
        mov  cx,8               ; 8 rows
.f1:    stosw
        stosw
        stosw
        stosw
        add  di,312             ; the next row down: 320 - 8
        loop .f1
        mov  di,bx
        call .adv
        jmp  .blk

.lit:   cmp  cx,64
        jb   .bad
        mov  bx,di
        mov  cx,8
.l1:    movsw
        movsw
        movsw
        movsw
        add  di,312             ; next row: 320 - 8
        loop .l1
        mov  di,bx
        call .adv
        jmp  .blk

.copy:  cmp  cx,2
        jb   .bad
        lodsw                   ; AL = cdx, AH = cdy (signed)
        mov  bx,ax
        cbw                     ; AX = cdx
        mov  cx,dx
        shl  cx,1
        shl  cx,1
        shl  cx,1               ; CX = column * 8 = the block's x
        add  cx,ax              ; CX = the source's x
        js   .bad               ; left of the frame
        cmp  cx,312
        ja   .bad               ; its right edge past 319
        mov  al,bh
        cbw                     ; AX = cdy
        mov  cx,[cs:owv_by]
        shl  cx,1
        shl  cx,1
        shl  cx,1               ; CX = row * 8 = the block's y
        add  cx,ax              ; CX = the source's y
        js   .bad               ; above the frame
        cmp  cx,192
        ja   .bad               ; its bottom past 199
        push dx                 ; IMUL writes DX: the column
        mov  cx,320
        imul cx                 ; AX = cdy * 320 (the low word is enough:
        pop  dx                 ; the sum below is a true offset, mod 64K)
        mov  cx,ax
        mov  al,bl
        cbw                     ; AX = cdx
        add  cx,ax              ; CX = cdy * 320 + cdx
        add  cx,di              ; CX = the source block, in the frame before
        push si
        push ds
        mov  si,cx
        mov  ds,[cs:owv_prev]
        mov  bx,di
        mov  cx,8
.c1:    movsw
        movsw
        movsw
        movsw
        add  si,312             ; next row: 320 - 8
        add  di,312
        loop .c1
        mov  di,bx
        pop  ds
        pop  si
        call .adv
        jmp  .blk

.rle:   cmp  cx,2
        jb   .bad
        sub  cx,2               ; CX = left after the length word
        lodsw                   ; AX = the coded length
        cmp  ax,cx
        ja   .bad
        add  ax,si
        mov  [cs:owv_nxt],ax    ; where the next opcode is - trusted
        push es                 ; over what the coder happens to eat
        push di
        push cs
        pop  es
        mov  di,owv_tmp
        mov  cx,64              ; one block out
        call OWV_UNRLE
        pop  di
        pop  es
        push ds
        push cs
        pop  ds
        mov  si,owv_tmp
        mov  bx,di
        mov  cx,8
.r1:    movsw
        movsw
        movsw
        movsw
        add  di,312             ; next row: 320 - 8
        loop .r1
        mov  di,bx
        pop  ds
        mov  si,[cs:owv_nxt]
        call .adv
        jmp  .blk

; .adv: the next block. DI += 8, a new row every 40; BP - 1, ZF = 0 left
.adv:   add  di,8               ; the block to the right
        inc  dx                 ; its column
        cmp  dx,40
        jb   .a1
        xor  dx,dx              ; a new row of blocks:
        add  di,2240            ; 320 * 8 - 320 = down 7 more rows
        inc  word [cs:owv_by]
.a1:    dec  bp                 ; one block fewer; ZF = 1 when none left
        ret

.bad:   push cs
        pop  ds
        jmp  .data
.dend:  push cs
        pop  ds
.done:  inc  word [owv_frame]   ; one more frame decoded
        mov  al,1
        clc
        jmp  .out
.end:   xor  al,al              ; the clip is over
        clc
        jmp  .out
.short: mov  al,OWV_E_SHORT
        jmp  .err
.data:  mov  al,OWV_E_DATA
.err:   stc
.out:   pop  es
        pop  bp
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        ret

; OWV_GET (inside): the chunk's payload, whole, into [owv_bseg]:0 ->
; [owv_len]. CF + AL: OWV_E_BIG over 65535 bytes, OWV_E_SHORT cut off.
OWV_GET:
        push bx
        push cx
        push dx
        mov  al,OWV_E_BIG
        cmp  word [owv_chd+4],0 ; the length's high word: 64K or more
        jne  .e
        mov  cx,word [owv_chd+2]
        mov  [owv_len],cx
        jcxz .ok                ; nothing to read
        mov  bx,[owv_fh]
        push ds
        mov  ds,[owv_bseg]
        xor  dx,dx
        mov  ah,3Fh             ; DOS: read CX bytes to DS:DX
        int  21h
        pop  ds
        jc   .sh
        cmp  ax,cx
        jne  .sh                ; the file ended inside the chunk
.ok:    clc
        jmp  .o
.sh:    mov  al,OWV_E_SHORT
.e:     stc
.o:     pop  dx
        pop  cx
        pop  bx
        ret

; OWV_SWAP (inside): the frame just shown becomes the one before
OWV_SWAP:
        push ax
        mov  ax,[owv_cur]
        xchg ax,[owv_prev]
        mov  [owv_cur],ax
        pop  ax
        ret

; OWV_SHIFT (inside): [owv_cur] = [owv_prev] moved by AL = dx, AH = dy
; pixels (signed). What scrolls in from outside is 0 - the coder never
; leaves a block that touches it as a skip.
OWV_SHIFT:
        push ax
        push bx
        push cx
        push dx
        push si
        push di
        push bp
        push ds
        push es
        mov  es,[owv_cur]
        xor  di,di
        or   ax,ax
        jnz  .moved
        mov  ds,[owv_prev]      ; nothing moved: the whole frame carries
        xor  si,si              ; over (most frames of most clips)
        mov  cx,32000           ; 64000 bytes in words
        rep  movsw
        jmp  .x
.moved: mov  bx,ax
        xor  ax,ax
        mov  cx,32000
        rep  stosw              ; clear first: the strip that comes in
        mov  al,bl
        cbw
        mov  dx,ax              ; DX = dx
        mov  al,bh
        cbw
        mov  bp,ax              ; BP = dy
        ; columns: dx >= 0 -> to x = dx from x = 0; dx < 0 -> to 0 from -dx
        xor  bx,bx              ; BX = the source's first x
        xor  di,di              ; DI = the destination's first x
        mov  cx,320
        or   dx,dx
        js   .left
        mov  di,dx
        sub  cx,dx              ; CX = 320 - dx bytes a row
        jmp  .cols
.left:  mov  bx,dx
        neg  bx                 ; BX = -dx
        add  cx,dx              ; CX = 320 + dx bytes a row
.cols:  or   cx,cx
        jle  .x                 ; moved clean off the frame
        mov  [owv_sn],cx
        ; rows: y from max(0,dy) to min(200,200+dy); the source row y - dy
        xor  ax,ax              ; AX = the first destination row
        or   bp,bp
        js   .up
        mov  ax,bp              ; dy >= 0: from row dy
.up:    mov  cx,200
        or   bp,bp
        jns  .dn
        add  cx,bp              ; dy < 0: down to 200 + dy
.dn:    sub  cx,ax              ; CX = the rows
        jle  .x
        push cx
        push ax
        mov  cx,320
        mul  cx                 ; AX = y0 * 320 (under 64000: DX = 0)
        add  di,ax              ; DI = the destination's first byte
        pop  ax
        sub  ax,bp              ; AX = the source's first row: y0 - dy
        mov  cx,320
        mul  cx                 ; AX = sy0 * 320
        add  bx,ax              ; BX = the source's first byte
        pop  dx                 ; DX = the rows
        mov  si,bx
        mov  bx,[owv_sn]        ; BX = bytes a row
        mov  ds,[owv_prev]
.row:   push si
        push di
        mov  cx,bx
        shr  cx,1               ; words
        rep  movsw
        adc  cx,cx              ; the odd byte, if one
        rep  movsb
        pop  di
        pop  si
        add  si,320             ; next row
        add  di,320
        dec  dx                 ; one row fewer
        jnz  .row
.x:     pop  es
        pop  ds
        pop  bp
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret
end if

; ----------------------------------------------------------------------
;@ OWV_SHOW   copy the decoded frame [owv_cur] to ES:0 (A000h = the screen)
;  in:  ES = the destination segment, 64000 bytes
;  out: -  (it does not wait for the retrace)
;  needs: OWV_FRAME
;  from: LAB\OWLFLY4\VIDEO\OWV.INC SHOWFRAME 597-603 (ported)
; ----------------------------------------------------------------------
if used OWV_SHOW
OWV_SHOW:
        push cx
        push si
        push di
        push ds
        cld
        mov  ds,[owv_cur]
        xor  si,si
        xor  di,di
        mov  cx,32000           ; 64000 bytes in words
        rep  movsw
        pop  ds
        pop  di
        pop  si
        pop  cx
        ret
end if

; ----------------------------------------------------------------------
;@ OWV_PLAY   play the open OWV to its end, paced by the BIOS tick at its fps
;  in:  ES = where frames are shown (0A000h = the screen); OWV_OPEN first
;  out: AX: AL = 0 the clip ended, 27 Esc or 32 Space stopped it (or what
;       OWV_ONFRAME said); CF = 1 error, AL = an OWV_E_ code
;  needs: OWV_OPEN; mode 13h set; hooks OWV_ONFRAME OWV_WAIT OWV_KEY if wanted
;  from: LAB\OWLFLY4\VIDEO\OWV.INC WAITTICK..NOKEY 678-716 (the tick path;
;        the due time by a remainder, no divide)
; ----------------------------------------------------------------------
if used OWV_PLAY
OWV_PLAY:
        push bx
        push cx
        push dx
        push si
        push di
        push bp
        mov  al,[owv_hdr+8]     ; frames a second, 1..255 (OPEN checked)
        xor  ah,ah
        mov  cx,10
        mul  cx                 ; AX = fps * 10 (at most 2550)
        mov  [owv_per],ax       ; a frame is 182 / (fps*10) ticks
        mov  word [owv_acc],0
        mov  word [owv_due],0
        call OWV_TICK
        mov  [owv_t0],ax
.f:     call OWV_FRAME
        jc   .out
        or   al,al
        jz   .out               ; the end: AL = 0, CF = 0
        call OWV_SHOW
if defined OWV_ONFRAME
        call OWV_ONFRAME
        jc   .stop
end if
        ; the next frame's due tick: 18.2 ticks a second = 182 tenths;
        ; add 182 a frame, take a tick per fps*10 - Bresenham, no divide
        add  word [owv_acc],182 ; tenths of a tick
.acc:   mov  ax,[owv_acc]
        cmp  ax,[owv_per]
        jb   .wait
        sub  ax,[owv_per]       ; a whole tick out of the remainder
        mov  [owv_acc],ax
        inc  word [owv_due]     ; the next frame one tick later
        jmp  .acc
.wait:
if defined OWV_WAIT
        call OWV_WAIT
else
.w:     call OWV_TICK
        sub  ax,[owv_t0]        ; ticks since the clip began
        cmp  ax,[owv_due]
        jb   .w
end if
if defined OWV_KEY
        call OWV_KEY
else
        mov  ah,1               ; BIOS: a key waiting? ZF = 1 none
        int  16h
        jz   .f
        xor  ah,ah              ; BIOS: take it, AL = ASCII
        int  16h
end if
        cmp  al,27
        je   .stop
        cmp  al,' '
        je   .stop
        jmp  .f
.stop:  clc
.out:   pop  bp
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        ret

; OWV_TICK (inside): AX = the BIOS tick counter's low word (0040:006Ch)
OWV_TICK:
        push ds
        mov  ax,40h
        mov  ds,ax
        mov  ax,[6Ch]
        pop  ds
        ret
end if

; ----------------------------------------------------------------------
;@ OWV_STILL  load a compressed picture: an OWV's first frame to ES:0, palette set
;  in:  DS:DX = the file name; ES = where the picture goes (64000 bytes)
;  out: AX; CF = 1 error, AL = an OWV_E_ code (the file is closed either way)
;  needs: OWV_ALLOC (or the segments); [owv_pal] keeps the palette after
;  from: new (OWL NIGHT's rooms are one-frame OWVs: BG.OWV)
; ----------------------------------------------------------------------
if used OWV_STILL
OWV_STILL:
        call OWV_OPEN
        jc   .r
        call OWV_FRAME
        jc   .c
        or   al,al
        jnz  .ok
        mov  al,OWV_E_SHORT     ; a file with no frame in it
        stc
        jmp  .c
.ok:    call OWV_SHOW
        xor  ax,ax
.c:     pushf
        call OWV_CLOSE
        popf
.r:     ret
end if

; ----------------------------------------------------------------------
;@ OWV_UNRLE  unpack OWV's byte RLE: DS:SI -> ES:DI until CX bytes are out
;  in:  DS:SI = coded bytes; ES:DI = where (CX bytes room); CX = bytes out.
;       Lead byte n = 00-7F: the next n+1 bytes as they are; n = 80-FF:
;       the next byte n-127 times (80h once .. FFh 128 times).
;       Any RLE-packed sprite or screen.
;  out: SI past what it read, DI past what it wrote, CX = 0
;  needs: -
;  from: LAB\OWLFLY4\VIDEO\OWV.INC RLEOUT 930-962 (ported)
; ----------------------------------------------------------------------
if used OWV_UNRLE
OWV_UNRLE:
        push ax
        push bx
        cld
.n:     jcxz .d
        lodsb                   ; the lead byte
        test al,80h
        jnz  .rep
        xor  ah,ah
        inc  ax                 ; AX = n + 1 bytes as they are
        cmp  ax,cx
        jbe  .l1
        mov  ax,cx              ; never past what was asked for
.l1:    sub  cx,ax              ; CX = still to make after these
        xchg ax,cx
        rep  movsb
        mov  cx,ax
        jmp  .n
.rep:   sub  al,7Fh             ; AL = 257 - n: 1..128
        xor  ah,ah
        mov  bx,ax
        cmp  bx,cx
        jbe  .r1
        mov  bx,cx              ; never past what was asked for
.r1:    sub  cx,bx              ; CX = still to make after these
        lodsb                   ; the byte to repeat
        mov  ah,al
        xchg bx,cx              ; CX = the run, BX = what is left
        shr  cx,1               ; words
        rep  stosw
        adc  cx,cx              ; the odd byte, if one
        rep  stosb
        mov  cx,bx
        jmp  .n
.d:     pop  bx
        pop  ax
        ret
end if

; ---- the state (one OWV open at a time) ------------------------------
if used OWV_OPEN | used OWV_ALLOC
owv_seg0  dw  0                 ; frame segment A (0FA0h paragraphs)
owv_seg1  dw  0                 ; frame segment B
owv_bseg  dw  0                 ; the chunk buffer (1000h paragraphs)
owv_cur   dw  0                 ; the frame being / just decoded
owv_prev  dw  0                 ; the frame before it
owv_fh    dw  0                 ; the file handle, 0 = none
owv_frame dw  0                 ; frames decoded since OWV_OPEN
owv_len   dw  0                 ; this chunk's payload bytes
owv_by    dw  0                 ; DELTA: the block row
owv_nxt   dw  0                 ; DELTA: after an RLE block
owv_sn    dw  0                 ; SHIFT: bytes a row
owv_per   dw  0                 ; PLAY: fps * 10
owv_acc   dw  0                 ; PLAY: tenths of a tick
owv_due   dw  0                 ; PLAY: the next frame's tick
owv_t0    dw  0                 ; PLAY: the clip's first tick
owv_dac   db  1                 ; 1: palettes go to the DAC
owv_chd   db  6 dup (0)         ; a chunk's head
owv_tmp   db  64 dup (0)        ; DELTA: one RLE block
owv_hdr   db  32 dup (0)        ; the header as in the file...
owv_pal   db  768 dup (0)       ; ...and its palette, 6-bit, kept current
end if
