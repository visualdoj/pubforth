unit pubforth_backend_pascal;
// Author:  Doj
// License: Public domain or MIT

//
//  Backend for producing Pascal Code.
//

{$MODE FPC}
{$MODESWITCH DEFAULTPARAMETERS}
{$MODESWITCH OUT}
{$MODESWITCH RESULT}

interface

uses
  pubforth_backend,
  pubforth_shell;




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

type
TBackendPascal = object(TBackend)
public
  constructor Init;
  destructor Done; virtual;

  function  Translate(Task: PTranslationTask): Boolean; virtual;
  function  Compile(Task: PTranslationTask): Boolean;
end;

var
  BackendPascal: TBackendPascal;

constructor TBackendPascal.Init;
begin
  inherited Init;
end;

destructor TBackendPascal.Done;
begin
  inherited Done;
end;

function  TBackendPascal.Translate(Task: PTranslationTask): Boolean;
begin
  OpenTextFile(Task^.OutputFileName);
  WriteLine('begin');
  WriteLine('  Writeln(''Hello world!'');');
  WriteLine('end.');
  CloseTextFile;

  if Task^.BinaryFileName <> '' then begin
    if not Compile(Task) then
      Exit(False);
  end;

  Exit(True);
end;

function  TBackendPascal.Compile(Task: PTranslationTask): Boolean;
var
  CmdS: array of AnsiString;
  Cmd: array of PAnsiChar;

  procedure AddCmd(const S: AnsiString);
  begin
    SetLength(CmdS, Length(CmdS) + 1);
    SetLength(Cmd, Length(Cmd) + 1);
    CmdS[High(CmdS)] := S;
    if S = '' then begin
      Cmd[High(Cmd)] := nil;
    end else
      Cmd[High(Cmd)] := PAnsiChar(CmdS[High(CmdS)]);
  end;
begin
  SetLength(CmdS, 0);
  SetLength(Cmd, 0);

  AddCmd('fpc');
  AddCmd(Task^.OutputFileName);
  AddCmd('-FE.'); // TODO temp directory
  AddCmd('-o' + Task^.BinaryFileName);
  AddCmd('');

  Result := ExecuteShell(@Cmd[0]);
end;

initialization
  BackendPascal.Init;
  RegisterBackend('pascal', @BackendPascal, '.pas');
finalization
  BackendPascal.Done;
end.
