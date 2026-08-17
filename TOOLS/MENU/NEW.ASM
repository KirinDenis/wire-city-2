; NEW.ASM - the template behind the menu's N. The copy in WORK is YOURS:
; it carries the name you chose, and nothing on the disk will ever write
; over it.
;
;   FASM MY.ASM MY.COM      builds it - use your file's own name
;   MY                      runs it
;
; It prints one star and returns to DOS. Everything past that is you.
format binary as 'com'
        org  100h               ; DOS loads a COM at offset 100h, always

start:  mov  dl, '*'            ; DL - the character to print
        mov  ah, 2              ; DOS function 2: write the character in DL
        int  21h                ; ask DOS to do it
        mov  ax, 4C00h          ; function 4Ch: exit, code 0
        int  21h
