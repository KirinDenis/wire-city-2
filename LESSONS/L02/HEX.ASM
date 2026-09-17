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

BUFSZ   =  16384                        ; how much of a file it reads: 16K

;  In C:
;
;      int main(int argc, char **argv)
;      {
;          if (argc < 2) usage();
;          strcpy(fname, argv[1]);
;          if (argc < 3) dump();
;          strcpy(numbuf, argv[2]);
;          if (argc < 4) usage();
;          strcpy(text, argv[3]);  tlen = strlen(text);
;          patch();
;      }
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
        mov  di, numbuf                 ; DI = numbuf
        call copy                       ; strcpy(numbuf, the word)
        call arg                        ; third: what to write there
        jnc  .what                      ; there is one: go on
        jmp  usage                      ; there is not: usage()
.what:  mov  di, text                   ; DI = text
        call copy                       ; strcpy(text, the word)
        mov  [tlen], cx                 ; tlen = its length
        jmp  patch                      ; patch()

; ---- open the file, read it, print it --------------------------------------
;  In C:
;
;      void dump(void)
;      {
;          openrw();  count = read(handle, buf, BUFSZ);  close();
;          for (si = 0; si < count; si += 16) {
;              printf("%04X: ", si);
;              for (bx = si, n = 16; n--; bx++)
;                  if (bx < count) printf("%02X ", buf[bx]); else printf("   ");
;              putc(' ');
;              for (bx = si, n = 16; n-- && bx < count; bx++)
;                  putc(buf[bx] < 32 || buf[bx] > 126 ? '.' : buf[bx]);
;              crlf();
;          }
;          crlf();  printf("%u bytes.\n", count);  exit(0);
;      }
dump:   call openrw                     ; openrw()
        mov  ah, 3Fh                    ; AH = 3Fh: read
        mov  bx, [handle]               ; BX = handle
        mov  cx, BUFSZ                  ; CX = up to 16K
        mov  dx, buf                    ; DX = buf
        int  21h                        ; AX = read(handle, buf, BUFSZ)
        mov  [count], ax                ; count = AX
        call close                      ; close()
                                        ;
        xor  si, si                     ; si = 0: offset within the file
.line:  mov  ax, si                     ; AX = si
        cmp  ax, [count]                ; si < count ?
        jae  .done                      ;   no: the end of the file
        call hex16                      ; the offset, four digits
        mov  dl, ':'                    ; DL = ':'
        call putc                       ; putc(':')
        mov  dl, ' '                    ; DL = ' '
        call putc                       ; putc(' ')
                                        ;
        mov  cx, 16                     ; n = 16: sixteen bytes across
        mov  bx, si                     ; bx = si
.byte:  cmp  bx, [count]                ; bx < count ?
        jae  .pad                       ;   no: past the end, pad instead
        mov  al, [buf+bx]               ; AL = buf[bx]
        call hex8                       ; two hex digits
        mov  dl, ' '                    ; DL = ' '
        call putc                       ; putc(' ')
        inc  bx                         ; bx++
        loop .byte                      ; while (--n)
        jmp  .ascii                     ; the ascii column
.pad:   mov  dl, ' '                    ; keep the ascii column lined up
        call putc                       ; putc(' ')
        call putc                       ; putc(' ')
        call putc                       ; putc(' '): three, the width of "XX "
        inc  bx                         ; bx++
        loop .pad                       ; while (--n)
                                        ;
.ascii: mov  dl, ' '                    ; DL = ' '
        call putc                       ; putc(' ')
        mov  cx, 16                     ; n = 16
        mov  bx, si                     ; bx = si
.ch:    cmp  bx, [count]                ; bx < count ?
        jae  .eol                       ;   no: the end of the line
        mov  dl, [buf+bx]               ; DL = buf[bx]
        cmp  dl, 32                     ; anything unprintable becomes a dot,
        jb   .dot                       ; or the listing walks off on its own
        cmp  dl, 126                    ; above '~' ?
        ja   .dot                       ;   yes: a dot too
        jmp  .put                       ; printable: as it is
.dot:   mov  dl, '.'                    ; DL = '.'
.put:   call putc                       ; putc(DL)
        inc  bx                         ; bx++
        loop .ch                        ; while (--n)
                                        ;
.eol:   call crlf                       ; crlf()
        add  si, 16                     ; si += 16
        jmp  .line                      ; the next line
                                        ;
.done:  call crlf                       ; crlf()
        mov  ax, [count]                ; AX = count
        call dec16                      ; in decimal
        mov  dx, bytesms                ; DX = " bytes."
        call print                      ; print()
        jmp  bye                        ; exit(0)

