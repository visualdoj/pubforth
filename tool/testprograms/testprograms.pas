{$MODE FPC}
{$MODESWITCH DEFAULTPARAMETERS}
{$MODESWITCH OUT}
{$MODESWITCH RESULT}

uses
  sysutils,
  testprograms_printer,
  testprograms_params,
  testprograms_tasks,
  testprograms_list,
  tp_diff,
  tp_worker,
  tp_status,
  tp_filter;

function BuildTasksFromListFile(const ListFileName: AnsiString): Boolean;
var
  T: File;
  S: AnsiString;
begin
  {$PUSH}
  {$I-}
  Assign(T, ListFileName);
  Reset(T, 1);
  if IOResult <> 0 then begin
    PrintError(['could not open list file: ', ListFileName]);
    Exit(False);
  end;
  SetLength(S, FileSize(T));
  BlockRead(T, S[1], Length(S));
  //while TestsListNext(T, Command) do begin
  //  NewTask(Command.Chains[High(Command.Chains)].Cmd);
  //end;
  Close(T);
  {$POP}
  Exit(GenerateTasks(@S[1], @S[1] + Length(S)));
end;

procedure PrintTasks;
var
  I: LongInt;
begin
  for I := 0 to High(Tasks) do begin
    PrintTask(Tasks[I]);
  end;
end;

function PrintReportSummary(Count: LongInt; CurrentOp: PCommand; Running: AnsiString): Boolean;
var
  I: LongInt;
  Succeeded, Failed, All: LongInt;
begin
  All := Length(Tasks);
  Succeeded := 0;
  Failed := 0;
  for I := 0 to Count - 1 do begin
    if not Tasks[I]^.Ok then begin
      Inc(Failed);
    end else
      Inc(Succeeded);
  end;
  if Failed = 0 then begin
    StartColorGreen;
    StatusLineColor := 1;
  end else begin
    StartColorRed;
    StatusLineColor := 2;
  end;
  if Running <> '' then
    Running := '... ' + Running;
  if TestProgramsParams.StatusFormat = '' then begin
    if Failed <> 0 then begin
      ChangeStatusLine([Succeeded, '/', All, ' tests succeeded', ', ', Failed , ' failed', Running]);
    end else
      ChangeStatusLine([Succeeded, '/', All, ' tests succeeded', Running]);
  end else begin
    ChangeStatusLine([GenerateStatusLine(Count, CurrentOp, TestProgramsParams.StatusFormat)]);
  end;
  {
  Print([Succeeded, '/', All, ' tests succeeded']);
  if Failed <> 0 then
    PrintLn([', ', Failed , ' failed']);
  }
  EndColor;
  Exit(Failed = 0);
end;

function PrintTaskResult(Task: PTask): Boolean;
begin
  if not Task^.Ok then begin
    if Task^.TimedOut then begin
      StartColorRed;
      PrintLn([Task^.CmdFull, ' TIMEOUT']);
      EndColor;
    end else if Task^.Verdict = 'PREPARATION_FAILED' then begin
      StartColorRed;
      PrintLn([Task^.CmdFull, ' ', Task^.Verdict]);
      EndColor;
    end else if Task^.ExitCode <> 0 then begin
      StartColorRed;
      PrintLn([Task^.CmdFull, ' FAILED']);
      EndColor;
    end else if Task^.Regression then begin
      StartColorBlue;
      PrintLn([Task^.CmdFull, ' REGRESSION']);
      EndColor;
      PrintDiff(Task);
    end else begin
      StartColorRed;
      PrintLn([Task^.CmdFull, ' UNKNOWN']);
      EndColor;
    end;
  end;
  Exit(True);
end;

function PrintFailedList: Boolean;
var
  I: LongInt;
begin
  for I := 0 to High(Tasks) do begin
    PrintTaskResult(Tasks[I]);
  end;
  Exit(True);
end;

function HasErrors(Count: LongInt = 0): Boolean;
var
  I: LongInt;
begin
  if Count = 0 then
    Count := Length(Tasks);
  for I := 0 to Count - 1 do
    if not Tasks[I]^.Ok then
      Exit(True);
  Exit(False);
end;

var
  I: LongInt;
  B: Boolean;
  W: TWorker;
begin
  if not ReadParams then begin
    if TestProgramsParams.NeedUsage then
      PrintUsage;
    Halt(1);
  end;
  if TestProgramsParams.NeedUsage then begin
    PrintUsage;
    Halt(0);
  end;
  if TestProgramsParams.EnableProgressLine and TestProgramsParams.DisableProgressLine then begin
    PrintWarning(['conflicted enabling and disabling progress line parameters']);
    UseStatusLine := False;
  end else if TestProgramsParams.EnableProgressLine then begin
    UseStatusLine := True;
  end else if TestProgramsParams.DisableProgressLine then begin
    UseStatusLine := False;
  end else begin
    // let UseStatusLine be by default
  end;
  if TestProgramsParams.DiffMode then begin
    if not TestProgramsDiff(TestProgramsParams.DiffLeft,
                            TestProgramsParams.DiffRight,
                            TestProgramsParams.DiffOut,
                            B) then begin
      Halt(1);
    end;
    if B then begin
      StartColorRed;
      VerboseLn('diff found');
      EndColor;
      Halt(1);
    end else begin
      StartColorGreen;
      VerboseLn('no diff');
      EndColor;
    end;
    Halt(0);
  end;
  if TestProgramsParams.RegEx <> '' then begin
    SetRegExpr(TestProgramsParams.RegEx);
  end;
  if (Length(TestProgramsParams.Cmds) = 0) and (TestProgramsParams.ListFileName = '') then begin
    StartColorGreen;
    PrintLn('No tasks, nothing to test');
    EndColor;
    Halt(0);
  end;
  for I := 0 to High(TestProgramsParams.Cmds) do begin
    if not GenerateTasks(@TestProgramsParams.Cmds[I][1],
                         @TestProgramsParams.Cmds[I][1] + Length(TestProgramsParams.Cmds[I])) then begin
      Halt(1);
    end;
  end;
  if (TestProgramsParams.ListFileName <> '') and not BuildTasksFromListFile(TestProgramsParams.ListFileName) then
    Halt(1);
  VerboseLn([Length(Tasks), ' tests running...']);
  StartStatusLine;
  W.Init;
  for I := 0 to High(Tasks) do begin
    if TestProgramsParams.ForceRerun or IsTaskNeedRerun(Tasks[I]) then begin
      if not W.Assign(Tasks[I]) then begin
        PrintError(['could not assign task ', Tasks[I]^.CmdFull]);
        Halt(1);
      end;
      PrintReportSummary(I - 1, W.Task^.Cmds[W.Stage], Tasks[I]^.CmdFull);
      while not W.Finished do begin
        if not W.Run then begin
          CancelStatusLine;
          PrintError(['task runner failed, could not finish the test suite: ', Tasks[I]^.CmdFull]);
          RestoreStatusLine;
          break;
        end;
      end;
      CancelStatusLine;
      PrintTaskResult(Tasks[I]);
      RestoreStatusLine;
    end else begin
      CancelStatusLine;
      PrintLn(['skipped ', Tasks[I]^.CmdFull]);
      RestoreStatusLine;
    end;
  end;
  W.Done;
  PrintReportSummary(Length(Tasks), nil, '');
  EndStatusLine;
  if TestProgramsParams.WaitKey then begin
    Print('Press ENTER to continue...');
    Readln;
  end;
  if HasErrors then
    Halt(1);
end.
