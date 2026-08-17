/* a screen is memory. this machine has two:

     B800:0000   text      80 x 25 cells, two bytes each
     A000:0000   graphics  320 x 200 pixels, one byte each

   both are one long row of bytes, written a line at a time:

     offset = y * width + x  */

/* ==========================================================================
   MEMORY.C - Lesson 1, "The Screen Is Memory".

   The same program as MEMORY.PAS, in C. Open Watcom, 16-bit real mode, DOS.
   No graphics library, no driver, no output function: two addresses and a
   byte each.

       0xB800  the text screen. 80 x 25 cells, TWO bytes per cell -
               the character code, and then its colour attribute.
       0xA000  the graphics screen in mode 13h. 320 x 200, ONE byte per
               pixel, and that byte is the colour.

   WHY far. On this machine an address is two numbers, not one: a segment
   and an offset inside it. `far` is C admitting that - it makes the pointer
   carry both, and it is why the screen can be named at all. The Pascal
   twin hides the same thing inside Mem[$A000:o]; here it is in the type,
   where you can see it.

   Build it with Open Watcom. It is free and open source, and it is NOT on
   this disk - a C compiler is far too big to ship for one lesson, which is
   itself the lesson: the modern tool prepares things elsewhere, and the
   8086 never meets it. Get it and set it up from a command line:

       download:  https://github.com/open-watcom/open-watcom-v2/releases
                  (or the older 1.9 from openwatcom.org)
       unpack it, then tell the shell where it lives:
           set WATCOM=C:\WATCOM
           set PATH=%WATCOM%\BINW;%PATH%
           set INCLUDE=%WATCOM%\H
       then, in this file's directory:
           wcl -0 -ml -bcl=dos MEMORY.C

   -0 means write 8086 instructions, -ml is the large memory model so that
   far pointers are the normal kind, and -bcl=dos builds a plain DOS
   executable. Any 16-bit real-mode C compiler builds it the same. It waits
   for a key between stages, so press one to move along.

   Video: https://github.com/KirinDenis/wire-city-2
   Owlos - legacy software modernization - https://owlos.sk
   ========================================================================== */
#include <i86.h>

unsigned char far *text = (unsigned char far *) 0xB8000000L;
unsigned char far *vga  = (unsigned char far *) 0xA0000000L;

/* Interrupt 16h, function 0: stop until somebody presses something. */
void WaitKey(void)
{
    union REGS r;
    r.h.ah = 0;
    int86(0x16, &r, &r);
}

/* Interrupt 10h, function 0: ask the video BIOS for a screen mode. */
void SetMode(unsigned char m)
{
    union REGS r;
    r.h.ah = 0;
    r.h.al = m;
    int86(0x10, &r, &r);
}

/* Text screen. Row * 80 + column, times two - because every cell is a pair. */
void WriteAt(unsigned col, unsigned row, char *s, unsigned char a)
{
    unsigned i, o;
    for (i = 0; s[i]; i++)
    {
        o = (row * 80 + col + i) * 2;
        text[o]     = (unsigned char) s[i];
        text[o + 1] = a;
    }
}

/* Graphics screen. Row * 320 + column. One byte, and the byte is the colour. */
void Plot(unsigned x, unsigned y, unsigned char c)
{
    vga[y * 320 + x] = c;
}

int main(void)
{
    unsigned i;

    /* Nothing is cleared and nothing is printed - the video card was already
       showing these bytes before we finished writing them. */
    WriteAt(10, 5, "HELLO", 0x1F);
    WriteAt(10, 7, "nobody printed this", 0x0E);
    WaitKey();

    SetMode(0x13);

    Plot(160, 30, 15);                              /* one pixel, white */
    WaitKey();

    for (i = 60; i <= 260; i++) Plot(i, 60, 10);    /* a line, green */
    WaitKey();

    for (i = 60; i <= 260; i++) Plot(i, 75, 12);    /* one number later, red */
    WaitKey();

    for (i = 112; i <= 208; i++)                    /* a square is four lines */
    {
        Plot(i, 100, 14);
        Plot(i, 180, 14);
    }
    for (i = 100; i <= 180; i++)
    {
        Plot(112, i, 14);
        Plot(208, i, 14);
    }
    WaitKey();

    /* Always hand the text screen back. */
    SetMode(3);
    WriteAt(37,  9, "OWLOS", 0x0F);
    WriteAt(25, 11, "LEGACY SOFTWARE MODERNIZATION", 0x07);
    WriteAt(32, 13, "https://owlos.sk", 0x0E);
    WaitKey();

    return 0;
}
