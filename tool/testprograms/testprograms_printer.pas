unit testprograms_printer;

//
//  Abstraction for printing results. Trivial wrapper over Write/Writerln
//  for now.
//

{$MODE OBJFPC}
{$MODESWITCH DEFAULTPARAMETERS}
{$MODESWITCH OUT}
{$MODESWITCH RESULT}

interface

uses
{$IF Defined(UNIX)}
  termio,
{$ELSEIF Defined(WINDOWS)}
  windows,
{$ENDIF}
  sysutils;

// Stdout
procedure Print(const S: AnsiString); overload;
procedure Print(const A: array of Const); overload;
procedure PrintLn; overload;
procedure PrintLn(const S: AnsiString); overload;
procedure PrintLn(const A: array of Const); overload;

var
  EnabledVerbose: Boolean = False;
procedure Verbose(const S: AnsiString); overload;
procedure Verbose(const A: array of Const); overload;
procedure VerboseLn; overload;
procedure VerboseLn(const S: AnsiString); overload;
procedure VerboseLn(const A: array of Const); overload;

// Stderr
procedure Err(const S: AnsiString); overload;
procedure Err(const A: array of Const); overload;
procedure ErrLn; overload;
procedure ErrLn(const S: AnsiString); overload;
procedure ErrLn(const A: array of Const); overload;

procedure PrintError(const A: array of Const);
      // Prints one line to stderr with prefixed 'Error: '

procedure PrintWarning(const A: array of Const);
      // Prints one line to stderr with prefixed 'Warning: '

var
  IsOutputAtty: Boolean = False;
procedure InitAtty;

// Changes color of stdout if supported and enabled
var
  UseColors: Boolean = True;
procedure StartColorRed;
procedure StartColorYellow;
procedure StartColorGreen;
procedure StartColorBlue;
procedure EndColor;

var
  UseStatusLine: Boolean = False;
  StatusLineActive: Boolean = False;
  StatusLine: AnsiString;
  StatusLineColor: LongInt = 0;
procedure InitStatusLine;
procedure StartStatusLine;
procedure EndStatusLine;
procedure ChangeStatusLine(S: AnsiString); overload;
procedure ChangeStatusLine(const A: array of Const); overload;
procedure CancelStatusLine;
procedure RestoreStatusLine;

implementation

procedure Print(const S: AnsiString);
begin
  Write(S);
end;

procedure Print(const A: array of Const);
var
  I: LongInt;
begin
  for I := 0 to High(A) do begin
    case A[I].VType of
       vtInteger    : Write(A[I].VInteger);
       vtBoolean    : Write(A[I].VBoolean);
       vtChar       : Write(A[I].VChar);
       vtWideChar   : Write(A[I].VWideChar);
       vtExtended   : Write(A[I].VExtended^);
       vtString     : Write(A[I].VString^);
       vtPointer    : Write('$', HexStr(PtrUInt(A[I].VPointer), SizeOf(PtrUInt) * 2));
       vtPChar      : Write(A[I].VPChar);
       vtObject     : Write('object at $', HexStr(PtrUInt(A[I].VObject), SizeOf(PtrUInt) * 2));
       vtClass      : Write('class at $', HexStr(PtrUInt(A[I].VClass), SizeOf(PtrUInt) * 2));
       // vtPWideChar  : Write(A[I].VPWideChar);
       vtAnsiString : Write(AnsiString(A[I].VAnsiString));
       // vtCurrency   : Write(A[I].VCurrency);
       // vtVariant    : Write(A[I].VVariant^);
       vtInterface  : Write(HexStr(PtrUInt(A[I].VInterface), SizeOf(PtrUInt) * 2));
       // vtWideString : Write(A[I].VWideString^);
       vtInt64      : Write(A[I].VInt64^);
       vtQWord      : Write(A[I].VQWord^);
    else
      Write('?');
    end;
  end;
end;

procedure PrintLn;
begin
  Writeln;
end;

procedure PrintLn(const S: AnsiString);
begin
  Print(S);
  PrintLn;
end;

