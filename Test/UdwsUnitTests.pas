unit UdwsUnitTests;

interface

uses Classes, SysUtils, TestFrameWork, dwsComp, dwsCompiler, dwsExprs,
   dwsTokenizer, dwsSymbols;

type

   TdwsUnitTests = class (TTestCase)
      private
         FCompiler : TDelphiWebScript;
         FUnit : TdwsUnit;

      public
         procedure SetUp; override;
         procedure TearDown; override;

         procedure DeclareTestFuncs;

         procedure Func1Eval(Info: TProgramInfo);
         procedure FuncOneEval(Info: TProgramInfo);
         procedure FuncOneDotFiveEval(Info: TProgramInfo);
         procedure FuncTrueEval(Info: TProgramInfo);
         procedure FuncIncEval(Info: TProgramInfo);

         procedure FuncExceptionEval(Info: TProgramInfo);

         procedure CompilationExecution(execute : Boolean);

      published

         procedure DesignTimeDisplayValues;
         procedure CompiledDescriptions;

         procedure CompilationNormal;
         procedure CompilationWithMapAndSymbols;
         procedure ExecutionNonOptimized;
         procedure ExecutionOptimized;

         procedure DelphiException;
         procedure DelphiExceptionReRaise;
   end;

   EDelphiException = class (Exception)
   end;

// ------------------------------------------------------------------
// ------------------------------------------------------------------
// ------------------------------------------------------------------
implementation
// ------------------------------------------------------------------
// ------------------------------------------------------------------
// ------------------------------------------------------------------

const
   cFuncsTestsSource =
       'if Func1<>1 then PrintLn(''Func1 failed'');'#13#10
      +'if FuncOne<>''One'' then PrintLn(''FuncOne failed'');'#13#10
      +'if FuncOneDotFive<>1.5 then PrintLn(''FuncOneDotFive failed'');'#13#10
      +'if FuncTrue<>True then PrintLn(''FuncTrue failed'');'#13#10
      ;

type
   TdwsFunctionCracker = class (TdwsFunction)
   end;

// ------------------
// ------------------ TdwsUnitTests ------------------
// ------------------

// SetUp
//
procedure TdwsUnitTests.SetUp;
begin
   FCompiler:=TDelphiWebScript.Create(nil);

   FUnit:=TdwsUnit.Create(nil);
   FUnit.UnitName:='Test';
   FUnit.Script:=FCompiler;

   DeclareTestFuncs;
end;

// TearDown
//
procedure TdwsUnitTests.TearDown;
begin
   FUnit.Free;
   FCompiler.Free;
end;

// DeclareTestFuncs
//
procedure TdwsUnitTests.DeclareTestFuncs;
var
   func : TdwsFunction;
   param : TdwsParameter;
begin
   func:=FUnit.Functions.Add as TdwsFunction;
   func.Name:='Func1';
   func.ResultType:='Integer';
   func.OnEval:=Func1Eval;

   func:=FUnit.Functions.Add as TdwsFunction;
   func.Name:='FuncOne';
   func.ResultType:='String';
   func.OnEval:=FuncOneEval;

   func:=FUnit.Functions.Add as TdwsFunction;
   func.Name:='FuncOneDotFive';
   func.ResultType:='Float';
   func.OnEval:=FuncOneDotFiveEval;

   func:=FUnit.Functions.Add as TdwsFunction;
   func.Name:='FuncTrue';
   func.ResultType:='Boolean';
   func.OnEval:=FuncTrueEval;

   func:=FUnit.Functions.Add as TdwsFunction;
   func.Name:='FuncException';
   func.ResultType:='';
   func.OnEval:=FuncExceptionEval;

   func:=FUnit.Functions.Add as TdwsFunction;
   func.Name:='FuncInc';
   func.ResultType:='Integer';
   func.OnEval:=FuncIncEval;
   param:=func.Parameters.Add as TdwsParameter;
   param.Name:='v';
   param.DataType:='Integer';
end;

// Func1Eval
//
procedure TdwsUnitTests.Func1Eval(Info: TProgramInfo);
begin
   Info.ResultAsInteger:=1;
end;

// FuncOneEval
//
procedure TdwsUnitTests.FuncOneEval(Info: TProgramInfo);
begin
   Info.ResultAsString:='One';
end;

// FuncOneDotFiveEval
//
procedure TdwsUnitTests.FuncOneDotFiveEval(Info: TProgramInfo);
begin
   Info.ResultAsFloat:=1.5;
end;

// FuncTrueEval
//
procedure TdwsUnitTests.FuncTrueEval(Info: TProgramInfo);
begin
   Info.ResultAsBoolean:=True;
end;

// FuncIncEval
//
procedure TdwsUnitTests.FuncIncEval(Info: TProgramInfo);
begin
   Info.ResultAsInteger:=Info.ValueAsInteger['v']+1;
end;

// FuncExceptionEval
//
procedure TdwsUnitTests.FuncExceptionEval(Info: TProgramInfo);
begin
   raise EDelphiException.Create('Hello, Delphi Exception here!');
end;

