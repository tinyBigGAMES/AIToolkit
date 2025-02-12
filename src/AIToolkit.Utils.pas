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

unit AIToolkit.Utils;

{$I AIToolkit.Defines.inc}

interface

uses
  WinApi.Windows,
  System.SysUtils,
  System.IOUtils,
  System.DateUtils,
  System.StrUtils,
  System.Classes,
  System.JSON,
  System.TypInfo,
  System.Rtti,
  System.Net.HttpClient,
  System.Net.URLClient,
  System.NetConsts;

type

  // Custom Attribute to store descriptions for functions and parameters
  atSchemaDescription = class(TCustomAttribute)
  private
    FDescription: string;
  public
    constructor Create(const ADescription: string);
    property Description: string read FDescription;
  end;

  { atUtils }
  atUtils = class
  private
    class constructor Create();
    class destructor Destroy();
  public
    class procedure UnitInit();
    class function  AsUTF8(const AText: string): Pointer; static;
    class function  GetPhysicalProcessorCount(): DWORD; static;
    class function  EnableVirtualTerminalProcessing(): DWORD; static;
    class function  GetEnvVarValue(const AVarName: string): string; static;
    class function  IsStartedFromDelphiIDE(): Boolean; static;
    class procedure ProcessMessages(); static;
    class function  RandomRange(const AMin, AMax: Integer): Integer; static;
    class function  RandomRangef(const AMin, AMax: Single): Single; static;
    class function  RandomBool(): Boolean; static;
    class function  GetRandomSeed(): Integer; static;
    class procedure SetRandomSeed(const AVaLue: Integer); static;
    class procedure Wait(const AMilliseconds: Double); static;
    class function  SanitizeFromJson(const aText: string): string; static;
    class function  SanitizeToJson(const aText: string): string; static;
    class function  GetJsonSchema(const AClass: TClass; const AMethodName: string): string; static;
    class function  GetJsonSchemas(AClass: TClass): string; static;
    class function  CallStaticMethod(const AClass: TClass; const AMethodName: string; const Args: array of TValue): TValue;
    class function  GetISO8601DateTime(): string;
    class function  GetISO8601DateTimeLocal(): string;
    class function  GetLocalDateTime(): string;
    class function  HasEnoughDiskSpace(const AFilePath: string; ARequiredSize: Int64): Boolean;
    class function  TavilyWebSearch(const AAPIKey, AQuery: string): string; static;
  end;

type
  { TatTokenPrintAction }
  TatTokenPrintAction = (tpaWait, tpaAppend, tpaNewline);

  { TatTokenResponse }
  TatTokenResponse = record
  private
    FRaw: string;                  // Full response as is
    FTokens: array of string;      // Actual tokens
    FMaxLineLength: Integer;       // Define confined space, in chars for fixed width font
    FWordBreaks: array of char;    // What is considered a logical word-break
    FLineBreaks: array of char;    // What is considered a logical line-break
    FWords: array of String;       // Response but as array of "words"
    FWord: string;                 // Current word accumulating
    FLine: string;                 // Current line accumulating
    FFinalized: Boolean;           // Know the finalization is done
    FRightMargin: Integer;
    function HandleLineBreaks(const AToken: string): Boolean;
    function SplitWord(const AWord: string; var APrefix, ASuffix: string): Boolean;
    function GetLineLengthMax(): Integer;
  public
    class operator Initialize (out ADest: TatTokenResponse);
    property RightMargin: Integer read FRightMargin;
    property MaxLineLength: Integer read FMaxLineLength;
    function  GetRightMargin(): Integer;
    procedure SetRightMargin(const AMargin: Integer);
    function  GetMaxLineLength(): Integer;
    procedure SetMaxLineLength(const ALength: Integer);
    function AddToken(const aToken: string): TatTokenPrintAction;
    function LastWord(const ATrimLeft: Boolean=False): string;
    function Finalize: Boolean;
    procedure Clear();
  end;

