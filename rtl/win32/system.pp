{
    $Id$
    This file is part of the Free Pascal run time library.
    Copyright (c) 1999-2000 by Florian Klaempfl and Pavel Ozerski
    member of the Free Pascal development team.

    FPC Pascal system unit for the Win32 API.

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}
{$ifndef VER1_0}
{ $define MT}
{$endif VER1_0}
unit {$ifdef VER1_0}SysWin32{$else}System{$endif};
interface

{$ifdef SYSTEMDEBUG}
  {$define SYSTEMEXCEPTIONDEBUG}
{$endif SYSTEMDEBUG}

{$ifdef cpui386}
  {$define Set_i386_Exception_handler}
{$endif cpui386}

{ include system-independent routine headers }
{$I systemh.inc}

{Platform specific information}
type
{$ifdef CPU64}
  THandle = QWord;
{$else CPU64}
  THandle = DWord;
{$endif CPU64}

const
 LineEnding = #13#10;
 LFNSupport = true;
 DirectorySeparator = '\';
 DriveSeparator = ':';
 PathSeparator = ';';
{ FileNameCaseSensitive is defined separately below!!! }

type
   PEXCEPTION_FRAME = ^TEXCEPTION_FRAME;
   TEXCEPTION_FRAME = record
     next : PEXCEPTION_FRAME;
     handler : pointer;
   end;

{ include heap support headers }
{$I heaph.inc}

const
{ Default filehandles }
  UnusedHandle    : THandle = -1;
  StdInputHandle  : THandle = 0;
  StdOutputHandle : THandle = 0;
  StdErrorHandle  : THandle = 0;

  FileNameCaseSensitive : boolean = true;

  sLineBreak = LineEnding;
  DefaultTextLineBreakStyle : TTextLineBreakStyle = tlbsCRLF;

  { Thread count for DLL }
  Thread_count : longint = 0;
  System_exception_frame : PEXCEPTION_FRAME =nil;

type
  TStartupInfo=packed record
    cb : longint;
    lpReserved : Pointer;
    lpDesktop : Pointer;
    lpTitle : Pointer;
    dwX : longint;
    dwY : longint;
    dwXSize : longint;
    dwYSize : longint;
    dwXCountChars : longint;
    dwYCountChars : longint;
    dwFillAttribute : longint;
    dwFlags : longint;
    wShowWindow : Word;
    cbReserved2 : Word;
    lpReserved2 : Pointer;
    hStdInput : longint;
    hStdOutput : longint;
    hStdError : longint;
  end;

var
{ C compatible arguments }
  argc : longint;
  argv : ppchar;
{ Win32 Info }
  startupinfo : tstartupinfo;
  hprevinst,
  HInstance,
  MainInstance,
  cmdshow     : longint;
  DLLreason,DLLparam:longint;
  Win32StackTop : Dword;

type
  TDLL_Process_Entry_Hook = function (dllparam : longint) : longbool;
  TDLL_Entry_Hook = procedure (dllparam : longint);

const
  Dll_Process_Attach_Hook : TDLL_Process_Entry_Hook = nil;
  Dll_Process_Detach_Hook : TDLL_Entry_Hook = nil;
  Dll_Thread_Attach_Hook : TDLL_Entry_Hook = nil;
  Dll_Thread_Detach_Hook : TDLL_Entry_Hook = nil;

type
  HMODULE = THandle;

implementation

{ include system independent routines }
{$I system.inc}

{ some declarations for Win32 API calls }
{$I win32.inc}


CONST
  { These constants are used for conversion of error codes }
  { from win32 i/o errors to tp i/o errors                 }
  { errors 1 to 18 are the same as in Turbo Pascal         }
  { DO NOT MODIFY UNLESS YOU KNOW EXACTLY WHAT YOU ARE DOING! }

{  The media is write protected.                   }
    ERROR_WRITE_PROTECT       =      19;
{  The system cannot find the device specified.    }
    ERROR_BAD_UNIT            =      20;
{  The device is not ready.                        }
    ERROR_NOT_READY           =      21;
{  The device does not recognize the command.      }
    ERROR_BAD_COMMAND         =      22;
{  Data error (cyclic redundancy check)            }
    ERROR_CRC                 =      23;
{  The program issued a command but the            }
{  command length is incorrect.                    }
    ERROR_BAD_LENGTH           =     24;
{  The drive cannot locate a specific              }
{  area or track on the disk.                      }
    ERROR_SEEK                 =     25;
{  The specified disk or diskette cannot be accessed. }
    ERROR_NOT_DOS_DISK         =     26;
{  The drive cannot find the sector requested.     }
    ERROR_SECTOR_NOT_FOUND      =    27;
{  The printer is out of paper.                    }
    ERROR_OUT_OF_PAPER          =    28;
{  The system cannot write to the specified device. }
    ERROR_WRITE_FAULT           =    29;
{  The system cannot read from the specified device. }
    ERROR_READ_FAULT            =    30;
{  A device attached to the system is not functioning.}
    ERROR_GEN_FAILURE           =    31;
{  The process cannot access the file because         }
{  it is being used by another process.               }
    ERROR_SHARING_VIOLATION      =   32;
{   A pipe has been closed on the other end }
{   Removing that error allows eof to works as on other OSes }
    ERROR_BROKEN_PIPE = 109;
    ERROR_DIR_NOT_EMPTY = 145;
    ERROR_ALREADY_EXISTS = 183;

{$IFDEF SUPPORT_THREADVAR}
threadvar
{$ELSE SUPPORT_THREADVAR}
var
{$ENDIF SUPPORT_THREADVAR}
    errno : longint;

{$ASMMODE ATT}


   { misc. functions }
   function GetLastError : DWORD;
     stdcall;external 'kernel32' name 'GetLastError';

   { time and date functions }
   function GetTickCount : longint;
     stdcall;external 'kernel32' name 'GetTickCount';

   { process functions }
   procedure ExitProcess(uExitCode : UINT);
     stdcall;external 'kernel32' name 'ExitProcess';


   Procedure Errno2InOutRes;
   Begin
     { DO NOT MODIFY UNLESS YOU KNOW EXACTLY WHAT YOU ARE DOING }
     case Errno of
       ERROR_WRITE_PROTECT..ERROR_GEN_FAILURE :
         begin
           { This is the offset to the Win32 to add to directly map  }
           { to the DOS/TP compatible error codes when in this range }
           InOutRes := word(errno)+131;
         end;
       ERROR_DIR_NOT_EMPTY,
       ERROR_ALREADY_EXISTS,
       ERROR_SHARING_VIOLATION :
         begin
           InOutRes :=5;
         end;
       else
         begin
           { other error codes can directly be mapped }
           InOutRes := Word(errno);
         end;
     end;
     errno:=0;
   end;


