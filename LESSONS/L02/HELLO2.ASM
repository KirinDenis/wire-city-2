; HELLO2.ASM - Lesson 2. The same program as an EXE: named segments, a
; header, and a stack of its own.
;
;   FASM HELLO2.ASM HELLO2.EXE
;
; One line differs from HELLO.ASM - `format MZ` instead of
; `format binary as 'com'` - and everything else here follows from it.
format MZ
entry CODE:start                ; an EXE says where it starts. A COM cannot.
stack 100h                      ; and it gets a stack segment of its own

; The segment is called VARS and not DATA because `data` is a word FASM keeps
; for itself. Segment names are yours to choose; just not that one.
segment VARS
msg     db   'HELLO FROM AN EXE$'

segment CODE
start:  mov  ax, VARS           ; the text lives in another segment now, so DS
        mov  ds, ax             ; has to be pointed at it. A COM never needs
                                ; this: there is only one segment to be in.
        mov  dx, msg
        mov  ah, 9
        int  21h
        mov  ax, 4C00h
        int  21h
