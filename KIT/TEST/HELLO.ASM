; HELLO.ASM - proves the kit's build: the paths, FASM, if used.
        org  100h
        include '..\..\ENGINE\E_8086.INC'
        mov  dx,msg
        mov  ah,9
        int  21h
        mov  ax,4C00h
        int  21h
msg     db   'KIT builds.',13,10,'$'
