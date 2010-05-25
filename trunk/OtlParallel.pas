///<summary>High-level parallel execution management.
///    Part of the OmniThreadLibrary project. Requires Delphi 2009 or newer.</summary>
///<author>Primoz Gabrijelcic</author>
///<license>
///This software is distributed under the BSD license.
///
///Copyright (c) 2010 Primoz Gabrijelcic
///All rights reserved.
///
///Redistribution and use in source and binary forms, with or without modification,
///are permitted provided that the following conditions are met:
///- Redistributions of source code must retain the above copyright notice, this
///  list of conditions and the following disclaimer.
///- Redistributions in binary form must reproduce the above copyright notice,
///  this list of conditions and the following disclaimer in the documentation
///  and/or other materials provided with the distribution.
///- The name of the Primoz Gabrijelcic may not be used to endorse or promote
///  products derived from this software without specific prior written permission.
///
///THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
///ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
///WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
///DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
///ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
///(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
///LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
///ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
///(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
///SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
///</license>
///<remarks><para>
///   Author            : Primoz Gabrijelcic
///   Creation date     : 2010-01-08
///   Last modification : 2010-01-14
///   Version           : 1.01
///</para><para>
///   History:
///     1.01: 2010-02-02
///       - Implemented ForEach(rangeLow, rangeHigh).
///       - Implemented ForEach.Aggregate.
///       - ForEach optimized for execution on single-core computer.
///       - Implemented Parallel.Join.
///       - Removed Stop method. Loop can be cancelled with a cancellation token.
///     1.0: 2010-01-14
///       - Released.
///</para></remarks>

// http://msdn.microsoft.com/en-us/magazine/cc163340.aspx
// http://blogs.msdn.com/pfxteam/archive/2007/11/29/6558543.aspx
// http://cis.jhu.edu/~dsimcha/parallelFuture.html

(* Things to consider:
  - Probably we need Parallel.Join.MonitorWith or something like that.
*)

unit OtlParallel;

{$IF CompilerVersion >= 21}
  {$DEFINE OTL_ERTTI}
{$IFEND}

interface

// TODO 1 -oPrimoz Gabrijelcic : At least some functionality should work in D2007.
// TODO 1 -oPrimoz Gabrijelcic : Add (primitive!) Execute(method) and Execute(procedure)
// TODO 1 -oPrimoz Gabrijelcic : Check compilation with D2009.
// TODO 5 -oPrimoz Gabrijelcic : Do we need separate thread (or task?) pool for Parallel.For?
// TODO 5 -oPrimoz Gabrijelcic : Simple way to access Parallel.ForEach output? something like "for xxx in Parallel.ForEach(...)..."? Better: Parallel.ForEach.NoWait and use for over the blocking collection. Add a demo.
// TODO 3 -oPrimoz Gabrijelcic : ForEach chaining (output of one ForEach goes into the next ForEach); must have a simple syntax and good task scheduler.
// TODO 3 -oPrimoz Gabrijelcic : Output queueing function (anonymous, same as the delegate enumerator). That has a meaning only if it preserves the input order.
// TODO 3 -oPrimoz Gabrijelcic : Need a 'non blocking' option for the ForEach (and some kind of completion signalisation; maybe nonblocking mode would have to use blocking collection as an output? or is that too restrictive?)
// TODO 3 -oPrimoz Gabrijelcic : Do we need another Int delegate using 'integer' instead of 'int64'?

{ TODO 1 -ogabr : There's no need for the 'Int' version of the delegate - <integer> can handle that
  Actually, it is a nice readability improvement. Could ForEach(range) return
  IOmniParallelLoopt<integer>?
}

uses
  SysUtils,
  {$IFDEF OTL_ERTTI}
  TypInfo,
  RTTI,
  {$ENDIF OTL_ERTTI}
  Generics.Collections,
  OtlCommon,
  OtlSync,
  OtlCollections,
  OtlTask,
  OtlDataManager;

