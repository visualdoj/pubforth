unit pubforth_command_line_args;
// Author:  Doj
// License: Public domain or MIT

//
//  Parser for command line arguments.
//
//  Run the following command for getting command line documentation:
//
//    pubforth --long-help
//

{$MODE FPC}
{$MODESWITCH DEFAULTPARAMETERS}
{$MODESWITCH OUT}
{$MODESWITCH RESULT}

interface

uses
  dterm,
  pubforth_core;

type
TPubForthInputArg = record
  _Type: Int32; // 0 - filename, 1 - code
  S: AnsiString;
end;

PPubForthCLArgs = ^TPubForthCLArgs;
TPubForthCLArgs = object
  ErrorMsg: AnsiString;
  NoArgs: Boolean;
  Usage: Boolean;
  LongHelp: Boolean;
  Version: Boolean;
  ShortVersion: Boolean;
  PrintPlan: Boolean;
  PatchReadme: Boolean;
  PrintStdList: Boolean;
  PrintBackendsList: Boolean;
  Experimental: Boolean;
  Test: Boolean;
  Std: AnsiString;
  Repl: Boolean;
  NoRepl: Boolean;
  Backend: AnsiString;
  BackendCompile: Boolean;
  BackendInclude: AnsiString;
  OutputFileName: AnsiString;
  Main: AnsiString;
  OS: AnsiString;
  CPU: AnsiString;
  InputArgs: array of TPubForthInputArg;
  procedure Init;
  procedure Done;
  procedure SetDefaults;

  function ParseParamStrings: Boolean;
      // Parses command line arguments from ParamStr(i)
end;

procedure PrintUsage;
procedure PrintLongHelp;
procedure PrintVersion;
procedure PrintShortVersion;

procedure PrintStdList;



implementation

//  ---------------------------------------------------------------------------
//  This software is available under 2 licenses -- choose whichever you prefer.
//  ---------------------------------------------------------------------------
//  ALTERNATIVE A - MIT License
//
//  Copyright (c) 2022 Viktor Matuzenko aka Doj
//
//  Permission is hereby granted, free of charge, to any person obtaining a
//  copy of this software and associated documentation files (the "Software"),
//  to deal in the Software without restriction, including without limitation
//  the rights to use, copy, modify, merge, publish, distribute, sublicense,
//  and/or sell copies of the Software, and to permit persons to whom the
//  Software is furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
//  DEALINGS IN THE SOFTWARE.
//
//  ---------------------------------------------------------------------------
//  ALTERNATIVE B - Public Domain (www.unlicense.org)
//
//  This is free and unencumbered software released into the public domain.
//
//  Anyone is free to copy, modify, publish, use, compile, sell, or distribute
//  this software, either in source code form or as a compiled binary, for any
//  purpose, commercial or non-commercial, and by any means.
//
//  In jurisdictions that recognize copyright laws, the author or authors of
//  this software dedicate any and all copyright interest in the software to
//  the public domain. We make this dedication for the benefit of the public at
//  large and to the detriment of our heirs and successors. We intend this
//  dedication to be an overt act of relinquishment in perpetuity of all
//  present and future rights to this software under copyright law.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
//  ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
//  CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//
//  For more information, please refer to <http://unlicense.org/>
//  ---------------------------------------------------------------------------

procedure TPubForthCLArgs.Init;
begin
  SetDefaults;
end;

procedure TPubForthCLArgs.Done;
begin
end;

procedure TPubForthCLArgs.SetDefaults;
begin
  ErrorMsg := '';
  NoArgs := True;
  Usage := False;
  Version := False;
  ShortVersion := False;
  PrintPlan := False;
  PatchReadme := False;
  PrintStdList := False;
  PrintBackendsList := False;
  Experimental := False;
  Test := False;
  Backend := '';
  BackendCompile := False;
  BackendInclude := '';
  OutputFileName := '';
  Main := '';
  OS := '';
  CPU := '';
  Std := 'forth2012';
  Repl := False;
  NoRepl := False;
  SetLength(InputArgs, 0);
end;

function TPubForthCLArgs.ParseParamStrings: Boolean;
var
  I: Int32;