procedure PrintLn(const A: array of Const);
begin
  Print(A);
  PrintLn;
end;

procedure Verbose(const S: AnsiString); overload;
begin
  if EnabledVerbose then
    Print(S);
end;

procedure Verbose(const A: array of Const); overload;
begin
  if EnabledVerbose then
    Print(A);
end;

procedure VerboseLn; overload;
begin
  if EnabledVerbose then
    PrintLn;
end;

procedure VerboseLn(const S: AnsiString); overload;
begin
  if EnabledVerbose then
    PrintLn(S);
end;

procedure VerboseLn(const A: array of Const); overload;
begin
  if EnabledVerbose then
    PrintLn(A);
end;

procedure Err(const S: AnsiString);
begin
  Write(stderr, S);
end;

procedure Err(const A: array of Const);
var
  I: LongInt;
begin
  for I := 0 to High(A) do begin
    case A[I].VType of
       vtInteger    : Write(stderr, A[I].VInteger);
       vtBoolean    : Write(stderr, A[I].VBoolean);
       vtChar       : Write(stderr, A[I].VChar);
       vtWideChar   : Write(stderr, A[I].VWideChar);
       vtExtended   : Write(stderr, A[I].VExtended^);
       vtString     : Write(stderr, A[I].VString^);
       vtPointer    : Write(stderr, '$', HexStr(PtrUInt(A[I].VPointer), SizeOf(PtrUInt) * 2));
       vtPChar      : Write(stderr, A[I].VPChar);
       vtObject     : Write(stderr, 'object at $', HexStr(PtrUInt(A[I].VObject), SizeOf(PtrUInt) * 2));
       vtClass      : Write(stderr, 'class at $', HexStr(PtrUInt(A[I].VClass), SizeOf(PtrUInt) * 2));
       // vtPWideChar  : Write(stderr, A[I].VPWideChar);
       vtAnsiString : Write(stderr, AnsiString(A[I].VAnsiString));
       // vtCurrency   : Write(stderr, A[I].VCurrency);
       // vtVariant    : Write(stderr, A[I].VVariant^);
       vtInterface  : Write(stderr, HexStr(PtrUInt(A[I].VInterface), SizeOf(PtrUInt) * 2));
       // vtWideString : Write(stderr, A[I].VWideString^);
       vtInt64      : Write(stderr, A[I].VInt64^);
       vtQWord      : Write(stderr, A[I].VQWord^);
    else
      Write(stderr, '?');
    end;
  end;
end;

procedure ErrLn;
begin
  Writeln(stderr);
end;

procedure ErrLn(const S: AnsiString);
begin
  Err(S);
  ErrLn;
end;

procedure ErrLn(const A: array of Const);
begin
  Err(A);
  ErrLn;
end;

procedure PrintError(const A: array of Const);
begin
  StartColorRed;
  Err('Error: ');
  ErrLn(A);
  EndColor;
end;

procedure PrintWarning(const A: array of Const);
begin
  StartColorYellow;
  Err('Warning: ');
  ErrLn(A);
  EndColor;
end;

{$IF Defined(WINDOWS)}
var
  HandleStdOut: windows.HANDLE;
{$ENDIF}

procedure InitAtty;
begin
{$IF Defined(UNIX)}
  IsOutputAtty := IsATTY(output) <> 0;
{$ELSEIF Defined(WINDOWS)}
  HandleStdOut := windows.GetStdHandle(windows.STD_OUTPUT_HANDLE);
  IsOutputAtty := GetFileType(HandleStdOut) = FILE_TYPE_CHAR;
{$ELSE}
  IsOutputAtty := False;
{$ENDIF}
  UseColors := IsOutputAtty;
  UseStatusLine := IsOutputAtty;
end;

procedure InitColorOutput;
begin
end;

