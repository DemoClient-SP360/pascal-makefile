{
    $Id$
    This file is part of the Free Pascal run time library.
    Copyright (c) 1999-2000 by Pierre Muller

    DPMI Exception routines for Go32V2

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}

{$ifndef IN_SYSTEM}
{$GOTO ON}
{$define IN_DPMIEXCP_UNIT}
{$ifndef NO_EXCEPTIONS_IN_SYSTEM}
{ $ define EXCEPTIONS_IN_SYSTEM}
{$endif NO_EXCEPTIONS_IN_SYSTEM}

Unit DpmiExcp;

{ If linking to C code we must avoid loading of the dpmiexcp.o
  in libc.a from the equivalent C code
  => all global functions from dpmiexcp.c must be aliased PM

  Problem this is only valid for DJGPP v2.01 }


interface

uses
  go32;

{$endif ndef IN_SYSTEM}
{ No stack checking ! }
{$S-}


{ Decide if we want to create the C functions or not }

{$ifdef EXCEPTIONS_IN_SYSTEM}
{ If exceptions are in system the C functions must be
  inserted in the system unit }
{$ifdef IN_DPMIEXCP_UNIT}
{$undef CREATE_C_FUNCTIONS}
{$else not IN_DPMIEXCP_UNIT}
{$define CREATE_C_FUNCTIONS}
{$endif ndef IN_DPMIEXCP_UNIT}
{$else not EXCEPTIONS_IN_SYSTEM}
{$define CREATE_C_FUNCTIONS}
{$endif not EXCEPTIONS_IN_SYSTEM}
{ Error Messages }
function do_faulting_finish_message(fake : boolean) : integer;cdecl;
{$ifdef IN_SYSTEM}forward;{$endif IN_SYSTEM}

{ SetJmp/LongJmp }
type
  { must also contain exception_state !! }
  pdpmi_jmp_buf = ^dpmi_jmp_buf;
  dpmi_jmp_buf = packed record
      eax,ebx,ecx,edx,esi,edi,ebp,esp,eip,flags : longint;
      cs,ds,es,fs,gs,ss : word;
      sigmask : longint;        {  for POSIX signals only  }
      signum : longint;         {  for expansion ie 386 exception number }
      exception_ptr : pdpmi_jmp_buf;  { pointer to previous exception if exists }
  end;
function dpmi_setjmp(var rec : dpmi_jmp_buf) : longint;
{$ifdef IN_SYSTEM}forward;{$endif IN_SYSTEM}
procedure dpmi_longjmp(var rec : dpmi_jmp_buf;return_value : longint);
{$ifdef IN_SYSTEM}forward;{$endif IN_SYSTEM}

{ Signals }
const
  SIGABRT   = 288;
  SIGFPE    = 289;
  SIGILL    = 290;
  SIGSEGV   = 291;
  SIGTERM   = 292;
  SIGALRM   = 293;
  SIGHUP    = 294;
  SIGINT    = 295;
  SIGKILL   = 296;
  SIGPIPE   = 297;
  SIGQUIT   = 298;
  SIGUSR1   = 299;
  SIGUSR2   = 300;
  SIGNOFP   = 301;
  SIGTRAP   = 302;
  SIGTIMR   = 303;    { Internal for setitimer (SIGALRM, SIGPROF) }
  SIGPROF   = 304;
  SIGMAX    = 320;

  SIG_BLOCK   = 1;
  SIG_SETMASK = 2;
  SIG_UNBLOCK = 3;

function SIG_DFL( x: longint) : longint;
{$ifdef IN_SYSTEM}forward;{$endif IN_SYSTEM}
function SIG_ERR( x: longint) : longint;
{$ifdef IN_SYSTEM}forward;{$endif IN_SYSTEM}
function SIG_IGN( x: longint) : longint;
{$ifdef IN_SYSTEM}forward;{$endif IN_SYSTEM}

type
  SignalHandler  = function (v : longint) : longint;
  PSignalHandler = ^SignalHandler; { to be compatible with linux.pp }

function signal(sig : longint;func : SignalHandler) : SignalHandler;
{$ifdef IN_SYSTEM}forward;{$endif IN_SYSTEM}
function _raise(sig : longint) : longint;
{$ifdef IN_SYSTEM}forward;{$endif IN_SYSTEM}

{ Exceptions }
type
  pexception_state = ^texception_state;
  texception_state = record
    __eax, __ebx, __ecx, __edx, __esi : longint;
    __edi, __ebp, __esp, __eip, __eflags : longint;
    __cs, __ds, __es, __fs, __gs, __ss : word;
    __sigmask : longint;        {  for POSIX signals only  }
    __signum : longint;         {  for expansion  }
    __exception_ptr : pexception_state;  {  pointer to previous exception  }
    __fpu_state : array [0..108-1] of byte; {  for future use  }
  end;

procedure djgpp_exception_toggle;
{$ifdef IN_SYSTEM}forward;{$endif IN_SYSTEM}
procedure djgpp_exception_setup;
{$ifdef IN_SYSTEM}forward;{$endif IN_SYSTEM}
function  djgpp_exception_state : pexception_state;
{$ifdef IN_SYSTEM}forward;{$endif IN_SYSTEM}
function  djgpp_set_ctrl_c(enable : boolean) : boolean;
{$ifdef IN_SYSTEM}forward;{$endif IN_SYSTEM}

{ Other }
function dpmi_set_coprocessor_emulation(flag : longint) : longint;
{$ifdef IN_SYSTEM}forward;{$endif IN_SYSTEM}
function __djgpp_set_sigint_key(new_key : longint) : longint;cdecl;
{$ifdef IN_SYSTEM}forward;{$endif IN_SYSTEM}
function __djgpp_set_sigquit_key(new_key : longint) : longint;cdecl;
{$ifdef IN_SYSTEM}forward;{$endif IN_SYSTEM}
function __djgpp__traceback_exit(sig : longint) : longint;cdecl;
{$ifdef IN_SYSTEM}forward;{$endif IN_SYSTEM}

{$ifndef IN_SYSTEM}
implementation
{$endif IN_SYSTEM}

{$asmmode ATT}

{$ifdef CREATE_C_FUNCTIONS}
{$L exceptn.o}
{$endif CREATE_C_FUNCTIONS}