type
  IOmniParallelLoop = interface;
  IOmniParallelLoop<T> = interface;

  TOmniAggregatorDelegate = reference to procedure(var aggregate: TOmniValue; const value: TOmniValue);
  TOmniAggregatorIntDelegate = reference to procedure(var aggregate: int64; value: int64);

  TOmniIteratorDelegate = reference to procedure(const value: TOmniValue);
  TOmniIteratorDelegate<T> = reference to procedure(const value: T);
  TOmniIteratorIntDelegate = reference to procedure(value: int64);

  TOmniIteratorAggregateDelegate = reference to function(const value: TOmniValue): TOmniValue;
  TOmniIteratorAggregateDelegate<T> = reference to function(const value: T): TOmniValue;
  TOmniIteratorAggregateIntDelegate = reference to function(value: int64): int64;
  TOmniIteratorAggregateIntDelegate<T> = reference to function(const value: T): int64;

  TOmniIteratorIntoDelegate = reference to procedure(const value: TOmniValue; var result: TOmniValue);
  TOmniIteratorIntoDelegate<T> = reference to procedure(const value: T; var result: TOmniValue);

  IOmniParallelAggregatorLoop = interface
    function  Execute(loopBody: TOmniIteratorAggregateDelegate): TOmniValue; overload;
    function  Execute(loopBody: TOmniIteratorAggregateIntDelegate): int64; overload;
  end; { IOmniParallelAggregatorLoop }

  IOmniParallelAggregatorLoop<T> = interface
    function  Execute(loopBody: TOmniIteratorAggregateDelegate<T>): TOmniValue; overload;
    function  Execute(loopBody: TOmniIteratorAggregateIntDelegate<T>): TOmniValue; overload;
  end; { IOmniParallelAggregatorLoop<T> }

  IOmniParallelIntoLoop = interface
    procedure Execute(loopBody: TOmniIteratorIntoDelegate);
  end; { IOmniParallelIntoLoop }

  IOmniParallelIntoLoop<T> = interface
    procedure Execute(loopBody: TOmniIteratorIntoDelegate<T>);
  end; { IOmniParallelIntoLoop<T> }

  IOmniParallelIntoNextContinuation = interface
    function  ForEach: IOmniParallelLoop;
  end; { IOmniParallelIntoNextContinuation }

  IOmniParallelIntoNextContinuation<T> = interface
    function  ForEach: IOmniParallelLoop<T>;
  end; { IOmniParallelIntoNextContinuation }

  IOmniParallelIntoNextLoop = interface
    function  Execute(loopBody: TOmniIteratorIntoDelegate): IOmniParallelIntoNextContinuation;
  end; { IOmniParallelIntoNextLoop }

  IOmniParallelIntoNextLoop<T> = interface
    function  Execute(loopBody: TOmniIteratorIntoDelegate<T>): IOmniParallelIntoNextContinuation<T>;
  end; { IOmniParallelIntoNextLoop<T> }

  IOmniParallelEnumerable = interface
    function  GetEnumerator: IOmniValueEnumerator;
  end; { IOmniParallelEnumerable }

  IOmniParallelEnumerateLoop = interface
    function  Execute(loopBody: TOmniIteratorIntoDelegate): IOmniParallelEnumerable;
  end; { IOmniParallelEnumerateLoop }

  IOmniParallelEnumerateLoop<T> = interface
    function  Execute(loopBody: TOmniIteratorIntoDelegate): IOmniParallelEnumerable; { TODO 1 -ogabr : should that be IOmniParallelEnumerable<T> ? }
  end; { IOmniParallelEnumerateLoop<T> }

  IOmniParallelLoop = interface
    function  Aggregate(aggregator: TOmniAggregatorDelegate): IOmniParallelAggregatorLoop; overload;
    function  Aggregate(aggregator: TOmniAggregatorIntDelegate): IOmniParallelAggregatorLoop; overload;
    function  Aggregate(aggregator: TOmniAggregatorDelegate;
      defaultAggregateValue: TOmniValue): IOmniParallelAggregatorLoop; overload;
    function  Aggregate(aggregator: TOmniAggregatorIntDelegate;
      defaultAggregateValue: int64): IOmniParallelAggregatorLoop; overload;
    procedure Execute(loopBody: TOmniIteratorDelegate); overload;
    procedure Execute(loopBody: TOmniIteratorIntDelegate); overload;
    function  CancelWith(const token: IOmniCancellationToken): IOmniParallelLoop;
    function  Enumerate: IOmniParallelEnumerateLoop;
    function  Into(queue: IOmniBlockingCollection): IOmniParallelIntoLoop; { TODO 1 -ogabr : do we need TOmniBlockingCollection overload? }
    function  IntoNext: IOmniParallelIntoNextLoop;
    function  NoWait: IOmniParallelLoop;
    function  NumTasks(taskCount : integer): IOmniParallelLoop;
    function  OnStop(stopCode: TProc): IOmniParallelLoop;
    function  PreserveOrder: IOmniParallelLoop;
  end; { IOmniParallelLoop }

  IOmniParallelLoop<T> = interface
    function  Aggregate(aggregator: TOmniAggregatorDelegate): IOmniParallelAggregatorLoop<T>; overload;
    function  Aggregate(aggregator: TOmniAggregatorDelegate;
      defaultAggregateValue: TOmniValue): IOmniParallelAggregatorLoop<T>; overload;
    procedure Execute(loopBody: TOmniIteratorDelegate<T>); overload;
    function  CancelWith(const token: IOmniCancellationToken): IOmniParallelLoop<T>;
    function  Enumerate: IOmniParallelEnumerateLoop<T>;
    function  Into(queue: IOmniBlockingCollection): IOmniParallelIntoLoop<T>;
    function  IntoNext: IOmniParallelIntoNextLoop<T>;
    function  NoWait: IOmniParallelLoop<T>;
    function  NumTasks(taskCount: integer): IOmniParallelLoop<T>;
    function  OnStop(stopCode: TProc): IOmniParallelLoop<T>;
    function  PreserveOrder: IOmniParallelLoop<T>;
  end; { IOmniParallelLoop<T> }

  TEnumeratorDelegate = reference to function(var next: TOmniValue): boolean;
  TEnumeratorDelegate<T> = reference to function(var next: T): boolean;

  Parallel = class
    class function  ForEach(const enumerable: IOmniValueEnumerable): IOmniParallelLoop; overload;
    class function  ForEach(const enum: IOmniValueEnumerator): IOmniParallelLoop; overload;
    class function  ForEach(const enumerable: IEnumerable): IOmniParallelLoop; overload;
    class function  ForEach(const enum: IEnumerator): IOmniParallelLoop; overload;
    class function  ForEach(const sourceProvider: TOmniSourceProvider): IOmniParallelLoop; overload;
    class function  ForEach(enumerator: TEnumeratorDelegate): IOmniParallelLoop; overload;
    class function  ForEach(low, high: integer; step: integer = 1): IOmniParallelLoop; overload;
    class function  ForEach<T>(const enumerable: IOmniValueEnumerable): IOmniParallelLoop<T>; overload;
    class function  ForEach<T>(const enum: IOmniValueEnumerator): IOmniParallelLoop<T>; overload;
    class function  ForEach<T>(const enumerable: IEnumerable): IOmniParallelLoop<T>; overload;
    class function  ForEach<T>(const enum: IEnumerator): IOmniParallelLoop<T>; overload;
    class function  ForEach<T>(const enumerable: TEnumerable<T>): IOmniParallelLoop<T>; overload;
    class function  ForEach<T>(const enum: TEnumerator<T>): IOmniParallelLoop<T>; overload;
    class function  ForEach<T>(enumerator: TEnumeratorDelegate<T>): IOmniParallelLoop<T>; overload;
    {$IFDEF OTL_ERTTI}
    class function  ForEach(const enumerable: TObject): IOmniParallelLoop; overload;
    class function  ForEach<T>(const enumerable: TObject): IOmniParallelLoop<T>; overload;
    {$ENDIF OTL_ERTTI}
    class procedure Join(const task1, task2: TOmniTaskFunction); overload;
    class procedure Join(const task1, task2: TProc); overload;
    class procedure Join(const tasks: array of TOmniTaskFunction); overload;
    class procedure Join(const tasks: array of TProc); overload;
  end; { Parallel }

  TOmniDelegateEnumerator = class(TOmniValueEnumerator)
  strict private
    odeDelegate: TEnumeratorDelegate;
    odeValue   : TOmniValue;
  public
    constructor Create(delegate: TEnumeratorDelegate);
    function  GetCurrent: TOmniValue; override;
    function  MoveNext: boolean; override;
  end; { TOmniDelegateEnumerator }

  TOmniDelegateEnumerator<T> = class(TOmniValueEnumerator)
  strict private
    odeDelegate: TEnumeratorDelegate<T>;
    odeValue   : T;
  public
    constructor Create(delegate: TEnumeratorDelegate<T>);
    function  GetCurrent: TOmniValue; override;
    function  MoveNext: boolean; override;
  end; { TOmniDelegateEnumerator }

  TOmniParallelLoopBase = class(TInterfacedObject)
  {$IFDEF OTL_ERTTI}
  strict private
    oplDestroy    : TRttiMethod;
    oplEnumerable : TValue;
    oplGetCurrent : TRttiMethod;
    oplMoveNext   : TRttiMethod;
    oplRttiContext: TRttiContext;
  public
    constructor Create(enumerable: TObject); overload;
  {$ENDIF OTL_ERTTI}
  strict private
    oplDelegateEnum     : TOmniDelegateEnumerator;
  private
    oplAggregate        : TOmniValue;
    oplAggregator       : TOmniAggregatorDelegate;
    oplCancellationToken: IOmniCancellationToken;
    oplManagedProvider  : boolean;
    oplNumTasks         : integer;
    oplSourceProvider   : TOmniSourceProvider;
  strict protected
    procedure InternalExecute(loopBody: TOmniIteratorDelegate);
    function  InternalExecuteAggregate(loopBody: TOmniIteratorAggregateDelegate): TOmniValue;
    procedure SetAggregator(aggregator: TOmniAggregatorDelegate; defaultAggregateValue:
      TOmniValue);
    procedure SetCancellationToken(const token: IOmniCancellationToken);
    procedure SetNumTasks(taskCount: integer);
    function  Stopped: boolean; inline;
  public
    constructor Create(const sourceProvider: TOmniSourceProvider; managedProvider: boolean); overload;
    constructor Create(const enumerator: TEnumeratorDelegate); overload;
    destructor  Destroy; override;
  end; { TOmniParallelLoopBase }

  TOmniParallelLoop = class(TOmniParallelLoopBase, IOmniParallelLoop,
                                                   IOmniParallelAggregatorLoop,
                                                   IOmniParallelIntoLoop,
                                                   IOmniParallelIntoNextLoop,
                                                   IOmniParallelIntoNextContinuation,
                                                   IOmniParallelEnumerateLoop,
                                                   IOmniParallelEnumerable)
  public
    function  Aggregate(aggregator: TOmniAggregatorDelegate): IOmniParallelAggregatorLoop; overload;
    function  Aggregate(aggregator: TOmniAggregatorDelegate; defaultAggregateValue: TOmniValue): IOmniParallelAggregatorLoop; overload;
    function  Aggregate(aggregator: TOmniAggregatorIntDelegate): IOmniParallelAggregatorLoop; overload;
    function  Aggregate(aggregator: TOmniAggregatorIntDelegate; defaultAggregateValue: int64): IOmniParallelAggregatorLoop; overload;
    function  CancelWith(const token: IOmniCancellationToken): IOmniParallelLoop;
    function  Enumerate: IOmniParallelEnumerateLoop;
    function  Execute(loopBody: TOmniIteratorAggregateDelegate): TOmniValue; overload;
    function  Execute(loopBody: TOmniIteratorAggregateIntDelegate): int64; overload;
    procedure Execute(loopBody: TOmniIteratorDelegate); overload;
    procedure Execute(loopBody: TOmniIteratorIntDelegate); overload;
    procedure Execute(loopBody: TOmniIteratorIntoDelegate); overload;
    function  ExecuteInto(loopBody: TOmniIteratorIntoDelegate): IOmniParallelIntoNextContinuation;
    function  ExecuteEnum(loopBody: TOmniIteratorIntoDelegate): IOmniParallelEnumerable;
    function  ForEach: IOmniParallelLoop;
    function  GetEnumerator: IOmniValueEnumerator;
    function  Into(queue: IOmniBlockingCollection): IOmniParallelIntoLoop; { TODO 1 -ogabr : do we need TOmniBlockingCollection overload? }
    function  IntoNext: IOmniParallelIntoNextLoop;
    function  NoWait: IOmniParallelLoop;
    function  NumTasks(taskCount: integer): IOmniParallelLoop;
    function  OnStop(stopCode: TProc): IOmniParallelLoop;
    function  PreserveOrder: IOmniParallelLoop;
    function  IOmniParallelIntoNextLoop.Execute = ExecuteInto;
    function  IOmniParallelEnumerateLoop.Execute = ExecuteEnum;
  end; { TOmniParallelLoop }

  TOmniParallelLoop<T> = class(TOmniParallelLoopBase, IOmniParallelLoop<T>,
                                                      IOmniParallelAggregatorLoop<T>,
                                                      IOmniParallelIntoLoop<T>,
                                                      IOmniParallelIntoNextLoop<T>,
                                                      IOmniParallelIntoNextContinuation<T>,
                                                      IOmniParallelEnumerateLoop<T>,
                                                      IOmniParallelEnumerable) { TODO 1 -ogabr : of T? }
  strict private
    oplDelegateEnum: TOmniDelegateEnumerator<T>;
    oplEnumerator  : TEnumerator<T>;
  public
    constructor Create(const enumerator: TEnumeratorDelegate<T>); overload;
    constructor Create(const enumerator: TEnumerator<T>); overload;
    destructor  Destroy; override;
    function  Aggregate(aggregator: TOmniAggregatorDelegate): IOmniParallelAggregatorLoop<T>; overload;
    function  Aggregate(aggregator: TOmniAggregatorDelegate;
      defaultAggregateValue: TOmniValue): IOmniParallelAggregatorLoop<T>; overload;
    function  CancelWith(const token: IOmniCancellationToken): IOmniParallelLoop<T>;
    function  Enumerate: IOmniParallelEnumerateLoop<T>;
    function  Execute(loopBody: TOmniIteratorAggregateDelegate<T>): TOmniValue; overload;
    function  Execute(loopBody: TOmniIteratorAggregateIntDelegate<T>): TOmniValue; overload;
    procedure Execute(loopBody: TOmniIteratorDelegate<T>); overload;
    procedure Execute(loopBody: TOmniIteratorIntoDelegate<T>); overload;
    function  ExecuteInto(loopBody: TOmniIteratorIntoDelegate<T>): IOmniParallelIntoNextContinuation<T>;
    function  ExecuteEnum(loopBody: TOmniIteratorIntoDelegate): IOmniParallelEnumerable;
    function  ForEach: IOmniParallelLoop<T>;
    function  GetEnumerator: IOmniValueEnumerator; { TODO 1 -ogabr : of T? }
    function  Into(queue: IOmniBlockingCollection): IOmniParallelIntoLoop<T>;
    function  IntoNext: IOmniParallelIntoNextLoop<T>;
    function  NoWait: IOmniParallelLoop<T>;
    function  NumTasks(taskCount: integer): IOmniParallelLoop<T>;
    function  OnStop(stopCode: TProc): IOmniParallelLoop<T>;
    function  PreserveOrder: IOmniParallelLoop<T>;
    function  IOmniParallelIntoNextLoop<T>.Execute = ExecuteInto;
    function  IOmniParallelEnumerateLoop<T>.Execute = ExecuteEnum;
  end; { TOmniParallelLoop<T> }

