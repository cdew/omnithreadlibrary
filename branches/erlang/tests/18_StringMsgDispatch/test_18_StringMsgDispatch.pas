unit test_18_StringMsgDispatch;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ActnList,
  OtlCommon,
  OtlComm,
  OtlTask,
  OtlTaskControl,
  OtlEventMonitor;

type
  TAsyncHello = class(TOmniWorker)
  strict private
    aiMessage: string;
  public
    function  Initialize: boolean; override;
  published
    procedure Change(const data: TOmniValue);
    procedure SendMessage;
    procedure TheAnswer(var sl: TStringList);
  end;

  TfrmTestStringMsgDispatch = class(TForm)
    btnChangeMessage : TButton;
    btnSendObject    : TButton;
    btnStartHello    : TButton;
    btnStopHello     : TButton;
    btnTestInvalidMsg: TButton;
    lbLog            : TListBox;
    OmniEventMonitor1: TOmniEventMonitor;
    procedure btnChangeMessageClick(Sender: TObject);
    procedure btnSendObjectClick(Sender: TObject);
    procedure btnStartHelloClick(Sender: TObject);
    procedure btnStopHelloClick(Sender: TObject);
    procedure btnTestInvalidMsgClick(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: boolean);
    procedure OmniEventMonitor1TaskMessage(const task: IOmniTaskControl);
    procedure OmniEventMonitor1TaskTerminated(const task: IOmniTaskControl);
  strict private
    FHelloTask: IOmniTaskControl;
  end;

var
  frmTestStringMsgDispatch: TfrmTestStringMsgDispatch;

implementation

uses
  DSiWin32;

{$R *.dfm}

{ TfrmTestOTL }

procedure TfrmTestStringMsgDispatch.btnChangeMessageClick(Sender: TObject);
begin
//  FHelloTask.Invoke('Change', 'Random ' + IntToStr(Random(1234)));
  FHelloTask.Invoke(@TAsyncHello.Change, 'Random ' + IntToStr(Random(1234)));
end;

procedure TfrmTestStringMsgDispatch.btnSendObjectClick(Sender: TObject);
var
  sl: TStringList;
begin
  sl := TStringList.Create;
  sl.Text := '42';
  FHelloTask.Invoke(@TAsyncHello.TheAnswer, sl);
end;

procedure TfrmTestStringMsgDispatch.btnStartHelloClick(Sender: TObject);
var
  worker: IOmniWorker;
begin
  worker := TAsyncHello.Create;
  FHelloTask :=
    OmniEventMonitor1.Monitor(CreateTask(worker, 'Hello')).
//    SetTimer(1000, 'SendMessage').
    SetTimer(1000, @TAsyncHello.SendMessage).
    SetParameter('Delay', 1000).
    SetParameter('Message', 'Hello').
    Run;
  btnStartHello.Enabled := false;
  btnChangeMessage.Enabled := true;
  btnSendObject.Enabled := true;
  btnTestInvalidMsg.Enabled := true;
  btnStopHello.Enabled := true;
end;

procedure TfrmTestStringMsgDispatch.btnStopHelloClick(Sender: TObject);
begin
  FHelloTask.Terminate;
  FHelloTask := nil;
end;

procedure TfrmTestStringMsgDispatch.btnTestInvalidMsgClick(Sender: TObject);
begin
  FHelloTask.Invoke('FooBar'); // will fail, FooBar method is not defined
end;

procedure TfrmTestStringMsgDispatch.FormCloseQuery(Sender: TObject; var CanClose:
  boolean);
begin
  if btnStopHello.Enabled then
    btnStopHello.Click;
end;

procedure TfrmTestStringMsgDispatch.OmniEventMonitor1TaskMessage(const task: IOmniTaskControl);
var
  msg: TOmniMessage;
begin
  task.Comm.Receive(msg);
  lbLog.ItemIndex := lbLog.Items.Add(Format('[%d/%s] %d|%s',
    [task.UniqueID, task.Name, msg.msgID, msg.msgData.AsString]));
end;

procedure TfrmTestStringMsgDispatch.OmniEventMonitor1TaskTerminated(const task: IOmniTaskControl);
begin
  lbLog.ItemIndex := lbLog.Items.Add(Format('[%d/%s] Terminated %s',
    [task.UniqueID, task.Name, task.ExitMessage]));
  btnStartHello.Enabled := true;
  btnChangeMessage.Enabled := false;
  btnSendObject.Enabled := false;
  btnTestInvalidMsg.Enabled := false;
  btnStopHello.Enabled := false;
end;

{ TAsyncHello }

procedure TAsyncHello.Change(const data: TOmniValue);
begin
  aiMessage := data;
end;

function TAsyncHello.Initialize: boolean;
begin
  aiMessage := Task.ParamByName['Message'];
  Result := true;
end;

procedure TAsyncHello.SendMessage;
begin
  Task.Comm.Send(0, aiMessage);
end;

procedure TAsyncHello.TheAnswer(var sl: TStringList);
begin
  Task.Comm.Send(0, Format('Received %s: %s', [sl.ClassName, sl.Text]));
  FreeAndNil(sl);
end;

initialization
  Randomize;
end.
