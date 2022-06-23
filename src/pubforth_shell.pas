unit pubforth_shell;
// Author:  Doj
// License: Public domain or MIT

//
// Executing shell commands.
//

{$MODE FPC}
{$MODESWITCH DEFAULTPARAMETERS}
{$MODESWITCH OUT}
{$MODESWITCH RESULT}

interface

uses
  process,
  tp_env;

function ExecuteShell(Cmd: PPAnsiChar): Boolean;


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

function ExecuteSingleProcess(Cmd, CmdEnd: PPAnsiChar; Env: PEnv): Boolean;
var
  Process: TProcess;
  Buffer: array[0 .. 4 * 1024] of AnsiChar;
  ReadSize, ReadCount: SizeUInt;
begin
  if Cmd >= CmdEnd then
    Exit(True); // NOP

  Process := TProcess.Create(nil);
  Process.Options := [poUsePipes];
  Process.Executable := Cmd^;
  Write('$ ', Cmd^);

  Inc(Cmd);
  while Cmd < CmdEnd do begin
    Write(' ', Cmd^);
    Process.Parameters.Add(Cmd^);
    Inc(Cmd);
  end;
  Writeln;

  if Env <> nil then begin
    OverrideEnv(Process, Env);
  end;

  Process.Execute;

  while Process.Running or (Process.Output.NumBytesAvailable > 0) or (Process.Stderr.NumBytesAvailable > 0) do begin
    if Process.Output.NumBytesAvailable > 0 then begin
      ReadSize := Process.Output.NumBytesAvailable;
      if ReadSize > Length(Buffer) - 1 then
        ReadSize := Length(Buffer) - 1;
      ReadCount := Process.Output.Read(Buffer[0], ReadSize);
      Buffer[ReadCount] := #0;
      Write(PAnsiChar(@Buffer[0]));
    end;

    if Process.Stderr.NumBytesAvailable > 0 then begin
      ReadSize := Process.Stderr.NumBytesAvailable;
      if ReadSize > Length(Buffer) - 1 then
        ReadSize := Length(Buffer) - 1;
      ReadCount := Process.Stderr.Read(Buffer[0], ReadSize);
      Buffer[ReadCount] := #0;
      Write(stderr, PAnsiChar(@Buffer[0]));
    end;
  end;

  Result := Process.ExitCode <> 0;

  Process.Free;
end;

function ExecutePipe(Pipe, PipeEnd: PPAnsiChar; Env: PEnv): Boolean;
begin
  // TODO actual pipe
  Exit(ExecuteSingleProcess(Pipe, PipeEnd, Env));
end;

function ExecuteShell(Cmd: PPAnsiChar): Boolean;
var
  Env: TEnv;
  LastSuccess: Boolean;
  CmdEnd: PPAnsiChar;
  EnvMode: Boolean;
begin
  Env.Init;

  LastSuccess := True;

  EnvMode := True;
  CmdEnd := Cmd;
  while CmdEnd^ <> nil do begin
    if EnvMode and (AnsiString(CmdEnd^) = 'set') then begin
      Env.Add(Cmd[1], Cmd[2]);
      Inc(Cmd, 3);
      CmdEnd := Cmd;
      continue;
    end;

    EnvMode := False;

    if AnsiString(CmdEnd^) = '&&' then begin
      if LastSuccess then
        LastSuccess := ExecutePipe(Cmd, CmdEnd, @Env);
      Cmd := CmdEnd + 1;
      CmdEnd := Cmd;
      continue;
    end;

    if AnsiString(CmdEnd^) = '||' then begin
      if not LastSuccess then
        LastSuccess := ExecutePipe(Cmd, CmdEnd, @Env);
      Cmd := CmdEnd + 1;
      CmdEnd := Cmd;
      continue;
    end;

    Inc(CmdEnd);
  end;

  if LastSuccess then
    LastSuccess := ExecutePipe(Cmd, CmdEnd, @Env);

  Env.Done;
  Exit(LastSuccess);
end;

end.