implementation

uses
  Windows,
  GpStuff,
  OtlTaskControl;

{ Parallel }

class function Parallel.ForEach(const enumerable: IOmniValueEnumerable):
  IOmniParallelLoop;
begin
  // Assumes that enumerator's TryTake method is threadsafe!
  Result := Parallel.ForEach(enumerable.GetEnumerator);
end; { Parallel.ForEach }

class function Parallel.ForEach(low, high: integer; step: integer): IOmniParallelLoop;
begin
  Result := TOmniParallelLoop.Create(CreateSourceProvider(low, high, step), true);
end; { Parallel.ForEach }

class function Parallel.ForEach(const enumerable: IEnumerable): IOmniParallelLoop;
begin
  Result := Parallel.ForEach(enumerable.GetEnumerator);
end; { Parallel.ForEach }

class function Parallel.ForEach(const enum: IEnumerator): IOmniParallelLoop;
begin
  Result := TOmniParallelLoop.Create(CreateSourceProvider(enum), true);
end; { Parallel.ForEach }

class function Parallel.ForEach(const sourceProvider: TOmniSourceProvider): IOmniParallelLoop;
begin
  Result := TOmniParallelLoop.Create(sourceProvider, false);
end; { Parallel.ForEach }

class function Parallel.ForEach(const enum: IOmniValueEnumerator): IOmniParallelLoop;
begin
  // Assumes that enumerator's TryTake method is threadsafe!
  Result := TOmniParallelLoop.Create(CreateSourceProvider(enum), true);
