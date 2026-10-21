; ==================================================================
;  ART.ASM - MULTIPLAY SOKO II's pictures as a file of their own:
;      FASM ART.ASM ART.DAT          (MAKE does it, before the game)
;  The pictures and the game's code together are more than the 64 KB a
;  .COM may be, so they live in ART.DAT; MULTSOK2.COM reads it at start,
;  from the folder it was started from, and compiles every picture into
;  a segment of its own.  KINDS.INC and ART.INC are TOOLS\ArtGen2's.
;  Every offset here counts from the file's first byte (FASM's binary
;  format starts at 0): ARTDIR's words are where each picture begins.
; ==================================================================
format binary as 'DAT'
        include 'KINDS.INC'
        include 'ART.INC'