function paramcount : longint;
begin
  paramcount := argc - 1;
end;

   { module functions }
   function GetModuleFileName(l1:longint;p:pointer;l2:longint):longint;
     stdcall;external 'kernel32' name 'GetModuleFileNameA';
   function GetModuleHandle(p : pointer) : longint;
     stdcall;external 'kernel32' name 'GetModuleHandleA';
   function GetCommandFile:pchar;forward;

function paramstr(l : longint) : string;
begin
  if (l>=0) and (l<argc) then
    paramstr:=strpas(argv[l])
  else
    paramstr:='';
end;


procedure randomize;
begin
  randseed:=GetTickCount;
end;


{*****************************************************************************
                              Heap Management
*****************************************************************************}
   { memory functions }
   function GetProcessHeap : DWord;
     stdcall;external 'kernel32' name 'GetProcessHeap';
   function HeapAlloc(hHeap : DWord; dwFlags : DWord; dwBytes : DWord) : Longint;
     stdcall;external 'kernel32' name 'HeapAlloc';
   function HeapFree(hHeap : dword; dwFlags : dword; lpMem: pointer) : boolean;
     stdcall;external 'kernel32' name 'HeapFree';
{$IFDEF SYSTEMDEBUG}
   function WinAPIHeapSize(hHeap : DWord; dwFlags : DWord; ptr : Pointer) : DWord;
     stdcall;external 'kernel32' name 'HeapSize';
{$ENDIF}

var
  heap : longint;external name 'HEAP';
  intern_heapsize : longint;external name 'HEAPSIZE';

function getheapstart:pointer;
assembler;
asm
        leal    HEAP,%eax
end ['EAX'];


function getheapsize:longint;
assembler;
asm
        movl    intern_HEAPSIZE,%eax
end ['EAX'];

{*****************************************************************************
      OS Memory allocation / deallocation
 ****************************************************************************}

function SysOSAlloc(size: ptrint): pointer;
var
  l : longword;
begin
  l := HeapAlloc(GetProcessHeap, 0, size);
{$ifdef DUMPGROW}
  Writeln('new heap part at $',hexstr(l,8), ' size = ',WinAPIHeapSize(GetProcessHeap()));
{$endif}
  SysOSAlloc := pointer(l);
end;

{$define HAS_SYSOSFREE}

procedure SysOSFree(p: pointer; size: ptrint);
begin
  HeapFree(GetProcessHeap, 0, p);
end;


{ include standard heap management }
{$I heap.inc}


{*****************************************************************************
                          Low Level File Routines
*****************************************************************************}

   function WriteFile(fh:thandle;buf:pointer;len:longint;var loaded:longint;
     overlap:pointer):longint;
     stdcall;external 'kernel32' name 'WriteFile';
   function ReadFile(fh:thandle;buf:pointer;len:longint;var loaded:longint;
     overlap:pointer):longint;
     stdcall;external 'kernel32' name 'ReadFile';
   function CloseHandle(h : thandle) : longint;
     stdcall;external 'kernel32' name 'CloseHandle';
   function DeleteFile(p : pchar) : longint;
     stdcall;external 'kernel32' name 'DeleteFileA';
   function MoveFile(old,_new : pchar) : longint;
     stdcall;external 'kernel32' name 'MoveFileA';
   function SetFilePointer(l1,l2 : thandle;l3 : pointer;l4 : longint) : longint;
     stdcall;external 'kernel32' name 'SetFilePointer';
   function GetFileSize(h:thandle;p:pointer) : longint;
     stdcall;external 'kernel32' name 'GetFileSize';
   function CreateFile(lpFileName:pchar; dwDesiredAccess:DWORD; dwShareMode:DWORD;
                       lpSecurityAttributes:PSECURITYATTRIBUTES; dwCreationDisposition:DWORD;
                       dwFlagsAndAttributes:DWORD; hTemplateFile:DWORD):longint;
     stdcall;external 'kernel32' name 'CreateFileA';
   function SetEndOfFile(h : thandle) : longbool;
     stdcall;external 'kernel32' name 'SetEndOfFile';
   function GetFileType(Handle:thandle):DWord;
     stdcall;external 'kernel32' name 'GetFileType';
   function GetFileAttributes(p : pchar) : dword;
     stdcall;external 'kernel32' name 'GetFileAttributesA';

procedure AllowSlash(p:pchar);
var
   i : longint;
begin
{ allow slash as backslash }
   for i:=0 to strlen(p) do
     if p[i]='/' then p[i]:='\';
end;

function do_isdevice(handle:thandle):boolean;
begin
  do_isdevice:=(getfiletype(handle)=2);
end;


procedure do_close(h : thandle);
begin
  if do_isdevice(h) then
   exit;
  CloseHandle(h);
end;


procedure do_erase(p : pchar);
begin
   AllowSlash(p);
   if DeleteFile(p)=0 then
    Begin
      errno:=GetLastError;
      if errno=5 then
       begin
         if (GetFileAttributes(p)=FILE_ATTRIBUTE_DIRECTORY) then
          errno:=2;
       end;
      Errno2InoutRes;
    end;
end;


procedure do_rename(p1,p2 : pchar);
begin
  AllowSlash(p1);
  AllowSlash(p2);
  if MoveFile(p1,p2)=0 then
   Begin
      errno:=GetLastError;
      Errno2InoutRes;
   end;
end;


function do_write(h:thandle;addr:pointer;len : longint) : longint;
var
   size:longint;
begin
   if writefile(h,addr,len,size,nil)=0 then
    Begin
      errno:=GetLastError;
      Errno2InoutRes;
    end;
   do_write:=size;
end;


function do_read(h:thandle;addr:pointer;len : longint) : longint;
var
  _result:longint;
begin
  if readfile(h,addr,len,_result,nil)=0 then
    Begin
      errno:=GetLastError;
      if errno=ERROR_BROKEN_PIPE then
        errno:=0
      else
        Errno2InoutRes;
    end;
  do_read:=_result;
end;


function do_filepos(handle : thandle) : longint;
var
  l:longint;
begin
  l:=SetFilePointer(handle,0,nil,FILE_CURRENT);
  if l=-1 then
   begin
    l:=0;
    errno:=GetLastError;
    Errno2InoutRes;
   end;
  do_filepos:=l;
end;


procedure do_seek(handle:thandle;pos : longint);
begin
  if SetFilePointer(handle,pos,nil,FILE_BEGIN)=-1 then
   Begin
    errno:=GetLastError;
    Errno2InoutRes;
   end;
end;


function do_seekend(handle:thandle):longint;
begin
  do_seekend:=SetFilePointer(handle,0,nil,FILE_END);
  if do_seekend=-1 then
    begin
      errno:=GetLastError;
      Errno2InoutRes;
    end;
end;