begin
  if ParamCount > 0 then
    NoArgs := False;

  I := 1;
  while I <= ParamCount do begin
    if (ParamStr(I) = '-?') or (ParamStr(I) = '-h') or (ParamStr(I) = '--usage') then begin
      Usage := True
    end else if (ParamStr(I) = '--help') or (ParamStr(I) = '--long-help') then begin
      LongHelp := True
    end else if (ParamStr(I) = '-v') or (ParamStr(I) = '--version') then begin
      Version := True;
    end else if ParamStr(I) = '--short-version' then begin
      ShortVersion := True;
    end else if ParamStr(I) = '--print-plan' then begin
      PrintPlan := True;
    end else if ParamStr(I) = '--patch-readme' then begin
      PatchReadme := True;
    end else if ParamStr(I) = '--print-std-list' then begin
      PrintStdList := True;
    end else if ParamStr(I) = '--print-backends-list' then begin
      PrintBackendsList := True;
    end else if ParamStr(I) = '--experimental' then begin
      Experimental := True;
    end else if ParamStr(I) = '--test' then begin
      Test := True;
    end else if ParamStr(I) = '--repl' then begin
      Repl := True;
    end else if ParamStr(I) = '--no-repl' then begin
      NoRepl := True;
    end else if ParamStr(I) = '--backend' then begin
      Inc(I);
      if I > ParamCount then begin
        ErrorMsg := ParamStr(I - 1) + ' needs an argument';
        Exit(False);
      end;
      Backend := ParamStr(I);
    end else if ParamStr(I) = '--backend-compile' then begin
      BackendCompile := True;
    end else if ParamStr(I) = '--backend-include' then begin
      Inc(I);
      if I > ParamCount then begin
        ErrorMsg := ParamStr(I - 1) + ' needs an argument';
        Exit(False);
      end;
      BackendInclude := ParamStr(I);
    end else if (ParamStr(I) = '-o') or (ParamStr(I) = '--output') then begin
      Inc(I);
      if I > ParamCount then begin
        ErrorMsg := ParamStr(I - 1) + ' needs an argument';
        Exit(False);
      end;
      OutputFileName := ParamStr(I);
    end else if (ParamStr(I) = '-e') or (ParamStr(I) = '--evaluate') then begin
      Inc(I);
      if I > ParamCount then begin
        ErrorMsg := ParamStr(I - 1) + ' needs an argument';
        Exit(False);
      end;
      SetLength(InputArgs, Length(InputArgs) + 1);
      InputArgs[High(InputArgs)]._Type := 1;
      InputArgs[High(InputArgs)].S := ParamStr(I);
    end else if ParamStr(I) = '--main' then begin
      Inc(I);
      if I > ParamCount then begin
        ErrorMsg := ParamStr(I - 1) + ' needs an argument';
        Exit(False);
      end;
      Main := ParamStr(I);
    end else if ParamStr(I) = '--os' then begin
      Inc(I);
      if I > ParamCount then begin
        ErrorMsg := ParamStr(I - 1) + ' needs an argument';
        Exit(False);
      end;
      OS := ParamStr(I);
    end else if ParamStr(I) = '--cpu' then begin
      Inc(I);
      if I > ParamCount then begin
        ErrorMsg := ParamStr(I - 1) + ' needs an argument';
        Exit(False);
      end;
      CPU := ParamStr(I);
    end else if ParamStr(I) = '--std' then begin
      Inc(I);
      if I > ParamCount then begin
        ErrorMsg := ParamStr(I - 1) + ' needs an argument';
        Exit(False);
      end;
      Std := ParamStr(I);
    end else begin
      if (Length(ParamStr(I)) > 0) and (ParamStr(I)[1] = '-') then begin
        ErrorMsg := 'unrecognized option ' + ParamStr(I);
        Exit(False);
      end;

      SetLength(InputArgs, Length(InputArgs) + 1);
      InputArgs[High(InputArgs)]._Type := 0;
      InputArgs[High(InputArgs)].S := ParamStr(I);
    end;

    Inc(I);
  end;

  Exit(True);
end;

