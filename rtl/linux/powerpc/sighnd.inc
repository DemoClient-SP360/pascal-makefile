{
    This file is part of the Free Pascal run time library.
    Copyright (c) 1999-2000 by Michael Van Canneyt,
    member of the Free Pascal development team.

    Signal handler is arch dependant due to processor to language
    exception conversion.

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}

procedure SignalToRunerror(sig : longint; SigInfo: PSigInfo; context: PUContext);public name '_FPC_DEFAULTSIGHANDLER';cdecl;
var
  res : word;
{  fpustate: longint; }
begin
  res:=0;
{$ifndef FPUNONE}
  { exception flags are turned off by kernel }
  SysResetFpu;
{$endif}
  case sig of
    SIGFPE :
      case (SigInfo^.si_code) of
        FPE_FLTDIV : res := 208;
        FPE_FLTOVF : res := 205;
        FPE_FLTUND : res := 206;
        else
          res := 207;
      end;
    SIGBUS :
      res:=214;
    SIGILL,
    SIGSEGV :
      res:=216;
    SIGINT:
        res:=217;
    SIGQUIT:
        res:=233;
  end;
  reenable_signal(sig);
  { give runtime error at the position where the signal was raised }
  if res<>0 then
    HandleErrorAddrFrame(res, pointer(context^.uc_mcontext.pt_regs^.nip),
      pointer(context^.uc_mcontext.pt_regs^.gpr[1]));
end;