function do_filesize(handle : thandle) : longint;
var
  aktfilepos : longint;
begin
  aktfilepos:=do_filepos(handle);
  do_filesize:=do_seekend(handle);
  do_seek(handle,aktfilepos);
end;


procedure do_truncate (handle:thandle;pos:longint);
begin
   do_seek(handle,pos);
   if not(SetEndOfFile(handle)) then
    begin
      errno:=GetLastError;
      Errno2InoutRes;
    end;
end;


procedure do_open(var f;p:pchar;flags:longint);
{
  filerec and textrec have both handle and mode as the first items so
  they could use the same routine for opening/creating.
  when (flags and $100)   the file will be append
  when (flags and $1000)  the file will be truncate/rewritten
  when (flags and $10000) there is no check for close (needed for textfiles)
}
Const
  file_Share_Read  = $00000001;
  file_Share_Write = $00000002;
Var
  shflags,
  oflags,cd : longint;
  security : TSecurityAttributes;
begin
  AllowSlash(p);
{ close first if opened }
  if ((flags and $10000)=0) then
   begin
     case filerec(f).mode of
       fminput,fmoutput,fminout : Do_Close(filerec(f).handle);
       fmclosed : ;
     else
      begin
        {not assigned}
        inoutres:=102;
        exit;
      end;
     end;
   end;
{ reset file handle }
  filerec(f).handle:=UnusedHandle;
{ convert filesharing }
  shflags:=0;
  if ((filemode and fmshareExclusive) = fmshareExclusive) then
    { no sharing }
  else
    if (filemode = fmShareCompat) or ((filemode and fmshareDenyWrite) = fmshareDenyWrite) then
      shflags := file_Share_Read
  else
    if ((filemode and fmshareDenyRead) = fmshareDenyRead) then
      shflags := file_Share_Write
  else
    if ((filemode and fmshareDenyNone) = fmshareDenyNone) then
      shflags := file_Share_Read + file_Share_Write;
{ convert filemode to filerec modes }
  case (flags and 3) of
   0 : begin
         filerec(f).mode:=fminput;
         oflags:=longint(GENERIC_READ);
       end;
   1 : begin
         filerec(f).mode:=fmoutput;
         oflags:=longint(GENERIC_WRITE);
       end;
   2 : begin
         filerec(f).mode:=fminout;
         oflags:=longint(GENERIC_WRITE or GENERIC_READ);
       end;
  end;
{ create it ? }
  if (flags and $1000)<>0 then
   cd:=CREATE_ALWAYS
{ or Append/Open ? }
  else
    cd:=OPEN_EXISTING;
{ empty name is special }
  if p[0]=#0 then
   begin
     case FileRec(f).mode of
       fminput :
         FileRec(f).Handle:=StdInputHandle;
       fminout, { this is set by rewrite }
       fmoutput :
         FileRec(f).Handle:=StdOutputHandle;
       fmappend :
         begin
           FileRec(f).Handle:=StdOutputHandle;
           FileRec(f).mode:=fmoutput; {fool fmappend}
         end;
     end;
     exit;
   end;
  security.nLength := Sizeof(TSecurityAttributes);
  security.bInheritHandle:=true;
  security.lpSecurityDescriptor:=nil;
  filerec(f).handle:=CreateFile(p,oflags,shflags,@security,cd,FILE_ATTRIBUTE_NORMAL,0);
{ append mode }
  if ((flags and $100)<>0) and
     (filerec(f).handle<>0) and
     (filerec(f).handle<>UnusedHandle) then
   begin
     do_seekend(filerec(f).handle);
     filerec(f).mode:=fmoutput; {fool fmappend}
   end;
{ get errors }
  { handle -1 is returned sometimes !! (PM) }
  if (filerec(f).handle=0) or (filerec(f).handle=UnusedHandle) then
    begin
      errno:=GetLastError;
      Errno2InoutRes;
    end;
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

{$DEFINE EOF_CTRLZ}

{$i text.inc}

{*****************************************************************************
                           Directory Handling
*****************************************************************************}

   function CreateDirectory(name : pointer;sec : pointer) : longbool;
     stdcall;external 'kernel32' name 'CreateDirectoryA';
   function RemoveDirectory(name:pointer):longbool;
     stdcall;external 'kernel32' name 'RemoveDirectoryA';
   function SetCurrentDirectory(name : pointer) : longbool;
     stdcall;external 'kernel32' name 'SetCurrentDirectoryA';
   function GetCurrentDirectory(bufsize : longint;name : pchar) : longbool;
     stdcall;external 'kernel32' name 'GetCurrentDirectoryA';

type
 TDirFnType=function(name:pointer):longbool;stdcall;

procedure dirfn(afunc : TDirFnType;const s:string);
var
  buffer : array[0..255] of char;
begin
  move(s[1],buffer,length(s));
  buffer[length(s)]:=#0;
  AllowSlash(pchar(@buffer));
  if not aFunc(@buffer) then
    begin
      errno:=GetLastError;
      Errno2InoutRes;
    end;
end;

function CreateDirectoryTrunc(name:pointer):longbool;stdcall;
begin
  CreateDirectoryTrunc:=CreateDirectory(name,nil);
end;

procedure mkdir(const s:string);[IOCHECK];
begin
  If (s='') or (InOutRes <> 0) then
   exit;
  dirfn(TDirFnType(@CreateDirectoryTrunc),s);
end;

procedure rmdir(const s:string);[IOCHECK];
begin
  if (s ='.') then
    InOutRes := 16;
  If (s='') or (InOutRes <> 0) then
   exit;
  dirfn(TDirFnType(@RemoveDirectory),s);
end;

procedure chdir(const s:string);[IOCHECK];
begin
  If (s='') or (InOutRes <> 0) then
   exit;
  dirfn(TDirFnType(@SetCurrentDirectory),s);
  if Inoutres=2 then
   Inoutres:=3;
end;

