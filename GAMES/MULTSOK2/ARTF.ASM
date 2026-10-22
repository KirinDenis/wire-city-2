; ==================================================================
;  ARTF.ASM - MULTIPLAY SOKO II's pictures for EGA 640, a file of their
;  own:  FASM ARTF.ASM ARTF.DAT        (MAKE does it, before the game)
;  The same kinds as ART.DAT drawn twice as fine across - joints and
;  rims a pixel thin, rounder rounds - packed four bits a pixel (and a
;  bit a pixel for what is see-through): ARTF.INC, TOOLS\ArtGen2's.  At
;  EGA 640 MULTSOK2.COM compiles a picture from here where there is one
;  and doubles ART.DAT's where there is not; without this file it doubles
;  them all.  Every offset counts from the file's first byte.
; ==================================================================
format binary as 'DAT'
        include 'KINDS.INC'
        include 'ARTF.INC'
