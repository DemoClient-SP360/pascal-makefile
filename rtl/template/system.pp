{
    $Id$
    This file is part of the Free Pascal run time library.
    Copyright (c) 1999-2000 by the Free Pascal development team.

    This is a prototype file to show all function that need to be implemented
    for a new operating system (provided the processor specific
    function are already implemented !)

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}
{ no stack check in system }
{$S-}
unit system;

interface

{ include system-independent routine headers }

{$I systemh.inc}

type
 THandle = longint;


{ include heap support headers }

{$I heaph.inc}

{Platform specific information}
const
 LineEnding = #13#10;
 LFNSupport = true;
 DirectorySeparator = '\';
 DriveSeparator = ':';
 PathSeparator = ';';
 FileNameCaseSensitive = false;

 {The highest exit code which can be returned to the operating system.
  Should be at least 255.}
 maxExitCode = 255;

const
  UnusedHandle    = -1;
  StdInputHandle  = 0;
  StdOutputHandle = 1;
  StdErrorHandle  = 2;

  sLineBreak : string[1] = LineEnding;
  DefaultTextLineBreakStyle : TTextLineBreakStyle = tlbsLF;

var
  argc : longint;
  argv : ppchar;
  envp : ppchar;

implementation

{ include system independent routines }

{$I system.inc}

procedure setup_arguments;
begin
end;

procedure setup_environment;
begin
end;

function GetProcessID: SizeUInt;
begin
end;

{*****************************************************************************
                         System Dependent Exit code
*****************************************************************************}
Procedure system_exit;
begin
end;


{*****************************************************************************
                              ParamStr/Randomize
*****************************************************************************}

{ number of args }
function paramcount : longint;
begin
  {paramcount := argc - 1;}
  paramcount:=0;
end;

{ argument number l }
function paramstr(l : longint) : string;
begin
  {if (l>=0) and (l+1<=argc) then
   paramstr:=strpas(argv[l])
  else}
   paramstr:='';
end;

{ set randseed to a new pseudo random value }
procedure randomize;
begin
  {regs.realeax:=$2c00;
  sysrealintr($21,regs);
  hl:=regs.realedx and $ffff;
  randseed:=hl*$10000+ (regs.realecx and $ffff);}
  randseed:=0;
end;


{*****************************************************************************
      OS Memory allocation / deallocation
 ****************************************************************************}

function SysOSAlloc(size: ptrint): pointer;
begin
  // code to allocate memory block
end;

// If the OS is capable of freeing memory, define HAS_SYSOSFREE and implement
// the SysOSFree function properly
//{$define HAS_SYSOSFREE}
{
procedure SysOSFree(p: pointer; size: ptrint);
begin
  // code to release memory block
end;
}

{ include standard heap management }
{$I heap.inc}


{****************************************************************************
                        Low level File Routines
       All these functions can set InOutRes on errors
 ****************************************************************************}

{ close a file from the handle value }
procedure do_close(handle : longint);
begin
  InOutRes:=1;
end;

procedure do_erase(p : pchar);
begin
  InOutRes:=1;
end;

procedure do_rename(p1,p2 : pchar);
begin
  InOutRes:=1;
end;

function do_write(h,addr,len : longint) : longint;
begin
  InOutRes:=1;
end;

function do_read(h,addr,len : longint) : longint;
begin
  InOutRes:=1;
end;

function do_filepos(handle : longint) : longint;
begin
  InOutRes:=1;
end;

procedure do_seek(handle,pos : longint);
begin
  InOutRes:=1;
end;

function do_seekend(handle:longint):longint;
begin
  InOutRes:=1;
end;

function do_filesize(handle : longint) : longint;
begin
  InOutRes:=1;
end;

{ truncate at a given position }
procedure do_truncate (handle,pos:longint);
begin
  InOutRes:=1;
end;

procedure do_open(var f;p:pchar;flags:longint);
{
  filerec and textrec have both handle and mode as the first items so
  they could use the same routine for opening/creating.
  when (flags and $10)   the file will be append
  when (flags and $100)  the file will be truncate/rewritten
  when (flags and $1000) there is no check for close (needed for textfiles)
}
begin
  InOutRes:=1;
end;

function do_isdevice(handle:longint):boolean;
begin
  do_isdevice:=false;
end;


{*****************************************************************************
                           UnTyped File Handling
*****************************************************************************}

{$i file.inc}

{*****************************************************************************
                           Typed File Handling
*****************************************************************************}

{$i typefile.inc}

{*****************************************************************************
                           Text File Handling
*****************************************************************************}

{ should we consider #26 as the  end of a file ? }
{?? $DEFINE EOF_CTRLZ}

{$i text.inc}

{*****************************************************************************
                           Directory Handling
*****************************************************************************}
procedure mkdir(const s : string);[IOCheck];
begin
  InOutRes:=1;
end;

procedure rmdir(const s : string);[IOCheck];
begin
  InOutRes:=1;
end;

procedure chdir(const s : string);[IOCheck];
begin
  InOutRes:=1;
end;

procedure GetDir (DriveNr: byte; var Dir: ShortString);

begin
  InOutRes := 1;
end;


{*****************************************************************************
                         SystemUnit Initialization
*****************************************************************************}

Begin
  { To be set if this is a GUI or console application }
  IsConsole := TRUE;
  { To be set if this is a library and not a program  }
  IsLibrary := FALSE;
  StackBottom := SPtr - StackLength;
  ExitCode := 0;
{ Setup heap }
  InitHeap;
{ Setup stdin, stdout and stderr }
  OpenStdIO(Input,fmInput,StdInputHandle);
  OpenStdIO(Output,fmOutput,StdOutputHandle);
  OpenStdIO(ErrOutput,fmOutput,StdErrorHandle);
  OpenStdIO(StdOut,fmOutput,StdOutputHandle);
  OpenStdIO(StdErr,fmOutput,StdErrorHandle);
{ Setup environment and arguments }
  Setup_Environment;
  Setup_Arguments;
{ Reset IO Error }
  InOutRes:=0;
(* This should be changed to a real value during *)
(* thread driver initialization if appropriate.  *)
  ThreadID := 1;
End.
{
  $Log$
  Revision 1.15  2004-12-05 14:36:38  hajny
    + GetProcessID added

  Revision 1.14  2004/11/04 09:32:31  peter
  ErrOutput added

  Revision 1.13  2004/10/25 15:38:59  peter
    * compiler defined HEAP and HEAPSIZE removed

  Revision 1.12  2004/09/03 19:26:57  olle
    + added maxExitCode to all System.pp
    * constrained error code to be below maxExitCode in RunError et. al.

  Revision 1.11  2004/06/17 16:16:14  peter
    * New heapmanager that releases memory back to the OS, donated
      by Micha Nelissen

  Revision 1.10  2004/01/20 23:12:49  hajny
    * ExecuteProcess fixes, ProcessID and ThreadID added

  Revision 1.9  2003/09/27 11:52:36  peter
    * sbrk returns pointer

  Revision 1.8  2002/09/07 16:01:27  peter
    * old logs removed and tabs fixed

  Revision 1.7  2002/04/21 15:55:14  carl
  + initialize some global variables

}