{$ifndef CREATE_C_FUNCTIONS}
procedure djgpp_exception_toggle;
external name '___djgpp_exception_toggle';
procedure djgpp_exception_setup;
external name '___djgpp_exception_setup';
function __djgpp_set_sigint_key(new_key : longint) : longint;cdecl;
external name '___djgpp_set_sigint_key';
function __djgpp_set_sigquit_key(new_key : longint) : longint;cdecl;
external name '___djgpp_set_sigquit_key';
function __djgpp__traceback_exit(sig : longint) : longint;cdecl;
external name '__djgpp__traceback_exit';
{$endif CREATE_C_FUNCTIONS}
var
  v2prt0_ds_alias : word;external name '___v2prt0_ds_alias';
  djgpp_ds_alias  : word;external name '___djgpp_ds_alias';
  djgpp_exception_state_ptr : pexception_state;external name '___djgpp_exception_state_ptr';
  endtext        : longint;external name '_etext';
  starttext       : longint;external name 'start';
  djgpp_old_kbd : tseginfo;external name '___djgpp_old_kbd';
  djgpp_hw_lock_start : longint;external name '___djgpp_hw_lock_start';
  djgpp_hw_lock_end : longint;external name '___djgpp_hw_lock_end';
  djgpp_hwint_flags : longint;external name '___djgpp_hwint_flags';
  djgpp_dos_sel : word;external name '___djgpp_dos_sel';
  djgpp_exception_table : array[0..0] of pointer;external name '___djgpp_exception_table';
  dosmemselector : word;external name '_core_selector';

procedure djgpp_i24;external name '___djgpp_i24';
procedure djgpp_iret;external name '___djgpp_iret';
procedure djgpp_npx_hdlr;external name '___djgpp_npx_hdlr';
procedure djgpp_kbd_hdlr;external name '___djgpp_kbd_hdlr';
procedure djgpp_kbd_hdlr_pc98;external name '___djgpp_kbd_hdlr_pc98';
procedure djgpp_cbrk_hdlr;external name '___djgpp_cbrk_hdlr';


{$ifdef CREATE_C_FUNCTIONS}
var
  exceptions_on : boolean;
{  old_int00 : tseginfo;cvar;external;
  old_int75 : tseginfo;cvar;external; }

const
  cbrk_vect : byte = $1b;
  exception_level : longint = 0;
{$endif CREATE_C_FUNCTIONS}


{$ifndef IN_DPMIEXCP_UNIT}
{****************************************************************************
          DPMI functions copied from go32 unit
****************************************************************************}

const
  int31error : word = 0;

    procedure test_int31(flag : longint);
      begin
         asm
            pushl %ebx
            movw  $0,INT31ERROR
            movl  flag,%ebx
            testb $1,%bl
            jz    .Lti31_1
            movw  %ax,INT31ERROR
            xorl  %eax,%eax
            jmp   .Lti31_2
            .Lti31_1:
            movl  $1,%eax
            .Lti31_2:
            popl  %ebx
         end;
      end;

    function set_pm_exception_handler(e : byte;const intaddr : tseginfo) : boolean;

      begin
         asm
            movl intaddr,%eax
            movl (%eax),%edx
            movw 4(%eax),%cx
            movl $0x212,%eax
            movb e,%bl
            int $0x31
            pushf
            call test_int31
            movb %al,__RESULT
         end;
      end;

    function set_exception_handler(e : byte;const intaddr : tseginfo) : boolean;

      begin
         asm
            movl intaddr,%eax
            movl (%eax),%edx
            movw 4(%eax),%cx
            movl $0x203,%eax
            movb e,%bl
            int $0x31
            pushf
            call test_int31
            movb %al,__RESULT
         end;
      end;

    function get_pm_exception_handler(e : byte;var intaddr : tseginfo) : boolean;

      begin
         asm
            movl $0x210,%eax
            movb e,%bl
            int $0x31
            pushf
            call test_int31
            movb %al,__RESULT
            movl intaddr,%eax
            movl %edx,(%eax)
            movw %cx,4(%eax)
         end;
      end;

    function get_exception_handler(e : byte;var intaddr : tseginfo) : boolean;

      begin
         asm
            movl $0x202,%eax
            movb e,%bl
            int $0x31
            pushf
            call test_int31
            movb %al,__RESULT
            movl intaddr,%eax
            movl %edx,(%eax)
            movw %cx,4(%eax)
         end;
      end;

    function get_segment_base_address(d : word) : longint;

      begin
         asm
            movw d,%bx
            movl $6,%eax
            int $0x31
            xorl %eax,%eax
            movw %dx,%ax
            shll $16,%ecx
            orl %ecx,%eax
            movl %eax,__RESULT
         end;
      end;

    function get_segment_limit(d : word) : longint;

      begin
         asm
            movzwl d,%eax
            lsl %eax,%eax
            jz .L_ok2
            xorl %eax,%eax
         .L_ok2:
            movl %eax,__RESULT
         end;
      end;

    function set_rm_interrupt(vector : byte;const intaddr : tseginfo) : boolean;

      begin
         asm
            movl intaddr,%eax
            movw (%eax),%dx
            movw 4(%eax),%cx
            movl $0x201,%eax
            movb vector,%bl
            int $0x31
            pushf
            call test_int31
            movb %al,__RESULT
         end;
      end;

    function get_rm_interrupt(vector : byte;var intaddr : tseginfo) : boolean;

      begin
         asm
            movb vector,%bl
            movl $0x200,%eax
            int $0x31
            pushf
            call test_int31
            movb %al,__RESULT
            movl intaddr,%eax
            movzwl %dx,%edx
            movl %edx,(%eax)
            movw %cx,4(%eax)
         end;
      end;


    function free_rm_callback(var intaddr : tseginfo) : boolean;
      begin
         asm
            movl intaddr,%eax
            movw (%eax),%dx
            movw 4(%eax),%cx
            movl $0x304,%eax
            int $0x31
            pushf
            call test_int31
            movb %al,__RESULT
         end;
      end;

    function get_rm_callback(pm_func : pointer;const reg : trealregs;var rmcb : tseginfo) : boolean;
      begin
         asm
            movl  pm_func,%esi
            movl  reg,%edi
            pushw %es
            movw  v2prt0_ds_alias,%ax
            movw  %ax,%es
            pushw %ds
            movw  %cs,%ax
            movw  %ax,%ds
            movl  $0x303,%eax
            int   $0x31
            popw  %ds
            popw  %es
            pushf
            call test_int31
            movb %al,__RESULT
            movl  rmcb,%eax
            movzwl %dx,%edx
            movl  %edx,(%eax)
            movw  %cx,4(%eax)
         end;
      end;

    function lock_linear_region(linearaddr, size : longint) : boolean;

      begin
          asm
            movl  $0x600,%eax
            movl  linearaddr,%ecx
            movl  %ecx,%ebx
            shrl  $16,%ebx
            movl  size,%esi
            movl  %esi,%edi
            shrl  $16,%esi
            int   $0x31
            pushf
            call test_int31
            movb %al,__RESULT
          end;
      end;

    function lock_code(functionaddr : pointer;size : longint) : boolean;

      var
         linearaddr : longint;

      begin
         linearaddr:=longint(functionaddr)+get_segment_base_address(get_cs);
         lock_code:=lock_linear_region(linearaddr,size);
      end;
{$endif ndef IN_DPMIEXCP_UNIT}

