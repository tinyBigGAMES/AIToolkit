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

unit AIToolkit.Inference;

{$I AIToolkit.Defines.inc}

interface

uses
  WinApi.Windows,
  System.SysUtils,
  System.StrUtils,
  System.IOUtils,
  System.Classes,
  System.Math,
  AIToolkit.CLibs,
  AIToolkit.Utils,
  AIToolkit.Common,
  AIToolkit.Messages,
  AIToolkit.Console;

type
  { Events }
  TatEvent          = reference to procedure();
  TatCancelEvent    = reference to function(): Boolean;
  TatNextTokenEvent = reference to procedure(const AToken: string);

  { TatInference }
  TatInference = class(TatBaseObject)
  protected
    FError: string;

    FModel: Pllama_model;
    FModelFilename: string;
    FActive: Boolean;
    FPrompt: string;
    FResponse: string;
    FTokenSpeed: Double;
    FInputTokens: Int32;
    FOutputTokens: Int32;

    FStream: Boolean;

    FTokenResponse: TatTokenResponse;

    FOnNextTokenEvent: TatNextTokenEvent;
    FOnCancelEvent: TatCancelEvent;
    FOnStartEvent: TatEvent;
    FOnEndEvent: TatEvent;

    function  TokenToPiece(const AVocab: Pllama_vocab; const AContext: Pllama_context; const AToken: llama_token; const ASpecial: Boolean): string;
    procedure CalcPerformance(const AContext: Pllama_context);

    procedure OnInfo(const ALevel: Integer; const AText: string); virtual;
    function  OnLoadModelProgress(const AModelFilename: string; const AProgress: Single): Boolean; virtual;
    procedure OnLoadModel(const AModelFilename: string; const ASuccess: Boolean); virtual;

    procedure DoOnNextToken(const AToken: string); virtual;
    procedure OnNextToken(const AToken: string); virtual;
    procedure OnStart(); virtual;
    procedure OnEnd(); virtual;
    function  OnCancel(): Boolean; virtual;

    function  GetTokenRightMargin(): Integer;
    procedure SetTokenRightMargin(const AValue: Integer);
    function  GetTokenMaxLineLength(): Integer;
    procedure SetTokenMaxLineLength(const AValue: Integer);
  public
    constructor Create(); override;
    destructor Destroy(); override;

    procedure SetError(const AText: string; const AArgs: array of const);
    function  GetError(): string;

    function  LoadModel(const AFilename: string; const AMainGPU: Integer=-1; const AGPULayers: Integer=-1): Boolean;
    function  ModelLoaded(): Boolean;
    procedure UnloadModel();

    function  Run(const AMessages: TatMessages; const AMaxContext: Cardinal=1024; const AMaxThreads: Integer=-1): Boolean;
    function  Response(): string;
    procedure Performance(const AlInputTokens: PInteger; AOutputTokens: PInteger; ATokenSpeed: PSingle);
    procedure ClearTokenResponse();

    property  TokenRightMargin: Integer read GetTokenRightMargin write SetTokenRightMargin;
    property  TokenMaxLineLength: Integer read GetTokenMaxLineLength write SetTokenMaxLineLength;

    property  Stream: Boolean read FStream write FStream;

    property  NextTokenEvent: TatNextTokenEvent read FOnNextTokenEvent write FOnNextTokenEvent;
    property  CancelEvent: TatCancelEvent read FOnCancelEvent write FOnCancelEvent;
    property  StartEvent: TatEvent read FOnStartEvent write FOnStartEvent;
    property  EndEvent: TatEvent read FOnEndEvent write FOnEndEvent;
  end;

  { TatInferenceDeepSeekR1 }
  TatInferenceDeepSeekR1 = class(TatInference)
  protected
    FThinking: Boolean;
    FShowThinking: Boolean;
    FOnThinkStartEvent: TatEvent;
    FOnThinkEndEvent: TatEvent;
    procedure OnThinkStart(); virtual;
    procedure OnThinkEnd(); virtual;
    procedure OnNextToken(const AToken: string); override;

  public
    constructor Create(); override;
    destructor Destroy(); override;

    property  Thinking: Boolean read FThinking;
    property  ShowThinking: Boolean read FShowThinking write FShowThinking;
    property  ThinkStartEvent: TatEvent read FOnThinkStartEvent write FOnThinkStartEvent;
    property  ThinkEndEvent: TatEvent read FOnThinkEndEvent write FOnThinkEndEvent;
  end;


