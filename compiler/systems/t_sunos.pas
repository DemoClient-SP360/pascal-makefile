{
    $Id$
    Copyright (c) 1998-2002 by Peter Vreman

    This unit implements support import,export,link routines
    for the (i386) sunos target

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
unit t_sunos;

{$i fpcdefs.inc}

interface

{ copy from t_linux
// Up to now we use gld since the solaris ld seems not support .res-files}
{-$DEFINE LinkTest} { DON't del link.res and write Info }
{$DEFINE GnuLd} {The other is not implemented }

implementation

  uses
    cutils,cclasses,
    verbose,systems,globtype,globals,
    symconst,script,
    fmodule,aasmbase,aasmtai,aasmcpu,cpubase,symsym,symdef,
    import,export,link,i_sunos;

  type
    timportlibsunos=class(timportlib)
      procedure preparelib(const s:string);override;
      procedure importprocedure(aprocdef:tprocdef;const module:string;index:longint;const name:string);override;
      procedure importvariable(vs:tglobalvarsym;const name,module:string);override;
      procedure generatelib;override;
    end;

    texportlibsunos=class(texportlib)
      procedure preparelib(const s : string);override;
      procedure exportprocedure(hp : texported_item);override;
      procedure exportvar(hp : texported_item);override;
      procedure generatelib;override;
    end;

    tlinkersunos=class(texternallinker)
    private
      Glibc2,
      Glibc21 : boolean;
      Function  WriteResponseFile(isdll:boolean) : Boolean;
    public
      constructor Create;override;
      procedure SetDefaultInfo;override;
      function  MakeExecutable:boolean;override;
      function  MakeSharedLibrary:boolean;override;
    end;


{*****************************************************************************
                               TIMPORTLIBsunos
*****************************************************************************}

procedure timportlibsunos.preparelib(const s : string);
begin
{$ifDef LinkTest}
  WriteLN('Prepare import: ',s);
{$EndIf}
end;


procedure timportlibsunos.importprocedure(aprocdef:tprocdef;const module:string;index:longint;const name:string);
begin
  { insert sharedlibrary }
{$ifDef LinkTest}
  WriteLN('Import: f:',func,' m:',module,' n:',name);
{$EndIf}
  current_module.linkothersharedlibs.add(SplitName(module),link_allways);
end;


procedure timportlibsunos.importvariable(vs:tglobalvarsym;const name,module:string);
begin
  { insert sharedlibrary }
  current_module.linkothersharedlibs.add(SplitName(module),link_allways);
  { reset the mangledname and turn off the dll_var option }
  vs.set_mangledname(name);
  exclude(vs.varoptions,vo_is_dll_var);
end;


procedure timportlibsunos.generatelib;
begin
end;


{*****************************************************************************
                               TEXPORTLIBsunos
*****************************************************************************}

procedure texportlibsunos.preparelib(const s:string);
begin
end;


procedure texportlibsunos.exportprocedure(hp : texported_item);
var
  hp2 : texported_item;
begin
  { first test the index value }
  if (hp.options and eo_index)<>0 then
   begin
     Message1(parser_e_no_export_with_index_for_target,'SunOS');
     exit;
   end;
  { use pascal name is none specified }
  if (hp.options and eo_name)=0 then
    begin
       hp.name:=stringdup(hp.sym.name);
       hp.options:=hp.options or eo_name;
    end;
  { now place in correct order }
  hp2:=texported_item(current_module._exports.first);
  while assigned(hp2) and
     (hp.name^>hp2.name^) do
    hp2:=texported_item(hp2.next);
  { insert hp there !! }
  if assigned(hp2) and (hp2.name^=hp.name^) then
    begin
      { this is not allowed !! }
      Message1(parser_e_export_name_double,hp.name^);
      exit;
    end;
  if hp2=texported_item(current_module._exports.first) then
    current_module._exports.insert(hp)
  else if assigned(hp2) then
    begin
       hp.next:=hp2;
       hp.previous:=hp2.previous;
       if assigned(hp2.previous) then
         hp2.previous.next:=hp;
       hp2.previous:=hp;
    end
  else
    current_module._exports.concat(hp);
end;


procedure texportlibsunos.exportvar(hp : texported_item);
begin
  hp.is_var:=true;
  exportprocedure(hp);
end;


procedure texportlibsunos.generatelib;
var
  hp2 : texported_item;
begin
  hp2:=texported_item(current_module._exports.first);
  while assigned(hp2) do
   begin
     if (not hp2.is_var) and
        (hp2.sym.typ=procsym) then
      begin
        { the manglednames can already be the same when the procedure
          is declared with cdecl }
        if tprocsym(hp2.sym).first_procdef.mangledname<>hp2.name^ then
         begin
{$ifdef i386}
           { place jump in codesegment }
           codesegment.concat(Tai_align.Create_op(4,$90));
           codeSegment.concat(Tai_symbol.Createname_global(hp2.name^,AT_FUNCTION,0));
           codeSegment.concat(Taicpu.Op_sym(A_JMP,S_NO,objectlibrary.newasmsymbol(tprocsym(hp2.sym).first_procdef.mangledname,AB_EXTERNAL,AT_FUNCTION)));
           codeSegment.concat(Tai_symbol_end.Createname(hp2.name^));
{$endif i386}
         end;
      end
     else
      Message1(parser_e_no_export_of_variables_for_target,'SunOS');
     hp2:=texported_item(hp2.next);
   end;
end;


{*****************************************************************************
                                  TLINKERSUNOS
*****************************************************************************}

Constructor TLinkersunos.Create;
begin
  Inherited Create;
  if NOT Dontlinkstdlibpath Then
   LibrarySearchPath.AddPath('/lib;/usr/lib;/usr/X11R6/lib;/opt/sfw/lib',true);
{$ifdef  LinkTest}
     if (cs_link_staticflag in aktglobalswitches) then  WriteLN('ForceLinkStaticFlag');
     if (cs_link_static in aktglobalswitches) then  WriteLN('LinkStatic-Flag');
     if (cs_link_shared in aktglobalswitches) then  WriteLN('LinkSynamicFlag');
{$EndIf}
end;


procedure TLinkersunos.SetDefaultInfo;
{
  This will also detect which libc version will be used
}
begin
  Glibc2:=false;
  Glibc21:=false;
  with Info do
   begin
{$IFDEF GnuLd}
     ExeCmd[1]:='gld $OPT $DYNLINK $STATIC $STRIP -L. -o $EXE $RES';
     DllCmd[1]:='gld $OPT -shared -L. -o $EXE $RES';
     DllCmd[2]:='strip --strip-unneeded $EXE';
     DynamicLinker:=''; { Gnu uses the default }
     Glibc21:=false;
{$ELSE}
    Not Implememted
{$ENDIF}
(* Linux Stuff not needed?
     { first try glibc2 } // muss noch gendert werden
     if FileExists(DynamicLinker) then
      begin
        Glibc2:=true;
        { Check for 2.0 files, else use the glibc 2.1 stub }
        if FileExists('/lib/ld-2.0.*') then
         Glibc21:=false
        else
         Glibc21:=true;
      end
     else
      DynamicLinker:='/lib/ld-linux.so.1';
*)
   end;

end;


Function TLinkersunos.WriteResponseFile(isdll:boolean) : Boolean;
Var
  linkres      : TLinkRes;
  i            : longint;
  cprtobj,
  gprtobj,
  prtobj       : string[80];
  HPath        : TStringListItem;
  s,s2         : string;
  linkdynamic,
  linklibc     : boolean;
begin
  WriteResponseFile:=False;
{ set special options for some targets }
  linkdynamic:=not(SharedLibFiles.empty);
{  linkdynamic:=false; // da nicht getestet }
  linklibc:=(SharedLibFiles.Find('c')<>nil);
  prtobj:='prt0';
  cprtobj:='cprt0';
  gprtobj:='gprt0';
  if cs_profile in aktmoduleswitches then
   begin
     prtobj:=gprtobj;
     if not glibc2 then
      AddSharedLibrary('gmon');
     AddSharedLibrary('c');
     linklibc:=true;
   end
  else
   begin
     if linklibc then
       prtobj:=cprtobj
      else
       AddSharedLibrary('c'); { quick hack: this sunos implementation needs alwys libc }
   end;

  { Open link.res file }
  LinkRes:=TLinkRes.Create(outputexedir+Info.ResName);

  { Write path to search libraries }
  HPath:=TStringListItem(current_module.locallibrarysearchpath.First);
  while assigned(HPath) do
   begin
     LinkRes.Add('SEARCH_DIR('+HPath.Str+')');
     HPath:=TStringListItem(HPath.Next);
   end;
  HPath:=TStringListItem(LibrarySearchPath.First);
  while assigned(HPath) do
   begin
     LinkRes.Add('SEARCH_DIR('+HPath.Str+')');
     HPath:=TStringListItem(HPath.Next);
   end;

  LinkRes.Add('INPUT(');
  { add objectfiles, start with prt0 always }
  if prtobj<>'' then
   LinkRes.AddFileName(FindObjectFile(prtobj,'',false));
  { try to add crti and crtbegin if linking to C }
  if linklibc then { Needed in sunos? }
   begin
{     if librarysearchpath.FindFile('crtbegin.o',s) then
      LinkRes.AddFileName(s);}
     if librarysearchpath.FindFile('crti.o',s) then
      LinkRes.AddFileName(s);
   end;
  { main objectfiles }
  while not ObjectFiles.Empty do
   begin
     s:=ObjectFiles.GetFirst;
     if s<>'' then
      LinkRes.AddFileName(s);
   end;
  LinkRes.Add(')');

  { Write staticlibraries }
  if not StaticLibFiles.Empty then
   begin
     LinkRes.Add('GROUP(');
     While not StaticLibFiles.Empty do
      begin
        S:=StaticLibFiles.GetFirst;
        LinkRes.AddFileName(s)
      end;
     LinkRes.Add(')');
   end;

  { Write sharedlibraries like -l<lib>, also add the needed dynamic linker
    here to be sure that it gets linked this is needed for glibc2 systems (PFV) }
  if not SharedLibFiles.Empty then
   begin
     LinkRes.Add('INPUT(');
     While not SharedLibFiles.Empty do
      begin
        S:=SharedLibFiles.GetFirst;
        if s<>'c' then
         begin
           i:=Pos(target_info.sharedlibext,S);
           if i>0 then
            Delete(S,i,255);
           LinkRes.Add('-l'+s);
         end
        else
         begin
           linklibc:=true;
           linkdynamic:=false; { libc will include the ld-sunos (war ld-linux) for us }
         end;
      end;
     { be sure that libc is the last lib }
     if linklibc then
      LinkRes.Add('-lc');
     { when we have -static for the linker the we also need libgcc }
     if (cs_link_staticflag in aktglobalswitches) then begin
      LinkRes.Add('-lgcc');
     end;
     if linkdynamic and (Info.DynamicLinker<>'') then { gld has a default, DynamicLinker is not set in sunos }
       LinkRes.AddFileName(Info.DynamicLinker);
     LinkRes.Add(')');
   end;
  { objects which must be at the end }
  if linklibc then {needed in sunos ? }
   begin
     if {librarysearchpath.FindFile('crtend.o',s1) or}
        librarysearchpath.FindFile('crtn.o',s2) then
      begin
        LinkRes.Add('INPUT(');
{        LinkRes.AddFileName(s1);}
        LinkRes.AddFileName(s2);
        LinkRes.Add(')');
      end;
   end;
{ Write and Close response }
  linkres.writetodisk;
  LinkRes.Free;

  WriteResponseFile:=True;
end;


function TLinkersunos.MakeExecutable:boolean;
var
  binstr : String;
  cmdstr  : TCmdStr;
  success : boolean;
  DynLinkStr : string[60];
  StaticStr,
  StripStr   : string[40];
begin
  if not(cs_link_extern in aktglobalswitches) then
   Message1(exec_i_linking,current_module.exefilename^);

{ Create some replacements }
  StaticStr:='';
  StripStr:='';
  DynLinkStr:='';
  if (cs_link_staticflag in aktglobalswitches) then
    StaticStr:='-Bstatic';
  if (cs_link_strip in aktglobalswitches) then
   StripStr:='-s';
  If (cs_profile in aktmoduleswitches) or
     ((Info.DynamicLinker<>'') and (not SharedLibFiles.Empty)) then
   DynLinkStr:='-dynamic-linker='+Info.DynamicLinker;
  { sunos sets DynamicLinker, but gld will (hopefully) defaults to -Bdynamic and add the default-linker }
{ Write used files and libraries }
  WriteResponseFile(false);

{ Call linker }
  SplitBinCmd(Info.ExeCmd[1],binstr,cmdstr);
  Replace(cmdstr,'$EXE',current_module.exefilename^);
  Replace(cmdstr,'$OPT',Info.ExtraOptions);
  Replace(cmdstr,'$RES',outputexedir+Info.ResName);
  Replace(cmdstr,'$STATIC',StaticStr);
  Replace(cmdstr,'$STRIP',StripStr);
  Replace(cmdstr,'$DYNLINK',DynLinkStr);
  success:=DoExec(FindUtil(utilsprefix+BinStr),CmdStr,true,false);

{ Remove ReponseFile }
{$IFNDEF LinkTest}
  if (success) and not(cs_link_extern in aktglobalswitches) then
   RemoveFile(outputexedir+Info.ResName);
{$ENDIF}
  MakeExecutable:=success;   { otherwise a recursive call to link method }
end;


Function TLinkersunos.MakeSharedLibrary:boolean;
var
  binstr : String;
  cmdstr  : TCmdStr;
  success : boolean;
begin
  MakeSharedLibrary:=false;
  if not(cs_link_extern in aktglobalswitches) then
   Message1(exec_i_linking,current_module.sharedlibfilename^);

{ Write used files and libraries }
  WriteResponseFile(true);

{ Call linker }
  SplitBinCmd(Info.DllCmd[1],binstr,cmdstr);
  Replace(cmdstr,'$EXE',current_module.sharedlibfilename^);
  Replace(cmdstr,'$OPT',Info.ExtraOptions);
  Replace(cmdstr,'$RES',outputexedir+Info.ResName);
  success:=DoExec(FindUtil(utilsprefix+binstr),cmdstr,true,false);

{ Strip the library ? }
  if success and (cs_link_strip in aktglobalswitches) then
   begin
     SplitBinCmd(Info.DllCmd[2],binstr,cmdstr);
     Replace(cmdstr,'$EXE',current_module.sharedlibfilename^);
     success:=DoExec(utilsprefix+FindUtil(binstr),cmdstr,true,false);
   end;

{ Remove ReponseFile }
{$IFNDEF LinkTest}
  if (success) and not(cs_link_extern in aktglobalswitches) then
   RemoveFile(outputexedir+Info.ResName);
{$ENDIF}
  MakeSharedLibrary:=success;   { otherwise a recursive call to link method }
end;


{*****************************************************************************
                                     Initialize
*****************************************************************************}

initialization
{$ifdef i386}
  RegisterExternalLinker(system_i386_sunos_info,TLinkerSunos);
  RegisterImport(system_i386_sunos,TImportLibSunos);
  RegisterExport(system_i386_sunos,TExportLibSunos);
  RegisterTarget(system_i386_sunos_info);
{$endif i386}

{$ifdef sparc}
  RegisterExternalLinker(system_sparc_sunos_info,TLinkerSunos);
  RegisterImport(system_sparc_sunos,TImportLibSunos);
  RegisterExport(system_sparc_sunos,TExportLibSunos);
  RegisterTarget(system_sparc_sunos_info);
{$endif sparc}
end.
{
  $Log$
  Revision 1.15  2004-11-19 16:30:24  peter
    * fixed setting of mangledname when importing

  Revision 1.14  2004/11/08 22:09:59  peter
    * tvarsym splitted

  Revision 1.13  2004/11/03 12:04:03  florian
    * fixed sparc <-> i386 mixture

  Revision 1.12  2004/10/14 18:16:17  mazen
  * USE_SYSUTILS merged successfully : cycles with and without defines
  * Need to be optimized in performance

  Revision 1.11  2004/10/01 17:41:21  marco
   * small updates to make playing with sparc/sunos easier

  Revision 1.10  2004/09/22 15:25:14  mazen
  * Fix error committing : previous version must be in branch USE_SYSUTILS

  Revision 1.8  2004/06/20 08:55:32  florian
    * logs truncated

  Revision 1.7  2004/03/02 00:36:33  olle
    * big transformation of Tai_[const_]Symbol.Create[data]name*

}
