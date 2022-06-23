unit pubforth_backend;
// Author:  Doj
// License: Public domain or MIT

//
//  Generic backend declarations
//

{$MODE FPC}
{$MODESWITCH ADVANCEDRECORDS}
{$MODESWITCH DEFAULTPARAMETERS}
{$MODESWITCH OUT}
{$MODESWITCH RESULT}

interface

uses
  pubforth_machine;

type
PTranslationTask = ^TTranslationTask;
TTranslationTask = record
  BackendName: AnsiString; // actual name of the backend
  Dictionary: PDictionary;
  Main: PDictionaryRecord;
  TargetOS: AnsiString; // windows or linux
  TargetCPU: AnsiString; // x86 x86_64 arm32 arm64
  OptimizationLevel: Int32;   // 0 - no optimization
  Include: AnsiString; // INCLUDE env for FASM
  OutputFileName: AnsiString;
  BinaryFileName: AnsiString; // executable or library
  procedure InitDefaults;
end;

PBackend = ^TBackend;
TBackend = object
public
  constructor Init;
  destructor  Done; virtual;

  function  Translate(Task: PTranslationTask): Boolean; virtual;

  // Helpers for writing to text file
public
  function  OpenTextFile(const FileName: AnsiString): Boolean;
  procedure CloseTextFile;
  function  WriteLine(const Line: AnsiString): Boolean;
  function  WriteChars(S, SEnd: PAnsiChar): Boolean;
private
  FTextFile: TextFile;
  FTextFileOpened: Boolean;

public
  function Error(const Msg: AnsiString): Boolean;
end;

PBackendList = ^TBackendList;
TBackendList = object
private
  FName: AnsiString;
  FExtensions: AnsiString;
  FBackend: PBackend;
  FNext: PBackendList;
end;

procedure RegisterBackend(Name: PAnsiChar; Backend: PBackend; Extensions: PAnsiChar = '');
      //  Registers new backend with the specified name.

function  FindBackend(const Name: AnsiString): PBackend;

procedure PrintBackendsList;



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

procedure TTranslationTask.InitDefaults;
begin
  BackendName := '';
  Dictionary := nil;
  Main := nil;
  TargetOS := '';
  TargetCPU := '';
  OptimizationLevel := 0;
  OutputFileName := '';
  BinaryFileName := '';
end;

constructor TBackend.Init;
begin
end;

destructor  TBackend.Done;
begin
end;

function  TBackend.Translate(Task: PTranslationTask): Boolean;
begin
  Exit(True);
end;

function  TBackend.OpenTextFile(const FileName: AnsiString): Boolean;
begin
  Assign(FTextFile, FileName);
  {$PUSH} {$I-} ReWrite(FTextFile); {$POP}
  FTextFileOpened := IOResult = 0;
  Exit(FTextFileOpened);
end;

procedure TBackend.CloseTextFile;
begin
  if not FTextFileOpened then
    Exit;
  FTextFileOpened := False;
  {$PUSH} {$I-} Flush(FTextFile); {$POP}
  if IOResult <> 0 then
    Exit;
  {$PUSH} {$I-} Close(FTextFile); {$POP}
  if IOResult <> 0 then
    Exit;
end;

function  TBackend.WriteLine(const Line: AnsiString): Boolean;
begin
  {$PUSH} {$I-} Writeln(FTextFile, Line); {$POP}
  if IOResult <> 0 then
    FTextFileOpened := False;
  Result := FTextFileOpened;
end;

function  TBackend.WriteChars(S, SEnd: PAnsiChar): Boolean;
var
  Buf: AnsiString;
begin
  SetLength(Buf, SEnd - S);
  Move(S^, Buf[1], SEnd - S);
  {$PUSH} {$I-} Write(FTextFile, Buf); {$POP}
  if IOResult <> 0 then
    FTextFileOpened := False;
  Result := FTextFileOpened;
end;

function TBackend.Error(const Msg: AnsiString): Boolean;
begin
  Writeln(Msg);
  Exit(False);
end;

var
  LastBackend: PBackendList = nil;

procedure RegisterBackend(Name: PAnsiChar; Backend: PBackend; Extensions: PAnsiChar = '');
var
  Item: PBackendList;
begin
  New(Item);
  Item^.FName := Name;
  Item^.FExtensions := Extensions;
  Item^.FBackend := Backend;
  Item^.FNext := LastBackend;

  LastBackend := Item;
end;

function  FindBackend(const Name: AnsiString): PBackend;
var
  It: PBackendList;
begin
  It := LastBackend;
  while It <> nil do begin
    if It^.FName = Name then
      Exit(It^.FBackend);
    It := It^.FNext;
  end;
  Exit(nil);
end;

procedure PrintBackendsList;
var
  It: PBackendList;
begin
  It := LastBackend;
  while It <> nil do begin
    Writeln(It^.FName, '              ', It^.FExtensions);
    It := It^.FNext;
  end;
end;

procedure FreeBackendList;
var
  Next: PBackendList;
begin
  while LastBackend <> nil do begin
    Next := LastBackend^.FNext;

    Dispose(LastBackend);

    LastBackend := Next;
  end;
end;

end.
