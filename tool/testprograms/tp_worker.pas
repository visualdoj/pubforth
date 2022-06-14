unit tp_worker;

{$MODE OBJFPC}
{$MODESWITCH DEFAULTPARAMETERS}
{$MODESWITCH OUT}
{$MODESWITCH RESULT}

interface

uses
  sysutils,
  pipes,
  process,
  dateutils,
  tp_env,
  tp_diff,
  testprograms_params,
  testprograms_printer,
  testprograms_tasks;

type
PWorker = ^TWorker;
TWorker = object
  Task: PTask;
  Process: TProcess;
  Finished: Boolean;
  StartTime: TDateTime;
  Stage: LongInt; // index of command in list
  Action: AnsiString; // build or test
  procedure Init;
  procedure Done;
  procedure Reset;
  function Assign(aTask: PTask): Boolean;
  function Run: Boolean;
end;

procedure WorkerLogCommand(Worker: PWorker; Command: PCommand);
procedure WorkerLogFile(Worker: PWorker; const FileName: AnsiString);
function PrintDiffFromFile(const FileName: AnsiString): Boolean;
procedure PrintDiff(Task: PTask);

implementation

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
    if Stream.NumBytesAvailable <= 0 then
      break;
    BytesRead := Stream.Read(Buffer[0], Length(Buffer));
    if BytesRead > 0 then
      BlockWrite(F, Buffer[0], BytesRead);
    if IOResult <> 0 then begin
      PrintError(['could not save output to '{FIXME , FileName}]);
      Exit(False);
    end;
    if not All then
      break;
  until BytesRead = 0;
{$I+}
  Exit(True);
end;

function ReadStdinFromFile(Process: TProcess; const FileName: AnsiString): Boolean;
var
  F: File;
  Data: Pointer;
  Size: SizeUInt;
begin
{$I-}
  Assign(F, FileName);
  Reset(F, 1);
  if IOResult <> 0 then begin
    PrintError(['Could not open for read: ', FileName]);
    Exit(False);
  end;
  Size := FileSize(F);
  Data := GetMem(Size);
  BlockRead(F, Data^, Size);
  if IOResult <> 0 then begin
    PrintError(['Could not read: ', FileName]);
    Exit(False);
  end;
  Process.Input.Write(Data^, Size);
  Process.CloseInput;
  Close(F);
{$I+}
  Exit(True);
end;

procedure TWorker.Init;
begin
  Task := nil;
  Process := nil;
  Stage := 0;
  Action := '';
  Finished := False;
end;

procedure TWorker.Done;
begin
end;

procedure TWorker.Reset;
begin
  Task := nil;
  //Process.Free;
  Stage := 0;
  Action := '';
  Finished := False;
end;

function TWorker.Assign(aTask: PTask): Boolean;
begin
  if Task <> nil then
    Reset;
  Task := aTask;
  try
    //Process := TProcess.Create(nil);
    //Process.Options := Process.Options + [poUsePipes];
    //OverrideEnv(Process, @Task^.Env);
  except
    //Reset;
    Exit(False);
  end;
  Exit(True);
end;

procedure DumpExceptionCallStack(E: Exception);
var
  I: Integer;
  Frames: PPointer;
  Report: AnsiString;
begin
  Report := 'Program exception! ' + LineEnding +
    'Stacktrace:' + LineEnding + LineEnding;
  if E <> nil then begin
    Report := Report + 'Exception class: ' + E.ClassName + LineEnding +
    'Message: ' + E.Message + LineEnding;
  end;
  Report := Report + BackTraceStrFunc(ExceptAddr);
  Frames := ExceptFrames;
  for I := 0 to ExceptFrameCount - 1 do
    Report := Report + LineEnding + BackTraceStrFunc(Frames[I]);
  Writeln(Report);
  //Halt; // End of program execution
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

function TWorker.Run: Boolean;
var
  Command: PCommand;
  I: LongInt;
  FOut, FErr: File;
  TestDir, Stdin: AnsiString;
  DiffDetected: Boolean;
