{===============================================================================
  __  __                              ___   _     _ ™
 |  \/  | ___  _ __   ___  _ _  _  _ |   \ | |   | |
 | |\/| |/ -_)| '  \ / _ \| '_|| || || |) || |__ | |__
 |_|  |_|\___||_|_|_|\___/|_|   \_, ||___/ |____||____|
                                |__/
 In-Memory Win64 DLL Loading & Execution for Pascal

 Copyright © 2024-present tinyBigGAMES™ LLC
 All Rights Reserved.

 https://github.com/tinyBigGAMES/MemoryDLL

 BSD 3-Clause License

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice,
    this list of conditions and the following disclaimer.

 2. Redistributions in binary form must reproduce the above copyright notice,
    this list of conditions and the following disclaimer in the documentation
    and/or other materials provided with the distribution.

 3. Neither the name of the copyright holder nor the names of its
    contributors may be used to endorse or promote products derived from
    this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
 LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.

 -----------------------------------------------------------------------------

 Summary:
   The MemoryDLL unit provides advanced functionality for loading dynamic-link
   libraries (win64 DLLs) directly from memory. This unit facilitates the
   loading of DLLs from byte arrays or memory streams, retrieval of function
   addresses within the loaded DLL, and proper unloading of the DLL module.
   Unlike traditional methods that rely on filesystem operations, MemoryDLL
   operates entirely in memory, offering a secure and efficient alternative
   for DLL management.

 Remarks:
   The MemoryDLL unit is meticulously crafted to cater to expert Pascal
   developers who require low-level control over DLL operations. By
   eliminating the dependency on the filesystem, this unit enhances security
   by preventing unauthorized access to DLL files and reduces I/O overhead,
   thereby improving application performance.

 Key Features:
   - MemoryLoadLibrary: Loads a DLL from a memory buffer, such as a byte
     array or memory stream, without writing to the disk.
   - You can then use standard win32 GetProcAddress and FreeLibrary as normal

 -----------------------------------------------------------------------------
 This project uses the following open-source libraries:
  * perfect-loader - https://github.com/EvanMcBroom/perfect-loader

 -----------------------------------------------------------------------------
 >>> CHANGELOG <<<

 Version 0.2.0
 -------------
  - Now works on Windows 11 24H2

 Version 0.1.0
 -------------
  - Initial release

===============================================================================}

unit MemoryDLL;

interface

const
  /// <summary>
  /// Major version of the MemoryDLL.
  /// </summary>
  /// <remarks>
  /// This represents the main version number, typically updated for significant changes or milestones.
  /// </remarks>
  MEMORYDLL_MAJOR_VERSION = '0';

  /// <summary>
  /// Minor version of the MemoryDLL.
  /// </summary>
  /// <remarks>
  /// This is incremented for smaller, incremental improvements or updates.
  /// </remarks>
  MEMORYDLL_MINOR_VERSION = '2';

  /// <summary>
  /// Patch version of the MemoryDLL.
  /// </summary>
  /// <remarks>
  /// This number increases for bug fixes or minor improvements that do not affect major or minor versions.
  /// </remarks>
  MEMORYDLL_PATCH_VERSION = '0';

  /// <summary>
  /// Full version of the MemoryDLL, formatted as Major.Minor.Patch.
  /// </summary>
  /// <remarks>
  /// This combines the major, minor, and patch versions into a single version string.
  /// </remarks>
  MEMORYDLL_VERSION = MEMORYDLL_MAJOR_VERSION + '.' + MEMORYDLL_MINOR_VERSION + '.' + MEMORYDLL_PATCH_VERSION;

/// <summary>
///   Loads a DLL directly from memory into the current process's address space.
/// </summary>
/// <param name="AData">
///   Pointer to the memory block containing the DLL binary data. This memory block must contain
///   the complete and valid DLL image.
/// </param>
/// <param name="ASize">
///   The size, in bytes, of the DLL binary data stored in the memory block.
/// </param>
/// <returns>
///   Returns a handle to the loaded DLL if successful, or <c>0</c> if the operation fails.
/// </returns>
/// <remarks>
///   This function is designed to load a dynamic-link library (DLL) directly from memory,
///   bypassing the need for the DLL to exist on the file system. It is particularly useful
///   in scenarios where DLLs are embedded as resources or transmitted over a network.
/// </remarks>
/// <exception>
///   If the function fails, the Windows error code can be retrieved using <c>GetLastError</c>.
///   Common failure reasons include invalid or corrupted DLL data, insufficient memory, or
///   security restrictions.
/// </exception>
/// <preconditions>
///   <list type="bullet">
///     <item><description>The memory block pointed to by <c>AData</c> must be valid.</description></item>
///     <item><description>The size of the memory block in <c>ASize</c> must match the DLL binary size.</description></item>
///   </list>
/// </preconditions>
/// <postconditions>
///   <list type="bullet">
///     <item><description>If successful, the DLL is loaded into the process's address space.</description></item>
///     <item><description>The returned handle can be used in subsequent API calls, such as <c>GetProcAddress</c>.</description></item>
///   </list>
/// </postconditions>
/// <seealso>
///   <c>FreeLibrary</c>, <c>GetProcAddress</c>
/// </seealso>
function LoadMemoryDLL(const AData: Pointer; const ASize: NativeUInt): THandle;

implementation

{$REGION ' USES '}
uses
  WinApi.Windows,
  System.SysUtils,
  System.Classes,
  System.IOUtils;
{$ENDREGION}

{$REGION ' MEMORYMODULE '}
{$IF NOT DECLARED(IMAGE_BASE_RELOCATION)}
type
  {$ALIGN 4}
  IMAGE_BASE_RELOCATION = record
    VirtualAddress: DWORD;
    SizeOfBlock: DWORD;
  end;
  {$ALIGN ON}
  PIMAGE_BASE_RELOCATION = ^IMAGE_BASE_RELOCATION;
{$IFEND}

{$IF NOT DECLARED(PIMAGE_DATA_DIRECTORY)}
type
  PIMAGE_DATA_DIRECTORY = ^IMAGE_DATA_DIRECTORY;
{$IFEND}

{$IF NOT DECLARED(PIMAGE_SECTION_HEADER)}
type
  PIMAGE_SECTION_HEADER = ^IMAGE_SECTION_HEADER;
{$IFEND}

{$IF NOT DECLARED(PIMAGE_EXPORT_DIRECTORY)}
type
  PIMAGE_EXPORT_DIRECTORY = ^IMAGE_EXPORT_DIRECTORY;
{$IFEND}

{$IF NOT DECLARED(PIMAGE_DOS_HEADER)}
type
  PIMAGE_DOS_HEADER = ^IMAGE_DOS_HEADER;
{$IFEND}

{$IF NOT DECLARED(PIMAGE_NT_HEADERS64)}
type
  IMAGE_NT_HEADERS64 = record
    Signature: DWORD;
    FileHeader: IMAGE_FILE_HEADER;
    OptionalHeader: IMAGE_OPTIONAL_HEADER64;
  end;
  PIMAGE_NT_HEADERS64 = ^IMAGE_NT_HEADERS64;
{$IFEND}

{$IF NOT DECLARED(PIMAGE_TLS_DIRECTORY64)}
type
  PIMAGE_TLS_DIRECTORY64 = ^IMAGE_TLS_DIRECTORY64; // Pointer to IMAGE_TLS_DIRECTORY64 structure
{$IFEND}

{$IF NOT DECLARED(PUINT_PTR)}
type
  PUINT_PTR = ^UINT_PTR; // Pointer to an unsigned integer type that can hold a pointer
{$IFEND}


const
  IMAGE_REL_BASED_ABSOLUTE = 0;
  IMAGE_REL_BASED_HIGHLOW = 3;
  IMAGE_REL_BASED_DIR64 = 10;

  IMAGE_DIRECTORY_ENTRY_EXPORT = 0;
  IMAGE_DIRECTORY_ENTRY_IMPORT = 1;
  IMAGE_DIRECTORY_ENTRY_TLS = 9;

  IMAGE_FILE_MACHINE_AMD64 = $8664;

  IMAGE_NT_SIGNATURE = $00004550;

  IMAGE_ORDINAL_FLAG64 = $8000000000000000;

  ProtectionFlags: array[Boolean, Boolean, Boolean] of DWORD =
  (
    (
      (PAGE_NOACCESS, PAGE_WRITECOPY),
      (PAGE_READONLY, PAGE_READWRITE)
    ),
    (
      (PAGE_EXECUTE, PAGE_EXECUTE_WRITECOPY),
      (PAGE_EXECUTE_READ, PAGE_EXECUTE_READWRITE)
    )
  );

  ERROR_BAD_EXE_FORMAT = 193;
  ERROR_MOD_NOT_FOUND = 126;
  ERROR_OUTOFMEMORY = 14;
  ERROR_PROC_NOT_FOUND = 127;
  ERROR_DLL_INIT_FAILED = 1114;

const
  IMAGE_SIZEOF_BASE_RELOCATION = SizeOf(IMAGE_BASE_RELOCATION);
  HOST_MACHINE = IMAGE_FILE_MACHINE_AMD64;

type
  TMemoryModuleRec = record
    Headers: PIMAGE_NT_HEADERS64;
    CodeBase: Pointer;
    Modules: array of HMODULE;
    NumModules: Integer;
    Initialized: Boolean;
    IsRelocated: Boolean;
    PageSize: DWORD;
  end;
  PMemoryModule = ^TMemoryModuleRec;

  TDllEntryProc = function(hinstDLL: HINST; fdwReason: DWORD; lpReserved: Pointer): BOOL; stdcall;

  TSectionFinalizeData = record
    Address: Pointer;
    AlignedAddress: Pointer;
    Size: SIZE_T;
    Characteristics: DWORD;
    Last: Boolean;
  end;

function GetProcAddress_Internal(hModule: HMODULE; lpProcName: LPCSTR): FARPROC; stdcall; external kernel32 name 'GetProcAddress';
function LoadLibraryA_Internal(lpLibFileName: LPCSTR): HMODULE; stdcall; external kernel32 name 'LoadLibraryA';
function FreeLibrary_Internal(hLibModule: HMODULE): BOOL; stdcall; external kernel32 name 'FreeLibrary';

procedure Abort;
begin
  raise TObject.Create;
end;

function StrComp(const Str1, Str2: PAnsiChar): Integer;
var
  P1, P2: PAnsiChar;
begin
  P1 := Str1;
  P2 := Str2;
  while True do
  begin
    if (P1^ <> P2^) or (P1^ = #0) then
      Exit(Ord(P1^) - Ord(P2^));
    Inc(P1);
    Inc(P2);
  end;
end;

{$IF NOT DECLARED(IMAGE_ORDINAL)}

function IMAGE_ORDINAL(Ordinal: NativeUInt): Word; inline;
begin
  Result := Ordinal and $FFFF;
end;
{$IFEND}

{$IF NOT DECLARED(IMAGE_SNAP_BY_ORDINAL)}

function IMAGE_SNAP_BY_ORDINAL(Ordinal: NativeUInt): Boolean; inline;
begin
  Result := ((Ordinal and IMAGE_ORDINAL_FLAG64) <> 0);
end;
{$IFEND}

function GET_HEADER_DICTIONARY(Module: PMemoryModule; Idx: Integer): PIMAGE_DATA_DIRECTORY;
begin
  Result := @((Module.Headers^.OptionalHeader.DataDirectory[Idx]));
end;

function ALIGN_DOWN(Address: Pointer; Alignment: DWORD): Pointer;
begin
  Result := Pointer(NativeUInt(Address) and not (Alignment - 1));
end;

function CopySections(data: Pointer; old_headers: PIMAGE_NT_HEADERS64; module: PMemoryModule): Boolean;
var
  I: Integer;
  LSize: Integer;
  LCodeBase: Pointer;
  LDest: Pointer;
  LSection: PIMAGE_SECTION_HEADER;
begin
  LCodeBase := module.CodeBase;
  LSection := PIMAGE_SECTION_HEADER(IMAGE_FIRST_SECTION(module.Headers));

  for I := 0 to module.Headers^.FileHeader.NumberOfSections - 1 do
  begin

    if LSection^.SizeOfRawData = 0 then
    begin
      LSize := old_headers^.OptionalHeader.SectionAlignment;
      if LSize > 0 then
      begin

        LDest := VirtualAlloc(
          PByte(LCodeBase) + LSection^.VirtualAddress,
          LSize,
          MEM_COMMIT,
          PAGE_READWRITE
        );

        if LDest = nil then
          Exit(False);

        LSection^.Misc.PhysicalAddress := LSection^.VirtualAddress;

        ZeroMemory(LDest, LSize);
      end;

      Inc(LSection);
      Continue;
    end;


    LDest := VirtualAlloc(
      PByte(LCodeBase) + LSection^.VirtualAddress,
      LSection^.SizeOfRawData,
      MEM_COMMIT,
      PAGE_READWRITE
    );

    if LDest = nil then
      Exit(False);

    CopyMemory(
      LDest,
      PByte(data) + LSection^.PointerToRawData,
      LSection^.SizeOfRawData
    );

    LSection^.Misc.PhysicalAddress := LSection^.VirtualAddress;

    Inc(LSection);
  end;

  Result := True;
end;

const
  ProtectionFlagsArray: array[Boolean, Boolean, Boolean] of DWORD =
  (
    (
      (PAGE_NOACCESS, PAGE_WRITECOPY),
      (PAGE_READONLY, PAGE_READWRITE)
    ),
    (
      (PAGE_EXECUTE, PAGE_EXECUTE_WRITECOPY),
      (PAGE_EXECUTE_READ, PAGE_EXECUTE_READWRITE)
    )
  );

function GetRealSectionSize(Module: PMemoryModule; Section: PIMAGE_SECTION_HEADER): DWORD;
begin
  Result := Section^.SizeOfRawData;

  if Result = 0 then
  begin
    if (Section^.Characteristics and IMAGE_SCN_CNT_INITIALIZED_DATA) <> 0 then
      Result := Module.Headers^.OptionalHeader.SizeOfInitializedData
    else if (Section^.Characteristics and IMAGE_SCN_CNT_UNINITIALIZED_DATA) <> 0 then
      Result := Module.Headers^.OptionalHeader.SizeOfUninitializedData;
  end;
end;

function FinalizeSection(Module: PMemoryModule; const SectionData: TSectionFinalizeData): Boolean;
var
  LProtect: DWORD;
  LOldProtect: DWORD;
  LExecutable: Boolean;
  LReadable: Boolean;
  LWriteable: Boolean;
begin
  if SectionData.Size = 0 then
    Exit(True);

  if (SectionData.Characteristics and IMAGE_SCN_MEM_DISCARDABLE) <> 0 then
  begin
    if (SectionData.Address = SectionData.AlignedAddress) and
       (SectionData.Last or
        (Module.Headers^.OptionalHeader.SectionAlignment = Module.PageSize) or
        (SectionData.Size mod Module.PageSize = 0)) then
    begin
      VirtualFree(SectionData.Address, SectionData.Size, MEM_DECOMMIT);
    end;
    Exit(True);
  end;

  LExecutable := (SectionData.Characteristics and IMAGE_SCN_MEM_EXECUTE) <> 0;
  LReadable   := (SectionData.Characteristics and IMAGE_SCN_MEM_READ) <> 0;
  LWriteable  := (SectionData.Characteristics and IMAGE_SCN_MEM_WRITE) <> 0;
  LProtect := ProtectionFlagsArray[LExecutable][LReadable][LWriteable];

  if (SectionData.Characteristics and IMAGE_SCN_MEM_NOT_CACHED) <> 0 then
    LProtect := LProtect or PAGE_NOCACHE;

  Result := VirtualProtect(SectionData.Address, SectionData.Size, LProtect, LOldProtect);
end;

function FinalizeSections(Module: PMemoryModule): Boolean;
var
  I: Integer;
  LSection: PIMAGE_SECTION_HEADER;
  LImageOffset: NativeUInt;
  LSectionData: TSectionFinalizeData;
  LSectionAddress: Pointer;
  LAlignedAddress: Pointer;
  LSectionSize: DWORD;
begin
  LSection := PIMAGE_SECTION_HEADER(IMAGE_FIRST_SECTION(Module.Headers));
  LImageOffset := NativeUInt(Module.CodeBase);


  LSectionData.Address := Pointer(LImageOffset + LSection^.VirtualAddress);
  LSectionData.AlignedAddress := ALIGN_DOWN(LSectionData.Address, Module.PageSize);
  LSectionData.Size := GetRealSectionSize(Module, LSection);
  LSectionData.Characteristics := LSection^.Characteristics;
  LSectionData.Last := False;
  Inc(LSection);

  for I := 1 to Module.Headers^.FileHeader.NumberOfSections - 1 do
  begin
    LSectionAddress := Pointer(LImageOffset + LSection^.VirtualAddress);
    LAlignedAddress := ALIGN_DOWN(LSectionData.Address, Module.PageSize);
    LSectionSize := GetRealSectionSize(Module, LSection);

    if (LSectionData.AlignedAddress = LAlignedAddress) or
       (PByte(LSectionData.Address) + LSectionData.Size > PByte(LAlignedAddress)) then
    begin
      if (LSection^.Characteristics and IMAGE_SCN_MEM_DISCARDABLE = 0) or
         (LSectionData.Characteristics and IMAGE_SCN_MEM_DISCARDABLE = 0) then
        LSectionData.Characteristics := (LSectionData.Characteristics or LSection^.Characteristics) and not IMAGE_SCN_MEM_DISCARDABLE
      else
        LSectionData.Characteristics := LSectionData.Characteristics or LSection^.Characteristics;

      LSectionData.Size := NativeUInt(LSectionAddress) + LSectionSize - NativeUInt(LSectionData.Address);
      Inc(LSection);
      Continue;
    end;

    if not FinalizeSection(Module, LSectionData) then
      Exit(False);

    LSectionData.Address := LSectionAddress;
    LSectionData.AlignedAddress := ALIGN_DOWN(LSectionData.Address, Module.PageSize);
    LSectionData.Size := LSectionSize;
    LSectionData.Characteristics := LSection^.Characteristics;

    Inc(LSection);
  end;

  LSectionData.Last := True;
  if not FinalizeSection(Module, LSectionData) then
    Exit(False);

  Result := True;
end;

function ExecuteTLS(Module: PMemoryModule): Boolean;
var
  LCodeBase: Pointer;
  LDirectory: PIMAGE_DATA_DIRECTORY;
  LTLS: PIMAGE_TLS_DIRECTORY64;
  LCallback: PPointer;

  function FixPtr(OldPtr: Pointer): Pointer;
  begin
    Result := Pointer(NativeUInt(OldPtr) - Module.Headers^.OptionalHeader.ImageBase + NativeUInt(LCodeBase));
  end;

begin
  Result := True;
  LCodeBase := Module.CodeBase;


  LDirectory := GET_HEADER_DICTIONARY(Module, IMAGE_DIRECTORY_ENTRY_TLS);
  if LDirectory^.VirtualAddress = 0 then
    Exit;


  LTLS := PIMAGE_TLS_DIRECTORY64(PByte(LCodeBase) + LDirectory^.VirtualAddress);

  LCallback := PPointer(LTLS^.AddressOfCallBacks);
  if LCallback <> nil then
  begin
    LCallback := FixPtr(LCallback);

    while LCallback^ <> nil do
    begin
      PIMAGE_TLS_CALLBACK(FixPtr(LCallback^))(LCodeBase, DLL_PROCESS_ATTACH, nil);
      Inc(LCallback);
    end;
  end;
end;

function PerformBaseRelocation(Module: PMemoryModule; Delta: NativeInt): Boolean;
var
  I: Cardinal;
  LCodeBase: Pointer;
  LDirectory: PIMAGE_DATA_DIRECTORY;
  LRelocation: PIMAGE_BASE_RELOCATION;
  LDest: Pointer;
  LRelInfo: ^UInt16;
  LPatchAddrHL: PDWORD;
  LPatchAddr64: PULONGLONG;
  LRelType: Integer;
  LOffset: Integer;
begin
  LCodeBase := Module.CodeBase;
  LDirectory := GET_HEADER_DICTIONARY(Module, IMAGE_DIRECTORY_ENTRY_BASERELOC); // Get base relocation directory
  if LDirectory^.Size = 0 then
    Exit(Delta = 0);

  LRelocation := PIMAGE_BASE_RELOCATION(PByte(LCodeBase) + LDirectory^.VirtualAddress);

  while LRelocation.VirtualAddress > 0 do
  begin
    LDest := Pointer(NativeUInt(LCodeBase) + LRelocation.VirtualAddress);
    LRelInfo := Pointer(NativeUInt(LRelocation) + IMAGE_SIZEOF_BASE_RELOCATION);

    for I := 0 to (LRelocation.SizeOfBlock - IMAGE_SIZEOF_BASE_RELOCATION) div 2 - 1 do
    begin
      LRelType := LRelInfo^ shr 12;
      LOffset := LRelInfo^ and $FFF;

      case LRelType of
        IMAGE_REL_BASED_ABSOLUTE:
          ;
        IMAGE_REL_BASED_HIGHLOW:
          begin
            LPatchAddrHL := PDWORD(NativeUInt(LDest) + NativeUInt(LOffset));
            Inc(LPatchAddrHL^, Delta);
          end;
        IMAGE_REL_BASED_DIR64:
          begin

            LPatchAddr64 := PULONGLONG(NativeUInt(LDest) + NativeUInt(LOffset));
            Inc(LPatchAddr64^, Delta);
          end;
      end;

      Inc(LRelInfo);
    end;

    LRelocation := PIMAGE_BASE_RELOCATION(NativeUInt(LRelocation) + LRelocation.SizeOfBlock);
  end;

  Result := True;
end;

function BuildImportTable(Module: PMemoryModule): Boolean; stdcall;
var
  LCodeBase: Pointer;
  LDirectory: PIMAGE_DATA_DIRECTORY;
  LImportDesc: PIMAGE_IMPORT_DESCRIPTOR;
  LThunkRef: PUINT_PTR;
  LFuncRef: ^FARPROC;
  LHandle: HMODULE;
  LThunkData: PIMAGE_IMPORT_BY_NAME;
begin
  LCodeBase := Module.CodeBase;
  Result := True;

  LDirectory := GET_HEADER_DICTIONARY(Module, IMAGE_DIRECTORY_ENTRY_IMPORT);
  if LDirectory^.Size = 0 then
    Exit(True);

  LImportDesc := PIMAGE_IMPORT_DESCRIPTOR(PByte(LCodeBase) + LDirectory^.VirtualAddress);

  while LImportDesc^.Name <> 0 do
  begin
    LHandle := LoadLibraryA_Internal(PAnsiChar(PByte(LCodeBase) + LImportDesc^.Name));
    if LHandle = 0 then
    begin
      SetLastError(ERROR_MOD_NOT_FOUND);
      Result := False;
      Break;
    end;

    try
      SetLength(Module.Modules, Module.NumModules + 1);
    except
      FreeLibrary_Internal(LHandle);
      SetLastError(ERROR_OUTOFMEMORY);
      Result := False;
      Break;
    end;

    Module.Modules[Module.NumModules] := LHandle;
    Inc(Module.NumModules);

    if LImportDesc^.OriginalFirstThunk <> 0 then
    begin
      LThunkRef := PUINT_PTR(PByte(LCodeBase) + LImportDesc^.OriginalFirstThunk);
      LFuncRef := Pointer(PByte(LCodeBase) + LImportDesc^.FirstThunk);
    end
    else
    begin
      LThunkRef := PUINT_PTR(PByte(LCodeBase) + LImportDesc^.FirstThunk);
      LFuncRef := Pointer(PByte(LCodeBase) + LImportDesc^.FirstThunk);
    end;

    while LThunkRef^ <> 0 do
    begin
      if IMAGE_SNAP_BY_ORDINAL(LThunkRef^) then
        LFuncRef^ := GetProcAddress_Internal(LHandle, PAnsiChar(IMAGE_ORDINAL(LThunkRef^)))
      else
      begin
        LThunkData := PIMAGE_IMPORT_BY_NAME(PByte(LCodeBase) + LThunkRef^);
        LFuncRef^ := GetProcAddress_Internal(LHandle, PAnsiChar(@LThunkData^.Name));
      end;

      if LFuncRef^ = nil then
      begin
        Result := False;
        Break;
      end;

      Inc(LFuncRef);
      Inc(LThunkRef);
    end;

    if not Result then
    begin
      FreeLibrary_Internal(LHandle);
      SetLastError(ERROR_PROC_NOT_FOUND);
      Break;
    end;

    Inc(LImportDesc);
  end;
end;

procedure MemoryFreeLibrary(Module: Pointer); stdcall;
var
  I: Integer;
  LDllEntry: TDllEntryProc;
  LMemModule: PMemoryModule;
begin
  if Module = nil then Exit;

  LMemModule := PMemoryModule(Module);

  if LMemModule^.Initialized then
  begin
    @LDllEntry := Pointer(PByte(LMemModule^.CodeBase) + LMemModule^.Headers^.OptionalHeader.AddressOfEntryPoint);
    LDllEntry(HINST(LMemModule^.CodeBase), DLL_PROCESS_DETACH, nil);
  end;

  if Length(LMemModule^.Modules) <> 0 then
  begin
    for I := 0 to LMemModule^.NumModules - 1 do
      if LMemModule^.Modules[I] <> 0 then
        FreeLibrary_Internal(LMemModule^.Modules[I]);

    SetLength(LMemModule^.Modules, 0);
  end;

  if LMemModule^.CodeBase <> nil then
    VirtualFree(LMemModule^.CodeBase, 0, MEM_RELEASE);

  HeapFree(GetProcessHeap(), 0, LMemModule);
end;

function MemoryLoadLibrary(Data: Pointer): Pointer; stdcall;
var
  LDosHeader: PIMAGE_DOS_HEADER;
  LOldHeader: PIMAGE_NT_HEADERS64;
  LCode: Pointer;
  LHeaders: Pointer;
  LLocationDelta: NativeInt;
  LSysInfo: SYSTEM_INFO;
  LDllEntry: TDllEntryProc;
  LSuccessfull: Boolean;
  LModule: PMemoryModule;
begin
  Result := nil;
  LModule := nil;

  try
    LDosHeader := PIMAGE_DOS_HEADER(Data);

    if (LDosHeader^.e_magic <> IMAGE_DOS_SIGNATURE) then
    begin
      SetLastError(ERROR_BAD_EXE_FORMAT);
      Exit;
    end;

    LOldHeader := PIMAGE_NT_HEADERS64(PByte(Data) + LDosHeader^._lfanew);

    if LOldHeader^.Signature <> IMAGE_NT_SIGNATURE then
    begin
      SetLastError(ERROR_BAD_EXE_FORMAT);
      Exit;
    end;

    if LOldHeader^.FileHeader.Machine <> IMAGE_FILE_MACHINE_AMD64 then
    begin
      SetLastError(ERROR_BAD_EXE_FORMAT);
      Exit;
    end;

    if (LOldHeader^.OptionalHeader.SectionAlignment and 1) <> 0 then
    begin
      SetLastError(ERROR_BAD_EXE_FORMAT);
      Exit;
    end;

    LCode := VirtualAlloc(
      Pointer(LOldHeader^.OptionalHeader.ImageBase),
      LOldHeader^.OptionalHeader.SizeOfImage,
      MEM_RESERVE or MEM_COMMIT,
      PAGE_READWRITE
    );

    if LCode = nil then
    begin
      LCode := VirtualAlloc(
        nil,
        LOldHeader^.OptionalHeader.SizeOfImage,
        MEM_RESERVE or MEM_COMMIT,
        PAGE_READWRITE
      );

      if LCode = nil then
      begin
        SetLastError(ERROR_OUTOFMEMORY);
        Exit;
      end;
    end;


    LModule := PMemoryModule(HeapAlloc(GetProcessHeap(), HEAP_ZERO_MEMORY, SizeOf(TMemoryModuleRec)));
    if LModule = nil then
    begin
      VirtualFree(LCode, 0, MEM_RELEASE);
      SetLastError(ERROR_OUTOFMEMORY);
      Exit;
    end;

    LModule^.CodeBase := LCode;
    LModule^.Headers := LOldHeader;
    GetNativeSystemInfo(LSysInfo);
    LModule^.PageSize := LSysInfo.dwPageSize;

    LHeaders := VirtualAlloc(
      LCode,
      LOldHeader^.OptionalHeader.SizeOfHeaders,
      MEM_COMMIT,
      PAGE_READWRITE
    );

    CopyMemory(
      LHeaders,
      Data,
      LOldHeader^.OptionalHeader.SizeOfHeaders
    );

    LModule^.Headers := PIMAGE_NT_HEADERS64(PByte(LHeaders) + LDosHeader^._lfanew);

    if not CopySections(Data, LOldHeader, LModule) then
      Abort;

    LLocationDelta := NativeUInt(LCode) - LOldHeader^.OptionalHeader.ImageBase;
    if LLocationDelta <> 0 then
      LModule^.IsRelocated := PerformBaseRelocation(LModule, LLocationDelta)
    else
      LModule^.IsRelocated := True;

    if not BuildImportTable(LModule) then
      Abort;

    if not FinalizeSections(LModule) then
      Abort;

    if not ExecuteTLS(LModule) then
      Abort;

    if LModule^.Headers^.OptionalHeader.AddressOfEntryPoint <> 0 then
    begin
      @LDllEntry := Pointer(PByte(LCode) + LModule^.Headers^.OptionalHeader.AddressOfEntryPoint);
      LSuccessfull := LDllEntry(HINST(LCode), DLL_PROCESS_ATTACH, nil);
      if not LSuccessfull then
      begin
        SetLastError(ERROR_DLL_INIT_FAILED);
        Abort;
      end;
      LModule^.Initialized := True;
    end;

    Result := LModule;
  except
    MemoryFreeLibrary(LModule);
    Exit;
  end;
end;

function MemoryGetProcAddress(Module: Pointer; const Name: PAnsiChar): Pointer; stdcall;
var
  LCodeBase: Pointer;
  LIdx: Integer;
  I: DWORD;
  LNameRef: PDWORD;
  LOrdinal: PWord;
  LExportDir: PIMAGE_EXPORT_DIRECTORY;
  LDirectory: PIMAGE_DATA_DIRECTORY;
  LTemp: PDWORD;
  LMemModule: PMemoryModule;
begin
  Result := nil;
  LMemModule := PMemoryModule(Module);

  LCodeBase := LMemModule^.CodeBase;

    LDirectory := GET_HEADER_DICTIONARY(LMemModule, IMAGE_DIRECTORY_ENTRY_EXPORT);
  if LDirectory^.Size = 0 then
  begin
    SetLastError(ERROR_PROC_NOT_FOUND);
    Exit;
  end;

  LExportDir := PIMAGE_EXPORT_DIRECTORY(PByte(LCodeBase) + LDirectory^.VirtualAddress);

  if (LExportDir^.NumberOfNames = 0) or (LExportDir^.NumberOfFunctions = 0) then
  begin
    SetLastError(ERROR_PROC_NOT_FOUND);
    Exit;
  end;

  LNameRef := PDWORD(PByte(LCodeBase) + LExportDir^.AddressOfNames);
  LOrdinal := PWord(PByte(LCodeBase) + LExportDir^.AddressOfNameOrdinals);
  LIdx := -1;

  for I := 0 to LExportDir^.NumberOfNames - 1 do
  begin
    if StrComp(Name, PAnsiChar(PByte(LCodeBase) + LNameRef^)) = 0 then
    begin
      LIdx := LOrdinal^;
      Break;
    end;
    Inc(LNameRef);
    Inc(LOrdinal);
  end;

  if (LIdx = -1) then
  begin
    SetLastError(ERROR_PROC_NOT_FOUND);
    Exit;
  end;

  if (DWORD(LIdx) >= LExportDir^.NumberOfFunctions) then
  begin
    SetLastError(ERROR_PROC_NOT_FOUND);
    Exit;
  end;

  LTemp := PDWORD(PByte(LCodeBase) + LExportDir^.AddressOfFunctions + LIdx * SizeOf(DWORD));
  Result := Pointer(PByte(LCodeBase) + LTemp^); // Calculate the absolute address of the function
end;
{$ENDREGION}

{$REGION ' PERFECTLOADER '}

{$REGION ' DATA '}
const PERFECT_LOADER: array[0..64511] of Byte = (
$4D, $5A, $90, $00, $03, $00, $00, $00, $04, $00, $00, $00, $FF, $FF, $00, $00,
$B8, $00, $00, $00, $00, $00, $00, $00, $40, $00, $00, $00, $00, $00, $00, $00,
$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,
$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $08, $01, $00, $00,
$0E, $1F, $BA, $0E, $00, $B4, $09, $CD, $21, $B8, $01, $4C, $CD, $21, $54, $68,
$69, $73, $20, $70, $72, $6F, $67, $72, $61, $6D, $20, $63, $61, $6E, $6E, $6F,
$74, $20, $62, $65, $20, $72, $75, $6E, $20, $69, $6E, $20, $44, $4F, $53, $20,
$6D, $6F, $64, $65, $2E, $0D, $0D, $0A, $24, $00, $00, $00, $00, $00, $00, $00,
$3F, $A6, $FB, $24, $7B, $C7, $95, $77, $7B, $C7, $95, $77, $7B, $C7, $95, $77,
$30, $BF, $96, $76, $7E, $C7, $95, $77, $30, $BF, $90, $76, $F3, $C7, $95, $77,
$30, $BF, $91, $76, $71, $C7, $95, $77, $6A, $41, $96, $76, $72, $C7, $95, $77,
$6A, $41, $91, $76, $75, $C7, $95, $77, $6A, $41, $90, $76, $57, $C7, $95, $77,
$30, $BF, $94, $76, $7E, $C7, $95, $77, $7B, $C7, $94, $77, $00, $C7, $95, $77,
$F8, $41, $90, $76, $7F, $C7, $95, $77, $F8, $41, $95, $76, $7A, $C7, $95, $77,
$F8, $41, $6A, $77, $7A, $C7, $95, $77, $F8, $41, $97, $76, $7A, $C7, $95, $77,
$52, $69, $63, $68, $7B, $C7, $95, $77, $00, $00, $00, $00, $00, $00, $00, $00,
$00, $00, $00, $00, $00, $00, $00, $00, $50, $45, $00, $00, $64, $86, $03, $00,
$AA, $59, $77, $67, $00, $00, $00, $00, $00, $00, $00, $00, $F0, $00, $22, $20,
$0B, $02, $0E, $2A, $00, $00, $01, $00, $00, $10, $00, $00, $00, $A0, $01, $00,
$50, $96, $02, $00, $00, $B0, $01, $00, $00, $00, $00, $80, $01, $00, $00, $00,
$00, $10, $00, $00, $00, $02, $00, $00, $06, $00, $00, $00, $00, $00, $00, $00,
$06, $00, $00, $00, $00, $00, $00, $00, $00, $C0, $02, $00, $00, $04, $00, $00,
$00, $00, $00, $00, $03, $00, $60, $01, $00, $00, $10, $00, $00, $00, $00, $00,
$00, $10, $00, $00, $00, $00, $00, $00, $00, $00, $10, $00, $00, $00, $00, $00,
$00, $10, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $10, $00, $00, $00,
$A4, $B2, $02, $00, $4C, $00, $00, $00, $DC, $B1, $02, $00, $C8, $00, $00, $00,
$00, $B0, $02, $00, $DC, $01, $00, $00, $00, $40, $02, $00, $68, $16, $00, $00,
$00, $00, $00, $00, $00, $00, $00, $00, $F0, $B2, $02, $00, $1C, $00, $00, $00,
$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,
$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,
$50, $A2, $02, $00, $40, $01, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,
$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,
$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,
$55, $50, $58, $30, $00, $00, $00, $00, $00, $A0, $01, $00, $00, $10, $00, $00,
$00, $00, $00, $00, $00, $04, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,
$00, $00, $00, $00, $80, $00, $00, $E0, $55, $50, $58, $31, $00, $00, $00, $00,
$00, $00, $01, $00, $00, $B0, $01, $00, $00, $F4, $00, $00, $00, $04, $00, $00,
$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $40, $00, $00, $E0,
$2E, $72, $73, $72, $63, $00, $00, $00, $00, $10, $00, $00, $00, $B0, $02, $00,
$00, $04, $00, $00, $00, $F8, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,
$00, $00, $00, $00, $40, $00, $00, $C0, $00, $00, $00, $00, $00, $00, $00, $00,
$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,
$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,
$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,
$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,
$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,
$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,
$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,
$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,
$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,
$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,
$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,
$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,
$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,
$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,
$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,
$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,
$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,
$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,
$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,
$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,
$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $34, $2E, $32, $34, $00,
$55, $50, $58, $21, $0D, $24, $0E, $0A, $3A, $D2, $22, $8E, $E1, $DC, $61, $54,
$BA, $7B, $02, $00, $49, $E6, $00, $00, $00, $44, $02, $00, $49, $0E, $00, $9D,
$1A, $03, $00, $24, $23, $3D, $AD, $A5, $DF, $6B, $FE, $F0, $17, $C9, $3F, $49,
$1C, $BA, $FE, $D1, $A8, $BA, $98, $3C, $E7, $FF, $10, $8D, $B3, $14, $2A, $06,
$96, $FF, $2B, $8B, $E0, $34, $A7, $03, $24, $7B, $78, $00, $E4, $9C, $DD, $28,
$96, $F5, $50, $E8, $B3, $46, $15, $F2, $29, $87, $86, $CD, $66, $00, $C0, $9B,
$7D, $EB, $05, $D0, $E8, $5D, $1F, $19, $E1, $70, $F4, $03, $AC, $94, $2C, $35,
$BB, $DB, $44, $AB, $9D, $D0, $22, $05, $F9, $34, $17, $A0, $D2, $7A, $7D, $EF,
$CC, $5E, $9A, $01, $A0, $27, $3C, $E3, $14, $35, $3B, $7A, $D5, $37, $B5, $BC,
$52, $35, $D4, $E5, $FC, $C6, $A8, $B1, $6B, $E2, $09, $EB, $11, $21, $0F, $37,
$9C, $36, $19, $A4, $44, $3C, $50, $01, $41, $98, $5B, $66, $51, $48, $A8, $06,
$F9, $29, $DD, $A1, $96, $C3, $A8, $45, $92, $CF, $F5, $1D, $CF, $B2, $4A, $78,
$A5, $04, $4E, $0E, $28, $FC, $8E, $DB, $5A, $8F, $1A, $5B, $BC, $9D, $BE, $3B,
$BE, $26, $D8, $09, $02, $97, $DA, $E0, $D4, $10, $A4, $4A, $A4, $18, $F1, $0C,
$A5, $EA, $74, $17, $71, $21, $71, $B6, $C7, $93, $F5, $2F, $8D, $B1, $4A, $38,
$17, $36, $DF, $51, $EF, $57, $79, $F2, $63, $EF, $14, $4A, $36, $E9, $46, $C6,
$A3, $11, $C6, $5B, $5F, $9B, $A1, $13, $14, $61, $EF, $49, $64, $6E, $BA, $DD,
$91, $73, $45, $41, $B1, $AC, $D6, $23, $71, $EF, $3A, $9D, $67, $51, $27, $DD,
$D1, $AB, $48, $CF, $CA, $D6, $B6, $18, $91, $84, $BB, $49, $E9, $34, $63, $1C,
$FB, $00, $AD, $46, $EC, $24, $7C, $08, $AB, $3D, $AC, $0C, $99, $A9, $72, $0A,
$66, $BE, $DE, $D8, $C7, $BF, $DE, $E4, $0B, $6C, $78, $86, $21, $76, $53, $57,
$48, $5E, $92, $03, $20, $6E, $B2, $FF, $11, $94, $6B, $4F, $2D, $3D, $C2, $6C,
$F5, $83, $D8, $AC, $6F, $14, $AF, $A0, $60, $A7, $CD, $5B, $60, $F3, $11, $3B,
$2C, $97, $DA, $89, $25, $16, $D2, $98, $A4, $E6, $0A, $2C, $4A, $58, $29, $15,
$53, $D1, $17, $D0, $71, $70, $38, $9C, $6C, $8B, $D4, $9E, $CE, $59, $BF, $59,
$02, $BA, $BE, $BD, $94, $54, $50, $7E, $58, $A7, $69, $09, $61, $83, $9D, $EE,
$04, $92, $D7, $A6, $30, $BB, $11, $90, $4B, $C9, $9B, $50, $99, $F0, $C5, $C7,
$3C, $F1, $FC, $29, $F6, $43, $C4, $E7, $B7, $DA, $00, $A3, $56, $9E, $53, $84,
$7D, $AF, $5A, $E7, $C7, $40, $55, $E6, $01, $79, $6E, $F1, $C3, $18, $FA, $CC,
$BF, $3A, $3C, $55, $FC, $2C, $DE, $75, $22, $65, $11, $BD, $E9, $88, $E7, $42,
$E0, $19, $28, $EB, $1B, $43, $AF, $53, $06, $3C, $C8, $80, $66, $57, $05, $6C,
$24, $60, $0A, $72, $27, $CD, $EF, $31, $59, $D0, $D2, $51, $F4, $AE, $0D, $30,
$AB, $E0, $74, $05, $A7, $ED, $82, $60, $E1, $3B, $6E, $A7, $5E, $15, $F8, $3D,
$3F, $53, $0C, $24, $FF, $10, $DA, $30, $CF, $D6, $4F, $57, $4F, $BD, $3D, $D6,
$95, $11, $37, $33, $5A, $20, $CD, $2C, $49, $DA, $47, $D6, $07, $7A, $3A, $E0,
$52, $ED, $4A, $1F, $09, $F1, $62, $11, $CF, $AE, $18, $74, $30, $18, $8D, $9E,
$A8, $C1, $3D, $16, $F3, $6D, $64, $4D, $EF, $87, $6A, $82, $68, $74, $83, $9F,
$B4, $C4, $3D, $E6, $B7, $C5, $D4, $B4, $57, $14, $BB, $67, $C1, $EB, $85, $E1,
$B0, $86, $CF, $B5, $7A, $74, $3A, $9A, $FD, $74, $59, $21, $53, $A4, $9E, $4A,
$74, $83, $7F, $40, $61, $8F, $A7, $F6, $AD, $85, $52, $D1, $12, $CB, $48, $68,
$0A, $29, $FA, $D0, $9E, $94, $7E, $D7, $57, $1F, $91, $91, $19, $E5, $65, $49,
$94, $54, $7B, $89, $8E, $EB, $22, $1A, $2D, $39, $D0, $C2, $88, $9B, $07, $2A,
$16, $6F, $99, $53, $C3, $A4, $72, $A1, $62, $67, $60, $16, $3C, $E1, $C9, $49,
$30, $16, $D1, $FD, $F7, $D8, $1A, $3F, $0E, $8B, $DB, $62, $B5, $43, $DA, $E0,
$7E, $73, $76, $63, $89, $8C, $15, $A8, $0C, $03, $64, $D5, $95, $6E, $0C, $65,
$B9, $92, $A8, $EE, $41, $3B, $BD, $A5, $B0, $F8, $79, $38, $2C, $A8, $A8, $12,
$35, $AB, $82, $9B, $3D, $9A, $C2, $EB, $5D, $00, $00, $D6, $E9, $E9, $8F, $CE,
$F4, $60, $DC, $87, $0B, $AB, $90, $D0, $27, $FC, $E1, $72, $40, $F6, $B6, $56,
$C4, $B8, $D8, $43, $F2, $DD, $5C, $32, $F7, $A6, $DC, $60, $2A, $CF, $4F, $DF,
$67, $BA, $87, $E0, $74, $40, $C6, $F2, $A6, $71, $98, $B7, $FB, $73, $3B, $BC,
$79, $2C, $37, $83, $53, $E3, $94, $0C, $0C, $06, $25, $4C, $E0, $93, $D6, $40,
$DD, $2A, $7E, $31, $BE, $11, $71, $0F, $D7, $B6, $60, $CE, $5D, $6B, $9D, $0A,
$A1, $E3, $45, $34, $0D, $B5, $48, $F0, $9D, $34, $CF, $40, $28, $2B, $88, $DE,
$8A, $E3, $53, $07, $5A, $82, $68, $3B, $C7, $4F, $8E, $07, $8C, $2B, $B1, $17,
$82, $1B, $74, $84, $D9, $7A, $73, $EC, $16, $9A, $61, $0A, $F0, $DE, $A3, $42,
$7A, $97, $18, $28, $70, $A6, $6E, $B7, $78, $07, $88, $1F, $C0, $05, $D2, $28,
$2A, $28, $4E, $60, $83, $CE, $FC, $38, $5E, $D4, $8F, $4F, $16, $E7, $DE, $86,
$2C, $07, $DB, $FF, $78, $74, $96, $A6, $EC, $CC, $05, $B4, $82, $33, $EF, $5E,
$9E, $B9, $ED, $01, $2B, $9E, $A9, $CD, $8B, $E0, $79, $95, $A8, $59, $C1, $6A,
$03, $AC, $AA, $71, $25, $E2, $ED, $2F, $BB, $D5, $22, $E8, $1F, $8E, $76, $F2,
$6F, $5E, $0C, $C2, $F1, $87, $86, $29, $4D, $38, $9F, $16, $F9, $CA, $E3, $B4,
$7F, $4C, $81, $BB, $4F, $15, $71, $06, $06, $9C, $E4, $60, $1E, $FF, $01, $A3,
$05, $C1, $92, $B8, $47, $C2, $47, $8C, $54, $0F, $FC, $D9, $EC, $E4, $16, $A1,
$B5, $B7, $FA, $A0, $CB, $00, $B4, $BA, $24, $37, $EE, $4F, $87, $6E, $2F, $43,
$6A, $45, $FF, $E0, $EE, $86, $DC, $FD, $EA, $97, $FF, $4F, $8A, $62, $EB, $2E,
$4D, $AE, $E9, $12, $A8, $DC, $BC, $9B, $2B, $D6, $BB, $9D, $FC, $D7, $70, $B2,
$CB, $DE, $67, $07, $E5, $75, $68, $13, $A4, $C8, $9A, $5A, $50, $AE, $8B, $3C,
$CB, $7E, $65, $B1, $91, $3B, $FA, $4C, $01, $27, $CA, $A0, $E7, $C0, $5C, $E9,
$B7, $9E, $42, $91, $38, $64, $8C, $2B, $49, $F8, $43, $42, $53, $87, $6C, $18,
$30, $77, $F8, $08, $A8, $62, $86, $3E, $94, $1B, $2D, $B1, $42, $72, $7D, $38,
$24, $13, $BD, $E4, $4D, $4B, $57, $B6, $80, $C9, $FD, $11, $FE, $86, $7A, $1B,
$A8, $C2, $A7, $67, $B6, $95, $94, $46, $4B, $1E, $00, $EA, $8B, $F9, $15, $96,
$A4, $F0, $E7, $37, $24, $90, $D6, $8C, $FB, $60, $73, $87, $BC, $E0, $7E, $D6,
$53, $79, $58, $26, $E0, $E1, $EA, $54, $62, $B5, $11, $E9, $95, $3E, $28, $B7,
$14, $80, $3B, $5B, $B2, $E4, $39, $06, $23, $BC, $4C, $4C, $4B, $DF, $5D, $F8,
$9B, $14, $E6, $12, $CA, $EB, $BE, $DA, $9A, $7C, $0E, $A5, $1D, $22, $F7, $CB,
$49, $C8, $38, $41, $36, $76, $9D, $A9, $59, $BC, $33, $6C, $A3, $34, $9B, $AD,
$2E, $5E, $6F, $E3, $52, $F9, $97, $30, $4D, $EB, $84, $19, $76, $2A, $96, $24,
$32, $47, $FF, $FB, $96, $0F, $7D, $1B, $BC, $95, $63, $C1, $28, $77, $28, $03,
$FE, $BA, $D6, $D8, $C4, $49, $14, $43, $F1, $F4, $A2, $25, $61, $06, $97, $78,
$90, $3B, $47, $A7, $8C, $F6, $43, $9D, $AA, $EA, $34, $CE, $39, $B3, $80, $58,
$4D, $9D, $62, $30, $E7, $A8, $5E, $65, $50, $30, $58, $3A, $A6, $C5, $7A, $79,
$84, $7F, $6F, $75, $46, $EC, $49, $E3, $52, $54, $9F, $20, $0F, $38, $EF, $72,
$2D, $28, $46, $EE, $99, $F9, $61, $8F, $82, $F7, $2B, $79, $D9, $2A, $7E, $0E,
$9E, $B3, $01, $56, $DB, $CC, $50, $6D, $35, $D6, $0F, $96, $4C, $B6, $22, $27,
$DF, $71, $C6, $55, $91, $56, $A9, $AC, $BE, $6C, $02, $9F, $15, $63, $DD, $CB,
$67, $03, $58, $B5, $D8, $6F, $93, $C5, $37, $C1, $D0, $6A, $43, $B9, $BE, $3A,
$CD, $B3, $B0, $BE, $EE, $5D, $F5, $03, $BB, $12, $5F, $1A, $47, $D3, $A4, $43,
$BD, $29, $FF, $E8, $14, $11, $FC, $55, $C3, $04, $79, $EF, $32, $BD, $C3, $23,
$0A, $32, $A2, $A8, $A0, $7A, $E6, $CE, $6F, $CF, $78, $EA, $3F, $E9, $05, $9C,
$4E, $BE, $98, $86, $CD, $7C, $18, $88, $48, $68, $6B, $9D, $79, $11, $20, $85,
$0E, $70, $6C, $51, $38, $2C, $C6, $1E, $89, $C8, $BA, $9D, $A0, $2E, $80, $FC,
$9C, $FF, $AE, $95, $09, $6D, $6B, $C5, $2F, $A8, $DB, $E9, $AD, $D5, $9F, $17,
$70, $DF, $E9, $8A, $85, $C9, $4D, $08, $56, $6F, $55, $FB, $54, $60, $3F, $2D,
$24, $67, $E8, $BC, $42, $BD, $04, $93, $F8, $ED, $5C, $92, $AF, $1D, $93, $E6,
$61, $E1, $35, $0D, $4A, $03, $09, $AB, $C5, $FF, $3E, $21, $A8, $9F, $A3, $27,
$33, $60, $D2, $60, $43, $81, $38, $CD, $67, $51, $CF, $E8, $CA, $32, $C7, $6A,
$46, $FD, $1B, $FC, $57, $57, $C6, $9D, $73, $FB, $C7, $EC, $7E, $0D, $9F, $0D,
$E2, $7E, $83, $FA, $34, $47, $FE, $28, $32, $BE, $7A, $4D, $E2, $45, $E0, $CB,
$77, $B8, $A0, $AF, $7D, $21, $17, $37, $33, $93, $FB, $D1, $3D, $D6, $91, $76,
$F1, $80, $ED, $96, $2A, $B4, $05, $09, $2F, $98, $EA, $5A, $5E, $48, $4F, $46,
$0E, $B4, $EB, $92, $A6, $F0, $CC, $6A, $43, $4A, $25, $ED, $8C, $E3, $2B, $24,
$07, $92, $23, $00, $C3, $78, $80, $89, $FD, $99, $39, $71, $C5, $DA, $E0, $88,
$67, $0E, $53, $61, $3B, $19, $7E, $5E, $2E, $23, $5D, $DE, $D2, $0A, $2F, $E0,
$93, $34, $DE, $9D, $03, $41, $64, $6C, $2C, $07, $AF, $6D, $C1, $C7, $FA, $24,
$02, $9C, $4E, $79, $FC, $44, $39, $9D, $4A, $1F, $4A, $62, $15, $4C, $5F, $5C,
$B2, $D3, $EE, $DB, $ED, $2E, $AE, $37, $4B, $F9, $47, $51, $A0, $2A, $21, $F0,
$A4, $90, $6F, $85, $D7, $1B, $42, $90, $C8, $0E, $F5, $64, $4E, $34, $BE, $9E,
$76, $B1, $CF, $C1, $CE, $6B, $46, $6F, $54, $D4, $6B, $29, $BD, $F2, $94, $17,
$25, $CB, $79, $68, $E4, $20, $89, $9B, $99, $AA, $57, $09, $93, $16, $F5, $83,
$5B, $41, $18, $C1, $1B, $43, $40, $22, $80, $87, $C6, $AC, $59, $4D, $A8, $2D,
$E7, $DD, $3D, $E6, $40, $5F, $AA, $45, $03, $5F, $A9, $FE, $42, $A3, $E3, $07,
$1A, $EF, $7D, $6A, $F1, $DB, $72, $A7, $62, $18, $42, $85, $86, $C8, $3B, $77,
$3C, $21, $E5, $55, $6B, $68, $33, $7A, $77, $4C, $02, $82, $21, $1B, $44, $69,
$20, $25, $05, $55, $3E, $8B, $59, $2E, $0D, $E4, $CC, $7D, $79, $8A, $31, $82,
$D7, $42, $04, $94, $F3, $46, $F7, $A7, $F3, $D9, $70, $2A, $25, $1F, $76, $7B,
$69, $25, $AA, $62, $43, $E6, $6A, $3D, $E9, $8C, $05, $B6, $3B, $43, $0A, $67,
$09, $DB, $D5, $3C, $EE, $D0, $4A, $F3, $62, $A6, $01, $C0, $B2, $A8, $8A, $CE,
$80, $D0, $5D, $97, $4E, $1C, $9B, $26, $81, $A9, $6C, $73, $13, $D5, $03, $DF,
$42, $D7, $77, $EE, $0D, $09, $2A, $F6, $D0, $42, $BF, $68, $31, $55, $4B, $33,
$69, $B3, $BC, $EF, $87, $D0, $FE, $E3, $A7, $A0, $19, $9C, $EA, $5B, $7A, $02,
$50, $7A, $3D, $F0, $17, $E4, $67, $D7, $41, $23, $EE, $B2, $16, $2E, $AB, $AB,
$7B, $8B, $19, $33, $18, $A1, $C1, $31, $D0, $EE, $EE, $B9, $C4, $32, $8E, $AB,
$7D, $40, $50, $89, $1B, $51, $EE, $8B, $5E, $42, $E6, $88, $43, $8C, $6D, $AD,
$3F, $DD, $BE, $0F, $50, $B2, $43, $77, $05, $CF, $96, $A2, $18, $2F, $AF, $B8,
$87, $50, $8C, $9B, $26, $1B, $57, $EC, $06, $3A, $9F, $8F, $66, $04, $72, $09,
$09, $7D, $6A, $8E, $A2, $B3, $C9, $16, $C8, $0C, $48, $BA, $26, $03, $37, $33,
$D5, $10, $E1, $94, $B4, $BC, $0D, $14, $F9, $9A, $D0, $AD, $EF, $6B, $90, $4B,
$E6, $16, $98, $11, $B5, $81, $D3, $2F, $BD, $9E, $D4, $F9, $2F, $38, $F9, $DA,
$C2, $55, $03, $E1, $AD, $AB, $5B, $52, $0F, $E2, $6A, $7F, $CC, $69, $B8, $75,
$A9, $0A, $A6, $70, $3F, $FE, $C7, $ED, $15, $12, $35, $63, $B5, $C1, $CA, $06,
$02, $7E, $E5, $9E, $E0, $7F, $A1, $37, $21, $5E, $3F, $D3, $9D, $FE, $DF, $F4,
$89, $73, $91, $92, $A6, $6C, $43, $55, $50, $49, $F6, $F2, $F4, $99, $2F, $09,
$A5, $6C, $B3, $86, $87, $A5, $C4, $AA, $5A, $75, $E9, $A3, $9B, $55, $0C, $1E,
$D9, $42, $ED, $2B, $9D, $21, $B0, $F3, $5A, $0E, $A1, $5A, $91, $74, $5E, $A7,
$A0, $AF, $34, $7D, $4F, $C1, $00, $53, $6E, $1A, $D4, $60, $1E, $31, $99, $E2,
$99, $8D, $11, $64, $A8, $8B, $BB, $21, $97, $0C, $5C, $FF, $B5, $50, $01, $8C,
$5F, $B2, $B9, $B4, $FA, $08, $9B, $79, $0E, $55, $95, $D6, $B9, $27, $54, $81,
$B1, $DA, $92, $AE, $06, $45, $D7, $05, $96, $5C, $4B, $A0, $80, $EC, $51, $00,
$03, $76, $55, $D4, $B4, $C5, $78, $9F, $11, $3B, $3A, $F3, $8A, $CE, $7A, $D9,
$47, $F4, $C6, $75, $66, $37, $F1, $B7, $7D, $E7, $3C, $C7, $2E, $24, $35, $86,
$CE, $7B, $98, $F4, $7E, $2F, $B5, $9D, $07, $0F, $B1, $26, $2B, $A9, $69, $F7,
$57, $F4, $D7, $82, $04, $18, $FC, $2D, $4B, $40, $1B, $39, $2A, $EE, $F7, $D1,
$EA, $63, $D0, $17, $64, $E9, $49, $0C, $8F, $87, $88, $76, $3F, $0F, $AF, $6A,
$DC, $94, $B2, $54, $F5, $7A, $8A, $C1, $A9, $09, $E0, $E7, $7D, $D4, $7C, $51,
$71, $35, $B2, $7A, $11, $5B, $74, $85, $FB, $9B, $C2, $BA, $DE, $4F, $6C, $E6,
$31, $4A, $12, $8A, $AB, $99, $7B, $7E, $08, $4D, $13, $01, $CD, $AA, $9A, $E8,
$00, $6B, $98, $DD, $BA, $F2, $31, $18, $64, $66, $65, $AB, $7D, $DE, $EF, $8A,
$BD, $8D, $34, $79, $58, $46, $4E, $EA, $61, $37, $38, $A8, $24, $AC, $45, $AE,
$1C, $35, $E9, $75, $E4, $15, $DE, $00, $2D, $46, $E0, $E7, $BB, $5A, $36, $F0,
$DF, $55, $AD, $E2, $ED, $FC, $A9, $52, $79, $4F, $F7, $E5, $2F, $BC, $F0, $4A,
$B2, $68, $AD, $C4, $2F, $49, $36, $01, $19, $B3, $D6, $62, $37, $B5, $3E, $76,
$E1, $67, $90, $0F, $34, $5D, $9D, $B3, $19, $7D, $A7, $A6, $00, $76, $B9, $10,
$93, $11, $CD, $D8, $D3, $75, $99, $E1, $FB, $C8, $3B, $03, $45, $A4, $5D, $F4,
$77, $88, $DE, $9E, $3E, $67, $86, $33, $B8, $62, $9F, $B9, $D0, $3D, $4A, $E0,
$0D, $B1, $D7, $BD, $F2, $C4, $58, $57, $16, $2D, $D9, $1A, $24, $1E, $0A, $A8,
$66, $2A, $E7, $2D, $59, $0E, $93, $CB, $F6, $0A, $0D, $64, $D0, $63, $83, $96,
$7B, $3A, $11, $2E, $74, $07, $BC, $1B, $24, $D1, $86, $45, $60, $10, $EE, $16,
$FB, $76, $4D, $B8, $26, $D4, $B5, $4B, $CA, $B1, $F9, $B1, $9F, $B6, $A4, $00,
$C8, $FF, $90, $75, $57, $A5, $C8, $E4, $AA, $83, $E7, $B7, $4E, $26, $B8, $21,
$BF, $BD, $65, $8C, $CB, $C7, $D2, $F5, $09, $EC, $7D, $85, $6B, $8C, $F6, $C3,
$C7, $B3, $A8, $15, $4F, $A9, $48, $ED, $16, $DD, $18, $25, $56, $7D, $82, $9E,
$15, $AD, $C8, $57, $E4, $CB, $BF, $9F, $55, $62, $62, $A0, $C1, $C7, $7F, $E3,
$BB, $74, $87, $06, $3C, $82, $16, $DB, $FC, $06, $9A, $3A, $B5, $26, $3B, $C4,
$4C, $F9, $A5, $17, $7E, $DA, $5B, $98, $F5, $B3, $59, $BF, $7F, $7D, $0D, $04,
$0A, $BB, $B2, $E3, $55, $F5, $C3, $E4, $4E, $44, $AA, $DB, $AB, $15, $CF, $E7,
$E3, $EC, $6E, $1C, $AF, $91, $E2, $14, $6E, $3F, $4C, $66, $FB, $FB, $3A, $A0,
$19, $05, $E3, $5A, $43, $91, $69, $D7, $41, $B3, $B2, $DB, $5C, $2C, $C9, $6C,
$70, $21, $50, $28, $74, $EF, $D4, $5F, $68, $E0, $53, $23, $65, $6E, $97, $AA,
$11, $4B, $7C, $DA, $BB, $7F, $39, $88, $11, $3B, $B9, $D0, $F7, $C0, $32, $3C,
$FD, $95, $AB, $3F, $09, $FA, $FD, $6A, $C2, $39, $D5, $AC, $ED, $FF, $4A, $9F,
$87, $7B, $3A, $0D, $2C, $7F, $8E, $21, $E7, $15, $32, $0D, $2F, $8E, $B0, $43,
$87, $5E, $D5, $0A, $E5, $B4, $D3, $59, $44, $97, $4B, $64, $B3, $14, $60, $CA,
$6F, $E7, $D7, $5A, $0A, $1B, $DA, $D3, $1F, $A9, $27, $15, $85, $B7, $EF, $DE,
$52, $DC, $10, $8C, $C2, $53, $77, $B4, $78, $E8, $5B, $96, $D8, $B7, $16, $23,
$38, $E4, $DB, $DC, $3A, $67, $59, $2A, $30, $8F, $C1, $31, $7A, $67, $3C, $C1,
$B5, $D3, $EE, $A1, $1A, $C1, $4F, $47, $F0, $C4, $63, $A2, $70, $21, $81, $79,
$64, $B2, $53, $3F, $FC, $EC, $47, $58, $BE, $3D, $63, $23, $BC, $D3, $00, $D4,
$E6, $EE, $5C, $F4, $56, $AA, $99, $64, $C9, $F6, $87, $A7, $6E, $5D, $D5, $E7,
$DB, $59, $48, $9F, $0F, $EC, $65, $43, $2D, $17, $16, $3D, $2D, $B8, $93, $E5,
$37, $36, $A8, $FF, $08, $A1, $C7, $86, $C0, $B5, $32, $4F, $2B, $EB, $C2, $86,
$BB, $C1, $42, $E5, $E4, $AF, $F8, $60, $2D, $8A, $0E, $88, $E9, $6F, $B9, $83,
$BA, $8E, $B4, $19, $35, $4F, $B1, $9B, $78, $A4, $88, $68, $C3, $EC, $D4, $FA,
$66, $E4, $03, $9F, $6A, $B0, $7E, $AE, $37, $33, $EF, $3B, $97, $45, $E4, $8B,
$0D, $A9, $8D, $45, $1E, $35, $B4, $74, $E7, $51, $9B, $D5, $0F, $2D, $49, $CF,
$BB, $61, $2D, $A8, $2B, $CB, $AD, $BC, $48, $57, $66, $21, $5D, $4E, $97, $90,
$EE, $D8, $44, $E6, $92, $1E, $42, $E0, $44, $68, $64, $B5, $81, $C8, $6A, $19,
$EB, $C0, $87, $A9, $20, $AC, $DC, $A9, $30, $2D, $D9, $A9, $8A, $1A, $B8, $C8,
$F1, $88, $80, $3B, $D4, $83, $35, $4C, $10, $39, $FA, $F1, $0B, $8B, $62, $1E,
$4E, $7A, $A6, $EE, $67, $04, $33, $44, $E2, $5E, $03, $49, $CD, $92, $2F, $2D,
$1B, $A4, $C3, $8D, $83, $BB, $91, $08, $CB, $47, $1C, $E1, $7B, $48, $62, $DA,
$F9, $EF, $01, $A0, $41, $94, $B1, $D9, $98, $1D, $84, $F1, $F0, $F8, $FF, $85,
$D3, $4F, $C5, $4D, $06, $7B, $3D, $71, $19, $55, $FA, $B6, $B2, $1E, $02, $35,
$8C, $E8, $F1, $36, $1D, $B0, $E8, $FF, $F6, $A6, $20, $97, $68, $D1, $66, $FD,
$4C, $99, $40, $EA, $E7, $15, $8F, $30, $BF, $10, $AD, $6D, $88, $A7, $C0, $49,
$94, $AE, $F6, $7E, $6F, $5E, $8B, $62, $EA, $8E, $BB, $0A, $E8, $E0, $01, $E2,
$D0, $78, $44, $1A, $9C, $D4, $38, $D5, $58, $EB, $D7, $72, $F8, $C4, $24, $D1,
$CE, $13, $63, $62, $73, $7B, $88, $61, $7E, $BE, $A2, $87, $A1, $03, $5D, $8C,
$E1, $68, $71, $2F, $2E, $DF, $68, $6E, $8D, $58, $92, $E8, $9B, $8B, $5E, $B6,
$A7, $8F, $0C, $E9, $CD, $2E, $47, $77, $D4, $81, $90, $67, $5B, $A1, $27, $91,
$BB, $21, $BD, $05, $5C, $C5, $AD, $BC, $85, $B0, $78, $94, $27, $59, $50, $29,
$A7, $9C, $AE, $33, $E3, $08, $3C, $75, $6D, $2E, $48, $BF, $D7, $01, $D1, $AA,
$CB, $E5, $56, $BF, $57, $FB, $0D, $D7, $43, $13, $38, $A2, $16, $1B, $C8, $BB,
$CB, $25, $85, $00, $D4, $84, $56, $45, $E4, $45, $FE, $A3, $95, $C3, $F3, $EE,
$0B, $35, $3C, $19, $97, $FE, $4A, $41, $A5, $55, $2C, $D3, $BE, $19, $1E, $7C,
$7B, $5B, $83, $1A, $BB, $73, $47, $C8, $69, $9C, $79, $58, $60, $4F, $BE, $AE,
$F4, $9F, $7F, $B7, $85, $3D, $E1, $2A, $EE, $7B, $11, $F7, $F4, $87, $16, $E0,
$49, $E0, $16, $B9, $37, $62, $9D, $31, $1C, $E7, $87, $77, $04, $EE, $84, $B8,
$0E, $B4, $B2, $18, $7A, $82, $6A, $96, $8A, $F5, $29, $64, $28, $93, $6C, $5D,
$EE, $4D, $B6, $68, $54, $B0, $00, $AE, $E1, $80, $2E, $D0, $0D, $19, $61, $0E,
$AB, $83, $8B, $5C, $93, $DD, $68, $23, $41, $94, $7F, $63, $7E, $06, $72, $4B,
$8E, $A8, $13, $A4, $90, $7D, $AC, $B7, $1D, $D3, $B2, $E7, $1F, $6B, $C9, $D8,
$5C, $54, $97, $BD, $88, $99, $F4, $DE, $F9, $7A, $E7, $FE, $C0, $A3, $6D, $36,
$14, $55, $64, $0A, $19, $EA, $06, $89, $B6, $82, $77, $E1, $DF, $83, $AA, $59,
$EC, $28, $9D, $FB, $68, $7C, $8C, $1F, $59, $CB, $EC, $BE, $47, $44, $BB, $BF,
$6B, $A8, $11, $E8, $A1, $7C, $3E, $7C, $10, $2F, $E3, $F6, $42, $8E, $C7, $CE,
$94, $7E, $05, $80, $B1, $2F, $AD, $03, $0E, $87, $93, $02, $74, $BF, $75, $BA,
$69, $44, $5C, $11, $5C, $83, $B9, $33, $34, $A3, $1F, $F1, $90, $23, $1F, $98,
$A4, $3F, $98, $F0, $3A, $B2, $F2, $92, $AA, $26, $A2, $A5, $32, $A2, $90, $79,
$0F, $CE, $DB, $57, $1D, $F4, $7E, $63, $CE, $60, $79, $35, $95, $4E, $B9, $B0,
$30, $DD, $A9, $38, $29, $AA, $1E, $A7, $28, $71, $A0, $40, $C8, $66, $65, $78,
$3C, $B8, $0E, $85, $90, $55, $A7, $D3, $BA, $BB, $24, $53, $8F, $D0, $C3, $DD,
$14, $14, $56, $28, $44, $39, $36, $D5, $3D, $C2, $35, $46, $41, $2B, $A8, $26,
$7A, $40, $7A, $23, $19, $F2, $7E, $74, $BA, $19, $7D, $E4, $9E, $53, $E0, $E2,
$B8, $E4, $4C, $4B, $DE, $97, $BE, $B3, $60, $10, $78, $34, $55, $AB, $67, $51,
$3A, $51, $58, $C5, $E3, $0D, $0C, $9E, $4B, $86, $59, $89, $8D, $32, $34, $A6,
$D8, $0D, $4A, $3D, $3E, $F6, $45, $04, $A4, $C5, $03, $7D, $F0, $1D, $09, $61,
$66, $BB, $0A, $E8, $F7, $9D, $0B, $DE, $32, $DB, $7C, $6C, $64, $D3, $5E, $94,
$B4, $33, $47, $95, $55, $F0, $2C, $A9, $53, $CE, $91, $C8, $88, $F1, $B5, $32,
$55, $F4, $F9, $BE, $3B, $90, $4F, $A9, $DE, $5D, $BE, $BB, $22, $A9, $FE, $F8,
$19, $04, $8C, $18, $65, $D9, $ED, $73, $EC, $29, $D2, $36, $A0, $FB, $DC, $DE,
$E3, $5C, $B6, $37, $D5, $4D, $57, $46, $FD, $72, $68, $A5, $9A, $FB, $70, $9B,
$CF, $98, $DE, $40, $E2, $21, $8E, $72, $FE, $F7, $23, $3D, $62, $00, $5F, $4C,
$49, $45, $82, $B7, $F6, $02, $00, $2D, $60, $61, $95, $CE, $63, $5A, $A5, $58,
$5A, $EF, $D5, $C7, $77, $12, $6C, $DE, $3B, $4F, $3D, $E1, $32, $9F, $2D, $0B,
$7F, $FA, $0B, $3E, $48, $71, $6E, $C9, $5D, $2D, $AE, $1B, $CC, $26, $0E, $A9,
$C0, $C9, $90, $82, $8D, $0F, $3A, $8D, $DD, $6D, $F5, $E1, $2F, $4F, $2F, $77,
$34, $E8, $9B, $C6, $4D, $2D, $A2, $9B, $1C, $08, $3A, $17, $6A, $C4, $E5, $A2,
$43, $69, $78, $5E, $3B, $E4, $52, $8F, $3B, $AE, $3A, $B1, $D6, $9D, $8A, $E9,
$FA, $A1, $72, $85, $3E, $B7, $EC, $DB, $7F, $CC, $DC, $50, $39, $1C, $40, $E1,
$75, $1C, $FD, $1C, $B1, $C7, $02, $47, $9C, $DC, $B3, $6F, $9A, $8A, $E1, $24,
$74, $37, $90, $D3, $54, $9F, $42, $49, $1E, $41, $17, $FA, $F7, $CE, $10, $96,
$0A, $2F, $D2, $43, $54, $BD, $27, $85, $40, $1E, $0D, $77, $25, $9D, $F7, $6C,
$DB, $12, $F0, $6A, $43, $5E, $2F, $AF, $63, $EE, $A0, $5D, $36, $E6, $75, $8B,
$CF, $F1, $75, $65, $B7, $3D, $C4, $BE, $D6, $A5, $A8, $73, $A1, $02, $29, $CF,
$C5, $BB, $4C, $46, $AF, $41, $6C, $72, $AC, $9F, $C9, $F6, $AD, $3E, $35, $71,
$81, $81, $74, $83, $63, $59, $A3, $ED, $74, $6C, $50, $70, $C3, $85, $94, $AF,
$5C, $DD, $4B, $6E, $52, $D5, $35, $F7, $99, $F3, $23, $1E, $BF, $0F, $8C, $8F,
$57, $C4, $09, $23, $EB, $F0, $F1, $63, $5F, $E5, $A1, $80, $93, $CF, $54, $CD,
$25, $0B, $16, $9A, $87, $04, $A7, $C6, $94, $BC, $C9, $40, $FD, $64, $B4, $8B,
$99, $6F, $05, $2D, $C7, $2E, $76, $25, $8D, $63, $5C, $E1, $54, $5D, $23, $55,
$58, $A2, $56, $08, $21, $0F, $A3, $D8, $A5, $75, $19, $73, $C5, $4D, $48, $76,
$DE, $9F, $87, $D2, $22, $95, $1B, $53, $80, $D3, $A0, $F0, $4D, $A5, $44, $B7,
$DA, $56, $31, $71, $29, $0F, $08, $14, $12, $4F, $4F, $EC, $FB, $A2, $5C, $05,
$10, $BF, $9F, $F6, $3D, $58, $A5, $73, $A6, $17, $E0, $B4, $FA, $85, $68, $42,
$FE, $15, $43, $98, $B9, $4D, $72, $BA, $F4, $79, $DD, $CE, $49, $F2, $78, $61,
$9B, $20, $FD, $59, $F5, $88, $EF, $95, $23, $73, $9C, $F5, $E4, $B8, $56, $1F,
$1D, $0D, $56, $A7, $F9, $C7, $2E, $0D, $E6, $C6, $7B, $71, $94, $CD, $86, $C2,
$61, $FA, $A0, $67, $D1, $81, $7D, $1B, $33, $32, $23, $97, $CC, $5B, $D0, $6E,
$25, $02, $C1, $E6, $A9, $56, $F4, $CE, $52, $46, $6F, $D5, $CA, $99, $25, $5B,
$07, $95, $35, $58, $03, $E6, $DE, $E1, $BA, $A3, $A3, $32, $F6, $47, $EE, $8B,
$1D, $2E, $D6, $A1, $BA, $A0, $54, $7D, $8E, $52, $45, $BE, $D1, $E1, $6C, $E7,
$E5, $89, $D6, $33, $05, $DB, $EE, $1C, $6B, $3E, $3D, $AE, $05, $48, $DD, $07,
$5C, $D6, $48, $E9, $F9, $E3, $C2, $6E, $A5, $99, $A5, $44, $BC, $DF, $C5, $7B,
$21, $01, $32, $53, $D6, $5E, $7B, $85, $F7, $C7, $6F, $CF, $DA, $D0, $55, $D2,
$FE, $68, $2A, $F9, $41, $98, $D8, $CA, $79, $5A, $98, $4E, $C7, $5A, $B8, $A7,
$3F, $8C, $55, $C8, $44, $29, $EF, $E8, $F0, $1B, $8A, $20, $C4, $63, $95, $8D,
$4E, $3B, $C1, $20, $14, $F6, $24, $36, $DC, $EA, $B1, $CF, $77, $88, $81, $FD,
$2C, $2E, $E9, $E0, $0D, $72, $F3, $C3, $86, $AB, $D2, $2F, $7B, $3F, $FE, $16,
$82, $75, $B1, $3F, $B6, $A5, $87, $51, $5C, $E2, $D0, $B3, $1E, $0F, $A7, $DB,
$38, $36, $6E, $7B, $20, $DA, $75, $8A, $30, $73, $63, $CE, $10, $4F, $C7, $AD,
$34, $C5, $5D, $9F, $EF, $60, $25, $EA, $FD, $EB, $68, $4A, $30, $77, $98, $BB,
$1F, $6A, $63, $A7, $65, $E0, $25, $B6, $1E, $4B, $70, $2A, $55, $F8, $CE, $31,
$0D, $6A, $78, $79, $FA, $57, $D2, $9A, $7B, $DF, $18, $BA, $6D, $A4, $66, $FB,
$96, $5E, $E5, $BC, $E6, $FE, $35, $A4, $D9, $78, $40, $C3, $EA, $85, $CE, $68,
$D8, $24, $9F, $57, $72, $31, $C0, $99, $38, $AB, $A5, $32, $DE, $01, $F0, $9B,
$7F, $73, $BF, $1D, $D3, $98, $E7, $00, $9B, $12, $5F, $16, $3F, $5C, $BC, $0D,
$65, $45, $AB, $6B, $EE, $12, $11, $0F, $00, $A7, $3D, $D7, $E4, $86, $F0, $07,
$30, $16, $2D, $5C, $9A, $5C, $54, $B0, $A3, $01, $8A, $1E, $CA, $21, $15, $01,
$96, $5F, $AB, $D1, $3E, $EB, $7B, $54, $3F, $FE, $09, $8A, $68, $56, $33, $96,
$4E, $86, $66, $86, $A2, $E4, $7A, $79, $C6, $6D, $EA, $24, $BD, $76, $B8, $64,
$BE, $D3, $9D, $1F, $40, $88, $5A, $3D, $9A, $E1, $71, $32, $A6, $74, $F2, $D0,
$4D, $7A, $34, $27, $CC, $1A, $47, $96, $8A, $C9, $E5, $69, $DF, $98, $17, $2F,
$6D, $1E, $36, $21, $A7, $AB, $1F, $69, $47, $48, $B2, $E1, $FE, $C0, $E0, $89,
$64, $52, $97, $3D, $E3, $7D, $DA, $0D, $47, $C5, $B7, $9A, $04, $85, $8F, $3C,
$E4, $CA, $45, $13, $0B, $2C, $06, $A9, $27, $DA, $81, $02, $DB, $73, $EF, $CF,
$DF, $B5, $B7, $D1, $33, $03, $10, $03, $A2, $C9, $C7, $0D, $58, $4A, $97, $0D,
$C5, $4A, $8C, $72, $3A, $C7, $02, $3C, $94, $A6, $05, $0C, $C2, $D1, $B6, $37,
$60, $6A, $04, $4D, $FC, $6F, $DE, $A6, $1E, $85, $29, $63, $B9, $D6, $0A, $30,
$D2, $2A, $39, $F4, $BC, $82, $19, $D9, $E1, $F3, $28, $7B, $9D, $3B, $B5, $B8,
$13, $5B, $7C, $09, $C8, $14, $AE, $F1, $D2, $A5, $F3, $39, $D7, $C4, $29, $A1,
$44, $72, $FC, $36, $6F, $3B, $63, $C6, $63, $F3, $48, $F0, $4F, $99, $16, $2C,
$89, $0B, $41, $99, $E5, $90, $F3, $29, $3D, $36, $53, $16, $4E, $CF, $18, $1B,
$20, $26, $7F, $2C, $50, $81, $E0, $2C, $28, $D5, $4D, $A9, $02, $E7, $4A, $54,
$EA, $A0, $32, $7D, $A0, $76, $45, $F6, $CA, $D2, $4F, $47, $16, $88, $40, $9C,
$0A, $F5, $11, $76, $FC, $56, $66, $44, $B1, $15, $F3, $8D, $1D, $67, $71, $A7,
$CA, $D4, $9C, $CE, $C1, $9E, $10, $CD, $11, $7A, $2D, $95, $F7, $06, $52, $07,
$F9, $9C, $99, $31, $6A, $49, $8E, $1B, $07, $F4, $A7, $C9, $41, $8B, $BC, $36,
$F8, $8B, $83, $C7, $22, $A1, $9F, $09, $47, $97, $AE, $76, $38, $CA, $67, $6A,
$6B, $3C, $14, $DF, $33, $D1, $C0, $80, $A0, $F1, $88, $35, $29, $1B, $98, $77,
$80, $B8, $12, $CE, $09, $44, $3F, $B8, $F4, $B1, $75, $67, $A1, $21, $AE, $6E,
$FE, $13, $D9, $20, $88, $BC, $02, $06, $0F, $F3, $F7, $C7, $53, $57, $7E, $40,
$82, $BD, $97, $BE, $28, $5B, $B1, $47, $69, $6C, $72, $4F, $3A, $A9, $E0, $B3,
$0C, $B7, $B9, $14, $73, $9B, $56, $62, $BD, $3E, $68, $34, $8A, $16, $BC, $E5,
$41, $0C, $0D, $B4, $F4, $67, $00, $E9, $B8, $CA, $A5, $08, $34, $8A, $56, $77,
$C3, $F0, $F8, $FA, $3A, $17, $2B, $49, $CB, $1B, $67, $16, $53, $F3, $CF, $90,
$D8, $54, $47, $97, $1B, $20, $5E, $23, $B7, $22, $80, $C6, $17, $11, $EC, $F8,
$67, $6C, $1B, $4D, $ED, $0E, $E7, $A8, $53, $CF, $FE, $33, $A8, $15, $70, $28,
$B1, $F8, $DA, $73, $CE, $D3, $6C, $CE, $7F, $4D, $5D, $0B, $3C, $E8, $00, $51,
$11, $64, $8C, $95, $84, $9A, $9E, $44, $04, $66, $C4, $5E, $53, $A6, $87, $E8,
$B0, $08, $1F, $B9, $98, $CF, $E0, $14, $89, $88, $9A, $12, $07, $E9, $A2, $E1,
$D1, $2D, $96, $D8, $91, $76, $7E, $CE, $93, $D4, $94, $CC, $28, $06, $01, $E0,
$B6, $AA, $F2, $DF, $E1, $EF, $4F, $16, $13, $E8, $E2, $14, $5E, $BA, $E2, $9C,
$75, $8A, $6D, $8A, $A0, $95, $3A, $03, $91, $AD, $1B, $1F, $BD, $04, $CE, $13,
$58, $3A, $86, $8D, $A6, $73, $76, $BE, $35, $20, $32, $9F, $C3, $F5, $17, $F0,
$B6, $F1, $B2, $B7, $D2, $91, $A0, $E5, $82, $56, $CB, $C1, $A5, $D6, $70, $A7,
$00, $30, $E6, $E0, $13, $F5, $D7, $0A, $92, $24, $BE, $54, $A3, $B2, $B4, $36,
$BF, $E6, $9D, $CD, $88, $9E, $68, $6E, $AE, $1F, $8A, $D5, $C4, $69, $CA, $48,
$D6, $D0, $E1, $87, $C2, $61, $50, $45, $54, $5D, $64, $D7, $7C, $B0, $89, $CE,
$80, $48, $BB, $02, $CA, $D1, $F1, $B9, $B0, $F4, $C1, $F6, $92, $40, $85, $24,
$38, $EB, $6E, $EF, $8E, $69, $E7, $0A, $BB, $42, $44, $32, $D2, $54, $B1, $F6,
$DD, $EA, $21, $E0, $7D, $87, $60, $49, $37, $49, $63, $C4, $29, $CF, $A5, $BA,
$62, $6E, $85, $B1, $7F, $66, $F3, $2C, $7B, $DE, $40, $55, $6A, $8D, $CB, $A7,
$50, $61, $F8, $5D, $99, $D0, $B9, $2A, $80, $84, $55, $FB, $C4, $1C, $66, $0C,
$DD, $FA, $E0, $55, $5C, $07, $6C, $77, $0E, $0A, $EF, $A6, $8F, $F8, $7F, $80,
$49, $08, $B2, $35, $F8, $AC, $95, $D2, $F1, $48, $5D, $F6, $A4, $4E, $85, $49,
$1D, $FB, $3C, $0C, $E2, $1C, $99, $CE, $4A, $A5, $FF, $EA, $28, $0D, $B1, $97,
$77, $68, $01, $28, $AB, $43, $6B, $88, $44, $80, $E6, $80, $A0, $49, $24, $F3,
$EB, $43, $A7, $B7, $2B, $32, $CE, $E2, $8C, $55, $2B, $61, $C3, $44, $DE, $9A,
$7E, $D5, $50, $4E, $0B, $53, $0A, $6F, $08, $FE, $39, $EB, $64, $29, $73, $2B,
$43, $93, $AA, $E9, $48, $A7, $98, $25, $0C, $D3, $89, $CE, $E2, $5E, $95, $E1,
$3B, $EE, $06, $13, $8F, $80, $D5, $FF, $74, $7E, $7B, $11, $4D, $19, $D3, $D5,
$73, $C4, $5D, $2B, $D7, $CF, $1C, $72, $01, $2D, $94, $B6, $B3, $75, $00, $44,
$07, $7C, $CE, $6A, $EC, $BD, $AE, $3C, $05, $0A, $6E, $62, $3A, $65, $D0, $41,
$63, $E2, $A2, $82, $A2, $76, $CB, $72, $B1, $71, $14, $59, $AD, $20, $81, $37,
$4E, $5B, $98, $C5, $53, $9C, $04, $8E, $7C, $43, $BB, $1F, $13, $82, $E1, $4C,
$9D, $88, $4C, $EF, $58, $27, $74, $9D, $4F, $9B, $4E, $27, $C2, $51, $6D, $14,
$19, $7B, $16, $16, $FA, $BA, $95, $1F, $21, $81, $DC, $F5, $A5, $6C, $08, $CF,
$E5, $D8, $3C, $5C, $3E, $83, $54, $94, $ED, $75, $CB, $9F, $B5, $C5, $D4, $94,
$2D, $FB, $5D, $4E, $93, $BF, $B8, $F7, $2B, $EA, $82, $A5, $9E, $85, $BB, $C4,
$8A, $22, $90, $AA, $C2, $DE, $DB, $87, $49, $E4, $30, $5F, $1A, $5E, $83, $4A,
$CB, $77, $CF, $8B, $8F, $D2, $90, $DE, $AE, $5F, $39, $BB, $80, $D3, $0D, $67,
$3C, $00, $DD, $A3, $A8, $ED, $1E, $E8, $0A, $A0, $14, $55, $65, $1F, $E4, $32,
$32, $6A, $E5, $33, $74, $57, $54, $B2, $62, $73, $12, $BC, $D5, $52, $C2, $03,
$84, $EC, $B0, $E9, $66, $DC, $52, $4C, $69, $D9, $CB, $34, $C2, $20, $E9, $1A,
$B2, $F5, $7A, $02, $AB, $2A, $00, $AE, $07, $9F, $D6, $09, $9C, $BA, $C5, $BA,
$FB, $92, $77, $EA, $B6, $FE, $5A, $07, $59, $F4, $D3, $3E, $02, $87, $C5, $BC,
$81, $43, $B2, $A0, $E6, $26, $FD, $47, $39, $E6, $A9, $8E, $AE, $B8, $47, $6C,
$A6, $A7, $E5, $6B, $81, $BD, $97, $89, $EC, $73, $AC, $32, $0E, $0E, $2A, $80,
$2F, $8F, $38, $1F, $69, $7D, $14, $69, $68, $5D, $DB, $BA, $9E, $A3, $57, $E5,
$E7, $56, $1A, $26, $2B, $F8, $BE, $99, $D5, $41, $17, $67, $44, $20, $7A, $60,
$D5, $D0, $47, $EE, $1F, $4C, $E3, $4D, $AC, $53, $2E, $4A, $6C, $DD, $D3, $E2,
$52, $A8, $FB, $54, $0A, $0D, $9D, $1A, $39, $BB, $7A, $51, $FB, $32, $63, $AC,
$87, $49, $0C, $26, $74, $BD, $7F, $E0, $EA, $31, $74, $D0, $29, $33, $14, $14,
$12, $29, $43, $C8, $12, $B4, $72, $B2, $EF, $E5, $3C, $F4, $AB, $45, $68, $1A,
$9E, $67, $60, $B2, $5E, $F2, $48, $35, $3A, $03, $30, $CE, $74, $59, $DF, $41,
$DA, $89, $0A, $41, $4E, $5F, $DF, $02, $CC, $A7, $72, $BF, $82, $27, $3E, $1C,
$0D, $E9, $13, $E0, $3A, $51, $2C, $EC, $5C, $BB, $F3, $A5, $E9, $B8, $76, $03,
$B4, $32, $5D, $B7, $DE, $E8, $20, $D8, $38, $20, $38, $B1, $67, $53, $C8, $10,
$8B, $05, $13, $29, $84, $7C, $96, $03, $C2, $3C, $EB, $04, $23, $AB, $3B, $B6,
$7A, $9A, $75, $0F, $59, $5A, $DC, $8F, $F5, $EA, $36, $27, $38, $FC, $38, $D2,
$21, $C7, $2C, $30, $A5, $9A, $B2, $02, $56, $A4, $B9, $FB, $AB, $80, $1F, $C1,
$F6, $3F, $F2, $6E, $7E, $91, $E4, $55, $1B, $1D, $F0, $4A, $74, $BB, $D1, $2B,
$F2, $BE, $D7, $71, $9E, $22, $1A, $9E, $B6, $15, $BB, $8B, $9C, $D2, $66, $28,
$75, $2E, $4A, $07, $21, $03, $45, $00, $D9, $27, $81, $A6, $69, $18, $9B, $38,
$F9, $83, $C1, $20, $A8, $D7, $37, $48, $2E, $B4, $DD, $BE, $DB, $23, $DF, $F5,
$82, $4E, $48, $17, $5A, $2B, $3B, $5A, $94, $F5, $02, $1D, $53, $7C, $71, $6A,
$99, $AB, $6F, $15, $DF, $57, $F6, $72, $EF, $7A, $1D, $72, $5F, $05, $C9, $0E,
$C4, $4B, $95, $E5, $D5, $66, $C7, $61, $7C, $F0, $CB, $63, $4B, $FC, $D0, $DE,
$AE, $6F, $60, $D7, $A9, $27, $91, $D7, $D3, $BD, $6E, $0D, $08, $1A, $33, $C3,
$01, $52, $4C, $B7, $B2, $24, $B9, $14, $31, $CA, $C0, $B6, $C3, $E7, $0D, $57,
$3E, $E3, $D1, $63, $36, $38, $E6, $0D, $01, $FF, $9F, $C9, $67, $30, $FF, $FC,
$9C, $8F, $28, $0D, $6A, $60, $34, $FF, $8A, $E8, $09, $A4, $B2, $E2, $4F, $0D,
$41, $17, $04, $C2, $A9, $D2, $EC, $97, $82, $81, $BB, $87, $0F, $E5, $98, $BC,
$60, $2A, $78, $8E, $FB, $7B, $DE, $7D, $ED, $A8, $B0, $EA, $45, $9C, $43, $78,
$62, $4B, $0F, $F5, $21, $4B, $2F, $DA, $AD, $1A, $E9, $70, $13, $75, $9A, $84,
$3F, $5F, $49, $E6, $67, $25, $70, $3C, $55, $AA, $EB, $B7, $06, $FE, $DA, $36,
$32, $BC, $8B, $63, $55, $4C, $B5, $19, $23, $32, $DB, $ED, $37, $E4, $FE, $F5,
$56, $93, $4C, $C1, $A9, $62, $88, $E5, $6C, $B4, $DC, $73, $9E, $6B, $BF, $D1,
$95, $07, $AE, $20, $4D, $8E, $C9, $A0, $2E, $19, $48, $7D, $B6, $6E, $A3, $88,
$F4, $52, $E9, $0E, $8D, $C7, $C2, $65, $70, $10, $78, $D0, $DE, $5A, $CA, $96,
$F5, $0F, $DD, $44, $60, $4D, $FD, $CC, $23, $3E, $8D, $38, $84, $19, $36, $49,
$A5, $BC, $CC, $16, $20, $10, $5A, $0F, $03, $F2, $A9, $51, $1D, $25, $3A, $93,
$8C, $8D, $89, $C5, $7E, $D2, $27, $85, $BD, $66, $42, $6F, $16, $96, $83, $DE,
$18, $05, $80, $1B, $18, $5C, $08, $20, $3E, $0E, $40, $AE, $25, $DA, $F8, $29,
$EF, $D2, $72, $74, $48, $66, $94, $6E, $AF, $75, $DF, $CB, $2F, $E0, $24, $8C,
$48, $56, $0A, $BC, $50, $97, $3E, $70, $80, $DD, $CF, $9F, $82, $D1, $8C, $07,
$26, $1F, $00, $3A, $E1, $05, $9D, $78, $F8, $0E, $F8, $67, $D2, $CC, $81, $1A,
$93, $D4, $37, $16, $50, $E7, $5E, $47, $DD, $7B, $25, $E4, $1B, $EC, $F6, $02,
$17, $20, $0E, $4A, $F5, $80, $09, $53, $66, $DA, $AF, $7F, $D1, $A4, $D5, $E0,
$3D, $C9, $8A, $74, $26, $DF, $2E, $7C, $1A, $41, $BD, $DD, $A0, $34, $DD, $00,
$E0, $D3, $C6, $FC, $B1, $F7, $71, $94, $F7, $4E, $6D, $C0, $57, $60, $E9, $5B,
$5F, $BA, $93, $C8, $9B, $50, $E7, $07, $F3, $C2, $47, $1B, $9B, $3C, $85, $0C,
$CB, $3C, $8C, $67, $E8, $33, $1D, $C4, $98, $70, $8A, $C6, $7B, $3E, $1B, $1B,
$CA, $A9, $22, $24, $FF, $9D, $FE, $CE, $FE, $6F, $32, $99, $36, $74, $D7, $22,
$30, $DD, $E4, $24, $8A, $EB, $B0, $08, $90, $3D, $29, $AD, $6F, $C9, $58, $61,
$1D, $54, $DB, $E8, $15, $7E, $42, $19, $4E, $F1, $15, $ED, $40, $25, $33, $26,
$90, $6A, $E9, $41, $22, $F9, $D2, $EB, $B9, $52, $2F, $EF, $DE, $13, $D0, $D8,
$4D, $BD, $FD, $D5, $E8, $2C, $B2, $0E, $FC, $3F, $AA, $24, $96, $2A, $17, $F9,
$C3, $50, $7E, $F9, $A4, $E5, $4E, $A8, $02, $10, $A0, $C2, $98, $C1, $21, $A3,
$53, $89, $88, $4E, $B9, $58, $EF, $9B, $D2, $C4, $67, $AD, $FE, $28, $90, $60,
$55, $A5, $B0, $84, $78, $82, $EC, $34, $03, $F5, $48, $1D, $AD, $58, $DC, $CC,
$6B, $6C, $63, $79, $E3, $81, $EC, $76, $BE, $3B, $85, $32, $6B, $20, $49, $6C,
$18, $7A, $41, $EF, $5E, $AE, $C2, $1F, $28, $C5, $5F, $60, $94, $6D, $45, $F7,
$20, $F6, $71, $95, $81, $31, $78, $6B, $DF, $6B, $2A, $48, $70, $EB, $35, $85,
$89, $44, $08, $3B, $D2, $64, $28, $99, $9E, $94, $10, $15, $F5, $93, $E1, $AC,
$B1, $87, $54, $BD, $45, $0B, $30, $2C, $21, $35, $80, $0D, $05, $2B, $F0, $1A,
$DD, $9C, $0B, $E3, $95, $F7, $28, $8F, $72, $A6, $50, $0A, $4B, $05, $29, $49,
$A4, $27, $CC, $C7, $C5, $DF, $2B, $EA, $06, $91, $F3, $F4, $8B, $EB, $E9, $9F,
$7C, $F9, $64, $B8, $13, $49, $D8, $F2, $62, $7F, $AF, $9B, $99, $18, $C7, $88,
$9B, $60, $49, $BC, $89, $24, $29, $BE, $3A, $B2, $A8, $E3, $42, $3D, $88, $02,
$F6, $B5, $39, $56, $7D, $E4, $D7, $DC, $3C, $51, $12, $FE, $F7, $61, $F6, $CD,
$98, $6D, $D7, $00, $B0, $75, $54, $B7, $BD, $D5, $0E, $E4, $5F, $1F, $30, $AB,
$19, $84, $95, $B8, $FD, $FE, $15, $EC, $AD, $F5, $62, $E4, $83, $3E, $A6, $C0,
$C9, $BD, $C0, $1A, $64, $34, $F6, $AB, $04, $7D, $97, $ED, $B3, $18, $82, $D1,
$0F, $29, $FE, $53, $12, $9C, $1F, $36, $F2, $FD, $AA, $4D, $27, $B6, $E8, $8E,
$A6, $B4, $FD, $18, $0C, $B3, $22, $45, $DE, $59, $20, $51, $26, $66, $F1, $22,
$74, $EF, $37, $65, $ED, $23, $AF, $DE, $0E, $61, $52, $7F, $F5, $EB, $33, $BE,
$04, $F5, $AA, $48, $EC, $AB, $F3, $18, $9D, $EA, $14, $F9, $F0, $4C, $D8, $DC,
$39, $56, $A2, $5B, $9C, $69, $54, $D1, $E4, $8D, $C2, $6F, $CE, $C1, $DC, $D6,
$E3, $27, $BF, $E0, $37, $D5, $91, $83, $31, $A1, $A1, $57, $D6, $F7, $B2, $85,
$6B, $7B, $29, $1F, $FC, $0F, $64, $84, $5F, $2F, $EC, $E6, $B4, $D0, $31, $2A,
$60, $44, $89, $81, $4B, $1E, $9E, $74, $BE, $8B, $7C, $2D, $69, $EE, $09, $17,
$02, $8C, $99, $92, $FB, $A0, $0A, $31, $59, $E5, $3D, $20, $77, $1D, $74, $79,
$02, $F9, $4E, $EA, $1B, $20, $8D, $83, $73, $70, $16, $32, $2B, $9E, $1A, $C5,
$0A, $CA, $FD, $4C, $9A, $72, $C1, $8C, $F6, $AD, $95, $99, $2F, $7C, $11, $B6,
$59, $76, $3B, $A5, $60, $1F, $79, $DA, $60, $11, $6E, $0A, $37, $75, $2B, $06,
$2E, $9C, $99, $BB, $4E, $D8, $60, $BF, $30, $17, $8C, $E5, $15, $24, $F0, $B0,
$24, $8D, $38, $B5, $47, $72, $38, $6D, $C2, $D8, $36, $EC, $00, $F4, $09, $D4,
$45, $64, $EB, $98, $1C, $18, $EF, $3F, $6C, $B0, $1E, $75, $49, $40, $33, $EF,
$DB, $D7, $8D, $A7, $FF, $8B, $F8, $B1, $68, $36, $13, $59, $29, $D2, $E8, $1A,
$AD, $6D, $14, $AE, $26, $2D, $05, $C3, $D6, $0F, $ED, $DB, $88, $94, $1E, $70,
$D9, $4F, $77, $43, $3E, $C7, $20, $42, $AF, $DD, $FF, $77, $5E, $23, $39, $05,
$A8, $E7, $63, $9C, $B1, $41, $A3, $F1, $1A, $E2, $61, $2C, $6F, $2A, $40, $BB,
$19, $5D, $DC, $B8, $2F, $58, $F8, $73, $9C, $EB, $EF, $A5, $A9, $01, $84, $74,
$F2, $E1, $C0, $62, $31, $A0, $F7, $54, $B2, $10, $E9, $6F, $96, $B1, $B7, $2F,
$36, $51, $D4, $33, $09, $5D, $C1, $2B, $BF, $D6, $29, $7B, $70, $B6, $43, $64,
$DF, $73, $B3, $6D, $5B, $43, $AF, $D3, $60, $A1, $1E, $2A, $D9, $27, $92, $1B,
$FF, $6C, $86, $DB, $3F, $6E, $56, $5B, $80, $D1, $E4, $CE, $D9, $0A, $83, $DD,
$B5, $03, $50, $FB, $85, $63, $2C, $25, $B9, $87, $69, $1C, $92, $E0, $2A, $10,
$93, $5B, $3E, $25, $5A, $7E, $2C, $34, $9F, $5A, $03, $42, $50, $A6, $3A, $99,
$A9, $3D, $B5, $FA, $C2, $F4, $4A, $19, $A7, $43, $47, $85, $27, $30, $1D, $9C,
$97, $B9, $B9, $5C, $A5, $53, $6A, $6A, $9F, $FC, $8C, $6C, $06, $81, $78, $83,
$94, $3B, $9B, $1A, $23, $C5, $1B, $CA, $55, $6C, $17, $B5, $61, $C9, $29, $8A,
$EC, $C5, $52, $A8, $EA, $33, $4F, $73, $A6, $71, $E5, $8D, $1A, $B1, $F0, $27,
$50, $3D, $E7, $1E, $C6, $A1, $1D, $92, $B4, $D8, $17, $7A, $7C, $F8, $55, $42,
$10, $75, $6C, $BF, $A0, $9F, $46, $C3, $4F, $08, $09, $6E, $0A, $B5, $4E, $70,
$77, $CC, $2A, $D2, $DB, $D6, $8D, $73, $39, $46, $A7, $9D, $EA, $DA, $25, $F0,
$E9, $AA, $8F, $AA, $EB, $DF, $69, $26, $5D, $6C, $27, $70, $62, $DA, $14, $D4,
$69, $6E, $B9, $46, $D2, $BB, $B7, $5F, $CC, $B2, $AA, $44, $0C, $9D, $E2, $F6,
$DC, $C8, $D5, $EC, $BB, $9B, $50, $4C, $01, $09, $7A, $93, $87, $80, $4D, $0D,
$9F, $1B, $D5, $1B, $4E, $A9, $0D, $10, $44, $50, $53, $0C, $F1, $BB, $DF, $09,
$81, $ED, $67, $6E, $3E, $BC, $13, $5F, $9D, $B5, $6E, $16, $CB, $61, $EE, $9F,
$89, $96, $57, $85, $9E, $62, $FD, $C4, $33, $59, $F5, $AF, $DE, $85, $76, $63,
$E2, $38, $6F, $AE, $E3, $33, $12, $4E, $E7, $68, $56, $D4, $A8, $7A, $49, $9F,
$13, $3B, $FE, $44, $46, $FF, $99, $07, $FB, $44, $71, $9E, $68, $A6, $95, $F1,
$D6, $F2, $E2, $03, $F0, $F3, $9B, $77, $06, $13, $A6, $34, $23, $55, $CC, $17,
$9A, $E1, $60, $FC, $EB, $08, $68, $8B, $F0, $27, $4C, $0E, $0E, $D9, $17, $F0,
$D5, $3D, $75, $44, $9B, $7E, $06, $94, $65, $AF, $7B, $C0, $A4, $96, $6D, $C2,
$BF, $40, $57, $C6, $94, $52, $EC, $D4, $5F, $F5, $31, $97, $37, $7E, $83, $A6,
$61, $F9, $A3, $A2, $A0, $86, $24, $74, $BA, $CD, $0D, $3E, $1C, $64, $56, $F6,
$9E, $03, $1B, $97, $C2, $9C, $D3, $A0, $D1, $DF, $5A, $F5, $3F, $FD, $64, $19,
$60, $9C, $79, $48, $85, $B8, $FF, $19, $72, $29, $29, $5B, $EF, $A0, $8D, $FE,
$EE, $A9, $CD, $BD, $6E, $C5, $96, $A8, $80, $82, $46, $FF, $0E, $D8, $3D, $58,
$67, $07, $19, $A3, $04, $29, $1E, $7B, $D4, $30, $C9, $11, $C3, $2F, $91, $6C,
$04, $81, $87, $B6, $6D, $49, $E0, $8F, $F1, $BE, $CB, $5B, $90, $94, $30, $9B,
$7A, $0E, $16, $3B, $29, $94, $ED, $4B, $5E, $49, $8E, $54, $5B, $5F, $A1, $B9,
$1A, $FC, $92, $E8, $C0, $66, $0F, $D7, $96, $38, $BA, $66, $84, $D1, $DC, $92,
$9D, $06, $F3, $A0, $9C, $5A, $1B, $80, $15, $5F, $D7, $33, $45, $76, $FE, $98,
$31, $E8, $24, $C7, $DE, $80, $02, $AC, $C0, $98, $41, $A8, $8C, $C9, $62, $B4,
$5B, $7F, $1E, $E3, $E7, $1A, $4E, $CC, $BE, $8B, $53, $DF, $81, $59, $4D, $D4,
$28, $C0, $18, $D3, $37, $B4, $AC, $E1, $08, $AE, $47, $CD, $72, $59, $65, $19,
$CC, $04, $80, $0B, $57, $7B, $55, $49, $0B, $07, $5F, $39, $C3, $F4, $2C, $30,
$09, $37, $69, $9C, $AC, $4F, $E7, $E1, $06, $62, $C7, $18, $60, $3E, $10, $22,
$D4, $FC, $EA, $C4, $46, $08, $22, $0D, $5D, $0F, $68, $BF, $F8, $25, $F4, $4C,
$60, $66, $A6, $7F, $82, $AD, $9D, $DB, $AD, $FB, $B7, $99, $61, $F2, $F5, $15,
$74, $03, $DB, $79, $7A, $6B, $59, $29, $7F, $5F, $26, $43, $15, $34, $A3, $48,
$58, $C4, $AA, $72, $3F, $F2, $79, $18, $BC, $5D, $80, $59, $36, $B4, $19, $F4,
$67, $BA, $3B, $86, $E8, $00, $E8, $26, $EE, $AD, $68, $67, $E6, $B4, $57, $AB,
$86, $0C, $60, $EC, $BB, $81, $35, $73, $60, $FA, $4F, $D6, $92, $B7, $D2, $C8,
$4B, $6D, $DC, $BD, $06, $A1, $39, $AE, $DE, $15, $29, $B2, $7B, $BF, $47, $31,
$74, $33, $CA, $C1, $74, $13, $94, $E2, $C4, $03, $9E, $42, $3B, $54, $B4, $C4,
$FC, $22, $74, $03, $3E, $09, $47, $4D, $04, $A8, $B9, $04, $2E, $52, $D4, $B9,
$63, $45, $4F, $3F, $FC, $3D, $38, $9A, $F0, $18, $FA, $53, $99, $73, $41, $BE,
$90, $3A, $C0, $CA, $AE, $64, $48, $1C, $28, $13, $E9, $E1, $DB, $7E, $AB, $6A,
$1D, $25, $61, $0F, $C6, $6E, $BA, $B9, $F3, $86, $39, $38, $F4, $ED, $A6, $1A,
$21, $21, $98, $5C, $F2, $CE, $B5, $6C, $7E, $D3, $26, $88, $1C, $94, $A4, $98,
$F9, $C7, $30, $E1, $3F, $40, $EF, $01, $95, $24, $87, $A1, $1D, $65, $14, $56,
$49, $EE, $C4, $D7, $5D, $E4, $77, $CE, $BD, $C3, $87, $92, $9A, $A0, $69, $B0,
$E7, $32, $7F, $64, $0D, $C1, $8B, $F3, $0D, $BE, $35, $20, $76, $6D, $66, $41,
$6C, $4E, $B9, $8F, $74, $60, $F2, $F7, $9B, $2E, $01, $63, $42, $3C, $76, $00,
$E2, $EB, $28, $01, $44, $81, $F1, $7D, $77, $8D, $D2, $FD, $80, $64, $A3, $9E,
$7C, $48, $AD, $BA, $4D, $72, $DD, $3B, $5C, $F0, $DC, $39, $60, $7A, $4E, $6F,
$B7, $97, $26, $56, $B4, $73, $3D, $13, $C7, $2C, $E9, $2E, $78, $0A, $8A, $74,
$DA, $F5, $66, $BB, $A7, $02, $95, $6C, $B0, $61, $19, $1C, $46, $81, $41, $56,
$8B, $57, $3E, $9D, $81, $33, $2A, $F3, $88, $B0, $CE, $B7, $73, $61, $58, $E6,
$0B, $27, $6D, $75, $26, $5E, $B8, $5D, $C4, $86, $3B, $23, $0D, $EB, $86, $7E,
$20, $BF, $56, $65, $36, $78, $5E, $BE, $C3, $21, $D1, $C4, $1E, $D4, $83, $FC,
$B7, $9F, $7B, $0C, $93, $73, $AB, $13, $6D, $22, $11, $9B, $79, $8F, $B6, $5C,
$3D, $D8, $3F, $8F, $6D, $36, $ED, $D6, $54, $A8, $16, $02, $8C, $E3, $C3, $32,
$25, $8F, $B7, $38, $E4, $68, $6E, $E9, $1C, $D7, $47, $BB, $1D, $A9, $9E, $47,
$16, $F9, $DC, $97, $5C, $35, $9F, $D8, $95, $AB, $EF, $01, $E5, $AA, $F7, $B1,
$50, $E7, $34, $AE, $89, $28, $58, $8F, $54, $77, $5F, $96, $ED, $5F, $F8, $C5,
$4E, $BF, $8C, $07, $55, $69, $36, $52, $F5, $D6, $2D, $1B, $7D, $F0, $C2, $04,
$D1, $AF, $C1, $C7, $93, $C9, $11, $47, $67, $93, $A9, $EC, $2C, $26, $D2, $15,
$76, $09, $FF, $51, $91, $3D, $2E, $A4, $64, $8C, $43, $8F, $08, $17, $4D, $0B,
$6A, $27, $B0, $C4, $03, $52, $C1, $8C, $68, $20, $0E, $31, $AD, $EC, $B5, $F8,
$67, $80, $24, $AB, $2B, $15, $67, $F1, $2F, $E2, $DC, $7E, $6C, $BD, $64, $E1,
$AB, $31, $AF, $F8, $8A, $88, $FA, $59, $F6, $2B, $48, $11, $D0, $4E, $55, $59,
$06, $55, $DA, $70, $9B, $31, $8B, $2E, $23, $BD, $35, $D0, $2A, $57, $28, $E7,
$18, $3E, $3B, $85, $FA, $37, $7F, $C6, $13, $F7, $E1, $9B, $7C, $4E, $CB, $43,
$79, $02, $AB, $D0, $58, $12, $57, $73, $D8, $80, $3C, $DF, $B1, $67, $3F, $50,
$E8, $A8, $BF, $3B, $D4, $81, $44, $F1, $05, $94, $F5, $14, $11, $1C, $06, $7F,
$0A, $A5, $9E, $7C, $90, $1A, $7C, $68, $43, $CF, $7E, $83, $75, $75, $39, $D0,
$46, $E8, $9B, $36, $0F, $45, $60, $38, $CC, $E1, $9D, $94, $D0, $B0, $F0, $16,
$68, $7D, $5D, $97, $2F, $BF, $3F, $F6, $DA, $C9, $1F, $E3, $73, $A5, $45, $E7,
$40, $D8, $D8, $2A, $AC, $64, $06, $2A, $8B, $F4, $BF, $09, $64, $D0, $6A, $0C,
$A1, $4A, $3A, $A6, $FF, $98, $10, $C8, $9F, $E8, $77, $F7, $D7, $2A, $48, $3C,
$89, $25, $1C, $0B, $B8, $7F, $3B, $AD, $FA, $0B, $E0, $D1, $FC, $47, $BE, $F4,
$29, $F5, $9C, $E2, $A6, $8F, $70, $70, $A0, $9D, $02, $EB, $FC, $4C, $08, $67,
$57, $66, $69, $A6, $7E, $C3, $9B, $DA, $14, $1F, $62, $E9, $45, $C2, $26, $B9,
$EB, $95, $34, $9A, $D5, $99, $01, $45, $A1, $7C, $6C, $03, $D8, $D6, $EF, $A6,
$78, $D7, $15, $A8, $48, $1F, $74, $7D, $73, $37, $A1, $DE, $A5, $22, $B6, $9F,
$50, $AC, $89, $68, $83, $7B, $49, $86, $95, $FD, $98, $12, $0B, $1A, $3C, $23,
$51, $45, $69, $31, $4A, $F6, $E7, $54, $F2, $27, $F8, $35, $D1, $E8, $09, $27,
$DA, $A4, $7F, $14, $58, $C6, $53, $F1, $7F, $EF, $60, $8E, $54, $3C, $F6, $02,
$CF, $4F, $7A, $5F, $E7, $8B, $33, $03, $E9, $B3, $4E, $66, $85, $47, $C7, $8B,
$A2, $05, $8C, $C9, $88, $5F, $AC, $03, $C1, $DD, $BF, $B5, $B4, $89, $CE, $41,
$15, $27, $6F, $9B, $AE, $F5, $F5, $D0, $97, $62, $32, $77, $A0, $DE, $56, $CC,
$9D, $04, $11, $E5, $8E, $4F, $D8, $D6, $8B, $CA, $2E, $48, $04, $8C, $34, $E2,
$52, $47, $66, $31, $6D, $AB, $EE, $F9, $41, $AF, $2B, $38, $BD, $11, $E3, $3E,
$A1, $46, $45, $7A, $8D, $88, $B9, $35, $E1, $94, $46, $93, $78, $F8, $9A, $AF,
$7D, $45, $CD, $A9, $32, $74, $8F, $C5, $B2, $A1, $39, $CD, $61, $B5, $19, $B9,
$59, $60, $7A, $C2, $CF, $5B, $CA, $EE, $03, $B3, $BC, $7B, $2A, $BF, $68, $C5,
$CD, $8F, $7B, $56, $CC, $30, $5A, $A1, $D1, $5A, $87, $AE, $B4, $0D, $0B, $91,
$AE, $4D, $C2, $D3, $F7, $2F, $AD, $A9, $77, $6C, $0B, $4B, $EB, $49, $FF, $AA,
$53, $EA, $B2, $13, $7B, $C6, $94, $99, $EF, $73, $6D, $B6, $B2, $63, $C3, $69,
$E4, $BB, $28, $E0, $D3, $9F, $1E, $FB, $67, $36, $9F, $D2, $C8, $2F, $47, $07,
$0F, $0F, $9A, $6E, $FF, $5C, $73, $BB, $5E, $78, $49, $01, $C5, $48, $C6, $66,
$E3, $02, $B5, $F1, $D1, $90, $59, $BC, $8F, $92, $16, $1A, $DF, $C2, $81, $C0,
$07, $DB, $4F, $90, $D2, $24, $3E, $BA, $14, $67, $F2, $34, $E4, $C3, $18, $C1,
$69, $BE, $FD, $70, $2F, $79, $84, $36, $36, $0B, $21, $E6, $FA, $B8, $06, $A6,
$58, $3B, $16, $CA, $2E, $3B, $2F, $65, $7E, $58, $A7, $C6, $B4, $3A, $99, $86,
$3D, $1C, $D9, $D2, $32, $20, $55, $B8, $58, $4A, $FC, $8E, $93, $54, $0B, $8B,
$CC, $62, $85, $E5, $D3, $8D, $11, $AB, $18, $BE, $6A, $D5, $EB, $37, $70, $D4,
$AE, $7A, $62, $6B, $A8, $BC, $D8, $87, $92, $9D, $93, $09, $C7, $C3, $A1, $66,
$94, $DA, $7B, $3D, $F9, $CB, $18, $F7, $FB, $26, $2F, $E6, $2C, $72, $A6, $C3,
$CB, $EC, $E8, $D2, $D0, $53, $A0, $21, $28, $7A, $51, $C2, $A1, $D0, $3D, $9F,
$D0, $6C, $83, $A8, $6D, $11, $1F, $DF, $77, $3F, $19, $8C, $2E, $38, $94, $88,
$06, $6A, $93, $98, $29, $86, $CD, $B1, $85, $47, $1A, $4D, $33, $47, $70, $5F,
$5C, $34, $6C, $53, $A4, $C8, $75, $F8, $9A, $AA, $8F, $82, $2B, $B1, $DF, $CF,
$87, $DA, $50, $64, $ED, $82, $CB, $51, $1A, $A5, $A3, $12, $A6, $20, $CE, $8C,
$47, $26, $81, $83, $6A, $8B, $7E, $78, $C8, $8C, $E6, $08, $92, $0A, $8C, $1A,
$24, $37, $F5, $92, $B0, $06, $34, $6D, $21, $09, $87, $F4, $9B, $BA, $92, $45,
$A9, $BA, $1D, $C2, $0A, $DF, $B1, $EF, $8D, $FC, $30, $78, $A8, $C9, $B4, $23,
$4F, $CF, $55, $1F, $76, $EC, $E9, $42, $87, $C3, $40, $C2, $29, $DF, $EA, $C7,
$1A, $FB, $89, $76, $D8, $83, $0E, $2D, $F4, $57, $CC, $73, $F7, $BF, $AE, $39,
$9D, $25, $67, $C9, $6D, $9F, $69, $47, $6B, $60, $AF, $38, $72, $C7, $58, $B1,
$6D, $42, $D0, $77, $9F, $50, $5D, $1D, $C3, $91, $70, $00, $A4, $77, $00, $B1,
$1E, $2B, $9E, $AE, $0F, $D7, $8D, $E4, $F0, $59, $96, $80, $F2, $F9, $BB, $28,
$34, $2A, $F6, $77, $E9, $BE, $89, $AA, $2B, $70, $C9, $D1, $F5, $7A, $EA, $DE,
$CE, $35, $3A, $88, $22, $D0, $6E, $C6, $14, $73, $CA, $6F, $7C, $9B, $6F, $4C,
$DE, $93, $E7, $A9, $36, $85, $B5, $B6, $6E, $F7, $28, $EC, $55, $81, $E5, $23,
$A8, $D4, $EA, $E2, $82, $52, $4D, $FF, $33, $01, $D0, $F4, $48, $34, $5D, $EC,
$EB, $CD, $7B, $DC, $DA, $30, $A2, $9B, $CD, $89, $77, $89, $A7, $68, $90, $98,
$C6, $2E, $DC, $25, $E9, $0B, $23, $18, $2A, $C2, $E5, $49, $C2, $1C, $2F, $C7,
$76, $4C, $12, $73, $1B, $9F, $5A, $CB, $99, $A4, $42, $0A, $0B, $A8, $0E, $C9,
$0C, $D6, $74, $9C, $1E, $F5, $DC, $C0, $7A, $4F, $50, $9B, $6A, $4F, $9B, $2D,
$DC, $D2, $F5, $AB, $8C, $C7, $A1, $06, $03, $8E, $AC, $57, $68, $8D, $AA, $33,
$B7, $73, $58, $8B, $A9, $0E, $1C, $11, $3B, $E8, $5B, $CB, $2B, $C9, $EA, $A7,
$3A, $E3, $69, $EA, $90, $12, $2A, $52, $9F, $E7, $6B, $54, $31, $23, $7B, $E9,
$08, $AF, $D3, $67, $3F, $D3, $34, $57, $A1, $F8, $1D, $5F, $66, $97, $92, $9D,
$AC, $D7, $D7, $C5, $BF, $86, $17, $BD, $0A, $8C, $C0, $77, $44, $AD, $D2, $26,
$EA, $8D, $6D, $B9, $2D, $B2, $10, $73, $C9, $33, $43, $1A, $9E, $C6, $66, $7E,
$A0, $A2, $AB, $7C, $DE, $3F, $2F, $E9, $C8, $5D, $24, $26, $C5, $0A, $3F, $27,
$85, $7A, $88, $C8, $CC, $6A, $A3, $04, $E5, $87, $4A, $F0, $1A, $5D, $89, $D8,
$CA, $9A, $76, $54, $EC, $A0, $D7, $DE, $75, $53, $B2, $60, $B2, $CB, $73, $03,
$95, $08, $CD, $5C, $70, $A1, $D1, $D2, $B1, $A8, $E4, $8E, $5F, $8E, $9D, $C0,
$E9, $B9, $A7, $D1, $E2, $76, $70, $FF, $8E, $E3, $81, $14, $EE, $7F, $CE, $36,
$10, $3D, $50, $03, $37, $BA, $10, $64, $8E, $83, $4A, $A7, $14, $D0, $23, $7D,
$57, $CB, $05, $3E, $F0, $69, $95, $0D, $6D, $87, $47, $BB, $D7, $E7, $41, $FD,
$BE, $8C, $ED, $7C, $1B, $78, $2A, $5B, $33, $D8, $DD, $96, $FF, $D2, $9C, $0F,
$20, $C7, $0E, $4B, $9B, $F1, $13, $8A, $37, $77, $E1, $53, $BA, $28, $D0, $02,
$39, $FD, $48, $3D, $0C, $C6, $F4, $40, $C4, $DE, $78, $38, $14, $A2, $A8, $C9,
$35, $EB, $38, $10, $2C, $38, $F5, $41, $11, $4C, $FA, $D2, $76, $0D, $4B, $EC,
$1D, $F4, $C0, $98, $C0, $B6, $D4, $0B, $3D, $42, $0E, $26, $26, $C9, $1F, $85,
$76, $96, $AF, $11, $6E, $89, $9B, $DE, $66, $0B, $6E, $C8, $36, $9F, $61, $A8,
$71, $5A, $4E, $5F, $5C, $9C, $9E, $30, $84, $C5, $68, $1E, $CE, $AB, $29, $55,
$AA, $6A, $E5, $3B, $8A, $A3, $10, $2E, $96, $2F, $B3, $79, $FE, $16, $6D, $9A,
$AA, $EC, $36, $CA, $E3, $20, $A1, $5D, $23, $94, $8F, $0A, $91, $9D, $5C, $18,
$19, $D3, $07, $6A, $41, $E4, $59, $2F, $FD, $D5, $74, $99, $18, $8A, $12, $45,
$97, $3D, $F2, $26, $38, $DA, $DD, $3F, $32, $47, $C3, $39, $02, $D8, $B4, $91,
$15, $84, $0A, $CC, $B0, $F5, $E5, $96, $C8, $34, $7E, $63, $0F, $C5, $82, $74,
$10, $6F, $1A, $A5, $2A, $49, $F3, $A8, $65, $45, $63, $89, $1D, $3B, $C2, $DE,
$12, $0C, $AD, $23, $68, $B0, $C9, $AD, $47, $8D, $C3, $64, $22, $70, $23, $F5,
$15, $D2, $EB, $E5, $5C, $B2, $66, $AB, $03, $B4, $2F, $24, $73, $DE, $93, $D9,
$94, $B8, $FC, $67, $52, $72, $C3, $B9, $48, $80, $7D, $F6, $1C, $87, $F8, $6A,
$BD, $F2, $A1, $17, $1A, $BC, $21, $4F, $D7, $C6, $F8, $85, $FE, $D9, $5F, $B5,
$7D, $67, $E9, $A8, $B5, $37, $D6, $39, $E9, $85, $B3, $B1, $84, $91, $06, $8E,
$27, $67, $63, $BF, $5F, $F1, $D4, $32, $6F, $58, $49, $5C, $0C, $3B, $41, $F2,
$B7, $8D, $84, $BF, $C8, $23, $3C, $C8, $94, $82, $6A, $8B, $8D, $D9, $D1, $5E,
$31, $1E, $C1, $36, $53, $86, $9A, $08, $02, $EC, $4B, $8E, $4C, $C1, $2C, $D3,
$F6, $93, $11, $D6, $3B, $35, $7F, $63, $6A, $AE, $02, $8F, $7D, $0B, $F7, $8D,
$84, $BB, $56, $A0, $AF, $44, $8D, $52, $38, $68, $12, $4B, $45, $12, $87, $66,
$91, $E4, $8F, $2F, $40, $EA, $57, $0F, $A9, $E9, $3B, $F3, $EA, $71, $5A, $7B,
$9C, $56, $C0, $E7, $4C, $D7, $B6, $91, $9D, $CF, $25, $3F, $92, $4D, $32, $6E,
$93, $8F, $3A, $A9, $E4, $5A, $C1, $CE, $95, $9B, $A2, $69, $B9, $69, $94, $57,
$2F, $4B, $B7, $39, $73, $55, $07, $A6, $41, $66, $CC, $19, $C4, $49, $98, $27,
$8E, $A4, $5A, $C2, $BB, $18, $B1, $84, $AE, $B6, $9A, $01, $D4, $3B, $B2, $A7,
$D6, $53, $83, $C3, $90, $9B, $CB, $75, $7B, $0C, $01, $86, $25, $8D, $59, $64,
$4D, $2A, $42, $90, $51, $43, $35, $89, $22, $93, $1F, $F6, $7E, $7B, $A0, $64,
$11, $FE, $93, $6F, $33, $70, $90, $0F, $07, $69, $EC, $96, $56, $7E, $78, $06,
$CA, $E9, $16, $36, $02, $82, $1A, $C1, $45, $6C, $8F, $85, $28, $EA, $F2, $1C,
$8B, $2E, $A1, $0C, $0D, $31, $D4, $A6, $83, $94, $83, $20, $F3, $6B, $36, $E8,
$1D, $F4, $44, $97, $6B, $3E, $06, $F0, $8B, $37, $07, $69, $47, $45, $79, $21,
$83, $BA, $15, $73, $A6, $01, $AF, $E5, $F4, $2E, $33, $59, $CE, $8D, $5C, $D5,
$77, $19, $08, $C2, $28, $82, $C5, $14, $0F, $4D, $3D, $32, $22, $BD, $38, $9F,
$C9, $6C, $CA, $FB, $A2, $A7, $CB, $DB, $88, $B0, $83, $C6, $28, $7A, $CE, $BC,
$6D, $01, $54, $91, $79, $3C, $03, $4F, $87, $99, $3C, $AE, $4A, $24, $81, $7E,
$5C, $01, $2E, $75, $5E, $7C, $5D, $FA, $A8, $F5, $8F, $9E, $94, $2F, $15, $76,
$58, $D9, $6D, $85, $29, $2A, $BE, $AC, $7B, $58, $4A, $40, $43, $1E, $3D, $44,
$17, $88, $49, $6D, $8E, $F3, $E6, $6A, $58, $88, $2F, $89, $89, $D6, $BA, $84,
$00, $A7, $75, $8E, $C1, $66, $89, $25, $57, $68, $F2, $B2, $F6, $07, $8B, $75,
$B4, $16, $D6, $86, $2B, $76, $4B, $A9, $70, $36, $9A, $20, $92, $B1, $DF, $55,
$FB, $CD, $1B, $51, $70, $14, $25, $C5, $16, $BD, $16, $EA, $DE, $99, $E0, $E5,
$2D, $C9, $E0, $96, $A7, $7A, $82, $B9, $5C, $03, $17, $66, $9F, $5A, $98, $1A,
$07, $80, $A8, $22, $4B, $F6, $42, $D9, $96, $2D, $F5, $4C, $76, $B7, $8B, $90,
$99, $A8, $D0, $15, $19, $C7, $B3, $41, $9E, $08, $32, $02, $2C, $B7, $7E, $6A,
$2E, $C1, $26, $40, $DD, $47, $CE, $E0, $59, $3C, $02, $03, $AE, $2E, $59, $6B,
$F7, $AE, $8D, $89, $24, $27, $AA, $8F, $B6, $E1, $92, $DB, $23, $03, $5F, $D3,
$76, $83, $99, $36, $37, $FD, $DC, $47, $B4, $7F, $74, $55, $A2, $77, $71, $8E,
$AC, $8F, $60, $B1, $33, $31, $18, $B3, $B9, $0C, $23, $47, $07, $8A, $B2, $8B,
$71, $42, $0D, $57, $E7, $E6, $26, $53, $BA, $84, $44, $16, $03, $4E, $BA, $EC,
$3A, $C2, $83, $16, $5D, $FC, $54, $6A, $D9, $3E, $A2, $48, $20, $56, $A8, $06,
$8B, $2E, $5C, $10, $1A, $49, $74, $7E, $BD, $06, $FF, $D8, $3A, $0C, $3E, $C1,
$70, $08, $B6, $EE, $49, $A3, $3E, $09, $10, $C0, $ED, $31, $EB, $C0, $62, $71,
$65, $99, $7C, $EA, $34, $7B, $79, $03, $B3, $7D, $E3, $5F, $84, $5B, $E0, $D6,
$21, $C1, $3C, $94, $AA, $3B, $AE, $9A, $10, $C1, $AC, $DE, $9D, $36, $D5, $40,
$11, $39, $AA, $E4, $A5, $61, $20, $D7, $52, $F0, $28, $0F, $B5, $AC, $38, $4E,
$69, $6A, $C5, $10, $00, $04, $6D, $3F, $09, $19, $A5, $4E, $2A, $B4, $52, $93,
$36, $75, $83, $BC, $F0, $0B, $B2, $FA, $2C, $DD, $84, $A9, $15, $4F, $22, $EB,
$AA, $99, $CA, $DE, $A5, $EC, $B1, $4D, $6B, $4B, $39, $C5, $6A, $AA, $A8, $AC,
$26, $AB, $1A, $35, $B1, $99, $EC, $B8, $A5, $F2, $A3, $15, $33, $10, $EA, $E8,
$87, $C7, $FF, $CE, $33, $6F, $0A, $A5, $9F, $3D, $62, $1C, $D1, $3F, $32, $67,
$C2, $6E, $14, $9B, $F4, $5C, $A1, $3F, $0C, $7D, $C6, $43, $CB, $F1, $A5, $CB,
$2E, $36, $15, $08, $AF, $62, $0B, $31, $D3, $75, $FC, $96, $36, $BE, $CE, $BF,
$39, $CF, $CE, $21, $7F, $28, $63, $D0, $C7, $DD, $DE, $B8, $86, $5A, $F1, $AF,
$77, $96, $E8, $2D, $C9, $45, $6A, $F5, $2C, $88, $A8, $3D, $59, $88, $4B, $43,
$1B, $4C, $D2, $48, $A8, $26, $FD, $7C, $C1, $34, $EB, $89, $BA, $62, $3B, $CD,
$32, $B2, $3B, $4C, $48, $A0, $72, $09, $1B, $7C, $39, $30, $61, $4A, $CD, $DB,
$71, $33, $66, $CF, $C4, $61, $90, $99, $9B, $C9, $9D, $7C, $45, $AE, $F8, $BE,
$98, $22, $A4, $E1, $31, $A3, $60, $57, $30, $BD, $56, $E3, $B5, $2A, $C4, $AC,
$29, $EB, $98, $38, $99, $A0, $7E, $F7, $2E, $2D, $F8, $42, $95, $50, $92, $BC,
$20, $40, $64, $05, $4A, $A2, $22, $DF, $B2, $CE, $1F, $65, $5F, $90, $C1, $83,
$D1, $6F, $3C, $8C, $D0, $60, $56, $69, $85, $1C, $84, $D5, $91, $99, $C3, $69,
$84, $08, $ED, $9F, $FB, $97, $6B, $D8, $B1, $C0, $EB, $FC, $D3, $BE, $EF, $17,
$69, $F3, $22, $47, $CC, $34, $C4, $9C, $06, $C1, $0E, $5B, $4A, $0F, $04, $53,
$12, $F5, $C2, $CE, $DE, $1A, $C6, $CA, $39, $1A, $FD, $D2, $A6, $91, $76, $97,
$2C, $D9, $E8, $6C, $91, $5B, $9D, $F6, $EE, $2A, $E9, $4D, $92, $35, $09, $1A,
$77, $87, $42, $A5, $3C, $BC, $04, $3E, $C3, $D7, $19, $E9, $E6, $32, $C8, $B5,
$D9, $AB, $1A, $8F, $E7, $54, $0F, $BC, $62, $2E, $9F, $9B, $C9, $57, $0F, $C3,
$30, $F9, $55, $98, $78, $04, $48, $5D, $3C, $EA, $89, $22, $1B, $2A, $D3, $0D,
$C6, $16, $3F, $DD, $21, $0A, $F6, $FF, $C2, $E1, $5A, $E6, $90, $56, $DA, $62,
$D3, $47, $70, $D5, $46, $67, $11, $EA, $4A, $56, $88, $86, $63, $28, $F3, $EC,
$4C, $D1, $35, $92, $D9, $AC, $35, $E4, $8A, $F0, $8A, $E4, $96, $86, $85, $54,
$4E, $84, $FD, $7C, $1D, $EA, $C8, $50, $CC, $15, $9B, $6E, $4E, $52, $5B, $A7,
$8F, $C7, $15, $C1, $DA, $93, $93, $F4, $CB, $6B, $56, $69, $1F, $D1, $93, $B0,
$97, $98, $0E, $43, $04, $E2, $05, $36, $00, $9A, $5F, $2F, $76, $3B, $BA, $8A,
$94, $F8, $1C, $F4, $49, $C2, $8F, $4C, $46, $0D, $22, $7D, $75, $36, $C7, $B7,
$3F, $68, $FE, $35, $22, $9D, $60, $44, $D3, $B6, $58, $EA, $E7, $5B, $21, $21,
$0B, $8A, $BA, $6A, $9D, $86, $62, $B4, $30, $94, $84, $A0, $5E, $84, $50, $66,
$54, $68, $84, $28, $70, $A3, $83, $64, $6E, $C4, $BF, $08, $62, $19, $BE, $E0,
$71, $3E, $BD, $89, $ED, $FB, $C7, $2B, $C2, $E4, $EE, $05, $1D, $EC, $8D, $1F,
$6F, $5D, $13, $48, $22, $BA, $75, $EB, $60, $2C, $62, $09, $BB, $0F, $B8, $2F,
$4E, $C9, $5E, $D7, $B1, $E5, $2D, $18, $70, $E3, $CE, $92, $DC, $F2, $01, $33,
$0A, $61, $17, $03, $7F, $DA, $8F, $6B, $C8, $F1, $9F, $08, $76, $6F, $FF, $14,
$A2, $C2, $F4, $17, $69, $C5, $11, $6B, $8D, $3A, $DA, $A2, $33, $C8, $2A, $D8,
$F4, $A0, $CA, $E8, $F4, $43, $89, $46, $76, $99, $18, $5F, $D1, $BA, $EE, $87,
$3A, $A6, $43, $9C, $35, $61, $F3, $E1, $26, $B1, $C4, $E6, $B4, $94, $9F, $CE,
$26, $A7, $7A, $D5, $93, $72, $D7, $FF, $B4, $5F, $42, $B0, $9B, $4C, $A3, $A1,
$C5, $E0, $6F, $5C, $5E, $79, $90, $F7, $FB, $E6, $CD, $FB, $3A, $0C, $93, $03,
$2C, $3C, $37, $9F, $94, $64, $21, $20, $D8, $C6, $DA, $FD, $9A, $78, $76, $AE,
$62, $6E, $82, $F9, $2E, $AE, $2A, $7D, $86, $86, $36, $87, $AF, $AC, $90, $F2,
$94, $5F, $10, $46, $3A, $7E, $FA, $2C, $60, $97, $6D, $FC, $32, $1D, $9D, $0A,
$50, $E7, $5C, $11, $22, $37, $B3, $E8, $7D, $CC, $A7, $19, $60, $31, $46, $A1,
$20, $DD, $05, $55, $B6, $8E, $65, $B5, $EA, $CB, $79, $CD, $76, $26, $DA, $8D,
$4E, $6F, $AF, $E1, $F8, $C6, $79, $FE, $B3, $E0, $46, $95, $53, $CC, $AB, $B5,
$E0, $74, $AF, $0F, $F2, $BE, $FE, $15, $BD, $C1, $21, $A8, $E2, $29, $C6, $50,
$AF, $45, $72, $C6, $6D, $0A, $BF, $5C, $32, $13, $FE, $D6, $32, $B7, $E2, $69,
$E3, $27, $1D, $8E, $83, $74, $10, $62, $77, $E2, $0A, $52, $08, $B7, $05, $10,
$55, $32, $F7, $44, $1E, $29, $14, $37, $CD, $C8, $92, $D3, $78, $36, $94, $71,
$A2, $E9, $8A, $BB, $8F, $52, $DF, $C9, $8F, $E2, $B7, $71, $61, $B5, $0A, $3B,
$C3, $57, $34, $FE, $5E, $B0, $AF, $2D, $B2, $B0, $2F, $7D, $2D, $09, $37, $16,
$29, $8A, $A2, $3B, $F4, $47, $90, $0C, $31, $96, $29, $CA, $12, $A6, $2D, $19,
$89, $0A, $DB, $F3, $A8, $CA, $64, $D1, $AA, $B1, $8E, $67, $A0, $7E, $73, $F4,
$A5, $86, $3C, $9C, $07, $C3, $60, $EA, $89, $E5, $D5, $2D, $FA, $DF, $C0, $2A,
$87, $7A, $6F, $85, $A2, $D4, $83, $14, $BD, $00, $1D, $09, $F2, $F1, $E7, $D7,
$C2, $85, $B0, $CA, $D8, $2F, $5F, $38, $42, $AC, $47, $E5, $C5, $B2, $F6, $DE,
$98, $CC, $81, $A4, $B9, $EF, $CE, $73, $54, $8D, $37, $BC, $B1, $9F, $D0, $F4,
$CC, $E2, $85, $47, $3D, $87, $8E, $3D, $0D, $E2, $2A, $CD, $EE, $9C, $02, $FD,
$DD, $92, $4B, $6B, $F3, $70, $91, $45, $C1, $AF, $99, $C5, $A1, $A3, $11, $71,
$F0, $CF, $2E, $CD, $2B, $51, $F9, $5B, $E8, $19, $62, $88, $67, $7E, $C4, $27,
$83, $61, $FD, $34, $89, $CC, $A7, $1A, $26, $2F, $16, $41, $89, $7E, $68, $27,
$B8, $2C, $49, $A3, $7C, $2B, $84, $52, $57, $3C, $32, $F1, $FC, $CC, $3C, $D9,
$B4, $07, $02, $B4, $C0, $39, $37, $74, $52, $2A, $EC, $A7, $71, $92, $67, $AF,
$44, $33, $2C, $37, $F5, $0D, $59, $A9, $36, $85, $08, $07, $0D, $BA, $3E, $F7,
$23, $CA, $D1, $B4, $0F, $A3, $05, $B8, $64, $CD, $C5, $DC, $E4, $7B, $83, $DB,
$DA, $BB, $EC, $43, $CF, $A6, $40, $5E, $DB, $F1, $26, $63, $59, $B5, $37, $2D,
$2F, $2A, $3B, $CA, $A7, $C9, $0F, $D8, $CB, $C0, $61, $57, $32, $09, $05, $E5,
$12, $4F, $C1, $C0, $DA, $99, $54, $BB, $1B, $60, $D8, $56, $98, $BC, $5D, $D1,
$4F, $DB, $1D, $A5, $49, $DC, $3B, $19, $3A, $13, $D3, $AE, $10, $10, $08, $5B,
$E0, $B5, $1B, $14, $D4, $DB, $BF, $29, $73, $BB, $A7, $D8, $20, $20, $E6, $3D,
$76, $8D, $ED, $04, $75, $41, $D6, $8C, $C0, $DF, $CD, $37, $A2, $23, $5F, $1A,
$61, $DF, $2A, $2C, $A6, $3D, $35, $07, $6A, $E5, $F0, $26, $D7, $0E, $E8, $CC,
$73, $12, $2D, $C0, $60, $01, $8D, $8F, $BB, $29, $61, $EF, $8F, $23, $4B, $CA,
$AF, $0C, $57, $C7, $5D, $DF, $DD, $08, $69, $F9, $40, $40, $39, $05, $E8, $06,
$40, $36, $D1, $FD, $EA, $60, $DC, $D1, $78, $16, $D4, $6F, $8A, $96, $1F, $73,
$60, $EC, $5D, $52, $7F, $58, $73, $94, $7D, $8F, $32, $28, $D1, $0B, $93, $60,
$D5, $F2, $C4, $BF, $70, $C8, $FD, $81, $EA, $9C, $8A, $AE, $1F, $7C, $7C, $1F,
$E9, $EC, $D2, $05, $6B, $17, $B5, $9A, $50, $0F, $3C, $D4, $13, $AF, $76, $79,
$F1, $5A, $EE, $04, $4E, $37, $6B, $AA, $0C, $87, $3B, $D8, $B2, $FF, $BA, $DD,
$D2, $98, $4B, $6E, $7E, $4C, $C4, $3C, $46, $A2, $06, $10, $B9, $14, $7C, $32,
$54, $BB, $91, $55, $6E, $D8, $ED, $FC, $E2, $5B, $30, $1E, $DC, $D1, $B5, $36,
$38, $23, $4D, $59, $D7, $99, $38, $7F, $13, $0B, $2A, $D5, $F4, $78, $20, $0F,
$F5, $67, $5A, $7B, $9E, $EF, $43, $17, $92, $83, $0A, $6D, $0D, $B8, $9E, $2B,
$83, $E2, $00, $EF, $37, $DA, $6C, $71, $0E, $30, $A7, $8B, $DF, $48, $1F, $4B,
$05, $95, $9D, $E8, $F2, $C9, $51, $8F, $1C, $60, $59, $9B, $4B, $CC, $31, $16,
$64, $B2, $E4, $B7, $9A, $76, $4E, $B0, $9A, $52, $EE, $E5, $E2, $DD, $74, $66,
$A2, $9B, $C3, $1A, $6F, $9C, $96, $F0, $BA, $28, $CA, $89, $67, $D9, $1E, $3D,
$C9, $23, $5D, $CA, $6E, $85, $5E, $A6, $43, $8C, $51, $1F, $AB, $86, $C7, $A3,
$CE, $1E, $60, $9A, $01, $98, $85, $63, $29, $70, $AC, $88, $62, $9F, $D2, $89,
$CB, $AD, $B8, $0C, $7A, $06, $9D, $A9, $4F, $5A, $0C, $F1, $6D, $0F, $45, $B5,
$39, $BD, $9B, $6B, $34, $85, $08, $0F, $3D, $A7, $6B, $43, $83, $F2, $02, $A5,
$80, $FF, $DB, $38, $13, $B5, $E6, $A7, $AD, $39, $31, $6C, $E8, $48, $30, $DD,
$8C, $42, $53, $B4, $02, $27, $56, $2F, $D8, $13, $EC, $AA, $F8, $38, $98, $C3,
$BF, $80, $9F, $19, $E2, $F2, $1E, $99, $78, $FD, $77, $43, $8D, $92, $8D, $9C,
$E5, $E2, $8A, $0E, $46, $F0, $E1, $65, $7A, $B1, $8A, $9B, $53, $8A, $04, $6F,
$9A, $35, $C5, $BD, $AD, $B5, $B1, $0E, $61, $A9, $84, $DD, $5B, $98, $89, $2D,
$DB, $F8, $8B, $84, $B4, $2B, $3B, $7F, $A2, $05, $36, $14, $27, $F0, $91, $A1,
$63, $83, $2C, $6F, $53, $11, $AE, $D8, $4D, $28, $59, $82, $CC, $FB, $7A, $84,
$32, $32, $E7, $E1, $1C, $5B, $BF, $AF, $B3, $68, $7E, $B7, $68, $71, $9B, $AC,
$EB, $8E, $0C, $21, $3F, $A1, $17, $A3, $92, $AA, $35, $46, $9E, $51, $8A, $0A,
$29, $24, $7B, $46, $25, $33, $A6, $46, $E8, $A9, $3B, $12, $76, $5E, $3F, $1B,
$D4, $83, $8C, $07, $D5, $BB, $E8, $E6, $B7, $63, $C2, $2A, $51, $0B, $0E, $CB,
$AA, $50, $2A, $B2, $F2, $A7, $20, $2C, $AF, $19, $97, $25, $AB, $42, $FF, $EC,
$AA, $AF, $9B, $8A, $0B, $72, $FB, $F9, $87, $D7, $9D, $11, $FD, $2E, $2E, $3B,
$78, $6C, $E3, $80, $0B, $7D, $84, $BE, $17, $66, $7A, $23, $71, $AE, $9C, $9E,
$AC, $EC, $90, $D5, $B8, $24, $28, $D2, $CE, $70, $A7, $FD, $17, $96, $BC, $BD,
$C2, $BB, $38, $9B, $5D, $BC, $10, $D8, $3C, $BC, $3E, $F6, $CC, $AD, $29, $BD,
$CB, $DE, $13, $0B, $1A, $40, $13, $C0, $BC, $12, $E3, $D7, $E7, $F2, $01, $95,
$77, $98, $B9, $98, $68, $DB, $24, $06, $12, $DB, $E5, $54, $06, $1B, $EA, $A8,
$A6, $2D, $61, $AA, $95, $8F, $3D, $2E, $C8, $A7, $E2, $00, $88, $F1, $BB, $E0,
$DB, $E2, $4A, $0E, $81, $72, $C6, $8A, $90, $45, $0B, $F7, $12, $5E, $AC, $32,
$F3, $5B, $62, $C4, $50, $17, $63, $11, $79, $EC, $4A, $1C, $E7, $CD, $29, $B9,
$58, $A1, $E0, $20, $65, $E4, $86, $25, $39, $84, $63, $80, $5D, $A5, $0D, $32,
$C2, $7B, $69, $BD, $BC, $DA, $31, $2B, $22, $C1, $B5, $62, $72, $31, $19, $99,
$7C, $4D, $D9, $3B, $62, $63, $80, $A8, $49, $AF, $53, $2E, $EE, $D9, $FC, $75,
$91, $3E, $8F, $DF, $E5, $32, $2B, $01, $95, $F6, $3D, $49, $71, $A2, $A0, $0E,
$3D, $B9, $56, $D1, $D1, $F8, $E4, $E6, $A5, $DF, $CB, $64, $CE, $00, $66, $9B,
$47, $61, $4D, $91, $D8, $41, $49, $A1, $2D, $49, $5F, $90, $56, $3D, $B4, $A6,
$4B, $7E, $89, $B0, $E0, $DF, $2F, $BB, $EC, $C8, $20, $35, $7C, $82, $54, $79,
$7F, $BD, $EA, $0F, $5A, $32, $0D, $52, $17, $B1, $06, $8B, $38, $F1, $71, $70,
$0F, $80, $63, $03, $C9, $82, $FC, $62, $5A, $A8, $0C, $1E, $93, $96, $16, $9E,
$34, $E1, $6C, $BE, $6F, $24, $01, $20, $23, $42, $1D, $90, $65, $27, $10, $78,
$7F, $8B, $66, $DF, $95, $37, $26, $44, $60, $6B, $30, $24, $6B, $EF, $D8, $E2,
$F6, $E2, $63, $55, $10, $11, $BC, $FB, $FB, $9C, $53, $2B, $69, $69, $0D, $82,
$99, $21, $96, $64, $F1, $61, $A6, $D0, $57, $78, $81, $50, $76, $38, $05, $73,
$8E, $84, $E9, $62, $C0, $51, $50, $08, $F7, $FB, $BD, $49, $34, $72, $A0, $7A,
$A9, $51, $FB, $52, $86, $19, $2C, $E6, $93, $03, $BC, $2D, $79, $D3, $E1, $BC,
$59, $FF, $62, $03, $9C, $4B, $D1, $53, $CF, $D8, $D4, $18, $F3, $E3, $47, $9E,
$B9, $5E, $33, $58, $C3, $4F, $9D, $43, $79, $49, $81, $8C, $41, $E4, $C2, $84,
$E5, $38, $BB, $F5, $38, $63, $4A, $20, $CE, $AB, $92, $6F, $B2, $30, $48, $13,
$C0, $34, $17, $85, $E1, $77, $24, $99, $F6, $4A, $3E, $1F, $64, $E9, $CF, $5C,
$EA, $FB, $0B, $3D, $7D, $03, $EC, $A1, $39, $3B, $39, $C4, $23, $65, $7B, $01,
$F4, $3B, $70, $A3, $BD, $79, $74, $5B, $09, $8F, $27, $5F, $F5, $D9, $67, $AC,
$A0, $4F, $01, $D6, $89, $C9, $FB, $8F, $DB, $EB, $75, $2C, $B4, $75, $E0, $90,
$06, $ED, $68, $83, $58, $57, $EA, $79, $37, $15, $75, $D0, $49, $A5, $83, $6C,
$E7, $AF, $72, $3F, $E0, $71, $80, $4A, $5A, $74, $9D, $F8, $5F, $02, $3E, $75,
$15, $1B, $EA, $EC, $9A, $47, $89, $86, $58, $64, $02, $B0, $11, $E8, $BC, $7F,
$A1, $16, $0D, $EE, $AE, $A0, $77, $8C, $3B, $6B, $32, $E4, $58, $6A, $28, $73,
$AB, $60, $3A, $D5, $A6, $D2, $D4, $0A, $FB, $A1, $EE, $9E, $30, $90, $FF, $72,
$42, $82, $1C, $4E, $27, $06, $B9, $C0, $99, $C4, $68, $61, $D4, $DC, $1D, $D2,
$83, $7E, $16, $7B, $6D, $A2, $6F, $D1, $0D, $B1, $6F, $5F, $0D, $21, $DC, $7A,
$FF, $D0, $E2, $76, $89, $50, $7A, $87, $1A, $A1, $5F, $11, $06, $18, $13, $D9,
$92, $3A, $7C, $C0, $7A, $42, $29, $5E, $76, $4C, $69, $40, $2C, $B9, $03, $6D,
$B8, $89, $53, $77, $91, $08, $26, $DA, $66, $FB, $8C, $DB, $28, $47, $E0, $36,
$58, $13, $85, $76, $01, $9D, $95, $38, $93, $D7, $A9, $74, $BC, $A1, $E7, $E4,
$4D, $66, $9B, $11, $F9, $C4, $A0, $9D, $0A, $77, $FC, $C6, $D1, $0B, $BF, $06,
$9E, $29, $87, $B5, $2B, $63, $51, $C7, $75, $EA, $C8, $2C, $E0, $FB, $8B, $2F,
$44, $4D, $D3, $56, $EE, $D4, $B8, $9F, $C4, $80, $3E, $30, $0E, $0C, $EB, $67,
$82, $BC, $B2, $0D, $7F, $0E, $70, $10, $18, $AD, $46, $9B, $73, $4C, $DB, $A5,
$C5, $D4, $AF, $F1, $8F, $86, $1B, $7F, $95, $5D, $DC, $63, $82, $F8, $57, $76,
$CF, $FC, $3C, $82, $57, $FB, $40, $E0, $56, $E4, $64, $3C, $0F, $15, $0E, $4A,
$32, $FD, $30, $A0, $85, $4D, $A9, $FA, $75, $32, $43, $4D, $AF, $D0, $72, $D3,
$8A, $D4, $F0, $FD, $38, $DF, $25, $EF, $61, $59, $FF, $4E, $38, $19, $30, $EE,
$BE, $6E, $C6, $EB, $FE, $28, $80, $03, $42, $73, $C6, $F0, $EF, $31, $8A, $0A,
$74, $A0, $24, $59, $79, $F4, $7B, $88, $E7, $A1, $42, $DA, $DF, $1C, $C9, $ED,
$64, $B3, $CE, $5D, $37, $E8, $56, $99, $3B, $B6, $C1, $B7, $D3, $BA, $B0, $DF,
$FB, $26, $3E, $F9, $6E, $71, $61, $BF, $91, $14, $18, $12, $53, $E3, $27, $A8,
$DF, $74, $CF, $65, $7B, $7B, $71, $E5, $DC, $10, $90, $4F, $99, $7D, $68, $08,
$5D, $F6, $95, $9A, $CA, $F2, $32, $3F, $EE, $9C, $57, $67, $E5, $17, $43, $1B,
$19, $B1, $8A, $A1, $DA, $C9, $0A, $96, $57, $FF, $A4, $13, $10, $57, $17, $CA,
$E0, $36, $96, $29, $85, $B3, $24, $D3, $92, $06, $59, $2E, $CD, $01, $C5, $B7,
$4E, $D8, $2E, $63, $5C, $89, $C2, $1C, $FD, $5A, $82, $86, $88, $1D, $45, $CD,
$0A, $25, $0B, $2F, $AF, $18, $52, $F5, $DD, $11, $2F, $BC, $D0, $0C, $B7, $39,
$E4, $7B, $30, $5F, $AA, $4E, $E1, $CF, $26, $0A, $72, $40, $81, $FD, $30, $19,
$A8, $43, $86, $2A, $8F, $7A, $A1, $A9, $18, $34, $6A, $7B, $70, $60, $F1, $EF,
$4A, $8D, $16, $2D, $74, $78, $13, $46, $06, $62, $F3, $70, $5A, $05, $58, $72,
$55, $26, $2E, $42, $80, $51, $07, $A5, $A4, $39, $2F, $C5, $A4, $5A, $AB, $6E,
$FD, $66, $04, $5C, $CB, $1A, $19, $5C, $3B, $FD, $E8, $43, $E3, $ED, $74, $00,
$20, $AF, $63, $4D, $98, $0B, $D0, $84, $CC, $EF, $30, $00, $EA, $48, $00, $D4,
$61, $5A, $50, $77, $6D, $80, $69, $D7, $E7, $FF, $AE, $48, $E1, $86, $A8, $BE,
$13, $0A, $2C, $20, $ED, $18, $0B, $B1, $61, $E6, $C7, $E5, $DE, $20, $12, $33,
$F7, $05, $04, $E0, $04, $51, $ED, $36, $A0, $AB, $8F, $23, $FB, $34, $BE, $B8,
$0A, $58, $A0, $FF, $A8, $32, $75, $40, $95, $60, $38, $BD, $58, $0F, $F6, $CD,
$5B, $9A, $10, $23, $D8, $26, $F8, $D9, $94, $EE, $1F, $91, $32, $FA, $24, $3E,
$9E, $9E, $2B, $EB, $D0, $73, $3C, $CA, $4E, $FD, $09, $F5, $DC, $B3, $70, $B0,
$B5, $13, $0E, $2C, $AE, $E3, $5F, $A3, $95, $F7, $CB, $9C, $BB, $DA, $C5, $38,
$CB, $A5, $BE, $9A, $F1, $9F, $01, $BB, $FD, $95, $30, $C1, $E6, $7E, $BF, $5A,
$B1, $03, $BC, $56, $53, $C1, $9E, $11, $EF, $10, $3F, $25, $CB, $59, $4D, $B4,
$F4, $A8, $E9, $34, $F0, $DE, $D9, $A9, $92, $1B, $58, $85, $56, $A3, $55, $5A,
$BE, $B3, $80, $FD, $4C, $FB, $92, $4B, $9C, $64, $68, $CE, $08, $3E, $5D, $02,
$0F, $E7, $B9, $7F, $D2, $E9, $87, $42, $D1, $6D, $39, $21, $96, $CB, $ED, $C8,
$71, $A7, $51, $0C, $C4, $37, $5D, $19, $EC, $6C, $A6, $61, $D4, $7E, $B5, $3E,
$26, $83, $74, $4B, $8B, $50, $82, $D1, $EA, $60, $F5, $CB, $B7, $D3, $EF, $08,
$4F, $82, $44, $53, $92, $8C, $01, $C8, $8F, $19, $AD, $BA, $78, $24, $D8, $48,
$39, $95, $D5, $B5, $91, $E8, $F1, $AD, $D2, $20, $75, $6A, $4C, $1B, $E1, $41,
$BE, $AE, $19, $6A, $53, $EB, $82, $9C, $32, $86, $5A, $CC, $83, $75, $82, $A1,
$04, $EA, $31, $F3, $E6, $E0, $DC, $2A, $9E, $26, $75, $5A, $AE, $B0, $30, $2D,
$BC, $58, $1B, $79, $1B, $F5, $15, $C4, $72, $8F, $0F, $FB, $AE, $DD, $74, $29,
$B6, $5F, $9A, $7B, $A2, $20, $AD, $26, $CF, $9B, $7F, $AA, $69, $8A, $BA, $9E,
$6D, $93, $0E, $7E, $E1, $B3, $16, $18, $13, $DE, $9B, $A1, $99, $5F, $34, $4C,
$42, $45, $3E, $FC, $E4, $70, $A5, $FC, $91, $1D, $75, $77, $2D, $30, $D1, $41,
$AF, $2D, $82, $FB, $1C, $8C, $36, $74, $4B, $B9, $55, $7D, $4B, $B5, $BF, $76,
$CD, $6B, $63, $FD, $E6, $95, $58, $36, $93, $85, $EF, $C9, $08, $C7, $C5, $D4,
$FE, $6A, $40, $42, $C8, $B1, $5A, $4F, $6C, $80, $82, $FA, $A5, $6C, $4D, $5B,
$9A, $85, $C1, $6B, $51, $BE, $5F, $DA, $0E, $41, $94, $ED, $44, $92, $17, $66,
$4F, $B2, $77, $F9, $2F, $50, $7A, $D7, $34, $A4, $FF, $E5, $A3, $B1, $25, $9C,
$82, $BB, $DF, $D2, $FA, $3D, $F2, $3F, $B7, $16, $74, $64, $CC, $4D, $F6, $63,
$4F, $B0, $38, $90, $F2, $7E, $0A, $29, $8C, $8E, $55, $21, $70, $E5, $6B, $D4,
$EC, $4B, $DC, $3A, $B7, $6D, $1F, $F0, $98, $7E, $8B, $27, $70, $81, $3A, $7E,
$69, $A0, $1F, $95, $2A, $15, $E9, $45, $08, $2D, $81, $A8, $16, $E0, $A0, $3B,
$FB, $10, $EF, $4D, $CD, $9D, $A1, $E3, $80, $43, $A0, $BF, $D3, $53, $B9, $7D,
$17, $5E, $E7, $47, $16, $0B, $E7, $43, $48, $B6, $D9, $57, $25, $FC, $28, $87,
$9B, $A0, $63, $D5, $6D, $B7, $63, $BC, $AD, $45, $4F, $E7, $48, $5E, $28, $DA,
$EC, $64, $90, $F4, $AF, $07, $9F, $13, $58, $ED, $9E, $FC, $D0, $C2, $CB, $73,
$D4, $8F, $8A, $AF, $6D, $73, $B7, $B1, $76, $57, $95, $4A, $E7, $DE, $03, $9A,
$E6, $49, $0E, $70, $68, $CA, $33, $76, $DB, $2C, $A0, $01, $AC, $15, $2E, $D8,
$41, $67, $96, $6C, $28, $D9, $AE, $53, $2F, $26, $CF, $42, $10, $A8, $3F, $A9,
$5D, $FD, $A3, $A9, $B8, $A8, $07, $72, $D4, $84, $06, $FE, $A0, $CE, $64, $EE,
$65, $97, $A3, $3C, $77, $6B, $8F, $A4, $9B, $B6, $7F, $1A, $C5, $03, $E4, $AB,
$B9, $AE, $DE, $C8, $4B, $56, $54, $8B, $76, $6F, $C8, $5F, $26, $A2, $63, $E4,
$40, $8A, $B0, $A3, $AF, $6F, $AB, $54, $43, $86, $2B, $7F, $67, $F6, $6C, $67,
$37, $37, $DB, $87, $94, $A3, $D8, $BC, $78, $0E, $BA, $92, $71, $6B, $B0, $73,
$68, $D1, $9F, $27, $58, $03, $4E, $0B, $7F, $42, $70, $22, $FF, $C9, $B8, $99,
$00, $43, $76, $D2, $96, $5C, $78, $4B, $F9, $DF, $22, $59, $83, $47, $93, $E0,
$DA, $98, $79, $C7, $1E, $95, $6B, $F6, $E8, $24, $D1, $E1, $10, $87, $1A, $3A,
$DF, $07, $AE, $FC, $55, $AC, $34, $26, $94, $4B, $C6, $86, $AE, $8F, $C8, $0A,
$EF, $84, $1D, $74, $36, $C0, $4B, $DC, $27, $3E, $92, $60, $40, $F4, $40, $1C,
$F6, $35, $4A, $9C, $86, $C9, $4C, $9F, $E5, $2F, $D2, $CF, $66, $F0, $32, $79,
$A6, $E6, $A0, $A1, $EE, $2F, $64, $00, $11, $06, $FD, $A0, $F5, $0E, $CC, $97,
$F3, $F3, $9A, $D7, $82, $04, $2F, $18, $E9, $FF, $9F, $EC, $2E, $C4, $17, $8F,
$8F, $73, $58, $93, $2C, $3C, $2F, $2B, $42, $75, $9F, $A6, $72, $45, $8C, $41,
$5D, $92, $88, $74, $BC, $19, $F0, $2A, $93, $D5, $D3, $09, $77, $99, $56, $A6,
$F9, $26, $29, $F7, $A0, $82, $24, $D5, $0B, $45, $48, $BB, $39, $F2, $95, $6A,
$D8, $ED, $B4, $28, $BB, $60, $2F, $07, $9C, $66, $66, $DB, $5F, $EC, $0D, $AA,
$2D, $DF, $57, $4B, $FD, $0E, $1F, $CE, $B9, $F2, $67, $0A, $1D, $BE, $4B, $C0,
$37, $91, $4F, $99, $94, $19, $DB, $9E, $CF, $BB, $BF, $ED, $FA, $6E, $8C, $20,
$27, $49, $8B, $50, $E0, $52, $B3, $54, $7B, $0D, $1D, $0F, $92, $2E, $95, $27,
$38, $8C, $92, $20, $0A, $E1, $52, $3B, $45, $E8, $F1, $80, $5E, $D9, $DB, $74,
$94, $02, $C0, $20, $C8, $16, $C3, $DE, $97, $C6, $82, $C8, $89, $BD, $F3, $4E,
$34, $9C, $70, $65, $9A, $36, $5E, $9E, $3D, $0A, $20, $C3, $4C, $15, $0C, $FD,
$E7, $60, $6A, $D6, $86, $39, $FE, $A9, $8A, $CB, $3B, $68, $4A, $5B, $3D, $AD,
$46, $55, $57, $72, $06, $23, $AB, $DC, $5F, $F2, $43, $8B, $9D, $F1, $BF, $85,
$3B, $A4, $7E, $B5, $2C, $56, $19, $92, $4A, $EC, $B3, $9D, $7E, $B5, $7E, $84,
$54, $C6, $88, $0D, $C0, $C2, $01, $31, $AA, $3E, $55, $FE, $AA, $69, $84, $4B,
$97, $DD, $0C, $2D, $82, $15, $81, $7D, $BF, $D8, $8D, $AC, $0D, $08, $FF, $7E,
$D3, $8F, $4F, $E4, $C0, $7B, $82, $A6, $34, $9B, $54, $DE, $0A, $C3, $C7, $1A,
$C7, $38, $9B, $8B, $6E, $F6, $37, $AC, $C0, $39, $13, $E5, $D3, $5F, $C4, $24,
$D7, $57, $16, $C1, $1F, $AE, $E6, $A6, $83, $4E, $16, $28, $37, $86, $18, $F0,
$0C, $CC, $64, $EB, $32, $63, $67, $77, $84, $35, $79, $0F, $09, $E9, $32, $41,
$58, $34, $4B, $51, $A2, $89, $1B, $47, $4A, $6F, $93, $FF, $C9, $1E, $5A, $ED,
$86, $F4, $3F, $0F, $A1, $A8, $3E, $9A, $3B, $F0, $5D, $70, $63, $94, $32, $17,
$E2, $DE, $F6, $C5, $8F, $7B, $E4, $9D, $D1, $74, $47, $41, $83, $83, $4A, $A0,
$A8, $66, $2F, $48, $FA, $82, $D3, $A4, $8F, $DD, $7B, $E9, $60, $33, $55, $02,
$26, $2A, $9E, $B9, $8E, $A0, $9C, $42, $CA, $F2, $D4, $3E, $C1, $CF, $F1, $7F,
$FF, $24, $06, $F3, $8A, $67, $ED, $B1, $4A, $85, $11, $E6, $7C, $8C, $7A, $5E,
$A2, $BD, $8C, $51, $9C, $8D, $AF, $AA, $4A, $99, $35, $16, $97, $BE, $AF, $4B,
$8A, $EC, $C0, $FB, $F3, $44, $5C, $54, $A2, $53, $5A, $40, $D2, $D1, $54, $20,
$44, $43, $A4, $AD, $AE, $F4, $52, $E7, $CD, $17, $15, $EE, $00, $A5, $26, $8A,
$A8, $63, $21, $1F, $28, $A4, $32, $21, $DE, $FA, $E9, $97, $BC, $E9, $C8, $E0,
$F5, $1C, $E3, $D6, $9F, $1F, $F6, $9E, $6E, $C9, $3A, $74, $6C, $0E, $46, $7A,
$1E, $0D, $67, $AB, $09, $6D, $77, $D3, $B3, $99, $BD, $31, $10, $9F, $68, $BF,
$5D, $CE, $3F, $31, $B0, $B6, $D9, $17, $A3, $F3, $58, $BE, $40, $94, $49, $FE,
$9A, $50, $59, $85, $A5, $6C, $C3, $DE, $2E, $E3, $A3, $54, $8C, $03, $B1, $DC,
$7E, $2D, $14, $01, $78, $A7, $83, $96, $DC, $5A, $43, $31, $89, $68, $91, $41,
$AC, $F7, $8E, $85, $7E, $42, $50, $D5, $D9, $2E, $57, $5A, $3A, $FF, $AF, $B2,
$B3, $F6, $7B, $FD, $A6, $8A, $2A, $3E, $6E, $A4, $CC, $69, $0F, $D5, $EE, $18,
$0B, $FA, $E0, $8A, $C5, $20, $5E, $2B, $EC, $34, $98, $88, $E1, $E8, $50, $5F,
$02, $41, $B1, $42, $93, $8B, $16, $DC, $08, $CE, $CC, $38, $92, $BA, $DE, $E9,
$5C, $21, $43, $D3, $BA, $6E, $38, $F6, $97, $7C, $F1, $2E, $79, $60, $0D, $BA,
$3D, $15, $55, $69, $B0, $DD, $92, $21, $C0, $B4, $B3, $1F, $11, $B0, $53, $8A,
$69, $30, $F0, $23, $EF, $E8, $34, $05, $34, $B8, $CB, $7A, $D0, $D5, $14, $62,
$80, $79, $7D, $71, $A5, $96, $38, $F9, $9D, $9D, $94, $CB, $F3, $43, $CA, $AB,
$10, $60, $CA, $23, $15, $51, $FF, $A3, $EB, $14, $19, $B2, $F7, $A2, $D6, $C7,
$28, $03, $FF, $53, $5D, $19, $9E, $5E, $65, $7B, $7A, $79, $EC, $01, $43, $B3,
$30, $BE, $1B, $D1, $F5, $E3, $76, $CE, $FA, $5C, $24, $E3, $DE, $A0, $C2, $B8,
$82, $F8, $88, $0B, $B9, $F8, $8D, $4E, $13, $D7, $4E, $1D, $53, $A7, $31, $A8,
$07, $2B, $90, $8E, $03, $85, $B9, $FC, $95, $DC, $4C, $13, $22, $FC, $3A, $27,
$C4, $32, $16, $4B, $12, $CB, $AB, $22, $FF, $E5, $4E, $46, $A3, $7B, $6F, $6B,
$24, $73, $19, $72, $61, $BA, $DD, $D4, $84, $17, $9F, $41, $92, $1D, $44, $CA,
$9D, $57, $20, $8D, $69, $4B, $6E, $7C, $28, $3C, $45, $C7, $5A, $2C, $62, $D1,
$C7, $F5, $10, $8A, $A7, $55, $F8, $11, $46, $E8, $9E, $BF, $D9, $16, $82, $13,
$D5, $06, $3E, $6C, $87, $9B, $68, $F0, $D7, $F8, $73, $6F, $7D, $8A, $3D, $4A,
$31, $D3, $97, $51, $9D, $69, $9B, $BE, $1E, $92, $7F, $FA, $D6, $A0, $31, $D1,
$AD, $CA, $FC, $AE, $2D, $29, $70, $2C, $E1, $D8, $ED, $42, $03, $B9, $1D, $50,
$90, $26, $A5, $FF, $E7, $47, $3D, $41, $3F, $DA, $94, $AC, $F9, $57, $CD, $0B,
$09, $21, $29, $42, $58, $68, $F5, $74, $1B, $50, $9B, $2B, $67, $C1, $94, $35,
$30, $C4, $C0, $49, $CB, $2F, $D5, $B7, $6C, $99, $F0, $24, $A7, $79, $96, $B2,
$93, $96, $5A, $71, $DD, $85, $9E, $56, $24, $67, $0D, $CF, $81, $7F, $00, $69,
$E4, $53, $04, $91, $05, $A8, $7D, $AE, $04, $CC, $52, $AE, $E9, $EE, $20, $10,
$E6, $EF, $8A, $16, $7E, $81, $57, $43, $DB, $F4, $1D, $B9, $F0, $F4, $90, $83,
$BA, $D3, $4A, $CC, $1D, $A1, $75, $B7, $57, $58, $91, $BC, $AF, $01, $98, $86,
$38, $B3, $63, $6B, $7F, $C6, $F1, $78, $48, $EB, $76, $BC, $9F, $89, $84, $AF,
$8A, $CE, $C7, $DB, $A8, $76, $9F, $6B, $D9, $97, $E7, $9B, $58, $69, $E8, $8B,
$A4, $28, $01, $30, $32, $95, $D5, $77, $F6, $98, $E9, $17, $07, $94, $52, $8D,
$8F, $E5, $0D, $12, $72, $7B, $20, $DD, $FD, $F8, $F3, $3B, $7C, $3C, $E7, $5B,
$9D, $E2, $F7, $E2, $DD, $0D, $30, $02, $D2, $7C, $C0, $43, $D0, $97, $F0, $BD,
$55, $34, $6B, $41, $39, $01, $BE, $96, $74, $74, $B7, $BB, $E3, $49, $FB, $E7,
$C8, $0A, $64, $5C, $14, $7B, $B8, $8F, $D8, $BC, $E8, $DD, $AE, $FE, $69, $26,
$A2, $68, $98, $93, $78, $54, $93, $2C, $9C, $51, $16, $7D, $CE, $43, $E4, $A1,
$A9, $DC, $40, $BD, $84, $59, $39, $30, $4E, $B7, $F0, $BE, $2D, $4C, $83, $05,
$A0, $BE, $31, $28, $7E, $A8, $42, $0B, $09, $43, $12, $6A, $B1, $A7, $6B, $D2,
$40, $4F, $8E, $9C, $EA, $93, $19, $CA, $E6, $0F, $DE, $6A, $22, $19, $A9, $4D,
$F9, $11, $AF, $D2, $BC, $F7, $85, $6B, $07, $C9, $9B, $FE, $7C, $4C, $C1, $C3,
$74, $6B, $6E, $69, $0B, $78, $1C, $D2, $EE, $C5, $E0, $EE, $4A, $AB, $5C, $BC,
$9C, $A1, $EF, $81, $D0, $E5, $79, $83, $79, $42, $CA, $F0, $3D, $38, $5D, $74,
$39, $B3, $BA, $71, $84, $D9, $33, $84, $50, $8A, $51, $6A, $4A, $8B, $0A, $B2,
$E3, $C9, $08, $A2, $3E, $F5, $C4, $BD, $AF, $E9, $BA, $09, $BA, $DA, $9D, $64,
$B8, $F4, $BA, $32, $4A, $D2, $42, $D1, $F3, $1E, $DD, $16, $22, $40, $CE, $FA,
$74, $96, $09, $89, $65, $A7, $E3, $B3, $A6, $85, $AF, $24, $13, $A6, $99, $DA,
$FF, $DF, $78, $F3, $CC, $98, $91, $3B, $D2, $5B, $B6, $1A, $38, $E6, $CD, $D5,
$9C, $2B, $DE, $DD, $9E, $12, $EB, $B0, $F6, $76, $4D, $74, $C0, $06, $86, $62,
$55, $83, $7E, $05, $3C, $83, $22, $AA, $73, $60, $D2, $55, $56, $59, $64, $7E,
$D6, $10, $FB, $D3, $94, $51, $25, $62, $93, $CD, $52, $19, $7C, $51, $86, $80,
$79, $B2, $22, $8F, $C2, $F4, $CD, $1C, $05, $45, $6B, $A4, $5C, $63, $81, $4A,
$77, $B1, $9A, $6A, $8C, $32, $9A, $1F, $0B, $2E, $D6, $1A, $6F, $9D, $9E, $87,
$D7, $2F, $DA, $60, $83, $21, $EE, $87, $8C, $E5, $A5, $B7, $2B, $FB, $38, $59,
$3B, $8D, $F8, $EF, $5E, $AC, $B8, $FB, $DE, $4D, $0C, $C9, $B1, $D4, $B7, $BA,
$79, $41, $D2, $AB, $AE, $08, $B2, $D2, $AC, $35, $7D, $89, $9C, $E3, $9D, $59,
$95, $E4, $DA, $67, $53, $05, $FA, $E6, $83, $0B, $FA, $AC, $FE, $94, $E0, $88,
$03, $B7, $20, $3D, $4A, $C1, $F4, $67, $9F, $27, $D2, $18, $D4, $82, $90, $2D,
$80, $16, $80, $DD, $8D, $36, $7E, $E2, $12, $53, $41, $26, $45, $7B, $C0, $55,
$90, $2A, $15, $39, $5B, $AE, $DA, $F7, $66, $C5, $D8, $26, $FE, $F6, $F7, $E9,
$6D, $02, $BF, $33, $DB, $5E, $F0, $0E, $88, $43, $52, $B4, $05, $A9, $CF, $86,
$2B, $8A, $8A, $20, $F4, $1D, $04, $D2, $24, $95, $97, $2B, $9B, $2A, $D1, $F5,
$6D, $12, $4F, $59, $EF, $1A, $E9, $3D, $44, $D8, $1F, $F6, $DF, $34, $75, $21,
$53, $F4, $6F, $31, $E8, $7C, $A4, $08, $4B, $0D, $B2, $45, $D1, $21, $80, $F6,
$28, $07, $0E, $94, $CD, $70, $B0, $87, $F6, $D4, $F7, $5C, $83, $5D, $F8, $03,
$0F, $BA, $C0, $8E, $EA, $44, $6E, $CD, $0D, $04, $BC, $85, $EF, $89, $06, $6E,
$30, $4E, $62, $78, $F5, $2A, $B9, $25, $06, $0E, $2F, $DE, $A3, $47, $E7, $4C,
$2E, $C0, $8B, $8E, $50, $B6, $6C, $58, $B7, $5D, $12, $8C, $B1, $F3, $00, $C6,
$8B, $A6, $6D, $6F, $9D, $1B, $80, $11, $A6, $B5, $FE, $26, $00, $EA, $B8, $15,
$68, $44, $27, $88, $C3, $AD, $32, $B3, $D1, $66, $73, $0A, $D0, $B5, $58, $CF,
$FA, $87, $7C, $2A, $76, $7B, $FD, $F0, $7D, $4B, $58, $1E, $7E, $70, $64, $38,
$B5, $2A, $C1, $1F, $3E, $3B, $49, $87, $4D, $07, $1B, $33, $96, $09, $88, $BC,
$1A, $6A, $FA, $50, $08, $05, $F7, $23, $E8, $70, $16, $E9, $24, $BC, $4C, $D1,
$C8, $90, $34, $0E, $AB, $23, $19, $AD, $41, $91, $7A, $38, $05, $98, $AE, $44,
$54, $59, $AB, $81, $F8, $7E, $F5, $78, $26, $58, $F2, $FD, $49, $FD, $15, $D2,
$3E, $DA, $27, $DA, $62, $F1, $27, $85, $F6, $4C, $E8, $71, $AE, $6D, $D8, $EF,
$16, $B6, $A1, $C0, $88, $F9, $BB, $6A, $00, $FD, $C2, $11, $99, $9D, $82, $DD,
$2D, $D2, $6B, $5B, $A0, $EA, $B8, $6C, $A2, $D6, $49, $70, $53, $2B, $CF, $01,
$A3, $46, $F2, $B7, $63, $55, $DD, $DB, $0E, $A5, $56, $4A, $58, $6D, $4B, $2A,
$A8, $09, $FB, $EA, $28, $5D, $8C, $40, $13, $FC, $4B, $08, $95, $9F, $1F, $BF,
$50, $CC, $C2, $A0, $F4, $F6, $15, $3B, $D0, $BF, $0D, $87, $88, $88, $4F, $D3,
$5C, $7D, $20, $4E, $E3, $CD, $6B, $70, $5B, $4D, $6C, $60, $43, $3E, $9E, $0A,
$6C, $6C, $D3, $BC, $49, $5A, $4A, $A3, $F7, $54, $F3, $85, $92, $AE, $7E, $56,
$16, $32, $4E, $AC, $8D, $1A, $A2, $3E, $93, $45, $A4, $7F, $67, $0D, $71, $E6,
$34, $9F, $DA, $E3, $78, $99, $0E, $8D, $C3, $EB, $90, $4E, $D1, $E4, $A5, $2B,
$61, $E4, $9B, $30, $71, $F5, $56, $21, $FB, $C8, $5E, $C2, $26, $C6, $5D, $BC,
$94, $3E, $96, $91, $5C, $BF, $54, $EE, $44, $DE, $09, $7C, $C0, $AD, $52, $AA,
$B4, $5C, $F0, $42, $52, $F2, $46, $4C, $50, $DD, $3A, $C7, $D3, $7B, $A3, $01,
$25, $50, $DC, $B7, $C4, $E5, $31, $E3, $F0, $01, $1D, $27, $C8, $96, $31, $DB,
$9F, $96, $33, $82, $03, $32, $F2, $67, $AE, $1E, $6B, $90, $46, $D8, $4B, $62,
$84, $FF, $14, $A3, $B4, $17, $6D, $24, $00, $34, $7E, $63, $FE, $44, $C2, $B1,
$59, $F0, $43, $6F, $06, $F5, $27, $08, $90, $60, $6D, $97, $F6, $F1, $37, $E4,
$0C, $A9, $36, $D4, $5C, $50, $C4, $5C, $8C, $1D, $8E, $C4, $17, $03, $76, $5C,
$DE, $15, $35, $38, $4C, $77, $6C, $88, $DB, $E6, $C1, $71, $65, $3D, $CA, $0C,
$EC, $EC, $E0, $E5, $20, $4B, $8B, $5D, $BC, $38, $BA, $DC, $1F, $1B, $D7, $A1,
$25, $61, $5C, $54, $02, $35, $64, $50, $A6, $1B, $E3, $F8, $6B, $FC, $AF, $87,
$82, $41, $57, $60, $AD, $71, $8E, $21, $07, $99, $DD, $35, $39, $F1, $FC, $F7,
$63, $36, $D0, $4C, $5F, $DC, $14, $00, $20, $CB, $0A, $C3, $D0, $B6, $5C, $81,
$2E, $A9, $F7, $6F, $67, $E7, $6A, $80, $81, $71, $39, $40, $4E, $74, $12, $55,
$9D, $D2, $D6, $1C, $F6, $9B, $0F, $56, $C8, $13, $99, $A0, $A3, $69, $B3, $AE,
$26, $9A, $C8, $2F, $15, $D0, $94, $09, $C2, $6E, $53, $D8, $8E, $E9, $55, $9D,
$69, $48, $98, $03, $C5, $6A, $36, $C1, $40, $6D, $31, $74, $69, $17, $FF, $D5,
$67, $67, $E6, $23, $47, $9E, $2A, $F2, $94, $23, $03, $C8, $9D, $03, $CF, $F3,
$F4, $E0, $C4, $3D, $13, $04, $28, $D8, $13, $DE, $A0, $3B, $3F, $E0, $63, $64,
$1E, $43, $70, $AC, $24, $15, $96, $19, $AD, $08, $7C, $93, $79, $DE, $47, $A3,
$A5, $49, $4B, $F1, $E9, $3B, $BC, $4F, $B2, $62, $EC, $AB, $57, $16, $0A, $48,
$29, $6F, $D0, $19, $7D, $85, $5D, $74, $C8, $8F, $3C, $46, $E1, $18, $C3, $B7,
$1F, $1C, $37, $AB, $22, $C4, $23, $37, $3C, $15, $B7, $76, $47, $6B, $A0, $6F,
$87, $E7, $49, $7B, $54, $3E, $82, $B0, $E5, $EA, $15, $E8, $7E, $40, $7C, $CA,
$7B, $18, $96, $7E, $CC, $31, $29, $B4, $F9, $EF, $7D, $C2, $46, $EE, $9F, $A0,
$BA, $06, $8C, $18, $CA, $31, $6E, $14, $6D, $A4, $61, $44, $2D, $07, $22, $C3,
$00, $02, $03, $DF, $29, $36, $81, $C4, $59, $D3, $65, $58, $B2, $95, $73, $18,
$38, $7F, $17, $AB, $89, $42, $3E, $E6, $6D, $35, $12, $86, $94, $D8, $E0, $EC,
$B2, $A9, $71, $1E, $00, $10, $79, $00, $14, $D3, $FC, $ED, $52, $BD, $DA, $4D,
$B4, $56, $6E, $83, $28, $28, $EF, $15, $9A, $87, $1F, $CA, $7D, $E1, $00, $6E,
$A8, $18, $15, $BF, $3C, $4C, $E9, $48, $7D, $3D, $70, $E5, $00, $F8, $18, $90,
$0A, $FD, $C3, $76, $B2, $2B, $31, $F5, $B8, $6F, $23, $EF, $9A, $51, $DA, $AA,
$91, $57, $DD, $BE, $FB, $D4, $35, $FC, $4A, $89, $39, $59, $B0, $34, $48, $22,
$B6, $F8, $43, $F7, $62, $E8, $19, $3C, $B7, $31, $B7, $50, $03, $2E, $BC, $A4,
$E1, $BF, $C6, $C7, $ED, $EE, $9C, $8A, $8B, $24, $C2, $EF, $24, $A0, $74, $A2,
$40, $3D, $21, $E4, $E7, $D1, $27, $C9, $FC, $BF, $2C, $9F, $60, $DA, $58, $F7,
$B2, $8F, $24, $96, $57, $E7, $49, $8A, $25, $26, $94, $55, $69, $D0, $00, $98,
$16, $7F, $53, $6F, $72, $64, $9D, $3F, $A6, $2F, $B6, $39, $24, $15, $1E, $9F,
$F7, $E1, $D6, $FA, $B7, $8B, $F3, $1D, $10, $CC, $20, $09, $6D, $1C, $85, $58,
$A2, $20, $1A, $50, $7B, $E6, $B4, $A2, $22, $FC, $58, $67, $0A, $27, $5E, $9F,
$3F, $52, $A8, $43, $47, $3C, $B2, $82, $61, $1F, $32, $96, $FB, $82, $0B, $78,
$69, $EF, $F5, $FA, $4B, $20, $B1, $B5, $FA, $D0, $12, $85, $8B, $46, $72, $99,
$EA, $D9, $85, $F0, $76, $C7, $E6, $E6, $1D, $5E, $FC, $16, $B9, $85, $FC, $E2,
$FB, $5E, $62, $2D, $B5, $EB, $EC, $ED, $47, $64, $DA, $54, $DF, $C0, $3F, $DA,
$22, $5F, $D9, $5B, $79, $5A, $06, $F7, $89, $F9, $95, $98, $8B, $F1, $11, $2F,
$2D, $49, $A9, $45, $A5, $73, $B7, $F3, $65, $1D, $7E, $60, $DD, $B6, $CF, $B3,
$04, $C8, $A8, $A2, $D1, $01, $ED, $10, $72, $D7, $FE, $EA, $74, $19, $3E, $F9,
$90, $ED, $98, $C0, $3B, $57, $90, $D6, $F3, $B0, $DA, $02, $C7, $C4, $C9, $90,
$5F, $97, $15, $66, $71, $88, $53, $E9, $45, $2C, $59, $14, $C7, $24, $54, $9E,
$87, $83, $47, $3A, $A0, $FA, $48, $36, $E8, $07, $85, $B7, $1D, $E9, $3B, $90,
$B7, $30, $70, $85, $86, $F0, $B4, $DB, $A2, $81, $C7, $63, $71, $55, $21, $96,
$5F, $D8, $65, $B3, $D4, $07, $48, $14, $EB, $F0, $27, $2D, $69, $AC, $9D, $C4,
$27, $28, $A4, $44, $AA, $90, $76, $36, $20, $C1, $67, $05, $21, $39, $7A, $66,
$F8, $7B, $A4, $B1, $D3, $00, $10, $9D, $BC, $5B, $12, $F3, $C4, $52, $4A, $93,
$C5, $58, $66, $99, $51, $FE, $62, $78, $AB, $31, $D8, $BB, $A0, $40, $D7, $11,
$0D, $F5, $CB, $5D, $E2, $DF, $C6, $A3, $36, $78, $CF, $C7, $55, $7E, $5E, $B0,
$4E, $FD, $4E, $38, $F8, $68, $22, $48, $7E, $42, $2F, $A9, $01, $DF, $52, $89,
$2D, $1E, $B9, $0E, $64, $63, $AA, $44, $80, $78, $31, $0B, $A7, $67, $79, $50,
$FB, $1D, $1E, $A3, $83, $AE, $04, $E5, $D0, $DA, $F7, $52, $57, $DD, $32, $FA,
$F1, $CA, $63, $B9, $55, $03, $87, $53, $D1, $76, $DD, $27, $8F, $57, $C1, $E4,
$20, $BC, $9B, $0D, $50, $8E, $A6, $38, $33, $26, $9A, $E0, $78, $C8, $A1, $C0,
$26, $31, $77, $D2, $78, $C8, $56, $D5, $F5, $85, $D8, $D9, $AC, $11, $9A, $13,
$84, $1F, $42, $E7, $E0, $0E, $1A, $42, $0B, $51, $84, $8A, $10, $EE, $1E, $7F,
$85, $5F, $7A, $4E, $F4, $76, $9E, $7E, $44, $C9, $D8, $01, $C1, $E7, $86, $B4,
$F9, $0C, $FA, $E7, $14, $DC, $3C, $5A, $66, $E4, $4D, $8D, $98, $44, $F6, $B0,
$89, $0F, $48, $60, $88, $CE, $B4, $10, $B9, $DD, $5F, $51, $1A, $FC, $37, $B2,
$57, $97, $35, $F7, $D4, $18, $74, $D3, $6C, $25, $1A, $17, $C2, $17, $63, $08,
$E0, $C5, $B2, $BA, $51, $62, $92, $35, $48, $CF, $32, $90, $17, $63, $11, $AA,
$95, $BF, $16, $01, $AC, $6B, $09, $C0, $E5, $83, $85, $B1, $B1, $AE, $7B, $14,
$0D, $63, $8A, $9F, $16, $23, $7E, $E3, $0E, $D4, $E8, $AD, $2D, $DE, $46, $6A,
$C3, $F9, $7A, $5C, $67, $9D, $C8, $F8, $67, $E4, $DE, $1D, $BB, $54, $72, $CC,
$53, $7F, $09, $A2, $F3, $D5, $FA, $5F, $C3, $F5, $83, $35, $E8, $10, $00, $66,
$6F, $3A, $2E, $3B, $42, $23, $6C, $33, $8B, $7B, $90, $F6, $20, $CD, $6E, $DA,
$49, $84, $C3, $F2, $A9, $8D, $77, $3A, $B8, $B0, $17, $25, $27, $9B, $6C, $15,
$95, $94, $F2, $B6, $2C, $34, $EB, $E0, $6F, $02, $39, $C8, $12, $0B, $69, $52,
$93, $53, $70, $BB, $C8, $38, $93, $0A, $2C, $32, $23, $90, $28, $13, $A7, $23,
$15, $44, $8D, $AD, $02, $84, $44, $6E, $4E, $3C, $09, $30, $41, $5A, $C3, $CD,
$F0, $5B, $4D, $34, $7F, $EC, $B1, $D9, $A7, $4A, $F9, $68, $D5, $2B, $6D, $47,
$81, $DE, $7E, $04, $FA, $09, $FF, $B7, $E6, $B4, $16, $D3, $C3, $AA, $07, $5B,
$99, $8E, $94, $E7, $F3, $3D, $69, $E7, $25, $BC, $DB, $11, $7A, $66, $30, $11,
$9F, $36, $EB, $13, $1F, $FC, $E2, $E1, $32, $FB, $FE, $D2, $F4, $B8, $73, $84,
$1E, $6F, $77, $DD, $45, $C5, $0B, $CB, $72, $25, $5D, $5C, $8C, $6C, $5C, $C7,
$58, $B3, $AD, $79, $90, $EB, $5C, $CD, $0E, $C2, $CC, $4D, $2B, $B7, $BB, $3E,
$5D, $38, $A9, $A3, $79, $85, $09, $4A, $B9, $DE, $13, $B6, $EC, $88, $2A, $63,
$E4, $D5, $E2, $50, $65, $CD, $CA, $B8, $B4, $27, $6E, $E9, $51, $EA, $A4, $38,
$00, $40, $D2, $FC, $02, $6B, $71, $22, $68, $F4, $4D, $B0, $A0, $09, $F4, $8B,
$83, $CD, $91, $72, $EF, $C1, $0B, $F3, $C0, $F5, $40, $B0, $52, $F6, $34, $E9,
$5F, $08, $9B, $FE, $7D, $67, $3F, $3A, $E7, $49, $A8, $97, $3F, $A3, $E1, $AD,
$3C, $CD, $F9, $08, $8E, $4F, $68, $A3, $D1, $A1, $C9, $E5, $4E, $88, $89, $49,
$DC, $AA, $27, $E5, $95, $A4, $FD, $34, $83, $77, $47, $63, $03, $44, $12, $D7,
$1E, $D2, $15, $6A, $10, $32, $95, $22, $4E, $37, $10, $97, $27, $91, $2E, $3E,
$1B, $04, $EE, $5B, $93, $50, $FF, $FF, $9B, $AA, $06, $EA, $E4, $BA, $FA, $18,
$E0, $04, $81, $0D, $7C, $8A, $AC, $53, $2B, $49, $DB, $C4, $63, $90, $0A, $D1,
$10, $5B, $10, $64, $77, $4E, $B1, $08, $42, $79, $7B, $F3, $03, $1E, $0B, $9B,
$22, $C1, $47, $B9, $5E, $14, $65, $2D, $FC, $1D, $5A, $02, $1C, $DB, $BB, $89,
$F8, $FE, $1C, $DB, $D9, $46, $FD, $E4, $B7, $08, $33, $F0, $7B, $01, $E6, $FC,
$00, $A3, $A5, $DF, $92, $DA, $D2, $E4, $B2, $6A, $DB, $B9, $D8, $59, $4D, $84,
$55, $36, $64, $3E, $62, $6B, $2B, $D1, $60, $10, $FF, $F9, $27, $13, $B0, $93,
$E9, $C5, $2E, $CD, $BB, $0C, $30, $2C, $5C, $2E, $45, $12, $76, $45, $CE, $06,
$11, $35, $19, $94, $7F, $FC, $22, $20, $27, $E6, $FD, $A0, $C0, $CE, $11, $08,
$E7, $B3, $FC, $DD, $35, $8F, $05, $AC, $B5, $70, $A7, $AE, $D4, $92, $B5, $71,
$04, $1D, $12, $73, $68, $AE, $BC, $33, $27, $5E, $6C, $DC, $FE, $B1, $B8, $83,
$C4, $C3, $F3, $0A, $FD, $51, $3A, $4C, $B0, $01, $FF, $BC, $F4, $B4, $F4, $19,
$49, $09, $FF, $FE, $01, $27, $10, $A7, $2C, $2D, $DA, $7E, $CC, $FD, $5C, $8C,
$10, $C1, $F6, $BD, $AE, $10, $34, $40, $FE, $AE, $65, $DA, $25, $4F, $43, $4F,
$B0, $BD, $19, $0D, $93, $3D, $A9, $05, $E4, $F2, $62, $AB, $CE, $06, $7B, $D5,
$FF, $16, $18, $F2, $F8, $54, $77, $5A, $F9, $94, $4C, $8E, $D2, $5F, $8F, $E3,
$71, $CB, $DA, $37, $B5, $CB, $63, $87, $C5, $09, $32, $B0, $DE, $EB, $8B, $00,
$51, $62, $F7, $AA, $D1, $DC, $E2, $91, $EF, $34, $07, $93, $16, $72, $3B, $D7,
$26, $2C, $42, $2E, $0C, $22, $DD, $8C, $C4, $49, $8C, $B6, $A6, $FE, $22, $79,
$74, $4D, $58, $C5, $BD, $4D, $29, $1E, $32, $9B, $4F, $70, $5B, $52, $0D, $27,
$AA, $BD, $ED, $0A, $FF, $03, $A4, $F8, $81, $AD, $9C, $FB, $8D, $D7, $EA, $BA,
$D1, $26, $94, $72, $F3, $30, $A0, $73, $F2, $88, $78, $BB, $6B, $81, $19, $1F,
$A6, $07, $AB, $55, $98, $D7, $4A, $5B, $D1, $CD, $63, $15, $81, $0F, $01, $93,
$49, $61, $92, $7B, $6C, $68, $82, $91, $CB, $30, $14, $70, $F4, $6F, $F2, $FF,
$4F, $9A, $7F, $E8, $90, $12, $FE, $EE, $4B, $2A, $9D, $90, $F4, $DA, $B6, $79,
$FE, $02, $BD, $5F, $DE, $E0, $E7, $BC, $24, $23, $BF, $5D, $60, $EE, $CA, $22,
$E1, $39, $FD, $9E, $11, $7D, $DF, $47, $48, $AE, $73, $F8, $A8, $D1, $09, $EC,
$EB, $71, $81, $05, $EA, $F9, $91, $37, $A5, $7F, $07, $93, $2A, $71, $0B, $AD,
$64, $B3, $40, $34, $D7, $72, $A0, $21, $3E, $21, $5E, $6B, $0E, $23, $D5, $5D,
$F4, $72, $F7, $F7, $38, $93, $10, $6D, $41, $98, $21, $45, $40, $08, $82, $3F,
$73, $A4, $75, $09, $16, $76, $94, $9B, $AB, $DC, $C8, $91, $E5, $6E, $70, $21,
$FF, $74, $53, $11, $97, $2A, $F9, $E7, $D7, $E9, $C0, $5E, $0D, $9C, $69, $DB,
$E6, $B8, $AD, $8D, $D6, $73, $A8, $A4, $F4, $A9, $3B, $0E, $FF, $34, $25, $26,
$F4, $0E, $CD, $A1, $23, $EC, $E4, $58, $22, $5C, $6C, $F7, $EF, $D8, $E4, $92,
$80, $F7, $BB, $6C, $D7, $EA, $50, $22, $CF, $9A, $22, $EC, $95, $BD, $1E, $03,
$0E, $32, $71, $29, $B2, $DA, $6A, $02, $C0, $63, $B6, $2A, $96, $E9, $BD, $D3,
$84, $29, $12, $64, $E0, $1D, $B7, $0E, $85, $F3, $B7, $52, $63, $DD, $3A, $A0,
$FE, $A4, $11, $EC, $B2, $ED, $0C, $8F, $83, $19, $2A, $F6, $D9, $47, $A4, $CE,
$95, $ED, $D6, $DB, $84, $B9, $39, $58, $75, $33, $40, $E7, $F9, $D1, $AF, $A9,
$F6, $C4, $72, $43, $91, $9C, $96, $6D, $36, $A7, $2F, $5D, $DD, $5F, $69, $79,
$AA, $B4, $77, $1D, $4E, $0E, $CA, $B1, $4A, $F4, $54, $43, $B9, $98, $9F, $95,
$C1, $A2, $D1, $13, $19, $23, $03, $72, $07, $25, $AD, $2B, $65, $E8, $95, $74,
$74, $BF, $76, $DD, $1C, $7B, $2A, $E5, $24, $3D, $B6, $3F, $5F, $FF, $83, $89,
$2F, $7E, $2D, $13, $8D, $15, $5C, $98, $C9, $C0, $DA, $E7, $28, $12, $C6, $11,
$24, $B4, $1A, $40, $1D, $82, $EB, $5A, $9D, $ED, $0D, $17, $46, $AA, $53, $CB,
$A1, $B9, $A1, $DB, $B0, $16, $55, $E6, $CE, $7D, $7C, $4F, $8C, $F1, $30, $48,
$AF, $47, $E2, $31, $8D, $FF, $1C, $5C, $CD, $5D, $C9, $25, $2D, $A3, $AF, $68,
$1B, $24, $A4, $A4, $36, $58, $79, $D3, $F8, $92, $1C, $02, $43, $85, $A3, $36,
$F3, $F9, $7D, $E2, $D7, $FC, $06, $37, $4A, $CB, $27, $D9, $16, $AD, $BC, $1F,
$50, $49, $4E, $E4, $1C, $8C, $1D, $3F, $71, $5B, $B5, $1C, $45, $91, $88, $FB,
$2F, $8E, $1A, $6E, $00, $C5, $F9, $A8, $5C, $67, $90, $68, $C4, $C6, $AD, $54,
$D7, $F0, $C4, $71, $BE, $DE, $DB, $00, $07, $15, $26, $3E, $78, $98, $6F, $EF,
$0C, $E7, $7F, $90, $CD, $C6, $1F, $05, $AA, $03, $84, $C6, $77, $34, $24, $75,
$58, $93, $44, $5A, $CC, $83, $67, $BC, $E1, $96, $6D, $FC, $F9, $0E, $1A, $B0,
$8C, $8E, $E2, $61, $66, $86, $DE, $DD, $62, $4D, $EF, $43, $E9, $62, $01, $B0,
$98, $E6, $04, $1F, $B1, $1F, $DB, $6D, $31, $8A, $0D, $39, $A9, $81, $C6, $FE,
$12, $84, $29, $5F, $03, $B0, $D6, $F4, $1F, $8B, $90, $62, $98, $41, $5E, $9D,
$6E, $AC, $25, $CA, $A0, $11, $0E, $D7, $35, $82, $BF, $52, $4F, $02, $C8, $C1,
$7D, $3C, $B7, $14, $C2, $16, $71, $5A, $77, $FD, $0A, $70, $4A, $AC, $6E, $3B,
$CA, $61, $44, $99, $45, $60, $A5, $B8, $D7, $58, $53, $BC, $67, $32, $3E, $E1,
$CA, $26, $E5, $1A, $38, $D6, $18, $6C, $1B, $57, $53, $41, $5B, $DA, $DF, $44,
$EB, $E1, $F7, $F2, $7F, $99, $92, $09, $5A, $4C, $07, $B5, $85, $C0, $96, $A4,
$6D, $53, $6C, $85, $2B, $DE, $22, $E9, $87, $B4, $A6, $C3, $75, $CB, $1B, $F2,
$E4, $07, $7F, $8A, $04, $B5, $3E, $FB, $C6, $2A, $EA, $39, $22, $95, $C5, $A7,
$55, $3A, $9A, $55, $53, $3E, $24, $68, $F2, $B0, $40, $C9, $43, $DB, $FD, $9D,
$5B, $17, $95, $0B, $B9, $0E, $D8, $8E, $F1, $5B, $16, $49, $AA, $8C, $BB, $60,
$49, $14, $06, $68, $CA, $B8, $B4, $73, $EF, $91, $54, $7F, $E8, $D9, $9D, $9F,
$34, $79, $73, $5A, $A8, $30, $B1, $BE, $F3, $16, $43, $83, $07, $64, $49, $5F,
$3C, $75, $22, $83, $E0, $ED, $7C, $22, $95, $64, $B2, $E0, $94, $47, $80, $D7,
$15, $56, $9A, $AF, $3E, $F0, $B3, $A8, $09, $95, $BD, $63, $38, $67, $F9, $7B,
$1C, $B2, $7C, $12, $AE, $CE, $E9, $2E, $EC, $94, $DB, $7A, $C4, $3E, $FA, $5D,
$13, $AB, $53, $F4, $9C, $EC, $A1, $0F, $A8, $B0, $84, $B1, $A9, $0D, $C8, $5F,
$AE, $9D, $9D, $BD, $D7, $9F, $F6, $12, $69, $9E, $06, $5D, $98, $F3, $42, $4F,
$7E, $5F, $57, $AB, $10, $B4, $59, $6E, $C3, $80, $5E, $48, $E3, $E5, $F4, $AA,
$F3, $BB, $1D, $46, $83, $D3, $C3, $CE, $F5, $D0, $5E, $E3, $22, $C7, $1A, $4E,
$5B, $D2, $6E, $B4, $5E, $32, $DE, $AA, $4A, $86, $B4, $1C, $78, $ED, $44, $38,
$F8, $CB, $BC, $D4, $9C, $CC, $3C, $CA, $9B, $84, $51, $D2, $9B, $CF, $58, $14,
$FE, $75, $A6, $86, $72, $9B, $C2, $31, $12, $D0, $82, $7B, $02, $8B, $EF, $5E,
$F6, $D5, $B8, $8E, $8E, $02, $40, $F7, $E2, $D2, $4F, $01, $8D, $17, $E8, $09,
$84, $F2, $26, $42, $44, $8E, $93, $E2, $C7, $66, $64, $76, $23, $CF, $33, $85,
$D7, $C5, $1F, $68, $97, $4E, $6B, $CE, $E9, $BF, $E4, $9E, $C6, $F8, $8E, $A9,
$92, $4D, $B7, $8C, $71, $A4, $EB, $BB, $55, $B7, $0D, $44, $25, $94, $3C, $FF,
$70, $78, $8B, $48, $37, $BE, $86, $B1, $AC, $5D, $E9, $E7, $D0, $B1, $8C, $D3,
$DD, $40, $F5, $42, $4D, $6E, $CD, $64, $7F, $C9, $79, $F4, $BB, $27, $B3, $AB,
$C9, $14, $8B, $21, $F6, $DA, $4B, $A4, $FB, $BA, $7A, $B3, $B8, $FE, $4F, $B9,
$83, $7D, $87, $02, $1D, $9F, $09, $43, $90, $32, $69, $1E, $6F, $39, $86, $BD,
$71, $36, $48, $7C, $2E, $32, $F1, $CA, $33, $B2, $14, $00, $A8, $B1, $D7, $C0,
$2B, $B9, $F7, $A3, $28, $31, $1D, $62, $CA, $6A, $CE, $E6, $7A, $78, $32, $CC,
$CE, $1D, $8E, $A8, $80, $8D, $2A, $B5, $C0, $F9, $B6, $AC, $6B, $7A, $74, $99,
$1D, $F6, $9C, $68, $BC, $4A, $72, $B6, $17, $D7, $84, $9C, $2C, $F8, $3B, $EF,
$D6, $66, $06, $07, $70, $0C, $E8, $09, $82, $D3, $9C, $59, $C7, $9E, $C1, $15,
$13, $E1, $9E, $3C, $19, $87, $60, $C6, $4D, $A1, $17, $B9, $32, $D2, $38, $62,
$12, $1F, $E3, $AE, $D7, $E9, $04, $46, $4F, $7F, $95, $72, $E8, $03, $71, $F7,
$4F, $8B, $38, $9E, $75, $C1, $AA, $86, $20, $13, $77, $D8, $95, $76, $A5, $1E,
$F2, $B9, $92, $48, $4E, $FA, $F4, $03, $12, $41, $47, $BC, $47, $DA, $76, $18,
$4B, $5F, $EF, $99, $FF, $E2, $B8, $F7, $A6, $41, $9E, $95, $61, $BD, $13, $F3,
$6E, $16, $7C, $F1, $63, $4A, $47, $8D, $4F, $5C, $F5, $08, $F9, $E5, $1D, $BB,
$08, $BE, $02, $E9, $B5, $7E, $6A, $28, $C7, $5A, $D4, $AB, $0C, $81, $D4, $23,
$BB, $FF, $A7, $C7, $DB, $E4, $FD, $49, $F7, $C5, $51, $D1, $DB, $1F, $3C, $75,
$B7, $2F, $F0, $80, $C5, $F8, $9F, $80, $CF, $1C, $DA, $77, $EC, $26, $D8, $25,
$CD, $96, $45, $A0, $C4, $1F, $89, $8E, $07, $0F, $B3, $37, $9D, $04, $1D, $AB,
$87, $AD, $63, $15, $C2, $77, $F2, $2C, $65, $84, $10, $0F, $43, $09, $DF, $C5,
$76, $17, $04, $CD, $0A, $17, $01, $69, $F4, $2E, $C1, $0C, $2D, $42, $ED, $1A,
$A6, $00, $8B, $1A, $F9, $74, $4F, $84, $F5, $A9, $11, $0F, $D9, $3F, $5B, $F2,
$7A, $51, $5B, $B9, $FD, $86, $8E, $05, $93, $EF, $57, $4A, $D5, $AC, $CA, $86,
$D2, $87, $6A, $CB, $06, $54, $C2, $F9, $5E, $3C, $F5, $F4, $49, $FF, $7F, $98,
$61, $0D, $94, $5A, $AA, $4A, $07, $9D, $9F, $E7, $6E, $0E, $87, $1E, $8B, $F5,
$1F, $26, $60, $18, $27, $AB, $E7, $74, $27, $EC, $6F, $05, $C0, $1F, $75, $CE,
$1C, $E9, $84, $ED, $D3, $36, $00, $DC, $49, $3E, $D3, $C4, $A4, $FF, $77, $4F,
$17, $D2, $97, $58, $2E, $76, $70, $04, $BB, $8B, $80, $73, $EE, $A8, $F1, $A0,
$06, $EF, $EF, $B7, $64, $BA, $DA, $2E, $9A, $88, $CA, $E8, $24, $CE, $97, $FE,
$09, $1D, $73, $14, $AC, $D6, $79, $88, $46, $A5, $90, $EA, $DC, $8E, $09, $22,
$F3, $B3, $88, $4E, $95, $61, $20, $2F, $08, $38, $7D, $A2, $89, $B3, $A5, $3A,
$9F, $74, $04, $E3, $48, $7E, $12, $7C, $71, $61, $81, $85, $6C, $44, $A3, $89,
$6E, $1A, $C5, $CE, $B8, $43, $57, $5F, $EE, $29, $C6, $BC, $34, $79, $DB, $B7,
$80, $24, $8A, $58, $91, $78, $6A, $A7, $A6, $1B, $93, $0E, $60, $4C, $65, $FE,
$7F, $31, $FE, $D2, $9B, $79, $DE, $9E, $22, $95, $BC, $4E, $E4, $78, $F0, $12,
$2B, $3B, $A4, $EE, $30, $5A, $17, $E6, $A7, $64, $75, $FD, $1F, $7C, $D9, $09,
$B9, $2E, $01, $BA, $80, $35, $C7, $49, $E6, $78, $5A, $D9, $F7, $BB, $E9, $C8,
$F6, $AC, $07, $39, $D7, $C5, $AB, $E0, $29, $6C, $7A, $E4, $2E, $60, $8E, $F8,
$AF, $3D, $51, $AA, $9C, $B5, $CA, $C6, $8E, $5D, $46, $77, $55, $99, $76, $7B,
$24, $99, $C4, $36, $43, $94, $52, $6E, $D7, $C6, $83, $76, $3D, $D8, $7A, $C7,
$81, $3A, $CA, $A2, $BD, $1E, $38, $1E, $B6, $9B, $95, $74, $6B, $2D, $09, $00,
$96, $30, $3F, $69, $33, $C5, $23, $F1, $C8, $2B, $58, $B9, $84, $3A, $16, $6C,
$9C, $68, $D5, $88, $6D, $5E, $5F, $29, $5D, $C7, $EB, $37, $62, $80, $BA, $35,
$12, $C4, $EC, $88, $32, $3B, $CC, $18, $53, $3E, $F9, $BA, $48, $A5, $32, $88,
$F2, $70, $7D, $A3, $AA, $C2, $8C, $5F, $5C, $2C, $E4, $D0, $EF, $0F, $0B, $D0,
$99, $9A, $37, $EA, $7A, $0C, $9B, $59, $9D, $EC, $23, $CC, $C9, $AF, $7D, $A8,
$7A, $1E, $1B, $41, $E3, $35, $D5, $A8, $09, $5E, $5B, $F7, $01, $90, $03, $44,
$0F, $70, $F6, $E7, $88, $EE, $21, $8D, $30, $03, $54, $AE, $DB, $19, $78, $A3,
$55, $A4, $CE, $33, $6F, $8C, $92, $61, $13, $99, $07, $47, $C6, $E4, $09, $20,
$76, $A7, $48, $EA, $DF, $EA, $45, $9C, $5F, $7B, $51, $4D, $35, $62, $B9, $18,
$70, $BC, $A9, $E2, $B1, $47, $0E, $DA, $AF, $67, $75, $D7, $8C, $A3, $73, $67,
$DE, $37, $39, $E8, $26, $C5, $84, $36, $63, $90, $27, $E3, $A4, $CE, $E2, $DD,
$BF, $EF, $91, $48, $41, $1E, $D3, $ED, $CA, $3D, $FD, $65, $2F, $B2, $A3, $71,
$17, $DA, $76, $79, $CA, $EB, $8D, $25, $E7, $7B, $73, $F2, $93, $BF, $94, $96,
$2A, $4E, $A5, $18, $79, $D1, $A0, $77, $30, $73, $57, $B9, $64, $C5, $6F, $57,
$47, $86, $2E, $ED, $32, $69, $B2, $BA, $EC, $16, $72, $11, $AB, $C5, $A9, $9E,
$7F, $51, $B7, $B3, $3B, $0A, $EE, $CD, $78, $A2, $1A, $84, $E2, $69, $48, $CE,
$5A, $9A, $1B, $85, $2A, $6F, $FC, $1C, $1C, $C1, $A5, $9B, $8E, $44, $79, $50,
$EC, $A9, $9B, $9D, $BF, $C5, $7D, $9F, $CD, $FE, $D9, $73, $74, $E2, $8C, $14,
$03, $56, $E3, $73, $A7, $70, $12, $91, $D9, $17, $AF, $4E, $7C, $40, $E7, $40,
$CF, $57, $98, $4B, $99, $31, $CD, $32, $A0, $F9, $0F, $6E, $59, $4A, $89, $F5,
$5C, $BC, $15, $85, $48, $5A, $C2, $FD, $2A, $6D, $CC, $02, $37, $8E, $8B, $D2,
$68, $DB, $0B, $3F, $84, $1A, $92, $BA, $A3, $41, $BE, $58, $A8, $C6, $7A, $03,
$A9, $3F, $A6, $F5, $CD, $6C, $16, $61, $4B, $4E, $E3, $CA, $40, $CC, $10, $65,
$C3, $A4, $4B, $0E, $35, $A1, $F8, $1D, $91, $C2, $01, $91, $B9, $59, $EE, $66,
$A2, $15, $C6, $58, $4E, $E1, $99, $2B, $29, $F5, $7C, $80, $B2, $AA, $7A, $21,
$5B, $F8, $E6, $3F, $D0, $0E, $79, $81, $0F, $F6, $E1, $3E, $D1, $1E, $59, $2E,
$91, $65, $64, $F6, $56, $B0, $8D, $B7, $44, $61, $FF, $43, $C9, $EF, $14, $B2,
$49, $ED, $6E, $D7, $AB, $C5, $84, $EB, $5E, $5D, $7C, $67, $37, $38, $C1, $28,
$E3, $50, $C4, $E9, $5D, $C4, $84, $D7, $F1, $79, $26, $09, $3B, $D1, $FA, $73,
$08, $25, $5D, $8E, $61, $74, $04, $8E, $E8, $E6, $3B, $84, $83, $18, $8B, $57,
$41, $1D, $CF, $BB, $D1, $27, $0C, $12, $7C, $D3, $D5, $BE, $7A, $A5, $34, $C7,
$4D, $A5, $A0, $D0, $49, $22, $04, $2B, $97, $60, $5F, $07, $B6, $4D, $C5, $B2,
$BC, $C3, $D9, $3F, $4A, $2D, $69, $9A, $CC, $37, $42, $55, $1E, $C9, $26, $90,
$DE, $BB, $AC, $29, $65, $E2, $18, $F7, $47, $8A, $FA, $88, $9B, $48, $5E, $30,
$8A, $68, $A9, $13, $B0, $9A, $81, $47, $CE, $DA, $B3, $27, $C8, $3C, $8C, $86,
$17, $FD, $EB, $BB, $44, $6D, $B8, $AF, $BF, $AB, $15, $E9, $5F, $0E, $E0, $91,
$47, $40, $2B, $B9, $33, $69, $39, $B5, $B2, $63, $97, $1F, $BA, $F3, $13, $DB,
$92, $73, $EE, $58, $BE, $FE, $A1, $DC, $73, $AD, $78, $55, $BD, $6C, $3B, $56,
$28, $CD, $6D, $C6, $DA, $2D, $CD, $BB, $62, $32, $B9, $2A, $AD, $3E, $28, $D7,
$D9, $8E, $D1, $66, $A5, $71, $2C, $F2, $C2, $37, $10, $5D, $C1, $70, $15, $6C,
$AE, $C5, $33, $FD, $91, $46, $3E, $3A, $DA, $54, $00, $5D, $EA, $52, $4B, $78,
$96, $71, $EA, $7B, $40, $E6, $78, $78, $46, $BA, $CB, $D2, $20, $74, $BB, $DC,
$46, $48, $7A, $ED, $9D, $0F, $6A, $5F, $0E, $BD, $8E, $EA, $31, $D8, $A6, $FF,
$C1, $98, $57, $F4, $82, $5D, $11, $2B, $DE, $2D, $55, $C2, $83, $61, $01, $31,
$1A, $00, $39, $4F, $31, $41, $66, $F7, $41, $BF, $E9, $3A, $80, $C0, $7A, $EB,
$3F, $2F, $7B, $3A, $C6, $30, $AB, $A6, $D4, $8D, $8E, $55, $EA, $EB, $56, $5F,
$99, $FA, $13, $A1, $AE, $E6, $28, $0D, $99, $30, $86, $EE, $A8, $F1, $45, $9C,
$32, $B0, $AA, $4D, $87, $1C, $16, $F4, $2B, $6A, $70, $18, $32, $A9, $A5, $41,
$A7, $A5, $87, $B5, $B9, $BE, $BA, $B9, $5F, $9E, $5F, $DA, $63, $78, $BD, $DF,
$6B, $EC, $7F, $61, $CC, $EA, $AD, $2B, $CA, $EE, $19, $DE, $66, $24, $0B, $BD,
$C2, $C0, $42, $D8, $CC, $F2, $45, $2E, $17, $4F, $DD, $5A, $B6, $3F, $CC, $35,
$3D, $B4, $EE, $8B, $D7, $70, $B9, $F3, $E5, $65, $C8, $7E, $43, $D3, $8C, $2D,
$58, $A8, $71, $24, $79, $77, $1E, $95, $40, $6D, $0B, $5D, $A8, $50, $C7, $A6,
$51, $7F, $C4, $F7, $C3, $81, $A4, $25, $FC, $4A, $09, $AC, $1F, $FC, $53, $D5,
$36, $46, $AA, $FF, $E6, $DB, $0E, $30, $EE, $86, $F9, $99, $B7, $90, $8A, $75,
$36, $5D, $47, $11, $99, $AF, $64, $5D, $D4, $60, $B4, $62, $95, $09, $73, $C5,
$91, $CA, $26, $F0, $D9, $CB, $20, $2C, $D8, $AE, $CE, $62, $5D, $F2, $AB, $7C,
$A4, $AC, $59, $24, $B6, $58, $4C, $21, $ED, $94, $1E, $42, $74, $34, $D4, $7C,
$22, $D7, $E1, $0C, $21, $9C, $31, $6A, $0F, $A9, $96, $40, $48, $8A, $5D, $67,
$FC, $C9, $69, $9E, $A3, $65, $47, $EC, $89, $BD, $5A, $09, $C5, $42, $52, $E8,
$9F, $22, $12, $B0, $54, $D0, $B5, $4B, $D3, $21, $13, $51, $A8, $01, $FA, $C6,
$28, $9F, $E1, $A3, $10, $E9, $46, $C2, $3D, $82, $F4, $68, $B7, $B1, $34, $2B,
$4E, $C6, $49, $A8, $65, $2F, $12, $99, $16, $FF, $30, $4B, $8E, $86, $14, $9D,
$7A, $7A, $46, $50, $18, $6F, $87, $02, $19, $79, $0E, $E1, $52, $27, $FE, $B0,
$52, $C5, $F6, $E0, $98, $3B, $5F, $D2, $1F, $1D, $28, $5C, $E0, $C9, $7C, $4F,
$B5, $1F, $DC, $AD, $6C, $3D, $14, $C5, $F4, $F1, $41, $E0, $4F, $81, $CF, $D0,
$27, $13, $B4, $DF, $A4, $36, $9B, $7E, $86, $04, $C5, $C0, $C3, $F0, $E5, $77,
$6C, $37, $73, $A6, $FF, $0D, $7C, $E7, $6D, $C8, $DC, $8F, $CD, $55, $FD, $4D,
$95, $BF, $78, $82, $D6, $B6, $FC, $71, $FA, $78, $EF, $93, $93, $2E, $52, $40,
$6D, $DE, $B6, $13, $DD, $4E, $4A, $E6, $42, $58, $58, $8F, $B4, $5A, $B2, $B9,
$5F, $F9, $27, $2E, $44, $17, $05, $B4, $62, $0E, $48, $BD, $8C, $A9, $C2, $71,
$9F, $E9, $00, $5D, $C8, $A0, $1C, $EE, $C3, $F8, $90, $0B, $71, $A1, $7E, $E1,
$C1, $88, $0F, $32, $89, $68, $C7, $AB, $F7, $56, $F5, $55, $2A, $05, $F1, $8A,
$45, $4A, $79, $CE, $01, $EA, $8F, $5B, $59, $6A, $FE, $2C, $B8, $13, $D3, $02,
$82, $E9, $46, $9E, $67, $25, $2F, $73, $D9, $CB, $50, $D0, $6E, $7A, $2F, $33,
$31, $F1, $9F, $4C, $AD, $BC, $B1, $92, $B4, $FB, $23, $6B, $EE, $F8, $0E, $66,
$87, $FB, $F7, $3C, $10, $6B, $5A, $8F, $15, $41, $CA, $9D, $AB, $E8, $98, $82,
$9F, $18, $3B, $D4, $58, $9B, $E6, $45, $84, $01, $1B, $FA, $76, $E5, $7B, $FD,
$23, $1E, $6D, $8E, $4D, $50, $8E, $A7, $DF, $A1, $7B, $C6, $5D, $77, $5B, $89,
$43, $00, $AB, $36, $A7, $2D, $3E, $CC, $0D, $12, $65, $92, $60, $9E, $64, $0A,
$32, $81, $CD, $FA, $D5, $7F, $F9, $23, $EE, $C4, $4D, $30, $04, $E2, $DE, $1F,
$6A, $65, $98, $28, $5B, $A3, $52, $35, $DD, $4F, $EA, $A0, $DD, $02, $87, $8A,
$88, $7D, $14, $28, $07, $A7, $E2, $14, $82, $B5, $D0, $17, $28, $0F, $9D, $54,
$E9, $31, $18, $88, $0C, $9B, $29, $2D, $4D, $27, $D8, $FE, $B3, $E8, $FC, $18,
$2E, $54, $6B, $48, $46, $5C, $71, $22, $5E, $5A, $F8, $21, $DD, $69, $F2, $A5,
$A3, $FF, $62, $D2, $1D, $2F, $1A, $51, $81, $B8, $EE, $DE, $9C, $1E, $79, $55,
$91, $E5, $7F, $77, $77, $2C, $74, $00, $06, $27, $04, $7C, $4D, $AF, $0E, $A5,
$43, $CA, $70, $AC, $28, $F3, $0F, $CC, $BE, $16, $62, $E3, $11, $CD, $AC, $20,
$26, $D6, $A1, $A0, $AD, $18, $A5, $BE, $72, $57, $53, $04, $E3, $60, $C7, $04,
$5C, $FE, $8C, $B1, $6A, $E9, $60, $60, $73, $31, $5E, $DD, $08, $F8, $16, $43,
$54, $B9, $1F, $45, $C6, $8C, $7E, $F4, $8C, $AC, $B9, $50, $F1, $0C, $CF, $F0,
$44, $A6, $D5, $69, $20, $7D, $13, $7A, $0E, $BD, $F9, $F3, $94, $24, $65, $9E,
$DC, $9A, $F5, $5F, $1C, $C4, $F3, $89, $4C, $FD, $56, $7F, $7D, $58, $63, $D8,
$11, $7E, $74, $E0, $86, $41, $40, $19, $B7, $7C, $AC, $8E, $A6, $84, $7A, $79,
$AA, $A8, $3F, $0D, $BF, $3F, $16, $33, $A0, $97, $7B, $67, $61, $04, $C6, $58,
$2D, $42, $29, $9E, $BF, $69, $53, $15, $B0, $CD, $7F, $35, $4F, $7A, $54, $3E,
$A4, $33, $D6, $54, $9D, $53, $09, $7D, $91, $5B, $40, $B3, $A5, $33, $B1, $9E,
$64, $C9, $43, $8F, $94, $73, $2F, $71, $E7, $63, $5A, $B3, $6F, $C6, $1D, $0F,
$52, $41, $4E, $30, $82, $5C, $D7, $2F, $DC, $CC, $6E, $93, $5E, $6A, $8D, $5E,
$48, $6D, $C1, $9E, $D8, $4E, $89, $0E, $D5, $13, $66, $C1, $CB, $B3, $AE, $45,
$B6, $EE, $9F, $85, $07, $55, $A9, $1B, $05, $77, $AD, $58, $11, $E2, $15, $92,
$EE, $1E, $07, $09, $35, $6A, $98, $D9, $1B, $80, $E8, $87, $9D, $3E, $A3, $05,
$7F, $21, $D1, $4B, $32, $27, $D4, $8D, $25, $B7, $AF, $17, $2E, $2A, $5E, $B8,
$62, $4C, $F1, $BC, $78, $14, $91, $8E, $FA, $E0, $06, $14, $04, $E4, $93, $62,
$9F, $80, $C1, $41, $12, $BE, $3A, $B5, $02, $8D, $7B, $64, $CB, $D9, $74, $2B,
$42, $D6, $D2, $28, $92, $4E, $E0, $36, $76, $62, $E6, $06, $A5, $F0, $B2, $6C,
$42, $1B, $E9, $A7, $87, $A4, $DA, $E8, $1A, $06, $F1, $FC, $3C, $B3, $13, $92,
$F4, $A9, $C5, $3F, $88, $72, $43, $F0, $90, $EB, $30, $0E, $40, $E4, $4D, $CF,
$3A, $2B, $17, $DC, $13, $B4, $47, $F4, $1D, $C5, $FA, $3B, $52, $D4, $11, $D9,
$A3, $21, $1F, $FD, $93, $4B, $70, $F3, $B3, $1D, $B4, $AF, $DC, $25, $72, $3B,
$56, $85, $64, $4C, $39, $9C, $A8, $13, $D0, $57, $AA, $96, $58, $E2, $78, $64,
$B4, $D1, $00, $B6, $F4, $7E, $4C, $F5, $26, $B5, $FE, $56, $D1, $EC, $75, $71,
$2B, $A7, $1E, $1E, $EE, $6E, $C2, $89, $DD, $4A, $D5, $9A, $C8, $16, $95, $4F,
$10, $2D, $01, $69, $12, $B9, $20, $D0, $D1, $4E, $17, $6A, $4D, $13, $78, $03,
$94, $9F, $FF, $4E, $8E, $CC, $93, $96, $AD, $BA, $3F, $97, $CE, $72, $C0, $7B,
$60, $75, $0A, $9D, $CF, $AE, $35, $52, $2F, $EF, $E7, $18, $BA, $DA, $6B, $8D,
$12, $E7, $58, $72, $7B, $8D, $FD, $99, $60, $28, $60, $1C, $C8, $D1, $5C, $F6,
$E7, $F8, $AF, $AA, $80, $CD, $FD, $3B, $0A, $B5, $59, $96, $8F, $72, $37, $84,
$B3, $0F, $EE, $34, $74, $FD, $BC, $B0, $99, $C1, $22, $D0, $D4, $55, $D3, $EA,
$EE, $2F, $12, $0E, $D7, $09, $A9, $F7, $06, $CE, $7A, $F9, $FE, $A9, $2B, $D9,
$00, $2D, $E2, $FE, $D4, $70, $39, $CD, $99, $4A, $C3, $B0, $94, $FB, $21, $E7,
$57, $4D, $2E, $2A, $74, $42, $61, $6C, $90, $FE, $11, $6F, $90, $BB, $C4, $8E,
$8A, $6E, $33, $B1, $5E, $6B, $27, $D6, $9D, $6D, $B1, $06, $12, $C1, $8F, $EE,
$89, $34, $72, $F3, $70, $74, $D6, $AF, $FC, $FB, $09, $53, $25, $5C, $52, $E0,
$39, $57, $46, $40, $8B, $0E, $6B, $34, $43, $60, $2D, $E8, $D1, $8F, $3A, $0E,
$7B, $7C, $D9, $C1, $A8, $7E, $29, $B2, $79, $F8, $79, $F2, $C9, $04, $4B, $3F,
$BF, $BC, $3D, $7F, $0F, $BD, $8E, $AF, $E5, $6A, $74, $46, $91, $E7, $3E, $23,
$D3, $1C, $45, $A9, $4F, $7E, $AA, $94, $F8, $4B, $48, $2A, $13, $E5, $36, $35,
$F1, $64, $A1, $11, $13, $B6, $11, $24, $04, $9D, $3F, $69, $EE, $E0, $E4, $2F,
$7A, $F5, $23, $DD, $B9, $83, $24, $44, $0D, $5A, $69, $4D, $DF, $A4, $2B, $3A,
$FE, $D2, $B9, $35, $BC, $63, $70, $2C, $EB, $78, $97, $32, $A6, $8E, $1C, $43,
$DA, $2A, $19, $A6, $6A, $54, $F3, $9A, $19, $96, $99, $D2, $44, $D9, $31, $39,
$1A, $63, $6F, $F0, $11, $44, $44, $43, $94, $2A, $D5, $71, $9B, $0F, $E9, $37,
$DF, $A0, $3F, $4A, $34, $B1, $18, $A2, $F0, $9E, $70, $89, $1F, $E8, $C0, $70,
$6B, $14, $1A, $60, $EF, $8A, $67, $6E, $1B, $74, $F5, $E3, $A3, $95, $83, $8D,
$9B, $5B, $9A, $FB, $B5, $9D, $CC, $57, $F3, $83, $33, $8F, $34, $FF, $33, $11,
$20, $E8, $FD, $8C, $F8, $18, $8D, $A8, $75, $1B, $2C, $B3, $67, $C7, $AE, $B8,
$F8, $64, $2D, $49, $AB, $81, $5D, $D5, $0B, $2C, $08, $1F, $58, $88, $7A, $36,
$80, $FF, $4D, $A7, $A7, $6E, $12, $74, $32, $79, $DD, $82, $76, $A1, $54, $56,
$FB, $8E, $CC, $32, $85, $34, $0E, $10, $0D, $48, $1D, $9B, $5F, $0C, $D4, $20,
$CD, $1F, $DD, $52, $13, $0C, $A4, $37, $96, $74, $44, $E5, $CA, $CE, $84, $84,
$82, $AA, $6C, $ED, $9A, $CD, $7E, $C0, $BB, $D0, $B1, $94, $47, $5F, $34, $77,
$23, $5D, $46, $3C, $8C, $98, $31, $03, $A1, $B2, $08, $22, $30, $F5, $09, $DD,
$FB, $44, $45, $AE, $37, $83, $D1, $A7, $6F, $BC, $F2, $70, $7C, $71, $E9, $2E,
$58, $C6, $4E, $7F, $73, $EC, $F7, $AF, $9C, $00, $E1, $F2, $E9, $7C, $EA, $BC,
$E3, $0E, $16, $BC, $23, $EC, $EA, $50, $C4, $DA, $EC, $77, $67, $44, $1D, $68,
$CA, $73, $84, $11, $05, $43, $DC, $B0, $07, $07, $1F, $C1, $18, $1F, $FE, $D4,
$16, $82, $73, $A5, $B6, $AC, $74, $F9, $B3, $7D, $45, $FD, $1F, $E5, $E4, $7A,
$51, $FB, $70, $A3, $15, $B8, $89, $5C, $0E, $96, $04, $13, $8B, $AD, $31, $F1,
$77, $CB, $63, $CD, $42, $66, $54, $0F, $65, $7E, $1D, $F1, $16, $00, $AC, $6E,
$BF, $C5, $6C, $D8, $97, $AA, $94, $FD, $56, $8B, $1E, $5D, $65, $37, $09, $80,
$99, $AD, $83, $CB, $99, $0C, $17, $00, $D4, $77, $67, $09, $D9, $46, $CC, $18,
$62, $5B, $4A, $C5, $8B, $84, $18, $75, $C5, $D7, $11, $32, $70, $7D, $4D, $04,
$B2, $6C, $F4, $BC, $EC, $5C, $C1, $B9, $3C, $C6, $01, $CA, $CB, $37, $54, $65,
$C0, $53, $BF, $0A, $19, $BD, $C2, $59, $2E, $5A, $C3, $6D, $C0, $01, $54, $7A,
$88, $F5, $09, $76, $2D, $41, $C0, $A6, $18, $02, $72, $E3, $4C, $4F, $A9, $3F,
$F0, $8D, $56, $DC, $96, $17, $49, $A1, $AD, $AE, $54, $86, $56, $0E, $40, $27,
$F9, $8B, $AC, $4A, $1A, $91, $CF, $CD, $39, $86, $6A, $03, $B6, $3C, $17, $8A,
$09, $B2, $A8, $07, $52, $FE, $B2, $59, $68, $D8, $D9, $BE, $15, $32, $21, $D4,
$7A, $12, $2E, $01, $17, $9F, $FA, $7E, $6E, $F5, $83, $79, $69, $CA, $F4, $5B,
$E4, $58, $80, $09, $B6, $0F, $44, $55, $1C, $67, $16, $BC, $55, $8D, $2A, $9C,
$D1, $5B, $E1, $C6, $E3, $E9, $84, $72, $16, $37, $0C, $65, $F0, $6D, $C0, $58,
$CE, $43, $23, $BD, $E6, $F0, $20, $20, $5F, $FD, $FE, $44, $10, $AC, $E9, $2F,
$8A, $02, $CD, $3D, $FE, $EE, $5A, $C9, $1E, $08, $53, $90, $02, $23, $3A, $06,
$21, $02, $7C, $CA, $78, $50, $C8, $D6, $7B, $90, $B1, $EB, $99, $15, $7D, $40,
$19, $3F, $E4, $DF, $5A, $EC, $26, $C9, $68, $02, $59, $42, $4C, $5B, $B3, $36,
$D6, $F2, $9D, $B4, $C9, $D6, $29, $D8, $63, $32, $E3, $DD, $94, $B7, $5D, $E1,
$D4, $D2, $F9, $FE, $1B, $19, $58, $F1, $1E, $67, $78, $F6, $C2, $2C, $C3, $CD,
$28, $19, $8D, $04, $4F, $19, $83, $0A, $FE, $CA, $D1, $3B, $53, $25, $06, $C3,
$9C, $2D, $98, $4C, $53, $2D, $DD, $64, $E8, $7E, $CE, $B5, $B9, $09, $C5, $AE,
$47, $8E, $A0, $A6, $C2, $06, $EC, $4D, $CB, $31, $7F, $03, $3E, $55, $C9, $38,
$D8, $52, $0A, $2E, $16, $CF, $37, $84, $CA, $FD, $88, $07, $73, $A6, $87, $32,
$6F, $08, $DF, $BD, $4D, $73, $AC, $DB, $9D, $AD, $7F, $92, $9C, $B6, $C5, $E9,
$07, $63, $C4, $37, $10, $A5, $72, $4B, $7F, $F8, $5B, $24, $30, $A1, $65, $79,
$15, $B6, $58, $85, $CA, $4A, $D6, $22, $F6, $3D, $2C, $D8, $F4, $7E, $A7, $00,
$FC, $3F, $0A, $B0, $BA, $04, $AD, $BA, $30, $49, $7B, $76, $A7, $CB, $77, $AE,
$84, $5E, $11, $11, $23, $7D, $7D, $31, $27, $79, $DD, $0F, $E8, $7D, $0A, $7B,
$F9, $8A, $CA, $6A, $CF, $FC, $85, $F0, $22, $F6, $30, $32, $39, $9F, $E2, $80,
$47, $1F, $2C, $A1, $95, $D7, $DB, $B9, $61, $05, $AD, $AE, $35, $5F, $CC, $3F,
$9C, $8E, $D9, $26, $4B, $11, $D3, $2B, $7B, $93, $0A, $F8, $DE, $53, $01, $53,
$0E, $D7, $B8, $83, $A2, $D7, $3F, $92, $84, $C4, $B3, $C1, $A5, $79, $40, $E3,
$88, $A2, $A9, $60, $B5, $56, $88, $A6, $FB, $CD, $F7, $40, $4C, $D4, $2D, $8B,
$26, $D2, $53, $B4, $8D, $3F, $8C, $84, $D8, $0C, $AC, $88, $A6, $13, $D3, $97,
$0D, $35, $8B, $E3, $0E, $DA, $0D, $4E, $A6, $B9, $65, $7C, $9D, $E0, $68, $E5,
$60, $E5, $FA, $FF, $7D, $38, $AB, $12, $D6, $39, $A7, $64, $87, $9C, $44, $6E,
$96, $5D, $8B, $2F, $0C, $65, $FD, $97, $4C, $E7, $DA, $72, $92, $61, $19, $7F,
$30, $12, $02, $AD, $10, $DB, $85, $44, $7E, $08, $06, $3A, $58, $08, $B6, $C2,
$43, $FF, $A2, $D0, $90, $D4, $70, $BB, $35, $BB, $B8, $94, $D6, $94, $64, $26,
$9A, $61, $E2, $20, $E6, $25, $5F, $87, $31, $E8, $BF, $EE, $D7, $B1, $C8, $15,
$AA, $4E, $B3, $73, $F1, $AB, $FC, $9E, $DA, $46, $32, $A4, $6B, $FF, $E4, $AB,
$4C, $15, $B4, $42, $72, $80, $27, $2F, $43, $D6, $C6, $ED, $8C, $7A, $52, $F3,
$C9, $D9, $50, $26, $C8, $AD, $2E, $73, $36, $EC, $1D, $CD, $5C, $93, $42, $98,
$B2, $CC, $C5, $00, $AD, $F8, $D1, $B1, $66, $45, $CA, $CD, $1D, $89, $1E, $8A,
$B4, $DF, $1C, $D6, $0F, $36, $E6, $A7, $AE, $8C, $65, $0F, $5C, $37, $54, $14,
$EA, $E4, $A4, $6D, $92, $DF, $C1, $65, $D7, $5E, $28, $FA, $B0, $F0, $67, $51,
$98, $A1, $59, $53, $F8, $1E, $FB, $E1, $F5, $40, $12, $A5, $C0, $0E, $05, $4B,
$F6, $7C, $8C, $86, $71, $35, $75, $C8, $7E, $3B, $93, $8E, $A8, $D5, $67, $C3,
$F4, $46, $CF, $FD, $B9, $B9, $42, $A6, $92, $7A, $E8, $7F, $B4, $1F, $BD, $25,
$40, $29, $AC, $9B, $49, $4D, $31, $AB, $10, $8B, $3B, $54, $B1, $1B, $58, $C1,
$26, $28, $E0, $AB, $E1, $2D, $E4, $09, $B7, $C3, $12, $2A, $04, $05, $60, $DE,
$26, $44, $CE, $80, $3D, $DE, $85, $FF, $22, $E9, $6D, $A4, $DE, $3C, $A3, $A0,
$8F, $F1, $F6, $A6, $21, $77, $C9, $A0, $6D, $8F, $07, $91, $A6, $1E, $D4, $2E,
$D5, $CB, $32, $09, $78, $00, $19, $7C, $A7, $6F, $01, $44, $50, $CC, $72, $F9,
$CB, $96, $47, $3D, $04, $02, $25, $A6, $6D, $41, $74, $D4, $91, $D3, $4C, $D2,
$A2, $EC, $57, $EC, $4B, $3E, $F9, $F6, $9E, $B1, $9A, $9B, $EE, $89, $CD, $4C,
$C2, $77, $69, $55, $91, $39, $8C, $1E, $03, $57, $6E, $C4, $C9, $F6, $32, $AF,
$C1, $DC, $61, $68, $3B, $5A, $92, $F4, $A1, $E2, $59, $25, $2F, $FC, $C1, $85,
$07, $79, $0A, $AE, $12, $BD, $8F, $67, $5A, $B5, $85, $63, $6E, $8E, $01, $19,
$06, $2B, $3D, $22, $58, $63, $4F, $6D, $19, $6F, $15, $2C, $CB, $FA, $67, $96,
$6A, $E7, $44, $AC, $E7, $3B, $C5, $74, $59, $5E, $95, $77, $3C, $E7, $3B, $7A,
$8B, $E6, $28, $D2, $B8, $4F, $06, $F2, $1E, $38, $C6, $56, $0E, $BB, $1B, $6D,
$7B, $ED, $61, $A2, $71, $C3, $F3, $5D, $DF, $E1, $8D, $55, $06, $C5, $B1, $90,
$EB, $7F, $21, $FC, $37, $52, $8D, $2F, $F6, $93, $33, $88, $5E, $C3, $2A, $0C,
$0F, $53, $F2, $1A, $BC, $17, $AA, $AA, $BB, $EC, $3C, $A2, $61, $81, $0C, $80,
$DE, $91, $89, $B5, $73, $3A, $01, $07, $C9, $70, $C9, $BD, $72, $76, $B6, $97,
$3C, $9E, $5B, $88, $B6, $4B, $45, $C3, $DA, $CC, $33, $3A, $93, $ED, $BE, $B5,
$73, $25, $A3, $7D, $95, $88, $01, $6D, $28, $AA, $A1, $48, $42, $38, $D1, $D0,
$A0, $21, $A8, $12, $FC, $9E, $03, $1C, $80, $14, $14, $9F, $7B, $7E, $34, $3A,
$51, $33, $68, $EF, $C5, $01, $F6, $78, $27, $7A, $2A, $2C, $28, $19, $3D, $43,
$38, $E7, $7C, $17, $FB, $F6, $83, $0E, $67, $B3, $5F, $28, $A6, $D5, $15, $0B,
$44, $F2, $02, $45, $73, $57, $A0, $EA, $2F, $A2, $53, $95, $79, $0C, $F6, $38,
$BE, $EB, $79, $92, $68, $5E, $2D, $0F, $D3, $BB, $AF, $3F, $D7, $6B, $E6, $3C,
$5D, $CC, $95, $75, $DD, $77, $E4, $A4, $22, $87, $CC, $37, $4B, $33, $BE, $DF,
$6D, $C5, $38, $3E, $A9, $D9, $05, $4F, $F1, $23, $2F, $2E, $FA, $23, $81, $63,
$79, $B9, $B8, $20, $15, $9A, $32, $22, $EB, $8F, $DC, $19, $63, $31, $88, $30,
$BB, $61, $C6, $96, $21, $45, $B4, $F8, $C8, $0F, $4A, $4E, $BB, $81, $78, $4B,
$74, $E7, $2C, $3C, $F4, $99, $75, $4A, $22, $56, $7E, $60, $16, $4A, $DA, $7D,
$B7, $A4, $F4, $B5, $0D, $E8, $14, $9E, $BC, $B8, $79, $9A, $E4, $1A, $9B, $0A,
$22, $07, $F7, $48, $8E, $8A, $18, $70, $69, $4F, $45, $B5, $16, $E1, $AA, $29,
$C8, $50, $6F, $8D, $59, $AA, $B9, $F0, $41, $D1, $D1, $32, $8D, $D2, $65, $2C,
$6A, $44, $8A, $1E, $F0, $76, $4D, $C0, $D5, $BC, $5A, $18, $1C, $09, $06, $40,
$C8, $66, $5D, $49, $57, $37, $26, $6C, $D0, $13, $03, $47, $B0, $7D, $C8, $C9,
$C5, $9D, $6B, $01, $F3, $0A, $B8, $47, $73, $CE, $CE, $88, $2A, $A8, $85, $44,
$61, $AB, $03, $7B, $4F, $62, $45, $39, $C4, $96, $3E, $32, $5E, $7C, $80, $71,
$D8, $19, $19, $B1, $7F, $0A, $BE, $85, $19, $D6, $37, $20, $F4, $24, $1F, $B1,
$89, $6C, $6F, $0D, $27, $73, $0E, $2D, $54, $EB, $D5, $37, $78, $9E, $B5, $58,
$C1, $1D, $AD, $6E, $D2, $DB, $75, $7D, $7D, $F1, $BC, $BC, $95, $F1, $88, $2A,
$85, $D5, $AA, $7E, $77, $BD, $C4, $50, $B7, $F3, $E8, $1C, $3A, $DE, $40, $DC,
$6E, $CD, $23, $D4, $86, $FC, $C8, $68, $29, $6D, $5F, $75, $49, $CB, $E6, $CB,
$37, $C1, $ED, $24, $7A, $AD, $DA, $72, $2C, $C4, $48, $4A, $13, $D4, $84, $41,
$A3, $87, $04, $98, $71, $07, $88, $53, $C8, $B1, $5A, $F9, $71, $D0, $C6, $1D,
$62, $7B, $B0, $46, $DD, $42, $C2, $9E, $3E, $C1, $19, $59, $DF, $E4, $4D, $31,
$71, $0A, $12, $1F, $67, $B5, $67, $0F, $98, $AC, $7B, $6B, $8C, $78, $FD, $BB,
$9D, $31, $F4, $EF, $B5, $0F, $B7, $7C, $18, $0D, $16, $E2, $6C, $46, $FE, $E5,
$6A, $C7, $93, $AE, $E5, $E6, $89, $8D, $60, $E3, $A5, $AF, $F4, $28, $A0, $F0,
$DC, $C0, $CF, $A5, $76, $44, $6B, $BB, $30, $98, $7C, $BE, $D8, $0D, $39, $6A,
$B2, $01, $FE, $22, $63, $D0, $D8, $6A, $F6, $42, $F0, $C9, $8C, $B6, $DF, $E2,
$E3, $32, $9E, $3B, $A3, $5C, $41, $03, $2C, $DE, $56, $58, $40, $73, $10, $D8,
$95, $8B, $F9, $B1, $2E, $7F, $AF, $E2, $B9, $54, $1B, $52, $BA, $66, $39, $15,
$79, $91, $04, $94, $7D, $D3, $01, $27, $C7, $A2, $D9, $5A, $AE, $A0, $25, $99,
$78, $18, $B0, $6A, $3F, $E0, $1E, $D7, $1E, $A5, $7A, $94, $D7, $14, $BF, $40,
$7B, $DB, $5E, $46, $FB, $2D, $21, $24, $6F, $B3, $CD, $98, $94, $34, $98, $DB,
$73, $4B, $BC, $11, $A7, $D8, $3D, $B6, $1D, $2D, $19, $6C, $BD, $12, $40, $F6,
$8D, $34, $01, $73, $15, $EF, $3E, $72, $56, $D6, $51, $A0, $B9, $94, $8E, $86,
$51, $6A, $FE, $E0, $C6, $5A, $F5, $63, $21, $77, $61, $2A, $63, $4C, $D8, $B2,
$89, $88, $88, $27, $7B, $D5, $43, $97, $66, $05, $03, $35, $4A, $E4, $8F, $70,
$6F, $07, $9B, $FB, $42, $D5, $5A, $D5, $7D, $03, $24, $BD, $86, $E3, $A2, $07,
$A9, $91, $BA, $3E, $F9, $9B, $A0, $B6, $8D, $1C, $5D, $13, $D9, $F2, $EC, $DC,
$FB, $42, $5F, $92, $08, $92, $FA, $5D, $D6, $DA, $A1, $B2, $59, $A5, $9E, $AC,
$1C, $76, $94, $20, $1D, $9D, $A1, $71, $BA, $63, $D1, $3B, $50, $3A, $32, $5F,
$DE, $5E, $55, $35, $0E, $43, $9F, $85, $2B, $32, $91, $FE, $21, $24, $CB, $16,
$7C, $C8, $C2, $07, $7F, $69, $D8, $31, $33, $C9, $0F, $27, $4D, $E6, $B7, $B3,
$B4, $70, $8E, $E1, $4D, $B1, $95, $F1, $68, $4A, $6C, $F2, $1A, $93, $41, $FC,
$9E, $A4, $B1, $3E, $D0, $EC, $EB, $E2, $9F, $64, $BD, $D5, $F7, $2A, $F0, $35,
$88, $C5, $BE, $EA, $46, $93, $AF, $8C, $DB, $E4, $4B, $BB, $EB, $DF, $38, $D7,
$92, $17, $D4, $7B, $9A, $8F, $59, $14, $BD, $F7, $B2, $AD, $1B, $88, $1B, $57,
$66, $96, $19, $28, $3A, $F1, $DA, $68, $59, $50, $9B, $2D, $31, $45, $43, $33,
$49, $88, $7B, $3C, $F5, $AC, $D8, $7A, $5F, $5B, $D8, $BF, $E5, $B3, $6D, $4C,
$C7, $77, $5E, $6E, $AA, $ED, $6B, $90, $EC, $FD, $F0, $00, $25, $97, $F1, $2B,
$E7, $34, $80, $C1, $6F, $5B, $81, $05, $E3, $17, $39, $E5, $54, $94, $88, $77,
$72, $09, $CE, $5A, $2D, $69, $90, $97, $88, $FE, $B8, $B5, $A2, $C2, $D8, $04,
$DE, $74, $D8, $13, $40, $13, $DD, $6A, $88, $BF, $A0, $AC, $13, $F4, $3F, $F3,
$8D, $32, $64, $45, $7A, $86, $C6, $77, $9C, $9D, $BC, $84, $FD, $03, $CE, $29,
$43, $DA, $EC, $96, $E9, $29, $7C, $30, $3C, $1E, $66, $CD, $C2, $1D, $B6, $77,
$01, $EB, $5D, $72, $5F, $F6, $95, $F2, $CD, $0D, $F6, $2F, $D7, $FF, $8B, $EC,
$D6, $F7, $59, $BA, $39, $44, $DF, $B2, $59, $F4, $66, $AB, $54, $4E, $B5, $7C,
$AE, $1F, $80, $BC, $42, $8F, $03, $C2, $B0, $6C, $05, $34, $88, $09, $B8, $00,
$98, $05, $AD, $52, $C0, $09, $48, $CF, $DD, $66, $74, $4C, $B9, $44, $2B, $03,
$CB, $4C, $BC, $CE, $6D, $77, $2F, $CA, $0E, $7E, $BC, $2D, $6A, $C9, $A2, $2A,
$4E, $B6, $7A, $09, $3E, $D0, $7C, $DC, $64, $D5, $A7, $65, $54, $08, $8B, $17,
$03, $61, $94, $29, $48, $FB, $77, $C4, $D4, $DD, $55, $84, $40, $C1, $63, $79,
$EC, $3F, $E0, $08, $ED, $BA, $4E, $00, $89, $90, $19, $49, $90, $59, $FC, $76,
$BC, $31, $16, $48, $D7, $7D, $BF, $52, $42, $E5, $D9, $4D, $CB, $18, $1C, $2B,
$B3, $DB, $B7, $C8, $9E, $75, $72, $E6, $7D, $3C, $8E, $9E, $E3, $25, $5B, $A8,
$FB, $D7, $4E, $39, $EC, $4C, $67, $0A, $67, $2E, $83, $77, $4E, $C3, $14, $D8,
$FB, $5A, $42, $A6, $78, $52, $E5, $20, $B6, $0E, $5E, $5B, $5A, $E7, $E2, $B0,
$9C, $13, $31, $1E, $02, $35, $7C, $3D, $5A, $AE, $46, $98, $68, $12, $69, $9E,
$9D, $26, $30, $C6, $74, $2B, $1C, $41, $EE, $08, $0F, $F0, $9B, $45, $4A, $6E,
$A9, $F3, $F6, $A4, $E8, $47, $ED, $3D, $55, $9B, $91, $29, $6D, $3F, $1D, $71,
$BC, $E1, $53, $A3, $FD, $A7, $9B, $55, $EF, $0B, $F1, $28, $92, $9D, $47, $0A,
$19, $1A, $E0, $FE, $8D, $1C, $A3, $AB, $47, $17, $DB, $57, $38, $2D, $3D, $2C,
$88, $51, $33, $63, $C0, $CF, $34, $94, $5B, $CB, $12, $8F, $F7, $E0, $7B, $E2,
$E8, $CB, $C7, $8E, $95, $25, $E4, $36, $0B, $CC, $18, $98, $B3, $10, $36, $89,
$36, $51, $73, $AA, $40, $D5, $B3, $5D, $32, $EC, $20, $15, $7A, $A5, $7A, $09,
$16, $BC, $61, $AF, $08, $1F, $90, $FC, $86, $0A, $73, $C4, $0C, $84, $6C, $8A,
$1A, $DE, $A5, $86, $B0, $D3, $1F, $50, $78, $9E, $67, $06, $77, $85, $73, $8D,
$4A, $52, $BF, $7F, $CE, $A7, $31, $B5, $B2, $D9, $2B, $0E, $C6, $0E, $0B, $2F,
$FD, $DA, $38, $BE, $42, $31, $10, $EE, $9F, $34, $8B, $B6, $5E, $9B, $88, $8E,
$6E, $E8, $D8, $70, $90, $E6, $97, $28, $BD, $01, $D5, $D0, $A1, $BE, $B8, $BC,
$A6, $C9, $E2, $A9, $2A, $1F, $CC, $46, $12, $58, $C6, $3C, $BB, $24, $2A, $7A,
$A6, $AD, $BC, $C0, $9E, $C2, $E3, $A7, $16, $B1, $4C, $C3, $69, $C2, $82, $6B,
$CD, $CA, $19, $94, $7E, $24, $0A, $17, $8D, $E5, $15, $41, $14, $12, $6E, $5E,
$8F, $F1, $3F, $C3, $A7, $71, $DC, $1F, $F3, $E8, $FF, $81, $20, $2C, $4D, $02,
$93, $07, $C9, $B1, $C9, $77, $58, $07, $4E, $C5, $DB, $4D, $15, $C3, $14, $70,
$A4, $CC, $17, $FB, $A2, $B6, $B9, $87, $18, $07, $D6, $9B, $C6, $F2, $64, $FD,
$55, $81, $5B, $65, $45, $25, $6D, $6F, $E1, $90, $5C, $64, $CC, $E1, $4A, $83,
$41, $AF, $61, $CD, $A6, $7C, $FA, $8B, $04, $E5, $06, $03, $8C, $5D, $18, $22,
$84, $04, $39, $7F, $45, $F6, $B7, $8F, $CC, $DE, $F0, $6E, $97, $BB, $56, $CE,
$7D, $1A, $51, $9E, $AD, $A3, $96, $2E, $CE, $0E, $AB, $36, $31, $EE, $CE, $B4,
$89, $F2, $27, $8D, $DB, $F3, $70, $12, $C9, $12, $B2, $4E, $D5, $D5, $C0, $86,
$39, $A5, $DE, $E2, $8C, $4F, $F8, $18, $09, $83, $F2, $E6, $DD, $6C, $FA, $88,
$04, $60, $0C, $97, $D8, $6B, $9A, $3A, $2D, $B1, $A9, $6B, $8F, $C3, $DC, $92,
$C4, $B6, $F3, $50, $FD, $2B, $CA, $4B, $06, $21, $1D, $C1, $E8, $90, $B3, $E3,
$3F, $D6, $17, $88, $D1, $AA, $67, $82, $9C, $5F, $A4, $63, $74, $0C, $21, $C0,
$21, $06, $D9, $2D, $9B, $B9, $97, $81, $4F, $A4, $0B, $9B, $D4, $85, $88, $2D,
$0C, $84, $B9, $3C, $1B, $2F, $AA, $87, $AE, $0F, $01, $D3, $7F, $BA, $40, $24,
$CE, $AB, $C8, $B7, $87, $13, $2B, $58, $40, $1B, $59, $F1, $A7, $22, $CF, $2D,
$C1, $E4, $84, $A9, $8A, $EC, $25, $15, $38, $29, $E7, $65, $72, $09, $7B, $8C,
$AC, $0A, $86, $FE, $CB, $DB, $C0, $F4, $CB, $DD, $B3, $6A, $94, $57, $12, $BB,
$11, $9D, $4D, $C6, $E6, $04, $CC, $CD, $C9, $27, $FF, $B3, $56, $36, $60, $60,
$46, $B7, $D6, $02, $09, $EB, $3F, $80, $F3, $7E, $70, $02, $B4, $B5, $4C, $E4,
$F2, $A9, $6C, $46, $32, $07, $01, $0C, $BC, $CA, $54, $49, $19, $75, $C2, $DE,
$99, $C9, $C9, $97, $FE, $19, $3D, $B1, $4D, $55, $31, $87, $75, $F4, $86, $1D,
$AC, $8D, $00, $CD, $92, $6C, $A7, $42, $4E, $24, $0D, $D7, $34, $DB, $16, $81,
$FD, $91, $9C, $0D, $B4, $16, $F5, $64, $5D, $D7, $C0, $39, $03, $3E, $BE, $E8,
$99, $44, $DB, $95, $A9, $61, $78, $09, $27, $A0, $C2, $9D, $94, $12, $0D, $01,
$A4, $57, $C2, $6A, $5E, $D2, $E5, $C0, $B1, $E8, $B6, $64, $9C, $75, $97, $83,
$99, $F1, $C2, $07, $9E, $5C, $2E, $8A, $C8, $D9, $55, $71, $B1, $B5, $27, $9A,
$C7, $DE, $E5, $B1, $34, $71, $99, $D1, $4D, $EC, $02, $32, $5F, $E4, $CE, $08,
$FC, $74, $36, $5B, $0F, $55, $02, $1A, $7A, $F4, $14, $35, $D1, $F1, $10, $73,
$D5, $29, $FA, $03, $4F, $BB, $B9, $C2, $61, $53, $7D, $76, $6D, $CC, $73, $C6,
$68, $4B, $75, $1C, $D6, $6C, $EE, $93, $6C, $49, $EF, $EE, $73, $F1, $FC, $2C,
$BC, $EF, $7F, $73, $CB, $BD, $CE, $1E, $11, $90, $5E, $7E, $72, $E7, $E4, $1F,
$48, $59, $D8, $FE, $68, $16, $02, $BC, $3F, $9A, $E0, $5B, $2B, $CF, $42, $F0,
$15, $45, $A8, $F5, $D4, $79, $92, $D9, $A7, $8C, $62, $1C, $D9, $E3, $14, $E2,
$DA, $2F, $61, $5E, $CD, $47, $48, $06, $9A, $B1, $1A, $A6, $18, $E5, $C6, $4C,
$34, $0D, $17, $08, $AA, $A6, $1B, $DA, $94, $CB, $23, $1B, $C3, $58, $5E, $9E,
$21, $5F, $2B, $1B, $60, $41, $DB, $7C, $E0, $02, $EA, $A9, $84, $86, $A2, $CB,
$E6, $61, $95, $06, $29, $FC, $F6, $5A, $9B, $B0, $61, $D5, $90, $C8, $64, $8C,
$0C, $0D, $83, $D7, $B2, $AE, $F9, $2B, $E4, $AE, $DD, $05, $65, $3A, $72, $EB,
$39, $49, $DD, $8D, $A0, $90, $34, $04, $71, $17, $76, $38, $84, $DD, $32, $72,
$AD, $11, $C3, $F0, $55, $23, $AE, $FC, $C5, $47, $34, $E2, $C7, $51, $D4, $ED,
$8F, $7C, $2E, $8C, $16, $BD, $F9, $4E, $A7, $8B, $D6, $C2, $10, $17, $78, $0C,
$42, $F4, $98, $F9, $F8, $40, $AA, $BE, $29, $2B, $22, $D8, $CB, $97, $40, $2B,
$32, $AC, $46, $08, $51, $EB, $34, $90, $ED, $E1, $9E, $90, $B4, $E9, $B7, $EC,
$88, $62, $47, $F4, $1C, $B8, $80, $13, $7B, $51, $34, $E9, $7E, $D2, $2E, $37,
$7B, $EB, $46, $5E, $72, $A9, $F7, $03, $7B, $2B, $F8, $C5, $CD, $A0, $A7, $8F,
$18, $27, $6C, $16, $28, $6B, $60, $51, $5B, $A3, $7C, $CA, $A5, $76, $2B, $78,
$3D, $01, $51, $1F, $E3, $F1, $8D, $07, $CA, $6D, $C7, $85, $DE, $AA, $57, $B8,
$AF, $A6, $C1, $03, $BD, $2C, $07, $FE, $C6, $5C, $3B, $17, $60, $77, $8B, $6C,
$5B, $97, $D7, $2F, $54, $3E, $F5, $12, $D3, $C4, $AB, $AB, $B6, $57, $54, $92,
$95, $5A, $C5, $22, $CF, $FF, $EA, $FD, $76, $56, $FF, $E4, $C8, $4A, $B1, $6C,
$7A, $15, $61, $19, $4C, $89, $97, $6C, $AB, $68, $E8, $86, $EB, $FA, $48, $9E,
$69, $BC, $E7, $FD, $94, $9A, $CA, $68, $6D, $2D, $65, $B6, $46, $D5, $D3, $B8,
$72, $87, $54, $43, $C8, $75, $9D, $2E, $86, $87, $A2, $07, $7A, $68, $38, $63,
$27, $AC, $CD, $8B, $02, $F5, $32, $2D, $3E, $A3, $78, $16, $31, $AC, $67, $E1,
$24, $A8, $7C, $C8, $33, $65, $57, $E7, $D3, $70, $E9, $13, $A0, $C3, $BC, $48,
$56, $65, $56, $83, $6F, $03, $D4, $30, $D9, $A6, $77, $F6, $58, $12, $EA, $21,
$64, $75, $97, $02, $C4, $1A, $16, $27, $B3, $A4, $19, $3D, $3F, $15, $95, $F6,
$D5, $F0, $15, $0B, $A2, $DE, $51, $7A, $B9, $F6, $1D, $2C, $F9, $61, $DD, $30,
$86, $C5, $85, $C1, $B8, $91, $43, $C7, $7E, $7B, $7D, $31, $F9, $31, $FA, $00,
$A3, $38, $10, $43, $21, $A3, $D1, $1B, $02, $61, $38, $01, $D3, $98, $45, $C1,
$D4, $5D, $EB, $CA, $E6, $01, $6B, $63, $DF, $92, $55, $0A, $73, $1F, $B1, $A0,
$1F, $53, $6A, $02, $05, $59, $D2, $3C, $18, $AA, $95, $1F, $E3, $AE, $41, $0A,
$3A, $CD, $1C, $3B, $8B, $46, $03, $BF, $A7, $B2, $4F, $89, $98, $5B, $8E, $36,
$8A, $3C, $D1, $93, $DE, $DF, $32, $CC, $A3, $12, $F4, $19, $BA, $0A, $64, $15,
$27, $BA, $85, $FB, $2B, $1F, $B1, $4C, $8E, $B8, $4A, $F1, $CC, $91, $95, $AC,
$B6, $76, $19, $9E, $18, $1C, $2B, $9F, $B6, $33, $09, $68, $03, $22, $78, $BA,
$C5, $B8, $B6, $8D, $C5, $42, $63, $FD, $D0, $E0, $6F, $17, $F0, $DA, $C9, $08,
$CA, $16, $3E, $21, $C0, $AE, $5E, $24, $04, $39, $80, $1C, $61, $3B, $93, $A5,
$F5, $3B, $11, $D4, $88, $B8, $E8, $64, $DF, $B2, $7F, $69, $A4, $DC, $34, $3B,
$95, $D6, $10, $E2, $31, $37, $3B, $29, $14, $5D, $59, $71, $33, $95, $33, $8F,
$10, $71, $4F, $8A, $3F, $A4, $A6, $A1, $B1, $5E, $56, $BA, $04, $F8, $42, $50,
$89, $00, $88, $BF, $3F, $83, $F0, $6C, $35, $97, $FE, $61, $8C, $D0, $39, $BA,
$94, $6E, $69, $0C, $1B, $B9, $7F, $44, $60, $ED, $DE, $F3, $6A, $32, $DE, $DA,
$A0, $C1, $29, $57, $3D, $9F, $57, $C5, $4D, $18, $55, $B3, $4D, $97, $0B, $F8,
$A7, $2D, $0D, $D0, $CF, $F1, $61, $92, $A5, $91, $E5, $49, $4D, $94, $50, $A0,
$A2, $FD, $D6, $1A, $F3, $8E, $AA, $97, $E8, $41, $E1, $55, $DA, $17, $C9, $7E,
$B9, $06, $56, $19, $B2, $1E, $7E, $B3, $B9, $B8, $41, $A9, $29, $AC, $B1, $BF,
$86, $78, $60, $46, $9A, $DB, $96, $19, $67, $5D, $21, $88, $93, $DE, $15, $03,
$7F, $9B, $A9, $12, $53, $E1, $51, $31, $41, $D1, $CD, $71, $39, $E9, $4D, $BA,
$98, $1E, $D5, $6B, $E2, $5F, $B3, $29, $28, $50, $86, $89, $3B, $F6, $D1, $6F,
$C3, $EE, $91, $9A, $0D, $0D, $B5, $92, $2F, $52, $69, $B4, $B0, $A8, $8A, $79,
$84, $A9, $6C, $B5, $03, $C4, $0F, $71, $EA, $1C, $0D, $93, $45, $95, $61, $EA,
$F7, $6E, $A6, $F0, $B5, $B2, $0C, $07, $4C, $B8, $07, $27, $AE, $F0, $6E, $04,
$13, $3B, $12, $F7, $AC, $34, $33, $C2, $D5, $7C, $81, $7D, $AC, $EE, $D0, $8B,
$69, $9C, $66, $4A, $1A, $D6, $9B, $C5, $D2, $9F, $FF, $4A, $6B, $B0, $4B, $C4,
$49, $27, $E5, $F7, $41, $C5, $34, $75, $C8, $25, $F4, $B5, $BE, $7F, $FD, $CB,
$2D, $D7, $CC, $54, $E7, $74, $55, $D2, $F5, $76, $5C, $4A, $A6, $C4, $92, $E7,
$96, $8B, $59, $EE, $88, $0D, $18, $C6, $FA, $5F, $28, $F8, $62, $71, $C4, $85,
$0B, $D9, $25, $97, $C8, $36, $7A, $5A, $1E, $65, $5D, $80, $27, $1D, $4B, $7A,
$2B, $72, $B2, $5D, $AD, $E6, $DE, $E8, $8D, $F6, $DE, $9A, $08, $7F, $17, $B7,
$13, $E3, $AF, $3E, $0B, $0D, $99, $F3, $5D, $07, $1A, $27, $20, $24, $53, $BD,
$84, $BF, $61, $40, $78, $BF, $F4, $D2, $0D, $C5, $2A, $06, $60, $B9, $07, $EF,
$8E, $AF, $D7, $E9, $4F, $11, $E1, $B8, $DD, $59, $93, $9E, $95, $DD, $16, $93,
$D7, $F6, $9C, $AF, $48, $A6, $C6, $3E, $77, $54, $F8, $3D, $08, $BB, $76, $98,
$ED, $B6, $EF, $D2, $4F, $E4, $4F, $EA, $3B, $96, $0A, $C3, $68, $29, $44, $BA,
$C5, $3F, $36, $9D, $D2, $D2, $ED, $86, $2E, $26, $61, $3F, $05, $20, $82, $AA,
$68, $A1, $8A, $57, $BE, $5A, $90, $A4, $A0, $1D, $B8, $A8, $FB, $E2, $27, $08,
$E1, $9C, $A4, $70, $FE, $B9, $23, $7C, $29, $C3, $65, $D4, $38, $04, $AF, $2B,
$3E, $31, $3A, $F9, $1E, $8A, $D3, $EC, $5A, $D6, $73, $C8, $C8, $DD, $79, $01,
$3E, $59, $46, $CE, $00, $CB, $62, $2F, $01, $17, $8D, $34, $11, $F0, $52, $AD,
$11, $B0, $59, $7A, $51, $57, $EF, $E4, $C9, $B7, $27, $D3, $60, $DE, $05, $CF,
$28, $73, $DD, $0A, $B3, $E7, $F5, $DB, $B1, $B6, $B5, $35, $B1, $FA, $F0, $74,
$B9, $DF, $1B, $3A, $E0, $E3, $3E, $4D, $78, $EA, $0A, $94, $FD, $A7, $0C, $EC,
$25, $88, $3C, $49, $20, $50, $7D, $21, $04, $8C, $9D, $0B, $B8, $1A, $51, $D8,
$59, $7A, $14, $5D, $3A, $04, $3E, $B7, $27, $ED, $5A, $C3, $29, $85, $86, $50,
$D1, $76, $0C, $26, $C6, $0D, $0F, $D3, $CE, $8C, $E8, $ED, $B3, $1B, $FB, $26,
$4D, $4F, $B9, $EE, $87, $4D, $01, $69, $B1, $58, $8E, $E1, $CC, $9A, $14, $B5,
$C3, $D3, $DA, $FD, $1F, $32, $12, $33, $12, $71, $46, $79, $96, $4D, $54, $17,
$E6, $69, $13, $6B, $D6, $34, $16, $B5, $D8, $4C, $26, $62, $0D, $19, $B3, $BC,
$65, $C2, $FB, $40, $1E, $AB, $2D, $CD, $61, $FF, $C1, $C5, $72, $59, $41, $29,
$12, $C1, $E7, $37, $ED, $43, $67, $C6, $05, $11, $72, $15, $05, $CD, $F6, $9A,
$4D, $BE, $8F, $5A, $EB, $BD, $29, $CC, $F5, $20, $97, $BB, $06, $50, $35, $1A,
$C9, $05, $9C, $49, $38, $73, $C7, $31, $75, $3A, $CE, $F3, $C8, $E2, $11, $7F,
$2F, $EB, $9F, $C7, $81, $29, $D3, $94, $35, $C2, $18, $1B, $FB, $50, $8E, $F5,
$32, $57, $FB, $BD, $92, $85, $16, $CE, $08, $C4, $EB, $13, $C2, $E4, $52, $B4,
$1E, $FF, $7F, $98, $09, $46, $47, $A1, $63, $1E, $63, $9A, $44, $0C, $64, $AC,
$0C, $72, $36, $13, $35, $4F, $D8, $3E, $C7, $72, $4D, $63, $78, $2D, $D3, $4F,
$CC, $9A, $66, $D1, $0E, $AA, $BD, $29, $CA, $F8, $04, $A2, $C4, $BD, $74, $D9,
$87, $CA, $96, $77, $F8, $3D, $A7, $6F, $ED, $E0, $89, $0F, $18, $C5, $6F, $BF,
$60, $56, $5C, $74, $81, $42, $C2, $88, $5B, $8F, $52, $5A, $B7, $10, $A3, $85,
$C6, $77, $3B, $07, $42, $2D, $7C, $33, $F8, $73, $20, $90, $6E, $7A, $2E, $C8,
$26, $87, $DD, $25, $27, $47, $38, $E0, $5A, $38, $1E, $83, $E9, $24, $CD, $8C,
$AD, $98, $19, $E4, $E5, $1F, $2B, $4D, $EB, $25, $B9, $BF, $7F, $80, $18, $3D,
$14, $BF, $6A, $AA, $92, $2F, $F7, $38, $AF, $47, $8B, $30, $66, $B3, $E9, $D5,
$E2, $5A, $61, $59, $2C, $DB, $CF, $F7, $95, $09, $C7, $09, $64, $4F, $61, $CC,
$61, $67, $72, $21, $B4, $B7, $37, $68, $55, $14, $5B, $8F, $F4, $75, $5A, $AB,
$3D, $AA, $52, $CA, $10, $D9, $AB, $BD, $25, $36, $D1, $3C, $EB, $89, $74, $93,
$72, $B6, $01, $C8, $EA, $EB, $38, $D3, $6B, $B7, $C0, $F8, $13, $96, $74, $DE,
$AC, $F9, $6E, $73, $20, $B7, $95, $01, $1E, $ED, $E1, $FB, $90, $A9, $10, $48,
$33, $E8, $0E, $10, $14, $AA, $66, $8B, $B8, $7D, $ED, $0E, $BE, $C5, $F2, $95,
$82, $64, $F1, $C6, $96, $B7, $BC, $6F, $54, $27, $24, $BD, $D8, $E2, $34, $60,
$66, $1A, $F3, $A1, $69, $6F, $2C, $C9, $2A, $F5, $6B, $7F, $47, $74, $BE, $24,
$B4, $F0, $2C, $BF, $B1, $BA, $05, $BA, $61, $EF, $E9, $FD, $70, $58, $F4, $54,
$26, $CA, $B6, $A9, $D3, $D3, $5A, $3C, $59, $A3, $CF, $9D, $FB, $44, $E7, $B1,
$17, $3F, $D7, $6E, $4E, $DC, $9F, $F9, $09, $7E, $27, $4C, $4A, $2B, $28, $83,
$33, $56, $70, $9D, $65, $1C, $CA, $AC, $2A, $92, $3F, $0B, $B8, $C2, $43, $12,
$34, $CC, $C8, $CE, $23, $7D, $0F, $31, $28, $85, $BD, $15, $17, $3F, $C3, $27,
$84, $54, $83, $D5, $8F, $4F, $30, $0F, $AD, $43, $72, $9D, $51, $8E, $CC, $3D,
$CD, $95, $72, $5D, $00, $DA, $2F, $2C, $EE, $30, $A6, $8A, $DF, $D4, $AF, $09,
$75, $DA, $C2, $15, $30, $CD, $45, $06, $A5, $E3, $3C, $C6, $32, $2F, $34, $59,
$6C, $83, $8E, $BC, $15, $B0, $5E, $84, $F9, $9E, $16, $55, $01, $D0, $83, $DD,
$10, $26, $1B, $43, $26, $16, $91, $9A, $80, $8A, $86, $C7, $57, $74, $56, $69,
$1E, $99, $78, $C1, $B0, $FD, $E1, $28, $72, $9F, $CD, $B3, $DE, $EF, $E1, $72,
$5D, $4F, $0E, $05, $E3, $98, $6A, $17, $B0, $D5, $DB, $EB, $C0, $ED, $5C, $C0,
$9E, $1F, $29, $C0, $18, $DE, $90, $D7, $52, $62, $07, $D0, $61, $80, $78, $6E,
$44, $53, $50, $BE, $D5, $71, $DF, $8E, $1A, $E8, $E4, $59, $56, $D3, $43, $4D,
$7C, $31, $A7, $05, $A6, $38, $22, $20, $DC, $32, $46, $07, $2A, $1C, $EF, $7F,
$8B, $9B, $49, $9B, $B9, $5C, $C2, $EE, $60, $04, $82, $29, $A3, $7E, $6E, $DD,
$35, $48, $C3, $A8, $18, $3F, $25, $E3, $2F, $72, $C1, $07, $03, $FE, $F0, $10,
$CC, $06, $11, $7C, $AB, $9A, $26, $A7, $9F, $36, $A0, $FB, $94, $24, $40, $3C,
$2E, $7B, $44, $4B, $3A, $CA, $E4, $F4, $97, $5D, $C1, $A6, $50, $77, $0C, $7F,
$36, $75, $A0, $33, $C6, $6C, $41, $BF, $FB, $B5, $48, $53, $87, $B4, $D3, $E4,
$41, $F0, $51, $3C, $5C, $6F, $E1, $BB, $9D, $E4, $DF, $03, $81, $91, $3F, $AE,
$93, $C7, $85, $2E, $B8, $74, $82, $E8, $82, $7C, $EB, $2A, $A9, $06, $B2, $A5,
$B7, $6C, $3B, $7A, $B2, $1F, $B7, $6F, $E0, $72, $3F, $97, $3E, $22, $12, $DA,
$81, $13, $F0, $1E, $3D, $FE, $27, $08, $E4, $5C, $6B, $F0, $BA, $74, $93, $39,
$90, $D0, $CA, $A2, $14, $24, $77, $60, $77, $8F, $2B, $45, $35, $D6, $A5, $BE,
$8F, $B6, $16, $22, $A3, $71, $77, $B0, $EA, $CB, $6A, $79, $75, $75, $85, $EB,
$5F, $E4, $3C, $E1, $68, $75, $47, $06, $72, $AF, $1A, $6F, $70, $57, $B1, $3C,
$FA, $44, $19, $19, $18, $D6, $31, $CA, $10, $41, $13, $11, $D5, $B8, $EA, $C4,
$CB, $94, $B9, $CD, $5D, $FD, $A7, $21, $6F, $1B, $8E, $A6, $77, $7C, $52, $44,
$4F, $72, $8B, $E4, $C5, $C9, $A9, $3D, $65, $6C, $AE, $1C, $C1, $E7, $9B, $80,
$94, $A9, $D5, $04, $83, $EB, $6A, $62, $EB, $EB, $2B, $8A, $6A, $AC, $D1, $BA,
$58, $98, $CE, $FE, $5B, $71, $CB, $60, $EE, $A4, $EB, $7B, $E8, $29, $4C, $F4,
$E8, $9E, $91, $8D, $E6, $4D, $4C, $32, $31, $79, $B2, $B3, $64, $AA, $4C, $71,
$6B, $D4, $AA, $BA, $D7, $B5, $0C, $87, $16, $3D, $6B, $6B, $8D, $84, $49, $E1,
$3C, $11, $28, $ED, $5B, $65, $C1, $FC, $8E, $A4, $02, $75, $7E, $18, $02, $B4,
$5B, $C4, $D1, $0C, $F1, $CD, $07, $BD, $17, $65, $72, $0A, $EC, $B5, $14, $13,
$2F, $F6, $F4, $16, $29, $E9, $4F, $6F, $1E, $B3, $77, $AE, $0E, $6D, $1C, $5B,
$FD, $22, $17, $C1, $75, $50, $FC, $D9, $A4, $9A, $C9, $39, $8B, $EB, $47, $CA,
$19, $F7, $8B, $73, $AB, $12, $DC, $70, $8E, $94, $22, $CE, $32, $7F, $2A, $56,
$80, $E9, $4C, $B4, $BB, $1F, $D6, $6B, $4A, $59, $CA, $4B, $43, $B1, $D1, $C8,
$D6, $B8, $3B, $41, $E7, $8E, $48, $3E, $D5, $AA, $BC, $85, $69, $54, $62, $D2,
$CF, $83, $1D, $A5, $4C, $EF, $1E, $E5, $2B, $09, $ED, $F7, $39, $62, $9F, $57,
$15, $B4, $6C, $E9, $E9, $F4, $CF, $A3, $AB, $3F, $D4, $67, $E6, $A1, $31, $63,
$33, $C2, $4D, $B1, $2D, $E7, $80, $A4, $31, $05, $4E, $6C, $1C, $13, $D8, $39,
$35, $AC, $BF, $1E, $EA, $8E, $03, $83, $1C, $E2, $C3, $3A, $DC, $14, $0B, $03,
$3E, $75, $23, $8C, $EE, $1C, $89, $CD, $03, $61, $2F, $0B, $02, $F7, $95, $E7,
$93, $52, $84, $1E, $57, $B7, $9C, $45, $DF, $C6, $62, $AE, $DB, $42, $77, $9A,
$6E, $77, $F7, $B4, $65, $22, $85, $FA, $C9, $19, $AD, $3B, $8F, $9C, $30, $17,
$8D, $21, $78, $74, $30, $90, $A6, $86, $13, $AA, $36, $7C, $1B, $D7, $02, $17,
$15, $EB, $48, $F5, $04, $D8, $96, $23, $21, $62, $6A, $C9, $2C, $0A, $B6, $55,
$92, $0F, $9C, $D6, $E0, $8D, $F9, $84, $26, $64, $E2, $D9, $3F, $36, $BC, $B7,
$D8, $78, $8E, $EA, $ED, $92, $A1, $D2, $60, $24, $EE, $E8, $CF, $FE, $B7, $42,
$50, $FF, $65, $8F, $2A, $2C, $98, $C5, $91, $D3, $B5, $65, $B8, $1F, $C1, $20,
$01, $AB, $E4, $75, $52, $83, $45, $CC, $88, $B2, $79, $84, $CC, $A3, $2C, $A5,
$14, $F0, $7A, $4A, $FA, $BF, $F5, $F1, $9D, $9B, $7C, $15, $FF, $36, $86, $50,
$0D, $C6, $83, $16, $58, $93, $2A, $A9, $2A, $A7, $5E, $4B, $0D, $68, $F4, $D3,
$B3, $6E, $21, $AA, $86, $E2, $45, $3D, $F5, $B8, $26, $07, $66, $F3, $D8, $BC,
$EA, $F7, $74, $48, $50, $BC, $AD, $72, $C5, $FE, $31, $8A, $58, $14, $6C, $63,
$FA, $FB, $FA, $91, $E6, $AC, $56, $D8, $DD, $19, $26, $2E, $A8, $4B, $53, $69,
$49, $9C, $10, $DD, $E3, $AF, $65, $A7, $A9, $34, $28, $4D, $09, $4C, $B3, $4E,
$C3, $2F, $47, $C8, $EA, $69, $02, $DA, $B0, $7A, $97, $A1, $3A, $4F, $93, $74,
$9E, $2B, $A2, $0C, $12, $33, $AC, $A1, $0C, $78, $65, $7B, $C7, $19, $F9, $F3,
$D4, $57, $84, $F0, $16, $0B, $43, $93, $B3, $62, $54, $2E, $4E, $35, $56, $03,
$E1, $96, $02, $AB, $CA, $40, $1F, $6A, $7F, $0F, $EB, $E7, $58, $52, $96, $50,
$FE, $0C, $0D, $77, $28, $F6, $84, $DA, $04, $D6, $43, $0D, $9D, $E8, $3E, $C1,
$57, $29, $7D, $C8, $88, $FA, $8E, $A0, $AD, $D1, $D2, $D9, $35, $69, $46, $BB,
$CE, $DB, $4E, $D5, $59, $E5, $FF, $A1, $7D, $DF, $F2, $DE, $89, $04, $96, $F8,
$DB, $9C, $45, $C2, $B6, $8E, $7C, $6F, $D3, $CB, $8C, $66, $2A, $CA, $50, $2C,
$56, $42, $95, $68, $1D, $7E, $31, $4C, $90, $BA, $6C, $25, $36, $5C, $6F, $D4,
$06, $77, $9A, $6A, $51, $40, $46, $8C, $D5, $8A, $32, $E6, $6E, $E3, $B2, $DB,
$B8, $2E, $0B, $BE, $A2, $DA, $C7, $8A, $3F, $85, $C2, $24, $FB, $19, $90, $5C,
$4A, $54, $DE, $01, $38, $55, $4B, $39, $DA, $50, $13, $89, $A2, $98, $FD, $D0,
$8D, $71, $74, $85, $AA, $00, $B3, $BB, $B6, $94, $80, $56, $F2, $08, $DB, $71,
$C0, $DB, $39, $6F, $49, $D7, $DC, $EA, $13, $6B, $83, $49, $4C, $35, $93, $BF,
$66, $7A, $B0, $10, $BF, $75, $4A, $74, $0B, $5B, $A5, $37, $02, $B5, $32, $B5,
$04, $19, $7B, $35, $41, $FC, $07, $36, $DA, $9E, $93, $60, $8F, $CB, $1F, $25,
$14, $2A, $85, $E4, $0C, $02, $B4, $A2, $0A, $DB, $77, $8B, $A5, $E3, $8E, $46,
$F3, $04, $B5, $C5, $F2, $89, $43, $D2, $89, $E2, $D7, $AE, $80, $2B, $F2, $E2,
$3E, $C8, $39, $37, $7E, $04, $D3, $57, $82, $62, $49, $0C, $2F, $33, $54, $C5,
$FC, $47, $5F, $8A, $EF, $D1, $13, $F1, $15, $C6, $65, $DB, $7C, $7A, $6F, $73,
$83, $F4, $29, $E2, $54, $05, $77, $3F, $8C, $8C, $DE, $93, $4A, $59, $B7, $38,
$E3, $93, $DE, $A3, $C6, $4E, $90, $06, $D8, $6F, $AD, $14, $D3, $F9, $E6, $42,
$5C, $68, $81, $ED, $D9, $8B, $74, $CD, $4A, $C8, $56, $2E, $84, $86, $57, $FD,
$6C, $5E, $DA, $7C, $51, $CF, $37, $65, $79, $38, $84, $CA, $76, $E0, $BA, $C1,
$2F, $52, $A2, $6B, $5D, $4F, $79, $1E, $68, $CF, $7F, $2B, $5D, $3C, $F6, $B8,
$72, $E9, $8F, $6B, $4A, $8D, $55, $4C, $38, $F8, $C7, $0E, $6E, $5B, $D8, $06,
$F4, $C1, $45, $3B, $4E, $AD, $09, $EF, $73, $88, $6F, $9A, $A5, $2F, $75, $D4,
$CC, $EF, $76, $05, $7D, $F8, $CA, $B2, $35, $4D, $9A, $CF, $3A, $3A, $87, $97,
$71, $03, $F2, $9C, $29, $F1, $37, $DA, $4C, $96, $E6, $9A, $90, $3C, $AB, $FC,
$FD, $9E, $83, $96, $F4, $77, $BA, $6C, $19, $D9, $72, $A2, $8F, $0E, $F4, $BB,
$B4, $20, $C9, $AD, $D2, $92, $A5, $65, $4D, $E5, $12, $3B, $25, $12, $52, $2C,
$E9, $EE, $08, $47, $55, $AA, $F3, $C0, $66, $BF, $D1, $2C, $79, $CD, $B8, $49,
$5A, $C6, $B7, $B8, $DA, $FA, $E1, $F2, $EB, $A9, $BE, $E3, $C5, $38, $9C, $36,
$13, $87, $48, $0E, $E5, $2A, $CD, $A0, $3D, $81, $F5, $30, $30, $FC, $3F, $88,
$DD, $25, $22, $DF, $02, $87, $DC, $B6, $40, $8D, $7D, $91, $24, $3B, $53, $4E,
$36, $14, $33, $B4, $93, $CA, $AB, $F1, $F3, $E8, $F7, $EC, $BB, $FA, $57, $50,
$25, $BC, $FF, $A3, $EA, $29, $C2, $82, $B1, $3E, $CD, $4E, $F5, $59, $C9, $EA,
$9D, $80, $F7, $E4, $30, $78, $3E, $3C, $91, $F7, $53, $A3, $67, $57, $A1, $0A,
$7A, $4A, $4D, $25, $58, $D5, $22, $4A, $98, $D3, $F6, $B1, $22, $98, $22, $0A,
$C5, $48, $54, $37, $02, $F8, $6D, $25, $90, $C3, $A6, $D1, $40, $53, $7A, $A4,
$53, $5E, $08, $8D, $F9, $9B, $15, $FC, $30, $7F, $4A, $86, $27, $7F, $E5, $8B,
$6E, $06, $C8, $6E, $A1, $22, $8D, $DA, $CE, $9A, $90, $41, $9C, $8E, $63, $22,
$17, $F1, $FC, $3D, $42, $68, $73, $1A, $1B, $CE, $BD, $51, $49, $E6, $D5, $DA,
$7D, $BA, $FF, $83, $18, $98, $3B, $F0, $B9, $19, $1B, $CC, $64, $DE, $9B, $8B,
$79, $0A, $77, $45, $64, $2A, $F7, $96, $9B, $E2, $66, $D4, $C0, $2B, $B9, $B8,
$A3, $C9, $65, $5C, $E5, $58, $61, $5A, $3E, $4A, $10, $4F, $66, $32, $C6, $8A,
$80, $86, $88, $BC, $58, $24, $80, $33, $E7, $E4, $DB, $7D, $29, $D3, $A5, $CB,
$C4, $99, $18, $92, $71, $20, $A4, $B6, $BB, $E2, $F5, $66, $AB, $D6, $0F, $4E,
$3A, $29, $31, $EA, $E4, $F3, $F3, $75, $7B, $36, $67, $CC, $67, $87, $A8, $E5,
$0D, $E4, $A3, $E5, $4B, $E3, $98, $18, $43, $2E, $DF, $C7, $27, $19, $BE, $67,
$DB, $B6, $54, $0D, $B4, $E1, $6A, $DE, $3E, $94, $55, $AB, $38, $67, $E5, $2E,
$26, $7E, $8D, $39, $C5, $2A, $CA, $CA, $0C, $D4, $FE, $1B, $F5, $57, $6F, $03,
$27, $6C, $E4, $C1, $FF, $73, $56, $24, $EA, $7D, $54, $FC, $E6, $79, $69, $68,
$B5, $01, $2F, $E3, $31, $47, $D0, $1D, $96, $2B, $31, $AB, $43, $19, $19, $81,
$31, $8D, $57, $E4, $BD, $83, $F0, $CC, $31, $3E, $C8, $22, $A4, $B8, $D9, $2E,
$B3, $1F, $7B, $2A, $69, $34, $C4, $A6, $40, $AA, $CA, $72, $A8, $DD, $62, $28,
$D4, $2E, $3A, $FB, $AE, $C8, $65, $A5, $F7, $F8, $6B, $0D, $44, $C7, $33, $41,
$A1, $06, $AC, $30, $D0, $94, $99, $33, $EB, $90, $F1, $0B, $96, $92, $A3, $5B,
$94, $51, $A8, $CB, $BD, $D3, $AE, $61, $6F, $CE, $80, $8E, $A3, $BF, $F8, $B0,
$72, $67, $19, $03, $21, $AD, $1F, $6A, $0E, $4D, $2E, $52, $20, $17, $D1, $FB,
$74, $93, $F9, $B7, $AA, $ED, $E7, $67, $AD, $43, $EA, $EB, $B9, $7C, $E8, $87,
$2C, $61, $C0, $69, $3C, $94, $2F, $8B, $1F, $24, $C9, $22, $A3, $6D, $1A, $92,
$21, $E4, $94, $0F, $6F, $95, $6C, $CF, $C9, $C3, $CF, $AD, $A4, $FA, $1A, $53,
$04, $92, $2E, $3D, $43, $BC, $67, $A3, $D7, $5D, $95, $01, $4D, $FC, $26, $BD,
$41, $EA, $A5, $47, $EC, $B4, $EE, $9A, $C2, $2E, $5F, $B8, $4B, $34, $DC, $FD,
$67, $14, $C4, $09, $E1, $16, $FF, $D0, $32, $D7, $24, $69, $ED, $36, $D1, $2A,
$5B, $00, $3A, $CD, $55, $50, $47, $DD, $E2, $FC, $EA, $7B, $CF, $8D, $A0, $34,
$73, $65, $44, $EA, $17, $CF, $C2, $FE, $B2, $55, $60, $D9, $71, $89, $84, $76,
$2B, $2E, $C6, $38, $CC, $45, $B4, $F2, $F0, $6B, $28, $38, $F2, $7E, $BB, $B9,
$F1, $9A, $BD, $45, $28, $FC, $D1, $22, $48, $7D, $91, $69, $5A, $42, $04, $78,
$C0, $B7, $E7, $01, $0E, $76, $9B, $1C, $4A, $1D, $FA, $FC, $4C, $C6, $61, $45,
$3C, $4B, $30, $97, $9D, $1A, $02, $55, $93, $F4, $BF, $C7, $CD, $2F, $F3, $FA,
$60, $B7, $A8, $D6, $88, $A2, $10, $42, $61, $B8, $60, $02, $EC, $4C, $B6, $B9,
$B5, $B8, $FC, $78, $D4, $58, $19, $FE, $6A, $07, $CE, $CC, $8C, $82, $26, $03,
$F3, $7E, $25, $54, $9D, $0D, $A4, $F4, $12, $13, $78, $25, $B7, $1C, $E3, $06,
$95, $EF, $AD, $84, $A3, $1B, $7A, $08, $A4, $B4, $74, $44, $0B, $21, $32, $47,
$FA, $4C, $3D, $9A, $36, $17, $98, $3F, $A0, $AA, $A4, $46, $F9, $8F, $35, $F5,
$4C, $50, $E7, $FD, $4C, $F9, $2D, $DB, $86, $2C, $EE, $81, $66, $F1, $15, $04,
$BF, $10, $1C, $8C, $A9, $A3, $BC, $8F, $2D, $94, $51, $1B, $84, $3C, $FA, $86,
$25, $B4, $01, $E3, $99, $47, $82, $36, $C8, $36, $1D, $8A, $CD, $F2, $FE, $1B,
$15, $95, $F7, $47, $CD, $5E, $F9, $7A, $7D, $BD, $F8, $EB, $D6, $8A, $C9, $BB,
$1B, $32, $87, $E8, $41, $46, $5F, $C3, $7F, $A8, $DC, $39, $38, $05, $14, $1B,
$D9, $97, $DF, $F8, $BF, $F1, $2B, $45, $76, $0F, $F0, $BE, $23, $5E, $45, $8A,
$F9, $9B, $10, $4B, $D3, $61, $06, $02, $5B, $B3, $E8, $FA, $08, $B1, $A4, $B0,
$96, $7F, $A0, $95, $23, $12, $40, $87, $DC, $AE, $BE, $63, $0D, $09, $43, $32,
$96, $47, $A0, $76, $FF, $CF, $D6, $FB, $B7, $8A, $3F, $3F, $F9, $0F, $C3, $A8,
$9F, $BE, $C9, $61, $11, $74, $06, $D2, $BB, $F6, $B3, $D7, $A9, $E7, $BE, $35,
$B6, $68, $3F, $4B, $8F, $92, $27, $B2, $9E, $E9, $F6, $71, $47, $25, $09, $92,
$B0, $E1, $27, $C7, $93, $85, $7B, $EC, $CB, $42, $1C, $11, $1C, $7B, $7F, $4B,
$54, $35, $73, $83, $58, $BC, $84, $B1, $6F, $EE, $C5, $57, $4F, $DD, $81, $0B,
$7A, $58, $6B, $E1, $C1, $00, $D4, $24, $A5, $C2, $0E, $65, $8E, $87, $45, $57,
$41, $5C, $79, $14, $69, $50, $63, $98, $EA, $FB, $49, $B0, $04, $BE, $82, $7D,
$38, $82, $4A, $BC, $93, $C9, $DD, $F7, $68, $B8, $D4, $14, $B1, $D7, $52, $7C,
$B7, $C8, $98, $EF, $7A, $3D, $7D, $28, $C4, $B2, $89, $EF, $55, $DF, $EA, $92,
$21, $E1, $4B, $20, $F1, $66, $CB, $9C, $71, $36, $19, $E9, $14, $41, $29, $50,
$8F, $F2, $D3, $51, $D4, $8C, $1D, $1A, $F3, $A2, $B4, $05, $95, $87, $2D, $F2,
$BF, $7D, $5E, $07, $EA, $9A, $79, $0E, $CD, $1F, $20, $FB, $1A, $54, $CA, $58,
$5B, $E7, $14, $9E, $76, $5B, $AE, $D6, $54, $4B, $FA, $74, $0C, $4D, $A6, $BD,
$4E, $FC, $CF, $45, $9F, $90, $13, $47, $B5, $44, $8C, $35, $73, $16, $F8, $51,
$55, $2F, $18, $77, $AA, $5E, $7D, $AF, $67, $07, $63, $CE, $8C, $62, $75, $FE,
$CF, $76, $C8, $C8, $08, $A9, $2A, $D3, $D2, $7E, $EC, $B8, $58, $18, $8C, $0B,
$B5, $AB, $74, $7D, $53, $22, $90, $0B, $3C, $8E, $6A, $10, $C4, $58, $02, $45,
$60, $B4, $37, $E5, $E5, $BA, $47, $89, $17, $ED, $91, $21, $4E, $8C, $44, $6E,
$54, $68, $9C, $6E, $19, $D4, $8C, $45, $CC, $A2, $60, $89, $6D, $7B, $00, $C9,
$51, $FB, $35, $99, $94, $8E, $E1, $36, $70, $14, $07, $B1, $10, $18, $40, $11,
$EE, $18, $95, $D3, $D4, $9A, $EA, $4C, $C2, $9A, $0F, $CB, $E9, $0F, $B0, $C5,
$49, $43, $F6, $8A, $FF, $55, $9C, $EC, $5E, $6A, $47, $50, $82, $A4, $07, $33,
$37, $0F, $60, $47, $20, $04, $10, $D5, $C6, $39, $61, $B5, $B9, $E3, $7B, $79,
$14, $EE, $9C, $26, $E9, $DE, $43, $81, $9A, $E6, $93, $90, $B6, $12, $01, $15,
$60, $FB, $24, $02, $73, $56, $89, $C9, $31, $FB, $7D, $67, $CA, $A7, $56, $5C,
$9F, $8B, $CA, $23, $16, $9D, $B1, $41, $FC, $30, $BD, $58, $B1, $EE, $FF, $DD,
$65, $DC, $8E, $26, $4D, $6C, $C4, $38, $85, $51, $90, $75, $02, $EF, $62, $E3,
$24, $31, $91, $8F, $D7, $FA, $77, $1A, $B6, $23, $DE, $E1, $22, $6A, $AA, $84,
$A9, $C3, $AB, $6F, $52, $2E, $9B, $7D, $E2, $77, $7B, $F5, $A1, $4D, $E6, $70,
$BB, $8F, $E5, $95, $B6, $21, $86, $C0, $20, $C4, $D2, $E1, $75, $83, $1A, $52,
$4A, $F8, $8E, $C8, $D9, $30, $E3, $73, $AD, $A2, $07, $DA, $5B, $AC, $12, $FD,
$BA, $63, $65, $F9, $45, $B9, $12, $51, $58, $A0, $56, $76, $0F, $50, $7F, $EA,
$A6, $75, $F9, $A6, $7E, $91, $AD, $52, $8C, $26, $2F, $FC, $6C, $16, $E6, $2C,
$29, $A1, $D0, $30, $FC, $1C, $BD, $1C, $63, $AA, $DC, $0D, $86, $99, $8E, $89,
$47, $EB, $D7, $60, $DA, $F3, $9A, $24, $59, $B0, $86, $94, $DE, $C9, $58, $12,
$27, $A9, $2A, $8E, $FD, $86, $BF, $36, $B8, $89, $E0, $91, $1C, $F2, $41, $1D,
$9F, $C5, $30, $48, $BC, $68, $3D, $FC, $4C, $B4, $C6, $7C, $5A, $3C, $46, $61,
$A4, $5F, $DA, $B9, $4C, $49, $BA, $84, $7E, $BB, $05, $FA, $14, $74, $03, $09,
$1A, $6B, $49, $5B, $B7, $CB, $0B, $E6, $80, $3B, $87, $32, $D6, $10, $CF, $16,
$3A, $E0, $4E, $E5, $AF, $77, $EA, $12, $79, $92, $57, $CA, $CB, $A6, $BC, $CA,
$12, $D7, $33, $75, $8B, $4E, $DF, $1B, $0B, $36, $54, $F7, $31, $70, $A3, $D3,
$FA, $6F, $33, $47, $E4, $B5, $26, $18, $B1, $C2, $6C, $1F, $E8, $2D, $73, $D2,
$EC, $1A, $72, $7F, $7F, $41, $4C, $BA, $4B, $23, $56, $0B, $2A, $CE, $DE, $FF,
$36, $98, $5C, $F1, $E3, $4D, $37, $C2, $1D, $70, $EC, $09, $90, $A8, $B0, $95,
$BE, $2D, $E1, $8D, $9E, $CC, $58, $8E, $FD, $31, $82, $D2, $12, $E4, $D2, $42,
$2D, $DB, $58, $C9, $EE, $07, $E7, $A0, $CC, $D6, $42, $3E, $9C, $D9, $D6, $9A,
$A6, $6F, $B2, $B3, $7A, $91, $D2, $EE, $2F, $CC, $70, $98, $EF, $AF, $E6, $21,
$FB, $9F, $1F, $DE, $F9, $E6, $DF, $46, $50, $BD, $91, $0D, $4F, $7B, $90, $BB,
$D7, $0A, $B5, $3B, $CD, $ED, $F3, $0D, $10, $70, $A8, $5C, $D6, $71, $BF, $2A,
$E3, $14, $31, $C7, $8E, $09, $28, $10, $21, $BF, $D6, $69, $92, $90, $34, $50,
$D9, $76, $04, $95, $3F, $06, $16, $CF, $17, $FC, $00, $32, $E7, $82, $5D, $66,
$BB, $92, $B5, $AD, $46, $7A, $D9, $98, $72, $15, $30, $61, $14, $47, $36, $DB,
$23, $96, $C8, $CA, $CA, $D3, $76, $70, $F7, $7A, $5C, $F9, $DA, $78, $26, $BF,
$93, $B5, $8B, $86, $29, $55, $28, $BE, $00, $51, $CD, $3D, $6B, $B2, $37, $FB,
$34, $EE, $FE, $C7, $EC, $77, $F8, $75, $9F, $5F, $E2, $D4, $22, $D5, $77, $FD,
$D0, $E8, $2A, $20, $1A, $AC, $9E, $58, $F2, $A0, $F9, $0D, $8C, $ED, $D4, $48,
$92, $15, $B6, $77, $AA, $DB, $B7, $0B, $76, $36, $7B, $79, $85, $F3, $F3, $3A,
$26, $6F, $19, $24, $6E, $A8, $15, $22, $A9, $13, $A4, $04, $6C, $21, $03, $4D,
$5A, $47, $BC, $15, $16, $41, $B1, $72, $D2, $C9, $8D, $76, $01, $4C, $EB, $DF,
$54, $8A, $72, $70, $15, $42, $AF, $00, $12, $A3, $5B, $0C, $10, $20, $09, $96,
$DB, $C5, $80, $1C, $19, $CE, $1A, $67, $9A, $45, $D2, $43, $4D, $16, $31, $3F,
$E5, $D6, $1C, $2D, $EE, $84, $53, $F8, $0C, $09, $84, $71, $66, $8B, $77, $67,
$61, $B2, $3E, $7B, $D9, $94, $1A, $7B, $DD, $7E, $04, $D9, $DC, $AD, $B8, $27,
$12, $63, $E0, $AA, $FD, $C2, $68, $02, $FD, $84, $D0, $9E, $65, $4B, $7D, $6D,
$B2, $9E, $1B, $F3, $57, $96, $A3, $F3, $3F, $39, $04, $D0, $FB, $94, $7F, $DF,
$FF, $98, $78, $58, $E7, $E1, $85, $B3, $A2, $64, $51, $EA, $B9, $45, $2A, $E7,
$BE, $97, $C9, $49, $E8, $D3, $38, $B4, $4D, $DE, $95, $64, $02, $88, $4F, $2E,
$4D, $A6, $E7, $D7, $99, $7D, $88, $C8, $E6, $5A, $8B, $8B, $85, $1A, $AB, $2D,
$4D, $BC, $DB, $CC, $64, $3A, $89, $72, $DE, $9B, $73, $2F, $15, $70, $F8, $44,
$51, $17, $07, $60, $2B, $61, $5B, $45, $F5, $2F, $F2, $9F, $A5, $63, $F2, $8E,
$21, $EE, $9C, $A6, $B3, $FA, $A7, $4F, $96, $19, $99, $EA, $95, $A0, $F3, $94,
$32, $43, $5B, $B3, $91, $C9, $D0, $73, $37, $A6, $16, $79, $67, $03, $E2, $58,
$76, $AB, $A2, $10, $5E, $DF, $E6, $80, $16, $91, $F4, $CF, $2C, $B6, $EE, $88,
$F1, $C3, $27, $9C, $C6, $F2, $B4, $E3, $88, $8C, $E6, $CC, $3B, $1A, $6C, $BF,
$19, $44, $D2, $00, $DC, $03, $89, $7E, $B7, $7A, $6B, $63, $D6, $64, $34, $BC,
$A0, $95, $1F, $47, $5A, $A8, $96, $4D, $EE, $38, $BC, $E5, $A8, $DE, $3C, $AB,
$EF, $3B, $C4, $1B, $C8, $60, $0B, $9B, $DB, $D0, $F0, $40, $79, $AE, $BB, $59,
$C7, $10, $47, $8A, $DC, $28, $EB, $1F, $3B, $11, $69, $31, $37, $DC, $68, $48,
$F0, $01, $67, $DA, $2F, $66, $74, $46, $27, $D8, $75, $76, $87, $CB, $E5, $2D,
$B4, $55, $E0, $A9, $D7, $56, $A8, $66, $15, $68, $56, $1D, $72, $BF, $E6, $10,
$FC, $A5, $9B, $AB, $7C, $75, $0D, $80, $80, $8B, $0A, $D8, $F1, $00, $1D, $75,
$16, $7E, $AD, $E4, $AE, $98, $C7, $7B, $9B, $DC, $1A, $DB, $A4, $43, $FD, $57,
$67, $23, $3E, $4E, $71, $BF, $97, $55, $2D, $8C, $62, $58, $8A, $B2, $08, $15,
$13, $E3, $09, $39, $E6, $98, $C1, $FF, $19, $45, $40, $C7, $73, $61, $D6, $6E,
$50, $1F, $66, $4F, $CE, $EA, $87, $4D, $C5, $CD, $88, $4F, $4B, $01, $F6, $D5,
$FA, $38, $3C, $0B, $79, $1A, $9B, $45, $6D, $0A, $9A, $7D, $99, $33, $AE, $AF,
$28, $9A, $49, $0C, $E9, $C4, $F4, $B3, $DC, $76, $8F, $97, $C5, $92, $ED, $2B,
$50, $C7, $6C, $FD, $2A, $0C, $D7, $A8, $D1, $38, $E1, $31, $A7, $C9, $A6, $E1,
$59, $8C, $B2, $5C, $18, $84, $C2, $85, $57, $3E, $33, $FF, $84, $50, $3A, $12,
$87, $7B, $23, $E8, $E2, $C5, $5B, $09, $15, $8D, $2B, $E0, $15, $34, $67, $80,
$32, $DF, $FB, $40, $CA, $A4, $A2, $B3, $1D, $BB, $B8, $7E, $2F, $C2, $B9, $AE,
$6D, $2A, $0B, $1F, $A3, $93, $72, $AC, $E4, $25, $28, $0D, $18, $21, $0C, $64,
$F3, $BC, $11, $EA, $7B, $82, $41, $8E, $5B, $1C, $51, $6A, $67, $C2, $7A, $C5,
$1C, $B0, $49, $B7, $94, $CC, $F5, $03, $3F, $8A, $3A, $78, $AF, $B4, $8A, $B9,
$EE, $DE, $88, $06, $74, $A0, $95, $7A, $23, $A1, $C4, $A0, $5E, $97, $4A, $ED,
$EA, $1C, $1E, $CA, $90, $08, $70, $8E, $EC, $77, $FC, $F2, $DF, $F3, $43, $60,
$8B, $07, $E4, $86, $0E, $60, $FD, $9E, $66, $83, $3B, $30, $39, $47, $A9, $6D,
$B7, $2B, $E3, $4C, $A6, $5D, $5F, $13, $54, $38, $5B, $5F, $6E, $2E, $EB, $37,
$15, $FB, $27, $35, $4B, $FF, $B2, $19, $18, $0B, $D8, $9B, $BE, $E7, $E1, $7B,
$0B, $F4, $16, $76, $4A, $CE, $D4, $98, $A6, $30, $B3, $64, $6E, $FB, $33, $7E,
$B0, $47, $12, $FF, $FF, $64, $4C, $70, $E0, $53, $74, $EC, $CB, $44, $52, $0C,
$33, $96, $EE, $4B, $95, $F6, $36, $95, $35, $22, $82, $9E, $70, $6F, $B5, $39,
$B0, $7B, $4C, $6B, $EB, $D4, $E4, $8D, $7D, $7F, $78, $BB, $39, $AA, $03, $4F,
$F0, $11, $85, $9A, $5D, $28, $5C, $0F, $B5, $BE, $F5, $15, $F8, $56, $8B, $AA,
$CB, $D8, $11, $BB, $8E, $9B, $6D, $64, $37, $82, $4E, $12, $67, $86, $8F, $12,
$AC, $E5, $19, $EF, $EF, $D9, $CA, $C7, $C0, $CF, $67, $DE, $8E, $82, $90, $4F,
$34, $C7, $57, $86, $DA, $41, $B1, $24, $4D, $26, $BC, $14, $4B, $57, $3D, $CC,
$CC, $C8, $B4, $44, $8C, $91, $3F, $5A, $9F, $25, $49, $FD, $BC, $AF, $D1, $74,
$C2, $74, $8B, $30, $C5, $A9, $B6, $52, $37, $9D, $5F, $55, $54, $32, $BE, $9F,
$3F, $11, $20, $A0, $15, $B2, $E4, $C9, $C7, $D5, $97, $8A, $AA, $35, $55, $E0,
$EF, $8F, $85, $2F, $8C, $8F, $C8, $C1, $3D, $0D, $83, $CB, $98, $78, $92, $91,
$05, $AC, $1F, $38, $38, $34, $2A, $A5, $28, $7B, $AA, $4A, $7E, $E0, $CD, $65,
$EF, $8C, $20, $5E, $9D, $85, $66, $F9, $29, $CE, $07, $95, $90, $5E, $DC, $96,
$86, $DD, $A8, $DC, $09, $D9, $8B, $06, $E6, $85, $9C, $F8, $8F, $E1, $D0, $CF,
$39, $69, $46, $CB, $15, $56, $E8, $3D, $9B, $89, $69, $8B, $4D, $7E, $D0, $03,
$E9, $A9, $DF, $AD, $1A, $ED, $54, $8A, $FA, $4E, $61, $A9, $98, $1F, $52, $FC,
$7B, $CF, $52, $BE, $AB, $76, $AF, $E0, $3E, $49, $32, $07, $0C, $0F, $49, $2E,
$7F, $5F, $A3, $33, $EA, $AE, $DA, $AD, $C5, $5B, $6D, $1D, $51, $70, $DB, $0E,
$B8, $4A, $AD, $DC, $52, $EC, $82, $96, $B4, $19, $50, $1E, $CA, $89, $EB, $40,
$DB, $73, $3C, $8D, $BB, $44, $C5, $74, $81, $08, $59, $38, $33, $F2, $58, $B7,
$3D, $14, $48, $70, $6E, $69, $9F, $38, $CB, $62, $C7, $0D, $23, $1E, $F6, $F4,
$44, $4C, $7C, $F3, $84, $04, $2B, $00, $49, $1F, $A3, $B0, $85, $67, $83, $AC,
$13, $30, $AD, $E2, $8A, $3B, $CF, $AD, $36, $EC, $FA, $E8, $65, $09, $ED, $1C,
$2B, $16, $9A, $78, $3C, $99, $36, $DE, $88, $32, $D3, $F9, $DA, $F0, $5A, $0A,
$FD, $90, $4C, $2C, $19, $72, $8E, $95, $98, $1B, $C4, $F4, $C2, $53, $A0, $CE,
$CB, $BD, $98, $A6, $31, $99, $C0, $74, $60, $FD, $D5, $50, $80, $DA, $90, $05,
$C3, $13, $E0, $06, $C9, $79, $E6, $44, $91, $2E, $15, $1E, $BA, $86, $7C, $DC,
$1F, $AE, $6A, $9D, $42, $7A, $61, $AC, $CA, $76, $EF, $F1, $9C, $86, $D4, $6E,
$E2, $5E, $2E, $9B, $D6, $26, $BA, $52, $7F, $9C, $60, $0C, $F4, $AA, $B2, $EF,
$BF, $75, $86, $D8, $F2, $6E, $09, $FE, $5C, $1E, $D3, $DC, $99, $31, $BC, $84,
$6C, $56, $50, $EF, $E9, $3C, $EC, $01, $33, $C0, $6E, $3B, $C3, $9B, $57, $CB,
$7B, $C8, $96, $75, $F8, $9D, $15, $03, $1E, $C8, $AE, $76, $12, $14, $14, $0D,
$E8, $91, $25, $70, $E2, $51, $A2, $BF, $29, $C2, $B7, $4F, $59, $81, $98, $BB,
$9F, $D0, $D2, $27, $A1, $46, $EF, $3F, $57, $AC, $1C, $17, $32, $63, $07, $6B,
$A9, $A4, $AE, $02, $07, $51, $F7, $00, $FB, $19, $43, $55, $2E, $FA, $3B, $4D,
$40, $E3, $C2, $96, $F7, $CD, $D7, $34, $B1, $A8, $97, $AA, $8E, $8A, $42, $59,
$5A, $4F, $8E, $5C, $BB, $B2, $78, $FD, $66, $8F, $B8, $61, $42, $DF, $31, $A5,
$5C, $35, $D7, $B0, $58, $AA, $B6, $89, $90, $E9, $5D, $56, $6D, $BA, $4D, $AC,
$25, $B5, $D2, $49, $AE, $5C, $87, $3D, $2D, $FB, $AE, $94, $88, $E8, $9E, $C7,
$7A, $B3, $F2, $9F, $3D, $54, $26, $C6, $96, $83, $00, $3E, $99, $6F, $AA, $0A,
$F3, $0C, $48, $AD, $9D, $05, $F4, $A1, $8A, $3C, $38, $A8, $61, $AF, $DD, $60,
$88, $E8, $76, $4B, $FA, $E2, $D5, $46, $84, $B6, $58, $8C, $BF, $5A, $60, $D8,
$6E, $C3, $4C, $82, $93, $82, $F0, $F1, $2D, $1C, $B3, $A8, $AF, $6B, $2D, $DE,
$33, $CB, $D9, $A2, $7C, $CD, $E7, $F0, $19, $32, $17, $BC, $28, $61, $DB, $86,
$B0, $32, $B0, $C0, $61, $A7, $73, $B9, $5D, $37, $03, $D9, $5C, $25, $9B, $31,
$7F, $E1, $DC, $57, $5A, $A4, $5D, $39, $2D, $A7, $1D, $67, $84, $38, $C6, $43,
$84, $EB, $DE, $32, $28, $B8, $39, $85, $74, $92, $84, $85, $4D, $98, $58, $50,
$AA, $4C, $10, $22, $1C, $F1, $89, $C5, $66, $4B, $71, $9A, $71, $99, $8F, $E7,
$F7, $0B, $18, $BB, $17, $2F, $6E, $AA, $8D, $0A, $5C, $58, $8C, $1D, $48, $76,
$FE, $F1, $6C, $C7, $13, $DF, $97, $08, $75, $16, $4D, $D4, $89, $A4, $37, $2D,
$CA, $A8, $5E, $68, $1C, $8A, $B1, $F5, $1F, $F4, $4B, $E7, $85, $FE, $05, $6B,
$65, $BC, $1A, $F8, $99, $8C, $31, $CE, $14, $8F, $1B, $33, $2F, $CA, $61, $18,
$C1, $CC, $2A, $61, $07, $0C, $FF, $F4, $18, $98, $DD, $88, $53, $03, $21, $24,
$FD, $DC, $8D, $EB, $53, $48, $7D, $AF, $DB, $FD, $EB, $DB, $08, $D6, $6F, $59,
$1B, $87, $6F, $41, $6C, $0B, $53, $1C, $5C, $1D, $BF, $CB, $C4, $25, $F8, $7F,
$E9, $C6, $55, $01, $64, $ED, $63, $89, $D0, $7B, $2D, $2F, $C0, $1A, $01, $1D,
$6A, $D2, $C3, $FD, $32, $30, $0C, $9B, $52, $B3, $83, $AC, $E3, $2B, $36, $0B,
$AE, $C7, $39, $49, $26, $7E, $4E, $1E, $2F, $C6, $82, $57, $19, $5E, $29, $FC,
$CF, $22, $0D, $71, $D8, $73, $17, $B5, $2D, $E5, $DB, $54, $5A, $D8, $17, $D8,
$EA, $67, $67, $27, $4C, $93, $00, $46, $F1, $3A, $FC, $8C, $9E, $B8, $72, $40,
$42, $24, $E8, $4C, $CD, $3D, $0E, $FD, $F7, $E9, $D8, $BB, $7B, $01, $6F, $AC,
$E2, $7F, $5F, $FD, $AD, $D1, $7C, $2D, $43, $F3, $73, $2A, $07, $F7, $D7, $07,
$0A, $F3, $08, $1A, $06, $58, $4F, $09, $1C, $17, $23, $25, $31, $C4, $69, $A4,
$EE, $5B, $9F, $5E, $65, $CE, $D4, $38, $80, $B8, $92, $4B, $0F, $CB, $B7, $51,
$B2, $F0, $DF, $0C, $ED, $9D, $57, $05, $82, $3B, $6D, $E3, $78, $51, $FB, $9D,
$CC, $37, $AE, $05, $5A, $74, $22, $94, $AF, $FA, $FB, $E7, $AD, $5B, $29, $E4,
$A2, $E5, $DA, $0E, $1E, $0D, $D3, $39, $E4, $33, $46, $74, $55, $0E, $FF, $AC,
$C5, $62, $7D, $71, $73, $F3, $48, $34, $9D, $33, $21, $49, $D1, $18, $6E, $A6,
$56, $48, $A9, $40, $82, $AF, $92, $A0, $1D, $B6, $85, $63, $92, $69, $0A, $AE,
$17, $7F, $B6, $D8, $78, $0E, $17, $36, $CF, $02, $EC, $C0, $61, $AF, $52, $C2,
$77, $A1, $C0, $B4, $1E, $97, $F1, $57, $A3, $99, $01, $68, $2D, $E7, $0C, $7C,
$66, $1E, $28, $0D, $32, $04, $7A, $E6, $28, $AC, $1B, $F2, $29, $BC, $57, $D7,
$E5, $A9, $93, $38, $3A, $82, $DE, $95, $ED, $B9, $5C, $C2, $4F, $CF, $D5, $88,
$03, $17, $06, $36, $42, $0C, $F7, $FA, $8A, $28, $E7, $58, $6B, $30, $D5, $71,
$46, $21, $24, $19, $DE, $F7, $A7, $8F, $EC, $4B, $9C, $3B, $A3, $3D, $38, $1C,
$24, $8B, $33, $1A, $C5, $86, $D8, $6C, $25, $DD, $46, $13, $89, $67, $2F, $05,
$30, $5D, $A8, $4D, $36, $21, $EB, $F9, $52, $33, $49, $A3, $27, $E7, $05, $22,
$B8, $ED, $2D, $D0, $3C, $53, $A0, $1C, $7A, $88, $81, $13, $E7, $F7, $FB, $D7,
$B8, $7E, $AD, $A2, $A8, $F3, $76, $43, $F1, $47, $A9, $63, $4B, $30, $22, $D9,
$58, $0A, $D1, $8D, $23, $13, $14, $77, $5E, $D1, $5F, $EE, $FE, $11, $90, $B9,
$48, $76, $5A, $36, $C2, $4E, $DC, $0B, $67, $85, $4C, $7D, $47, $B4, $C1, $4C,
$22, $32, $F5, $1E, $DB, $7B, $69, $ED, $14, $41, $C8, $53, $29, $33, $E7, $02,
$25, $2B, $F1, $DE, $E1, $D2, $66, $E6, $0B, $04, $6C, $3E, $9E, $84, $A4, $D0,
$CB, $12, $2E, $D6, $81, $71, $2A, $1B, $37, $B5, $90, $F0, $AE, $8E, $E6, $99,
$AC, $4E, $E5, $52, $13, $FE, $7F, $3D, $77, $34, $AC, $71, $68, $C4, $18, $71,
$76, $8D, $25, $BD, $79, $F5, $EC, $D5, $7E, $3B, $CA, $1E, $DF, $3F, $DC, $D0,
$92, $D2, $8F, $34, $32, $05, $07, $E7, $34, $23, $FA, $9C, $57, $B1, $F0, $99,
$C4, $ED, $BC, $A4, $98, $D4, $59, $5C, $89, $F8, $DA, $02, $46, $62, $1F, $65,
$C0, $6D, $F7, $E1, $EF, $73, $63, $90, $49, $80, $70, $84, $E3, $E2, $49, $F0,
$F0, $1B, $3D, $1D, $C1, $91, $9C, $4B, $02, $0A, $F6, $C5, $CC, $D6, $35, $7A,
$DD, $E0, $E7, $A6, $6A, $C6, $71, $14, $59, $16, $1E, $FD, $5A, $BA, $2B, $C2,
$58, $C1, $B3, $52, $24, $3C, $0F, $E2, $74, $B5, $96, $40, $D3, $3E, $46, $07,
$3B, $AC, $52, $CD, $17, $47, $E1, $77, $F3, $3D, $84, $05, $59, $A9, $DA, $D3,
$78, $0F, $FD, $D6, $7B, $9C, $4C, $2F, $FE, $8B, $92, $26, $09, $1D, $51, $EE,
$2F, $51, $1C, $1F, $33, $6C, $71, $57, $D2, $F8, $BE, $9A, $43, $67, $7C, $9C,
$94, $CC, $D9, $B3, $B0, $58, $CB, $0F, $32, $6A, $53, $00, $E7, $A1, $70, $15,
$10, $05, $AE, $35, $B3, $BC, $7A, $2E, $67, $F2, $76, $94, $9E, $4E, $E4, $D1,
$C0, $54, $51, $4C, $66, $F0, $CD, $68, $7B, $60, $52, $11, $CA, $9D, $BE, $F3,
$4B, $4D, $F3, $2B, $88, $F6, $44, $6A, $54, $DA, $72, $9E, $66, $6F, $02, $58,
$75, $1F, $BE, $EF, $11, $8B, $4F, $06, $CB, $7A, $32, $78, $7D, $73, $2E, $DE,
$FC, $CC, $3A, $C5, $BB, $AB, $40, $CC, $67, $E6, $00, $8F, $B1, $F9, $A0, $1D,
$63, $7F, $44, $86, $10, $92, $F1, $57, $AF, $93, $18, $C7, $0E, $4C, $06, $1C,
$0F, $A8, $07, $A7, $77, $FD, $E8, $59, $1B, $E8, $A7, $EC, $4A, $60, $73, $2E,
$D0, $5B, $A4, $7B, $03, $50, $AD, $CB, $06, $CF, $94, $76, $DE, $23, $CB, $CD,
$C7, $F6, $5D, $40, $02, $00, $FD, $B5, $BF, $FE, $9B, $38, $09, $38, $47, $B6,
$CF, $B0, $A6, $DA, $65, $EC, $A8, $4E, $ED, $15, $08, $E6, $90, $BB, $55, $E2,
$27, $D3, $6B, $0F, $6F, $20, $61, $67, $DA, $35, $BA, $A1, $90, $BD, $69, $9A,
$16, $7F, $34, $C3, $EC, $59, $24, $1D, $A2, $5D, $81, $CD, $7D, $37, $A5, $4B,
$6A, $CB, $7A, $BE, $32, $6B, $DD, $96, $36, $6B, $01, $91, $C8, $41, $37, $7C,
$52, $98, $56, $DA, $91, $4A, $88, $5C, $EC, $A9, $F5, $94, $1E, $56, $BA, $36,
$7D, $C7, $9F, $29, $62, $C0, $CC, $3B, $76, $EE, $3A, $B5, $50, $D8, $2A, $A4,
$2B, $5C, $6F, $4C, $F7, $39, $69, $DE, $D8, $4A, $48, $AC, $31, $91, $39, $32,
$59, $5E, $18, $A4, $D2, $F0, $9D, $F2, $9F, $D1, $7C, $0A, $29, $EA, $68, $10,
$60, $6E, $EA, $59, $95, $6C, $F9, $BC, $42, $77, $0D, $9D, $CA, $09, $F6, $4B,
$C1, $77, $1F, $DA, $6D, $94, $20, $2F, $E9, $8D, $32, $0C, $50, $2D, $5B, $69,
$77, $4C, $EB, $EF, $8F, $72, $F5, $65, $CD, $A1, $B5, $17, $E1, $11, $0C, $C8,
$B5, $25, $1C, $58, $CE, $86, $D0, $81, $EC, $ED, $27, $3D, $E0, $96, $DC, $14,
$99, $FE, $EA, $A3, $E6, $AC, $06, $DA, $98, $DB, $79, $61, $01, $3E, $82, $F7,
$A2, $90, $D8, $26, $9F, $CE, $3E, $FC, $D6, $C6, $30, $1D, $31, $79, $7B, $C3,
$A6, $B9, $96, $CD, $BA, $CB, $E9, $6C, $8C, $F7, $AA, $36, $D1, $8D, $E2, $73,
$82, $42, $5B, $84, $40, $4E, $B3, $BB, $05, $F9, $A3, $59, $F0, $14, $B3, $49,
$7B, $3B, $0D, $6D, $79, $F7, $EB, $97, $D2, $69, $40, $52, $57, $79, $56, $4C,
$F8, $C9, $E8, $4C, $CC, $10, $A2, $AD, $A8, $A5, $DC, $86, $2E, $BD, $05, $F8,
$D1, $A7, $28, $C8, $7A, $CD, $AE, $CA, $4D, $42, $BC, $9B, $66, $EC, $89, $1D,
$A7, $1A, $A1, $B0, $B0, $68, $AE, $0B, $0A, $01, $E2, $F5, $17, $20, $86, $8D,
$2C, $51, $8E, $88, $2F, $F5, $15, $C0, $B6, $C9, $F9, $6C, $6F, $B0, $AF, $13,
$44, $31, $24, $58, $BD, $13, $F5, $90, $33, $0D, $82, $45, $A1, $14, $20, $EC,
$EB, $CA, $98, $3E, $7B, $AE, $40, $70, $F3, $1F, $C6, $54, $E4, $A5, $18, $B3,
$43, $27, $A6, $14, $AA, $AF, $FF, $63, $68, $E6, $3B, $EF, $1E, $FE, $79, $CC,
$45, $B4, $15, $C3, $A3, $A0, $78, $CC, $A6, $23, $D6, $B1, $95, $A1, $3D, $E3,
$2B, $C5, $FD, $6C, $F2, $37, $97, $58, $35, $29, $60, $47, $F3, $62, $40, $AB,
$8E, $95, $4C, $3E, $97, $44, $A9, $D6, $BF, $43, $B0, $7B, $0D, $E2, $04, $46,
$FC, $F1, $D2, $39, $3E, $19, $7F, $35, $99, $9B, $91, $F2, $02, $AC, $B7, $BF,
$C1, $00, $83, $DC, $57, $32, $49, $7A, $5A, $F0, $34, $8F, $35, $06, $52, $8A,
$32, $B9, $E9, $F2, $D2, $BD, $A9, $04, $69, $1A, $3F, $4E, $E9, $EC, $9E, $D1,
$CB, $0E, $74, $B3, $4E, $3C, $53, $7F, $1E, $94, $EB, $69, $4F, $8F, $E3, $C8,
$23, $0E, $5A, $A4, $4F, $C3, $1D, $2C, $17, $96, $39, $F7, $64, $96, $56, $92,
$5A, $FF, $72, $AD, $3D, $AC, $82, $F2, $7C, $F7, $F2, $67, $09, $7A, $5C, $9C,
$B8, $39, $11, $70, $BD, $B3, $72, $30, $BB, $A1, $B3, $EB, $BC, $86, $FD, $C7,
$33, $5B, $28, $F8, $89, $93, $7E, $67, $B9, $D3, $2E, $B7, $A0, $4A, $35, $C4,
$A4, $B6, $D4, $3A, $3B, $34, $8F, $69, $C7, $21, $AE, $73, $BB, $CE, $A7, $F5,
$D7, $B7, $EF, $82, $0B, $1F, $EA, $99, $82, $49, $C2, $64, $6E, $FA, $08, $AA,
$41, $11, $EF, $5D, $B5, $1D, $DA, $82, $E2, $3A, $8F, $8A, $A6, $D7, $98, $BC,
$49, $DC, $6A, $D7, $35, $BB, $A5, $E7, $3F, $CA, $7E, $14, $5D, $70, $FF, $15,
$78, $69, $B7, $B5, $FD, $F3, $A1, $5D, $6D, $77, $E8, $62, $E1, $48, $A8, $D7,
$9B, $F6, $B2, $56, $C5, $8F, $14, $E1, $08, $0C, $DD, $39, $52, $23, $76, $A6,
$1B, $02, $BE, $33, $CE, $0B, $02, $F1, $1F, $51, $04, $8E, $FC, $8C, $75, $63,
$57, $AD, $B8, $E1, $42, $B0, $1D, $C4, $55, $EC, $EB, $53, $5A, $24, $43, $B3,
$7E, $AC, $5D, $28, $B0, $C0, $A5, $B1, $60, $8B, $EB, $53, $52, $11, $AA, $D5,
$53, $3D, $93, $D5, $EF, $B6, $CA, $CC, $99, $60, $8A, $DC, $27, $B5, $A4, $81,
$22, $9E, $B9, $B4, $EF, $4D, $DD, $07, $47, $0E, $1A, $95, $67, $72, $D1, $B5,
$F4, $BD, $E9, $45, $30, $33, $60, $31, $0A, $06, $99, $D9, $D0, $ED, $50, $A5,
$73, $62, $9A, $BE, $E8, $D0, $B7, $B5, $B6, $FE, $D8, $20, $98, $04, $25, $B4,
$33, $87, $55, $31, $3F, $A9, $6B, $88, $67, $23, $43, $5C, $A1, $BA, $35, $A9,
$62, $F8, $F4, $CF, $1C, $BC, $5E, $6B, $BD, $E0, $9A, $12, $AE, $A0, $06, $ED,
$7F, $3C, $9F, $F4, $C3, $5D, $74, $BA, $70, $8F, $7A, $28, $4F, $93, $D9, $C9,
$3A, $F0, $6E, $EB, $D0, $B0, $A3, $EC, $A8, $8C, $79, $D0, $47, $7A, $41, $89,
$13, $7C, $D8, $68, $92, $03, $77, $2F, $42, $77, $24, $8E, $5A, $7B, $FE, $E0,
$89, $BB, $0F, $9C, $E3, $9A, $00, $B8, $5B, $11, $DF, $75, $A6, $D8, $B0, $A9,
$AC, $76, $89, $87, $D1, $78, $93, $2F, $64, $72, $56, $15, $A0, $48, $0D, $62,
$16, $83, $7F, $85, $2C, $3A, $E8, $7D, $54, $C5, $C1, $64, $41, $8F, $92, $7E,
$8A, $C1, $E6, $6B, $06, $5D, $77, $10, $15, $51, $8A, $87, $A7, $B0, $FD, $21,
$47, $F5, $7C, $5F, $A5, $24, $80, $21, $B9, $6F, $C6, $0F, $D5, $1E, $03, $B6,
$FD, $DC, $CF, $46, $10, $16, $B4, $44, $35, $2B, $00, $01, $CF, $ED, $44, $3D,
$C8, $25, $53, $C6, $DF, $89, $68, $8C, $E6, $1D, $FE, $B7, $E2, $FC, $4B, $EC,
$81, $5A, $C8, $B9, $FB, $80, $9F, $98, $FF, $62, $F0, $C7, $5D, $5E, $4D, $5B,
$3E, $25, $3D, $19, $20, $39, $99, $9D, $0B, $1F, $D4, $CA, $59, $A3, $3D, $65,
$52, $6B, $7D, $6D, $10, $4D, $29, $07, $11, $64, $2F, $87, $AE, $7A, $A9, $BB,
$06, $F6, $F6, $8C, $32, $58, $EC, $34, $98, $E5, $BF, $65, $D9, $1D, $FE, $05,
$6B, $B2, $38, $15, $7E, $BB, $6A, $D3, $FC, $8F, $DE, $06, $EC, $1F, $93, $3B,
$19, $2C, $25, $31, $D2, $FD, $06, $C8, $91, $E4, $9E, $99, $8F, $8A, $8B, $CA,
$E0, $55, $07, $16, $F8, $D3, $A0, $C8, $F2, $47, $6A, $38, $42, $B2, $75, $37,
$06, $FD, $ED, $8E, $C6, $B8, $13, $2A, $2F, $D2, $CD, $3C, $EC, $8B, $2F, $89,
$3B, $EC, $A1, $78, $2B, $A1, $1E, $7D, $79, $90, $0B, $9D, $00, $3F, $CD, $F6,
$22, $29, $D6, $09, $E9, $55, $8F, $05, $9A, $BA, $A7, $10, $7D, $50, $B4, $CD,
$96, $37, $1C, $48, $9C, $39, $D2, $FE, $3E, $B2, $C9, $CF, $1F, $A1, $CE, $A5,
$86, $3F, $1A, $00, $70, $27, $66, $FD, $D2, $F0, $76, $F2, $3D, $37, $25, $83,
$84, $45, $3E, $59, $8B, $E9, $37, $4C, $6D, $D3, $E5, $C2, $06, $96, $64, $36,
$71, $72, $AF, $EB, $BF, $BA, $23, $B0, $3F, $72, $FC, $A9, $48, $07, $F3, $96,
$F4, $7F, $8F, $32, $34, $D4, $6C, $9E, $F4, $33, $B1, $D5, $AC, $B1, $B5, $F8,
$11, $89, $89, $48, $41, $00, $90, $BC, $F8, $6B, $81, $CC, $45, $5A, $EC, $F3,
$69, $92, $EC, $BA, $0A, $1C, $02, $60, $05, $21, $CF, $9C, $D0, $A6, $04, $C7,
$26, $1E, $F1, $FC, $03, $B1, $48, $1E, $43, $F9, $D2, $FA, $DA, $ED, $8C, $0B,
$84, $D4, $71, $C0, $B9, $FA, $89, $56, $A0, $5D, $F7, $18, $C4, $50, $DD, $7A,
$6D, $2B, $27, $5A, $CC, $69, $6F, $90, $42, $09, $66, $25, $6C, $3B, $17, $99,
$53, $C2, $03, $5B, $56, $26, $9E, $49, $7D, $76, $1F, $59, $12, $D3, $6A, $97,
$56, $AB, $80, $A5, $AF, $32, $FF, $A5, $8E, $5A, $1B, $5F, $CD, $37, $8F, $E8,
$35, $78, $D9, $D0, $A8, $05, $0A, $56, $CA, $AB, $96, $C9, $B7, $24, $9A, $9E,
$66, $F1, $6C, $8D, $B6, $1A, $F6, $50, $18, $D5, $F4, $96, $90, $19, $32, $65,
$18, $E9, $B2, $87, $55, $86, $62, $D7, $22, $D7, $F2, $19, $3D, $5B, $A5, $B0,
$35, $41, $A4, $35, $47, $20, $A6, $C2, $89, $CC, $92, $1F, $B7, $21, $36, $93,
$65, $87, $DE, $AB, $F1, $CA, $6C, $E5, $95, $D6, $92, $FC, $F5, $EF, $ED, $4C,
$A0, $D7, $09, $2F, $C1, $22, $04, $6C, $0F, $72, $1D, $77, $72, $26, $B7, $4E,
$4D, $4E, $DE, $86, $5A, $AA, $E7, $B5, $F0, $23, $06, $66, $F1, $4B, $4B, $9D,
$71, $09, $B4, $BB, $72, $58, $11, $95, $EC, $7C, $13, $34, $01, $CC, $16, $9C,
$D9, $98, $21, $5F, $9B, $0E, $E5, $85, $C8, $6B, $3B, $04, $83, $B9, $E9, $47,
$15, $5B, $28, $BF, $EA, $4F, $DF, $36, $66, $7A, $C9, $F9, $13, $12, $32, $DB,
$AC, $8F, $70, $64, $0A, $95, $C7, $61, $B5, $F5, $80, $E8, $0E, $B4, $6D, $89,
$BF, $47, $C0, $76, $6C, $8D, $05, $E9, $97, $AF, $BB, $C2, $5D, $E5, $B6, $B9,
$8C, $B2, $0A, $B1, $AE, $02, $03, $9C, $F3, $97, $63, $5E, $FC, $B2, $16, $16,
$EE, $EB, $48, $EA, $AC, $B3, $FA, $46, $90, $4D, $21, $84, $2A, $02, $80, $89,
$3C, $A6, $36, $C9, $17, $00, $72, $0E, $9A, $5D, $7B, $75, $7C, $29, $BA, $F8,
$25, $C3, $18, $FA, $03, $C7, $29, $49, $FE, $09, $0C, $F6, $08, $1E, $25, $4B,
$4E, $73, $9B, $23, $20, $8C, $90, $AF, $83, $56, $CB, $D5, $21, $B8, $4D, $7E,
$E5, $49, $4E, $34, $3B, $72, $27, $D3, $83, $62, $1C, $AB, $C3, $DE, $03, $F1,
$92, $4D, $2C, $FD, $09, $FE, $77, $CE, $CA, $87, $11, $86, $FE, $1C, $D8, $97,
$10, $8C, $13, $C1, $97, $08, $25, $AE, $1C, $78, $09, $2F, $04, $7B, $F3, $D4,
$D6, $36, $25, $C5, $6F, $74, $29, $78, $EE, $04, $D8, $40, $0F, $AA, $4C, $24,
$21, $25, $FA, $C8, $31, $F4, $BC, $41, $22, $96, $75, $C6, $75, $A2, $22, $7E,
$F8, $5B, $D7, $DB, $72, $52, $38, $53, $60, $0B, $19, $8A, $08, $7F, $F7, $BC,
$C3, $3B, $59, $43, $77, $8A, $B3, $BB, $17, $F1, $70, $88, $5C, $E4, $8F, $B7,
$9B, $E2, $EC, $2C, $AB, $C6, $48, $5C, $06, $BD, $E8, $E1, $FA, $0D, $4B, $A4,
$62, $65, $21, $3E, $57, $85, $33, $53, $4E, $01, $56, $FB, $E4, $B5, $A5, $C8,
$4C, $A7, $6C, $AF, $83, $E3, $CC, $7F, $37, $5B, $6B, $9D, $98, $3E, $98, $D6,
$64, $C2, $9A, $A8, $90, $44, $5A, $86, $E2, $C0, $95, $A0, $25, $C5, $4D, $E7,
$3A, $C2, $F4, $BC, $53, $F3, $57, $B3, $ED, $6A, $3A, $C3, $D8, $AD, $90, $5F,
$EA, $97, $A8, $30, $DF, $03, $DF, $14, $0E, $C1, $15, $03, $A3, $0F, $01, $75,
$82, $A6, $80, $6C, $7C, $FA, $5A, $87, $24, $59, $38, $6C, $4B, $B5, $CA, $04,
$23, $76, $24, $5F, $52, $0A, $C5, $45, $A2, $2E, $D7, $9B, $32, $0E, $16, $AF,
$22, $6D, $D1, $BD, $0A, $BA, $67, $50, $C1, $26, $90, $91, $BC, $B9, $64, $04,
$D0, $2B, $57, $81, $FF, $5F, $FB, $BA, $CE, $06, $1D, $99, $54, $AE, $1C, $4B,
$61, $0C, $CF, $65, $7F, $4E, $3F, $84, $05, $27, $FE, $87, $25, $1C, $5D, $AA,
$08, $1C, $C6, $71, $F2, $1E, $3B, $50, $D4, $2D, $0B, $F2, $05, $24, $69, $54,
$A5, $52, $31, $74, $FC, $4A, $5E, $32, $79, $B5, $88, $E0, $E5, $08, $C5, $E7,
$D3, $31, $3A, $9F, $87, $CE, $22, $CB, $3F, $DC, $78, $80, $B5, $94, $40, $6A,
$2E, $BB, $35, $E1, $24, $8D, $E1, $02, $38, $63, $02, $DB, $62, $15, $34, $C2,
$58, $ED, $75, $70, $04, $48, $94, $20, $EB, $06, $F1, $4E, $7F, $07, $EE, $FF,
$B4, $DA, $E1, $CD, $B2, $00, $C3, $50, $3E, $16, $08, $9B, $DD, $22, $C8, $DF,
$58, $42, $38, $B4, $35, $7F, $25, $2C, $50, $B2, $DC, $E0, $97, $B1, $0B, $42,
$26, $9B, $22, $56, $48, $D0, $57, $58, $B4, $84, $FA, $13, $ED, $1D, $70, $FD,
$E3, $84, $48, $5E, $EC, $2E, $DB, $D0, $FF, $47, $98, $9A, $3B, $7E, $75, $74,
$3F, $22, $15, $00, $55, $2A, $FA, $C6, $2E, $5E, $9A, $34, $9A, $33, $DE, $99,
$86, $73, $E1, $C7, $61, $CE, $A2, $9A, $56, $DC, $17, $CC, $95, $8D, $1F, $60,
$60, $40, $2A, $C2, $57, $75, $AE, $52, $B3, $71, $DA, $D5, $FD, $36, $46, $45,
$2B, $5D, $36, $27, $96, $5D, $D8, $5A, $3B, $C4, $B4, $C0, $3F, $D0, $CB, $B2,
$56, $01, $9D, $77, $65, $D0, $1F, $7C, $CA, $56, $8E, $70, $8A, $F7, $D0, $E8,
$FD, $E4, $88, $17, $6B, $4B, $36, $E7, $CB, $94, $13, $1D, $9A, $26, $FF, $DB,
$3F, $51, $F7, $D6, $CA, $F9, $96, $58, $C8, $2C, $0A, $88, $63, $9B, $E7, $2D,
$1E, $BA, $D4, $CB, $A2, $66, $9D, $79, $86, $56, $7D, $FA, $1B, $E7, $48, $9C,
$92, $9E, $BA, $BB, $4D, $64, $D9, $CD, $07, $ED, $10, $32, $32, $03, $07, $B2,
$7E, $3D, $38, $A2, $07, $E7, $F0, $29, $04, $45, $D8, $07, $4E, $B5, $C4, $FF,
$F4, $F6, $6A, $0F, $6A, $08, $9C, $A7, $FA, $4C, $D6, $76, $61, $EE, $49, $D8,
$51, $6B, $5B, $2B, $97, $3B, $23, $B7, $94, $DA, $2B, $04, $A8, $84, $69, $DF,
$70, $07, $CC, $03, $F5, $06, $87, $D0, $38, $FC, $77, $01, $74, $21, $05, $9A,
$42, $DA, $21, $6B, $44, $40, $F5, $0E, $59, $96, $D7, $49, $DA, $4D, $A2, $69,
$40, $3F, $B0, $19, $F6, $96, $80, $44, $CE, $04, $C3, $F8, $6D, $80, $C9, $E5,
$26, $BA, $57, $A1, $91, $AE, $F6, $50, $BC, $75, $E4, $AC, $47, $BC, $A2, $51,
$28, $62, $44, $60, $7D, $5A, $5D, $5D, $3A, $DF, $0C, $72, $2F, $42, $12, $0C,
$A8, $6A, $91, $19, $82, $E9, $FB, $4F, $82, $88, $4B, $C1, $BF, $6F, $FC, $3A,
$28, $9E, $82, $7A, $4A, $61, $9B, $60, $2F, $B2, $82, $6F, $C7, $94, $56, $2C,
$F8, $D9, $75, $F2, $31, $47, $B7, $86, $B4, $C1, $E8, $69, $AB, $B9, $5A, $1D,
$63, $D7, $A4, $6D, $40, $C1, $0E, $58, $B2, $E0, $E4, $1D, $8E, $F3, $79, $BE,
$85, $7D, $53, $9C, $DA, $3F, $45, $B2, $F6, $80, $D1, $CF, $C1, $7B, $48, $DA,
$90, $BB, $18, $4B, $40, $14, $46, $EE, $34, $4D, $AB, $AD, $10, $5D, $48, $B3,
$F1, $BA, $E5, $22, $BE, $0D, $D5, $F5, $63, $43, $AE, $A3, $C5, $91, $84, $A4,
$97, $9C, $B5, $7B, $09, $40, $CC, $42, $39, $67, $6A, $36, $69, $DD, $68, $D0,
$61, $54, $28, $3B, $A2, $F8, $0B, $69, $5E, $4E, $D5, $FA, $6C, $19, $FA, $D5,
$BE, $1B, $9A, $B6, $80, $05, $10, $7A, $5D, $91, $94, $85, $0C, $DC, $EB, $54,
$6C, $50, $1B, $54, $1A, $D5, $E2, $AA, $8F, $31, $31, $8A, $DB, $A2, $17, $D4,
$A1, $4F, $8A, $DE, $27, $68, $19, $24, $C1, $0C, $67, $AE, $81, $FC, $9F, $D7,
$8B, $E4, $5F, $AF, $C7, $EE, $91, $89, $40, $48, $FC, $73, $D4, $D8, $88, $C5,
$06, $09, $01, $D2, $6D, $00, $99, $F5, $10, $0D, $D5, $7C, $AE, $89, $6D, $15,
$8F, $F7, $4F, $19, $B9, $A3, $23, $DB, $C7, $0A, $AD, $18, $08, $5E, $2C, $25,
$E3, $72, $98, $22, $A7, $DF, $E2, $03, $BA, $C2, $39, $A2, $D1, $AE, $5D, $29,
$68, $64, $04, $C5, $64, $34, $21, $A5, $AA, $A9, $A1, $4D, $6A, $0F, $F9, $46,
$20, $4A, $0E, $1C, $22, $81, $EE, $4D, $23, $E4, $A0, $F7, $45, $03, $AD, $C1,
$87, $E9, $FF, $A0, $62, $38, $D2, $F8, $6B, $0E, $B7, $08, $94, $3F, $BE, $C2,
$E3, $F5, $75, $52, $23, $F1, $00, $8C, $C1, $BD, $F1, $F9, $0E, $F1, $50, $3C,
$05, $C2, $E3, $54, $7E, $A7, $D2, $B9, $D0, $74, $E4, $20, $36, $FE, $EF, $E4,
$37, $DE, $F6, $43, $DD, $7E, $F5, $41, $B1, $A3, $1C, $78, $19, $83, $9B, $C4,
$A5, $2B, $46, $58, $9F, $18, $B8, $B6, $F4, $C8, $76, $22, $CD, $F6, $78, $4D,
$B2, $70, $0E, $D3, $D4, $BA, $62, $C9, $6F, $9D, $35, $C9, $96, $C5, $88, $4A,
$D8, $5D, $63, $8C, $63, $06, $51, $42, $76, $96, $C5, $7D, $21, $60, $9B, $DA,
$02, $1F, $41, $BD, $FC, $90, $21, $B9, $34, $F8, $17, $16, $17, $6F, $E6, $C2,
$3B, $1C, $B6, $D5, $DF, $81, $45, $73, $D3, $72, $4E, $96, $CB, $D4, $43, $51,
$58, $64, $58, $14, $D6, $49, $98, $E2, $12, $83, $9F, $5D, $FB, $63, $42, $13,
$C7, $1B, $44, $31, $74, $85, $23, $52, $3F, $0A, $2E, $B4, $A8, $86, $81, $ED,
$15, $77, $5C, $56, $FB, $C6, $7C, $0C, $0E, $82, $B1, $BF, $F7, $FF, $5B, $87,
$BA, $66, $E7, $F0, $13, $27, $6A, $FF, $0B, $62, $AF, $E0, $96, $87, $5B, $2A,
$CB, $79, $C3, $88, $1D, $E8, $31, $2E, $82, $A5, $B8, $BE, $BA, $C1, $70, $E9,
$52, $6C, $87, $5F, $9A, $FB, $D2, $39, $3F, $94, $5B, $A6, $8E, $5B, $62, $1E,
$1F, $76, $FE, $47, $04, $67, $F1, $57, $8D, $73, $BA, $12, $C8, $46, $EF, $FC,
$3B, $2F, $35, $D8, $9F, $B7, $72, $24, $27, $B8, $C6, $CA, $EA, $0D, $CD, $5C,
$E1, $D9, $63, $A4, $B0, $5E, $A1, $72, $C1, $66, $D1, $84, $C1, $35, $BE, $E5,
$EA, $CD, $54, $23, $FD, $33, $F1, $76, $C8, $5E, $F0, $43, $00, $CE, $57, $2F,
$ED, $04, $72, $5E, $60, $AF, $1B, $22, $83, $95, $CD, $5E, $4F, $69, $E0, $20,
$C4, $CA, $64, $06, $63, $25, $35, $EA, $65, $D3, $28, $38, $AC, $91, $5D, $C5,
$09, $06, $74, $19, $EB, $CF, $B3, $F0, $25, $3E, $9E, $F6, $3E, $CD, $0C, $53,
$B3, $DF, $3A, $C9, $49, $8F, $53, $72, $E6, $9C, $AA, $17, $81, $6F, $9A, $C7,
$E5, $E9, $18, $3E, $35, $23, $A7, $78, $2F, $8F, $CB, $E8, $B9, $14, $93, $19,
$AA, $62, $1B, $44, $0C, $54, $45, $38, $34, $52, $82, $8A, $B0, $3E, $75, $0B,
$99, $77, $CD, $E2, $D8, $6E, $81, $D1, $0F, $1C, $6C, $C4, $1C, $FC, $DD, $02,
$4E, $F7, $AB, $CB, $21, $AE, $96, $BB, $41, $06, $66, $FE, $1E, $50, $2F, $FC,
$B8, $28, $14, $F3, $05, $4E, $71, $8F, $EC, $41, $3A, $44, $BF, $2D, $21, $DC,
$B2, $9C, $A0, $55, $3F, $48, $A5, $4D, $62, $F5, $96, $D3, $D2, $85, $FF, $C6,
$56, $D3, $43, $9D, $BC, $8F, $6B, $92, $8C, $39, $65, $D6, $80, $2A, $0D, $05,
$A5, $C5, $7F, $D5, $AD, $19, $F6, $D7, $07, $47, $10, $54, $4C, $EC, $37, $22,
$4F, $63, $8F, $CE, $9E, $7B, $54, $62, $3B, $86, $99, $99, $4A, $26, $BD, $97,
$CC, $7B, $FF, $82, $C3, $6F, $00, $94, $66, $25, $DB, $AC, $99, $E8, $9B, $A3,
$5D, $1F, $19, $34, $4E, $C5, $03, $8F, $96, $0E, $77, $81, $1F, $02, $90, $D8,
$37, $E7, $2F, $C7, $78, $7F, $E5, $A5, $EC, $1B, $8C, $8B, $DC, $78, $01, $5B,
$FD, $83, $00, $94, $2B, $6E, $F1, $C2, $E9, $03, $21, $01, $81, $13, $18, $F9,
$F6, $B2, $E4, $3D, $B6, $A4, $A4, $7D, $56, $5B, $71, $DD, $53, $4B, $95, $12,
$75, $95, $05, $6F, $27, $65, $50, $0D, $1B, $4A, $E3, $6F, $65, $45, $3F, $E2,
$F4, $1D, $B5, $7F, $3D, $A9, $00, $47, $53, $B2, $02, $31, $2F, $40, $2A, $A8,
$94, $77, $35, $00, $50, $1C, $12, $AA, $68, $C0, $11, $C8, $88, $E3, $C2, $69,
$0E, $5C, $60, $4D, $CC, $FB, $CE, $7D, $54, $91, $64, $08, $94, $1A, $63, $C4,
$67, $C7, $3A, $C3, $82, $0C, $BE, $78, $05, $C7, $23, $54, $19, $E9, $C4, $54,
$03, $FB, $6C, $B3, $53, $12, $65, $4F, $06, $B0, $90, $B0, $8E, $C2, $43, $93,
$66, $7B, $63, $7F, $2D, $69, $74, $C1, $0A, $9A, $C0, $D2, $11, $92, $01, $9E,
$01, $E4, $5C, $7F, $DF, $07, $34, $5D, $15, $56, $2C, $F4, $87, $D5, $2B, $3F,
$EC, $69, $8A, $F1, $8D, $F9, $80, $99, $BF, $13, $46, $9D, $1D, $FC, $6D, $DE,
$BE, $85, $AC, $D4, $91, $79, $87, $6E, $86, $B4, $5A, $0A, $4B, $6E, $B6, $15,
$CC, $33, $7E, $12, $52, $76, $B9, $20, $72, $C5, $9F, $5A, $A9, $03, $6F, $84,
$95, $00, $1C, $67, $DA, $45, $52, $1C, $C3, $DF, $E5, $32, $1F, $10, $12, $CE,
$B3, $4B, $37, $80, $32, $51, $BB, $2E, $BB, $A4, $55, $6B, $65, $B4, $95, $ED,
$C1, $0E, $35, $33, $BA, $0B, $03, $CB, $85, $85, $AE, $52, $1E, $CD, $90, $CB,
$72, $6E, $7B, $8D, $F3, $95, $75, $19, $C7, $ED, $8A, $9A, $2D, $E7, $72, $AC,
$0C, $53, $38, $27, $3A, $B3, $3A, $43, $E5, $69, $5A, $DC, $BE, $B4, $62, $37,
$7A, $FA, $C5, $BC, $5D, $29, $FD, $5C, $AD, $96, $6A, $AB, $48, $05, $BC, $46,
$10, $3C, $12, $45, $F5, $46, $56, $51, $21, $0B, $B0, $EC, $F1, $37, $59, $AD,
$9C, $14, $C2, $F8, $EB, $E3, $C4, $CE, $B8, $92, $17, $FA, $8A, $8E, $D8, $3C,
$2C, $7F, $58, $9B, $9D, $FA, $2A, $FD, $B3, $42, $61, $97, $FB, $71, $79, $75,
$8D, $C8, $FC, $69, $D4, $6C, $DA, $8F, $CD, $82, $FB, $F7, $DF, $A5, $13, $7E,
$02, $64, $17, $BE, $75, $0B, $FB, $C8, $4A, $BB, $F3, $98, $79, $50, $91, $83,
$CF, $69, $DF, $5D, $F9, $F2, $66, $BB, $9C, $F6, $E8, $D2, $A0, $9F, $FC, $87,
$3D, $F2, $AD, $9F, $F2, $8B, $37, $79, $27, $83, $3F, $FA, $26, $BA, $4D, $30,
$F5, $37, $D1, $FA, $BE, $79, $81, $B1, $E8, $43, $B4, $1A, $71, $4E, $CD, $8A,
$23, $E0, $D7, $02, $A6, $69, $91, $13, $5B, $50, $5C, $08, $B3, $0D, $13, $A7,
$DB, $BB, $F0, $1C, $FC, $11, $4D, $F5, $7E, $B6, $CE, $1D, $0C, $5D, $AE, $90,
$69, $92, $51, $7B, $E1, $C6, $BD, $D5, $D0, $32, $C3, $69, $EC, $BA, $47, $5F,
$6A, $2F, $84, $BE, $AA, $2E, $5C, $6A, $1E, $1D, $5A, $E5, $1B, $48, $C3, $51,
$C6, $94, $C4, $E4, $17, $5D, $9C, $34, $2C, $F1, $57, $50, $1E, $5A, $86, $C1,
$8D, $0D, $6E, $EC, $55, $83, $5C, $EE, $E8, $7C, $4B, $4C, $E5, $D5, $8B, $B8,
$31, $63, $19, $10, $66, $90, $50, $19, $1E, $AF, $85, $4D, $EE, $8D, $A2, $97,
$09, $18, $9A, $9A, $2F, $33, $FB, $E2, $EB, $9F, $3D, $D3, $86, $05, $EF, $F0,
$C1, $7D, $B0, $22, $10, $96, $B4, $E8, $E8, $8C, $2E, $76, $A3, $27, $CA, $0A,
$5E, $B0, $83, $13, $07, $33, $C5, $8C, $7D, $E9, $1B, $5A, $9E, $04, $87, $E6,
$DB, $0E, $11, $61, $C1, $97, $D5, $B3, $28, $90, $9D, $E1, $C6, $37, $B6, $24,
$7B, $0A, $A2, $28, $1F, $75, $5A, $9F, $BE, $47, $50, $96, $F5, $FF, $50, $2F,
$A0, $37, $63, $8E, $0F, $50, $E9, $97, $6C, $9B, $39, $98, $32, $6D, $07, $F0,
$AD, $2C, $56, $02, $E9, $29, $58, $52, $91, $28, $64, $0F, $33, $00, $89, $69,
$C7, $2B, $4D, $50, $DA, $63, $56, $4A, $16, $BD, $A8, $AA, $F6, $F6, $1F, $FC,
$E5, $7E, $4E, $6E, $DA, $10, $D8, $7F, $C8, $20, $81, $D9, $AD, $55, $41, $01,
$48, $CF, $E7, $E1, $FB, $7D, $86, $D7, $E6, $1E, $91, $8E, $F0, $51, $0D, $72,
$7A, $D6, $DF, $B9, $99, $D9, $65, $C7, $73, $66, $52, $B0, $A3, $15, $75, $23,
$9A, $34, $9F, $88, $5B, $6C, $E1, $13, $AF, $91, $74, $26, $06, $C2, $43, $9E,
$68, $2E, $FF, $E9, $04, $34, $E9, $67, $AF, $10, $AA, $07, $3D, $49, $C8, $51,
$FD, $C5, $9C, $7F, $76, $CC, $18, $22, $29, $2C, $2D, $D6, $5D, $25, $CF, $53,
$99, $0C, $6F, $76, $B2, $E5, $B0, $E2, $04, $BF, $63, $C8, $AC, $C8, $2C, $6A,
$8F, $58, $85, $85, $3C, $E8, $1F, $BE, $AD, $7B, $D8, $FD, $0C, $CE, $FD, $A3,
$C8, $94, $3F, $28, $6E, $F4, $C5, $CE, $FA, $52, $F5, $AF, $FD, $2F, $F6, $3E,
$DC, $DD, $EA, $A8, $7A, $A2, $59, $1E, $E2, $C6, $61, $4C, $D5, $7A, $CF, $F1,
$0B, $82, $8C, $A1, $8E, $EE, $76, $B4, $B9, $A1, $F4, $2E, $84, $CE, $5D, $F3,
$E2, $57, $A4, $0D, $FE, $DD, $9D, $5C, $F1, $13, $45, $EC, $C8, $08, $E2, $EA,
$A0, $C7, $7D, $E9, $DD, $FB, $EE, $50, $CD, $7C, $73, $53, $24, $9B, $4A, $C0,
$57, $08, $C5, $C8, $03, $F7, $29, $AB, $E6, $8C, $CC, $2B, $CD, $51, $02, $2B,
$97, $88, $84, $B7, $04, $E3, $45, $59, $2F, $EC, $AF, $5A, $1E, $DA, $D3, $17,
$72, $D0, $A3, $4B, $A5, $7C, $18, $EF, $FD, $86, $81, $E6, $CA, $64, $56, $25,
$A1, $3B, $A2, $60, $C2, $9C, $0E, $82, $F3, $48, $6B, $D0, $6B, $45, $BB, $8E,
$90, $0A, $ED, $B2, $B7, $EE, $0E, $26, $F5, $A3, $5C, $14, $7D, $27, $76, $36,
$16, $9B, $A6, $1C, $81, $3F, $9A, $B9, $62, $B3, $FE, $3D, $CB, $41, $5D, $72,
$BD, $CC, $1F, $83, $88, $64, $D2, $10, $D6, $69, $30, $0C, $EB, $BA, $1D, $D9,
$B9, $D9, $1C, $2B, $6F, $66, $B8, $85, $B0, $EC, $74, $0D, $A2, $B5, $E5, $66,
$78, $8F, $54, $3F, $35, $B0, $6B, $91, $0C, $EE, $4F, $51, $E7, $5B, $D1, $7A,
$61, $A2, $9C, $E2, $42, $C2, $CD, $D2, $B9, $41, $7E, $28, $08, $A0, $32, $60,
$80, $29, $C0, $4F, $EA, $BB, $FB, $4B, $F6, $7E, $5C, $BA, $66, $05, $EC, $BC,
$64, $A5, $F3, $F1, $27, $58, $CF, $25, $EE, $A5, $90, $A6, $05, $22, $29, $D1,
$1A, $9D, $D4, $A4, $2F, $F3, $51, $5A, $1E, $D0, $54, $66, $B5, $BE, $40, $B4,
$77, $C8, $F3, $A4, $A6, $CF, $E2, $57, $8D, $F7, $0B, $06, $DB, $7B, $FC, $0D,
$04, $1A, $89, $3A, $61, $B8, $1E, $9B, $12, $B2, $07, $C5, $F6, $6A, $91, $D1,
$91, $7F, $74, $B9, $D0, $1C, $0D, $8B, $06, $85, $CD, $7C, $F3, $A4, $E2, $AD,
$CB, $A4, $26, $62, $F1, $BA, $2C, $BA, $0F, $91, $1F, $37, $77, $A0, $11, $C6,
$0F, $7A, $07, $07, $EE, $E1, $0E, $5E, $A1, $F2, $AA, $F7, $ED, $72, $02, $F3,
$61, $02, $72, $E7, $06, $EF, $6A, $1E, $34, $9D, $C3, $8D, $61, $FA, $9D, $BE,
$51, $0F, $7F, $A3, $8A, $D9, $F8, $26, $3E, $AF, $FD, $69, $B5, $5D, $BC, $3C,
$40, $88, $E5, $F6, $D2, $D8, $21, $C5, $42, $45, $F8, $1A, $0A, $26, $8C, $04,
$95, $5C, $51, $7B, $A4, $F4, $DB, $D9, $81, $2F, $72, $13, $1A, $9F, $E0, $9A,
$D1, $A8, $2F, $FB, $FF, $4F, $0F, $66, $D1, $CB, $AC, $6B, $D7, $9D, $A4, $AF,
$2B, $65, $15, $C0, $8A, $33, $BF, $44, $4B, $0D, $79, $84, $6E, $61, $F1, $35,
$2B, $52, $D0, $71, $B2, $18, $5B, $0E, $0C, $D2, $A2, $9D, $0C, $5E, $93, $AF,
$02, $CB, $0F, $1F, $E0, $59, $77, $D5, $F2, $89, $A9, $0C, $7F, $B1, $55, $1B,
$67, $B4, $22, $53, $67, $52, $06, $D7, $26, $6B, $4A, $AD, $29, $13, $50, $D6,
$1F, $BF, $1B, $4A, $B3, $D0, $99, $45, $5F, $EF, $40, $8E, $4D, $A4, $43, $DF,
$39, $5F, $16, $1B, $CC, $E1, $18, $D3, $48, $F9, $40, $DF, $14, $D6, $86, $B7,
$AD, $F8, $7B, $AD, $AC, $0E, $25, $79, $D1, $AC, $2F, $31, $46, $84, $36, $16,
$0A, $F3, $B2, $6B, $37, $A4, $04, $53, $1E, $FE, $24, $F0, $1B, $6D, $D1, $DE,
$55, $F7, $CA, $8F, $74, $3F, $B2, $1C, $88, $36, $46, $04, $EB, $23, $8A, $DD,
$1D, $FF, $99, $8C, $B3, $80, $63, $15, $EB, $0D, $84, $ED, $AE, $16, $77, $CA,
$F4, $C6, $92, $E5, $E1, $96, $03, $BB, $0C, $BF, $5C, $B1, $08, $AD, $39, $ED,
$48, $F6, $BD, $E9, $57, $9D, $48, $AD, $A7, $FB, $F7, $25, $6E, $3B, $3C, $24,
$26, $88, $31, $E2, $71, $1B, $52, $9C, $B0, $7E, $6C, $45, $E0, $46, $5F, $9D,
$1F, $2E, $F1, $5B, $81, $44, $F5, $F2, $33, $C5, $D4, $13, $FA, $78, $4B, $69,
$5F, $5F, $CC, $9E, $D2, $FF, $05, $B9, $11, $5B, $99, $C4, $F5, $EA, $4A, $26,
$9C, $B5, $BC, $54, $2A, $1B, $0E, $98, $11, $A4, $12, $DB, $EF, $2A, $8B, $7D,
$BB, $8D, $93, $FF, $50, $97, $89, $A7, $0B, $A6, $02, $3C, $86, $9D, $B9, $6B,
$DC, $97, $DB, $4A, $EF, $F7, $76, $A5, $9F, $CD, $21, $1E, $19, $86, $FA, $32,
$3E, $05, $CC, $84, $BC, $F1, $98, $85, $EF, $18, $4E, $A9, $E0, $6B, $24, $72,
$CB, $70, $DB, $02, $B7, $32, $87, $AA, $69, $1B, $D6, $44, $3C, $32, $05, $84,
$27, $2D, $03, $87, $C0, $EB, $06, $2C, $40, $40, $A4, $98, $01, $0A, $C9, $39,
$3F, $5D, $83, $F3, $BE, $7A, $6C, $1D, $5C, $64, $C5, $B7, $5D, $DD, $C7, $11,
$64, $D5, $90, $2E, $4A, $6D, $BA, $DD, $4C, $26, $92, $6E, $AA, $59, $6C, $93,
$24, $7C, $51, $DD, $C5, $FD, $D2, $3B, $7F, $4E, $20, $64, $D2, $E9, $92, $A8,
$BF, $13, $1A, $59, $2D, $D6, $C2, $54, $D6, $E2, $F8, $9E, $0B, $6E, $53, $1A,
$05, $38, $BF, $E6, $4F, $2B, $D0, $00, $B5, $04, $02, $AA, $C4, $AB, $F6, $7C,
$C7, $07, $AB, $BC, $F9, $07, $56, $46, $9C, $7C, $3E, $80, $77, $D2, $7F, $8C,
$EA, $62, $C7, $B2, $F9, $E9, $41, $0E, $0C, $B2, $21, $A4, $90, $06, $AB, $E0,
$44, $CD, $EB, $07, $9E, $E2, $58, $78, $D9, $50, $68, $2C, $41, $A3, $07, $DF,
$06, $74, $17, $6C, $5D, $62, $20, $7E, $A3, $48, $82, $C7, $63, $3F, $FF, $FB,
$9D, $88, $4A, $48, $61, $7C, $20, $6B, $68, $D9, $3C, $69, $D3, $1F, $AE, $5C,
$F0, $3A, $64, $F5, $AC, $8D, $EC, $E9, $7A, $A9, $9B, $00, $0A, $CE, $57, $8C,
$75, $16, $38, $0C, $78, $E5, $E5, $05, $56, $EE, $10, $D8, $3F, $09, $1D, $76,
$56, $69, $D8, $5C, $E9, $3C, $42, $4E, $2C, $38, $66, $C7, $D7, $C3, $54, $D7,
$1D, $B8, $5D, $EC, $B2, $9C, $48, $5D, $09, $B6, $52, $32, $6F, $63, $0E, $CD,
$89, $61, $C7, $83, $19, $7F, $B1, $B9, $9E, $A2, $D0, $46, $EE, $CE, $34, $B1,
$AC, $6C, $81, $52, $B5, $B6, $FD, $C2, $13, $48, $22, $2F, $94, $88, $D3, $75,
$7F, $AB, $3A, $01, $E7, $04, $95, $CE, $20, $FA, $8D, $C8, $A7, $B0, $4F, $84,
$F9, $36, $51, $7D, $A7, $37, $37, $96, $1F, $EF, $D8, $62, $5C, $90, $15, $47,
$CB, $0D, $9F, $FA, $4C, $3A, $9A, $C2, $2F, $27, $F2, $EC, $93, $C6, $2E, $79,
$4D, $10, $D4, $EA, $8C, $F9, $10, $56, $5C, $0E, $0D, $A9, $57, $C4, $DF, $63,
$EB, $61, $59, $59, $A8, $A0, $75, $EF, $F4, $24, $5F, $85, $90, $6C, $68, $06,
$7A, $F7, $F2, $13, $47, $BF, $40, $5C, $8C, $89, $E8, $47, $A6, $4C, $F1, $0E,
$31, $09, $F1, $CB, $E6, $26, $6A, $24, $5F, $42, $F0, $BA, $7C, $77, $12, $C1,
$D7, $B5, $76, $35, $A2, $07, $EF, $3B, $9E, $EF, $B2, $BD, $27, $FF, $75, $E5,
$4D, $42, $2A, $37, $F8, $C2, $45, $D3, $41, $7A, $97, $62, $A9, $73, $BF, $D0,
$B2, $83, $A0, $72, $9A, $EE, $AD, $22, $63, $E5, $48, $76, $3E, $BE, $6B, $51,
$3F, $05, $F1, $7E, $F3, $CC, $35, $7A, $9B, $F8, $A7, $6B, $9A, $D1, $70, $1B,
$18, $7F, $96, $38, $3F, $80, $B5, $A9, $95, $90, $A9, $CE, $53, $EC, $8F, $F6,
$DE, $35, $AE, $31, $F0, $69, $1D, $D7, $73, $84, $F1, $0A, $A3, $F0, $37, $F9,
$DE, $D0, $DC, $0C, $6D, $85, $28, $3B, $D6, $5D, $FA, $52, $4C, $65, $B9, $22,
$09, $68, $62, $74, $19, $F2, $AE, $7F, $BF, $EC, $BC, $46, $4A, $26, $53, $AE,
$5B, $0C, $B2, $16, $70, $F3, $DD, $62, $67, $5B, $5C, $BB, $D0, $1E, $B9, $6E,
$A2, $B5, $4A, $9A, $67, $42, $C0, $D0, $77, $06, $E8, $B0, $28, $CA, $3F, $C4,
$C0, $F3, $67, $D6, $98, $3D, $E9, $89, $A7, $F0, $13, $35, $4F, $ED, $CE, $2A,
$86, $35, $F4, $BB, $BB, $EE, $B0, $2E, $97, $0E, $7F, $58, $9E, $71, $02, $F1,
$C9, $8D, $04, $06, $0D, $DD, $7B, $09, $B9, $69, $97, $83, $5A, $9A, $63, $04,
$46, $AC, $28, $66, $4F, $4E, $B1, $8E, $8A, $AF, $48, $8E, $84, $56, $CC, $5C,
$1D, $8A, $25, $8A, $56, $D3, $0C, $8E, $27, $0C, $A0, $EE, $B9, $B5, $33, $CE,
$FF, $B8, $CD, $1A, $BC, $95, $45, $C5, $ED, $1B, $5A, $81, $E9, $14, $12, $40,
$6F, $75, $09, $37, $45, $5B, $56, $86, $0C, $B6, $E0, $D1, $29, $9F, $52, $D0,
$16, $4E, $10, $E6, $40, $7E, $02, $AA, $4A, $B6, $26, $68, $3C, $E3, $1A, $5B,
$4B, $1A, $D0, $19, $0A, $2D, $16, $FC, $4A, $22, $A3, $D4, $3D, $1B, $6D, $D2,
$0A, $D9, $EC, $EC, $EE, $5B, $32, $B1, $8D, $40, $03, $C4, $97, $D2, $81, $08,
$87, $7F, $81, $4D, $53, $81, $C5, $0B, $40, $FF, $FF, $B3, $F2, $A6, $9B, $9E,
$53, $72, $44, $8A, $BC, $02, $E1, $CC, $0A, $66, $52, $5E, $69, $4B, $05, $26,
$97, $9A, $76, $76, $E2, $16, $F7, $62, $14, $79, $26, $91, $81, $A9, $06, $38,
$60, $1E, $23, $19, $90, $8C, $3F, $E3, $2A, $AE, $07, $2C, $38, $7B, $4C, $69,
$57, $14, $B9, $C3, $64, $68, $8B, $42, $EB, $95, $3D, $A1, $6E, $27, $1B, $95,
$87, $0B, $27, $2C, $34, $07, $F0, $50, $A0, $2A, $40, $55, $0B, $7D, $F4, $3C,
$25, $53, $AC, $0C, $76, $2C, $5E, $FF, $BB, $B9, $AF, $BB, $9E, $B0, $FC, $F3,
$52, $1A, $68, $97, $70, $58, $0D, $CD, $0D, $66, $D7, $19, $24, $AA, $C6, $79,
$79, $72, $A0, $F6, $6D, $8E, $47, $C2, $17, $70, $EA, $63, $DD, $83, $DC, $ED,
$49, $53, $F8, $A2, $18, $59, $FF, $8C, $AE, $3A, $D8, $73, $75, $39, $9B, $10,
$17, $5E, $78, $28, $2E, $F1, $73, $DB, $C4, $19, $F1, $3B, $80, $D6, $63, $CA,
$7A, $E0, $39, $47, $BC, $E0, $99, $87, $47, $D3, $8E, $1E, $E5, $B3, $60, $4C,
$27, $4C, $C8, $EF, $89, $1D, $3A, $5E, $A7, $B9, $65, $A3, $8B, $AC, $F8, $73,
$B5, $08, $7D, $D7, $1D, $7D, $0A, $57, $A8, $E2, $EB, $44, $8B, $DA, $DF, $E9,
$D9, $9E, $8F, $D9, $0F, $93, $58, $29, $3C, $56, $C2, $D5, $17, $25, $79, $D7,
$C4, $99, $D4, $2D, $BF, $37, $81, $94, $75, $FE, $80, $11, $3C, $9E, $E1, $9A,
$A7, $23, $FE, $0D, $71, $40, $96, $E6, $9C, $62, $48, $6F, $C9, $14, $9F, $F2,
$B4, $96, $D3, $0F, $2A, $61, $95, $6A, $E5, $34, $AF, $E1, $E4, $9B, $7A, $A8,
$8C, $DF, $64, $71, $F7, $30, $D2, $49, $BD, $B9, $DF, $71, $3B, $0E, $8C, $10,
$D2, $40, $AC, $ED, $8D, $5A, $14, $B0, $42, $19, $BB, $F0, $CB, $90, $D9, $D9,
$61, $AB, $91, $2E, $D6, $34, $D8, $97, $08, $9F, $42, $81, $A3, $BA, $A8, $0E,
$FC, $3D, $75, $8D, $75, $07, $EC, $46, $C7, $E1, $A3, $06, $E5, $68, $90, $D6,
$03, $7D, $8E, $3B, $11, $C5, $EE, $08, $D1, $38, $17, $C4, $94, $91, $F0, $6F,
$A1, $95, $2E, $32, $B2, $46, $AD, $6D, $2D, $13, $DC, $B7, $6F, $F0, $C0, $A5,
$80, $C2, $15, $B7, $D4, $45, $02, $E4, $2F, $18, $1D, $AF, $77, $AD, $B4, $A3,
$76, $BF, $72, $56, $20, $0E, $79, $54, $F7, $D5, $F9, $A9, $2C, $C3, $68, $C7,
$4F, $55, $B2, $56, $30, $BF, $60, $86, $8C, $40, $A7, $1C, $9A, $0D, $2D, $EA,
$93, $5F, $A6, $EA, $B0, $3D, $12, $EB, $9E, $54, $83, $28, $6F, $8A, $73, $13,
$CA, $5F, $0F, $74, $2D, $88, $08, $CC, $A0, $F4, $E1, $4E, $AC, $55, $4F, $25,
$F7, $50, $AF, $DF, $68, $60, $F6, $E9, $4C, $1F, $07, $5F, $EF, $B2, $19, $48,
$A9, $48, $B9, $8A, $A6, $23, $CC, $FB, $AF, $03, $45, $45, $CD, $07, $3A, $EA,
$D0, $B0, $40, $FB, $42, $07, $D1, $E2, $48, $73, $C8, $E7, $AC, $06, $12, $98,
$66, $F5, $99, $FA, $4F, $69, $59, $1A, $DB, $4B, $37, $53, $BD, $8E, $5C, $CC,
$C0, $D2, $8A, $A6, $E0, $2A, $59, $FA, $36, $CF, $CD, $EF, $43, $BE, $4B, $FB,
$7F, $20, $F3, $51, $0F, $1C, $68, $9D, $62, $FC, $FC, $8D, $68, $1A, $ED, $18,
$10, $41, $88, $0D, $3A, $F4, $2F, $C5, $45, $C1, $85, $31, $7E, $09, $03, $C4,
$46, $50, $41, $C4, $6A, $3D, $87, $41, $8D, $EB, $F5, $72, $EC, $06, $CC, $78,
$82, $C6, $87, $56, $D2, $1E, $98, $60, $FD, $92, $55, $62, $8F, $4B, $8E, $A7,
$C5, $B7, $46, $F7, $46, $37, $26, $95, $1C, $21, $61, $1A, $04, $A2, $7C, $78,
$F7, $6B, $35, $8F, $CD, $AE, $A5, $99, $D0, $1D, $8B, $97, $10, $33, $51, $CB,
$16, $9C, $C2, $C1, $3D, $39, $A5, $18, $7F, $55, $1A, $AD, $CA, $39, $7A, $A5,
$C4, $50, $E8, $CD, $6D, $21, $90, $5B, $33, $13, $79, $14, $41, $DF, $6D, $E4,
$72, $98, $30, $95, $F5, $53, $FC, $BD, $66, $2B, $ED, $6E, $47, $C8, $6E, $F8,
$0A, $81, $9B, $50, $6D, $A6, $E2, $10, $5D, $03, $D7, $59, $22, $A5, $BD, $48,
$C7, $14, $47, $AD, $33, $D4, $7E, $42, $A5, $B5, $4E, $0F, $B2, $39, $91, $FE,
$37, $27, $11, $D8, $C9, $0D, $6C, $08, $79, $03, $F9, $34, $61, $15, $64, $5C,
$80, $80, $85, $B5, $CA, $5F, $09, $B1, $5C, $F2, $86, $38, $89, $58, $C8, $0A,
$E1, $0B, $D6, $DD, $EF, $62, $A9, $CF, $67, $CC, $A3, $78, $04, $BF, $82, $9D,
$F8, $D8, $DE, $DD, $2E, $4B, $AD, $CE, $93, $1A, $C9, $70, $FF, $6B, $69, $7F,
$7A, $3D, $0D, $5E, $D5, $8A, $36, $29, $76, $58, $30, $6B, $D8, $FD, $7C, $DC,
$9C, $42, $78, $56, $A5, $44, $45, $0A, $C2, $74, $71, $18, $B1, $6C, $50, $C8,
$FA, $8B, $6D, $B8, $8A, $35, $E4, $1A, $E3, $FA, $5D, $DE, $9A, $AD, $DC, $F7,
$B3, $0C, $45, $37, $37, $D1, $7A, $79, $0B, $E9, $F1, $56, $E7, $C1, $38, $41,
$18, $48, $15, $BA, $1F, $7F, $D0, $B1, $31, $08, $94, $5C, $AB, $8C, $33, $21,
$B2, $10, $80, $C4, $C4, $2A, $D7, $90, $AA, $D8, $91, $31, $2F, $43, $B9, $CC,
$15, $42, $64, $46, $0F, $33, $3B, $64, $D2, $4F, $40, $CE, $5F, $EB, $D7, $FD,
$87, $B9, $FB, $28, $A8, $D3, $83, $0B, $16, $35, $0E, $74, $6E, $57, $1D, $1F,
$57, $7B, $8C, $9B, $5F, $D2, $89, $C8, $67, $04, $03, $1D, $64, $13, $ED, $7F,
$EB, $F9, $AB, $3C, $A4, $B7, $B0, $58, $75, $4F, $6F, $90, $02, $31, $EF, $15,
$3A, $AE, $9D, $89, $9F, $15, $A8, $3E, $19, $12, $81, $37, $8B, $4D, $98, $68,
$7B, $7E, $1F, $CC, $45, $86, $57, $5A, $90, $BA, $88, $38, $82, $E3, $6F, $AF,
$42, $86, $07, $5F, $A9, $DC, $F0, $8B, $33, $31, $7F, $14, $47, $DE, $31, $11,
$69, $2B, $CB, $33, $CD, $E7, $2B, $E7, $C3, $44, $3D, $6D, $F0, $53, $5E, $C7,
$62, $70, $8B, $7C, $2A, $E5, $02, $42, $BD, $E0, $EA, $FD, $B9, $16, $1A, $76,
$C9, $B2, $B9, $B7, $E6, $18, $5A, $7E, $E8, $8C, $88, $64, $D8, $82, $2B, $91,
$90, $C7, $E9, $79, $5C, $30, $25, $77, $93, $57, $3A, $FB, $40, $15, $3A, $FE,
$CF, $C7, $72, $B2, $F8, $58, $46, $33, $13, $4A, $6A, $1E, $73, $B3, $F5, $DD,
$76, $66, $37, $46, $9F, $61, $55, $9B, $AB, $3A, $02, $2A, $A2, $D1, $E4, $12,
$06, $03, $78, $74, $6C, $B6, $6D, $90, $65, $A2, $A4, $9E, $0A, $C7, $97, $E7,
$59, $8A, $A1, $3E, $DE, $FE, $14, $28, $0F, $2C, $49, $47, $51, $63, $C4, $C0,
$94, $EA, $3E, $13, $51, $98, $AD, $C3, $21, $AB, $2D, $CC, $09, $4F, $C2, $73,
$A2, $EF, $8B, $7E, $6F, $F6, $50, $8A, $81, $E7, $99, $25, $8D, $65, $4A, $C6,
$47, $7D, $EB, $16, $E9, $8B, $D9, $31, $8C, $5C, $E5, $38, $9A, $E8, $D0, $5A,
$F5, $7E, $CA, $8F, $F2, $9C, $B3, $8C, $78, $C6, $7D, $80, $ED, $FE, $8F, $DF,
$5E, $17, $9B, $10, $96, $FA, $6C, $14, $CD, $51, $BB, $74, $87, $1B, $93, $7E,
$3E, $B3, $7A, $7A, $EB, $7B, $0F, $ED, $6C, $38, $17, $E1, $2C, $F5, $D2, $83,
$2B, $16, $67, $2D, $78, $36, $1C, $AF, $80, $7E, $75, $AC, $83, $EB, $ED, $C9,
$4B, $0E, $94, $D4, $8A, $86, $F2, $2B, $9B, $1C, $D5, $A7, $B2, $40, $ED, $25,
$05, $7C, $AF, $30, $7C, $93, $4F, $A9, $25, $F3, $F3, $7E, $75, $22, $32, $5F,
$B2, $81, $FC, $B9, $5D, $F1, $9F, $89, $C1, $B8, $0A, $3E, $B3, $C3, $25, $AF,
$AC, $45, $D1, $8C, $23, $BB, $7B, $71, $30, $EC, $23, $6D, $76, $87, $0F, $F9,
$40, $6E, $B1, $24, $27, $2C, $0C, $B2, $E2, $BF, $7B, $65, $60, $31, $5D, $CC,
$DD, $DE, $0C, $1C, $58, $8F, $E5, $70, $4C, $7D, $CB, $35, $5F, $1A, $51, $43,
$4D, $33, $AF, $08, $3B, $FD, $E7, $1F, $35, $EF, $13, $A7, $F2, $CA, $26, $BA,
$12, $80, $2B, $56, $DC, $75, $33, $08, $46, $85, $2C, $4D, $B8, $07, $7A, $D3,
$AB, $E4, $3D, $A9, $4E, $36, $A5, $D5, $7B, $72, $70, $5C, $E7, $86, $56, $0A,
$B3, $C2, $88, $ED, $6F, $B2, $21, $EA, $DC, $46, $CB, $95, $6B, $FA, $6E, $2F,
$EA, $BB, $47, $81, $CA, $B2, $64, $29, $16, $EC, $C1, $9B, $1C, $67, $5B, $0D,
$CC, $38, $88, $0A, $AD, $5A, $5F, $B8, $3B, $78, $8F, $5A, $2E, $80, $B3, $74,
$02, $FE, $D1, $80, $36, $53, $36, $FF, $01, $96, $0F, $58, $C6, $C7, $48, $15,
$8C, $8D, $A6, $FE, $E8, $60, $0E, $E3, $C3, $0D, $19, $FC, $16, $EC, $82, $C9,
$15, $67, $EA, $08, $10, $FD, $EE, $3E, $88, $D8, $4A, $C7, $A9, $26, $76, $43,
$7A, $3E, $5C, $AC, $4E, $6D, $22, $53, $51, $A0, $0D, $BF, $98, $3F, $A3, $98,
$DD, $8F, $A1, $F2, $35, $B1, $03, $6C, $C1, $03, $9B, $67, $B1, $33, $DD, $64,
$4B, $F8, $E5, $5B, $05, $DB, $5C, $0C, $BB, $A4, $3A, $28, $1F, $48, $3A, $C6,
$08, $83, $3A, $C1, $05, $CF, $A0, $E4, $76, $5C, $9D, $7B, $7C, $E4, $BD, $7D,
$7D, $B6, $8D, $A0, $C2, $30, $23, $D8, $1C, $84, $1D, $2C, $2E, $AA, $7E, $BB,
$66, $BC, $24, $37, $FF, $C5, $75, $D5, $D5, $97, $36, $F4, $50, $FF, $0E, $4A,
$EF, $94, $FE, $91, $40, $A9, $B9, $91, $13, $33, $3D, $DD, $D4, $CD, $99, $BB,
$B5, $5B, $D4, $2E, $2E, $40, $2C, $0E, $8C, $FF, $9A, $76, $C4, $EC, $18, $37,
$2C, $B4, $3F, $03, $94, $86, $D7, $01, $58, $EC, $00, $8B, $08, $0B, $D0, $EB,
$D1, $17, $C0, $7E, $23, $C3, $D3, $EF, $30, $A7, $5B, $5D, $55, $FA, $9B, $9C,
$CC, $F0, $75, $CB, $5F, $48, $82, $7D, $6C, $26, $7C, $F5, $22, $13, $C9, $0E,
$70, $A5, $CC, $89, $75, $C0, $0E, $13, $F1, $92, $BB, $46, $1A, $F8, $43, $4A,
$71, $3C, $BD, $D0, $44, $68, $76, $3A, $2B, $69, $86, $3A, $A2, $9A, $42, $4C,
$2C, $15, $48, $E8, $67, $0D, $A3, $4D, $E3, $D7, $0D, $73, $8C, $19, $2E, $FB,
$D7, $E8, $73, $57, $75, $DE, $F7, $5C, $88, $0E, $78, $8B, $B0, $10, $54, $6D,
$8A, $6F, $8D, $98, $47, $69, $FC, $28, $E8, $5B, $F8, $2D, $24, $B7, $A7, $12,
$39, $E7, $AA, $3A, $C2, $00, $18, $82, $5F, $53, $9A, $1A, $B8, $82, $3F, $DD,
$EC, $24, $37, $E8, $B1, $87, $6B, $5A, $E0, $3A, $AC, $89, $06, $4C, $C4, $B5,
$9F, $5A, $C8, $AE, $5C, $57, $27, $64, $86, $31, $07, $A6, $93, $64, $52, $2C,
$31, $6C, $3D, $29, $AD, $D8, $31, $A0, $E0, $AC, $E4, $AB, $7C, $56, $5B, $97,
$FC, $B5, $70, $AE, $08, $03, $9D, $41, $57, $1F, $DE, $4D, $B9, $C9, $C4, $C9,
$30, $12, $E4, $42, $0F, $64, $BC, $9C, $3F, $BA, $82, $D5, $02, $EA, $19, $05,
$86, $76, $78, $DB, $A7, $02, $B5, $DE, $46, $30, $BD, $DD, $45, $2B, $5F, $62,
$57, $64, $18, $ED, $F0, $3A, $5C, $63, $A2, $C4, $5C, $12, $4B, $B8, $4A, $3F,
$71, $60, $F4, $DB, $6B, $BE, $A1, $F6, $80, $F2, $22, $E3, $9E, $05, $03, $F2,
$79, $A1, $57, $22, $85, $CE, $AE, $05, $B5, $BE, $EC, $1E, $C6, $5E, $F2, $E8,
$BA, $DF, $26, $90, $0D, $80, $EC, $9B, $1A, $9A, $29, $EF, $EE, $01, $64, $25,
$89, $3A, $AC, $BC, $9C, $A6, $06, $E4, $37, $0D, $AF, $A1, $28, $30, $A0, $EC,
$B5, $06, $C2, $13, $49, $DC, $15, $4E, $44, $C3, $03, $7C, $B8, $3C, $A9, $E8,
$A9, $FD, $20, $1A, $ED, $91, $F1, $1B, $03, $01, $3C, $78, $6E, $BB, $F4, $DC,
$C1, $8C, $76, $7A, $75, $08, $FF, $BB, $AB, $D3, $8A, $D3, $57, $75, $59, $DC,
$D5, $AC, $BE, $56, $BB, $C3, $8D, $06, $5C, $05, $A9, $A7, $93, $A7, $7C, $3B,
$01, $3C, $1B, $FA, $1D, $09, $C6, $B9, $21, $2C, $A0, $DB, $62, $A8, $70, $5F,
$0D, $B2, $40, $06, $70, $FF, $51, $D5, $E9, $7F, $6B, $6B, $42, $3E, $4D, $E4,
$56, $BC, $D8, $03, $D2, $0C, $42, $0A, $E7, $4C, $89, $06, $DE, $34, $43, $A2,
$E4, $6D, $52, $B7, $C7, $10, $54, $A3, $16, $32, $FF, $0B, $6B, $93, $E1, $40,
$B9, $6F, $28, $3D, $71, $A3, $71, $5A, $ED, $3E, $AC, $77, $94, $DB, $C9, $6D,
$B2, $30, $23, $9B, $64, $77, $37, $7E, $90, $FC, $D9, $ED, $D2, $E3, $A7, $CB,
$FE, $A1, $A6, $E9, $12, $3B, $CC, $0F, $9A, $28, $D6, $D5, $AC, $1C, $3B, $8E,
$D1, $4A, $C6, $4C, $46, $54, $BA, $12, $EE, $84, $0D, $4F, $E9, $C7, $87, $DB,
$F0, $99, $9C, $41, $5D, $1B, $53, $D3, $0F, $4E, $EF, $57, $2A, $49, $58, $4E,
$1A, $60, $33, $1B, $FF, $DE, $6B, $FA, $DE, $44, $D6, $F8, $E7, $82, $B6, $31,
$4E, $93, $C5, $E8, $00, $A7, $86, $19, $77, $36, $12, $CA, $BA, $5A, $DB, $B4,
$BA, $B9, $F3, $A8, $28, $7E, $3F, $7F, $70, $BF, $FD, $B6, $F4, $B4, $39, $80,
$13, $FE, $13, $35, $84, $CA, $5B, $40, $BE, $E1, $27, $6E, $16, $70, $CD, $86,
$9C, $13, $23, $80, $21, $4D, $5F, $36, $3C, $43, $8B, $3F, $C6, $87, $A9, $80,
$03, $BB, $43, $2A, $5B, $31, $D2, $39, $AE, $B4, $95, $B6, $61, $4A, $69, $B8,
$F1, $9E, $A5, $EA, $CA, $4E, $90, $11, $45, $25, $B8, $F6, $FB, $AA, $76, $45,
$A6, $DA, $0E, $C8, $57, $6A, $25, $33, $FC, $55, $22, $94, $CF, $EE, $3C, $AD,
$98, $52, $00, $81, $05, $DB, $24, $CD, $24, $B1, $B1, $41, $DD, $64, $02, $75,
$2B, $A1, $75, $C4, $DF, $C7, $4A, $EA, $9A, $26, $FB, $1F, $3F, $03, $C4, $C5,
$D8, $C2, $BF, $87, $3C, $AE, $1B, $D0, $51, $81, $49, $04, $7E, $ED, $2A, $D7,
$6D, $79, $85, $20, $BB, $D4, $12, $F3, $EC, $FE, $D0, $AE, $F7, $7A, $4C, $4B,
$3F, $B3, $1B, $83, $65, $D7, $A7, $5A, $A6, $BA, $6F, $5D, $B3, $4F, $04, $2D,
$D2, $83, $AB, $CB, $E6, $F7, $17, $CE, $3B, $6D, $22, $4D, $D2, $55, $40, $C3,
$BE, $5A, $9E, $EF, $3E, $BE, $31, $38, $04, $60, $28, $47, $AF, $98, $39, $1E,
$49, $FA, $6C, $B6, $ED, $32, $BC, $CB, $8E, $F8, $B4, $1F, $2A, $CB, $B9, $B8,
$08, $21, $2E, $11, $11, $ED, $AD, $14, $92, $CC, $CE, $B9, $BF, $67, $67, $01,
$52, $52, $57, $AB, $D5, $BC, $4E, $6C, $EF, $58, $60, $2C, $81, $EC, $77, $3B,
$88, $2E, $34, $7F, $26, $23, $FB, $1A, $3E, $0C, $B5, $31, $48, $08, $69, $F6,
$58, $06, $1B, $AA, $AA, $48, $49, $F3, $8A, $2E, $29, $79, $C4, $DF, $B9, $25,
$19, $6C, $4D, $3C, $37, $44, $8A, $AD, $C1, $49, $98, $76, $9B, $16, $FA, $DD,
$F6, $95, $88, $DA, $2A, $63, $55, $45, $07, $41, $EE, $07, $1C, $03, $7E, $5F,
$2C, $21, $03, $63, $14, $B4, $97, $5A, $A9, $27, $89, $95, $F7, $A1, $9B, $E4,
$D3, $FC, $C0, $E8, $74, $18, $2A, $CA, $AA, $40, $9F, $C5, $74, $A0, $F7, $59,
$C6, $E9, $6D, $6E, $90, $EF, $00, $FC, $A4, $A5, $C3, $FB, $F7, $66, $68, $BD,
$3D, $AE, $89, $40, $27, $F3, $01, $7E, $88, $52, $3D, $26, $01, $9E, $6A, $9C,
$F2, $37, $09, $5A, $34, $62, $AC, $D5, $35, $9B, $AF, $7F, $73, $F2, $B4, $C5,
$B3, $B2, $8E, $74, $08, $4E, $95, $52, $DD, $CF, $C6, $25, $46, $9C, $D9, $21,
$96, $1A, $11, $56, $08, $4A, $D9, $9E, $8F, $E6, $2D, $5F, $4C, $22, $19, $38,
$C0, $97, $B2, $CD, $C4, $C2, $07, $B8, $37, $81, $4D, $35, $56, $E7, $77, $8B,
$09, $50, $5F, $54, $12, $2E, $3F, $16, $C7, $68, $A7, $37, $FB, $C1, $34, $E3,
$E2, $72, $CE, $2E, $F0, $1E, $47, $38, $7A, $79, $C3, $33, $51, $65, $B2, $25,
$8A, $B0, $A5, $0A, $64, $5F, $7D, $28, $1B, $A7, $5F, $AB, $4D, $D8, $CA, $64,
$21, $F4, $96, $8E, $9B, $92, $F0, $71, $7C, $5C, $68, $82, $95, $51, $54, $FE,
$15, $A5, $99, $41, $CC, $D1, $73, $65, $6A, $6F, $43, $AB, $9D, $84, $EF, $CD,
$5A, $8A, $98, $DA, $CC, $6F, $67, $C8, $D5, $90, $1D, $E3, $51, $5E, $86, $40,
$25, $87, $86, $41, $94, $B1, $20, $9A, $3C, $9F, $45, $AF, $80, $C7, $E5, $0C,
$82, $F1, $22, $BB, $2B, $55, $0D, $9C, $52, $14, $F6, $6D, $22, $D6, $5D, $E4,
$B4, $CE, $DE, $EC, $30, $9A, $48, $64, $1F, $A7, $E5, $D6, $C4, $81, $5B, $51,
$87, $FB, $26, $CC, $D0, $BA, $63, $58, $4A, $2F, $06, $88, $9E, $C9, $05, $EE,
$53, $EA, $9B, $FC, $C2, $E9, $B7, $69, $A8, $FC, $87, $D3, $34, $FF, $4F, $9B,
$D1, $2E, $B3, $85, $A4, $AD, $51, $4D, $1B, $8E, $55, $48, $B9, $39, $56, $1C,
$B8, $A9, $58, $3A, $ED, $70, $9B, $9A, $E3, $33, $B5, $12, $F9, $5E, $55, $44,
$65, $45, $26, $53, $65, $40, $BD, $CB, $0C, $C2, $AA, $17, $1F, $5C, $FE, $32,
$A1, $4B, $75, $72, $CB, $71, $9D, $35, $90, $B8, $2E, $40, $18, $24, $11, $0F,
$B1, $49, $27, $96, $06, $0E, $05, $90, $49, $4E, $F9, $D9, $E7, $99, $E1, $84,
$34, $8D, $36, $30, $89, $BA, $10, $C1, $33, $A9, $46, $95, $A0, $0A, $E8, $AB,
$91, $93, $35, $D9, $75, $D2, $37, $44, $22, $F1, $45, $F4, $20, $97, $C8, $50,
$BD, $D2, $38, $F4, $CF, $31, $A3, $DD, $86, $64, $88, $EB, $35, $DA, $C9, $8D,
$6D, $02, $00, $D2, $96, $54, $A4, $EE, $32, $EE, $19, $42, $90, $F2, $5E, $9A,
$EA, $45, $D2, $1F, $43, $21, $28, $C7, $85, $A6, $FF, $84, $41, $FD, $CF, $C9,
$FC, $0D, $3A, $8B, $70, $4D, $DF, $82, $14, $CF, $7D, $EE, $A8, $F5, $28, $D3,
$CE, $CD, $12, $DC, $7B, $7A, $4D, $5C, $4C, $7C, $93, $DA, $32, $24, $72, $5F,
$9E, $A8, $CB, $DF, $E5, $7B, $E7, $9B, $64, $BB, $AA, $17, $21, $8F, $89, $D2,
$80, $65, $0B, $28, $2E, $E2, $94, $44, $A1, $04, $70, $E3, $77, $AC, $AF, $41,
$FC, $AA, $68, $2F, $51, $FF, $23, $13, $A7, $2E, $96, $4D, $80, $43, $C4, $C7,
$E7, $A3, $A3, $67, $24, $01, $6D, $6F, $FD, $CB, $63, $9C, $FD, $32, $FD, $A8,
$5C, $ED, $0F, $FF, $B2, $BC, $1A, $3C, $CC, $62, $D0, $9F, $85, $42, $C1, $07,
$2E, $EC, $7D, $99, $44, $2C, $5E, $78, $8C, $6C, $C4, $A3, $88, $C6, $13, $2D,
$45, $4C, $A2, $06, $00, $D7, $51, $10, $01, $60, $A7, $56, $EF, $7A, $0B, $67,
$5E, $4E, $5B, $63, $0C, $20, $0A, $46, $A6, $A7, $31, $5C, $E2, $7A, $9D, $66,
$E1, $41, $56, $45, $3E, $C6, $D2, $5D, $87, $EC, $07, $DA, $64, $91, $1B, $78,
$72, $7A, $F5, $45, $85, $45, $EC, $B7, $0D, $35, $15, $EC, $C4, $65, $41, $E5,
$3E, $31, $32, $35, $CC, $7C, $A7, $86, $E4, $1E, $13, $2A, $2D, $F2, $A1, $A6,
$CC, $6B, $71, $EC, $7E, $29, $5F, $81, $2E, $07, $FF, $2F, $87, $7C, $15, $78,
$47, $A6, $05, $30, $A1, $EE, $2A, $BB, $85, $C8, $06, $EC, $D3, $C0, $60, $4C,
$59, $49, $7E, $EE, $B0, $4D, $4E, $D5, $39, $CE, $8E, $9E, $48, $ED, $99, $FE,
$25, $C3, $87, $7C, $84, $33, $2F, $4F, $69, $F0, $AC, $35, $37, $53, $B1, $91,
$2E, $E6, $64, $B3, $31, $30, $6A, $89, $46, $72, $91, $C1, $CB, $85, $D1, $B7,
$2F, $12, $CD, $E4, $56, $89, $E6, $FA, $4D, $19, $3C, $20, $93, $4C, $F3, $67,
$D9, $D2, $82, $4F, $E7, $16, $2A, $79, $4C, $8C, $BD, $12, $9A, $62, $AE, $93,
$64, $3C, $44, $06, $7E, $8E, $F5, $54, $31, $F8, $D4, $41, $90, $15, $61, $46,
$44, $F1, $CF, $5F, $22, $0A, $D5, $D1, $5E, $7B, $0F, $12, $E9, $98, $FE, $47,
$DE, $22, $E8, $D3, $F0, $42, $21, $87, $0C, $A0, $1C, $C9, $B1, $03, $E6, $7A,
$C4, $18, $14, $AC, $51, $4A, $42, $32, $C3, $4F, $51, $86, $33, $A7, $B7, $0E,
$C3, $AE, $81, $A7, $9A, $A9, $D5, $F4, $F3, $6B, $97, $C7, $71, $67, $07, $82,
$C0, $F8, $1D, $C3, $4C, $85, $B9, $C2, $97, $5B, $A8, $A4, $CB, $40, $A6, $1A,
$5B, $BC, $3D, $49, $05, $FC, $74, $A3, $2D, $0D, $9A, $6B, $4D, $53, $E1, $73,
$5E, $E7, $E1, $A1, $57, $70, $86, $3B, $31, $AE, $0D, $37, $9F, $79, $BD, $12,
$DE, $D9, $DF, $65, $06, $F8, $34, $0E, $DF, $42, $5B, $25, $31, $56, $CA, $53,
$DD, $84, $1B, $2F, $02, $83, $71, $C6, $EA, $A5, $DE, $AF, $DE, $33, $15, $96,
$99, $29, $78, $C4, $D3, $4B, $25, $A4, $5E, $AB, $48, $78, $9A, $19, $78, $0D,
$B9, $94, $6A, $0E, $B9, $E5, $6A, $A7, $CE, $9D, $DE, $15, $A8, $AA, $94, $B2,
$66, $E2, $C7, $7A, $02, $9A, $F3, $EC, $4A, $1F, $30, $BA, $5A, $34, $7D, $78,
$EE, $2A, $24, $FB, $DC, $2B, $81, $3D, $78, $96, $0D, $F2, $61, $55, $C7, $22,
$E0, $08, $9D, $4C, $3C, $53, $7B, $BE, $F9, $D5, $58, $3C, $98, $3C, $95, $69,
$6B, $67, $24, $32, $E6, $D3, $EC, $6E, $C2, $3F, $36, $A3, $55, $47, $A9, $31,
$1C, $96, $B6, $E8, $55, $0C, $B2, $74, $98, $71, $8A, $0A, $8E, $39, $5E, $E7,
$03, $5A, $1C, $75, $53, $10, $BF, $46, $B5, $53, $11, $5B, $19, $8B, $88, $55,
$AD, $37, $E3, $E5, $FA, $43, $27, $5A, $8C, $2C, $1A, $AC, $18, $E4, $9C, $50,
$06, $1B, $F1, $85, $25, $CC, $56, $F5, $0E, $69, $F3, $50, $88, $7D, $E6, $25,
$A7, $E9, $11, $B5, $19, $B4, $0F, $43, $98, $61, $01, $DF, $F8, $04, $E1, $74,
$93, $1E, $F4, $4D, $74, $DD, $ED, $1F, $D2, $F4, $11, $B5, $F2, $D0, $6D, $29,
$AE, $7F, $6D, $33, $61, $C0, $DA, $9A, $8C, $75, $F1, $05, $FF, $DF, $20, $8D,
$26, $CD, $F6, $83, $32, $57, $40, $FC, $37, $A6, $83, $E4, $2D, $28, $39, $02,
$E0, $D6, $01, $18, $EB, $92, $92, $FD, $90, $15, $C9, $13, $6D, $2D, $87, $0B,
$61, $18, $43, $6B, $E9, $92, $37, $77, $82, $8B, $21, $17, $68, $7F, $63, $86,
$25, $4F, $F8, $B6, $28, $6E, $2D, $8A, $E4, $6B, $4A, $3F, $2E, $0A, $FC, $71,
$6D, $C1, $61, $60, $14, $9C, $49, $19, $1B, $F8, $0E, $2A, $5E, $8F, $83, $16,
$0E, $87, $48, $46, $9A, $35, $3C, $13, $FD, $7D, $E9, $A3, $74, $AA, $19, $5B,
$3D, $98, $4E, $39, $B9, $AC, $63, $F1, $A9, $FA, $85, $B2, $4B, $91, $5C, $5B,
$FF, $B5, $3C, $76, $DF, $FA, $7A, $C2, $F2, $F4, $93, $35, $F9, $0B, $9D, $2D,
$8A, $BE, $7B, $11, $E3, $CF, $15, $1C, $11, $50, $52, $DA, $6B, $C2, $5B, $2E,
$18, $08, $FF, $C7, $11, $BD, $3D, $19, $02, $AE, $31, $DB, $85, $BC, $CA, $84,
$1E, $8D, $93, $F4, $B5, $C0, $3E, $A8, $C5, $69, $F6, $85, $4F, $D5, $D3, $D9,
$0D, $B8, $1D, $1C, $C2, $85, $78, $F6, $23, $3B, $8F, $5A, $4A, $A0, $24, $AD,
$B4, $0F, $09, $FC, $79, $A8, $F8, $47, $B9, $7A, $C9, $89, $60, $C6, $CF, $82,
$9B, $07, $9E, $66, $36, $FA, $24, $40, $B0, $00, $9F, $3E, $59, $44, $3A, $80,
$86, $F7, $B4, $7F, $3F, $8E, $79, $27, $92, $AD, $95, $B6, $04, $5B, $FA, $5B,
$DA, $22, $AB, $C8, $F2, $83, $51, $9B, $DC, $06, $19, $D4, $74, $EC, $7A, $66,
$33, $E0, $0A, $6C, $14, $1B, $62, $11, $D4, $AA, $7F, $E1, $59, $04, $BF, $B1,
$1F, $A8, $FD, $CA, $0A, $1B, $1D, $F9, $C0, $A2, $BC, $17, $8A, $8B, $F5, $6F,
$2B, $43, $03, $B5, $9E, $65, $E4, $2C, $2A, $34, $AE, $91, $67, $17, $60, $DD,
$28, $88, $A3, $ED, $3E, $CB, $D8, $D3, $F4, $33, $EE, $2E, $BF, $07, $12, $49,
$32, $75, $B9, $7D, $E7, $D4, $28, $A3, $51, $17, $DC, $59, $F0, $8F, $05, $48,
$C7, $C8, $F3, $F3, $F2, $37, $B8, $C4, $74, $AE, $59, $47, $E5, $E9, $1A, $A9,
$FE, $E2, $D1, $F0, $78, $6D, $95, $56, $1A, $F6, $B6, $41, $68, $D2, $FB, $90,
$D0, $51, $B9, $43, $F4, $73, $4A, $AE, $DA, $C0, $AF, $DA, $04, $31, $88, $5D,
$43, $1E, $A1, $7B, $76, $D3, $56, $27, $89, $3D, $A3, $D0, $9F, $AE, $0B, $A2,
$87, $E7, $60, $13, $9A, $BE, $F1, $A4, $C9, $2C, $96, $10, $47, $E5, $C4, $E4,
$16, $37, $E6, $95, $68, $C8, $3C, $57, $92, $00, $E8, $0E, $D0, $1C, $A0, $91,
$23, $8C, $07, $6A, $A5, $7C, $1E, $75, $C8, $73, $C3, $C3, $6A, $9B, $11, $7A,
$BD, $47, $6B, $F8, $37, $2C, $12, $B6, $7C, $F7, $FB, $6F, $F1, $53, $9F, $30,
$BD, $94, $24, $A8, $00, $1A, $6E, $34, $CD, $81, $F3, $3A, $2F, $4F, $F1, $38,
$D8, $EB, $C0, $15, $D7, $BC, $AE, $98, $D6, $CD, $C4, $2B, $FA, $23, $E7, $81,
$D8, $0E, $90, $30, $4F, $51, $84, $DE, $B9, $52, $C8, $5C, $60, $A9, $C5, $51,
$66, $5F, $EB, $5C, $13, $9A, $4A, $0D, $A8, $71, $17, $F5, $89, $C4, $5D, $F7,
$1E, $62, $5D, $E2, $66, $80, $29, $8F, $FF, $C7, $88, $6A, $EE, $3E, $93, $6B,
$33, $7D, $70, $73, $4F, $58, $A4, $63, $74, $06, $9A, $6E, $40, $AD, $A8, $6C,
$E6, $92, $D9, $C9, $05, $35, $DF, $54, $8E, $BC, $AB, $95, $95, $8F, $9B, $BC,
$7E, $2E, $7F, $47, $F9, $42, $2E, $77, $05, $8F, $F0, $A1, $5B, $A9, $DE, $36,
$D1, $47, $88, $2C, $7D, $E6, $F7, $6D, $59, $9C, $BB, $14, $30, $F5, $A4, $E9,
$1A, $0F, $75, $40, $D6, $3C, $F9, $D5, $A1, $BC, $E2, $B2, $34, $84, $12, $D2,
$3D, $17, $4A, $9D, $CD, $5D, $B2, $DF, $91, $3E, $C7, $E0, $0F, $8C, $5C, $1A,
$F0, $DD, $95, $C8, $68, $64, $B4, $49, $30, $54, $6C, $23, $83, $6A, $4B, $2C,
$EC, $38, $59, $EE, $48, $BA, $08, $6E, $9B, $D7, $AB, $FC, $E8, $67, $E6, $AC,
$E4, $4D, $7E, $A3, $9C, $42, $26, $0C, $85, $3D, $90, $E8, $E4, $BD, $2B, $5C,
$2A, $A7, $68, $DC, $CB, $E1, $7B, $A4, $DB, $D0, $4E, $B3, $FD, $EF, $53, $3F,
$98, $EE, $D3, $F9, $C0, $DD, $0B, $1D, $93, $6F, $FB, $01, $F9, $A5, $EC, $F4,
$43, $24, $B2, $E3, $FF, $F6, $42, $3E, $90, $24, $30, $FF, $7C, $3B, $78, $D3,
$7D, $A8, $9C, $5D, $FA, $A9, $F5, $A6, $DB, $50, $33, $DA, $C7, $9D, $0C, $E6,
$48, $DE, $E0, $77, $D6, $9B, $3C, $4F, $C3, $B4, $D2, $7C, $FF, $08, $E6, $DC,
$51, $BA, $0D, $F1, $C5, $9D, $93, $21, $B7, $E2, $3E, $77, $72, $44, $72, $59,
$C7, $8C, $B8, $3B, $40, $FF, $78, $91, $36, $E6, $2A, $FD, $CF, $6C, $31, $3A,
$69, $EB, $BC, $DA, $48, $33, $9B, $3F, $A1, $70, $5B, $88, $DB, $A5, $E1, $59,
$0C, $27, $D1, $C7, $F4, $FF, $E7, $A2, $CC, $1E, $68, $0B, $2D, $50, $96, $A7,
$A9, $D8, $3A, $5C, $51, $53, $7D, $AC, $D6, $8D, $85, $C8, $CD, $4D, $57, $C9,
$E2, $F1, $05, $48, $0B, $2A, $76, $28, $31, $F4, $EF, $CD, $61, $E5, $7A, $D5,
$B3, $D4, $84, $AD, $66, $CB, $AF, $EF, $3F, $37, $09, $4E, $8E, $78, $0C, $5F,
$23, $EF, $B6, $A9, $D5, $2B, $CD, $A0, $8A, $BF, $E3, $D1, $B4, $AA, $E5, $A1,
$2E, $93, $BA, $AF, $D4, $00, $29, $AC, $EB, $91, $E3, $0C, $BC, $71, $6D, $49,
$A8, $64, $E2, $84, $2C, $5B, $09, $06, $ED, $2A, $C9, $FD, $40, $18, $BD, $D1,
$4D, $CD, $B4, $5E, $03, $A5, $AC, $D8, $66, $DC, $AE, $42, $1E, $33, $6D, $7B,
$B9, $AD, $F0, $33, $98, $CF, $3C, $18, $08, $11, $82, $91, $E3, $2F, $82, $15,
$4B, $94, $7F, $A1, $AE, $CF, $3C, $63, $C4, $D3, $F3, $BF, $63, $10, $DF, $3F,
$E0, $59, $FA, $2E, $58, $E4, $81, $64, $E8, $27, $30, $69, $5D, $2E, $88, $FE,
$83, $B3, $0F, $CD, $BD, $49, $85, $13, $74, $40, $C8, $EC, $48, $30, $C7, $40,
$1B, $77, $D8, $28, $7F, $A7, $CF, $D2, $9A, $DA, $B5, $D9, $F7, $7E, $DD, $4A,
$BC, $29, $1A, $29, $F3, $07, $06, $71, $94, $6D, $74, $F3, $33, $AB, $CB, $5D,
$20, $92, $60, $48, $DE, $A0, $FF, $0A, $B9, $2C, $99, $3E, $43, $CE, $F7, $3D,
$4F, $D1, $3D, $07, $C5, $BE, $8E, $D7, $81, $09, $78, $A4, $43, $A8, $5F, $DC,
$EF, $B8, $5E, $C7, $49, $EA, $62, $13, $F3, $83, $9A, $30, $FF, $3A, $49, $AF,
$2F, $57, $DE, $3B, $7C, $74, $3E, $D3, $ED, $CC, $CF, $12, $41, $45, $5A, $B6,
$3A, $0E, $E5, $3C, $D0, $DC, $3F, $03, $8D, $E9, $4A, $23, $9C, $E5, $C5, $04,
$58, $8A, $1F, $62, $CB, $AF, $E5, $2B, $D6, $B5, $AE, $0A, $B0, $9C, $90, $00,
$BC, $51, $C8, $E9, $06, $A2, $0F, $7C, $4A, $BD, $17, $5C, $B8, $4D, $5E, $5B,
$82, $CD, $30, $8E, $38, $8C, $DD, $76, $08, $A6, $8B, $5B, $F8, $82, $18, $9A,
$4C, $F1, $1E, $71, $BC, $5C, $01, $74, $22, $A8, $AE, $90, $E2, $42, $3C, $8B,
$3D, $90, $AC, $CD, $E1, $E5, $40, $FD, $83, $F9, $60, $43, $3E, $DD, $6D, $5A,
$4D, $13, $FF, $2A, $2F, $5B, $EA, $AF, $59, $A3, $2C, $B3, $E1, $51, $B3, $DA,
$C4, $07, $DD, $85, $C6, $02, $74, $E2, $A0, $37, $69, $59, $42, $79, $9A, $30,
$40, $4C, $EF, $BE, $AB, $13, $67, $53, $67, $D8, $F8, $20, $FB, $22, $BD, $9B,
$3F, $58, $43, $13, $F4, $D7, $80, $16, $86, $ED, $D8, $52, $AC, $F8, $94, $57,
$0A, $34, $DD, $EA, $E6, $52, $9C, $B4, $04, $47, $A7, $29, $72, $2A, $B0, $E3,
$9D, $19, $4B, $31, $02, $08, $38, $AA, $50, $E6, $DA, $1B, $41, $B2, $B2, $3C,
$F5, $BE, $85, $DB, $6A, $4F, $7B, $4C, $7C, $B0, $96, $7F, $FA, $2D, $15, $4A,
$90, $CB, $93, $D2, $64, $31, $48, $7A, $B0, $AE, $FA, $55, $DA, $6C, $EE, $B8,
$0D, $4B, $8E, $AC, $D9, $87, $A0, $4D, $2D, $A6, $F9, $F7, $95, $6D, $84, $4E,
$B8, $CA, $A5, $34, $B6, $B9, $F3, $73, $2D, $E0, $2F, $23, $DD, $7A, $12, $04,
$17, $E1, $DA, $9B, $FC, $B2, $9A, $99, $36, $1E, $9B, $E9, $6E, $03, $45, $69,
$25, $5B, $9E, $E5, $07, $36, $E0, $B8, $0F, $A1, $94, $4C, $63, $05, $43, $96,
$0B, $DB, $4B, $27, $CC, $42, $DD, $ED, $C9, $77, $04, $F6, $61, $6A, $E2, $90,
$3B, $A3, $6D, $8A, $9B, $FA, $19, $AE, $70, $5B, $8B, $A4, $A7, $2A, $B6, $28,
$B5, $40, $2E, $46, $C0, $8A, $9E, $F8, $FC, $62, $80, $8C, $2B, $6A, $B9, $21,
$51, $D0, $CA, $62, $E0, $4B, $E5, $2A, $A9, $76, $5F, $72, $B0, $13, $9E, $2D,
$74, $38, $5C, $A2, $EF, $74, $E4, $F8, $DA, $EA, $BF, $DA, $98, $80, $CF, $97,
$21, $EF, $AF, $52, $B6, $47, $FB, $5A, $FD, $39, $F2, $64, $5F, $EB, $11, $9A,
$00, $7F, $1E, $F1, $38, $2A, $C5, $4A, $EB, $5E, $71, $95, $77, $A8, $79, $2A,
$96, $C4, $9E, $4B, $CF, $D0, $49, $71, $C7, $00, $02, $DE, $31, $5D, $A4, $AF,
$B7, $59, $58, $40, $05, $A1, $A0, $7B, $61, $88, $F7, $83, $9A, $5A, $6F, $ED,
$9C, $9A, $E4, $95, $53, $94, $D1, $4C, $F5, $91, $49, $1F, $00, $FF, $3B, $8E,
$95, $5E, $D8, $0E, $5E, $04, $E2, $1C, $1A, $47, $0F, $DC, $62, $5E, $01, $DA,
$CB, $93, $39, $70, $6F, $5C, $61, $D0, $2E, $E7, $24, $42, $DA, $1D, $BE, $8B,
$DE, $C8, $AA, $10, $C8, $BA, $F8, $25, $83, $2F, $4A, $33, $EF, $CC, $66, $A6,
$CB, $FA, $4D, $54, $A5, $CC, $12, $C0, $C7, $F5, $27, $87, $F4, $BB, $45, $6D,
$24, $DB, $69, $66, $C5, $7D, $6E, $97, $A2, $D6, $58, $D3, $C0, $D2, $B5, $9F,
$68, $25, $54, $C7, $3D, $1C, $8B, $28, $C3, $DF, $57, $3A, $3B, $71, $87, $4A,
$4D, $A2, $E0, $46, $59, $A9, $74, $0D, $8E, $D5, $E2, $96, $B5, $21, $3A, $1D,
$98, $DB, $10, $DC, $2E, $68, $E2, $2E, $9F, $96, $E9, $ED, $4E, $3A, $B9, $3E,
$51, $67, $78, $4E, $C2, $30, $50, $64, $03, $9A, $D6, $C2, $50, $B9, $D9, $F5,
$E6, $AC, $A0, $CA, $C6, $0B, $FC, $C8, $9F, $E8, $5E, $C5, $E4, $39, $FE, $79,
$76, $FC, $73, $8B, $36, $70, $A3, $FD, $92, $9C, $FD, $9B, $1F, $90, $4A, $53,
$2E, $56, $83, $35, $27, $1E, $FA, $C8, $BC, $9D, $42, $55, $44, $20, $A8, $51,
$89, $4C, $60, $DA, $78, $ED, $89, $01, $72, $98, $D2, $22, $B6, $30, $55, $13,
$40, $3A, $2F, $E4, $11, $42, $D9, $16, $E2, $AC, $3D, $13, $23, $58, $9A, $E2,
$2A, $71, $69, $21, $80, $E7, $BF, $B4, $45, $A3, $B5, $18, $96, $39, $1B, $6C,
$65, $3C, $3C, $12, $18, $4F, $20, $7A, $B7, $62, $AF, $F6, $F3, $E7, $1B, $87,
$43, $FE, $C3, $AD, $8C, $ED, $FB, $21, $3B, $02, $BE, $9A, $17, $60, $4E, $6E,
$93, $02, $FA, $06, $2B, $AE, $00, $61, $A8, $15, $8A, $2F, $D9, $C1, $E0, $F8,
$98, $9A, $FE, $F4, $6E, $7D, $D6, $7B, $5D, $20, $7D, $EE, $27, $6E, $E1, $EE,
$68, $B8, $CA, $1A, $B5, $8E, $39, $7B, $71, $E4, $AB, $BE, $BF, $21, $38, $0B,
$3F, $04, $9A, $9A, $D6, $95, $03, $88, $B3, $44, $04, $22, $97, $F4, $AE, $2C,
$5E, $D5, $15, $38, $F1, $08, $24, $19, $76, $23, $30, $03, $45, $95, $CA, $91,
$11, $FC, $F0, $01, $F0, $51, $6D, $94, $AE, $A5, $AD, $25, $D3, $AC, $68, $ED,
$5C, $91, $18, $CF, $E4, $78, $2C, $6D, $76, $1C, $FA, $47, $30, $A1, $8E, $21,
$20, $5B, $68, $A3, $7D, $49, $18, $FC, $F7, $CB, $28, $D3, $58, $72, $4E, $C9,
$81, $AE, $98, $5E, $34, $D0, $4A, $41, $D2, $41, $CB, $27, $B5, $2A, $DF, $CC,
$85, $34, $75, $41, $7C, $3B, $3A, $70, $72, $DE, $1D, $15, $C1, $B2, $2D, $B3,
$94, $BE, $B5, $73, $E3, $8A, $CF, $67, $31, $E9, $26, $60, $58, $D0, $5E, $45,
$AC, $80, $44, $41, $36, $ED, $81, $F2, $76, $9A, $70, $BD, $89, $AC, $32, $6B,
$0B, $50, $21, $92, $94, $11, $FA, $5C, $ED, $89, $69, $6D, $EC, $A2, $5F, $6D,
$39, $66, $B1, $6B, $D3, $C2, $93, $02, $62, $7B, $EB, $71, $7C, $B9, $1A, $23,
$AF, $19, $60, $97, $2E, $4C, $10, $60, $9D, $A9, $6F, $A9, $A2, $A9, $50, $C5,
$7D, $53, $FA, $31, $1F, $14, $07, $60, $FF, $3F, $41, $0E, $81, $68, $08, $CC,
$95, $C0, $4C, $D5, $99, $52, $02, $6A, $18, $7C, $C1, $F3, $87, $86, $A7, $3C,
$80, $E6, $3D, $D7, $8F, $73, $1D, $3A, $9F, $CC, $7D, $A4, $84, $B8, $EA, $FC,
$BA, $AF, $78, $05, $7B, $9E, $C2, $4F, $A1, $48, $02, $16, $1B, $BF, $EC, $6D,
$E7, $7F, $CA, $FF, $41, $6C, $87, $9D, $CE, $29, $CE, $D6, $C1, $86, $E8, $9A,
$23, $AA, $C5, $4C, $80, $B0, $5B, $CF, $55, $A5, $DA, $A2, $8A, $28, $AA, $7F,
$9F, $72, $CA, $64, $C3, $AD, $D6, $FD, $65, $45, $A6, $C4, $81, $90, $28, $B6,
$C9, $00, $81, $3D, $90, $C5, $6F, $15, $A9, $1E, $21, $BB, $7B, $B3, $EC, $BE,
$55, $5F, $93, $3E, $7F, $B6, $AA, $D0, $55, $28, $2B, $56, $A1, $EF, $E7, $E7,
$2C, $89, $99, $AF, $B7, $31, $80, $83, $36, $F4, $F0, $38, $6A, $92, $56, $51,
$F2, $52, $ED, $84, $FF, $74, $EC, $E1, $71, $41, $92, $E6, $C2, $F7, $D8, $76,
$64, $80, $F8, $9D, $F5, $CD, $4B, $63, $B5, $5A, $C2, $41, $21, $5C, $2B, $EA,
$25, $C3, $E4, $5C, $9D, $D3, $83, $00, $87, $10, $A7, $24, $83, $AD, $AA, $B8,
$57, $0D, $DE, $77, $F8, $FB, $18, $1E, $8C, $90, $34, $42, $39, $DB, $57, $21,
$2F, $58, $30, $AC, $2D, $85, $82, $DD, $E3, $AD, $30, $59, $7B, $DF, $EC, $EC,
$FA, $29, $26, $AE, $FB, $FC, $A0, $5B, $FC, $75, $C8, $90, $72, $AD, $03, $5A,
$4A, $CD, $04, $5F, $BD, $35, $44, $9F, $B4, $F2, $1F, $7D, $02, $56, $E9, $36,
$D6, $F8, $D6, $CA, $F5, $55, $2F, $41, $D3, $74, $E5, $5E, $8E, $C8, $EB, $2B,
$20, $13, $B9, $DC, $03, $31, $95, $74, $CE, $54, $F6, $D5, $EE, $E0, $D0, $E9,
$4B, $84, $A2, $09, $78, $D7, $74, $C1, $21, $F0, $05, $6C, $CF, $09, $CB, $6B,
$D6, $9F, $C4, $A0, $D2, $0A, $8A, $E3, $46, $26, $BF, $E1, $35, $4C, $2B, $3D,
$54, $85, $69, $F6, $FB, $2C, $00, $94, $6D, $14, $BB, $4D, $CA, $8D, $C4, $DD,
$48, $80, $3F, $BF, $A4, $58, $C1, $02, $40, $97, $C1, $11, $82, $87, $7B, $7E,
$8F, $94, $61, $0E, $EB, $86, $A2, $FB, $C8, $07, $64, $DC, $24, $4C, $4D, $E4,
$21, $CB, $7F, $28, $6B, $D4, $E1, $EA, $99, $DE, $E8, $55, $F8, $38, $C8, $F9,
$58, $50, $C9, $2E, $EA, $15, $EC, $99, $7E, $74, $B4, $87, $A7, $6B, $48, $EB,
$BE, $EB, $C2, $4B, $F5, $1B, $AA, $B6, $01, $93, $0D, $5C, $87, $62, $49, $DF,
$79, $0F, $B5, $DE, $77, $72, $26, $D8, $B1, $62, $14, $1C, $99, $67, $96, $A3,
$F8, $8C, $5A, $1E, $2F, $73, $DE, $F4, $D5, $53, $04, $62, $15, $B6, $B2, $B0,
$C3, $56, $F5, $E0, $58, $94, $59, $E7, $FE, $CD, $00, $9E, $9C, $86, $C5, $DA,
$A2, $84, $F5, $D9, $C3, $03, $A9, $00, $DC, $C5, $2A, $97, $C7, $85, $8C, $95,
$5A, $F0, $30, $E0, $5D, $A5, $50, $E7, $B1, $8C, $24, $A5, $DD, $C5, $0F, $7B,
$3D, $28, $33, $E6, $5E, $8D, $4A, $48, $69, $10, $03, $65, $D7, $3E, $D3, $8F,
$6A, $78, $C6, $0E, $E0, $24, $7C, $3F, $62, $E4, $FC, $4B, $C4, $48, $71, $A1,
$8D, $02, $02, $42, $0C, $99, $F2, $F3, $26, $42, $71, $D8, $C9, $7A, $62, $93,
$E4, $F6, $7F, $72, $77, $5C, $F7, $4A, $C0, $9A, $2B, $39, $5B, $4F, $56, $53,
$34, $15, $A8, $F0, $F2, $3C, $0E, $A3, $41, $99, $B5, $6D, $8E, $B6, $22, $94,
$1A, $7E, $E2, $62, $19, $6C, $DA, $84, $EE, $82, $2D, $06, $C5, $7B, $6E, $47,
$2A, $32, $A4, $00, $C2, $0F, $BD, $14, $C6, $E3, $6F, $87, $6C, $67, $FC, $90,
$CB, $02, $3B, $AB, $14, $AC, $8C, $36, $6E, $B7, $7D, $8C, $F6, $08, $6C, $B8,
$DC, $47, $61, $B5, $10, $8D, $DA, $72, $58, $15, $07, $FF, $98, $CF, $02, $28,
$66, $93, $7B, $A3, $9E, $2F, $DD, $77, $B4, $B5, $4D, $FB, $C0, $CD, $44, $A6,
$1A, $66, $CA, $17, $E2, $C2, $1C, $53, $EC, $FC, $0A, $F6, $6A, $AD, $2A, $59,
$F8, $1A, $BE, $3C, $24, $09, $76, $F1, $83, $8E, $40, $67, $E2, $04, $E9, $A7,
$0A, $08, $88, $BF, $99, $37, $9F, $B1, $0F, $BA, $9B, $7E, $05, $3A, $26, $9E,
$70, $74, $79, $DB, $06, $3F, $CB, $18, $65, $9D, $15, $C5, $7A, $1C, $A6, $53,
$BE, $BB, $30, $DC, $B9, $6C, $E4, $EB, $24, $3D, $43, $4F, $1B, $5D, $E9, $37,
$D5, $6F, $61, $C1, $F1, $F2, $13, $2D, $D2, $24, $5D, $E2, $C7, $D5, $23, $C9,
$1E, $13, $1B, $54, $00, $C3, $9F, $4F, $1C, $66, $E1, $A1, $D0, $78, $DF, $85,
$29, $9D, $A0, $0C, $FA, $AB, $1C, $A6, $FC, $47, $FE, $56, $13, $58, $A9, $B2,
$63, $2E, $70, $CF, $7A, $D3, $F0, $FC, $64, $20, $19, $C4, $DA, $7E, $FB, $55,
$99, $30, $F4, $C7, $48, $8A, $AE, $67, $25, $16, $DE, $16, $6C, $41, $96, $DA,
$B3, $E0, $25, $14, $44, $00, $A9, $6B, $DD, $CA, $93, $AA, $93, $4A, $24, $36,
$60, $A8, $9F, $C7, $50, $C0, $F3, $2C, $D9, $0B, $EB, $69, $A3, $28, $43, $8D,
$CD, $B2, $6F, $66, $CC, $C7, $29, $CB, $E7, $4D, $CD, $BA, $29, $6E, $3E, $D4,
$2A, $8D, $F1, $8A, $34, $63, $E3, $18, $87, $2E, $5C, $30, $FC, $54, $83, $9B,
$79, $65, $23, $AA, $C5, $CC, $71, $7A, $C6, $30, $F0, $B3, $13, $A1, $8C, $40,
$5B, $69, $4F, $5C, $85, $9D, $F9, $12, $BD, $04, $F7, $44, $B6, $9B, $48, $C2,
$13, $A1, $09, $24, $2B, $CE, $3E, $7E, $45, $F1, $DC, $08, $C1, $8E, $51, $CD,
$C5, $16, $50, $A4, $CA, $1E, $62, $A3, $E5, $2D, $45, $D9, $AF, $8F, $81, $DD,
$84, $96, $15, $1C, $7E, $44, $7D, $FF, $EF, $0F, $A6, $46, $9E, $92, $89, $5B,
$4D, $A1, $E2, $1B, $FB, $FB, $C3, $3F, $98, $32, $3B, $8C, $36, $38, $D3, $B1,
$08, $F6, $39, $AF, $6A, $6F, $6C, $75, $31, $AE, $77, $B7, $B6, $72, $BB, $9D,
$E0, $3F, $EA, $AA, $AF, $23, $82, $BB, $68, $03, $44, $0B, $D0, $27, $8F, $5D,
$80, $B5, $F0, $3A, $A2, $8D, $9D, $E5, $DB, $18, $08, $A1, $B1, $5F, $D1, $19,
$E7, $EB, $BF, $B8, $D1, $3D, $04, $83, $82, $91, $F6, $ED, $1E, $79, $B9, $0A,
$4C, $29, $4D, $CF, $8E, $AB, $80, $22, $4B, $3B, $57, $5D, $FD, $33, $E8, $D4,
$8B, $54, $CF, $68, $8A, $75, $6A, $BC, $80, $3D, $FF, $14, $4D, $5D, $11, $F8,
$E6, $8A, $7C, $B8, $EF, $AB, $9F, $94, $C8, $4A, $BB, $80, $E2, $95, $7A, $C5,
$BD, $D4, $59, $9E, $DD, $99, $A3, $5F, $3F, $F2, $1D, $54, $31, $BF, $C6, $B7,
$43, $C0, $48, $A3, $E3, $86, $22, $1A, $94, $66, $AA, $EB, $50, $43, $8A, $99,
$59, $65, $31, $21, $FE, $D9, $BD, $1B, $37, $D0, $23, $68, $29, $B9, $31, $38,
$88, $B6, $26, $34, $25, $F1, $E5, $8E, $2E, $70, $70, $62, $77, $50, $5A, $B9,
$20, $EC, $98, $78, $33, $03, $F0, $AD, $6D, $BC, $A3, $EF, $BC, $D3, $48, $0A,
$EA, $24, $0B, $99, $BC, $11, $1F, $C0, $F7, $07, $F3, $56, $DB, $21, $01, $08,
$1E, $15, $E1, $33, $DA, $1C, $5D, $5A, $20, $E8, $1D, $2D, $37, $68, $C6, $18,
$77, $D3, $96, $95, $35, $65, $9D, $C4, $C8, $7C, $2D, $0B, $A7, $D2, $96, $91,
$A4, $76, $D6, $7E, $81, $0F, $C0, $AF, $A6, $C2, $49, $52, $A0, $EB, $AC, $84,
$D0, $52, $A9, $21, $13, $FA, $C8, $98, $26, $28, $98, $A8, $9D, $6A, $20, $86,
$33, $A0, $87, $44, $60, $E4, $BE, $68, $40, $1A, $07, $06, $88, $A4, $5E, $37,
$64, $98, $3A, $68, $17, $08, $86, $4A, $1C, $85, $F5, $AD, $AB, $D1, $E4, $0F,
$28, $EE, $61, $2F, $73, $D5, $D1, $60, $7E, $D0, $BD, $57, $04, $1D, $AF, $90,
$F0, $FF, $5C, $94, $DA, $46, $66, $A2, $65, $D6, $88, $DA, $B2, $AC, $F5, $E4,
$5D, $05, $16, $D3, $92, $EC, $84, $86, $1B, $7F, $D3, $70, $11, $E5, $BD, $94,
$5B, $7A, $24, $B1, $7D, $67, $5A, $E4, $49, $F9, $09, $07, $E8, $D2, $B3, $97,
$BD, $1D, $64, $C7, $2F, $E2, $DC, $8F, $AE, $7A, $24, $20, $51, $D3, $7A, $4B,
$57, $7A, $68, $6A, $53, $9B, $EB, $4A, $A4, $24, $5C, $BA, $F7, $60, $71, $6C,
$11, $AF, $DD, $99, $F6, $B3, $75, $90, $55, $C2, $BE, $35, $7B, $BC, $19, $9F,
$FA, $E3, $3C, $F6, $BB, $F3, $90, $9A, $71, $3A, $6A, $66, $CD, $63, $A2, $A7,
$02, $36, $F2, $19, $6B, $7B, $55, $FB, $74, $F3, $48, $9C, $00, $4A, $33, $3E,
$A1, $3F, $E4, $AF, $F7, $8B, $0C, $37, $0A, $97, $73, $58, $1F, $58, $33, $CB,
$83, $E6, $78, $A0, $30, $70, $A0, $4B, $DE, $92, $C7, $FA, $9E, $3D, $C2, $D1,
$AA, $5F, $35, $A6, $EA, $99, $31, $F4, $68, $CA, $77, $40, $17, $5E, $F9, $E5,
$23, $67, $BC, $27, $AF, $A4, $0B, $67, $36, $A7, $1B, $65, $4E, $1E, $28, $FF,
$AD, $ED, $6A, $CF, $63, $93, $41, $D4, $20, $E7, $71, $78, $51, $AB, $EB, $5F,
$67, $8D, $10, $D6, $AD, $A2, $BD, $A4, $BD, $69, $61, $F0, $16, $99, $EE, $4F,
$D6, $E6, $4C, $B6, $46, $57, $7E, $12, $85, $08, $F6, $90, $C5, $45, $17, $8B,
$E8, $DF, $31, $7F, $84, $F8, $F9, $EF, $CC, $3D, $6C, $3E, $5F, $1E, $7F, $63,
$3F, $B1, $F7, $57, $EE, $35, $8D, $13, $97, $87, $F9, $2F, $A4, $68, $81, $F0,
$05, $9E, $D6, $93, $AD, $08, $AD, $80, $E8, $C0, $58, $BB, $60, $4B, $B2, $A0,
$36, $20, $50, $65, $93, $A8, $D5, $65, $1A, $08, $40, $15, $4D, $A1, $FB, $6D,
$1B, $FA, $E4, $B3, $2F, $6D, $33, $7B, $F8, $57, $3F, $F5, $AD, $79, $00, $56,
$43, $97, $80, $92, $9B, $A2, $21, $3E, $05, $54, $47, $5C, $A6, $E2, $D8, $B0,
$CF, $7A, $2D, $95, $37, $C3, $1A, $CD, $1D, $6C, $BB, $80, $1D, $F2, $A3, $3C,
$73, $D7, $F1, $C2, $DB, $E5, $FF, $08, $30, $F6, $6F, $4F, $88, $CB, $95, $2B,
$F7, $30, $69, $F5, $D3, $33, $91, $92, $66, $C1, $EA, $20, $61, $61, $C6, $B1,
$DE, $70, $D7, $70, $D0, $AC, $4E, $C9, $3D, $77, $B6, $F4, $F0, $80, $F0, $E2,
$E5, $BC, $7D, $2A, $4E, $E8, $27, $56, $B3, $13, $40, $13, $8D, $9D, $63, $3F,
$4A, $55, $37, $DF, $DA, $E6, $CF, $A9, $3C, $B0, $EB, $26, $AE, $5E, $42, $0A,
$08, $42, $70, $38, $40, $82, $24, $6A, $C5, $B3, $C2, $F4, $E0, $B4, $2C, $81,
$5E, $3D, $5D, $C2, $C0, $AF, $30, $23, $A4, $42, $A6, $2B, $5B, $E8, $32, $B0,
$6F, $2F, $00, $90, $88, $42, $7C, $12, $DB, $27, $9D, $2E, $AE, $00, $71, $E4,
$8D, $C0, $B0, $D7, $63, $5D, $3B, $58, $76, $27, $08, $EE, $F4, $D7, $73, $54,
$D0, $62, $26, $95, $FD, $6F, $93, $DE, $11, $7E, $BF, $20, $32, $73, $AA, $E9,
$AB, $11, $A1, $38, $C7, $AE, $A7, $B5, $59, $A8, $E7, $3B, $8E, $01, $8C, $CD,
$76, $B6, $37, $71, $1C, $5D, $6D, $FE, $80, $FA, $A8, $29, $E6, $42, $05, $01,
$2D, $F9, $34, $A6, $76, $13, $62, $6F, $64, $7F, $F1, $02, $CE, $BA, $D5, $30,
$5A, $0D, $0C, $4B, $3D, $61, $99, $77, $56, $5E, $0F, $00, $A7, $FE, $98, $80,
$F6, $07, $09, $51, $AB, $31, $DB, $EB, $61, $97, $54, $46, $00, $A1, $E3, $D2,
$12, $96, $64, $41, $D5, $31, $36, $18, $20, $96, $9A, $03, $2A, $3D, $76, $68,
$CA, $C9, $24, $53, $D3, $91, $A4, $11, $8F, $73, $62, $6E, $44, $A2, $5C, $5E,
$EA, $76, $7A, $4A, $18, $3F, $36, $B7, $2D, $7D, $19, $2C, $A5, $3A, $23, $3C,
$C4, $73, $8B, $59, $F0, $23, $39, $7C, $4D, $FE, $B7, $E7, $1C, $C4, $76, $E3,
$5D, $AD, $11, $70, $16, $36, $8B, $C4, $73, $18, $7B, $37, $FF, $20, $ED, $C2,
$3B, $96, $CE, $32, $3D, $00, $17, $01, $94, $86, $71, $7B, $3A, $60, $F7, $37,
$EC, $AC, $3A, $4E, $69, $3F, $73, $AD, $79, $AB, $2D, $F2, $0A, $23, $C4, $31,
$DA, $20, $55, $39, $83, $CE, $D3, $D4, $F1, $38, $12, $82, $C5, $1B, $EC, $BA,
$68, $81, $2C, $2D, $6E, $23, $6D, $0E, $84, $2B, $04, $11, $17, $5C, $B6, $27,
$77, $2D, $A1, $EA, $4C, $B2, $39, $8E, $05, $EB, $74, $BC, $E7, $A7, $BC, $02,
$4A, $45, $67, $71, $47, $34, $F4, $18, $41, $AD, $B0, $E9, $1E, $D5, $B1, $39,
$66, $FF, $DF, $47, $8A, $65, $C9, $0A, $74, $02, $4B, $7E, $46, $7B, $BC, $74,
$C4, $27, $16, $16, $18, $98, $25, $84, $C7, $BB, $E1, $61, $CB, $D4, $E0, $F8,
$44, $B1, $0B, $02, $2D, $AA, $F4, $17, $44, $9E, $07, $31, $2E, $58, $0C, $68,
$89, $B2, $3E, $B6, $9D, $5C, $6A, $28, $87, $E0, $EF, $AC, $B2, $CC, $FB, $AA,
$02, $17, $C7, $45, $30, $D0, $12, $3A, $A0, $54, $C2, $79, $8B, $05, $60, $9D,
$6A, $30, $0F, $CF, $63, $00, $B8, $A8, $D0, $3B, $3C, $E6, $24, $25, $16, $91,
$63, $F9, $A7, $B6, $04, $C6, $63, $5C, $43, $65, $6D, $C4, $3B, $33, $9D, $CE,
$95, $FB, $AE, $C4, $90, $4E, $F0, $64, $6B, $05, $9D, $84, $B2, $5D, $9C, $34,
$DA, $C1, $D2, $DD, $21, $F3, $10, $F1, $D5, $00, $27, $5B, $0B, $85, $19, $1A,
$30, $1A, $61, $85, $BF, $4E, $9C, $8B, $E4, $0F, $27, $6C, $9C, $6C, $1F, $AB,
$EC, $FF, $A1, $30, $5C, $0F, $C7, $3C, $67, $04, $9D, $56, $B3, $5C, $69, $4F,
$02, $BB, $1D, $7F, $CE, $AB, $F5, $CD, $66, $D0, $9E, $72, $D0, $B0, $79, $B2,
$EA, $20, $27, $16, $63, $BA, $1B, $03, $44, $40, $B2, $0A, $18, $8B, $24, $9F,
$2A, $5F, $EF, $B6, $22, $AB, $E6, $F3, $42, $88, $63, $F5, $DB, $9F, $D5, $97,
$0D, $3F, $00, $5A, $10, $8E, $AD, $E3, $01, $EF, $2D, $26, $25, $AA, $8F, $6C,
$25, $C0, $71, $C4, $C1, $04, $AB, $97, $8B, $5E, $9A, $7D, $3D, $FD, $39, $30,
$BB, $37, $D4, $96, $5A, $67, $29, $BF, $2E, $79, $E5, $C6, $C2, $54, $E4, $A8,
$52, $E8, $03, $F6, $ED, $8B, $8D, $AB, $55, $8D, $10, $2A, $4A, $17, $16, $08,
$0D, $44, $16, $EB, $E4, $31, $63, $C2, $DB, $89, $95, $F3, $88, $8E, $49, $7F,
$C7, $41, $77, $C9, $14, $2D, $FF, $CC, $35, $4D, $4A, $15, $89, $D7, $DF, $51,
$C8, $3B, $87, $15, $58, $40, $8B, $66, $43, $AA, $B3, $FB, $0C, $74, $D9, $8C,
$42, $CA, $D3, $40, $D1, $AC, $C9, $74, $B3, $BF, $1D, $CC, $CE, $4D, $B4, $35,
$F7, $5F, $74, $90, $20, $A9, $7E, $78, $B5, $D7, $6F, $33, $D0, $C9, $82, $77,
$33, $61, $CC, $D8, $A4, $B4, $AD, $70, $4B, $4E, $1B, $B7, $C2, $48, $3B, $8A,
$0F, $C7, $E4, $9D, $A9, $69, $35, $15, $87, $1C, $E3, $27, $7E, $AD, $47, $88,
$44, $A1, $0D, $A2, $39, $70, $F7, $75, $E8, $3A, $0D, $22, $B1, $A4, $03, $79,
$99, $23, $EF, $43, $59, $B5, $E3, $77, $68, $E6, $88, $F2, $22, $80, $D5, $A6,
$7B, $71, $B2, $B8, $40, $93, $10, $E6, $9E, $8A, $09, $C5, $C3, $1B, $DC, $22,
$51, $91, $6D, $8F, $30, $8B, $D3, $C8, $F3, $96, $D8, $79, $39, $18, $02, $F0,
$62, $50, $59, $42, $BE, $E1, $58, $7A, $86, $AC, $73, $95, $12, $61, $2D, $5C,
$DD, $B4, $D6, $6B, $7B, $68, $F2, $85, $F7, $BE, $E2, $05, $90, $CE, $C7, $B1,
$89, $AA, $80, $CC, $D0, $93, $03, $D2, $9B, $F4, $EF, $CD, $D2, $14, $0C, $9A,
$EF, $3C, $33, $BB, $DB, $2F, $B4, $5F, $96, $AC, $30, $BE, $EB, $CE, $0A, $8E,
$53, $DA, $4A, $2F, $C1, $F0, $64, $2F, $AE, $FB, $11, $5A, $D2, $DB, $0D, $65,
$89, $EC, $59, $B3, $3E, $8F, $76, $7D, $C7, $CA, $C0, $E0, $D9, $A4, $AE, $C7,
$C8, $41, $BF, $E0, $2B, $5E, $FC, $34, $D7, $9C, $18, $AF, $2B, $15, $B1, $88,
$91, $57, $43, $8B, $78, $36, $06, $A2, $7D, $D8, $D1, $B7, $3C, $E5, $03, $3C,
$7A, $51, $BD, $81, $41, $91, $F6, $BD, $BD, $B2, $81, $5F, $FA, $63, $34, $60,
$AB, $58, $4A, $D8, $65, $16, $4B, $C5, $40, $EB, $BF, $29, $3F, $EC, $0D, $B3,
$5F, $E3, $5F, $45, $A2, $DC, $1A, $F6, $41, $52, $7F, $79, $6B, $4F, $84, $01,
$3B, $91, $D6, $85, $32, $97, $65, $40, $AE, $73, $09, $6A, $4F, $4B, $15, $91,
$99, $86, $B0, $22, $D4, $44, $0E, $F0, $91, $4B, $B0, $E3, $9D, $BA, $8E, $F3,
$A6, $9A, $0A, $70, $83, $3A, $A6, $85, $A5, $9E, $BC, $B4, $6E, $15, $2A, $E1,
$5A, $1F, $50, $D3, $24, $C8, $0A, $4D, $78, $FB, $51, $FD, $F2, $5B, $5C, $5F,
$04, $0F, $3A, $E9, $BF, $E5, $41, $11, $56, $10, $3E, $39, $B4, $24, $49, $9F,
$10, $81, $9B, $8E, $CF, $C5, $EE, $5E, $D2, $D2, $38, $40, $35, $30, $4D, $3D,
$A3, $0B, $61, $1E, $EE, $87, $FC, $8A, $4E, $64, $50, $A8, $75, $1E, $E6, $D8,
$84, $C5, $6E, $E2, $7B, $71, $DD, $49, $A5, $85, $7B, $BE, $77, $D0, $14, $3D,
$DA, $4F, $8C, $FB, $50, $B9, $D7, $38, $B3, $CF, $F5, $83, $9A, $14, $D2, $8B,
$D5, $EA, $BF, $67, $30, $C1, $B5, $57, $AC, $08, $26, $C7, $A0, $DA, $77, $4E,
$CD, $73, $6D, $8C, $E9, $47, $E2, $96, $56, $F0, $99, $55, $11, $C5, $48, $C0,
$A5, $5A, $0C, $E0, $4D, $A6, $64, $B6, $5E, $A1, $FF, $EC, $DC, $89, $57, $CC,
$9F, $5E, $D6, $CF, $8D, $8A, $1C, $54, $6B, $5A, $97, $3E, $CD, $35, $12, $C1,
$07, $16, $69, $00, $DF, $4A, $48, $3D, $40, $3B, $EA, $C5, $B2, $40, $F7, $55,
$35, $4D, $B6, $3B, $D6, $3D, $31, $CE, $79, $FB, $AE, $C2, $E2, $60, $A3, $6C,
$D4, $CD, $A3, $E6, $D2, $B6, $AC, $1D, $86, $87, $AF, $A9, $0C, $23, $BE, $D3,
$5B, $22, $C9, $B9, $AC, $C9, $A2, $3C, $73, $44, $C0, $54, $C1, $93, $4D, $BE,
$F9, $19, $A0, $09, $7E, $50, $40, $75, $67, $CD, $D6, $A1, $75, $55, $7B, $1F,
$B1, $90, $35, $EA, $55, $6F, $0F, $F9, $51, $34, $C3, $10, $5C, $BC, $B6, $98,
$96, $F4, $1E, $90, $F6, $01, $73, $E3, $3E, $B7, $00, $2E, $F5, $BA, $88, $AF,
$A5, $5C, $6F, $34, $94, $DB, $77, $BA, $87, $77, $F8, $EC, $78, $61, $29, $EE,
$42, $65, $3B, $59, $C0, $FC, $54, $9A, $FA, $BD, $44, $9F, $6C, $A5, $CC, $ED,
$1E, $73, $8A, $33, $C4, $2A, $52, $76, $28, $96, $C8, $2E, $6B, $17, $26, $03,
$5A, $D1, $D5, $91, $9E, $CD, $A2, $3A, $83, $16, $4C, $9B, $3F, $10, $8A, $F4,
$90, $91, $10, $F1, $76, $EA, $7B, $1B, $89, $16, $7F, $62, $AE, $FA, $11, $6D,
$0E, $A0, $4B, $B4, $B4, $3A, $03, $AC, $EC, $91, $73, $ED, $65, $41, $EA, $A4,
$F5, $8B, $9E, $0E, $97, $BB, $0D, $F1, $07, $22, $46, $7B, $ED, $E8, $1E, $8B,
$D2, $8A, $82, $D3, $13, $1D, $A6, $A4, $52, $A4, $AA, $86, $DB, $95, $72, $FF,
$E5, $A9, $89, $61, $8A, $65, $7A, $F9, $D6, $8B, $B1, $66, $4A, $85, $44, $12,
$52, $49, $C0, $33, $E5, $E4, $C3, $05, $89, $FE, $32, $C8, $A0, $AA, $52, $F8,
$BF, $6D, $EF, $96, $E2, $CB, $8F, $55, $6B, $04, $24, $B4, $C9, $E9, $4E, $4B,
$46, $14, $FA, $B5, $04, $DA, $D1, $BD, $EC, $9B, $81, $11, $B1, $01, $C6, $81,
$4A, $06, $AC, $0D, $23, $47, $08, $A4, $C1, $B6, $AA, $02, $39, $2B, $51, $E7,
$44, $F9, $83, $C7, $90, $23, $E9, $6A, $8B, $37, $6C, $71, $64, $BE, $F5, $8E,
$D1, $CE, $29, $D6, $3A, $03, $06, $CB, $5E, $A7, $03, $EB, $67, $01, $E9, $C7,
$E4, $89, $F0, $32, $69, $5C, $04, $BE, $CF, $81, $D2, $EB, $3D, $30, $D2, $5F,
$FC, $DE, $18, $9F, $BB, $7C, $5A, $0E, $B6, $99, $A3, $7B, $D3, $6C, $86, $28,
$88, $24, $38, $F3, $8F, $40, $C5, $C2, $D2, $48, $CE, $58, $A3, $F8, $02, $7A,
$31, $26, $60, $E3, $F6, $A7, $A6, $68, $9F, $8B, $CD, $2B, $DC, $AC, $5E, $00,
$E9, $4F, $1B, $A6, $01, $5B, $78, $FC, $9F, $29, $07, $35, $1B, $E2, $9C, $62,
$B7, $1A, $23, $46, $65, $E6, $10, $AB, $0D, $0B, $38, $36, $84, $94, $36, $58,
$98, $24, $AB, $E6, $22, $3C, $CB, $8D, $20, $91, $45, $F1, $B9, $64, $A5, $5E,
$3A, $BD, $FE, $10, $5A, $6D, $72, $B2, $44, $64, $9E, $60, $1D, $73, $C1, $EF,
$46, $3E, $36, $FD, $1A, $8B, $31, $40, $DC, $13, $07, $BB, $FC, $CF, $CC, $43,
$97, $81, $AF, $CC, $B0, $55, $33, $A5, $65, $AF, $43, $5D, $8B, $A0, $B3, $04,
$0A, $6F, $B4, $C7, $8A, $FB, $39, $BD, $BE, $3A, $46, $21, $2E, $8D, $37, $0B,
$B0, $CF, $FD, $A7, $90, $DE, $7C, $0A, $AF, $C2, $5C, $D7, $C8, $84, $AA, $7C,
$63, $90, $07, $F1, $0C, $43, $1E, $2B, $FF, $2B, $5B, $6C, $32, $EC, $A1, $78,
$D7, $D9, $66, $FE, $C9, $27, $68, $93, $36, $27, $7C, $27, $8B, $1A, $55, $32,
$91, $2C, $F8, $3D, $FD, $2A, $86, $3F, $A2, $14, $02, $46, $DF, $A9, $FF, $6C,
$B3, $BB, $2A, $47, $22, $9F, $5A, $C6, $BA, $B9, $53, $66, $AF, $F8, $82, $DB,
$BF, $C3, $97, $00, $2E, $57, $37, $21, $6D, $E6, $FA, $58, $ED, $65, $5D, $AE,
$D8, $05, $93, $23, $1B, $41, $02, $F8, $B1, $02, $DD, $35, $CE, $8E, $9E, $5E,
$CD, $D5, $19, $8C, $84, $1B, $C8, $A4, $B9, $94, $BB, $4E, $C3, $46, $6E, $81,
$61, $87, $A9, $C6, $8E, $27, $EF, $AF, $99, $AC, $2C, $8C, $98, $F8, $96, $5E,
$B4, $BE, $94, $E1, $6A, $01, $26, $EB, $C2, $59, $77, $27, $5E, $A0, $BB, $30,
$B6, $D0, $BA, $A1, $13, $05, $AE, $28, $0A, $9E, $B9, $96, $B0, $DE, $86, $7F,
$85, $AA, $C4, $27, $1D, $73, $30, $FE, $27, $EE, $FE, $32, $74, $01, $E8, $A3,
$13, $0F, $94, $8B, $F3, $A6, $E7, $57, $76, $BB, $A8, $C7, $9E, $9B, $A0, $EA,
$AF, $D7, $CB, $C6, $FD, $47, $21, $B3, $CD, $53, $94, $4D, $05, $CE, $E4, $39,
$83, $5A, $FB, $EB, $DB, $98, $19, $9A, $31, $8D, $7C, $78, $00, $D3, $16, $DC,
$C4, $30, $E4, $89, $3B, $E2, $32, $97, $CD, $F3, $C0, $E2, $99, $DF, $62, $1A,
$DC, $85, $5A, $D7, $2F, $E1, $37, $BA, $CA, $9B, $68, $3C, $F5, $0F, $45, $51,
$89, $58, $1A, $CD, $36, $57, $7F, $F2, $14, $E1, $32, $AA, $E2, $69, $2D, $3F,
$49, $5F, $C9, $4F, $28, $28, $83, $51, $FC, $23, $10, $86, $E8, $82, $D1, $B6,
$C6, $3A, $DC, $A6, $55, $FC, $7F, $38, $8E, $0F, $AE, $23, $BA, $B7, $BB, $CE,
$B3, $DA, $E1, $B0, $3C, $8A, $0D, $EA, $F0, $B9, $C2, $69, $34, $C0, $62, $C2,
$F0, $60, $A3, $3C, $74, $B1, $C6, $9F, $5D, $78, $C9, $7A, $AF, $D8, $16, $0C,
$BE, $F3, $08, $F8, $4A, $DD, $6F, $23, $60, $33, $E9, $99, $A6, $41, $C3, $74,
$63, $51, $CB, $F1, $98, $00, $8E, $EF, $9A, $4C, $69, $2C, $F7, $5F, $4A, $1B,
$CD, $5E, $C1, $37, $9F, $7A, $B1, $01, $53, $0E, $23, $51, $A4, $61, $94, $08,
$02, $7E, $45, $9D, $5E, $D4, $EE, $26, $8D, $EC, $FD, $74, $31, $11, $60, $51,
$B6, $18, $2A, $2C, $6C, $A7, $B3, $1E, $DA, $B5, $90, $29, $C4, $D4, $C3, $83,
$AF, $85, $FA, $45, $CF, $21, $5A, $BD, $D0, $F9, $AB, $DF, $BB, $2D, $49, $9C,
$D6, $AE, $84, $1E, $ED, $0E, $C6, $77, $F5, $2C, $D3, $FB, $F3, $0D, $66, $9D,
$AD, $EA, $3E, $8A, $BE, $AA, $A7, $DD, $51, $D8, $79, $21, $0A, $25, $77, $06,
$5D, $DB, $5E, $AB, $6D, $94, $24, $43, $D1, $69, $16, $4B, $E6, $44, $68, $1B,
$22, $D2, $ED, $1D, $5E, $09, $E2, $0C, $16, $3E, $5A, $70, $6C, $BE, $8F, $F9,
$12, $0C, $D1, $41, $BF, $0B, $3C, $A6, $40, $71, $95, $69, $39, $E1, $71, $60,
$56, $95, $3D, $C0, $D1, $94, $A6, $1F, $B7, $7F, $A8, $94, $5B, $67, $8A, $77,
$99, $D6, $BF, $F1, $E3, $37, $F2, $3D, $C5, $90, $2B, $B1, $7A, $7D, $01, $B3,
$70, $36, $06, $40, $D0, $A6, $03, $99, $15, $08, $06, $F8, $9E, $CE, $CC, $35,
$1F, $97, $A5, $5A, $4E, $A2, $7B, $8F, $C0, $BC, $3F, $7A, $64, $25, $7A, $B7,
$C2, $F3, $34, $50, $41, $9A, $D7, $60, $9E, $57, $26, $07, $5A, $3C, $BA, $AA,
$CA, $F6, $94, $AF, $6C, $54, $EB, $CF, $A9, $3B, $B9, $67, $41, $CC, $92, $36,
$4C, $D2, $AE, $85, $76, $DE, $62, $5B, $5E, $7A, $27, $FA, $2C, $2B, $58, $AA,
$8C, $6D, $7C, $B3, $49, $7E, $7A, $F1, $63, $94, $BE, $22, $C1, $09, $AF, $13,
$45, $AA, $50, $A9, $53, $0F, $30, $12, $0B, $89, $9F, $8D, $6F, $0E, $C5, $5A,
$D2, $28, $46, $A1, $0A, $1C, $3B, $3F, $B2, $6D, $17, $78, $C9, $67, $0B, $C9,
$6A, $5A, $80, $13, $D0, $BE, $DD, $41, $01, $DC, $14, $DC, $CB, $E8, $B1, $AA,
$36, $18, $C4, $7C, $71, $08, $C8, $B4, $56, $FF, $0D, $E0, $8C, $1F, $0C, $8A,
$E9, $CC, $C0, $36, $F4, $BD, $13, $2C, $50, $C2, $8C, $EC, $B3, $75, $6B, $69,
$87, $D3, $93, $0F, $72, $2D, $43, $77, $33, $1E, $C9, $D0, $91, $E0, $DD, $1F,
$81, $11, $4A, $CE, $ED, $62, $AC, $9F, $D4, $E6, $F6, $EC, $DE, $94, $13, $69,
$B5, $ED, $4C, $88, $78, $B9, $0E, $BE, $21, $BE, $F5, $A3, $26, $EC, $68, $74,
$AD, $2A, $74, $B8, $91, $52, $CA, $90, $2C, $E4, $B8, $4C, $3B, $42, $40, $44,
$74, $CE, $E6, $3E, $D3, $1A, $9B, $59, $45, $53, $55, $AE, $A0, $B9, $75, $86,
$86, $69, $B8, $E7, $E6, $61, $DE, $0C, $3D, $B0, $D4, $34, $0C, $D2, $E3, $23,
$00, $01, $72, $7C, $CF, $61, $FB, $F2, $92, $86, $B6, $84, $4C, $5F, $31, $E0,
$52, $0A, $E1, $7A, $F2, $FF, $00, $CB, $DE, $0B, $B2, $27, $58, $82, $3B, $44,
$0A, $A1, $2F, $41, $8B, $01, $68, $C2, $60, $17, $FE, $33, $14, $FF, $69, $A7,
$FE, $A5, $68, $49, $1B, $DA, $E6, $72, $17, $FD, $77, $DE, $E4, $2A, $9D, $83,
$67, $95, $B1, $F0, $42, $74, $C9, $1E, $AF, $F6, $22, $95, $6A, $93, $6B, $0E,
$5D, $9E, $B3, $E4, $8D, $04, $A8, $F9, $D9, $A2, $38, $AD, $CF, $69, $AE, $E7,
$45, $F2, $EE, $75, $A2, $1C, $5C, $A6, $42, $F3, $C7, $26, $40, $8C, $65, $83,
$29, $53, $3E, $37, $EA, $6D, $42, $62, $22, $C1, $9B, $0B, $2A, $13, $9C, $24,
$24, $5C, $A0, $55, $0C, $56, $0E, $28, $AB, $19, $FB, $5F, $21, $B5, $E8, $FA,
$E3, $D6, $4B, $00, $C7, $2A, $F1, $80, $B8, $9C, $99, $62, $48, $0A, $39, $E7,
$FA, $A5, $8E, $B4, $40, $BB, $BA, $7E, $01, $B8, $F9, $10, $13, $C2, $5F, $B2,
$B7, $9C, $BB, $B8, $3B, $D9, $D5, $0B, $FE, $73, $E8, $70, $BE, $90, $27, $D9,
$9A, $A8, $2D, $20, $D5, $90, $6C, $0C, $B2, $9F, $B7, $69, $5B, $FD, $D0, $08,
$F9, $D5, $4C, $F5, $9D, $07, $E7, $FF, $A0, $53, $60, $AA, $38, $D5, $54, $15,
$D5, $8B, $BD, $65, $C1, $13, $3D, $21, $4F, $1F, $A1, $D5, $53, $9C, $3F, $D7,
$DB, $85, $4D, $74, $71, $2D, $21, $E4, $D3, $F1, $A9, $DE, $CE, $13, $F4, $92,
$34, $C4, $DC, $E5, $27, $94, $33, $FA, $11, $A5, $B7, $7A, $70, $E8, $92, $B8,
$8C, $6E, $AF, $6E, $1F, $D9, $56, $0A, $60, $9B, $EF, $D6, $70, $D5, $3A, $EB,
$9A, $9D, $E0, $F5, $06, $29, $02, $A3, $8F, $3A, $E0, $F6, $95, $7F, $BF, $A2,
$5D, $45, $64, $FF, $7D, $B1, $5C, $77, $88, $EE, $E5, $AD, $0C, $BD, $7D, $4A,
$9D, $FB, $11, $F8, $A5, $AA, $6E, $75, $10, $AB, $F6, $38, $EA, $C6, $BA, $0E,
$09, $1C, $43, $62, $17, $FC, $FA, $A0, $C4, $0A, $05, $FD, $8A, $4A, $15, $DD,
$BE, $F7, $94, $3D, $4E, $A6, $52, $BF, $AA, $25, $57, $96, $B2, $DC, $9D, $25,
$45, $E4, $C6, $FB, $E5, $A4, $34, $2E, $C5, $80, $06, $59, $B6, $8E, $66, $09,
$CB, $71, $BC, $0C, $D5, $C0, $AE, $07, $90, $3B, $91, $E1, $95, $1B, $06, $B9,
$2A, $93, $51, $87, $BC, $D7, $8A, $BA, $4A, $69, $9A, $85, $3F, $0E, $F4, $FF,
$18, $F0, $F6, $7A, $BF, $AF, $F7, $3D, $45, $B8, $99, $A6, $8F, $BF, $14, $60,
$E0, $06, $8C, $43, $BC, $DE, $D4, $F8, $85, $A7, $80, $61, $68, $64, $DD, $E7,
$9E, $B8, $84, $6E, $25, $67, $86, $78, $E5, $80, $9A, $76, $08, $FD, $2F, $0F,
$CD, $DF, $E9, $FB, $B6, $EB, $51, $E0, $65, $78, $DD, $89, $E0, $95, $35, $B9,
$19, $E9, $58, $3C, $13, $4D, $55, $FD, $41, $A0, $3C, $10, $EC, $A6, $06, $BE,
$27, $81, $5B, $23, $DC, $54, $CA, $36, $25, $39, $4A, $3E, $CD, $CF, $B0, $EF,
$AD, $28, $5B, $18, $7F, $1C, $BE, $73, $9D, $68, $28, $E9, $5F, $33, $E7, $DD,
$54, $5F, $35, $43, $21, $EF, $E9, $F1, $2C, $A0, $E0, $68, $24, $B6, $42, $BA,
$43, $38, $C2, $4E, $1F, $D6, $A6, $90, $4F, $EF, $4D, $CA, $12, $2E, $B5, $A9,
$5C, $E4, $8B, $58, $92, $0B, $28, $DD, $B7, $C5, $07, $70, $37, $82, $28, $9C,
$31, $13, $05, $0E, $61, $E9, $4F, $86, $88, $C0, $4A, $07, $CA, $D4, $69, $FE,
$C6, $CA, $EE, $1F, $DA, $1F, $FA, $65, $C6, $99, $53, $0A, $D6, $D1, $FA, $1B,
$B1, $03, $7F, $2D, $C2, $00, $03, $4D, $D4, $35, $9F, $33, $E9, $5D, $D6, $48,
$01, $23, $A4, $74, $FE, $3A, $D9, $19, $C9, $B5, $EF, $C9, $D1, $7C, $99, $02,
$19, $15, $E7, $FE, $47, $8B, $F0, $5D, $11, $74, $72, $03, $9E, $35, $47, $6E,
$77, $CC, $09, $24, $1F, $ED, $AA, $B8, $03, $3A, $18, $63, $8C, $A3, $00, $05,
$B1, $D5, $07, $5B, $AB, $F6, $64, $C2, $65, $54, $27, $AB, $9E, $7D, $2C, $44,
$C8, $8E, $9D, $20, $56, $65, $12, $5E, $A9, $6A, $0A, $CC, $49, $21, $F6, $B4,
$D2, $D0, $E1, $73, $D1, $E1, $D0, $47, $03, $AD, $0F, $62, $FF, $5F, $44, $0C,
$4E, $9A, $B3, $7B, $84, $6D, $2F, $AA, $93, $44, $D2, $CD, $36, $D6, $07, $99,
$EC, $63, $43, $7A, $72, $3E, $29, $3E, $72, $F5, $12, $0F, $A9, $E1, $9A, $C3,
$B5, $61, $07, $2B, $7F, $8C, $FA, $AC, $7E, $EE, $02, $13, $95, $0F, $9C, $6D,
$5B, $8D, $0D, $77, $9B, $AF, $A7, $74, $85, $72, $9B, $FE, $19, $39, $CA, $CD,
$CD, $6A, $37, $C7, $38, $C2, $30, $49, $77, $20, $1F, $41, $A6, $0B, $9C, $23,
$6E, $3A, $C1, $E5, $68, $4E, $12, $19, $7B, $93, $20, $56, $44, $FD, $F0, $05,
$8E, $73, $FB, $A0, $88, $CA, $DC, $AD, $36, $54, $BA, $8B, $4A, $06, $05, $5A,
$B3, $ED, $D8, $AC, $40, $79, $35, $A0, $7C, $8F, $0F, $8F, $B6, $C4, $7A, $04,
$C5, $E9, $EA, $F5, $92, $5E, $D1, $C8, $A4, $3E, $48, $FF, $00, $F1, $BA, $5A,
$81, $B0, $46, $26, $59, $F8, $02, $01, $93, $10, $5F, $CA, $84, $3B, $73, $25,
$0F, $89, $73, $42, $17, $A6, $1B, $6C, $B8, $68, $81, $71, $39, $BD, $0E, $2E,
$0F, $E5, $BF, $9E, $30, $6F, $C5, $87, $8F, $F9, $88, $5F, $A3, $4F, $63, $04,
$DB, $26, $F4, $A3, $67, $CF, $42, $29, $F4, $EE, $B5, $5C, $7A, $27, $D3, $F7,
$A0, $CE, $71, $44, $24, $06, $B4, $26, $67, $13, $A7, $95, $E2, $0E, $04, $1F,
$78, $56, $89, $6C, $3B, $25, $D8, $BB, $0C, $A2, $4A, $DD, $D9, $78, $EE, $C2,
$33, $FF, $3D, $D8, $75, $F4, $74, $CE, $D9, $6F, $42, $06, $02, $44, $D5, $08,
$F4, $4F, $20, $DF, $75, $0B, $EA, $7C, $0C, $30, $93, $28, $25, $3F, $16, $75,
$53, $8E, $E8, $6D, $D6, $69, $77, $7B, $05, $61, $5D, $79, $47, $00, $B2, $94,
$A3, $70, $F5, $85, $DE, $F9, $5E, $FE, $41, $17, $6F, $1B, $49, $C8, $36, $EC,
$B9, $84, $53, $B0, $BA, $47, $CE, $FE, $3B, $3C, $59, $7C, $83, $C3, $3F, $1A,
$36, $9E, $6A, $DF, $3E, $15, $9B, $1D, $DE, $08, $26, $2E, $5C, $7C, $88, $5E,
$78, $69, $2C, $12, $45, $81, $8E, $30, $FF, $70, $40, $10, $99, $D4, $F7, $86,
$8B, $89, $65, $2C, $24, $31, $C8, $A9, $8D, $3B, $19, $BE, $73, $09, $03, $F0,
$3F, $F2, $E9, $93, $71, $1A, $3B, $5F, $84, $2F, $6D, $9C, $10, $A2, $89, $5B,
$2B, $E1, $23, $FE, $88, $FC, $03, $CE, $DB, $FB, $6C, $62, $D0, $46, $05, $F6,
$94, $14, $36, $E8, $22, $89, $BF, $7A, $C8, $C8, $38, $5F, $93, $09, $CD, $52,
$5E, $08, $E6, $ED, $B3, $C6, $A9, $67, $C4, $D9, $EC, $79, $CD, $50, $1B, $D6,
$23, $97, $4D, $DB, $97, $70, $FA, $43, $54, $73, $32, $98, $68, $43, $A7, $80,
$CF, $F8, $01, $96, $DF, $C3, $01, $10, $00, $E7, $C4, $A3, $F5, $56, $29, $3A,
$80, $19, $4D, $42, $90, $46, $8C, $5D, $04, $72, $E8, $F3, $9F, $06, $74, $16,
$AC, $9C, $C8, $47, $4F, $89, $92, $1D, $25, $BC, $78, $4E, $44, $55, $B4, $78,
$3D, $13, $5E, $EF, $90, $37, $0B, $01, $42, $68, $A6, $AF, $69, $4D, $AB, $8E,
$D5, $AB, $67, $F5, $0D, $82, $A9, $0C, $D2, $9C, $94, $4D, $E7, $E4, $3E, $04,
$18, $B0, $36, $BA, $B1, $A8, $15, $41, $E8, $17, $62, $C8, $4B, $52, $79, $7A,
$08, $86, $BD, $6C, $D9, $F6, $82, $12, $F2, $A2, $B0, $5B, $A8, $A8, $81, $16,
$E8, $F9, $EA, $F5, $DD, $E9, $75, $A3, $BB, $B6, $9F, $26, $35, $43, $5B, $6D,
$52, $FD, $26, $09, $89, $9F, $BC, $32, $3C, $65, $AA, $BF, $B1, $8B, $09, $60,
$AF, $98, $C3, $00, $48, $73, $89, $97, $50, $3A, $D5, $B4, $41, $24, $44, $EC,
$CB, $46, $ED, $3A, $D9, $44, $97, $61, $BB, $1B, $17, $ED, $2A, $A7, $E0, $E2,
$CA, $15, $66, $EF, $26, $97, $7A, $A5, $0A, $4C, $02, $82, $35, $D5, $62, $2D,
$9E, $D7, $0E, $9F, $22, $19, $EC, $56, $8D, $DF, $35, $94, $9A, $8D, $9C, $11,
$13, $9D, $17, $8E, $EF, $88, $A2, $2F, $49, $7F, $36, $28, $47, $4A, $30, $68,
$D2, $C5, $D3, $59, $9D, $98, $FA, $F1, $3F, $B2, $CF, $A2, $66, $8A, $22, $30,
$6A, $61, $30, $3B, $83, $66, $DC, $28, $B1, $BF, $7E, $AF, $84, $03, $27, $92,
$35, $DE, $09, $34, $96, $4F, $2A, $D3, $3E, $17, $B0, $15, $8C, $CF, $E2, $5B,
$AB, $E8, $2F, $60, $87, $84, $6D, $DB, $E3, $E3, $1E, $1B, $8F, $AF, $A0, $AD,
$C2, $13, $C9, $5F, $59, $8F, $7C, $3A, $7C, $90, $17, $A2, $C2, $D1, $FA, $6E,
$25, $DA, $37, $E7, $6F, $24, $3C, $31, $1C, $B1, $A9, $37, $F4, $31, $5D, $96,
$ED, $8D, $F7, $B3, $72, $7E, $39, $DC, $60, $02, $73, $E7, $51, $F8, $A9, $5C,
$67, $A0, $DC, $F4, $13, $29, $E7, $15, $F7, $F4, $FA, $F6, $2F, $22, $B4, $EB,
$F3, $80, $15, $3D, $C3, $BE, $BD, $9C, $AC, $A2, $42, $FA, $2E, $E1, $26, $FF,
$73, $CC, $47, $1C, $52, $78, $63, $05, $22, $37, $0D, $BE, $97, $0A, $33, $85,
$81, $4A, $AE, $63, $FE, $79, $F1, $A1, $C8, $CC, $36, $A4, $0F, $57, $7F, $76,
$BC, $73, $28, $64, $C0, $B0, $6E, $78, $71, $4D, $74, $18, $1F, $1F, $15, $2B,
$DD, $73, $C3, $9C, $26, $16, $DF, $59, $DC, $2C, $E0, $DB, $4C, $1D, $0E, $21,
$B0, $11, $26, $35, $44, $DC, $7B, $D7, $0A, $8E, $85, $B3, $BB, $DD, $B9, $47,
$03, $F8, $F5, $84, $CC, $34, $76, $EC, $2A, $53, $2D, $9C, $F2, $6F, $34, $F9,
$05, $E6, $70, $2E, $E0, $21, $00, $A0, $0B, $6D, $22, $1E, $4D, $57, $19, $52,
$B7, $EE, $2F, $01, $74, $90, $74, $19, $67, $1A, $63, $0F, $56, $33, $F0, $5E,
$5F, $39, $15, $B6, $CB, $E2, $D0, $B8, $08, $6D, $6C, $AA, $75, $00, $80, $58,
$69, $8B, $4A, $51, $B0, $F5, $E0, $6D, $7B, $DC, $7D, $C9, $D1, $60, $F5, $F7,
$B4, $48, $9B, $C6, $D1, $A4, $29, $BE, $C3, $5B, $7A, $9F, $76, $A1, $08, $F9,
$14, $46, $BD, $7B, $C3, $A3, $02, $34, $B2, $5C, $D8, $F5, $5A, $61, $75, $6B,
$81, $53, $3E, $71, $9F, $00, $45, $CB, $D0, $D6, $E8, $19, $A0, $6A, $6F, $04,
$5C, $92, $4A, $5C, $3E, $50, $F1, $5A, $DB, $A4, $5F, $FC, $C6, $9D, $19, $A3,
$D2, $0F, $4F, $2E, $2F, $27, $E9, $D1, $B4, $7F, $1E, $FD, $3D, $B8, $DF, $18,
$E7, $25, $2D, $48, $B3, $E7, $81, $F7, $EF, $6A, $11, $0F, $BE, $BA, $F7, $7D,
$D9, $C3, $C1, $FE, $67, $88, $0D, $45, $90, $37, $16, $8F, $69, $A3, $AB, $D2,
$D7, $EE, $AA, $92, $D7, $4D, $1A, $60, $6F, $7C, $21, $D9, $12, $E8, $C9, $2A,
$3F, $37, $6D, $AA, $86, $3E, $66, $07, $B1, $52, $4F, $C6, $B3, $4D, $FA, $90,
$71, $32, $A6, $39, $D7, $7E, $04, $FE, $C6, $A8, $0E, $51, $BA, $C1, $6C, $18,
$6B, $C2, $5F, $E1, $1A, $8F, $14, $71, $76, $94, $51, $8A, $C3, $C8, $67, $28,
$25, $75, $68, $22, $FB, $CB, $0E, $6A, $CD, $1F, $F0, $C9, $3E, $55, $AC, $4D,
$F8, $81, $98, $59, $A2, $67, $B9, $C8, $E7, $AB, $5E, $22, $AD, $B7, $50, $0C,
$F5, $87, $E5, $8C, $7C, $B9, $32, $EE, $BA, $CB, $56, $24, $3F, $93, $31, $3B,
$EF, $C1, $9B, $83, $97, $12, $5D, $FD, $C1, $90, $EF, $93, $5B, $C5, $A5, $24,
$4E, $1F, $42, $6C, $FB, $C6, $77, $AC, $1F, $57, $0B, $60, $34, $0F, $91, $1E,
$10, $1B, $47, $E6, $C0, $4E, $BB, $32, $04, $64, $D6, $E2, $08, $69, $92, $89,
$36, $30, $9F, $88, $83, $F7, $CB, $2F, $D4, $30, $3C, $A2, $F5, $1A, $DD, $B0,
$BF, $93, $CB, $F9, $10, $DB, $3A, $32, $70, $22, $27, $68, $BC, $7B, $7A, $A4,
$8A, $80, $BB, $19, $DC, $84, $33, $DD, $A2, $1E, $86, $1F, $E0, $2D, $70, $14,
$92, $A1, $C3, $AB, $5C, $E4, $E4, $E0, $E8, $92, $90, $51, $9B, $2A, $B7, $CA,
$DC, $3A, $0B, $06, $E3, $CF, $5E, $33, $D9, $FE, $93, $7A, $D8, $8A, $D6, $B1,
$A0, $30, $4A, $EA, $B7, $32, $2A, $71, $A9, $E4, $F1, $3A, $0C, $16, $40, $4C,
$46, $7A, $9B, $4F, $24, $F9, $68, $5E, $1E, $EA, $60, $0A, $6F, $3D, $1A, $0A,
$56, $79, $1C, $A7, $27, $07, $4A, $67, $83, $7E, $A1, $14, $E2, $3B, $D0, $FA,
$38, $50, $6A, $8A, $1A, $74, $AF, $93, $D9, $95, $DA, $D4, $93, $97, $AA, $FD,
$4F, $61, $4A, $BB, $39, $88, $12, $C8, $4C, $B8, $BD, $24, $BF, $C7, $6C, $FE,
$54, $46, $D9, $4B, $85, $44, $5D, $32, $09, $95, $26, $5F, $CB, $EF, $88, $B5,
$10, $05, $52, $25, $DC, $77, $29, $44, $79, $33, $71, $3C, $67, $BD, $DA, $78,
$6D, $48, $14, $00, $2B, $5C, $A8, $BF, $3E, $9D, $6E, $B0, $0A, $DF, $8A, $F5,
$3B, $3C, $F8, $8A, $DC, $4E, $22, $65, $01, $86, $93, $53, $24, $80, $9C, $FE,
$5F, $B3, $93, $81, $12, $FE, $DB, $B9, $B3, $67, $5D, $F4, $4D, $69, $2B, $37,
$11, $4A, $29, $4D, $DA, $80, $26, $05, $2A, $0F, $C0, $E5, $09, $1E, $C3, $30,
$7F, $1A, $B2, $F8, $67, $BA, $0C, $C2, $44, $91, $06, $E4, $78, $51, $B4, $95,
$8D, $9F, $D9, $8B, $7C, $8F, $D1, $57, $B5, $45, $29, $C1, $A4, $52, $48, $6A,
$89, $54, $CB, $0F, $CF, $2B, $D3, $22, $5C, $B6, $CC, $E6, $B6, $64, $62, $38,
$2C, $B9, $FF, $B8, $46, $6C, $C4, $CA, $EB, $7E, $DA, $79, $A7, $B9, $14, $46,
$93, $88, $37, $9C, $9D, $5A, $BC, $68, $28, $5C, $D1, $27, $3A, $99, $A6, $6C,
$EF, $FB, $41, $A4, $44, $9B, $EF, $71, $E4, $B3, $30, $EC, $05, $92, $BA, $04,
$0C, $6A, $27, $5F, $5D, $30, $80, $BA, $B6, $6D, $8C, $D8, $C7, $3E, $83, $2E,
$D6, $AB, $1F, $38, $64, $C1, $C1, $2B, $E8, $6C, $62, $66, $31, $A6, $AF, $6E,
$91, $4B, $36, $07, $EE, $78, $CA, $69, $B0, $2F, $59, $B9, $9C, $1A, $5B, $C2,
$33, $BB, $E6, $76, $2A, $B3, $0C, $5E, $9C, $D5, $B7, $E6, $97, $DF, $62, $1C,
$E6, $4A, $39, $A3, $AB, $25, $F2, $ED, $E3, $84, $C5, $D9, $7B, $D2, $48, $CC,
$A8, $8B, $ED, $77, $E3, $48, $C9, $5A, $CA, $92, $C8, $4F, $78, $0D, $E0, $E9,
$44, $B2, $42, $54, $71, $B5, $2E, $6E, $D1, $A5, $E3, $8F, $CB, $FB, $2B, $83,
$88, $D1, $69, $7E, $39, $81, $74, $16, $7E, $F2, $B5, $43, $EB, $34, $CF, $42,
$47, $83, $2E, $09, $2F, $82, $76, $7E, $12, $A9, $06, $17, $1C, $9B, $94, $05,
$6B, $88, $CE, $8F, $F9, $B1, $64, $39, $19, $17, $14, $E7, $E3, $51, $06, $62,
$B4, $4E, $53, $EA, $5C, $10, $34, $AA, $F8, $15, $9F, $92, $7E, $77, $5C, $D7,
$27, $3B, $8E, $A3, $35, $31, $2E, $EF, $FF, $54, $63, $34, $AE, $C2, $AA, $8F,
$93, $92, $6D, $01, $AD, $8B, $7E, $9F, $47, $0F, $63, $0C, $96, $83, $00, $35,
$8C, $1A, $64, $F4, $B3, $A8, $93, $D9, $50, $C1, $D5, $DE, $17, $EF, $EF, $97,
$D3, $8A, $07, $A1, $BB, $07, $76, $80, $AB, $EE, $77, $44, $16, $02, $35, $6E,
$70, $01, $5E, $EC, $DE, $34, $C0, $A5, $69, $C2, $63, $B8, $67, $6D, $D1, $FD,
$E7, $D0, $83, $38, $B2, $9F, $97, $97, $DB, $82, $75, $DC, $55, $0E, $FD, $AC,
$0A, $41, $46, $94, $42, $6F, $C9, $CC, $13, $3A, $90, $98, $8F, $A6, $9E, $E2,
$7C, $5E, $33, $71, $0F, $90, $66, $F4, $80, $98, $F7, $6E, $B3, $EB, $D0, $9D,
$27, $1E, $99, $5E, $1E, $18, $28, $5C, $14, $BA, $AD, $B5, $ED, $F5, $3A, $05,
$34, $BA, $BF, $9F, $22, $91, $EB, $62, $5E, $DA, $1B, $DA, $81, $E8, $DA, $44,
$E1, $B3, $DE, $76, $8E, $0A, $0E, $79, $7A, $8C, $39, $25, $35, $CB, $56, $FA,
$56, $C3, $1B, $C4, $3A, $57, $5B, $5F, $49, $87, $7E, $9C, $0C, $B1, $45, $B9,
$14, $35, $62, $07, $C6, $9C, $C3, $F3, $E8, $5E, $E1, $03, $5C, $A9, $12, $77,
$15, $60, $E7, $C7, $DF, $1C, $4E, $C8, $75, $C3, $BA, $80, $BF, $82, $3D, $E3,
$AF, $45, $5F, $A5, $61, $10, $29, $A4, $A4, $4E, $09, $63, $49, $15, $D8, $D9,
$BB, $43, $A8, $09, $0F, $7D, $B8, $6C, $5B, $43, $D1, $35, $09, $2C, $A7, $9F,
$2D, $E7, $DE, $4A, $BC, $85, $9D, $18, $36, $B7, $EC, $AA, $1A, $5B, $93, $95,
$45, $9D, $51, $E4, $A6, $DE, $87, $41, $C8, $81, $42, $68, $C6, $ED, $CC, $D6,
$CE, $F2, $94, $46, $33, $B5, $0E, $7C, $D5, $E2, $8B, $A8, $D8, $4C, $CA, $AF,
$90, $FB, $E0, $A6, $A0, $EB, $AB, $49, $6E, $22, $AA, $EB, $FC, $B4, $E2, $5B,
$55, $5D, $0C, $E1, $3D, $ED, $0F, $67, $E9, $4A, $DD, $28, $6F, $06, $D3, $C4,
$5B, $DD, $59, $18, $CE, $13, $75, $F3, $4D, $41, $C9, $50, $D9, $44, $0C, $69,
$92, $EA, $C6, $45, $45, $2C, $93, $64, $D8, $3B, $23, $6F, $67, $4F, $84, $E3,
$B0, $24, $24, $17, $DE, $B4, $B3, $72, $1A, $C2, $0D, $C3, $6E, $4C, $91, $58,
$81, $46, $FF, $1E, $A4, $A9, $3C, $76, $15, $5F, $69, $14, $FF, $02, $76, $C7,
$1D, $08, $7F, $1F, $14, $25, $EF, $E9, $03, $CD, $EC, $E1, $26, $EE, $49, $64,
$F7, $9C, $D0, $2F, $72, $FA, $45, $A1, $65, $C1, $5C, $6E, $2E, $43, $58, $E4,
$D9, $C3, $44, $AA, $23, $57, $26, $7D, $67, $93, $E4, $51, $78, $A6, $1F, $D5,
$11, $64, $1F, $2B, $43, $B8, $E9, $CA, $B7, $03, $E2, $AC, $D4, $20, $67, $07,
$17, $35, $FB, $24, $E0, $18, $05, $DD, $9B, $9D, $85, $EA, $A9, $A3, $BE, $45,
$36, $E8, $CE, $73, $14, $E7, $A0, $B1, $17, $E2, $1A, $80, $B6, $7A, $1D, $7E,
$85, $22, $E9, $F9, $51, $C9, $56, $A4, $80, $47, $7A, $3E, $2D, $79, $50, $E2,
$DC, $76, $6E, $29, $01, $4A, $8E, $BC, $EC, $7B, $48, $68, $76, $07, $57, $CD,
$96, $1D, $AD, $48, $E0, $E2, $5E, $F6, $26, $E6, $1B, $20, $1C, $BA, $67, $DE,
$9C, $B4, $AF, $AD, $73, $06, $BB, $67, $15, $02, $BA, $AB, $14, $0F, $29, $B3,
$07, $D1, $C2, $10, $F7, $FE, $CC, $45, $18, $5C, $A2, $CE, $BC, $85, $6B, $3C,
$9A, $97, $20, $D6, $42, $E0, $56, $4B, $D0, $FD, $A0, $94, $1E, $31, $00, $FD,
$61, $63, $60, $A6, $86, $DA, $5A, $A3, $27, $F0, $66, $99, $4A, $CF, $26, $5D,
$96, $2B, $F4, $32, $C3, $47, $85, $28, $EC, $A5, $93, $0D, $82, $87, $94, $F9,
$92, $09, $8A, $7C, $E8, $50, $16, $CF, $3F, $9D, $BE, $5A, $EE, $35, $E1, $B3,
$84, $79, $E7, $20, $95, $7A, $88, $D5, $4A, $D7, $82, $6D, $19, $70, $C5, $2C,
$11, $12, $AE, $94, $67, $79, $38, $DA, $90, $DD, $8E, $83, $5B, $0D, $44, $28,
$2D, $D8, $E0, $74, $EA, $DB, $56, $2B, $B7, $76, $57, $B2, $B8, $26, $A4, $1B,
$06, $3F, $76, $27, $41, $A3, $64, $43, $BD, $39, $D2, $F3, $61, $D9, $A6, $1A,
$2B, $FF, $2A, $4B, $FE, $6E, $E2, $75, $9C, $4C, $6C, $3F, $2D, $7C, $B4, $6D,
$A3, $6B, $56, $C1, $70, $B3, $A5, $8D, $29, $E8, $EC, $07, $2C, $7B, $CA, $54,
$FA, $BB, $A2, $62, $E6, $78, $07, $97, $9B, $35, $67, $08, $FD, $13, $98, $CB,
$8D, $7F, $99, $F4, $2B, $EB, $1D, $A5, $77, $B1, $A2, $95, $24, $71, $43, $D7,
$03, $63, $88, $D1, $0A, $5E, $A4, $1A, $43, $54, $3B, $E0, $49, $F2, $3D, $64,
$DD, $A0, $47, $C7, $7B, $CB, $D3, $61, $60, $C7, $A8, $AA, $8B, $4A, $56, $AD,
$21, $C0, $A0, $36, $22, $6C, $26, $87, $68, $2E, $BF, $F9, $B6, $0E, $57, $84,
$67, $C9, $6F, $06, $07, $57, $1B, $4C, $2B, $60, $14, $C1, $30, $2A, $83, $98,
$65, $81, $37, $27, $C2, $47, $5D, $23, $E4, $54, $74, $A9, $1E, $7E, $56, $E3,
$F2, $10, $BC, $B5, $FE, $EF, $6C, $4C, $61, $1E, $68, $67, $B9, $7A, $FE, $D7,
$3F, $11, $3F, $1C, $46, $16, $4B, $16, $45, $C3, $46, $BD, $F5, $0E, $B3, $9F,
$E9, $9A, $AF, $7A, $CF, $06, $6F, $84, $1B, $45, $B5, $DA, $B7, $BD, $1E, $A3,
$A7, $42, $E0, $45, $B0, $7B, $8D, $11, $6F, $D3, $69, $15, $7D, $F6, $A3, $42,
$3E, $CC, $58, $FD, $FD, $FD, $E6, $E9, $C2, $01, $36, $81, $5C, $95, $E2, $0E,
$7D, $40, $AD, $41, $1D, $51, $B5, $AB, $42, $17, $26, $DE, $77, $D4, $76, $E5,
$EE, $F4, $8A, $80, $C9, $65, $8A, $7F, $A1, $09, $92, $8C, $E5, $F6, $41, $5B,
$9D, $09, $8A, $2F, $35, $6F, $61, $84, $62, $94, $A7, $59, $CC, $6C, $B6, $01,
$0F, $27, $31, $C9, $3E, $5F, $68, $D3, $A4, $20, $A0, $C0, $87, $F6, $D2, $05,
$41, $37, $86, $9D, $FE, $05, $9C, $A1, $CB, $94, $89, $2A, $95, $C7, $CB, $3B,
$A9, $4D, $62, $96, $C4, $55, $86, $92, $15, $BC, $46, $5C, $CF, $DD, $45, $EB,
$EE, $1D, $DF, $EF, $69, $A4, $64, $EE, $15, $0B, $29, $A6, $B1, $4F, $D8, $97,
$E3, $CD, $5E, $ED, $B6, $77, $A1, $2D, $DC, $55, $BC, $C2, $55, $BD, $34, $2D,
$5F, $46, $AD, $C9, $88, $34, $AE, $5A, $00, $AA, $BF, $26, $97, $2E, $B5, $AC,
$EF, $18, $74, $CD, $12, $01, $0D, $31, $88, $36, $7F, $41, $EB, $E4, $23, $00,
$4A, $FF, $56, $0E, $D4, $0D, $41, $73, $75, $10, $E7, $41, $1C, $6B, $1E, $B1,
$CE, $84, $60, $70, $28, $DB, $74, $38, $B8, $05, $D3, $C5, $2E, $BB, $F8, $0F,
$A4, $7E, $D7, $9B, $AB, $FF, $50, $2E, $22, $86, $8A, $A5, $E4, $0F, $AC, $D7,
$67, $F3, $82, $97, $5C, $74, $55, $1B, $F2, $CA, $09, $8B, $28, $C9, $B2, $B3,
$DD, $AE, $AC, $E8, $5C, $17, $4D, $03, $6B, $F4, $B1, $DA, $7E, $8C, $7B, $B0,
$5A, $65, $A6, $69, $5C, $2A, $77, $2F, $35, $9D, $FA, $7A, $78, $44, $B6, $84,
$64, $2E, $E0, $89, $00, $C0, $93, $DA, $6E, $A4, $A0, $FC, $32, $CD, $43, $07,
$A8, $B7, $47, $66, $BC, $C8, $C6, $D8, $2B, $A5, $17, $6E, $98, $EB, $8C, $F6,
$2E, $32, $DA, $A7, $D7, $D0, $43, $07, $EC, $B8, $81, $0A, $BB, $21, $BE, $B7,
$D6, $04, $EB, $4A, $2C, $5C, $E6, $A9, $21, $29, $8E, $F9, $3C, $E3, $9A, $E3,
$F4, $B5, $45, $36, $F6, $C8, $F9, $DF, $AD, $62, $41, $44, $15, $6D, $E1, $CF,
$48, $D2, $36, $58, $C7, $CF, $BC, $79, $DB, $1F, $7C, $11, $84, $9C, $24, $F2,
$C9, $D7, $B2, $41, $07, $2F, $87, $4B, $49, $40, $A0, $CC, $3E, $91, $65, $FD,
$6E, $20, $14, $EE, $30, $BA, $27, $5C, $7E, $3F, $F8, $B1, $4E, $19, $BA, $A1,
$3E, $D6, $04, $33, $53, $68, $A3, $55, $71, $D2, $6F, $DA, $8D, $2B, $6D, $0B,
$39, $7A, $4B, $3E, $DD, $41, $F0, $AF, $04, $ED, $D2, $9B, $96, $9B, $45, $72,
$B3, $6B, $98, $65, $F6, $60, $5F, $D3, $72, $C1, $16, $23, $F2, $1B, $23, $00,
$10, $D1, $B9, $6B, $49, $64, $4F, $A4, $59, $BD, $3E, $24, $F1, $AF, $73, $40,
$A0, $84, $0E, $79, $6A, $FB, $89, $90, $7A, $50, $A2, $77, $CF, $A7, $D3, $73,
$CC, $61, $72, $BC, $22, $4C, $3F, $C2, $43, $4E, $B4, $91, $5D, $7B, $33, $29,
$21, $39, $CA, $B7, $89, $12, $76, $9F, $33, $2C, $45, $9C, $77, $CF, $4E, $49,
$5D, $A6, $FA, $C1, $B3, $EF, $45, $7F, $6D, $33, $53, $3A, $4C, $29, $3C, $B0,
$FE, $D5, $2B, $BA, $81, $A7, $4D, $20, $34, $1B, $76, $FF, $20, $31, $8E, $89,
$F5, $23, $77, $10, $37, $8B, $1F, $A4, $96, $D6, $4B, $8C, $37, $81, $C6, $A2,
$7E, $F9, $ED, $E5, $28, $DB, $2B, $BC, $44, $8E, $8A, $72, $93, $7E, $05, $EC,
$C9, $E0, $16, $2E, $6E, $1D, $DB, $D9, $7C, $E2, $50, $B5, $1A, $DD, $A7, $8C,
$58, $D8, $E5, $2F, $47, $FF, $96, $33, $C5, $9F, $75, $00, $B5, $D9, $77, $35,
$27, $70, $12, $AF, $92, $DF, $68, $CA, $06, $D3, $CE, $1C, $79, $CE, $3D, $65,
$53, $8B, $11, $F4, $DA, $B1, $5B, $25, $8C, $B3, $8F, $23, $30, $F0, $44, $40,
$35, $8A, $0E, $49, $CD, $49, $A6, $DB, $7E, $81, $DB, $2E, $07, $41, $D7, $E8,
$2C, $AA, $84, $D5, $A7, $0F, $1B, $8B, $7D, $FB, $F1, $C1, $37, $B5, $0D, $91,
$11, $22, $45, $30, $42, $5A, $61, $53, $C4, $F3, $33, $A4, $85, $14, $13, $AF,
$54, $1F, $5E, $B5, $E6, $9A, $C7, $DA, $5E, $20, $91, $42, $1A, $A2, $8D, $EE,
$F2, $5C, $87, $1B, $87, $44, $77, $40, $CF, $C0, $26, $D3, $CA, $BC, $19, $A8,
$5A, $28, $CD, $CC, $1D, $96, $D0, $30, $FB, $4C, $BA, $B0, $EE, $10, $CA, $24,
$F9, $98, $FF, $9B, $43, $7D, $BE, $0C, $BE, $A4, $EC, $E4, $25, $F9, $52, $64,
$0C, $2A, $F9, $37, $F8, $B1, $47, $FF, $AD, $73, $9F, $9A, $A3, $5D, $A9, $DC,
$69, $D2, $C0, $E6, $54, $24, $E2, $51, $EE, $0A, $35, $1B, $D2, $0D, $E9, $B1,
$2A, $13, $8F, $16, $6D, $7A, $C1, $34, $27, $ED, $88, $EC, $69, $4A, $EF, $3B,
$D5, $D0, $47, $E1, $44, $EB, $3E, $20, $25, $57, $64, $BD, $B6, $61, $76, $53,
$CA, $49, $F2, $10, $F3, $50, $4B, $63, $D1, $CF, $51, $E7, $AD, $29, $4A, $EC,
$69, $D2, $95, $29, $8A, $2F, $90, $1F, $8D, $30, $D8, $2B, $68, $6A, $56, $ED,
$DB, $05, $16, $38, $D7, $3D, $AC, $74, $D0, $97, $54, $B2, $F3, $E9, $85, $45,
$7E, $00, $81, $27, $8D, $20, $59, $10, $EB, $6B, $AE, $7F, $59, $C2, $A8, $02,
$8C, $B5, $D8, $A9, $D2, $38, $06, $67, $53, $0E, $14, $33, $68, $D0, $C9, $91,
$12, $4B, $BC, $50, $A4, $37, $94, $3D, $00, $23, $AF, $A9, $BB, $0F, $74, $C8,
$FB, $D5, $2E, $6C, $E1, $44, $8E, $3A, $BB, $9C, $3D, $48, $82, $9F, $6D, $18,
$FA, $54, $B6, $42, $40, $C4, $14, $8C, $4F, $DC, $89, $6C, $C2, $46, $0C, $46,
$3E, $EB, $BF, $79, $C0, $1E, $E5, $2D, $FC, $5C, $65, $35, $78, $FD, $E8, $4C,
$05, $9C, $97, $C4, $6F, $4C, $E8, $8A, $93, $07, $E5, $1D, $A2, $D1, $B7, $6E,
$6B, $AF, $40, $A8, $15, $BB, $92, $64, $F4, $FB, $4B, $B6, $EF, $93, $A7, $E0,
$45, $2E, $20, $76, $04, $2B, $50, $0A, $86, $38, $9B, $25, $67, $24, $BE, $D2,
$CC, $03, $81, $07, $FA, $03, $40, $53, $5E, $9B, $AC, $D9, $F5, $5C, $1B, $19,
$E0, $6F, $D4, $45, $F9, $76, $B3, $5A, $87, $26, $2A, $8D, $35, $2E, $95, $55,
$A5, $15, $FB, $EF, $AB, $0F, $0B, $2F, $4A, $A3, $91, $E3, $43, $DC, $6B, $70,
$72, $04, $75, $8A, $1F, $25, $84, $36, $7F, $B1, $B2, $76, $AA, $E6, $18, $D4,
$BB, $A8, $59, $5B, $12, $20, $0E, $0F, $42, $59, $6C, $BD, $CD, $BF, $DA, $6B,
$19, $1C, $8F, $46, $BF, $86, $09, $2E, $44, $5B, $43, $22, $E1, $C7, $00, $28,
$22, $39, $CE, $1B, $57, $36, $32, $89, $52, $CE, $88, $D1, $CD, $2A, $95, $6F,
$59, $A5, $B8, $7A, $58, $83, $A1, $48, $5A, $23, $CA, $76, $29, $05, $B4, $48,
$9D, $1C, $D0, $FB, $33, $BC, $8B, $2B, $28, $2A, $E7, $4C, $A1, $D5, $65, $FE,
$BA, $E2, $AD, $29, $77, $EB, $AC, $E1, $2B, $9A, $68, $B9, $F0, $00, $EE, $96,
$87, $81, $97, $BB, $F1, $DC, $6A, $C7, $51, $C0, $D6, $B0, $40, $69, $17, $2D,
$9A, $2E, $E5, $F7, $66, $26, $27, $D8, $8F, $F6, $9A, $8D, $59, $D1, $0B, $ED,
$D1, $6F, $1F, $18, $8B, $2E, $B7, $AD, $29, $DD, $64, $16, $7C, $FD, $62, $6F,
$61, $31, $45, $2B, $1D, $EB, $34, $D1, $93, $E4, $80, $42, $95, $A0, $2C, $E6,
$3E, $E8, $95, $00, $9E, $03, $23, $8B, $6C, $B1, $F8, $FA, $63, $FD, $6C, $EB,
$E1, $E7, $A4, $59, $85, $69, $5B, $53, $49, $05, $57, $9D, $39, $74, $2D, $C2,
$D2, $43, $46, $8A, $CD, $46, $1E, $79, $13, $DF, $9B, $C9, $95, $68, $91, $92,
$66, $90, $AF, $88, $EC, $0C, $38, $61, $B8, $33, $2A, $02, $A4, $12, $71, $03,
$6F, $83, $C3, $44, $5E, $37, $64, $CF, $30, $B2, $D9, $62, $5D, $1E, $25, $43,
$9C, $92, $65, $51, $78, $AC, $EF, $8D, $AD, $65, $0B, $71, $5C, $99, $B9, $41,
$B7, $DA, $94, $75, $B5, $40, $90, $1D, $C2, $7D, $96, $2A, $C5, $06, $3C, $32,
$9B, $F7, $57, $AE, $21, $1B, $BA, $92, $1B, $03, $B3, $13, $77, $C4, $60, $1A,
$E2, $65, $83, $8E, $C4, $23, $3A, $6B, $B3, $46, $9F, $A9, $B3, $89, $D6, $15,
$15, $37, $B1, $14, $3E, $A7, $94, $F4, $8D, $26, $4C, $56, $0E, $00, $C7, $27,
$DC, $89, $EC, $31, $67, $19, $CC, $66, $F9, $EB, $11, $7E, $5C, $5E, $D7, $C6,
$29, $BD, $6D, $5B, $8C, $D8, $7C, $69, $BB, $10, $BD, $6E, $83, $18, $CB, $66,
$1A, $19, $3D, $33, $B3, $CD, $BC, $5F, $0E, $BA, $14, $80, $28, $5A, $21, $49,
$5E, $4B, $2A, $42, $FF, $A0, $74, $68, $BC, $79, $53, $C6, $F6, $BF, $D8, $33,
$0C, $A1, $8C, $37, $8E, $78, $C6, $A8, $CF, $29, $A3, $B4, $E6, $E7, $E1, $A5,
$4A, $58, $22, $91, $D3, $DF, $40, $8C, $36, $B6, $68, $FC, $30, $BA, $8C, $49,
$89, $D8, $47, $65, $C7, $4E, $19, $A2, $53, $A4, $EB, $C2, $C6, $9F, $4D, $52,
$61, $04, $83, $D2, $99, $2B, $56, $2E, $A5, $74, $52, $BA, $26, $F5, $3C, $91,
$C4, $B4, $85, $78, $37, $1A, $01, $39, $66, $F6, $59, $AE, $95, $F9, $CB, $D0,
$42, $79, $B1, $B4, $50, $54, $D7, $4B, $59, $33, $82, $13, $DE, $BC, $89, $52,
$16, $19, $03, $88, $19, $3C, $F2, $EF, $FF, $20, $E9, $E8, $F2, $DE, $D6, $E3,
$64, $A8, $F3, $4E, $F2, $B0, $BD, $6F, $56, $67, $28, $03, $5E, $8C, $34, $F6,
$7F, $9B, $62, $18, $6F, $24, $80, $82, $6A, $58, $43, $6E, $10, $60, $86, $1F,
$C9, $84, $62, $C0, $04, $7A, $1A, $41, $9D, $CC, $B1, $83, $2D, $07, $CD, $7A,
$82, $1C, $82, $30, $78, $80, $B0, $96, $A2, $67, $53, $FF, $13, $FF, $DE, $EF,
$8A, $0C, $84, $B5, $E1, $4C, $1C, $17, $36, $6D, $B9, $0D, $BE, $AF, $F0, $66,
$6E, $D8, $F5, $5D, $F8, $30, $7E, $6F, $D6, $82, $32, $F6, $8A, $E9, $28, $EC,
$21, $B6, $B4, $00, $E5, $98, $14, $E8, $EC, $56, $43, $58, $E6, $41, $46, $D0,
$74, $F3, $C4, $87, $77, $2D, $96, $15, $F9, $80, $52, $77, $2E, $1A, $25, $7D,
$EE, $3B, $2D, $10, $95, $6A, $A2, $D4, $7F, $02, $7C, $90, $95, $A2, $30, $7C,
$49, $80, $CA, $77, $CE, $2F, $9D, $E3, $0D, $97, $87, $44, $73, $C4, $37, $AA,
$74, $43, $B9, $8D, $EF, $B0, $0F, $E0, $5A, $1C, $8E, $15, $21, $5E, $21, $A2,
$54, $17, $6F, $E0, $E2, $F9, $95, $BB, $56, $E2, $DB, $F4, $E7, $5B, $33, $5A,
$B0, $8C, $E8, $0A, $42, $59, $80, $09, $B0, $AE, $38, $AE, $E5, $89, $19, $98,
$60, $6E, $D6, $A8, $FA, $98, $C3, $C2, $38, $18, $D6, $E2, $FE, $26, $C6, $05,
$8A, $D3, $50, $2A, $A9, $52, $49, $7F, $8B, $15, $5F, $19, $9C, $7C, $2A, $CB,
$24, $3D, $B1, $1E, $71, $A2, $06, $67, $6A, $99, $D0, $60, $BC, $7B, $4E, $C6,
$DD, $7C, $0A, $EF, $11, $2D, $7E, $E7, $71, $B7, $2D, $97, $D6, $8F, $5A, $F3,
$F8, $E7, $F7, $02, $32, $B1, $A0, $5B, $AF, $1E, $A9, $4F, $AF, $69, $C3, $BD,
$27, $3C, $C4, $FF, $B9, $3E, $7E, $2A, $E1, $93, $34, $5D, $CE, $6F, $F8, $EC,
$3C, $40, $FD, $3E, $16, $29, $5C, $A8, $C0, $7C, $85, $FF, $97, $8A, $DE, $C9,
$74, $B6, $41, $C3, $F7, $5E, $ED, $F2, $E2, $1D, $75, $FB, $78, $72, $03, $89,
$5B, $81, $02, $67, $58, $D1, $49, $EB, $92, $13, $63, $D6, $71, $AC, $86, $9F,
$19, $9C, $47, $62, $8A, $41, $51, $F2, $8B, $4A, $2E, $9C, $B1, $C8, $64, $B8,
$61, $4D, $4D, $18, $12, $CB, $91, $8C, $D3, $C7, $22, $E8, $40, $4C, $EA, $BF,
$D9, $45, $26, $D9, $C7, $5C, $EA, $03, $03, $C5, $07, $D8, $CB, $CD, $3C, $DE,
$F6, $A2, $E6, $2C, $4C, $34, $4F, $AF, $BD, $DB, $A4, $64, $D6, $E1, $50, $85,
$82, $D1, $4F, $F4, $F5, $7C, $F2, $7B, $36, $12, $AC, $07, $A9, $F3, $9B, $6A,
$2B, $42, $36, $CD, $60, $81, $84, $81, $61, $69, $0A, $A2, $C4, $A5, $AA, $3A,
$10, $70, $A3, $28, $B4, $EA, $43, $34, $6A, $F8, $AA, $20, $AE, $51, $A7, $DE,
$C4, $74, $A6, $43, $41, $47, $42, $16, $6F, $AF, $1D, $C7, $3D, $21, $56, $40,
$C5, $0D, $16, $68, $1C, $A4, $AC, $C2, $0C, $08, $3E, $08, $7B, $51, $46, $48,
$30, $EB, $8C, $D3, $D2, $E4, $4F, $5E, $85, $34, $74, $FF, $71, $F0, $6D, $1F,
$0B, $14, $2C, $58, $39, $EF, $64, $90, $B6, $96, $78, $93, $3C, $1E, $94, $CC,
$EB, $B7, $E4, $0D, $67, $CB, $1A, $6D, $38, $28, $94, $FA, $AC, $4E, $E9, $96,
$18, $35, $42, $3D, $8E, $71, $ED, $B1, $77, $C3, $18, $F2, $B8, $D7, $F7, $DB,
$7D, $FE, $BE, $96, $A9, $B9, $90, $7D, $34, $02, $BB, $57, $92, $95, $B7, $F3,
$0B, $F1, $54, $90, $59, $C5, $64, $03, $28, $63, $F1, $F6, $3A, $A6, $A6, $A2,
$EB, $DD, $40, $B9, $26, $F8, $BE, $CC, $D5, $DE, $0C, $21, $88, $B4, $FC, $DE,
$13, $CB, $93, $DA, $D6, $3F, $DD, $98, $D0, $4E, $AE, $7F, $73, $FF, $DF, $18,
$EB, $79, $99, $89, $06, $22, $73, $7F, $69, $03, $CF, $43, $32, $CA, $D1, $6D,
$A4, $C6, $83, $4C, $0C, $F5, $24, $4D, $EE, $9D, $8D, $D6, $5C, $73, $75, $61,
$31, $1B, $A1, $1A, $52, $AD, $56, $A3, $4D, $F0, $31, $5F, $2E, $33, $91, $BC,
$65, $89, $FD, $D3, $65, $C7, $66, $53, $BE, $9A, $2D, $E8, $F4, $7B, $24, $49,
$00, $9C, $3D, $37, $1D, $E0, $D0, $EA, $14, $A9, $63, $44, $8D, $83, $40, $48,
$50, $B7, $F3, $D9, $6A, $F9, $7C, $69, $4C, $33, $FC, $46, $1B, $89, $47, $F2,
$C1, $E0, $AE, $59, $37, $58, $1A, $F2, $3A, $B9, $B3, $92, $BB, $C0, $01, $0D,
$15, $62, $97, $C9, $85, $52, $8D, $6B, $A9, $52, $FE, $75, $DE, $7E, $14, $F9,
$92, $08, $14, $9D, $CB, $B0, $A3, $93, $BB, $1B, $BA, $07, $F3, $B2, $E5, $E6,
$B0, $54, $A6, $45, $DC, $38, $22, $CF, $10, $4E, $3E, $D4, $52, $D6, $8D, $F3,
$40, $82, $70, $D2, $24, $D3, $DF, $63, $7B, $6B, $A9, $27, $A1, $F0, $9B, $F1,
$92, $3A, $EE, $CC, $03, $9A, $91, $FF, $8F, $B9, $20, $52, $99, $1C, $5A, $0F,
$5B, $CA, $43, $0F, $B2, $A7, $62, $61, $30, $67, $26, $8C, $01, $CF, $C9, $AD,
$69, $EC, $20, $BC, $DA, $D0, $B9, $90, $15, $02, $9D, $FA, $0F, $1E, $D0, $16,
$A4, $23, $A0, $00, $D5, $67, $3D, $38, $8C, $A7, $62, $B2, $E3, $CC, $7F, $6D,
$41, $2B, $9D, $44, $3F, $56, $E1, $3F, $86, $FC, $90, $4E, $2E, $BB, $2A, $6F,
$D8, $77, $39, $CE, $2C, $BE, $03, $C0, $C9, $8D, $28, $75, $64, $C9, $1C, $18,
$E2, $6A, $F4, $5E, $D0, $95, $FB, $B0, $B2, $47, $7A, $C0, $D4, $57, $E8, $D2,
$C8, $9D, $72, $69, $FD, $39, $28, $3C, $46, $A7, $5E, $09, $0B, $C7, $C6, $96,
$16, $DC, $B4, $96, $F5, $26, $39, $82, $1E, $E3, $2E, $73, $AC, $BF, $EF, $4C,
$1A, $F3, $20, $C8, $D2, $05, $B8, $0E, $79, $99, $30, $16, $7A, $6A, $3F, $9D,
$67, $0B, $F7, $0C, $59, $1E, $2E, $BE, $3F, $46, $AE, $1C, $97, $9C, $45, $C1,
$57, $CA, $3A, $82, $B2, $7F, $18, $DD, $67, $93, $BC, $2E, $B9, $4B, $F1, $58,
$E4, $6A, $BB, $B3, $A0, $B8, $13, $A8, $7D, $5B, $FE, $CD, $D9, $D7, $83, $B3,
$E3, $A5, $9F, $D9, $8E, $F8, $F6, $00, $E9, $F9, $FA, $D0, $37, $DB, $84, $B9,
$01, $55, $54, $F6, $9F, $7F, $A1, $BD, $93, $D6, $AB, $2E, $CA, $1C, $30, $92,
$C5, $E8, $DF, $61, $86, $45, $A1, $BE, $B0, $47, $50, $AB, $DA, $FD, $44, $42,
$F4, $A3, $64, $DF, $78, $DB, $33, $88, $AE, $66, $C4, $86, $A5, $33, $CC, $E3,
$CF, $35, $56, $E6, $79, $2A, $57, $87, $40, $B6, $7C, $F7, $DA, $5C, $0F, $7F,
$B3, $E1, $13, $1D, $4D, $64, $86, $95, $B3, $0B, $CF, $DA, $D9, $C8, $4E, $BB,
$16, $C2, $63, $D5, $67, $4E, $16, $23, $55, $EF, $10, $C6, $B8, $33, $89, $D3,
$F8, $FE, $8B, $54, $96, $DC, $DF, $8F, $FD, $9B, $AC, $42, $3C, $BA, $6E, $FB,
$20, $48, $88, $37, $25, $E7, $FB, $DE, $76, $EF, $ED, $39, $A7, $17, $45, $73,
$0D, $4F, $55, $08, $D3, $F5, $75, $FB, $79, $03, $DB, $52, $2E, $57, $53, $75,
$08, $56, $EF, $DE, $A9, $10, $5A, $FC, $91, $3D, $B8, $D5, $A1, $B9, $3A, $86,
$33, $5B, $01, $76, $71, $99, $57, $57, $7D, $EC, $BA, $71, $6A, $0C, $1A, $C6,
$1B, $FC, $41, $45, $16, $17, $AD, $5F, $DE, $17, $E6, $95, $16, $29, $D0, $9B,
$29, $3A, $35, $39, $40, $AA, $03, $3B, $B2, $D7, $EF, $CA, $11, $11, $CD, $B9,
$33, $E7, $81, $9F, $EE, $E0, $66, $AB, $CB, $11, $88, $1F, $8E, $5C, $5F, $FB,
$CA, $07, $83, $B6, $59, $9C, $B5, $62, $D1, $A1, $CB, $4B, $90, $8F, $A6, $D2,
$07, $FE, $A0, $42, $D1, $87, $73, $91, $DC, $9C, $27, $C7, $8E, $52, $DD, $56,
$70, $73, $35, $0A, $4E, $8E, $0F, $7D, $9E, $95, $53, $A6, $F7, $9A, $87, $09,
$8D, $7C, $E0, $8F, $62, $88, $34, $64, $B4, $A8, $67, $2F, $BC, $5C, $B8, $0A,
$BB, $57, $E8, $A9, $D7, $1F, $48, $BC, $1B, $32, $2C, $45, $1C, $BB, $FC, $89,
$8F, $9E, $75, $94, $4C, $F5, $57, $34, $7F, $AC, $4F, $4B, $03, $D8, $45, $5F,
$4A, $8F, $A7, $46, $36, $78, $45, $C2, $AA, $F0, $93, $84, $A2, $3B, $3D, $3E,
$BB, $D5, $49, $22, $9D, $90, $87, $45, $3F, $46, $B4, $66, $7E, $41, $2C, $3A,
$84, $65, $02, $10, $E4, $8F, $19, $67, $C8, $EB, $4E, $61, $F9, $45, $6B, $0D,
$FA, $D8, $90, $9E, $AC, $3D, $1C, $03, $F3, $90, $95, $55, $05, $0E, $EE, $57,
$35, $51, $AC, $05, $E1, $82, $05, $23, $4D, $0F, $AA, $40, $3F, $D2, $AE, $EA,
$CD, $96, $91, $D1, $45, $36, $C9, $56, $44, $51, $CE, $AF, $22, $98, $0F, $6E,
$C7, $93, $EB, $B3, $8F, $32, $BD, $1E, $47, $01, $C2, $0F, $07, $FE, $A9, $B5,
$08, $D1, $1B, $61, $C9, $5E, $67, $23, $E6, $92, $7C, $65, $18, $3B, $D2, $E3,
$A8, $92, $FD, $3B, $B7, $46, $25, $98, $93, $81, $25, $DB, $27, $42, $C0, $08,
$B1, $EC, $DC, $97, $41, $AA, $2D, $FC, $E2, $6C, $A2, $DA, $27, $48, $B5, $C7,
$B2, $7B, $87, $9C, $94, $18, $D0, $85, $2D, $84, $A6, $6D, $49, $94, $67, $5F,
$B2, $0F, $E5, $2D, $A6, $54, $98, $EF, $BF, $FF, $4A, $B9, $B9, $66, $45, $48,
$78, $A1, $40, $47, $90, $42, $67, $BB, $74, $25, $0B, $39, $BE, $08, $A8, $42,
$B2, $EB, $93, $89, $DF, $E6, $5D, $4D, $96, $90, $9A, $D9, $FB, $6B, $78, $D0,
$4B, $B1, $08, $C3, $B1, $F2, $92, $C6, $8A, $50, $F2, $1D, $E6, $9A, $8B, $AD,
$9E, $1D, $E1, $59, $E3, $E3, $AD, $A1, $9E, $BC, $B2, $18, $8F, $AF, $27, $28,
$56, $1B, $8C, $49, $0E, $86, $FF, $0A, $65, $9A, $BA, $94, $66, $72, $36, $B5,
$29, $6F, $34, $9B, $30, $CA, $BE, $B6, $D2, $6D, $FB, $16, $96, $EA, $03, $F8,
$04, $0C, $F1, $05, $0C, $26, $76, $EA, $6A, $98, $FD, $4C, $6F, $89, $7C, $7C,
$38, $90, $B2, $DE, $F3, $2A, $D9, $2B, $DA, $1A, $A6, $C3, $89, $EC, $40, $AA,
$6F, $13, $B4, $7F, $A5, $57, $FF, $A9, $5D, $BA, $47, $73, $28, $A6, $20, $28,
$E8, $7B, $43, $4A, $E6, $F0, $D6, $3A, $F2, $DB, $05, $AC, $45, $F2, $57, $6F,
$5B, $CF, $40, $94, $33, $38, $C6, $22, $58, $6E, $23, $F8, $AF, $FD, $12, $2D,
$9E, $01, $A9, $17, $14, $DC, $DC, $94, $93, $8B, $8B, $F2, $BE, $06, $C5, $BB,
$00, $0D, $8C, $EA, $EC, $60, $FE, $EE, $1F, $6B, $28, $4F, $93, $BC, $47, $61,
$19, $F2, $47, $38, $B4, $00, $D3, $9B, $57, $37, $14, $99, $02, $7B, $9D, $33,
$E1, $11, $C8, $C0, $BA, $0D, $7A, $D7, $81, $8A, $91, $15, $24, $6E, $B9, $0D,
$BD, $52, $42, $81, $B9, $F7, $28, $92, $18, $D1, $77, $DD, $B9, $5E, $61, $55,
$6A, $61, $CE, $C0, $48, $A9, $F3, $A8, $4A, $89, $7F, $7F, $F5, $EF, $10, $E1,
$58, $17, $2C, $A8, $C8, $1B, $F8, $39, $02, $C7, $34, $61, $C1, $A8, $D6, $67,
$42, $DE, $1B, $FD, $45, $50, $45, $D9, $86, $96, $70, $09, $D5, $B3, $89, $B0,
$45, $DD, $FF, $15, $8B, $4C, $8D, $2F, $A2, $11, $5C, $B9, $88, $DF, $A2, $F8,
$39, $0C, $A0, $74, $FF, $8E, $9F, $F8, $AB, $7C, $F3, $93, $6E, $96, $05, $E6,
$CF, $40, $34, $2C, $0E, $5F, $14, $F9, $09, $69, $F0, $65, $7A, $FE, $D5, $66,
$09, $40, $BE, $C4, $9D, $9A, $C7, $B8, $E3, $E6, $2B, $18, $0F, $73, $6E, $92,
$5C, $3B, $78, $63, $CD, $16, $4C, $10, $65, $78, $85, $29, $A4, $7B, $67, $DC,
$EA, $30, $29, $9B, $7E, $68, $68, $1D, $AB, $54, $A2, $EF, $AA, $56, $D0, $35,
$DA, $DC, $3B, $AD, $25, $CA, $A0, $C4, $03, $6B, $81, $F0, $86, $1B, $0E, $72,
$E3, $2D, $92, $8A, $7E, $F9, $C7, $7A, $B1, $5F, $1F, $85, $49, $6F, $57, $16,
$E0, $1B, $B6, $F5, $5B, $EF, $B6, $9D, $41, $8A, $40, $7D, $F1, $03, $0C, $49,
$AA, $10, $F0, $8C, $09, $D5, $16, $F4, $3E, $D5, $62, $CF, $61, $26, $0F, $EE,
$FB, $5A, $37, $35, $98, $C6, $93, $D0, $B3, $36, $DD, $7C, $5B, $01, $6F, $12,
$23, $10, $C1, $06, $90, $DB, $D0, $88, $12, $D5, $B7, $02, $B9, $AF, $36, $69,
$0B, $86, $1A, $19, $2D, $51, $5B, $12, $5A, $20, $1A, $F7, $3D, $14, $3F, $2F,
$5F, $C2, $AD, $AA, $C6, $65, $9A, $86, $CD, $5B, $D4, $14, $92, $C1, $8A, $3B,
$49, $81, $15, $77, $53, $17, $96, $48, $77, $68, $A6, $CD, $64, $5F, $E5, $6F,
$1F, $09, $61, $DD, $CD, $52, $8B, $39, $94, $77, $62, $B0, $27, $DC, $34, $A3,
$FB, $6E, $F6, $3D, $F8, $71, $DA, $AA, $47, $E5, $EC, $A4, $A4, $7A, $DE, $21,
$45, $BA, $63, $AB, $9F, $2A, $9F, $11, $69, $75, $DC, $DC, $80, $A8, $C3, $9C,
$4C, $FC, $B7, $0D, $89, $4E, $16, $99, $F9, $B9, $BC, $F1, $3F, $11, $9C, $C3,
$66, $66, $6F, $60, $2E, $6B, $DD, $5A, $69, $09, $5A, $DF, $6D, $E6, $58, $CA,
$E2, $E5, $D9, $90, $2A, $6D, $A9, $83, $15, $24, $1A, $3E, $17, $8E, $11, $C2,
$67, $BC, $E6, $C3, $F5, $18, $16, $56, $F0, $29, $4E, $11, $CA, $3B, $49, $25,
$D3, $8A, $77, $53, $B6, $F2, $B5, $04, $CD, $37, $6E, $BA, $9F, $4D, $EC, $3D,
$65, $6E, $D9, $53, $E7, $09, $4B, $97, $FB, $D5, $BE, $60, $57, $1E, $B9, $B8,
$79, $32, $4F, $05, $1B, $58, $EE, $11, $18, $DF, $1F, $8B, $4A, $98, $7D, $57,
$8C, $5F, $BA, $C9, $46, $75, $FA, $EF, $7C, $86, $52, $7D, $92, $5A, $44, $D4,
$9B, $9B, $FB, $64, $12, $34, $22, $A0, $82, $4C, $7F, $10, $7F, $B9, $FA, $AF,
$00, $90, $9A, $56, $37, $D7, $03, $2B, $97, $9F, $AB, $12, $1F, $61, $D5, $B3,
$91, $6E, $E4, $3B, $F4, $AF, $42, $46, $AC, $45, $3D, $CF, $91, $4B, $5E, $87,
$A5, $EB, $9C, $96, $AD, $2B, $8E, $57, $9F, $DD, $BE, $3F, $F6, $A1, $3B, $C5,
$1F, $31, $E0, $CB, $DD, $65, $53, $F4, $39, $A5, $F5, $8A, $8C, $E9, $D8, $61,
$45, $A4, $DD, $B4, $85, $4B, $DA, $94, $6F, $F4, $7A, $CC, $94, $45, $F1, $CE,
$D3, $D6, $F3, $27, $44, $6D, $CB, $D9, $53, $F0, $BE, $C9, $FD, $CC, $68, $49,
$BB, $1F, $DD, $F5, $1B, $74, $99, $2D, $71, $80, $28, $2C, $C7, $E1, $4D, $CC,
$6B, $70, $AA, $99, $42, $A1, $5B, $9B, $7B, $B1, $B8, $F3, $98, $1D, $27, $20,
$AE, $9F, $96, $06, $F2, $69, $8C, $D1, $D1, $C2, $92, $DF, $36, $E1, $56, $7C,
$4F, $7B, $B6, $D7, $E1, $48, $B2, $46, $22, $E3, $8C, $6A, $17, $01, $1B, $E7,
$EB, $C8, $1E, $D7, $68, $D9, $7C, $7A, $54, $DB, $6F, $91, $88, $9B, $E3, $93,
$27, $4E, $DB, $37, $3D, $12, $2A, $C6, $67, $FE, $B5, $51, $B8, $78, $C6, $6A,
$DF, $69, $92, $67, $D4, $E5, $66, $B3, $E2, $1E, $0A, $53, $01, $12, $EE, $15,
$99, $0D, $A1, $B9, $0E, $40, $2A, $B7, $0A, $38, $0F, $FA, $44, $3B, $D7, $09,
$BE, $38, $CF, $5F, $90, $A2, $DA, $7C, $A6, $BC, $9F, $38, $AF, $86, $89, $27,
$E2, $2F, $69, $EA, $C2, $2F, $56, $69, $EF, $A3, $8F, $FF, $0B, $70, $42, $C6,
$65, $A7, $E7, $24, $27, $28, $45, $C6, $AD, $76, $2B, $A3, $7A, $98, $C6, $9D,
$4E, $ED, $F3, $C4, $78, $97, $78, $87, $01, $60, $DA, $D0, $06, $4C, $99, $34,
$D6, $7F, $D5, $9F, $AD, $98, $3E, $AC, $2A, $7C, $44, $4E, $CC, $23, $F6, $8B,
$CD, $C3, $05, $D3, $1C, $C3, $3B, $F6, $7B, $F6, $88, $50, $AF, $39, $17, $B9,
$60, $5A, $62, $F0, $7F, $F4, $C4, $97, $D1, $F8, $91, $11, $0A, $84, $DF, $B9,
$EE, $6B, $F2, $54, $8B, $82, $77, $AE, $BA, $4C, $F1, $00, $4B, $A7, $3A, $28,
$2A, $91, $F1, $7E, $2F, $64, $A3, $F0, $CD, $9C, $2B, $A2, $E9, $1D, $5C, $8C,
$03, $67, $19, $17, $77, $9A, $8D, $F2, $93, $3D, $14, $08, $33, $F0, $9D, $8B,
$4A, $D3, $6E, $E8, $F8, $36, $7D, $3F, $66, $C0, $2A, $B0, $C7, $71, $D5, $DF,
$62, $C7, $2B, $9E, $65, $06, $F6, $A4, $ED, $3E, $38, $8F, $EB, $DB, $91, $7F,
$14, $9B, $09, $46, $50, $9C, $33, $D6, $0F, $C3, $D8, $50, $43, $9C, $35, $0D,
$4E, $18, $A0, $8F, $AB, $83, $20, $F3, $28, $75, $85, $E3, $96, $B0, $9C, $AC,
$86, $DD, $6E, $1D, $15, $B3, $92, $FA, $59, $79, $0A, $9D, $7E, $4D, $FA, $44,
$A9, $0A, $6C, $1C, $8A, $EA, $2F, $7E, $A0, $BE, $78, $D0, $C4, $09, $A9, $1D,
$E9, $89, $8E, $A1, $A3, $EB, $55, $9A, $F0, $FA, $C7, $8B, $59, $AD, $D0, $05,
$A6, $DA, $26, $BE, $7F, $3E, $F8, $A8, $D2, $27, $B7, $06, $2A, $61, $4C, $F9,
$B9, $B8, $AB, $A2, $EB, $09, $BA, $D5, $EA, $89, $F5, $0D, $EA, $93, $10, $BC,
$25, $4C, $A2, $A7, $14, $94, $F6, $CC, $4C, $C1, $6E, $2D, $66, $B6, $90, $68,
$0C, $39, $F8, $49, $4F, $D0, $0D, $F8, $D6, $B6, $3A, $2F, $20, $F7, $38, $2A,
$02, $B3, $12, $EE, $AA, $52, $40, $81, $1C, $26, $47, $6B, $5D, $E9, $6E, $31,
$FC, $4E, $64, $A8, $DF, $49, $BC, $C4, $48, $D5, $BE, $F1, $EA, $40, $E2, $1B,
$E8, $87, $65, $7A, $ED, $88, $BB, $C9, $9B, $E7, $F9, $84, $8F, $49, $2F, $28,
$97, $3D, $8E, $DB, $FB, $7E, $3E, $B6, $FD, $C1, $4A, $5D, $09, $8B, $F0, $42,
$83, $09, $A2, $88, $09, $D8, $E6, $97, $6B, $E7, $FD, $C3, $A6, $FD, $91, $44,
$99, $21, $7B, $FD, $FA, $6D, $10, $E8, $BD, $2A, $94, $2B, $9B, $69, $89, $EB,
$AA, $46, $CD, $45, $2F, $1B, $9C, $14, $1E, $4F, $0D, $BB, $73, $A4, $29, $4E,
$2E, $AA, $A8, $FD, $C4, $F6, $1D, $C8, $77, $96, $80, $DF, $8A, $91, $19, $A6,
$A6, $EE, $BA, $EA, $D1, $D0, $35, $36, $A8, $74, $CB, $FD, $6E, $07, $AB, $26,
$BC, $66, $48, $C9, $10, $1D, $9C, $3C, $36, $EB, $B0, $6E, $A4, $C3, $49, $70,
$07, $F5, $93, $DA, $16, $4A, $C8, $22, $5A, $B3, $2F, $A9, $88, $9D, $2B, $7F,
$D6, $EB, $23, $39, $44, $9A, $D1, $CD, $1A, $2B, $A3, $97, $0D, $CB, $7E, $14,
$73, $C9, $84, $15, $E5, $1A, $E1, $C7, $31, $D7, $3D, $D5, $B9, $4B, $84, $08,
$90, $FC, $A3, $3C, $DD, $9D, $00, $2D, $B1, $A9, $7F, $17, $29, $8F, $80, $54,
$BC, $72, $83, $B6, $53, $64, $26, $9E, $4A, $6A, $D7, $22, $81, $FB, $D2, $B9,
$DF, $3F, $AF, $7F, $79, $9E, $F0, $54, $6C, $AF, $A5, $C0, $BD, $FD, $9C, $7E,
$22, $6A, $5C, $18, $4F, $C7, $DE, $71, $0D, $F3, $4B, $B3, $B2, $7F, $CD, $4C,
$6C, $E0, $CF, $C2, $74, $AC, $8E, $F6, $DF, $68, $A8, $0F, $7F, $6A, $74, $2F,
$5D, $33, $99, $8D, $E3, $39, $F3, $E7, $2B, $12, $A0, $CB, $3E, $CD, $C9, $3A,
$55, $EF, $41, $92, $99, $53, $6F, $C8, $CF, $0E, $0A, $68, $12, $BF, $28, $1A,
$D2, $30, $62, $A3, $73, $5E, $83, $A7, $EB, $B1, $B6, $14, $74, $36, $B6, $5F,
$DF, $C7, $76, $7C, $A6, $79, $00, $21, $CD, $AC, $22, $DD, $88, $7F, $4B, $A3,
$B7, $60, $4F, $C4, $88, $20, $5F, $44, $03, $26, $1A, $17, $C7, $BC, $78, $5B,
$60, $F0, $1B, $EF, $3F, $7D, $45, $5F, $B6, $24, $94, $C0, $BC, $AD, $5E, $64,
$98, $33, $09, $9E, $27, $82, $BF, $F6, $64, $42, $9A, $32, $74, $56, $CA, $67,
$B0, $86, $9A, $84, $FF, $39, $D7, $7A, $FB, $68, $68, $F3, $0E, $A2, $65, $A3,
$55, $4A, $EF, $3C, $3D, $DB, $16, $2C, $5D, $6E, $B8, $26, $52, $91, $D3, $82,
$70, $DD, $B5, $EA, $53, $FA, $5B, $87, $26, $BC, $93, $86, $C7, $E7, $6B, $F0,
$C2, $1B, $2C, $D1, $3E, $93, $01, $C8, $55, $64, $EF, $AE, $6B, $18, $B1, $EA,
$78, $9A, $B8, $0A, $6B, $77, $8C, $11, $2B, $DE, $6E, $1D, $75, $6E, $03, $5C,
$38, $5D, $BB, $93, $41, $41, $BB, $08, $AF, $C5, $E4, $D2, $C0, $60, $49, $2D,
$0D, $8D, $3E, $34, $56, $E1, $6C, $AE, $5C, $95, $F8, $74, $0B, $65, $ED, $9A,
$33, $2C, $8F, $0E, $3E, $C9, $B0, $C8, $95, $DF, $E8, $2F, $52, $DC, $F5, $C4,
$7B, $90, $01, $40, $45, $A1, $77, $96, $12, $4C, $68, $15, $2B, $02, $A8, $7C,
$B4, $8D, $34, $5E, $D6, $20, $8F, $62, $BD, $73, $CC, $24, $97, $7C, $F3, $DB,
$80, $DA, $83, $50, $7F, $39, $DE, $97, $C4, $CD, $F9, $51, $53, $77, $47, $44,
$AF, $EE, $C6, $DB, $66, $07, $F0, $41, $54, $C7, $D8, $12, $0B, $08, $D9, $9D,
$9B, $B5, $DB, $CD, $44, $2C, $5E, $C0, $1C, $66, $2F, $C2, $0B, $61, $DE, $81,
$9E, $02, $31, $D5, $D4, $8C, $CC, $BF, $80, $99, $31, $C3, $45, $1B, $24, $B2,
$BE, $3F, $5E, $DB, $E2, $8E, $88, $41, $55, $15, $B5, $08, $80, $D0, $46, $7D,
$66, $53, $12, $9B, $73, $01, $7B, $DE, $35, $E1, $FC, $FD, $FA, $67, $D5, $F6,
$66, $A3, $10, $E9, $9E, $A8, $10, $B2, $54, $06, $51, $C5, $CF, $7B, $66, $D4,
$B9, $32, $97, $15, $62, $73, $5F, $A0, $1C, $B3, $32, $1E, $AB, $E3, $56, $51,
$DD, $92, $25, $1D, $53, $B7, $D6, $B5, $86, $FA, $67, $4D, $10, $E6, $97, $D4,
$73, $D7, $B6, $0B, $EB, $DD, $EA, $05, $D1, $75, $3B, $69, $5D, $6A, $95, $9E,
$8E, $0C, $A5, $EC, $46, $01, $4C, $23, $7C, $85, $FB, $31, $99, $AF, $79, $69,
$E8, $A3, $C6, $EB, $62, $90, $CB, $AB, $09, $8D, $66, $DF, $B4, $C2, $B5, $AF,
$2F, $2F, $76, $BC, $C4, $B7, $8D, $3D, $45, $57, $E0, $AC, $46, $EE, $64, $D8,
$C5, $2C, $CD, $ED, $24, $68, $4A, $3B, $20, $28, $32, $C5, $82, $7B, $D6, $AE,
$7E, $D9, $5A, $F6, $4F, $C2, $4C, $C4, $34, $E3, $A0, $9F, $FC, $5A, $6C, $02,
$04, $12, $75, $D1, $3A, $21, $0D, $45, $2A, $8B, $CE, $0C, $BD, $0A, $6F, $7C,
$05, $BE, $32, $3F, $99, $BF, $3B, $D4, $1B, $09, $68, $B5, $D1, $FD, $74, $73,
$7C, $82, $DB, $67, $07, $0E, $2D, $A6, $8D, $27, $C9, $FD, $4C, $31, $3A, $49,
$11, $78, $00, $FF, $12, $69, $78, $FD, $97, $90, $D8, $B8, $31, $5B, $AC, $FD,
$5F, $0E, $B5, $AA, $5B, $AE, $6A, $CE, $4B, $D2, $DF, $24, $41, $FE, $93, $0B,
$E6, $FF, $C4, $42, $B9, $4B, $F4, $5B, $A4, $5E, $63, $20, $6B, $EA, $6D, $0D,
$E3, $CC, $06, $61, $C3, $97, $D9, $AB, $5C, $7C, $AA, $28, $68, $88, $0C, $B4,
$C5, $EC, $48, $F8, $32, $22, $95, $05, $3D, $26, $6A, $9F, $CF, $BE, $8A, $A3,
$80, $D0, $C7, $CF, $F2, $A9, $15, $08, $8B, $EE, $A6, $0C, $46, $8E, $B0, $C9,
$31, $43, $50, $C8, $AD, $9D, $5F, $F6, $F6, $CC, $66, $8F, $E7, $19, $D8, $84,
$E1, $7B, $46, $48, $44, $4B, $0E, $A7, $03, $7D, $CE, $5C, $63, $97, $0B, $78,
$2F, $6C, $00, $6B, $44, $85, $50, $0F, $B8, $28, $44, $38, $1D, $AC, $06, $F4,
$47, $A1, $5D, $5B, $59, $50, $7A, $22, $08, $A1, $9F, $29, $22, $03, $AF, $EB,
$06, $F7, $18, $7F, $FB, $80, $BA, $45, $14, $03, $2B, $30, $D3, $E9, $1F, $55,
$F0, $B8, $B7, $8B, $81, $3A, $0A, $E6, $E8, $58, $15, $1A, $55, $36, $48, $01,
$8F, $B3, $90, $21, $E4, $BE, $DF, $C4, $A1, $1C, $D4, $1E, $B0, $A7, $80, $5E,
$D7, $1D, $F6, $2E, $33, $02, $CE, $AD, $FE, $4B, $42, $53, $88, $D9, $7C, $17,
$F6, $E0, $50, $F8, $2B, $FC, $60, $8F, $9C, $2A, $9F, $00, $10, $CC, $3B, $D9,
$59, $BB, $E3, $E0, $69, $74, $E5, $5C, $9D, $25, $F4, $2C, $0D, $44, $0A, $02,
$CA, $F1, $DD, $DE, $41, $3F, $E9, $B4, $1B, $25, $74, $FF, $86, $D2, $01, $55,
$85, $2E, $AF, $98, $6B, $B2, $9C, $C7, $95, $F1, $EC, $6C, $2C, $FA, $11, $F9,
$D0, $47, $5B, $2A, $A7, $25, $95, $A4, $50, $28, $A4, $EE, $25, $8B, $8A, $44,
$B1, $65, $E8, $6C, $3C, $97, $84, $11, $35, $D8, $2D, $17, $F8, $11, $AC, $07,
$3C, $C2, $05, $D1, $FE, $50, $04, $FC, $76, $31, $10, $35, $33, $D5, $E4, $BA,
$E9, $93, $83, $0A, $C6, $83, $4A, $B1, $18, $4A, $41, $0A, $7C, $BA, $A0, $1F,
$65, $4B, $ED, $F4, $DF, $DC, $6B, $23, $42, $49, $82, $AB, $F5, $DD, $6A, $65,
$FA, $5F, $96, $88, $17, $7B, $4F, $F8, $98, $69, $76, $FF, $27, $08, $CB, $27,
$CD, $90, $4D, $04, $69, $C6, $85, $C4, $32, $91, $13, $8E, $15, $AA, $5D, $6E,
$57, $D3, $73, $5B, $03, $06, $7E, $C4, $83, $D9, $47, $E6, $7F, $EC, $E1, $65,
$03, $FD, $07, $CC, $E5, $74, $37, $DE, $F6, $71, $5C, $01, $4A, $61, $F3, $30,
$3B, $4E, $6A, $0F, $49, $0C, $7F, $F5, $0B, $67, $3F, $4F, $33, $47, $3A, $42,
$FC, $F4, $EB, $FD, $0D, $34, $AF, $23, $AF, $AA, $4E, $4E, $68, $6F, $B7, $02,
$11, $82, $C0, $B2, $0C, $5F, $4F, $9B, $43, $3B, $58, $31, $A8, $4C, $C6, $DB,
$7F, $33, $D3, $F1, $A6, $66, $52, $B5, $FF, $E8, $78, $BA, $B2, $B7, $54, $69,
$C5, $E5, $27, $AB, $A7, $75, $CD, $91, $ED, $6B, $8E, $FC, $8E, $D6, $ED, $C5,
$35, $8B, $93, $56, $BB, $BD, $92, $1A, $93, $22, $64, $A2, $13, $8A, $90, $89,
$EE, $99, $D2, $90, $AE, $3D, $8F, $02, $08, $47, $8C, $99, $FD, $66, $8E, $7D,
$23, $5C, $EA, $7F, $A2, $67, $42, $A2, $4E, $B3, $F0, $6A, $85, $9D, $7A, $B6,
$F7, $F1, $36, $E3, $17, $44, $20, $5E, $7B, $A2, $B8, $55, $9B, $40, $EF, $FE,
$B2, $7F, $0F, $FF, $A3, $96, $04, $F3, $35, $AB, $15, $72, $29, $56, $5D, $2F,
$64, $AF, $49, $A4, $68, $E0, $AA, $D9, $FB, $09, $08, $6A, $30, $B0, $F4, $04,
$DD, $AE, $20, $A1, $D7, $0C, $49, $D4, $5E, $7E, $A0, $84, $41, $3B, $8F, $F4,
$4D, $97, $70, $E8, $4F, $DB, $FE, $EE, $D9, $8E, $5C, $3C, $9D, $FC, $DB, $CE,
$70, $2B, $01, $9A, $33, $6C, $46, $5D, $98, $22, $6D, $08, $5F, $AA, $C7, $C4,
$26, $F8, $05, $46, $A4, $C6, $EB, $4E, $C8, $EF, $63, $23, $1F, $C5, $C7, $8C,
$45, $3B, $5F, $E8, $8E, $7E, $52, $E6, $00, $97, $50, $4C, $20, $84, $22, $05,
$B4, $20, $5B, $FB, $A3, $6D, $A5, $8C, $E0, $11, $63, $F0, $6F, $7A, $3D, $8A,
$4F, $FF, $BC, $0C, $3B, $53, $D9, $6B, $B3, $79, $40, $44, $B6, $C3, $D7, $1B,
$48, $56, $9A, $0E, $AC, $15, $7D, $B9, $15, $BC, $D0, $08, $31, $D5, $70, $4D,
$9A, $98, $A0, $D9, $D0, $5A, $7B, $1E, $DB, $B8, $21, $F1, $F6, $98, $94, $79,
$A9, $AA, $31, $C0, $7C, $84, $C0, $11, $29, $CD, $17, $DD, $1A, $6C, $8D, $7F,
$8D, $E3, $58, $A6, $3D, $48, $84, $40, $CB, $16, $FA, $AA, $15, $11, $EF, $36,
$F2, $68, $79, $AF, $4C, $74, $CA, $C5, $D4, $DB, $1E, $CD, $1C, $39, $3E, $70,
$F0, $26, $3A, $91, $D1, $9E, $DC, $5C, $CF, $32, $97, $97, $CD, $33, $73, $E7,
$D9, $B4, $1D, $B9, $75, $C6, $8C, $09, $7B, $8D, $88, $EB, $02, $C3, $BF, $CF,
$DD, $B7, $2E, $2C, $9E, $1D, $92, $01, $2E, $95, $1F, $4C, $71, $13, $29, $C8,
$99, $2D, $A2, $D9, $54, $26, $12, $C2, $66, $C6, $CC, $AB, $5D, $C6, $C0, $22,
$07, $BE, $AB, $9B, $80, $6A, $9D, $4C, $92, $DD, $38, $24, $6A, $12, $7E, $47,
$E8, $AC, $B3, $09, $AD, $46, $04, $EE, $FB, $CF, $DF, $69, $17, $45, $8B, $18,
$74, $FD, $57, $B1, $7C, $4E, $6B, $8B, $6A, $C3, $21, $E4, $8B, $D6, $99, $52,
$FF, $B1, $63, $AC, $8F, $35, $63, $10, $3F, $EC, $B5, $40, $3A, $EA, $24, $28,
$DE, $49, $01, $8B, $D2, $9E, $E4, $6A, $B6, $44, $9E, $ED, $EB, $36, $C3, $4B,
$E1, $48, $D8, $CD, $D0, $F3, $EB, $5D, $16, $AD, $CD, $E6, $A1, $0B, $CD, $1D,
$21, $8F, $E4, $E0, $D1, $5E, $79, $46, $58, $C3, $E8, $EA, $0C, $71, $24, $F3,
$0A, $81, $CF, $AF, $76, $20, $68, $F2, $F5, $8E, $5D, $8F, $E5, $11, $D6, $86,
$0B, $87, $60, $C5, $D3, $63, $C0, $32, $EA, $20, $2B, $83, $66, $8D, $80, $54,
$66, $EC, $D3, $76, $83, $68, $5A, $01, $D0, $87, $07, $8C, $82, $80, $F6, $CF,
$07, $63, $C9, $CE, $3E, $41, $2F, $71, $D8, $24, $5B, $16, $53, $7E, $7E, $CF,
$D4, $C6, $12, $9F, $A3, $A6, $EE, $F3, $66, $06, $D1, $1A, $7D, $21, $E4, $51,
$D1, $84, $0D, $92, $9C, $B3, $A0, $2E, $3D, $7D, $F6, $86, $C8, $D5, $0D, $97,
$DB, $4E, $79, $BE, $1F, $B7, $5F, $C0, $FA, $BF, $16, $C6, $3F, $9A, $19, $8C,
$2F, $5B, $9B, $F6, $32, $66, $ED, $5A, $69, $DA, $19, $BC, $C3, $D2, $5E, $86,
$A5, $C2, $69, $4A, $DB, $BB, $7E, $07, $7E, $52, $68, $1E, $74, $92, $A9, $4B,
$EE, $CF, $53, $44, $4E, $08, $B9, $B2, $BD, $89, $08, $9A, $39, $D3, $D6, $4B,
$1D, $81, $2F, $4F, $B3, $CA, $80, $EF, $63, $F6, $BB, $2C, $8F, $F7, $85, $A6,
$84, $68, $66, $05, $0A, $A6, $67, $B8, $1D, $B1, $65, $F2, $E9, $D0, $0A, $8E,
$89, $CB, $75, $0D, $EE, $AA, $64, $76, $E9, $27, $BF, $95, $3A, $72, $A9, $7F,
$E7, $A0, $26, $BD, $AE, $8D, $86, $D6, $AA, $21, $1F, $8D, $39, $61, $F0, $E0,
$72, $97, $F2, $15, $7E, $3D, $8E, $FA, $3F, $54, $83, $BB, $80, $62, $01, $2B,
$6F, $69, $8E, $1F, $17, $81, $63, $2B, $0C, $BC, $EB, $DC, $F6, $EF, $E3, $C6,
$27, $40, $17, $FF, $BC, $8D, $7F, $CA, $39, $AB, $30, $7F, $21, $0A, $53, $F2,
$60, $9F, $BB, $FA, $4B, $38, $38, $00, $F9, $26, $57, $09, $1C, $9B, $05, $F2,
$4F, $06, $16, $7A, $2E, $FC, $23, $88, $3A, $F0, $35, $5F, $64, $46, $FC, $C5,
$93, $2E, $FA, $86, $E2, $64, $F3, $9C, $3B, $FB, $74, $8A, $95, $9F, $5A, $3D,
$03, $AF, $B3, $FE, $8C, $D2, $25, $B4, $E8, $9B, $FA, $46, $A8, $A0, $54, $D8,
$44, $38, $FA, $C5, $EC, $7A, $D2, $AC, $FD, $2A, $CD, $F6, $AF, $85, $9D, $7A,
$DE, $28, $76, $7F, $58, $D5, $24, $7A, $75, $8D, $7A, $A6, $D3, $E5, $63, $F9,
$F8, $C7, $FC, $9F, $C6, $81, $F5, $AB, $C6, $53, $70, $A0, $6A, $8B, $1A, $A9,
$56, $A9, $89, $97, $BD, $FF, $77, $77, $00, $B9, $67, $9B, $CD, $59, $F1, $4E,
$76, $EF, $72, $CC, $71, $8D, $B1, $37, $BC, $64, $3B, $0A, $4C, $B6, $FD, $6E,
$E7, $71, $BA, $EE, $EC, $3F, $86, $50, $10, $89, $B1, $45, $BF, $E0, $C3, $2C,
$33, $1E, $CB, $54, $AB, $BD, $92, $44, $E0, $28, $E9, $A9, $9C, $36, $AA, $54,
$55, $A0, $DC, $89, $00, $C2, $41, $78, $B6, $3B, $90, $F0, $4C, $C2, $C4, $3E,
$A4, $56, $48, $FA, $7B, $6B, $36, $75, $28, $11, $7C, $DC, $EE, $36, $59, $66,
$2D, $6F, $BC, $DE, $66, $79, $F2, $92, $A0, $EA, $F8, $46, $47, $92, $D2, $43,
$FC, $1C, $0F, $10, $04, $BF, $D5, $92, $CD, $D1, $C9, $55, $88, $09, $57, $73,
$2C, $32, $A7, $84, $84, $1E, $57, $A1, $FC, $15, $0A, $DF, $39, $0B, $FF, $55,
$69, $E0, $F3, $CA, $EC, $72, $A1, $E4, $41, $FA, $4C, $9C, $A8, $AF, $B9, $29,
$64, $B4, $A2, $8A, $D4, $DD, $58, $0A, $1F, $AF, $CD, $D6, $54, $4D, $D1, $32,
$7F, $C6, $C5, $1D, $79, $9B, $97, $EA, $4C, $62, $F4, $30, $D6, $5A, $34, $EF,
$A2, $69, $C0, $DB, $88, $97, $5D, $3F, $46, $A0, $4C, $15, $AB, $9D, $30, $DD,
$96, $49, $38, $EC, $63, $98, $5C, $D0, $27, $B2, $B7, $7D, $B8, $73, $74, $B8,
$AA, $3A, $BA, $38, $8C, $B2, $E9, $4C, $1A, $61, $5D, $97, $0B, $AE, $FF, $64,
$47, $0A, $5D, $23, $D4, $15, $B9, $C5, $08, $B4, $70, $97, $37, $CD, $77, $A4,
$46, $00, $CE, $C5, $43, $8B, $46, $24, $A9, $DD, $12, $7C, $46, $AB, $CD, $5D,
$44, $23, $16, $F3, $B4, $9C, $7A, $2D, $95, $82, $17, $FA, $CB, $1C, $FF, $2A,
$06, $78, $19, $24, $56, $53, $31, $B6, $C6, $06, $0D, $0C, $E9, $47, $6E, $08,
$FB, $22, $17, $3D, $89, $FC, $47, $D5, $77, $EA, $10, $91, $BA, $78, $FC, $B4,
$5E, $E5, $F7, $CB, $7B, $1C, $32, $D5, $FC, $93, $C0, $A8, $FD, $69, $11, $4F,
$71, $E1, $21, $86, $CC, $00, $23, $F6, $4F, $E9, $B2, $E1, $9B, $22, $DA, $7F,
$67, $5E, $10, $E3, $13, $A3, $4C, $98, $F1, $C8, $D5, $A7, $4D, $E5, $15, $B0,
$FB, $C8, $CA, $C6, $CD, $C6, $C0, $7F, $78, $5D, $14, $C6, $96, $51, $7B, $F6,
$EF, $05, $49, $CB, $D0, $7D, $8B, $EF, $D9, $7A, $49, $29, $57, $EE, $A0, $EE,
$CC, $B4, $B8, $58, $A7, $6B, $55, $27, $D8, $F2, $00, $88, $1D, $D8, $AA, $AF,
$19, $63, $83, $07, $E5, $04, $49, $B6, $E6, $19, $12, $20, $7D, $30, $C5, $87,
$B3, $C9, $BF, $5A, $61, $8F, $4F, $81, $AC, $DC, $11, $25, $F5, $84, $53, $A3,
$68, $91, $99, $5D, $01, $C5, $95, $57, $5F, $41, $C8, $74, $9D, $70, $C3, $14,
$47, $63, $EE, $ED, $31, $7E, $D9, $C4, $3C, $A1, $DB, $D5, $15, $50, $BD, $BD,
$52, $7F, $C0, $CF, $E6, $2F, $FE, $15, $37, $CC, $15, $73, $8F, $61, $EB, $25,
$21, $4F, $CC, $97, $0F, $5E, $B5, $05, $F4, $28, $5B, $F5, $82, $CE, $FF, $E6,
$BA, $B0, $89, $A1, $4D, $13, $F4, $10, $B0, $2B, $1D, $81, $62, $3D, $B1, $0E,
$2E, $F6, $75, $17, $50, $20, $40, $9A, $08, $C5, $18, $A3, $C2, $FB, $EC, $60,
$EF, $51, $BB, $A6, $E1, $C0, $5E, $BB, $F2, $43, $2A, $79, $B6, $73, $84, $66,
$A2, $C4, $43, $FB, $0D, $47, $46, $EA, $89, $C0, $21, $58, $17, $FD, $E9, $00,
$91, $B7, $AD, $B3, $57, $0B, $58, $57, $7A, $1E, $5E, $49, $74, $8E, $14, $4D,
$1D, $28, $2B, $95, $CE, $96, $16, $BF, $59, $D2, $3C, $60, $E5, $5C, $54, $C2,
$B9, $58, $E1, $FA, $6C, $45, $71, $00, $E1, $AE, $76, $67, $01, $9D, $A2, $40,
$69, $EA, $D2, $AE, $F0, $B5, $A8, $EA, $02, $07, $A5, $98, $A2, $DC, $6A, $94,
$9E, $65, $57, $58, $B7, $EE, $28, $5A, $EA, $ED, $DA, $3A, $49, $A7, $50, $D4,
$B9, $85, $67, $5E, $5C, $D4, $AC, $D5, $2D, $3D, $F3, $B1, $32, $A1, $CF, $7E,
$03, $78, $E5, $4C, $8B, $72, $46, $09, $C3, $7D, $A8, $9C, $EE, $18, $15, $51,
$C5, $C2, $83, $5D, $4D, $B7, $C7, $F9, $33, $9B, $67, $18, $5B, $F9, $1D, $F3,
$5F, $26, $5E, $B0, $1D, $BE, $DF, $CF, $26, $C4, $AB, $CF, $59, $CD, $B9, $46,
$BC, $C6, $24, $AF, $5E, $F5, $85, $02, $FE, $83, $27, $59, $5D, $AE, $C8, $2F,
$1E, $05, $46, $E7, $3E, $BE, $33, $06, $85, $91, $92, $68, $08, $AD, $0C, $61,
$F6, $D8, $0D, $66, $43, $DB, $32, $1E, $FF, $AE, $CF, $5B, $22, $DC, $C6, $09,
$8F, $4E, $F3, $11, $2A, $E8, $FA, $82, $A8, $18, $15, $A4, $42, $A5, $EC, $3D,
$60, $CF, $A6, $EB, $81, $AD, $74, $A9, $5C, $BB, $6E, $A7, $88, $80, $A4, $54,
$8F, $E6, $E4, $F7, $17, $41, $1A, $23, $30, $35, $E5, $CF, $BB, $82, $C7, $FE,
$0E, $F0, $5E, $E9, $AD, $CD, $0D, $E0, $1C, $65, $00, $CD, $55, $B6, $2B, $71,
$B2, $3E, $64, $B7, $7C, $9C, $88, $7A, $B5, $C1, $86, $5B, $10, $91, $5E, $47,
$3F, $08, $1C, $4A, $F0, $A1, $F6, $C1, $8D, $F4, $8A, $E5, $8F, $0B, $78, $F7,
$81, $54, $D1, $1D, $97, $3C, $C6, $97, $E2, $73, $FA, $B1, $AD, $A6, $97, $FF,
$00, $BF, $2F, $E1, $EA, $8A, $84, $EC, $C1, $3C, $B2, $C0, $A8, $F2, $3F, $43,
$69, $47, $EC, $69, $3E, $2C, $0E, $07, $F3, $1F, $AD, $4D, $27, $51, $66, $66,
$45, $7A, $12, $4B, $8B, $F1, $61, $55, $AC, $2A, $69, $88, $10, $A0, $47, $CC,
$BF, $8D, $10, $AA, $A8, $F3, $43, $F3, $E2, $D6, $23, $8C, $6E, $F7, $C5, $5D,
$C6, $70, $15, $0F, $34, $80, $AC, $7B, $53, $94, $16, $AC, $B3, $A0, $49, $C8,
$00, $94, $D1, $83, $D3, $74, $31, $26, $42, $96, $A5, $FC, $BF, $15, $8D, $80,
$45, $FC, $23, $7E, $C1, $D9, $9C, $D8, $70, $45, $B3, $A1, $0B, $2D, $49, $09,
$57, $23, $88, $82, $F9, $75, $31, $75, $1F, $FD, $1E, $57, $1C, $CC, $E2, $0D,
$A9, $FD, $EF, $35, $0A, $35, $58, $4B, $51, $DA, $4D, $86, $9C, $EF, $92, $90,
$3B, $E8, $EF, $9A, $5F, $0D, $86, $4F, $88, $D6, $77, $49, $79, $FA, $22, $39,
$80, $CD, $7E, $87, $B2, $48, $DA, $0B, $B2, $BF, $63, $D9, $EB, $11, $14, $B0,
$DB, $09, $04, $0D, $93, $3C, $BD, $6C, $A5, $62, $8F, $20, $46, $82, $B5, $F8,
$E4, $D5, $DC, $CE, $39, $E2, $A1, $73, $A2, $89, $BC, $E6, $4C, $2B, $DB, $43,
$5B, $99, $62, $CC, $E8, $6D, $02, $5F, $D1, $43, $A3, $4A, $1E, $E8, $40, $AC,
$86, $C4, $87, $E8, $8B, $27, $66, $09, $60, $F1, $B5, $27, $5A, $12, $E3, $72,
$8A, $5A, $81, $CE, $F4, $90, $A0, $A3, $50, $99, $4B, $40, $3D, $EB, $7D, $9B,
$2F, $00, $26, $82, $5B, $32, $C9, $B0, $F2, $97, $FF, $DB, $7A, $F0, $D9, $77,
$6C, $A7, $AE, $E6, $91, $63, $22, $3C, $15, $68, $29, $ED, $8D, $14, $ED, $53,
$4F, $88, $1E, $FF, $EA, $06, $C9, $FB, $5B, $DA, $3A, $5F, $88, $78, $D4, $42,
$08, $97, $94, $94, $DE, $A0, $34, $02, $1C, $59, $0D, $9C, $44, $D0, $EF, $D3,
$90, $2B, $AC, $96, $2C, $66, $AA, $A2, $6C, $7C, $7B, $DF, $20, $D7, $E6, $D8,
$1C, $B9, $DF, $FB, $A3, $E2, $D7, $85, $43, $71, $0B, $54, $89, $AF, $83, $CD,
$7A, $95, $04, $BC, $7C, $6A, $01, $26, $E2, $1E, $5D, $F7, $F8, $D0, $D1, $04,
$7F, $CB, $D2, $06, $DD, $B1, $45, $09, $C5, $77, $E9, $7E, $5E, $89, $7A, $76,
$09, $64, $57, $A6, $3E, $85, $05, $78, $82, $6F, $29, $76, $24, $3E, $B2, $3E,
$81, $54, $9E, $22, $C8, $D0, $4C, $2C, $73, $50, $79, $5F, $5E, $3C, $EA, $F3,
$84, $2A, $48, $4F, $90, $A7, $92, $0F, $0B, $E3, $59, $22, $60, $E7, $9E, $49,
$DD, $80, $32, $6C, $E5, $5C, $72, $44, $01, $6F, $13, $42, $FE, $D6, $14, $28,
$1F, $7F, $DC, $78, $2E, $33, $C6, $13, $95, $5D, $93, $21, $9C, $31, $2E, $9A,
$07, $22, $61, $09, $AE, $9C, $7C, $8E, $EB, $39, $2D, $C8, $D4, $A0, $92, $43,
$E5, $7F, $FD, $D2, $2E, $AE, $20, $B9, $09, $F3, $55, $31, $9D, $D8, $9D, $35,
$0A, $19, $8E, $C9, $DB, $8A, $35, $72, $5D, $D1, $75, $4C, $C8, $C2, $5F, $FB,
$12, $0A, $10, $DA, $49, $F8, $00, $F2, $F7, $F5, $0A, $84, $88, $2A, $CE, $A9,
$2C, $77, $A0, $98, $A9, $04, $1B, $B9, $8D, $6C, $4E, $BB, $EA, $F1, $C1, $72,
$55, $35, $B6, $DE, $BF, $53, $8C, $F4, $89, $F4, $92, $88, $55, $E6, $A3, $9F,
$B1, $52, $AF, $50, $47, $7B, $C3, $42, $BB, $50, $E0, $6D, $FC, $8E, $12, $C7,
$21, $0D, $A8, $9C, $6D, $85, $A4, $85, $52, $0C, $F4, $0D, $22, $33, $98, $34,
$8E, $A9, $24, $1E, $F5, $97, $73, $DD, $DA, $16, $7C, $7C, $65, $6F, $C3, $85,
$41, $D1, $E7, $B3, $AD, $47, $6E, $6F, $4D, $F0, $CB, $64, $72, $09, $C0, $FA,
$BB, $5A, $02, $DA, $1D, $97, $10, $00, $4E, $E5, $3A, $5C, $89, $36, $77, $F8,
$78, $8C, $CC, $F3, $81, $C0, $1B, $8E, $04, $7E, $D1, $1D, $3B, $87, $0E, $BA,
$C2, $FD, $D5, $20, $75, $C1, $5C, $97, $C7, $4A, $41, $FF, $7D, $11, $2A, $9F,
$2B, $09, $F1, $BE, $4C, $48, $CE, $21, $AB, $E1, $6E, $B1, $09, $3C, $98, $69,
$58, $23, $EF, $CF, $B9, $AF, $49, $6D, $BF, $D4, $5A, $2F, $F0, $40, $A1, $E2,
$B9, $DE, $27, $86, $05, $0A, $66, $39, $04, $00, $6C, $0A, $F4, $BF, $5F, $33,
$D8, $D5, $19, $DA, $6D, $B7, $39, $29, $75, $35, $4D, $FD, $50, $B1, $38, $51,
$95, $7D, $99, $A6, $22, $E6, $F4, $47, $DF, $4F, $12, $CD, $5E, $35, $E0, $97,
$5F, $FE, $05, $57, $7D, $33, $43, $34, $CB, $6F, $57, $C6, $0D, $C5, $D3, $CF,
$7D, $78, $A1, $A4, $D7, $4E, $30, $70, $5A, $02, $88, $98, $51, $48, $A2, $96,
$AA, $7F, $1B, $A4, $80, $CF, $3A, $2A, $9C, $26, $C8, $F1, $C5, $4D, $76, $35,
$DC, $D1, $31, $57, $F9, $77, $16, $D2, $F7, $A9, $A0, $69, $38, $AD, $A0, $DD,
$51, $83, $4E, $E9, $F6, $FF, $BB, $66, $4F, $83, $1E, $94, $54, $7C, $81, $29,
$6C, $F7, $EE, $19, $46, $7F, $43, $73, $E2, $CD, $CA, $44, $D5, $15, $92, $6A,
$E7, $0C, $93, $7F, $ED, $7F, $60, $59, $EA, $49, $24, $A8, $E9, $D2, $E0, $5B,
$B2, $63, $43, $9E, $97, $D9, $9A, $AC, $7A, $7A, $80, $3E, $C9, $03, $4A, $F8,
$CB, $79, $99, $38, $74, $85, $0F, $B0, $C1, $F7, $77, $0B, $B8, $D8, $22, $2C,
$61, $5D, $BF, $E3, $4A, $55, $F2, $DE, $BD, $7A, $F5, $96, $4F, $40, $3B, $D4,
$30, $0C, $0D, $84, $88, $96, $A6, $5B, $8A, $FE, $4F, $C1, $85, $B3, $46, $4F,
$BE, $FE, $9E, $A9, $D3, $BE, $87, $A5, $06, $48, $08, $74, $37, $09, $B5, $D6,
$EE, $93, $30, $2E, $C4, $20, $B2, $CD, $BE, $19, $A0, $DE, $58, $EA, $C3, $58,
$21, $50, $59, $AB, $29, $44, $F4, $43, $FD, $04, $DA, $31, $CB, $69, $04, $A4,
$4D, $C5, $94, $1E, $48, $28, $D9, $B2, $36, $E3, $1D, $0C, $0C, $D8, $3E, $6A,
$0C, $EF, $13, $01, $77, $EF, $C2, $4E, $6D, $4E, $06, $9A, $E3, $9F, $6D, $81,
$7B, $58, $9F, $69, $B5, $42, $86, $B6, $91, $F0, $45, $BF, $0C, $85, $62, $09,
$AF, $84, $97, $1F, $9E, $FE, $25, $A5, $A7, $6E, $92, $81, $23, $BF, $49, $7B,
$6C, $78, $7D, $77, $C6, $12, $2C, $CE, $49, $F8, $D4, $43, $8C, $41, $34, $2E,
$67, $03, $F1, $A6, $57, $5A, $DF, $20, $00, $00, $00, $00, $00, $00, $00, $00,
$48, $89, $4C, $24, $08, $48, $89, $54, $24, $10, $4C, $89, $44, $24, $18, $80,
$FA, $01, $0F, $85, $D3, $0B, $00, $00, $53, $56, $57, $55, $48, $8D, $35, $8D,
$19, $FF, $FF, $48, $8D, $BE, $00, $60, $FE, $FF, $57, $B8, $BA, $7B, $02, $00,
$50, $48, $89, $E1, $48, $89, $FA, $48, $89, $F7, $BE, $47, $E6, $00, $00, $55,
$48, $89, $E5, $44, $8B, $09, $49, $89, $D0, $48, $89, $F2, $48, $8D, $77, $02,
$56, $8A, $07, $FF, $CA, $88, $C1, $24, $07, $C0, $E9, $03, $48, $C7, $C3, $00,
$FD, $FF, $FF, $48, $D3, $E3, $88, $C1, $48, $8D, $9C, $5C, $88, $F1, $FF, $FF,
$48, $83, $E3, $C0, $6A, $00, $48, $39, $DC, $75, $F9, $53, $48, $8D, $7B, $08,
$8A, $4E, $FF, $FF, $CA, $88, $47, $02, $88, $C8, $C0, $E9, $04, $88, $4F, $01,
$24, $0F, $88, $07, $48, $8D, $4F, $FC, $50, $41, $57, $48, $8D, $47, $04, $45,
$31, $FF, $41, $56, $41, $BE, $01, $00, $00, $00, $41, $55, $45, $31, $ED, $41,
$54, $55, $53, $48, $83, $EC, $48, $48, $89, $4C, $24, $38, $48, $89, $44, $24,
$20, $B8, $01, $00, $00, $00, $48, $89, $74, $24, $40, $4C, $89, $44, $24, $30,
$89, $C3, $44, $89, $4C, $24, $2C, $0F, $B6, $4F, $02, $D3, $E3, $89, $D9, $48,
$8B, $9C, $24, $80, $00, $00, $00, $FF, $C9, $89, $4C, $24, $1C, $0F, $B6, $4F,
$01, $D3, $E0, $48, $8B, $4C, $24, $38, $FF, $C8, $89, $44, $24, $18, $0F, $B6,
$07, $C7, $01, $00, $00, $00, $00, $C7, $44, $24, $10, $00, $00, $00, $00, $C7,
$44, $24, $0C, $01, $00, $00, $00, $C7, $44, $24, $08, $01, $00, $00, $00, $C7,
$44, $24, $04, $01, $00, $00, $00, $C7, $03, $00, $00, $00, $00, $89, $44, $24,
$14, $0F, $B6, $4F, $01, $01, $C1, $B8, $00, $03, $00, $00, $D3, $E0, $31, $C9,
$8D, $B8, $36, $07, $00, $00, $41, $39, $FF, $73, $13, $48, $8B, $5C, $24, $20,
$89, $C8, $FF, $C1, $39, $F9, $66, $C7, $04, $43, $00, $04, $EB, $EB, $48, $8B,
$7C, $24, $40, $89, $D0, $45, $31, $D2, $41, $83, $CB, $FF, $31, $D2, $49, $89,
$FC, $49, $01, $C4, $4C, $39, $E7, $0F, $84, $EB, $08, $00, $00, $0F, $B6, $07,
$41, $C1, $E2, $08, $FF, $C2, $48, $FF, $C7, $41, $09, $C2, $83, $FA, $04, $7E,
$E3, $44, $3B, $7C, $24, $2C, $0F, $83, $D6, $08, $00, $00, $8B, $44, $24, $1C,
$48, $63, $5C, $24, $10, $48, $8B, $54, $24, $20, $44, $21, $F8, $89, $04, $24,
$48, $63, $2C, $24, $48, $89, $D8, $48, $C1, $E0, $04, $48, $01, $E8, $41, $81,
$FB, $FF, $FF, $FF, $00, $4C, $8D, $0C, $42, $77, $1A, $4C, $39, $E7, $0F, $84,
$94, $08, $00, $00, $0F, $B6, $07, $41, $C1, $E2, $08, $41, $C1, $E3, $08, $48,
$FF, $C7, $41, $09, $C2, $41, $0F, $B7, $11, $44, $89, $D8, $C1, $E8, $0B, $0F,
$B7, $CA, $0F, $AF, $C1, $41, $39, $C2, $0F, $83, $C5, $01, $00, $00, $41, $89,
$C3, $B8, $00, $08, $00, $00, $48, $8B, $5C, $24, $20, $29, $C8, $0F, $B6, $4C,
$24, $14, $BE, $01, $00, $00, $00, $C1, $F8, $05, $8D, $04, $02, $41, $0F, $B6,
$D5, $66, $41, $89, $01, $8B, $44, $24, $18, $44, $21, $F8, $D3, $E0, $B9, $08,
$00, $00, $00, $2B, $4C, $24, $14, $D3, $FA, $01, $D0, $69, $C0, $00, $03, $00,
$00, $83, $7C, $24, $10, $06, $89, $C0, $4C, $8D, $8C, $43, $6C, $0E, $00, $00,
$0F, $8E, $B8, $00, $00, $00, $48, $8B, $54, $24, $30, $44, $89, $F8, $44, $29,
$F0, $0F, $B6, $2C, $02, $01, $ED, $48, $63, $D6, $89, $EB, $81, $E3, $00, $01,
$00, $00, $41, $81, $FB, $FF, $FF, $FF, $00, $48, $63, $C3, $49, $8D, $04, $41,
$4C, $8D, $04, $50, $77, $1A, $4C, $39, $E7, $0F, $84, $D9, $07, $00, $00, $0F,
$B6, $07, $41, $C1, $E2, $08, $41, $C1, $E3, $08, $48, $FF, $C7, $41, $09, $C2,
$41, $0F, $B7, $90, $00, $02, $00, $00, $44, $89, $D8, $C1, $E8, $0B, $0F, $B7,
$CA, $0F, $AF, $C1, $41, $39, $C2, $73, $20, $41, $89, $C3, $B8, $00, $08, $00,
$00, $01, $F6, $29, $C8, $C1, $F8, $05, $85, $DB, $8D, $04, $02, $66, $41, $89,
$80, $00, $02, $00, $00, $74, $21, $EB, $2D, $41, $29, $C3, $41, $29, $C2, $89,
$D0, $66, $C1, $E8, $05, $8D, $74, $36, $01, $66, $29, $C2, $85, $DB, $66, $41,
$89, $90, $00, $02, $00, $00, $74, $0E, $81, $FE, $FF, $00, $00, $00, $0F, $8E,
$61, $FF, $FF, $FF, $EB, $78, $81, $FE, $FF, $00, $00, $00, $7F, $70, $48, $63,
$C6, $41, $81, $FB, $FF, $FF, $FF, $00, $4D, $8D, $04, $41, $77, $1A, $4C, $39,
$E7, $0F, $84, $41, $07, $00, $00, $0F, $B6, $07, $41, $C1, $E2, $08, $41, $C1,
$E3, $08, $48, $FF, $C7, $41, $09, $C2, $41, $0F, $B7, $10, $44, $89, $D8, $C1,
$E8, $0B, $0F, $B7, $CA, $0F, $AF, $C1, $41, $39, $C2, $73, $18, $41, $89, $C3,
$B8, $00, $08, $00, $00, $01, $F6, $29, $C8, $C1, $F8, $05, $8D, $04, $02, $66,
$41, $89, $00, $EB, $A1, $41, $29, $C3, $41, $29, $C2, $89, $D0, $66, $C1, $E8,
$05, $8D, $74, $36, $01, $66, $29, $C2, $66, $41, $89, $10, $EB, $88, $48, $8B,
$4C, $24, $30, $44, $89, $F8, $41, $FF, $C7, $41, $89, $F5, $40, $88, $34, $01,
$83, $7C, $24, $10, $03, $7F, $0D, $C7, $44, $24, $10, $00, $00, $00, $00, $E9,
$A4, $06, $00, $00, $8B, $54, $24, $10, $8B, $44, $24, $10, $83, $EA, $03, $83,
$E8, $06, $83, $7C, $24, $10, $09, $0F, $4F, $D0, $89, $54, $24, $10, $E9, $85,
$06, $00, $00, $41, $29, $C3, $41, $29, $C2, $89, $D0, $66, $C1, $E8, $05, $66,
$29, $C2, $48, $8B, $44, $24, $20, $41, $81, $FB, $FF, $FF, $FF, $00, $66, $41,
$89, $11, $48, $8D, $34, $58, $77, $1A, $4C, $39, $E7, $0F, $84, $77, $06, $00,
$00, $0F, $B6, $07, $41, $C1, $E2, $08, $41, $C1, $E3, $08, $48, $FF, $C7, $41,
$09, $C2, $0F, $B7, $96, $80, $01, $00, $00, $44, $89, $D8, $C1, $E8, $0B, $0F,
$B7, $CA, $0F, $AF, $C1, $41, $39, $C2, $73, $4E, $41, $89, $C3, $B8, $00, $08,
$00, $00, $4C, $8B, $4C, $24, $20, $29, $C8, $8B, $4C, $24, $0C, $44, $89, $74,
$24, $0C, $C1, $F8, $05, $8D, $04, $02, $8B, $54, $24, $08, $89, $4C, $24, $08,
$66, $89, $86, $80, $01, $00, $00, $31, $C0, $83, $7C, $24, $10, $06, $89, $54,
$24, $04, $0F, $9F, $C0, $49, $81, $C1, $64, $06, $00, $00, $8D, $04, $40, $89,
$44, $24, $10, $E9, $54, $02, $00, $00, $41, $29, $C3, $41, $29, $C2, $89, $D0,
$66, $C1, $E8, $05, $66, $29, $C2, $41, $81, $FB, $FF, $FF, $FF, $00, $66, $89,
$96, $80, $01, $00, $00, $77, $1A, $4C, $39, $E7, $0F, $84, $D8, $05, $00, $00,
$0F, $B6, $07, $41, $C1, $E2, $08, $41, $C1, $E3, $08, $48, $FF, $C7, $41, $09,
$C2, $0F, $B7, $96, $98, $01, $00, $00, $44, $89, $D8, $C1, $E8, $0B, $0F, $B7,
$CA, $0F, $AF, $C1, $41, $39, $C2, $0F, $83, $D0, $00, $00, $00, $41, $B8, $00,
$08, $00, $00, $41, $89, $C3, $48, $C1, $E3, $05, $44, $89, $C0, $29, $C8, $C1,
$F8, $05, $8D, $04, $02, $66, $89, $86, $98, $01, $00, $00, $48, $8B, $44, $24,
$20, $48, $01, $D8, $41, $81, $FB, $FF, $FF, $FF, $00, $48, $8D, $34, $68, $77,
$1A, $4C, $39, $E7, $0F, $84, $6E, $05, $00, $00, $0F, $B6, $07, $41, $C1, $E2,
$08, $41, $C1, $E3, $08, $48, $FF, $C7, $41, $09, $C2, $0F, $B7, $96, $E0, $01,
$00, $00, $44, $89, $D8, $C1, $E8, $0B, $0F, $B7, $CA, $0F, $AF, $C1, $41, $39,
$C2, $73, $4F, $41, $29, $C8, $41, $89, $C3, $41, $C1, $F8, $05, $45, $85, $FF,
$42, $8D, $04, $02, $66, $89, $86, $E0, $01, $00, $00, $0F, $84, $27, $05, $00,
$00, $31, $C0, $83, $7C, $24, $10, $06, $48, $8B, $5C, $24, $30, $0F, $9F, $C0,
$8D, $44, $00, $09, $89, $44, $24, $10, $44, $89, $F8, $44, $29, $F0, $44, $0F,
$B6, $2C, $03, $44, $89, $F8, $41, $FF, $C7, $44, $88, $2C, $03, $E9, $D6, $04,
$00, $00, $41, $29, $C3, $41, $29, $C2, $89, $D0, $66, $C1, $E8, $05, $66, $29,
$C2, $66, $89, $96, $E0, $01, $00, $00, $E9, $11, $01, $00, $00, $41, $29, $C3,
$41, $29, $C2, $89, $D0, $66, $C1, $E8, $05, $66, $29, $C2, $41, $81, $FB, $FF,
$FF, $FF, $00, $66, $89, $96, $98, $01, $00, $00, $77, $1A, $4C, $39, $E7, $0F,
$84, $B3, $04, $00, $00, $0F, $B6, $07, $41, $C1, $E2, $08, $41, $C1, $E3, $08,
$48, $FF, $C7, $41, $09, $C2, $0F, $B7, $96, $B0, $01, $00, $00, $44, $89, $D8,
$C1, $E8, $0B, $0F, $B7, $CA, $0F, $AF, $C1, $41, $39, $C2, $73, $20, $41, $89,
$C3, $B8, $00, $08, $00, $00, $29, $C8, $C1, $F8, $05, $8D, $04, $02, $66, $89,
$86, $B0, $01, $00, $00, $8B, $44, $24, $0C, $E9, $98, $00, $00, $00, $41, $29,
$C3, $41, $29, $C2, $89, $D0, $66, $C1, $E8, $05, $66, $29, $C2, $41, $81, $FB,
$FF, $FF, $FF, $00, $66, $89, $96, $B0, $01, $00, $00, $77, $1A, $4C, $39, $E7,
$0F, $84, $42, $04, $00, $00, $0F, $B6, $07, $41, $C1, $E2, $08, $41, $C1, $E3,
$08, $48, $FF, $C7, $41, $09, $C2, $0F, $B7, $96, $C8, $01, $00, $00, $44, $89,
$D8, $C1, $E8, $0B, $0F, $B7, $CA, $0F, $AF, $C1, $41, $39, $C2, $73, $1D, $41,
$89, $C3, $B8, $00, $08, $00, $00, $29, $C8, $C1, $F8, $05, $8D, $04, $02, $66,
$89, $86, $C8, $01, $00, $00, $8B, $44, $24, $08, $EB, $22, $41, $29, $C3, $41,
$29, $C2, $89, $D0, $66, $C1, $E8, $05, $66, $29, $C2, $8B, $44, $24, $04, $66,
$89, $96, $C8, $01, $00, $00, $8B, $54, $24, $08, $89, $54, $24, $04, $8B, $4C,
$24, $0C, $89, $4C, $24, $08, $44, $89, $74, $24, $0C, $41, $89, $C6, $31, $C0,
$83, $7C, $24, $10, $06, $4C, $8B, $4C, $24, $20, $0F, $9F, $C0, $49, $81, $C1,
$68, $0A, $00, $00, $8D, $44, $40, $08, $89, $44, $24, $10, $41, $81, $FB, $FF,
$FF, $FF, $00, $77, $1A, $4C, $39, $E7, $0F, $84, $9A, $03, $00, $00, $0F, $B6,
$07, $41, $C1, $E2, $08, $41, $C1, $E3, $08, $48, $FF, $C7, $41, $09, $C2, $41,
$0F, $B7, $11, $44, $89, $D8, $C1, $E8, $0B, $0F, $B7, $CA, $0F, $AF, $C1, $41,
$39, $C2, $73, $26, $41, $89, $C3, $B8, $00, $08, $00, $00, $45, $31, $ED, $29,
$C8, $C1, $F8, $05, $8D, $04, $02, $66, $41, $89, $01, $48, $63, $04, $24, $48,
$C1, $E0, $04, $4D, $8D, $44, $01, $04, $EB, $77, $41, $29, $C3, $41, $29, $C2,
$89, $D0, $66, $C1, $E8, $05, $66, $29, $C2, $41, $81, $FB, $FF, $FF, $FF, $00,
$66, $41, $89, $11, $77, $1A, $4C, $39, $E7, $0F, $84, $29, $03, $00, $00, $0F,
$B6, $07, $41, $C1, $E2, $08, $41, $C1, $E3, $08, $48, $FF, $C7, $41, $09, $C2,
$41, $0F, $B7, $51, $02, $44, $89, $D8, $C1, $E8, $0B, $0F, $B7, $CA, $0F, $AF,
$C1, $41, $39, $C2, $73, $33, $41, $89, $C3, $B8, $00, $08, $00, $00, $41, $BD,
$08, $00, $00, $00, $29, $C8, $C1, $F8, $05, $8D, $04, $02, $66, $41, $89, $41,
$02, $48, $63, $04, $24, $48, $C1, $E0, $04, $4D, $8D, $84, $01, $04, $01, $00,
$00, $41, $B9, $03, $00, $00, $00, $EB, $27, $41, $29, $C3, $41, $29, $C2, $89,
$D0, $66, $C1, $E8, $05, $4D, $8D, $81, $04, $02, $00, $00, $41, $BD, $10, $00,
$00, $00, $66, $29, $C2, $66, $41, $89, $51, $02, $41, $B9, $08, $00, $00, $00,
$44, $89, $CB, $BD, $01, $00, $00, $00, $48, $63, $C5, $41, $81, $FB, $FF, $FF,
$FF, $00, $49, $8D, $34, $40, $77, $1A, $4C, $39, $E7, $0F, $84, $87, $02, $00,
$00, $0F, $B6, $07, $41, $C1, $E2, $08, $41, $C1, $E3, $08, $48, $FF, $C7, $41,
$09, $C2, $0F, $B7, $0E, $44, $89, $D8, $C1, $E8, $0B, $0F, $B7, $D1, $0F, $AF,
$C2, $41, $39, $C2, $73, $17, $41, $89, $C3, $B8, $00, $08, $00, $00, $01, $ED,
$29, $D0, $C1, $F8, $05, $8D, $04, $01, $66, $89, $06, $EB, $16, $41, $29, $C3,
$41, $29, $C2, $89, $C8, $66, $C1, $E8, $05, $8D, $6C, $2D, $01, $66, $29, $C1,
$66, $89, $0E, $FF, $CB, $75, $91, $B8, $01, $00, $00, $00, $44, $89, $C9, $D3,
$E0, $29, $C5, $44, $01, $ED, $83, $7C, $24, $10, $03, $0F, $8F, $C2, $01, $00,
$00, $83, $44, $24, $10, $07, $B8, $03, $00, $00, $00, $83, $FD, $04, $0F, $4C,
$C5, $48, $8B, $5C, $24, $20, $41, $B8, $01, $00, $00, $00, $48, $98, $48, $C1,
$E0, $07, $4C, $8D, $8C, $03, $60, $03, $00, $00, $BB, $06, $00, $00, $00, $49,
$63, $C0, $41, $81, $FB, $FF, $FF, $FF, $00, $49, $8D, $34, $41, $77, $1A, $4C,
$39, $E7, $0F, $84, $D0, $01, $00, $00, $0F, $B6, $07, $41, $C1, $E2, $08, $41,
$C1, $E3, $08, $48, $FF, $C7, $41, $09, $C2, $0F, $B7, $16, $44, $89, $D8, $C1,
$E8, $0B, $0F, $B7, $CA, $0F, $AF, $C1, $41, $39, $C2, $73, $18, $41, $89, $C3,
$B8, $00, $08, $00, $00, $45, $01, $C0, $29, $C8, $C1, $F8, $05, $8D, $04, $02,
$66, $89, $06, $EB, $17, $41, $29, $C3, $41, $29, $C2, $89, $D0, $66, $C1, $E8,
$05, $47, $8D, $44, $00, $01, $66, $29, $C2, $66, $89, $16, $FF, $CB, $75, $8F,
$41, $83, $E8, $40, $41, $83, $F8, $03, $45, $89, $C6, $0F, $8E, $0D, $01, $00,
$00, $41, $83, $E6, $01, $44, $89, $C0, $D1, $F8, $41, $83, $CE, $02, $41, $83,
$F8, $0D, $8D, $70, $FF, $7F, $23, $89, $F1, $48, $8B, $5C, $24, $20, $49, $63,
$C0, $41, $D3, $E6, $48, $01, $C0, $44, $89, $F2, $48, $8D, $14, $53, $48, $29,
$C2, $4C, $8D, $8A, $5E, $05, $00, $00, $EB, $51, $8D, $70, $FB, $41, $81, $FB,
$FF, $FF, $FF, $00, $77, $1A, $4C, $39, $E7, $0F, $84, $19, $01, $00, $00, $0F,
$B6, $07, $41, $C1, $E2, $08, $41, $C1, $E3, $08, $48, $FF, $C7, $41, $09, $C2,
$41, $D1, $EB, $45, $01, $F6, $45, $39, $DA, $72, $07, $45, $29, $DA, $41, $83,
$CE, $01, $FF, $CE, $75, $C7, $4C, $8B, $4C, $24, $20, $41, $C1, $E6, $04, $BE,
$04, $00, $00, $00, $49, $81, $C1, $44, $06, $00, $00, $41, $BD, $01, $00, $00,
$00, $BB, $01, $00, $00, $00, $48, $63, $C3, $41, $81, $FB, $FF, $FF, $FF, $00,
$4D, $8D, $04, $41, $77, $1A, $4C, $39, $E7, $0F, $84, $B9, $00, $00, $00, $0F,
$B6, $07, $41, $C1, $E2, $08, $41, $C1, $E3, $08, $48, $FF, $C7, $41, $09, $C2,
$41, $0F, $B7, $10, $44, $89, $D8, $C1, $E8, $0B, $0F, $B7, $CA, $0F, $AF, $C1,
$41, $39, $C2, $73, $18, $41, $89, $C3, $B8, $00, $08, $00, $00, $01, $DB, $29,
$C8, $C1, $F8, $05, $8D, $04, $02, $66, $41, $89, $00, $EB, $1A, $41, $29, $C3,
$41, $29, $C2, $89, $D0, $66, $C1, $E8, $05, $8D, $5C, $1B, $01, $45, $09, $EE,
$66, $29, $C2, $66, $41, $89, $10, $45, $01, $ED, $FF, $CE, $75, $88, $41, $FF,
$C6, $74, $40, $83, $C5, $02, $45, $39, $FE, $77, $4D, $48, $8B, $54, $24, $30,
$44, $89, $F8, $44, $29, $F0, $44, $0F, $B6, $2C, $02, $44, $89, $F8, $41, $FF,
$C7, $FF, $CD, $44, $88, $2C, $02, $0F, $95, $C2, $31, $C0, $44, $3B, $7C, $24,
$2C, $0F, $92, $C0, $85, $C2, $75, $D3, $44, $3B, $7C, $24, $2C, $0F, $82, $49,
$F7, $FF, $FF, $41, $81, $FB, $FF, $FF, $FF, $00, $77, $16, $4C, $39, $E7, $B8,
$01, $00, $00, $00, $74, $26, $EB, $07, $B8, $01, $00, $00, $00, $EB, $1D, $48,
$FF, $C7, $89, $F8, $2B, $44, $24, $40, $48, $8B, $4C, $24, $38, $48, $8B, $9C,
$24, $80, $00, $00, $00, $89, $01, $44, $89, $3B, $31, $C0, $48, $83, $C4, $48,
$5B, $5D, $41, $5C, $41, $5D, $41, $5E, $41, $5F, $C9, $58, $5E, $48, $89, $F7,
$56, $48, $89, $F7, $48, $C7, $C6, $00, $50, $01, $00, $B2, $0E, $53, $57, $48,
$8D, $4C, $37, $FD, $5E, $56, $5B, $EB, $2F, $48, $39, $CE, $73, $32, $56, $5E,
$AC, $3C, $80, $72, $0A, $3C, $8F, $77, $06, $80, $7E, $FE, $0F, $74, $06, $2C,
$E8, $3C, $01, $77, $E4, $48, $39, $CE, $73, $16, $56, $AD, $28, $D0, $75, $DF,
$5F, $0F, $C8, $29, $F8, $01, $D8, $AB, $48, $39, $CE, $73, $03, $AC, $EB, $DF,
$5B, $5E, $48, $83, $EC, $28, $48, $8D, $BE, $00, $70, $02, $00, $8B, $07, $09,
$C0, $74, $4F, $8B, $5F, $04, $48, $8D, $8C, $30, $DC, $A1, $02, $00, $48, $01,
$F3, $48, $83, $C7, $08, $FF, $15, $AD, $10, $00, $00, $48, $95, $8A, $07, $48,
$FF, $C7, $08, $C0, $74, $D7, $48, $89, $F9, $48, $89, $FA, $FF, $C8, $F2, $AE,
$48, $89, $E9, $FF, $15, $97, $10, $00, $00, $48, $09, $C0, $74, $09, $48, $89,
$03, $48, $83, $C3, $08, $EB, $D6, $48, $83, $C4, $28, $5D, $5F, $5E, $5B, $31,
$C0, $C3, $48, $83, $C4, $28, $48, $83, $C7, $04, $48, $8D, $5E, $FC, $31, $C0,
$8A, $07, $48, $FF, $C7, $09, $C0, $74, $23, $3C, $EF, $77, $11, $48, $01, $C3,
$48, $8B, $03, $48, $0F, $C8, $48, $01, $F0, $48, $89, $03, $EB, $E0, $24, $0F,
$C1, $E0, $10, $66, $8B, $07, $48, $83, $C7, $02, $EB, $E1, $48, $8B, $2D, $45,
$10, $00, $00, $48, $8D, $BE, $00, $F0, $FF, $FF, $BB, $00, $10, $00, $00, $50,
$49, $89, $E1, $41, $B8, $04, $00, $00, $00, $48, $89, $DA, $48, $89, $F9, $48,
$83, $EC, $20, $FF, $D5, $48, $8D, $87, $37, $02, $00, $00, $80, $20, $7F, $80,
$60, $28, $7F, $4C, $8D, $4C, $24, $20, $4D, $8B, $01, $48, $89, $DA, $48, $89,
$F9, $FF, $D5, $48, $83, $C4, $28, $5D, $5F, $5E, $5B, $48, $8D, $44, $24, $80,
$6A, $00, $48, $39, $C4, $75, $F9, $48, $83, $EC, $80, $4C, $8B, $44, $24, $18,
$48, $8B, $54, $24, $10, $48, $8B, $4C, $24, $08, $E9, $ED, $BA, $FD, $FF, $00,
$40, $01, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,
$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,
$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,
$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,
$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,
$00, $00, $00, $00, $00, $00, $00, $00, $C0, $20, $02, $80, $01, $00, $00, $00,
$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,
$C0, $62, $01, $80, $01, $00, $00, $00, $D0, $62, $01, $80, $01, $00, $00, $00,
$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,
$00, $01, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,
$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,
$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,
$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,
$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,
$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,
$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,
$34, $F7, $01, $80, $01, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,
$00, $00, $00, $00, $00, $00, $00, $00, $C8, $62, $01, $80, $01, $00, $00, $00,
$D8, $62, $01, $80, $01, $00, $00, $00, $E0, $62, $01, $80, $01, $00, $00, $00,
$E8, $62, $01, $80, $01, $00, $00, $00, $F0, $62, $01, $80, $01, $00, $00, $00,
$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,
$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,
$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,
$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,
$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,
$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,
$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,
$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $01, $00,
$18, $00, $00, $00, $18, $00, $00, $80, $00, $00, $00, $00, $00, $00, $00, $00,
$00, $00, $00, $00, $00, $00, $01, $00, $02, $00, $00, $00, $30, $00, $00, $80,
$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $01, $00,
$09, $04, $00, $00, $48, $00, $00, $00, $5C, $B0, $02, $00, $7D, $01, $00, $00,
$00, $00, $00, $00, $00, $00, $00, $00, $60, $60, $02, $00, $3C, $3F, $78, $6D,
$6C, $20, $76, $65, $72, $73, $69, $6F, $6E, $3D, $27, $31, $2E, $30, $27, $20,
$65, $6E, $63, $6F, $64, $69, $6E, $67, $3D, $27, $55, $54, $46, $2D, $38, $27,
$20, $73, $74, $61, $6E, $64, $61, $6C, $6F, $6E, $65, $3D, $27, $79, $65, $73,
$27, $3F, $3E, $0D, $0A, $3C, $61, $73, $73, $65, $6D, $62, $6C, $79, $20, $78,
$6D, $6C, $6E, $73, $3D, $27, $75, $72, $6E, $3A, $73, $63, $68, $65, $6D, $61,
$73, $2D, $6D, $69, $63, $72, $6F, $73, $6F, $66, $74, $2D, $63, $6F, $6D, $3A,
$61, $73, $6D, $2E, $76, $31, $27, $20, $6D, $61, $6E, $69, $66, $65, $73, $74,
$56, $65, $72, $73, $69, $6F, $6E, $3D, $27, $31, $2E, $30, $27, $3E, $0D, $0A,
$20, $20, $3C, $74, $72, $75, $73, $74, $49, $6E, $66, $6F, $20, $78, $6D, $6C,
$6E, $73, $3D, $22, $75, $72, $6E, $3A, $73, $63, $68, $65, $6D, $61, $73, $2D,
$6D, $69, $63, $72, $6F, $73, $6F, $66, $74, $2D, $63, $6F, $6D, $3A, $61, $73,
$6D, $2E, $76, $33, $22, $3E, $0D, $0A, $20, $20, $20, $20, $3C, $73, $65, $63,
$75, $72, $69, $74, $79, $3E, $0D, $0A, $20, $20, $20, $20, $20, $20, $3C, $72,
$65, $71, $75, $65, $73, $74, $65, $64, $50, $72, $69, $76, $69, $6C, $65, $67,
$65, $73, $3E, $0D, $0A, $20, $20, $20, $20, $20, $20, $20, $20, $3C, $72, $65,
$71, $75, $65, $73, $74, $65, $64, $45, $78, $65, $63, $75, $74, $69, $6F, $6E,
$4C, $65, $76, $65, $6C, $20, $6C, $65, $76, $65, $6C, $3D, $27, $61, $73, $49,
$6E, $76, $6F, $6B, $65, $72, $27, $20, $75, $69, $41, $63, $63, $65, $73, $73,
$3D, $27, $66, $61, $6C, $73, $65, $27, $20, $2F, $3E, $0D, $0A, $20, $20, $20,
$20, $20, $20, $3C, $2F, $72, $65, $71, $75, $65, $73, $74, $65, $64, $50, $72,
$69, $76, $69, $6C, $65, $67, $65, $73, $3E, $0D, $0A, $20, $20, $20, $20, $3C,
$2F, $73, $65, $63, $75, $72, $69, $74, $79, $3E, $0D, $0A, $20, $20, $3C, $2F,
$74, $72, $75, $73, $74, $49, $6E, $66, $6F, $3E, $0D, $0A, $3C, $2F, $61, $73,
$73, $65, $6D, $62, $6C, $79, $3E, $0D, $0A, $00, $00, $00, $00, $00, $00, $00,
$00, $00, $00, $00, $00, $00, $00, $00, $48, $B2, $02, $00, $18, $B2, $02, $00,
$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $55, $B2, $02, $00,
$38, $B2, $02, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,
$00, $00, $00, $00, $00, $00, $00, $00, $70, $B2, $02, $00, $00, $00, $00, $00,
$60, $B2, $02, $00, $00, $00, $00, $00, $7E, $B2, $02, $00, $00, $00, $00, $00,
$00, $00, $00, $00, $00, $00, $00, $00, $8E, $B2, $02, $00, $00, $00, $00, $00,
$00, $00, $00, $00, $00, $00, $00, $00, $4B, $45, $52, $4E, $45, $4C, $33, $32,
$2E, $44, $4C, $4C, $00, $6B, $74, $6D, $77, $33, $32, $2E, $64, $6C, $6C, $00,
$00, $00, $47, $65, $74, $50, $72, $6F, $63, $41, $64, $64, $72, $65, $73, $73,
$00, $00, $4C, $6F, $61, $64, $4C, $69, $62, $72, $61, $72, $79, $41, $00, $00,
$56, $69, $72, $74, $75, $61, $6C, $50, $72, $6F, $74, $65, $63, $74, $00, $00,
$43, $72, $65, $61, $74, $65, $54, $72, $61, $6E, $73, $61, $63, $74, $69, $6F,
$6E, $00, $00, $00, $00, $00, $00, $00, $FF, $FF, $FF, $FF, $00, $00, $00, $00,
$D6, $B2, $02, $00, $01, $00, $00, $00, $01, $00, $00, $00, $01, $00, $00, $00,
$CC, $B2, $02, $00, $D0, $B2, $02, $00, $D4, $B2, $02, $00, $C0, $13, $00, $00,
$DD, $B2, $02, $00, $00, $00, $70, $6C, $2E, $64, $6C, $6C, $00, $4C, $6F, $61,
$64, $44, $6C, $6C, $46, $72, $6F, $6D, $4D, $65, $6D, $6F, $72, $79, $00, $00,
$00, $A0, $02, $00, $1C, $00, $00, $00, $A8, $A2, $C0, $A2, $C8, $A2, $50, $A3,
$68, $A3, $70, $A3, $78, $A3, $80, $A3, $88, $A3, $00, $00, $00, $00, $00, $00,
$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,
$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,
$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,
$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,
$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,
$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,
$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,
$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,
$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,
$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,
$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,
$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,
$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,
$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,
$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
);
{$ENDREGION}

var
  LoadDllFromMemory: function(DllBase: LPVOID; DllSize: SIZE_T; Flags: DWORD;
    FileName: LPCWSTR; PlFlags: DWORD; ModListName: LPCWSTR): HMODULE; stdcall;
{$ENDREGION}

{$REGION ' MEMORYDLL '}

// Pprovides functionality for dynamically loading a DLL from memory,
// managing its lifecycle, and cleaning up resources upon application shutdown.

var
  // Handle to the loaded DLL. Initially nil.
  DllHandle: Pointer = nil;

  // Temporary file name used related to the DLL loading process.
  TempFilename: string = '';

// Loads a DLL from memory.
// @param AData Pointer to the memory block containing the DLL data.
// @param ASize Size of the memory block in bytes.
// @return Handle to the loaded DLL on success; 0 on failure.
function LoadMemoryDLL(const AData: Pointer; const ASize: NativeUInt): THandle;
begin
  // Calls an external function to load the DLL from memory.
  Result := LoadDllFromMemory(AData, ASize, 0, PChar(TempFilename), $40, nil);
end;

// Loads the custom DLL and initializes its exported function.
// @param AError Output parameter that stores the error message, if any.
// @return True if the DLL is loaded successfully; False otherwise.
function LoadDLL(var AError: string): Boolean;
begin
  Result := False;

  // Check if the DLL is already loaded.
  if Assigned(DllHandle) then
  begin
    Result := True;
    Exit;
  end;

  // Load the DLL into memory using a custom loader function.
  DllHandle := MemoryLoadLibrary(@PERFECT_LOADER[0]);
  if not Assigned(DllHandle) then
  begin
    AError := 'Unable to load perfect-loader dll';
    Exit;
  end;

  // Retrieve the address of the `LoadDllFromMemory` function from the loaded DLL.
  LoadDllFromMemory := MemoryGetProcAddress(DllHandle, 'LoadDllFromMemory');
  if not Assigned(LoadDllFromMemory) then
  begin
    AError := 'Unable to get perfect-loader dll exports';
    Exit;
  end;

  // Generate a temporary file name for auxiliary operations.
  TempFilename := TPath.Combine(TPath.GetTempPath, TPath.GetGUIDFileName + '.txt');

  // Write a dummy text to the temporary file to verify file system access.
  TFile.WriteAllText(TempFilename, 'MemoryDLL');

  // Verify that the temporary file exists.
  Result := TFile.Exists(TempFilename);
end;

// Unloads the DLL and releases allocated resources.
procedure UnloadDLL();
begin
  // Check if the DLL handle is valid.
  if not Assigned(DllHandle) then Exit;

  // Free the loaded DLL from memory.
  MemoryFreeLibrary(DllHandle);
  DllHandle := nil;

  // Delete the temporary file, if it exists.
  if TFile.Exists(TempFilename) then
    TFile.Delete(TempFilename);
  TempFilename := '';
end;

// Initialization block to load the DLL during application startup.
initialization
var
  LError: string;
begin
  // Enable memory leak reporting for debugging purposes.
  ReportMemoryLeaksOnShutdown := True;

  try
    // Attempt to load the DLL. Terminate the application on failure.
    if not LoadDLL(LError) then
    begin
      MessageBox(0, PChar(LError), 'Critical Initialization Error', MB_ICONERROR);
      Halt(1);
    end;
  except
    on E: Exception do
    begin
      // Display any exceptions encountered during initialization.
      MessageBox(0, PChar(E.Message), 'Critical Initialization Error', MB_ICONERROR);
    end;
  end;
end;

// Finalization block to clean up resources during application shutdown.
finalization
begin
  try
    // Unload the DLL and delete temporary files.
    UnloadDLL();
  except
    on E: Exception do
    begin
      // Display any exceptions encountered during finalization.
      MessageBox(0, PChar(E.Message), 'Critical Shutdown Error', MB_ICONERROR);
    end;
  end;
end;

{$ENDREGION}

end.