procedure GetDir (DriveNr: byte; var Dir: ShortString);
const
  Drive:array[0..3]of char=(#0,':',#0,#0);
var
  defaultdrive:boolean;
  DirBuf,SaveBuf:array[0..259] of Char;
begin
  defaultdrive:=drivenr=0;
  if not defaultdrive then
   begin
    byte(Drive[0]):=Drivenr+64;
    GetCurrentDirectory(SizeOf(SaveBuf),SaveBuf);
    if not SetCurrentDirectory(@Drive) then
     begin
      errno := word (GetLastError);
      Errno2InoutRes;
      Dir := char (DriveNr + 64) + ':\';
      SetCurrentDirectory(@SaveBuf);
      Exit;
     end;
   end;
  GetCurrentDirectory(SizeOf(DirBuf),DirBuf);
  if not defaultdrive then
   SetCurrentDirectory(@SaveBuf);
  dir:=strpas(DirBuf);
  if not FileNameCaseSensitive then
   dir:=upcase(dir);
end;

{*****************************************************************************
                         SystemUnit Initialization
*****************************************************************************}

   { Startup }
   procedure GetStartupInfo(p : pointer);
     stdcall;external 'kernel32' name 'GetStartupInfoA';
   function GetStdHandle(nStdHandle:DWORD):THANDLE;
     stdcall;external 'kernel32' name 'GetStdHandle';

   { command line/enviroment functions }
   function GetCommandLine : pchar;
     stdcall;external 'kernel32' name 'GetCommandLineA';

   function GetCurrentThread : dword;
     stdcall; external 'kernel32' name 'GetCurrentThread';


var
  ModuleName : array[0..255] of char;

function GetCommandFile:pchar;
begin
  GetModuleFileName(0,@ModuleName,255);
  GetCommandFile:=@ModuleName;
end;


procedure setup_arguments;
var
  arglen,
  count   : longint;
  argstart,
  pc,arg  : pchar;
  quote   : char;
  argvlen : longint;

  procedure allocarg(idx,len:longint);
    begin
      if idx>=argvlen then
       begin
         argvlen:=(idx+8) and (not 7);
         sysreallocmem(argv,argvlen*sizeof(pointer));
       end;
      { use realloc to reuse already existing memory }
      { always allocate, even if length is zero, since }
      { the arg. is still present!                     }
      sysreallocmem(argv[idx],len+1);
    end;

begin
  { create commandline, it starts with the executed filename which is argv[0] }
  { Win32 passes the command NOT via the args, but via getmodulefilename}
  count:=0;
  argv:=nil;
  argvlen:=0;
  pc:=getcommandfile;
  Arglen:=0;
  repeat
    Inc(Arglen);
  until (pc[Arglen]=#0);
  allocarg(count,arglen);
  move(pc^,argv[count]^,arglen);
  { Setup cmdline variable }
  cmdline:=GetCommandLine;
  { process arguments }
  pc:=cmdline;
{$IfDef SYSTEM_DEBUG_STARTUP}
  Writeln(stderr,'Win32 GetCommandLine is #',pc,'#');
{$EndIf }
  while pc^<>#0 do
   begin
     { skip leading spaces }
     while pc^ in [#1..#32] do
      inc(pc);
     if pc^=#0 then
      break;
     { calc argument length }
     quote:=' ';
     argstart:=pc;
     arglen:=0;
     while (pc^<>#0) do
      begin
        case pc^ of
          #1..#32 :
            begin
              if quote<>' ' then
               inc(arglen)
              else
               break;
            end;
          '"' :
            begin
              if quote<>'''' then
               begin
                 if pchar(pc+1)^<>'"' then
                  begin
                    if quote='"' then
                     quote:=' '
                    else
                     quote:='"';
                  end
                 else
                  inc(pc);
               end
              else
               inc(arglen);
            end;
          '''' :
            begin
              if quote<>'"' then
               begin
                 if pchar(pc+1)^<>'''' then
                  begin
                    if quote=''''  then
                     quote:=' '
                    else
                     quote:='''';
                  end
                 else
                  inc(pc);
               end
              else
               inc(arglen);
            end;
          else
            inc(arglen);
        end;
        inc(pc);
      end;
     { copy argument }
     { Don't copy the first one, it is already there.}
     If Count<>0 then
      begin
        allocarg(count,arglen);
        quote:=' ';
        pc:=argstart;
        arg:=argv[count];
        while (pc^<>#0) do
         begin
           case pc^ of
             #1..#32 :
               begin
                 if quote<>' ' then
                  begin
                    arg^:=pc^;
                    inc(arg);
                  end
                 else
                  break;
               end;
             '"' :
               begin
                 if quote<>'''' then
                  begin
                    if pchar(pc+1)^<>'"' then
                     begin
                       if quote='"' then
                        quote:=' '
                       else
                        quote:='"';
                     end
                    else
                     inc(pc);
                  end
                 else
                  begin
                    arg^:=pc^;
                    inc(arg);
                  end;
               end;
             '''' :
               begin
                 if quote<>'"' then
                  begin
                    if pchar(pc+1)^<>'''' then
                     begin
                       if quote=''''  then
                        quote:=' '
                       else
                        quote:='''';
                     end
                    else
                     inc(pc);
                  end
                 else
                  begin
                    arg^:=pc^;
                    inc(arg);
                  end;
               end;
             else
               begin
                 arg^:=pc^;
                 inc(arg);
               end;
           end;
           inc(pc);
         end;
        arg^:=#0;
      end;
 {$IfDef SYSTEM_DEBUG_STARTUP}
     Writeln(stderr,'dos arg ',count,' #',arglen,'#',argv[count],'#');
 {$EndIf SYSTEM_DEBUG_STARTUP}
     inc(count);
   end;
  { get argc and create an nil entry }
  argc:=count;
  allocarg(argc,0);
  { free unused memory }
  sysreallocmem(argv,(argc+1)*sizeof(pointer));
end;


{*****************************************************************************
                         System Dependent Exit code
*****************************************************************************}

  procedure install_exception_handlers;forward;
  procedure remove_exception_handlers;forward;
  procedure PascalMain;stdcall;external name 'PASCALMAIN';
  procedure fpc_do_exit;stdcall;external name 'FPC_DO_EXIT';
  Procedure ExitDLL(Exitcode : longint); forward;
  procedure asm_exit; stdcall;external name 'asm_exit';

Procedure system_exit;
begin
  { don't call ExitProcess inside
    the DLL exit code !!
    This crashes Win95 at least PM }
  if IsLibrary then
    ExitDLL(ExitCode);
  if not IsConsole then
   begin
     Close(stderr);
     Close(stdout);
     { what about Input and Output ?? PM }
   end;
  remove_exception_handlers;
  { call exitprocess, with cleanup as required }
  asm
    xorl %eax, %eax
    movw exitcode,%ax
    call asm_exit
  end;
end;

var
  { value of the stack segment
    to check if the call stack can be written on exceptions }
  _SS : Cardinal;

procedure Exe_entry;[public, alias : '_FPC_EXE_Entry'];
  begin
     IsLibrary:=false;
     { install the handlers for exe only ?
       or should we install them for DLL also ? (PM) }
     install_exception_handlers;
     { This strange construction is needed to solve the _SS problem
       with a smartlinked syswin32 (PFV) }
     asm
         { allocate space for an exception frame }
        pushl $0
        pushl %fs:(0)
        { movl  %esp,%fs:(0)
          but don't insert it as it doesn't
          point to anything yet
          this will be used in signals unit }
        movl %esp,%eax
        movl %eax,System_exception_frame
        pushl %ebp
        xorl %ebp,%ebp
        movl %esp,%eax
        movl %eax,Win32StackTop
        movw %ss,%bp
        movl %ebp,_SS
        call SysResetFPU
        xorl %ebp,%ebp
        call PASCALMAIN
        popl %ebp
     end;
     { if we pass here there was no error ! }
     system_exit;
  end;

Const
  { DllEntryPoint  }
     DLL_PROCESS_ATTACH = 1;
     DLL_THREAD_ATTACH = 2;
     DLL_PROCESS_DETACH = 0;
     DLL_THREAD_DETACH = 3;
Var
     DLLBuf : Jmp_buf;
Const
     DLLExitOK : boolean = true;

function Dll_entry : longbool;[public, alias : '_FPC_DLL_Entry'];
var
  res : longbool;

  begin
     IsLibrary:=true;
     Dll_entry:=false;
     case DLLreason of
       DLL_PROCESS_ATTACH :
         begin
           If SetJmp(DLLBuf) = 0 then
             begin
               if assigned(Dll_Process_Attach_Hook) then
                 begin
                   res:=Dll_Process_Attach_Hook(DllParam);
                   if not res then
                     exit(false);
                 end;
               PASCALMAIN;
               Dll_entry:=true;
             end
           else
             Dll_entry:=DLLExitOK;
         end;
       DLL_THREAD_ATTACH :
         begin
           inc(Thread_count);
{$warning Allocate Threadvars !}
           if assigned(Dll_Thread_Attach_Hook) then
             Dll_Thread_Attach_Hook(DllParam);
           Dll_entry:=true; { return value is ignored }
         end;
       DLL_THREAD_DETACH :
         begin
           dec(Thread_count);
           if assigned(Dll_Thread_Detach_Hook) then
             Dll_Thread_Detach_Hook(DllParam);
{$warning Release Threadvars !}
           Dll_entry:=true; { return value is ignored }
         end;
       DLL_PROCESS_DETACH :
         begin
           Dll_entry:=true; { return value is ignored }
           If SetJmp(DLLBuf) = 0 then
             begin
               FPC_DO_EXIT;
             end;
           if assigned(Dll_Process_Detach_Hook) then
             Dll_Process_Detach_Hook(DllParam);
         end;
     end;
  end;

Procedure ExitDLL(Exitcode : longint);
begin
    DLLExitOK:=ExitCode=0;
    LongJmp(DLLBuf,1);
end;

function GetCurrentProcess : dword;
 stdcall;external 'kernel32' name 'GetCurrentProcess';

function ReadProcessMemory(process : dword;address : pointer;dest : pointer;size : dword;bytesread : pdword) :  longbool;
 stdcall;external 'kernel32' name 'ReadProcessMemory';

function is_prefetch(p : pointer) : boolean;
  var
    a : array[0..15] of byte;
    doagain : boolean;
    instrlo,instrhi,opcode : byte;
    i : longint;
  begin
    result:=false;
    { read memory savely without causing another exeception }
    if not(ReadProcessMemory(GetCurrentProcess,p,@a,sizeof(a),nil)) then
      exit;
    i:=0;
    doagain:=true;
    while doagain and (i<15) do
      begin
        opcode:=a[i];
        instrlo:=opcode and $f;
        instrhi:=opcode and $f0;
        case instrhi of
          { prefix? }
          $20,$30:
            doagain:=(instrlo and 7)=6;
          $60:
            doagain:=(instrlo and $c)=4;
          $f0:
            doagain:=instrlo in [0,2,3];
          $0:
            begin
              result:=(instrlo=$f) and (a[i+1] in [$d,$18]);
              exit;
            end;
          else
            doagain:=false;
        end;
        inc(i);
      end;
  end;


//
// Hardware exception handling
//

{$ifdef Set_i386_Exception_handler}

{
  Error code definitions for the Win32 API functions


  Values are 32 bit values layed out as follows:
   3 3 2 2 2 2 2 2 2 2 2 2 1 1 1 1 1 1 1 1 1 1
   1 0 9 8 7 6 5 4 3 2 1 0 9 8 7 6 5 4 3 2 1 0 9 8 7 6 5 4 3 2 1 0
  +---+-+-+-----------------------+-------------------------------+
  |Sev|C|R|     Facility          |               Code            |
  +---+-+-+-----------------------+-------------------------------+

  where
      Sev - is the severity code
          00 - Success
          01 - Informational
          10 - Warning
          11 - Error

      C - is the Customer code flag
      R - is a reserved bit
      Facility - is the facility code
      Code - is the facility's status code
}

const
        SEVERITY_SUCCESS                = $00000000;
        SEVERITY_INFORMATIONAL  = $40000000;
        SEVERITY_WARNING                = $80000000;
        SEVERITY_ERROR                  = $C0000000;

const
        STATUS_SEGMENT_NOTIFICATION             = $40000005;
        DBG_TERMINATE_THREAD                    = $40010003;
        DBG_TERMINATE_PROCESS                   = $40010004;
        DBG_CONTROL_C                                   = $40010005;
        DBG_CONTROL_BREAK                               = $40010008;

        STATUS_GUARD_PAGE_VIOLATION             = $80000001;
        STATUS_DATATYPE_MISALIGNMENT    = $80000002;
        STATUS_BREAKPOINT                               = $80000003;
        STATUS_SINGLE_STEP                              = $80000004;
        DBG_EXCEPTION_NOT_HANDLED               = $80010001;

        STATUS_ACCESS_VIOLATION                 = $C0000005;
        STATUS_IN_PAGE_ERROR                    = $C0000006;
        STATUS_INVALID_HANDLE                   = $C0000008;
        STATUS_NO_MEMORY                                = $C0000017;
        STATUS_ILLEGAL_INSTRUCTION              = $C000001D;
        STATUS_NONCONTINUABLE_EXCEPTION = $C0000025;
        STATUS_INVALID_DISPOSITION              = $C0000026;
        STATUS_ARRAY_BOUNDS_EXCEEDED    = $C000008C;
        STATUS_FLOAT_DENORMAL_OPERAND   = $C000008D;
        STATUS_FLOAT_DIVIDE_BY_ZERO             = $C000008E;
        STATUS_FLOAT_INEXACT_RESULT             = $C000008F;
        STATUS_FLOAT_INVALID_OPERATION  = $C0000090;
        STATUS_FLOAT_OVERFLOW                   = $C0000091;
        STATUS_FLOAT_STACK_CHECK                = $C0000092;
        STATUS_FLOAT_UNDERFLOW                  = $C0000093;
        STATUS_INTEGER_DIVIDE_BY_ZERO   = $C0000094;
        STATUS_INTEGER_OVERFLOW                 = $C0000095;
        STATUS_PRIVILEGED_INSTRUCTION   = $C0000096;
        STATUS_STACK_OVERFLOW                   = $C00000FD;
        STATUS_CONTROL_C_EXIT                   = $C000013A;
        STATUS_FLOAT_MULTIPLE_FAULTS    = $C00002B4;
        STATUS_FLOAT_MULTIPLE_TRAPS             = $C00002B5;
        STATUS_REG_NAT_CONSUMPTION              = $C00002C9;

        EXCEPTION_EXECUTE_HANDLER               = 1;
        EXCEPTION_CONTINUE_EXECUTION    = -1;
        EXCEPTION_CONTINUE_SEARCH               = 0;

        EXCEPTION_MAXIMUM_PARAMETERS    = 15;

        CONTEXT_X86                                     = $00010000;
        CONTEXT_CONTROL                         = CONTEXT_X86 or $00000001;
        CONTEXT_INTEGER                         = CONTEXT_X86 or $00000002;
        CONTEXT_SEGMENTS                        = CONTEXT_X86 or $00000004;
        CONTEXT_FLOATING_POINT          = CONTEXT_X86 or $00000008;
        CONTEXT_DEBUG_REGISTERS         = CONTEXT_X86 or $00000010;
        CONTEXT_EXTENDED_REGISTERS      = CONTEXT_X86 or $00000020;

        CONTEXT_FULL                            = CONTEXT_CONTROL or CONTEXT_INTEGER or CONTEXT_SEGMENTS;

        MAXIMUM_SUPPORTED_EXTENSION     = 512;

type
        PFloatingSaveArea = ^TFloatingSaveArea;
        TFloatingSaveArea = packed record
                ControlWord : Cardinal;
                StatusWord : Cardinal;
                TagWord : Cardinal;
                ErrorOffset : Cardinal;
                ErrorSelector : Cardinal;
                DataOffset : Cardinal;
                DataSelector : Cardinal;
                RegisterArea : array[0..79] of Byte;
                Cr0NpxState : Cardinal;
        end;

        PContext = ^TContext;
        TContext = packed record
            //
            // The flags values within this flag control the contents of
            // a CONTEXT record.
            //
                ContextFlags : Cardinal;

            //
            // This section is specified/returned if CONTEXT_DEBUG_REGISTERS is
            // set in ContextFlags.  Note that CONTEXT_DEBUG_REGISTERS is NOT
            // included in CONTEXT_FULL.
            //
                Dr0, Dr1, Dr2,
                Dr3, Dr6, Dr7 : Cardinal;

            //
            // This section is specified/returned if the
            // ContextFlags word contains the flag CONTEXT_FLOATING_POINT.
            //
                FloatSave : TFloatingSaveArea;

            //
            // This section is specified/returned if the
            // ContextFlags word contains the flag CONTEXT_SEGMENTS.
            //
                SegGs, SegFs,
                SegEs, SegDs : Cardinal;

            //
            // This section is specified/returned if the
            // ContextFlags word contains the flag CONTEXT_INTEGER.
            //
                Edi, Esi, Ebx,
                Edx, Ecx, Eax : Cardinal;

            //
            // This section is specified/returned if the
            // ContextFlags word contains the flag CONTEXT_CONTROL.
            //
                Ebp : Cardinal;
                Eip : Cardinal;
                SegCs : Cardinal;
                EFlags, Esp, SegSs : Cardinal;

            //
            // This section is specified/returned if the ContextFlags word
            // contains the flag CONTEXT_EXTENDED_REGISTERS.
            // The format and contexts are processor specific
            //
                ExtendedRegisters : array[0..MAXIMUM_SUPPORTED_EXTENSION-1] of Byte;
        end;

type
        PExceptionRecord = ^TExceptionRecord;
        TExceptionRecord = packed record
                ExceptionCode   : Longint;
                ExceptionFlags  : Longint;
                ExceptionRecord : PExceptionRecord;
                ExceptionAddress : Pointer;
                NumberParameters : Longint;
                ExceptionInformation : array[0..EXCEPTION_MAXIMUM_PARAMETERS-1] of Pointer;
        end;

        PExceptionPointers = ^TExceptionPointers;
        TExceptionPointers = packed record
                ExceptionRecord   : PExceptionRecord;
                ContextRecord     : PContext;
        end;

     { type of functions that should be used for exception handling }
        TTopLevelExceptionFilter = function (excep : PExceptionPointers) : Longint;stdcall;

function SetUnhandledExceptionFilter(lpTopLevelExceptionFilter : TTopLevelExceptionFilter) : TTopLevelExceptionFilter;
        stdcall;external 'kernel32' name 'SetUnhandledExceptionFilter';

const
        MaxExceptionLevel = 16;
        exceptLevel : Byte = 0;

var
        exceptEip       : array[0..MaxExceptionLevel-1] of Longint;
        exceptError     : array[0..MaxExceptionLevel-1] of Byte;
        resetFPU        : array[0..MaxExceptionLevel-1] of Boolean;

{$ifdef SYSTEMEXCEPTIONDEBUG}
procedure DebugHandleErrorAddrFrame(error, addr, frame : longint);
begin
        if IsConsole then begin
                write(stderr,'HandleErrorAddrFrame(error=',error);
                write(stderr,',addr=',hexstr(addr,8));
                writeln(stderr,',frame=',hexstr(frame,8),')');
        end;
        HandleErrorAddrFrame(error,addr,frame);
end;
{$endif SYSTEMEXCEPTIONDEBUG}

procedure JumpToHandleErrorFrame;
var
        eip, ebp, error : Longint;
begin
        // save ebp
        asm
                movl (%ebp),%eax
                movl %eax,ebp
        end;
        if (exceptLevel > 0) then
                dec(exceptLevel);

        eip:=exceptEip[exceptLevel];
        error:=exceptError[exceptLevel];
{$ifdef SYSTEMEXCEPTIONDEBUG}
        if IsConsole then
          writeln(stderr,'In JumpToHandleErrorFrame error=',error);
{$endif SYSTEMEXCEPTIONDEBUG}
        if resetFPU[exceptLevel] then asm
                fninit
                fldcw   fpucw
        end;
        { build a fake stack }
        asm
{$ifdef REGCALL}
                movl   ebp,%ecx
                movl   eip,%edx
                movl   error,%eax
                pushl  eip
                movl   ebp,%ebp // Change frame pointer
{$else}
                movl   ebp,%eax
                pushl  %eax
                movl   eip,%eax
                pushl  %eax
                movl   error,%eax
                pushl  %eax
                movl   eip,%eax
                pushl  %eax
                movl   ebp,%ebp // Change frame pointer
{$endif}

{$ifdef SYSTEMEXCEPTIONDEBUG}
                jmpl   DebugHandleErrorAddrFrame
{$else not SYSTEMEXCEPTIONDEBUG}
                jmpl   HandleErrorAddrFrame
{$endif SYSTEMEXCEPTIONDEBUG}
        end;
end;

function syswin32_i386_exception_handler(excep : PExceptionPointers) : Longint;stdcall;
var
        frame,
        res  : longint;

function SysHandleErrorFrame(error, frame : Longint; must_reset_fpu : Boolean) : Longint;
begin
        if (frame = 0) then
                SysHandleErrorFrame:=EXCEPTION_CONTINUE_SEARCH
        else begin
                if (exceptLevel >= MaxExceptionLevel) then exit;

                exceptEip[exceptLevel] := excep^.ContextRecord^.Eip;
                exceptError[exceptLevel] := error;
                resetFPU[exceptLevel] := must_reset_fpu;
                inc(exceptLevel);

                excep^.ContextRecord^.Eip := Longint(@JumpToHandleErrorFrame);
                excep^.ExceptionRecord^.ExceptionCode := 0;

                SysHandleErrorFrame := EXCEPTION_CONTINUE_EXECUTION;
{$ifdef SYSTEMEXCEPTIONDEBUG}
                if IsConsole then begin
                        writeln(stderr,'Exception Continue Exception set at ',
                                hexstr(exceptEip[exceptLevel],8));
                        writeln(stderr,'Eip changed to ',
                                hexstr(longint(@JumpToHandleErrorFrame),8), ' error=', error);
                end;
{$endif SYSTEMEXCEPTIONDEBUG}
        end;
end;

begin
        if excep^.ContextRecord^.SegSs=_SS then
                frame := excep^.ContextRecord^.Ebp
        else
                frame := 0;
        res := EXCEPTION_CONTINUE_SEARCH;
{$ifdef SYSTEMEXCEPTIONDEBUG}
        if IsConsole then Writeln(stderr,'Exception  ',
                hexstr(excep^.ExceptionRecord^.ExceptionCode, 8));
{$endif SYSTEMEXCEPTIONDEBUG}
        case cardinal(excep^.ExceptionRecord^.ExceptionCode) of
                STATUS_INTEGER_DIVIDE_BY_ZERO,
                STATUS_FLOAT_DIVIDE_BY_ZERO :
                        res := SysHandleErrorFrame(200, frame, true);
                STATUS_ARRAY_BOUNDS_EXCEEDED :
                        res := SysHandleErrorFrame(201, frame, false);
                STATUS_STACK_OVERFLOW :
                        res := SysHandleErrorFrame(202, frame, false);
                STATUS_FLOAT_OVERFLOW :
                        res := SysHandleErrorFrame(205, frame, true);
                STATUS_FLOAT_DENORMAL_OPERAND,
                STATUS_FLOAT_UNDERFLOW :
                        res := SysHandleErrorFrame(206, frame, true);
{excep^.ContextRecord^.FloatSave.StatusWord := excep^.ContextRecord^.FloatSave.StatusWord and $ffffff00;}
                STATUS_FLOAT_INEXACT_RESULT,
                STATUS_FLOAT_INVALID_OPERATION,
                STATUS_FLOAT_STACK_CHECK :
                        res := SysHandleErrorFrame(207, frame, true);
                STATUS_INTEGER_OVERFLOW :
                        res := SysHandleErrorFrame(215, frame, false);
                STATUS_ILLEGAL_INSTRUCTION:
                  res := SysHandleErrorFrame(216, frame, true);
                STATUS_ACCESS_VIOLATION:
                  { Athlon prefetch bug? }
                  if is_prefetch(pointer(excep^.ContextRecord^.Eip)) then
                    begin
                      { if yes, then retry }
                      excep^.ExceptionRecord^.ExceptionCode := 0;
                      res:=EXCEPTION_CONTINUE_EXECUTION;
                    end
                  else
                    res := SysHandleErrorFrame(216, frame, true);

                STATUS_CONTROL_C_EXIT:
                        res := SysHandleErrorFrame(217, frame, true);
                STATUS_PRIVILEGED_INSTRUCTION:
                  res := SysHandleErrorFrame(218, frame, false);
                else
                  begin
                    if ((excep^.ExceptionRecord^.ExceptionCode and SEVERITY_ERROR) = SEVERITY_ERROR) then
                      res  :=  SysHandleErrorFrame(217, frame, true)
                    else
                      res := SysHandleErrorFrame(255, frame, true);
                  end;
        end;
        syswin32_i386_exception_handler := res;
end;


procedure install_exception_handlers;
{$ifdef SYSTEMEXCEPTIONDEBUG}
var
        oldexceptaddr,
        newexceptaddr : Longint;
{$endif SYSTEMEXCEPTIONDEBUG}

begin
{$ifdef SYSTEMEXCEPTIONDEBUG}
        asm
                movl $0,%eax
                movl %fs:(%eax),%eax
                movl %eax,oldexceptaddr
        end;
{$endif SYSTEMEXCEPTIONDEBUG}
        SetUnhandledExceptionFilter(@syswin32_i386_exception_handler);
{$ifdef SYSTEMEXCEPTIONDEBUG}
        asm
                movl $0,%eax
                movl %fs:(%eax),%eax
                movl %eax,newexceptaddr
        end;
        if IsConsole then
                writeln(stderr,'Old exception  ',hexstr(oldexceptaddr,8),
                        ' new exception  ',hexstr(newexceptaddr,8));
{$endif SYSTEMEXCEPTIONDEBUG}
end;

procedure remove_exception_handlers;
begin
        SetUnhandledExceptionFilter(nil);
end;

{$else not cpui386 (Processor specific !!)}
procedure install_exception_handlers;
begin
end;

procedure remove_exception_handlers;
begin
end;

{$endif Set_i386_Exception_handler}


{****************************************************************************
                    Error Message writing using messageboxes
****************************************************************************}

function MessageBox(w1:longint;l1,l2:pointer;w2:longint):longint;
   stdcall;external 'user32' name 'MessageBoxA';

const
  ErrorBufferLength = 1024;
var
  ErrorBuf : array[0..ErrorBufferLength] of char;
  ErrorLen : longint;

Function ErrorWrite(Var F: TextRec): Integer;
{
  An error message should always end with #13#10#13#10
}
var
  p : pchar;
  i : longint;
Begin
  if F.BufPos>0 then
   begin
     if F.BufPos+ErrorLen>ErrorBufferLength then
       i:=ErrorBufferLength-ErrorLen
     else
       i:=F.BufPos;
     Move(F.BufPtr^,ErrorBuf[ErrorLen],i);
     inc(ErrorLen,i);
     ErrorBuf[ErrorLen]:=#0;
   end;
  if ErrorLen>3 then
   begin
     p:=@ErrorBuf[ErrorLen];
     for i:=1 to 4 do
      begin
        dec(p);
        if not(p^ in [#10,#13]) then
         break;
      end;
   end;
   if ErrorLen=ErrorBufferLength then
     i:=4;
   if (i=4) then
    begin
      MessageBox(0,@ErrorBuf,pchar('Error'),0);
      ErrorLen:=0;
    end;
  F.BufPos:=0;
  ErrorWrite:=0;
End;


Function ErrorClose(Var F: TextRec): Integer;
begin
  if ErrorLen>0 then
   begin
     MessageBox(0,@ErrorBuf,pchar('Error'),0);
     ErrorLen:=0;
   end;
  ErrorLen:=0;
  ErrorClose:=0;
end;


Function ErrorOpen(Var F: TextRec): Integer;
Begin
  TextRec(F).InOutFunc:=@ErrorWrite;
  TextRec(F).FlushFunc:=@ErrorWrite;
  TextRec(F).CloseFunc:=@ErrorClose;
  ErrorOpen:=0;
End;


procedure AssignError(Var T: Text);
begin
  Assign(T,'');
  TextRec(T).OpenFunc:=@ErrorOpen;
  Rewrite(T);
end;


procedure SysInitStdIO;
begin
  { Setup stdin, stdout and stderr, for GUI apps redirect stderr,stdout to be
    displayed in and messagebox }
  StdInputHandle:=longint(GetStdHandle(cardinal(STD_INPUT_HANDLE)));
  StdOutputHandle:=longint(GetStdHandle(cardinal(STD_OUTPUT_HANDLE)));
  StdErrorHandle:=longint(GetStdHandle(cardinal(STD_ERROR_HANDLE)));
  if not IsConsole then
   begin
     AssignError(stderr);
     AssignError(stdout);
     Assign(Output,'');
     Assign(Input,'');
   end
  else
   begin
     OpenStdIO(Input,fmInput,StdInputHandle);
     OpenStdIO(Output,fmOutput,StdOutputHandle);
     OpenStdIO(StdOut,fmOutput,StdOutputHandle);
     OpenStdIO(StdErr,fmOutput,StdErrorHandle);
   end;
end;


const
   Exe_entry_code : pointer = @Exe_entry;
   Dll_entry_code : pointer = @Dll_entry;

begin
  StackLength := InitialStkLen;
  StackBottom := Sptr - StackLength;
  { get some helpful informations }
  GetStartupInfo(@startupinfo);
  { some misc Win32 stuff }
  hprevinst:=0;
  if not IsLibrary then
    HInstance:=getmodulehandle(GetCommandFile);
  MainInstance:=HInstance;
  cmdshow:=startupinfo.wshowwindow;
  { Setup heap }
  InitHeap;
  SysInitExceptions;
  SysInitStdIO;
  { Arguments }
  setup_arguments;
  { Reset IO Error }
  InOutRes:=0;
  ProcessID := GetCurrentProcess;
  ThreadID := GetCurrentThread;
  { Reset internal error variable }
  errno:=0;
{$ifdef HASVARIANT}
  initvariantmanager;
{$endif HASVARIANT}
end.

{
  $Log$
  Revision 1.60  2004-06-27 11:57:18  florian
    * finally (hopefully) fixed sysalloc trouble

  Revision 1.59  2004/06/26 15:05:14  florian
    * fixed argument copying

  Revision 1.58  2004/06/20 09:24:40  peter
  fixed go32v2 compile

  Revision 1.57  2004/06/17 16:16:14  peter
    * New heapmanager that releases memory back to the OS, donated
      by Micha Nelissen

  Revision 1.56  2004/05/16 18:51:20  peter
    * use thandle in do_*

  Revision 1.55  2004/04/22 21:10:56  peter
    * do_read/do_write addr argument changed to pointer

  Revision 1.54  2004/02/15 21:37:18  hajny
    * ProcessID initialization added

  Revision 1.53  2004/02/02 17:01:47  florian
    * workaround for AMD prefetch bug

  Revision 1.52  2004/01/20 23:12:49  hajny
    * ExecuteProcess fixes, ProcessID and ThreadID added

  Revision 1.51  2003/12/17 21:56:33  peter
    * win32 regcall patches

  Revision 1.50  2003/12/04 20:52:41  peter
    * stdcall for CreateFile

  Revision 1.49  2003/11/24 23:08:37  michael
  + Redefined Fileopen so it corresponds to ascdef.inc definition

  Revision 1.48  2003/11/03 09:42:28  marco
   * Peter's Cardinal<->Longint fixes patch

  Revision 1.47  2003/10/17 22:15:10  olle
    * changed i386 to cpui386

  Revision 1.46  2003/10/16 15:43:13  peter
    * THandle is platform dependent

  Revision 1.45  2003/10/06 23:52:53  florian
    * some data types cleaned up

  Revision 1.44  2003/09/27 11:52:36  peter
    * sbrk returns pointer

  Revision 1.43  2003/09/26 07:30:34  michael
  + Win32 Do_open crahs on append

  Revision 1.42  2003/09/17 15:06:36  peter
    * stdcall patch

  Revision 1.41  2003/09/12 12:33:43  olle
    * nice-ified

  Revision 1.40  2003/01/01 20:56:57  florian
    + added invalid instruction exception

  Revision 1.39  2002/12/24 15:35:15  peter
    * error code fixes

  Revision 1.38  2002/12/07 13:58:45  carl
    * fix warnings

  Revision 1.37  2002/11/30 18:17:35  carl
    + profiling support

  Revision 1.36  2002/10/31 15:17:58  carl
    * always allocate argument even if its empty (bugfix web bug 2202)

  Revision 1.35  2002/10/14 20:40:22  florian
    * InitFPU renamed to SysResetFPU

  Revision 1.34  2002/10/14 19:39:17  peter
    * threads unit added for thread support

  Revision 1.33  2002/10/13 09:28:45  florian
    + call to initvariantmanager inserted

  Revision 1.32  2002/09/07 21:28:10  carl
    - removed os_types
    * fix range check errors

  Revision 1.31  2002/09/07 16:01:29  peter
    * old logs removed and tabs fixed

  Revision 1.30  2002/08/26 13:49:18  pierre
   * fix bug report 2086

  Revision 1.29  2002/07/28 20:43:49  florian
    * several fixes for linux/powerpc
    * several fixes to MT

  Revision 1.28  2002/07/01 16:29:05  peter
    * sLineBreak changed to normal constant like Kylix

  Revision 1.27  2002/06/04 09:25:14  pierre
   * Rename HeapSize to WinAPIHeapSize to avoid conflict with general function

  Revision 1.26  2002/04/12 17:45:13  carl
  + generic stack checking

  Revision 1.25  2002/03/11 19:10:33  peter
    * Regenerated with updated fpcmake

  Revision 1.24  2002/01/30 14:57:11  pierre
   * fix compilation failure

  Revision 1.23  2002/01/25 16:23:03  peter
    * merged filesearch() fix

}
