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

unit UTest03;

interface

uses
  WinApi.Windows,
  System.SysUtils,
  System.Classes,
  AIToolkit.Console,
  AIToolkit.Messages,
  AIToolkit.Inference;

procedure Test();


implementation

{
  A Router Prompt is a structured prompt designed to analyze incoming queries
  and determine the appropriate processing path based on their characteristics.
  It acts as a decision-making system that classifies queries into three
  categories:

  - function_calling (for real-time or external data retrieval).
  - deep_thinking (for complex calculations and reasoning).
  - standard_processing (for basic knowledge retrieval).

  The prompt returns a standardized JSON response containing the chosen path,
  reasoning, requirements, and complexity level, enabling automated handling of
  different query types.

  This example uses the new DeepHermes-3 model, one of the first in the
  world to unify reasoning (long chains of thought that improve answer
  accuracy) and standard LLM response modes into a single system. It also
  features enhanced **LLM annotation, judgment, and function calling.

  This model is capable of handling all the scenarios mentioned above.

  You can down it from our Hugging Face account:
  https://huggingface.co/tinybiggames/DeepHermes-3-Llama-3-8B-Preview-Q4_K_M-GGUF/resolve/main/deephermes-3-llama-3-8b-preview-q4_k_m.gguf?download=true
}

procedure Test();
const
  CMaxContext = 1024*8;
  CDeepThinkLevel = 7;
  CShowThinking = True;
  CModel = 'C:/LLM/GGUF/DeepHermes-3-Llama-3-8B-q4.gguf';
  CPromptFilename = 'res/prompts/router_prompt.txt';
var
  LMessages: TatMessagesLLaMA;
  LInference: TatInference;
  LQuestion: string;
  LPrompt: TStringList;
begin
  try
    // Init Prompt
    LPrompt := TStringList.Create();
    try
      // Load prompt
      LPrompt.LoadFromFile(CPromptFilename);

      // Init messages
      LMessages := TatMessagesLLaMA.Create();
      try
        // Init inference
        LInference := TatInference.Create();
        try

          // Load model
          if not LInference.LoadModel(CModel) then Exit;

          LMessages.Add(atSystem, LPrompt.Text);

          // Add user question
          LQuestion := 'who is bill gates?';
          //LQuestion := 'do i run over one person to save many or save the one person let many die?';
          //LQuestion := 'What is y if y=2*2-4+(3*2)?';
          //LQuestion := 'what is the current net worth of bill gates as of 2025?';
          //LQuestion := 'what is 2 + 2?';
          //LQuestion := 'I walk on four legs in the morning, two legs at noon, and three legs in the evening. But beware, for this is not the famous riddle of the Sphinx. Instead, my journey is cyclical, and each stage is both an end and a beginning. I am not a creature, but I hold the essence of all creatures within me. What am I?';

          LMessages.Add(atUser, LQuestion);

          // Run inference
          if LInference.Run(LMessages, CMaxContext) then
          begin
          end;

        finally
          // Free inference
          LInference.Free();
        end;
      finally
        // Free messages
        LMessages.Free();
      end;
    finally
      LPrompt.Free();
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
