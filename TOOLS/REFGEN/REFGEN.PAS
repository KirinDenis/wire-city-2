{ ==========================================================================
  REFGEN - build scenes with the real Turbo Vision and dump what it drew.

  This is the reference rig. Not a screenshot of it, not a photograph of a
  screenshot: the actual bytes Turbo Vision put in video memory, written to
  a file, one file per scene.

  There is no resident, no hotkey and nobody pressing anything. The program
  constructs a scene, lets Turbo Vision draw it, copies B800 to disk, takes
  it down and builds the next one. Run it once and the whole reference set
  exists.

  Each scene is 4000 bytes: 2000 cells of glyph byte then attribute byte -
  the same shape SCRGRAB produces, so ShotRead.exe reads either.

  Compile and run it with MAKEWIN.BAT. It needs Borland Pascal, which is not
  in this repository and will not be; this source is ours, the units it uses
  are not.
  ========================================================================== }

program RefGen;

uses Objects, Drivers, Memory, Views, Menus, Dialogs, App;

const
  cmNothing = 1000;

  SCREEN = 4000;              { 80 * 25 * 2 }

type
  TRefApp = object(TApplication)
    procedure InitMenuBar; virtual;
    procedure InitStatusLine; virtual;
  end;

var
  RefApp : TRefApp;
  Index  : Text;
  Shot   : Integer;

{ --------------------------------------------------------------------------
  A menu and a status line that look like something, because they are in
  every scene and an empty one would tell us nothing about their colours.
  -------------------------------------------------------------------------- }
procedure TRefApp.InitMenuBar;
var
  R : TRect;
begin
  GetExtent(R);
  R.B.Y := R.A.Y + 1;
  MenuBar := New(PMenuBar, Init(R, NewMenu(
    NewSubMenu('~F~ile', hcNoContext, NewMenu(
      NewItem('~O~pen', 'F3', kbF3, cmNothing, hcNoContext,
      NewItem('~S~ave', 'F2', kbF2, cmNothing, hcNoContext,
      NewLine(
      NewItem('E~x~it', 'Alt+X', kbAltX, cmQuit, hcNoContext,
      nil))))),
    NewSubMenu('~E~dit', hcNoContext, NewMenu(
      NewItem('Cu~t~', 'Shift+Del', kbShiftDel, cmNothing, hcNoContext,
      NewItem('~C~opy', 'Ctrl+Ins', kbCtrlIns, cmNothing, hcNoContext,
      NewItem('~P~aste', 'Shift+Ins', kbShiftIns, cmNothing, hcNoContext,
      nil)))),
    NewSubMenu('~W~indow', hcNoContext, NewMenu(
      NewItem('~Z~oom', 'F5', kbF5, cmZoom, hcNoContext,
      NewItem('~N~ext', 'F6', kbF6, cmNext, hcNoContext,
      nil))),
    nil))))));
end;

procedure TRefApp.InitStatusLine;
var
  R : TRect;
begin
  GetExtent(R);
  R.A.Y := R.B.Y - 1;
  StatusLine := New(PStatusLine, Init(R,
    NewStatusDef(0, $FFFF,
      NewStatusKey('~F1~ Help', kbF1, cmHelp,
      NewStatusKey('~F2~ Save', kbF2, cmNothing,
      NewStatusKey('~F3~ Open', kbF3, cmNothing,
      NewStatusKey('~Alt+F3~ Close', kbAltF3, cmClose,
      NewStatusKey('~F5~ Zoom', kbF5, cmZoom,
      NewStatusKey('~Alt+X~ Exit', kbAltX, cmQuit,
      nil)))))),
    nil)));
end;

{ --------------------------------------------------------------------------
  Write the screen out and note what it is.

  BlockWrite straight off Mem[$B800:0] - no intermediate copy and no chance
  of anything reformatting it on the way. What Turbo Vision wrote is what
  lands in the file.
  -------------------------------------------------------------------------- }
procedure Dump(const What: string);
var
  F    : file;
  Name : string[12];
begin
  Name := 'REF' + Chr(48 + Shot div 10) + Chr(48 + Shot mod 10) + '.BIN';
  Assign(F, Name);
  Rewrite(F, 1);
  BlockWrite(F, Mem[$B800:0], SCREEN);
  Close(F);
  WriteLn(Index, Name, ' ', What);
  Inc(Shot);
end;

{ Take the desktop back to nothing so the next scene starts clean. }
procedure Clear;
begin
  while Desktop^.Current <> nil do
  begin
    Desktop^.Delete(Desktop^.Current);
  end;
  RefApp.Redraw;
end;

{ ==========================================================================
  The scenes.
  ========================================================================== }

procedure SceneDesktop;
begin
  RefApp.Redraw;
  Dump('desktop, menu bar, status line - nothing else');
end;

procedure SceneOneWindow;
var
  R : TRect;