; ---- write the third argument at the offset given by the second ------------
;  In C:
;
;      void patch(void)
;      {
;          int at = parse(numbuf);
;          openrw();  lseek(handle, at, SEEK_SET);  write(handle, text, tlen);  close();
;          print(donems);  exit(0);
;      }
patch:  mov  si, numbuf                 ; SI = numbuf
        call parse                      ; AX = parse(numbuf): decimal, because a lesson should not
        push ax                         ; keep at:            ask for hex before it has taught it
        call openrw                     ; openrw()
        pop  dx                         ; DX = at, the low word of the offset
        mov  ah, 42h                    ; AH = 42h: seek
        xor  al, al                     ; AL = 0: from the start
        mov  bx, [handle]               ; BX = handle
        xor  cx, cx                     ; CX = 0: the high word of the offset
        int  21h                        ; lseek(handle, at, SEEK_SET)
                                        ;
        mov  ah, 40h                    ; AH = 40h: write
        mov  bx, [handle]               ; BX = handle
        mov  cx, [tlen]                 ; CX = tlen bytes
        mov  dx, text                   ; DX = text
        int  21h                        ; write(handle, text, tlen)
        call close                      ; close()
        mov  dx, donems                 ; DX = "Written. ..."
        call print                      ; print()
        jmp  bye                        ; exit(0)

usage:  mov  dx, usagems                ; DX = the usage text
        call print                      ; print()
bye:    mov  ax, 4C00h                  ; AH = 4Ch exit, AL = 0 the code
        int  21h                        ; exit(0)

; ---- the file --------------------------------------------------------------
;  In C:   void openrw(void) { handle = open(fname, O_RDWR);  if (handle < 0) { print(nofilems); exit(1); } }
openrw: mov  ah, 3Dh                    ; AH = 3Dh: open
        mov  al, 2                      ; AL = 2: for reading AND writing
        mov  dx, fname                  ; DX = fname
        int  21h                        ; AX = open(fname, O_RDWR); CF on failure
        jc   .bad                       ; failed: say so and leave
        mov  [handle], ax               ; handle = AX
        ret                             ; return
.bad:   mov  dx, nofilems               ; DX = "No such file."
        call print                      ; print()
        mov  ax, 4C01h                  ; AH = 4Ch exit, AL = 1 the code
        int  21h                        ; exit(1)

;  In C:   void close(void) { close(handle); }
close:  mov  ah, 3Eh                    ; AH = 3Eh: close
        mov  bx, [handle]               ; BX = handle
        int  21h                        ; close(handle)
        ret                             ; return

; ---- the command tail ------------------------------------------------------
; arg: SI walks the tail. Returns SI at the first character of the next word
; and CX its length; carry set when there is nothing left.
;  In C:
;
;      int arg(char **s, int *len)          /* returns 0 when nothing is left */
;      {
;          while (**s == ' ' || **s == '\t') (*s)++;
;          if (**s == '\r') return 0;
;          char *start = *s;
;          while (**s != ' ' && **s != '\t' && **s != '\r') (*s)++;
;          *len = *s - start;  *s = start;  return 1;
;      }
arg:    mov  cx, 0                      ; len = 0
.skip:  lodsb                           ; AL = *s++
        cmp  al, 13                     ; the tail ends with a carriage return
        je   .none                      ;   nothing left: return 0
        cmp  al, ' '                    ; a space ?
        je   .skip                      ;   yes: skip it
        cmp  al, 9                      ; a tab ?
        je   .skip                      ;   yes: skip it
        dec  si                         ; back onto the first real character
        push si                         ; keep start
.len:   lodsb                           ; AL = *s++
        cmp  al, 13                     ; the end of the tail ?
        je   .end                       ;   yes: the word ends
        cmp  al, ' '                    ; a space ?
        je   .end                       ;   yes: the word ends
        cmp  al, 9                      ; a tab ?
        je   .end                       ;   yes: the word ends
        inc  cx                         ; len++
        jmp  .len                       ; the next character
.end:   dec  si                         ; back onto the separator
        pop  ax                         ; AX = start
        push si                         ; keep where the word ended (unused after)
        mov  si, ax                     ; SI = start
        pop  ax                         ; SI = start, CX = length
        clc                             ; return 1: a word was found
        ret                             ; return
.none:  stc                             ; return 0: nothing left
        ret                             ; return

; copy: CX bytes from SI to DI, then a zero. Leaves SI past the word.
;  In C:   void copy(char *dst, char *src, int n) { while (n--) *dst++ = *src++;  *dst = 0; }
copy:   push cx                         ; keep n
        jcxz .z                         ; n == 0: just the zero
.c:     lodsb                           ; AL = *src++
        mov  [di], al                   ; *dst = AL
        inc  di                         ; dst++
        loop .c                         ; while (--n)
.z:     mov  byte [di], 0               ; *dst = 0
        pop  cx                         ; n back
        ret                             ; return

; parse: a decimal number at SI (zero terminated) into AX.
;  In C:   int parse(char *s) { int n = 0;  while (*s >= '0' && *s <= '9') n = n * 10 + *s++ - '0';  return n; }
parse:  xor  ax, ax                     ; n = 0
        xor  bx, bx                     ; BX = 0, so BL alone is the digit
