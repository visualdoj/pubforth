unit pubforth_machine;
// Author:  Doj
// License: Public domain or MIT

{$MODE FPC}
{$MODESWITCH ADVANCEDRECORDS}
{$MODESWITCH DEFAULTPARAMETERS}
{$MODESWITCH OUT}
{$MODESWITCH RESULT}

interface

uses
  dterm,
  dfilereader,
  pubforth_core,
  pubforth_command_line_args,
  pubforth_strings,
  pubforth_words;

const
  STACK_DIRECTION_UP = False;

{$MACRO ON}
{$IF STACK_DIRECTION_UP}
  {$DEFINE WGrow := Inc}
  {$DEFINE WDrop := Dec}
  {$DEFINE WDir  := 1}
{$ELSE}
  {$DEFINE WGrow := Dec}
  {$DEFINE WDrop := Inc}
  {$DEFINE WDir  := -1}
{$ENDIF}

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

TValueFileID    = TValueN;

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
  FLAG_TRUE           = -1;
  FLAG_FASLE          = 0;
  STATE_INTERPRETING  = 0;
  STATE_COMPILE       = -1;

  DEFINITION_PROCESSED    = 1 shl 0;
  DEFINITION_REACHABLE    = 1 shl 1;
  DEFINITION_COLON        = 1 shl 2;

type
PDictionary = ^TDictionary;
PDictionaryRecord = ^TDictionaryRecord;
PMachine = ^TMachine;

TSemantic = function (Machine: PMachine; Param: Pointer): Boolean;

TDictionaryRecord = object
  Name: AnsiString;
  Next: PDictionaryRecord;
  Semantic: TSemantic;
  Immediate: Boolean;
  Opcode: Int32;
  Code: PUInt8;
  Flags: UInt8;
  Source: AnsiString;
  SourceIndex: UInt16; // beginning of the definition
  SourceOffset: UInt16; // offset of the beginning of the definition in the source

  function IsReachable: Boolean; inline;
  function IsColonDefinition: Boolean; inline;
end;

TDictionary = object
private
  FLast: PDictionaryRecord;
  FCurrentDefinition: PDictionaryRecord;

public
  ReachableOpcodes: array[0 .. 255] of Boolean;

  procedure Init;
  procedure Done;

  procedure LoadDefaultWords;

  function CreateDifinition(const Name: AnsiString): PDictionaryRecord;
  function CreateDifinition(Name, NameEnd: PAnsiChar): PDictionaryRecord;

  function Find(const Name: AnsiString; out Rec: PDictionaryRecord): Boolean;
  function Find(Name, NameEnd: PAnsiChar; out Rec: PDictionaryRecord): Boolean;
      // Returns False if not found

  procedure ClearReachable;
      // Clears DEFINITION_PROCESSED and DEFINITION_REACHABLE flags
      // for all definitions.

  procedure MarkReachable(Definition: PDictionaryRecord);
      // Marks all reachable definitions from the Definition with flag
      // DEFINITION_REACHABLE

  property Last: PDictionaryRecord read FLast;
end;

TMachine = object
private
  FState: TValueN;
  FDictionary: TDictionary;

  // Current input source
  FSourceBegin: PAnsiChar;
  FSource: PAnsiChar;     // <- cursor
  FSourceEnd: PAnsiChar;

  FSources: array of AnsiString;
  FSourceIndex: Int32; // current source index
  FSourceID: TValueN; // for SOURCE-ID

  FBase: PtrInt;

  // Stack
  FStackArray: array of TCell;
  FStackBegin: PCell;
  FStack: PCell; // <- cursor
  FStackEnd: PCell;

  // FControlFlowStack: PCell; // C: TODO
  // FReturnStack: PCell; // R: TODO

  FCodeArray: array of UInt8;
  FCodeBegin: PUInt8;
  FCode: PUInt8; // <- cursor
  FCodeEnd: PUInt8;

  // Tests
  FTestStartStack: PCell;
  FTestStartDepth: Int32;
  FTestActualDepth: Int32;
  FTestResults: array of TCell;
  FTestSource: PAnsiChar;

  function  Error(const ErrorMsg: AnsiString): Boolean;
  procedure Hint(const HintMsg: AnsiString);