// CompilationExecution
//
procedure TdwsUnitTests.CompilationExecution(execute : Boolean);
var
   prog : TdwsProgram;
begin
   prog:=FCompiler.Compile(cFuncsTestsSource);
   try
      CheckEquals('', prog.Msgs.AsInfo, 'FuncsTest compile');
      if execute then begin
         prog.Execute;
         CheckEquals('', (prog.Result as TdwsDefaultResult).Text, 'FuncsTest result');
         CheckEquals('', prog.Msgs.AsInfo, 'FuncsTest Msgs');
      end;
   finally
      prog.Free;
   end;
end;

// DesignTimeDisplayValues
//
procedure TdwsUnitTests.DesignTimeDisplayValues;

   function FuncByName(const aName : String) : TdwsFunctionCracker;
   var
      i : Integer;
   begin
      i:=FUnit.Functions.IndexOf(aName);
      Result:=TdwsFunctionCracker(FUnit.Functions.Items[i] as TdwsFunction);
   end;

begin
   CheckEquals('function Func1 : Integer;', FuncByName('Func1').GetDisplayName);
   CheckEquals('function FuncOne : String;', FuncByName('FuncOne').GetDisplayName);
   CheckEquals('function FuncOneDotFive : Float;', FuncByName('FuncOneDotFive').GetDisplayName);
   CheckEquals('function FuncTrue : Boolean;', FuncByName('FuncTrue').GetDisplayName);
   CheckEquals('procedure FuncException;', FuncByName('FuncException').GetDisplayName);
   CheckEquals('function FuncInc(v : Integer) : Integer;', FuncByName('FuncInc').GetDisplayName);
end;

// CompiledDescriptions
//
procedure TdwsUnitTests.CompiledDescriptions;
var
   prog : TdwsProgram;
   sym : TSymbol;
begin
   prog:=FCompiler.Compile('');
   try
      sym:=prog.Table.FindSymbol('Func1');
      CheckEquals('function Func1(): Integer', sym.Description);
      sym:=prog.Table.FindSymbol('FuncOne');
      CheckEquals('function FuncOne(): String', sym.Description);
      sym:=prog.Table.FindSymbol('FuncOneDotFive');
      CheckEquals('function FuncOneDotFive(): Float', sym.Description);
      sym:=prog.Table.FindSymbol('FuncTrue');
      CheckEquals('function FuncTrue(): Boolean', sym.Description);
      sym:=prog.Table.FindSymbol('FuncException');
      CheckEquals('procedure FuncException()', sym.Description);
      sym:=prog.Table.FindSymbol('FuncInc');
      CheckEquals('function FuncInc(v: Integer): Integer', sym.Description);
   finally
      prog.Free;
   end;
end;

// CompilationNormal
//
procedure TdwsUnitTests.CompilationNormal;
begin
   FCompiler.Config.CompilerOptions:=[coOptimize];
   CompilationExecution(False);
end;

// CompilationWithMapAndSymbols
//
procedure TdwsUnitTests.CompilationWithMapAndSymbols;
begin
   FCompiler.Config.CompilerOptions:=[coSymbolDictionary, coContextMap];
   CompilationExecution(False);
end;

// ExecutionNonOptimized
//
procedure TdwsUnitTests.ExecutionNonOptimized;
begin
   FCompiler.Config.CompilerOptions:=[];
   CompilationExecution(True);
end;

// ExecutionOptimized
//
procedure TdwsUnitTests.ExecutionOptimized;
begin
   FCompiler.Config.CompilerOptions:=[coOptimize];
   CompilationExecution(True);
end;

// DelphiException
//
procedure TdwsUnitTests.DelphiException;
var
   prog : TdwsProgram;
begin
   prog:=FCompiler.Compile('FuncException;');
   try
      CheckEquals('', prog.Msgs.AsInfo, 'Compile');
      prog.Execute;
      CheckEquals('Runtime Error: Hello, Delphi Exception here! [line: 1, column: 1]'#13#10,
                  prog.Msgs.AsInfo, 'Execute Msgs');
   finally
      prog.Free;
   end;
end;

// DelphiExceptionReRaise
//
procedure TdwsUnitTests.DelphiExceptionReRaise;
var
   prog : TdwsProgram;
begin
   prog:=FCompiler.Compile( 'try'#13#10
                           +#9'FuncException;'#13#10
                           +'except'#13#10
                           +#9'raise;'#13#10
                           +'end;'#13#10
                           );
   try
      CheckEquals('', prog.Msgs.AsInfo, 'Compile');
      prog.Execute;
      CheckEquals('Runtime Error: Hello, Delphi Exception here! [line: 2, column: 2]'#13#10,
                  prog.Msgs.AsInfo, 'Execute Msgs');
   finally
      prog.Free;
   end;
end;

// ------------------------------------------------------------------
// ------------------------------------------------------------------
// ------------------------------------------------------------------
initialization
// ------------------------------------------------------------------
// ------------------------------------------------------------------
// ------------------------------------------------------------------

   TestFramework.RegisterTest('dwsUnitTests', TdwsUnitTests.Suite);

end.
