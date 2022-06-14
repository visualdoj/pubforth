unit pubforth_machine;
// Author:  Doj
// License: Public domain or MIT

{$MODE FPC}
{$MODESWITCH DEFAULTPARAMETERS}
{$MODESWITCH OUT}
{$MODESWITCH RESULT}

interface

uses
  dfilereader,
  pubforth_command_line_args,
  pubforth_dictionary;

type
TInputSourceSpecification = record
      // for nesting of parser operationg

  S: PAnsiChar;
  SEnd: PAnsiChar;
end;

TCellInt  = PtrInt;
TCellUInt = PtrUInt;
TCellPtr  = Pointer;
TCell     = Pointer;

PCellInt = ^TCellInt;
PCellPtr = ^TCellPtr;
PCell = ^TCell;

// Standard types on stack
TValueFlag      = TCellInt;   //  flag
TValueChar      = TCellUInt;  //  character
TValueN         = TCellInt;   //  n
TValuePlusN     = TCellUInt;  //  +n
TValueU         = TCellUInt;  //  u
TValueU_or_N    = TCellInt;   //  u|n     (does not matter signed or not)
TValueX         = TCellPtr;   //  x       (unspecified cell)
TValueXT        = TCellPtr;   //  xt      (execution token)
TValueAddr      = TCellPtr;   //  addr
TValueAAddr     = TCellPtr;   //  a-addr  (aligned address)
TValueCAddr     = TCellPtr;   //  c-addr  (character-aligned address)
TValueIOR       = TCellInt;   //  ior     (error result)
TValueD         = array[0 .. 1] of TValueN;       //  d
TValuePlusD     = array[0 .. 1] of TValuePlusN;   //  +d
TValueUD        = array[0 .. 1] of TValueU;       //  ud
TValueD_or_UD   = array[0 .. 1] of TValueU_or_N;  //  d|ud
TValueXD        = array[0 .. 1] of TValueX;       //  xd
TValueColonSys  = TCellPtr; // colon-sys
TValueDoSys     = TCellPtr; // do-sys
TValueCaseSys   = TCellPtr; // case-sys
TValueOfSys     = TCellPtr; // of-sys
TValueOrig      = TCellPtr; // orig
TValueDest      = TCellPtr; // dest
TValueLoopSys   = TCellPtr; // loop-sys
TValueNestSys   = TCellPtr; // nest-sys

PValueFlag      = ^TValueFlag;
PValueChar      = ^TValueChar;
PValueN         = ^TValueN;
PValuePlusN     = ^TValuePlusN;
PValueU         = ^TValueU;
PValueU_or_N    = ^TValueU_or_N;
PValueX         = ^TValueX;
PValueXT        = ^TValueXT;
PValueAddr      = ^TValueAddr;
PValueAAddr     = ^TValueAAddr;
PValueCAddr     = ^TValueCAddr;
PValueIOR       = ^TValueIOR;
PValueD         = ^TValueD;
PValuePlusD     = ^TValuePlusD;
PValueUD        = ^TValueUD;
PValueD_or_UD   = ^TValueD_or_UD;
PValueXD        = ^TValueXD;
PValueColonSys  = ^TValueColonSys;
PValueDoSys     = ^TValueDoSys;
PValueCaseSys   = ^TValueCaseSys;
PValueOfSys     = ^TValueOfSys;
PValueOrig      = ^TValueOrig;
PValueDest      = ^TValueDest;
PValueLoopSys   = ^TValueLoopSys;
PValueNestSys   = ^TValueNestSys;

const
  FLAG_TRUE       = -1;
  FLAG_FASLE      = 0;

type
PMachine = ^TMachine;
TMachine = object
private
  FState: PtrInt;
  FDictionary: TDictionary;

  FBase: PtrInt;
  // FStack: PCell; // S: TODO data stack
  // FControlFlowStack: PCell; // C: TODO
  // FReturnStack: PCell; // R: TODO

  function Error(const ErrorMsg: AnsiString): Boolean;

public
  Bye: Boolean; // for signaling

  procedure Init;
  procedure Done;

  procedure Configurate(Args: PPubForthCLArgs);
      // Should be called after Init.

  function IsInterpreting: Boolean; inline;

  function ParseAnyNum(S, SEnd: PAnsiChar; out Num: TValueN): Boolean; inline;
  function Interpret(S, SEnd: PAnsiChar): Boolean;

  function InterpretREPLInput(const Line: AnsiString): Boolean;
  function InterpretFile(const FileName: AnsiString): Boolean;
end;

function IsGraphicCharacter(C: TValueChar): Boolean; inline;
      //  Minimum set of visible characters.
      //  Other graphic characters are implementation-detail.




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

function IsGraphicCharacter(C: TValueChar): Boolean; inline;
begin
  Exit(C in [32..126]);
end;

function TMachine.Error(const ErrorMsg: AnsiString): Boolean;
begin
  Writeln(stderr, ErrorMsg);
  Exit(False);
end;

procedure TMachine.Init;
begin
  Bye := False;
  FState := 0;
  FBase := 10;

  FDictionary.Init;

  FDictionary.CreateDifinition(':');
  FDictionary.CreateDifinition(';');
  FDictionary.CreateDifinition('.');
end;

procedure TMachine.Done;
begin
  FDictionary.Done;
end;

{$PUSH} {$warn 5024 off} // <- Hint: (5024) Parameter "P" not used
procedure UNUSED(const P: Pointer); inline;
begin
end;
{$POP}