implementation

uses
  AIToolkit.Console;

var
  LMarshaller: TMarshaller;

{ TatSchemaDescription }
constructor atSchemaDescription.Create(const ADescription: string);
begin
  FDescription := ADescription;
end;

{ atUtils }
class constructor atUtils.Create();
begin
  Randomize();
end;

class destructor atUtils.Destroy();
begin
end;

class procedure atUtils.UnitInit();
begin
  // force constructor
end;

class function  atUtils.AsUTF8(const AText: string): Pointer;
begin
  Result := LMarshaller.AsUtf8(AText).ToPointer;
end;

class function atUtils.GetPhysicalProcessorCount(): DWORD;
var
  BufferSize: DWORD;
  Buffer: PSYSTEM_LOGICAL_PROCESSOR_INFORMATION;
  ProcessorInfo: PSYSTEM_LOGICAL_PROCESSOR_INFORMATION;
  Offset: DWORD;
begin
  Result := 0;
  BufferSize := 0;

  // Call GetLogicalProcessorInformation with buffer size set to 0 to get required buffer size
  if not GetLogicalProcessorInformation(nil, BufferSize) and (WinApi.Windows.GetLastError() = ERROR_INSUFFICIENT_BUFFER) then
  begin
    // Allocate buffer
    GetMem(Buffer, BufferSize);
    try
      // Call GetLogicalProcessorInformation again with allocated buffer
      if GetLogicalProcessorInformation(Buffer, BufferSize) then
      begin
        ProcessorInfo := Buffer;
        Offset := 0;

        // Loop through processor information to count physical processors
        while Offset + SizeOf(SYSTEM_LOGICAL_PROCESSOR_INFORMATION) <= BufferSize do
        begin
          if ProcessorInfo.Relationship = RelationProcessorCore then
            Inc(Result);

          Inc(ProcessorInfo);
          Inc(Offset, SizeOf(SYSTEM_LOGICAL_PROCESSOR_INFORMATION));
        end;
      end;
    finally
      FreeMem(Buffer);
    end;
  end;
end;

class function atUtils.EnableVirtualTerminalProcessing(): DWORD;
var
  HOut: THandle;
  LMode: DWORD;
begin
  HOut := GetStdHandle(STD_OUTPUT_HANDLE);
  if HOut = INVALID_HANDLE_VALUE then
  begin
    Result := GetLastError;
    Exit;
  end;

  if not GetConsoleMode(HOut, LMode) then
  begin
    Result := GetLastError;
    Exit;
  end;

  LMode := LMode or ENABLE_VIRTUAL_TERMINAL_PROCESSING;
  if not SetConsoleMode(HOut, LMode) then
  begin
    Result := GetLastError;
    Exit;
  end;

  Result := 0;  // Success
end;

class function atUtils.GetEnvVarValue(const AVarName: string): string;
var
  LBufSize: Integer;
begin
  LBufSize := GetEnvironmentVariable(PChar(AVarName), nil, 0);
  if LBufSize > 0 then
    begin
      SetLength(Result, LBufSize - 1);
      GetEnvironmentVariable(PChar(AVarName), PChar(Result), LBufSize);
    end
  else
    Result := '';
end;

class function atUtils.IsStartedFromDelphiIDE(): Boolean;
begin
  // Check if the IDE environment variable is present
  Result := (GetEnvironmentVariable('BDS') <> '');
end;

class procedure atUtils.ProcessMessages();
var
  LMsg: TMsg;
begin
  while Integer(PeekMessage(LMsg, 0, 0, 0, PM_REMOVE)) <> 0 do
  begin
    TranslateMessage(LMsg);
    DispatchMessage(LMsg);
  end;
end;

function _RandomRange(const aFrom, aTo: Integer): Integer;
var
  LFrom: Integer;
  LTo: Integer;
begin
  LFrom := aFrom;
  LTo := aTo;

  if AFrom > ATo then
    Result := Random(LFrom - LTo) + ATo
  else
    Result := Random(LTo - LFrom) + AFrom;
