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

program Testbed;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  AIToolkit.CLibs in '..\..\src\AIToolkit.CLibs.pas',
  AIToolkit.Utils in '..\..\src\AIToolkit.Utils.pas',
  AIToolkit.Messages in '..\..\src\AIToolkit.Messages.pas',
  AIToolkit.Common in '..\..\src\AIToolkit.Common.pas',
  UTestbed in 'UTestbed.pas',
  AIToolkit.Inference in '..\..\src\AIToolkit.Inference.pas',
  AIToolkit.Tools in '..\..\src\AIToolkit.Tools.pas',
  AIToolkit.Console in '..\..\src\AIToolkit.Console.pas',
  UTest01 in 'UTest01.pas',
  UTest02 in 'UTest02.pas',
  UTest03 in 'UTest03.pas';

begin
  RunTests();
end.
