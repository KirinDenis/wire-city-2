; ============================================================================
;  HEX.ASM - look at a file's bytes, and change them. Lesson 2's other tool.
;
;      HEX HELLO.COM              show every byte
;      HEX HELLO.COM 12 WORLD     write WORLD at offset 12
;
;  WHY THIS EXISTS. The lesson needs to do two things to a finished program:
;  read its eighteen bytes, and change five of them without assembling
;  anything. A file manager can do both, and the first recording used one -
;  but Volkov Commander is shareware. It may be used; it may not be shipped,
;  and this lesson is meant to be opened in a browser and worked through by
;  somebody who downloaded nothing.
;
;  So the tool that shows you the bytes is itself a program you can read, in
;  the language the lesson is about, built by the assembler the lesson uses.
;  That is a better answer than borrowing one.
;
;      FASM HEX.ASM HEX.COM
;
;  Owlos - legacy software modernization - https://owlos.sk
; ============================================================================
format binary as 'com'
        org  100h

BUFSZ   =  16384

start:  mov  si, 81h                    ; DOS leaves the command tail here
        call arg                        ; first: the file name
        jnc  .named                     ; NOT `jc usage`. A conditional jump on
        jmp  usage                      ; an 8086 reaches 127 bytes and USAGE is
.named: mov  di, fname                  ; further; FASM would have quietly used
        call copy                       ; the 386 form, and this is an 8086
                                        ; program. Jump over an unconditional
                                        ; jump instead - which is exactly what
                                        ; ENGINE\E_8086.INC does for the games.

        call arg                        ; second: an offset, if there is one
        jc   dump                       ; no second argument - just look
        mov  di, numbuf
        call copy
        call arg                        ; third: what to write there
        jnc  .what
        jmp  usage
.what:  mov  di, text
        call copy
        mov  [tlen], cx
        jmp  patch

; ---- open the file, read it, print it --------------------------------------
dump:   call openrw
        mov  ah, 3Fh                    ; read
        mov  bx, [handle]
        mov  cx, BUFSZ
        mov  dx, buf
        int  21h
        mov  [count], ax
        call close

        xor  si, si                     ; si = offset within the file
.line:  mov  ax, si
        cmp  ax, [count]
        jae  .done
        call hex16                      ; the offset, four digits
        mov  dl, ':'
        call putc
        mov  dl, ' '
        call putc

        mov  cx, 16                     ; sixteen bytes across
        mov  bx, si
.byte:  cmp  bx, [count]
        jae  .pad
        mov  al, [buf+bx]
        call hex8
        mov  dl, ' '
        call putc
        inc  bx
        loop .byte
        jmp  .ascii
.pad:   mov  dl, ' '                    ; keep the ascii column lined up
        call putc
        call putc
        call putc
        inc  bx
        loop .pad

.ascii: mov  dl, ' '
        call putc
        mov  cx, 16
        mov  bx, si
.ch:    cmp  bx, [count]
        jae  .eol
        mov  dl, [buf+bx]
        cmp  dl, 32                     ; anything unprintable becomes a dot,
        jb   .dot                       ; or the listing walks off on its own
        cmp  dl, 126
        ja   .dot
        jmp  .put
.dot:   mov  dl, '.'
.put:   call putc
        inc  bx
        loop .ch

.eol:   call crlf
        add  si, 16
        jmp  .line

.done:  call crlf
        mov  ax, [count]
        call dec16
        mov  dx, bytesms
        call print
        jmp  bye

; ---- write the third argument at the offset given by the second ------------
patch:  mov  si, numbuf
        call parse                      ; decimal, because a lesson should not
        push ax                         ; ask for hex before it has taught it
        call openrw
        pop  dx
        mov  ah, 42h                    ; seek from the start
        xor  al, al
        mov  bx, [handle]
        xor  cx, cx
        int  21h

        mov  ah, 40h                    ; write
        mov  bx, [handle]
        mov  cx, [tlen]
        mov  dx, text
        int  21h
        call close
        mov  dx, donems
        call print
        jmp  bye