.d:     mov  bl, [si]                   ; BL = *s
        cmp  bl, '0'                    ; below '0' ?
        jb   .done                      ;   yes: not a digit, done
        cmp  bl, '9'                    ; above '9' ?
        ja   .done                      ;   yes: not a digit, done
        sub  bl, '0'                    ; BL = the digit's value
        mov  cx, 10                     ; CX = 10
        mul  cx                         ; n *= 10
        add  ax, bx                     ; n += the digit
        inc  si                         ; s++
        jmp  .d                         ; the next character
.done:  ret                             ; return n

; ---- printing --------------------------------------------------------------
;  In C:   void putc(char c) { dos_putc(c); }   - DL, and AX comes back untouched
putc:   push ax                         ; keep AX
        mov  ah, 2                      ; AH = 2: DOS, write the character in DL
        int  21h                        ; putc(DL)
        pop  ax                         ; AX back
        ret                             ; return

;  In C:   void print(char *s) { fputs(s, stdout); }   - up to the '$'
print:  mov  ah, 9                      ; DS:DX, terminated by '$'
        int  21h                        ; print(DX)
        ret                             ; return

;  In C:   void crlf(void) { putc('\r');  putc('\n'); }
crlf:   mov  dl, 13                     ; DL = '\r'
        call putc                       ; putc('\r')
        mov  dl, 10                     ; DL = '\n'
        call putc                       ; putc('\n')
        ret                             ; return

; hex8: AL as two hex digits.
;  In C:   void hex8(unsigned char b) { nib(b >> 4);  nib(b & 15); }
hex8:   push ax                         ; keep b
        shr  al, 1                      ; AL >>= 1: the 8086 shifts by one, or by CL -
        shr  al, 1                      ; AL >>= 1:  four ones is shorter than loading CL
        shr  al, 1                      ; AL >>= 1
        shr  al, 1                      ; AL = b >> 4, the high nibble
        call nib                        ; nib(b >> 4)
        pop  ax                         ; AL = b
        push ax                         ; keep b
        and  al, 0Fh                    ; AL = b & 15, the low nibble
        call nib                        ; nib(b & 15)
        pop  ax                         ; AL = b
        ret                             ; return

;  In C:   void nib(int n) { n += '0';  if (n > '9') n += 7;  putc(n); }
nib:    and  al, 0Fh                    ; AL &= 15
        add  al, '0'                    ; AL += '0'
        cmp  al, '9'                    ; a digit ?
        jbe  .p                         ;   yes
        add  al, 7                      ;   no: hop the gap between '9' and 'A'
.p:     mov  dl, al                     ; DL = the character
        jmp  putc                       ; putc(DL), and its RET is ours

; hex16: AX as four hex digits.
;  In C:   void hex16(unsigned w) { hex8(w >> 8);  hex8(w & 255); }
hex16:  push ax                         ; keep w
        mov  al, ah                     ; AL = the high byte
        call hex8                       ; hex8(w >> 8)
        pop  ax                         ; AX = w
        push ax                         ; keep w
        call hex8                       ; hex8(w & 255): AL is the low byte
        pop  ax                         ; AX = w
        ret                             ; return

; dec16: AX as decimal, no leading zeros.
;  In C:   void dec16(unsigned n) { push n % 10, n /= 10, until n is 0;  then pop and print each digit }
dec16:  mov  cx, 0                      ; count = 0
        mov  bx, 10                     ; BX = 10
.split: xor  dx, dx                     ; DX = 0: the top half of the dividend
        div  bx                         ; AX = n / 10, DX = n % 10
        push dx                         ; push the digit
        inc  cx                         ; count++
        or   ax, ax                     ; n == 0 ?
        jnz  .split                     ;   no: again
.out:   pop  dx                         ; DL = the digit, last pushed first
        add  dl, '0'                    ; DL += '0'
        call putc                       ; putc(DL)
        loop .out                       ; while (--count)
        ret                             ; return

; ---- data ------------------------------------------------------------------
usagems db 13,10,'HEX - look at a file, and change it.',13,10,13,10
        db '  HEX file                 show every byte',13,10
        db '  HEX file offset text     write text at that offset',13,10,13,10
        db 'The offset is decimal. Nothing is backed up: the file is',13,10
        db 'changed where it lies, which is the whole point.',13,10,'$'
nofilems db 13,10,'No such file.',13,10,'$'
donems  db 13,10,'Written. Run it again - the source still says the old thing.',13,10,'$'
bytesms db ' bytes.',13,10,'$'

handle  dw 0                            ; the open file
count   dw 0                            ; how many bytes were read
tlen    dw 0                            ; how long the text to write is
fname   rb 80                           ; the first argument
numbuf  rb 16                           ; the second, as typed
text    rb 80                           ; the third
buf     rb BUFSZ                        ; the file itself, up to 16K of it
