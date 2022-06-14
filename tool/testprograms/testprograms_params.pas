unit testprograms_params;

{$MODE FPC}
{$MODESWITCH DEFAULTPARAMETERS}
{$MODESWITCH OUT}
{$MODESWITCH RESULT}

interface

uses
  testprograms_printer;

type
TTestProgramsParams = record
  NeedUsage: Boolean;
  DiffMode: Boolean;
  ListFileName: AnsiString; // '' if no list file
  Cmds: array of AnsiString;
  CanExt: AnsiString;
  ForceRerun: Boolean;
  RegEx: AnsiString;
  TimeOut: LongInt;
  ArtifactsDir: AnsiString;
  DiffLeft, DiffRight, DiffOut: AnsiString;
  EnableProgressLine, DisableProgressLine: Boolean;
  WaitKey: Boolean;
  StatusFormat: AnsiString;

  EnableWorkerLog: Boolean;
end;

var
  TestProgramsParams: TTestProgramsParams;

function ReadParams: Boolean;
      //  Reads ParamStr values and fills the TestProgramsParams record.

procedure PrintUsage;
      //  Prints usage of the testprograms.

implementation

function TryGetParam(var Index: LongInt; const Arg: AnsiString; out S: AnsiString): Boolean;
begin
  Inc(Index);
  if Index > ParamCount then begin
    PrintError([Arg, ' needs an argument']);
    Exit(False);
  end;
  S := ParamStr(Index);
  Exit(True);
end;

function TryGetParam(var Index: LongInt; const Arg: AnsiString; out I: LongInt): Boolean;
var
  S: AnsiString;
  Code: Word;
begin
  if not TryGetParam(Index, Arg, S) then
    Exit(False);
  Val(S, I, Code);
  if Code <> 0 then begin
    PrintError([Arg, ' needs an integer argument']);
    Exit(False);
  end else
    Exit(True);
end;

function ReadParams: Boolean;
var
  I: LongInt;
  S: AnsiString;
begin
  // Fill the defaults
  TestProgramsParams.NeedUsage := ParamCount = 0;
  TestProgramsParams.DiffMode := ParamCount = 0;
  TestProgramsParams.ListFileName := '';
  TestProgramsParams.CanExt := '.can';
  TestProgramsParams.ForceRerun := False;
  TestProgramsParams.RegEx := '';
  TestProgramsParams.TimeOut := 10;
  TestProgramsParams.ArtifactsDir := '';
  TestProgramsParams.EnableProgressLine := False;
  TestProgramsParams.DisableProgressLine := False;
  TestProgramsParams.WaitKey := False;
  TestProgramsParams.StatusFormat := '';
  TestProgramsParams.EnableWorkerLog := False;

  if TestProgramsParams.NeedUsage then
    Exit(True);
  I := 1;
  while I <= ParamCount do begin
    S := ParamStr(I);
    if S = '' then begin
      continue;
    end else if (S = '-?') or (S = '-h') or (S = '--help') or (S = '--usage') then begin
      TestProgramsParams.NeedUsage := True;
    end else if (S = '-l') or (S = '--list') then begin
      if TestProgramsParams.ListFileName <> '' then
        ErrLn(['WARNING: overriding ', S]);
      if not TryGetParam(I, S, TestProgramsParams.ListFileName) then
        Exit(False);
    end else if (S = '-c') or (S = '--can') then begin
      if TestProgramsParams.CanExt <> '.can' then
        ErrLn(['WARNING: overriding ', S]);
      if not TryGetParam(I, S, TestProgramsParams.CanExt) then
        Exit(False);
    end else if (S = '-d') or (S = '--dir') then begin
      if TestProgramsParams.ArtifactsDir <> '' then
        ErrLn(['WARNING: overriding ', S]);
      if not TryGetParam(I, S, TestProgramsParams.ArtifactsDir) then
        Exit(False);
      if TestProgramsParams.ArtifactsDir <> '' then
        TestProgramsParams.ArtifactsDir := TestProgramsParams.ArtifactsDir + '/';
    end else if (S = '-t') or (S = '--timeout') then begin
      if not TryGetParam(I, S, TestProgramsParams.TimeOut) then
        Exit(False);
    end else if (S = '-C') or (S = '--nocolors') then begin
      UseColors := False;
    end else if (S = '-f') or (S = '--force-rerun') then begin
      TestProgramsParams.ForceRerun := True;
    end else if (S = '-r') or (S = '--regex') then begin
      if not TryGetParam(I, S, TestProgramsParams.RegEx) then
        Exit(False);
    end else if (S = '-v') or (S = '--verbose') then begin
      EnabledVerbose := True;
    end else if (S = '-p') or (S = '--disable-progress') then begin
      TestProgramsParams.DisableProgressLine := True;
    end else if (S = '-P') or (S = '--enable-progress') then begin
      TestProgramsParams.EnableProgressLine := True;
    end else if S = '--colors' then begin
      UseColors := True;
    end else if (S = '--diff') then begin
      TestProgramsParams.DiffMode := True;
      if not TryGetParam(I, S, TestProgramsParams.DiffLeft) then
        Exit(False);
      if not TryGetParam(I, S, TestProgramsParams.DiffRight) then
        Exit(False);
      if not TryGetParam(I, S, TestProgramsParams.DiffOut) then
        Exit(False);
    end else if S = '--wait-key' then begin
      TestProgramsParams.WaitKey := True;
    end else if (S = '-S') or (S = '--status-format') then begin
      if not TryGetParam(I, S, TestProgramsParams.StatusFormat) then
        Exit(False);
    end else if S = '--worker-log' then begin
      TestProgramsParams.EnableWorkerLog := True;
    end else begin
      if S[1] = '-' then begin
        PrintError(['unknown command line option ', S]);
        Exit(False);
      end;
      SetLength(TestProgramsParams.Cmds, Length(TestProgramsParams.Cmds) + 1);
      TestProgramsParams.Cmds[High(TestProgramsParams.Cmds)] := S;
    end;
    Inc(I);
  end;
  Exit(True);
end;

procedure PrintUsage;
begin
  PrintLn('Usage: testprograms [option|cmd]*');
  PrintLn('');
  PrintLn('Options:');
  PrintLn('    -h | -? | --help | --usage');
  PrintLn('          Prints this help.');
  PrintLn('    -v | --verbose');
  PrintLn('          Be verbose.');
  PrintLn('    -f | --force-rerun');
  PrintLn('          Forces to rerun the tests.');
  PrintLn('    -l <filename> | --list <filename>');
  PrintLn('          Reads list of commands to run from the specified file,');
  PrintLn('          one command per line.');
  PrintLn('    -c <.ext> | --can <.ext>');
  PrintLn('          Sets extension of canonical files (default: .can).');
  PrintLn('    -C | --nocolors');
  PrintLn('          Disables colourful output.');
  PrintLn('    -t <seconds> | --timeout <seconds>');
  PrintLn('          Timeout for a test.');
  PrintLn('    -d <dir> | --artifacts-dir <dir>');
  PrintLn('          Save all tests artifact in the specified directory.');
  PrintLn('    --diff <left> <right> <result>');
  PrintLn('          Just run internal diff instead of regular pipeline.');
  PrintLn('    -p | --disable-progress');
  PrintLn('    -P | --enable-progress');
  PrintLn('          Disable or enable progress line.');
  PrintLn('    --wait-key');
  PrintLn('          Waits for key pressed by user before exit.');
end;

end.
