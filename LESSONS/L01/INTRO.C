/* ==========================================================================
   INTRO.C - the pictures the narrator talks over, before any code is typed.

   The first ninety seconds of lesson 1 are narration: what we are going to
   build, what stands between a modern program and its pixels, and what DOS
   takes away. Without this the viewer watches a DOS prompt do nothing.

   It is a slide deck, and it is drawn the way the lesson is about to teach:
   one byte per pixel at A000, text through the video BIOS. Nothing here uses
   anything the lesson does not explain in the next ten minutes - which is the
   point, and worth saying out loud at the end of the recording.

   IT DOES NOT TIME ITSELF. Every slide waits on interrupt 16h, and the rig
   sends the key when the sentence it belongs to has been spoken. Narration
   lengths change every time the voice is re-rendered; a program counting
   BIOS ticks would drift away from them by the third slide.

       wcl -0 -ml -bcl=dos INTRO.C

   Built into the lecture rig's root, not into WORK: the lesson types into an
   empty directory, and this must not appear in the file panel.

       \INTRO

   Owlos - legacy software modernization - https://owlos.sk
   ========================================================================== */
#include <i86.h>

unsigned char far *vga = (unsigned char far *) 0xA0000000L;

#define BLACK   0
#define BLUE    1
#define GREEN   2
#define RED     4
#define GREY    8
#define BRIGHT 15
#define YELLOW 14
#define CYAN   11
#define ORANGE 42

static void SetMode(unsigned char m)
{
    union REGS r;
    r.h.ah = 0; r.h.al = m;
    int86(0x10, &r, &r);
}

static void WaitKey(void)
{
    union REGS r;
    r.h.ah = 0;
    int86(0x16, &r, &r);
}

/* ---- the whole drawing engine, and it is four functions ---------------- */

static void Plot(int x, int y, unsigned char c)
{
    if (x >= 0 && x < 320 && y >= 0 && y < 200) vga[(unsigned)y * 320 + x] = c;
}

static void HLine(int x, int y, int len, unsigned char c)
{
    while (len-- > 0) Plot(x++, y, c);
}

static void VLine(int x, int y, int len, unsigned char c)
{
    while (len-- > 0) Plot(x, y++, c);
}

static void Box(int x, int y, int w, int h, unsigned char c)
{
    HLine(x, y, w, c); HLine(x, y + h - 1, w, c);
    VLine(x, y, h, c); VLine(x + w - 1, y, h, c);
}

static void Fill(int x, int y, int w, int h, unsigned char c)
{
    int i;
    for (i = 0; i < h; i++) HLine(x, y + i, w, c);
}

/* Text through the BIOS, in the ROM font, one 8x8 cell at a time. Teletype
   (function 0Eh) works in a graphics mode and moves the cursor itself; BL is
   the colour. Column and row are in cells: 40 across, 25 down. */
static void At(int col, int row)
{
    union REGS r;
    r.h.ah = 2; r.h.bh = 0; r.h.dh = (unsigned char) row; r.h.dl = (unsigned char) col;
    int86(0x10, &r, &r);
}

static void Say(int col, int row, char *s, unsigned char c)
{
    union REGS r;
    At(col, row);
    while (*s)
    {
        r.h.ah = 0x0E; r.h.al = (unsigned char) *s++; r.h.bl = c; r.h.bh = 0;
        int86(0x10, &r, &r);
    }
}

static void Clear(void) { SetMode(0x13); }

/* Centred text. The screen is 40 cells across, so a line of n characters
   starts at (40 - n) / 2 - worked out here rather than counted by hand,
   which is how the title came to sit thirty-two pixels left of the middle. */
static void Mid(int row, char *s, unsigned char c)
{
    int n = 0;
    while (s[n]) n++;
    Say((40 - n) / 2, row, s, c);
}

/* A label centred inside a box given in CELLS, so the words sit in the
   middle of the frame instead of near one end of it. */
static void MidIn(int col, int wide, int row, char *s, unsigned char c)
{
    int n = 0;
    while (s[n]) n++;
    Say(col + (wide - n) / 2, row, s, c);
}

/* Text mode 3 - the OTHER screen the lesson teaches, at B800. Eighty
   columns instead of forty, which is where the wordy slides go. */
static void TextMode(void)
{
    SetMode(3);
}

/* ---- slide 1: the title ------------------------------------------------ */
static void Title(void)
{
    Fill(0, 56, 320, 48, BLUE);
    Mid(8,  "THE SCREEN IS MEMORY", BRIGHT);
    Mid(11, "lesson one", CYAN);
    Mid(17, "DOS   .   C   .   8086", GREY);
    Mid(21, "no library. no driver. no engine.", GREY);
}

/* ---- slide 2: the five things we are going to build --------------------
   Labels live in columns 2..23, demonstrations in 26..38, and no line of
   text shares a row with a line of graphics. The first cut had the red line
   struck through its own caption. */
