{
    $Id$
    Copyright (c) 1993-98 by Florian Klaempfl

    Commandline compiler for Free Pascal

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

 ****************************************************************************}

{
  possible compiler switches (* marks a currently required switch):
  -----------------------------------------------------------------
  USE_RHIDE           generates errors and warning in an format recognized
                      by rhide
  TP                  to compile the compiler with Turbo or Borland Pascal
  GDB*                support of the GNU Debugger
  I386                generate a compiler for the Intel i386+
  M68K                generate a compiler for the M68000
  USEOVERLAY          compiles a TP version which uses overlays
  EXTDEBUG            some extra debug code is executed
  SUPPORT_MMX         only i386: releases the compiler switch
                      MMX which allows the compiler to generate
                      MMX instructions
  EXTERN_MSG          Don't compile the msgfiles in the compiler, always
                      use external messagefiles, default for TP
  NOAG386INT          no Intel Assembler output
  NOAG386NSM          no NASM output
  NOAG386BIN          leaves out the binary writer, default for TP
  LOGMEMBLOCKS        adds memory manager which logs the size of
                      each allocated memory block, the information
                      is written to memuse.log after compiling
  -----------------------------------------------------------------

  Required switches for a i386 compiler be compiled by Free Pascal Compiler:
  GDB;I386

  Required switches for a i386 compiler be compiled by Turbo Pascal:
  GDB;I386;TP

  Required switches for a 68000 compiler be compiled by Turbo Pascal:
  GDB;M68k;TP
}

{$ifdef FPC}
   {$ifndef GDB}
      { people can try to compile without GDB }
      { $error The compiler switch GDB must be defined}
   {$endif GDB}
   { but I386 or M68K must be defined }
   { and only one of the two }
   {$ifndef I386}
      {$ifndef M68K}
        {$fatal One of the switches I386 or M68K must be defined}
      {$endif M68K}
   {$endif I386}
   {$ifdef I386}
      {$ifdef M68K}
        {$fatal ONLY one of the switches I386 or M68K must be defined}
      {$endif M68K}
   {$endif I386}
   {$ifdef support_mmx}
     {$ifndef i386}
       {$fatal I386 switch must be on for MMX support}
     {$endif i386}
   {$endif support_mmx}
{$endif}

{$ifdef TP}
  {$IFNDEF DPMI}
    {$M 24000,0,655360}
  {$ELSE}
    {$M 65000}
  {$ENDIF DPMI}
  {$E+,N+,F+,S-,R-}
{$endif TP}


program pp;

{$IFDEF TP}
  {$UNDEF PROFILE}
  {$IFDEF DPMI}
    {$UNDEF USEOVERLAY}
  {$ENDIF}
  {$DEFINE NOAG386BIN}
{$ENDIF}
{$ifdef FPC}
  {$UNDEF USEOVERLAY}
{$ENDIF}

uses
{$ifdef useoverlay}
  {$ifopt o+}
    Overlay,ppovin,
  {$else}
    {$error You must compile with the $O+ switch}
  {$endif}
{$endif useoverlay}
{$ifdef profile}
  profile,
{$endif profile}
{$ifdef FPC}
{$ifdef heaptrc}
  ppheap,
{$endif heaptrc}
{$ifdef linux}
  catch,
{$endif}
{$ifdef go32v2}
  catch,
{$endif}
{$endif FPC}
  globals,compiler
{$ifdef logmemblocks}
{$ifdef fpc}
  ,memlog
{$endif fpc}
{$endif logmemblocks}
  ;

