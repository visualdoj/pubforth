unit testprograms_list;

//
//  Parser of the list file
//

{$MODE FPC}
{$MODESWITCH DEFAULTPARAMETERS}
{$MODESWITCH OUT}
{$MODESWITCH RESULT}

interface

uses
  sysutils,
  testprograms_printer,
  testprograms_tasks;

type
TParsedChain = record
  Cmd: array of AnsiString;
end;

TParsedCommand = record
  Chains: array of TParsedChain;
end;

function SplitTestListLine(const Line: AnsiString;
                           out Cmd: TParsedCommand): Boolean;

function TestsListNext(var T: TextFile;
                       out Command: TParsedCommand): Boolean;

function GenerateTasks(S, SEnd: PAnsiChar): Boolean;

implementation

var
  Task: PTask;
  Cmd: array of AnsiString;
  Stdin: AnsiString;

function SplitTestListLine(const Line: AnsiString;
                           out Cmd: TParsedCommand): Boolean;
var
  I: LongInt;
  Arg: AnsiString;
  procedure AddArg;
  begin
    SetLength(Cmd.Chains[High(Cmd.Chains)].Cmd, Length(Cmd.Chains[High(Cmd.Chains)].Cmd) + 1);
    Cmd.Chains[High(Cmd.Chains)].Cmd[High(Cmd.Chains[High(Cmd.Chains)].Cmd)] := Arg;
    Arg := '';
  end;
begin
  I := 1;
  SetLength(Cmd.Chains, 1);
  Arg := '';
  while I <= Length(Line) do begin
    if Line[I] = '''' then begin // literal string
      Inc(I);
      while I <= Length(Line) do begin
        if Line[I] = '''' then
          break;
        Arg := Arg + Line[I];
        Inc(I);
      end;
      if I > Length(Line) then begin
        PrintError(['single quote not closed: ', Line]);
        Exit(False);
      end;
    end else if Line[I] = '"' then begin // with possible env values
      Inc(I);
      while I <= Length(Line) do begin
        if Line[I] = '"' then
          break;
        Arg := Arg + Line[I];
        Inc(I);
      end;
      if I > Length(Line) then begin
        PrintError(['double quote not closed: ', Line]);
        Exit(False);
      end;
    end else if Line[I] = '$' then begin // environmental variable
        PrintError(['environmental variable TODO: ', Line]);
        Exit(False);
    end else if Line[I] = '&' then begin // chaining?
        PrintError(['Chaining TODO: ', Line]);
        Exit(False);
    end else if Line[I] = ' ' then begin
      if Arg <> '' then
        AddArg;
    end else
      Arg := Arg + Line[I];
    Inc(I);
  end;
  if Arg <> '' then
    AddArg;
  Exit(True);
end;

function TestsListNext(var T: TextFile;
                       out Command: TParsedCommand): Boolean;
var
  S: AnsiString;
  Line: AnsiString;
begin
{$I-}
  Line := '';
  while not Eof(T) do begin
    Readln(T, S);
    S := Trim(S);
    if S = '' then
      continue;
    if S[1] = '#' then
      continue;
    if S[Length(S)] = '\' then begin
      S := Copy(S, 1, Length(S) - 1);
      if S = '' then
        continue;
      Line := Line + ' ' + S;
      if S[Length(S)] = '\' then
        break;
    end else begin
      Line := Line + ' ' + S;
      break;
    end;
  end;
{$I+}
  if Line = '' then
    Exit(False);
  Exit(SplitTestListLine(Line, Command));
end;

function FinishTask: Boolean;
begin
  Exit(True);
end;

function ResolveEnvVariable(const VarName: AnsiString): AnsiString;
begin
  Result := Task^.Env.Get(VarName);
end;

function ParseVarName(S, SEnd: PAnsiChar;
                     out VarName: AnsiString;
                     out SNext: PAnsiChar): Boolean;
      // [a-zA-Z_][a-zA-Z_0-9]*
      // ^                     ^
      // S                     SNext
begin
  VarName := '';
  while S < SEnd do begin
    if S^ in ['a'..'z', 'A'..'Z', '_', '0'..'9'] then begin
      VarName := VarName + S^;
      Inc(S);
    end else
      break;
  end;
  if VarName <> '' then
    SNext := S;
  Exit(VarName <> '');
end;

