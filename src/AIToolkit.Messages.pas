{===============================================================================
    _    ___  _____            _  _    _  _ ™
   /_\  |_ _||_   _| ___  ___ | || |__(_)| |_
  / _ \  | |   | |  / _ \/ _ \| || / /| ||  _|
 /_/ \_\|___|  |_|  \___/\___/|_||_\_\|_| \__|
           AI Construction Set

 Copyright © 2025-present tinyBigGAMES™ LLC
 All Rights Reserved.

 https://github.com/tinyBigGAMES/AIToolkit

 See LICENSE file for license information
===============================================================================}

unit AIToolkit.Messages;

{$I AIToolkit.Defines.inc}

interface

uses
  System.SysUtils,
  System.StrUtils,
  System.Classes,
  AIToolkit.CLibs,
  AIToolkit.Utils,
  AIToolkit.Common;

const
  atSystem    = 'system';
  atUser      = 'user';
  atAssistant = 'assistant';
  atTool      = 'tool';

type

  { TatMessages }
  TatMessages = class(TatBaseObject)
  protected
    FList: TStringList;
    FLastUser: string;
  public
    constructor Create(); override;
    destructor Destroy(); override;
    procedure Clear(); virtual;
    procedure AddRaw(const AContent: string); virtual;
    procedure Add(const ARole, AContent: string); virtual;
    procedure AddEnd(); virtual;
    function  Prompt(): string; virtual;
    function  IsEmpty: Boolean; virtual;
    function  LastUser(): string;
  end;

  { TatMessagesChatML }
  TatMessagesChatML = class(TatMessages)
  public
    procedure Add(const ARole, AContent: string); override;
    procedure AddEnd(); override;
  end;

  { TatMessagesDeepSeekR1 }
  TatMessagesDeepSeekR1 = class(TatMessages)
  public
    procedure Add(const ARole, AContent: string); override;
    procedure AddEnd(); override;
  end;

  { TatMessagesLLaMA }
  TatMessagesLLaMA = class(TatMessages)
  public
    procedure Add(const ARole, AContent: string); override;
    procedure AddEnd(); override;
  end;

implementation

{ TatMessages }
constructor TatMessages.Create();
begin
  inherited;
  FList := TStringList.Create();
end;

destructor TatMessages.Destroy();
begin
  FList.Free();
  inherited;
end;

procedure TatMessages.Clear();
begin
  FList.Clear();
end;

procedure TatMessages.AddRaw(const AContent: string);
var
  LContent: string;
begin
  LContent := AContent.Trim();
  if LContent.IsEmpty then Exit;

  FList.Add(AContent.Trim);
end;

procedure TatMessages.Add(const ARole, AContent: string);
var
  LRole: string;
  LContent: string;
begin
  LRole := ARole.Trim();
  LContent := AContent.Trim();

  if LRole.IsEmpty then Exit;
  if LContent.IsEmpty then Exit;

  if SameText(LRole, 'user') then
  begin
    FLastUser := LContent;
  end;
end;

procedure TatMessages.AddEnd();
begin
end;

function  TatMessages.Prompt(): string;
var
  LItem: string;
begin
  Result := '';
  for LItem in FList do
  begin
    Result := Result + LItem + ' ';
  end;
  Result := Result.Trim();
end;

function  TatMessages.IsEmpty: Boolean;
begin
  Result := Prompt().IsEmpty;
end;

function  TatMessages.LastUser(): string;
begin
  Result := FLastUser;
end;

{ TatMessagesChatML }
procedure TatMessagesChatML.Add(const ARole, AContent: string);
var
  LRole: string;
  LContent: string;
  LMsg: string;
begin
  inherited;

  LRole := ARole.Trim();
  LContent := AContent.Trim();

  if LRole.IsEmpty then Exit;
  if LContent.IsEmpty then Exit;

  if SameText(LRole, atSystem) then
    LMsg := '<|im_start|>system\n' + LContent + '<|im_end|>'
  else
  if SameText(LRole, atUser) then
    LMsg := '<|im_start|>user\n' + LContent + '<|im_end|>'
  else
  if SameText(LRole, atAssistant) then
    LMsg := '<|im_start|>assistant\n' + LContent + '<|im_end|>'
  else
  if SameText(LRole, atTool) then
    LMsg := '<|im_start|>tool\n' + LContent + '<|im_end|>';

  AddRaw(LMsg);
end;

procedure TatMessagesChatML.AddEnd();
var
  LMsg: string;
begin
  inherited;

  LMsg := '<|im_start|>assistant\n';
  AddRaw(LMsg);
end;

{ TatMessagesDeepSeekR1 }
procedure TatMessagesDeepSeekR1.Add(const ARole, AContent: string);
var
  LMsg: string;
  LRole: string;
  LContent: string;
begin
  inherited;

  LRole := ARole.Trim();
  LContent := AContent.Trim();

  if LRole.IsEmpty then Exit;
  if LContent.IsEmpty then Exit;

  if SameText(LRole, atUser) then
    LMsg := '<｜User｜>' + LContent
  else
  if SameText(LRole, atAssistant) then
    LMsg := '<｜Assistant｜>' + LContent + '<｜end▁of▁sentence｜>';

  AddRaw(LMsg);
end;

procedure TatMessagesDeepSeekR1.AddEnd();
begin
  inherited;

  AddRaw('<｜Assistant｜>');
end;

{ TatMessagesLLaMA }
procedure TatMessagesLLaMA.Add(const ARole, AContent: string);
var
  LMsg: string;
  LRole: string;
  LContent: string;
begin
  inherited;

  LRole := ARole.Trim();
  LContent := AContent.Trim();

  if LRole.IsEmpty then Exit;
  if LContent.IsEmpty then Exit;

  if SameText(LRole, atSystem) then
    LMsg := '<|start_header_id|>system<|end_header_id|>' + LContent + '<|eot_id|>'
  else
  if SameText(LRole, atUser) then
    LMsg := '<|start_header_id|>user<|end_header_id|>' + LContent + '<|eot_id|>'
  else
  if SameText(LRole, atAssistant) then
    LMsg := '<|start_header_id|>assistant<|end_header_id|>' + LContent + '<|eot_id|>';

  AddRaw(LMsg);
end;

procedure TatMessagesLLaMA.AddEnd();
begin
  inherited;

  AddRaw('<|start_header_id|>assistant<|end_header_id|>');
end;

end.