implementation

{ TatInference }
function TatInference.TokenToPiece(const AVocab: Pllama_vocab; const AContext: Pllama_context; const AToken: llama_token; const ASpecial: Boolean): string;
var
  LTokens: Int32;
  LCheck: Int32;
  LBuffer: TArray<UTF8Char>;
begin
  try
    SetLength(LBuffer, 9);
    LTokens := llama_token_to_piece(AVocab, AToken, @LBuffer[0], 8, 0, ASpecial);
    if LTokens < 0 then
      begin
        SetLength(LBuffer, (-LTokens)+1);
        LCheck := llama_token_to_piece(AVocab, AToken, @LBuffer[0], -LTokens, 0, ASpecial);
        Assert(LCheck = -LTokens);
        LBuffer[-LTokens] := #0;
      end
    else
      begin
        LBuffer[LTokens] := #0;
      end;
    Result := UTF8ToString(@LBuffer[0]);
  except
    on E: Exception do
    begin
      SetError(E.Message, []);
      Exit;
    end;
  end;
end;

procedure TatInference.CalcPerformance(const AContext: Pllama_context);
var
  LTotalTimeSec: Double;
  APerfData: llama_perf_context_data;
begin
  APerfData := llama_perf_context(AContext);

  // Convert milliseconds to seconds
  LTotalTimeSec := APerfData.t_eval_ms / 1000;

  // Total input tokens (n_p_eval assumed to be input tokens)
  FInputTokens := APerfData.n_p_eval;

  // Total output tokens (n_eval assumed to be output tokens)
  FOutputTokens := APerfData.n_eval;

  // Calculate tokens per second (total tokens / time in seconds)
  if LTotalTimeSec > 0 then
    FTokenSpeed := (FInputTokens + FOutputTokens) / LTotalTimeSec
  else
    FTokenSpeed := 0;
end;

procedure TatInference.OnInfo(const ALevel: Integer; const AText: string);
begin
  //atConsole.Print(AText);
end;

function  TatInference.OnLoadModelProgress(const AModelFilename: string; const AProgress: Single): Boolean;
begin
  Result := True;

  //atConsole.Print(#13+'Loading model "%s" (%3.2f%s)...', [AModelFilename, AProgress*100, '%']);
end;

procedure TatInference.OnLoadModel(const AModelFilename: string; const ASuccess: Boolean);
begin
end;

procedure TatInference.DoOnNextToken(const AToken: string);
var
  LToken: string;
begin
  LToken := AToken;
  FResponse := FResponse + LToken;

  OnNextToken(LToken);
end;

procedure TatInference.OnNextToken(const AToken: string);
begin
  if FStream then
  begin
    if Assigned(FOnNextTokenEvent) then
      FOnNextTokenEvent(AToken)
    else
      atConsole.Print(AToken);
  end;
end;

procedure TatInference.OnStart();
begin
  if Assigned(FOnStartEvent) then
    FOnStartEvent();
end;

procedure TatInference.OnEnd();
begin
  if Assigned(FOnEndEvent) then
    FOnEndEvent();
end;

function  TatInference.OnCancel(): Boolean;
begin
  if Assigned(FOnCancelEvent) then
    Result := FOnCancelEvent()
  else
    Result := Boolean(GetAsyncKeyState(VK_ESCAPE) <> 0);
end;

function  TatInference.GetTokenRightMargin(): Integer;
begin
  Result := FTokenResponse.GetRightMargin();