public
  Bye: Boolean; // for signaling

  procedure Init;
  procedure Done;

  procedure RegIntrinsic(const Name: AnsiString; F: TSemantic; Opcode: Int32);
  procedure RegImmediate(const Name: AnsiString; F: TSemantic);

  procedure Configurate(Args: PPubForthCLArgs);
      // Should be called after Init.

  procedure ConfigureTest;
  procedure ConfigureExperimental;
  procedure ConfigureREPL;

  function  StackDepth: Int32; inline;

  procedure Compile(Opcode: UInt8);
  procedure CompileN(N: TValueN);
  procedure CompileCall(Xt: PDictionaryRecord);
  procedure CompileLiteral(Number: TValueN);
  procedure CompileLiteralStr(OpCode: UInt8; S, SEnd: PAnsiChar);

  function IsInterpreting: Boolean; inline;

  function GetDictionary: PDictionary;

  function ParseAnyNum(S, SEnd: PAnsiChar; out Num: TValueN): Boolean; inline;
      // <anynum>   :=  { <BASEnum> | <decnum> | <hexnum> | <binnum> | <cnum> }
      // <BASEnum>  :=  [-]<bdigit><bdigit>*
      // <decnum>   :=  #[-]<decdigit><decdigit>*
      // <hexnum>   :=  $[-]<hexdigit><hexdigit>*
      // <binnum>   :=  %[-]<bindigit><bindigit>*
      // <cnum>     :=  '<char>'
      // <bindigit> :=  { 0 | 1 }
      // <decdigit> :=  { 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 }
      // <hexdigit> :=  { <decdigit> | a | b | c | d | e | f | A | B | C | D | E | F }

  procedure AddSource(const S: AnsiString; ID: TValueFileID);
  function InterpretLoop(S: PAnsiChar = nil; SEnd: PAnsiChar = nil): Boolean;

  function InterpretREPLInput(const Line: AnsiString): Boolean;
  function InterpretString(const S: AnsiString): Boolean;
  function InterpretFile(const FileName: AnsiString): Boolean;

  function UnrecognizedWord(S, SEnd: PAnsiChar): Boolean;
end;

function IsGraphicCharacter(C: TValueChar): Boolean; inline;
      //  Minimum set of visible characters.
      //  Other graphic characters are implementation-detail.

function SliceToAnsiString(S, SEnd: PAnsiChar): AnsiString;



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

function SliceToAnsiString(S, SEnd: PAnsiChar): AnsiString;
begin
  SetLength(Result, SEnd - S);
  Move(S^, Result[1], SEnd - S);
end;

function RunVM(Code: PUInt8; Machine: PMachine): Boolean;
var
  Len: TValueN;
  Definition: PDictionaryRecord;
begin
  while True do begin
    case Code^ of
    OP_NOP: ;
    OP_LITERAL: begin
                  WGrow(Machine^.FStack);
                  Machine^.FStack^ := Pointer(Pointer(Code + 1)^);
                  Inc(Code, 1 + SizeOf(TValueN));
                  continue;
                end;
    OP_CR: Writeln;
    OP_CALL: begin
               Definition := PDictionaryRecord(Pointer(Code + 1)^);
               if Machine^.IsInterpreting then begin
                 if @Definition^.Semantic <> nil then begin
                   if not Definition^.Semantic(Machine, Definition^.Code) then
                     Exit(False);
                 end else
                   Writeln(stderr, 'ERROR no semantic for ', Definition^.Name);
               end else begin
                 if Definition^.Immediate then begin
                   if @Definition^.Semantic <> nil then begin
                     if not Definition^.Semantic(Machine, Definition^.Code) then
                       Exit(False);
                   end else
                     Writeln(stderr, 'ERROR no semantic for ', Definition^.Name);
                 end else begin
                   if Definition^.Opcode >= 0 then begin
                     Machine^.Compile(Definition^.Opcode);
                   end else begin
                     Machine^.CompileCall(Definition);
                   end;
                 end;
               end;

               Inc(Code, 1 + SizeOf(PDictionaryRecord));
               continue;
             end;
    OP_ENTER: Exit(Machine^.Error('OP_ENTER is not ready'));
    OP_DOT: begin
              Write(TValueN(Machine^.FStack^), ' ');
              WDrop(Machine^.FStack);
            end;
    OP_BYE: begin
              Machine^.Bye := True;
              Exit(True);
            end;
    OP_RETURN: Exit(True);
    OP_PRINT_LITERAL_STR: begin
              Len := TValueN(Pointer(Code + 1)^);
              Inc(Code, 1 + SizeOf(TValueN));
              Write(SliceToAnsiString(PAnsiChar(Code), PAnsiChar(Code + Len)));
              Inc(Code, Len);
              continue;
            end;
    else
      Exit(Machine^.Error('unknown opcode ' + HexStr(Code^, 2)));
    end;
    Inc(Code);
  end;

  Exit(False); // must be unreachable
