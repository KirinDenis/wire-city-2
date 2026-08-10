        .model tiny
        .code
        org 100h
start:  mov  dx, offset msg
        mov  ah, 9
        int  21h
        mov  ax, 4C00h
        int  21h
msg     db   'HELLO$'
        end  start