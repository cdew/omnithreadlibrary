object frmOtlParallelExceptions: TfrmOtlParallelExceptions
  Left = 0
  Top = 0
  Caption = 'Exceptions in OtlParallel'
  ClientHeight = 436
  ClientWidth = 635
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  PixelsPerInch = 96
  TextHeight = 13
  object btnAsync: TButton
    Left = 16
    Top = 16
    Width = 75
    Height = 25
    Caption = 'Async'
    Enabled = False
    TabOrder = 0
  end
  object btnFuture1: TButton
    Left = 16
    Top = 144
    Width = 91
    Height = 25
    Caption = 'Future 1'
    TabOrder = 4
    OnClick = btnFuture1Click
  end
  object btnJoin1: TButton
    Left = 16
    Top = 48
    Width = 91
    Height = 25
    Caption = 'Join 1'
    TabOrder = 1
    OnClick = btnJoin1Click
  end
  object btnForeach: TButton
    Left = 16
    Top = 240
    Width = 75
    Height = 25
    Caption = 'ForEach'
    Enabled = False
    TabOrder = 7
  end
  object btnPipeline1: TButton
    Left = 16
    Top = 272
    Width = 91
    Height = 25
    Caption = 'Pipeline 1'
    TabOrder = 8
    OnClick = btnPipeline1Click
  end
  object btnForkJoin: TButton
    Left = 16
    Top = 396
    Width = 75
    Height = 25
    Caption = 'Fork/Join'
    Enabled = False
    TabOrder = 9
  end
  object lbLog: TListBox
    Left = 128
    Top = 0
    Width = 507
    Height = 436
    Align = alRight
    Anchors = [akLeft, akTop, akRight, akBottom]
    ItemHeight = 13
    TabOrder = 10
    ExplicitHeight = 337
  end
  object btnFuture2: TButton
    Left = 16
    Top = 176
    Width = 91
    Height = 25
    Caption = 'Future 2'
    TabOrder = 5
    OnClick = btnFuture2Click
  end
  object btnFuture3: TButton
    Left = 16
    Top = 208
    Width = 91
    Height = 25
    Caption = 'Future 3'
    TabOrder = 6
    OnClick = btnFuture3Click
  end
  object btnJoin2: TButton
    Left = 16
    Top = 80
    Width = 91
    Height = 25
    Caption = 'Join 2'
    TabOrder = 2
    OnClick = btnJoin2Click
  end
  object btnJoin3: TButton
    Left = 16
    Top = 112
    Width = 91
    Height = 25
    Caption = 'Join 3'
    TabOrder = 3
    OnClick = btnJoin3Click
  end
  object btnPipeline2: TButton
    Left = 16
    Top = 303
    Width = 91
    Height = 25
    Caption = 'Pipeline 2'
    TabOrder = 11
    OnClick = btnPipeline2Click
  end
  object btnPipeline3: TButton
    Left = 16
    Top = 334
    Width = 91
    Height = 25
    Caption = 'Pipeline 3'
    TabOrder = 12
    OnClick = btnPipeline3Click
  end
  object btnPipeline4: TButton
    Left = 16
    Top = 365
    Width = 91
    Height = 25
    Caption = 'Pipeline 4'
    TabOrder = 13
    OnClick = btnPipeline4Click
  end
end