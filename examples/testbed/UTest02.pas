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

unit UTest02;

interface

uses
  WinApi.Windows,
  System.SysUtils,
  AIToolkit.Console,
  AIToolkit.Messages,
  AIToolkit.Inference;

procedure Test();

implementation

const
  CRethinkPrompt =
    'You were asked this question:' + sLineBreak +
    '%s' + sLineBreak + sLineBreak +
    'You generated this output:' + sLineBreak +
    '%s' + sLineBreak + sLineBreak +
    'Now, engage in a multi-level analysis of your response:' + sLineBreak + sLineBreak +

    '1. First Principles Analysis:' + sLineBreak +
    '- What core assumptions underlie your reasoning?' + sLineBreak +
    '- Are these assumptions valid in all cases?' + sLineBreak +
    '- What fundamental principles or concepts did you draw from?' + sLineBreak + sLineBreak +

    '2. Structural Evaluation:' + sLineBreak +
    '- Is the information organized in the most logical flow?' + sLineBreak +
    '- Are there any gaps in the progression of ideas?' + sLineBreak +
    '- Could the structure better serve the user''s needs?' + sLineBreak + sLineBreak +

    '3. Technical Accuracy:' + sLineBreak +
    '- Verify each claim and statement' + sLineBreak +
    '- Check for hidden edge cases or exceptions' + sLineBreak +
    '- Identify any oversimplifications' + sLineBreak + sLineBreak +

    '4. Clarity & Accessibility:' + sLineBreak +
    '- Would someone without domain expertise understand this?' + sLineBreak +
    '- Are technical terms adequately explained?' + sLineBreak +
    '- Are examples concrete and relevant?' + sLineBreak + sLineBreak +

    '5. Efficiency & Conciseness:' + sLineBreak +
    '- Is there redundant information?' + sLineBreak +
    '- Could any point be made more succinctly?' + sLineBreak +
    '- Is every included detail necessary?' + sLineBreak + sLineBreak +

    '6. Alternative Perspectives:' + sLineBreak +
    '- What counter-arguments haven''t been addressed?' + sLineBreak +
    '- What different approaches could solve this problem?' + sLineBreak +
    '- What contexts might change the validity of this response?' + sLineBreak + sLineBreak +

    '7. Implementation & Practicality:' + sLineBreak +
    '- How easily can this be applied in real-world scenarios?' + sLineBreak +
    '- What potential obstacles haven''t been considered?' + sLineBreak +
    '- Are there any unstated prerequisites?' + sLineBreak + sLineBreak +

    'Based on this analysis:' + sLineBreak +
    '1. List specific improvements needed' + sLineBreak +
    '2. Develop an enhanced solution incorporating these improvements' + sLineBreak +
    '3. Verify the new solution addresses all identified issues' + sLineBreak +
    '4. Iterate if necessary until the response is optimal' + sLineBreak + sLineBreak +

    'Output your improved response with these enhancements implemented.' + sLineBreak + sLineBreak +

    'Remember to be explicit about any remaining limitations or assumptions in your final response.';

  CQuestion =
    'I walk on four legs in the morning, two legs at noon, and three legs in the evening. But beware, for this is not the famous riddle of the Sphinx. Instead, my journey is cyclical, and each stage is both an end and a beginning. I am not a creature, but I hold the essence of all creatures within me. What am I?';

// The solution to this riddle is "Time" or "Life itself" in a cyclical sense.
// After deep thinking level #6 it will start to realizes that it maybe "time"
// and by level 7 it realizes that it is "time" or "life itself".
procedure Test();
const
  CMaxContext = 1024*8;
  CDeepThinkLevel = 7;
  CShowThinking = True;
var
  LMessages: TatMessagesDeepSeekR1;
  LInference: TatInferenceDeepSeekR1;
  LText: string;
  LResponse: string;
  LThinkLevel: Integer;
begin
  try
    // Init messages
    LMessages := TatMessagesDeepSeekR1.Create();
    try
      // Init inference
      LInference := TatInferenceDeepSeekR1.Create();
      try

        // Load model
        if not LInference.LoadModel('C:\LLM\GGUF\deepseek-r1-distill-llama-8b-abliterated-q4_k_m.gguf') then Exit;

        // Set show thinking
        LInference.ShowThinking := CShowThinking;

        // Init the next token event handler
        LInference.NextTokenEvent :=
        procedure (const AToken: string)
        begin
          if not LInference.Thinking then
          begin
            LResponse := LResponse + AToken;
          end;
          atConsole.Print(AToken);
        end;

        // Init the concel event handler
        LInference.CancelEvent :=
        function: Boolean
        begin
          Result := Boolean(GetAsyncKeyState(VK_ESCAPE) <> 0);
        end;

        // Init the "think end" event handler
        LInference.ThinkEndEvent :=
        procedure
        begin
          LInference.ClearTokenResponse();
          atConsole.PrintLn('</think>');
        end;

        // Add user question
        LMessages.Add(atUser, CQuestion);

        // Loop throught thinking levels
        for LThinkLevel := 0 to CDeepThinkLevel do
        begin
          // Clear the think answer response
          LResponse := '';

          // Run inference
          if LInference.Run(LMessages, CMaxContext) then
          begin
            // check if use is trying to cancel
            if LInference.CancelEvent() then Exit;

            // Clear messages
            LMessages.Clear();

            // Create a "think deeper" prompt
            LText := Format(CRethinkPrompt, [CQuestion, LResponse]);

            // Add the question and the current response
            LMessages.Add(atUser, LText);

            // Keep thinking until we reach the requested think level
            if LThinkLevel < CDeepThinkLevel then
            begin
              atConsole.PrintLn();
              atConsole.PrintLn();
              atConsole.PrintLn('Thinking deeper, level #%d...', [LThinkLevel+1]);
            end;
          end;
        end;

      finally
        // Free inference
        LInference.Free();
      end;
    finally
      // Free messages
      LMessages.Free();
    end;
  except
    // Display any unhandled exceptions
    on E: Exception do
    begin
      atConsole.PrintLn();
      atConsole.PrintLn();
      atConsole.PrintLn('Error: %s', [E.Message]);
    end;
  end;
end;

end.
