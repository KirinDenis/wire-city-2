; ============================================================================
;  K_INI.INC - KIT: INI files - levels, texts, item lists and settings in a
;  text file a person or a model writes, read by the game at run time.
;
;  The file, as OWL NIGHT's STORY.INI and SCENE.INI:
;      ; a comment (also # at the start of a line)
;      TITLE = THE ATTIC              a key line: KEY = VALUE
;      [HALL]                         a section: the lines below are its own
;      ITEM KEY = 40,60               a key with a SUB-key: KEY SUB = VALUE
;      TEXT KEY = An old iron key.
;  Keys and sub-keys are one word each (up to 15 letters kept), compared
;  without regard to case. A value is the rest of the line, spaces at both
;  ends trimmed; it is NOT 0-ended in the text: [ini_val] and [ini_vlen].
;
;        mov  dx,fname                   ; db 'ROOM.INI',0
;        mov  di,inibuf                  ; inibuf db 4096 dup(?)
;        mov  cx,4096
;        call INI_READ                   ; CF = 1: the file is not there
;        mov  si,sHall                   ; db 'HALL',0
;        mov  di,sTitle                  ; db 'TITLE',0
;        xor  bx,bx                      ; any sub-key
;        call INI_FIND                   ; SI = the value, CX = its length
;  or line by line:
;  .next: call INI_NEXT                  ; AL = 1 [section], 2 key line
;        jc   .end                       ; ini_key / ini_sub / ini_val
;
;  The scan's cursor is a variable, [ini_pos], never a register - OWL
;  NIGHT's first parser carried it in SI and every handler that used SI
;  for its own string ended the parse after one item.
; ============================================================================

if used ini_pos
ini_txt  dw ini_empty           ; the text being read (INI_READ / INI_TEXT)
ini_pos  dw ini_empty           ; where INI_NEXT reads next
ini_key  db 16 dup(0)           ; INI_NEXT: the key / the section's name
ini_sub  db 16 dup(0)           ;  the sub-key ('' none)
ini_val  dw ini_empty           ;  the value: where it starts in the text
ini_vlen dw 0                   ;  ... and how many bytes it is
ini_empty db 0
end if

; ---- INI_SKIPSP (inside the kit): SI past spaces and tabs.
if used INI_SKIPSP
INI_SKIPSP:
        cmp  byte [si],' '
        je   .s
        cmp  byte [si],9
        jne  .out
.s:     inc  si                 ; the next byte
        jmp  INI_SKIPSP
.out:   ret
end if

; ----------------------------------------------------------------------
;@ INI_READ   read a text file into a buffer, 0-ended, and start scanning it
;  in:  DX = the file's name (0-ended), DI = the buffer, CX = its size
;       (the file is cut at CX-1 bytes; at least 2)
;  out: CF = 1 the file is not there or unreadable (the buffer holds an
;       empty text then); AX = the bytes read; [ini_txt] = [ini_pos] = DI
;  needs: -
;  from: LAB\OWLFLY4\ENGINE\STORY.ASM:2125-2148 READTXT (buffer and size
;        made parameters)
; ----------------------------------------------------------------------
if used INI_READ
INI_READ:
        push bx
        push cx
        push dx
        mov  byte [di],0        ; empty, whatever happens
        mov  [ini_txt],di
        mov  [ini_pos],di
        push cx
        mov  ax,3D00h
        int  21h                ; open for reading -> AX = handle
        pop  cx
        jc   .no
        mov  bx,ax
        dec  cx                 ; room for the 0
        mov  dx,di
        mov  ah,3Fh
        int  21h                ; read CX bytes to DS:DX -> AX = read
        jc   .close
        push di
        add  di,ax              ; past the last byte read
        mov  byte [di],0
        pop  di
        push ax
        mov  ah,3Eh
        int  21h                ; close
        pop  ax
        clc
        jmp  .out
.close: mov  ah,3Eh
        int  21h
.no:    xor  ax,ax
        stc
.out:   pop  dx
        pop  cx
        pop  bx
        ret
end if

; ----------------------------------------------------------------------
;@ INI_TEXT   scan a 0-ended INI text already in memory (built into the program)
;  in:  SI = the text
;  out: - ([ini_txt] = [ini_pos] = SI)
;  needs: -
;  from: new
; ----------------------------------------------------------------------
if used INI_TEXT
INI_TEXT:
        mov  [ini_txt],si
        mov  [ini_pos],si
        ret
end if

; ----------------------------------------------------------------------
;@ INI_REWIND scan the text again from its first line
;  in:  -
;  out: - ([ini_pos] = [ini_txt])
;  needs: INI_READ or INI_TEXT first
;  from: new
; ----------------------------------------------------------------------
if used INI_REWIND
INI_REWIND:
        push ax
        mov  ax,[ini_txt]
        mov  [ini_pos],ax
        pop  ax
        ret
end if

; ----------------------------------------------------------------------
;@ INI_NEXT   the next line that says something: a [section] or a KEY [SUB] = VALUE
;  in:  [ini_pos] (INI_READ / INI_TEXT set it)
;  out: CF = 1 the end of the text (AX = 0). Else AX = 1 a section (its
;       name in ini_key), or 2 a key line (ini_key, ini_sub - '' if
;       none -, [ini_val] and [ini_vlen]). Blank lines, comments (; or #)
;       and lines that are neither are passed over.
;  needs: -
;  from: LAB\OWLFLY4\ENGINE\STORY.ASM:2514-2642 NEXTLINE/SKIPSP (already
;        16-bit); a tab separates too, a key over 15 letters is cut, not
;        split into a sub-key, a comment on the last line is the end
; ----------------------------------------------------------------------
if used INI_NEXT
INI_NEXT:
        push bx
        push cx
        push si
        push di
        mov  si,[ini_pos]
        xor  bx,bx              ; BL = the kind found
.line:  call INI_SKIPSP
        mov  al,[si]
        test al,al
        jz   .end
        cmp  al,13
        je   .eol
        cmp  al,10
        je   .eol
        cmp  al,';'
        je   .skip
        cmp  al,'#'
        je   .skip
        cmp  al,'['
        je   .sect
        ; a key: up to a space, a tab or '='
        mov  di,ini_key
        mov  cx,15
        call INI_WORD1          ; -> AL = the byte it stopped at
        cmp  al,'='
        je   .k2
        cmp  al,' '
        je   .k2
        cmp  al,9
        jne  .skip              ; the line ended: not a key line
.k2:    call INI_SKIPSP
        mov  di,ini_sub
        mov  byte [di],0
        cmp  byte [si],'='
        je   .val
        mov  cx,15
        call INI_WORD1          ; the sub-key
        call INI_SKIPSP
        cmp  byte [si],'='
        jne  .skip              ; a third word: not a key line
.val:   inc  si                 ; past '='
        call INI_SKIPSP
        mov  [ini_val],si
        mov  di,si
.v1:    mov  al,[di]            ; to the end of the line
        test al,al
        jz   .v2
        cmp  al,13
        je   .v2
        cmp  al,10
        je   .v2
        inc  di                 ; the value's next byte
        jmp  .v1
.v2:    mov  cx,di
        sub  cx,si              ; CX = the value's length
.v3:    jcxz .v4                ; trim the spaces at its end
        cmp  byte [di-1],' '
        je   .v5
        cmp  byte [di-1],9
        jne  .v4
.v5:    dec  di                 ; one space fewer
        dec  cx                 ; ... from its length
        jmp  .v3
.v4:    mov  [ini_vlen],cx
        mov  bl,2
        jmp  .toeol
.sect:  inc  si                 ; past '['
        mov  di,ini_key
        mov  cx,15
.s1:    mov  al,[si]
        cmp  al,']'
        je   .s2
        cmp  al,13
        je   .s2
        cmp  al,10
        je   .s2
        test al,al
        jz   .s2
        jcxz .s3                ; a long name: the rest is dropped
        mov  [di],al
        inc  di                 ; the next place
        dec  cx                 ; room for one fewer
.s3:    inc  si                 ; the next letter
        jmp  .s1
.s2:    mov  byte [di],0
        mov  bl,1
        jmp  .toeol
.skip:  xor  bl,bl
.toeol: mov  al,[si]
        test al,al
        jz   .ret
        cmp  al,13
        je   .eol
        cmp  al,10
        je   .eol
        inc  si                 ; past the CR
        jmp  .toeol
.eol:   cmp  byte [si],13       ; past CR and/or LF
        jne  .e1
        inc  si                 ; past the LF
.e1:    cmp  byte [si],10
        jne  .e2
        inc  si                 ; the next byte
.e2:    test bl,bl
        jnz  .ret
        jmp  .line              ; blank or comment: the next line
.ret:   test bl,bl
        jz   .end               ; the text ended on a comment
        mov  [ini_pos],si
        xor  ah,ah
        mov  al,bl
        clc
        jmp  .out
.end:   mov  [ini_pos],si
        xor  ax,ax
        stc
.out:   pop  di
        pop  si
        pop  cx
        pop  bx
        ret
end if

; ---- INI_WORD1 (inside the kit): copy a word at SI to DI (at most CX
;  bytes kept, the rest passed over), 0-ended. Stops at a space, a tab,
;  '=', or the line's end; AL = the byte it stopped at, SI on it.
if used INI_WORD1
INI_WORD1:
.l:     mov  al,[si]
        cmp  al,' '
        je   .e
        cmp  al,9
        je   .e
        cmp  al,'='
        je   .e
        cmp  al,13
        je   .e
        cmp  al,10
        je   .e
        test al,al
        jz   .e
        jcxz .n                 ; full: passed over
        mov  [di],al
        inc  di                 ; the next place
        dec  cx                 ; room for one fewer
.n:     inc  si                 ; the next letter
        jmp  .l
.e:     mov  byte [di],0
        ret
end if

; ----------------------------------------------------------------------
;@ INI_EQ     are the 0-ended words SI and DI the same, ignoring case?  CF = 1 no
;  in:  SI, DI = the two words (mov di,ini_key to ask about the line read)
;  out: CF = 0 the same, CF = 1 different
;  needs: -
;  from: LAB\OWLFLY4\ENGINE\STORY.ASM:2711-2728 STREQ, made blind to case
; ----------------------------------------------------------------------
if used INI_EQ
INI_EQ:
        push ax
        push si
        push di
.l:     mov  al,[si]
        call INI_UP
        mov  ah,al
        mov  al,[di]
        call INI_UP
        cmp  al,ah
        jne  .no
        test al,al
        jz   .yes               ; both ended together
        inc  si                 ; the next letter of each
        inc  di                 ; ...
        jmp  .l
.yes:   clc
        jmp  .out
.no:    stc
.out:   pop  di
        pop  si
        pop  ax
        ret
end if

; ---- INI_UP (inside the kit): AL a-z -> A-Z.
if used INI_UP
INI_UP:
        cmp  al,'a'
        jb   .o
        cmp  al,'z'
        ja   .o
        sub  al,32              ; small letter -> capital
.o:     ret
end if

; ----------------------------------------------------------------------
;@ INI_NUMAT  read a decimal number at SI (CX bytes left), step past it and its comma
;  in:  SI = where, CX = bytes left in the value
;  out: AX = the number (a '-' before it allowed; -32768..65535, beyond
;       wraps); SI, CX past it and past the spaces/tabs/commas after.
;       CF = 1 no digits there (AX = 0, SI/CX past the separators)
;  needs: -
;  from: LAB\OWLFLY4\ENGINE\STORY.ASM:2652-2674 PARSENUM, 16-bit, signed,
;        separators passed so a list "40,60" or "21 22" reads in a loop
; ----------------------------------------------------------------------
if used INI_NUMAT
INI_NUMAT:
        push bx
        push dx
        call INI_SEPS           ; to the first non-separator
        xor  ax,ax              ; the number
        mov  byte [ini_neg],0
        mov  byte [ini_dig],0
        jcxz .end
        cmp  byte [si],'-'
        jne  .d
        mov  byte [ini_neg],1
        inc  si                 ; past the minus
        dec  cx                 ; one byte fewer left
.d:     jcxz .end
        mov  bl,[si]
        cmp  bl,'0'
        jb   .end
        cmp  bl,'9'
        ja   .end
        sub  bl,'0'             ; BL = the digit
        xor  bh,bh
        mov  dx,ax
        shl  ax,1               ; n * 2
        shl  ax,1               ; AX = n * 4
        add  ax,dx              ; n * 5
        shl  ax,1               ; n * 10
        add  ax,bx              ; + the digit
        mov  byte [ini_dig],1
        inc  si                 ; the next digit
        dec  cx                 ; one byte fewer left
        jmp  .d
.end:   cmp  byte [ini_neg],0
        je   .pos
        neg  ax                 ; the minus
.pos:   call INI_SEPS           ; past the comma after it
        cmp  byte [ini_dig],1
        je   .ok
        xor  ax,ax
        stc
        jmp  .out
.ok:    clc
.out:   pop  dx
        pop  bx
        ret
end if

if used ini_neg
ini_neg db 0                    ; INI_NUMAT: a minus was seen
ini_dig db 0                    ;  a digit was seen
end if

; ---- INI_SEPS (inside the kit): SI/CX past spaces, tabs and commas.
if used INI_SEPS
INI_SEPS:
.l:     jcxz .o
        cmp  byte [si],' '
        je   .s
        cmp  byte [si],9
        je   .s
        cmp  byte [si],','
        jne  .o
.s:     inc  si                 ; past the separator
        dec  cx                 ; one byte fewer left
        jmp  .l
.o:     ret
end if

; ----------------------------------------------------------------------
;@ INI_NUM    AX = the (first) number in the value of the line just read
;  in:  [ini_val] [ini_vlen] (INI_NEXT or INI_FIND set them)
;  out: AX = the number, CF = 1 the value does not start with one (AX = 0)
;  needs: a list of numbers: SI = [ini_val], CX = [ini_vlen], INI_NUMAT
;         in a loop
;  from: LAB\OWLFLY4\ENGINE\STORY.ASM:2652 PARSENUM
; ----------------------------------------------------------------------
if used INI_NUM
INI_NUM:
        push cx
        push si
        mov  si,[ini_val]
        mov  cx,[ini_vlen]
        call INI_NUMAT
        pop  si
        pop  cx
        ret
end if

; ----------------------------------------------------------------------
;@ INI_WORD   copy the next word of a list value (SI, CX bytes left) to DI, 0-ended
;  in:  SI = where, CX = bytes left, DI = where it goes, BX = its room
;       (bytes, the 0 included; at least 1)
;  out: SI, CX past the word and the separators after it (space, tab,
;       comma); CF = 1 no word left (DI gets an empty string)
;  needs: -
;  from: LAB\OWLFLY4\ENGINE\STORY.ASM:2731-2750 COPYNAME (ORDER lists)
; ----------------------------------------------------------------------
if used INI_WORD
INI_WORD:
        push ax
        push bx
        push di
        call INI_SEPS
        dec  bx                 ; room for the 0
        mov  ah,0               ; AH = 1 once a letter is taken
.l:     jcxz .e
        mov  al,[si]
        cmp  al,' '
        je   .e
        cmp  al,9
        je   .e
        cmp  al,','
        je   .e
        mov  ah,1
        test bx,bx
        jz   .n                 ; full: the rest passed over
        mov  [di],al
        inc  di                 ; the next place
        dec  bx                 ; room for one fewer
.n:     inc  si                 ; the next letter
        dec  cx                 ; one byte fewer left
        jmp  .l
.e:     mov  byte [di],0
        call INI_SEPS
        cmp  ah,1
        je   .ok
        stc
        jmp  .out
.ok:    clc
.out:   pop  di
        pop  bx
        pop  ax
        ret
end if

; ----------------------------------------------------------------------
;@ INI_COPY   copy a value (SI, CX bytes) to DI as a 0-ended string, cut to fit
;  in:  SI = the value, CX = its length, DI = where, BX = the room (bytes,
;       the 0 included; at least 1)
;  out: - (a caption for TXT_PUT, a file name for INI_READ...)
;  needs: -
;  from: new
; ----------------------------------------------------------------------
if used INI_COPY
INI_COPY:
        push ax
        push bx
        push cx
        push si
        push di
        dec  bx                 ; room for the 0
        cmp  cx,bx
        jbe  .c
        mov  cx,bx              ; cut
.c:     jcxz .z
.l:     mov  al,[si]
        mov  [di],al
        inc  si                 ; the next byte of each
        inc  di                 ; ...
        loop .l
.z:     mov  byte [di],0
        pop  di
        pop  si
        pop  cx
        pop  bx
        pop  ax
        ret
end if

; ----------------------------------------------------------------------
;@ INI_FIND   the value of KEY [SUB] in [SECTION] - anywhere in the text
;  in:  SI = the section's name (0-ended; '' or SI = 0: the lines above
;       the first section), DI = the key, BX = the sub-key (0: any, or
;       none); [ini_txt]
;  out: SI = the value, CX = its length, CF = 0 found; CF = 1 not there
;       (SI, CX kept). [ini_pos] is kept: a scan in progress goes on.
;       ini_key/ini_sub/[ini_val] are of the line found
;  needs: INI_READ or INI_TEXT first
;  from: new (STORY.ASM FINDNEXT's loop over NEXTLINE + STREQ, made one call)
; ----------------------------------------------------------------------
if used INI_FIND
INI_FIND:
        push ax
        push si
        push cx
        push di
        push dx
        mov  [ini_fsec],si
        mov  [ini_fkey],di
        mov  [ini_fsub],bx
        push word [ini_pos]     ; a scan in progress is kept
        mov  ax,[ini_txt]
        mov  [ini_pos],ax
        mov  dl,1               ; DL = 1 inside the section asked for
        test si,si
        jz   .l
        cmp  byte [si],0
        je   .l                 ; '' : the top of the file is the section
        mov  dl,0
.l:     call INI_NEXT
        jc   .no
        cmp  al,1
        jne  .key
        mov  dl,0               ; a section starts: is it the one?
        mov  si,[ini_fsec]
        test si,si
        jz   .l                 ; the top was asked for: it is over
        mov  di,ini_key
        call INI_EQ
        jc   .l
        mov  dl,1
        jmp  .l
.key:   test dl,dl
        jz   .l
        mov  si,[ini_fkey]
        mov  di,ini_key
        call INI_EQ
        jc   .l
        mov  si,[ini_fsub]
        test si,si
        jz   .yes               ; any sub-key
        mov  di,ini_sub
        call INI_EQ
        jc   .l
.yes:   pop  word [ini_pos]
        pop  dx
        pop  di
        pop  cx
        pop  si
        mov  si,[ini_val]
        mov  cx,[ini_vlen]
        pop  ax
        clc
        ret
.no:    pop  word [ini_pos]
        pop  dx
        pop  di
        pop  cx
        pop  si
        pop  ax
        stc
        ret
end if

if used ini_fsec
ini_fsec dw 0                   ; INI_FIND: what it looks for
ini_fkey dw 0
ini_fsub dw 0
end if