procedure PrintHelp(LongHelp: Boolean);

  procedure EmitColorized(S, SEnd: PAnsiChar);
  const
    DEF = TERMINAL_COLOR_DEFAULT;
    OPT = TERMINAL_COLOR_BRIGHT_WHITE;
  var
    Start: PAnsiChar;
    InsideOpt: Boolean;
    CurrentColor: TTerminalColor;
    Prev: AnsiChar;

    procedure EmitRaw(S, SEnd: PAnsiChar);
    var
      Buf: ShortString;
    begin
      SetLength(Buf, SEnd - S);
      Move(S^, Buf[1], SEnd - S);
      Write(Buf);
      Start := SEnd;
    end;
    procedure SetCurrentColor(NewColor: TTerminalColor);
    begin
      if NewColor <> CurrentColor then begin
        EmitRaw(Start, S);
        CurrentColor := NewColor;
        SetTerminalColor(NewColor);
      end;

      if NewColor = DEF then
        ResetTerminalColor;
    end;

  begin
    CurrentColor := DEF;
    Start := S;
    InsideOpt := False;
    Prev := #0;
    while S < SEnd do begin
      if (not InsideOpt) and (S^ = '-') and (Prev in [#0, ' ']) then
        InsideOpt := True;

      if InsideOpt then begin
        SetCurrentColor(OPT);
      end else begin
        SetCurrentColor(DEF);
      end;

      if InsideOpt and not (S^ in ['a'..'z', 'A'..'Z', '-', '0'..'9']) then
        InsideOpt := False;

      Prev := S^;
      Inc(S);
    end;

    EmitRaw(Start, S);
    SetCurrentColor(DEF);
  end;
  procedure U(const Msg: AnsiString); // Usage only
  begin
    if not LongHelp then begin
      EmitColorized(@Msg[1], @Msg[1] + Length(Msg));
      Writeln
    end;
  end;
  procedure L(const Msg: AnsiString); // Long help only
  begin
    if LongHelp then begin
      EmitColorized(@Msg[1], @Msg[1] + Length(Msg));
      Writeln
    end;
  end;
  procedure A(const Msg: AnsiString); // All
  begin
    EmitColorized(@Msg[1], @Msg[1] + Length(Msg));
    Writeln;
  end;
begin
  U('Usage: ');
  L('Commands: ');
  A('  pubforth -?|-h|--usage');
  L('     Prints short usage');
  L('');
  A('  pubforth --help|--long-help');
  L('     Prints this help');
  L('');
  A('  pubforth -v|--version');
  L('     Prints version');
  L('');
  L('  pubforth --short-version');
  L('     Prints short version in format <major.minor.patch>');
  L('');
  L('  pubforth --patch-readme README.md');
  L('     Patchs README.md with some information known from source code');
  L('');
  A('  pubforth --print-backends-list');
  L('     Prints list of supported backends with their respective extensions');
  L('');
  A('  pubforth --print-std-list');
  L('     Prints list of supported standards');
  L('');
  A('  pubforth --print-plan');
  L('     Prints the development plan');
  L('');
  A('  pubforth -e|--evaluate <STRING>');
  L('     Evaluate the specified STRING');
  L('');
  A('  pubforth -o|--output <FILENAME>');
  L('     Generate backend code and save it to the specified filename');
  A('');
  A('Options:');
  A('  --std <STANDARD>');
  L('     Use the specified standard. Default: forth2012');
  L('');
  A('  --backend <BACKEND>');
  L('     Use the specified backend. By default will try detect backend by output file extension');
  L('');
  L('  --backend-compile');
  L('     Call external compiler for producing executable instead of source');
  L('');
  L('  --backend-include <DIRECTORY>');
  L('     For FASM backend: sets INCLUDE environment variable');
  L('');
  A('  --main <WORDNAME>');
  L('     Use the specified word as a program entry point. Default: MAIN');
  L('');
  A('  --os <OSNAME>');
  L('     Use other target OS. Possible values: windows, linux');
  L('');
  A('  --cpu <CPUNAME>');
  L('     Use other target CPU');
  L('');
  A('  --experimental');
  L('     Turns on all experimental and not-yet-tested words');
  L('');
  A('  --test');
  L('     Turns on test mode. Essentially it adds the following words:');
  L('     T{   ->   }T');
  L('');
  A('  --repl');
  L('     Run REPL mode after processing all sources');
  L('');
  A('  --no-repl');
  L('     Do not run REPL mode after processing all sources');
end;

procedure PrintUsage;
begin
  PrintHelp(False);
end;

procedure PrintLongHelp;
begin
  PrintHelp(True);
end;

procedure PrintShortVersion;
begin
  Write(PUBFORTH_VERSION_MAIN, '.', PUBFORTH_VERSION_MAJOR, '.', PUBFORTH_VERSION_MINOR);
  {$IF PUBFORTH_VERSION_PATCH > 0}
    Write('.', PUBFORTH_VERSION_PATCH);
  {$ENDIF}
  Writeln;
end;

procedure PrintVersion;
begin
  Write('PubForth ', PUBFORTH_VERSION_MAIN, '.', PUBFORTH_VERSION_MAJOR, '.', PUBFORTH_VERSION_MINOR);
  {$IF PUBFORTH_VERSION_PATCH > 0}
    Write('.', PUBFORTH_VERSION_PATCH);
  {$ENDIF}
  Write(PUBFORTH_VERSION_PRERELEASE);
  Write(PUBFORTH_VERSION_META);
  Writeln;
  Writeln('Public domain implementation of Forth');
  Writeln('https://github.com/visualdoj/pubforth');
end;

procedure PrintStdList;
begin
  Writeln('forth2012');
end;

end.
