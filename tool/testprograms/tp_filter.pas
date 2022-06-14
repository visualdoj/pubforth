unit tp_filter;

//
//  Unit for filtering tasks with a regexpr.
//

{$MODE FPC}
{$MODESWITCH DEFAULTPARAMETERS}
{$MODESWITCH OUT}
{$MODESWITCH RESULT}

interface

uses
  testprograms_tasks,
  RegExpr;

var
  re: TRegExpr;

procedure SetRegExpr(const RegExpr: AnsiString);

function IgnoreTask(Task: PTask): Boolean;

implementation

procedure SetRegExpr(const RegExpr: AnsiString);
begin
  if re <> nil then
    re.Free;
  if RegExpr = '' then begin
    re := nil;
    Exit;
  end;
  re := TRegExpr.Create(RegExpr);
end;

function IgnoreTask(Task: PTask): Boolean;
begin
  if re = nil then
    Exit(False);
  Result := not re.Exec(Task^.CmdFull);
end;

initialization
  re := nil;
finalization
  if re <> nil then
    re.Free;
end.
