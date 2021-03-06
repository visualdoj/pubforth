program pubforth;
// Author:  Doj
// License: Public domain or MIT

{$MODE FPC}
{$MODESWITCH DEFAULTPARAMETERS}
{$MODESWITCH OUT}
{$MODESWITCH RESULT}

uses
  dterm,
  //pubforth_core,
  pubforth_words,
  //pubforth_doc_parser,
  pubforth_machine,
  pubforth_backend,
  pubforth_backend_dump,
  pubforth_backend_c,
  pubforth_backend_pascal,
  pubforth_backend_asm,
  pubforth_command_line_args;

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

procedure PrintError(const ErrorMsg: AnsiString);
begin
  SetTerminalColor(TERMINAL_COLOR_BRIGHT_RED);
  Writeln(stderr, ErrorMsg);
  ResetTerminalColor;
end;

function EndsWith(const S: AnsiString; const Ending: AnsiString): Boolean;
begin
  Exit((Length(S) >= Length(Ending)) and (Copy(S, Length(S) - Length(Ending) + 1, Length(Ending)) = Ending));
end;

var
  Args: TPubForthCLArgs;
  Machine: TMachine;
  BackendName: AnsiString;
  Backend: PBackend;
  TranslationTask: TTranslationTask;
  I: Int32;

procedure REPL;
var
  Line: AnsiString;
begin
  if Machine.Bye then
    Exit;
  Writeln('Type BYE to exit the REPL');
  while not Machine.Bye do begin
    Write('> ');
    Readln(Line);
    if Machine.InterpretREPLInput(Line) then
      Writeln('ok')
  end;
end;

function ReplaceExt(const FileName: AnsiString; const NewExt: AnsiString): AnsiString;
var
  I: Int32;
begin
  I := Length(FileName);
  while I > 0 do begin
    if FileName[I] = '.' then
      break;
    Dec(I);
  end;

  if I <= 0 then begin
    Exit(FileName + NewExt);
  end else
    Exit(Copy(FileName, 1, I - 1) + NewExt);
end;

begin
  Args.Init;

  Args.SetDefaults;
  if not Args.ParseParamStrings then begin
    PrintError(Args.ErrorMsg);
    Halt(1);
  end;

  if Args.NoArgs then begin
    PrintVersion;
    Writeln;
    PrintUsage;
    Halt(0);
  end;

  if Args.LongHelp then begin
    PrintLongHelp;
    Halt(0);
  end;

  if Args.NoArgs or Args.Usage then begin
    PrintUsage;
    Halt(0);
  end;

  if Args.Version then begin
    PrintVersion;
    Halt(0);
  end;

  if Args.ShortVersion then begin
    PrintShortVersion;
    Halt(0);
  end;

  if Args.PrintPlan then begin
    PrintDevelopmentPlan;
    Halt(0);
  end;

  if Args.PatchReadme then begin
    if Length(Args.InputArgs) = 0 then begin
      PrintError('no filename provided');
      Halt(1);
    end;
    if not PatchReadmeFile(Args.InputArgs[0].S) then begin
      PrintError('Failed patching ' + Args.InputArgs[0].S);
      Halt(1);
    end;
    Halt(0);
  end;

  if Args.PrintStdList then begin
    PrintStdList;
    Halt(0);
  end;

  if Args.PrintBackendsList then begin
    PrintBackendsList;
    Halt(0);
  end;

  Machine.Init;
  Machine.Configurate(@Args);

  if Args.Experimental then
    Machine.ConfigureExperimental;

  if Args.Test then
    Machine.ConfigureTest;

  for I := 0 to High(Args.InputArgs) do begin
    case Args.InputArgs[I]._Type of
    0: if not Machine.InterpretFile(Args.InputArgs[I].S) then
         Halt(1);
    1: if not Machine.InterpretString(Args.InputArgs[I].S) then
         Halt(1);
    end;
    if Machine.Bye then
      break;
  end;

  if Args.OutputFileName <> '' then begin
    BackendName := Args.Backend;
    if BackendName = '' then begin
      if EndsWith(Args.OutputFileName, '.dump') then begin
        BackendName := 'dump';
      end else if EndsWith(Args.OutputFileName, '.c') then begin
        BackendName := 'c';
      end else if EndsWith(Args.OutputFileName, '.pas') then begin
        BackendName := 'pascal';
      end else if EndsWith(Args.OutputFileName, '.fasm') then begin
        BackendName := 'fasm';
      end else begin
        PrintError('cannot find suitable backend for ' + Args.OutputFileName);
        Halt(1);
      end;
    end;

    Backend := FindBackend(BackendName);
    if Backend = nil then begin
      PrintError('unknown backend: ' + BackendName);
      Halt(1);
    end;

    TranslationTask.InitDefaults;
    TranslationTask.BackendName := BackendName;

    if Args.BackendCompile then begin
      TranslationTask.OutputFileName := ReplaceExt(Args.OutputFileName, '.pp'); // TODO temp filename
      TranslationTask.BinaryFileName := Args.OutputFileName;
    end else begin
      TranslationTask.OutputFileName := Args.OutputFileName;
    end;

    TranslationTask.TargetOS := Args.OS;
    if TranslationTask.TargetOS = '' then begin
      {$IF Defined(WINDOWS)}
      TranslationTask.TargetOS := 'windows';
      {$ELSEIF Defined(LINUX)}
      TranslationTask.TargetOS := 'linux';
      {$ELSEIF Defined(UNIX)}
      TranslationTask.TargetOS := 'linux';
      {$ELSE}
      TranslationTask.TargetOS := 'linux';
      {$ENDIF}
    end;

    TranslationTask.TargetCPU := Args.CPU;
    if TranslationTask.TargetCPU = '' then begin
      {$IF Defined(CPU386) or Defined(CPUi386)}
      TranslationTask.TargetCPU := 'x86';
      {$ELSEIF Defined(CPUAMD64) or Defined(CPUX86_64) or Defined(CPUX64)}
      TranslationTask.TargetCPU := 'x86_64';
      {$ELSE}
      TranslationTask.TargetCPU := '?';
      {$ENDIF}
    end;

    TranslationTask.Include := Args.BackendInclude;

    TranslationTask.Dictionary := Machine.GetDictionary;
    if not TranslationTask.Dictionary^.Find('MAIN', TranslationTask.Main) then begin
      PrintError('MAIN is not defined');
      Halt(1);
    end;

    TranslationTask.Dictionary^.ClearReachable;
    TranslationTask.Dictionary^.MarkReachable(TranslationTask.Main);

    if not Backend^.Translate(@TranslationTask) then
      Halt(1);
  end;

  if Args.Repl then begin
    Machine.ConfigureREPL;
    REPL;
  end;

  Machine.Done;

  Args.Done;
end.
