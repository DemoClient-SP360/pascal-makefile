{
    $Id$
    This file is part of the Free Pascal run time library.
    Copyright (c) 2003 by Florian Klaempfl
    member of the Free Pascal development team

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}
{$mode objfpc}
{$H+}
unit sysconst;

interface

resourcestring

{ from old str*.inc files }

  SAbortError            = 'Operation aborted';
  SAbstractError         = 'Abstract method called';
  SAccessDenied          = 'Access denied';
  SAccessViolation       = 'Access violation';
  SArgumentMissing       = 'Missing argument in format "%s"';
  SAssertError           = '%s (%s, line %d)';
  SAssertionFailed       = 'Assertion failed';
  SControlC              = 'Control-C hit';
  SDiskFull              = 'Disk Full';
  SDispatchError         = 'No variant method call dispatch';
  SDivByZero             = 'Division by zero';
  SEndOfFile             = 'Read past end of file';
  SErrInvalidDateMonthWeek = 'Year %d, month %d, Week %d and day %d is not a valid date.';
  SErrInvalidDateWeek    = '%d %d %d is not a valid dateweek';
  SErrInvalidDayOfWeek   = '%d is not a valid day of the week';
  SErrInvalidDayOfWeekInMonth = 'Year %d Month %d NDow %d DOW %d is not a valid date';
  SErrInvalidDayOfYear   = 'Year %d does not have a day number %d';
  SErrInvalidTimeStamp   = 'Invalid date/timestamp : "%s"';
  SExceptionErrorMessage = 'exception at %p';
  SExceptionStack        = 'Exception stack error';
  SExecuteProcessFailed  = 'Failed to execute %s : %d';
  SExternalException     = 'External exception %x';
  SFileNotAssigned       = 'File not assigned';
  SFileNotFound          = 'File not found';
  SFileNotOpen           = 'File not open';
  SFileNotOpenForInput   = 'File not open for input';
  SFileNotOpenForOutput  = 'File not open for output';
  SInValidFileName       = 'Invalid filename';
  SIntOverflow           = 'Arithmetic overflow';
  SIntfCastError         = 'Interface not supported';
  SInvalidArgIndex       = 'Invalid argument index in format "%s"';
  SInvalidBoolean        = '"%s" is not a valid boolean.';
  SInvalidCast           = 'Invalid type cast';
  SinvalidCurrency       = 'Invalid currency: "%s"';
  SInvalidDateTime       = '%f is not a valid date/time value.';
  SInvalidDrive          = 'Invalid drive specified';
  SInvalidFileHandle     = 'Invalid file handle';
  SInvalidFloat          = '"%s" is an invalid float';
  SInvalidFormat         = 'Invalid format specifier : "%s"';
  SInvalidGUID           = '"%s" is not a valid GUID value';
  SInvalidInput          = 'Invalid input';
  SInvalidInteger        = '"%s" is an invalid integer';
  SInvalidOp             = 'Invalid floating point operation';
  SInvalidPointer        = 'Invalid pointer operation';
  SInvalidVarCast        = 'Invalid variant type case';
  SInvalidVarNullOp      = 'Invalid NULL variant operation';
  SInvalidVarOp          = 'Invalid variant operation';
  SInvalidVarOpWithHResultWithPrefix = 'Invalid variant operation (%s%.8x)'+LineEnding+'%s';
  SNoError               = 'No error.';
  SNoThreadSupport       = 'Threads not supported. Recompile program with thread driver.';
  SOSError               = 'System error, (OS Code %d):'+LineEnding+'%s';
  SOutOfMemory           = 'Out of memory';
  SOverflow              = 'Floating point overflow';
  SPrivilege             = 'Privileged instruction';
  SRangeError            = 'Range check error';
  SSafecallException     = 'Exception in safecall method';
  STooManyOpenFiles      = 'Too many open files';
  SUnKnownRunTimeError   = 'Unknown Run-Time error : %3.3d';
  SUnderflow             = 'Floating point underflow';
  SUnkOSError            = 'An operating system call failed.';
  SUnknown               = 'Unknown run-time error code: ';
  SUnknownErrorCode      = 'Unknown error code: %d';
  SVarArrayBounds        = 'Variant array bounds error';
  SVarArrayCreate        = 'Variant array cannot be created';
  SVarArrayLocked        = 'Variant array locked';
  SVarBadType            = 'Invalid variant type';
  SVarInvalid            = 'Invalid argument';
  SVarNotArray           = 'Variant doesn''t contain an array';
  SVarNotImplemented     = 'Operation not supported';
  SVarOutOfMemory        = 'Variant operation ran out memory';
  SVarOverflow           = 'Variant overflow';
  SVarParamNotFound      = 'Variant Parameter not found';
  SVarTypeAlreadyUsedWithPrefix = 'Custom variant type (%s%.4x) already used by %s';
  SVarTypeConvertOverflow       = 'Overflow while converting variant of type (%s) into type (%s)';
  SVarTypeCouldNotConvert       = 'Could not convert variant of type (%s) into type (%s)';
  SVarTypeNotUsableWithPrefix   = 'Custom variant type (%s%.4x) is not usable';
  SVarTypeOutOfRangeWithPrefix  = 'Custom variant type (%s%.4x) is out of range';
  SVarTypeRangeCheck1           = 'Range check error for variant of type (%s)';
  SVarTypeRangeCheck2           = 'Range check error while converting variant of type (%s) into type (%s)';
  SVarTypeTooManyCustom         = 'Too many custom variant types have been registered';
  SVarUnexpected                = 'Unexpected variant error';
      
  SNoToolserver                 = 'Toolserver is not installed, cannot execute Tool';

  SShortMonthNameJan = 'Jan';
  SShortMonthNameFeb = 'Feb';
  SShortMonthNameMar = 'Mar';
  SShortMonthNameApr = 'Apr';
  SShortMonthNameMay = 'May';
  SShortMonthNameJun = 'Jun';
  SShortMonthNameJul = 'Jul';
  SShortMonthNameAug = 'Aug';
  SShortMonthNameSep = 'Sep';
  SShortMonthNameOct = 'Oct';
  SShortMonthNameNov = 'Nov';
  SShortMonthNameDec = 'Dec';

  SLongMonthNameJan = 'January';
  SLongMonthNameFeb = 'February';
  SLongMonthNameMar = 'March';
  SLongMonthNameApr = 'April';
  SLongMonthNameMay = 'May';
  SLongMonthNameJun = 'June';
  SLongMonthNameJul = 'July';
  SLongMonthNameAug = 'August';
  SLongMonthNameSep = 'September';
  SLongMonthNameOct = 'October';
  SLongMonthNameNov = 'November';
  SLongMonthNameDec = 'December';

  SShortDayNameMon = 'Mon';
  SShortDayNameTue = 'Tue';
  SShortDayNameWed = 'Wed';
  SShortDayNameThu = 'Thu';
  SShortDayNameFri = 'Fri';
  SShortDayNameSat = 'Sat';
  SShortDayNameSun = 'Sun';

  SLongDayNameMon = 'Monday';
  SLongDayNameTue = 'Tuesday';
  SLongDayNameWed = 'Wednesday';
  SLongDayNameThu = 'Thursday';
  SLongDayNameFri = 'Friday';
  SLongDayNameSat = 'Saturday';
  SLongDayNameSun = 'Sunday';

