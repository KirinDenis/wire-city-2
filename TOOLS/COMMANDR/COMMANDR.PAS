{ ==========================================================================
  COMMANDR.PAS - a two-panel file manager for DOS, in Pascal.

      RUN               both sides on the folder you are in
      RUN C:\ D:\       the left side on C:\, the right side on D:\

  The classic DOS file manager's shape: two folders side by side, and the keys along
  the bottom say what they do.

      Tab       the other side          Enter   into a folder, .. back out;
      Insert    mark a file                     on a program, it runs; on any other
                                                file, what DOS knows of it
      F1 Help   F3 View   F4 Edit   F5 Copy   F6 Move   F7 MkDir   F8 Del
      F10 Quit  Alt+F1, Alt+F2 a drive for the left or right side
                Alt+F10 the drive as a tree, and the other side follows it
                Ctrl+R  both folders read again

  F5, F6 and F8 work on the marked files, or on the one under the cursor
  when none are marked - the classic rule. Copy and move go to the other side.

  The same program is Examples\Desktop\CSharp\03-Commander, in C#. What is
  different here is who reads the disk: every folder, file and drive is
  DOS's own - FindFirst, BlockRead, MkDir, DiskSize - and the toolkit behind
  INT 60h (lib\dos\pascal\OWLOSUI.PAS) only shows what this program hands
  it. The panels, the viewer and editor with their Edit menu and colours,
  the dialogs: all of that is the resident's.
  ========================================================================== }

program Commandr;

{ A deep stack, for copying folders inside folders; and a heap of 128K -
  the viewer's buffer and an editor's text - so the rest of DOS's memory is
  free for a program Enter runs. }
{$M 32768,0,131072}

uses Dos, OwlosUI;