{****************************************************************************
                                  Helpers
****************************************************************************}

procedure err(const x : string);
begin
   write(stderr, x);
end;

procedure errln(const x : string);
begin
   writeln(stderr, x);
end;


procedure itox(v,len : longint);
var
  st : string;
begin
  st:=hexstr(v,len);
  err(st);
end;


{****************************************************************************
                              SetJmp/LongJmp
****************************************************************************}

{$ifdef CREATE_C_FUNCTIONS}
function c_setjmp(var rec : dpmi_jmp_buf) : longint;[public, alias : '_setjmp'];
  begin
  { here we need to be subtle :
    - we need to return with the arg still on the stack
    - but we also need to jmp to FPC_setjmp and not to call it
    because otherwise the return address is wrong !!

    For this we shift the return address down and
    duplicate the rec on stack }
     asm
        movl    %ebp,%esp
        popl    %ebp
        subl    $8,%esp
        movl    %eax,(%esp)
        movl    8(%esp),%eax
        movl    %eax,4(%esp)
        movl    12(%esp),%eax
        movl    %eax,8(%esp)
        popl    %eax
        jmp     dpmi_setjmp
     end;
  end;
{$endif CREATE_C_FUNCTIONS}

function dpmi_setjmp(var rec : dpmi_jmp_buf) : longint;
{$ifndef CREATE_C_FUNCTIONS}
external name 'FPC_setjmp';
{$else CREATE_C_FUNCTIONS}
[alias : 'FPC_setjmp'];
begin
  asm
        pushl   %edi
        movl    rec,%edi
        movl    %eax,(%edi)
        movl    %ebx,4(%edi)
        movl    %ecx,8(%edi)
        movl    %edx,12(%edi)
        movl    %esi,16(%edi)
        { load edi }
        movl    -4(%ebp),%eax
        { ... and store it }
        movl    %eax,20(%edi)
        { ebp ... }
        movl    (%ebp),%eax
        movl    %eax,24(%edi)
        { esp ... }
        movl    %esp,%eax
        addl    $12,%eax
        movl    %eax,28(%edi)
        { the return address }
        movl    4(%ebp),%eax
        movl    %eax,32(%edi)
        { flags ... }
        pushfl
        popl    36(%edi)
        { !!!!! the segment registers, not yet needed }
        { you need them if the exception comes from
        an interrupt or a seg_move }
        movw    %cs,40(%edi)
        movw    %ds,42(%edi)
        movw    %es,44(%edi)
        movw    %fs,46(%edi)
        movw    %gs,48(%edi)
        movw    %ss,50(%edi)
        movl    djgpp_exception_state_ptr, %eax
        movl    %eax, 60(%edi)
        { restore EDI }
        pop     %edi
        { we come from the initial call }
        xorl    %eax,%eax
        movl    %eax,__RESULT
        { leave USING RET inside CDECL functions is risky as
        some registers are pushed at entry
        ret  $4 not anymore since cdecl !! }
  end;
end;
{$endif CREATE_C_FUNCTIONS}


{$ifdef CREATE_C_FUNCTIONS}
procedure c_longjmp(var  rec : dpmi_jmp_buf;return_value : longint);[public, alias : '_longjmp'];
  begin
     dpmi_longjmp(rec,return_value);
     { never gets here !! so pascal stack convention is no problem }
  end;
{$endif CREATE_C_FUNCTIONS}

procedure dpmi_longjmp(var  rec : dpmi_jmp_buf;return_value : longint);
{$ifndef CREATE_C_FUNCTIONS}
external name 'FPC_longjmp';
{$else CREATE_C_FUNCTIONS}
[public, alias : 'FPC_longjmp'];
begin
  if (exception_level>0) then
    dec(exception_level);
  asm
        { restore compiler shit }
        popl    %ebp
        { copy from longjmp.S }
        movl    4(%esp),%edi    { get dpmi_jmp_buf }
        movl    8(%esp),%eax    { store retval in j->eax }
        movl    %eax,0(%edi)

        movw    46(%edi),%fs
        movw    48(%edi),%gs
        movl    4(%edi),%ebx
        movl    8(%edi),%ecx
        movl    12(%edi),%edx
        movl    24(%edi),%ebp
        { Now for some uglyness.  The dpmi_jmp_buf structure may be ABOVE the
           point on the new SS:ESP we are moving to.  We don't allow overlap,
           but do force that it always be valid.  We will use ES:ESI for
           our new stack before swapping to it.  }
        movw    50(%edi),%es
        movl    28(%edi),%esi
        subl    $28,%esi        { We need 7 working longwords on stack }
        movl    60(%edi),%eax
        movl    %eax,%es:(%esi)     { Exception pointer }
        movzwl  42(%edi),%eax
        movl    %eax,%es:4(%esi)    { DS }
        movl    20(%edi),%eax
        movl    %eax,%es:8(%esi)    { EDI }
        movl    16(%edi),%eax
        movl    %eax,%es:12(%esi)   { ESI }
        movl    32(%edi),%eax
        movl    %eax,%es:16(%esi)   { EIP - start of IRET frame }
        movl    40(%edi),%eax
        movl    %eax,%es:20(%esi)   { CS }
        movl    36(%edi),%eax
        movl    %eax,%es:24(%esi)   { EFLAGS }
        movl    0(%edi),%eax
        movw    44(%edi),%es
        movw    50(%edi),%ss
        movl    %esi,%esp
        popl    djgpp_exception_state_ptr
        popl    %ds
        popl    %edi
        popl    %esi
        iret                    { actually jump to new cs:eip loading flags }
  end;
