{
    $Id$
    Copyright (c) 1998-2002 by Florian Klaempfl

    Handles the parsing and loading of the modules (ppufiles)

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
unit pmodules;

{$i defines.inc}

{$define New_GDB}

interface

    procedure proc_unit;
    procedure proc_program(islibrary : boolean);


implementation

    uses
       globtype,version,systems,tokens,
       cutils,cclasses,comphook,
       globals,verbose,fmodule,finput,fppu,
       symconst,symbase,symtype,symdef,symsym,symtable,aasm,
       cgbase,
       ncgutil,
       link,assemble,import,export,gendef,ppu,comprsrc,
       cresstr,cpubase,cpuasm,
{$ifdef GDB}
       gdb,
{$endif GDB}
       scanner,pbase,pexpr,psystem,psub;

    procedure create_objectfile;
      var
        DLLScanner      : TDLLScanner;
        s               : string;
        KeepShared      : TStringList;
      begin
        { try to create import entries from system dlls }
        if target_info.DllScanSupported and
           (not current_module.linkOtherSharedLibs.Empty) then
         begin
           { Init DLLScanner }
           if assigned(CDLLScanner[target_info.target]) then
            DLLScanner:=CDLLScanner[target_info.target].Create
           else
            internalerror(200104121);
           KeepShared:=TStringList.Create;
           { Walk all shared libs }
           While not current_module.linkOtherSharedLibs.Empty do
            begin
              S:=current_module.linkOtherSharedLibs.Getusemask(link_allways);
              if not DLLScanner.scan(s) then
               KeepShared.Concat(s);
            end;
           DLLscanner.Free;
           { Recreate import section }
           if (target_info.target in [target_i386_win32,target_i386_wdosx]) then
            begin
              if assigned(importssection)then
               importssection.clear
              else
               importssection:=taasmoutput.Create;
              importlib.generatelib;
            end;
           { Readd the not processed files }
           while not KeepShared.Empty do
            begin
              s:=KeepShared.GetFirst;
              current_module.linkOtherSharedLibs.add(s,link_allways);
            end;
           KeepShared.Free;
         end;

        { create the .s file and assemble it }
        GenerateAsm(false);

        { Also create a smartlinked version ? }
        if (cs_create_smart in aktmoduleswitches) then
         begin
           { regenerate the importssection for win32 }
           if assigned(importssection) and
              (target_info.target in [target_i386_win32,target_i386_wdosx]) then
            begin
              importsSection.clear;
              importlib.generatesmartlib;
            end;

           GenerateAsm(true);
           if target_asm.needar then
             Linker.MakeStaticLibrary;
         end;

        { resource files }
        CompileResourceFiles;
      end;


    procedure insertobjectfile;
    { Insert the used object file for this unit in the used list for this unit }
      begin
        current_module.linkunitofiles.add(current_module.objfilename^,link_static);
        current_module.flags:=current_module.flags or uf_static_linked;

        if (cs_create_smart in aktmoduleswitches) then
         begin
           current_module.linkunitstaticlibs.add(current_module.staticlibfilename^,link_smart);
           current_module.flags:=current_module.flags or uf_smart_linked;
         end;
      end;


    procedure insertsegment;

        procedure fixseg(p:TAAsmoutput;sec:tsection);
        begin
          p.insert(Tai_section.Create(sec));
          if (cs_create_smart in aktmoduleswitches) then
           p.insert(Tai_cut.Create);
          p.concat(Tai_section.Create(sec_none));
        end;

      begin
      { Insert Ident of the compiler }
        if (not (cs_create_smart in aktmoduleswitches))
{$ifndef EXTDEBUG}
           and (not current_module.is_unit)
{$endif}
           then
         begin
           { align the first data }
           dataSegment.insert(Tai_align.Create(used_align(32,
               aktalignment.constalignmin,aktalignment.constalignmax)));
           dataSegment.insert(Tai_string.Create('FPC '+full_version_string+
             ' ['+date_string+'] for '+target_cpu_string+' - '+target_info.shortname));
         end;
        { align code segment }
        codeSegment.concat(Tai_align.Create(aktalignment.procalign));
       { Insert start and end of sections }
        fixseg(codesegment,sec_code);
        fixseg(datasegment,sec_data);
        fixseg(bsssegment,sec_bss);
      { we should use .rdata section for these two no ? }
      { .rdata is a read only data section (PM) }
        fixseg(rttilist,sec_data);
        fixseg(consts,sec_data);
        if assigned(resourcestringlist) then
          fixseg(resourcestringlist,sec_data);
{$ifdef GDB}
        if assigned(debuglist) then
          begin
            debugList.insert(Tai_symbol.Createname('gcc2_compiled',0));
            debugList.insert(Tai_symbol.Createname('fpc_compiled',0));
            fixseg(debuglist,sec_code);
          end;
{$endif GDB}
      end;


    Procedure InsertResourceTablesTable;
      var
        hp : tused_unit;
        ResourceStringTables : taasmoutput;
        count : longint;
      begin
        ResourceStringTables:=TAAsmOutput.Create;
        count:=0;
        hp:=tused_unit(usedunits.first);
        while assigned(hp) do
         begin
           If (hp.u.flags and uf_has_resources)=uf_has_resources then
            begin
              ResourceStringTables.concat(Tai_const_symbol.Createname(hp.u.modulename^+'_RESOURCESTRINGLIST'));
              inc(count);
            end;
           hp:=tused_unit(hp.next);
         end;
        { Add program resources, if any }
        If ResourceStringList<>Nil then
         begin
           ResourceStringTables.concat(Tai_const_symbol.Createname(current_module.modulename^+'_RESOURCESTRINGLIST'));
           Inc(Count);
         end;
        { TableCount }
        ResourceStringTables.insert(Tai_const.Create_32bit(count));
        ResourceStringTables.insert(Tai_symbol.Createdataname_global('FPC_RESOURCESTRINGTABLES',0));
        ResourceStringTables.concat(Tai_symbol_end.Createname('FPC_RESOURCESTRINGTABLES'));
        { insert in data segment }
        if (cs_create_smart in aktmoduleswitches) then
          dataSegment.concat(Tai_cut.Create);
        dataSegment.concatlist(ResourceStringTables);
        ResourceStringTables.free;
      end;





    procedure InsertInitFinalTable;
      var
        hp : tused_unit;
        unitinits : taasmoutput;
        count : longint;
      begin
        unitinits:=TAAsmOutput.Create;
        count:=0;
        hp:=tused_unit(usedunits.first);
        while assigned(hp) do
         begin
           { call the unit init code and make it external }
           if (hp.u.flags and (uf_init or uf_finalize))<>0 then
            begin
              if (hp.u.flags and uf_init)<>0 then
               unitinits.concat(Tai_const_symbol.Createname('INIT$$'+hp.u.modulename^))
              else
               unitinits.concat(Tai_const.Create_32bit(0));
              if (hp.u.flags and uf_finalize)<>0 then
               unitinits.concat(Tai_const_symbol.Createname('FINALIZE$$'+hp.u.modulename^))
              else
               unitinits.concat(Tai_const.Create_32bit(0));
              inc(count);
            end;
           hp:=tused_unit(hp.next);
         end;
        if current_module.islibrary then
          if (current_module.flags and uf_finalize)<>0 then
            begin
              { INIT code is done by PASCALMAIN calling }
              unitinits.concat(Tai_const.Create_32bit(0));
              unitinits.concat(Tai_const_symbol.Createname('FINALIZE$$'+current_module.modulename^));
              inc(count);
            end;
        { TableCount,InitCount }
        unitinits.insert(Tai_const.Create_32bit(0));
        unitinits.insert(Tai_const.Create_32bit(count));
        unitinits.insert(Tai_symbol.Createdataname_global('INITFINAL',0));
        unitinits.concat(Tai_symbol_end.Createname('INITFINAL'));
        { insert in data segment }
        if (cs_create_smart in aktmoduleswitches) then
          dataSegment.concat(Tai_cut.Create);
        dataSegment.concatlist(unitinits);
        unitinits.free;
      end;


    procedure insertheap;
      begin
         if (cs_create_smart in aktmoduleswitches) then
           begin
             bssSegment.concat(Tai_cut.Create);
             dataSegment.concat(Tai_cut.Create);
           end;
        { On the Macintosh Classic M68k Architecture
          The Heap variable is simply a POINTER to the
          real HEAP. The HEAP must be set up by the RTL
          and must store the pointer in this value.
          On OS/2 the heap is also intialized by the RTL. We do
          not output a pointer }
         case target_info.target of
{$ifdef i386}
            target_i386_OS2:
              ;
{$endif i386}
{$ifdef alpha}
            target_alpha_linux:
              ;
{$endif alpha}
{$ifdef powerpc}
            target_powerpc_linux:
              ;
{$endif powerpc}
{$ifdef m68k}
            target_m68k_Mac:
              bssSegment.concat(Tai_datablock.Create_global('HEAP',4));
            target_m68k_PalmOS:
              ;
{$endif m68k}
{$IFDEF SPARC}
            target_SPARC_Linux:
              ;
{$ENDIF SPARC}
         else
           bssSegment.concat(Tai_datablock.Create_global('HEAP',heapsize));
         end;
{$ifdef m68k}
         if target_info.target<>target_m68k_PalmOS then
           begin
              dataSegment.concat(Tai_symbol.Createdataname_global('HEAPSIZE',4));
              dataSegment.concat(Tai_const.Create_32bit(heapsize));
           end;
{$else m68k}
         dataSegment.concat(Tai_symbol.Createdataname_global('HEAPSIZE',4));
         dataSegment.concat(Tai_const.Create_32bit(heapsize));
{$endif m68k}
      end;


    procedure insertstacklength;
      begin
        { stacksize can be specified and is now simulated }
        dataSegment.concat(Tai_symbol.Createdataname_global('__stklen',4));
        dataSegment.concat(Tai_const.Create_32bit(stacksize));
      end;


    procedure loaddefaultunits;
      var
        hp : tmodule;
        unitsym : tunitsym;
      begin
      { are we compiling the system unit? }
        if (cs_compilesystem in aktmoduleswitches) then
         begin
         { create system defines }
           createconstdefs;
         { we don't need to reset anything, it's already done in parser.pas }
           exit;
         end;
     { insert the system unit, it is allways the first }
        hp:=loadunit('System','');
        systemunit:=tglobalsymtable(hp.globalsymtable);
        { it's always the first unit }
        systemunit.next:=nil;
        symtablestack:=systemunit;
        { add to the used units }
        current_module.used_units.concat(tused_unit.create(hp,true));
        unitsym:=tunitsym.create('System',systemunit);
        inc(unitsym.refs);
        refsymtable.insert(unitsym);
        { read default constant definitions }
        make_ref:=false;
        readconstdefs;
        make_ref:=true;
      { Objpas unit? }
        if m_objpas in aktmodeswitches then
         begin
           hp:=loadunit('ObjPas','');
           tsymtable(hp.globalsymtable).next:=symtablestack;
           symtablestack:=hp.globalsymtable;
           { add to the used units }
           current_module.used_units.concat(tused_unit.create(hp,true));
           unitsym:=tunitsym.create('ObjPas',hp.globalsymtable);
           inc(unitsym.refs);
           refsymtable.insert(unitsym);
         end;
      { Profile unit? Needed for go32v2 only }
        if (cs_profile in aktmoduleswitches) and (target_info.target=target_i386_go32v2) then
         begin
           hp:=loadunit('Profile','');
           tsymtable(hp.globalsymtable).next:=symtablestack;
           symtablestack:=hp.globalsymtable;
           { add to the used units }
           current_module.used_units.concat(tused_unit.create(hp,true));
           unitsym:=tunitsym.create('Profile',hp.globalsymtable);
           inc(unitsym.refs);
           refsymtable.insert(unitsym);
         end;
      { Units only required for main module }
        if not(current_module.is_unit) then
         begin
           { Heaptrc unit }
           if (cs_gdb_heaptrc in aktglobalswitches) then
            begin
              hp:=loadunit('HeapTrc','');
              tsymtable(hp.globalsymtable).next:=symtablestack;
              symtablestack:=hp.globalsymtable;
              { add to the used units }
              current_module.used_units.concat(tused_unit.create(hp,true));
              unitsym:=tunitsym.create('HeapTrc',hp.globalsymtable);
              inc(unitsym.refs);
              refsymtable.insert(unitsym);
            end;
           { Lineinfo unit }
           if (cs_gdb_lineinfo in aktglobalswitches) then
            begin
              hp:=loadunit('LineInfo','');
              tsymtable(hp.globalsymtable).next:=symtablestack;
              symtablestack:=hp.globalsymtable;
              { add to the used units }
              current_module.used_units.concat(tused_unit.create(hp,true));
              unitsym:=tunitsym.create('LineInfo',hp.globalsymtable);
              inc(unitsym.refs);
              refsymtable.insert(unitsym);
            end;
         end;
      { save default symtablestack }
        defaultsymtablestack:=symtablestack;
      end;


    procedure loadunits;
      var
         s,sorg : stringid;
         fn     : string;
         pu,
         hp : tused_unit;
         hp2 : tmodule;
         hp3 : tsymtable;
         oldprocsym:tprocsym;
         oldprocdef:tprocdef;
         unitsym : tunitsym;
      begin
         oldprocsym:=aktprocsym;
         oldprocdef:=aktprocdef;
         consume(_USES);
{$ifdef DEBUG}
         test_symtablestack;
{$endif DEBUG}
         repeat
           s:=pattern;
           sorg:=orgpattern;
           consume(_ID);
           { support "<unit> in '<file>'" construct, but not for tp7 }
           if not(m_tp7 in aktmodeswitches) then
            begin
              if try_to_consume(_OP_IN) then
               fn:=get_stringconst
              else
               fn:='';
            end;
           { Give a warning if objpas is loaded }
           if s='OBJPAS' then
            Message(parser_w_no_objpas_use_mode);
           { check if the unit is already used }
           pu:=tused_unit(current_module.used_units.first);
           while assigned(pu) do
            begin
              if (pu.name^=s) then
               break;
              pu:=tused_unit(pu.next);
            end;
         { avoid uses of itself }
           if not assigned(pu) and (s<>current_module.modulename^) then
            begin
            { load the unit }
              hp2:=loadunit(sorg,fn);
            { the current module uses the unit hp2 }
              current_module.used_units.concat(tused_unit.create(hp2,not current_module.in_implementation));
              tused_unit(current_module.used_units.last).in_uses:=true;
              if current_module.compiled then
                exit;
              unitsym:=tunitsym.create(sorg,hp2.globalsymtable);
              { never claim about unused unit if
                there is init or finalize code  PM }
              if (hp2.flags and (uf_init or uf_finalize))<>0 then
                inc(unitsym.refs);
              refsymtable.insert(unitsym);
            end
           else
            Message1(sym_e_duplicate_id,s);
           if token=_COMMA then
            begin
              pattern:='';
              consume(_COMMA);
            end
           else
            break;
         until false;
         consume(_SEMICOLON);

         { set the symtable to systemunit so it gets reorderd correctly }
         symtablestack:=defaultsymtablestack;

         { now insert the units in the symtablestack }
         hp:=tused_unit(current_module.used_units.first);
         while assigned(hp) do
           begin
{$IfDef GDB}
              if (cs_debuginfo in aktmoduleswitches) and
                 (cs_gdb_dbx in aktglobalswitches) and
                not hp.is_stab_written then
                begin
                   tglobalsymtable(hp.u.globalsymtable).concattypestabto(debuglist);
                   hp.is_stab_written:=true;
                   hp.unitid:=tsymtable(hp.u.globalsymtable).unitid;
                end;
{$EndIf GDB}
              if hp.in_uses then
                begin
                   hp3:=symtablestack;
                   while assigned(hp3) do
                     begin
                        { insert units only once ! }
                        if hp.u.globalsymtable=hp3 then
                          break;
                        hp3:=hp3.next;
                        { unit isn't inserted }
                        if hp3=nil then
                          begin
                             tsymtable(hp.u.globalsymtable).next:=symtablestack;
                             symtablestack:=tsymtable(hp.u.globalsymtable);
{$ifdef DEBUG}
                             test_symtablestack;
{$endif DEBUG}
                          end;
                     end;
                end;
              hp:=tused_unit(hp.next);
           end;
          aktprocsym:=oldprocsym;
          aktprocdef:=oldprocdef;
      end;


     procedure write_gdb_info;
{$IfDef GDB}
       var
         hp : tused_unit;
       begin
         if not (cs_debuginfo in aktmoduleswitches) then
          exit;
         if (cs_gdb_dbx in aktglobalswitches) then
           begin
             debugList.concat(Tai_asm_comment.Create(strpnew('EINCL of global '+
               tglobalsymtable(current_module.globalsymtable).name^+' has index '+
               tostr(tglobalsymtable(current_module.globalsymtable).unitid))));
             debugList.concat(Tai_stabs.Create(strpnew('"'+
               tglobalsymtable(current_module.globalsymtable).name^+'",'+
               tostr(N_EINCL)+',0,0,0')));
             tglobalsymtable(current_module.globalsymtable).dbx_count_ok:={true}false;
             dbx_counter:=tglobalsymtable(current_module.globalsymtable).prev_dbx_counter;
             do_count_dbx:=false;
           end;

         { now insert the units in the symtablestack }
         hp:=tused_unit(current_module.used_units.first);
         while assigned(hp) do
           begin
              if (cs_debuginfo in aktmoduleswitches) and
                not hp.is_stab_written then
                begin
                   tglobalsymtable(hp.u.globalsymtable).concattypestabto(debuglist);
                   hp.is_stab_written:=true;
                   hp.unitid:=tsymtable(hp.u.globalsymtable).unitid;
                end;
              hp:=tused_unit(hp.next);
           end;
         if current_module.in_implementation and
            assigned(current_module.localsymtable) then
           begin
              { all types }
              tstaticsymtable(current_module.localsymtable).concattypestabto(debuglist);
              { and all local symbols}
              tstaticsymtable(current_module.localsymtable).concatstabto(debuglist);
           end
         else if assigned(current_module.globalsymtable) then
           begin
              { all types }
              tglobalsymtable(current_module.globalsymtable).concattypestabto(debuglist);
              { and all local symbols}
              tglobalsymtable(current_module.globalsymtable).concatstabto(debuglist);
           end;
       end;
{$Else GDB}
       begin
       end;
{$EndIf GDB}


    procedure parse_implementation_uses(symt:tsymtable);
      begin
         if token=_USES then
           begin
              loadunits;
{$ifdef DEBUG}
              test_symtablestack;
{$endif DEBUG}
           end;
      end;


    procedure setupglobalswitches;
      begin
        { can't have local browser when no global browser }
        if (cs_local_browser in aktmoduleswitches) and
           not(cs_browser in aktmoduleswitches) then
          exclude(aktmoduleswitches,cs_local_browser);

        { define a symbol in delphi,objfpc,tp,gpc mode }
        if (m_delphi in aktmodeswitches) then
         current_scanner.def_macro('FPC_DELPHI')
        else
         if (m_tp7 in aktmodeswitches) then
          current_scanner.def_macro('FPC_TP')
        else
         if (m_objfpc in aktmodeswitches) then
          current_scanner.def_macro('FPC_OBJFPC')
        else
         if (m_gpc in aktmodeswitches) then
          current_scanner.def_macro('FPC_GPC');
      end;


    procedure gen_main_procsym(const name:string;options:tproctypeoption;st:tsymtable);
      var
        stt : tsymtable;
        procdefs : pprocdeflist;
      begin
        {Generate a procsym for main}
        make_ref:=false;
        aktprocsym:=tprocsym.create('$'+name);
        { main are allways used }
        inc(aktprocsym.refs);
        {Try to insert in in static symtable ! }
        stt:=symtablestack;
        symtablestack:=st;
        aktprocdef:=tprocdef.create;
        new(procdefs);
        procdefs^.def:=aktprocdef;
        procdefs^.next:=aktprocsym.defs;
        aktprocsym.defs:=procdefs;
        aktprocdef.procsym:=aktprocsym;
        symtablestack:=stt;
        aktprocdef.proctypeoption:=options;
        aktprocdef.setmangledname(target_info.cprefix+name);
        aktprocdef.forwarddef:=false;
        make_ref:=true;
        { The localst is a local symtable. Change it into the static
          symtable }
        aktprocdef.localst.free;
        aktprocdef.localst:=st;
        { and insert the procsym in symtable }
        st.insert(aktprocsym);
        { set some informations about the main program }
        with procinfo^ do
         begin
           _class:=nil;
           para_offset:=target_info.first_parm_offset;
           framepointer:=FRAME_POINTER_REG;
           flags:=0;
           procdef:=aktprocdef;
         end;
      end;

    procedure insertLocalThreadvarsTablesTable;
      var
        hp : tused_unit;
        ltvTables : taasmoutput;
        count : longint;
      begin
        ltvTables:=TAAsmOutput.Create;
        count:=0;
        hp:=tused_unit(usedunits.first);
        while assigned(hp) do
         begin
           If (hp.u.flags and uf_local_threadvars)=uf_local_threadvars then
            begin
              ltvTables.concat(Tai_const_symbol.Createname(hp.u.modulename^+'_$LOCALTHREADVARLIST'));
              inc(count);
            end;
           hp:=tused_unit(hp.next);
         end;
        { TableCount }
        ltvTables.insert(Tai_const.Create_32bit(count));
        ltvTables.insert(Tai_symbol.Createdataname_global('FPC_LOCALTHREADVARTABLES',0));
        ltvTables.concat(Tai_symbol_end.Createname('FPC_LOCALTHREADVARTABLES'));
        { insert in data segment }
        if (cs_create_smart in aktmoduleswitches) then
          dataSegment.concat(Tai_cut.Create);
        dataSegment.concatlist(ltvTables);
        ltvTables.free;
        if count > 0 then
          have_local_threadvars := true;
      end;


    procedure addToLocalThreadvarTab(p:tnamedindexitem;arg:pointer);
      var
        ltvTable : taasmoutput;
      begin
        ltvTable:=taasmoutput(arg);
        if (tsym(p).typ=varsym) and
           (vo_is_thread_var in tvarsym(p).varoptions) then
         begin
           { address of threadvar }
           ltvTable.concat(tai_const_symbol.create(newasmsymbol(tvarsym(p).mangledname)));
           { size of threadvar }
           ltvTable.concat(tai_const.create_32bit(tvarsym(p).getsize));
         end;
      end;



    procedure proc_unit;

      function is_assembler_generated:boolean;
      begin
        is_assembler_generated:=(Errorcount=0) and
          not(
          codeSegment.empty and
          dataSegment.empty and
          bssSegment.empty and
          ((importssection=nil) or importsSection.empty) and
          ((resourcesection=nil) or resourceSection.empty) and
          ((resourcestringlist=nil) or resourcestringList.empty)
        );
      end;

      var
         main_file: tinputfile;
         st     : tsymtable;
         unitst : tglobalsymtable;
{$ifdef GDB}
         pu     : tused_unit;
{$endif GDB}
         store_crc,store_interface_crc : cardinal;
         s2  : ^string; {Saves stack space}
         force_init_final : boolean;
         ltvTable : taasmoutput;
      begin
         consume(_UNIT);
         if compile_level=1 then
          Status.IsExe:=false;

         if token=_ID then
          begin
          { create filenames and unit name }
             main_file := current_scanner.inputfile;
             while assigned(main_file.next) do
               main_file := main_file.next;

             current_module.SetFileName(main_file.path^+main_file.name^,true);

             stringdispose(current_module.modulename);
             stringdispose(current_module.realmodulename);
             current_module.modulename:=stringdup(pattern);
             current_module.realmodulename:=stringdup(orgpattern);
          { check for system unit }
             new(s2);
             s2^:=upper(SplitName(main_file.name^));
             if (cs_check_unit_name in aktglobalswitches) and
                not((current_module.modulename^=s2^) or
                    ((length(current_module.modulename^)>8) and
                     (copy(current_module.modulename^,1,8)=s2^))) then
              Message1(unit_e_illegal_unit_name,current_module.realmodulename^);
             if (current_module.modulename^='SYSTEM') then
              include(aktmoduleswitches,cs_compilesystem);
             dispose(s2);
          end;

         consume(_ID);
         consume(_SEMICOLON);
         consume(_INTERFACE);
         { global switches are read, so further changes aren't allowed }
         current_module.in_global:=false;

         { handle the global switches }
         setupglobalswitches;

         Message1(unit_u_start_parse_interface,current_module.realmodulename^);

         { update status }
         status.currentmodule:=current_module.realmodulename^;

         { maybe turn off m_objpas if we are compiling objpas }
         if (current_module.modulename^='OBJPAS') then
           exclude(aktmodeswitches,m_objpas);

         parse_only:=true;

         { generate now the global symboltable }
         st:=tglobalsymtable.create(current_module.modulename^);
         refsymtable:=st;
         unitst:=tglobalsymtable(st);
         { define first as local to overcome dependency conflicts }
         current_module.localsymtable:=st;

         { the unit name must be usable as a unit specifier }
         { inside the unit itself (PM)                }
         { this also forbids to have another symbol      }
         { with the same name as the unit                  }
         refsymtable.insert(tunitsym.create(current_module.realmodulename^,unitst));

         { load default units, like the system unit }
         loaddefaultunits;

         { reset }
         make_ref:=true;
         lexlevel:=0;

         { insert qualifier for the system unit (allows system.writeln) }
         if not(cs_compilesystem in aktmoduleswitches) then
           begin
              if token=_USES then
                begin
                   loadunits;
                   { has it been compiled at a higher level ?}
                   if current_module.compiled then
                     begin
                        { this unit symtable is obsolete }
                        { dispose(unitst,done);
                        disposed as localsymtable !! }
                        RestoreUnitSyms;
                        exit;
                     end;
                end;
              { ... but insert the symbol table later }
              st.next:=symtablestack;
              symtablestack:=st;
           end
         else
         { while compiling a system unit, some types are directly inserted }
           begin
              st.next:=symtablestack;
              symtablestack:=st;
              insert_intern_types(st);
           end;

         { now we know the place to insert the constants }
         constsymtable:=symtablestack;

         { move the global symtab from the temporary local to global }
         current_module.globalsymtable:=current_module.localsymtable;
         current_module.localsymtable:=nil;

         reset_global_defs;

         { number all units, so we know if a unit is used by this unit or
           needs to be added implicitly }
         current_module.numberunits;

         { ... parse the declarations }
         Message1(parser_u_parsing_interface,current_module.realmodulename^);
         read_interface_declarations;

         { leave when we got an error }
         if (Errorcount>0) and not status.skip_error then
          begin
            Message1(unit_f_errors_in_unit,tostr(Errorcount));
            status.skip_error:=true;
            exit;
          end;
         {else  in inteface its somatimes necessary even if unused
          st^.allunitsused; }

{$ifdef New_GDB}
         write_gdb_info;
{$endIf Def New_GDB}

         if not(cs_compilesystem in aktmoduleswitches) then
           if (Errorcount=0) then
             tppumodule(current_module).getppucrc;

         { Parse the implementation section }
         consume(_IMPLEMENTATION);
         current_module.in_implementation:=true;
         Message1(unit_u_start_parse_implementation,current_module.modulename^);

         parse_only:=false;

         { generates static symbol table }
         st:=tstaticsymtable.create(current_module.modulename^);
         current_module.localsymtable:=st;

         { remove the globalsymtable from the symtable stack }
         { to reinsert it after loading the implementation units }
         symtablestack:=unitst.next;

         { we don't want implementation units symbols in unitsymtable !! PM }
         refsymtable:=st;

         { Read the implementation units }
         parse_implementation_uses(unitst);

         if current_module.compiled then
           begin
              RestoreUnitSyms;
              exit;
           end;

         { reset ranges/stabs in exported definitions }
         reset_global_defs;

         { All units are read, now give them a number }
         current_module.numberunits;

         { now we can change refsymtable }
         refsymtable:=st;

         { but reinsert the global symtable as lasts }
         unitst.next:=symtablestack;
         symtablestack:=unitst;

         tstoredsymtable(symtablestack).chainoperators;

{$ifdef DEBUG}
         test_symtablestack;
{$endif DEBUG}
         constsymtable:=symtablestack;

{$ifdef Splitheap}
         if testsplit then
           begin
              Split_Heap;
              allow_special:=true;
              Switch_to_temp_heap;
           end;
         { it will report all crossings }
         allow_special:=false;
{$endif Splitheap}

         Message1(parser_u_parsing_implementation,current_module.realmodulename^);

         { Compile the unit }
         codegen_newprocedure;
         gen_main_procsym(current_module.modulename^+'_init',potype_unitinit,st);
         aktprocdef.aliasnames.insert('INIT$$'+current_module.modulename^);
         aktprocdef.aliasnames.insert(target_info.cprefix+current_module.modulename^+'_init');
         compile_proc_body(true,false);
         codegen_doneprocedure;

         { avoid self recursive destructor call !! PM }
         aktprocdef.localst:=nil;

         { if the unit contains ansi/widestrings, initialization and
           finalization code must be forced }
         force_init_final:=tglobalsymtable(current_module.globalsymtable).needs_init_final or
                           tstaticsymtable(current_module.localsymtable).needs_init_final;

         { should we force unit initialization? }
         { this is a hack, but how can it be done better ? }
         if force_init_final and ((current_module.flags and uf_init)=0) then
           begin
              current_module.flags:=current_module.flags or uf_init;
              { now we can insert a cut }
              if (cs_create_smart in aktmoduleswitches) then
                codeSegment.concat(Tai_cut.Create);
              genimplicitunitinit(codesegment);
           end;
         { finalize? }
         if token=_FINALIZATION then
           begin
              { set module options }
              current_module.flags:=current_module.flags or uf_finalize;

              { Compile the finalize }
              codegen_newprocedure;
              gen_main_procsym(current_module.modulename^+'_finalize',potype_unitfinalize,st);
              aktprocdef.aliasnames.insert('FINALIZE$$'+current_module.modulename^);
              aktprocdef.aliasnames.insert(target_info.cprefix+current_module.modulename^+'_finalize');
              compile_proc_body(true,false);
              codegen_doneprocedure;
           end
         else if force_init_final then
           begin
              current_module.flags:=current_module.flags or uf_finalize;
              { now we can insert a cut }
              if (cs_create_smart in aktmoduleswitches) then
                codeSegment.concat(Tai_cut.Create);
              genimplicitunitfinal(codesegment);
           end;

         { generate a list of local threadvars }
         ltvTable:=TAAsmoutput.create;
         st.foreach_static({$ifdef FPCPROCVAR}@{$endif}addToLocalThreadvarTab,ltvTable);
         if ltvTable.first<>nil then
          begin
            { add begin and end of the list }
            ltvTable.insert(tai_symbol.createdataname_global(current_module.modulename^+'_$LOCALTHREADVARLIST',0));
            ltvTable.concat(tai_const.create_32bit(0));  { end of list marker }
            ltvTable.concat(tai_symbol_end.createname(current_module.modulename^+'_$LOCALTHREADVARLIST'));
            if (cs_create_smart in aktmoduleswitches) then
             dataSegment.concat(Tai_cut.Create);
            dataSegment.concatlist(ltvTable);
            current_module.flags:=current_module.flags or uf_local_threadvars;
          end;
         ltvTable.Free;

         { the last char should always be a point }
         consume(_POINT);

         If ResourceStrings.ResStrCount>0 then
          begin
            ResourceStrings.CreateResourceStringList;
            current_module.flags:=current_module.flags or uf_has_resources;
            { only write if no errors found }
            if (Errorcount=0) then
             ResourceStrings.WriteResourceFile(ForceExtension(current_module.ppufilename^,'.rst'));
          end;

         { avoid self recursive destructor call !! PM }
         aktprocdef.localst:=nil;
         { absence does not matter here !! }
         aktprocdef.forwarddef:=false;
         { test static symtable }
         if (Errorcount=0) then
           begin
             tstoredsymtable(st).allsymbolsused;
             tstoredsymtable(st).allunitsused;
             tstoredsymtable(st).allprivatesused;
           end;

         { size of the static data }
         datasize:=st.datasize;

{$ifdef GDB}
         { add all used definitions even for implementation}
         if (cs_debuginfo in aktmoduleswitches) then
          begin
{$IfnDef New_GDB}
            if assigned(current_module.globalsymtable) then
              begin
                 { all types }
                 tglobalsymtable(current_module.globalsymtable).concattypestabto(debuglist);
                 { and all local symbols}
                 tglobalsymtable(current_module.globalsymtable).concatstabto(debuglist);
              end;
            { all local types }
            tglobalsymtable(st)^.concattypestabto(debuglist);
            { and all local symbols}
            st^.concatstabto(debuglist);
{$else New_GDB}
            write_gdb_info;
{$endIf Def New_GDB}
          end;
{$endif GDB}

         reset_global_defs;

         if (Errorcount=0) then
           begin
             { tests, if all (interface) forwards are resolved }
             tstoredsymtable(symtablestack).check_forwards;
             { check if all private fields are used }
             tstoredsymtable(symtablestack).allprivatesused;
             { remove cross unit overloads }
             tstoredsymtable(symtablestack).unchain_overloaded;
           end;

         current_module.in_implementation:=false;
{$ifdef GDB}
         tglobalsymtable(symtablestack).is_stab_written:=false;
{$endif GDB}

         { leave when we got an error }
         if (Errorcount>0) and not status.skip_error then
          begin
            Message1(unit_f_errors_in_unit,tostr(Errorcount));
            status.skip_error:=true;
            exit;
          end;

         { generate imports }
         if current_module.uses_imports then
           importlib.generatelib;

         { insert own objectfile, or say that it's in a library
           (no check for an .o when loading) }
         if is_assembler_generated then
           insertobjectfile
         else
           current_module.flags:=current_module.flags or uf_no_link;

         if cs_local_browser in aktmoduleswitches then
           current_module.localsymtable:=refsymtable;
{$ifdef GDB}
         pu:=tused_unit(usedunits.first);
         while assigned(pu) do
           begin
              if assigned(pu.u.globalsymtable) then
                tglobalsymtable(pu.u.globalsymtable).is_stab_written:=false;
              pu:=tused_unit(pu.next);
           end;
{$endif GDB}

         if is_assembler_generated then
          begin
          { finish asmlist by adding segment starts }
            insertsegment;
          { assemble }
            create_objectfile;
          end;

         { Write out the ppufile after the object file has been created }
         store_interface_crc:=current_module.interface_crc;
         store_crc:=current_module.crc;
         if (Errorcount=0) then
           tppumodule(current_module).writeppu;

         if not(cs_compilesystem in aktmoduleswitches) then
           if store_interface_crc<>current_module.interface_crc then
             Comment(V_Warning,current_module.ppufilename^+' Interface CRC changed '+
               hexstr(store_crc,8)+'<>'+hexstr(current_module.interface_crc,8));
{$ifdef EXTDEBUG}
         if not(cs_compilesystem in aktmoduleswitches) then
           if (store_crc<>current_module.crc) and simplify_ppu then
             Comment(V_Warning,current_module.ppufilename^+' implementation CRC changed '+
               hexstr(store_crc,8)+'<>'+hexstr(current_module.crc,8));
{$endif EXTDEBUG}

         { remove static symtable (=refsymtable) here to save some mem }
         if not (cs_local_browser in aktmoduleswitches) then
           begin
              st.free;
              current_module.localsymtable:=nil;
           end;

         RestoreUnitSyms;

         { leave when we got an error }
         if (Errorcount>0) and not status.skip_error then
          begin
            Message1(unit_f_errors_in_unit,tostr(Errorcount));
            status.skip_error:=true;
            exit;
          end;
      end;


    procedure proc_program(islibrary : boolean);
      var
         main_file: tinputfile;
         st    : tsymtable;
         hp    : tmodule;
      begin
         DLLsource:=islibrary;
         Status.IsLibrary:=IsLibrary;
         Status.IsExe:=true;
         parse_only:=false;
         { relocation works only without stabs under win32 !! PM }
         { internal assembler uses rva for stabs info
           so it should work with relocated DLLs }
         if RelocSection and
            (target_info.target in [target_i386_win32,target_i386_wdosx]) and
            (target_info.assem<>as_i386_pecoff) then
           begin
              include(aktglobalswitches,cs_link_strip);
              { Warning stabs info does not work with reloc section !! }
              if cs_debuginfo in aktmoduleswitches then
                begin
                  Message1(parser_w_parser_reloc_no_debug,current_module.mainsource^);
                  Message(parser_w_parser_win32_debug_needs_WN);
                  exclude(aktmoduleswitches,cs_debuginfo);
                end;
           end;

         { get correct output names }
         main_file := current_scanner.inputfile;
         while assigned(main_file.next) do
           main_file := main_file.next;

         current_module.SetFileName(main_file.path^+main_file.name^,true);

         if islibrary then
           begin
              consume(_LIBRARY);
              stringdispose(current_module.modulename);
              current_module.modulename:=stringdup(pattern);
              current_module.islibrary:=true;
              exportlib.preparelib(pattern);
              consume(_ID);
              consume(_SEMICOLON);
           end
         else
           { is there an program head ? }
           if token=_PROGRAM then
            begin
              consume(_PROGRAM);
              stringdispose(current_module.modulename);
              stringdispose(current_module.realmodulename);
              current_module.modulename:=stringdup(pattern);
              current_module.realmodulename:=stringdup(orgpattern);
              if (target_info.target in [target_i386_WIN32,target_i386_wdosx]) then
                exportlib.preparelib(pattern);
              consume(_ID);
              if token=_LKLAMMER then
                begin
                   consume(_LKLAMMER);
                   consume_idlist;
                   consume(_RKLAMMER);
                end;
              consume(_SEMICOLON);
            end
         else if (target_info.target in [target_i386_WIN32,target_i386_wdosx]) then
           exportlib.preparelib(current_module.modulename^);

         { global switches are read, so further changes aren't allowed }
         current_module.in_global:=false;

         { setup things using the global switches }
         setupglobalswitches;

         { set implementation flag }
         current_module.in_implementation:=true;

         { insert after the unit symbol tables the static symbol table }
         { of the program                                             }
         st:=tstaticsymtable.create(current_module.modulename^);;
         current_module.localsymtable:=st;
         refsymtable:=st;

         { load standard units (system,objpas,profile unit) }
         loaddefaultunits;

         { reset }
         lexlevel:=0;

         {Load the units used by the program we compile.}
         if token=_USES then
           loadunits;

         tstoredsymtable(symtablestack).chainoperators;

         { reset ranges/stabs in exported definitions }
         reset_global_defs;

         { All units are read, now give them a number }
         current_module.numberunits;

         {Insert the name of the main program into the symbol table.}
         if current_module.realmodulename^<>'' then
           st.insert(tunitsym.create(current_module.realmodulename^,st));

         { ...is also constsymtable, this is the symtable where }
         { the elements of enumeration types are inserted       }
         constsymtable:=st;

         Message1(parser_u_parsing_implementation,current_module.mainsource^);

         {The program intialization needs an alias, so it can be called
          from the bootstrap code.}
         codegen_newprocedure;
         if islibrary then
          begin
            gen_main_procsym(current_module.modulename^+'_main',potype_proginit,st);
            aktprocdef.aliasnames.insert(target_info.cprefix+current_module.modulename^+'_main');
            aktprocdef.aliasnames.insert('PASCALMAIN');
            { this code is called from C so we need to save some
              registers }
            include(aktprocdef.procoptions,po_savestdregs);
          end
         else
          begin
            gen_main_procsym('main',potype_proginit,st);
            aktprocdef.aliasnames.insert('program_init');
            aktprocdef.aliasnames.insert('PASCALMAIN');
            aktprocdef.aliasnames.insert(target_info.cprefix+'main');
          end;
         insertLocalThreadvarsTablesTable;
         compile_proc_body(true,false);

         { Add symbol to the exports section for win32 so smartlinking a
           DLL will include the edata section }
         if assigned(exportlib) and
            (target_info.target in [target_i386_win32,target_i386_wdosx]) and
            assigned(current_module._exports.first) then
           codesegment.concat(tai_const_symbol.create(exportlib.edatalabel));

         { avoid self recursive destructor call !! PM }
         aktprocdef.localst:=nil;

         { consider these symbols as global ones for browser
           but the typecasting of the globalsymtable with tglobalsymtable
           can then lead to problems (PFV)
         current_module.globalsymtable:=current_module.localsymtable;
         current_module.localsymtable:=nil;}

         If ResourceStrings.ResStrCount>0 then
          begin
            ResourceStrings.CreateResourceStringList;
            { only write if no errors found }
            if (Errorcount=0) then
             ResourceStrings.WriteResourceFile(ForceExtension(current_module.ppufilename^,'.rst'));
          end;

         codegen_doneprocedure;

         { finalize? }
         if token=_FINALIZATION then
           begin
              { set module options }
              current_module.flags:=current_module.flags or uf_finalize;

              { Compile the finalize }
              codegen_newprocedure;
              gen_main_procsym(current_module.modulename^+'_finalize',potype_unitfinalize,st);
              aktprocdef.aliasnames.insert('FINALIZE$$'+current_module.modulename^);
              aktprocdef.aliasnames.insert(target_info.cprefix+current_module.modulename^+'_finalize');
              compile_proc_body(true,false);
              codegen_doneprocedure;
           end;

         { consume the last point }
         consume(_POINT);

{$ifdef New_GDB}
         write_gdb_info;
{$endIf Def New_GDB}
         { leave when we got an error }
         if (Errorcount>0) and not status.skip_error then
          begin
            Message1(unit_f_errors_in_unit,tostr(Errorcount));
            status.skip_error:=true;
            exit;
          end;

         { test static symtable }
         if (Errorcount=0) then
           begin
             tstoredsymtable(st).allsymbolsused;
             tstoredsymtable(st).allunitsused;
             tstoredsymtable(st).allprivatesused;
           end;

         { generate imports }
         if current_module.uses_imports then
          importlib.generatelib;

         if islibrary or
            (target_info.target in [target_i386_WIN32,target_i386_wdosx]) or
            (target_info.target=target_i386_NETWARE) then
           exportlib.generatelib;


         { insert heap }
         insertResourceTablesTable;

         insertinitfinaltable;
         insertheap;
         insertstacklength;

         datasize:=symtablestack.datasize;

         { finish asmlist by adding segment starts }
         insertsegment;

         { insert own objectfile }
         insertobjectfile;

         { assemble and link }
         create_objectfile;

         { leave when we got an error }
         if (Errorcount>0) and not status.skip_error then
          begin
            Message1(unit_f_errors_in_unit,tostr(Errorcount));
            status.skip_error:=true;
            exit;
          end;

         { create the executable when we are at level 1 }
         if (compile_level=1) then
          begin
            { insert all .o files from all loaded units }
            hp:=tmodule(loaded_units.first);
            while assigned(hp) do
             begin
               linker.AddModuleFiles(hp);
               hp:=tmodule(hp.next);
             end;
            { write .def file }
            if (cs_link_deffile in aktglobalswitches) then
             deffile.writefile;
            { finally we can create a executable }
            if (not current_module.is_unit) then
             begin
               if DLLSource then
                linker.MakeSharedLibrary
               else
                linker.MakeExecutable;
             end;
          end;
      end;

end.
{
  $Log$
  Revision 1.65  2002-05-14 19:34:49  peter
    * removed old logs and updated copyright year

  Revision 1.64  2002/05/12 16:53:09  peter
    * moved entry and exitcode to ncgutil and cgobj
    * foreach gets extra argument for passing local data to the
      iterator function
    * -CR checks also class typecasts at runtime by changing them
      into as
    * fixed compiler to cycle with the -CR option
    * fixed stabs with elf writer, finally the global variables can
      be watched
    * removed a lot of routines from cga unit and replaced them by
      calls to cgobj
    * u32bit-s32bit updates for and,or,xor nodes. When one element is
      u32bit then the other is typecasted also to u32bit without giving
      a rangecheck warning/error.
    * fixed pascal calling method with reversing also the high tree in
      the parast, detected by tcalcst3 test

  Revision 1.63  2002/05/06 19:54:50  carl
  + added more patches from Mazen for SPARC port

  Revision 1.62  2002/04/20 21:32:24  carl
  + generic FPC_CHECKPOINTER
  + first parameter offset in stack now portable
  * rename some constants
  + move some cpu stuff to other units
  - remove unused constents
  * fix stacksize for some targets
  * fix generic size problems which depend now on EXTEND_SIZE constant

  Revision 1.61  2002/04/19 15:46:02  peter
    * mangledname rewrite, tprocdef.mangledname is now created dynamicly
      in most cases and not written to the ppu
    * add mangeledname_prefix() routine to generate the prefix of
      manglednames depending on the current procedure, object and module
    * removed static procprefix since the mangledname is now build only
      on demand from tprocdef.mangledname

  Revision 1.60  2002/04/14 16:53:10  carl
  + align code section and data section according to alignment rules

  Revision 1.59  2002/04/07 17:58:38  carl
  + generic stack checking

  Revision 1.58  2002/04/04 19:06:03  peter
    * removed unused units
    * use tlocation.size in cg.a_*loc*() routines

  Revision 1.57  2002/04/04 18:42:49  carl
  + added wdosx support (patch from Pavel)

  Revision 1.56  2002/04/02 17:11:29  peter
    * tlocation,treference update
    * LOC_CONSTANT added for better constant handling
    * secondadd splitted in multiple routines
    * location_force_reg added for loading a location to a register
      of a specified size
    * secondassignment parses now first the right and then the left node
      (this is compatible with Kylix). This saves a lot of push/pop especially
      with string operations
    * adapted some routines to use the new cg methods

  Revision 1.55  2002/04/01 13:43:32  armin
  addToLocalThreadvarList used '_'+name instead of mangledname to find asm symbol

  Revision 1.54  2002/03/29 17:19:50  armin
  + allow exports for netware

  Revision 1.53  2002/03/29 09:00:56  armin
  + forgot to delete a debug writeln

  Revision 1.52  2002/03/28 16:07:52  armin
  + initialize threadvars defined local in units

  Revision 1.51  2002/01/24 18:25:49  peter
   * implicit result variable generation for assembler routines
   * removed m_tp modeswitch, use m_tp7 or not(m_fpc) instead

}