static void Promise(void)
{
    int i;
    Clear();
    Say(8, 0, "WHAT WE ARE GOING TO DRAW", BRIGHT);

    Say(2, 4, "a word nothing printed", GREY);
    Say(29, 4, "HELLO", YELLOW);

    Say(2, 7, "a dot", GREY);
    Plot(248, 60, BRIGHT); Plot(249, 60, BRIGHT);
    Plot(248, 61, BRIGHT); Plot(249, 61, BRIGHT);

    Say(2, 10, "a line", GREY);
    HLine(210, 84, 90, GREEN);

    Say(2, 13, "one number different", GREY);
    HLine(210, 108, 90, RED);

    Say(2, 16, "a square: four lines", GREY);
    for (i = 0; i < 3; i++) Box(228 + i, 136 + i, 54 - 2 * i, 54 - 2 * i, YELLOW);

    Say(2, 23, "all five the same way", GREY);
}

/* ---- slide 3: what stands in the way today ----------------------------
   Outlines, not fills. The BIOS draws a character cell with a BLACK
   background, so a label inside a grey block comes out as a redaction bar. */
static void Today(void)
{
    Clear();
    Mid(0, "DRAWING A PIXEL TODAY", BRIGHT);

    /* Boxes span rows R..R+2 (24 pixels) and the label sits in row R+1, so
       the frame cannot cross the letters. The first version put an 18-pixel
       box and an 8-pixel row at the same address and drew a line through
       every word. */
    Box(80, 3 * 8, 160, 24, CYAN);   MidIn(10, 20, 4,  "your call", CYAN);
    Box(80, 7 * 8, 160, 24, GREY);   MidIn(10, 20, 8,  "an engine", GREY);
    Box(80, 11 * 8, 160, 24, GREY);  MidIn(10, 20, 12, "a driver", GREY);
    Box(80, 15 * 8, 160, 24, GREY);  MidIn(10, 20, 16, "the hardware", GREY);

    VLine(160, 3 * 8 + 24, 8, GREY);
    VLine(160, 7 * 8 + 24, 8, GREY);
    VLine(160, 11 * 8 + 24, 8, GREY);

    Mid(21, "and you will never", RED);
    Mid(22, "see any of them", RED);
}

/* ---- slide 4: what DOS takes away -------------------------------------- */
static void Dos(void)
{
    Clear();
    Mid(0, "AND IN DOS", BRIGHT);

    Box(80, 4 * 8, 160, 24, CYAN);   MidIn(10, 20, 5,  "your program", CYAN);
    Box(80, 13 * 8, 160, 24, CYAN);  MidIn(10, 20, 14, "the screen", CYAN);

    VLine(160, 4 * 8 + 24, 32, CYAN);
    HLine(156, 13 * 8 - 6, 9, CYAN);
    Plot(158, 13 * 8 - 8, CYAN); Plot(162, 13 * 8 - 8, CYAN);

    Mid(18, "one program. the whole machine.", GREY);
    Mid(21, "nothing in between, because", BRIGHT);
    Mid(22, "there is nothing to put there", BRIGHT);
}

/* ---- slide 5: and it is not nostalgia ---------------------------------- */
static void Still(void)
{
    int i;
    Clear();
    Say(7, 0, "AND THIS IS NOT NOSTALGIA", BRIGHT);

    for (i = 0; i < 3; i++)
    {
        int x = 34 + i * 88;
        Box(x, 40, 60, 44, GREY);
        Fill(x + 4, 44, 52, 30, BLUE);
        HLine(x + 20, 84, 20, GREY);
        HLine(x + 12, 90, 36, GREY);
        Plot(x + 52, 78, GREEN);
    }

    Say(3, 13, "tills. production lines.", GREY);
    Say(3, 14, "dispatch desks. accounting.", GREY);

    Say(3, 19, "still running - and the people", ORANGE);
    Say(3, 20, "who built them are retiring", ORANGE);
    Say(3, 21, "faster than it is replaced.", ORANGE);
}

/* ---- slide 6: the screen is memory ------------------------------------- */
static void Memory(void)
{
    int i, j;
    Clear();
    Say(10, 0, "SO WHAT IS A SCREEN?", BRIGHT);

    Say(2, 3, "one long row of bytes", GREY);
    for (i = 0; i < 16; i++)
    {
        Box(24 + i * 17, 40, 18, 14, GREY);
        if (i == 9) Fill(25 + i * 17, 41, 16, 12, YELLOW);
    }

    Say(2, 8, "folded, a line at a time", GREY);
    for (j = 0; j < 5; j++)
        for (i = 0; i < 16; i++)
        {
            Box(24 + i * 17, 88 + j * 14, 18, 14, GREY);
            if (j == 0 && i == 9) Fill(25 + i * 17, 89, 16, 12, YELLOW);
        }

    Say(2, 21, "write a byte into the right", BRIGHT);
    Say(2, 22, "address, and it is on the glass", BRIGHT);
}

