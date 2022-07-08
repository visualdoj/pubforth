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
  pubforth_core,
  pubforth_machine,
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
private
  FStdoutPrepared: Boolean;

  procedure PrepareStdout;
  function  EscapeIdentifier(const Identifier: AnsiString): AnsiString;

public
  constructor Init;
  destructor Done; virtual;

  function  Translate(Task: PTranslationTask): Boolean; virtual;
  function  Compile(Task: PTranslationTask): Boolean;
end;

var
  BackendPascal: TBackendPascal;

procedure TBackendPascal.PrepareStdout;
begin
  if FStdoutPrepared then
    Exit;

  FStdoutPrepared := True;
end;

function  TBackendPascal.EscapeIdentifier(const Identifier: AnsiString): AnsiString;
begin
  Exit(Identifier);
end;

constructor TBackendPascal.Init;
begin
  inherited Init;
end;

destructor TBackendPascal.Done;
begin
  inherited Done;
end;

function  TBackendPascal.Translate(Task: PTranslationTask): Boolean;
var
  {$I pubforth_iterate_code_variables.inc};
  Dictionary: PDictionary;
  I: Int32;
  It, Definition: PDictionaryRecord;
begin
  OpenTextFile(Task^.OutputFileName);

  Dictionary := Task^.Dictionary;
  for I := 0 to 255 do begin
    if Dictionary^.ReachableOpcodes[I] then begin
      case I of
        OP_NOP: ;
        OP_END: ;
        OP_LITERAL: ;
        OP_CR: PrepareStdout;
        OP_CALL: ;
        OP_ENTER: ;
        OP_DOT: PrepareStdout;
        OP_BYE: ;
        OP_RETURN: ;
        OP_WORDS: Exit(Error('no backend semantics for WORDS'));
        OP_PRINT_LITERAL_STR: PrepareStdout;
        OP_SEE: Exit(Error('no backend semantics for SEE'));
        OP_DOT_S: Exit(Error('no backend semantics for .S'));
        OP_QUESTION: PrepareStdout;
        OP_STATE: Exit(Error('no backend semantics for STATE'));
        OP_SOURCE_ID: Exit(Error('no backend semantics for SOURCE-ID'));
      end;
    end;
  end;

  // TODO fix iteration order (from first to last)
  //      make colon definitions forward for now
  It := Dictionary^.Last;
  while It <> nil do begin
    if It^.IsReachable and It^.IsColonDefinition then
      WriteLine('procedure ' + EscapeIdentifier(It^.Name) + '; forward;');
    It := It^.Next;
  end;

  // Colon definitions
  It := Dictionary^.Last;
  while It <> nil do begin
    if It^.IsReachable and It^.IsColonDefinition then begin
      WriteLine('procedure ' + EscapeIdentifier(It^.Name) + ';');
      WriteLine('begin');
      Definition := It;
      {$I pubforth_iterate_code_begin.inc}
        OP_NOP: ;
        OP_END:     WriteLine('  Exit;');
        // OP_LITERAL: WriteLine('  LITERAL' + IntToStr({$I pubforth_iterate_code_arg_n.inc}));
        OP_CR:      WriteLine('  Writeln;');
        OP_CALL:    WriteLine('  ' + EscapeIdentifier({$I pubforth_iterate_code_arg_xt.inc}^.Name) + ';');
        OP_ENTER: ;
        // OP_DOT:     WriteLine('  Write(W^); Dec(W);');
        OP_BYE:     WriteLine('  Halt(0);');
        OP_RETURN:  WriteLine('  Exit;');
        OP_WORDS:   Exit(Error('no backend semantics for WORDS'));

        // TODO escape string:
        OP_PRINT_LITERAL_STR:   WriteLine('  Write(''' + SliceToAnsiString({$I pubforth_iterate_code_arg_slice.inc}) + ''');');
        else
          WriteLine('  ' + HexStr({$I pubforth_iterate_code_opcode.inc}, 2));
      {$I pubforth_iterate_code_end.inc}
      WriteLine('end;');
      WriteLine('');
    end;

    It := It^.Next;
  end;

  WriteLine('begin');
  WriteLine('  ' + EscapeIdentifier(Task^.Main^.Name) + ';');
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
