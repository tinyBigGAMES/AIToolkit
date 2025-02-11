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

{$WARN SYMBOL_DEPRECATED OFF}
{$WARN SYMBOL_PLATFORM OFF}

{$WARN UNIT_PLATFORM OFF}
{$WARN UNIT_DEPRECATED OFF}

{$Z4}
{$A8}

{$INLINE AUTO}

{$IFNDEF WIN64}
  {$MESSAGE Error 'Unsupported platform'}
{$ENDIF}

{$IF (CompilerVersion < 36.0)}
  {$IFNDEF WIN64}
    {$MESSAGE Error 'Must use Delphi 12.2 or higher'}
  {$ENDIF}
{$IFEND}
