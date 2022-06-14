unit testprograms_tasks;

{$MODE OBJFPC}
{$MODESWITCH DEFAULTPARAMETERS}
{$MODESWITCH OUT}
{$MODESWITCH RESULT}

interface

uses
  pipes,
  process,
  sysutils,
  dateutils,
  testprograms_params,
  testprograms_printer,
  testprograms_paths,
  tp_env;

const
  RESULT_OK         = 'SUCCESS';
  RESULT_MISSED     = 'MISSED';
  RESULT_FAILURE    = 'FAILURE';
  RESULT_TIMEOUT    = 'TIMEOUT';

type
PCommand = ^TCommand;
TCommand = record
  Atoms: array of AnsiString;
  Stdin: AnsiString;
end;

PTask = ^TTask;
TTask = record
  Cmds: array of PCommand;
  CmdFull: AnsiString;
  CmdEscaped: AnsiString;
  TestName: AnsiString;
  Env: TEnv;
  CanFileName: AnsiString; // empty if no canonical file
  Deps: array of AnsiString; // list of all dependencies for result
  Build: PTask;
  Timeout: LongInt; // time to be executed
  // Results
  Verdict: AnsiString;
  Ok: Boolean;
  Missed: Boolean;
  ExitCode: LongInt;
  StdoutFileName: AnsiString; // path to stdout
  StderrFileName: AnsiString; // path to stderr
  DiffFileName: AnsiString; // path to diff
  ResultFileName: AnsiString;
  Regression: Boolean;
  TimedOut: Boolean;
end;

var
  Tasks: array of PTask;
  IgnoredTasks: array of PTask;

function NewTask: PTask; overload;
function NewTask(const Cmd: array of AnsiString): PTask; overload;
procedure FreeTask(Task: PTask);
procedure AddTask(Task: PTask);
procedure AddCommand(Task: PTask; Command: PCommand);

function NewCommand(const Cmd: array of AnsiString;
                    const Stdin: AnsiString): PCommand;
procedure FreeCommand(Command: PCommand);

function IsTaskNeedRerun(Task: PTask): Boolean;

function RunTask(Task: PTask): Boolean;

procedure PrintTask(Task: PTask);
procedure PrintCommand(Command: PCommand);
function CommandToString(Command: PCommand): AnsiString;

implementation

uses
  tp_filter;

function Escape(const S: AnsiString): AnsiString;
var
  I: LongInt;
begin
  Result := '';
  for I := 1 to Length(S) do begin
    if S[I] = #10 then begin
      Result := Result + ' ';
    end else if S[I] = #13 then begin
      Result := Result + ' ';
    end else begin
      Result := Result + S[I];
    end;
  end;
end;

function EscapeStrong(const S: AnsiString): AnsiString;
var
  I: LongInt;
begin
  Result := '';
  for I := 1 to Length(S) do begin
    if S[I] = #10 then begin
      Result := Result + '_';
    end else if S[I] = #13 then begin
      Result := Result + '_';
    end else if S[I] = ' ' then begin
      Result := Result + '_';
    end else begin
      Result := Result + S[I];
    end;
  end;
end;

function ReadVerdict(const ResultPath: AnsiString; out Verdict: AnsiString): Boolean;
var
  T: TextFile;
  Line: AnsiString;
  I: LongInt;
begin
{$PUSH}
{$I-}
  Assign(T, ResultPath);
  Reset(T);
  if IOResult <> 0 then
    Exit(False);
  Readln(T, Line);
  if IOResult <> 0 then begin
    Close(T);
    Exit(False);
  end;
  I := 1;
  while I <= Length(Line) do begin
    if Line[I] = ' ' then
      break;
    Inc(I);
  end;
  Verdict := Copy(Line, 1, I - 1);
  Close(T);
{$POP}
  Exit(True);
end;

function EnsureDir(const Path: AnsiString): Boolean;
var
  I: LongInt;
  Dir: AnsiString;
