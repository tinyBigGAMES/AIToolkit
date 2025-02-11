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

unit AIToolkit.Common;

{$I AIToolkit.Defines.inc}

interface

uses
  WinApi.Windows,
  System.SysUtils,
  System.Classes,
  MemoryDLL,
  AIToolkit.CLibs,
  AIToolkit.Utils;

const
  CatAIToolkitVersion  = '0.1.0';

  CatTavilyApiKeyEnvVar = 'TAVILY_API_KEY';

type

  { TatBaseObject }
  TatBaseObject = class
  public
    constructor Create(); virtual;
    destructor Destroy(); override;
  end;

implementation

uses
  AIToolkit.Console;

{ TatBaseObject }
constructor TatBaseObject.Create();
begin
  inherited;
end;

destructor TatBaseObject.Destroy();
begin
  inherited;
end;

//===========================================================================

var
  CLibsDLLHandle: THandle = 0;

function LoadClibsDLL(var AError: string): Boolean;
var
  LResStream: TResourceStream;

  function bb68520eaec64c5c9fe0ec6c3d19285f(): string;
  const
    CValue = '0703b1ba00e642c69f9c0d9672a607fc';
  begin
    Result := CValue;
  end;

  procedure SetError(const AText: string);
  begin
    AError := AText;
  end;

begin
  Result := False;
  AError := 'Failed to load LuaJIT DLL';

  // load deps DLL
  if CLibsDLLHandle <> 0 then Exit(True);
  try
    if not Boolean((FindResource(HInstance, PChar(bb68520eaec64c5c9fe0ec6c3d19285f()), RT_RCDATA) <> 0)) then
    begin
      SetError('Failed to find Deps DLL resource');
      Exit;
    end;
    LResStream := TResourceStream.Create(HInstance, bb68520eaec64c5c9fe0ec6c3d19285f(), RT_RCDATA);
    try
      CLibsDLLHandle := LoadMemoryDLL(LResStream.Memory, LResStream.Size);
      if CLibsDLLHandle = 0 then
      begin
        SetError('Failed to load extracted Deps DLL: ' + SysErrorMessage(GetLastError));
        Exit;
      end;

      GetExports(CLibsDLLHandle);

      Result := True;
    finally
      LResStream.Free();
    end;
  except
    on E: Exception do
      SetError('Unexpected error: ' + E.Message);
  end;
end;

procedure UnloadCLibsDLL();
begin
  if CLibsDLLHandle <> 0 then
  begin
    FreeLibrary(CLibsDLLHandle);
    CLibsDLLHandle := 0;
  end;
end;

initialization
var
  LError: string;
begin
  ReportMemoryLeaksOnShutdown := True;

  if not LoadClibsDLL(LError) then
  begin
    MessageBox(0, PChar(LError), 'Critical Initialization Error', MB_ICONERROR);
    Halt(1); // Exit the application with a non-zero exit code to indicate failure
  end;

  atUtils.UnitInit();
  atConsole.UnitInit();
end;

finalization
begin
  try
    UnloadCLibsDLL();
  except
    on E: Exception do
    begin
      MessageBox(0, PChar(E.Message), 'Critical Shutdown Error', MB_ICONERROR);
    end;
  end;
end;

end.