end;

class function  atUtils.RandomRange(const AMin, AMax: Integer): Integer;
begin
  Result := _RandomRange(AMin, AMax + 1);
end;

class function  atUtils.RandomRangef(const AMin, AMax: Single): Single;
var
  LNum: Single;
begin
  LNum := _RandomRange(0, MaxInt) / MaxInt;
  Result := AMin + (LNum * (AMax - AMin));
end;

class function  atUtils.RandomBool(): Boolean;
begin
  Result := Boolean(_RandomRange(0, 2) = 1);
end;

class function  atUtils.GetRandomSeed(): Integer;
begin
  Result := System.RandSeed;
end;

class procedure atUtils.SetRandomSeed(const AVaLue: Integer);
begin
  System.RandSeed := AVaLue;
end;

class procedure atUtils.Wait(const AMilliseconds: Double);
var
  LFrequency, LStartCount, LCurrentCount: Int64;
  LElapsedTime: Double;
begin
  // Get the high-precision frequency of the system's performance counter
  QueryPerformanceFrequency(LFrequency);

  // Get the starting value of the performance counter
  QueryPerformanceCounter(LStartCount);

  // Convert milliseconds to seconds for precision timing
  repeat
    QueryPerformanceCounter(LCurrentCount);
    LElapsedTime := (LCurrentCount - LStartCount) / LFrequency * 1000.0; // Convert to milliseconds
  until LElapsedTime >= AMilliseconds;
end;

class function  atUtils.SanitizeToJson(const aText: string): string;
var
  i: Integer;
begin
  Result := '';
  for i := 1 to Length(aText) do
  begin
    case aText[i] of
      '\': Result := Result + '\\';
      '"': Result := Result + '\"';
      '/': Result := Result + '\/';
      #8:  Result := Result + '\b';
      #9:  Result := Result + '\t';
      #10: Result := Result + '\n';
      #12: Result := Result + '\f';
      #13: Result := Result + '\r';
      else
        Result := Result + aText[i];
    end;
  end;
  Result := Result;
end;

class function  atUtils.SanitizeFromJson(const aText: string): string;
var
  LText: string;