procedure TMachine.Configurate(Args: PPubForthCLArgs);
begin
  UNUSED(Args);
end;

function TMachine.IsInterpreting: Boolean; inline;
begin
  Exit(FState = 0);
end;

function SkipSpaces(S, SEnd: PAnsiChar): PAnsiChar; inline;
begin
  while (S < SEnd) and (S^ = ' ') do
    Inc(S);

  Exit(S);
end;

function SkipName(S, SEnd: PAnsiChar): PAnsiChar; inline;
begin
  while (S < SEnd) and not (S^ = ' ') do
    Inc(S);

  Exit(S);
end;

function ParseBaseNumber(S, SEnd: PAnsiChar; Base: Int32; out Value: TValueN): Boolean; inline;
begin
  UNUSED(@S);
  UNUSED(@SEnd);
  UNUSED(@Base);
  UNUSED(@Value);
  Writeln('TODO ParseBaseNumber');
  Exit(False);
end;

function ParseDecimalNumber(S, SEnd: PAnsiChar; out Value: TValueN): Boolean; inline;
begin
  UNUSED(@S);
  UNUSED(@SEnd);
  UNUSED(@Value);
  Writeln('TODO ParseDecimalNumber');
  Exit(False);
end;

function ParseHexNumber(S, SEnd: PAnsiChar; out Value: TValueN): Boolean; inline;
begin
  UNUSED(@S);
  UNUSED(@SEnd);
  UNUSED(@Value);
  Writeln('TODO ParseHexNumber');
  Exit(False);
end;

function ParseBinNumber(S, SEnd: PAnsiChar; out Value: TValueN): Boolean; inline;
begin
  UNUSED(@S);
  UNUSED(@SEnd);
  UNUSED(@Value);
  Writeln('TODO ParseBinNumber');
  Exit(False);
end;

function ParseCNumber(S, SEnd: PAnsiChar; out Value: TValueN): Boolean; inline;
begin
  if ((SEnd - S) = 3) and (S[0] = '''') and (S[2] = '''') then begin
    Value := Ord(S[1]);
    Exit(True);
  end;

  Exit(False);
end;

//function TryParseNumber(S, SEnd: PAnsiChar; out Value: TValueN): Boolean; inline;
//begin
//  Result := S < SEnd;
//
//  //case S^ of
//  //'-': Exit(ParseBaseNumber(S, SEnd);
//end;

function ToPrintableString(S, SEnd: PAnsiChar): AnsiString;
begin
  Result := '';
  while S < SEnd do begin
    if IsGraphicCharacter(Ord(S^)) then begin
      Result := Result + S^;
    end else
      Result := Result + '$' + HexStr(Ord(S^), 2);
    Inc(S);
  end;
end;

function EqualsString(S, SEnd: PAnsiChar; const ConstString: AnsiString): Boolean; inline;
begin
  Exit((Length(ConstString) = SEnd - S) and (CompareByte(S^, ConstString[1], SEnd - S) = 0));
end;

function TMachine.ParseAnyNum(S, SEnd: PAnsiChar; out Num: TValueN): Boolean;
begin
  if S >= SEnd then
    Exit(False);

  case S^ of
  '#':  Exit(ParseDecimalNumber(S + 1, SEnd, Num)); // <decnum>
  '$':  Exit(ParseHexNumber(S + 1, SEnd, Num));     // <hexnum>
  '%':  Exit(ParseBinNumber(S + 1, SEnd, Num));     // <binnum>
  '''': if (SEnd - S = 3) and (S[2] = '''') then begin  // <cnum>
          Num := Ord(S[1]);
          Exit(True);
        end;
  else
    Exit(ParseBaseNumber(S, SEnd, FBase, Num)); // <BASEnum>
  end;

  Exit(False); // make compiler happy
end;

function TMachine.Interpret(S, SEnd: PAnsiChar): Boolean;
var
  NameEnd: PAnsiChar;
  Definition: PDictionaryRecord;
  Number: TValueN;
begin
  S := SkipSpaces(S, SEnd);
  while S < SEnd do begin
    NameEnd := SkipName(S, SEnd);

    if FDictionary.Find(S, NameEnd, Definition) then begin
      if IsInterpreting then begin
        Writeln(stderr, 'INTERPRETATION ', Definition^.Name);
      end else begin
        Writeln(stderr, 'COMPILE ', Definition^.Name);
      end;
    end else begin
      if ParseAnyNum(S, NameEnd, Number) then begin
        if IsInterpreting then begin
          Writeln(stderr, 'PUSH ', Number);
        end else begin
          Writeln(stderr, 'LITERAL ', Number);
        end;
      end else if EqualsString(S, NameEnd, 'BYE') then begin
        Bye := True;
      end else begin
        Exit(Error('unrecognized word ' + ToPrintableString(S, NameEnd)));
      end;
    end;

    S := SkipSpaces(NameEnd, SEnd);
  end;

  Exit(True);
end;

function TMachine.InterpretREPLInput(const Line: AnsiString): Boolean;
begin
  Exit(Interpret(@Line[1], @Line[1] + Length(Line)));
end;

function TMachine.InterpretFile(const FileName: AnsiString): Boolean;
var
  Content: PAnsiChar;
  ContentLen: SizeUInt;
begin
  if not ReadFileContent(FileName, 0, Content, ContentLen) then
    Exit(Error('could not read ' + FileName));

  Result := Interpret(Content, Content + ContentLen);

  FreeMem(Content);
end;

end.