end;

function IsGraphicCharacter(C: TValueChar): Boolean; inline;
begin
  Exit(C in [32..126]);
end;

function f_ColonDefinition(Machine: PMachine; Param: Pointer): Boolean;
begin
  Exit(RunVM(Param, Machine));
end;

function TDictionaryRecord.IsReachable: Boolean; inline;
begin
  Exit(Flags and DEFINITION_REACHABLE <> 0);
end;

function TDictionaryRecord.IsColonDefinition: Boolean; inline;
begin
  Exit(Flags and DEFINITION_COLON <> 0);
end;

procedure TDictionary.Init;
begin
  FLast := nil;
end;

procedure TDictionary.Done;
begin
end;

procedure TDictionary.LoadDefaultWords;
begin
end;

function TDictionary.CreateDifinition(const Name: AnsiString): PDictionaryRecord;
begin
  New(Result);
  Result^.Name := Name;
  Result^.Next := FLast;
  Result^.Semantic := nil;
  Result^.Immediate := False;
  Result^.Opcode := -1;
  Result^.Code := nil;
  Result^.Source := '';
  Result^.SourceIndex := High(UInt16);
  Result^.SourceOffset := 0;
  FLast := Result;
  FCurrentDefinition := Result;
end;

function TDictionary.CreateDifinition(Name, NameEnd: PAnsiChar): PDictionaryRecord;
begin
  Result := CreateDifinition('');
  SetLength(Result^.Name, NameEnd - Name);
  Move(Name^, Result^.Name[1], NameEnd - Name);
  FLast := Result;
end;

function TDictionary.Find(const Name: AnsiString; out Rec: PDictionaryRecord): Boolean;
var
  It: PDictionaryRecord;
begin
  It := FLast;
  while It <> nil do begin
    if Name = It^.Name then begin
      Rec := It;
      Exit(True);
    end;

    It := It^.Next;
  end;

  Exit(False);
end;

function TDictionary.Find(Name, NameEnd: PAnsiChar; out Rec: PDictionaryRecord): Boolean;
var
  It: PDictionaryRecord;
begin
  It := FLast;
  while It <> nil do begin
    if (Length(It^.Name) = NameEnd - Name) and EqualsCaseInsensitive(Name, NameEnd, PAnsiChar(It^.Name)) then begin
      Rec := It;
      Exit(True);
    end;

    It := It^.Next;
  end;

  Exit(False);
end;

procedure TDictionary.ClearReachable;
var
  It: PDictionaryRecord;
  I: Int32;
begin
  It := FLast;
  while It <> nil do begin
    It^.Flags := It^.Flags and not UInt8(DEFINITION_PROCESSED or DEFINITION_REACHABLE);
    It := It^.Next;
  end;

  for I := 0 to High(ReachableOpcodes) do
    ReachableOpcodes[I] := False;
end;

procedure TDictionary.MarkReachable(Definition: PDictionaryRecord);
var
  {$I pubforth_iterate_code_variables.inc};
begin
  if Definition^.Flags and DEFINITION_PROCESSED <> 0 then
    Exit;

  Definition^.Flags := Definition^.Flags or DEFINITION_PROCESSED or DEFINITION_REACHABLE;
  if Definition^.Semantic = @f_ColonDefinition then begin
    {$I pubforth_iterate_code_begin.inc}
      OP_CALL: MarkReachable({$I pubforth_iterate_code_arg_xt.inc});
      else
        ReachableOpcodes[{$I pubforth_iterate_code_opcode.inc}] := True;
    {$I pubforth_iterate_code_end.inc}
  end;
end;

function TMachine.Error(const ErrorMsg: AnsiString): Boolean;
begin
  SetTerminalColor(TERMINAL_COLOR_BRIGHT_RED);
  Writeln(stderr, 'Error: ' + ErrorMsg);
  SetTerminalColor(TERMINAL_COLOR_DEFAULT);
  Exit(False);
end;

procedure TMachine.Hint(const HintMsg: AnsiString);
begin
  SetTerminalColor(TERMINAL_COLOR_BRIGHT_BLUE);
  Writeln(stderr, 'Hint: ' + HintMsg);
  SetTerminalColor(TERMINAL_COLOR_DEFAULT);
end;

function f_CR(Machine: PMachine; Param: Pointer): Boolean;
begin
  Writeln;
  Exit(True);
end;

