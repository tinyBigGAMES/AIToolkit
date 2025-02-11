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

unit UTest01;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  System.JSON,
  System.RegularExpressions,
  AIToolkit.Utils,
  AIToolkit.Common,
  AIToolkit.Messages,
  AIToolkit.Inference,
  AIToolkit.Tools,
  AIToolkit.Console;

procedure Test();

implementation

const
  // Toggle show thinking on/off
  CShowThinking: Boolean = True;

  // Max inference context used
  CMaxContext = 1024*4;

// Get random "think" end messages
function GetRandomThinkingResult: string;
const
  Messages: array[0..9] of string = (
    'Here’s what I came up with:',
    'This is what I found:',
    'Here’s my answer:',
    'Done! Here’s the result:',
    'Here’s my response:',
    'I’ve worked it out:',
    'Processing complete. Here’s my output:',
    'Here’s what I think:',
    'After thinking it through, here’s my take:',
    'Solution ready! Check this out:'
  );
begin
  Randomize();
  Result := Messages[Random(Length(Messages))];
end;

// Custom next token event
procedure NextTokenEvent(const AToken: string);
begin
  atConsole.Print(atCSIFGGreen+atCSIBold+atUtils.SanitizeFromJson(AToken));
end;

// Customize "think" start event
procedure  ThinkStartEvent();
begin
  atConsole.Print(atCSIFGBrightWhite+'Thinking...');
end;

// Customize "think" end event
procedure ThinkEndEvent();
begin
  atConsole.ClearLine();
  atConsole.PrintLn();
  atConsole.PrintLn(atCSIFGCyan+GetRandomThinkingResult());
end;

type
  {$M+}

  // Tools static class
  MyTools = class
  published
    [atSchemaDescription('Provides access to the internet to perform a web search and return the answer as a string. Only call when you can not answer the query and for real-time, time sensitive information')]
    class function web_search(
      [atSchemaDescription('A string containing the result of the search query')]
       query: string
    ): string; static;

  end;
  {$M-}

// Websearch tool function
class function MyTools.web_search(query: string): string;
begin
  Result := atWebSearch(query.Trim()).Trim();
end;

procedure Test();

var
  LTools: TatTools;
  LMessages: TatMessagesDeepSeekR1;
  LInference: TatInferenceDeepSeekR1;

  LQuestion: string;

  LTokenSpeed: Single;
  LInputTokens: Integer;
  LOutputTokens: Integer;
begin
  LTools := TatTools.Create();
  try
    LMessages := TatMessagesDeepSeekR1.Create();
    try
        LInference := TatInferenceDeepSeekR1.Create;
        try

          // Add tool - called when need to do a web search for real-time, up todate inforamtion
          LTools.Add(

            // Class with published static tool methods
            MyTools,

              // Tool name
            'web_search',

            // Tool native function
            procedure(const AMessages: TatMessages; const AInference: TatInference; const AToolCall: TatToolCall)
            var
              LArgs: TatParamArg;
              LResponse: string;
            begin
              // Exit if function_call is nil
              if not Assigned(AToolCall) then Exit;

              // Display the name of this function_call to console
              atConsole.PrintLn();
              atConsole.PrintLn();
              atConsole.PrintLn(atCSIFGYellow+'tool_call: "web_search"...');

              // Loop over the function_call params
              for LArgs in AToolCall.Params do
              begin
                // Do web search on Arg value (query)
                LResponse := atUtils.CallStaticMethod(AToolCall.GetClass(), AToolCall.FuncName, [LArgs.Value]).AsString;

                // Add result as a user message
                AMessages.Clear();
                AMessages.Add(atUser, LResponse);
              end;

              // Let reasoner LLM do inference on question
              //RunInference(LMsgReason, AInference, True, CMaxContext, -1);
              if not AInference.Run(AMessages, CMaxContext) then
              begin
                // Failed - display error
                atConsole.PrintLn();
                atConsole.PrintLn();
                atConsole.PrintLn(atCSIFGRed+'Error: %s', [AInference.GetError()])
              end;
            end
          );

          LInference.ThinkStartEvent := ThinkStartEvent;
          LInference.ThinkEndEvent := ThinkEndEvent;
          LInference.ShowThinking := CShowThinking;
          LInference.NextTokenEvent := NextTokenEvent;

          LInference.LoadModel(CAIToolkit_Reasoning, -1, -1);

          LMessages.Add(atUser, LTools.CallPrompt());

          // default question is nothing else is defined
          LQuestion := 'what is AI?';

          //LQuestion := 'what is bill gates current net worth as of 2025';
          //LQuestion := 'who is bill gates?';
          //LQuestion := 'what is the current U.S. natial debt as of 2025?';
          //LQuestion := 'what is KNO3?';
          LQuestion := 'how many r''s are there in the word starawberry';
          //LQuestion := 'what is the latest status on the forest fires in california in 2025?';
          //LQuestion := 'detail steps how to make KNO3.';

          LMessages.Add(atUser, LQuestion);

          // Do inference
          if LInference.Run(LMessages, CMaxContext) then
            begin
              LTools.Call(LMessages, LInference, LInference.Response());

              // Success - display performance
              LInference.Performance(@LInputTokens, @LOutputTokens, @LTokenSpeed);
              atConsole.PrintLn();
              atConsole.PrintLn();
              atConsole.PrintLn(atCSIFGYellow+atCSIBold+'Tokens :: Input: %d, Output: %d, Speed: %3.2f', [LInputTokens, LOutputTokens, LTokenSpeed]);
            end
          else
            begin
              // Failed - display error
              atConsole.PrintLn();
              atConsole.PrintLn();
              atConsole.PrintLn(atCSIFGRed+'Error: %s', [LInference.GetError()])
            end;
        finally
          LInference.Free();
        end;
      finally
      LMessages.Free();
    end;
  finally
    LTools.Free();
  end;
end;

end.
