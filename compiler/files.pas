{
    $Id$
    Copyright (c) 1996-98 by Florian Klaempfl

    This unit implements an extended file management and the first loading
    and searching of the modules (ppufiles)

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

 ****************************************************************************
}
unit files;

  interface

    uses
       cobjects,globals,ppu;

    const
{$ifdef FPC}
       maxunits = 1024;
       extbufsize = 65535;
{$else}
       maxunits = 128;
       extbufsize=1024;
{$endif}

    type
       pinputfile = ^tinputfile;
       tinputfile = object
          path,name    : pstring;    { path and filename }
          next         : pinputfile; { next file for reading }

          savebufstart,              { save fields for scanner }
          savebufsize,
          savelastlinepos,
          saveline_no      : longint;
          saveinputbuffer,
          saveinputpointer : pchar;

          linebuf      : plongint;   { line buffer to retrieve lines }
          maxlinebuf   : longint;

          ref_count    : longint;    { to handle the browser refs }
          ref_index    : longint;
          ref_next     : pinputfile;

          constructor init(const fn:string);
          destructor done;
{$ifdef SourceLine}
          function  getlinestr(l:longint):string;
{$endif SourceLine}
       end;

       pfilemanager = ^tfilemanager;
       tfilemanager = object
          files : pinputfile;
          last_ref_index : longint;
          constructor init;
          destructor done;
          procedure register_file(f : pinputfile);
          function  get_file(l:longint) : pinputfile;
          function  get_file_name(l :longint):string;
          function  get_file_path(l :longint):string;
       end;


    type
       tunitmap = array[0..maxunits-1] of pointer;
       punitmap = ^tunitmap;

       pmodule = ^tmodule;
       tmodule = object(tlinkedlist_item)
          ppufile       : pppufile; { the PPU file }
          crc,
          flags         : longint;  { the PPU flags }

          compiled,                 { unit is already compiled }
          do_assemble,              { only assemble the object, don't recompile }
          do_compile,               { need to compile the sources }
          sources_avail,            { if all sources are reachable }
          is_unit,
          in_implementation,        { processing the implementation part? }
          in_global     : boolean;  { allow global settings }

          map           : punitmap; { mapping of all used units }
          unitcount     : word;     { local unit counter }
          unit_index    : word;     { global counter for browser }
          symtable      : pointer;  { pointer to the psymtable of this unit }

          uses_imports  : boolean;  { Set if the module imports from DLL's.}
          imports       : plinkedlist;

          sourcefiles   : tfilemanager;
          linksharedlibs,
          linkstaticlibs,
          linkofiles    : tstringcontainer;
          used_units    : tlinkedlist;

          { used in firstpass for faster settings }
          scanner       : pointer;
          current_index : word;

          path,                     { path where the module is find/created }
          modulename,               { name of the module in uppercase }
          objfilename,              { fullname of the objectfile }
          asmfilename,              { fullname of the assemblerfile }
          ppufilename,              { fullname of the ppufile }
          staticlibfilename,        { fullname of the static libraryfile }
          sharedlibfilename,        { fullname of the shared libraryfile }
          exefilename,              { fullname of the exefile }
          asmprefix,                { prefix for the smartlink asmfiles }
          mainsource    : pstring;  { name of the main sourcefile }

          constructor init(const s:string;_is_unit:boolean);
          destructor done;virtual;
          procedure setfilename(const fn:string);
          function  openppu:boolean;
          function  search_unit(const n : string):boolean;
       end;

       pused_unit = ^tused_unit;
       tused_unit = object(tlinkedlist_item)
          unitid          : word;
          name            : pstring;
          checksum        : longint;
          loaded          : boolean;
          in_uses,
          in_interface,
          is_stab_written : boolean;
          u               : pmodule;
          constructor init(_u : pmodule;intface:boolean);
          constructor init_to_load(const n:string;c:longint;intface:boolean);
          destructor done;virtual;
       end;

    var
       main_module    : pmodule;     { Main module of the program }
       current_module : pmodule;     { Current module which is compiled }
       current_ppu    : pppufile;    { Current ppufile which is read }
       global_unit_count : word;
       usedunits      : tlinkedlist; { Used units for this program }
       loaded_units   : tlinkedlist; { All loaded units }


  implementation

  uses
    dos,verbose,systems;

{****************************************************************************
                                  TINPUTFILE
 ****************************************************************************}

    constructor tinputfile.init(const fn:string);
      var
        p,n,e : string;
      begin
        FSplit(fn,p,n,e);
        name:=stringdup(n+e);
        path:=stringdup(p);
        next:=nil;
      { indexing refs }
        ref_next:=nil;
        ref_count:=0;
        ref_index:=0;
{$ifdef SourceLine}
      { line buffer }
        linebuf:=nil;
        maxlinebuf:=0;
{$endif SourceLine}
      end;


    destructor tinputfile.done;
      begin
        stringdispose(path);
        stringdispose(name);
{$ifdef SourceLine}
      { free memory }
        if assigned(linebuf) then
         freemem(linebuf,maxlinebuf shl 2);
{$endif SourceLine}
      end;


{$ifdef SourceLine}
    function tinputfile.getlinestr(l:longint):string;
      var
        c : char;
        i,fpos : longint;
      begin
        getlinestr:='';
        if l<maxlinebuf then
         begin
           fpos:=plongint(longint(linebuf)+line_no*2)^;
         { in current buf ? }
           if (fpos<bufstart) or (fpos>bufstart+bufsize) then
            begin
              seekbuf(fpos);
              readbuf;
            end;
         { the begin is in the buf now simply read until #13,#10 }
           i:=0;

           inputpointer:=inputbuffer;
           c:=inputpointer^;
           while (i<255) and not(c in [#13,#10]) do
            begin
              inc(i);
              getlinestr[i]:=c;
              c:=inputpointer^;
              if c=#0 then
               reload
              else
               inc(longint(inputpointer));
            end;
           getlinestr[0]:=chr(i);
         end;
      end;
{$endif SourceLine}

{****************************************************************************
                                TFILEMANAGER
 ****************************************************************************}

    constructor tfilemanager.init;
      begin
         files:=nil;
         last_ref_index:=0;
      end;


    destructor tfilemanager.done;
      var
         hp : pinputfile;
      begin
         hp:=files;
         while assigned(hp) do
          begin
            files:=files^.ref_next;
            dispose(hp,done);
            hp:=files;
          end;
         last_ref_index:=0;
      end;


    procedure tfilemanager.register_file(f : pinputfile);
      begin
         inc(last_ref_index);
         f^.ref_next:=files;
         f^.ref_index:=last_ref_index;
         files:=f;
      end;


   function tfilemanager.get_file(l :longint) : pinputfile;
     var
        ff : pinputfile;
     begin
        ff:=files;
        while assigned(ff) and (ff^.ref_index<>l) do
         ff:=ff^.ref_next;
        get_file:=ff;
     end;


   function tfilemanager.get_file_name(l :longint):string;
     var
       hp : pinputfile;
     begin
       hp:=get_file(l);
       if assigned(hp) then
        get_file_name:=hp^.name^
       else
        get_file_name:='';
     end;


   function tfilemanager.get_file_path(l :longint):string;
     var
       hp : pinputfile;
     begin
       hp:=get_file(l);
       if assigned(hp) then
        get_file_path:=hp^.path^
       else
        get_file_path:='';
     end;


{****************************************************************************
                                  TMODULE
 ****************************************************************************}

    procedure tmodule.setfilename(const fn:string);
      var
        p : dirstr;
        n : NameStr;
        e : ExtStr;
        s : string;
      begin
         stringdispose(objfilename);
         stringdispose(asmfilename);
         stringdispose(ppufilename);
         stringdispose(staticlibfilename);
         stringdispose(sharedlibfilename);
         stringdispose(exefilename);
         stringdispose(path);
         fsplit(fn,p,n,e);
         path:=stringdup(FixPath(p));
         s:=FixFileName(FixPath(p)+n);
         objfilename:=stringdup(s+target_info.objext);
         asmfilename:=stringdup(s+target_info.asmext);
         ppufilename:=stringdup(s+target_info.unitext);
         { lib and exe could be loaded with a file specified with -o }
         if OutputFile<>'' then
          s:=OutputFile;
         staticlibfilename:=stringdup(target_os.libprefix+s+target_os.staticlibext);
         sharedlibfilename:=stringdup(target_os.libprefix+s+target_os.sharedlibext);
         exefilename:=stringdup(s+target_os.exeext);
      end;


    function tmodule.openppu:boolean;
      var
         objfiletime,
         ppufiletime,
         asmfiletime : longint;
      begin
        openppu:=false;
      { Get ppufile time (also check if the file exists) }
        ppufiletime:=getnamedfiletime(ppufilename^);
        if ppufiletime=-1 then
         exit;
      { Open the ppufile }
        Message1(unit_u_ppu_loading,ppufilename^);
        ppufile:=new(pppufile,init(ppufilename^));
        if not ppufile^.open then
         begin
           dispose(ppufile,done);
           Message(unit_d_ppu_file_too_short);
           exit;
         end;
      { check for a valid PPU file }
        if not ppufile^.CheckPPUId then
         begin
           dispose(ppufile,done);
           Message(unit_d_ppu_invalid_header);
           exit;
         end;
      { check for allowed PPU versions }
        if not (ppufile^.GetPPUVersion in [15]) then
         begin
           dispose(ppufile,done);
           Message1(unit_d_ppu_invalid_version,tostr(ppufile^.GetPPUVersion));
           exit;
         end;
      { check the target processor }
        if ttargetcpu(ppufile^.header.cpu)<>target_cpu then
         begin
           dispose(ppufile,done);
           Comment(V_Debug,'unit is compiled for an other processor');
           exit;
         end;
      { check target }
        if ttarget(ppufile^.header.target)<>target_info.target then
         begin
           dispose(ppufile,done);
           Comment(V_Debug,'unit is compiled for an other target');
           exit;
         end;
  {!!!!!!!!!!!!!!!!!!! }
      { Load values to be access easier }
        flags:=ppufile^.header.flags;
        crc:=ppufile^.header.checksum;
      { Show Debug info }
        Message1(unit_d_ppu_time,filetimestring(ppufiletime));
        Message1(unit_d_ppu_flags,tostr(flags));
        Message1(unit_d_ppu_crc,tostr(ppufile^.header.checksum));
      { check the object and assembler file to see if we need only to
        assemble, only if it's not in a library }
        do_compile:=false;
        if (flags and uf_in_library)=0 then
         begin
           if (flags and uf_static_linked)<>0 then
            begin
              objfiletime:=getnamedfiletime(staticlibfilename^);
              if (ppufiletime<0) or (objfiletime<0) or (ppufiletime>objfiletime) then
                do_compile:=true;
            end
           else
            if (flags and uf_shared_linked)<>0 then
             begin
               objfiletime:=getnamedfiletime(sharedlibfilename^);
               if (ppufiletime<0) or (objfiletime<0) or (ppufiletime>objfiletime) then
                do_compile:=true;
             end
           else
            begin
            { the objectfile should be newer than the ppu file }
              objfiletime:=getnamedfiletime(objfilename^);
              if (ppufiletime<0) or (objfiletime<0) or (ppufiletime>objfiletime) then
               begin
               { check if assembler file is older than ppu file }
                 asmfileTime:=GetNamedFileTime(asmfilename^);
                 if (asmfiletime<0) or (ppufiletime>asmfiletime) then
                  begin
                    Message(unit_d_obj_and_asm_are_older_than_ppu);
                    do_compile:=true;
                    { we should try to get the source file }
                    exit;
                  end
                 else
                  begin
                    Message(unit_d_obj_is_older_than_asm);
                    exit;
                  end;
               end;
            end;
         end;
        openppu:=true;
      end;


    function tmodule.search_unit(const n : string):boolean;
      var
         ext       : string[8];
         singlepathstring,
         unitPath,
         filename  : string;
         found     : boolean;
         start,i   : longint;

         Function UnitExists(const ext:string):boolean;
         begin
           Message1(unit_t_unitsearch,Singlepathstring+filename+ext);
           UnitExists:=FileExists(Singlepathstring+FileName+ext);
         end;

       begin
         start:=1;
         filename:=FixFileName(n);
         unitpath:=UnitSearchPath;
         Found:=false;
         repeat
         { Create current path to check }
           i:=pos(';',unitpath);
           if i=0 then
            i:=length(unitpath)+1;
           singlepathstring:=FixPath(copy(unitpath,start,i-start));
           delete(unitpath,start,i-start+1);
         { Check for PPL file }
           if not Found then
            begin
              Found:=UnitExists(target_info.unitlibext);
              if Found then
               Begin
                 SetFileName(SinglePathString+FileName);
                 Found:=OpenPPU;
               End;
             end;
         { Check for PPU file }
           if not Found then
            begin
              Found:=UnitExists(target_info.unitext);
              if Found then
               Begin
                 SetFileName(SinglePathString+FileName);
                 Found:=OpenPPU;
               End;
            end;
         { Check for Sources }
           if not Found then
            begin
              ppufile:=nil;
              do_compile:=true;
            {Check for .pp file}
              Found:=UnitExists(target_os.sourceext);
              if Found then
               Ext:=target_os.sourceext
              else
               begin
               {Check for .pas}
                 Found:=UnitExists(target_os.pasext);
                 if Found then
                  Ext:=target_os.pasext;
               end;
              stringdispose(mainsource);
              if Found then
               begin
                 sources_avail:=true;
               {Load Filenames when found}
                 mainsource:=StringDup(SinglePathString+FileName+Ext);
                 SetFileName(SinglePathString+FileName);
               end
              else
               sources_avail:=false;
            end;
         until Found or (unitpath='');
         search_unit:=Found;
      end;


    constructor tmodule.init(const s:string;_is_unit:boolean);
      var
        p : dirstr;
        n : namestr;
        e : extstr;
      begin
         FSplit(s,p,n,e);
      { Programs have the name program to don't conflict with dup id's }
         if _is_unit then
           modulename:=stringdup(Upper(n))
         else
           modulename:=stringdup('PROGRAM');
         mainsource:=stringdup(s);
         ppufilename:=nil;
         objfilename:=nil;
         asmfilename:=nil;
         staticlibfilename:=nil;
         sharedlibfilename:=nil;
         exefilename:=nil;
         { go32v2 has the famous 8.3 limit ;) }
{$ifdef go32v2}
         asmprefix:=stringdup(FixFileName('as'));
{$else}
         asmprefix:=stringdup(FixFileName(n));
{$endif}
         path:=nil;
         setfilename(p+n);
         used_units.init;
         sourcefiles.init;
         linkofiles.init;
         linkstaticlibs.init;
         linksharedlibs.init;
         current_index:=0;
         ppufile:=nil;
         scanner:=nil;
         map:=nil;
         symtable:=nil;
         flags:=0;
         crc:=0;
         unitcount:=1;
         inc(global_unit_count);
         unit_index:=global_unit_count;
         do_assemble:=false;
         do_compile:=false;
         sources_avail:=true;
         compiled:=false;
         in_implementation:=false;
         in_global:=true;
         is_unit:=_is_unit;
         uses_imports:=false;
         imports:=new(plinkedlist,init);
       { set smartlink flag }
         if (cs_smartlink in aktmoduleswitches) then
          flags:=flags or uf_smartlink;
       { search the PPU file if it is an unit }
         if is_unit then
          begin
            if (not search_unit(modulename^)) and (length(modulename^)>8) then
             search_unit(copy(modulename^,1,8));
          end;
      end;


    destructor tmodule.done;
      begin
        if assigned(map) then
         dispose(map);
        if assigned(ppufile) then
         dispose(ppufile,done);
        if assigned(imports) then
         dispose(imports,done);
        used_units.done;
        sourcefiles.done;
        linkofiles.done;
        linkstaticlibs.done;
        linksharedlibs.done;
        stringdispose(objfilename);
        stringdispose(asmfilename);
        stringdispose(ppufilename);
        stringdispose(staticlibfilename);
        stringdispose(sharedlibfilename);
        stringdispose(exefilename);
        stringdispose(path);
        stringdispose(modulename);
        stringdispose(mainsource);
        stringdispose(asmprefix);
        inherited done;
      end;


{****************************************************************************
                              TUSED_UNIT
 ****************************************************************************}

    constructor tused_unit.init(_u : pmodule;intface:boolean);
      begin
        u:=_u;
        in_interface:=intface;
        in_uses:=false;
        is_stab_written:=false;
        loaded:=true;
        name:=stringdup(_u^.modulename^);
        checksum:=_u^.crc;
        unitid:=0;
      end;


    constructor tused_unit.init_to_load(const n:string;c:longint;intface:boolean);
      begin
        u:=nil;
        in_interface:=intface;
        in_uses:=false;
        is_stab_written:=false;
        loaded:=false;
        name:=stringdup(n);
        checksum:=c;
        unitid:=0;
      end;


    destructor tused_unit.done;
      begin
        stringdispose(name);
        inherited done;
      end;

end.
{
  $Log$
  Revision 1.39  1998-08-25 16:44:16  pierre
    * openppu was true even if the object file is missing
      this lead to trying to open a filename without extension
      and prevented the 'make cycle' to work for win32

  Revision 1.38  1998/08/19 10:06:12  peter
    * fixed filenames and removedir which supports slash at the end

  Revision 1.37  1998/08/18 20:52:19  peter
    * renamed in_main to in_global which is more logical

  Revision 1.36  1998/08/17 10:10:07  peter
    - removed OLDPPU

  Revision 1.35  1998/08/17 09:17:44  peter
    * static/shared linking updates

  Revision 1.34  1998/08/14 21:56:31  peter
    * setting the outputfile using -o works now to create static libs

  Revision 1.33  1998/08/11 14:09:08  peter
    * fixed some messages and smaller msgtxt.inc

  Revision 1.32  1998/08/10 14:49:58  peter
    + localswitches, moduleswitches, globalswitches splitting

  Revision 1.31  1998/07/14 14:46:48  peter
    * released NEWINPUT

  Revision 1.30  1998/07/07 11:19:55  peter
    + NEWINPUT for a better inputfile and scanner object

  Revision 1.29  1998/06/25 10:51:00  pierre
    * removed a remaining ifndef NEWPPU
      replaced by ifdef OLDPPU
    * added uf_finalize to ppu unit

  Revision 1.28  1998/06/25 08:48:12  florian
    * first version of rtti support

  Revision 1.27  1998/06/24 14:48:34  peter
    * ifdef newppu -> ifndef oldppu

  Revision 1.26  1998/06/17 14:36:19  peter
    * forgot an $ifndef OLDPPU :(

  Revision 1.25  1998/06/17 14:10:11  peter
    * small os2 fixes
    * fixed interdependent units with newppu (remake3 under linux works now)

  Revision 1.24  1998/06/16 08:56:20  peter
    + targetcpu
    * cleaner pmodules for newppu

  Revision 1.23  1998/06/15 14:44:36  daniel
  * BP updates.

  Revision 1.22  1998/06/14 18:25:41  peter
    * small fix with crc in newppu

  Revision 1.21  1998/06/13 00:10:05  peter
    * working browser and newppu
    * some small fixes against crashes which occured in bp7 (but not in
      fpc?!)

  Revision 1.20  1998/06/12 14:50:48  peter
    * removed the tree dependency to types.pas
    * long_fil.pas support (not fully tested yet)

  Revision 1.19  1998/06/12 10:32:26  pierre
    * column problem hopefully solved
    + C vars declaration changed

  Revision 1.18  1998/06/11 13:58:07  peter
    * small fix to let newppu compile

  Revision 1.17  1998/06/09 16:01:40  pierre
    + added procedure directive parsing for procvars
      (accepted are popstack cdecl and pascal)
    + added C vars with the following syntax
      var C calias 'true_c_name';(can be followed by external)
      reason is that you must add the Cprefix

      which is target dependent

  Revision 1.16  1998/06/04 10:42:19  pierre
    * small bug fix in load_ppu or openppu

  Revision 1.15  1998/05/28 14:37:53  peter
    * default programname is PROGRAM (like TP7) to avoid dup id's

  Revision 1.14  1998/05/27 19:45:02  peter
    * symtable.pas splitted into includefiles
    * symtable adapted for $ifndef OLDPPU

  Revision 1.13  1998/05/23 01:21:05  peter
    + aktasmmode, aktoptprocessor, aktoutputformat
    + smartlink per module $SMARTLINK-/+ (like MMX) and moved to aktswitches
    + $LIBNAME to set the library name where the unit will be put in
    * splitted cgi386 a bit (codeseg to large for bp7)
    * nasm, tasm works again. nasm moved to ag386nsm.pas

  Revision 1.12  1998/05/20 09:42:33  pierre
    + UseTokenInfo now default
    * unit in interface uses and implementation uses gives error now
    * only one error for unknown symbol (uses lastsymknown boolean)
      the problem came from the label code !
    + first inlined procedures and function work
      (warning there might be allowed cases were the result is still wrong !!)
    * UseBrower updated gives a global list of all position of all used symbols
      with switch -gb

  Revision 1.11  1998/05/12 10:46:59  peter
    * moved printstatus to verb_def
    + V_Normal which is between V_Error and V_Warning and doesn't have a
      prefix like error: warning: and is included in V_Default
    * fixed some messages
    * first time parameter scan is only for -v and -T
    - removed old style messages

  Revision 1.10  1998/05/11 13:07:53  peter
    + $ifndef OLDPPU for the new ppuformat
    + $define GDB not longer required
    * removed all warnings and stripped some log comments
    * no findfirst/findnext anymore to remove smartlink *.o files

  Revision 1.9  1998/05/06 15:04:20  pierre
    + when trying to find source files of a ppufile
      check the includepathlist for included files
      the main file must still be in the same directory

  Revision 1.8  1998/05/04 17:54:25  peter
    + smartlinking works (only case jumptable left todo)
    * redesign of systems.pas to support assemblers and linkers
    + Unitname is now also in the PPU-file, increased version to 14

  Revision 1.7  1998/05/01 16:38:44  florian
    * handling of private and protected fixed
    + change_keywords_to_tp implemented to remove
      keywords which aren't supported by tp
    * break and continue are now symbols of the system unit
    + widestring, longstring and ansistring type released

  Revision 1.6  1998/05/01 07:43:53  florian
    + basics for rtti implemented
    + switch $m (generate rtti for published sections)

  Revision 1.5  1998/04/30 15:59:40  pierre
    * GDB works again better :
      correct type info in one pass
    + UseTokenInfo for better source position
    * fixed one remaining bug in scanner for line counts
    * several little fixes

  Revision 1.4  1998/04/29 10:33:52  pierre
    + added some code for ansistring (not complete nor working yet)
    * corrected operator overloading
    * corrected nasm output
    + started inline procedures
    + added starstarn : use ** for exponentiation (^ gave problems)
    + started UseTokenInfo cond to get accurate positions

  Revision 1.3  1998/04/27 23:10:28  peter
    + new scanner
    * $makelib -> if smartlink
    * small filename fixes pmodule.setfilename
    * moved import from files.pas -> import.pas

  Revision 1.2  1998/04/21 10:16:47  peter
    * patches from strasbourg
    * objects is not used anymore in the fpc compiled version
}