end; { Parallel.ForEach }

class function Parallel.ForEach(const enumerable: TObject): IOmniParallelLoop;
begin
  Result := TOmniParallelLoop.Create(enumerable);
end; { Parallel.ForEach }

class function Parallel.ForEach(enumerator: TEnumeratorDelegate): IOmniParallelLoop;
begin
  Result := TOmniParallelLoop.Create(enumerator);
end; { Parallel.ForEach }

class function Parallel.ForEach<T>(const enumerable: IOmniValueEnumerable):
  IOmniParallelLoop<T>;
begin
  // Assumes that enumerator's TryTake method is threadsafe!
  Result := Parallel.ForEach<T>(enumerable.GetEnumerator);
end; { Parallel.ForEach }

class function Parallel.ForEach<T>(const enum: IOmniValueEnumerator):
  IOmniParallelLoop<T>;
begin
  // Assumes that enumerator's TryTake method is threadsafe!
  Result := TOmniParallelLoop<T>.Create(CreateSourceProvider(enum), true);
end; { Parallel.ForEach }

class function Parallel.ForEach<T>(const enumerable: TEnumerable<T>): IOmniParallelLoop<T>;
begin
  Result := Parallel.ForEach<T>(enumerable.GetEnumerator());
end; { Parallel.ForEach }

class function Parallel.ForEach<T>(const enum: TEnumerator<T>): IOmniParallelLoop<T>;
begin
  Result := TOmniParallelLoop<T>.Create(enum);
