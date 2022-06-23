unit tp_env;

{$MODE OBJFPC}
{$MODESWITCH DEFAULTPARAMETERS}
{$MODESWITCH OUT}
{$MODESWITCH RESULT}

interface

uses
  sysutils,
  pipes,
  process,
  classes;

type
PEnv = ^TEnv;
TEnv = object
private
  Names: array of AnsiString;
  Values: array of AnsiString;
  procedure AddDefaultEnv;
public
  procedure Init;
  procedure Done;
  procedure Add(const Name, Value: AnsiString; Force: Boolean = False);
  function Get(const Name: AnsiString): AnsiString;
  function STDIN: AnsiString;
  function TESTDIR: AnsiString;
  function TESTNAME: AnsiString;
end;

procedure OverrideEnv(Process: TProcess;
                      Env: PEnv);
      //
      // Passes environment of testprograms to the Process, but overrides or
      // adds values from the Env.
      //

implementation

procedure TEnv.AddDefaultEnv;
var
  I: LongInt;
  EnvVars: TStringList;
begin
  EnvVars := TStringList.Create;
  try
    for I := 1 to GetEnvironmentVariableCount do
      EnvVars.Add(GetEnvironmentString(I));
    EnvVars.Sort;
    for I := 0 to EnvVars.Count - 1 do
      Add(EnvVars.Names[I], EnvVars.ValueFromIndex[I], True);
  finally
    EnvVars.Free;
  end;
end;

procedure TEnv.Init;
begin
  SetLength(Names, 0);
  SetLength(Values, 0);
end;

procedure TEnv.Done;
begin
  SetLength(Names, 0);
  SetLength(Values, 0);
end;

procedure TEnv.Add(const Name, Value: AnsiString; Force: Boolean = False);
var
  I: LongInt;
begin
  if (not Force) and (Length(Names) = 0) then
    AddDefaultEnv;
  for I := 0 to High(Names) do begin
    if Name = Names[I] then begin
      Values[I] := Value;
      Exit;
    end;
  end;
  SetLength(Names, Length(Names) + 1);
  Names[High(Names)] := Name;
  SetLength(Values, Length(Values) + 1);
  Values[High(Values)] := Value;
end;

function TEnv.Get(const Name: AnsiString): AnsiString;
var
  I: LongInt;
begin
  for I := 0 to High(Names) do begin
    if Names[I] = Name then
      Exit(Values[I]);
  end;
  Exit('');
end;

function TEnv.STDIN: AnsiString;
begin
  Exit(Get('STDIN'));
end;

function TEnv.TESTDIR: AnsiString;
begin
  Exit(Get('TESTDIR'));
end;

function TEnv.TESTNAME: AnsiString;
begin
  Exit(Get('TESTNAME'));
end;

procedure OverrideEnv(Process: TProcess;
                      Env: PEnv);
var
  I: LongInt;
begin
  if Length(Env^.Names) = 0 then
    Exit;
  for I := 0 to High(Env^.Names) do
    Process.Environment.Add(Env^.Names[I] + '=' + Env^.Values[I]);
end;

end.
