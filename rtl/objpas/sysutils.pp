{
    $Id$
    This file is part of the Free Pascal run time library.
    Copyright (c) 1998 by Florian Klaempfl
    member of the Free Pascal development team

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}
unit sysutils;
interface

{$MODE objfpc}

    uses
    {$ifdef linux}
       linux
    {$else}
       dos
      {$ifdef go32v2}
         ,go32
      {$endif go32v2}
    {$endif linux}
    {$ifndef AUTOOBJPAS}
       ,objpas
    {$endif}   
       ;


    type
       { some helpful data types }

       tprocedure = procedure;

       tfilename = string;

       longrec = packed record
          lo,hi : word;
       end;

       wordrec = packed record
          lo,hi : byte;
       end;

       { exceptions }
       exception = class(TObject)
        private
          fmessage : string;
          fhelpcontext : longint;
        public
          constructor create(const msg : string);
{$ifdef autoobjpas}
          constructor createfmt(const msg : string; const args : array of const);
{$endif}          
          constructor createres(ident : longint);
          { !!!! }
          property helpcontext : longint read fhelpcontext write fhelpcontext;
          property message : string read fmessage write fmessage;
       end;

       exceptclass = class of exception;

       { integer math exceptions }
       EInterror    = Class(Exception);
       EDivByZero   = Class(EIntError);
       ERangeError  = Class(EIntError);
       EIntOverflow = Class(EIntError);

       { General math errors }
       EMathError  = Class(Exception);
       EInvalidOp  = Class(EMathError);
       EZeroDivide = Class(EMathError);
       EOverflow   = Class(EMathError);
       EUnderflow  = Class(EMathError);
       
       { Run-time and I/O Errors }
       EInOutError = class(Exception)
         public
         ErrorCode : Longint;
         end;
       EInvalidPointer  = Class(Exception);
       EOutOfMemory     = Class(Exception);
       EAccessViolation = Class(Exception);
       EInvalidCast = Class(Exception);
       
       
       { String conversion errors }
       EConvertError = class(Exception);

       { Other errors } 
       EAbort           = Class(Exception);
       EAbstractError   = Class(Exception);
       EAssertionFailed = Class(Exception);
       
  { Read date & Time function declarations }
  {$i datih.inc}

  { Read String Handling functions declaration }
  {$i sysstrh.inc}

  { Read pchar handling functions declration }
  {$i syspchh.inc}

  { Read filename handling functions declaration }
  {$i finah.inc}

  { Read other file handling function declarations }
  {$i filutilh.inc}
  
  implementation
  
  { Read message string definitions }
  { 
   Add a language with IFDEF LANG_NAME
   just befor the final ELSE. This way English will always be the default.
  }

  {$IFDEF LANG_GERMAN}
  {$i strg.inc} // Does not exist yet !!
  {$ELSE}
  {$i stre.inc}
  {$ENDIF}

  { Read filename handling functions implementation }
  {$i fina.inc}

  { Read other file handling function implementations }
  {$i filutil.inc}
  
  { Read date & Time function implementations }
  {$i dati.inc}

  { Read String Handling functions implementation }
  {$i sysstr.inc}

  { Read pchar handling functions implementation }
  {$i syspch.inc}


    constructor exception.create(const msg : string);

      begin
         inherited create;
         fmessage:=msg;
      end;

{$ifdef autoobjpas}
    constructor exception.createfmt(const msg : string; const args : array of const);

      begin
         inherited create;
         fmessage:=Format(msg,args);
      end;
{$endif}

    constructor exception.createres(ident : longint);

      begin
         inherited create;
         {!!!!!}
      end;

       
Procedure CatchUnhandledException (Obj : TObject; Addr: Pointer);    
Var
  Message : String;
begin
{$ifndef USE_WINDOWS}
  Writeln ('An unhandled exception occurred at ',HexStr(Longint(Addr),8),' : ');
  if Obj is exception then
   begin
     Message:=Exception(Obj).Message;
     Writeln (Message);
   end
  else
   Writeln ('Exception object ',Obj.ClassName,' is not of class Exception.');
  Halt(217);
{$else}
{$endif}
end;


Var OutOfMemory : EOutOfMemory;
    InValidPointer : EInvalidPointer;
    

Procedure RunErrorToExcept (ErrNo : Longint; Address : Pointer);

Var E : Exception;
    S : String;
    