end;
{$endif CREATE_C_FUNCTIONS}


{****************************************************************************
                                 Signals
****************************************************************************}

var
  signal_list : Array[0..SIGMAX] of SignalHandler;cvar;
  {$ifndef CREATE_C_FUNCTIONS}external;{$endif}

{$ifdef CREATE_C_FUNCTIONS}
function SIG_ERR(x:longint):longint;[public,alias : '___djgpp_SIG_ERR'];
begin
  SIG_ERR:=-1;
end;


function SIG_IGN(x:longint):longint;[public,alias : '___djgpp_SIG_IGN'];
begin
  SIG_IGN:=-1;
end;


function SIG_DFL(x:longint):longint;[public,alias : '___djgpp_SIG_DFL'];
begin
  SIG_DFL:=0;
end;

{$else CREATE_C_FUNCTIONS}
function SIG_ERR(x:longint):longint;external name '___djgpp_SIG_ERR';
function SIG_IGN(x:longint):longint;external name '___djgpp_SIG_IGN';
function SIG_DFL(x:longint):longint;external name '___djgpp_SIG_DFL';
{$endif CREATE_C_FUNCTIONS}

function signal(sig : longint;func : SignalHandler) : SignalHandler;
var
  temp : SignalHandler;
begin
  if ((sig < 0) or (sig > SIGMAX) or (sig = SIGKILL)) then
   begin
     signal:=@SIG_ERR;
     runerror(201);
   end;
  temp := signal_list[sig];
  signal_list[sig] := func;
  signal:=temp;
end;


{$ifdef CREATE_C_FUNCTIONS}
{ C counter part }
function c_signal(sig : longint;func : SignalHandler) : SignalHandler;cdecl;[public,alias : '_signal'];
var
  temp : SignalHandler;
begin
  temp:=signal(sig,func);
  c_signal:=temp;
end;
{$endif CREATE_C_FUNCTIONS}


const
  signames : array [0..14] of string[4] = (
    'ABRT','FPE ','ILL ','SEGV','TERM','ALRM','HUP ',
    'INT ','KILL','PIPE','QUIT','USR1','USR2','NOFP','TRAP');

procedure print_signal_name(sig : longint);
begin
     if ((sig >= SIGABRT) and (sig <= SIGTRAP)) then
      begin
        err('Exiting due to signal SIG');
        err(signames[sig-sigabrt]);
      end
     else
      begin
        err('Exiting due to signal $');
        itox(sig, 4);
      end;
     errln('');
end;

function _raise(sig : longint) : longint;
var
  temp : SignalHandler;
begin
  if(sig < 0) or (sig > SIGMAX) then
   exit(-1);
  temp:=signal_list[sig];
  if (temp = SignalHandler(@SIG_IGN)) then
   exit(0);
  if (temp = SignalHandler(@SIG_DFL)) then
   begin
     print_signal_name(sig);
     do_faulting_finish_message(djgpp_exception_state<>nil);   { Exits, does not return }
     exit(-1);
   end;
  { this is incompatible with dxegen-dxeload stuff PM }
  if ((cardinal(temp) < cardinal(@starttext)) or
      (cardinal(temp) > cardinal(@endtext))) then
   begin
     errln('Bad signal handler, ');
     print_signal_name(sig);
     do_faulting_finish_message(djgpp_exception_state<>nil);   { Exits, does not return }
     exit(-1);
   end;
  { WARNING !!! temp can be a pascal or a C
    function... thus %esp can be modified here !!!
    This might be dangerous for some optimizations ?? PM }
  temp(sig);
  exit(0);
end;


{$ifdef CREATE_C_FUNCTIONS}
function c_raise(sig : longint) : longint;cdecl;[public,alias : '_raise'];
begin
  c_raise:=_raise(sig);
end;
{$endif CREATE_C_FUNCTIONS}


{****************************************************************************
                                 Exceptions
****************************************************************************}

{$ifdef CREATE_C_FUNCTIONS}
function except_to_sig(excep : longint) : longint;
begin
  case excep of
    5,8,9,11,12,13,14 : exit(SIGSEGV);
    0,4,16            : exit(SIGFPE);
    1,3               : exit(SIGTRAP);
    7                 : exit(SIGNOFP);
  else
    begin
      case excep of
        $75 : exit(SIGFPE);
        $78 : exit(SIGTIMR);
        $1b,
        $79 : exit(SIGINT);
        $7a : exit(SIGQUIT);
      else
        exit(SIGILL);
      end;
    end;
  end;
end;


procedure show_call_frame(djgpp_exception_state : pexception_state);
begin
  errln('Call frame traceback EIPs:');
  errln('  0x'+hexstr(djgpp_exception_state^.__eip, 8));
  dump_stack(stderr,djgpp_exception_state^.__ebp);
end;


const
  EXCEPTIONCOUNT = 18;
  exception_names : array[0..EXCEPTIONCOUNT-1] of pchar = (
   'Division by Zero',
   'Debug',
   'NMI',
   'Breakpoint',
   'Overflow',
   'Bounds Check',
   'Invalid Opcode',
   'Coprocessor not available',
   'Double Fault',
   'Coprocessor overrun',
   'Invalid TSS',
   'Segment Not Present',
   'Stack Fault',
   'General Protection Fault',
   'Page fault',
   ' ',
   'Coprocessor Error',
   'Alignment Check');

  has_error : array [0..EXCEPTIONCOUNT-1] of byte =
   (0,0,0,0,0,0,0,0,1,0,1,1,1,1,1,0,0,1);

  cbrk_hooked    : boolean = false;
  old_video_mode : byte = 3;


procedure dump_selector(const name : string; sel : word);
var
  base,limit : longint;
begin
  err(name);
  err(': sel=');
  itox(sel, 4);
  if (sel<>0) then
   begin
     base:=get_segment_base_address(sel);
     err('  base='); itox(base, 8);
     limit:=get_segment_limit(sel);
     err('  limit='); itox(limit, 8);
   end;
  errln('');
end;


function farpeekb(sel : word;offset : longint) : byte;
var
  b : byte;
begin
{$ifdef IN_DPMIEXCP_UNIT}
  seg_move(sel,offset,get_ds,longint(@b),1);
{$else not IN_DPMIEXCP_UNIT}
  sysseg_move(sel,offset,get_ds,longint(@b),1);
{$endif IN_DPMIEXCP_UNIT}
  farpeekb:=b;
end;


const message_level : byte = 0;

