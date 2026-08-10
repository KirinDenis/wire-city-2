        .model small
        .stack 100h
        .data
msg     db   'HELLO FROM AN EXE$'
        .code
start:  mov  ax, @data
        mov  ds, ax
        mov  dx, offset msg
        mov  ah, 9
        int  21h
        mov  ax, 4C00h
        int  21h
        end  start