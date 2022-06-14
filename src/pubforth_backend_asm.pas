unit pubforth_backend_asm;
// Author:  Doj
// License: Public domain or MIT

//
//  Several backends for producing assembler code.
//

{$MODE FPC}
{$MODESWITCH DEFAULTPARAMETERS}
{$MODESWITCH OUT}
{$MODESWITCH RESULT}

interface

uses
  pubforth_backend;




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
TBackendAsm = object(TBackend)
public
  constructor Init;
  destructor Done; virtual;

  function  Translate(Task: PTranslationTask): Boolean; virtual;
end;

var
  BackendAsm: TBackendAsm;

constructor TBackendAsm.Init;
begin
  inherited Init;
end;

destructor TBackendAsm.Done;
begin
  inherited Done;
end;

function  TBackendAsm.Translate(Task: PTranslationTask): Boolean;
begin
  OpenTextFile(Task^.OutputFileName);

  if Task^.TargetOS = 'windows' then begin
    WriteLine('; ' + Task^.BackendName + ' to windows');
    WriteLine('format PE console');
    WriteLine('entry main');
    WriteLine('');
    WriteLine('include ''include\win32a.inc''');
    WriteLine('');
    WriteLine(';====================================');
    WriteLine('section ''.data'' data readable writeable');
    WriteLine('');
    WriteLine('hello_msg db ''Hello, world!'',0');
    WriteLine('');
    WriteLine(';====================================');
    WriteLine('section ''.code'' code readable executable');
    WriteLine('');
    WriteLine('main:');
    WriteLine('  ccall    [printf],hello_msg');
    WriteLine('  ccall    [getchar]');
    WriteLine('  stdcall  [ExitProcess],0');
    WriteLine('');
    WriteLine(';====================================');
    WriteLine('section ''.idata'' import data readable');
    WriteLine('');
    WriteLine('library kernel,''kernel32.dll'',\');
    WriteLine('        msvcrt,''msvcrt.dll''');
    WriteLine('');
    WriteLine('import kernel,\');
    WriteLine('       ExitProcess,''ExitProcess''');
    WriteLine('');
    WriteLine('import msvcrt,\');
    WriteLine('       printf,''printf'',\');
    WriteLine('       getchar,''_fgetchar''');
  end else if Task^.TargetOS = 'linux' then begin
    WriteLine('; ' + Task^.BackendName + ' to linux');
    WriteLine('');
    WriteLine('format ELF executable 3');
    WriteLine('entry main');
    WriteLine('');
    WriteLine('segment readable executable');
    WriteLine('');
    WriteLine('main:');
    WriteLine('');
    WriteLine('mov eax,4');
    WriteLine('mov ebx,1');
    WriteLine('mov ecx,msg');
    WriteLine('mov edx,msg_size');
    WriteLine('int 0x80');
    WriteLine('');
    WriteLine('mov eax,1');
    WriteLine('xor ebx,ebx');
    WriteLine('int 0x80');
    WriteLine('');
    WriteLine('segment readable writeable');
    WriteLine('');
    WriteLine('msg db ''Hello world!'',0xA');
    WriteLine('msg_size = $-msg');
  end else begin
    Exit(Error('unknown target OS ' + Task^.TargetOS));
  end;

  CloseTextFile;
  Exit(True);
end;

initialization
  BackendAsm.Init;
  RegisterBackend('fasm', @BackendAsm, '.fasm');
  RegisterBackend('x86', @BackendAsm);
  RegisterBackend('x86_64', @BackendAsm);
  RegisterBackend('arm', @BackendAsm);
  RegisterBackend('arm64', @BackendAsm);
finalization
  BackendAsm.Done;
end.
