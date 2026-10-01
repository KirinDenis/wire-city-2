==============================================================================
  OWL FLY III
  A combat flight simulator for DOS, in 8086 assembly
==============================================================================

  Seven video systems, from Hercules mono to VGA, and every one of them
  flies. Two squadrons fight an attrition war over a procedural island; you
  arrive as a spectator above it and press ENTER to take a jet.

  This is new code written in the idiom of the era, not a re-release of
  anything: pure 8086 assembly, one source file of about thirty thousand
  commented lines, assembled with flat assembler, no linker and no library.
  It is a DOS program - not specifically MS-DOS. It wants DOS and a video
  card and does not care whose.


------------------------------------------------------------------------------
  RUNNING IT
------------------------------------------------------------------------------

  Everything in this archive is what runs. Nothing needs building or
  installing.

  IN DOSBOX

      mount c <the folder holding this file>
      c:
      OWLFLY3

  Tested with DOSBox 0.74-3, and with DOSBox compiled to WebAssembly
  (js-dos 8.3.20). DOSBOX.CONF in this archive holds the settings it was
  tested at; the one that matters is cycles=30000. Below that the frame
  rate suffers, and far above it the game runs faster than it was tuned
  for. In DOSBox you can also press Ctrl-F12 a few times instead.

  No emulator is included here, deliberately. DOSBox is GPL software with
  its own distribution terms, and you will have your own build of it.

  ON REAL HARDWARE

      Copy every file out of this archive into one directory and run
      OWLFLY3. An 8086 will do. A Sound Blaster is not required, but it is
      what the sound was written for.


------------------------------------------------------------------------------
  THE FIRST SCREEN
------------------------------------------------------------------------------

  The game opens on SELECT VIDEO SYSTEM. Pick what the machine actually
  has - a mode the hardware lacks is marked as missing and will not appear
  by magic.

      1  HERCULES 720x348 mono   the 6845 programmed by hand, dithered by
                                 density, with its own drawn cockpit
      2  CGA 320x200             palette 1, cyan/magenta/white. H swaps the
                                 hardware palette in flight
      3  EGA 320x200x16          runs on any EGA, the 64K card included
      4  EGA 640x350x16          EGA's best; wants a 128K card and an EGA
                                 monitor
      5  MCGA 320x200x256        the mode 13h path
      6  VGA 320x200x256         the game as born
      7  VGA 640x480x16          the crispest geometry of all

  The renderer never changes. Every mode converts the same finished
  320x200x256 frame, and the cockpit on the retro cards is its own drawn
  artwork rather than a per-pixel conversion of the VGA one.


------------------------------------------------------------------------------
  CONTROLS
------------------------------------------------------------------------------

  FLIGHT
      Arrows            pitch and roll
      Q / E             rudder left / right
                        also Z, numpad 7 / 9, or top-row 1 / 3
      W / S             throttle up / down
                        also = / - , or numpad + / -
      Shift+W           throttle to full
      Shift+S           throttle to idle
      A                 afterburner (hold)
      F                 flaps
      L                 landing gear
      B                 airbrake

  COMBAT
      ENTER             lock the target under the sight
      Backspace         launch a missile
      O                 master mode, air-to-air / air-to-ground
      SPACE             back into the sky after being shot down

  VIEWS
      F2                cockpit view
      F3                chase camera
      F4                orbit the locked target
      F5                missile camera, arm / disarm
      F6 / F7           look left / right, ninety degrees
                        also Ctrl + left / right
      M                 right MFD mode
      N                 day / night

  SYSTEMS
      G                 ground comms, VHF-FM - the army net
      U                 air comms, UHF - the squadron net
      I                 IFF transponder
      T                 TACAN
      P                 autopilot
      R                 emissions, transmit / receive
      J                 ECM
      Y                 noise jammer
      V                 sound: everything / effects only / silence

  OTHER
      TAB or F8         change seats: the jet, or the Shilka on the ground
      Alt-Q             quit


------------------------------------------------------------------------------
  TWO PLAYERS
------------------------------------------------------------------------------

  A shared sky runs over IPX, which DOSBox tunnels over UDP. One machine
  hosts with DOSBox's own "ipxnet startserver"; the other joins with
  "ipxnet connect <host address>". Then both run OWLFLY3 as usual.

  The repository has NETHOST.BAT and NETJOIN.BAT, which do exactly that and
  nothing clever.


------------------------------------------------------------------------------
  WHAT IS IN THIS ARCHIVE
------------------------------------------------------------------------------

      OWLFLY3.EXE       the game
      *.DAT             artwork, palettes, fonts, sound bank and the city
      ENGINE.RAW        the turbine sample
      DOSBOX.CONF       the settings it was tested at
      README.TXT        this file
      LICENSE.TXT       MIT
      FILE_ID.DIZ       the short description, for archives that want one
      WEB\              the same game packaged for js-dos, if you host
                        games in a browser. It contains no emulator.


------------------------------------------------------------------------------
  LICENCE AND SOURCE
------------------------------------------------------------------------------

  MIT. Copyright (c) 2026 Denys Kirin. See LICENSE.TXT.

  Every byte in this archive is the author's own work. Nothing third-party
  is redistributed here.

  Source, build instructions and the architecture notes:
      https://github.com/KirinDenis/wire-city-2

  The game in a browser, and the fuller instructions:
      https://kirindenis.github.io/wire-city-2/owlfly3.html

  The whole workshop - four games, thirteen teaching programs and the
  lessons that go with them:
      https://kirindenis.github.io/wire-city-2/
