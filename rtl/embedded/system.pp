{
    This file is part of the Free Pascal run time library.
    Copyright (c) 2006 by Florian Klaempfl
    member of the Free Pascal development team.

    System unit for embedded systems

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}

Unit System;

{*****************************************************************************}
                                    interface
{*****************************************************************************}

{$define FPC_IS_SYSTEM}
{$define HAS_CMDLINE}
{$define USE_NOTHREADMANAGER}

{ Do not use standard memory manager }
{$define HAS_MEMORYMANAGER}

{$I check.inc}

{$I systemh.inc}

const
{$ifdef FPC_HAS_FEATURE_TEXTIO}
  LineEnding = #10;
{$endif FPC_HAS_FEATURE_TEXTIO}
{$ifdef FPC_HAS_FEATURE_FILEIO}
  LFNSupport = true;
  DirectorySeparator = '/';
  DriveSeparator = ':';
  ExtensionSeparator = '.';
  PathSeparator = ':';
  AllowDirectorySeparators : set of char = ['\','/'];
  AllowDriveSeparators : set of char = [':'];
{$endif FPC_HAS_FEATURE_FILEIO}

{ FileNameCaseSensitive is defined below! }

{$ifdef FPC_HAS_FEATURE_EXITCODE}
  maxExitCode = 255;
{$endif FPC_HAS_FEATURE_EXITCODE}
{$ifdef FPC_HAS_FEATURE_FILEIO}

  MaxPathLen = 1024; // BSDs since 1993, Solaris 10, Darwin
  AllFilesMask = '*';

  UnusedHandle    = -1;
  StdInputHandle  = 0;
  StdOutputHandle = 1;
  StdErrorHandle  = 2;

  FileNameCaseSensitive : boolean = true;
{$endif FPC_HAS_FEATURE_FILEIO}
{$ifdef FPC_HAS_FEATURE_TEXTIO}
  CtrlZMarksEOF: boolean = false; (* #26 not considered as end of file *)

  sLineBreak = LineEnding;
  DefaultTextLineBreakStyle : TTextLineBreakStyle = tlbsLF;
{$endif FPC_HAS_FEATURE_TEXTIO}

{$ifdef FPC_HAS_FEATURE_COMMANDARGS}
var
  argc: LongInt = 0;
  argv: PPChar = nil;
  envp: PPChar = nil;
  cmdline: PChar = nil;
{$endif FPC_HAS_FEATURE_COMMANDARGS}

{$ifndef FPUNONE}
{$ifdef FPC_HAS_FEATURE_SOFTFPU}

{$define fpc_softfpu_interface}
{$i softfpu.pp}
{$undef fpc_softfpu_interface}

{$endif FPC_HAS_FEATURE_SOFTFPU}
{$endif FPUNONE}

{*****************************************************************************}
                                 implementation
{*****************************************************************************}

{ Include ELF resources }

const calculated_cmdline:Pchar=nil;

{$ifndef FPUNONE}
{$ifdef FPC_HAS_FEATURE_SOFTFPU}

{$define fpc_softfpu_implementation}
{$i softfpu.pp}
{$undef fpc_softfpu_implementation}
{$endif FPUNONE}

{ we get these functions and types from the softfpu code }
{$define FPC_SYSTEM_HAS_float64}
{$define FPC_SYSTEM_HAS_float32}
{$define FPC_SYSTEM_HAS_flag}
{$define FPC_SYSTEM_HAS_extractFloat64Frac0}
{$define FPC_SYSTEM_HAS_extractFloat64Frac1}
{$define FPC_SYSTEM_HAS_extractFloat64Exp}
{$define FPC_SYSTEM_HAS_extractFloat64Frac}
{$define FPC_SYSTEM_HAS_extractFloat64Sign}
{$define FPC_SYSTEM_HAS_ExtractFloat32Frac}
{$define FPC_SYSTEM_HAS_extractFloat32Exp}
{$define FPC_SYSTEM_HAS_extractFloat32Sign}

{$endif FPC_HAS_FEATURE_SOFTFPU}

{$I system.inc}

{*****************************************************************************
                       Misc. System Dependent Functions
*****************************************************************************}

procedure haltproc(e:longint);cdecl;external name '_haltproc';

procedure System_exit;
begin
{$ifdef FPC_HAS_FEATURE_EXITCODE}
  haltproc(ExitCode);
{$else FPC_HAS_FEATURE_EXITCODE}
  haltproc(0);
{$endif FPC_HAS_FEATURE_EXITCODE}
End;


{$ifdef FPC_HAS_FEATURE_PROCESSES}
function GetProcessID: SizeUInt;
begin
  GetProcessID := 0;
end;
{$endif}


{$ifdef FPC_HAS_FEATURE_RANDOM}

Procedure Randomize;
Begin
  RandSeed := 63458; 
End;

{$endif FPC_HAS_FEATURE_RANDOM}


{$ifdef FPC_HAS_FEATURE_COMMANDARGS}

Function ParamCount: Longint;
Begin
  Paramcount:=argc-1
End;


function paramstr(l: longint) : string;
 begin
   if l=0 then
     begin
       paramstr := '';
     end
   else
     paramstr:=strpas(argv[l]);
 end;

{$endif FPC_HAS_FEATURE_COMMANDARGS}


{*****************************************************************************
                         SystemUnit Initialization
*****************************************************************************}

{$ifdef FPC_HAS_FEATURE_STACKCHECK}

function CheckInitialStkLen(stklen : SizeUInt) : SizeUInt;inline;
begin
  result := stklen;
end;

var
  initialstkptr : Pointer; // external name '__stkptr';
{$endif FPC_HAS_FEATURE_STACKCHECK}

begin
{$ifdef FPC_HAS_FEATURE_FPU}
  SysResetFPU;
  if not(IsLibrary) then
    SysInitFPU;
{$endif FPC_HAS_FEATURE_FPU}

{$ifdef FPC_HAS_FEATURE_CONSOLEIO}
  IsConsole := TRUE;
{$endif FPC_HAS_FEATURE_CONSOLEIO}

{$ifdef FPC_HAS_FEATURE_STACKCHECK}
  StackLength := CheckInitialStkLen(initialStkLen);
  StackBottom := initialstkptr - StackLength;
{$endif FPC_HAS_FEATURE_STACKCHECK}

{$ifdef FPC_HAS_FEATURE_EXCEPTIONS}
  SysInitExceptions;
{$endif FPC_HAS_FEATURE_EXCEPTIONS}

{$ifdef FPC_HAS_FEATURE_CONSOLEIO}
  { Reset IO Error }
  InOutRes:=0;
{$endif FPC_HAS_FEATURE_CONSOLEIO}

{$ifdef FPC_HAS_FEATURE_THREADING}
  { threading }
  InitSystemThreads;
{$endif FPC_HAS_FEATURE_THREADING}

{$ifdef FPC_HAS_FEATURE_VARIANTS}
  initvariantmanager;
{$endif FPC_HAS_FEATURE_VARIANTS}

{$ifdef FPC_HAS_FEATURE_WIDESTRINGS}
//  initunicodestringmanager;
{$endif FPC_HAS_FEATURE_WIDESTRINGS}
end.
