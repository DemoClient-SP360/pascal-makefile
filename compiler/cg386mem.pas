{
    $Id$
    Copyright (c) 1993-98 by Florian Klaempfl

    Generate i386 assembler for in memory related nodes

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
unit cg386mem;
interface

    uses
      tree;

    procedure secondloadvmt(var p : ptree);
    procedure secondhnewn(var p : ptree);
    procedure secondnewn(var p : ptree);
    procedure secondhdisposen(var p : ptree);
    procedure secondsimplenewdispose(var p : ptree);
    procedure secondaddr(var p : ptree);
    procedure seconddoubleaddr(var p : ptree);
    procedure secondderef(var p : ptree);
    procedure secondsubscriptn(var p : ptree);
    procedure secondvecn(var p : ptree);
    procedure secondselfn(var p : ptree);
    procedure secondwith(var p : ptree);


implementation

    uses
      globtype,systems,
      cobjects,verbose,globals,
      symtable,aasm,types,
      hcodegen,temp_gen,pass_2,pass_1,
{$ifdef ag386bin}
      i386base,i386asm,
{$else}
      i386,
{$endif}
      cgai386,tgeni386;

{*****************************************************************************
                             SecondLoadVMT
*****************************************************************************}

    procedure secondloadvmt(var p : ptree);
      begin
         p^.location.register:=getregister32;
         exprasmlist^.concat(new(pai386,op_sym_ofs_reg(A_MOV,
            S_L,newasmsymbol(pobjectdef(pclassrefdef(p^.resulttype)^.definition)^.vmt_mangledname),0,
            p^.location.register)));
         maybe_concat_external(pobjectdef(pclassrefdef(p^.resulttype)^.definition)^.owner,
            pobjectdef(pclassrefdef(p^.resulttype)^.definition)^.vmt_mangledname);
      end;


{*****************************************************************************
                             SecondHNewN
*****************************************************************************}

    procedure secondhnewn(var p : ptree);
      begin
      end;


{*****************************************************************************
                             SecondNewN
*****************************************************************************}

    procedure secondnewn(var p : ptree);
      var
         pushed : tpushed;
         r : preference;
      begin
         if assigned(p^.left) then
           begin
              secondpass(p^.left);
              p^.location.register:=p^.left^.location.register;
           end
         else
           begin
              pushusedregisters(pushed,$ff);

              { code copied from simplenewdispose PM }
              { determines the size of the mem block }
              push_int(ppointerdef(p^.resulttype)^.definition^.size);

              gettempofsizereference(target_os.size_of_pointer,p^.location.reference);
              emitpushreferenceaddr(exprasmlist,p^.location.reference);

              emitcall('FPC_GETMEM',true);
              if ppointerdef(p^.resulttype)^.definition^.needs_inittable then
                begin
                   new(r);
                   reset_reference(r^);
                   r^.symbol:=newasmsymbol(lab2str(ppointerdef(p^.left^.resulttype)^.definition^.get_inittable_label));
                   emitpushreferenceaddr(exprasmlist,r^);
                   { push pointer adress }
                   emitpushreferenceaddr(exprasmlist,p^.location.reference);
                   dispose(r);
                   emitcall('FPC_INITIALIZE',true);
                end;
              popusedregisters(pushed);
              { may be load ESI }
              maybe_loadesi;
           end;
         if codegenerror then
           exit;
      end;


{*****************************************************************************
                             SecondDisposeN
*****************************************************************************}

    procedure secondhdisposen(var p : ptree);
      begin
         secondpass(p^.left);
         if codegenerror then
           exit;
         clear_reference(p^.location.reference);
         case p^.left^.location.loc of
            LOC_REGISTER,
            LOC_CREGISTER:
              begin
                 p^.location.reference.index:=getregister32;
                 exprasmlist^.concat(new(pai386,op_reg_reg(A_MOV,S_L,
                   p^.left^.location.register,
                   p^.location.reference.index)));
              end;
            LOC_MEM,LOC_REFERENCE :
              begin
                 del_reference(p^.left^.location.reference);
                 p^.location.reference.index:=getregister32;
                 exprasmlist^.concat(new(pai386,op_ref_reg(A_MOV,S_L,newreference(p^.left^.location.reference),
                   p^.location.reference.index)));
              end;
         end;
      end;


{*****************************************************************************
                             SecondNewDispose
*****************************************************************************}

    procedure secondsimplenewdispose(var p : ptree);

      var
         pushed : tpushed;
         r : preference;

      begin
         secondpass(p^.left);
         if codegenerror then
           exit;

         pushusedregisters(pushed,$ff);
         { determines the size of the mem block }
         push_int(ppointerdef(p^.left^.resulttype)^.definition^.size);

         { push pointer adress }
         case p^.left^.location.loc of
            LOC_CREGISTER : exprasmlist^.concat(new(pai386,op_reg(A_PUSH,S_L,
              p^.left^.location.register)));
            LOC_REFERENCE:
              emitpushreferenceaddr(exprasmlist,p^.left^.location.reference);
         end;

         { call the mem handling procedures }
         case p^.treetype of
           simpledisposen:
             begin
                if ppointerdef(p^.left^.resulttype)^.definition^.needs_inittable then
                  begin
                     new(r);
                     reset_reference(r^);
                     r^.symbol:=newasmsymbol(lab2str(ppointerdef(p^.left^.resulttype)^.definition^.get_inittable_label));
                     emitpushreferenceaddr(exprasmlist,r^);
                     { push pointer adress }
                     case p^.left^.location.loc of
                        LOC_CREGISTER : exprasmlist^.concat(new(pai386,op_reg(A_PUSH,S_L,
                          p^.left^.location.register)));
                        LOC_REFERENCE:
                          emitpushreferenceaddr(exprasmlist,p^.left^.location.reference);
                     end;
                     dispose(r);
                     emitcall('FPC_FINALIZE',true);
                  end;
                emitcall('FPC_FREEMEM',true);
             end;
           simplenewn:
             begin
                emitcall('FPC_GETMEM',true);
                if ppointerdef(p^.left^.resulttype)^.definition^.needs_inittable then
                  begin
                     new(r);
                     reset_reference(r^);
                     r^.symbol:=newasmsymbol(lab2str(ppointerdef(p^.left^.resulttype)^.definition^.get_inittable_label));
                     emitpushreferenceaddr(exprasmlist,r^);
                     { push pointer adress }
                     case p^.left^.location.loc of
                        LOC_CREGISTER : exprasmlist^.concat(new(pai386,op_reg(A_PUSH,S_L,
                          p^.left^.location.register)));
                        LOC_REFERENCE:
                          emitpushreferenceaddr(exprasmlist,p^.left^.location.reference);
                     end;
                     dispose(r);
                     emitcall('FPC_INITIALIZE',true);
                  end;
             end;
         end;
         popusedregisters(pushed);
         { may be load ESI }
         maybe_loadesi;
      end;


{*****************************************************************************
                             SecondAddr
*****************************************************************************}

    procedure secondaddr(var p : ptree);
      begin
         secondpass(p^.left);
         p^.location.loc:=LOC_REGISTER;
         del_reference(p^.left^.location.reference);
         p^.location.register:=getregister32;
         {@ on a procvar means returning an address to the procedure that
           is stored in it.}
         { yes but p^.left^.symtableentry can be nil
           for example on @self !! }
         { symtableentry can be also invalid, if left is no tree node }
         if (m_tp_procvar in aktmodeswitches) and
           (p^.left^.treetype=loadn) and
           assigned(p^.left^.symtableentry) and
           (p^.left^.symtableentry^.typ=varsym) and
           (pvarsym(p^.left^.symtableentry)^.definition^.deftype=procvardef) then
           exprasmlist^.concat(new(pai386,op_ref_reg(A_MOV,S_L,
             newreference(p^.left^.location.reference),
             p^.location.register)))
         else
           exprasmlist^.concat(new(pai386,op_ref_reg(A_LEA,S_L,
             newreference(p^.left^.location.reference),
             p^.location.register)));
           { for use of other segments }
           if p^.left^.location.reference.segment<>R_DEFAULT_SEG then
             p^.location.segment:=p^.left^.location.reference.segment;
      end;


{*****************************************************************************
                             SecondDoubleAddr
*****************************************************************************}

    procedure seconddoubleaddr(var p : ptree);
      begin
         secondpass(p^.left);
         p^.location.loc:=LOC_REGISTER;
         del_reference(p^.left^.location.reference);
         p^.location.register:=getregister32;
         exprasmlist^.concat(new(pai386,op_ref_reg(A_LEA,S_L,
         newreference(p^.left^.location.reference),
           p^.location.register)));
      end;


{*****************************************************************************
                             SecondDeRef
*****************************************************************************}

    procedure secondderef(var p : ptree);
      var
         hr : tregister;
      begin
         secondpass(p^.left);
         clear_reference(p^.location.reference);
         case p^.left^.location.loc of
            LOC_REGISTER:
              p^.location.reference.base:=p^.left^.location.register;
            LOC_CREGISTER:
              begin
                 { ... and reserve one for the pointer }
                 hr:=getregister32;
                 emit_reg_reg(A_MOV,S_L,p^.left^.location.register,hr);
                 p^.location.reference.base:=hr;
              end;
            else
              begin
                 { free register }
                 del_reference(p^.left^.location.reference);

                 { ...and reserve one for the pointer }
                 hr:=getregister32;
                 exprasmlist^.concat(new(pai386,op_ref_reg(
                   A_MOV,S_L,newreference(p^.left^.location.reference),
                   hr)));
                 p^.location.reference.base:=hr;
              end;
         end;
         if p^.left^.resulttype^.deftype=farpointerdef then
          p^.location.reference.segment:=R_FS;
      end;


{*****************************************************************************
                             SecondSubScriptN
*****************************************************************************}

    procedure secondsubscriptn(var p : ptree);
      var
         hr : tregister;
      begin
         secondpass(p^.left);
         if codegenerror then
           exit;
         { classes must be dereferenced implicit }
         if (p^.left^.resulttype^.deftype=objectdef) and
           pobjectdef(p^.left^.resulttype)^.isclass then
           begin
             clear_reference(p^.location.reference);
             case p^.left^.location.loc of
                LOC_REGISTER:
                  p^.location.reference.base:=p^.left^.location.register;
                LOC_CREGISTER:
                  begin
                     { ... and reserve one for the pointer }
                     hr:=getregister32;
                     emit_reg_reg(A_MOV,S_L,p^.left^.location.register,hr);
                       p^.location.reference.base:=hr;
                  end;
                else
                  begin
                     { free register }
                     del_reference(p^.left^.location.reference);

                     { ... and reserve one for the pointer }
                     hr:=getregister32;
                     exprasmlist^.concat(new(pai386,op_ref_reg(
                       A_MOV,S_L,newreference(p^.left^.location.reference),
                       hr)));
                     p^.location.reference.base:=hr;
                  end;
             end;
           end
         else
           set_location(p^.location,p^.left^.location);

         inc(p^.location.reference.offset,p^.vs^.address);
      end;


{*****************************************************************************
                               SecondVecN
*****************************************************************************}

    procedure secondvecn(var p : ptree);
      var
        is_pushed : boolean;
        ind,hr : tregister;
        _p : ptree;

          function get_mul_size:longint;
          begin
            if p^.memindex then
             get_mul_size:=1
            else
             get_mul_size:=p^.resulttype^.size;
          end;

          procedure calc_emit_mul;
          var
             l1,l2 : longint;
          begin
            l1:=get_mul_size;
            case l1 of
             1,2,4,8 : p^.location.reference.scalefactor:=l1;
            else
              begin
                 if ispowerof2(l1,l2) then
                   exprasmlist^.concat(new(pai386,op_const_reg(A_SHL,S_L,l2,ind)))
                 else
                   exprasmlist^.concat(new(pai386,op_const_reg(A_IMUL,S_L,l1,ind)));
              end;
            end;
          end;

      var
         extraoffset : longint;
         { rl stores the resulttype of the left node, this is necessary }
         { to detect if it is an ansistring                             }
         { because in constant nodes which constant index               }
         { the left tree is removed                                     }
         rl : pdef;
         t   : ptree;
         hp  : preference;
         href : treference;
         tai : Pai386;
         pushed : tpushed;
         hightree : ptree;

      begin
         secondpass(p^.left);
         rl:=p^.left^.resulttype;
         { we load the array reference to p^.location }

         { an ansistring needs to be dereferenced }
         if is_ansistring(p^.left^.resulttype) or
           is_widestring(p^.left^.resulttype) then
           begin
              reset_reference(p^.location.reference);
              if p^.callunique then
                begin
                   if p^.left^.location.loc<>LOC_REFERENCE then
                     begin
                        CGMessage(cg_e_illegal_expression);
                        exit;
                     end;
                   pushusedregisters(pushed,$ff);
                   emitpushreferenceaddr(exprasmlist,p^.left^.location.reference);
                   if is_ansistring(p^.left^.resulttype) then
                     emitcall('FPC_ANSISTR_UNIQUE',true)
                   else
                     emitcall('FPC_WIDESTR_UNIQUE',true);
                   maybe_loadesi;
                   popusedregisters(pushed);
                end;

              if p^.left^.location.loc in [LOC_REGISTER,LOC_CREGISTER] then
                begin
                   p^.location.reference.base:=p^.left^.location.register;
                end
              else
                begin
                   del_reference(p^.left^.location.reference);
                   p^.location.reference.base:=getregister32;
                   exprasmlist^.concat(new(pai386,op_ref_reg(A_MOV,S_L,
                     newreference(p^.left^.location.reference),
                     p^.location.reference.base)));
                end;

              { check for a zero length string,
                we can use the ansistring routine here }
              if (cs_check_range in aktlocalswitches) then
                begin
                   pushusedregisters(pushed,$ff);
                   exprasmlist^.concat(new(pai386,op_reg(A_PUSH,S_L,p^.location.reference.base)));
                   emitcall('FPC_ANSISTR_CHECKZERO',true);
                   maybe_loadesi;
                   popusedregisters(pushed);
                end;

              if is_ansistring(p^.left^.resulttype) then
                { in ansistrings S[1] is pchar(S)[0] !! }
                dec(p^.location.reference.offset)
              else
                begin
                   { in widestrings S[1] is pwchar(S)[0] !! }
                   dec(p^.location.reference.offset,2);
                   exprasmlist^.concat(new(pai386,op_const_reg(A_SHL,S_L,
                     1,p^.location.reference.base)));
                end;

              { we've also to keep left up-to-date, because it is used   }
              { if a constant array index occurs, subject to change (FK) }
              set_location(p^.left^.location,p^.location);
           end
         else
           set_location(p^.location,p^.left^.location);

         { offset can only differ from 0 if arraydef }
         if p^.left^.resulttype^.deftype=arraydef then
           dec(p^.location.reference.offset,
               get_mul_size*parraydef(p^.left^.resulttype)^.lowrange);
         if p^.right^.treetype=ordconstn then
           begin
              { offset can only differ from 0 if arraydef }
              if (p^.left^.resulttype^.deftype=arraydef) then
                begin
                   if not(is_open_array(p^.left^.resulttype)) then
                     begin
                        if (p^.right^.value>parraydef(p^.left^.resulttype)^.highrange) or
                           (p^.right^.value<parraydef(p^.left^.resulttype)^.lowrange) then
                           begin
                              if (cs_check_range in aktlocalswitches) then
                                CGMessage(parser_e_range_check_error)
                              else
                                CGMessage(parser_w_range_check_error);
                           end;
                        dec(p^.left^.location.reference.offset,
                            get_mul_size*parraydef(p^.left^.resulttype)^.lowrange);
                     end
                   else
                     begin
                        { range checking for open arrays !!!! }
                        {!!!!!!!!!!!!!!!!!}
                     end;
                end
              else if (p^.left^.resulttype^.deftype=stringdef) then
                begin
                   if (p^.right^.value=0) and not(is_shortstring(p^.left^.resulttype)) then
                     CGMessage(cg_e_can_access_element_zero);

                   if (cs_check_range in aktlocalswitches) then
                     case pstringdef(p^.left^.resulttype)^.string_typ of
                        { it's the same for ansi- and wide strings }
                        st_widestring,
                        st_ansistring:
                          begin
                             pushusedregisters(pushed,$ff);
                             push_int(p^.right^.value);
                             hp:=newreference(p^.location.reference);
                             dec(hp^.offset,7);
                             exprasmlist^.concat(new(pai386,op_ref(A_PUSH,S_L,hp)));
                             emitcall('FPC_ANSISTR_RANGECHECK',true);
                             popusedregisters(pushed);
                             maybe_loadesi;
                          end;

                        st_shortstring:
                          begin
                             {!!!!!!!!!!!!!!!!!}
                          end;

                        st_longstring:
                          begin
                             {!!!!!!!!!!!!!!!!!}
                          end;
                     end;
                end;

              inc(p^.left^.location.reference.offset,
                  get_mul_size*p^.right^.value);
              if p^.memseg then
                p^.left^.location.reference.segment:=R_FS;
              p^.left^.resulttype:=p^.resulttype;
              disposetree(p^.right);
              _p:=p^.left;
              putnode(p);
              p:=_p;
           end
         else
         { not treetype=ordconstn }
           begin
              { quick hack, to overcome Delphi 2 }
              if (cs_regalloc in aktglobalswitches) and
                (p^.left^.resulttype^.deftype=arraydef) then
                begin
                   extraoffset:=0;
                   if (p^.right^.treetype=addn) then
                     begin
                        if p^.right^.right^.treetype=ordconstn then
                          begin
                             extraoffset:=p^.right^.right^.value;
                             t:=p^.right^.left;
                             putnode(p^.right);
                             putnode(p^.right^.right);
                             p^.right:=t
                          end
                        else if p^.right^.left^.treetype=ordconstn then
                          begin
                             extraoffset:=p^.right^.left^.value;
                             t:=p^.right^.right;
                             putnode(p^.right);
                             putnode(p^.right^.left);
                             p^.right:=t
                          end;
                     end
                   else if (p^.right^.treetype=subn) then
                     begin
                        if p^.right^.right^.treetype=ordconstn then
                          begin
                             extraoffset:=p^.right^.right^.value;
                             t:=p^.right^.left;
                             putnode(p^.right);
                             putnode(p^.right^.right);
                             p^.right:=t
                          end
                        else if p^.right^.left^.treetype=ordconstn then
                          begin
                             extraoffset:=p^.right^.left^.value;
                             t:=p^.right^.right;
                             putnode(p^.right);
                             putnode(p^.right^.left);
                             p^.right:=t
                          end;
                     end;
                   inc(p^.location.reference.offset,
                       get_mul_size*extraoffset);
                end;
              { calculate from left to right }
              if (p^.location.loc<>LOC_REFERENCE) and
                 (p^.location.loc<>LOC_MEM) then
                CGMessage(cg_e_illegal_expression);
              is_pushed:=maybe_push(p^.right^.registers32,p);
              secondpass(p^.right);
              if is_pushed then
                restore(p);
              { here we change the location of p^.right
                and the update was forgotten so it
                led to wrong code in emitrangecheck later PM
                so make range check before }

              if cs_check_range in aktlocalswitches then
               begin
                 if p^.left^.resulttype^.deftype=arraydef then
                   begin
                     if is_open_array(p^.left^.resulttype) then
                      begin
                        reset_reference(href);
                        parraydef(p^.left^.resulttype)^.genrangecheck;
                        href.symbol:=newasmsymbol(parraydef(p^.left^.resulttype)^.getrangecheckstring);
                        href.offset:=4;
                        getsymonlyin(p^.left^.symtable,'high'+pvarsym(p^.left^.symtableentry)^.name);
                        hightree:=genloadnode(pvarsym(srsym),p^.left^.symtable);
                        firstpass(hightree);
                        secondpass(hightree);
                        emit_mov_loc_ref(hightree^.location,href);
                        disposetree(hightree);
                      end;
                     emitrangecheck(p^.right,p^.left^.resulttype);
                   end;
               end;
               
              case p^.right^.location.loc of
                 LOC_REGISTER:
                   begin
                      ind:=p^.right^.location.register;
                      case p^.right^.resulttype^.size of
                         1:
                           begin
                              hr:=reg8toreg32(ind);
                              emit_reg_reg(A_MOVZX,S_BL,ind,hr);
                              ind:=hr;
                           end;
                         2:
                           begin
                              hr:=reg16toreg32(ind);
                              emit_reg_reg(A_MOVZX,S_WL,ind,hr);
                              ind:=hr;
                           end;
                      end;
                   end;
                 LOC_CREGISTER:
                   begin
                      ind:=getregister32;
                      case p^.right^.resulttype^.size of
                         1:
                           emit_reg_reg(A_MOVZX,S_BL,p^.right^.location.register,ind);
                         2:
                           emit_reg_reg(A_MOVZX,S_WL,p^.right^.location.register,ind);
                         4:
                           emit_reg_reg(A_MOV,S_L,p^.right^.location.register,ind);
                      end;
                   end;
                 LOC_FLAGS:
                   begin
                      ind:=getregister32;
                      emit_flag2reg(p^.right^.location.resflags,reg32toreg8(ind));
                      emit_reg_reg(A_MOVZX,S_BL,reg32toreg8(ind),ind);
                   end
                 else
                    begin
                       del_reference(p^.right^.location.reference);
                       ind:=getregister32;
                       { Booleans are stored in an 8 bit memory location, so
                         the use of MOVL is not correct }
                       case p^.right^.resulttype^.size of
                        1 : tai:=new(pai386,op_ref_reg(A_MOVZX,S_BL,newreference(p^.right^.location.reference),ind));
                        2 : tai:=new(Pai386,op_ref_reg(A_MOVZX,S_WL,newreference(p^.right^.location.reference),ind));
                        4 : tai:=new(Pai386,op_ref_reg(A_MOV,S_L,newreference(p^.right^.location.reference),ind));
                       end;
                       exprasmlist^.concat(tai);
                    end;
                end;

            { produce possible range check code: }
              if cs_check_range in aktlocalswitches then
               begin
                 if p^.left^.resulttype^.deftype=arraydef then
                   begin
                     { done defore (PM) }
                   end
                 else if (p^.left^.resulttype^.deftype=stringdef) then
                   begin
                      case pstringdef(p^.left^.resulttype)^.string_typ of
                         { it's the same for ansi- and wide strings }
                         st_widestring,
                         st_ansistring:
                           begin
                              pushusedregisters(pushed,$ff);
                              exprasmlist^.concat(new(pai386,op_reg(A_PUSH,S_L,ind)));
                              hp:=newreference(p^.location.reference);
                              dec(hp^.offset,7);
                              exprasmlist^.concat(new(pai386,op_ref(A_PUSH,S_L,hp)));
                              emitcall('FPC_ANSISTR_RANGECHECK',true);
                              popusedregisters(pushed);
                              maybe_loadesi;
                           end;
                         st_shortstring:
                           begin
                              {!!!!!!!!!!!!!!!!!}
                           end;
                         st_longstring:
                           begin
                              {!!!!!!!!!!!!!!!!!}
                           end;
                      end;
                   end;
               end;

              if p^.location.reference.index=R_NO then
               begin
                 p^.location.reference.index:=ind;
                 calc_emit_mul;
               end
              else
               begin
                 if p^.location.reference.base=R_NO then
                  begin
                    case p^.location.reference.scalefactor of
                     2 : exprasmlist^.concat(new(pai386,op_const_reg(A_SHL,S_L,1,p^.location.reference.index)));
                     4 : exprasmlist^.concat(new(pai386,op_const_reg(A_SHL,S_L,2,p^.location.reference.index)));
                     8 : exprasmlist^.concat(new(pai386,op_const_reg(A_SHL,S_L,3,p^.location.reference.index)));
                    end;
                    calc_emit_mul;
                    p^.location.reference.base:=p^.location.reference.index;
                    p^.location.reference.index:=ind;
                  end
                 else
                  begin
                    exprasmlist^.concat(new(pai386,op_ref_reg(
                      A_LEA,S_L,newreference(p^.location.reference),
                      p^.location.reference.index)));
                    ungetregister32(p^.location.reference.base);
                    { the symbol offset is loaded,               }
                    { so release the symbol name and set symbol  }
                    { to nil                                     }
                    p^.location.reference.symbol:=nil;
                    p^.location.reference.offset:=0;
                    calc_emit_mul;
                    p^.location.reference.base:=p^.location.reference.index;
                    p^.location.reference.index:=ind;
                  end;
               end;

              if p^.memseg then
                p^.location.reference.segment:=R_FS;
           end;

         { have we to remove a temp. wide/ansistring ?
           c:=(s1+s2)[i]
           for example
         }
         if (p^.location.loc=LOC_MEM) and
            (rl^.deftype=stringdef) then
           begin
              case pstringdef(rl)^.string_typ of
                 st_ansistring:
                   begin
                      del_reference(p^.location.reference);
                      hr:=reg32toreg8(getregister32);
                      exprasmlist^.concat(new(pai386,op_ref_reg(A_MOV,S_B,
                        newreference(p^.location.reference),hr)));
                      clear_reference(p^.location.reference);
                      p^.location.loc:=LOC_REGISTER;
                      p^.location.register:=hr;
                      { we can remove all temps }
                      removetemps(exprasmlist,temptoremove);
                      temptoremove^.clear;
                   end;
                 st_widestring:
                   begin
                      del_reference(p^.location.reference);
                      hr:=reg32toreg16(getregister32);
                      exprasmlist^.concat(new(pai386,op_ref_reg(A_MOV,S_W,
                        newreference(p^.location.reference),hr)));                      clear_reference(p^.location.reference);
                      p^.location.loc:=LOC_REGISTER;
                      p^.location.register:=hr;
                      { we can remove all temps }
                      removetemps(exprasmlist,temptoremove);
                      temptoremove^.clear;
                   end;
              end;
           end;
      end;

{*****************************************************************************
                               SecondSelfN
*****************************************************************************}

    procedure secondselfn(var p : ptree);
      begin
         clear_reference(p^.location.reference);
         if (p^.resulttype^.deftype=classrefdef) or
           ((p^.resulttype^.deftype=objectdef)
             and pobjectdef(p^.resulttype)^.isclass
           ) then
           p^.location.register:=R_ESI
         else
           p^.location.reference.base:=R_ESI;
      end;


{*****************************************************************************
                               SecondWithN
*****************************************************************************}

    procedure secondwith(var p : ptree);
      var
        ref : treference;
        symtable : psymtable;
        i : longint;
        load : boolean;
      begin
         if assigned(p^.left) then
            begin
               secondpass(p^.left);
               load:=true;
               if p^.left^.location.reference.segment<>R_DEFAULT_SEG then
                 message(parser_e_no_with_for_variable_in_other_segments);
               ref.symbol:=nil;
               gettempofsizereference(4,ref);
               if (p^.left^.treetype=loadn) and
                  (p^.left^.symtable=aktprocsym^.definition^.localst) then
                 begin
                    { for local class just use the local storage }
                    ungetiftemp(ref);
                    new(p^.pref);
                    p^.pref^:=p^.left^.location.reference;
                    { don't discard symbol if in main procedure }
                    p^.left^.location.reference.symbol:=nil;
                    load:=false;
                 end
               else if (p^.left^.resulttype^.deftype=objectdef) and
                  pobjectdef(p^.left^.resulttype)^.isclass then
                 begin
                    exprasmlist^.concat(new(pai386,op_ref_reg(A_MOV,S_L,
                      newreference(p^.left^.location.reference),R_EDI)))
                 end
               else
                 exprasmlist^.concat(new(pai386,op_ref_reg(A_LEA,S_L,
                   newreference(p^.left^.location.reference),R_EDI)));
               if load then
                 exprasmlist^.concat(new(pai386,op_reg_ref(A_MOV,S_L,
                 R_EDI,newreference(ref))));
               del_reference(p^.left^.location.reference);
               { the offset relative to (%ebp) is only needed here! }
               symtable:=p^.withsymtable;
               for i:=1 to p^.tablecount do
                 begin
                    symtable^.datasize:=ref.offset;
                    symtable:=symtable^.next;
                 end;

               { p^.right can be optimize out !!! }
               if p^.right<>nil then
                 secondpass(p^.right);
               { clear some stuff }
               if assigned(p^.pref) then
                 dispose(p^.pref);
               if load then
                 ungetiftemp(ref);
            end;
       end;


end.
{
  $Log$
  Revision 1.33  1999-03-26 11:43:26  pierre
   * bug0236 fixed

  Revision 1.32  1999/03/24 23:16:53  peter
    * fixed bugs 212,222,225,227,229,231,233

  Revision 1.31  1999/02/25 21:02:29  peter
    * ag386bin updates
    + coff writer

  Revision 1.30  1999/02/22 02:15:14  peter
    * updates for ag386bin

  Revision 1.29  1999/02/07 22:53:07  florian
    * potential bug in secondvecn fixed

  Revision 1.28  1999/02/04 17:16:51  peter
    * fixed crash with temp ansistring indexing

  Revision 1.27  1999/02/04 11:44:46  florian
    * fixed indexed access of ansistrings to temp. ansistring, i.e.
      c:=(s1+s2)[i], the temp is now correctly remove and the generated
      code is also fixed

  Revision 1.26  1999/02/04 10:49:41  florian
    + range checking for ansi- and widestrings
    * made it compilable with TP

  Revision 1.25  1999/01/21 16:40:52  pierre
   * fix for constructor inside with statements

  Revision 1.24  1999/01/19 12:05:27  pierre
   * bug with @procvar=procvar fiwed

  Revision 1.23  1998/12/30 22:15:45  peter
    + farpointer type
    * absolutesym now also stores if its far

  Revision 1.22  1998/12/11 00:02:55  peter
    + globtype,tokens,version unit splitted from globals

  Revision 1.21  1998/12/10 09:47:18  florian
    + basic operations with int64/qord (compiler with -dint64)
    + rtti of enumerations extended: names are now written

  Revision 1.20  1998/11/25 19:12:54  pierre
    * var:=new(pointer_type) support added

  Revision 1.19  1998/11/20 15:35:55  florian
    * problems with rtti fixed, hope it works

  Revision 1.18  1998/11/17 00:36:40  peter
    * more ansistring fixes

  Revision 1.17  1998/11/16 15:35:09  pierre
   * added error for with if different segment

  Revision 1.16  1998/10/21 11:44:42  florian
    + check for access to index 0 of long/wide/ansi strings added,
      gives now an error
    * problem with access to contant index of ansistrings fixed

  Revision 1.15  1998/10/12 09:49:53  florian
    + support of <procedure var type>:=<pointer> in delphi mode added

  Revision 1.14  1998/10/02 07:20:37  florian
    * range checking in units doesn't work if the units are smartlinked, fixed

  Revision 1.13  1998/09/27 10:16:23  florian
    * type casts pchar<->ansistring fixed
    * ansistring[..] calls does now an unique call

  Revision 1.12  1998/09/23 15:46:36  florian
    * problem with with and classes fixed

  Revision 1.11  1998/09/17 09:42:18  peter
    + pass_2 for cg386
    * Message() -> CGMessage() for pass_1/pass_2

  Revision 1.10  1998/09/14 10:43:52  peter
    * all internal RTL functions start with FPC_

  Revision 1.9  1998/09/03 16:03:15  florian
    + rtti generation
    * init table generation changed

  Revision 1.8  1998/08/23 21:04:34  florian
    + rtti generation for classes added
    + new/dispose do now also a call to INITIALIZE/FINALIZE, if necessaray

  Revision 1.7  1998/08/20 11:27:40  michael
  * Applied Peters Fix

  Revision 1.6  1998/08/10 14:49:49  peter
    + localswitches, moduleswitches, globalswitches splitting

  Revision 1.5  1998/07/26 21:58:58  florian
   + better support for switch $H
   + index access to ansi strings added
   + assigment of data (records/arrays) containing ansi strings

  Revision 1.4  1998/07/24 22:16:55  florian
    * internal error 10 together with array access fixed. I hope
      that's the final fix.

  Revision 1.3  1998/06/25 08:48:09  florian
    * first version of rtti support

  Revision 1.2  1998/06/08 13:13:35  pierre
    + temporary variables now in temp_gen.pas unit
      because it is processor independent
    * mppc68k.bat modified to undefine i386 and support_mmx
      (which are defaults for i386)

  Revision 1.1  1998/06/05 17:44:13  peter
    * splitted cgi386

}