begin
  R.Assign(5, 3, 60, 18);
  Desktop^.Insert(New(PWindow, Init(R, 'One window', 1)));
  RefApp.Redraw;
  Dump('a single active window');
end;

procedure SceneTwoWindows;
var
  R : TRect;
begin
  R.Assign(3, 2, 48, 14);
  Desktop^.Insert(New(PWindow, Init(R, 'Behind', 1)));
  R.Assign(18, 7, 72, 20);
  Desktop^.Insert(New(PWindow, Init(R, 'In front', 2)));
  RefApp.Redraw;
  Dump('two windows - front active, back inactive, shadow between');
end;

procedure SceneScrollBars;
var
  R  : TRect;
  W  : PWindow;
  SB : PScrollBar;
begin
  R.Assign(8, 4, 66, 19);
  W := New(PWindow, Init(R, 'Scrollbars', 3));
  SB := W^.StandardScrollBar(sbVertical + sbHandleKeyboard);
  { 100 lines in a 13-row view: the furthest it can scroll is 87. }
  SB^.SetParams(30, 0, 87, 13, 1);
  SB := W^.StandardScrollBar(sbHorizontal + sbHandleKeyboard);
  { 100 columns in a 56-wide view: 44. }
  SB^.SetParams(20, 0, 44, 56, 1);
  Desktop^.Insert(W);
  RefApp.Redraw;
  Dump('a window with both scrollbars, thumbs off the ends');
end;

procedure SceneDialog;
var
  R     : TRect;
  D     : PDialog;
  Input : PInputLine;
begin
  R.Assign(0, 0, 48, 16);
  D := New(PDialog, Init(R, 'A dialog'));
  D^.Options := D^.Options or ofCentered;

  R.Assign(3, 3, 44, 4);
  Input := New(PInputLine, Init(R, 64));
  D^.Insert(Input);
  R.Assign(2, 2, 20, 3);
  D^.Insert(New(PLabel, Init(R, '~T~ext to find', Input)));

  R.Assign(3, 5, 44, 7);
  D^.Insert(New(PCheckBoxes, Init(R,
    NewSItem('~C~ase sensitive',
    NewSItem('~W~hole words only', nil)))));

  R.Assign(3, 8, 24, 11);
  D^.Insert(New(PRadioButtons, Init(R,
    NewSItem('~F~orward',
    NewSItem('~B~ackward',
    NewSItem('~E~ntire scope', nil))))));

  R.Assign(12, 12, 22, 14);
  D^.Insert(New(PButton, Init(R, 'O~K~', cmOK, bfDefault)));
  R.Assign(26, 12, 36, 14);
  D^.Insert(New(PButton, Init(R, 'Cancel', cmCancel, bfNormal)));

  D^.SelectNext(False);
  Desktop^.Insert(D);
  RefApp.Redraw;
  Dump('a dialog - input line, label, checkboxes, radio buttons, buttons');
end;

{ --------------------------------------------------------------------------
  A menu panel on its own.

  TMenuBox is what drops down from the menu bar, but it is an ordinary view
  and can be put on the desktop by itself - which is exactly what a local
  menu is. Inserting one here gets us its real colours and spacing without
  having to drive the menu bar, which only opens inside its own modal loop
  and cannot be photographed from outside it.
  -------------------------------------------------------------------------- }
procedure SceneMenuBox;
var
  R  : TRect;
  M  : PMenu;
  MB : PMenuBox;
begin
  M := NewMenu(
    NewItem('~O~pen', 'F3', kbF3, cmNothing, hcNoContext,
    NewItem('~S~ave', 'F2', kbF2, cmNothing, hcNoContext,
    NewLine(
    NewItem('~P~rint', '', kbNoKey, cmNothing, hcNoContext,
    NewItem('E~x~it', 'Alt+X', kbAltX, cmQuit, hcNoContext,
    nil))))));
  R.Assign(14, 6, 44, 16);
  MB := New(PMenuBox, Init(R, M, nil));
  Desktop^.Insert(MB);
  RefApp.Redraw;
  Dump('a menu panel by itself - what a local menu is');

  { And again with an item picked out, which is the one colour a panel
    standing on its own does not otherwise show. }
  MB^.Current := M^.Items;
  MB^.DrawView;
  Dump('the same panel with the first item selected');
end;

{ ========================================================================== }

begin
  Assign(Index, 'REFS.TXT');
  Rewrite(Index);
  WriteLn(Index, 'Turbo Vision reference screens, 80x25, 4000 bytes each.');
  WriteLn(Index, 'Glyph byte then attribute byte, straight from B800.');
  WriteLn(Index);

  Shot := 0;
  RefApp.Init;

  SceneDesktop;
  Clear;
  SceneOneWindow;
  Clear;
  SceneTwoWindows;
  Clear;
  SceneScrollBars;
  Clear;
  SceneDialog;
  Clear;
  SceneMenuBox;

  RefApp.Done;
  Close(Index);

  WriteLn('REFGEN wrote ', Shot, ' screens. See REFS.TXT.');
end.
