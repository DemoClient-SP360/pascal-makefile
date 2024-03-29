{
    This file is part of the Free Pascal run time library.
    Copyright (c) 2011 by Marcus Sackrow

    dos.library functions for AROS

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}

function Open(name: PAnsiChar; accessMode: longint): BPTR; syscall AOS_DOSBase 5;
function dosClose(_file: BPTR): LongBool;  syscall AOS_DOSBase 6;
function dosRead(_file: BPTR; buffer: Pointer; length: longint): longint; syscall AOS_DOSBase 7;
function dosWrite(_file: BPTR; buffer: Pointer; length: longint): longint;  syscall AOS_DOSBase 8;
function dosInput: BPTR; syscall AOS_DOSBase 9;
function dosOutput: BPTR; syscall AOS_DOSBase 10;
{$ifdef AROS_ABIv0}
function DosError1: BPTR;  syscall AOS_DOSBase 142;
{$endif}
function dosSeek(_file: BPTR; position: longint;offset: longint): longint; syscall AOS_DOSBase 11;
function dosDeleteFile(const name: PAnsiChar): LongBool; syscall AOS_DOSBase 12;
function dosRename(const oldName: PAnsiChar;newName: PAnsiChar): LongInt; syscall AOS_DOSBase 13;
function Lock(const name: PAnsiChar;_type: longint): BPTR; syscall AOS_DOSBase 14;
function UnLock(lock: BPTR): LongInt; syscall AOS_DOSBase 15;
function DupLock(Lock: BPTR): BPTR; syscall AOS_DOSBase 16;
function Examine(lock: BPTR; fileInfoBlock: PFileInfoBlock): LongInt; syscall AOS_DOSBase 17;
function Info(lock: BPTR; parameterBlock: PInfoData): LongInt; syscall AOS_DOSBase 19;
function dosCreateDir(const name: PAnsiChar): BPTR; syscall AOS_DOSBase 20;
function CurrentDir(lock: BPTR): BPTR; syscall AOS_DOSBase 21;
function IoErr: longint; syscall AOS_DOSBase 22;
procedure dosExit(ErrCode: longint); syscall AOS_DOSBase 24;
function SetProtection(const name: PAnsiChar; protect: longword): LongInt; syscall AOS_DOSBase 31;
function DateStamp(date: PDateStamp): PDateStamp; syscall AOS_DOSBase 32;
procedure dosDelay(ticks: LongWord); syscall AOS_DOSBase 33;
function AllocDosObject(Type_: LongWord; const Tags: PTagItem): Pointer; syscall AOS_DOSBase 38;
procedure FreeDosObject(Type_: LongWord; Ptr: Pointer); syscall AOS_DOSBase 39;
function SetFileDate(name: PAnsiChar; date: PDateStamp): LongBool; syscall AOS_DOSBase 66;
function NameFromLock(lock: BPTR; buffer: PAnsiChar; len: longint): LongBool; syscall AOS_DOSBase 67;
function SetFileSize(fh: BPTR; pos: longint; mode: longint): longint; syscall AOS_DOSBase 76;
function Cli : pCommandLineInterface; syscall AOS_DOSBase 82;
function CreateNewProc(const Tags: PTagItem): PProcess; syscall AOS_DOSBase 83;
function GetArgStr: PAnsiChar; syscall AOS_DOSBase 89;
function GetCurrentDirName(buf: PAnsiChar; len: longint): LongBool; syscall AOS_DOSBase 94;
function GetProgramName(buf: PAnsiChar; len: longint): LongBool; syscall AOS_DOSBase 96;
function GetProgramDir: BPTR; syscall AOS_DOSBase 100;
function SystemTagList(command: PAnsiChar; tags: PTagItem): longint; syscall AOS_DOSBase 101;
function LockDosList(flags: longword): PDosList; syscall AOS_DOSBase 109;
procedure UnLockDosList(flags: longword); syscall AOS_DOSBase 110;
function NextDosEntry(dlist: PDosList; flags: longword): PDosList; syscall AOS_DOSBase 115;
function MatchFirst(pat: PAnsiChar; anchor: PAnchorPath): longint; syscall AOS_DOSBase 137;
function MatchNext(anchor: PAnchorPath): longint; syscall AOS_DOSBase 138;
procedure MatchEnd(anchor: PAnchorPath); syscall AOS_DOSBase 139;
function GetVar(name: PAnsiChar; buffer: PAnsiChar; size: longint; flags: longword): longint; syscall AOS_DOSBase 151;
function ExamineFH(Fh: BPTR; Fib: PFileInfoBlock): LongBool; syscall AOS_DOSBase 65;
function NameFromFH(Fh: BPTR; Buffer: PAnsiChar; Length: LongInt): LongBool; syscall AOS_DOSBase 68;


{$ifdef AROS_ABIv1}
function DosError1(): BPTR;
var
  P: PProcess;
begin
  DosError1 := 0;
  P := PProcess(FindTask(nil));
  if Assigned(P) then
    DosError1 := P^.pr_CES;
  if DosError1 = 0 then
    DosError1 := DosOutput();
end;
{$endif}
