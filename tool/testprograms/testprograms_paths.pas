unit testprograms_paths;

//
//  Utilities for working with paths.
//

{$MODE FPC}
{$MODESWITCH DEFAULTPARAMETERS}
{$MODESWITCH OUT}
{$MODESWITCH RESULT}

interface

function CutExtension(const Path: AnsiString): AnsiString;

function ReplaceExtension(const Path: AnsiString; const NewPostfix: AnsiString): AnsiString;

implementation

function CutExtension(const Path: AnsiString): AnsiString;
var
  I: LongInt;
begin
  I := Length(Path);
  while I >= 1 do begin
    if (Path[I] = '/') or (Path[I] = '\') then
      Exit(Path);
    if Path[I] = '.' then
      Exit(Copy(Path, 1, I - 1));
    Dec(I);
  end;
  Exit(Path);
end;

function ReplaceExtension(const Path: AnsiString; const NewPostfix: AnsiString): AnsiString;
begin
  Exit(CutExtension(Path) + NewPostfix);
end;

end.