end; { Parallel.ForEach }

class function Parallel.ForEach<T>(const enumerable: IEnumerable): IOmniParallelLoop<T>;
begin
  Result := Parallel.ForEach<T>(enumerable.GetEnumerator);
end; { Parallel.ForEach }

class function Parallel.ForEach<T>(const enum: IEnumerator): IOmniParallelLoop<T>;
begin
  Result := TOmniParallelLoop<T>.Create(CreateSourceProvider(enum), true );
end; { Parallel.ForEach }

class function Parallel.ForEach<T>(const enumerable: TObject): IOmniParallelLoop<T>;
begin
  Result := TOmniParallelLoop<T>.Create(enumerable);
end; { Parallel.ForEach }

class function Parallel.ForEach<T>(enumerator: TEnumeratorDelegate<T>):
  IOmniParallelLoop<T>;
begin
  Result := TOmniParallelLoop<T>.Create(enumerator);
end; { Parallel.ForEach }

class procedure Parallel.Join(const task1, task2: TOmniTaskFunction);
begin
  Join([task1, task2]);
end; { Parallel.Join }

class procedure Parallel.Join(const tasks: array of TOmniTaskFunction);
var
  countStopped: TOmniResourceCount;
  firstTask   : IOmniTaskControl;
  prevTask    : IOmniTaskControl;
  proc        : TOmniTaskFunction;
  task        : IOmniTaskControl;
begin
  if (Environment.Process.Affinity.Count = 1) or (Length(tasks) = 1) then begin
    prevTask := nil;
    for proc in tasks do begin
      task := CreateTask(proc).Unobserved;
      if assigned(prevTask) then
        prevTask.ChainTo(task);
      prevTask := task;
      if not assigned(firstTask) then
        firstTask := task;
    end;
    if assigned(firstTask) then begin
      firstTask.Run;
      prevTask.WaitFor(INFINITE);
    end;
  end
  else begin
    countStopped := TOmniResourceCount.Create(Length(tasks));
    for proc in tasks do
      CreateTask(
        procedure (const task: IOmniTask) begin
          proc(task);
          countStopped.Allocate;
        end
      ).Unobserved
       .Schedule;
    WaitForSingleObject(countStopped.Handle, INFINITE);
  end;
end; { Parallel.Join }

class procedure Parallel.Join(const task1, task2: TProc);
begin
  Join([task1, task2]);
end; { Parallel.Join }

class procedure Parallel.Join(const tasks: array of TProc);
var
  countStopped: TOmniResourceCount;
  proc        : TProc;
begin
  if (Environment.Process.Affinity.Count = 1) or (Length(tasks) = 1) then begin
    for proc in tasks do
      proc;
  end
  else begin
    countStopped := TOmniResourceCount.Create(Length(tasks));
    for proc in tasks do
      CreateTask(
        procedure (const task: IOmniTask) begin
          proc;
          countStopped.Allocate;
        end
      ).Unobserved
       .Schedule;
    WaitForSingleObject(countStopped.Handle, INFINITE);
  end;
end; { Parallel.Join }

{ TOmniParallelLoopBase }

constructor TOmniParallelLoopBase.Create(const sourceProvider: TOmniSourceProvider;
  managedProvider: boolean);
begin
  inherited Create;
  oplNumTasks := Environment.Process.Affinity.Count;
  oplSourceProvider := sourceProvider;
  oplManagedProvider := managedProvider;
end; { TOmniParallelLoopBase.Create }

{$IFDEF OTL_ERTTI}
constructor TOmniParallelLoopBase.Create(enumerable: TObject);
var
  rm: TRttiMethod;
  rt: TRttiType;
begin
  oplRttiContext := TRttiContext.Create;
  rt := oplRttiContext.GetType(enumerable.ClassType);
  Assert(assigned(rt));
  rm := rt.GetMethod('GetEnumerator');
  Assert(assigned(rm));
  Assert(assigned(rm.ReturnType) and (rm.ReturnType.TypeKind = tkClass));
  oplEnumerable := rm.Invoke(enumerable, []);
  Assert(oplEnumerable.AsObject <> nil);
  rt := oplRttiContext.GetType(oplEnumerable.TypeInfo);
  oplMoveNext := rt.GetMethod('MoveNext');
  Assert(assigned(oplMoveNext));
  Assert((oplMoveNext.ReturnType.TypeKind = tkEnumeration) and SameText(oplMoveNext.ReturnType.Name, 'Boolean'));
  oplGetCurrent := rt.GetMethod('GetCurrent');
  Assert(assigned(oplGetCurrent));
  oplDestroy := rt.GetMethod('Destroy');
  Assert(assigned(oplDestroy));
  Create(
    function (var next: TOmniValue): boolean begin
      Result := oplMoveNext.Invoke(oplEnumerable, []).AsBoolean;
      if Result then
        next := oplGetCurrent.Invoke(oplEnumerable, []);
    end
  );
end; { TOmniParallelLoopBase.Create }

constructor TOmniParallelLoopBase.Create(const enumerator: TEnumeratorDelegate);
begin
  oplDelegateEnum := TOmniDelegateEnumerator.Create(enumerator);
  Create(CreateSourceProvider(oplDelegateEnum), true);
end; { TOmniParallelLoopBase.Create }

{$ENDIF OTL_ERTTI}

destructor TOmniParallelLoopBase.Destroy;
begin
  if oplManagedProvider then
    FreeAndNil(oplSourceProvider);
  FreeAndNil(oplDelegateEnum);
  {$IFDEF OTL_ERTTI}
  if oplEnumerable.AsObject <> nil then begin
    oplDestroy.Invoke(oplEnumerable, []);
    oplRttiContext.Free;
  end;
  {$ENDIF OTL_ERTTI}
  inherited;