begin
  while Stage <= High(Task^.Cmds) do begin
    Command := Task^.Cmds[Stage];
    if Length(Command^.Atoms) = 0 then begin
      Inc(Stage);
      continue;
    end;
    if Stage = High(Task^.Cmds) then begin
      Action := 'test';
    end else
      Action := 'build';
    WorkerLogCommand(@Self, Command);
    Inc(Stage);
    try
      Process := TProcess.Create(nil);
      Process.Options := Process.Options + [poUsePipes];
      TestDir := Task^.Env.TESTDIR;
      if TestDir <> '' then begin
        Process.CurrentDirectory := TestDir;
      end;
      OverrideEnv(Process, @Task^.Env);
      Process.Executable := GetExePath(TestDir, Command^.Atoms[0]);
      //if Action = 'test' then begin
      //  Process.Executable := './' + TestDir + '/' + Command^.Atoms[0];
      //end else
      //  Process.Executable := Command^.Atoms[0];
      Process.ConsoleTitle := Process.Executable;
      for I := 1 to High(Command^.Atoms) do begin
        Process.Parameters.Add(Command^.Atoms[I]);
      end;
      try
        Process.Execute;
      except
        CancelStatusLine;
        PrintError(['Could not run: ', TestDir, ' ', CommandToString(Command)]);
        RestoreStatusLine;
        Process.Free;
        Finished := True;
        Task^.Ok := False;
        Task^.Verdict := 'PREPARATION_FAILED';
        Exit(True);
      end;
      StartTime := Now;
      if Action = 'test' then begin
        if Command^.Stdin <> '' then begin
          Stdin := Command^.Stdin;
          if Stdin <> '' then
            Stdin := TestDir + '/' + Stdin;
          ReadStdinFromFile(Process, Stdin);
        end;
        // TODO collect build logs too
        if not StartSaveStreamToFile(Task^.StdoutFileName, FOut)
        or not StartSaveStreamToFile(Task^.StderrFileName, FErr)
        then
          Exit(False);
      end else begin
        if not StartSaveStreamToFile('build.out', FOut)
        or not StartSaveStreamToFile('build.err', FErr)
        then
          Exit(False);
      end;
      while Process.Running and (MilliSecondSpan(StartTime,Now) < Task^.Timeout * 1000) do begin
        Sleep(1);
        //if Action = 'test' then begin
          if not CopyStreamToFile(Process.Output, FOut, False)
          or not CopyStreamToFile(Process.Stderr, FErr, False)
          then
            Exit(False);
        //end;
      end;
      if Process.Running then begin
        Task^.Ok := False;
        Task^.TimedOut := True;
        Task^.Verdict := 'TIMEOUT';
        Process.Free;
        SaveTaskResult(Task);
        Finished := True;
        Exit(True);
      end;
      if not CopyStreamToFile(Process.Output, FOut, True)
      or not CopyStreamToFile(Process.Stderr, FErr, True)
      then
        Exit(False);
      FinishSaveStreamToFile(FOut);
      FinishSaveStreamToFile(FErr);
      if Action = 'test' then begin
        Task^.ExitCode := Process.ExitCode;
        Task^.Ok := Task^.ExitCode = 0;
        if Task^.ExitCode <> 0 then begin
          Task^.Verdict := 'FAILURE';
        end else
          Task^.Verdict := 'SUCCESS';
      end else begin
        if Process.ExitCode <> 0 then begin
          Task^.Ok := False;
          Task^.Verdict := 'PREPARATION_FAILED';
          Finished := True;
        end;
      end;
      Process.Free;
      Exit(True);
    except
    on E: Exception do begin
      DumpExceptionCallStack(E);
      Process.Free;
      Reset;
      Exit(False);
    end else
      Writeln('Unknown exception');
      Process.Free;
      Reset;
      Exit(False);
    end;
  end;
  if Task^.CanFileName <> '' then begin
    Action := 'check';
    WorkerLogFile(@Self, Task^.CanFileName);
    if not TestProgramsDiff(Task^.CanFileName, Task^.StdoutFileName, Task^.DiffFileName, DiffDetected) then begin
      Finished := True;
      Exit(False);
    end;
    if DiffDetected then begin
      Task^.Ok := False;
      Task^.Regression := True;
      Task^.Verdict := 'REGRESSION';
      SaveTaskResult(Task);
    end;
  end else begin
    SaveTaskResult(Task);
  end;
  Finished := True;
  Exit(True);
end;

procedure WorkerLogCommand(Worker: PWorker; Command: PCommand);
begin
  if not TestProgramsParams.EnableWorkerLog then
    Exit;
  CancelStatusLine;
  Print([Worker^.Action, ': ']);
  PrintCommand(Command);
  PrintLn;
  RestoreStatusLine;
end;

procedure WorkerLogFile(Worker: PWorker; const FileName: AnsiString);
begin
  if not TestProgramsParams.EnableWorkerLog then
    Exit;
  CancelStatusLine;
  Print([Worker^.Action, ': ', FileName]);
  PrintLn;
  RestoreStatusLine;
end;

function PrintDiffFromFile(const FileName: AnsiString): Boolean;
var
  T: TextFile;
  S: AnsiString;
begin
{$I-}
  Assign(T, FileName);
  Reset(T);
  if IOResult <> 0 then begin
    PrintError(['Could not open for read: ', FileName]);
    Exit(False);
  end;
  while not Eof(T) do begin
    Readln(T, S);
    if IOResult <> 0 then begin
      PrintError(['Could not read: ', FileName]);
      Exit(False);
    end;
    PrintLn(S);
  end;
  Close(T);
{$I+}
  Exit(True);
end;

procedure PrintDiff(Task: PTask);
begin
  PrintDiffFromFile(Task^.DiffFileName);
end;

end.