end;

procedure TatInference.SetTokenRightMargin(const AValue: Integer);
begin
  FTokenResponse.SetRightMargin(AValue);
end;

function  TatInference.GetTokenMaxLineLength(): Integer;
begin
  Result := FTokenResponse.GetMaxLineLength();
end;

procedure TatInference.SetTokenMaxLineLength(const AValue: Integer);
begin
  FTokenResponse.SetMaxLineLength(AValue);
end;

constructor TatInference.Create();
begin
  inherited;
  FTokenResponse.Initialize;
  FStream := True;
end;

destructor TatInference.Destroy();
begin
  UnloadModel();
  inherited;
end;

procedure TatInference.SetError(const AText: string; const AArgs: array of const);
begin
  FError := Format(AText, AArgs);
end;

function  TatInference.GetError(): string;
begin
  Result := FError;
end;

procedure TatInference_CErrCallback(const AText: PUTF8Char; AUserData: Pointer); cdecl;
begin
  //if Assigned(AUserData) then
  //  TatInference(AUserData).OnInfo(GGML_LOG_LEVEL_ERROR, Utf8ToString(AText));
end;

procedure TatInference_LogCallback(ALevel: ggml_log_level; const AText: PUTF8Char; AUserData: Pointer); cdecl;
begin
  if Assigned(AUserData) then
    TatInference(AUserData).OnInfo(ALevel, Utf8ToString(AText));
end;

function TatInference_ProgressCallback(AProgress: single; AUserData: pointer): Boolean; cdecl;
var
  LPhippsAI: TatInference;
begin
  LPhippsAI := AUserData;
  if Assigned(LPhippsAI) then
    Result := LPhippsAI.OnLoadModelProgress(LPhippsAI.FModelFilename, AProgress)
  else
    Result := True;
end;

function  TatInference.LoadModel(const AFilename: string; const AMainGPU: Integer; const AGPULayers: Integer): Boolean;
var
  LModelParams: llama_model_params;
