unit dfilereader;
//
//  Simple file reader.
//

{$MODE FPC}
{$MODESWITCH OUT}
{$MODESWITCH RESULT}

interface

function ReadFileContent(const FileName: AnsiString;
                         MaxSize: SizeUInt;
                         out Content: PAnsiChar;
                         out ContentLen: SizeUInt): Boolean; overload;
      // Reads file FileName and saves content to the Content and ContentLen.
      // Allocates memory for Content, so you should FreeMem'ed it.
      // Returns True on success, returns False otherwise.
      // If MaxSize is greater than 0 and file is larger than MaxSize, returns
      // False.

function ReadFileContent(const FileName: AnsiString;
                         out Content: AnsiString): Boolean; overload; inline;
      // Reads file FileName and saves content to the Content.
      // Returns True on success, returns False otherwise.

implementation

function ReadFileContent(const FileName: AnsiString;
                         MaxSize: SizeUInt;
                         out Content: PAnsiChar;
                         out ContentLen: SizeUInt): Boolean;
var
  F: file of Byte;
  Size: {$IF Defined(WINDOWS)} SizeUInt {$ELSE} SizeInt {$ENDIF};
begin
  Assign(F, FileName);
  {$I-}
  Reset(F);
  if IOResult <> 0 then
    Exit(False);
  Size := FileSize(F);
  if (MaxSize > 0) and (Size > MaxSize) then
    Exit(False);
  ContentLen := Size;
  Content := GetMem(Size);
  BlockRead(F, Content[0], Size, Size);
  if (IOResult <> 0) or (Size < ContentLen) then begin
    FreeMem(Content);
    Exit(False);
  end;
  Close(F);
  {$I+}
  Exit(True);
end;

function ReadFileContent(const FileName: AnsiString;
                         out Content: AnsiString): Boolean;
var
  F: file of Byte;
  Size: SizeInt;
begin
  Assign(F, FileName);
  {$I-}
  Reset(F);
  {$I+}
  if IOResult <> 0 then
    Exit(False);
  SetLength(Content, FileSize(F));
  Size := 0;
  {$I-} BlockRead(F, Content[1], Length(Content), Size); {$I+}
  if (IOResult <> 0) or (Size < Length(Content)) then
    Exit(False);
  Close(F);
  Exit(True);
end;

end.