const
  { What the status line sends. The numbers are this program's own. }
  CmHelp = 1;       CmView = 3;       CmEdit = 4;       CmCopy = 5;
  CmMove = 6;       CmMkdir = 7;      CmDelete = 8;     CmQuit = 9;
  CmSwitch = 10;    CmTree = 11;      CmDriveLeft = 12; CmDriveRight = 13;
  CmReread = 14;
  { What the dialogs answer. }
  CmNo = 20;        CmYes = 21;       CmMkdirOk = 22;   CmSave = 23;
  CmCloseEdit = 24; CmCloseView = 25; CmDriveOk = 26;

  { Marks; no "*.*" on top; and at the bottom only what the cursor is on -
    the folder is in the window's title. }
  PanelFlags = FilesMarks or FilesNoPathLine or FilesDetails;
  TitleRoom = 26;                       { what a 40-column window's title can hold }
  MaxItems = 200;                       { names at once: marked, or folders in a tree }
  BufSize = 32000;                      { a file read for the viewer or the editor }

type
  TPanel = record
    Win, Files, Tree: Word;
    Dir: string;                        { C:\GAMES, or a root: C:\ }
    TreeRoot: string;                   { while a tree is shown: its drive, C:\ }
    TreeDir: string;                    { the folder the tree's cursor was on }
  end;
  TName = string[12];                   { a DOS name is 8.3 }
  TBuf = array[0..BufSize - 1] of Byte;

var
  Left, Right: TPanel;
  Box, AskInput, DriveList: Word;       { the dialog that is up, and its parts }
  Pending: Word;                        { what Yes does: CmCopy, CmMove, CmDelete }
  PendingTo: string;                    { and where copy and move go }
  DriveFor: Integer;                    { 1 the left side, 2 the right }
  Drives: string[26];                   { the drive list's letters, in order }
  Items: array[1..MaxItems] of TName;   { what F5, F6, F8 act on }
  ItemCount: Integer;
  ItemsFrom: string;
  Names: array[1..MaxItems] of TName;   { a folder's subfolders, for the tree }
  NameCount: Integer;
  Editor, EditorText, Viewer: Word;
  EditorPath: string;
  Failure: string;                      { the first thing that went wrong, said once }
  Buf: ^TBuf;
  Home: string;                         { where RUNPROG.BAT and COMMANDR.SAV go: the folder this
                                          started in, where its batch file looks for them }
  StartedIn: string;                    { the folder DOS was in when this started }
  CanStep: Boolean;                     { /STEP: the batch file that started this runs RUNPROG.BAT }
  Stepped: Boolean;                     { stepping out now, for a program to run }

{ ---- words ---------------------------------------------------------------- }

function IntStr(N: LongInt): string;
var
  S: string;
begin
  Str(N, S);
  IntStr := S;
end;

{ 1234567 as 1,234,567: a size read at a glance. }
function Grouped(N: LongInt): string;
var
  S: string;
  I: Integer;
begin
  S := IntStr(N);
  I := Length(S) - 3;
  while I > 0 do
  begin
    Insert(',', S, I + 1);
    Dec(I, 3);
  end;
  Grouped := S;
end;

function Two(N: Word): string;
begin
  if N < 10 then Two := '0' + IntStr(N) else Two := IntStr(N);
end;

function Upper(const S: string): string;
var
  I: Integer;
  R: string;
begin
  R := S;
  for I := 1 to Length(R) do R[I] := UpCase(R[I]);
  Upper := R;
end;

{ What DOS's error numbers mean, in words a person can act on. }
function DosText(Code: Integer): string;
begin
  case Code of
    2: DosText := 'no such file';
    3: DosText := 'no such folder';
    4: DosText := 'too many files open';
    5: DosText := 'access denied - read-only, or a folder that is not empty';
    15: DosText := 'no such drive';
    16: DosText := 'it is the current folder';
    17: DosText := 'not the same drive';
    100: DosText := 'the disk could not be read';
    101: DosText := 'the disk is full';
    150: DosText := 'the disk is write-protected';
    152: DosText := 'the drive is not ready';
  else
    DosText := 'DOS error ' + IntStr(Code);
  end;
end;

{ ---- paths ---------------------------------------------------------------- }

function IsRoot(const Dir: string): Boolean;
begin
  IsRoot := (Length(Dir) = 3) and (Dir[2] = ':') and (Dir[3] = '\');
end;

function Join(const Dir, Name: string): string;
begin
  if (Length(Dir) > 0) and (Dir[Length(Dir)] = '\') then Join := Dir + Name
  else Join := Dir + '\' + Name;
end;

{ C:\GAMES\OWL is in C:\GAMES; C:\GAMES is in C:\; C:\ stays. }
function ParentOf(const Dir: string): string;
var
  I: Integer;
begin
  ParentOf := Dir;
  if IsRoot(Dir) then Exit;
  I := Length(Dir);
  while (I > 0) and (Dir[I] <> '\') do Dec(I);
  if I <= 3 then ParentOf := Copy(Dir, 1, 3) else ParentOf := Copy(Dir, 1, I - 1);
end;

{ A folder as the program keeps it: whole, upper case, no \ at the end
  unless it is a root. }
function Normal(const Path: string): string;
var
  S: string;
begin
  S := Upper(FExpand(Path));
  if (Length(S) > 3) and (S[Length(S)] = '\') then Dec(S[0]);
  Normal := S;
end;

const
  Anything = ReadOnly or Hidden or SysFile or Directory or Archive;   { not a volume label }

function IsFolder(const Path: string): Boolean;
var
  SR: SearchRec;
begin
  if IsRoot(Path) then
  begin
    IsFolder := True;
    Exit;
  end;
  FindFirst(Path, Anything, SR);
  IsFolder := (DosError = 0) and (SR.Attr and Directory <> 0);
end;

function Exists(const Path: string): Boolean;
var
  SR: SearchRec;
begin
  FindFirst(Path, Anything, SR);
  Exists := DosError = 0;
end;

{ Whether Path is Folder or somewhere inside it. }
function Inside(const Path, Folder: string): Boolean;
var
  P, F: string;
begin
  P := Upper(Path) + '\';
  F := Upper(Folder) + '\';
  Inside := Copy(P, 1, Length(F)) = F;
end;

{ ---- dialogs -------------------------------------------------------------- }

procedure CloseBox;
begin
  if Box <> 0 then OwlClose(Box);
  Box := 0;
  AskInput := 0;
  DriveList := 0;
end;

procedure Tell(const Text: string);
begin
  CloseBox;
  Pending := 0;
  OwlMessageBox('Commander', Text, 1);
  OwlButton(CmNo, OwlDefault, '~O~K');
  Box := OwlEnd;
end;

{ A question about files. No is the default: Enter and Escape both leave
  things as they are, and doing something to files is chosen on purpose. }
procedure Ask(const Text: string; What: Word);
begin
  CloseBox;
  Pending := What;
  OwlMessageBox('Confirm', Text, 2);
  OwlButton(CmYes, 0, '~Y~es');
  OwlButton(CmNo, OwlDefault, '~N~o');
  Box := OwlEnd;
end;

{ F1: what every key does - and, as buttons, what needs Alt. }
procedure Help;
begin
  CloseBox;
  Box := OwlWindow(0, -1, -1, 66, 18, OwlDialog or OwlModal, 'Help', CmNo);
  OwlStatic(Box, 2, 1, 60, 3,
    'Tab goes to the other side. Enter opens a folder, .. goes back up; Enter on a ' +
    '.COM, .EXE or .BAT runs it, on any other file says what DOS knows. Insert marks.');
  OwlStatic(Box, 2, 5, 60, 3,
    'F3 shows a file and F4 edits it; F2 saves. F5 copies and F6 moves to the other ' +
    'side - the marked files, or the one under the cursor. F7 makes a folder, F8 deletes.');
  OwlStatic(Box, 2, 9, 60, 3,
    'Alt+F1 and Alt+F2 choose a drive for the left and the right side. Alt+F10 shows ' +
    'the drive as a tree, and the other side follows it. The buttons below do the same.');
  OwlStatic(Box, 2, 13, 60, 1, 'Ctrl+R reads both folders again. F10 quits.');
  OwlButtons(Box, 4);
  OwlButton(CmNo, OwlDefault, '~O~K');
  OwlButton(CmTree, 0, '~T~ree');
  OwlButton(CmDriveLeft, 0, '~L~eft drive');
  OwlButton(CmDriveRight, 0, '~R~ight drive');
  OwlEnd;
end;

{ ---- the panels ----------------------------------------------------------- }

{ A path for a window's title: whole if it fits, or its end - the end is the
  part that says where you are. }
function Fit(const Path: string): string;
begin
  if Length(Path) <= TitleRoom then Fit := Path
  else Fit := '...' + Copy(Path, Length(Path) - TitleRoom + 4, TitleRoom - 3);
end;

procedure OpenPanel(var P: TPanel; X, W: Integer; const Dir: string);
begin
  P.Dir := Dir;
  P.Tree := 0;
  { No shadow: the two windows tile the screen. Closing either quits. The
    title is the folder the side shows. }
  P.Win := OwlWindow(0, X, 0, W, 24, OwlBlue or OwlNoShadow, Fit(Dir), CmQuit);
  P.Files := OwlFilesEx(P.Win, 0, PanelFlags, Dir);
end;

{ Another folder in a panel, and its path in the title - or, if DOS cannot
  read it, a word why, and the old listing stays. }
procedure Go(var P: TPanel; const Dir: string);
begin
  if P.Tree <> 0 then Exit;
  if OwlSetFiles(P.Files, Dir) then
  begin
    P.Dir := Dir;
    OwlSetText(P.Win, Fit(Dir));
  end
  else OwlFilesError(P.Files, 'Cannot read ' + Dir);
end;

procedure Refresh;
begin
  Go(Left, Left.Dir);
  Go(Right, Right.Dir);
end;

{ 1 the left side is in front, 2 the right, 0 something else is. }
function Side: Integer;
var
  A: Word;
begin
  A := OwlActive;
  if A = Left.Win then Side := 1
  else if A = Right.Win then Side := 2
  else Side := 0;
end;

{ What F5, F6 and F8 act on: the marks, or the cursor. Never ... }
procedure Collect(var P: TPanel);
var
  N, I: Word;
  S: string;
begin
  ItemCount := 0;
  ItemsFrom := P.Dir;
  N := OwlMarked(P.Files);
  for I := 1 to N do
  begin
    S := OwlMarkedName(I);
    if (S <> '..') and (ItemCount < MaxItems) then
    begin
      Inc(ItemCount);
      Items[ItemCount] := S;
    end;
  end;
end;

{ The one file under the cursor, for F3 and F4. False on .., on a folder,
  and when several are marked. }
function CursorFile(var P: TPanel; var Name: string): Boolean;
begin
  CursorFile := False;
  if (P.Tree <> 0) or (OwlMarked(P.Files) <> 1) then Exit;
  Name := OwlMarkedName(1);
  if Name = '..' then Exit;
  CursorFile := not IsFolder(Join(P.Dir, Name));
end;

{ ---- the tree -------------------------------------------------------------- }

{ A folder's subfolders into Names, in alphabetical order. }
procedure SubFolders(const Dir: string);
var
  SR: SearchRec;
  I, J: Integer;
  T: TName;
begin
  NameCount := 0;
  FindFirst(Join(Dir, '*.*'), Anything, SR);
  while (DosError = 0) and (NameCount < MaxItems) do
  begin
    if (SR.Attr and Directory <> 0) and (SR.Name <> '.') and (SR.Name <> '..') then
    begin
      Inc(NameCount);
      Names[NameCount] := SR.Name;
    end;
    FindNext(SR);
  end;
  for I := 2 to NameCount do            { few enough for an insertion sort }
  begin
    T := Names[I];
    J := I - 1;
    while (J >= 1) and (Names[J] > T) do
    begin
      Names[J + 1] := Names[J];
      Dec(J);
    end;
    Names[J + 1] := T;
  end;
end;

{ Each subfolder a node that is filled when it is opened: a whole disk is
  not read to show its top. }
procedure SendNames;
var
  I: Integer;
begin
  for I := 1 to NameCount do OwlNode(NodeLazy, Names[I], 0);
end;

{ The folder a place in the tree names: the drive, then a name a level. }
function TreeDirOf(var P: TPanel; var Path: TTreePath): string;
var
  S: string;
  K: Integer;
begin
  S := P.TreeRoot;
  for K := 2 to Path.Depth do S := Join(S, Path.Text[K]);
  TreeDirOf := S;
end;

{ Alt+F10: the side shows its drive's folders as a tree, and back. }
procedure ToggleTree(var P: TPanel);
var
  Path: TTreePath;
  Dir: string;
begin
  if P.Tree = 0 then
  begin
    P.TreeRoot := Copy(P.Dir, 1, 3);
    OwlClose(P.Files);
    P.Files := 0;
    SubFolders(P.TreeRoot);
    OwlTree(P.Win, 1);
    OwlNode(NodeOpen, Copy(P.TreeRoot, 1, 2), NameCount);
    SendNames;
    P.Tree := OwlEnd;
    P.TreeDir := '';
    OwlSetText(P.Win, 'Tree of ' + P.TreeRoot);
  end
  else
  begin
    OwlTreePath(P.Tree, Path);
    Dir := TreeDirOf(P, Path);
    OwlClose(P.Tree);
    P.Tree := 0;
    P.Files := OwlFilesEx(P.Win, 0, PanelFlags, P.Dir);
    Go(P, Dir);
  end;
end;

{ After every key: a node opened is filled, and the other side is sent to
  the folder under the tree's cursor. }
procedure PollTree(var P, Other: TPanel);
var
  Path: TTreePath;
  Dir: string;
begin
  if OwlTreeExpand(P.Tree, Path) then
  begin
    SubFolders(TreeDirOf(P, Path));
    OwlTreeChildren(P.Tree, Path, NameCount);
    SendNames;
    OwlEnd;
  end;
  OwlTreePath(P.Tree, Path);
  Dir := TreeDirOf(P, Path);
  if Dir <> P.TreeDir then
  begin
    P.TreeDir := Dir;
    if (Other.Tree = 0) and IsFolder(Dir) then Go(Other, Dir);
  end;
end;

{ ---- drives --------------------------------------------------------------- }

function VolumeLabel(Drive: Char): string;
var
  SR: SearchRec;
  S: string;
  I: Integer;
begin
  FindFirst(Drive + ':\*.*', VolumeID, SR);
  S := '';
  if DosError = 0 then
    for I := 1 to Length(SR.Name) do
      if SR.Name[I] <> '.' then S := S + SR.Name[I];
  VolumeLabel := S;
end;

{ Alt+F1, Alt+F2: every drive DOS answers for, in a list. }
procedure ShowDrives(Which: Integer);
var
  C: Char;
  I, Rows: Integer;
begin
  CloseBox;
  DriveFor := Which;
  Drives := '';
  for C := 'A' to 'Z' do
    if DiskSize(Ord(C) - 64) >= 0 then Drives := Drives + C;
  Rows := Length(Drives);
  if Rows > 10 then Rows := 10;
  if Rows < 1 then Rows := 1;
  if Which = 1 then Box := OwlWindow(0, -1, -1, 40, Rows + 6, OwlDialog or OwlModal, 'Left side: drive', CmNo)
  else Box := OwlWindow(0, -1, -1, 40, Rows + 6, OwlDialog or OwlModal, 'Right side: drive', CmNo);
  OwlList(Box, 1, 1, 34, Rows, Length(Drives));
  for I := 1 to Length(Drives) do OwlListItem(Drives[I] + ':   ' + VolumeLabel(Drives[I]));
  DriveList := OwlEnd;
  OwlButtons(Box, 2);
  OwlButton(CmDriveOk, OwlDefault, '~O~K');
  OwlButton(CmNo, OwlCancel, '~C~ancel');
  OwlEnd;
end;

procedure DriveChosen;
var
  Ix: Word;
  C: Char;
  Dir: string;
begin
  Ix := OwlCurrent(DriveList);
  CloseBox;
  if Ix >= Length(Drives) then Exit;
  C := Drives[Ix + 1];
  {$I-} GetDir(Ord(C) - 64, Dir); {$I+}
  if IOResult <> 0 then Dir := C + ':\';
  if DriveFor = 1 then
  begin
    if Left.Tree <> 0 then ToggleTree(Left);
    Go(Left, Dir);
  end
  else
  begin
    if Right.Tree <> 0 then ToggleTree(Right);
    Go(Right, Dir);
  end;
end;

{ ---- properties ----------------------------------------------------------- }

{ Enter on a file: what DOS knows about it. DOS keeps one date. }
procedure Properties(const Dir, Name: string);
var
  SR: SearchRec;
  DT: DateTime;
  Attrs: string;
  I: Integer;
  Lab: array[1..5] of string[12];
  Value: array[1..5] of string;
begin
  FindFirst(Join(Dir, Name), Anything, SR);
  if DosError <> 0 then Exit;
  UnpackTime(SR.Time, DT);
  Attrs := '';
  if SR.Attr and ReadOnly <> 0 then Attrs := Attrs + ', read-only';
  if SR.Attr and Hidden <> 0 then Attrs := Attrs + ', hidden';
  if SR.Attr and SysFile <> 0 then Attrs := Attrs + ', system';
  if SR.Attr and Archive <> 0 then Attrs := Attrs + ', archive';
  if Attrs = '' then Attrs := 'none' else Delete(Attrs, 1, 2);
  Lab[1] := 'Name';       Value[1] := SR.Name;
  Lab[2] := 'Folder';     Value[2] := Dir;
  Lab[3] := 'Size';       Value[3] := Grouped(SR.Size) + ' bytes';
  Lab[4] := 'Modified';   Value[4] := IntStr(DT.Year) + '-' + Two(DT.Month) + '-' + Two(DT.Day) +
                                      ' ' + Two(DT.Hour) + ':' + Two(DT.Min);
  Lab[5] := 'Attributes'; Value[5] := Attrs;
  CloseBox;
  Box := OwlWindow(0, -1, -1, 60, 11, OwlDialog or OwlModal, 'Properties', CmNo);
  for I := 1 to 5 do
  begin
    OwlStatic(Box, 2, I, 11, 1, Lab[I] + ':');
    OwlStatic(Box, 14, I, 42, 1, Value[I]);
  end;
  OwlButtons(Box, 1);
  OwlButton(CmNo, OwlDefault, '~O~K');
  OwlEnd;
end;

{ ---- copying, moving, deleting -------------------------------------------- }

procedure Fail(const What, Name: string; Code: Integer);
begin
  if Failure = '' then Failure := 'Cannot ' + What + ' ' + Name + ': ' + DosText(Code) + '.';
end;

procedure CopyFile(const Src, Dst: string);
var
  F, G: file;
  Got, Put: Word;
  E: Integer;
  T: LongInt;
begin
  {$I-}
  Assign(F, Src);
  FileMode := 0;                        { read-only files can be copied too }
  Reset(F, 1);
  FileMode := 2;
  E := IOResult;
  if E <> 0 then
  begin
    Fail('read', Src, E);
    Exit;
  end;
  Assign(G, Dst);
  if Exists(Dst) then SetFAttr(G, 0);   { a read-only copy there is replaced as well }
  E := IOResult;
  Rewrite(G, 1);
  E := IOResult;
  if E <> 0 then
  begin
    Fail('write', Dst, E);
    Close(F);
    E := IOResult;
    Exit;
  end;
  repeat
    BlockRead(F, Buf^, BufSize, Got);
    E := IOResult;
    Put := Got;
    if (E = 0) and (Got > 0) then
    begin
      BlockWrite(G, Buf^, Got, Put);
      E := IOResult;
      if (E = 0) and (Put < Got) then E := 101;
    end;
  until (Got = 0) or (E <> 0);
  GetFTime(F, T);                       { the copy keeps the original's date }
  SetFTime(G, T);
  Close(G);
  Close(F);
  if E = 0 then E := IOResult;
  if E <> 0 then Fail('copy', Src, E);
  {$I+}
end;

procedure CopyTree(const Src, Dst: string);
var
  SR: SearchRec;
  E: Integer;
begin
  {$I-} MkDir(Dst); {$I+}
  E := IOResult;
  if (E <> 0) and not IsFolder(Dst) then
  begin
    Fail('make', Dst, E);
    Exit;
  end;
  FindFirst(Join(Src, '*.*'), Anything, SR);
  while (DosError = 0) and (Failure = '') do
  begin
    if (SR.Name <> '.') and (SR.Name <> '..') then
      if SR.Attr and Directory <> 0 then CopyTree(Join(Src, SR.Name), Join(Dst, SR.Name))
      else CopyFile(Join(Src, SR.Name), Join(Dst, SR.Name));
    FindNext(SR);
  end;
end;

procedure DeletePath(const Path: string);
var
  SR: SearchRec;
  F: file;
  E: Integer;
begin
  if IsFolder(Path) then
  begin
    FindFirst(Join(Path, '*.*'), Anything, SR);
    while (DosError = 0) and (Failure = '') do
    begin
      if (SR.Name <> '.') and (SR.Name <> '..') then DeletePath(Join(Path, SR.Name));
      FindNext(SR);
    end;
    if Failure <> '' then Exit;
    {$I-} RmDir(Path); {$I+}
    E := IOResult;
    if E <> 0 then Fail('delete', Path, E);
  end
  else
  begin
    Assign(F, Path);
    {$I-}
    SetFAttr(F, 0);                     { read-only is not a reason to keep it }
    E := IOResult;
    Erase(F);
    E := IOResult;
    {$I+}
    if E <> 0 then Fail('delete', Path, E);
  end;
end;

{ A file on the same drive moves by renaming: nothing is copied. A folder,
  or a file to another drive, is copied and the original deleted. }
procedure MovePath(const Src, Dst: string);
var
  F: file;
  E: Integer;
begin
  if not IsFolder(Src) and (UpCase(Src[1]) = UpCase(Dst[1])) then
  begin
    if Exists(Dst) then DeletePath(Dst);
    if Failure <> '' then Exit;
    Assign(F, Src);
    {$I-} Rename(F, Dst); {$I+}
    E := IOResult;
    if E <> 0 then Fail('move', Src, E);
    Exit;
  end;
  if IsFolder(Src) then CopyTree(Src, Dst) else CopyFile(Src, Dst);
  if Failure = '' then DeletePath(Src);
end;

{ Copy or move what was collected, a bar showing how far it has got. }
procedure Transfer(Move: Boolean);
var
  W, Bar: Word;
  I: Integer;
  Src, Dst: string;
begin
  Failure := '';
  if Move then W := OwlWindow(0, -1, -1, 50, 5, OwlDialog or OwlModal or OwlNoClose, 'Move', 0)
  else W := OwlWindow(0, -1, -1, 50, 5, OwlDialog or OwlModal or OwlNoClose, 'Copy', 0);
  Bar := OwlProgress(W, 2, 1, 44, ItemCount);
  OwlDraw;
  for I := 1 to ItemCount do
  begin
    Src := Join(ItemsFrom, Items[I]);
    Dst := Join(PendingTo, Items[I]);
    if Upper(Src) = Upper(Dst) then Continue;   { already where it is going }
    if IsFolder(Src) and Inside(PendingTo, Src) then
      Failure := 'Cannot put ' + Items[I] + ' inside itself.'
    else if Move then MovePath(Src, Dst)
    else if IsFolder(Src) then CopyTree(Src, Dst)
    else CopyFile(Src, Dst);
    if Failure <> '' then Break;
    OwlSetProgress(Bar, I);
    OwlDraw;
  end;
  OwlClose(W);
end;

procedure DeleteItems;
var
  I: Integer;
begin
  Failure := '';
  for I := 1 to ItemCount do
  begin
    DeletePath(Join(ItemsFrom, Items[I]));
    if Failure <> '' then Break;
  end;
end;

{ OK in the Make-directory dialog: the name, looked at, made on the side in front. }
procedure MakeDir;
var
  Name: string;
  P: ^TPanel;
  E: Integer;
begin
  Name := OwlGetText(AskInput);
  CloseBox;
  while (Length(Name) > 0) and (Name[1] = ' ') do Delete(Name, 1, 1);
  while (Length(Name) > 0) and (Name[Length(Name)] = ' ') do Dec(Name[0]);
  if (Name = '') or (Name = '.') or (Name = '..') or (Pos('\', Name) > 0) or (Pos('/', Name) > 0) then
  begin
    Tell('A folder needs a name: up to eight letters, and a dot and three more if you like.');
    Exit;
  end;
  if Side = 2 then P := @Right else P := @Left;
  {$I-} MkDir(Join(P^.Dir, Name)); {$I+}
  E := IOResult;
  if E <> 0 then Tell('Cannot make ' + Name + ': ' + DosText(E) + '.');
  Refresh;
end;

{ ---- viewer and editor ---------------------------------------------------- }

{ Up to BufSize bytes of a file into Buf; its whole size in Size. }
function ReadFile(const Path: string; var N: Word; var Size: LongInt): Integer;
var
  F: file;
  E: Integer;
begin
  {$I-}
  Assign(F, Path);
  FileMode := 0;
  Reset(F, 1);
  FileMode := 2;
  E := IOResult;
  if E = 0 then
  begin
    Size := FileSize(F);
    BlockRead(F, Buf^, BufSize, N);
    E := IOResult;
    Close(F);
  end;
  {$I+}
  ReadFile := E;
end;

{ A zero byte early on: not a text, whatever its name says. }
function Binary(N: Word): Boolean;
var
  I: Word;
begin
  Binary := False;
  if N > 4096 then N := 4096;
  for I := 0 to N - 1 do
    if Buf^[I] = 0 then
    begin
      Binary := True;
      Exit;
    end;
end;

procedure CloseViewer;
begin
  if Viewer <> 0 then OwlClose(Viewer);
  Viewer := 0;
end;

procedure CloseEditor;
begin
  if Editor <> 0 then OwlClose(Editor);
  Editor := 0;
  EditorText := 0;
end;

{ F3. A viewer is an editor that takes no typing; its Edit menu has Find,
  Word wrap, the bytes in hex, and the language it is coloured as. }
procedure ViewFile(const Dir, Name: string);
var
  N, Fits, T: Word;
  Size: LongInt;
  E: Integer;
  Title: string;
begin
  E := ReadFile(Join(Dir, Name), N, Size);
  if E <> 0 then
  begin
    Tell('Cannot read ' + Name + ': ' + DosText(E) + '.');
    Exit;
  end;
  if (N > 0) and Binary(N) then
  begin
    Tell(Name + ' is not a text file.');
    Exit;
  end;
  Fits := OwlDosFits(Buf^, N);
  if Size > Fits then Title := Name + ' - the first ' + IntStr(Fits) + ' bytes'
  else Title := Name;
  CloseViewer;
  Viewer := OwlWindow(0, 2, 1, 76, 22, OwlBlue, Title, CmCloseView);
  T := OwlTextDos(Viewer, Buf^, Fits, 1);
  { The caret's line:column on the bottom edge; code gets its line
    numbers as well, the way an assembler counts them in its errors. }
  OwlEditor(T, OfferFind or OfferWrap or OfferHex or OfferSyntax, EditReadOnly or EditPosition);
  if OwlSyntax(T, Name) then
    OwlEditor(T, OfferFind or OfferWrap or OfferHex or OfferSyntax, EditReadOnly or EditPosition or EditNumbers);
  OwlWindowStatus(Viewer, 1);           { Escape closes it; F3 and F10 do too }
  OwlKey('', CmCloseView, KeyNamed, 1, 0);
  OwlEnd;
end;

{ F4. The whole file or nothing: an editor holding part of a file would
  save the rest of it away. }
procedure EditFile(const Dir, Name: string);
var
  N: Word;
  Size: LongInt;
  E: Integer;
begin
  E := ReadFile(Join(Dir, Name), N, Size);
  if E <> 0 then
  begin
    Tell('Cannot read ' + Name + ': ' + DosText(E) + '.');
    Exit;
  end;
  if (N > 0) and Binary(N) then
  begin
    Tell(Name + ' is not a text file.');
    Exit;
  end;
  if (Size > N) or (OwlDosFits(Buf^, N) < N) then
  begin
    Tell(Name + ' is too big to edit here. F3 shows its beginning.');
    Exit;
  end;
  CloseEditor;
  EditorPath := Join(Dir, Name);
  Editor := OwlWindow(0, 2, 1, 76, 22, OwlBlue, Name, CmCloseEdit);
  EditorText := OwlTextDos(Editor, Buf^, N, 0);
  { Everything the editor has, on an Edit menu of its own, in the colours
    of the language its name says. }
  OwlEditor(EditorText, OfferAll, EditPosition);
  if OwlSyntax(EditorText, Name) then
    OwlEditor(EditorText, OfferAll, EditPosition or EditNumbers);
  OwlWindowStatus(Editor, 1);           { F2 saves, as it did in the classic editors }
  OwlKey('', CmSave, KeyF, 2, 0);
  OwlEnd;
  OwlButtons(Editor, 2);
  OwlButton(CmSave, 0, '~S~ave F2');
  OwlButton(CmCloseEdit, OwlCancel, '~C~lose Esc');
  OwlEnd;
end;

procedure SaveEditor;
var
  N: Word;
  F: file;
  E: Integer;
  Put: Word;
begin
  N := OwlGetTextDos(EditorText, Buf^, BufSize);
  if N = $FFFF then
  begin
    Tell('The text has grown too big to save here.');
    Exit;
  end;
  {$I-}
  Assign(F, EditorPath);
  Rewrite(F, 1);
  E := IOResult;
  if E = 0 then
  begin
    BlockWrite(F, Buf^, N, Put);
    E := IOResult;
    if (E = 0) and (Put < N) then E := 101;
    Close(F);
  end;
  {$I+}
  if E <> 0 then
  begin
    Tell('Cannot save: ' + DosText(E) + '.');
    Exit;
  end;
  CloseEditor;
  Refresh;
end;

{ ---- the commands ---------------------------------------------------------- }

procedure BuildStatus;
begin
  OwlStatus(13);
  OwlKey('~F1~ Help', CmHelp, KeyF, 1, 0);
  OwlKey('~F3~ View', CmView, KeyF, 3, 0);
  OwlKey('~F4~ Edit', CmEdit, KeyF, 4, 0);
  OwlKey('~F5~ Copy', CmCopy, KeyF, 5, 0);
  OwlKey('~F6~ Move', CmMove, KeyF, 6, 0);
  OwlKey('~F7~ MkDir', CmMkdir, KeyF, 7, 0);
  OwlKey('~F8~ Del', CmDelete, KeyF, 8, 0);
  OwlKey('~F10~ Quit', CmQuit, KeyF, 10, 0);
  { Bound and not shown, as the commanders had them: the row is full. }
  OwlKey('', CmSwitch, KeyNamed, 2, 0);
  OwlKey('', CmDriveLeft, KeyF, 1, ModAlt);
  OwlKey('', CmDriveRight, KeyF, 2, ModAlt);
  OwlKey('', CmTree, KeyF, 10, ModAlt);
  OwlKey('', CmReread, KeyChar, Ord('r'), ModCtrl);
  OwlEnd;
end;

{ A command about files, on the side in front. }
procedure FileCommand(Cmd: Word; var P, Other: TPanel);
var
  Name, Shown: string;
  I: Integer;
begin
  case Cmd of
    CmView: if CursorFile(P, Name) then ViewFile(P.Dir, Name);
    CmEdit: if CursorFile(P, Name) then EditFile(P.Dir, Name);
    CmTree: ToggleTree(P);
    CmCopy, CmMove:
      begin
        if P.Tree <> 0 then Exit;
        Collect(P);
        if ItemCount = 0 then
        begin
          Tell('Nothing to copy: mark some files with Insert, or stand on one.');
          Exit;
        end;
        PendingTo := Other.Dir;
        if Cmd = CmCopy then Ask('Copy ' + IntStr(ItemCount) + ' file(s) to ' + PendingTo + '?', CmCopy)
        else Ask('Move ' + IntStr(ItemCount) + ' file(s) to ' + PendingTo + '?', CmMove);
      end;
    CmDelete:
      begin
        if P.Tree <> 0 then Exit;
        Collect(P);
        if ItemCount = 0 then
        begin
          Tell('Nothing to delete.');
          Exit;
        end;
        Shown := '';
        for I := 1 to ItemCount do
          if I <= 3 then
          begin
            if Shown <> '' then Shown := Shown + ', ';
            Shown := Shown + Items[I];
          end;
        if ItemCount > 3 then Shown := Shown + ', +' + IntStr(ItemCount - 3);
        Ask('Delete ' + IntStr(ItemCount) + ' file(s): ' + Shown + '?', CmDelete);
      end;
    CmMkdir:
      begin
        CloseBox;
        Box := OwlWindow(0, -1, -1, 46, 8, OwlDialog or OwlModal, 'Make directory', CmNo);
        AskInput := OwlInput(Box, 2, 2, 40, 12, 'Name:', '');
        OwlButtons(Box, 2);
        OwlButton(CmMkdirOk, OwlDefault, '~O~K');
        OwlButton(CmNo, OwlCancel, '~C~ancel');
        OwlEnd;
      end;
    CmSwitch: OwlActivate(Other.Win);
  end;
end;

{ One command. False means leave. }
function Command(Cmd: Word): Boolean;
var
  A: Word;
  What: Word;
begin
  Command := True;
  { The Help box's buttons: the box goes first, so "in front" is a side. }
  if (Cmd = CmTree) or (Cmd = CmDriveLeft) or (Cmd = CmDriveRight) then CloseBox;
  A := OwlActive;
  { In the viewer, F3, F10 and Escape close it; in the editor, F10 and
    Escape do. Neither lets F5 copy files behind its back. }
  if (Viewer <> 0) and (A = Viewer) then
  begin
    if (Cmd = CmView) or (Cmd = CmQuit) or (Cmd = CmCloseView) then CloseViewer;
    Exit;
  end;
  if (Editor <> 0) and (A = Editor) then
  begin
    if (Cmd = CmQuit) or (Cmd = CmCloseEdit) then CloseEditor
    else if Cmd = CmSave then SaveEditor;
    Exit;
  end;
  case Cmd of
    CmQuit: Command := False;
    CmHelp: Help;
    CmNo:
      begin
        CloseBox;
        Pending := 0;
      end;
    CmYes:
      begin
        What := Pending;
        CloseBox;
        Pending := 0;
        Failure := '';
        case What of
          CmCopy: Transfer(False);
          CmMove: Transfer(True);
          CmDelete: DeleteItems;
        end;
        { The marks are used up once their files are dealt with, as
          in the classic file managers; a failure leaves them, to try again. }
        if Failure = '' then
          case Side of
            1: if Left.Files <> 0 then OwlUnmark(Left.Files);
            2: if Right.Files <> 0 then OwlUnmark(Right.Files);
          end;
        Refresh;
        if Failure <> '' then Tell(Failure);
      end;
    CmMkdirOk: MakeDir;
    CmDriveLeft: ShowDrives(1);
    CmDriveRight: ShowDrives(2);
    CmDriveOk: DriveChosen;
    CmCloseView: CloseViewer;
    CmCloseEdit: CloseEditor;
    { Ctrl+R, Volkov's re-read: both folders read again, for files that
      came from somewhere other than this program - another program, or
      the web page a browser's DOSBox is in. }
    CmReread: Refresh;
  else
    case Side of
      1: FileCommand(Cmd, Left, Right);
      2: FileCommand(Cmd, Right, Left);
    end;
  end;
end;

{ A name DOS can run: a program, or a batch file. }
function Runnable(const Name: string): Boolean;
var
  E: string[4];
begin
  E := Upper(Copy(Name, Length(Name) - 3, 4));
  Runnable := (E = '.COM') or (E = '.EXE') or (E = '.BAT');
end;

{ Whether a program draws with this toolkit: each one says, in its own
  bytes, that it wants OWLOSRES - the message it gives when started
  without it. }
function UsesToolkit(const Path: string): Boolean;
const
  Sig: array[0..7] of Char = 'OWLOSRES';
var
  F: file;
  At, Size: LongInt;
  N, I, J: Word;
  Hit: Boolean;
begin
  UsesToolkit := False;
  Assign(F, Path);
  FileMode := 0;
  {$I-} Reset(F, 1); {$I+}
  FileMode := 2;
  if IOResult <> 0 then Exit;
  Size := FileSize(F);
  At := 0;
  while (At < Size) and (At < 262144) do
  begin
    Seek(F, At);
    BlockRead(F, Buf^, BufSize, N);
    if N < 8 then Break;
    for I := 0 to N - 8 do
      if Buf^[I] = Ord('O') then
      begin
        Hit := True;
        for J := 1 to 7 do
          if Buf^[I + J] <> Ord(Sig[J]) then Hit := False;
        if Hit then
        begin
          UsesToolkit := True;
          Close(F);
          Exit;
        end;
      end;
    Inc(At, N - 7);                     { a name across two reads is still found }
  end;
  Close(F);
end;

{ Step out: what the batch file that started this one runs next - the
  program, in its own folder, and then back to the folder it started in -
  and where both sides were, for the commander it starts again. }
procedure StepOut(var P: TPanel; const Name: string);
var
  T: Text;
  E: string[4];
begin
  E := Upper(Copy(Name, Length(Name) - 3, 4));
  Assign(T, Home + 'RUNPROG.BAT');
  Rewrite(T);
  WriteLn(T, '@echo off');
  WriteLn(T, Copy(P.Dir, 1, 2));
  if IsRoot(P.Dir) then WriteLn(T, 'cd \') else WriteLn(T, 'cd ', Copy(P.Dir, 3, 255));
  if E = '.BAT' then WriteLn(T, 'call ', Name) else WriteLn(T, Name);
  WriteLn(T, 'pause');
  WriteLn(T, Copy(StartedIn, 1, 2));
  if IsRoot(StartedIn) then WriteLn(T, 'cd \') else WriteLn(T, 'cd ', Copy(StartedIn, 3, 255));
  Close(T);
  Assign(T, Home + 'COMMANDR.SAV');
  Rewrite(T);
  WriteLn(T, Left.Dir);
  WriteLn(T, Right.Dir);
  WriteLn(T, Side);
  Close(T);
  Stepped := True;
end;

{ Enter on a program: it runs, in its own folder - a game finds its data
  beside itself.

  A toolkit program runs from in here, the panels put aside meanwhile: it
  needs the toolkit, which is here, and it is small. Any other program gets
  the whole of DOS's memory, as it would from the prompt - when the batch
  file that started this one said it can (/STEP), the commander steps out
  of memory altogether and is started again afterwards in the same
  folders. A program that takes for granted it was loaded low - OWL FLY III
  lays its buffers out at fixed distances above itself and never asks DOS
  - would otherwise write past the end of memory, into the video card.

  Then the panels again, read afresh: it may have made or deleted files. }
procedure RunProgram(var P: TPanel; const Name: string);
var
  Was: string;
  Code: Integer;
begin
  if CanStep and not UsesToolkit(Join(P.Dir, Name)) then
  begin
    StepOut(P, Name);
    Exit;
  end;
  GetDir(0, Was);
  {$I-} ChDir(P.Dir); {$I+}
  if IOResult <> 0 then ;
  Code := OwlRun(Join(P.Dir, Name), '', True);
  {$I-} ChDir(Was); {$I+}
  if IOResult <> 0 then ;
  Refresh;
  if Code = 8 then Tell('There is not enough memory to run ' + Name + '.')
  else if Code <> 0 then Tell('DOS would not run ' + Name + ': ' + DosText(Code) + '.');
end;

{ What a panel says that is not a command: a name Enter was pressed on. }
procedure PollPanel(var P, Other: TPanel);
var
  Text: string;
begin
  if P.Tree <> 0 then
  begin
    PollTree(P, Other);
    Exit;
  end;
  if OwlTakeFiles(P.Files, Text) <> 1 then Exit;
  if Text = '..' then Go(P, ParentOf(P.Dir))
  else if IsFolder(Join(P.Dir, Text)) then Go(P, Join(P.Dir, Text))
  else if Exists(Join(P.Dir, Text)) and Runnable(Text) then RunProgram(P, Text)
  else if Exists(Join(P.Dir, Text)) then Properties(P.Dir, Text);
end;

{ A folder named on the command line, or the one DOS is in. }
function StartDir(const Arg: string): string;
var
  S: string;
begin
  S := '';
  if Arg <> '' then S := Normal(Arg);
  if (S = '') or not IsFolder(S) then
  begin
    GetDir(0, S);
    S := Normal(S);
  end;
  StartDir := S;
end;

{ Where the two sides were when the commander stepped out for a program:
  COMMANDR.SAV, read once and gone. }
function Resumed(var L, R: string; var Front: Integer): Boolean;
var
  T: Text;
begin
  Resumed := False;
  Assign(T, Home + 'COMMANDR.SAV');
  {$I-} Reset(T); {$I+}
  if IOResult <> 0 then Exit;
  ReadLn(T, L);
  ReadLn(T, R);
  ReadLn(T, Front);
  Close(T);
  Erase(T);
  if not IsFolder(L) then L := StartDir('');
  if not IsFolder(R) then R := L;
  Resumed := True;
end;

var
  Pressed, Chosen: Word;
  Running: Boolean;
  L, R: string;
  Args: array[1..2] of string;
  NArgs, I, Front: Integer;

begin
  if not OwlCheck then Halt(1);
  New(Buf);
  { The folders for the two sides, and /STEP anywhere among them. }
  NArgs := 0;
  Args[1] := '';
  Args[2] := '';
  for I := 1 to ParamCount do
    if Upper(ParamStr(I)) = '/STEP' then CanStep := True
    else if NArgs < 2 then
    begin
      Inc(NArgs);
      Args[NArgs] := ParamStr(I);
    end;
  GetDir(0, StartedIn);
  Home := StartedIn;
  if Home[Length(Home)] <> '\' then Home := Home + '\';
  Front := 1;
  if not (CanStep and Resumed(L, R, Front)) then
  begin
    L := StartDir(Args[1]);
    if NArgs >= 2 then R := StartDir(Args[2]) else R := L;
  end;
  OwlInit;
  BuildStatus;
  OpenPanel(Left, 0, 40, L);
  OpenPanel(Right, 40, 40, R);
  if Front = 2 then OwlActivate(Right.Win) else OwlActivate(Left.Win);
  Running := True;
  while Running do
  begin
    OwlWait(Pressed, Chosen);           { a button pressed, a command chosen }
    if Pressed <> 0 then Running := Command(Pressed);
    if Running and (Chosen <> 0) then Running := Command(Chosen);
    if Running then
    begin
      PollPanel(Left, Right);           { and a name entered in a panel }
      PollPanel(Right, Left);
    end;
    if Stepped then Running := False;  { out of memory, for RUNPROG.BAT }
  end;
  OwlQuit;
end.