begin
  I := 1;
  while I <= Length(Path) do begin
    if (Path[I] = '/') {$IF Defined(WINDOWS)}or (Path[I] = '\'){$ENDIF} then begin
      Dir := Copy(Path, 1, I - 1);
      if Dir = '' then begin
        Inc(I);
        continue;
      end;
{$I-}
      Mkdir(Dir); // TODO check if already exists
{$I+}
      if IOResult <> 0 then
        ; // pull the error (if got one) and ignore it
    end;
    Inc(I);
  end;
  Exit(True);
end;

function NewTask: PTask;
begin
  New(Result);
  Result^.Env.Init;
  Result^.CmdFull := '';
  Result^.CmdEscaped := '';
  Result^.StdoutFileName := '';
  Result^.StderrFileName := '';
  Result^.DiffFileName := '';
  Result^.ResultFileName := '';
  EnsureDir(Result^.ResultFileName);
  Result^.Timeout := TestProgramsParams.Timeout;
end;

function NewTask(const Cmd: array of AnsiString): PTask;
begin
  Result := NewTask();
  AddCommand(Result, NewCommand(Cmd, ''));
end;

procedure AddTask(Task: PTask);
begin
  if IgnoreTask(Task) then begin
    SetLength(IgnoredTasks, Length(IgnoredTasks) + 1);
    IgnoredTasks[High(IgnoredTasks)] := Task;
  end else begin
    SetLength(Tasks, Length(Tasks) + 1);
    Tasks[High(Tasks)] := Task;
  end;
end;

procedure FreeTask(Task: PTask);
begin
  Task^.Env.Done;
  Dispose(Task);
end;

function GetExePath(const TestDir, Exe: AnsiString): AnsiString;
var
  I: LongInt;
begin
  // TODO check if Exe is absolute or started with ./
  for I := 1 to Length(Exe) do begin
    if (Exe[I] = '/') or (Exe[I] = '\') then begin
      Exit('./' + TestDir + '/' + Exe);
    end;
  end;
  Exit(Exe);
end;

procedure AddCommand(Task: PTask; Command: PCommand);
var
  I: LongInt;
  TestDir: AnsiString;
begin
  Setlength(Task^.Cmds, Length(Task^.Cmds) + 1);
  Task^.Cmds[High(Task^.Cmds)] := Command;
  // Autodetect some values from last command
  Task^.CmdFull := '';
  Task^.CmdEscaped := '';
  TestDir := Task^.Env.TESTDIR;
  if TestDir <> '' then begin
    Task^.CmdFull := TestDir + '/';
  end;
  for I := 0 to High(Command^.Atoms) do begin
    if I > 0 then
      Task^.CmdFull := Task^.CmdFull + ' ';
    Task^.CmdFull := Task^.CmdFull + Escape(Command^.Atoms[I]);
    if Task^.CmdEscaped <> '' then begin
      Task^.CmdEscaped := Task^.CmdEscaped + '_' + EscapeStrong(Command^.Atoms[I]);
    end else
      Task^.CmdEscaped := EscapeStrong(Command^.Atoms[I]);
  end;
  Task^.TestName := Task^.Env.TESTNAME;
  if Task^.TestName = '' then
    Task^.TestName := Task^.CmdEscaped;
  Task^.StdoutFileName := TestProgramsParams.ArtifactsDir + Task^.TestName + '.out';
  Task^.StderrFileName := TestProgramsParams.ArtifactsDir + Task^.TestName + '.err';
  Task^.DiffFileName := TestProgramsParams.ArtifactsDir + Task^.TestName + '.diff';
  Task^.ResultFileName := TestProgramsParams.ArtifactsDir + Task^.TestName + '.res';
  Task^.CanFileName := Task^.Env.TESTDIR + '/' + Task^.TestName + '.can';
  if not FileExists(Task^.CanFileName) then begin
    Task^.CanFileName := '';
  end;
  EnsureDir(Task^.ResultFileName);
end;

function NewCommand(const Cmd: array of AnsiString;
                    const Stdin: AnsiString): PCommand;
var
  I: LongInt;
begin
  New(Result);
  SetLength(Result^.Atoms, Length(Cmd));
  for I := 0 to High(Cmd) do
    Result^.Atoms[I] := Cmd[I];
  Result^.Stdin := Stdin;
end;

procedure FreeCommand(Command: PCommand);
begin
  Dispose(Command);
end;

function IsTaskNeedRerun(Task: PTask): Boolean;
var
  CmdAge: PtrInt;
  ResAge: PtrInt;
  Exe: AnsiString;
begin
  Exe := Task^.Cmds[High(Task^.Cmds)]^.Atoms[0];
  CmdAge := FileAge(Exe);
{$IF Defined(WINDOWS)}
  if CmdAge = -1 then
    CmdAge := FileAge(Exe + '.exe');
  if CmdAge = -1 then
    CmdAge := FileAge(Exe + '.com');
{$ENDIF}
  ResAge := FileAge(Task^.ResultFileName);
  if (ResAge = -1) or (CmdAge = -1) or (CmdAge >= ResAge) then begin
    Exit(True);
  end;
  if not ReadVerdict(Task^.ResultFileName, Task^.Verdict) then begin
    Exit(True);
  end;
  Task^.Ok := Task^.Verdict = 'SUCCESS';
  if (Task^.Verdict = 'SUCCESS') or (Task^.Verdict = 'REGRESSION') then begin
    Exit(False);
  end;
  Exit(True);
end;

function StartSaveStreamToFile(const FileName: AnsiString; var F: File): Boolean;
begin
{$I-}
  Assign(F, FileName);
  ReWrite(F, 1);
  if IOResult <> 0 then begin
    PrintError(['could not open file ', FileName]);
    Exit(False);
  end;
{$I+}
  Exit(True);
end;

function FinishSaveStreamToFile(var F: File): Boolean;
begin
{$I-}
  Close(F);
  if IOResult <> 0 then
    ; // ignore the error
{$I+}
  Exit(True);
end;

function CopyStreamToFile(Stream: TInputPipeStream; var F: File; All: Boolean): Boolean;
var
  Buffer: array[0 .. 2 * 1024 - 1] of Byte;
  BytesRead: LongInt;
begin
{$I-}
  repeat
    BytesRead := Stream.Read(Buffer[0], Length(Buffer));
    if BytesRead > 0 then
      BlockWrite(F, Buffer[0], BytesRead);
    if IOResult <> 0 then begin
      PrintError(['could not save output to '{FIXME , FileName}]);
      Exit(False);
    end;
  until (BytesRead = 0) or not All;
{$I+}
  Exit(True);
end;

//function FlushStreamToFile(Stream: TInputPipeStream; const FileName: AnsiString; All: Boolean): Boolean;
//var
//  F: file;
//  Buffer: array[0 .. 2 * 1024 - 1] of Byte;
//  BytesRead: LongInt;
//begin
//{$I-}
//  Assign(F, FileName);
//  Append(F);
//  if IOResult <> 0 then begin
//    PrintError(['could not open ', FileName]);
//    Exit(False);
//  end;
//  repeat
//    BytesRead := Stream.Read(Buffer[0], Length(Buffer));
//    if BytesRead > 0 then
//      BlockWrite(F, Buffer[0], BytesRead);
//    if IOResult <> 0 then begin
//      PrintError(['could not save output to ', FileName]);
//     Exit(False);
//   end;
//  until (BytesRead = 0) or or All;
//  Close(F);
//{$I+}
//  Exit(True);
//end;

function SaveStreamToFile(Stream: TInputPipeStream; const FileName: AnsiString): Boolean;
var
  F: file;
  Buffer: array[0 .. 2 * 1024 - 1] of Byte;
  BytesRead: LongInt;
begin
{$I-}
  Assign(F, FileName);
  ReWrite(F, 1);
  if IOResult <> 0 then begin
    PrintError(['could not save output to ', FileName]);
    Exit(False);
  end;
  repeat
    BytesRead := Stream.Read(Buffer[0], Length(Buffer));
    if BytesRead > 0 then
      BlockWrite(F, Buffer[0], BytesRead);
    if IOResult <> 0 then begin
      PrintError(['could not save output to ', FileName]);
      Exit(False);
    end;
  until BytesRead = 0;
  Close(F);
{$I+}
  Exit(True);
end;

function SaveTaskResult(Task: PTask): Boolean;
var
  T: TextFile;
begin
{$I-}
  Assign(T, Task^.ResultFileName);
  ReWrite(T);
  if IOResult <> 0 then begin
    PrintError(['could not save output to ', Task^.ResultFileName]);
    Exit(False);
  end;
  Writeln(T, Task^.Verdict, ' ', Task^.ExitCode, ' ', Task^.Timeout);
  if IOResult <> 0 then begin
    PrintError(['could not save output to ', Task^.ResultFileName]);
    Exit(False);
  end;
  Close(T);
{$I+}
  Exit(True);
end;

function RunTask(Task: PTask): Boolean;
var
  Process: TProcess;
  I: LongInt;
  StartTime: TDateTime;
  Cmd: PCommand;
  FOut, FErr: File;
begin
  Task^.Ok := False;
  VerboseLn(['running: ', Task^.CmdFull]);
  Cmd := Task^.Cmds[High(Task^.Cmds)];
  try
    try
      Process := TProcess.Create(nil);
      Process.Executable := Cmd^.Atoms[0];
      for I := 1 to High(Cmd^.Atoms) do begin
        Process.Parameters.Add(Cmd^.Atoms[I]);
      end;
      Process.Options := Process.Options + [poUsePipes];
      Process.Execute;
      StartTime := Now;
      if not StartSaveStreamToFile(Task^.StdoutFileName, FOut)
      or not StartSaveStreamToFile(Task^.StderrFileName, FErr)
      then
        Exit(False);
      while Process.Running and (MilliSecondSpan(StartTime,Now) < Task^.Timeout * 1000) do begin
        Sleep(1);
        if not CopyStreamToFile(Process.Output, FOut, False)
        or not CopyStreamToFile(Process.Stderr, FErr, False)
        then
          Exit(False);
      end;
      if Process.Running then begin
        Task^.Ok := False;
        Task^.TimedOut := True;
        Task^.Verdict := 'TIMEOUT';
        Process.Free;
        SaveTaskResult(Task);
        Exit(True);
      end;
      if not CopyStreamToFile(Process.Output, FOut, True)
      or not CopyStreamToFile(Process.Stderr, FErr, True)
      then
        Exit(False);
      FinishSaveStreamToFile(FOut);
      FinishSaveStreamToFile(FErr);
      // if not SaveStreamToFile(Process.Output, Task^.StdoutFileName)
      // or not SaveStreamToFile(Process.Stderr, Task^.StderrFileName)
      // then
      //   Exit(False);
      Task^.ExitCode := Process.ExitCode;
      Task^.Ok := Task^.ExitCode = 0;
      if Task^.ExitCode <> 0 then begin
        Task^.Verdict := 'FAILURE';
      end else
        Task^.Verdict := 'SUCCESS';
    finally
      Process.Free;
    end;
  except
    Task^.Verdict := 'FAILURE';
    Task^.ExitCode := 1;
    Task^.Ok := False;
  end;
  SaveTaskResult(Task);
  Exit(True);
end;

procedure PrintTask(Task: PTask);
var
  I, J: LongInt;
begin
  // TODO print custom env
  for I := 0 to High(Task^.Cmds) do begin
    for J := 0 to High(Task^.Cmds[I]^.Atoms) do begin
      if J > 0 then begin
        Write(stderr, '''', Task^.Cmds[I]^.Atoms[J], ''' ');
      end else
        Write(stderr, Task^.Cmds[I]^.Atoms[J], ' ');
    end;
    if Task^.Cmds[I]^.Stdin <> '' then
      Write('<', Task^.Cmds[I]^.Stdin, ' ');
    if I < High(Task^.Cmds) then
      Write(stderr, '&& ');
  end;
  Writeln;
end;

procedure PrintCommand(Command: PCommand);
var
  I: LongInt;
begin
  for I := 0 to High(Command^.Atoms) do begin
    Print([Command^.Atoms[I], ' ']);
  end;
  if Command^.Stdin <> '' then
    Print(['<', Command^.Stdin]);
end;

function CommandToString(Command: PCommand): AnsiString;
var
  I: LongInt;
begin
  Result := '';
  for I := 0 to High(Command^.Atoms) do begin
    Result := Command^.Atoms[I] + ' ';
  end;
  if Command^.Stdin <> '' then
    Result := Result + '<' + Command^.Stdin;
end;

end.