{$ifdef useoverlay}
  {$O files}
  {$O globals}
  {$O hcodegen}
  {$O pass_1}
  {$O pass_2}
  {$O tree}
  {$O types}
  {$O objects}
  {$O options}
  {$O cobjects}
  {$O globals}
  {$O systems}
  {$O parser}
  {$O pbase}
  {$O pdecl}
  {$O pexports}
  {$O pexpr}
  {$O pmodules}
  {$O pstatmnt}
  {$O psub}
  {$O psystem}
  {$O ptconst}
  {$O script}
  {$O switches}
  {$O temp_gen}
  {$O comphook}
  {$O dos}
  {$O scanner}
  {$O symtable}
  {$O objects}
  {$O aasm}
  {$O link}
  {$O assemble}
  {$O messages}
  {$O gendef}
  {$O import}
{$ifdef i386}
  {$O os2_targ}
  {$O win_targ}
{$endif i386}
  {$ifdef gdb}
        {$O gdb}
  {$endif gdb}
  {$ifdef i386}
        {$O opts386}
        {$O cpubase}
        {$O cgai386}
        {$O tgeni386}
        {$O cg386add}
        {$O cg386cal}
        {$O cg386cnv}
        {$O cg386con}
        {$O cg386flw}
        {$O cg386ld}
        {$O cg386inl}
        {$O cg386mat}
        {$O cg386set}
        {$ifndef NOOPT}
          {$O aopt386}
        {$endif}
        {$IfNDef Nora386dir}
          {$O ra386dir}
        {$endif}
        {$IfNDef Nora386int}
          {$O ra386int}
        {$endif}
        {$IfNDef Nora386att}
          {$O ra386att}
        {$endif}
        {$ifndef NoAg386Int}
          {$O ag386int}
        {$endif}
        {$ifndef NoAg386Att}
          {$O ag386att}
        {$endif}
        {$ifndef NoAg386Nsm}
          {$O ag386nsm}
        {$endif}
  {$endif}
  {$ifdef m68k}
        {$O opts68k}
        {$O m68k}
        {$O cga68k}
        {$O tgen68k}
        {$O cg68kadd}
        {$O cg68kcal}
        {$O cg68kcnv}
        {$O cg68kcon}
        {$O cg68kflw}
        {$O cg68kld}
        {$O cg68kinl}
        {$O cg68kmat}
        {$O cg68kset}
        {$IfNDef Nora68kMot}
          {$O ra68kmot}
        {$endif}
        {$IfNDef Noag68kGas}
          {$O ag68kgas}
        {$endif}
        {$IfNDef Noag68kMot}
          {$O ag68kmot}
        {$endif}
        {$IfNDef Noag68kMit}
          {$O ag68kmit}
        {$endif}
  {$endif}
{$endif useoverlay}

var
  oldexit : pointer;
procedure myexit;{$ifndef FPC}far;{$endif}
begin
  exitproc:=oldexit;
{ Show Runtime error if there was an error }
  if (erroraddr<>nil) then
   begin
     case exitcode of
      202 : begin
              erroraddr:=nil;
              Writeln('Error: Stack Overflow');
            end;
      203 : begin
              erroraddr:=nil;
              Writeln('Error: Out of memory');
            end;
     end;
     { we cannot use aktfilepos.file because all memory might have been
       freed already !
       But we can use global parser_current_file var }
     Writeln('Compilation aborted ',parser_current_file,':',aktfilepos.line);
   end;
end;

begin
  oldexit:=exitproc;
  exitproc:=@myexit;
{$ifdef fpc}
  heapblocks:=true;
{$endif}
{$ifdef UseOverlay}
  InitOverlay;
{$endif}

{ Call the compiler with empty command, so it will take the parameters }
  Halt(compiler.Compile(''));