procedure ___exit(c:longint);cdecl;external name '___exit';
{$endif CREATE_C_FUNCTIONS}

function do_faulting_finish_message(fake : boolean) : integer;cdecl;
{$ifndef CREATE_C_FUNCTIONS}
external;
{$else CREATE_C_FUNCTIONS}
public;
var
  en : pchar;
  signum,i : longint;
  old_vid : byte;
label
  simple_exit;
begin
  inc(message_level);
  if message_level>2 then
    goto simple_exit;
  do_faulting_finish_message:=0;
  signum:=djgpp_exception_state_ptr^.__signum;
  { check video mode for original here and reset (not if PC98) */ }
  if ((go32_info_block.linear_address_of_primary_screen <> $a0000) and
     (farpeekb(dosmemselector, $449) <> old_video_mode)) then
    begin
       old_vid:=old_video_mode;
       asm
          pusha
          movzbl old_vid,%eax
          int $0x10
          popa
          nop
       end;
    end;

  if (signum >= EXCEPTIONCOUNT) then
    begin
       case signum of
         $75 : en:='Floating Point exception';
         $1b : en:='Control-Break Pressed';
         $79 : en:='Control-C Pressed';
       else
         en:=nil;
       end;
    end
  else
    en:=exception_names[signum];

  if (en = nil) then
    begin
       if fake then
         err('Raised ')
       else
         err('Exception ');
       itox(signum, 2);
       err(' at eip=');
       itox(djgpp_exception_state_ptr^.__eip, 8);
    end
  else
    begin
       write(stderr, 'FPC ',en);
       err(' at eip=');
       itox(djgpp_exception_state_ptr^.__eip, 8);
    end;
  { Control-C should stop the program also !}
  {if (signum = $79) then
    begin
       errln('');
       exit(-1);
    end;}
  if ((signum < EXCEPTIONCOUNT) and (has_error[signum]=1)) then
   begin
     errorcode := djgpp_exception_state_ptr^.__sigmask and $ffff;
     if(errorcode<>0) then
      begin
        err(', error=');
        itox(errorcode, 4);
      end;
   end;
  errln('');
  err('eax=');
  itox(djgpp_exception_state_ptr^.__eax, 8);
  err(' ebx='); itox(djgpp_exception_state_ptr^.__ebx, 8);
  err(' ecx='); itox(djgpp_exception_state_ptr^.__ecx, 8);
  err(' edx='); itox(djgpp_exception_state_ptr^.__edx, 8);
  err(' esi='); itox(djgpp_exception_state_ptr^.__esi, 8);
  err(' edi='); itox(djgpp_exception_state_ptr^.__edi, 8);
  errln('');
  err('ebp='); itox(djgpp_exception_state_ptr^.__ebp, 8);
  err(' esp='); itox(djgpp_exception_state_ptr^.__esp, 8);
  err(' program=');
  errln(paramstr(0));
  dump_selector('cs', djgpp_exception_state_ptr^.__cs);
  dump_selector('ds', djgpp_exception_state_ptr^.__ds);
  dump_selector('es', djgpp_exception_state_ptr^.__es);
  dump_selector('fs', djgpp_exception_state_ptr^.__fs);
  dump_selector('gs', djgpp_exception_state_ptr^.__gs);
  dump_selector('ss', djgpp_exception_state_ptr^.__ss);
  errln('');
  if (djgpp_exception_state_ptr^.__cs = get_cs) then
    show_call_frame(djgpp_exception_state_ptr)
{$ifdef DPMIEXCP_DEBUG}
  else
    errln('Exception occured in another context');
{$endif def DPMIEXCP_DEBUG}
   ;
  if assigned(djgpp_exception_state_ptr^.__exception_ptr) then
    if (djgpp_exception_state_ptr^.__exception_ptr^.__cs = get_cs) then
    begin
       Errln('First exception level stack');
       show_call_frame(djgpp_exception_state_ptr^.__exception_ptr);
    end
{$ifdef DPMIEXCP_DEBUG}
  else
    begin
       errln('First exception occured in another context');
       djgpp_exception_state_ptr:=djgpp_exception_state_ptr^.__exception_ptr;
       do_faulting_finish_message(false);
    end;
{$endif def DPMIEXCP_DEBUG}
   ;
  { must not return !! }
simple_exit:
  if exceptions_on then
    djgpp_exception_toggle;
  ___exit(-1);
end;
{$endif CREATE_C_FUNCTIONS}

function djgpp_exception_state:pexception_state;assembler;
asm
        movl    djgpp_exception_state_ptr,%eax
end;


{$ifdef CREATE_C_FUNCTIONS}
procedure djgpp_exception_processor;[public,alias : '___djgpp_exception_processor'];
var
  sig : longint;
begin
  if not assigned(djgpp_exception_state_ptr^.__exception_ptr) then
    exception_level:=1
  else
    inc(exception_level);

  sig:=djgpp_exception_state_ptr^.__signum;

  if (exception_level=1) or (sig=$78) then
    begin
       sig := except_to_sig(sig);
       if signal_list[djgpp_exception_state_ptr^.__signum]
          <>SignalHandler(@SIG_DFL) then
         _raise(djgpp_exception_state_ptr^.__signum)
       else
         _raise(sig);
       if (djgpp_exception_state_ptr^.__signum >= EXCEPTIONCOUNT) then
         {  Not exception so continue OK }
         dpmi_longjmp(pdpmi_jmp_buf(djgpp_exception_state_ptr)^, djgpp_exception_state_ptr^.__eax);
       { User handler did not exit or longjmp, we must exit }
       err('FPC cannot continue from exception, exiting due to signal ');
       itox(sig, 4);
       errln('');
    end
  else
    begin
       if exception_level>2 then
         begin
            errln('FPC triple exception, exiting !!! ');
            if (exceptions_on) then
              djgpp_exception_toggle;
            ___exit(1);
         end;
       err('FPC double exception, exiting due to signal ');
       itox(sig, 4);
       errln('');
    end;
  do_faulting_finish_message(djgpp_exception_state<>nil);
end;


type
  trealseginfo = tseginfo;
  pseginfo = ^tseginfo;
var
  except_ori : array [0..EXCEPTIONCOUNT-1] of tseginfo;
{$ifdef DPMIEXCP_DEBUG}
   export name '_ori_exceptions';
{$endif def DPMIEXCP_DEBUG}
  kbd_ori    : tseginfo;
  npx_ori    : tseginfo;
  cbrk_ori,
  cbrk_rmcb  : trealseginfo;
  cbrk_regs  : trealregs;
  v2prt0_exceptions_on : longbool;external name '_v2prt0_exceptions_on';


