unit tp_diff;

{$MODE FPC}
{$MODESWITCH DEFAULTPARAMETERS}
{$MODESWITCH OUT}
{$MODESWITCH RESULT}

interface

uses
  testprograms_printer;

type
TLines = record
  A: array of AnsiString;
  L: SizeUInt; // <- actual length; Length(A) is capacity
end;

function TestProgramReadLines(const FileName: AnsiString; out Lines: TLines): Boolean;
      //
      //  Reads the text file FileName and splits it into the Lines.
      //  Returns True if succeded. Returns False otherwise.
      //

function TestProgramDiffLines(const L, R: TLines;
                              out Diff: TLines;
                              out DiffDetected: Boolean): Boolean;

function TestProgramsDiff(const Left, Right, Res: AnsiString;
                          out DiffDetected: Boolean): Boolean;

implementation

function TestProgramReadLines(const FileName: AnsiString; out Lines: TLines): Boolean;
const
  MAX_LINES = 10000;
var
  T: TextFile;
begin
{$PUSH}
{$I-}
  Assign(T, FileName);
  Reset(T);
  if IOResult <> 0 then
    Exit(False);
  SetLength(Lines.A, 10000);
  Lines.L := 0;
  while not Eof(T) do begin
    if Lines.L >= MAX_LINES then begin
      Close(T);
      Exit(False);
    end;
    ReadLn(T, Lines.A[Lines.L]);
    if IOResult <> 0 then begin
      Close(T);
      Exit(False);
    end;
    Inc(Lines.L);
  end;
  Close(T);
{$POP}
  Exit(True);
end;

function TestProgramsSaveDiff(const Diff: TLines; const FileName: AnsiString): Boolean;
var
  T: TextFile;
  I: LongInt;
begin
{$PUSH}
  Assign(T, FileName);
  ReWrite(T);
  if IOResult <> 0 then
    Exit(False);
  for I := 0 to Diff.L - 1 do begin
    Writeln(T, Diff.A[I]);
    if IOResult <> 0 then begin
      Close(T);
      Exit(False);
    end;
  end;
  Close(T);
{$POP}
  Exit(True);
end;

function TestProgramDiffLines(const L, R: TLines;
                              out Diff: TLines;
                              out DiffDetected: Boolean): Boolean;
type
  PCell = ^TCell;
  TCell = record
    M: LongInt;
    L, R: AnsiString;
    Ref: PCell;
    ForwardRef: PCell;
  end;
var
  DynamicTable: array of TCell;
  I, J, N, W: LongInt;
  Current, Prev1, Prev2: PCell;
begin
  W := (L.L + 1);
  SetLength(DynamicTable, (L.L + 1) * (R.L + 1));
  // if L.L > R.L then begin
  //   MaxLength := L.L;
  // end else
  //   MaxLength := R.L;
  for I := 0 to L.L do begin
    DynamicTable[I + 0 * W].M := 0;
    DynamicTable[I + 0 * W].Ref := nil;
    if I > 0 then begin
      DynamicTable[I + 0 * W].L := '< ' + L.A[I - 1];
      DynamicTable[I + 0 * W].R := '';
      DynamicTable[I + 0 * W].Ref := @DynamicTable[I - 1 + 0 * W];
    end else begin
      DynamicTable[I + 0 * W].L := '';
      DynamicTable[I + 0 * W].R := '';
    end;
  end;
  for I := 0 to R.L do begin
    DynamicTable[0 + I * W].M := 0;
    DynamicTable[0 + I * W].Ref := nil;
    if I > 0 then begin
      DynamicTable[0 + I * W].L := '';
      DynamicTable[0 + I * W].R := '> ' + R.A[I - 1];
      DynamicTable[0 + I * W].Ref := @DynamicTable[0 + (I - 1) * W];
    end else begin
      DynamicTable[0 + I * W].L := '';
      DynamicTable[0 + I * W].R := '';
    end;
  end;
  for N := 2 to L.L + R.L do begin
    for I := 1 to L.L do begin
      J := N - I;
      if (I <= 0) or (J <= 0) or (I > L.L) or (J > R.L) then
        continue;
      Current := @DynamicTable[I + J * W];
      if L.A[I - 1] = R.A[J - 1] then begin
        Current^.Ref := @DynamicTable[(I - 1) + (J - 1) * W];
        Current^.M := Current^.Ref^.M + 1;
        Current^.L := '  ' + L.A[I - 1];
        Current^.R := '  ' + R.A[J - 1];
        // Writeln(I, ' ', J, ' -> ', I - 1, ' ', J - 1);
      end else begin
        Prev1 := @DynamicTable[(I - 1) +       J * W];
        Prev2 := @DynamicTable[      I + (J - 1) * W];
        if Prev1^.M > Prev2^.M then begin
          Current^.Ref := Prev1;
          Current^.M   := Prev1^.M;
          Current^.L   := '< ' + L.A[I - 1];
          Current^.R   := '';
          // Writeln(I, ' ', J, ' -> ', I - 1, ' ', J);
        end else begin
          Current^.Ref := Prev2;
          Current^.M   := Prev2^.M;
          Current^.L   := '';
          Current^.R   := '> ' + R.A[J - 1];
          // Writeln(I, ' ', J, ' -> ', I, ' ', J - 1);
        end;
      end;
    end;
  end;
  // Now reverse the Ref chain from the end
  I := 1;
  Current := @DynamicTable[L.L + R.L * W];
  Current^.ForwardRef := nil;
  while Current^.Ref <> nil do begin
    //Writeln('REVERSING');
    Prev1 := Current;
    Current := Current^.Ref;
    Current^.ForwardRef := Prev1;
    Inc(I);
  end;
  // Now we have the Current and forward links, we can build actual diff
  SetLength(Diff.A, I);
  Diff.L := 0;
  DiffDetected := False;
  while Current <> nil do begin
    if Current^.L = Current^.R then begin
      if Current^.L <> '' then begin
        Diff.A[Diff.L] := Current^.L;
        Inc(Diff.L);
      end;
    end else if Current^.L = '' then begin
      Diff.A[Diff.L] := Current^.R;
      DiffDetected := True;
      Inc(Diff.L);
    end else begin
      Diff.A[Diff.L] := Current^.L;
      DiffDetected := True;
      Inc(Diff.L);
    end;
    Current := Current^.ForwardRef;
  end;
  Exit(True);
end;

function TestProgramsDiff(const Left, Right, Res: AnsiString;
                          out DiffDetected: Boolean): Boolean;
var
  L, R, Diff: TLines;
begin
  if not TestProgramReadLines(Left, L) then begin
    PrintError(['could not read file for diff: ', Left]);
    Exit(False);
  end;
  if not TestProgramReadLines(Right, R) then begin
    PrintError(['could not read file for diff: ', Right]);
    Exit(False);
  end;
  if not TestProgramDiffLines(L, R, Diff, DiffDetected) then begin
    PrintError(['internal error while proccessing: diff ', Left, ' ', Right, ' ', Res]);
    Exit(False);
  end;
  if DiffDetected then begin
    if not TestProgramsSaveDiff(Diff, Res) then begin
      Exit(False);
    end;
  end;
  Exit(True);
end;

end.