usage:  mov  dx, usagems
        call print
bye:    mov  ax, 4C00h
        int  21h

; ---- the file --------------------------------------------------------------
openrw: mov  ah, 3Dh                    ; open for reading AND writing
        mov  al, 2
        mov  dx, fname
        int  21h
        jc   .bad
        mov  [handle], ax
        ret
.bad:   mov  dx, nofilems
        call print
        mov  ax, 4C01h
        int  21h

close:  mov  ah, 3Eh
        mov  bx, [handle]
        int  21h
        ret

; ---- the command tail ------------------------------------------------------
; arg: SI walks the tail. Returns SI at the first character of the next word
; and CX its length; carry set when there is nothing left.
arg:    mov  cx, 0
.skip:  lodsb
        cmp  al, 13                     ; the tail ends with a carriage return
        je   .none
        cmp  al, ' '
        je   .skip
        cmp  al, 9
        je   .skip
        dec  si                         ; back onto the first real character
        push si
.len:   lodsb
        cmp  al, 13
        je   .end
        cmp  al, ' '
        je   .end
        cmp  al, 9
        je   .end
        inc  cx
        jmp  .len
.end:   dec  si
        pop  ax
        push si
        mov  si, ax
        pop  ax                         ; SI = start, CX = length
        clc
        ret
.none:  stc
        ret

; copy: CX bytes from SI to DI, then a zero. Leaves SI past the word.
copy:   push cx
        jcxz .z
.c:     lodsb
        mov  [di], al
        inc  di
        loop .c
.z:     mov  byte [di], 0
        pop  cx
        ret

; parse: a decimal number at SI (zero terminated) into AX.
parse:  xor  ax, ax
        xor  bx, bx
.d:     mov  bl, [si]
        cmp  bl, '0'
        jb   .done
        cmp  bl, '9'
        ja   .done
        sub  bl, '0'
        mov  cx, 10
        mul  cx
        add  ax, bx
        inc  si
        jmp  .d
.done:  ret

; ---- printing --------------------------------------------------------------
putc:   push ax
        mov  ah, 2
        int  21h
        pop  ax
        ret

print:  mov  ah, 9                      ; DS:DX, terminated by '$'
        int  21h
        ret

crlf:   mov  dl, 13
        call putc
        mov  dl, 10
        call putc
        ret

; hex8: AL as two hex digits.
hex8:   push ax
        shr  al, 1
        shr  al, 1
        shr  al, 1
        shr  al, 1
        call nib
        pop  ax
        push ax
        and  al, 0Fh
        call nib
        pop  ax
        ret

nib:    and  al, 0Fh
        add  al, '0'
        cmp  al, '9'
        jbe  .p
        add  al, 7
.p:     mov  dl, al
        jmp  putc

; hex16: AX as four hex digits.
hex16:  push ax
        mov  al, ah
        call hex8
        pop  ax
        push ax
        call hex8
        pop  ax
        ret

; dec16: AX as decimal, no leading zeros.
dec16:  mov  cx, 0
        mov  bx, 10
.split: xor  dx, dx
        div  bx
        push dx
        inc  cx
        or   ax, ax
        jnz  .split
.out:   pop  dx
        add  dl, '0'
        call putc
        loop .out
        ret

; ---- data ------------------------------------------------------------------
usagems db 13,10,'HEX - look at a file, and change it.',13,10,13,10
        db '  HEX file                 show every byte',13,10
        db '  HEX file offset text     write text at that offset',13,10,13,10
        db 'The offset is decimal. Nothing is backed up: the file is',13,10
        db 'changed where it lies, which is the whole point.',13,10,'$'
nofilems db 13,10,'No such file.',13,10,'$'
donems  db 13,10,'Written. Run it again - the source still says the old thing.',13,10,'$'
bytesms db ' bytes.',13,10,'$'

handle  dw 0
count   dw 0
tlen    dw 0
fname   rb 80
numbuf  rb 16
text    rb 80
buf     rb BUFSZ
