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

unit AIToolkit.Tools;

{$I AIToolkit.Defines.inc}

interface

uses
  System.Rtti,
  System.SysUtils,
  System.Classes,
  System.RegularExpressions,
  System.Generics.Collections,
  AIToolkit.Utils,
  AIToolkit.Common,
  AIToolkit.Messages,
  AIToolkit.Inference;

const

  { CAIToolkit_Reasoning }
  CAIToolkit_Reasoning    = 'C:\LLM\GGUF\deepseek-r1-distill-llama-8b-abliterated-q4_k_m.gguf';

  { CatToolCallPrompt }
  CatToolCallPrompt =
  '''
  The present date and time is: %s

  You are provided with function signatures within `tools` JSON array.

  You may call one or more functions to assist with the user query.

  IMPORTANT: If you know about the use query, just answer it directly and DO NOT USE a tool.

  Available tools:
  [
  %s
  ]

  When requests correspond to these tools, respond by outputting a list of function calls, one per line, in the following structure:
  [func_name1(params_name1=params_value1, params_name2=params_value2...), func_name2(params_name1=params_value1...), func_name3(params...), {additional function calls as needed, one per line}]
  ''';

  { CtaToolResponsePrompt }
  CtaToolResponsePrompt =
  '''
  <question>%s</question>
  <answer>%s</answer>

  Transform the text inside <question></question> into a well-formatted <answer></answer>.

  Output format:
  <answer>
  Transformed text  here
  </answer>
  ''';

type
  { TatParamArg }
  TatParamArg = TPair<string, string>;

  { TatParams }
  TatParams = TDictionary<string, string>;

  { TatToolCall }
  TatToolCall = class
  private
    FFuncName: string;
    FParams: TatParams;
    FClass: TClass;
  public
    constructor Create(const AFuncName: string);
    destructor Destroy(); override;
    procedure SetClass(const AClass: TClass);
    function  GetClass(): TClass;
    property FuncName: string read FFuncName;
    property Params: TatParams read FParams;
  end;

  { TatToolCalls }
  TatToolCalls = TArray<TatToolCall>;

  { TatToolCallEvent }
  TatToolCallEvent = reference to procedure(const AMessages: TatMessages; const AInference: TatInference; const AFunctionCall: TatToolCall);

  { TatTools }
  TatTools = class(TatBaseObject)
  protected type
    TTool = record
      Name: string;
      Schema: string;
      ToolCallEvent: TatToolCallEvent;
      Class_: TClass;
    end;
  protected
    FList: TDictionary<string, TTool>;
  public
    constructor Create(); override;
    destructor Destroy(); override;
    procedure Clear();
    function  Add(const AClass: TClass; const AMethodName: string; const AToolcallEvent: TatToolCallEvent): Boolean;
    function  Count(): Integer;
    function  CallPrompt(): string;
    class function  ResponsePrompt(const AQuestion, AResponse: string): string;
    procedure Call(const AMessages: TatMessages; const AInference: TatInference; const AInput: string);
  end;

{ Routines }
function  atWebSearch(const AQuestion: string): string;
function  atParseToolCalls(const AInput: string): TatToolCalls;
procedure atFreeFunctionCalls(var AFuncCalls: TatToolCalls);

implementation

{ TatToolCall }
constructor TatToolCall.Create(const AFuncName: string);
begin
  FFuncName := AFuncName;
  FParams := TDictionary<string, string>.Create;
end;

destructor TatToolCall.Destroy;
begin
  FParams.Free;
  inherited;
end;

procedure TatToolCall.SetClass(const AClass: TClass);
begin
  FClass := AClass;
end;

function  TatToolCall.GetClass(): TClass;
begin
  Result := FClass;
end;

{ TatTools }
constructor TatTools.Create();
begin
  inherited;
  FList := TDictionary<string, TTool>.Create();
end;

destructor TatTools.Destroy();
begin
  FList.Free();
  inherited;
end;

procedure TatTools.Clear();
begin
  FList.Clear();
end;

function  TatTools.Add(const AClass: TClass; const AMethodName: string; const AToolcallEvent: TatToolCallEvent): Boolean;
var
  LTool: TTool;