begin
  Case Errno of
   1,203 : E:=OutOfMemory;
   //!! ?? 2 is a 'file not found error' ??
   2,204 : E:=InvalidPointer;
   3,4,5,6,100,101,102,103,105,106 : { I/O errors }
     begin
     Case Errno of
       3 : S:=SInvalidFileName;
       4 : S:=STooManyOpenFiles;
       5 : S:=SAccessDenied;
       6 : S:=SInvalidFileHandle;
       15 : S:=SInvalidDrive;
       100 : S:=SEndOfFile;
       101 : S:=SDiskFull;
       102 : S:=SFileNotAssigned;
       103 : S:=SFileNotOpen;
       104 : S:=SFileNotOpenForInput;
       105 : S:=SFileNotOpenForOutput;
       106 : S:=SInvalidInput;
     end;
     E:=EinOutError.Create (S);
     EInoutError(E).ErrorCode:=IOresult; // Clears InOutRes !!
     end;
  // We don't set abstracterrorhandler, but we do it here. 
  // Unless the use sets another handler we'll get here anyway...
  200 : E:=EDivByZero.Create(SDivByZero);
  201 : E:=ERangeError.Create(SRangeError);  
  211 : E:=EAbstractError.Create(SAbstractError);
  216 : E:=EAccessViolation.Create(SAccessViolation);
  219 : E:=EInvalidCast.Create(SInvalidCast);
  227 : E:=EAssertionFailed.Create(SAssertionFailed);
  else
{$ifdef autoobjpas}
   E:=Exception.CreateFmt (SUnKnownRunTimeError,[Errno]);
{$else}
   E:=Exception.Create(SUnknownRunTimeError);
{$endif}
  end;
  Raise E {at Address};
end;

{$ifdef autoobjpas}
Procedure AssertErrorHandler (Const Msg,FN : String;LineNo,TheAddr : Longint);

Var S: String;

begin
  If Msg='' then 
    S:=SAssertionFailed
  else
    S:=Msg;
  Raise EAssertionFailed.Createfmt(SAssertError,[S,Fn,LineNo]); // at Pointer(theAddr);
end;
{$endif}

Procedure InitExceptions;
{
  Must install uncaught exception handler (ExceptProc)
  and install exceptions for system exceptions or signals.
  (e.g: SIGSEGV -> ESegFault or so.)
}
begin
  ExceptProc:=@CatchUnhandledException;
  // Create objects that may have problems when there is no memory.
  OutOfMemory:=EOutOfMemory.Create(SOutOfMemory);
  InvalidPointer:=EInvalidPointer.Create(SInvalidPointer);
{$ifdef autoobjpas}  
  AssertErrorProc:=@AssertErrorHandler;
{$endif}
  ErrorProc:=@RunErrorToExcept;
end;


{Initialization code.}
begin
  InitExceptions;
end.
{
    $Log$
    Revision 1.16  1998-10-11 12:23:41  michael
    + More sysutils calls.

    Revision 1.15  1998/10/10 09:53:10  michael
    Added assertion handling

    Revision 1.14  1998/10/03 15:08:05  florian
      * EInvalidCast added (from runerror 219)

    Revision 1.13  1998/10/02 13:00:11  michael
    + More RTL error handling

    Revision 1.12  1998/10/02 12:17:18  michael
    + Made sure it compiles with official 0.99.8

    Revision 1.11  1998/10/01 16:04:11  michael
    + Added RTL error handling

    Revision 1.10  1998/09/24 23:45:27  peter
      * updated for auto objpas loading

    Revision 1.9  1998/09/24 16:13:49  michael
    Changes in exception and open array handling

    Revision 1.8  1998/09/18 23:57:26  michael
    * Changed use_excepions to useexceptions

    Revision 1.7  1998/09/16 14:34:38  pierre
      * go32v2 did not compile
      * wrong code in systr.inc corrected

    Revision 1.6  1998/09/16 08:28:44  michael
    Update from gertjan Schouten, plus small fix for linux

    Revision 1.5  1998/09/04 08:49:07  peter
      * 0.99.5 doesn't compile a whole objpas anymore to overcome crashes

    Revision 1.4  1998/08/10 15:52:27  peter
      * fixed so 0.99.5 compiles it, but no exception class

    Revision 1.3  1998/07/29 15:44:32  michael
     included sysutils and math.pp as target. They compile now.
}
