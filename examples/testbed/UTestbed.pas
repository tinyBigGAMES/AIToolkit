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

unit UTestbed;

interface

uses
  System.SysUtils,
  AIToolkit.Common,
  AIToolkit.Console,
  UTest01;

procedure RunTests();

implementation

(*
  === USAGE NOTES ===
  1. Download model from:
     - https://huggingface.co/tinybiggames/DeepSeek-R1-Distill-Llama-8B-abliterated-Q4_K_M-GGUF/resolve/main/deepseek-r1-distill-llama-8b-abliterated-q4_k_m.gguf?download=true
  2. Place in your desired location, the examples expect:
     - C:/LLM/GGUF

  3. Get search api key from:
     - https://tavily.com/
     - You get 1000 free tokens per month
     - Create a an environment variable named "TAVILY_API_KEY" and set it to
       the search api key.
*)

procedure RunTests();
var
  LNum: Integer;
begin
  atConsole.PrintLn(atCSIFGMagenta+'AIToolkit v%s', [CatAIToolkitVersion]);
  atConsole.PrintLn();

  LNum := 01;

  case LNum of
    01: UTest01.Test();
  end;

  atConsole.Pause();
end;

end.