procedure djgpp_exception_toggle;
[public,alias : '___djgpp_exception_toggle'];
var
  _except : tseginfo;
  i : longint;
begin
{$ifdef DPMIEXCP_DEBUG}
  if exceptions_on then
   errln('Disabling FPC exceptions')
  else
   errln('Enabling FPC exceptions');
{$endif DPMIEXCP_DEBUG}
  { toggle here to avoid infinite recursion }
  { if a subfunction calls runerror !!      }
  exceptions_on:=not exceptions_on;
  v2prt0_exceptions_on:=exceptions_on;
  for i:=0 to EXCEPTIONCOUNT-1 do
   begin
     if get_pm_exception_handler(i,_except) then
      begin
        if (i <> 2) {or (_crt0_startup_flags & _CRT0_FLAG_NMI_SIGNAL))} then
         begin
           if not set_pm_exception_handler(i,except_ori[i]) then
            errln('error setting exception n�'+hexstr(i,2));
         end;
        except_ori[i]:=_except;
      end
     else
      begin
        if get_exception_handler(i,_except) then
         begin
           if (i <> 2) {or (_crt0_startup_flags & _CRT0_FLAG_NMI_SIGNAL))} then
            begin
              if not set_exception_handler(i,except_ori[i]) then
               errln('error setting exception n�'+hexstr(i,2));
            end;
           except_ori[i]:=_except;
         end;
      end;
   end;
  get_pm_interrupt($75,_except);
  set_pm_interrupt($75,npx_ori);
  npx_ori:=_except;
  get_pm_interrupt(9,_except);
  set_pm_interrupt(9,kbd_ori);
  kbd_ori:=_except;
  if (cbrk_hooked) then
   begin
     set_rm_interrupt(cbrk_vect,cbrk_ori);
     free_rm_callback(cbrk_rmcb);
     cbrk_hooked := false;
{$ifdef DPMIEXCP_DEBUG}
     errln('back to ori rm cbrk  '+hexstr(cbrk_ori.segment,4)+':'+hexstr(longint(cbrk_ori.offset),4));
{$endif DPMIEXCP_DEBUG}
   end
  else
   begin
     get_rm_interrupt(cbrk_vect, cbrk_ori);
{$ifdef DPMIEXCP_DEBUG}
     errln('ori rm cbrk  '+hexstr(cbrk_ori.segment,4)+':'+hexstr(longint(cbrk_ori.offset),4));
{$endif DPMIEXCP_DEBUG}
     get_rm_callback(@djgpp_cbrk_hdlr, cbrk_regs, cbrk_rmcb);
     set_rm_interrupt(cbrk_vect, cbrk_rmcb);
{$ifdef DPMIEXCP_DEBUG}
     errln('now rm cbrk  '+hexstr(cbrk_rmcb.segment,4)+':'+hexstr(longint(cbrk_rmcb.offset),4));
{$endif DPMIEXCP_DEBUG}
     cbrk_hooked := true;
   end;
end;
{$endif CREATE_C_FUNCTIONS}

function dpmi_set_coprocessor_emulation(flag : longint) : longint;
var
  res : longint;
begin
  asm
        movl    flag,%ebx
        movl    $0xe01,%eax
        int     $0x31
        jc      .L_coproc_error
        xorl    %eax,%eax
.L_coproc_error:
        movl    %eax,res
  end;
  dpmi_set_coprocessor_emulation:=res;
end;


var
  _swap_in  : pointer;external name '_swap_in';
  _swap_out : pointer;external name '_swap_out';
  _exception_exit : pointer;external name '_exception_exit';