end; { TOmniParallelLoopBase.Destroy }

procedure TOmniParallelLoopBase.InternalExecute(loopBody: TOmniIteratorDelegate);
var
  countStopped: IOmniResourceCount;
  dataManager : TOmniDataManager;
  iTask       : integer;
  localQueue  : TOmniLocalQueue;
  value       : TOmniValue;
begin
  if ((oplNumTasks = 1) or (Environment.Thread.Affinity.Count = 1)) then begin
    dataManager := CreateDataManager(oplSourceProvider, oplNumTasks);
    try
      localQueue := dataManager.CreateLocalQueue;
      try
        while (not Stopped) and localQueue.GetNext(value) do
          loopBody(value);
      finally FreeAndNil(localQueue); end;
    finally FreeAndNil(dataManager); end;
  end
  else begin
    // TODO 3 -oPrimoz Gabrijelcic : Replace this with a task pool?
    dataManager := CreateDataManager(oplSourceProvider, oplNumTasks);
    try
      countStopped := TOmniResourceCount.Create(oplNumTasks);
      for iTask := 1 to oplNumTasks do
        CreateTask(
          procedure (const task: IOmniTask)
          var
            localQueue: TOmniLocalQueue;
            value     : TOmniValue;
          begin
            localQueue := dataManager.CreateLocalQueue;
            try
              while (not Stopped) and localQueue.GetNext(value) do
                loopBody(value);
            finally FreeAndNil(localQueue); end;
            countStopped.Allocate;
          end,
          'Parallel.ForEach worker #' + IntToStr(iTask)
        ).Unobserved
         .Schedule;
      WaitForSingleObject(countStopped.Handle, INFINITE);
    finally FreeAndNil(dataManager); end;
  end;
end; { TOmniParallelLoopBase.InternalExecute }

function TOmniParallelLoopBase.InternalExecuteAggregate(loopBody:
  TOmniIteratorAggregateDelegate): TOmniValue;
var
  countStopped : IOmniResourceCount;
  dataManager  : TOmniDataManager;
  iTask        : integer;
  localQueue   : TOmniLocalQueue;
  lockAggregate: IOmniCriticalSection;
  value        : TOmniValue;
begin
  if ((oplNumTasks = 1) or (Environment.Thread.Affinity.Count = 1)) then begin
    dataManager := CreateDataManager(oplSourceProvider, oplNumTasks);
    try
      localQueue := dataManager.CreateLocalQueue;
      try
        while (not Stopped) and localQueue.GetNext(value) do
          oplAggregator(oplAggregate, loopBody(value));
      finally FreeAndNil(localQueue); end;
    finally FreeAndNil(dataManager); end;
    Result := oplAggregate;
  end
  else begin
    countStopped := TOmniResourceCount.Create(oplNumTasks);
    lockAggregate := CreateOmniCriticalSection;
    dataManager := CreateDataManager(oplSourceProvider, oplNumTasks);
    try
      for iTask := 1 to oplNumTasks do
        CreateTask(
          procedure (const task: IOmniTask)
          var
            aggregate : TOmniValue;
            localQueue: TOmniLocalQueue;
            value     : TOmniValue;
          begin
            aggregate := TOmniValue.Null;
            localQueue := dataManager.CreateLocalQueue;
            try
              while (not Stopped) and localQueue.GetNext(value) do
                oplAggregator(aggregate, loopBody(value));
            finally FreeAndNil(localQueue); end;
            task.Lock.Acquire;
            try
              oplAggregator(oplAggregate, aggregate);
            finally task.Lock.Release; end;
            countStopped.Allocate;
          end,
          'Parallel.ForEach worker #' + IntToStr(iTask)
        ).WithLock(lockAggregate)
         .Unobserved
         .Schedule;
      WaitForSingleObject(countStopped.Handle, INFINITE);
    finally FreeAndNil(dataManager); end;
    Result := oplAggregate;
  end;
end; { TOmniParallelLoopBase.InternalExecuteAggregate }

procedure TOmniParallelLoopBase.SetAggregator(aggregator: TOmniAggregatorDelegate;
  defaultAggregateValue: TOmniValue);
begin
  oplAggregator := aggregator;
  oplAggregate := defaultAggregateValue;
end; { TOmniParallelLoopBase.SetAggregator }

procedure TOmniParallelLoopBase.SetCancellationToken(const token: IOmniCancellationToken);
begin
  oplCancellationToken := token;
end; { TOmniParallelLoopBase.SetCancellationToken }

procedure TOmniParallelLoopBase.SetNumTasks(taskCount: integer);
begin
  Assert(taskCount > 0);
  oplNumTasks := taskCount;
end; { TOmniParallelLoopBase.SetNumTasks }

function TOmniParallelLoopBase.Stopped: boolean;
begin
  Result := (assigned(oplCancellationToken) and oplCancellationToken.IsSignaled);
end; { TOmniParallelLoopBase.Stopped }

{ TOmniParallelLoop }

function TOmniParallelLoop.Aggregate(aggregator: TOmniAggregatorDelegate):
  IOmniParallelAggregatorLoop;
begin
  Result := Aggregate(aggregator, TOmniValue.Null);
end; { TOmniParallelLoop.Aggregate }

function TOmniParallelLoop.Aggregate(aggregator: TOmniAggregatorDelegate;
  defaultAggregateValue: TOmniValue): IOmniParallelAggregatorLoop;
begin
  SetAggregator(aggregator, defaultAggregateValue);
  Result := Self;
end; { TOmniParallelLoop.Aggregate }

function TOmniParallelLoop.Aggregate(aggregator: TOmniAggregatorIntDelegate):
  IOmniParallelAggregatorLoop;
begin
  Result := Aggregate(aggregator, 0);