function SkipSpaces(S, SEnd: PAnsiChar): PAnsiChar; inline;
begin
  while (S < SEnd) and (S^ in [' ', #13, #10, #9]) do
    Inc(S);

  Exit(S);
end;

function SkipName(S, SEnd: PAnsiChar): PAnsiChar; inline;
begin
  while (S < SEnd) and not (S^ in [' ', #13, #10, #9]) do
    Inc(S);

  Exit(S);
end;

function SkipToDoubleQuote(S, SEnd: PAnsiChar): PAnsiChar; inline;
begin
  while (S < SEnd) and (S^ <> '"') do
    Inc(S);

  Exit(S);
end;

function f_Colon(Machine: PMachine; Param: Pointer): Boolean;
var
  NameEnd: PAnsiChar;
  Rec: PDictionaryRecord;
  SourceOffset: Int16;
begin
  Machine^.FSource := SkipSpaces(Machine^.FSource, Machine^.FSourceEnd);
  SourceOffset := Machine^.FSource - Machine^.FSourceBegin;

  NameEnd := SkipName(Machine^.FSource, Machine^.FSourceEnd);
  if Machine^.FSource >= NameEnd then
    Exit(Machine^.Error('name expected after :'));

  Rec := Machine^.FDictionary.CreateDifinition(Machine^.FSource, NameEnd);
  Rec^.Semantic := @f_ColonDefinition;
  Rec^.Code := Machine^.FCode;
  Rec^.Flags := DEFINITION_COLON;
  Rec^.SourceIndex := Machine^.FSourceIndex;
  Rec^.SourceOffset := SourceOffset;

  Machine^.FSource := NameEnd + 1;
  Machine^.FState := STATE_COMPILE;
  Exit(True);
end;

function f_Semicolon(Machine: PMachine; Param: Pointer): Boolean;
var
  Rec: PDictionaryRecord;
  I: Int32;
begin
  if Machine^.IsInterpreting then
    Exit(Machine^.Error('no interpreatation semantic for ;'));

  Machine^.Compile(OP_RETURN);
  Machine^.Compile(OP_END);

  Rec := Machine^.FDictionary.FCurrentDefinition;
  if Rec^.SourceIndex = Machine^.FSourceIndex then begin
    Rec^.Source := ': ' + SliceToAnsiString(@Machine^.FSources[Machine^.FSourceIndex][Rec^.SourceOffset + 1],
                                            Machine^.FSource);
  end else begin
    Rec^.Source := ': ' + SliceToAnsiString(@Machine^.FSources[Rec^.SourceIndex][Rec^.SourceOffset + 1],
                                            @Machine^.FSources[Rec^.SourceIndex][Length(Machine^.FSources[Rec^.SourceIndex])]);
    for I := Rec^.SourceIndex + 1 to Machine^.FSourceIndex - 1 do begin
      Rec^.Source := Rec^.Source + ' ' + Machine^.FSources[I];
    end;
    Rec^.Source := Rec^.Source + ' ' + SliceToAnsiString(Machine^.FSourceBegin, Machine^.FSource);
  end;

  Machine^.FState := STATE_INTERPRETING;
  Exit(True);
end;

function f_Dot(Machine: PMachine; Param: Pointer): Boolean;
begin
  Write(TValueN(Machine^.FStack^), ' ');
  WDrop(Machine^.FStack);
  Exit(True);
end;

function f_Words(Machine: PMachine; Param: Pointer): Boolean;
var
  Rec: PDictionaryRecord;
begin
  Rec := Machine^.FDictionary.FLast;
  while Rec <> nil do begin
    // TODO do we print names of unfinished words?
    Writeln(Rec^.Name);
    Rec := Rec^.Next;
  end;
  Exit(True);
end;

function f_See(Machine: PMachine; Param: Pointer): Boolean;
var
  Rec: PDictionaryRecord;
  NameEnd: PAnsiChar;
begin
  NameEnd := SkipName(Machine^.FSource, Machine^.FSourceEnd);
  if Machine^.FDictionary.Find(Machine^.FSource, NameEnd, Rec) then begin
    Machine^.FSource := NameEnd;
    if Rec^.IsColonDefinition then begin
      Writeln(Rec^.Source);
    end else begin
      Writeln('Built-in opcode ', Rec^.Opcode);
    end;
    Exit(True);
  end else begin
    // TODO check for experimental support
    Machine^.UnrecognizedWord(Machine^.FSource, NameEnd);
    Machine^.FSource := NameEnd;
    Exit(False);
  end;
end;

function f_DotS(Machine: PMachine; Param: Pointer): Boolean;
var
  Cell, CellEnd: PCell;
begin
{$IF STACK_DIRECTION_UP}
  Cell := Machine^.FStackBegin + 1;
  CellEnd := Machine^.FStack;
  while Cell <= CellEnd do begin
    Write(TValueN(Cell^), ' ');
    Inc(Cell);
  end;
{$ELSE}
  Cell := Machine^.FStackEnd - 1;
  CellEnd := Machine^.FStack;
  while Cell >= CellEnd do begin
    Write(TValueN(Cell^), ' ');
    Dec(Cell);
  end;
{$ENDIF}
  Exit(True);
end;

function f_Question(Machine: PMachine; Param: Pointer): Boolean;
begin
  Write(TValueN(Pointer(Machine^.FStack^)^), ' ');
  WDrop(Machine^.FStack);
  Exit(True);
end;

function f_State(Machine: PMachine; Param: Pointer): Boolean;
begin
  // TODO garantee read-only
  WGrow(Machine^.FStack);
  Machine^.FStack^ := @Machine^.FState;
  Exit(True);
end;

function f_SourceID(Machine: PMachine; Param: Pointer): Boolean;
begin
  WGrow(Machine^.FStack);
  TValueN(PtrUInt(Machine^.FStack^)) := Machine^.FSourceID;
  Exit(True);
end;

function f_PrintLiteralStr(Machine: PMachine; Param: Pointer): Boolean;
var
  LiteralStrEnd: PAnsiChar;
begin
  LiteralStrEnd := SkipToDoubleQuote(Machine^.FSource, Machine^.FSourceEnd);
  // TODO check for source end?

  if Machine^.IsInterpreting then begin
    Write(SliceToAnsiString(Machine^.FSource, LiteralStrEnd));
  end else begin
    Machine^.CompileLiteralStr(OP_PRINT_LITERAL_STR, Machine^.FSource, LiteralStrEnd);
  end;

  if LiteralStrEnd >= Machine^.FSourceEnd then begin
    Machine^.FSource := Machine^.FSourceEnd;
  end else
    Machine^.FSource := LiteralStrEnd + 1;

  Exit(True);
end;

function f_BYE(Machine: PMachine; Param: Pointer): Boolean;
begin
  Machine^.Bye := True;
  Exit(True);
end;

function SkipLine(S, SEnd: PAnsiChar): PAnsiChar;
begin
  while S < SEnd do begin
    if S^ = #10 then begin
      Exit(S + 1);
    end else if S^ = #13 then begin
      Inc(S);
      if (S < SEnd) and (S^ = #10) then
        Exit(S + 1);
      Exit(S);
    end;
    Inc(S);
  end;

  Exit(SEnd);
end;

function f_SingleLineComment(Machine: PMachine; Param: Pointer): Boolean;
begin
  Machine^.FSource := SkipLine(Machine^.FSource, Machine^.FSourceEnd);
  Exit(True);
end;

function f_BeginTest(Machine: PMachine; Param: Pointer): Boolean;
begin
  Machine^.FTestStartStack  := Machine^.FStack;
  Machine^.FTestStartDepth  := Machine^.StackDepth;
  Machine^.FTestActualDepth := Machine^.StackDepth;
  Machine^.FTestSource := Machine^.FSource;
  SetLength(Machine^.FTestResults, 0);
  Exit(True);
end;

function f_TestCheckpoint(Machine: PMachine; Param: Pointer): Boolean;
var
  I: Int32;
begin
  Machine^.FTestActualDepth := Machine^.StackDepth;
  if Machine^.FTestActualDepth > Machine^.FTestStartDepth then begin
    SetLength(Machine^.FTestResults, Machine^.FTestActualDepth - Machine^.FTestStartDepth);
    for I := 0 to Machine^.FTestActualDepth - Machine^.FTestStartDepth do begin
      Machine^.FTestResults[I] := (Machine^.FStack + WDir * I)^;
    end;
  end;
  Machine^.FStack := Machine^.FTestStartStack;
  Exit(True);
end;

function f_EndTest(Machine: PMachine; Param: Pointer): Boolean;
var
  I: Int32;
begin
  // TODO vectorize Error handling
  // TODO allow not fail at first error

  if Machine^.FTestActualDepth <> Machine^.StackDepth then
    Exit(Machine^.Error('WRONG NUMBER OF RESULTS: T{ ' + SliceToAnsiString(Machine^.FTestSource, Machine^.FSource)));

  if Machine^.FTestActualDepth > Machine^.FTestStartDepth then begin
    for I := 0 to High(Machine^.FTestResults) do begin
      if Machine^.FTestResults[I] <> (Machine^.FStack + WDir * I)^ then
        Exit(Machine^.Error('INCORRECT RESULT: T{ ' + SliceToAnsiString(Machine^.FTestSource, Machine^.FSource)));
    end;
  end;

  Exit(True);
end;

function SkipToCloseRoundBracketOrEOS(S, SEnd: PAnsiChar): PAnsiChar;
begin
  while S < SEnd do begin
    if S^ = ')' then
      Exit(S + 1);
    Inc(S);
  end;

  Exit(SEnd);
end;

function f_MultiLineComment(Machine: PMachine; Param: Pointer): Boolean;
begin
  Machine^.FSource := SkipToCloseRoundBracketOrEOS(Machine^.FSource, Machine^.FSourceEnd);
  Exit(True);
end;

procedure TMachine.Init;
begin
  Bye := False;
  FState := 0;
  FBase := 10;

  // TODO be more adaptive: allow dynamic stack size
  SetLength(FStackArray, 4 * 1024);
  FStackBegin := @FStackArray[0];
  FStackEnd := FStackBegin + Length(FStackArray);
  {$IF STACK_DIRECTION_UP}
    FStack := FStackBegin; // TODO some padding for little safety
  {$ELSE}
    FStack := FStackEnd; // TODO some padding for little safety
  {$ENDIF}

  FSourceIndex := -1;
  FSourceID := -1;

  // TODO be more adaptive: allow expanding code size
  SetLength(FCodeArray, 4 * 1024);
  FCodeBegin := @FCodeArray[0];
  FCode := FCodeBegin;
  FCodeEnd := FCodeBegin + Length(FCodeArray);

  FDictionary.Init;
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

procedure TMachine.RegIntrinsic(const Name: AnsiString; F: TSemantic; Opcode: Int32);
var
  Rec: PDictionaryRecord;
begin
  Rec := FDictionary.CreateDifinition(Name);
  Rec^.Semantic := F;
  Rec^.Opcode := Opcode;
end;

procedure TMachine.RegImmediate(const Name: AnsiString; F: TSemantic);
var
  Rec: PDictionaryRecord;
begin
  Rec := FDictionary.CreateDifinition(Name);
  Rec^.Semantic := F;
  Rec^.Immediate := True;
end;

procedure TMachine.Configurate(Args: PPubForthCLArgs);
begin
  UNUSED(Args);

  RegIntrinsic('BYE',     @f_BYE, OP_BYE);
  RegImmediate('\',       @f_SingleLineComment);
  RegImmediate('(',       @f_MultiLineComment);
  RegIntrinsic(':',       @f_Colon, OP_ENTER);
  RegImmediate(';',       @f_Semicolon);
  RegIntrinsic('CR',      @f_CR, OP_CR);
  RegImmediate('."',      @f_PrintLiteralStr);
end;

procedure TMachine.ConfigureTest;
begin
  RegIntrinsic('T{',      @f_BeginTest, -1);
  RegIntrinsic('}T',      @f_EndTest, -1);
  RegIntrinsic('->',      @f_TestCheckpoint, -1);
end;

procedure TMachine.ConfigureExperimental;
begin
  RegIntrinsic('.',         @f_Dot, OP_DOT);
  RegIntrinsic('WORDS',     @f_Words, OP_WORDS);
  RegIntrinsic('SEE',       @f_See, OP_SEE);
  RegIntrinsic('.S',        @f_DotS, OP_DOT_S);
  RegIntrinsic('?',         @f_Question, OP_QUESTION);
  RegIntrinsic('STATE',     @f_State, OP_STATE);
  RegIntrinsic('SOURCE-ID', @f_SourceID, OP_SOURCE_ID);
end;

procedure TMachine.ConfigureREPL;
begin
end;

function  TMachine.StackDepth: Int32; inline;
begin
  {$IF STACK_DIRECTION_UP}
    Exit(FStack - FStackBegin);
  {$ELSE}
    Exit(FStackBegin - FStack);
  {$ENDIF}
end;

procedure TMachine.Compile(Opcode: UInt8);
begin
  FCode^ := Opcode;
  Inc(FCode);
end;

procedure TMachine.CompileN(N: TValueN);
begin
  Move(N, Pointer(FCode)^, SizeOf(TValueN));
  Inc(FCode, SizeOf(TValueN));
end;

procedure TMachine.CompileCall(Xt: PDictionaryRecord);
begin
  Compile(OP_CALL);
  Move(Xt, Pointer(FCode)^, SizeOf(PDictionaryRecord));
  Inc(FCode, SizeOf(PDictionaryRecord));
end;

procedure TMachine.CompileLiteral(Number: TValueN);
begin
  Compile(OP_LITERAL);
  Move(Number, Pointer(FCode)^, SizeOf(TValueN));
  Inc(FCode, SizeOf(TValueN));
end;

procedure TMachine.CompileLiteralStr(OpCode: UInt8; S, SEnd: PAnsiChar);
begin
  Compile(OpCode);
  CompileN(SEnd - S);
  Move(S^, Pointer(FCode)^, SEnd - S);
  Inc(FCode, SEnd - S); // TODO alignment
end;

function TMachine.IsInterpreting: Boolean; inline;
begin
  Exit(FState = 0);
end;

function TMachine.GetDictionary: PDictionary;
begin
  Exit(@FDictionary);
end;

function DigitToNumber(C: AnsiChar): Int32;
begin
  if C in ['0'..'9'] then begin
    Exit(Ord(C) - Ord('0'));
  end else if C in ['a'..'z'] then begin
    Exit(Ord(C) - Ord('a'));
  end else if C in ['A'..'Z'] then begin
    Exit(Ord(C) - Ord('A'));
  end else
    Exit(0);
end;

function ParseBaseNumber(S, SEnd: PAnsiChar; Base: Int32; out Value: TValueN): Boolean; inline;
label
  LSuccess;
var
  MinusSign: Boolean;
  D: Int32;
begin
  if S >= SEnd then
    Exit(False);

  if S^ = '-' then begin
    MinusSign := True;
    Inc(S);
    if S >= SEnd then
      Exit(False);
  end else
    MinusSign := False;

  if DigitToNumber(S^) >= Base then
    Exit(False);

  Value := 0;
  while S < SEnd do begin
    if S^ in [' ', #9, #10, #13] then
      goto LSuccess;

    D := DigitToNumber(S^);
    if D >= Base then
      Exit(False);

    Value := Value * Base + D;

    Inc(S);
  end;

LSuccess:
  if MinusSign then
    Value := - Value;

  Exit(True);
end;

function ParseDecimalNumber(S, SEnd: PAnsiChar; out Value: TValueN): Boolean; inline;
label
  LSuccess;
var
  MinusSign: Boolean;
begin
  if S >= SEnd then
    Exit(False);

  if S^ = '-' then begin
    MinusSign := True;
    Inc(S);
    if S >= SEnd then
      Exit(False);
  end else
    MinusSign := False;

  if not (S^ in ['0'..'9']) then
    Exit(False);

  Value := 0;
  while S < SEnd do begin
    if S^ in [' ', #9, #10, #13] then
      goto LSuccess;

    if not (S^ in ['0'..'9']) then
      Exit(False);

    Value := Value * 10 + Ord(S^) - Ord('0');

    Inc(S);
  end;

LSuccess:
  if MinusSign then
    Value := - Value;

  Exit(True);
end;

function ParseHexNumber(S, SEnd: PAnsiChar; out Value: TValueN): Boolean; inline;
label
  LSuccess;
var
  MinusSign: Boolean;
begin
  if S >= SEnd then
    Exit(False);

  if S^ = '-' then begin
    MinusSign := True;
    Inc(S);
    if S >= SEnd then
      Exit(False);
  end else
    MinusSign := False;

  if not (S^ in ['0'..'9', 'a'..'f', 'A'..'F']) then
    Exit(False);

  Value := 0;
  while S < SEnd do begin
    if S^ in [' ', #9, #10, #13] then
      goto LSuccess;

    if not (S^ in ['0'..'9', 'a'..'z', 'A'..'Z']) then
      Exit(False);

    if S^ in ['0'..'9'] then begin
      Value := Value * 16 + Ord(S^) - Ord('0');
    end else if S^ in ['a'..'f'] then begin
      Value := Value * 16 + Ord(S^) - Ord('a') + 10;
    end else if S^ in ['A'..'F'] then begin
      Value := Value * 16 + Ord(S^) - Ord('A') + 10;
    end;

    Inc(S);
  end;

LSuccess:
  if MinusSign then
    Value := - Value;

  Exit(True);
end;

function ParseBinNumber(S, SEnd: PAnsiChar; out Value: TValueN): Boolean; inline;
label
  LSuccess;
var
  MinusSign: Boolean;
begin
  if S >= SEnd then
    Exit(False);

  MinusSign := S^ = '-';
  if MinusSign then
    Inc(S);

  if (S >= SEnd) or not (S^ in ['0', '1']) then
    Exit(False);

  Value := 0;
  while S < SEnd do begin
    if S^ in [' ', #9, #10, #13] then
      goto LSuccess;

    if not (S^ in ['0', '1']) then
      Exit(False);

    Value := (Value shl 1) or (Ord(S^) - Ord('0'));

    Inc(S);
  end;

LSuccess:
  if MinusSign then
    Value := - Value;

  Exit(True);
end;

function ParseCNumber(S, SEnd: PAnsiChar; out Value: TValueN): Boolean; inline;
begin
  if ((SEnd - S) = 3) and (S[0] = '''') and (S[2] = '''') then begin
    Value := Ord(S[1]);
    Exit(True);
  end;

  Exit(False);
end;

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
    case FBase of
     2: Exit(ParseBinNumber(S, SEnd, Num));
    10: Exit(ParseDecimalNumber(S, SEnd, Num));
    16: Exit(ParseHexNumber(S, SEnd, Num));
    else
      Exit(ParseBaseNumber(S, SEnd, FBase, Num)); // <BASEnum>
    end;
  end;

  Exit(False);
end;

procedure TMachine.AddSource(const S: AnsiString; ID: TValueFileID);
begin
  FSourceID := ID;
  Inc(FSourceIndex);
  SetLength(FSources, Length(FSources) + 1);
  FSources[FSourceIndex] := S;
end;

function TMachine.InterpretLoop(S: PAnsiChar = nil; SEnd: PAnsiChar = nil): Boolean;
var
  NameEnd: PAnsiChar;
  Definition: PDictionaryRecord;
  Number: TValueN;
begin
  FSourceBegin := @FSources[FSourceIndex][1];
  FSource := FSourceBegin;
  FSourceEnd := FSourceBegin + Length(FSources[FSourceIndex]);

  SEnd := FSourceEnd;
  S := SkipSpaces(FSourceBegin, SEnd);
  while S < SEnd do begin
    NameEnd := SkipName(S, SEnd);
    FSource := NameEnd + 1;

    if FDictionary.Find(S, NameEnd, Definition) then begin
      if IsInterpreting then begin
        if @Definition^.Semantic <> nil then begin
          if not Definition^.Semantic(@Self, Definition^.Code) then
            Exit(False);
        end else
          Writeln(stderr, 'ERROR no semantic for ', Definition^.Name);
      end else begin
        if Definition^.Immediate then begin
          if @Definition^.Semantic <> nil then begin
            if not Definition^.Semantic(@Self, Definition^.Code) then
              Exit(False);
          end else
            Writeln(stderr, 'ERROR no semantic for ', Definition^.Name);
        end else begin
          if Definition^.Opcode >= 0 then begin
            Compile(Definition^.Opcode);
          end else begin
            CompileCall(Definition);
          end;
        end;
      end;
    end else begin
      if ParseAnyNum(S, NameEnd, Number) then begin
        if IsInterpreting then begin
          WGrow(FStack);
          FStack^ := Pointer(Number);
        end else begin
          CompileLiteral(Number);
        end;
      end else begin
        UnrecognizedWord(S, NameEnd);
        S := SkipSpaces(FSource, SEnd);
        Exit(False);
      end;
    end;

    S := SkipSpaces(FSource, SEnd);
  end;

  Exit(True);
end;

function TMachine.InterpretREPLInput(const Line: AnsiString): Boolean;
begin
  AddSource(Line, 0);
  Exit(InterpretLoop);
end;

function TMachine.InterpretString(const S: AnsiString): Boolean;
begin
  AddSource(S, -1);
  Exit(InterpretLoop);
end;

function TMachine.InterpretFile(const FileName: AnsiString): Boolean;
var
  Content: AnsiString;
begin
  if not ReadFileContent(FileName, Content) then
    Exit(Error('could not read ' + FileName));

  AddSource(Content, -1);

  Result := InterpretLoop;

  Exit;
end;

function TMachine.UnrecognizedWord(S, SEnd: PAnsiChar): Boolean;
var
  Date: AnsiString;
begin
  Error('unrecognized word ' + ToPrintableString(S, SEnd));
  if IsForth2012Plan(S, SEnd, Date) then
    Hint('it is planned to be implemented on (approximately) ' + Date);
  Exit(False);
end;

end.