begin
  Result := False;

  if not Assigned(AClass) then Exit;
  if AMethodName.IsEmpty then Exit;
  if not Assigned(AToolcallEvent) then Exit;

  LTool := Default(TTool);

  LTool.Schema := atUtils.GetJsonSchema(AClass, AMethodName).Trim();
  if LTool.Schema.IsEmpty then Exit;

  LTool.Name := AMethodName;
  LTool.ToolCallEvent := AToolcallEvent;
  LTool.Class_ := AClass;

  Result := FList.TryAdd(AMethodName, LTool);
end;

function  TatTools.Count(): Integer;
begin
  Result := FList.Count;
end;

function  TatTools.CallPrompt(): string;
var
  LPair: TPair<string, TTool>;
  LSchemes: string;
  I: Integer;
begin
  Result := '';

  LSchemes := '';

  for LPair in FList do
  begin
    LSchemes := LSchemes + LPair.Value.Schema + ',' + #10#13;
  end;

  if LSchemes.EndsWith(','+#10#13) then
  begin
    I := LSchemes.LastIndexOf(','+#10#13);
    LSchemes := LSchemes.Remove(I, 3);
  end;

  Result := Format(CatToolCallPrompt, [atUtils.GetLocalDateTime(), LSchemes]);
end;

class function  TatTools.ResponsePrompt(const AQuestion, AResponse: string): string;
begin
  Result := Format(CtaToolResponsePrompt, [AQuestion, AResponse]);
end;

procedure TatTools.Call(const AMessages: TatMessages; const AInference: TatInference; const AInput: string);
var
  LTool: TTool;
  LToolCalls: TatToolCalls;
  LItem: TatToolCall;
  LToolCall: TatToolCall;
begin
  if not Assigned(AMessages) then Exit;
  if not Assigned(AInference) then Exit;

  if AInput.IsEmpty then Exit;

  LToolCalls := atParseToolCalls(AInput);
  try
    for LItem in LToolCalls do
    begin
      if FList.TryGetValue(LItem.FuncName, LTool) then
      begin
        LToolCall := LItem;
        LToolCall.SetClass(LTool.Class_);
        LTool.ToolCallEvent(AMessages, AInference, LToolCall);
      end;
    end;
  finally
    atFreeFunctionCalls(LToolCalls);
  end;
end;

{ Routines }
function  atParseToolCalls(const AInput: string): TatToolCalls;
var
  LRegex, LParamRegex: TRegEx;
  LMatches, LParamMatches: TMatchCollection;
  LMatch, LParamMatch: TMatch;
  LFuncList: TList<TatToolCall>;
  LFuncCall: TatToolCall;
  LParamStr, LParamKey, LParamValue: string;
  LParams: TStringList;
begin
  LRegex := TRegEx.Create('(\w+)\(([^)]*)\)');
  LParamRegex := TRegEx.Create('(\w+)\s*=\s*"?([^"]+?)"?(?=,|$)');
  LMatches := LRegex.Matches(AInput);
  LFuncList := TList<TatToolCall>.Create;

  for LMatch in LMatches do
  begin
    LFuncCall := TatToolCall.Create(LMatch.Groups[1].Value);
    LParams := TStringList.Create;
    try
      LParamStr := LMatch.Groups[2].Value;
      LParamMatches := LParamRegex.Matches(LParamStr);

  for LParamMatch in LParamMatches do
      begin
        LParamKey := LParamMatch.Groups[1].Value;
        LParamValue := LParamMatch.Groups[2].Value;
        LFuncCall.FParams.Add(LParamKey, LParamValue);
      end;
      LFuncList.Add(LFuncCall);
    except
      LFuncCall.Free;
    end;
    LParams.Free;
  end;

  Result := LFuncList.ToArray;
  LFuncList.Free;
end;

procedure atFreeFunctionCalls(var AFuncCalls: TatToolCalls);
var
  I: Integer;
begin
  for I := Low(AFuncCalls) to High(AFuncCalls) do
    AFuncCalls[I].Free;
  SetLength(AFuncCalls, 0);
end;

function  atWebSearch(const AQuestion: string): string;
  function GetPrompt(const AQuestion, AResponse: string): string;
  begin
    Result := Format(CtaToolResponsePrompt, [AQuestion, AResponse]);
  end;
begin
  Result := TatTools.ResponsePrompt(AQuestion, atUtils.TavilyWebSearch(atUtils.GetEnvVarValue(CatTavilyApiKeyEnvVar).Trim(), AQuestion));
end;

end.