end; { TOmniParallelLoop.Aggregate }

function TOmniParallelLoop.Aggregate(aggregator: TOmniAggregatorIntDelegate;
  defaultAggregateValue: int64): IOmniParallelAggregatorLoop;
begin
  SetAggregator(
    procedure (var aggregate: TOmniValue; const value: TOmniValue)
    var
      aggregateInt: int64;
    begin
      aggregateInt := aggregate.AsInt64;
      aggregator(aggregateInt, value);
      aggregate.AsInt64 := aggregateInt;
    end,
    defaultAggregateValue);
  Result := Self;
end; { TOmniParallelLoop.Aggregate }

function TOmniParallelLoop.CancelWith(const token: IOmniCancellationToken): IOmniParallelLoop;
begin
  SetCancellationToken(token);
  Result := Self;
end; { TOmniParallelLoop.CancelWith }

function TOmniParallelLoop.Enumerate: IOmniParallelEnumerateLoop;
begin
  { TODO 1 -ogabr : implement }
  Result := Self;
end; { TOmniParallelLoop.Enumerate }

function TOmniParallelLoop.Execute(loopBody: TOmniIteratorAggregateDelegate): TOmniValue;
begin
  Result := InternalExecuteAggregate(loopBody);
end; { TOmniParallelLoop.Execute }

function TOmniParallelLoop.Execute(loopBody: TOmniIteratorAggregateIntDelegate): int64;
begin
  Result := Execute(
    function(const value: TOmniValue): TOmniValue
    begin
      Result := loopBody(value);
    end);
end; { TOmniParallelLoop.Execute }

procedure TOmniParallelLoop.Execute(loopBody: TOmniIteratorDelegate);
begin
  InternalExecute(loopBody);
end; { TOmniParallelLoop.Execute }

procedure TOmniParallelLoop.Execute(loopBody: TOmniIteratorIntDelegate);
begin
  Execute(
    procedure (const elem: TOmniValue)
    begin
      loopBody(elem);
    end);
end; { TOmniParallelLoop.Execute }

function TOmniParallelLoop.Into(
  queue: IOmniBlockingCollection): IOmniParallelIntoLoop;
begin
  { TODO 1 -ogabr : implement }
  Result := Self;
end; { TOmniParallelLoop.Into }

function TOmniParallelLoop.IntoNext: IOmniParallelIntoNextLoop;
begin
  { TODO 1 -ogabr : implement }
  Result := Self;
end; { TOmniParallelLoop.IntoNext }

function TOmniParallelLoop.NoWait: IOmniParallelLoop;
begin
  { TODO 1 -ogabr : implement }
  Result := Self;
end; { TOmniParallelLoop.NoWait }

function TOmniParallelLoop.NumTasks(taskCount: integer): IOmniParallelLoop;
begin
  SetNumTasks(taskCount);
  Result := Self;
end; { TOmniParallelLoop.taskCount }

function TOmniParallelLoop.OnStop(stopCode: TProc): IOmniParallelLoop;
begin
  { TODO 1 -ogabr : implement }
  Result := Self;
end; { TOmniParallelLoop.OnStop }

function TOmniParallelLoop.PreserveOrder: IOmniParallelLoop;
begin
  { TODO 1 -ogabr : implement }
  Result := Self;
end; { TOmniParallelLoop.PreserveOrder }

{ TOmniParalleLoop<T> }

constructor TOmniParallelLoop<T>.Create(const enumerator: TEnumeratorDelegate<T>);
begin
  oplDelegateEnum := TOmniDelegateEnumerator<T>.Create(enumerator);
  Create(CreateSourceProvider(oplDelegateEnum), true);
end; { TOmniParallelLoop }

constructor TOmniParallelLoop<T>.Create(const enumerator: TEnumerator<T>);
begin
  oplEnumerator := enumerator;
  Create(
    function(var next: T): boolean
    begin
      Result := oplEnumerator.MoveNext;
      if Result then
        next := oplEnumerator.Current;
    end
  );
end; { TOmniParallelLoop<T>.Create }

destructor TOmniParallelLoop<T>.Destroy;
begin
  if oplManagedProvider then
    FreeAndNil(oplSourceProvider);
  FreeAndNil(oplDelegateEnum);
  FreeAndNil(oplEnumerator);
  inherited;
end; { TOmniParallelLoop }

function TOmniParallelLoop<T>.Aggregate(aggregator: TOmniAggregatorDelegate):
  IOmniParallelAggregatorLoop<T>;
begin
  SetAggregator(aggregator, TOmniValue.Null);
  Result := Self;
end; { TOmniParallelLoop<T>.Aggregate }

function TOmniParallelLoop<T>.Aggregate(aggregator: TOmniAggregatorDelegate;
  defaultAggregateValue: TOmniValue): IOmniParallelAggregatorLoop<T>;
begin
  SetAggregator(aggregator, defaultAggregateValue);
  Result := Self;
end; { TOmniParallelLoop<T>.Aggregate }

function TOmniParallelLoop<T>.CancelWith(const token: IOmniCancellationToken): IOmniParallelLoop<T>;
begin
  SetCancellationToken(token);
  Result := Self;
end; { TOmniParallelLoop<T>.CancelWith }

function TOmniParallelLoop<T>.Execute(loopBody: TOmniIteratorAggregateDelegate<T>): TOmniValue;
begin
  Result := InternalExecuteAggregate(
    function (const value: TOmniValue): TOmniValue
    begin
      Result := loopBody(value.CastAs<T>);
    end
  );
end; { TOmniParallelLoop<T>.Execute }

procedure TOmniParallelLoop<T>.Execute(loopBody: TOmniIteratorDelegate<T>);
begin
  InternalExecute(
    procedure (const value: TOmniValue)
    begin
      loopBody(T(value.AsObject));
    end
  );
