{
    $Id$
    Copyright (c) 1998-2002 by Florian Klaempfl, Daniel Mantione

    Does the parsing of the procedures/functions

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
unit pdecsub;

{$i fpcdefs.inc}

interface

    uses
      tokens,symconst,symtype,symdef,symsym;

    const
      pd_global    = $1;    { directive must be global }
      pd_body      = $2;    { directive needs a body }
      pd_implemen  = $4;    { directive can be used implementation section }
      pd_interface = $8;    { directive can be used interface section }
      pd_object    = $10;   { directive can be used object declaration }
      pd_procvar   = $20;   { directive can be used procvar declaration }
      pd_notobject = $40;   { directive can not be used object declaration }
      pd_notobjintf= $80;   { directive can not be used interface declaration }

    function  is_proc_directive(tok:ttoken):boolean;

    procedure insert_hidden_para(pd:tabstractprocdef);
    procedure check_self_para(aktprocdef:tabstractprocdef);
    procedure parameter_dec(aktprocdef:tabstractprocdef);

    procedure parse_proc_directives(var pdflags:word);

    procedure handle_calling_convention(sym:tprocsym;def:tabstractprocdef);
    procedure calc_parasymtable_addresses(pd:tprocdef);

    procedure parse_proc_head(options:tproctypeoption);
    procedure parse_proc_dec;
    procedure parse_var_proc_directives(var sym : tsym);
    procedure parse_object_proc_directives(var sym : tprocsym);

    function proc_add_definition(aprocsym:tprocsym;var aprocdef : tprocdef) : boolean;


implementation

    uses
{$ifdef delphi}
       sysutils,
{$else delphi}
       strings,
{$endif delphi}
       { common }
       cutils,cclasses,
       { global }
       globtype,globals,verbose,
       systems,cpubase,
       { aasm }
       aasmbase,aasmtai,aasmcpu,
       { symtable }
       symbase,symtable,defutil,defcmp,paramgr,
       { pass 1 }
       node,htypechk,
       nmat,nadd,ncal,nset,ncnv,ninl,ncon,nld,nflw,
       { parser }
       fmodule,scanner,
       pbase,pexpr,ptype,pdecl,
       { linking }
       import,gendef,
       { codegen }
       cpuinfo,cgbase
       ;


    procedure insert_hidden_para(pd:tabstractprocdef);
      var
        currpara : tparaitem;
        hvs : tvarsym;
      begin
        { walk from right to left, so we can insert the
          high parameters after the current parameter }
        currpara:=tparaitem(pd.para.last);
        while assigned(currpara) do
         begin
           { needs high parameter ? }
           if paramanager.push_high_param(currpara.paratype.def,pd.proccalloption) then
            begin
              if assigned(currpara.parasym) then
               begin
                 hvs:=tvarsym.create('$high'+tvarsym(currpara.parasym).name,s32bittype);
                 hvs.varspez:=vs_const;
                 include(hvs.varoptions,vo_is_high_value);
                 tvarsym(currpara.parasym).owner.insert(hvs);
                 tvarsym(currpara.parasym).highvarsym:=hvs;
               end
              else
               hvs:=nil;
              pd.concatpara(currpara,s32bittype,hvs,vs_hidden,nil);
            end
           else
            begin
              { Give a warning that cdecl routines does not include high()
                support }
              if (pd.proccalloption in [pocall_cdecl,pocall_cppdecl]) and
                 paramanager.push_high_param(currpara.paratype.def,pocall_fpccall) then
               begin
                 if is_open_string(currpara.paratype.def) then
                    Message(parser_w_cdecl_no_openstring);
                 if not (po_external in pd.procoptions) then
                   Message(parser_w_cdecl_has_no_high);
               end;
            end;
           currpara:=tparaitem(currpara.previous);
         end;
      end;


    procedure checkvaluepara(p:tnamedindexitem;arg:pointer);
      begin
        if tsym(p).typ<>varsym then
         exit;
        with tvarsym(p) do
         begin
           { do we need a local copy? Then rename the varsym, do this after the
             insert so the dup id checking is done correctly.
             array of const and open array do not need this, the local copy routine
             will patch the pushed value to point to the local copy }
           if (varspez=vs_value) and
              paramanager.push_addr_param(vartype.def,aktprocdef.proccalloption) and
              not(is_array_of_const(vartype.def) or
                  is_open_array(vartype.def)) then
            aktprocdef.parast.symsearch.rename(name,'val'+name);
         end;
      end;


    procedure check_c_para(p:tnamedindexitem;arg:pointer);
      begin
        if (tsym(p).typ<>varsym) then
         exit;
        with tvarsym(p) do
         begin
           case vartype.def.deftype of
             arraydef :
               begin
                 if not is_variant_array(vartype.def) and
                    not is_array_of_const(vartype.def) then
                  begin
                    if (varspez<>vs_var) then
                      Message(parser_h_c_arrays_are_references);
                  end;
                 if is_array_of_const(vartype.def) and
                    assigned(indexnext) and
                    (tsym(indexnext).typ=varsym) and
                    not(vo_is_high_value in tvarsym(indexnext).varoptions) then
                   Message(parser_e_C_array_of_const_must_be_last);
               end;
            end;
         end;
      end;


    procedure check_self_para(aktprocdef:tabstractprocdef);
      var
        hpara : tparaitem;
      begin
        hpara:=aktprocdef.selfpara;
        if assigned(hpara) and
           (
            ((aktprocdef.deftype=procvardef) and
             (po_methodpointer in aktprocdef.procoptions)) or
            ((aktprocdef.deftype=procdef) and
             assigned(tprocdef(aktprocdef)._class))
           ) then
         begin
           include(aktprocdef.procoptions,po_containsself);
           if hpara.paratyp <> vs_value then
             CGMessage(parser_e_self_call_by_value);
           if (aktprocdef.deftype=procdef) then
            begin
              inc(procinfo.selfpointer_offset,tvarsym(hpara.parasym).address);
              if compare_defs(hpara.paratype.def,tprocdef(aktprocdef)._class,nothingn)=te_incompatible then
                CGMessage2(type_e_incompatible_types,hpara.paratype.def.typename,tprocdef(aktprocdef)._class.typename);
            end;
         end;
      end;


    procedure parameter_dec(aktprocdef:tabstractprocdef);
      {
        handle_procvar needs the same changes
      }
      var
        is_procvar : boolean;
        sc      : tsinglelist;
        tt      : ttype;
        arrayelementtype : ttype;
        vs      : tvarsym;
        srsym   : tsym;
        hs1 : string;
        varspez : Tvarspez;
        hpara      : tparaitem;
        tdefaultvalue : tconstsym;
        defaultrequired : boolean;
        old_object_option : tsymoptions;
        dummyst : tparasymtable;
        currparast : tparasymtable;
      begin
        consume(_LKLAMMER);
        { Delphi/Kylix supports nonsense like }
        { procedure p();                      }
        if try_to_consume(_RKLAMMER) and
          not(m_tp7 in aktmodeswitches) then
          exit;
        { parsing a proc or procvar ? }
        is_procvar:=(aktprocdef.deftype=procvardef);
        { create dummy symtable for procvars }
        if is_procvar then
         begin
           dummyst:=tparasymtable.create;
           currparast:=dummyst;
         end
        else
         begin
           currparast:=tparasymtable(tprocdef(aktprocdef).parast);
         end;
        { reset }
        sc:=tsinglelist.create;
        defaultrequired:=false;
        { the variables are always public }
        old_object_option:=current_object_option;
        current_object_option:=[sp_public];
        inc(testcurobject);
        repeat
          if try_to_consume(_VAR) then
            varspez:=vs_var
          else
            if try_to_consume(_CONST) then
              varspez:=vs_const
          else
            if (idtoken=_OUT) and (m_out in aktmodeswitches) then
              begin
                 consume(_OUT);
                 varspez:=vs_out
              end
          else
              varspez:=vs_value;
          tdefaultvalue:=nil;
          tt.reset;
          { read identifiers and insert with error type }
          sc.reset;
          repeat
            vs:=tvarsym.create(orgpattern,generrortype);
            currparast.insert(vs);
            if assigned(vs.owner) then
             sc.insert(vs)
            else
             vs.free;
            consume(_ID);
          until not try_to_consume(_COMMA);
          { read type declaration, force reading for value and const paras }
          if (token=_COLON) or (varspez=vs_value) then
           begin
             consume(_COLON);
             { check for an open array }
             if token=_ARRAY then
              begin
                consume(_ARRAY);
                consume(_OF);
                { define range and type of range }
                tt.setdef(tarraydef.create(0,-1,s32bittype));
                { array of const ? }
                if (token=_CONST) and (m_objpas in aktmodeswitches) then
                 begin
                   consume(_CONST);
                   srsym:=searchsymonlyin(systemunit,'TVARREC');
                   if not assigned(srsym) then
                    InternalError(1234124);
                   tarraydef(tt.def).setelementtype(ttypesym(srsym).restype);
                   tarraydef(tt.def).IsArrayOfConst:=true;
                 end
                else
                 begin
                   { define field type }
                   single_type(arrayelementtype,hs1,false);
                   tarraydef(tt.def).setelementtype(arrayelementtype);
                 end;
              end
             else
              begin
                { open string ? }
                if (varspez=vs_var) and
                        (
                          (
                            ((token=_STRING) or (idtoken=_SHORTSTRING)) and
                            (cs_openstring in aktmoduleswitches) and
                            not(cs_ansistrings in aktlocalswitches)
                          ) or
                        (idtoken=_OPENSTRING)) then
                 begin
                   consume(token);
                   tt:=openshortstringtype;
                   hs1:='openstring';
                 end
                else
                 begin
                   { everything else }
                   single_type(tt,hs1,false);
                 end;

                { default parameter }
                if (m_default_para in aktmodeswitches) then
                 begin
                   if try_to_consume(_EQUAL) then
                    begin
                      vs:=tvarsym(sc.first);
                      if assigned(vs.listnext) then
                        Message(parser_e_default_value_only_one_para);
                      { prefix 'def' to the parameter name }
                      tdefaultvalue:=ReadConstant('$def'+vs.name,vs.fileinfo);
                      if assigned(tdefaultvalue) then
                       tprocdef(aktprocdef).parast.insert(tdefaultvalue);
                      defaultrequired:=true;
                    end
                   else
                    begin
                      if defaultrequired then
                        Message1(parser_e_default_value_expected_for_para,vs.name);
                    end;
                 end;
              end;
           end
          else
           begin
{$ifndef UseNiceNames}
             hs1:='$$$';
{$else UseNiceNames}
             hs1:='var';
{$endif UseNiceNames}
             tt:=cformaltype;
           end;

          vs:=tvarsym(sc.first);
          while assigned(vs) do
           begin
             { update varsym }
             vs.vartype:=tt;
             vs.varspez:=varspez;
             { For proc vars we only need the definitions }
             if not is_procvar then
              begin
                if (varspez in [vs_var,vs_const,vs_out]) and
                   paramanager.push_addr_param(tt.def,aktprocdef.proccalloption) then
                  include(vs.varoptions,vo_regable);
                hpara:=aktprocdef.concatpara(nil,tt,vs,varspez,tdefaultvalue);
              end
             else
              hpara:=aktprocdef.concatpara(nil,tt,nil,varspez,tdefaultvalue);
             { save position of self parameter }
             if vs.name='SELF' then
              aktprocdef.selfpara:=hpara;
             vs:=tvarsym(vs.listnext);
           end;
        until not try_to_consume(_SEMICOLON);
        { remove parasymtable from stack }
        if is_procvar then
          dummyst.free;
        sc.free;
        { check for a self parameter, only for normal procedures. For
          procvars we need to wait until the 'of object' is parsed }
        if not is_procvar then
          check_self_para(aktprocdef);
        { reset object options }
        dec(testcurobject);
        current_object_option:=old_object_option;
        consume(_RKLAMMER);
      end;


    procedure parse_proc_head(options:tproctypeoption);
      var
        orgsp,sp:stringid;
        paramoffset:longint;
        sym:tsym;
        st : tsymtable;
        srsymtable : tsymtable;
        storepos,procstartfilepos : tfileposinfo;
        searchagain : boolean;
        i: longint;
      begin
        { Save the position where this procedure really starts }
        procstartfilepos:=akttokenpos;

        aktprocdef:=nil;

        if (options=potype_operator) then
          begin
            sp:=overloaded_names[optoken];
            orgsp:=sp;
          end
        else
          begin
            sp:=pattern;
            orgsp:=orgpattern;
            consume(_ID);
          end;

          { examine interface map: function/procedure iname.functionname=locfuncname }
          if parse_only and
             assigned(procinfo._class) and
             assigned(procinfo._class.implementedinterfaces) and
             (procinfo._class.implementedinterfaces.count>0) and
             try_to_consume(_POINT) then
            begin
               storepos:=akttokenpos;
               akttokenpos:=procstartfilepos;
               { get interface syms}
               searchsym(sp,sym,srsymtable);
               if not assigned(sym) then
                begin
                  identifier_not_found(orgsp);
                  sym:=generrorsym;
                end;
               akttokenpos:=storepos;
               { load proc name }
               if sym.typ=typesym then
                 i:=procinfo._class.implementedinterfaces.searchintf(ttypesym(sym).restype.def);
               { qualifier is interface name? }
               if (sym.typ<>typesym) or (ttypesym(sym).restype.def.deftype<>objectdef) or
                  (i=-1) then
                 begin
                    Message(parser_e_interface_id_expected);
                    aktprocsym:=nil;
                 end
               else
                 begin
                    aktprocsym:=tprocsym(procinfo._class.implementedinterfaces.interfaces(i).symtable.search(sp));
                    { the method can be declared after the mapping FK
                      if not(assigned(aktprocsym)) then
                        Message(parser_e_methode_id_expected);
                    }
                 end;
               consume(_ID);
               consume(_EQUAL);
               if (token=_ID) { and assigned(aktprocsym) } then
                 procinfo._class.implementedinterfaces.addmappings(i,sp,pattern);
               consume(_ID);
               exit;
          end;

        { method  ? }
        if not(parse_only) and
           (lexlevel=normal_function_level) and
           try_to_consume(_POINT) then
         begin
           { search for object name }
           storepos:=akttokenpos;
           akttokenpos:=procstartfilepos;
           searchsym(sp,sym,srsymtable);
           if not assigned(sym) then
            begin
              identifier_not_found(orgsp);
              sym:=generrorsym;
            end;
           akttokenpos:=storepos;
           { consume proc name }
           sp:=pattern;
           orgsp:=orgpattern;
           procstartfilepos:=akttokenpos;
           consume(_ID);
           { qualifier is class name ? }
           if (sym.typ<>typesym) or
              (ttypesym(sym).restype.def.deftype<>objectdef) then
             begin
                Message(parser_e_class_id_expected);
                aktprocsym:=nil;
                aktprocdef:=nil;
             end
           else
             begin
                { used to allow private syms to be seen }
                aktobjectdef:=tobjectdef(ttypesym(sym).restype.def);
                procinfo._class:=tobjectdef(ttypesym(sym).restype.def);
                aktprocsym:=tprocsym(procinfo._class.symtable.search(sp));
                {The procedure has been found. So it is
                 a global one. Set the flags to mark this.}
                procinfo.flags:=procinfo.flags or pi_is_global;
                aktobjectdef:=nil;
                { we solve this below }
                if assigned(aktprocsym) then
                  begin
                    if aktprocsym.typ<>procsym then
                     begin
                       {  we use a different error message for tp7 so it looks more compatible }
                       if (m_fpc in aktmodeswitches) then
                         Message1(parser_e_overloaded_no_procedure,aktprocsym.realname)
                       else
                         Message(parser_e_methode_id_expected);
                       { rename the name to an unique name to avoid an
                         error when inserting the symbol in the symtable }
                       orgsp:=orgsp+'$'+tostr(aktfilepos.line);
                       aktprocsym:=nil;
                     end;
                  end
                else
                  Message(parser_e_methode_id_expected);
             end;
         end
        else
         begin
           { check for constructor/destructor which is not allowed here }
           if (not parse_only) and
              (options in [potype_constructor,potype_destructor]) then
              Message(parser_e_constructors_always_objects);

           repeat
             searchagain:=false;
             akttokenpos:=procstartfilepos;
             aktprocsym:=tprocsym(symtablestack.search(sp));

             if not(parse_only) and
                not assigned(aktprocsym) and
                (symtablestack.symtabletype=staticsymtable) and
                assigned(symtablestack.next) and
                (symtablestack.next.unitid=0) then
               begin
                 {The procedure we prepare for is in the implementation
                  part of the unit we compile. It is also possible that we
                  are compiling a program, which is also some kind of
                  implementaion part.

                  We need to find out if the procedure is global. If it is
                  global, it is in the global symtable.}
                 aktprocsym:=tprocsym(symtablestack.next.search(sp));
               end;

             { Check if overloaded is a procsym }
             if assigned(aktprocsym) and
                (aktprocsym.typ<>procsym) then
              begin
                { when the other symbol is a unit symbol then hide the unit
                  symbol. Only in tp mode because it's bad programming }
                if (m_duplicate_names in aktmodeswitches) and
                   (aktprocsym.typ=unitsym) then
                 begin
                   aktprocsym.owner.rename(aktprocsym.name,'hidden'+aktprocsym.name);
                   searchagain:=true;
                 end
                else
                 begin
                   {  we use a different error message for tp7 so it looks more compatible }
                   if (m_fpc in aktmodeswitches) then
                    Message1(parser_e_overloaded_no_procedure,aktprocsym.realname)
                   else
                    DuplicateSym(aktprocsym);
                   { rename the name to an unique name to avoid an
                     error when inserting the symbol in the symtable }
                   orgsp:=orgsp+'$'+tostr(aktfilepos.line);
                   { generate a new aktprocsym }
                   aktprocsym:=nil;
                 end;
              end;
           until not searchagain;
         end;

        { test again if assigned, it can be reset to recover }
        if not assigned(aktprocsym) then
         begin
           { create a new procsym and set the real filepos }
           akttokenpos:=procstartfilepos;
           { for operator we have only one procsym for each overloaded
             operation }
           if (options=potype_operator) then
             begin
               { is the current overload sym already in the current unit }
               if assigned(overloaded_operators[optoken]) and
                  (overloaded_operators[optoken].owner=symtablestack) then
                 aktprocsym:=overloaded_operators[optoken]
               else
                 begin
                   { create the procsym with saving the original case }
                   aktprocsym:=tprocsym.create('$'+sp);
                   if assigned(overloaded_operators[optoken]) then
                     overloaded_operators[optoken].concat_procdefs_to(aktprocsym);
                 end;
             end
            else
             aktprocsym:=tprocsym.create(orgsp);
            symtablestack.insert(aktprocsym);
         end
        else
         begin
           { Set global flag when found in globalsytmable }
           if (not parse_only) and
              (aktprocsym.owner.symtabletype=globalsymtable) then
             procinfo.flags:=procinfo.flags or pi_is_global;
         end;

        st:=symtablestack;
        aktprocdef:=tprocdef.create;
        aktprocdef.symtablelevel:=symtablestack.symtablelevel;

        if assigned(procinfo._class) then
          aktprocdef._class := procinfo._class;

        { set the options from the caller (podestructor or poconstructor) }
        aktprocdef.proctypeoption:=options;

        { add procsym to the procdef }
        aktprocdef.procsym:=aktprocsym;

        { save file position and symbol options }
        aktprocdef.fileinfo:=procstartfilepos;
        aktprocdef.symoptions:=current_object_option;

        { this must also be inserted in the right symtable !! PM }
        { otherwise we get subbtle problems with
          definitions of args defs in staticsymtable for
          implementation of a global method }
        if token=_LKLAMMER then
          parameter_dec(aktprocdef);

        { calculate the offset of the parameters }
        paramoffset:=target_info.first_parm_offset;

        { calculate frame pointer offset }
        if lexlevel>normal_function_level then
          begin
            procinfo.framepointer_offset:=paramoffset;
            inc(paramoffset,pointer_size);
            { this is needed to get correct framepointer push for local
              forward functions !! }
            aktprocdef.parast.symtablelevel:=lexlevel;
          end;

        { Get self, vmt offsets }
        if assigned (procinfo._Class) then
         begin
           { self pointer offset, must be done after parsing the parameters }
           { self isn't pushed in nested procedure of methods }
           if (lexlevel=normal_function_level) then
            begin
              if assigned(aktprocdef) and
                 not(po_containsself in aktprocdef.procoptions) then
                begin
                  procinfo.selfpointer_offset:=paramoffset;
                  inc(paramoffset,POINTER_SIZE);
                end;
            end;

           { Special parameters for de-/constructors }
           case aktprocdef.proctypeoption of
             potype_constructor :
               begin
                 procinfo.vmtpointer_offset:=paramoffset;
                 inc(paramoffset,POINTER_SIZE);
               end;
             potype_destructor :
               begin
                 if is_object(procinfo._class) then
                  begin
                    procinfo.vmtpointer_offset:=paramoffset;
                    inc(paramoffset,POINTER_SIZE);
                  end
                 else
                  if is_class(procinfo._class) then
                   begin
                     procinfo.inheritedflag_offset:=paramoffset;
                     inc(paramoffset,POINTER_SIZE);
                   end
                 else
                  internalerror(200303261);
               end;
           end;
         end;

        procinfo.para_offset:=paramoffset;

        { so we only restore the symtable now }
        symtablestack:=st;
        if (options=potype_operator) then
          overloaded_operators[optoken]:=aktprocsym;
      end;


    procedure parse_proc_dec;
      var
        hs : string;
        isclassmethod : boolean;
      begin
        inc(lexlevel);
      { read class method }
        if try_to_consume(_CLASS) then
         begin
           { class method only allowed for procedures and functions }
           if not(token in [_FUNCTION,_PROCEDURE]) then
             Message(parser_e_procedure_or_function_expected);

           isclassmethod:=true;
         end
        else
         isclassmethod:=false;
        case token of
           _FUNCTION : begin
                         consume(_FUNCTION);
                         parse_proc_head(potype_none);
                         if token<>_COLON then
                          begin
                             if assigned(aktprocsym) and
                                not(is_interface(aktprocdef._class)) and
                                not(aktprocdef.forwarddef) or
                               (m_repeat_forward in aktmodeswitches) then
                             begin
                               consume(_COLON);
                               consume_all_until(_SEMICOLON);
                             end;
                          end
                         else
                          begin
                            consume(_COLON);
                            inc(testcurobject);
                            single_type(aktprocdef.rettype,hs,false);
                            aktprocdef.test_if_fpu_result;
                            if (aktprocdef.rettype.def.deftype=stringdef) and
                               (tstringdef(aktprocdef.rettype.def).string_typ<>st_shortstring) then
                              procinfo.no_fast_exit:=true;
                            dec(testcurobject);
                          end;
                       end;
          _PROCEDURE : begin
                         consume(_PROCEDURE);
                         parse_proc_head(potype_none);
                         if assigned(aktprocsym) then
                           aktprocdef.rettype:=voidtype;
                       end;
        _CONSTRUCTOR : begin
                         consume(_CONSTRUCTOR);
                         parse_proc_head(potype_constructor);
                         if assigned(procinfo._class) and
                            is_class(procinfo._class) then
                          begin
                            { CLASS constructors return the created instance }
                            aktprocdef.rettype.setdef(procinfo._class);
                          end
                         else
                          begin
                            { OBJECT constructors return a boolean }
                            aktprocdef.rettype:=booltype;
                          end;
                       end;
         _DESTRUCTOR : begin
                         consume(_DESTRUCTOR);
                         parse_proc_head(potype_destructor);
                         aktprocdef.rettype:=voidtype;
                       end;
           _OPERATOR : begin
                         if lexlevel>normal_function_level then
                           Message(parser_e_no_local_operator);
                         consume(_OPERATOR);
                         if (token in [first_overloaded..last_overloaded]) then
                          begin
                            procinfo.flags:=procinfo.flags or pi_operator;
                            optoken:=token;
                          end
                         else
                          begin
                            Message(parser_e_overload_operator_failed);
                            { Use the dummy NOTOKEN that is also declared
                              for the overloaded_operator[] }
                            optoken:=NOTOKEN;
                          end;
                         consume(Token);
                         parse_proc_head(potype_operator);
                         if token<>_ID then
                           begin
                              otsym:=nil;
                              if not(m_result in aktmodeswitches) then
                                consume(_ID);
                           end
                         else
                           begin
                             otsym:=tvarsym.create(pattern,voidtype);
                             consume(_ID);
                           end;
                         if not try_to_consume(_COLON) then
                           begin
                             consume(_COLON);
                             aktprocdef.rettype:=generrortype;
                             consume_all_until(_SEMICOLON);
                           end
                         else
                          begin
                            single_type(aktprocdef.rettype,hs,false);
                            aktprocdef.test_if_fpu_result;
                            if (optoken in [_EQUAL,_GT,_LT,_GTE,_LTE]) and
                               ((aktprocdef.rettype.def.deftype<>orddef) or
                                (torddef(aktprocdef.rettype.def).typ<>bool8bit)) then
                               Message(parser_e_comparative_operator_return_boolean);
                            if assigned(otsym) then
                              otsym.vartype.def:=aktprocdef.rettype.def;
                            if (optoken=_ASSIGNMENT) and
                               equal_defs(aktprocdef.rettype.def,
                                  tvarsym(aktprocdef.parast.symindex.first).vartype.def) then
                              message(parser_e_no_such_assignment)
                            else if not isoperatoracceptable(aktprocdef,optoken) then
                              Message(parser_e_overload_impossible);
                          end;
                       end;
        end;
        if isclassmethod and
           assigned(aktprocsym) then
          include(aktprocdef.procoptions,po_classmethod);
        { support procedure proc;stdcall export; in Delphi mode only }
        if not((m_delphi in aktmodeswitches) and
           is_proc_directive(token)) then
         consume(_SEMICOLON);
        dec(lexlevel);
      end;


{****************************************************************************
                        Procedure directive handlers
****************************************************************************}

procedure pd_far;
begin
  Message1(parser_w_proc_directive_ignored,'FAR');
end;

procedure pd_near;
begin
  Message1(parser_w_proc_directive_ignored,'NEAR');
end;

procedure pd_export;
begin
  if assigned(procinfo._class) then
    Message(parser_e_methods_dont_be_export);
  if lexlevel<>normal_function_level then
    Message(parser_e_dont_nest_export);
  { only os/2 and emx need this }
  if target_info.system in [system_i386_os2,system_i386_emx] then
   begin
     aktprocdef.aliasnames.insert(aktprocsym.realname);
     procinfo.exported:=true;
     if cs_link_deffile in aktglobalswitches then
       deffile.AddExport(aktprocdef.mangledname);
   end;
end;

procedure pd_forward;
begin
  aktprocdef.forwarddef:=true;
end;

procedure pd_alias;
begin
  consume(_COLON);
  aktprocdef.aliasnames.insert(get_stringconst);
end;

procedure pd_asmname;
begin
  aktprocdef.setmangledname(target_info.Cprefix+pattern);
  if token=_CCHAR then
    consume(_CCHAR)
  else
    consume(_CSTRING);
  { we don't need anything else }
  aktprocdef.forwarddef:=false;
end;

procedure pd_inline;
var
  hp : tparaitem;
begin
  { check if there is an array of const }
  hp:=tparaitem(aktprocdef.para.first);
  while assigned(hp) do
   begin
     if assigned(hp.paratype.def) and
        (hp.paratype.def.deftype=arraydef) then
      begin
        with tarraydef(hp.paratype.def) do
         if IsVariant or IsConstructor {or IsArrayOfConst} then
          begin
            Message1(parser_w_not_supported_for_inline,'array of const');
            Message(parser_w_inlining_disabled);
            aktprocdef.proccalloption:=pocall_fpccall;
          end;
      end;
     hp:=tparaitem(hp.next);
   end;
end;

procedure pd_intern;
begin
  consume(_COLON);
  aktprocdef.extnumber:=get_intconst;
end;

procedure pd_interrupt;
begin
  if lexlevel<>normal_function_level then
    Message(parser_e_dont_nest_interrupt);
end;

procedure pd_abstract;
begin
  if (po_virtualmethod in aktprocdef.procoptions) then
    include(aktprocdef.procoptions,po_abstractmethod)
  else
    Message(parser_e_only_virtual_methods_abstract);
  { the method is defined }
  aktprocdef.forwarddef:=false;
end;

procedure pd_virtual;
{$ifdef WITHDMT}
var
  pt : tnode;
{$endif WITHDMT}
begin
  if (aktprocdef.proctypeoption=potype_constructor) and
     is_object(aktprocdef._class) then
    Message(parser_e_constructor_cannot_be_not_virtual);
{$ifdef WITHDMT}
  if is_object(aktprocdef._class) and
    (token<>_SEMICOLON) then
    begin
       { any type of parameter is allowed here! }
       pt:=comp_expr(true);
       if is_constintnode(pt) then
         begin
           include(aktprocdef.procoptions,po_msgint);
           aktprocdef.messageinf.i:=pt^.value;
         end
       else
         Message(parser_e_ill_msg_expr);
       disposetree(pt);
    end;
{$endif WITHDMT}
end;

procedure pd_static;
begin
  if (cs_static_keyword in aktmoduleswitches) then
    begin
      include(aktprocsym.symoptions,sp_static);
      include(aktprocdef.procoptions,po_staticmethod);
    end;
end;

procedure pd_override;
begin
  if not(is_class_or_interface(aktprocdef._class)) then
    Message(parser_e_no_object_override);
end;

procedure pd_overload;
begin
   include(aktprocsym.symoptions,sp_has_overloaded);
end;

procedure pd_message;
var
  pt : tnode;
begin
  if not is_class(aktprocdef._class) then
    Message(parser_e_msg_only_for_classes);
  { check parameter type }
  if not(po_containsself in aktprocdef.procoptions) and
     ((aktprocdef.minparacount<>1) or
      (aktprocdef.maxparacount<>1) or
      (TParaItem(aktprocdef.Para.first).paratyp<>vs_var)) then
   Message(parser_e_ill_msg_param);
  pt:=comp_expr(true);
  if pt.nodetype=stringconstn then
    begin
      include(aktprocdef.procoptions,po_msgstr);
      aktprocdef.messageinf.str:=strnew(tstringconstnode(pt).value_str);
    end
  else
   if is_constintnode(pt) then
    begin
      include(aktprocdef.procoptions,po_msgint);
      aktprocdef.messageinf.i:=tordconstnode(pt).value;
    end
  else
    Message(parser_e_ill_msg_expr);
  pt.free;
end;


procedure pd_reintroduce;
begin
  Message1(parser_w_proc_directive_ignored,'REINTRODUCE');
end;


procedure pd_syscall;
begin
  aktprocdef.forwarddef:=false;
  aktprocdef.extnumber:=get_intconst;
end;


procedure pd_external;
{
  If import_dll=nil the procedure is assumed to be in another
  object file. In that object file it should have the name to
  which import_name is pointing to. Otherwise, the procedure is
  assumed to be in the DLL to which import_dll is pointing to. In
  that case either import_nr<>0 or import_name<>nil is true, so
  the procedure is either imported by number or by name. (DM)
}
var
  pd : tprocdef;
  import_dll,
  import_name : string;
  import_nr   : word;
begin
  aktprocdef.forwarddef:=false;
{ forbid local external procedures }
  if lexlevel>normal_function_level then
   Message(parser_e_no_local_external);
{ If the procedure should be imported from a DLL, a constant string follows.
  This isn't really correct, an contant string expression follows
  so we check if an semicolon follows, else a string constant have to
  follow (FK) }
  import_nr:=0;
  import_name:='';
  if not(token=_SEMICOLON) and not(idtoken=_NAME) then
    begin
      import_dll:=get_stringconst;
      if (idtoken=_NAME) then
       begin
         consume(_NAME);
         import_name:=get_stringconst;
       end;
      if (idtoken=_INDEX) then
       begin
         {After the word index follows the index number in the DLL.}
         consume(_INDEX);
         import_nr:=get_intconst;
       end;
      { default is to used the realname of the procedure }
      if (import_nr=0) and (import_name='') then
        import_name:=aktprocsym.realname;
      { create importlib if not already done }
      if not(current_module.uses_imports) then
       begin
         current_module.uses_imports:=true;
         importlib.preparelib(current_module.modulename^);
       end;
      if not(m_repeat_forward in aktmodeswitches) then
       begin
         { we can only have one overloaded here ! }
         if aktprocsym.procdef_count>1 then
          pd:=aktprocsym.procdef[2]
         else
          pd:=aktprocdef;
       end
      else
       pd:=aktprocdef;
      importlib.importproceduredef(pd,import_dll,import_nr,import_name);
    end
  else
    begin
      if (idtoken=_NAME) then
       begin
         consume(_NAME);
         import_name:=get_stringconst;
         aktprocdef.setmangledname(import_name);
       end;
    end;
end;

type
   pd_handler=procedure;
   proc_dir_rec=record
     idtok     : ttoken;
     pd_flags  : longint;
     handler   : pd_handler;
     pocall    : tproccalloption;
     pooption  : tprocoptions;
     mutexclpocall : tproccalloptions;
     mutexclpotype : tproctypeoptions;
     mutexclpo     : tprocoptions;
   end;
const
  {Should contain the number of procedure directives we support.}
  num_proc_directives=36;
  proc_direcdata:array[1..num_proc_directives] of proc_dir_rec=
   (
    (
      idtok:_ABSTRACT;
      pd_flags : pd_interface+pd_object+pd_notobjintf;
      handler  : {$ifdef FPCPROCVAR}@{$endif}pd_abstract;
      pocall   : pocall_none;
      pooption : [po_abstractmethod];
      mutexclpocall : [pocall_internproc,pocall_inline];
      mutexclpotype : [potype_constructor,potype_destructor];
      mutexclpo     : [po_exports,po_interrupt,po_external]
    ),(
      idtok:_ALIAS;
      pd_flags : pd_implemen+pd_body+pd_notobjintf;
      handler  : {$ifdef FPCPROCVAR}@{$endif}pd_alias;
      pocall   : pocall_none;
      pooption : [];
      mutexclpocall : [pocall_inline];
      mutexclpotype : [];
      mutexclpo     : [po_external]
    ),(
      idtok:_ASMNAME;
      pd_flags : pd_interface+pd_implemen+pd_notobjintf;
      handler  : {$ifdef FPCPROCVAR}@{$endif}pd_asmname;
      pocall   : pocall_cdecl;
      pooption : [po_external];
      mutexclpocall : [pocall_internproc,pocall_inline];
      mutexclpotype : [];
      mutexclpo     : [po_external]
    ),(
      idtok:_ASSEMBLER;
      pd_flags : pd_implemen+pd_body+pd_notobjintf;
      handler  : nil;
      pocall   : pocall_none;
      pooption : [po_assembler];
      mutexclpocall : [];
      mutexclpotype : [];
      mutexclpo     : [po_external]
    ),(
      idtok:_CDECL;
      pd_flags : pd_interface+pd_implemen+pd_body+pd_procvar;
      handler  : nil;
      pocall   : pocall_cdecl;
      pooption : [];
      mutexclpocall : [];
      mutexclpotype : [potype_constructor,potype_destructor];
      mutexclpo     : [po_assembler,po_external]
    ),(
      idtok:_DYNAMIC;
      pd_flags : pd_interface+pd_object+pd_notobjintf;
      handler  : {$ifdef FPCPROCVAR}@{$endif}pd_virtual;
      pocall   : pocall_none;
      pooption : [po_virtualmethod];
      mutexclpocall : [pocall_internproc,pocall_inline];
      mutexclpotype : [];
      mutexclpo     : [po_exports,po_interrupt,po_external]
    ),(
      idtok:_EXPORT;
      pd_flags : pd_body+pd_global+pd_interface+pd_implemen{??}+pd_notobjintf;
      handler  : {$ifdef FPCPROCVAR}@{$endif}pd_export;
      pocall   : pocall_none;
      pooption : [po_exports];
      mutexclpocall : [pocall_internproc,pocall_inline];
      mutexclpotype : [potype_constructor,potype_destructor];
      mutexclpo     : [po_external,po_interrupt]
    ),(
      idtok:_EXTERNAL;
      pd_flags : pd_implemen+pd_interface+pd_notobject+pd_notobjintf;
      handler  : {$ifdef FPCPROCVAR}@{$endif}pd_external;
      pocall   : pocall_none;
      pooption : [po_external];
      mutexclpocall : [pocall_internproc,pocall_inline,pocall_palmossyscall];
      mutexclpotype : [potype_constructor,potype_destructor];
      mutexclpo     : [po_exports,po_interrupt,po_assembler]
    ),(
      idtok:_FAR;
      pd_flags : pd_implemen+pd_body+pd_interface+pd_procvar+pd_notobject+pd_notobjintf;
      handler  : {$ifdef FPCPROCVAR}@{$endif}pd_far;
      pocall   : pocall_none;
      pooption : [];
      mutexclpocall : [pocall_internproc,pocall_inline];
      mutexclpotype : [];
      mutexclpo     : []
    ),(
      idtok:_FAR16;
      pd_flags : pd_interface+pd_implemen+pd_body+pd_procvar+pd_notobject;
      handler  : nil;
      pocall   : pocall_far16;
      pooption : [];
      mutexclpocall : [];
      mutexclpotype : [];
      mutexclpo     : [po_external,po_leftright]
    ),(
      idtok:_FORWARD;
      pd_flags : pd_implemen+pd_notobject+pd_notobjintf;
      handler  : {$ifdef FPCPROCVAR}@{$endif}pd_forward;
      pocall   : pocall_none;
      pooption : [];
      mutexclpocall : [pocall_internproc,pocall_inline];
      mutexclpotype : [];
      mutexclpo     : [po_external]
    ),(
      idtok:_FPCCALL;
      pd_flags : pd_interface+pd_implemen+pd_body+pd_procvar;
      handler  : nil;
      pocall   : pocall_fpccall;
      pooption : [];
      mutexclpocall : [];
      mutexclpotype : [];
      mutexclpo     : [po_leftright]
    ),(
      idtok:_INLINE;
      pd_flags : pd_interface+pd_implemen+pd_body+pd_notobjintf;
      handler  : {$ifdef FPCPROCVAR}@{$endif}pd_inline;
      pocall   : pocall_inline;
      pooption : [];
      mutexclpocall : [];
      mutexclpotype : [potype_constructor,potype_destructor];
      mutexclpo     : [po_exports,po_external,po_interrupt]
    ),(
      idtok:_INTERNCONST;
      pd_flags : pd_implemen+pd_body+pd_notobject+pd_notobjintf;
      handler  : {$ifdef FPCPROCVAR}@{$endif}pd_intern;
      pocall   : pocall_none;
      pooption : [po_internconst];
      mutexclpocall : [];
      mutexclpotype : [potype_operator];
      mutexclpo     : []
    ),(
      idtok:_INTERNPROC;
      pd_flags : pd_implemen+pd_notobject+pd_notobjintf;
      handler  : {$ifdef FPCPROCVAR}@{$endif}pd_intern;
      pocall   : pocall_internproc;
      pooption : [];
      mutexclpocall : [];
      mutexclpotype : [potype_constructor,potype_destructor,potype_operator];
      mutexclpo     : [po_exports,po_external,po_interrupt,po_assembler,po_iocheck,po_leftright]
    ),(
      idtok:_INTERRUPT;
      pd_flags : pd_implemen+pd_body+pd_notobject+pd_notobjintf;
      handler  : {$ifdef FPCPROCVAR}@{$endif}pd_interrupt;
      pocall   : pocall_none;
      pooption : [po_interrupt];
      mutexclpocall : [pocall_internproc,pocall_cdecl,pocall_cppdecl,
                       pocall_inline,pocall_pascal,pocall_system,pocall_far16,pocall_fpccall];
      mutexclpotype : [potype_constructor,potype_destructor,potype_operator];
      mutexclpo     : [po_external,po_leftright,po_clearstack]
    ),(
      idtok:_IOCHECK;
      pd_flags : pd_implemen+pd_body+pd_notobjintf;
      handler  : nil;
      pocall   : pocall_none;
      pooption : [po_iocheck];
      mutexclpocall : [pocall_internproc];
      mutexclpotype : [];
      mutexclpo     : [po_external]
    ),(
      idtok:_MESSAGE;
      pd_flags : pd_interface+pd_object+pd_notobjintf;
      handler  : {$ifdef FPCPROCVAR}@{$endif}pd_message;
      pocall   : pocall_none;
      pooption : []; { can be po_msgstr or po_msgint }
      mutexclpocall : [pocall_inline,pocall_internproc];
      mutexclpotype : [potype_constructor,potype_destructor,potype_operator];
      mutexclpo     : [po_interrupt,po_external]
    ),(
      idtok:_NEAR;
      pd_flags : pd_implemen+pd_body+pd_procvar+pd_notobjintf;
      handler  : {$ifdef FPCPROCVAR}@{$endif}pd_near;
      pocall   : pocall_none;
      pooption : [];
      mutexclpocall : [pocall_internproc];
      mutexclpotype : [];
      mutexclpo     : []
    ),(
      idtok:_OVERLOAD;
      pd_flags : pd_implemen+pd_interface+pd_body;
      handler  : {$ifdef FPCPROCVAR}@{$endif}pd_overload;
      pocall   : pocall_none;
      pooption : [po_overload];
      mutexclpocall : [pocall_internproc];
      mutexclpotype : [];
      mutexclpo     : []
    ),(
      idtok:_OVERRIDE;
      pd_flags : pd_interface+pd_object+pd_notobjintf;
      handler  : {$ifdef FPCPROCVAR}@{$endif}pd_override;
      pocall   : pocall_none;
      pooption : [po_overridingmethod,po_virtualmethod];
      mutexclpocall : [pocall_inline,pocall_internproc];
      mutexclpotype : [];
      mutexclpo     : [po_exports,po_external,po_interrupt]
    ),(
      idtok:_PASCAL;
      pd_flags : pd_interface+pd_implemen+pd_body+pd_procvar;
      handler  : nil;
      pocall   : pocall_pascal;
      pooption : [];
      mutexclpocall : [];
      mutexclpotype : [potype_constructor,potype_destructor];
      mutexclpo     : [po_external]
    ),(
      idtok:_POPSTACK;
      pd_flags : pd_interface+pd_implemen+pd_body+pd_procvar;
      handler  : nil;
      pocall   : pocall_none;
      pooption : [po_clearstack];
      mutexclpocall : [pocall_inline,pocall_internproc,pocall_stdcall];
      mutexclpotype : [potype_constructor,potype_destructor];
      mutexclpo     : [po_assembler,po_external]
    ),(
      idtok:_PUBLIC;
      pd_flags : pd_implemen+pd_body+pd_global+pd_notobject+pd_notobjintf;
      handler  : nil;
      pocall   : pocall_none;
      pooption : [];
      mutexclpocall : [pocall_internproc,pocall_inline];
      mutexclpotype : [];
      mutexclpo     : [po_external]
    ),(
      idtok:_REGISTER;
      pd_flags : pd_interface+pd_implemen+pd_body+pd_procvar;
      handler  : nil;
      pocall   : pocall_register;
      pooption : [];
      mutexclpocall : [];
      mutexclpotype : [potype_constructor,potype_destructor];
      mutexclpo     : [po_external]
    ),(
      idtok:_REINTRODUCE;
      pd_flags : pd_interface+pd_object;
      handler  : {$ifdef FPCPROCVAR}@{$endif}pd_reintroduce;
      pocall   : pocall_none;
      pooption : [];
      mutexclpocall : [];
      mutexclpotype : [];
      mutexclpo     : []
    ),(
      idtok:_SAFECALL;
      pd_flags : pd_interface+pd_implemen+pd_body+pd_procvar;
      handler  : nil;
      pocall   : pocall_safecall;
      pooption : [];
      mutexclpocall : [];
      mutexclpotype : [potype_constructor,potype_destructor];
      mutexclpo     : [po_external]
    ),(
      idtok:_SAVEREGISTERS;
      pd_flags : pd_interface+pd_implemen+pd_body+pd_procvar+pd_notobjintf;
      handler  : nil;
      pocall   : pocall_none;
      pooption : [po_saveregisters];
      mutexclpocall : [pocall_internproc];
      mutexclpotype : [potype_constructor,potype_destructor];
      mutexclpo     : [po_external]
    ),(
      idtok:_STATIC;
      pd_flags : pd_interface+pd_object+pd_notobjintf;
      handler  : {$ifdef FPCPROCVAR}@{$endif}pd_static;
      pocall   : pocall_none;
      pooption : [po_staticmethod];
      mutexclpocall : [pocall_inline,pocall_internproc];
      mutexclpotype : [potype_constructor,potype_destructor];
      mutexclpo     : [po_external,po_interrupt,po_exports]
    ),(
      idtok:_STDCALL;
      pd_flags : pd_interface+pd_implemen+pd_body+pd_procvar;
      handler  : nil;
      pocall   : pocall_stdcall;
      pooption : [];
      mutexclpocall : [];
      mutexclpotype : [potype_constructor,potype_destructor];
      mutexclpo     : [po_external]
    ),(
      idtok:_SYSCALL;
      pd_flags : pd_interface+pd_implemen+pd_notobjintf;
      handler  : {$ifdef FPCPROCVAR}@{$endif}pd_syscall;
      pocall   : pocall_palmossyscall;
      pooption : [];
      mutexclpocall : [];
      mutexclpotype : [potype_constructor,potype_destructor];
      mutexclpo     : [po_external,po_assembler,po_interrupt,po_exports]
    ),(
      idtok:_SYSTEM;
      pd_flags : pd_implemen+pd_notobject+pd_notobjintf;
      handler  : nil;
      pocall   : pocall_system;
      pooption : [];
      mutexclpocall : [];
      mutexclpotype : [potype_constructor,potype_destructor];
      mutexclpo     : [po_external,po_assembler,po_interrupt]
    ),(
      idtok:_VIRTUAL;
      pd_flags : pd_interface+pd_object+pd_notobjintf;
      handler  : {$ifdef FPCPROCVAR}@{$endif}pd_virtual;
      pocall   : pocall_none;
      pooption : [po_virtualmethod];
      mutexclpocall : [pocall_inline,pocall_internproc];
      mutexclpotype : [];
      mutexclpo     : [po_external,po_interrupt,po_exports]
    ),(
      idtok:_CPPDECL;
      pd_flags : pd_interface+pd_implemen+pd_body+pd_procvar;
      handler  : nil;
      pocall   : pocall_cppdecl;
      pooption : [po_savestdregs];
      mutexclpocall : [];
      mutexclpotype : [potype_constructor,potype_destructor];
      mutexclpo     : [po_assembler,po_external,po_virtualmethod]
    ),(
      idtok:_VARARGS;
      pd_flags : pd_interface+pd_implemen+pd_procvar;
      handler  : nil;
      pocall   : pocall_none;
      pooption : [po_varargs];
      mutexclpocall : [pocall_internproc,pocall_stdcall,pocall_register,
                       pocall_inline,pocall_far16,pocall_fpccall];
      mutexclpotype : [];
      mutexclpo     : [po_assembler,po_interrupt,po_leftright]
    ),(
      idtok:_COMPILERPROC;
      pd_flags : pd_interface+pd_implemen+pd_body+pd_notobjintf;
      handler  : nil;
      pocall   : pocall_compilerproc;
      pooption : [];
      mutexclpocall : [];
      mutexclpotype : [potype_constructor,potype_destructor];
      mutexclpo     : [po_interrupt]
    )
   );


    function is_proc_directive(tok:ttoken):boolean;
      var
        i : longint;
      begin
        is_proc_directive:=false;
        for i:=1 to num_proc_directives do
         if proc_direcdata[i].idtok=idtoken then
          begin
            is_proc_directive:=true;
            exit;
          end;
      end;


    function parse_proc_direc(var pdflags:word):boolean;
      {
        Parse the procedure directive, returns true if a correct directive is found
      }
      var
        p     : longint;
        found : boolean;
        name  : stringid;
      begin
        parse_proc_direc:=false;
        name:=tokeninfo^[idtoken].str;
        found:=false;

      { Hint directive? Then exit immediatly }
        if (m_hintdirective in aktmodeswitches) then
         begin
           case idtoken of
             _LIBRARY,
             _PLATFORM,
             _UNIMPLEMENTED,
             _DEPRECATED :
               exit;
           end;
         end;

      { retrieve data for directive if found }
        for p:=1 to num_proc_directives do
         if proc_direcdata[p].idtok=idtoken then
          begin
            found:=true;
            break;
          end;

      { Check if the procedure directive is known }
        if not found then
         begin
            { parsing a procvar type the name can be any
              next variable !! }
            if (pdflags and (pd_procvar or pd_object))=0 then
              Message1(parser_w_unknown_proc_directive_ignored,name);
            exit;
         end;

        { static needs a special treatment }
        if (idtoken=_STATIC) and not (cs_static_keyword in aktmoduleswitches) then
          exit;

      { Conflicts between directives ? }
        if (aktprocdef.proctypeoption in proc_direcdata[p].mutexclpotype) or
           (aktprocdef.proccalloption in proc_direcdata[p].mutexclpocall) or
           ((aktprocdef.procoptions*proc_direcdata[p].mutexclpo)<>[]) then
         begin
           Message1(parser_e_proc_dir_conflict,name);
           exit;
         end;

      { set calling convention }
        if proc_direcdata[p].pocall<>pocall_none then
         begin
           if aktprocdef.proccalloption<>pocall_none then
            begin
              Message2(parser_w_proc_overriding_calling,
                proccalloptionStr[aktprocdef.proccalloption],
                proccalloptionStr[proc_direcdata[p].pocall]);
            end;
           aktprocdef.proccalloption:=proc_direcdata[p].pocall;
         end;

        { check if method and directive not for object, like public.
          This needs to be checked also for procvars }
        if ((proc_direcdata[p].pd_flags and pd_notobject)<>0) and
           (aktprocdef.owner.symtabletype=objectsymtable) then
           exit;

        if aktprocdef.deftype=procdef then
         begin
           { Check if the directive is only for objects }
           if ((proc_direcdata[p].pd_flags and pd_object)<>0) and
              not assigned(aktprocdef._class) then
            exit;

           { check if method and directive not for interface }
           if ((proc_direcdata[p].pd_flags and pd_notobjintf)<>0) and
              is_interface(aktprocdef._class) then
            exit;
         end;

      { consume directive, and turn flag on }
        consume(token);
        parse_proc_direc:=true;

      { Check the pd_flags if the directive should be allowed }
        if ((pdflags and pd_interface)<>0) and
           ((proc_direcdata[p].pd_flags and pd_interface)=0) then
          begin
            Message1(parser_e_proc_dir_not_allowed_in_interface,name);
            exit;
          end;
        if ((pdflags and pd_implemen)<>0) and
           ((proc_direcdata[p].pd_flags and pd_implemen)=0) then
          begin
            Message1(parser_e_proc_dir_not_allowed_in_implementation,name);
            exit;
          end;
        if ((pdflags and pd_procvar)<>0) and
           ((proc_direcdata[p].pd_flags and pd_procvar)=0) then
          begin
            Message1(parser_e_proc_dir_not_allowed_in_procvar,name);
            exit;
          end;

      { Return the new pd_flags }
        if (proc_direcdata[p].pd_flags and pd_body)=0 then
          pdflags:=pdflags and (not pd_body);
        if (proc_direcdata[p].pd_flags and pd_global)<>0 then
          pdflags:=pdflags or pd_global;

      { Add the correct flag }
        aktprocdef.procoptions:=aktprocdef.procoptions+proc_direcdata[p].pooption;

      { Call the handler }
        if pointer({$ifndef FPCPROCVAR}@{$endif}proc_direcdata[p].handler)<>nil then
          proc_direcdata[p].handler{$ifdef FPCPROCVAR}(){$endif};
      end;


    procedure handle_calling_convention(sym:tprocsym;def:tabstractprocdef);
      begin
        { set the default calling convention }
        if def.proccalloption=pocall_none then
          def.proccalloption:=aktdefproccall;
        { handle proccall specific settings }
        case def.proccalloption of
          pocall_cdecl :
            begin
              { use popstack and save std registers }
              include(def.procoptions,po_clearstack);
              include(def.procoptions,po_savestdregs);
              { set mangledname }
              if (def.deftype=procdef) then
               begin
                 if not tprocdef(def).has_mangledname then
                  begin
                    if assigned(tprocdef(def)._class) then
                     tprocdef(def).setmangledname(target_info.Cprefix+tprocdef(def)._class.objrealname^+'_'+sym.realname)
                    else
                     tprocdef(def).setmangledname(target_info.Cprefix+sym.realname);
                  end;
                 if not assigned(tprocdef(def).parast) then
                  internalerror(200110234);
                 { check C cdecl para types }
                 tprocdef(def).parast.foreach_static({$ifdef FPCPROCVAR}@{$endif}check_c_para,nil);
                 { Adjust alignment to match cdecl or stdcall }
                 tprocdef(def).parast.dataalignment:=std_param_align;
               end;
            end;
          pocall_cppdecl :
            begin
              if not assigned(sym) then
               internalerror(200110231);
              { use popstack and save std registers }
              include(def.procoptions,po_clearstack);
              include(def.procoptions,po_savestdregs);
              { set mangledname }
              if (def.deftype=procdef) then
               begin
                 if not tprocdef(def).has_mangledname then
                  tprocdef(def).setmangledname(target_info.Cprefix+tprocdef(def).cplusplusmangledname);
                 if not assigned(tprocdef(def).parast) then
                  internalerror(200110235);
                 { check C cdecl para types }
                 tprocdef(def).parast.foreach_static({$ifdef FPCPROCVAR}@{$endif}check_c_para,nil);
                 { Adjust alignment to match cdecl or stdcall }
                 tprocdef(def).parast.dataalignment:=std_param_align;
               end;
            end;
          pocall_stdcall :
            begin
              include(def.procoptions,po_savestdregs);
              if (def.deftype=procdef) then
               begin
                 if not assigned(tprocdef(def).parast) then
                  internalerror(200110236);
                 { Adjust alignment to match cdecl or stdcall }
                 tprocdef(def).parast.dataalignment:=std_param_align;
               end;
            end;
          pocall_safecall :
            begin
              include(def.procoptions,po_savestdregs);
            end;
          pocall_compilerproc :
            begin
              if (not assigned(sym)) or
                 (def.deftype<>procdef) then
               internalerror(200110232);
              tprocdef(def).setmangledname(lower(sym.name));
            end;
          pocall_pascal :
            begin
              include(def.procoptions,po_leftright);
            end;
          pocall_register :
            begin
              Message1(parser_w_proc_directive_ignored,'REGISTER');
            end;
          pocall_far16 :
            begin
              { Temporary stub, must be rewritten to support OS/2 far16 }
              Message1(parser_w_proc_directive_ignored,'FAR16');
            end;
          pocall_system :
            begin
              include(def.procoptions,po_clearstack);
              if (not assigned(sym)) or
                 (def.deftype<>procdef) then
               internalerror(200110233);
              if not tprocdef(def).has_mangledname then
               tprocdef(def).setmangledname(sym.realname);
            end;
          pocall_palmossyscall :
            begin
              { use popstack and save std registers }
              include(def.procoptions,po_clearstack);
              include(def.procoptions,po_savestdregs);
              if (def.deftype=procdef) then
               begin
                 if not assigned(tprocdef(def).parast) then
                  internalerror(200110236);
                 { Adjust positions of args for cdecl or stdcall }
                 tprocdef(def).parast.dataalignment:=std_param_align;
               end;
            end;
          pocall_inline :
            begin
              if not(cs_support_inline in aktmoduleswitches) then
               begin
                 Message(parser_e_proc_inline_not_supported);
                 def.proccalloption:=pocall_fpccall;
               end;
            end;
        end;

        { insert hidden high parameters }
        insert_hidden_para(def);

        { insert local valXXX value parameters }
        if (def.deftype=procdef) then
          tprocdef(def).parast.foreach_static({$ifdef FPCPROCVAR}@{$endif}checkvaluepara,nil);


        { add mangledname to external list }
        if (def.deftype=procdef) and
           (po_external in def.procoptions) and
           target_info.DllScanSupported then
           current_module.externals.insert(tExternalsItem.create(tprocdef(def).mangledname));
      end;


    procedure calc_parasymtable_addresses(pd:tprocdef);
      var
        currpara : tparaitem;
        st : tsymtable;
      begin
        st:=pd.parast;
        if po_leftright in pd.procoptions then
         begin
           { pushed from left to right, so the in reverse order
             on the stack }
           currpara:=tparaitem(pd.para.last);
           while assigned(currpara) do
            begin
              if not(assigned(currpara.parasym) and (currpara.parasym.typ=varsym)) then
                internalerror(200304231);
              st.insertvardata(currpara.parasym);
              currpara:=tparaitem(currpara.previous);
            end;
         end
        else
         begin
           { pushed from right to left }
           currpara:=tparaitem(pd.para.first);
           while assigned(currpara) do
            begin
              if not(assigned(currpara.parasym) and (currpara.parasym.typ=varsym)) then
                internalerror(200304232);
              st.insertvardata(currpara.parasym);
              currpara:=tparaitem(currpara.next);
            end;
         end;
      end;



    procedure parse_proc_directives(var pdflags:word);
      {
        Parse the procedure directives. It does not matter if procedure directives
        are written using ;procdir; or ['procdir'] syntax.
      }
      var
        res : boolean;
      begin
        while token in [_ID,_LECKKLAMMER] do
         begin
           if try_to_consume(_LECKKLAMMER) then
            begin
              repeat
                parse_proc_direc(pdflags);
              until not try_to_consume(_COMMA);
              consume(_RECKKLAMMER);
              { we always expect at least '[];' }
              res:=true;
            end
           else
            begin
              res:=parse_proc_direc(pdflags);
            end;
         { A procedure directive normally followed by a semicolon, but in
           a const section we should stop when _EQUAL is found }
           if res then
            begin
              if (block_type=bt_const) and
                 (token=_EQUAL) then
               break;
              { support procedure proc;stdcall export; in Delphi mode only }
              if not((m_delphi in aktmodeswitches) and
                     is_proc_directive(token)) then
               consume(_SEMICOLON);
            end
           else
            break;
         end;
        handle_calling_convention(aktprocsym,aktprocdef);
        { calculate addresses in parasymtable }
        if aktprocdef.deftype=procdef then
          calc_parasymtable_addresses(aktprocdef);
      end;


    procedure parse_var_proc_directives(var sym : tsym);
      var
        pdflags : word;
        oldsym  : tprocsym;
        olddef  : tprocdef;
        pd      : tabstractprocdef;
      begin
        oldsym:=aktprocsym;
        olddef:=aktprocdef;
        pdflags:=pd_procvar;
        { we create a temporary aktprocsym to read the directives }
        aktprocsym:=tprocsym.create(sym.name);
        case sym.typ of
          varsym :
            pd:=tabstractprocdef(tvarsym(sym).vartype.def);
          typedconstsym :
            pd:=tabstractprocdef(ttypedconstsym(sym).typedconsttype.def);
          typesym :
            pd:=tabstractprocdef(ttypesym(sym).restype.def);
          else
            internalerror(994932432);
        end;
        if pd.deftype<>procvardef then
         internalerror(994932433);
        tabstractprocdef(aktprocdef):=pd;
        { names should never be used anyway }
        inc(lexlevel);
        parse_proc_directives(pdflags);
        dec(lexlevel);
        aktprocsym.free;
        aktprocsym:=oldsym;
        aktprocdef:=olddef;
      end;


    procedure parse_object_proc_directives(var sym : tprocsym);
      var
        pdflags : word;
      begin
        pdflags:=pd_object;
        inc(lexlevel);
        parse_proc_directives(pdflags);
        dec(lexlevel);
        if (po_containsself in aktprocdef.procoptions) and
           (([po_msgstr,po_msgint]*aktprocdef.procoptions)=[]) then
          Message(parser_e_self_in_non_message_handler);
      end;


    function proc_add_definition(aprocsym:tprocsym;var aprocdef : tprocdef) : boolean;
      {
        Add definition aprocdef to the overloaded definitions of aprocsym. If a
        forwarddef is found and reused it returns true
      }
      var
        hd    : tprocdef;
        ad,fd : tsym;
        i     : cardinal;
        forwardfound : boolean;
        po_comp : tprocoptions;
      begin
        forwardfound:=false;

        { check overloaded functions if the same function already exists }
        for i:=1 to aprocsym.procdef_count do
         begin
           hd:=aprocsym.procdef[i];

           { Skip overloaded definitions that are declared in other
             units }
           if hd.procsym<>aprocsym then
             continue;

           { check the parameters, for delphi/tp it is possible to
             leave the parameters away in the implementation (forwarddef=false).
             But for an overload declared function this is not allowed }
           if { check if empty implementation arguments match is allowed }
              (
               not(m_repeat_forward in aktmodeswitches) and
               not(aprocdef.forwarddef) and
               (aprocdef.maxparacount=0) and
               not(po_overload in hd.procoptions)
              ) or
              { check arguments }
              (
               (compare_paras(aprocdef.para,hd.para,cp_none,false)>=te_equal) and
               { for operators equal_paras is not enough !! }
               ((aprocdef.proctypeoption<>potype_operator) or (optoken<>_ASSIGNMENT) or
                equal_defs(hd.rettype.def,aprocdef.rettype.def))
              ) then
             begin
               { Check if we've found the forwarddef, if found then
                 we need to update the forward def with the current
                 implementation settings }
               if hd.forwarddef then
                 begin
                   forwardfound:=true;

                   { Check if the procedure type and return type are correct,
                     also the parameters must match also with the type }
                   if (hd.proctypeoption<>aprocdef.proctypeoption) or
                      (
                       (m_repeat_forward in aktmodeswitches) and
                       (not((aprocdef.maxparacount=0) or
                            (compare_paras(aprocdef.para,hd.para,cp_all,false)>=te_equal)))
                      ) or
                      (
                       ((m_repeat_forward in aktmodeswitches) or
                        not(is_void(aprocdef.rettype.def))) and
                       (not equal_defs(hd.rettype.def,aprocdef.rettype.def))) then
                     begin
                       MessagePos1(aprocdef.fileinfo,parser_e_header_dont_match_forward,
                                   aprocdef.fullprocname);
                       aprocsym.write_parameter_lists(aprocdef);
                       break;
                     end;

                   { Check if both are declared forward }
                   if hd.forwarddef and aprocdef.forwarddef then
                    begin
                      MessagePos1(aprocdef.fileinfo,parser_e_function_already_declared_public_forward,
                                  aprocdef.fullprocname);
                    end;

                   { internconst or internproc only need to be defined once }
                   if (hd.proccalloption=pocall_internproc) then
                    aprocdef.proccalloption:=hd.proccalloption
                   else
                    if (aprocdef.proccalloption=pocall_internproc) then
                     hd.proccalloption:=aprocdef.proccalloption;
                   if (po_internconst in hd.procoptions) then
                    include(aprocdef.procoptions,po_internconst)
                   else if (po_internconst in aprocdef.procoptions) then
                    include(hd.procoptions,po_internconst);

                   { Check calling convention }
                   if (hd.proccalloption<>aprocdef.proccalloption) then
                    begin
                      { In delphi it is possible to specify the calling
                        convention in the interface or implementation if
                        there was no convention specified in the other
                        part }
                      if (m_delphi in aktmodeswitches) then
                       begin
                         if (aprocdef.proccalloption=pocall_none) then
                          aprocdef.proccalloption:=hd.proccalloption
                         else
                          if (hd.proccalloption=pocall_none) then
                           hd.proccalloption:=aprocdef.proccalloption
                         else
                          begin
                            MessagePos(aprocdef.fileinfo,parser_e_call_convention_dont_match_forward);
                            aprocsym.write_parameter_lists(aprocdef);
                            { restore interface settings }
                            aprocdef.proccalloption:=hd.proccalloption;
                          end;
                       end
                      else
                       begin
                         MessagePos(aprocdef.fileinfo,parser_e_call_convention_dont_match_forward);
                         aprocsym.write_parameter_lists(aprocdef);
                         { restore interface settings }
                         aprocdef.proccalloption:=hd.proccalloption;
                       end;
                    end;

                   { Check procedure options, Delphi requires that class is
                     repeated in the implementation for class methods }
                   if (m_fpc in aktmodeswitches) then
                     po_comp:=[po_varargs,po_methodpointer,po_containsself,po_interrupt,po_clearstack]
                   else
                     po_comp:=[po_classmethod,po_methodpointer,po_containsself];

                   if ((po_comp * hd.procoptions)<>(po_comp * aprocdef.procoptions)) then
                     begin
                       MessagePos1(aprocdef.fileinfo,parser_e_header_dont_match_forward,
                                   aprocdef.fullprocname);
                       aprocsym.write_parameter_lists(aprocdef);
                       { This error is non-fatal, we can recover }
                     end;

                   { Check manglednames }
                   if (m_repeat_forward in aktmodeswitches) or
                      aprocdef.haspara then
                    begin
                      { If mangled names are equal then they have the same amount of arguments }
                      { We can check the names of the arguments }
                      { both symtables are in the same order from left to right }
                      ad:=tsym(hd.parast.symindex.first);
                      fd:=tsym(aprocdef.parast.symindex.first);
                      repeat
                        { skip default parameter constsyms }
                        while assigned(ad) and (ad.typ<>varsym) do
                         ad:=tsym(ad.indexnext);
                        while assigned(fd) and (fd.typ<>varsym) do
                         fd:=tsym(fd.indexnext);
                        { stop when one of the two lists is at the end }
                        if not assigned(ad) or not assigned(fd) then
                         break;
                        if (ad.name<>fd.name) then
                         begin
                           MessagePos3(aprocdef.fileinfo,parser_e_header_different_var_names,
                                       aprocsym.name,ad.name,fd.name);
                           break;
                         end;
                        ad:=tsym(ad.indexnext);
                        fd:=tsym(fd.indexnext);
                      until false;
                      if assigned(ad) xor assigned(fd) then
                        internalerror(200204178);
                    end;

                   { Everything is checked, now we can update the forward declaration
                     with the new data from the implementation }
                   hd.forwarddef:=aprocdef.forwarddef;
                   hd.hasforward:=true;
                   hd.parast.address_fixup:=aprocdef.parast.address_fixup;
                   hd.procoptions:=hd.procoptions+aprocdef.procoptions;
                   if hd.extnumber=65535 then
                     hd.extnumber:=aprocdef.extnumber;
                   while not aprocdef.aliasnames.empty do
                    hd.aliasnames.insert(aprocdef.aliasnames.getfirst);
                   { update mangledname if the implementation has a fixed mangledname set }
                   if aprocdef.has_mangledname then
                    begin
                      { rename also asmsymbol first, because the name can already be used }
                      objectlibrary.renameasmsymbol(hd.mangledname,aprocdef.mangledname);
                      hd.setmangledname(aprocdef.mangledname);
                    end;
                   { for compilerproc defines we need to rename and update the
                     symbolname to lowercase }
                   if (aprocdef.proccalloption=pocall_compilerproc) then
                    begin
                      { rename to lowercase so users can't access it }
                      aprocsym.owner.rename(aprocsym.name,lower(aprocsym.name));
                      { also update the realname that is stored in the ppu }
                      stringdispose(aprocsym._realname);
                      aprocsym._realname:=stringdup('$'+aprocsym.name);
                      { the mangeled name is already changed by the pd_compilerproc }
                      { handler. It must be done immediately because if we have a   }
                      { call to a compilerproc before it's implementation is        }
                      { encountered, it must already use the new mangled name (JM)  }
                    end;

                   { return the forwarddef }
                   aprocdef:=hd;
                 end
               else
                begin
                  { abstract methods aren't forward defined, but this }
                  { needs another error message                   }
                  if (po_abstractmethod in hd.procoptions) then
                    MessagePos(aprocdef.fileinfo,parser_e_abstract_no_definition)
                  else
                    MessagePos(aprocdef.fileinfo,parser_e_overloaded_have_same_parameters);
                 end;

               { we found one proc with the same arguments, there are no others
                 so we can stop }
               break;
             end;

           { check for allowing overload directive }
           if not(m_fpc in aktmodeswitches) then
            begin
              { overload directive turns on overloading }
              if ((po_overload in aprocdef.procoptions) or
                  (po_overload in hd.procoptions)) then
               begin
                 { check if all procs have overloading, but not if the proc was
                   already declared forward, then the check is already done }
                 if not(hd.hasforward or
                        (aprocdef.forwarddef<>hd.forwarddef) or
                        ((po_overload in aprocdef.procoptions) and
                         (po_overload in hd.procoptions))) then
                  begin
                    MessagePos1(aprocdef.fileinfo,parser_e_no_overload_for_all_procs,aprocsym.realname);
                    break;
                  end;
               end
              else
               begin
                 if not(hd.forwarddef) then
                  begin
                    MessagePos(aprocdef.fileinfo,parser_e_procedure_overloading_is_off);
                    break;
                  end;
               end;
            end; { equal arguments }
         end;

        { if we didn't reuse a forwarddef then we add the procdef to the overloaded
          list }
        if not forwardfound then
         begin
           aprocsym.addprocdef(aprocdef);
           { add overloadnumber for unique naming, the overloadcount is
             counted per module and 0 for the first procedure }
           aprocdef.overloadnumber:=aprocsym.overloadcount;
           inc(aprocsym.overloadcount);
         end;

        { insert otsym only in the right symtable }
        if ((procinfo.flags and pi_operator)<>0) and
           assigned(otsym) then
         begin
           if not parse_only then
            begin
              if paramanager.ret_in_param(aprocdef.rettype.def,aprocdef.proccalloption) then
               begin
                 aprocdef.parast.insert(otsym);
                 { this allows to read the funcretoffset }
                 otsym.address:=-4;
                 otsym.varspez:=vs_var;
               end
              else
               begin
                 if not assigned(aprocdef.localst) then
                  aprocdef.insert_localst;
                 aprocdef.localst.insert(otsym);
                 aprocdef.localst.insertvardata(otsym);
               end;
            end
           else
            begin
              { this is not required anymore }
              otsym.free;
              otsym:=nil;
            end;
         end;
        paramanager.create_param_loc_info(aprocdef);
        proc_add_definition:=forwardfound;
      end;

end.
{
  $Log$
  Revision 1.115  2003-04-24 13:03:01  florian
    * comp is now written with its bit pattern to the ppu instead as an extended

  Revision 1.114  2003/04/23 13:12:26  peter
    * fix po_comp setting for fpc mode

  Revision 1.113  2003/04/23 10:12:51  peter
    * don't check po_varargs for delphi

  Revision 1.112  2003/04/22 13:47:08  peter
    * fixed C style array of const
    * fixed C array passing
    * fixed left to right with high parameters

  Revision 1.111  2003/04/10 17:57:53  peter
    * vs_hidden released

  Revision 1.110  2003/03/28 19:16:56  peter
    * generic constructor working for i386
    * remove fixed self register
    * esi added as address register for i386

  Revision 1.109  2003/03/23 23:21:42  hajny
    + emx target added

  Revision 1.108  2003/03/19 17:34:04  peter
    * only allow class [procedure|function]

  Revision 1.107  2003/03/17 18:56:02  peter
    * fix crash with duplicate id

  Revision 1.106  2003/03/17 15:54:22  peter
    * store symoptions also for procdef
    * check symoptions (private,public) when calculating possible
      overload candidates

  Revision 1.105  2003/01/15 20:02:28  carl
    * fix highname problem

  Revision 1.104  2003/01/12 15:42:23  peter
    * m68k pathexist update from 1.0.x
    * palmos res update from 1.0.x

  Revision 1.103  2003/01/07 19:16:38  peter
    * removed some duplicate code when creating aktprocsym

  Revision 1.102  2003/01/05 18:17:45  peter
    * more conflicts for constructor/destructor types

  Revision 1.100  2003/01/02 19:49:00  peter
    * update self parameter only for methodpointer and methods

  Revision 1.99  2003/01/01 22:51:03  peter
    * high value insertion changed so it works also when 2 parameters
      are passed

  Revision 1.98  2003/01/01 14:35:33  peter
    * don't check for export directive repeat

  Revision 1.97  2002/12/29 18:16:06  peter
    * delphi allows setting calling convention in interface or
      implementation

  Revision 1.96  2002/12/29 14:55:44  peter
    * fix static method check
    * don't require class for class methods in the implementation for
      non delphi modes

  Revision 1.95  2002/12/27 15:25:14  peter
    * check procoptions when a forward is found
    * exclude some call directives for constructor/destructor

  Revision 1.94  2002/12/25 01:26:56  peter
    * duplicate procsym-unitsym fix

  Revision 1.93  2002/12/24 21:21:06  peter
    * remove code that skipped the _ prefix for win32 imports

  Revision 1.92  2002/12/23 21:24:22  peter
    * fix wrong internalerror when var names were different

  Revision 1.91  2002/12/23 20:58:52  peter
    * cdecl array fix, hack to change it to vs_var is not needed

  Revision 1.90  2002/12/17 22:19:33  peter
    * fixed pushing of records>8 bytes with stdcall
    * simplified hightree loading

  Revision 1.89  2002/12/15 21:07:30  peter
    * don't allow external in object declarations

  Revision 1.88  2002/12/15 19:34:31  florian
    + some front end stuff for vs_hidden added

  Revision 1.87  2002/12/07 14:27:07  carl
    * 3% memory optimization
    * changed some types
    + added type checking with different size for call node and for
       parameters

  Revision 1.86  2002/12/06 17:51:10  peter
    * merged cdecl and array fixes

  Revision 1.85  2002/12/01 22:06:14  carl
    * cleanup of error messages

  Revision 1.84  2002/11/29 22:31:19  carl
    + unimplemented hint directive added
    * hint directive parsing implemented
    * warning on these directives

  Revision 1.83  2002/11/27 02:35:28  peter
    * fixed typo in method comparing

  Revision 1.82  2002/11/25 17:43:21  peter
    * splitted defbase in defutil,symutil,defcmp
    * merged isconvertable and is_equal into compare_defs(_ext)
    * made operator search faster by walking the list only once

  Revision 1.81  2002/11/18 17:31:58  peter
    * pass proccalloption to ret_in_xxx and push_xxx functions

  Revision 1.80  2002/11/17 16:31:56  carl
    * memory optimization (3-4%) : cleanup of tai fields,
       cleanup of tdef and tsym fields.
    * make it work for m68k

  Revision 1.79  2002/11/16 14:20:50  peter
    * fix infinite loop in pd_inline

  Revision 1.78  2002/11/15 01:58:53  peter
    * merged changes from 1.0.7 up to 04-11
      - -V option for generating bug report tracing
      - more tracing for option parsing
      - errors for cdecl and high()
      - win32 import stabs
      - win32 records<=8 are returned in eax:edx (turned off by default)
      - heaptrc update
      - more info for temp management in .s file with EXTDEBUG

  Revision 1.77  2002/10/06 15:09:12  peter
    * variant:=nil supported

  Revision 1.76  2002/09/27 21:13:29  carl
    * low-highval always checked if limit ober 2GB is reached (to avoid overflow)

  Revision 1.75  2002/09/16 14:11:13  peter
    * add argument to equal_paras() to support default values or not

  Revision 1.74  2002/09/10 16:27:28  peter
    * don't insert parast in symtablestack, because typesyms should not be
      searched in the the parast

  Revision 1.73  2002/09/09 19:39:07  peter
    * check return type for forwarddefs also not delphi mode when
      the type is not void

  Revision 1.72  2002/09/09 17:34:15  peter
    * tdicationary.replace added to replace and item in a dictionary. This
      is only allowed for the same name
    * varsyms are inserted in symtable before the types are parsed. This
      fixes the long standing "var longint : longint" bug
    - consume_idlist and idstringlist removed. The loops are inserted
      at the callers place and uses the symtable for duplicate id checking

  Revision 1.71  2002/09/07 15:25:06  peter
    * old logs removed and tabs fixed

  Revision 1.70  2002/09/03 16:26:27  daniel
    * Make Tprocdef.defs protected

  Revision 1.69  2002/09/01 12:11:33  peter
    * calc param_offset after parameters are read, because the calculation
      depends on po_containself

  Revision 1.68  2002/08/25 19:25:20  peter
    * sym.insert_in_data removed
    * symtable.insertvardata/insertconstdata added
    * removed insert_in_data call from symtable.insert, it needs to be
      called separatly. This allows to deref the address calculation
    * procedures now calculate the parast addresses after the procedure
      directives are parsed. This fixes the cdecl parast problem
    * push_addr_param has an extra argument that specifies if cdecl is used
      or not

  Revision 1.67  2002/08/25 11:33:06  peter
    * also check the paratypes when a forward was found

  Revision 1.66  2002/08/19 19:36:44  peter
    * More fixes for cross unit inlining, all tnodes are now implemented
    * Moved pocall_internconst to po_internconst because it is not a
      calling type at all and it conflicted when inlining of these small
      functions was requested

  Revision 1.65  2002/08/18 20:06:24  peter
    * inlining is now also allowed in interface
    * renamed write/load to ppuwrite/ppuload
    * tnode storing in ppu
    * nld,ncon,nbas are already updated for storing in ppu

  Revision 1.64  2002/08/17 09:23:39  florian
    * first part of procinfo rewrite

  Revision 1.63  2002/08/11 14:32:27  peter
    * renamed current_library to objectlibrary

  Revision 1.62  2002/08/11 13:24:12  peter
    * saving of asmsymbols in ppu supported
    * asmsymbollist global is removed and moved into a new class
      tasmlibrarydata that will hold the info of a .a file which
      corresponds with a single module. Added librarydata to tmodule
      to keep the library info stored for the module. In the future the
      objectfiles will also be stored to the tasmlibrarydata class
    * all getlabel/newasmsymbol and friends are moved to the new class

  Revision 1.61  2002/07/26 21:15:40  florian
    * rewrote the system handling

  Revision 1.60  2002/07/20 11:57:55  florian
    * types.pas renamed to defbase.pas because D6 contains a types
      unit so this would conflicts if D6 programms are compiled
    + Willamette/SSE2 instructions to assembler added

  Revision 1.59  2002/07/11 14:41:28  florian
    * start of the new generic parameter handling

  Revision 1.58  2002/07/01 18:46:25  peter
    * internal linker
    * reorganized aasm layer

  Revision 1.57  2002/05/18 13:34:12  peter
    * readded missing revisions

  Revision 1.56  2002/05/16 19:46:42  carl
  + defines.inc -> fpcdefs.inc to avoid conflicts if compiling by hand
  + try to fix temp allocation (still in ifdef)
  + generic constructor calls
  + start of tassembler / tmodulebase class cleanup

  Revision 1.54  2002/05/12 16:53:08  peter
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

  Revision 1.53  2002/04/21 19:02:04  peter
    * removed newn and disposen nodes, the code is now directly
      inlined from pexpr
    * -an option that will write the secondpass nodes to the .s file, this
      requires EXTDEBUG define to actually write the info
    * fixed various internal errors and crashes due recent code changes

  Revision 1.52  2002/04/20 21:32:24  carl
  + generic FPC_CHECKPOINTER
  + first parameter offset in stack now portable
  * rename some constants
  + move some cpu stuff to other units
  - remove unused constents
  * fix stacksize for some targets
  * fix generic size problems which depend now on EXTEND_SIZE constant

  Revision 1.51  2002/04/20 15:27:05  carl
  - remove ifdef i386 define

  Revision 1.50  2002/04/19 15:46:02  peter
    * mangledname rewrite, tprocdef.mangledname is now created dynamicly
      in most cases and not written to the ppu
    * add mangeledname_prefix() routine to generate the prefix of
      manglednames depending on the current procedure, object and module
    * removed static procprefix since the mangledname is now build only
      on demand from tprocdef.mangledname

}
