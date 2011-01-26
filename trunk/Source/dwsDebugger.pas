{**********************************************************************}
{                                                                      }
{    "The contents of this file are subject to the Mozilla Public      }
{    License Version 1.1 (the "License"); you may not use this         }
{    file except in compliance with the License. You may obtain        }
{    a copy of the License at http://www.mozilla.org/MPL/              }
{                                                                      }
{    Software distributed under the License is distributed on an       }
{    "AS IS" basis, WITHOUT WARRANTY OF ANY KIND, either express       }
{    or implied. See the License for the specific language             }
{    governing rights and limitations under the License.               }
{                                                                      }
{    The Initial Developer of the Original Code is Matthias            }
{    Ackermann. For other initial contributors, see contributors.txt   }
{    Subsequent portions Copyright Creative IT.                        }
{                                                                      }
{    Current maintainer: Eric Grange                                   }
{                                                                      }
{**********************************************************************}
{$I dws.inc}
unit dwsDebugger;

interface

uses
   Classes, SysUtils, dwsExprs, dwsSymbols, dwsXPlatform, dwsCompiler, dwsErrors,
   dwsUtils;

type
   TdwsDebugger = class;

   TOnDebugStartStopEvent = procedure(exec: TdwsExecution) of object;
   TOnDebugEvent = procedure(exec: TdwsExecution; expr: TExprBase) of object;

   // TdwsSimpleDebugger
   //
   TdwsSimpleDebugger = class (TComponent, IUnknown, IDebugger)
      private

      protected
         FOnDebug : TOnDebugEvent;
         FOnStartDebug : TOnDebugStartStopEvent;
         FOnStopDebug : TOnDebugStartStopEvent;
         FOnEnterFunc : TOnDebugEvent;
         FOnLeaveFunc : TOnDebugEvent;

         procedure StartDebug(exec : TdwsExecution); virtual;
         procedure DoDebug(exec : TdwsExecution; expr : TExprBase); virtual;
         procedure StopDebug(exec : TdwsExecution); virtual;
         procedure EnterFunc(exec : TdwsExecution; funcExpr : TExprBase); virtual;
         procedure LeaveFunc(exec : TdwsExecution; funcExpr : TExprBase); virtual;

      public


      published
         property OnDebug : TOnDebugEvent read FOnDebug write FOnDebug;
         property OnDebugStart : TOnDebugStartStopEvent read FOnStartDebug write FOnStartDebug;
         property OnDebugStop : TOnDebugStartStopEvent read FOnStopDebug write FOnStopDebug;
         property OnEnterFunc : TOnDebugEvent read FOnEnterFunc write FOnEnterFunc;
         property OnLeaveFunc : TOnDebugEvent read FOnLeaveFunc write FOnLeaveFunc;
   end;

   TdwsDebuggerState = (dsIdle, dsDebugRun,
                        dsDebugSuspending, dsDebugSuspended, dsDebugResuming,
                        dsDebugDone);

   TdwsDebuggerAction = (daCanBeginDebug, daCanSuspend, daCanStep, daCanResume,
                         daCanEndDebug, daCanEvaluate);
   TdwsDebuggerActions = set of TdwsDebuggerAction;

   TdwsDebuggerMode = (dmMainThread,
                       dmThreadedSynchronize, // not supported (yet)
                       dmThreaded);           // not supported (yet)

   TdwsDebugBeginOption = (dboBeginSuspended);
   TdwsDebugBeginOptions = set of TdwsDebugBeginOption;

   // TdwsDebuggerBreakpoint
   //
   TdwsDebuggerBreakpoint = class
      private
         FLine : Integer;
         FSourceName : String;

      protected

      public
         property Line : Integer read FLine write FLine;
         property SourceName : String read FSourceName write FSourceName;
   end;

   // TdwsDebuggerBreakpoints
   //
   TdwsDebuggerBreakpoints = class (TSortedList<TdwsDebuggerBreakpoint>)
      private
         FDebugger : TdwsDebugger;
         FLookupVar : TdwsDebuggerBreakpoint;

      protected
         function Compare(const item1, item2 : TdwsDebuggerBreakpoint) : Integer; override;

      public
         constructor Create(aDebugger : TdwsDebugger);
         destructor Destroy; override;

         procedure Add(aLine : Integer; const aSourceName : String);

         function BreakpointAt(const scriptPos : TScriptPos) : TdwsDebuggerBreakpoint;

         procedure BreakPointsChanged;

         property Debugger : TdwsDebugger read FDebugger;
   end;

   // TdwsDebuggerSuspendCondition
   //
   TdwsDebuggerSuspendCondition = class
      private
         FDebugger : TdwsDebugger;

      protected
         FParentCondition : TdwsDebuggerSuspendCondition;

      public
         constructor Create(aDebugger : TdwsDebugger);
         destructor Destroy; override;

         function SuspendExecution : Boolean; virtual;

         property Debugger : TdwsDebugger read FDebugger;
         property ParentCondition : TdwsDebuggerSuspendCondition read FParentCondition write FParentCondition;
   end;

   // TdwsDSCBreakpoints
   //
   TdwsDSCBreakpoints = class (TdwsDebuggerSuspendCondition)
      private
         FBitmap : TBits;
         FBreakpoints : TdwsDebuggerBreakpoints;

      public
         constructor Create(aDebugger : TdwsDebugger; breakpointsList : TdwsDebuggerBreakpoints);
         destructor Destroy; override;

         procedure BreakpointsChanged;

         function SuspendExecution : Boolean; override;
   end;

   // TdwsDSCStep
   //
   {: Self-release is automatic on execution suspension }
   TdwsDSCStep = class (TdwsDebuggerSuspendCondition)
      public
         constructor Create(aDebugger : TdwsDebugger);
         destructor Destroy; override;
   end;

   // TdwsDSCStepDetail
   //
   TdwsDSCStepDetail = class (TdwsDSCStep)
      public
         function SuspendExecution : Boolean; override;
   end;

   // TdwsDebugger
   //
   // Work in progres, compiles, but is NOT operational yet
   TdwsDebugger = class (TdwsSimpleDebugger)
      private
         FExecution : IdwsProgramExecution;
         FOnStateChanged : TNotifyEvent;
         FMode : TdwsDebuggerMode;
         FState : TdwsDebuggerState;
         FCurrentExpression : TExprBase;
         FSuspendCondition : TdwsDebuggerSuspendCondition;
         FStepCondition : TdwsDebuggerSuspendCondition;
         FBreakpoints : TdwsDebuggerBreakpoints;
         FBreakpointsCondition : TdwsDSCBreakpoints;
         FLastAutoProcessMessages : Cardinal;

         FParams : TVariantDynArray;
         FBeginOptions : TdwsDebugBeginOptions;

      protected
         procedure StartDebug(exec : TdwsExecution); override;
         procedure DoDebug(exec : TdwsExecution; expr : TExprBase); override;
         procedure StopDebug(exec : TdwsExecution); override;
         procedure EnterFunc(exec : TdwsExecution; funcExpr : TExprBase); override;
         procedure LeaveFunc(exec : TdwsExecution; funcExpr : TExprBase); override;

         procedure StateChanged;
         procedure BreakpointsChanged;

         procedure ExecuteDebug(const notifyStageChanged : TThreadMethod);

         function GetCurrentScriptPos : TScriptPos; inline;

      public
         constructor Create(AOwner: TComponent); override;
         destructor Destroy; override;

         procedure BeginDebug(exec : IdwsProgramExecution);
         procedure EndDebug;

         procedure Suspend;
         procedure Resume;

         procedure StepDetailed;

         procedure ClearSuspendConditions;

         function Evaluate(const expression : String) : IdwsEvaluateExpr;
         function EvaluateAsString(const expression : String) : String;

         function AllowedActions : TdwsDebuggerActions;

         property Execution : IdwsProgramExecution read FExecution;
         property Breakpoints : TdwsDebuggerBreakpoints read FBreakpoints;
         property Params : TVariantDynArray read FParams write FParams;
         property BeginOptions : TdwsDebugBeginOptions read FBeginOptions write FBeginOptions;
         property State : TdwsDebuggerState read FState;

         property CurrentExpression : TExprBase read FCurrentExpression;
         property CurrentScriptPos : TScriptPos read GetCurrentScriptPos;

      published
         property Mode : TdwsDebuggerMode read FMode write FMode default dmMainThread;

         property OnStateChanged : TNotifyEvent read FOnStateChanged write FOnStateChanged;
  end;


// ------------------------------------------------------------------
// ------------------------------------------------------------------
// ------------------------------------------------------------------
implementation
// ------------------------------------------------------------------
// ------------------------------------------------------------------
// ------------------------------------------------------------------

type
   TThreadedDebugger = class (TThread)
      FMain : TdwsDebugger;
      FExec : IdwsProgramExecution;
      constructor Create(exec : IdwsProgramExecution; main : TdwsDebugger);
      destructor Destroy; override;
      procedure Execute; override;
   end;

   TSynchronizedThreadedDebugger = class (TThreadedDebugger, IDebugger)
      function QueryInterface(const IID: TGUID; out Obj): HResult; stdcall;
      function _AddRef: Integer; stdcall;
      function _Release: Integer; stdcall;
      procedure StateChanged;
      procedure StartDebug(exec : TdwsExecution);
      procedure DoDebug(exec : TdwsExecution; expr : TExprBase);
      procedure StopDebug(exec : TdwsExecution);
      procedure EnterFunc(exec : TdwsExecution; funcExpr : TExprBase);
      procedure LeaveFunc(exec : TdwsExecution; funcExpr : TExprBase);
   end;

// ------------------
// ------------------ TThreadedDebugger ------------------
// ------------------

// Create
//
constructor TThreadedDebugger.Create(exec : IdwsProgramExecution; main : TdwsDebugger);
begin
   inherited Create;
   FExec:=exec;
   FMain:=main;
   FreeOnTerminate:=True;
end;

// Destroy
//
destructor TThreadedDebugger.Destroy;
begin
   inherited;
   FExec:=nil;
end;

// Execute
//
procedure TThreadedDebugger.Execute;
begin
   FExec.Debugger:=FMain;
   FMain.ExecuteDebug(FMain.StateChanged);
end;

// ------------------
// ------------------ TSynchronizedThreadedDebugger ------------------
// ------------------

// QueryInterface
//
function TSynchronizedThreadedDebugger.QueryInterface(const IID: TGUID; out Obj): HResult;
begin
   if GetInterface(IID, Obj) then
      Result:=S_OK
   else Result:=E_NOINTERFACE
end;

// _AddRef
//
function TSynchronizedThreadedDebugger._AddRef: Integer;
begin
   Result:=-1;   // -1 indicates no reference counting is taking place
end;

// _Release
//
function TSynchronizedThreadedDebugger._Release: Integer;
begin
   Result:=-1;   // -1 indicates no reference counting is taking place
end;

// StateChanged
//
procedure TSynchronizedThreadedDebugger.StateChanged;
begin
   Synchronize(FMain.StateChanged);
end;

// StartDebug
//
procedure TSynchronizedThreadedDebugger.StartDebug(exec : TdwsExecution);
begin
   Synchronize(procedure begin FMain.StartDebug(exec) end);
end;

// DoDebug
//
procedure TSynchronizedThreadedDebugger.DoDebug(exec : TdwsExecution; expr : TExprBase);
begin
   Synchronize(procedure begin FMain.DoDebug(exec, expr) end);
end;

// StopDebug
//
procedure TSynchronizedThreadedDebugger.StopDebug(exec : TdwsExecution);
begin
   Synchronize(procedure begin FMain.StopDebug(exec) end);
end;

// EnterFunc
//
procedure TSynchronizedThreadedDebugger.EnterFunc(exec : TdwsExecution; funcExpr : TExprBase);
begin
   Synchronize(procedure begin FMain.EnterFunc(exec, funcExpr) end);
end;

// LeaveFunc
//
procedure TSynchronizedThreadedDebugger.LeaveFunc(exec : TdwsExecution; funcExpr : TExprBase);
begin
   Synchronize(procedure begin FMain.LeaveFunc(exec, funcExpr) end);
end;

// ------------------
// ------------------ TdwsSimpleDebugger ------------------
// ------------------

// DoDebug
//
procedure TdwsSimpleDebugger.DoDebug(exec: TdwsExecution; expr: TExprBase);
begin
   if Assigned(FOnDebug) then
      FOnDebug(exec, Expr);
end;

// EnterFunc
//
procedure TdwsSimpleDebugger.EnterFunc(exec: TdwsExecution; funcExpr: TExprBase);
begin
   if Assigned(FOnEnterFunc) then
      if funcExpr is TFuncExprBase then
         FOnEnterFunc(exec, TFuncExprBase(funcExpr));
end;

// LeaveFunc
//
procedure TdwsSimpleDebugger.LeaveFunc(exec: TdwsExecution; funcExpr: TExprBase);
begin
   if Assigned(FOnLeaveFunc) then
      if funcExpr is TFuncExprBase then
         FOnLeaveFunc(exec, TFuncExprBase(funcExpr));
end;

// StartDebug
//
procedure TdwsSimpleDebugger.StartDebug(exec: TdwsExecution);
begin
   if Assigned(FOnStartDebug) then
      FOnStartDebug(exec);
end;

// StopDebug
//
procedure TdwsSimpleDebugger.StopDebug(exec: TdwsExecution);
begin
   if Assigned(FOnStopDebug) then
      FOnStopDebug(exec);
end;

// ------------------
// ------------------ TdwsDebugger ------------------
// ------------------

// Create
//
constructor TdwsDebugger.Create(AOwner: TComponent);
begin
   inherited;
   FMode:=dmMainThread;
   FState:=dsIdle;
   TdwsDebuggerBreakpoints.Create(Self);
end;

// Destroy
//
destructor TdwsDebugger.Destroy;
begin
   if daCanEndDebug in AllowedActions then
      EndDebug;
   ClearSuspendConditions;
   FBreakpoints.Free;
   inherited;
end;

// StateChanged
//
procedure TdwsDebugger.StateChanged;
begin
   if Assigned(FOnStateChanged) then
      FOnStateChanged(Self);
end;

// BeginDebug
//
procedure TdwsDebugger.BeginDebug(exec : IdwsProgramExecution);
begin
   Assert(daCanBeginDebug in AllowedActions, 'BeginDebug not allowed');
   Assert(exec<>nil, 'Execution is nil');

   BreakpointsChanged;
   if dboBeginSuspended in BeginOptions then
      TdwsDSCStepDetail.Create(Self);

   FExecution:=exec;
   case Mode of
      dmMainThread :
         ExecuteDebug(StateChanged);
      dmThreadedSynchronize :
         TSynchronizedThreadedDebugger.Create(exec, Self);
      dmThreaded :
         TThreadedDebugger.Create(exec, Self);
   else
      Assert(False);
   end;
end;

// EndDebug
//
procedure TdwsDebugger.EndDebug;
begin
   Assert(daCanEndDebug in AllowedActions, 'EndDebug not allowed');

   ClearSuspendConditions;
   if not (FState in [dsIdle, dsDebugDone]) then begin
      FExecution.Stop;
      if FState=dsDebugSuspended then
         FState:=dsDebugRun;
      Exit;
   end;

   while FState<>dsDebugDone do
      ProcessApplicationMessages(25);

   FCurrentExpression:=nil;
   FExecution:=nil;
   FState:=dsIdle;

   StateChanged;
end;

// Suspend
//
procedure TdwsDebugger.Suspend;
begin
   Assert(daCanSuspend in AllowedActions, 'Suspend not allowed');

   TdwsDSCStepDetail.Create(Self);
end;

// Resume
//
procedure TdwsDebugger.Resume;
begin
   Assert(daCanResume in AllowedActions, 'Resume not allowed');

   FState:=dsDebugResuming;
end;

// StepDetailed
//
procedure TdwsDebugger.StepDetailed;
begin
   Assert(daCanStep in AllowedActions, 'Suspend not allowed');

   TdwsDSCStepDetail.Create(Self);
   FState:=dsDebugResuming;
end;

// ClearSuspendConditions
//
procedure TdwsDebugger.ClearSuspendConditions;
begin
   while FSuspendCondition<>nil do
      FSuspendCondition.Free;
end;

// BreakpointsChanged
//
procedure TdwsDebugger.BreakpointsChanged;
begin
   if FBreakpointsCondition<>nil then
      FBreakpointsCondition.BreakpointsChanged
   else if FBreakpoints.Count>0 then
      TdwsDSCBreakpoints.Create(Self, FBreakpoints);
end;

// Evaluate
//
function TdwsDebugger.Evaluate(const expression : String) : IdwsEvaluateExpr;
begin
   Assert(daCanEvaluate in AllowedActions, 'Evaluate not allowed');

   Result:=TdwsCompiler.Evaluate(FExecution, expression);
end;

// EvaluateAsString
//
function TdwsDebugger.EvaluateAsString(const expression : String) : String;
var
   expr : IdwsEvaluateExpr;
begin
   try
      expr:=Evaluate(expression);
      try
         Result:='(no result)';
         expr.Expression.EvalAsString(FExecution as TdwsExecution, Result);
      finally
         expr:=nil;
      end;
   except
      on E : Exception do
         Result:=E.Message;
   end;
end;

// AllowedActions
//
function TdwsDebugger.AllowedActions : TdwsDebuggerActions;
begin
   Result:=[];
   if Assigned(FExecution) then begin
      case FState of
         dsDebugRun : begin
            Result:=[daCanSuspend, daCanEndDebug];
            if Mode in [dmMainThread] then
               Include(Result, daCanEvaluate);
         end;
         dsDebugSuspended :
            Result:=[daCanResume, daCanEndDebug, daCanStep, daCanEvaluate];
         dsDebugDone :
            Result:=[daCanEvaluate, daCanEndDebug];
      else
         Assert(False);
      end;
   end else begin
      case FState of
         dsIdle :
            Result:=[daCanBeginDebug, daCanEvaluate];
      end;
   end;
end;

// ExecuteDebug
//
procedure TdwsDebugger.ExecuteDebug(const notifyStageChanged : TThreadMethod);
begin
   FState:=dsDebugRun;
   try
      FExecution.Debugger:=Self;
      try
         notifyStageChanged();
         if Length(FParams)>0 then
            FExecution.ExecuteParam(FParams)
         else FExecution.Execute;
      finally
         FExecution.Debugger:=nil;
      end;
   finally
      FState:=dsDebugDone;
   end;
   notifyStageChanged();
end;

// GetCurrentScriptPos
//
function TdwsDebugger.GetCurrentScriptPos : TScriptPos;
begin
   if FCurrentExpression<>nil then
      Result:=FCurrentExpression.ScriptPos
   else Result:=cNullPos;
end;

// StartDebug
//
procedure TdwsDebugger.StartDebug(exec : TdwsExecution);
begin
   if Assigned(FOnStartDebug) then
      inherited;
end;

// DoDebug
//
procedure TdwsDebugger.DoDebug(exec : TdwsExecution; expr : TExprBase);
var
   ticks : Cardinal;
begin
   FCurrentExpression:=expr;
   if Assigned(FOnDebug) then
      inherited;
   if (FSuspendCondition<>nil) and (FSuspendCondition.SuspendExecution) then begin
      FState:=dsDebugSuspended;
      StateChanged;
      while FState=dsDebugSuspended do
         ProcessApplicationMessages(10);
      if FState=dsDebugResuming then
         FState:=dsDebugRun;
      StateChanged;
   end;
   if Mode=dmMainThread then begin
      ticks:=GetSystemMilliseconds;
      if Cardinal(ticks-FLastAutoProcessMessages)>50 then begin
         FLastAutoProcessMessages:=ticks;
         ProcessApplicationMessages(0);
      end;
   end;
end;

// StopDebug
//
procedure TdwsDebugger.StopDebug(exec : TdwsExecution);
begin
   if Assigned(FOnStopDebug) then
      inherited;
end;

// EnterFunc
//
procedure TdwsDebugger.EnterFunc(exec : TdwsExecution; funcExpr : TExprBase);
begin
   if Assigned(FOnEnterFunc) then
      inherited;
end;

// LeaveFunc
//
procedure TdwsDebugger.LeaveFunc(exec : TdwsExecution; funcExpr : TExprBase);
begin
   if Assigned(FOnLeaveFunc) then
      inherited;
end;


// ------------------
// ------------------ TdwsDebuggerBreakpoints ------------------
// ------------------

// Create
//
constructor TdwsDebuggerBreakpoints.Create(aDebugger : TdwsDebugger);
begin
   inherited Create;
   FDebugger:=aDebugger;
   FDebugger.FBreakpoints:=Self;
   FLookupVar:=TdwsDebuggerBreakpoint.Create;
end;

// Destroy
//
destructor TdwsDebuggerBreakpoints.Destroy;
begin
   FDebugger.FBreakpoints:=nil;
   FLookupVar.Free;
   inherited;
end;

// Add
//
procedure TdwsDebuggerBreakpoints.Add(aLine : Integer; const aSourceName : String);
var
   bp : TdwsDebuggerBreakpoint;
begin
   bp:=TdwsDebuggerBreakpoint.Create;
   bp.Line:=aLine;
   bp.SourceName:=aSourceName;
   inherited Add(bp);
end;

// Compare
//
function TdwsDebuggerBreakpoints.Compare(const item1, item2 : TdwsDebuggerBreakpoint) : Integer;
begin
   Result:=CompareText(item1.SourceName, item2.SourceName);
   if Result=0 then
      Result:=item2.Line-item1.Line;
end;

// BreakpointAt
//
function TdwsDebuggerBreakpoints.BreakpointAt(const scriptPos : TScriptPos) : TdwsDebuggerBreakpoint;
var
   i : Integer;
begin
   FLookupVar.Line:=scriptPos.Line;
   FLookupVar.SourceName:=scriptPos.SourceFile.SourceFile;
   if Find(FLookupVar, i) then
      Result:=Items[i]
   else Result:=nil;
end;

// BreakPointsChanged
//
procedure TdwsDebuggerBreakpoints.BreakPointsChanged;
begin
   Debugger.BreakpointsChanged;
end;

// ------------------
// ------------------ TdwsDebuggerSuspendCondition ------------------
// ------------------

// Create
//
constructor TdwsDebuggerSuspendCondition.Create(aDebugger : TdwsDebugger);
begin
   inherited Create;
   FDebugger:=aDebugger;
   FParentCondition:=aDebugger.FSuspendCondition;
   aDebugger.FSuspendCondition:=Self;
end;

// Destroy
//
destructor TdwsDebuggerSuspendCondition.Destroy;
begin
   FDebugger.FSuspendCondition:=FParentCondition;
   inherited;
end;

// SuspendExecution
//
function TdwsDebuggerSuspendCondition.SuspendExecution : Boolean;
begin
   if Assigned(FParentCondition) then
      Result:=FParentCondition.SuspendExecution
   else Result:=False;
end;

// ------------------
// ------------------ TdwsDSCBreakpoints ------------------
// ------------------

// Create
//
constructor TdwsDSCBreakpoints.Create(aDebugger : TdwsDebugger; breakpointsList : TdwsDebuggerBreakpoints);
begin
   inherited Create(aDebugger);
   FBreakpoints:=breakpointsList;
   FBitmap:=TBits.Create;
   BreakpointsChanged;
end;

// Destroy
//
destructor TdwsDSCBreakpoints.Destroy;
begin
   Debugger.FBreakpointsCondition:=nil;
   FBitmap.Free;
   inherited;
end;

// BreakpointsChanged
//
procedure TdwsDSCBreakpoints.BreakpointsChanged;
var
   i : Integer;
   bp : TdwsDebuggerBreakpoint;
begin
   FBitmap.Size:=0;
   for i:=FBreakpoints.Count-1 downto 0 do begin
      bp:=FBreakpoints[i];
      if FBitmap.Size<=bp.Line then
         FBitmap.Size:=bp.Line+1;
      FBitmap.Bits[bp.Line]:=True;
   end;
end;

// SuspendExecution
//
function TdwsDSCBreakpoints.SuspendExecution : Boolean;
var
   scriptPos : TScriptPos;
begin
   scriptPos:=Debugger.CurrentScriptPos;
   if scriptPos.Line<FBitmap.Size then begin
      if     FBitmap.Bits[scriptPos.Line]
         and (FBreakpoints.BreakpointAt(scriptPos)<>nil) then
         Exit(True);
   end;

   Result:=inherited;
end;

// ------------------
// ------------------ TdwsDSCStep ------------------
// ------------------

// Create
//
constructor TdwsDSCStep.Create(aDebugger : TdwsDebugger);
begin
   inherited;
   aDebugger.FStepCondition.Free;
   aDebugger.FStepCondition:=Self;
end;

// Destroy
//
destructor TdwsDSCStep.Destroy;
begin
   Debugger.FStepCondition:=nil;
   inherited;
end;

// ------------------
// ------------------ TdwsDSCStepDetail ------------------
// ------------------

// SuspendExecution
//
function TdwsDSCStepDetail.SuspendExecution : Boolean;
begin
   Result:=True;
   Free;
end;


end.
