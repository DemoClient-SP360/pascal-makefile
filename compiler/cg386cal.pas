{
    $Id$
    Copyright (c) 1998-2000 by Florian Klaempfl

    Generate i386 assembler for in call nodes

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published bymethodpointer
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
{$ifdef FPC}
  {$goto on}
{$endif FPC}
unit cg386cal;
interface

{ $define AnsiStrRef}

    uses
      symtable,tree;

    procedure secondcallparan(var p : ptree;defcoll : pparaitem;
                push_from_left_to_right,inlined,is_cdecl : boolean;para_alignment,para_offset : longint);
    procedure secondcalln(var p : ptree);
    procedure secondprocinline(var p : ptree);


implementation

    uses
      globtype,systems,
      cobjects,verbose,globals,
      symconst,aasm,types,
{$ifdef GDB}
      strings,gdb,
{$endif GDB}
      hcodegen,temp_gen,pass_2,
      cpubase,cpuasm,
      cgai386,tgeni386,cg386ld;

{*****************************************************************************
                             SecondCallParaN
*****************************************************************************}

    procedure secondcallparan(var p : ptree;defcoll : pparaitem;
                push_from_left_to_right,inlined,is_cdecl : boolean;para_alignment,para_offset : longint);

      procedure maybe_push_high;
        begin
           { open array ? }
           { defcoll^.data can be nil for read/write }
           if assigned(defcoll^.paratype.def) and
              push_high_param(defcoll^.paratype.def) then
             begin
               if assigned(p^.hightree) then
                begin
                  secondpass(p^.hightree);
                  { this is a longint anyway ! }
                  push_value_para(p^.hightree,inlined,false,para_offset,4);
                end
               else
                internalerror(432645);
             end;
        end;

      procedure prepareout(const r : treference);

        var
           hr : treference;
           pushed : tpushed;

        begin
           { out parameters needs to be finalized }
           if (defcoll^.paratype.def^.needs_inittable) then
             begin
                reset_reference(hr);
                hr.symbol:=defcoll^.paratype.def^.get_inittable_label;
                emitpushreferenceaddr(hr);
                emitpushreferenceaddr(r);
                emitcall('FPC_FINALIZE');
             end
           else
           { or at least it zeroed out }
             begin
                case defcoll^.paratype.def^.size of
                   1:
                     emit_const_ref(A_MOV,S_B,0,newreference(r));
                   2:
                     emit_const_ref(A_MOV,S_W,0,newreference(r));
                   4:
                     emit_const_ref(A_MOV,S_L,0,newreference(r));
                   else
                     begin
                        pushusedregisters(pushed,$ff);
                        emit_const(A_PUSH,S_W,0);
                        push_int(defcoll^.paratype.def^.size);
                        emitpushreferenceaddr(r);
                        emitcall('FPC_FILLCHAR');
                        popusedregisters(pushed);
                     end
                end;
             end;
        end;
      var
         otlabel,oflabel : pasmlabel;
         { temporary variables: }
         tempdeftype : tdeftype;
         r : preference;

      begin
         { set default para_alignment to target_os.stackalignment }
         if para_alignment=0 then
          para_alignment:=target_os.stackalignment;

         { push from left to right if specified }
         if push_from_left_to_right and assigned(p^.right) then
           secondcallparan(p^.right,pparaitem(defcoll^.next),push_from_left_to_right,
             inlined,is_cdecl,para_alignment,para_offset);
         otlabel:=truelabel;
         oflabel:=falselabel;
         getlabel(truelabel);
         getlabel(falselabel);
         secondpass(p^.left);
         { filter array constructor with c styled args }
         if is_array_constructor(p^.left^.resulttype) and p^.left^.cargs then
           begin
             { nothing, everything is already pushed }
           end
         { in codegen.handleread.. defcoll^.data is set to nil }
         else if assigned(defcoll^.paratype.def) and
           (defcoll^.paratype.def^.deftype=formaldef) then
           begin
              { allow @var }
              inc(pushedparasize,4);
              if (p^.left^.treetype=addrn) and
                 (not p^.left^.procvarload) then
                begin
                { always a register }
                  if inlined then
                    begin
                       r:=new_reference(procinfo^.framepointer,para_offset-pushedparasize);
                       emit_reg_ref(A_MOV,S_L,
                         p^.left^.location.register,r);
                    end
                  else
                    emit_reg(A_PUSH,S_L,p^.left^.location.register);
                  ungetregister32(p^.left^.location.register);
                end
              else
                begin
                   if not(p^.left^.location.loc in [LOC_MEM,LOC_REFERENCE]) then
                     CGMessage(type_e_mismatch)
                   else
                     begin
                       if inlined then
                         begin
{$ifndef noAllocEdi}
                           getexplicitregister32(R_EDI);
{$endif noAllocEdi}
                           emit_ref_reg(A_LEA,S_L,
                             newreference(p^.left^.location.reference),R_EDI);
                           r:=new_reference(procinfo^.framepointer,para_offset-pushedparasize);
                           emit_reg_ref(A_MOV,S_L,R_EDI,r);
{$ifndef noAllocEdi}
                           ungetregister32(R_EDI);
{$endif noAllocEdi}
                         end
                      else
                        emitpushreferenceaddr(p^.left^.location.reference);
                        del_reference(p^.left^.location.reference);
                     end;
                end;
           end
         { handle call by reference parameter }
         else if (defcoll^.paratyp in [vs_var,vs_out]) then
           begin
              if (p^.left^.location.loc<>LOC_REFERENCE) then
                CGMessage(cg_e_var_must_be_reference);
              maybe_push_high;
              inc(pushedparasize,4);
              if inlined then
                begin
{$ifndef noAllocEdi}
                   getexplicitregister32(R_EDI);
{$endif noAllocEdi}
                   emit_ref_reg(A_LEA,S_L,
                     newreference(p^.left^.location.reference),R_EDI);
                   r:=new_reference(procinfo^.framepointer,para_offset-pushedparasize);
                   emit_reg_ref(A_MOV,S_L,R_EDI,r);
{$ifndef noAllocEdi}
                   ungetregister32(R_EDI);
{$endif noAllocEdi}
                end
              else
                emitpushreferenceaddr(p^.left^.location.reference);
              if defcoll^.paratyp=vs_out then
                prepareout(p^.left^.location.reference);
              del_reference(p^.left^.location.reference);
           end
         else
           begin
              tempdeftype:=p^.resulttype^.deftype;
              if tempdeftype=filedef then
               CGMessage(cg_e_file_must_call_by_reference);
              { open array must always push the address, this is needed to
                also push addr of small arrays (PFV) }

              if ((assigned(defcoll^.paratype.def) and
                  is_open_array(defcoll^.paratype.def)) or
                 push_addr_param(p^.resulttype)) and
                 not is_cdecl then
                begin
                   maybe_push_high;
                   inc(pushedparasize,4);
                   if inlined then
                     begin
{$ifndef noAllocEdi}
                        getexplicitregister32(R_EDI);
{$endif noAllocEdi}
                        emit_ref_reg(A_LEA,S_L,
                          newreference(p^.left^.location.reference),R_EDI);
                        r:=new_reference(procinfo^.framepointer,para_offset-pushedparasize);
                        emit_reg_ref(A_MOV,S_L,R_EDI,r);
{$ifndef noAllocEdi}
                        ungetregister32(R_EDI);
{$endif noAllocEdi}
                     end
                   else
                     emitpushreferenceaddr(p^.left^.location.reference);
                   del_reference(p^.left^.location.reference);
                end
              else
                begin
                   push_value_para(p^.left,inlined,is_cdecl,
                     para_offset,para_alignment);
                end;
           end;
         truelabel:=otlabel;
         falselabel:=oflabel;
         { push from right to left }
         if not push_from_left_to_right and assigned(p^.right) then
           secondcallparan(p^.right,pparaitem(defcoll^.next),push_from_left_to_right,
             inlined,is_cdecl,para_alignment,para_offset);
      end;


{*****************************************************************************
                             SecondCallN
*****************************************************************************}

    procedure secondcalln(var p : ptree);
      var
         unusedregisters : tregisterset;
         usablecount : byte;
         pushed : tpushed;
         hr,funcretref : treference;
         hregister,hregister2 : tregister;
         oldpushedparasize : longint;
         { true if ESI must be loaded again after the subroutine }
         loadesi : boolean;
         { true if a virtual method must be called directly }
         no_virtual_call : boolean;
         { true if we produce a con- or destrutor in a call }
         is_con_or_destructor : boolean;
         { true if a constructor is called again }
         extended_new : boolean;
         { adress returned from an I/O-error }
         iolabel : pasmlabel;
         { lexlevel count }
         i : longint;
         { help reference pointer }
         r : preference;
         hp,
         pp,params : ptree;
         inlined : boolean;
         inlinecode : ptree;
         para_alignment,
         para_offset : longint;
         { instruction for alignement correction }
{        corr : paicpu;}
         { we must pop this size also after !! }
{        must_pop : boolean; }
         pop_size : longint;
         pop_allowed : boolean;
{$ifdef OPTALIGN}
         pop_esp : boolean;
         push_size : longint;
{$endif OPTALIGN}


      label
         dont_call;

      begin
         reset_reference(p^.location.reference);
         extended_new:=false;
         iolabel:=nil;
         inlinecode:=nil;
         inlined:=false;
         loadesi:=true;
         no_virtual_call:=false;
         unusedregisters:=unused;
         usablecount:=usablereg32;

         if (pocall_cdecl in p^.procdefinition^.proccalloptions) or
            (pocall_stdcall in p^.procdefinition^.proccalloptions) then
          para_alignment:=4
         else
          para_alignment:=target_os.stackalignment;

         if not assigned(p^.procdefinition) then
          exit;

         { Deciding whether we may still need the parameters happens next (JM) }
         params:=p^.left;

         if (pocall_inline in p^.procdefinition^.proccalloptions) then
           begin
              { make a copy for the next time the procedure is inlined (JM) }
              p^.left:=getcopy(p^.left);
              inlined:=true;
              inlinecode:=p^.right;
              { set it to the same lexical level as the local symtable, becuase
                the para's are stored there }
              pprocdef(p^.procdefinition)^.parast^.symtablelevel:=aktprocsym^.definition^.localst^.symtablelevel;
              if assigned(params) then
                inlinecode^.para_offset:=gettempofsizepersistant(inlinecode^.para_size);
              pprocdef(p^.procdefinition)^.parast^.address_fixup:=inlinecode^.para_offset;
{$ifdef extdebug}
             Comment(V_debug,
               'inlined parasymtable is at offset '
               +tostr(pprocdef(p^.procdefinition)^.parast^.address_fixup));
             exprasmlist^.concat(new(pai_asm_comment,init(
               strpnew('inlined parasymtable is at offset '
               +tostr(pprocdef(p^.procdefinition)^.parast^.address_fixup)))));
{$endif extdebug}
              { copy for the next time the procedure is inlined (JM) }
              p^.right:=getcopy(p^.right);
              { disable further inlining of the same proc
                in the args }
              exclude(p^.procdefinition^.proccalloptions,pocall_inline);
           end
         else
           { parameters not necessary anymore (JM) }
           p^.left := nil;
         { only if no proc var }
         if inlined or
            not(assigned(p^.right)) then
           is_con_or_destructor:=(p^.procdefinition^.proctypeoption in [potype_constructor,potype_destructor]);
         { proc variables destroy all registers }
         if (inlined or
            (p^.right=nil)) and
            { virtual methods too }
            not(po_virtualmethod in p^.procdefinition^.procoptions) then
           begin
              if (cs_check_io in aktlocalswitches) and
                 (po_iocheck in p^.procdefinition^.procoptions) and
                 not(po_iocheck in aktprocsym^.definition^.procoptions) then
                begin
                   getlabel(iolabel);
                   emitlab(iolabel);
                end
              else
                iolabel:=nil;

              { save all used registers }
              pushusedregisters(pushed,pprocdef(p^.procdefinition)^.usedregisters);

              { give used registers through }
              usedinproc:=usedinproc or pprocdef(p^.procdefinition)^.usedregisters;
           end
         else
           begin
              pushusedregisters(pushed,$ff);
              usedinproc:=$ff;
              { no IO check for methods and procedure variables }
              iolabel:=nil;
           end;

         { generate the code for the parameter and push them }
         oldpushedparasize:=pushedparasize;
         pushedparasize:=0;
         pop_size:=0;
         { no inc esp for inlined procedure
           and for objects constructors PM }
         if (inlined or
            (p^.right=nil)) and
            (p^.procdefinition^.proctypeoption=potype_constructor) and
            { quick'n'dirty check if it is a class or an object }
            (p^.resulttype^.deftype=orddef) then
           pop_allowed:=false
         else
           pop_allowed:=true;
         if pop_allowed then
          begin
          { Old pushedsize aligned on 4 ? }
            i:=oldpushedparasize and 3;
            if i>0 then
             inc(pop_size,4-i);
          { This parasize aligned on 4 ? }
            i:=p^.procdefinition^.para_size(para_alignment) and 3;
            if i>0 then
             inc(pop_size,4-i);
          { insert the opcode and update pushedparasize }
          { never push 4 or more !! }
            pop_size:=pop_size mod 4;
            if pop_size>0 then
             begin
               inc(pushedparasize,pop_size);
               emit_const_reg(A_SUB,S_L,pop_size,R_ESP);
{$ifdef GDB}
               if (cs_debuginfo in aktmoduleswitches) and
                  (exprasmlist^.first=exprasmlist^.last) then
                 exprasmlist^.concat(new(pai_force_line,init));
{$endif GDB}
             end;
          end;
{$ifdef OPTALIGN}
         if pop_allowed and (cs_align in aktglobalswitches) then
           begin
              pop_esp:=true;
              push_size:=p^.procdefinition^.para_size(para_alignment);
              { !!!! here we have to take care of return type, self
                and nested procedures
              }
              inc(push_size,12);
              emit_reg_reg(A_MOV,S_L,R_ESP,R_EDI);
              if (push_size mod 8)=0 then
                emit_const_reg(A_AND,S_L,$fffffff8,R_ESP)
              else
                begin
                   emit_const_reg(A_SUB,S_L,push_size,R_ESP);
                   emit_const_reg(A_AND,S_L,$fffffff8,R_ESP);
                   emit_const_reg(A_SUB,S_L,push_size,R_ESP);
                end;
              emit_reg(A_PUSH,S_L,R_EDI);
           end
         else
           pop_esp:=false;
{$endif OPTALIGN}
         if (p^.resulttype<>pdef(voiddef)) and
            ret_in_param(p^.resulttype) then
           begin
              funcretref.symbol:=nil;
{$ifdef test_dest_loc}
              if dest_loc_known and (dest_loc_tree=p) and
                 (dest_loc.loc in [LOC_REFERENCE,LOC_MEM]) then
                begin
                   funcretref:=dest_loc.reference;
                   if assigned(dest_loc.reference.symbol) then
                     funcretref.symbol:=stringdup(dest_loc.reference.symbol^);
                   in_dest_loc:=true;
                end
              else
{$endif test_dest_loc}
                if inlined then
                  begin
                     reset_reference(funcretref);
                     funcretref.offset:=gettempofsizepersistant(p^.procdefinition^.rettype.def^.size);
                     funcretref.base:=procinfo^.framepointer;
                  end
                else
                  gettempofsizereference(p^.procdefinition^.rettype.def^.size,funcretref);
           end;
         if assigned(params) then
           begin
              { be found elsewhere }
              if inlined then
                para_offset:=pprocdef(p^.procdefinition)^.parast^.address_fixup+
                  pprocdef(p^.procdefinition)^.parast^.datasize
              else
                para_offset:=0;
              if not(inlined) and
                 assigned(p^.right) then
                secondcallparan(params,pparaitem(pabstractprocdef(p^.right^.resulttype)^.para^.first),
                  (pocall_leftright in p^.procdefinition^.proccalloptions),inlined,
                  (pocall_cdecl in p^.procdefinition^.proccalloptions),
                  para_alignment,para_offset)
              else
                secondcallparan(params,pparaitem(p^.procdefinition^.para^.first),
                  (pocall_leftright in p^.procdefinition^.proccalloptions),inlined,
                  (pocall_cdecl in p^.procdefinition^.proccalloptions),
                  para_alignment,para_offset);
           end;
         if inlined then
           inlinecode^.retoffset:=gettempofsizepersistant(4);
         if ret_in_param(p^.resulttype) then
           begin
              { This must not be counted for C code
                complex return address is removed from stack
                by function itself !   }
{$ifdef OLD_C_STACK}
              inc(pushedparasize,4); { lets try without it PM }
{$endif not OLD_C_STACK}
              if inlined then
                begin
{$ifndef noAllocEdi}
                   getexplicitregister32(R_EDI);
{$endif noAllocEdi}
                   emit_ref_reg(A_LEA,S_L,
                     newreference(funcretref),R_EDI);
                   r:=new_reference(procinfo^.framepointer,inlinecode^.retoffset);
                   emit_reg_ref(A_MOV,S_L,R_EDI,r);
{$ifndef noAllocEdi}
                   ungetregister32(R_EDI);
{$endif noAllocEdi}
                end
              else
                emitpushreferenceaddr(funcretref);
           end;
         { procedure variable ? }
         if inlined or
           (p^.right=nil) then
           begin
              { overloaded operator have no symtable }
              { push self }
              if assigned(p^.symtable) and
                (p^.symtable^.symtabletype=withsymtable) then
                begin
                   { dirty trick to avoid the secondcall below }
                   p^.methodpointer:=genzeronode(callparan);
                   p^.methodpointer^.location.loc:=LOC_REGISTER;
{$ifndef noAllocEDI}
                   getexplicitregister32(R_ESI);
{$endif noAllocEDI}
                   p^.methodpointer^.location.register:=R_ESI;
                   { ARGHHH this is wrong !!!
                     if we can init from base class for a child
                     class that the wrong VMT will be
                     transfered to constructor !! }
                   p^.methodpointer^.resulttype:=
                     ptree(pwithsymtable(p^.symtable)^.withnode)^.left^.resulttype;
                   { change dispose type !! }
                   p^.disposetyp:=dt_mbleft_and_method;
                   { make a reference }
                   new(r);
                   reset_reference(r^);
                   { if assigned(ptree(pwithsymtable(p^.symtable)^.withnode)^.pref) then
                     begin
                        r^:=ptree(pwithsymtable(p^.symtable)^.withnode)^.pref^;
                     end
                   else
                     begin
                        r^.offset:=p^.symtable^.datasize;
                        r^.base:=procinfo^.framepointer;
                     end; }
                   r^:=ptree(pwithsymtable(p^.symtable)^.withnode)^.withreference^;
                   if (not pwithsymtable(p^.symtable)^.direct_with) or
                      pobjectdef(p^.methodpointer^.resulttype)^.is_class then
                     emit_ref_reg(A_MOV,S_L,r,R_ESI)
                   else
                     emit_ref_reg(A_LEA,S_L,r,R_ESI);
                end;

              { push self }
              if assigned(p^.symtable) and
                ((p^.symtable^.symtabletype=objectsymtable) or
                (p^.symtable^.symtabletype=withsymtable)) then
                begin
                   if assigned(p^.methodpointer) then
                     begin
                        {
                        if p^.methodpointer^.resulttype=classrefdef then
                          begin
                              two possibilities:
                               1. constructor
                               2. class method

                          end
                        else }
                          begin
                             case p^.methodpointer^.treetype of
                               typen:
                                 begin
                                    { direct call to inherited method }
                                    if (po_abstractmethod in p^.procdefinition^.procoptions) then
                                      begin
                                         CGMessage(cg_e_cant_call_abstract_method);
                                         goto dont_call;
                                      end;
                                    { generate no virtual call }
                                    no_virtual_call:=true;

                                    if (sp_static in p^.symtableprocentry^.symoptions) then
                                      begin
                                         { well lets put the VMT address directly into ESI }
                                         { it is kind of dirty but that is the simplest    }
                                         { way to accept virtual static functions (PM)     }
                                         loadesi:=true;
                                         { if no VMT just use $0 bug0214 PM }
{$ifndef noAllocEDI}
                                         getexplicitregister32(R_ESI);
{$endif noAllocEDI}
                                         if not(oo_has_vmt in pobjectdef(p^.methodpointer^.resulttype)^.objectoptions) then
                                           emit_const_reg(A_MOV,S_L,0,R_ESI)
                                         else
                                           begin
                                             emit_sym_ofs_reg(A_MOV,S_L,
                                               newasmsymbol(pobjectdef(p^.methodpointer^.resulttype)^.vmt_mangledname),
                                               0,R_ESI);
                                           end;
                                         { emit_reg(A_PUSH,S_L,R_ESI);
                                           this is done below !! }
                                      end
                                    else
                                      { this is a member call, so ESI isn't modfied }
                                      loadesi:=false;

                                    { a class destructor needs a flag }
                                    if pobjectdef(p^.methodpointer^.resulttype)^.is_class and
                                       {assigned(aktprocsym) and
                                       (aktprocsym^.definition^.proctypeoption=potype_destructor)}
                                       (p^.procdefinition^.proctypeoption=potype_destructor) then
                                      begin
                                        push_int(0);
                                        emit_reg(A_PUSH,S_L,R_ESI);
                                      end;

                                    if not(is_con_or_destructor and
                                           pobjectdef(p^.methodpointer^.resulttype)^.is_class and
                                           {assigned(aktprocsym) and
                                          (aktprocsym^.definition^.proctypeoption in [potype_constructor,potype_destructor])}
                                           (p^.procdefinition^.proctypeoption in [potype_constructor,potype_destructor])
                                          ) then
                                      emit_reg(A_PUSH,S_L,R_ESI);
                                    { if an inherited con- or destructor should be  }
                                    { called in a con- or destructor then a warning }
                                    { will be made                                  }
                                    { con- and destructors need a pointer to the vmt }
                                    if is_con_or_destructor and
                                    not(pobjectdef(p^.methodpointer^.resulttype)^.is_class) and
                                    assigned(aktprocsym) then
                                      begin
                                         if not(aktprocsym^.definition^.proctypeoption in
                                                [potype_constructor,potype_destructor]) then
                                          CGMessage(cg_w_member_cd_call_from_method);
                                      end;
                                    { class destructors get there flag above }
                                    { constructor flags ?                    }
                                    if is_con_or_destructor and
                                        not(pobjectdef(p^.methodpointer^.resulttype)^.is_class and
                                        assigned(aktprocsym) and
                                        (aktprocsym^.definition^.proctypeoption=potype_destructor)) then
                                      begin
                                         { a constructor needs also a flag }
                                         if pobjectdef(p^.methodpointer^.resulttype)^.is_class then
                                           push_int(0);
                                         push_int(0);
                                      end;
                                 end;
                               hnewn:
                                 begin
                                    { extended syntax of new }
                                    { ESI must be zero }
{$ifndef noAllocEDI}
                                    getexplicitregister32(R_ESI);
{$endif noAllocEDI}
                                    emit_reg_reg(A_XOR,S_L,R_ESI,R_ESI);
                                    emit_reg(A_PUSH,S_L,R_ESI);
                                    { insert the vmt }
                                    emit_sym(A_PUSH,S_L,
                                      newasmsymbol(pobjectdef(p^.methodpointer^.resulttype)^.vmt_mangledname));
                                    extended_new:=true;
                                 end;
                               hdisposen:
                                 begin
                                    secondpass(p^.methodpointer);

                                    { destructor with extended syntax called from dispose }
                                    { hdisposen always deliver LOC_REFERENCE          }
{$ifndef noAllocEDI}
                                    getexplicitregister32(R_ESI);
{$endif noAllocEDI}
                                    emit_ref_reg(A_LEA,S_L,
                                      newreference(p^.methodpointer^.location.reference),R_ESI);
                                    del_reference(p^.methodpointer^.location.reference);
                                    emit_reg(A_PUSH,S_L,R_ESI);
                                    emit_sym(A_PUSH,S_L,
                                      newasmsymbol(pobjectdef(p^.methodpointer^.resulttype)^.vmt_mangledname));
                                 end;
                               else
                                 begin
                                    { call to an instance member }
                                    if (p^.symtable^.symtabletype<>withsymtable) then
                                      begin
                                         secondpass(p^.methodpointer);
{$ifndef noAllocEDI}
                                         getexplicitregister32(R_ESI);
{$endif noAllocEDI}
                                         case p^.methodpointer^.location.loc of
                                            LOC_CREGISTER,
                                            LOC_REGISTER:
                                              begin
                                                 emit_reg_reg(A_MOV,S_L,p^.methodpointer^.location.register,R_ESI);
                                                 ungetregister32(p^.methodpointer^.location.register);
                                              end;
                                            else
                                              begin
                                                 if (p^.methodpointer^.resulttype^.deftype=classrefdef) or
                                                    ((p^.methodpointer^.resulttype^.deftype=objectdef) and
                                                   pobjectdef(p^.methodpointer^.resulttype)^.is_class) then
                                                   emit_ref_reg(A_MOV,S_L,
                                                     newreference(p^.methodpointer^.location.reference),R_ESI)
                                                 else
                                                   emit_ref_reg(A_LEA,S_L,
                                                     newreference(p^.methodpointer^.location.reference),R_ESI);
                                                 del_reference(p^.methodpointer^.location.reference);
                                              end;
                                         end;
                                      end;
                                    { when calling a class method, we have to load ESI with the VMT !
                                      But, not for a class method via self }
                                    if not(po_containsself in p^.procdefinition^.procoptions) then
                                      begin
                                        if (po_classmethod in p^.procdefinition^.procoptions) and
                                           not(p^.methodpointer^.resulttype^.deftype=classrefdef) then
                                          begin
                                             { class method needs current VMT }
                                             getexplicitregister32(R_ESI);
                                             new(r);
                                             reset_reference(r^);
                                             r^.base:=R_ESI;
                                             r^.offset:= pprocdef(p^.procdefinition)^._class^.vmt_offset;
                                             emit_ref_reg(A_MOV,S_L,r,R_ESI);
                                          end;

                                        { direct call to destructor: remove data }
                                        if (p^.procdefinition^.proctypeoption=potype_destructor) and
                                           (p^.methodpointer^.resulttype^.deftype=objectdef) and
                                           (pobjectdef(p^.methodpointer^.resulttype)^.is_class) then
                                          emit_const(A_PUSH,S_L,1);

                                        { direct call to class constructor, don't allocate memory }
                                        if (p^.procdefinition^.proctypeoption=potype_constructor) and
                                           (p^.methodpointer^.resulttype^.deftype=objectdef) and
                                           (pobjectdef(p^.methodpointer^.resulttype)^.is_class) then
                                          begin
                                             emit_const(A_PUSH,S_L,0);
                                             emit_const(A_PUSH,S_L,0);
                                          end
                                        else
                                          begin
                                             { constructor call via classreference => allocate memory }
                                             if (p^.procdefinition^.proctypeoption=potype_constructor) and
                                                (p^.methodpointer^.resulttype^.deftype=classrefdef) and
                                                (pobjectdef(pclassrefdef(p^.methodpointer^.resulttype)^.
                                                   pointertype.def)^.is_class) then
                                                emit_const(A_PUSH,S_L,1);
                                             emit_reg(A_PUSH,S_L,R_ESI);
                                          end;
                                      end;

                                    if is_con_or_destructor then
                                      begin
                                         { classes don't get a VMT pointer pushed }
                                         if (p^.methodpointer^.resulttype^.deftype=objectdef) and
                                           not(pobjectdef(p^.methodpointer^.resulttype)^.is_class) then
                                           begin
                                              if (p^.procdefinition^.proctypeoption=potype_constructor) then
                                                begin
                                                   { it's no bad idea, to insert the VMT }
                                                   emit_sym(A_PUSH,S_L,newasmsymbol(
                                                     pobjectdef(p^.methodpointer^.resulttype)^.vmt_mangledname));
                                                end
                                              { destructors haven't to dispose the instance, if this is }
                                              { a direct call                                           }
                                              else
                                                push_int(0);
                                           end;
                                      end;
                                 end;
                             end;
                          end;
                     end
                   else
                     begin
                        if (po_classmethod in p^.procdefinition^.procoptions) and
                          not(
                            assigned(aktprocsym) and
                            (po_classmethod in aktprocsym^.definition^.procoptions)
                          ) then
                          begin
                             { class method needs current VMT }
                             getexplicitregister32(R_ESI);
                             new(r);
                             reset_reference(r^);
                             r^.base:=R_ESI;
                             r^.offset:= pprocdef(p^.procdefinition)^._class^.vmt_offset;
                             emit_ref_reg(A_MOV,S_L,r,R_ESI);
                          end
                        else
                          begin
                             { member call, ESI isn't modified }
                             loadesi:=false;
                          end;
                        { direct call to destructor: don't remove data! }
                        if procinfo^._class^.is_class then
                          begin
                             if (p^.procdefinition^.proctypeoption=potype_destructor) then
                               begin
                                  emit_const(A_PUSH,S_L,0);
                                  emit_reg(A_PUSH,S_L,R_ESI);
                               end
                             else if (p^.procdefinition^.proctypeoption=potype_constructor) then
                               begin
                                  emit_const(A_PUSH,S_L,0);
                                  emit_const(A_PUSH,S_L,0);
                               end
                             else
                               emit_reg(A_PUSH,S_L,R_ESI);
                          end
                        else
                          begin
                             emit_reg(A_PUSH,S_L,R_ESI);
                             if is_con_or_destructor then
                               begin
                                  if (p^.procdefinition^.proctypeoption=potype_constructor) then
                                    begin
                                       { it's no bad idea, to insert the VMT }
                                       emit_sym(A_PUSH,S_L,newasmsymbol(
                                         procinfo^._class^.vmt_mangledname));
                                    end
                                  { destructors haven't to dispose the instance, if this is }
                                  { a direct call                                           }
                                  else
                                    push_int(0);
                               end;
                          end;
                     end;
                end;

              { push base pointer ?}
              if (lexlevel>=normal_function_level) and assigned(pprocdef(p^.procdefinition)^.parast) and
                ((pprocdef(p^.procdefinition)^.parast^.symtablelevel)>normal_function_level) then
                begin
                   { if we call a nested function in a method, we must      }
                   { push also SELF!                                    }
                   { THAT'S NOT TRUE, we have to load ESI via frame pointer }
                   { access                                              }
                   {
                     begin
                        loadesi:=false;
                        emit_reg(A_PUSH,S_L,R_ESI);
                     end;
                   }
                   if lexlevel=(pprocdef(p^.procdefinition)^.parast^.symtablelevel) then
                     begin
                        new(r);
                        reset_reference(r^);
                        r^.offset:=procinfo^.framepointer_offset;
                        r^.base:=procinfo^.framepointer;
                        emit_ref(A_PUSH,S_L,r)
                     end
                     { this is only true if the difference is one !!
                       but it cannot be more !! }
                   else if (lexlevel=pprocdef(p^.procdefinition)^.parast^.symtablelevel-1) then
                     begin
                        emit_reg(A_PUSH,S_L,procinfo^.framepointer)
                     end
                   else if (lexlevel>pprocdef(p^.procdefinition)^.parast^.symtablelevel) then
                     begin
                        hregister:=getregister32;
                        new(r);
                        reset_reference(r^);
                        r^.offset:=procinfo^.framepointer_offset;
                        r^.base:=procinfo^.framepointer;
                        emit_ref_reg(A_MOV,S_L,r,hregister);
                        for i:=(pprocdef(p^.procdefinition)^.parast^.symtablelevel) to lexlevel-1 do
                          begin
                             new(r);
                             reset_reference(r^);
                             {we should get the correct frame_pointer_offset at each level
                             how can we do this !!! }
                             r^.offset:=procinfo^.framepointer_offset;
                             r^.base:=hregister;
                             emit_ref_reg(A_MOV,S_L,r,hregister);
                          end;
                        emit_reg(A_PUSH,S_L,hregister);
                        ungetregister32(hregister);
                     end
                   else
                     internalerror(25000);
                end;

              if (po_virtualmethod in p^.procdefinition^.procoptions) and
                 not(no_virtual_call) then
                begin
                   { static functions contain the vmt_address in ESI }
                   { also class methods                       }
                   { Here it is quite tricky because it also depends }
                   { on the methodpointer                        PM }
                   getexplicitregister32(R_ESI);
                   if assigned(aktprocsym) then
                     begin
                       if (((sp_static in aktprocsym^.symoptions) or
                        (po_classmethod in aktprocsym^.definition^.procoptions)) and
                        ((p^.methodpointer=nil) or (p^.methodpointer^.treetype=typen)))
                        or
                        (po_staticmethod in p^.procdefinition^.procoptions) or
                        ((p^.procdefinition^.proctypeoption=potype_constructor) and
                        { esi contains the vmt if we call a constructor via a class ref }
                         assigned(p^.methodpointer) and
                         (p^.methodpointer^.resulttype^.deftype=classrefdef)
                        ) or
                        { ESI is loaded earlier }
                        (po_classmethod in p^.procdefinition^.procoptions) then
                         begin
                            new(r);
                            reset_reference(r^);
                            r^.base:=R_ESI;
                         end
                       else
                         begin
                            new(r);
                            reset_reference(r^);
                            r^.base:=R_ESI;
                            { this is one point where we need vmt_offset (PM) }
                            r^.offset:= pprocdef(p^.procdefinition)^._class^.vmt_offset;
{$ifndef noAllocEdi}
                            getexplicitregister32(R_EDI);
{$endif noAllocEdi}
                            emit_ref_reg(A_MOV,S_L,r,R_EDI);
                            new(r);
                            reset_reference(r^);
                            r^.base:=R_EDI;
                         end;
                     end
                   else
                     { aktprocsym should be assigned, also in main program }
                     internalerror(12345);
                   {
                     begin
                       new(r);
                       reset_reference(r^);
                       r^.base:=R_ESI;
                       emit_ref_reg(A_MOV,S_L,r,R_EDI);
                       new(r);
                       reset_reference(r^);
                       r^.base:=R_EDI;
                     end;
                   }
                   if pprocdef(p^.procdefinition)^.extnumber=-1 then
                     internalerror(44584);
                   r^.offset:=pprocdef(p^.procdefinition)^._class^.vmtmethodoffset(pprocdef(p^.procdefinition)^.extnumber);
                   if (cs_check_object_ext in aktlocalswitches) then
                     begin
                        emit_sym(A_PUSH,S_L,
                          newasmsymbol(pprocdef(p^.procdefinition)^._class^.vmt_mangledname));
                        emit_reg(A_PUSH,S_L,r^.base);
                        emitcall('FPC_CHECK_OBJECT_EXT');
                     end
                   else if (cs_check_range in aktlocalswitches) then
                     begin
                        emit_reg(A_PUSH,S_L,r^.base);
                        emitcall('FPC_CHECK_OBJECT');
                     end;
                   emit_ref(A_CALL,S_NO,r);
{$ifndef noAllocEdi}
                   ungetregister32(R_EDI);
{$endif noAllocEdi}
                end
              else if not inlined then
                begin
                  { We can call interrupts from within the smae code
                    by just pushing the flags and CS PM }
                  if (po_interrupt in p^.procdefinition^.procoptions) then
                    begin
                        emit_none(A_PUSHF,S_L);
                        emit_reg(A_PUSH,S_L,R_CS);
                    end;
                  emitcall(pprocdef(p^.procdefinition)^.mangledname);
                end
              else { inlined proc }
                { inlined code is in inlinecode }
                begin
                   { set poinline again }
                   include(p^.procdefinition^.proccalloptions,pocall_inline);
                   { process the inlinecode }
                   secondpass(inlinecode);
                   { free the args }
                   if pprocdef(p^.procdefinition)^.parast^.datasize>0 then
                     ungetpersistanttemp(pprocdef(p^.procdefinition)^.parast^.address_fixup);
                end;
           end
         else
           { now procedure variable case }
           begin
              secondpass(p^.right);
              if (po_interrupt in p^.procdefinition^.procoptions) then
                begin
                    emit_none(A_PUSHF,S_L);
                    emit_reg(A_PUSH,S_L,R_CS);
                end;
              { procedure of object? }
              if (po_methodpointer in p^.procdefinition^.procoptions) then
                begin
                   { method pointer can't be in a register }
                   hregister:=R_NO;

                   { do some hacking if we call a method pointer }
                   { which is a class member                 }
                   { else ESI is overwritten !             }
                   if (p^.right^.location.reference.base=R_ESI) or
                      (p^.right^.location.reference.index=R_ESI) then
                     begin
                        del_reference(p^.right^.location.reference);
{$ifndef noAllocEdi}
                        getexplicitregister32(R_EDI);
{$endif noAllocEdi}
                        emit_ref_reg(A_MOV,S_L,
                          newreference(p^.right^.location.reference),R_EDI);
                        hregister:=R_EDI;
                     end;

                   { load self, but not if it's already explicitly pushed }
                   if not(po_containsself in p^.procdefinition^.procoptions) then
                     begin
                       { load ESI }
                       inc(p^.right^.location.reference.offset,4);
                       getexplicitregister32(R_ESI);
                       emit_ref_reg(A_MOV,S_L,
                         newreference(p^.right^.location.reference),R_ESI);
                       dec(p^.right^.location.reference.offset,4);
                       { push self pointer }
                       emit_reg(A_PUSH,S_L,R_ESI);
                     end;

                   if hregister=R_NO then
                     emit_ref(A_CALL,S_NO,newreference(p^.right^.location.reference))
                   else
                     begin
{$ifndef noAllocEdi}
                       ungetregister32(hregister);
{$else noAllocEdi}
                       { the same code, the previous line is just to       }
                       { indicate EDI actually is deallocated if allocated }
                       { above (JM)                                        }
                       ungetregister32(hregister);
{$endif noAllocEdi}
                       emit_reg(A_CALL,S_NO,hregister);
                     end;

                   del_reference(p^.right^.location.reference);
                end
              else
                begin
                   case p^.right^.location.loc of
                      LOC_REGISTER,LOC_CREGISTER:
                         begin
                             emit_reg(A_CALL,S_NO,p^.right^.location.register);
                             ungetregister32(p^.right^.location.register);
                         end
                      else
                         emit_ref(A_CALL,S_NO,newreference(p^.right^.location.reference));
                         del_reference(p^.right^.location.reference);
                   end;
                end;
           end;

           { this was only for normal functions
             displaced here so we also get
             it to work for procvars PM }
           if (not inlined) and (pocall_clearstack in p^.procdefinition^.proccalloptions) then
             begin
                { we also add the pop_size which is included in pushedparasize }
                pop_size:=0;
                { better than an add on all processors }
                if pushedparasize=4 then
                  begin
{$ifndef noAllocEdi}
                    getexplicitregister32(R_EDI);
{$endif noAllocEdi}
                    emit_reg(A_POP,S_L,R_EDI);
{$ifndef noAllocEdi}
                    ungetregister32(R_EDI);
{$endif noAllocEdi}
                  end
                { the pentium has two pipes and pop reg is pairable }
                { but the registers must be different!        }
                else if (pushedparasize=8) and
                  not(cs_littlesize in aktglobalswitches) and
                  (aktoptprocessor=ClassP5) and
                  (procinfo^._class=nil) then
                    begin
{$ifndef noAllocEdi}
                       getexplicitregister32(R_EDI);
{$endif noAllocEdi}
                       emit_reg(A_POP,S_L,R_EDI);
{$ifndef noAllocEdi}
                       ungetregister32(R_EDI);
{$endif noAllocEdi}
{$ifndef noAllocEdi}
                       exprasmlist^.concat(new(pairegalloc,alloc(R_ESI)));
{$endif noAllocEdi}
                       emit_reg(A_POP,S_L,R_ESI);
{$ifndef noAllocEdi}
                       exprasmlist^.concat(new(pairegalloc,alloc(R_ESI)));
{$endif noAllocEdi}
                    end
                else if pushedparasize<>0 then
                  emit_const_reg(A_ADD,S_L,pushedparasize,R_ESP);
             end;
{$ifdef OPTALIGN}
         if pop_esp then
           emit_reg(A_POP,S_L,R_ESP);
{$endif OPTALIGN}
      dont_call:
         pushedparasize:=oldpushedparasize;
         unused:=unusedregisters;
         usablereg32:=usablecount;
{$ifdef TEMPREGDEBUG}
         testregisters32;
{$endif TEMPREGDEBUG}

         { a constructor could be a function with boolean result }
         { if calling constructor called fail we
           must jump directly to quickexitlabel  PM
           but only if it is a call of an inherited constructor }
         if (inlined or
             (p^.right=nil)) and
            (p^.procdefinition^.proctypeoption=potype_constructor) and
            assigned(p^.methodpointer) and
            (p^.methodpointer^.treetype=typen) and
            (aktprocsym^.definition^.proctypeoption=potype_constructor) then
           begin
             emitjmp(C_Z,faillabel);
           end;
         { handle function results }
         { structured results are easy to handle.... }
         { needed also when result_no_used !! }
         if (p^.resulttype<>pdef(voiddef)) and ret_in_param(p^.resulttype) then
           begin
              p^.location.loc:=LOC_MEM;
              p^.location.reference.symbol:=nil;
              p^.location.reference:=funcretref;
           end;
         { we have only to handle the result if it is used, but }
         { ansi/widestrings must be registered, so we can dispose them }
         if (p^.resulttype<>pdef(voiddef)) and (p^.return_value_used or
           is_ansistring(p^.resulttype) or is_widestring(p^.resulttype)) then
           begin
              { a contructor could be a function with boolean result }
              if (inlined or
                  (p^.right=nil)) and
                 (p^.procdefinition^.proctypeoption=potype_constructor) and
                 { quick'n'dirty check if it is a class or an object }
                 (p^.resulttype^.deftype=orddef) then
                begin
                   { this fails if popsize > 0 PM }
                   p^.location.loc:=LOC_FLAGS;
                   p^.location.resflags:=F_NE;


                   if extended_new then
                     begin
{$ifdef test_dest_loc}
                        if dest_loc_known and (dest_loc_tree=p) then
                          mov_reg_to_dest(p,S_L,R_EAX)
                        else
{$endif test_dest_loc}
                          begin
                             hregister:=getexplicitregister32(R_EAX);
                             emit_reg_reg(A_MOV,S_L,R_EAX,hregister);
                             p^.location.register:=hregister;
                          end;
                     end;
                end
               { structed results are easy to handle.... }
              else if ret_in_param(p^.resulttype) then
                begin
                   {p^.location.loc:=LOC_MEM;
                   stringdispose(p^.location.reference.symbol);
                   p^.location.reference:=funcretref;
                   already done above (PM) }
                end
              else
                begin
                   if (p^.resulttype^.deftype in [orddef,enumdef]) then
                     begin
                        p^.location.loc:=LOC_REGISTER;
                        case p^.resulttype^.size of
                          4 :
                            begin
{$ifdef test_dest_loc}
                               if dest_loc_known and (dest_loc_tree=p) then
                                 mov_reg_to_dest(p,S_L,R_EAX)
                               else
{$endif test_dest_loc}
                                 begin
                                    hregister:=getexplicitregister32(R_EAX);
                                    emit_reg_reg(A_MOV,S_L,R_EAX,hregister);
                                    p^.location.register:=hregister;
                                 end;
                            end;
                          1 :
                            begin
{$ifdef test_dest_loc}
                                 if dest_loc_known and (dest_loc_tree=p) then
                                   mov_reg_to_dest(p,S_B,R_AL)
                                 else
{$endif test_dest_loc}
                                   begin
                                      hregister:=getexplicitregister32(R_EAX);
                                      emit_reg_reg(A_MOV,S_B,R_AL,reg32toreg8(hregister));
                                      p^.location.register:=reg32toreg8(hregister);
                                   end;
                              end;
                          2 :
                            begin
{$ifdef test_dest_loc}
                               if dest_loc_known and (dest_loc_tree=p) then
                                 mov_reg_to_dest(p,S_W,R_AX)
                               else
{$endif test_dest_loc}
                                 begin
                                    hregister:=getexplicitregister32(R_EAX);
                                    emit_reg_reg(A_MOV,S_W,R_AX,reg32toreg16(hregister));
                                    p^.location.register:=reg32toreg16(hregister);
                                 end;
                            end;
                           8 :
                             begin
{$ifdef test_dest_loc}
{$error Don't know what to do here}
{$endif test_dest_loc}
                                hregister:=getexplicitregister32(R_EAX);
                                hregister2:=getexplicitregister32(R_EDX);
                                emit_reg_reg(A_MOV,S_L,R_EAX,hregister);
                                emit_reg_reg(A_MOV,S_L,R_EDX,hregister2);
                                p^.location.registerlow:=hregister;
                                p^.location.registerhigh:=hregister2;
                             end;
                        else internalerror(7);
                     end

                end
              else if (p^.resulttype^.deftype=floatdef) then
                case pfloatdef(p^.resulttype)^.typ of
                  f32bit:
                    begin
                       p^.location.loc:=LOC_REGISTER;
{$ifdef test_dest_loc}
                       if dest_loc_known and (dest_loc_tree=p) then
                         mov_reg_to_dest(p,S_L,R_EAX)
                       else
{$endif test_dest_loc}
                         begin
                            hregister:=getexplicitregister32(R_EAX);
                            emit_reg_reg(A_MOV,S_L,R_EAX,hregister);
                            p^.location.register:=hregister;
                         end;
                    end;
                  else
                    begin
                       p^.location.loc:=LOC_FPU;
                       inc(fpuvaroffset);
                    end;
                end
              else if is_ansistring(p^.resulttype) or
                is_widestring(p^.resulttype) then
                begin
                   hregister:=getexplicitregister32(R_EAX);
                   emit_reg_reg(A_MOV,S_L,R_EAX,hregister);
                   gettempansistringreference(hr);
                   decrstringref(p^.resulttype,hr);
                   emit_reg_ref(A_MOV,S_L,hregister,
                     newreference(hr));
                   ungetregister32(hregister);
                   p^.location.loc:=LOC_MEM;
                   p^.location.reference:=hr;
                end
              else
                begin
                   p^.location.loc:=LOC_REGISTER;
{$ifdef test_dest_loc}
                   if dest_loc_known and (dest_loc_tree=p) then
                     mov_reg_to_dest(p,S_L,R_EAX)
                   else
{$endif test_dest_loc}
                    begin
                       hregister:=getexplicitregister32(R_EAX);
                       emit_reg_reg(A_MOV,S_L,R_EAX,hregister);
                       p^.location.register:=hregister;
                    end;
                end;
             end;
           end;

         { perhaps i/o check ? }
         if iolabel<>nil then
           begin
              emit_sym(A_PUSH,S_L,iolabel);
              emitcall('FPC_IOCHECK');
           end;
         if pop_size>0 then
           emit_const_reg(A_ADD,S_L,pop_size,R_ESP);

         { restore registers }
         popusedregisters(pushed);

         { at last, restore instance pointer (SELF) }
         if loadesi then
           maybe_loadesi;
         pp:=params;
         while assigned(pp) do
           begin
              if assigned(pp^.left) then
                begin
                  if (pp^.left^.location.loc in [LOC_REFERENCE,LOC_MEM]) then
                    ungetiftemp(pp^.left^.location.reference);
                { process also all nodes of an array of const }
                  if pp^.left^.treetype=arrayconstructn then
                    begin
                      if assigned(pp^.left^.left) then
                       begin
                         hp:=pp^.left;
                         while assigned(hp) do
                          begin
                            if (hp^.left^.location.loc in [LOC_REFERENCE,LOC_MEM]) then
                              ungetiftemp(hp^.left^.location.reference);
                            hp:=hp^.right;
                          end;
                       end;
                    end;
                end;
              pp:=pp^.right;
           end;
         if inlined then
           ungetpersistanttemp(inlinecode^.retoffset);
         if assigned(inlinecode) then
           disposetree(inlinecode);
         disposetree(params);


         { from now on the result can be freed normally }
         if inlined and ret_in_param(p^.resulttype) then
           persistanttemptonormal(funcretref.offset);

         { if return value is not used }
         if (not p^.return_value_used) and (p^.resulttype<>pdef(voiddef)) then
           begin
              if p^.location.loc in [LOC_MEM,LOC_REFERENCE] then
                begin
                   { data which must be finalized ? }
                   if (p^.resulttype^.needs_inittable) and
                     ( (p^.resulttype^.deftype<>objectdef) or
                       not(pobjectdef(p^.resulttype)^.is_class)) then
                      finalize(p^.resulttype,p^.location.reference,ret_in_param(p^.resulttype));
                   { release unused temp }
                   ungetiftemp(p^.location.reference)
                end
              else if p^.location.loc=LOC_FPU then
                begin
                  { release FPU stack }
                  emit_reg(A_FSTP,S_NO,R_ST0);
                  {
                    dec(fpuvaroffset);
                    do NOT decrement as the increment before
                    is not called for unused results PM }
                end;
           end;
      end;


{*****************************************************************************
                             SecondProcInlineN
*****************************************************************************}


    procedure secondprocinline(var p : ptree);
       var st : psymtable;
           oldprocsym : pprocsym;
           para_size : longint;
           oldprocinfo : pprocinfo;
           oldinlining_procedure,
           nostackframe,make_global : boolean;
           proc_names : tstringcontainer;
           inlineentrycode,inlineexitcode : paasmoutput;
           oldexitlabel,oldexit2label,oldquickexitlabel:Pasmlabel;
{$ifdef GDB}
           startlabel,endlabel : pasmlabel;
           pp : pchar;
           mangled_length  : longint;
{$endif GDB}
       begin
          oldinlining_procedure:=inlining_procedure;
          oldexitlabel:=aktexitlabel;
          oldexit2label:=aktexit2label;
          oldquickexitlabel:=quickexitlabel;
          getlabel(aktexitlabel);
          getlabel(aktexit2label);
          oldprocsym:=aktprocsym;
          { we're inlining a procedure }
          inlining_procedure:=true;
          { save old procinfo }
          getmem(oldprocinfo,sizeof(tprocinfo));
          move(procinfo^,oldprocinfo^,sizeof(tprocinfo));
          { set the return value }
          aktprocsym:=p^.inlineprocsym;
          procinfo^.returntype:=aktprocsym^.definition^.rettype;
          procinfo^.return_offset:=p^.retoffset;
          procinfo^.para_offset:=p^.para_offset;
          { arg space has been filled by the parent secondcall }
          st:=aktprocsym^.definition^.localst;
          { set it to the same lexical level }
          st^.symtablelevel:=oldprocsym^.definition^.localst^.symtablelevel;
          if st^.datasize>0 then
            begin
              st^.address_fixup:=gettempofsizepersistant(st^.datasize)+st^.datasize;
{$ifdef extdebug}
              Comment(V_debug,'local symtable is at offset '+tostr(st^.address_fixup));
              exprasmlist^.concat(new(pai_asm_comment,init(strpnew(
                'local symtable is at offset '+tostr(st^.address_fixup)))));
{$endif extdebug}
            end;
          exprasmlist^.concat(new(Pai_Marker, Init(InlineStart)));
{$ifdef extdebug}
          exprasmlist^.concat(new(pai_asm_comment,init(strpnew('Start of inlined proc'))));
{$endif extdebug}
{$ifdef GDB}
          if (cs_debuginfo in aktmoduleswitches) then
            begin
              getlabel(startlabel);
              getlabel(endlabel);
              emitlab(startlabel);
              p^.inlineprocsym^.definition^.localst^.symtabletype:=inlinelocalsymtable;
              p^.inlineprocsym^.definition^.parast^.symtabletype:=inlineparasymtable;

              { Here we must include the para and local symtable info }
              p^.inlineprocsym^.concatstabto(withdebuglist);

              { set it back for savety }
              p^.inlineprocsym^.definition^.localst^.symtabletype:=localsymtable;
              p^.inlineprocsym^.definition^.parast^.symtabletype:=parasymtable;

              mangled_length:=length(oldprocsym^.definition^.mangledname);
              getmem(pp,mangled_length+50);
              strpcopy(pp,'192,0,0,'+startlabel^.name);
              if (target_os.use_function_relative_addresses) then
                begin
                  strpcopy(strend(pp),'-');
                  strpcopy(strend(pp),oldprocsym^.definition^.mangledname);
                end;
              withdebuglist^.concat(new(pai_stabn,init(strnew(pp))));
            end;
{$endif GDB}
          { takes care of local data initialization }
          inlineentrycode:=new(paasmoutput,init);
          inlineexitcode:=new(paasmoutput,init);
          proc_names.init;
          para_size:=p^.para_size;
          make_global:=false; { to avoid warning }
          genentrycode(inlineentrycode,proc_names,make_global,0,para_size,nostackframe,true);
          exprasmlist^.concatlist(inlineentrycode);
          secondpass(p^.inlinetree);
          genexitcode(inlineexitcode,0,false,true);
          exprasmlist^.concatlist(inlineexitcode);

          dispose(inlineentrycode,done);
          dispose(inlineexitcode,done);
{$ifdef extdebug}
          exprasmlist^.concat(new(pai_asm_comment,init(strpnew('End of inlined proc'))));
{$endif extdebug}
          exprasmlist^.concat(new(Pai_Marker, Init(InlineEnd)));

          {we can free the local data now, reset also the fixup address }
          if st^.datasize>0 then
            begin
              ungetpersistanttemp(st^.address_fixup-st^.datasize);
              st^.address_fixup:=0;
            end;
          { restore procinfo }
          move(oldprocinfo^,procinfo^,sizeof(tprocinfo));
          freemem(oldprocinfo,sizeof(tprocinfo));
{$ifdef GDB}
          if (cs_debuginfo in aktmoduleswitches) then
            begin
              emitlab(endlabel);
              strpcopy(pp,'224,0,0,'+endlabel^.name);
             if (target_os.use_function_relative_addresses) then
               begin
                 strpcopy(strend(pp),'-');
                 strpcopy(strend(pp),oldprocsym^.definition^.mangledname);
               end;
              withdebuglist^.concat(new(pai_stabn,init(strnew(pp))));
              freemem(pp,mangled_length+50);
            end;
{$endif GDB}
          { restore }
          aktprocsym:=oldprocsym;
          aktexitlabel:=oldexitlabel;
          aktexit2label:=oldexit2label;
          quickexitlabel:=oldquickexitlabel;
          inlining_procedure:=oldinlining_procedure;
       end;



end.
{
  $Log$
  Revision 1.3  2000-07-13 12:08:24  michael
  + patched to 1.1.0 with former 1.09patch from peter

  Revision 1.2  2000/07/13 11:32:32  michael
  + removed logs

}
