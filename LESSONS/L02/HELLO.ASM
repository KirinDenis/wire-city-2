; HELLO.ASM - Lesson 2. A COM file: no header, no segments, no linker.
;
;   FASM HELLO.ASM HELLO.COM
;
; The first line is the whole difference between this file and HELLO2.ASM.
format binary as 'com'
        org  100h               ; DOS loads a COM at offset 100h, always

start:  mov  dx, msg            ; the address of the text
        mov  ah, 9              ; DOS function 9: print until '$'
        int  21h                ; ask DOS to do it
        mov  ax, 4C00h          ; function 4Ch: exit, code 0
        int  21h

msg     db   'HELLO$'