begin
  Result := False;

  if ModelLoaded() then Exit(True);

  FModel := nil;
  FModelFilename := '';
  FActive := False;
  FPrompt := '';
  FResponse := '';
  FTokenSpeed := 0;
  FInputTokens := 0;
  FOutputTokens := 0;

  llama_log_set(TatInference_LogCallback, Self);

  LModelParams := llama_model_default_params();

  LModelParams.progress_callback := TatInference_ProgressCallback;
  LModelParams.progress_callback_user_data := Self;
  LModelParams.main_gpu := AMainGPU;

  if AGPULayers < 0 then
    LModelParams.n_gpu_layers := MaxInt
  else
    LModelParams.n_gpu_layers := AGPULayers;

  FModelFilename := AFilename;
  FModelFilename := FModelFilename.Replace('\', '/');

  FModel := llama_model_load_from_file(atUtils.AsUtf8(FModelFilename), LModelParams);
  if not Assigned(FModel) then
  begin
    OnLoadModel(FModelFilename, False);
    SetError('Failed to load model: "%s"', [FModelFilename]);
    Exit;
  end;
  OnLoadModel(FModelFilename, True);

  Result := True;
end;

function  TatInference.ModelLoaded(): Boolean;
begin
  Result := False;
  if not Assigned(FModel) then Exit;

  Result := True;
end;

procedure TatInference.UnloadModel();
begin
  if not ModelLoaded() then Exit;
  llama_free_model(FModel);

  FModel := nil;
  FModelFilename := '';
  FActive := False;
  FPrompt := '';
  FResponse := '';
  FTokenSpeed := 0;
  FInputTokens := 0;
  FOutputTokens := 0;
end;

function  TatInference.Run(const AMessages: TatMessages; const AMaxContext: Cardinal; const AMaxThreads: Integer): Boolean;
var
  LNumPrompt: Integer;
  LPromptTokens: TArray<llama_token>;
  LCtxParams: llama_context_params;
  LNumPredict: integer;
  LCtx: Pllama_context;
  LSmplrParams: llama_sampler_chain_params;
  LSmplr: Pllama_sampler;
  N: Integer;
  LTokenStr: string;
  LBatch: llama_batch;
  LNewTokenId: llama_token;
  LNumPos: Integer;
  LPrompt: UTF8String;
  LFirstToken: Boolean;
  V: Int32;
  LBuf: array[0..255] of UTF8Char;
  LKey: string;
  LMaxContext: Cardinal;
  LVocab: Pllama_vocab;
begin
  Result := False;

  // check if inference is already runnig
  if FActive then
  begin
    SetError('[%s] Inference already active', ['RunInference']);
    Exit;
  end;

  // check if model not loaded
  if not ModelLoaded() then
  begin
    SetError('[%s] Model not loaded', ['RunInference']);
    Exit;
  end;

  if not AMessages.IsEmpty then
    AMessages.AddEnd();

  FPrompt := AMessages.Prompt();

  if FPrompt.IsEmpty then
  begin
    SetError('Not messages was found', []);
    Exit(False);
  end;

  FActive := True;
  FResponse := '';

  FError := '';
  LFirstToken := True;
  LMaxContext := 0;

  for V := 0 to llama_model_meta_count(FModel)-1 do
  begin
    llama_model_meta_key_by_index(FModel, V, @LBuf[0], length(LBuf));
    LKey := string(LBuf);
    if LKey.Contains('context_length') then
    begin
      llama_model_meta_val_str_by_index(FModel, V, @LBuf[0], length(LBuf));
      LKey := string(LBuf);
      LMaxContext :=  LKey.ToInteger;
      break;
    end;
  end;

  if LMaxContext > 0 then
    LNumPredict := EnsureRange(AMaxContext, 512, LMaxContext)
  else
    LNumPredict := 512;

  LVocab := llama_model_get_vocab(FModel);

  LPrompt := UTF8String(FPrompt);

  LNumPrompt := -llama_tokenize(LVocab, PUTF8Char(LPrompt), Length(LPrompt), nil, 0, true, true);

  SetLength(LPromptTokens, LNumPrompt);

  if llama_tokenize(LVocab, PUTF8Char(LPrompt), Length(LPrompt), @LPromptTokens[0], Length(LPromptTokens), true, true) < 0 then
  begin
    SetError('Failed to tokenize prompt', []);
  end;

  LCtxParams := llama_context_default_params();
  LCtxParams.n_ctx := LNumPrompt + LNumPredict - 1;
  LCtxParams.n_batch := LNumPrompt;
  LCtxParams.no_perf := false;
  if AMaxThreads = -1 then
    LCtxParams.n_threads := atUtils.GetPhysicalProcessorCount()
  else
    LCtxParams.n_threads := EnsureRange(AMaxThreads, 1, atUtils.GetPhysicalProcessorCount());
  LCtxParams.n_threads_batch := LCtxParams.n_threads;
  LCtxParams.flash_attn := False;

  LCtx := llama_new_context_with_model(FModel, LCtxParams);
  if LCtx = nil then
  begin
    SetError('Failed to create inference context', []);
    llama_free_model(FModel);
    exit;
  end;

  LSmplrParams := llama_sampler_chain_default_params();
  LSmplr := llama_sampler_chain_init(LSmplrParams);
  llama_sampler_chain_add(LSmplr, llama_sampler_init_greedy());

  LBatch := llama_batch_get_one(@LPromptTokens[0], Length(LPromptTokens));

  LNumPos := 0;

  FOutputTokens := 0;
  FInputTokens := 0;
  FTokenSpeed := 0;

  OnStart();

  llama_perf_context_reset(LCtx);

  while LNumPos + LBatch.n_tokens < LNumPrompt + LNumPredict do
  begin
    if OnCancel() then Break;

    N := llama_decode(LCtx, LBatch);
    if N <> 0 then
    begin
      SetError('Failed to decode context', []);
      llama_sampler_free(LSmplr);
      llama_free(LCtx);
      llama_free_model(FModel);
      Exit;
    end;

    LNumPos := LNumPos + LBatch.n_tokens;

    LNewTokenId := llama_sampler_sample(LSmplr, LCtx, -1);

    if llama_token_is_eog(LVocab, LNewTokenId) then
    begin
      break;
    end;

    if llama_vocab_is_eog(LVocab, LNewTokenId) then
    begin
      break;
    end;

    LTokenStr := TokenToPiece(LVocab, LCtx, LNewTokenId, false);

    if LFirstToken then
    begin
      LTokenStr := LTokenStr.Trim();
      LFirstToken := False;
    end;

    case FTokenResponse.AddToken(LTokenStr) of
      tpaWait:
      begin
      end;

      tpaAppend:
      begin
        DoOnNextToken(FTokenResponse.LastWord(False));
      end;

      tpaNewline:
      begin
        DoOnNextToken(#10);
        DoOnNextToken(FTokenResponse.LastWord(True));
      end;
    end;

    LBatch := llama_batch_get_one(@LNewTokenId, 1);
  end;

  if FTokenResponse.Finalize then
  begin
    case FTokenResponse.AddToken('') of
      tpaWait:
      begin
      end;

      tpaAppend:
      begin
        DoOnNextToken(FTokenResponse.LastWord(False));
      end;

      tpaNewline:
      begin
        DoOnNextToken(#10);
        DoOnNextToken(FTokenResponse.LastWord(True));
      end;
    end;
  end;

  OnEnd();

  CalcPerformance(LCtx);

  llama_sampler_free(LSmplr);
  llama_free(LCtx);

  FActive := False;
  FTokenResponse.Clear();

  Result := True;
end;

function  TatInference.Response(): string;
begin
  Result := FResponse;
end;

procedure TatInference.Performance(const AlInputTokens: PInteger; AOutputTokens: PInteger; ATokenSpeed: PSingle);
begin
  if Assigned(AlInputTokens) then
    AlInputTokens^ := FInputTokens;

  if Assigned(AOutputTokens) then
    AOutputTokens^ := FOutputTokens;

  if Assigned(ATokenSpeed) then
    ATokenSpeed^ := FTokenSpeed;
end;

procedure TatInference.ClearTokenResponse();
begin
  FTokenResponse.Clear();
end;

{ TatInferenceDeepSeekR1 }
procedure TatInferenceDeepSeekR1.OnNextToken(const AToken: string);
var
  LToken: string;
begin
  LToken := AToken;

  if LToken.StartsWith('<think>') then
    begin
      LToken := '';
      FThinking := True;
      OnThinkStart();
    end
  else
  if LToken.StartsWith('</think>') then
    begin
      LToken := '';
      FThinking := False;
      OnThinkEnd();
    end;

  if FThinking then
  begin
    if not FShowThinking then Exit;
  end;

  inherited OnNextToken(LToken);
end;

procedure TatInferenceDeepSeekR1.OnThinkStart();
begin
  if Assigned(FOnThinkStartEvent) then
    begin
      FOnThinkStartEvent();
    end
  else
    begin
      inherited OnNextToken('<think>'+atCRLF);
    end;
end;

procedure TatInferenceDeepSeekR1.OnThinkEnd();
begin
  if Assigned(FOnThinkEndEvent) then
    begin
      FOnThinkEndEvent();
    end
  else
    begin
      inherited OnNextToken('<think>'+atCRLF);
    end;
end;

constructor TatInferenceDeepSeekR1.Create();
begin
  inherited;
  ShowThinking := True;
end;

destructor TatInferenceDeepSeekR1.Destroy();
begin
  inherited;
end;

initialization
begin
  redirect_cerr_to_callback(TatInference_CErrCallback, nil);
end;

finalization
begin
  restore_cerr();
end;

end.