Function GetRunError(Errno : Byte) : String;

Implementation

Function GetRunError(Errno : Byte) : String;

begin
  Case Errno Of
     0  : Result:=SNoError;
     1  : Result:=SOutOfMemory;
     2  : Result:=SFileNotFound;
     3  : Result:=SInvalidFileName;
     4  : Result:=STooManyOpenFiles;
     5  : Result:=SAccessDenied;
     6  : Result:=SInvalidFileHandle;
     15 : Result:=SInvalidDrive;
     100 : Result:=SEndOfFile;
     101 : Result:=SDiskFull;
     102 : Result:=SFileNotAssigned;
     103 : Result:=SFileNotOpen;
     104 : Result:=SFileNotOpenForInput;
     105 : Result:=SFileNotOpenForOutput;
     106 : Result:=SInvalidInput;
     200 : Result:=SDivByZero;
     201 : Result:=SRangeError;
     203 : Result:=SOutOfMemory;
     204 : Result:=SInvalidPointer;
     205 : Result:=SOverFlow;
     206 : Result:=SUnderFlow;
     207 : Result:=SInvalidOp;
     211 : Result:=SAbstractError;
     215 : Result:=SIntOverFlow;
     216 : Result:=SAccessViolation;
     217 : Result:=SPrivilege;
     218 : Result:=SControlC;
     219 : Result:=SInvalidCast;
     220 : Result:=SInvalidVarCast;
     221 : Result:=SInvalidVarOp;
     222 : Result:=SDispatchError;
     223 : Result:=SVarArrayCreate;
     224 : Result:=SVarNotArray;
     225 : Result:=SVarArrayBounds;
     227 : Result:=SAssertionFailed;
     228 : Result:=SExternalException;
     229 : Result:=SIntfCastError;
     230 : Result:=SSafecallException;
     231 : Result:=SExceptionStack;
     232 : Result:=SNoThreadSupport;

     {Error in the range 900 - 999 is considered platform specific}
//     900 : Result:=SNoToolserver;    {Mac OS specific}
  end;
  If length(Result)=0 then
{$ifdef VER1_0}  
    begin
      Str(Errno:3,Result);
      Result:=SUnknown+Result;
    end;
{$else}      
    Result:=SUnknown+Str(Errno:3);
{$endif}    
end;

end.
{
  $Log$
  Revision 1.12  2004-08-25 15:29:58  peter
    * disbaled error 900 that is out of range

  Revision 1.11  2004/08/20 10:18:58  olle
    + added error 900, for macos

  Revision 1.10  2004/06/12 13:23:17  michael
  + Fixed currency<->string conversion support

  Revision 1.9  2004/02/08 11:44:05  michael
  + OSERRor related constants

  Revision 1.8  2004/01/20 23:05:31  hajny
    * ExecuteProcess fixes, ProcessID and ThreadID added

  Revision 1.7  2004/01/10 19:35:17  michael
  + Moved all resource strings to rtlconst/sysconst

  Revision 1.6  2004/01/10 17:55:45  michael
  + Changed lookup table with Case: Array of resourcestring is not translated

  Revision 1.5  2003/11/30 15:04:56  michael
  + Removed old strings

  Revision 1.4  2003/11/27 20:39:43  michael
  + Added runerrors functionality to sysconst

  Revision 1.3  2003/11/26 20:34:19  michael
  + Some fixes to have everything compile again

  Revision 1.2  2003/11/26 20:00:19  florian
    * error handling for Variants improved

  Revision 1.1  2003/09/03 14:09:37  florian
    * arm fixes to the common rtl code
    * some generic math code fixed
    * ...
}