procedure StartColorRed;
begin
  if not UseColors then
    Exit;
{$IF Defined(UNIX)}
  Write(#27'[1;31m');
{$ELSEIF Defined(WINDOWS)}
  windows.SetConsoleTextAttribute(HandleStdOut, windows.FOREGROUND_RED);
{$ENDIF}
end;

procedure StartColorYellow;
begin
  if not UseColors then
    Exit;
{$IF Defined(UNIX)}
  Write(#27'[1;33m');
{$ELSEIF Defined(WINDOWS)}
  windows.SetConsoleTextAttribute(HandleStdOut, windows.FOREGROUND_RED or windows.FOREGROUND_GREEN);
{$ENDIF}
end;

procedure StartColorGreen;
begin
  if not UseColors then
    Exit;
{$IF Defined(UNIX)}
  Write(#27'[1;32m');
{$ELSEIF Defined(WINDOWS)}
  windows.SetConsoleTextAttribute(HandleStdOut, windows.FOREGROUND_GREEN);
{$ENDIF}
end;

procedure StartColorBlue;
begin
  if not UseColors then
    Exit;
{$IF Defined(UNIX)}
  Write(#27'[1;34m');
{$ELSEIF Defined(WINDOWS)}
  windows.SetConsoleTextAttribute(HandleStdOut, windows.FOREGROUND_BLUE);
{$ENDIF}
end;

procedure EndColor;
begin
  if not UseColors then
    Exit;
{$IF Defined(UNIX)}
  Write(#27'[0m');
{$ELSEIF Defined(WINDOWS)}
  windows.SetConsoleTextAttribute(HandleStdOut, windows.FOREGROUND_RED or windows.FOREGROUND_GREEN or windows.FOREGROUND_BLUE);
{$ENDIF}
end;

procedure InitStatusLine;
begin
end;

procedure StartStatusLine;
begin
  if (not UseStatusLine) or StatusLineActive then
    Exit;
  StatusLineActive := True;
{$IF Defined(UNIX) or Defined(WINDOWS)}
  // Nothing to do here
{$ENDIF}
end;

procedure EndStatusLine;
begin
  if (not UseStatusLine) or (not StatusLineActive) then
    Exit;
  StatusLineActive := False;
{$IF Defined(UNIX) or Defined(WINDOWS)}
  PrintLn;
{$ENDIF}
end;

procedure ChangeStatusLine(S: AnsiString);
begin
  if not StatusLineActive then
    Exit;
  if Length(S) > 60 then
    SetLength(S, 60);
  StatusLine := S;
  if not UseStatusLine then
    Exit;
{$IF Defined(UNIX)}
  // Clear previous status line first
  Print(#$0D);
  Print(Space(80));
  // Now the actual output
  Print(#$0D);
  Print(S);
{$ELSEIF Defined(WINDOWS)}
  // Clear previous status line first
  Print(#$0D);
  Print(Space(60));
  // Now the actual output
  Print(#$0D);
  Print(S);
{$ENDIF}
end;

procedure ChangeStatusLine(const A: array of Const);
var
  S: AnsiString;
  I: LongInt;
begin
  if not StatusLineActive then
    Exit;
  S := '';
  for I := 0 to High(A) do begin
    case A[I].VType of
    vtInteger: S := S + IntToStr(A[I].VInteger);
    vtChar: S := S + A[I].VChar;
    vtString: S := S + A[I].VString^;
    vtAnsiString: S := S + AnsiString(A[I].VAnsiString);
    else
      continue;
    end;
    if Length(S) >= 60 then begin
      SetLength(S, 60);
      break;
    end;
  end;
  StatusLine := S;
  if not UseStatusLine then
    Exit;
  ChangeStatusLine(S);
end;

procedure CancelStatusLine;
begin
  if not StatusLineActive then
    Exit;
{$IF Defined(UNIX) or Defined(WINDOWS)}
  Print(#$0D);
  Print(Space(60));
  Print(#$0D);
{$ENDIF}
end;

procedure RestoreStatusLine;
begin
  if not StatusLineActive then
    Exit;
  case StatusLineColor of
    0: ;
    1: StartColorGreen;
    2: StartColorRed;
  end;
  Print(StatusLine);
  if StatusLineColor <> 0 then
    EndColor;
end;

initialization
  InitAtty;
  InitColorOutput;
  InitStatusLine;
end.