end; { TOmniParallelLoop<T>.Execute }

function TOmniParallelLoop<T>.Enumerate: IOmniParallelEnumerateLoop<T>;
begin
  { TODO 1 -ogabr : implement }
  Result := Self;
end; { TOmniParallelLoop<T>.Enumerate }

procedure TOmniParallelLoop<T>.Execute(loopBody: TOmniIteratorIntoDelegate<T>);
begin
  { TODO 1 -ogabr : implement }
end; { TOmniParallelLoop<T>.Execute }

function TOmniParallelLoop<T>.ExecuteEnum(
  loopBody: TOmniIteratorIntoDelegate): IOmniParallelEnumerable;
begin
  { TODO 1 -ogabr : implement }
  Result := Self;
end; { TOmniParallelLoop<T>.ExecuteEnum }

function TOmniParallelLoop<T>.Execute(loopBody: TOmniIteratorAggregateIntDelegate<T>):
  TOmniValue;
begin
  Result := InternalExecuteAggregate(
    function (const value: TOmniValue): TOmniValue
    begin
      Result := loopBody(T(value.AsObject));
    end
  );
end; { TOmniParallelLoop }

function TOmniParallelLoop<T>.ExecuteInto(
  loopBody: TOmniIteratorIntoDelegate<T>): IOmniParallelIntoNextContinuation<T>;
begin
  { TODO 1 -ogabr : implement }
  Result := Self;
end; { TOmniParallelLoop<T>.ExecuteInto }

function TOmniParallelLoop<T>.ForEach: IOmniParallelLoop<T>;
begin
  { TODO 1 -ogabr : implement }
  Result := Self;
end; { TOmniParallelLoop<T>.ForEach }

function TOmniParallelLoop<T>.GetEnumerator: IOmniValueEnumerator;
begin
  { TODO 1 -ogabr : implement }
  Result := nil;
end; { TOmniParallelLoop<T>.GetEnumerator }

function TOmniParallelLoop<T>.Into(
  queue: IOmniBlockingCollection): IOmniParallelIntoLoop<T>;
begin
  { TODO 1 -ogabr : implement }
  Result := Self;
end; { TOmniParallelLoop<T>.Into }

function TOmniParallelLoop<T>.IntoNext: IOmniParallelIntoNextLoop<T>;
begin
  { TODO 1 -ogabr : implement }
  Result := Self;
end; { TOmniParallelLoop<T>.IntoNext }

function TOmniParallelLoop<T>.NoWait: IOmniParallelLoop<T>;
begin
  { TODO 1 -ogabr : implement }
  Result := Self;
end; { TOmniParallelLoop<T>.NoWait }

function TOmniParallelLoop<T>.NumTasks(taskCount: integer): IOmniParallelLoop<T>;
begin
  SetNumTasks(taskCount);
  Result := Self;
end; { TOmniParallelLoop<T>.NumTasks }

function TOmniParallelLoop<T>.OnStop(stopCode: TProc): IOmniParallelLoop<T>;
begin
  { TODO 1 -ogabr : implement }
  Result := Self;
end; { TOmniParallelLoop<T>.OnStop }

function TOmniParallelLoop<T>.PreserveOrder: IOmniParallelLoop<T>;
begin
  { TODO 1 -ogabr : implement }
  Result := Self;
end; { TOmniParallelLoop<T>.PreserveOrder }

procedure TOmniParallelLoop.Execute(loopBody: TOmniIteratorIntoDelegate);
begin
  { TODO 1 -ogabr : implement }
end; { TOmniParallelLoop.Execute }

function TOmniParallelLoop.ExecuteEnum(
  loopBody: TOmniIteratorIntoDelegate): IOmniParallelEnumerable;
begin
  { TODO 1 -ogabr : implement }
  Result := Self;
end; { TOmniParallelLoop.ExecuteEnum }

function TOmniParallelLoop.ExecuteInto(
  loopBody: TOmniIteratorIntoDelegate): IOmniParallelIntoNextContinuation;
begin
  { TODO 1 -ogabr : implement }
  Result := Self;
end; { TOmniParallelLoop.ExecuteInto }

function TOmniParallelLoop.ForEach: IOmniParallelLoop;
begin
  { TODO 1 -ogabr : implement }
  Result := Self;
end; { TOmniParallelLoop.ForEach }

function TOmniParallelLoop.GetEnumerator: IOmniValueEnumerator;
begin
  { TODO 1 -ogabr : implement }
  Result := nil;
end; { TOmniParallelLoop.GetEnumerator }

{ TOmniDelegateEnumerator }

constructor TOmniDelegateEnumerator.Create(delegate: TEnumeratorDelegate);
begin
  odeDelegate := delegate;
end; { TOmniDelegateEnumerator.Create }

function TOmniDelegateEnumerator.GetCurrent: TOmniValue;
begin
  Result := odeValue;
end; { TOmniDelegateEnumerator.GetCurrent }

function TOmniDelegateEnumerator.MoveNext: boolean;
begin
  Result := odeDelegate(odeValue);
end; { TOmniDelegateEnumerator.MoveNext }

{ TOmniDelegateEnumerator<T> }

constructor TOmniDelegateEnumerator<T>.Create(delegate: TEnumeratorDelegate<T>);
begin
  odeDelegate := delegate;
end; { TOmniDelegateEnumerator }

function TOmniDelegateEnumerator<T>.GetCurrent: TOmniValue;
begin
  Result := TOmniValue.CastFrom<T>(odeValue);
end; { TOmniDelegateEnumerator }

function TOmniDelegateEnumerator<T>.MoveNext: boolean;
begin
  Result := odeDelegate(odeValue);
end; { TOmniDelegateEnumerator }

end.