{$ifdef CREATE_C_FUNCTIONS}
procedure dpmiexcp_exit{(status : longint)};[public,alias : 'excep_exit'];
{ We need to restore hardware interrupt handlers even if somebody calls
  `_exit' directly, or else we crash the machine in nested programs.
  We only toggle the handlers if the original keyboard handler is intact
  (otherwise, they might have already toggled them). }
begin
  if (exceptions_on) then
    djgpp_exception_toggle;
  _exception_exit:=nil;
  _swap_in:=nil;
  _swap_out:=nil;
  { restore the FPU state }
  dpmi_set_coprocessor_emulation(1);
end;

{ _exit in dpmiexcp.c
  is already present in v2prt0.as  PM}

{ used by dos.pp for swap vectors }
procedure dpmi_swap_in;[public,alias : 'swap_in'];
begin
  if not (exceptions_on) then
   djgpp_exception_toggle;
end;


procedure dpmi_swap_out;[public,alias : 'swap_out'];
begin
  if (exceptions_on) then
   djgpp_exception_toggle;
end;

{$else CREATE_C_FUNCTIONS}
procedure dpmiexcp_exit;external name 'excep_exit';
procedure dpmi_swap_in;external name 'swap_in';
procedure dpmi_swap_out;external name 'swap_out';
{$endif CREATE_C_FUNCTIONS}

var
  ___djgpp_app_DS : word;external name '___djgpp_app_DS';
  ___djgpp_our_DS : word;external name '___djgpp_our_DS';

{$ifdef CREATE_C_FUNCTIONS}
  __djgpp_sigint_mask : word;external name '___djgpp_sigint_mask';
  __djgpp_sigint_key  : word;external name '___djgpp_sigint_key';
  __djgpp_sigquit_mask : word;external name '___djgpp_sigquit_mask';
  __djgpp_sigquit_key  : word;external name '___djgpp_sigquit_key';
{ to avoid loading of C lib version of dpmiexcp
  I need to have all exported assembler labels
  of dpmiexcp.c in this unit.
  DJGPP v2.03 add to new functions:
  __djgpp_set_sigint_key
  __djgpp_set_sigquit_key
  that I implement here simply translating C code PM }
Const
  LSHIFT = 1;
  RSHIFT = 2;
  CTRL   = 4;
  ALT    = 8;
  DEFAULT_SIGINT  = $042e; { Ctrl-C: scan code 2Eh, kb status 04h }
  DEFAULT_SIGQUIT = $042b; { Ctrl-\: scan code 2Bh, kb status 04h }
  DEFAULT_SIGINT_98  = $042b; { Ctrl-C: scan code 2Bh, kb status 04h }
  DEFAULT_SIGQUIT_98 = $040d; { Ctrl-\: scan code 0Dh, kb status 04h }

{ Make it so the key NEW_KEY will generate the signal SIG.
   NEW_KEY must include the keyboard status byte in bits 8-15 and the
   scan code in bits 0-7.  }
function set_signal_key(sig,new_key : longint) : longint;
  type
    pword = ^word;
  var
    old_key : longint;
    mask,key : pword;
    kb_status : word;

  begin
    if (sig = SIGINT) then
      begin
        mask := @__djgpp_sigint_mask;
        key  := @__djgpp_sigint_key;
      end
    else if (sig = SIGQUIT) then
      begin
        mask := @__djgpp_sigquit_mask;
        key  := @__djgpp_sigquit_key;
      end
    else
      exit(-1);

    old_key := key^;
    key^ := new_key and $ffff;
    kb_status := key^ shr 8;
    mask^ := $f;      { Alt, Ctrl and Shift bits only }
    {  Mask off the RShift bit unless they explicitly asked for it.
       Our keyboard handler pretends that LShift is pressed when they
       press RShift.  }
    if ((kb_status and RSHIFT) = 0) then
      mask^ :=mask^ and not RSHIFT;
    {  Mask off the LShift bit if any of the Ctrl or Alt are set
       since Shift doesn't matter when Ctrl and/or Alt are pressed.  }
    if (kb_status and (CTRL or ALT))<>0 then
      mask^:= mask^ and not LSHIFT;

    exit(old_key);
  end;

function __djgpp_set_sigint_key(new_key : longint) : longint;cdecl;
begin
  __djgpp_set_sigint_key:=set_signal_key(SIGINT, new_key);
end;

function __djgpp_set_sigquit_key(new_key : longint) : longint;cdecl;
begin
  __djgpp_set_sigquit_key:=set_signal_key(SIGQUIT, new_key);
end;

function __djgpp__traceback_exit(sig : longint) : longint;cdecl;
var
  fake_exception : texception_state;
begin
  if (sig >= SIGABRT) and (sig <= SIGTRAP) then
    begin
      if djgpp_exception_state_ptr=nil then
        begin
        { This is a software signal, like SIGABRT or SIGKILL.
           Fill the exception structure, so we get the traceback.  }
          djgpp_exception_state_ptr:=@fake_exception;
          if (dpmi_setjmp(pdpmi_jmp_buf(djgpp_exception_state_ptr)^)<>0) then
            begin
              errln('Bad longjmp to __djgpp_exception_state--aborting');
              do_faulting_finish_message(true); { does not return }
            end
          else
            { Fake the exception number.  7Ah is the last one hardwired
              inside exceptn.S, for SIGQUIT.  }
            djgpp_exception_state_ptr^.__signum:=$7a + 1 + sig - SIGABRT;
        end;
    end;
  print_signal_name(sig);
  if assigned(djgpp_exception_state_ptr) then
    { This exits, does not return.  }
    do_faulting_finish_message(djgpp_exception_state_ptr=@fake_exception);
  ___exit(-1);
end;

procedure djgpp_exception_setup;
[alias : '___djgpp_exception_setup'];
var
  temp_kbd,
  temp_npx    : pointer;
  _except,
  old_kbd     : tseginfo;
  locksize    : longint;
  i           : longint;
begin
  if assigned(_exception_exit) then
   exit;
  if (go32_info_block.linear_address_of_primary_screen <> $a0000) then
    begin
      __djgpp_set_sigint_key(DEFAULT_SIGINT);
      __djgpp_set_sigquit_key(DEFAULT_SIGQUIT);
    end
  else
    begin  { for PC98 }
      __djgpp_set_sigint_key(DEFAULT_SIGINT_98);
      __djgpp_set_sigquit_key(DEFAULT_SIGQUIT_98);
    end;
  _exception_exit:=@dpmiexcp_exit;
  _swap_in:=@dpmi_swap_in;
  _swap_out:=@dpmi_swap_out;
{ reset signals }
  for i := 0 to  SIGMAX do
   signal_list[i] := SignalHandler(@SIG_DFL);
{ app_DS only used when converting HW interrupts to exceptions }
  asm
        movw    %ds,___djgpp_app_DS
        movw    %ds,___djgpp_our_DS
  end;
  djgpp_dos_sel:=dosmemselector;
{ lock addresses which may see HW interrupts }
  lock_code(@djgpp_hw_lock_start,@djgpp_hw_lock_end-@djgpp_hw_lock_start);
  _except.segment:=get_cs;
  _except.offset:=@djgpp_exception_table;
  for i:=0 to ExceptionCount-1 do
   begin
     except_ori[i] := _except;    { New value to set }
     inc(_except.offset,4);       { This is the size of push n, jmp }
   end;
  kbd_ori.segment:=_except.segment;
  npx_ori.segment:=_except.segment;
  npx_ori.offset:=@djgpp_npx_hdlr;
  if (go32_info_block.linear_address_of_primary_screen <> $a0000) then
   kbd_ori.offset:=@djgpp_kbd_hdlr
  else
   begin
     kbd_ori.offset:=@djgpp_kbd_hdlr_pc98;
     cbrk_vect := $06;
     _except.offset:=@djgpp_iret;
     set_pm_interrupt($23,_except);
   end;
  _except.offset:=@djgpp_i24;
  set_pm_interrupt($24, _except);
  get_pm_interrupt(9,djgpp_old_kbd);
  djgpp_exception_toggle;    { Set new values & save old values }
{ get original video mode and save }
  old_video_mode := farpeekb(dosmemselector, $449);
end;
{$endif CREATE_C_FUNCTIONS}


function djgpp_set_ctrl_c(enable : boolean) : boolean;
begin
  djgpp_set_ctrl_c:=(djgpp_hwint_flags and 1)=0;
  if enable then
   djgpp_hwint_flags:=djgpp_hwint_flags and (not 1)
  else
   djgpp_hwint_flags:=djgpp_hwint_flags or 1;
end;


{$ifdef CREATE_C_FUNCTIONS}
function c_djgpp_set_ctrl_c(enable : longint) : boolean;cdecl;[public,alias : '___djgpp_set_ctrl_c'];
begin
  c_djgpp_set_ctrl_c:=djgpp_set_ctrl_c(boolean(enable));
end;
{$endif def CREATE_C_FUNCTIONS}


{$ifdef IN_DPMIEXCP_UNIT}
procedure ResetDefaultHandlers;
begin
  Signal(SIGSEGV,@SIG_DFL);
  Signal(SIGFPE,@SIG_DFL);
  Signal(SIGNOFP,@SIG_DFL);
  Signal(SIGTRAP,@SIG_DFL);
  Signal(SIGTIMR,@SIG_DFL);
  Signal(SIGINT,@SIG_DFL);
  Signal(SIGQUIT,@SIG_DFL);
  Signal(SIGILL,@SIG_DFL);
end;
{$endif IN_DPMIEXCP_UNIT}

procedure InitDPMIExcp;
begin
{$ifdef CREATE_C_FUNCTIONS}
  djgpp_ds_alias:=v2prt0_ds_alias;
  djgpp_exception_setup;
{$endif CREATE_C_FUNCTIONS}
end;

{$ifndef IN_SYSTEM}

begin
{$ifdef CREATE_C_FUNCTIONS}
  InitDPMIExcp;
{$else not CREATE_C_FUNCTIONS}
  ResetDefaultHandlers;
{$endif CREATE_C_FUNCTIONS}
end.
{$else IN_SYSTEM}

function HandleException(sig : longint) : longint;
var
  truesig : longint;
  ErrorOfSig : longint;
begin
  if assigned(djgpp_exception_state_ptr) then
    truesig:=djgpp_exception_state_ptr^.__signum
  else
    truesig:=sig;
  ErrorOfSig:=0;
  case truesig of
   {exception_names : array[0..EXCEPTIONCOUNT-1] of pchar = (}
   0 : ErrorOfSig:=200;    {'Division by Zero'}
   5 : ErrorOfSig:=201;    {'Bounds Check'}
   12 : ErrorOfSig:=202;   {'Stack Fault'}
   7,                      {'Coprocessor not available'}
   9,                      {'Coprocessor overrun'}
   SIGFPE,SIGNOFP : ErrorOfSig:=207;
   16 : begin
         { This needs special handling }
         { to discriminate between 205,206 and 207 }
         ErrorOfSig:=207;  {'Coprocessor Error'}
        end;
   4 : ErrorOfSig:=215;    {'Overflow'}
   1,                      {'Debug'}
   2,                      {'NMI'}
   3,                      {'Breakpoint'}
   6,                      {'Invalid Opcode'}
   8,                      {'Double Fault'}
   10,                     {'Invalid TSS'}
   11,                     {'Segment Not Present'}
   13,                     {'General Protection Fault'}
   14,                     {'Page fault'}
   15,                     {' ',}
   17,                     {'Alignment Check');}
   SIGSEGV,SIGTRAP,SIGTIMR,SIGINT,SIGQUIT
    : ErrorOfSig:=216;
  end;
  if assigned(djgpp_exception_state_ptr) then
    Begin
      HandleErrorAddrFrame(ErrorOfSig,
        djgpp_exception_state_ptr^.__eip,
        djgpp_exception_state_ptr^.__ebp);
    End
  else
    { probably higher level is required }
    HandleErrorFrame(ErrorOfSig,get_caller_frame(get_frame));
  HandleException:=0;
end;

procedure InstallDefaultHandlers;
begin
  Signal(SIGSEGV,@HandleException);
  Signal(SIGFPE,@HandleException);
  Signal(SIGNOFP,@HandleException);
  Signal(SIGTRAP,@HandleException);
  Signal(SIGTIMR,@HandleException);
  Signal(SIGINT,@HandleException);
  Signal(SIGQUIT,@HandleException);
  Signal(SIGILL,@HandleException);
end;
{$endif IN_SYSTEM}
{
  $Log$
  Revision 1.13  2000-03-10 09:53:17  pierre
   * some clean up for exceptions in system

  Revision 1.12  2000/03/09 09:15:10  pierre
    + support for djgpp v2.03 (added some new functions that are in v2.03 ofdpmiexcp.c)
    + code to integrate exception support inside the system unit

  Revision 1.10  2000/01/10 12:14:57  pierre
   * add $goto on to avoid problems

  Revision 1.9  2000/01/07 16:41:31  daniel
    * copyright 2000

  Revision 1.8  2000/01/07 16:32:23  daniel
    * copyright 2000 added

  Revision 1.7  1999/03/01 15:40:49  peter
    * use external names
    * removed all direct assembler modes

  Revision 1.6  1999/02/05 12:49:25  pierre
   <> debug conditionnal renamed DPMIEXCP_DEBUG

  Revision 1.5  1999/01/22 15:46:33  pierre
   * PsignalHandler is now a pointer as changed in linux.pp

  Revision 1.4  1999/01/22 12:39:19  pierre
   + added text arg for dump_stack

  Revision 1.3  1999/01/18 09:14:20  pierre
   * exception_level counting was wrong if dpmi_jmp_buf was copied

  Revision 1.2  1998/12/21 14:23:12  pierre
  dpmiexcp.pp

  Revision 1.1  1998/12/21 13:07:02  peter
    * use -FE

  Revision 1.11  1998/11/17 09:42:50  pierre
   * position check of signal handler was wrong

  Revision 1.10  1998/10/13 21:42:42  peter
    * cleanup and use of external var
    * fixed ctrl-break crashes

  Revision 1.9  1998/08/20 08:08:36  pierre
    * dpmiexcp did not compile with older versions
      due to the proc to procvar bug
    * makefile separator problem fixed

  Revision 1.8  1998/08/19 10:56:33  pierre
    + added some special code for C interface
      to avoid loading of crt1.o or dpmiexcp.o from the libc.a

  Revision 1.7  1998/08/15 17:01:13  peter
    * smartlinking the units works now
    * setjmp/longjmp -> dmpi_setjmp/dpmi_longjmp to solve systemunit
      conflict

  Revision 1.6  1998/08/04 13:31:32  pierre
    * changed all FPK into FPC

  Revision 1.5  1998/07/08 12:02:19  carl
    * make it compiler under fpc v0995

  Revision 1.4  1998/06/26 08:19:08  pierre
    + all debug in ifdef SYSTEMDEBUG
    + added local arrays :
      opennames names of opened files
      fileopen boolean array to know if still open
      usefull with gdb if you get problems about too
      many open files !!

  Revision 1.3  1998/05/31 14:18:23  peter
    * force att or direct assembling
    * cleanup of some files

  Revision 1.2  1998/04/21 14:46:33  pierre
    + debug info better output
      no normal code changed
}