end.
{
  $Log$
  Revision 1.47  1999-09-02 18:47:45  daniel
    * Could not compile with TP, some arrays moved to heap
    * NOAG386BIN default for TP
    * AG386* files were not compatible with TP, fixed.

  Revision 1.46  1999/08/28 15:34:20  florian
    * bug 519 fixed

  Revision 1.45  1999/08/04 00:23:18  florian
    * renamed i386asm and i386base to cpuasm and cpubase

  Revision 1.44  1999/06/02 22:44:13  pierre
   * previous wrong log corrected

  Revision 1.43  1999/06/02 22:25:44  pierre
  * catch is used for go32v2 also
  
  Revision 1.42  1999/05/12 22:36:11  florian
    * override isn't allowed in objects!

  Revision 1.41  1999/05/02 09:35:45  florian
    + method message handlers which contain an explicit self can't be called
      directly anymore
    + self is now loaded at the start of the an message handler with an explicit
      self
    + $useoverlay fixed: i386 was renamed to i386base

  Revision 1.40  1999/01/27 13:05:41  pierre
   * give include file name on error

  Revision 1.39  1999/01/22 12:19:30  pierre
   + currently compiled file name added on errors

  Revision 1.38  1999/01/19 10:19:03  florian
    * bug with mul. of dwords fixed, reported by Alexander Stohr
    * some changes to compile with TP
    + small enhancements for the new code generator

  Revision 1.37  1998/12/16 00:27:21  peter
    * removed some obsolete version checks

  Revision 1.36  1998/11/27 22:54:52  michael
  + Added catch unit again

  Revision 1.35  1998/11/05 12:02:53  peter
    * released useansistring
    * removed -Sv, its now available in fpc modes

  Revision 1.34  1998/10/14 11:28:24  florian
    * emitpushreferenceaddress gets now the asmlist as parameter
    * m68k version compiles with -duseansistrings

  Revision 1.33  1998/10/08 17:17:26  pierre
    * current_module old scanner tagged as invalid if unit is recompiled
    + added ppheap for better info on tracegetmem of heaptrc
      (adds line column and file index)
    * several memory leaks removed ith help of heaptrc !!

  Revision 1.32  1998/10/02 17:03:51  peter
    * ifdef heaptrc for heaptrc

  Revision 1.31  1998/09/28 16:57:23  pierre
    * changed all length(p^.value_str^) into str_length(p)
      to get it work with and without ansistrings
    * changed sourcefiles field of tmodule to a pointer

  Revision 1.30  1998/09/24 23:49:13  peter
    + aktmodeswitches

  Revision 1.29  1998/09/17 09:42:41  peter
    + pass_2 for cg386
    * Message() -> CGMessage() for pass_1/pass_2

  Revision 1.28  1998/08/26 15:31:17  peter
    * heapblocks for >0.99.5

  Revision 1.27  1998/08/11 00:00:00  peter
    * fixed dup log

  Revision 1.26  1998/08/10 15:49:40  peter
    * small fixes for 0.99.5

  Revision 1.25  1998/08/10 14:50:16  peter
    + localswitches, moduleswitches, globalswitches splitting

  Revision 1.24  1998/08/10 10:18:32  peter
    + Compiler,Comphook unit which are the new interface units to the
      compiler

  Revision 1.23  1998/08/05 16:00:16  florian
    * some fixes for ansi strings

  Revision 1.22  1998/08/04 16:28:40  jonas
  * added support for NoRa386* in the $O ... section

  Revision 1.21  1998/07/18 17:11:12  florian
    + ansi string constants fixed
    + switch $H partial implemented

  Revision 1.20  1998/07/14 14:46:55  peter
    * released NEWINPUT

  Revision 1.19  1998/07/07 11:20:04  peter
    + NEWINPUT for a better inputfile and scanner object

  Revision 1.18  1998/06/24 14:06:33  peter
    * fixed the name changes

  Revision 1.17  1998/06/23 08:59:22  daniel
    * Recommitted.

  Revision 1.16  1998/06/17 14:10:17  peter
    * small os2 fixes
    * fixed interdependent units with newppu (remake3 under linux works now)

  Revision 1.15  1998/06/16 11:32:18  peter
    * small cosmetic fixes

  Revision 1.14  1998/06/15 13:43:45  daniel


  * Updated overlays.

  Revision 1.12  1998/05/23 01:21:23  peter
    + aktasmmode, aktoptprocessor, aktoutputformat
    + smartlink per module $SMARTLINK-/+ (like MMX) and moved to aktswitches
    + $LIBNAME to set the library name where the unit will be put in
    * splitted cgi386 a bit (codeseg to large for bp7)
    * nasm, tasm works again. nasm moved to ag386nsm.pas

  Revision 1.11  1998/05/20 09:42:35  pierre
    + UseTokenInfo now default
    * unit in interface uses and implementation uses gives error now
    * only one error for unknown symbol (uses lastsymknown boolean)
      the problem came from the label code !
    + first inlined procedures and function work
      (warning there might be allowed cases were the result is still wrong !!)
    * UseBrower updated gives a global list of all position of all used symbols
      with switch -gb

  Revision 1.10  1998/05/12 10:47:00  peter
    * moved printstatus to verb_def
    + V_Normal which is between V_Error and V_Warning and doesn't have a
      prefix like error: warning: and is included in V_Default
    * fixed some messages
    * first time parameter scan is only for -v and -T
    - removed old style messages

  Revision 1.9  1998/05/11 13:07:56  peter
    + $ifdef NEWPPU for the new ppuformat
    + $define GDB not longer required
    * removed all warnings and stripped some log comments
    * no findfirst/findnext anymore to remove smartlink *.o files

  Revision 1.8  1998/05/08 09:21:57  michael
  + Librarysearchpath is now a linker object field;

  Revision 1.7  1998/05/04 17:54:28  peter
    + smartlinking works (only case jumptable left todo)
    * redesign of systems.pas to support assemblers and linkers
    + Unitname is now also in the PPU-file, increased version to 14

  Revision 1.6  1998/04/29 13:40:23  peter
    + heapblocks:=true

  Revision 1.5  1998/04/29 10:33:59  pierre
    + added some code for ansistring (not complete nor working yet)
    * corrected operator overloading
    * corrected nasm output
    + started inline procedures
    + added starstarn : use ** for exponentiation (^ gave problems)
    + started UseTokenInfo cond to get accurate positions

  Revision 1.3  1998/04/21 10:16:48  peter
    * patches from strasbourg
    * objects is not used anymore in the fpc compiled version

  Revision 1.2  1998/04/07 13:19:47  pierre
    * bugfixes for reset_gdb_info
      in MEM parsing for go32v2
      better external symbol creation
      support for rhgdb.exe (lowercase file names)
}
