unit pubforth_backend_dump;
// Author:  Doj
// License: Public domain or MIT

//
//  A dumper of Dembro code in human-readable form.
//  Cannot be used for producing executables.
//

{$MODE FPC}
{$MODESWITCH DEFAULTPARAMETERS}
{$MODESWITCH OUT}
{$MODESWITCH RESULT}

interface

uses
  pubforth_core,
  pubforth_machine,
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
TBackendDump = object(TBackend)
public
  constructor Init;
  destructor Done; virtual;

  function  Translate(Task: PTranslationTask): Boolean; virtual;
end;

var
  BackendDump: TBackendDump;

constructor TBackendDump.Init;
begin
  inherited Init;
end;

destructor TBackendDump.Done;
begin
  inherited Done;
end;

function  TBackendDump.Translate(Task: PTranslationTask): Boolean;
var
  {$I pubforth_iterate_code_variables.inc};
  Dictionary: PDictionary;
  I: Int32;
  It, Definition: PDictionaryRecord;
begin
  OpenTextFile(Task^.OutputFileName);

  Dictionary := Task^.Dictionary;
  for I := 0 to 255 do begin
    if Dictionary^.ReachableOpcodes[I] then
      WriteLine('OPCODE ' + IntToStr(I));
  end;

  // Colon definitions
  It := Dictionary^.Last;
  while It <> nil do begin
    if It^.IsReachable and It^.IsColonDefinition then begin
      WriteLine('COLON ' + It^.Name);
      Definition := It;
      {$I pubforth_iterate_code_begin.inc}
        OP_NOP:     WriteLine('  NOP');
        OP_END:     WriteLine('  END');
        OP_LITERAL: WriteLine('  LITERAL' + IntToStr({$I pubforth_iterate_code_arg_n.inc}));
        OP_CR:      WriteLine('  CR');
        OP_CALL:    WriteLine('  CALL ' + {$I pubforth_iterate_code_arg_xt.inc}^.Name);
        OP_ENTER:   WriteLine('  ENTER');
        OP_DOT:     WriteLine('  .');
        OP_BYE:     WriteLine('  BYE');
        OP_RETURN:  WriteLine('  RETURN');
        OP_WORDS:   WriteLine('  WORDS');
        OP_PRINT_LITERAL_STR:   WriteLine('  ." ' + SliceToAnsiString({$I pubforth_iterate_code_arg_slice.inc}));
        else
          WriteLine('  ' + HexStr({$I pubforth_iterate_code_opcode.inc}, 2));
      {$I pubforth_iterate_code_end.inc}
    end;

    It := It^.Next;
  end;

  CloseTextFile;
  Exit(True);
end;

initialization
  BackendDump.Init;
  RegisterBackend('dump', @BackendDump, '.dump');
finalization
  BackendDump.Done;
end.
