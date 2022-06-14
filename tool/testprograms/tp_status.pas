unit tp_status;

//
//  Unit for generating status line.
//

{$MODE FPC}
{$MODESWITCH DEFAULTPARAMETERS}
{$MODESWITCH OUT}
{$MODESWITCH RESULT}

interface

uses
  sysutils,
  testprograms_tasks;

function GenerateStatusLine(Completed: LongInt;
                            CurrentOp: PCommand;
                            const Format: AnsiString): AnsiString;
      //
      //  %% -- just percent
      //  %n -- number of tests
      //  %i -- number of completed tests
      //  %s -- number of succeded tests
      //  %f -- number of failed tests
      //  %p -- percent of completion
      //  %d -- test directory
      //  %c -- current command
      //  %t -- current test
      //  %T -- current test name
      //
      //  Examples (format and possible output):
      //
      //    Format: [%p%%] %d/%c
      //    Status: [ 61%] some/test/dir/prog arg1 arg2 arg3
      //
      //    Format: %s/%n tests succeeded%F{, %f failed}, running... %d/%c
      //    Status: 3/11 tests succeded, 2 failed, running... some/test/dir/prog arg1 arg2 arg3
      //

implementation

function GenerateStatusLine(Completed: LongInt;
                            CurrentOp: PCommand;
                            const Format: AnsiString): AnsiString;
var
  I: LongInt;
  Succeeded, Failed, All: LongInt;
begin
  All := Length(Tasks);
  Succeeded := 0;
  Failed := 0;
  for I := 0 to Completed - 1 do begin
    if not Tasks[I]^.Ok then begin
      Inc(Failed);
    end else
      Inc(Succeeded);
  end;
  Result := '';
  I := 1;
  while I <= Length(Format) do begin
    if Format[I] = '%' then begin
      Inc(I);
      if I <= Length(Format) then begin
        case Format[I] of
          '%': Result := Result + '%';
          'n': Result := Result + IntToStr(All);
          'i': Result := Result + IntToStr(Completed);
          'f': Result := Result + IntToStr(Failed);
          's': Result := Result + IntToStr(Succeeded);
          'p': Result := Result + IntToStr(Round(100 * Completed / All));
        else
          Result := Result + '?';
        end;
        Inc(I);
      end;
    end else begin
      Result := Result + Format[I];
      Inc(I);
    end;
  end;
end;

end.