begin
  LText := aText;
  LText := LText.Replace('\n', #10);
  LText := LText.Replace('\r', #13);
  LText := LText.Replace('\b', #8);
  LText := LText.Replace('\t', #9);
  LText := LText.Replace('\f', #12);
  LText := LText.Replace('\/', '/');
  LText := LText.Replace('\"', '"');
  LText := LText.Replace('\\', '\');
  Result := LText;
end;

// Helper function to map Delphi types to JSON Schema types
function GetJsonType(DelphiType: TRttiType): string;
begin
  if not Assigned(DelphiType) then
    Exit('null');

  case DelphiType.TypeKind of
    tkInteger, tkInt64: Result := 'integer';
    tkFloat: Result := 'number';
    tkChar, tkWChar, tkString, tkLString, tkWString, tkUString: Result := 'string';
    tkEnumeration:
      begin
        if SameText(DelphiType.Name, 'Boolean') then
          Result := 'boolean'
        else
          Result := 'string';
      end;
    tkClass, tkRecord: Result := 'object';
    tkSet, tkDynArray, tkArray: Result := 'array';
  else
    Result := 'unknown';
  end;
end;

class function atUtils.GetJsonSchema(const AClass: TClass; const AMethodName: string): string;
var
  JsonRoot, JsonFunction, JsonParams, JsonProperties, JsonParamObj: TJSONObject;
  RequiredArray: TJSONArray;
  Context: TRttiContext;
  RttiType: TRttiType;
  Method: TRttiMethod;
  Param: TRttiParameter;
  Attr: TCustomAttribute;
  ParamDescription: string;
begin
  Result := '';
  Context := TRttiContext.Create;
  try
    RttiType := Context.GetType(AClass.ClassInfo);
    if not Assigned(RttiType) then Exit;

    Method := RttiType.GetMethod(AMethodName);
    if not Assigned(Method) then Exit;

    // Ensure the method is a STATIC method
    if not (Method.MethodKind in [mkClassFunction, mkClassProcedure]) then
      Exit; // Return empty result if it's not a static method

    // Root JSON Object
    JsonRoot := TJSONObject.Create;
    JsonRoot.AddPair('type', 'function');

    // Function JSON Object
    JsonFunction := TJSONObject.Create;
    JsonFunction.AddPair('name', AMethodName);

    // Extract method description (if available)
    for Attr in Method.GetAttributes do
      if Attr is atSchemaDescription then
        JsonFunction.AddPair('description', atSchemaDescription(Attr).Description);

    // Parameter Section
    JsonParams := TJSONObject.Create;
    JsonParams.AddPair('type', 'object');

    JsonProperties := TJSONObject.Create;
    RequiredArray := TJSONArray.Create;

    for Param in Method.GetParameters do
    begin
      JsonParamObj := TJSONObject.Create;
      JsonParamObj.AddPair('type', GetJsonType(Param.ParamType));

      // Extract parameter description (if available)
      ParamDescription := '';
      for Attr in Param.GetAttributes do
        if Attr is atSchemaDescription then
          ParamDescription := atSchemaDescription(Attr).Description;

      if ParamDescription <> '' then
        JsonParamObj.AddPair('description', ParamDescription);

      JsonProperties.AddPair(Param.Name, JsonParamObj);
      RequiredArray.AddElement(TJSONString.Create(Param.Name));
    end;

    JsonParams.AddPair('properties', JsonProperties);
    JsonParams.AddPair('required', RequiredArray);
    JsonFunction.AddPair('parameters', JsonParams);

    // Return Type
    if Assigned(Method.ReturnType) then
      JsonFunction.AddPair('return_type', GetJsonType(Method.ReturnType))
    else
      JsonFunction.AddPair('return_type', 'void');

    JsonRoot.AddPair('function', JsonFunction);

    Result := JsonRoot.Format();
    JsonRoot.Free();

  finally
    Context.Free;
  end;
end;

class function atUtils.CallStaticMethod(const AClass: TClass; const AMethodName: string; const Args: array of TValue): TValue;
var
  Context: TRttiContext;
  RttiType: TRttiType;
  Method: TRttiMethod;
begin
  Context := TRttiContext.Create;
  try
    RttiType := Context.GetType(AClass.ClassInfo);
    if not Assigned(RttiType) then
      raise Exception.Create('Class RTTI not found.');

    Method := RttiType.GetMethod(AMethodName);
    if not Assigned(Method) then
      raise Exception.CreateFmt('Method "%s" not found.', [AMethodName]);

    // Ensure the method is a class method (STATIC method)
    if not (Method.MethodKind in [mkClassFunction, mkClassProcedure]) then
      raise Exception.CreateFmt('Method "%s" is not a static class method.', [AMethodName]);

    // Invoke the method dynamically
    Result := Method.Invoke(nil, Args);
  finally
    Context.Free;
  end;
end;

class function atUtils.GetJsonSchemas(AClass: TClass): string;
var
  JsonRoot, JsonTool: TJSONObject;
  JsonToolsArray: TJSONArray;
  Context: TRttiContext;
  RttiType: TRttiType;
  Method: TRttiMethod;
begin
  Result := '';
  JsonRoot := TJSONObject.Create;
  JsonToolsArray := TJSONArray.Create;
  Context := TRttiContext.Create;
  try
    RttiType := Context.GetType(AClass.ClassInfo);
    if not Assigned(RttiType) then Exit;

    // Loop through all published methods
    for Method in RttiType.GetMethods do
    begin
      // Ensure the method is published and static
      if (Method.Visibility = mvPublished) and
         (Method.MethodKind in [mkClassFunction, mkClassProcedure]) then
      begin
        // Get the JSON schema for the method
        JsonTool := TJSONObject.ParseJSONValue(GetJsonSchema(AClass, Method.Name)) as TJSONObject;
        if Assigned(JsonTool) then
          JsonToolsArray.AddElement(JsonTool);
      end;
    end;

    // Add tools array to the root JSON object
    JsonRoot.AddPair('tools', JsonToolsArray);
    Result := JsonRoot.Format();
    JsonRoot.Free();
  finally
    Context.Free;
  end;
end;

class function atUtils.GetISO8601DateTime(): string;
begin
  Result := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss"Z"', Now);
end;

class function atUtils.GetISO8601DateTimeLocal(): string;
var
  TZI: TTimeZoneInformation;
  Bias, HoursOffset, MinsOffset: Integer;
  TimeZoneStr: string;
begin
  case GetTimeZoneInformation(TZI) of
    TIME_ZONE_ID_STANDARD, TIME_ZONE_ID_DAYLIGHT:
      Bias := TZI.Bias + TZI.DaylightBias; // Adjust for daylight saving time
    else
      Bias := 0; // Default to UTC if timezone is unknown
  end;

  HoursOffset := Abs(Bias) div 60;
  MinsOffset := Abs(Bias) mod 60;

  if Bias = 0 then
    TimeZoneStr := 'Z'
  else
    TimeZoneStr := Format('%s%.2d:%.2d', [IfThen(Bias > 0, '-', '+'), HoursOffset, MinsOffset]);

  Result := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', Now) + TimeZoneStr;
end;

class function atUtils.GetLocalDateTime(): string;
begin
 Result := FormatDateTime('dddd, dd mmmm yyyy hh:nn:ss AM/PM', Now);
end;

class function atUtils.HasEnoughDiskSpace(const AFilePath: string; ARequiredSize: Int64): Boolean;
var
  LFreeAvailable, LTotalSpace, LTotalFree: Int64;
  LDrive: string;
begin
  Result := False;

  // Resolve the absolute path in case of a relative path
  LDrive := ExtractFileDrive(TPath.GetFullPath(AFilePath));

  // If there is no drive letter, use the current drive
  if LDrive = '' then
    LDrive := ExtractFileDrive(TDirectory.GetCurrentDirectory);

  // Ensure drive has a trailing backslash
  if LDrive <> '' then
    LDrive := LDrive + '\';

  if GetDiskFreeSpaceEx(PChar(LDrive), LFreeAvailable, LTotalSpace, @LTotalFree) then
    Result := LFreeAvailable >= ARequiredSize;
end;

class function atUtils.TavilyWebSearch(const AAPIKey, AQuery: string): string;
var
  HttpClient: THTTPClient;
  Response: IHTTPResponse;
  JsonRequest, JsonResponse: TJSONObject;
  StringContent: TStringStream;
  Url: string;
begin
  Result := '';
  HttpClient := THTTPClient.Create;
  try
    // Set the API URL
    Url := 'https://api.tavily.com/search';

    // Create JSON request body
    JsonRequest := TJSONObject.Create;
    try
      JsonRequest.AddPair('api_key', AAPIKey);
      JsonRequest.AddPair('query', AQuery);
      JsonRequest.AddPair('include_answer', 'advanced'); // Include 'include_answer' parameter
      JsonRequest.AddPair('include_answer', True);
      JsonRequest.AddPair('include_images', False);
      JsonRequest.AddPair('include_image_descriptions', False);
      JsonRequest.AddPair('include_raw_content', False);
      JsonRequest.AddPair('max_results', 5);
      JsonRequest.AddPair('include_domains', TJSONArray.Create); // Empty array
      JsonRequest.AddPair('exclude_domains', TJSONArray.Create); // Empty array

      // Convert JSON to string stream
      StringContent := TStringStream.Create(JsonRequest.ToString, TEncoding.UTF8);
      try
        // Set content type to application/json
        HttpClient.ContentType := 'application/json';

        // Perform the POST request
        Response := HttpClient.Post(Url, StringContent);

        // Check if the response is successful
        if Response.StatusCode = 200 then
        begin
          // Parse the JSON response
          JsonResponse := TJSONObject.ParseJSONValue(Response.ContentAsString(TEncoding.UTF8)) as TJSONObject;
          try
            // Extract the 'answer' field from the response
            if JsonResponse.TryGetValue('answer', Result) then
            begin
              // 'Result' now contains the answer from the API
            end
            else
            begin
              raise Exception.Create('The "answer" field is missing in the API response.');
            end;
          finally
            JsonResponse.Free;
          end;
        end
        else
        begin
          raise Exception.CreateFmt('Error: %d - %s', [Response.StatusCode, Response.StatusText]);
        end;
      finally
        StringContent.Free;
      end;
    finally
      JsonRequest.Free;
    end;
  finally
    HttpClient.Free;
  end;
end;

{ TatTokenResponse }
class operator TatTokenResponse.Initialize (out ADest: TatTokenResponse);
var
  LSize: Integer;
begin
  // Defaults
  ADest.FRaw := '';
  SetLength(ADest.FTokens, 0);
  SetLength(ADest.FWordBreaks, 0);
  SetLength(ADest.FLineBreaks, 0);
  SetLength(ADest.FWords, 0);
  ADest.FWord := '';
  ADest.FLine := '';
  ADest.FFinalized := False;
  ADest.FRightMargin := 10;

  // If stream output is sent to a destination without wordwrap,
  // the TatTokenResponse will find wordbreaks and split into lines by full words

  // Stream is tabulated into full words based on these break characters
  // !Syntax requires at least one!
  SetLength(ADest.FWordBreaks, 4);
  ADest.FWordBreaks[0] := ' ';
  ADest.FWordBreaks[1] := '-';
  ADest.FWordBreaks[2] := ',';
  ADest.FWordBreaks[3] := '.';

  // Stream may contain forced line breaks
  // !Syntax requires at least one!
  SetLength(ADest.FLineBreaks, 2);
  ADest.FLineBreaks[0] := #13;
  ADest.FLineBreaks[1] := #10;

  ADest.SetRightMargin(10);

  LSize := 120;
  atConsole.GetSize(@LSize, nil);
  ADest.SetMaxLineLength(LSize);
end;

function TatTokenResponse.AddToken(const aToken: string): TatTokenPrintAction;
var
  LPrefix, LSuffix: string;
begin
  // Keep full original response
  FRaw := FRaw + aToken;                    // As continuous string
  Setlength(FTokens, Length(FTokens)+1);    // Make space
  FTokens[Length(FTokens)-1] := aToken;     // As an array

  // Accumulate "word"
  FWord := FWord + aToken;

  // If stream contains linebreaks, print token out without added linebreaks
  if HandleLineBreaks(aToken) then
    exit(TatTokenPrintAction.tpaAppend)

  // Check if a natural break exists, also split if word is longer than the allowed space
  // and print out token with or without linechange as needed
  else if SplitWord(FWord, LPrefix, LSuffix) or FFinalized then
    begin
      // On last call when Finalized we want access to the line change logic only
      // Bad design (fix on top of a fix) Would be better to separate word slipt and line logic from eachother
      if not FFinalized then
        begin
          Setlength(FWords, Length(FWords)+1);        // Make space
          FWords[Length(FWords)-1] := LPrefix;        // Add new word to array
          FWord := LSuffix;                         // Keep the remainder of the split
        end;

      // Word was split, so there is something that can be printed

      // Need for a new line?
      if Length(FLine) + Length(LastWord) > GetLineLengthMax() then
        begin
          Result  := TatTokenPrintAction.tpaNewline;
          FLine   := LastWord;                  // Reset Line (will be new line and then the word)
        end
      else
        begin
          Result  := TatTokenPrintAction.tpaAppend;
          FLine   := FLine + LastWord;          // Append to the line
        end;
    end
  else
    begin
      Result := TatTokenPrintAction.tpaWait;
    end;
end;

function TatTokenResponse.HandleLineBreaks(const AToken: string): Boolean;
var
  LLetter, LLineBreak: Integer;
begin
  Result := false;

  for LLetter := Length(AToken) downto 1 do                   // We are interested in the last possible linebreak
  begin
    for LLineBReak := 0 to Length(Self.FLineBreaks)-1 do       // Iterate linebreaks
    begin
      if AToken[LLetter] = FLineBreaks[LLineBreak] then        // If linebreak was found
      begin
        // Split into a word by last found linechange (do note the stored word may have more linebreak)
        Setlength(FWords, Length(FWords)+1);                          // Make space
        FWords[Length(FWords)-1] := FWord + LeftStr(AToken, Length(AToken)-LLetter); // Add new word to array

        // In case aToken did not end after last LF
        // Word and new line will have whatever was after the last linebreak
        FWord := RightStr(AToken, Length(AToken)-LLetter);
        FLine := FWord;

        // No need to go further
        exit(true);
      end;
    end;
  end;
end;

function TatTokenResponse.Finalize: Boolean;
begin
  // Buffer may contain something, if so make it into a word
  if FWord <> ''  then
    begin
      Setlength(FWords, Length(FWords)+1);      // Make space
      FWords[Length(FWords)-1] := FWord;        // Add new word to array
      Self.FFinalized := True;                // Remember Finalize was done (affects how last AddToken-call behaves)
      exit(true);
    end
  else
    Result := false;
end;

procedure TatTokenResponse.Clear();
begin
  FRaw := '';
  SetLength(FTokens, 0);
  SetLength(FWords, 0);
  FWord := '';
  FLine := '';
  FFinalized := False;
end;

function TatTokenResponse.LastWord(const ATrimLeft: Boolean): string;
begin
  Result := FWords[Length(FWords)-1];
  if ATrimLeft then
    Result := Result.TrimLeft;
end;

function TatTokenResponse.SplitWord(const AWord: string; var APrefix, ASuffix: string): Boolean;
var
  LLetter, LSeparator: Integer;
begin
  Result := false;

  for LLetter := 1 to Length(AWord) do               // Iterate whole word
  begin
    for LSeparator := 0 to Length(FWordBreaks)-1 do   // Iterate all separating characters
    begin
      if AWord[LLetter] = FWordBreaks[LSeparator] then // check for natural break
      begin
        // Let the world know there's stuff that can be a reason for a line change
        Result := True;

        APrefix := LeftStr(AWord, LLetter);
        ASuffix := RightStr(AWord, Length(AWord)-LLetter);
      end;
    end;
  end;

  // Maybe the word is too long but there was no natural break, then cut it to LineLengthMax
  if Length(AWord) > GetLineLengthMax() then
  begin
    Result := True;
    APrefix := LeftStr(AWord, GetLineLengthMax());
    ASuffix := RightStr(AWord, Length(AWord)-GetLineLengthMax());
  end;
end;

function TatTokenResponse.GetLineLengthMax(): Integer;
begin
  Result := FMaxLineLength - FRightMargin;
end;

function  TatTokenResponse.GetRightMargin(): Integer;
begin
  Result := FRightMargin;
end;

procedure TatTokenResponse.SetRightMargin(const AMargin: Integer);
begin
  FRightMargin := AMargin;
end;

function  TatTokenResponse.GetMaxLineLength(): Integer;
begin
  Result := FMaxLineLength;
end;

procedure TatTokenResponse.SetMaxLineLength(const ALength: Integer);
begin
  FMaxLineLength := ALength;
end;

initialization
begin
  ReportMemoryLeaksOnShutdown := True;
  Randomize();
end;

finalization
begin
end;

end.
