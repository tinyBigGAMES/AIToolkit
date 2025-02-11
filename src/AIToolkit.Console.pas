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

unit AIToolkit.Console;

{$I AIToolkit.Defines.inc}

interface

uses
  WinApi.Windows,
  WinApi.Messages,
  System.SysUtils,
  AIToolkit.Utils;

const
  atLF   = AnsiChar(#10);
  atCR   = AnsiChar(#13);
  atCRLF = atLF+atCR;
  atESC  = AnsiChar(#27);

  atVK_ESC = 27;

  // Cursor Movement
  atCSICursorPos = atESC + '[%d;%dH';         // Set cursor position
  atCSICursorUp = atESC + '[%dA';             // Move cursor up
  atCSICursorDown = atESC + '[%dB';           // Move cursor down
  atCSICursorForward = atESC + '[%dC';        // Move cursor forward
  atCSICursorBack = atESC + '[%dD';           // Move cursor backward
  atCSISaveCursorPos = atESC + '[s';          // Save cursor position
  atCSIRestoreCursorPos = atESC + '[u';       // Restore cursor position

  // Cursor Visibility
  atCSIShowCursor = atESC + '[?25h';          // Show cursor
  atCSIHideCursor = atESC + '[?25l';          // Hide cursor
  atCSIBlinkCursor = atESC + '[?12h';         // Enable cursor blinking
  atCSISteadyCursor = atESC + '[?12l';        // Disable cursor blinking

  // Screen Manipulation
  atCSIClearScreen = atESC + '[2J';           // Clear screen
  atCSIClearLine = atESC + '[2K';             // Clear line
  atCSIScrollUp = atESC + '[%dS';             // Scroll up by n lines
  atCSIScrollDown = atESC + '[%dT';           // Scroll down by n lines

  // Text Formatting
  atCSIBold = atESC + '[1m';                  // Bold text
  atCSIUnderline = atESC + '[4m';             // Underline text
  atCSIResetFormat = atESC + '[0m';           // Reset text formatting
  atCSIResetBackground = #27'[49m';         // Reset background text formatting
  atCSIResetForeground = #27'[39m';         // Reset forground text formatting
  atCSIInvertColors = atESC + '[7m';          // Invert foreground/background
  atCSINormalColors = atESC + '[27m';         // Normal colors

  atCSIDim = atESC + '[2m';
  atCSIItalic = atESC + '[3m';
  atCSIBlink = atESC + '[5m';
  atCSIFramed = atESC + '[51m';
  atCSIEncircled = atESC + '[52m';

  // Text Modification
  atCSIInsertChar = atESC + '[%d@';           // Insert n spaces at cursor position
  atCSIDeleteChar = atESC + '[%dP';           // Delete n characters at cursor position
  atCSIEraseChar = atESC + '[%dX';            // Erase n characters at cursor position

  // Colors (Foreground and Background)
  atCSIFGBlack = atESC + '[30m';
  atCSIFGRed = atESC + '[31m';
  atCSIFGGreen = atESC + '[32m';
  atCSIFGYellow = atESC + '[33m';
  atCSIFGBlue = atESC + '[34m';
  atCSIFGMagenta = atESC + '[35m';
  atCSIFGCyan = atESC + '[36m';
  atCSIFGWhite = atESC + '[37m';

  atCSIBGBlack = atESC + '[40m';
  atCSIBGRed = atESC + '[41m';
  atCSIBGGreen = atESC + '[42m';
  atCSIBGYellow = atESC + '[43m';
  atCSIBGBlue = atESC + '[44m';
  atCSIBGMagenta = atESC + '[45m';
  atCSIBGCyan = atESC + '[46m';
  atCSIBGWhite = atESC + '[47m';

  atCSIFGBrightBlack = atESC + '[90m';
  atCSIFGBrightRed = atESC + '[91m';
  atCSIFGBrightGreen = atESC + '[92m';
  atCSIFGBrightYellow = atESC + '[93m';
  atCSIFGBrightBlue = atESC + '[94m';
  atCSIFGBrightMagenta = atESC + '[95m';
  atCSIFGBrightCyan = atESC + '[96m';
  atCSIFGBrightWhite = atESC + '[97m';

  atCSIBGBrightBlack = atESC + '[100m';
  atCSIBGBrightRed = atESC + '[101m';
  atCSIBGBrightGreen = atESC + '[102m';
  atCSIBGBrightYellow = atESC + '[103m';
  atCSIBGBrightBlue = atESC + '[104m';
  atCSIBGBrightMagenta = atESC + '[105m';
  atCSIBGBrightCyan = atESC + '[106m';
  atCSIBGBrightWhite = atESC + '[107m';

  atCSIFGRGB = atESC + '[38;2;%d;%d;%dm';        // Foreground RGB
  atCSIBGRGB = atESC + '[48;2;%d;%d;%dm';        // Backg

type
  { AGT_CharSet }
  atCharSet = set of AnsiChar;

  { atConsole }
  atConsole = class
  private class var
    FInputCodePage: Cardinal;
    FOutputCodePage: Cardinal;
    FTeletypeDelay: Integer;
    FKeyState: array [0..1, 0..255] of Boolean;
  private
    class constructor Create();
    class destructor Destroy();
  public
    class procedure UnitInit();
    class procedure Print(const AMsg: string); overload; static;
    class procedure PrintLn(const AMsg: string); overload; static;

    class procedure Print(const AMsg: string; const AArgs: array of const); overload; static;
    class procedure PrintLn(const AMsg: string; const AArgs: array of const); overload; static;

    class procedure Print(); overload; static;
    class procedure PrintLn(); overload; static;

    class procedure GetCursorPos(X, Y: PInteger); static;
    class procedure SetCursorPos(const X, Y: Integer); static;
    class procedure SetCursorVisible(const AVisible: Boolean); static;
    class procedure HideCursor(); static;
    class procedure ShowCursor(); static;
    class procedure SaveCursorPos(); static;
    class procedure RestoreCursorPos(); static;
    class procedure MoveCursorUp(const ALines: Integer); static;
    class procedure MoveCursorDown(const ALines: Integer); static;
    class procedure MoveCursorForward(const ACols: Integer); static;
    class procedure MoveCursorBack(const ACols: Integer); static;

    class procedure ClearScreen(); static;
    class procedure ClearLine(); static;
    class procedure ClearLineFromCursor(const AColor: string); static;

    class procedure SetBoldText(); static;
    class procedure ResetTextFormat(); static;
    class procedure SetForegroundColor(const AColor: string); static;
    class procedure SetBackgroundColor(const AColor: string); static;
    class procedure SetForegroundRGB(const ARed, AGreen, ABlue: Byte); static;
    class procedure SetBackgroundRGB(const ARed, AGreen, ABlue: Byte); static;

    class procedure GetSize(AWidth: PInteger; AHeight: PInteger); static;

    class procedure SetTitle(const ATitle: string); static;
    class function  GetTitle(): string; static;

    class function  HasOutput(): Boolean; static;
    class function  WasRunFrom(): Boolean; static;
    class procedure WaitForAnyKey(); static;
    class function  AnyKeyPressed(): Boolean; static;

    class procedure ClearKeyStates(); static;
    class procedure ClearKeyboardBuffer(); static;

    class function  IsKeyPressed(AKey: Byte): Boolean; static;
    class function  WasKeyReleased(AKey: Byte): Boolean; static;
    class function  WasKeyPressed(AKey: Byte): Boolean; static;

    class function  ReadKey(): WideChar; static;
    class function  ReadLnX(const AAllowedChars: atCharSet; AMaxLength: Integer; const AColor: string=atCSIFGWhite): string; static;

    class procedure Pause(const AForcePause: Boolean=False; AColor: string=atCSIFGWhite; const AMsg: string=''); static;

    class function  WrapTextEx(const ALine: string; AMaxCol: Integer; const ABreakChars: atCharSet=[' ', '-', ',', ':', #9]): string; static;
    class procedure Teletype(const AText: string; const AColor: string=atCSIFGWhite; const AMargin: Integer=10; const AMinDelay: Integer=0; const AMaxDelay: Integer=3; const ABreakKey: Byte=VK_ESCAPE); static;
  end;

implementation

{ atConsole }
class constructor atConsole.Create();
begin
  FTeletypeDelay := 0;

  // save current console codepage
  FInputCodePage := GetConsoleCP();
  FOutputCodePage := GetConsoleOutputCP();

  // set code page to UTF8
  SetConsoleCP(CP_UTF8);
  SetConsoleOutputCP(CP_UTF8);

  atUtils.EnableVirtualTerminalProcessing();
end;

class destructor atConsole.Destroy();
begin
  // restore code page
  SetConsoleCP(FInputCodePage);
  SetConsoleOutputCP(FOutputCodePage);
end;

class procedure atConsole.UnitInit();
begin
end;

class procedure atConsole.Print(const AMsg: string);
begin
  if not HasOutput() then Exit;
  Write(AMsg+atCSIResetFormat);
end;

class procedure atConsole.PrintLn(const AMsg: string);
begin
  if not HasOutput() then Exit;
  WriteLn(AMsg+atCSIResetFormat);
end;

class procedure atConsole.Print(const AMsg: string; const AArgs: array of const);
begin
  if not HasOutput() then Exit;
  Write(Format(AMsg, AArgs)+atCSIResetFormat);
end;

class procedure atConsole.PrintLn(const AMsg: string; const AArgs: array of const);
begin
  if not HasOutput() then Exit;
  WriteLn(Format(AMsg, AArgs)+atCSIResetFormat);
end;

class procedure atConsole.Print();
begin
  if not HasOutput() then Exit;
  Write(atCSIResetFormat);
end;

class procedure atConsole.PrintLn();
begin
  if not HasOutput() then Exit;
  WriteLn(atCSIResetFormat);
end;

class procedure atConsole.GetCursorPos(X, Y: PInteger);
var
  hConsole: THandle;
  BufferInfo: TConsoleScreenBufferInfo;
begin
  hConsole := GetStdHandle(STD_OUTPUT_HANDLE);
  if hConsole = INVALID_HANDLE_VALUE then
    Exit;

  if not GetConsoleScreenBufferInfo(hConsole, BufferInfo) then
    Exit;

  if Assigned(X) then
    X^ := BufferInfo.dwCursorPosition.X;
  if Assigned(Y) then
    Y^ := BufferInfo.dwCursorPosition.Y;
end;

class procedure atConsole.SetCursorPos(const X, Y: Integer);
begin
  if not HasOutput() then Exit;
  Write(Format(atCSICursorPos, [X, Y]));
end;

class procedure atConsole.SetCursorVisible(const AVisible: Boolean);
var
  ConsoleInfo: TConsoleCursorInfo;
  ConsoleHandle: THandle;
begin
  ConsoleHandle := GetStdHandle(STD_OUTPUT_HANDLE);
  ConsoleInfo.dwSize := 25; // You can adjust cursor size if needed
  ConsoleInfo.bVisible := AVisible;
  SetConsoleCursorInfo(ConsoleHandle, ConsoleInfo);
end;

class procedure atConsole.HideCursor();
begin
  if not HasOutput() then Exit;
  Write(atCSIHideCursor);
end;

class procedure atConsole.ShowCursor();
begin
  if not HasOutput() then Exit;
  Write(atCSIShowCursor);
end;

class procedure atConsole.SaveCursorPos();
begin
  if not HasOutput() then Exit;
  Write(atCSISaveCursorPos);
end;

class procedure atConsole.RestoreCursorPos();
begin
  if not HasOutput() then Exit;
  Write(atCSIRestoreCursorPos);
end;

class procedure atConsole.MoveCursorUp(const ALines: Integer);
begin
  if not HasOutput() then Exit;
  Write(Format(atCSICursorUp, [ALines]));
end;

class procedure atConsole.MoveCursorDown(const ALines: Integer);
begin
  if not HasOutput() then Exit;
  Write(Format(atCSICursorDown, [ALines]));
end;

class procedure atConsole.MoveCursorForward(const ACols: Integer);
begin
  if not HasOutput() then Exit;
  Write(Format(atCSICursorForward, [ACols]));
end;

class procedure atConsole.MoveCursorBack(const ACols: Integer);
begin
  if not HasOutput() then Exit;
  Write(Format(atCSICursorBack, [ACols]));
end;

class procedure atConsole.ClearScreen();
begin
  if not HasOutput() then Exit;
  Write(atCSIClearScreen);
  SetCursorPos(0, 0);
end;

class procedure atConsole.ClearLine();
begin
  if not HasOutput() then Exit;
  Write(atCR);
  Write(atCSIClearLine);
end;

class procedure atConsole.ClearLineFromCursor(const AColor: string);
var
  LConsoleOutput: THandle;
  LConsoleInfo: TConsoleScreenBufferInfo;
  LNumCharsWritten: DWORD;
  LCoord: TCoord;
begin
  LConsoleOutput := GetStdHandle(STD_OUTPUT_HANDLE);

  if GetConsoleScreenBufferInfo(LConsoleOutput, LConsoleInfo) then
  begin
    LCoord.X := 0;
    LCoord.Y := LConsoleInfo.dwCursorPosition.Y;

    Print(AColor, []);
    FillConsoleOutputCharacter(LConsoleOutput, ' ', LConsoleInfo.dwSize.X
      - LConsoleInfo.dwCursorPosition.X, LCoord, LNumCharsWritten);
    SetConsoleCursorPosition(LConsoleOutput, LCoord);
  end;
end;

class procedure atConsole.SetBoldText();
begin
  if not HasOutput() then Exit;
  Write(atCSIBold);
end;

class procedure atConsole.ResetTextFormat();
begin
  if not HasOutput() then Exit;
  Write(atCSIResetFormat);
end;

class procedure atConsole.SetForegroundColor(const AColor: string);
begin
  if not HasOutput() then Exit;
  Write(AColor);
end;

class procedure atConsole.SetBackgroundColor(const AColor: string);
begin
  if not HasOutput() then Exit;
  Write(AColor);
end;

class procedure atConsole.SetForegroundRGB(const ARed, AGreen, ABlue: Byte);
begin
  if not HasOutput() then Exit;
  Write(Format(atCSIFGRGB, [ARed, AGreen, ABlue]));
end;

class procedure atConsole.SetBackgroundRGB(const ARed, AGreen, ABlue: Byte);
begin
  if not HasOutput() then Exit;
  Write(Format(atCSIBGRGB, [ARed, AGreen, ABlue]));
end;

class procedure atConsole.GetSize(AWidth: PInteger; AHeight: PInteger);
var
  LConsoleInfo: TConsoleScreenBufferInfo;
begin
  GetConsoleScreenBufferInfo(GetStdHandle(STD_OUTPUT_HANDLE), LConsoleInfo);
  if Assigned(AWidth) then
    AWidth^ := LConsoleInfo.dwSize.X;

  if Assigned(AHeight) then
  AHeight^ := LConsoleInfo.dwSize.Y;
end;

class procedure atConsole.SetTitle(const ATitle: string);
begin
  WinApi.Windows.SetConsoleTitle(PChar(ATitle));
end;

class function  atConsole.GetTitle(): string;
const
  MAX_TITLE_LENGTH = 1024;
var
  LTitle: array[0..MAX_TITLE_LENGTH] of WideChar;
  LTitleLength: DWORD;
begin
  // Get the console title and store it in LTitle
  LTitleLength := GetConsoleTitleW(LTitle, MAX_TITLE_LENGTH);

  // If the title is retrieved, assign it to the result
  if LTitleLength > 0 then
    Result := string(LTitle)
  else
    Result := '';
end;

class function  atConsole.HasOutput(): Boolean;
var
  LStdHandle: THandle;
begin
  LStdHandle := GetStdHandle(STD_OUTPUT_HANDLE);
  Result := (LStdHandle <> INVALID_HANDLE_VALUE) and
            (GetFileType(LStdHandle) = FILE_TYPE_CHAR);
end;

class function  atConsole.WasRunFrom(): Boolean;
var
  LStartupInfo: TStartupInfo;
begin
  LStartupInfo.cb := SizeOf(TStartupInfo);
  GetStartupInfo(LStartupInfo);
  Result := ((LStartupInfo.dwFlags and STARTF_USESHOWWINDOW) = 0);
end;

class procedure atConsole.WaitForAnyKey();
var
  LInputRec: TInputRecord;
  LNumRead: Cardinal;
  LOldMode: DWORD;
  LStdIn: THandle;
begin
  LStdIn := GetStdHandle(STD_INPUT_HANDLE);
  GetConsoleMode(LStdIn, LOldMode);
  SetConsoleMode(LStdIn, 0);
  repeat
    ReadConsoleInput(LStdIn, LInputRec, 1, LNumRead);
  until (LInputRec.EventType and KEY_EVENT <> 0) and
    LInputRec.Event.KeyEvent.bKeyDown;
  SetConsoleMode(LStdIn, LOldMode);
end;

class function  atConsole.AnyKeyPressed(): Boolean;
var
  LNumberOfEvents     : DWORD;
  LBuffer             : TInputRecord;
  LNumberOfEventsRead : DWORD;
  LStdHandle           : THandle;
begin
  Result:=false;
  //get the console handle
  LStdHandle := GetStdHandle(STD_INPUT_HANDLE);
  LNumberOfEvents:=0;
  //get the number of events
  GetNumberOfConsoleInputEvents(LStdHandle,LNumberOfEvents);
  if LNumberOfEvents<> 0 then
  begin
    //retrieve the event
    PeekConsoleInput(LStdHandle,LBuffer,1,LNumberOfEventsRead);
    if LNumberOfEventsRead <> 0 then
    begin
      if LBuffer.EventType = KEY_EVENT then //is a Keyboard event?
      begin
        if LBuffer.Event.KeyEvent.bKeyDown then //the key was pressed?
          Result:=true
        else
          FlushConsoleInputBuffer(LStdHandle); //flush the buffer
      end
      else
      FlushConsoleInputBuffer(LStdHandle);//flush the buffer
    end;
  end;
end;

class procedure atConsole.ClearKeyStates();
begin
  FillChar(FKeyState, SizeOf(FKeyState), 0);
  ClearKeyboardBuffer();
end;

class procedure atConsole.ClearKeyboardBuffer();
var
  LInputRecord: TInputRecord;
  LEventsRead: DWORD;
  LMsg: TMsg;
begin
  while PeekConsoleInput(GetStdHandle(STD_INPUT_HANDLE), LInputRecord, 1, LEventsRead) and (LEventsRead > 0) do
  begin
    ReadConsoleInput(GetStdHandle(STD_INPUT_HANDLE), LInputRecord, 1, LEventsRead);
  end;

  while PeekMessage(LMsg, 0, WM_KEYFIRST, WM_KEYLAST, PM_REMOVE) do
  begin
    // No operation; just removing messages from the queue
  end;
end;

class function  atConsole.IsKeyPressed(AKey: Byte): Boolean;
begin
  Result := (GetAsyncKeyState(AKey) and $8000) <> 0;
end;

class function  atConsole.WasKeyReleased(AKey: Byte): Boolean;
begin
  Result := False;
  if IsKeyPressed(AKey) and (not FKeyState[1, AKey]) then
  begin
    FKeyState[1, AKey] := True;
    Result := True;
  end
  else if (not IsKeyPressed(AKey)) and (FKeyState[1, AKey]) then
  begin
    FKeyState[1, AKey] := False;
    Result := False;
  end;
end;

class function  atConsole.WasKeyPressed(AKey: Byte): Boolean;
begin
  Result := False;
  if IsKeyPressed(AKey) and (not FKeyState[1, AKey]) then
  begin
    FKeyState[1, AKey] := True;
    Result := False;
  end
  else if (not IsKeyPressed(AKey)) and (FKeyState[1, AKey]) then
  begin
    FKeyState[1, AKey] := False;
    Result := True;
  end;
end;

class function  atConsole.ReadKey(): WideChar;
var
  LInputRecord: TInputRecord;
  LEventsRead: DWORD;
begin
  repeat
    ReadConsoleInput(GetStdHandle(STD_INPUT_HANDLE), LInputRecord, 1, LEventsRead);
  until (LInputRecord.EventType = KEY_EVENT) and LInputRecord.Event.KeyEvent.bKeyDown;
  Result := LInputRecord.Event.KeyEvent.UnicodeChar;
end;

class function  atConsole.ReadLnX(const AAllowedChars: atCharSet; AMaxLength: Integer; const AColor: string): string;
var
  LInputChar: Char;
begin
  Result := '';

  repeat
    LInputChar := ReadKey;

    if CharInSet(LInputChar, AAllowedChars) then
    begin
      if Length(Result) < AMaxLength then
      begin
        if not CharInSet(LInputChar, [#10, #0, #13, #8])  then
        begin
          //Print(LInputChar, AColor);
          Print('%s%s', [AColor, LInputChar]);
          Result := Result + LInputChar;
        end;
      end;
    end;
    if LInputChar = #8 then
    begin
      if Length(Result) > 0 then
      begin
        //Print(#8 + ' ' + #8);
        Print(#8 + ' ' + #8, []);
        Delete(Result, Length(Result), 1);
      end;
    end;
  until (LInputChar = #13);

  PrintLn();
end;

class procedure atConsole.Pause(const AForcePause: Boolean; AColor: string; const AMsg: string);
var
  LDoPause: Boolean;
begin
  if not HasOutput then Exit;

  ClearKeyboardBuffer();

  if not AForcePause then
  begin
    LDoPause := True;
    if WasRunFrom() then LDoPause := False;
    if atUtils.IsStartedFromDelphiIDE() then LDoPause := True;
    if not LDoPause then Exit;
  end;

  WriteLn;
  if AMsg = '' then
    Print('%sPress any key to continue... ', [aColor])
  else
    Print('%s%s', [aColor, AMsg]);

  WaitForAnyKey();
  WriteLn;
end;

class function  atConsole.WrapTextEx(const ALine: string; AMaxCol: Integer; const ABreakChars: atCharSet): string;
var
  LText: string;
  LPos: integer;
  LChar: Char;
  LLen: Integer;
  I: Integer;
begin
  LText := ALine.Trim;

  LPos := 0;
  LLen := 0;

  while LPos < LText.Length do
  begin
    Inc(LPos);

    LChar := LText[LPos];

    if LChar = #10 then
    begin
      LLen := 0;
      continue;
    end;

    Inc(LLen);

    if LLen >= AMaxCol then
    begin
      for I := LPos downto 1 do
      begin
        LChar := LText[I];

        if CharInSet(LChar, ABreakChars) then
        begin
          LText.Insert(I, #10);
          Break;
        end;
      end;

      LLen := 0;
    end;
  end;

  Result := LText;
end;

class procedure atConsole.Teletype(const AText: string; const AColor: string; const AMargin: Integer; const AMinDelay: Integer; const AMaxDelay: Integer; const ABreakKey: Byte);
var
  LText: string;
  LMaxCol: Integer;
  LChar: Char;
  LWidth: Integer;
begin
  GetSize(@LWidth, nil);
  LMaxCol := LWidth - AMargin;

  LText := WrapTextEx(AText, LMaxCol);

  for LChar in LText do
  begin
    atUtils.ProcessMessages();
    Print('%s%s', [AColor, LChar]);
    if not atUtils.RandomBool() then
      FTeletypeDelay := atUtils.RandomRange(AMinDelay, AMaxDelay);
    atUtils.Wait(FTeletypeDelay);
    if IsKeyPressed(ABreakKey) then
    begin
      ClearKeyboardBuffer;
      Break;
    end;
  end;
end;

end.