/* ---- slide 7: which byte, exactly -------------------------------------
   The frame the whole lesson stands on, so it is not one picture but six,
   turned by the narration like all the others.

   It answers the question nobody asks out loud: why does the origin sit at
   the TOP left, when every graph ever drawn puts it at the bottom? Two
   reasons, and they are the same reason. Offset zero is the start of the
   segment, and it has to be drawn first. And it is drawn first because the
   electron beam swept the glass left to right, dropped a line, and swept
   again, from the top down - so the bytes are laid out in the order the beam
   needed them. Every canvas since has counted from the top left corner, and
   this is why.

   The grid is eight cells wide and four tall with a gap and the last one
   named, because 320 and 200 will not fit on the screen and pretending they
   might is worse than showing the break.
   ------------------------------------------------------------------------ */

#define GX 56
#define GY 40
#define GW 24
#define GH 16

static void Cell(int cx, int cy, unsigned char c)
{
    Fill(GX + cx * GW + 1, GY + cy * GH + 1, GW - 1, GH - 1, c);
}

static void Grid(void)
{
    int i, j;
    Clear();
    Mid(0, "WHICH BYTE, EXACTLY?", BRIGHT);

    Say(4, 2, "x", GREY);
    Say(7, 2, "0  1  2  3  4  5  6  7", GREY);
    Say(30, 2, "..", GREY);
    Say(33, 2, "319", GREY);

    Say(1, 4, "y", GREY);
    for (j = 0; j < 4; j++)
    {
        char lab[2];
        lab[0] = (char)('0' + j); lab[1] = 0;
        Say(3, 5 + j * 2, lab, GREY);
        for (i = 0; i < 8; i++) Box(GX + i * GW, GY + j * GH, GW + 1, GH + 1, GREY);
        Box(GX + 9 * GW, GY + j * GH, GW + 1, GH + 1, GREY);
    }
    Say(29, 5, "..", GREY);
    Say(1, 13, "..", GREY);
    Say(1, 15, "199", GREY);
    for (i = 0; i < 8; i++) Box(GX + i * GW, GY + 5 * GH, GW + 1, GH + 1, GREY);
    Box(GX + 9 * GW, GY + 5 * GH, GW + 1, GH + 1, GREY);
}

/* The beam: left to right, drop, left to right again. Drawn as arrows over
   the grid, because that order IS the memory order. */
static void Beam(void)
{
    int j;
    for (j = 0; j < 3; j++)
    {
        int y = GY + j * GH + GH / 2;
        HLine(GX + 2, y, 8 * GW - 6, GREEN);
        Plot(GX + 8 * GW - 8, y - 2, GREEN);
        Plot(GX + 8 * GW - 6, y - 1, GREEN);
        Plot(GX + 8 * GW - 8, y + 2, GREEN);
        Plot(GX + 8 * GW - 6, y + 1, GREEN);
        VLine(GX + 2, y, GH, GREEN);            /* and back to the left edge */
    }
}

static void Address(void)
{
    /* 1 - the grid, and what it is not */
    Grid();
    Mid(19, "a screen looks like a grid.", GREY);
    Mid(20, "memory is one long row.", GREY);
    WaitKey();

    /* 2 - the origin */
    Grid();
    Cell(0, 0, YELLOW);
    Say(3, 18, "0, 0 is the TOP left corner", BRIGHT);
    Say(3, 20, "offset 0 - the first byte of", CYAN);
    Say(3, 21, "the segment, so it is drawn first", CYAN);
    WaitKey();

    /* 3 - and why the beam decided that */
    Grid();
    Cell(0, 0, YELLOW);
    Beam();
    Say(3, 18, "the beam swept left to right,", GREEN);
    Say(3, 19, "dropped a line, and swept again", GREEN);
    Say(3, 21, "the bytes are in the order", BRIGHT);
    Say(3, 22, "the beam needed them", BRIGHT);
    WaitKey();

    /* 4 - along the first row, nothing to work out */
    Grid();
    Cell(5, 0, YELLOW);
    Say(3, 18, "x = 5   y = 0", CYAN);
    Say(3, 20, "offset = 5", YELLOW);
    Say(3, 22, "five along the first row", GREY);
    WaitKey();

    /* 5 - one row down is a whole width */
    Grid();
    Cell(0, 1, YELLOW);
    Say(3, 18, "x = 0   y = 1", CYAN);
    Say(3, 20, "offset = 320", YELLOW);
    Say(3, 22, "one row down is one width", GREY);
    WaitKey();

    /* 6 - and any pixel at all */
    Grid();
    Cell(5, 2, YELLOW);
    Say(3, 17, "x = 5   y = 2   width = 320", CYAN);
    Say(3, 19, "offset = y * width + x", BRIGHT);
    Say(3, 20, "       = 2 * 320 + 5", BRIGHT);
    Say(3, 21, "       = 645", YELLOW);
    Say(3, 23, "vga[645] = 15;", GREEN);
}

int main(void)
{
    SetMode(0x13);
    Title();   WaitKey();
    Promise(); WaitKey();
    Today();   WaitKey();
    Dos();     WaitKey();
    Still();   WaitKey();
    Memory();  WaitKey();
    Address(); WaitKey();          /* six pictures of its own, see above */

    /* Hand the text screen back, exactly as the lesson will insist on. */
    SetMode(3);
    return 0;
}