function ParseDQ(S, SEnd: PAnsiChar;
                 out Value: AnsiString;
                 out SNext: PAnsiChar): Boolean;
      //
      //  On success Result=True:
      //
      //        Value is the value of the parsed string.
      //        SNext points to a character right after closed "
      //
      //  On failed Result=False:
      //
      //        SEnd reached and closed " not found.
      //        Value is partially builded value.
      //        SNext is unchanged.
      //
var
  VarName, VarValue: AnsiString;
begin
  Value := '';
  while S < SEnd do begin
    if S^ = '"' then begin
      SNext := S + 1;
      Exit(True);
    end else if S^ = '$' then begin
      if ParseVarName(S + 1, SEnd, VarName, S) then begin
        VarValue := ResolveEnvVariable(VarName);
        Value := Value + VarValue;
      end else begin
        Value := Value + '$';
        Inc(S);
      end;
    end else if S^ = '\' then begin
      Inc(S);
      if S >= SEnd then
        Exit(False);
      case S^ of
        '$', '\', '"': begin
               Value := Value + S^;
               Inc(S);
               continue;
             end;
        #13: begin
               Inc(S);
             end;
        #10: begin
               Inc(S);
               if (S < SEnd) and (S^ = #13) then
                 Inc(S);
             end;
      else
        Value := Value + '\';
      end;
    end else begin
      Value := Value + S^;
      Inc(S);
    end;
  end;
  Exit(False);
end;

function ParseSQ(S, SEnd: PAnsiChar;
                 out Value: AnsiString;
                 out SNext: PAnsiChar): Boolean;
begin
  Value := '';
  while S < SEnd do begin
    if S^ = '''' then begin
      SNext := S + 1;
      Exit(True);
    end else begin
      Value := Value + S^;
      Inc(S);
    end;
  end;
  SNext := S;
  Exit(True);
end;

function IsAtomStart(C: AnsiChar): Boolean; inline;
begin
  Exit(C in ['a'..'z',
             'A'..'Z',
             '0'..'9',
             '+', '-', '_', '.', '/', '%', ':', '=', '@',
             '$',
             '\',
             '"',
             '''']);
end;

function ParseAtom(S, SEnd: PAnsiChar;
                   out Value: AnsiString;
                   out SNext: PAnsiChar): Boolean;
var
  SubValue, VarName: AnsiString;
begin
  Value := '';
  while S < SEnd do begin
    case S^ of
      ' ', #13, #10, '#': begin
        SNext := S;
        Exit(True);
      end;
      '"': begin
        if ParseDQ(S + 1, SEnd, SubValue, S) then begin
          Value := Value + SubValue;
        end else begin
          Exit(False);
        end;
      end;
      '''': begin
        if ParseSQ(S + 1, SEnd, SubValue, S) then begin
          Value := Value + SubValue;
        end else begin
          Exit(False);
        end;
      end;
      '$': begin
        if ParseVarName(S + 1, SEnd, VarName, S) then begin
          Value := Value + ResolveEnvVariable(VarName);
        end else begin
          Value := Value + '$';
          Inc(S);
        end;
      end;
      'a'..'z',
      'A'..'Z',
      '0'..'9',
      '+', '-',
      '_', '.',
      '/', '%',
      ':', '=',
      '@': begin // safe characters
        Value := Value + S^;
        Inc(S);
      end;
      '\': begin // escaped character or new line ignoring
        Inc(S);
        if S >= SEnd then begin
          // TODO do we?
          SNext := S;
          Exit(True);
        end;
        if S^ = #13 then begin
          Inc(S);
          if (S < SEnd) and (S^ = #10) then
            Inc(S);
        end else if S^ = #10 then begin
          Inc(S);
        end else begin
          Value := Value + S^;
          Inc(S);
        end;
      end;
    else // case -- assume other symbols to be stop-symbols
      SNext := S;
      Exit(True);
    end;
  end;
  SNext := S;
  Exit(True);
end;

function ParseVarAssignment(S, SEnd: PAnsiChar;
                            out VarName, VarExpr: AnsiString;
                            out SNext: PAnsiChar): Boolean;
            //
            //  varname=atom
            //
begin
  VarName := '';
  VarExpr := '';
  // Try to read first character
  if not ParseVarName(S, SEnd, VarName, S) then
    Exit(False);
  if (S >= SEnd) or (S^ <> '=') then
    Exit(False);
  Inc(S);
  if not ParseAtom(S, SEnd, VarExpr, S) then
    Exit(False);
  // Writeln(stderr, 'set ', VarName, '=', VarExpr);
  Task^.Env.Add(VarName, VarExpr);
  SNext := S;
  Exit(True);
end;

function SkipSpaces(S, SEnd: PAnsiChar): PAnsiChar;
begin
  while S < SEnd do begin
    if S^ <> ' ' then
      Exit(S);
    Inc(S);
  end;
  Exit(SEnd);
end;

function ParseVarList(S, SEnd: PAnsiChar;
                      out SNext: PAnsiChar): Boolean;
var
  VarName, VarExpr: AnsiString;
begin
  while S < SEnd do begin
    S := SkipSpaces(S, SEnd);
    if not ParseVarAssignment(S, SEnd, VarName, VarExpr, S) then begin
      SNext := S;
      Exit(True);
    end;
  end;
  SNext := SEnd;
  Exit(True);
end;

function SkipLine(S, SEnd: PAnsiChar; out SNext: PAnsiChar): Boolean;
begin
  while S < SEnd do begin
    case S^ of
    #13: begin
           SNext := S + 1;
           Exit(True);
         end;
    #10: begin
           if (S + 1 < SEnd) and ((S + 1)^ = #13) then begin
             SNext := S + 2;
           end else
             SNext := S + 1;
           Exit(True);
         end;
    end;
    Inc(S);
  end;
  SNext := S;
  Exit(True);
end;

function ParseTask(S, SEnd: PAnsiChar; out SNext: PAnsiChar): Boolean;
var
  Atom: AnsiString;
begin
  if not ParseVarList(S, SEnd, S) then
    Exit(False);
  while S < SEnd do begin
    S := SkipSpaces(S, SEnd);
    if S >= SEnd then begin
      Exit(True);
    end;
    case S^ of
    #10, #13, '#': Exit(SkipLine(S, SEnd, SNext));
    ' ': Inc(S);
    '&': begin
           Inc(S);
           if (S >= SEnd) or (S^ <> '&') then begin
             // TODO forking with & is not supported
             Exit(False);
           end;
           Inc(S);
           if Length(Cmd) <= 0 then begin
             // TODO command cannot be empty
             Exit(False);
           end;
           // Writeln('Started new command');
           if (Length(Task^.Cmds) = 0) and (Cmd[0] = 'cd') and (Length(Cmd) > 1) then begin
             Task^.Env.Add('TESTDIR', Cmd[1]);
             SetLength(Cmd, 0);
             Stdin := '';
           end else begin
             AddCommand(Task, NewCommand(Cmd, ''));
             SetLength(Cmd, 0);
             Stdin := '';
           end;
         end;
    '<': begin
           S := SkipSpaces(S + 1, SEnd);
           if not ParseAtom(S, SEnd, Atom, S) then begin
             PrintError(['stdin for "<" is not specified']);
             Exit(False);
           end;
           // Writeln('stdin: ', Atom);
           Stdin := Atom;
           S := SkipSpaces(S, SEnd);
           if S < SEnd then begin
             if (S^ <> '#') and (S^ <> #10) and (S^ <> #13) then begin
               PrintError(['<stdin must be last part of a task']);
               Exit(False);
             end;
           end;
         end;
    else
      if not IsAtomStart(S^) then begin
        PrintError(['character ', S^, ' is to be escaped']);
        Exit(False);
      end;
      if not ParseAtom(S, SEnd, Atom, S) then
        Exit(False);
      // Writeln('atom: ', Atom);
      SetLength(Cmd, Length(Cmd) + 1);
      Cmd[High(Cmd)] := Atom;
    end;
  end;
  SNext := SEnd;
  // TODO check non-empty
  Exit(True);
end;

function GenerateTasks(S, SEnd: PAnsiChar): Boolean;
begin
  while S < SEnd do begin
    // Writeln('New task:');
    Task := NewTask;
    SetLength(Cmd, 0);
    Stdin := '';
    if not ParseTask(S, SEnd, S) then
      Exit(False);
    if Length(Cmd) > 0 then begin
      AddCommand(Task, NewCommand(Cmd, Stdin));
      //PrintTask(Task);
      AddTask(Task);
    end else begin
      FreeTask(Task);
    end;
  end;
  Exit(True);
end;

end.
