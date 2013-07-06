{
    Copyright (c) 2002 by Florian Klaempfl

    Generates the argument location information for i8086

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
unit cpupara;

{$i fpcdefs.inc}

  interface

    uses
       globtype,
       aasmtai,aasmdata,cpubase,cgbase,cgutils,
       symconst,symtype,symsym,symdef,
       parabase,paramgr;

    type
       ti8086paramanager = class(tparamanager)
          function param_use_paraloc(const cgpara:tcgpara):boolean;override;
          function ret_in_param(def:tdef;pd:tabstractprocdef):boolean;override;
          function push_addr_param(varspez:tvarspez;def : tdef;calloption : tproccalloption) : boolean;override;
          function get_para_align(calloption : tproccalloption):byte;override;
          function get_volatile_registers_int(calloption : tproccalloption):tcpuregisterset;override;
          function get_volatile_registers_fpu(calloption : tproccalloption):tcpuregisterset;override;
          function get_volatile_registers_mm(calloption : tproccalloption):tcpuregisterset;override;
          { Returns the location for the nr-st 16 Bit int parameter
            if every parameter before is an 16 Bit int parameter as well
            and if the calling conventions for the helper routines of the
            rtl are used.

            TODO: This allocates 32-bit ints on other CPU architectures. Since
            we're small/tiny model only, for now we can get away with allocating
            always 16-bit int parameters, but in the future, when we implement
            other memory models, this mechanism has to be extended somehow to
            support 32-bit addresses on a 16-bit CPU.
          }
          procedure getintparaloc(pd : tabstractprocdef; nr : longint; var cgpara : tcgpara);override;
          function create_paraloc_info(p : tabstractprocdef; side: tcallercallee):longint;override;
          function create_varargs_paraloc_info(p : tabstractprocdef; varargspara:tvarargsparalist):longint;override;
          procedure createtempparaloc(list: TAsmList;calloption : tproccalloption;parasym : tparavarsym;can_use_final_stack_loc : boolean;var cgpara:TCGPara);override;
          function get_funcretloc(p : tabstractprocdef; side: tcallercallee; forcetempdef: tdef): TCGPara;override;
       private
          procedure create_stdcall_paraloc_info(p : tabstractprocdef; side: tcallercallee;paras:tparalist;var parasize:longint);
          procedure create_register_paraloc_info(p : tabstractprocdef; side: tcallercallee;paras:tparalist;var parareg,parasize:longint);
       end;


  implementation

    uses
       cutils,
       systems,verbose,
       symtable,
       defutil;

      const
        parasupregs : array[0..2] of tsuperregister = (RS_AX,RS_DX,RS_CX);

{****************************************************************************
                                ti8086paramanager
****************************************************************************}

    function ti8086paramanager.param_use_paraloc(const cgpara:tcgpara):boolean;
      var
        paraloc : pcgparalocation;
      begin
        if not assigned(cgpara.location) then
          internalerror(200410102);
        result:=true;
        { All locations are LOC_REFERENCE }
        paraloc:=cgpara.location;
        while assigned(paraloc) do
          begin
            if (paraloc^.loc<>LOC_REFERENCE) then
              begin
                result:=false;
                exit;
              end;
            paraloc:=paraloc^.next;
          end;
      end;


    function ti8086paramanager.ret_in_param(def:tdef;pd:tabstractprocdef):boolean;
      var
        size: longint;
      begin
        if handle_common_ret_in_param(def,pd,result) then
          exit;

        if (def.size > 8) and (def.typ <> floatdef) then
          begin
            result:=true;
            exit;
          end;

        result:=inherited ret_in_param(def,pd);
      end;


    function ti8086paramanager.push_addr_param(varspez:tvarspez;def : tdef;calloption : tproccalloption) : boolean;
      begin
        result:=false;
        { var,out,constref always require address }
        if varspez in [vs_var,vs_out,vs_constref] then
          begin
            result:=true;
            exit;
          end;
        { Only vs_const, vs_value here }
        case def.typ of
          variantdef :
            begin
              { variants are small enough to be passed by value except if
                required by the windows api

                variants are somethings very delphi/windows specific so do it like
                windows/delphi (FK)
              }
              if ((target_info.system=system_i386_win32) and
                 (calloption in [pocall_stdcall,pocall_safecall]) and
                 (varspez=vs_const)) or
                 (calloption=pocall_register) then
                result:=true
              else
                result:=false;
            end;
          formaldef :
            result:=true;
          recorddef :
            begin
              { Delphi stdcall passes records on the stack for call by value }
              if (target_info.system=system_i386_win32) and
                 (calloption=pocall_stdcall) and
                 (varspez=vs_value) then
                result:=false
              else
                result:=
                  (not(calloption in (cdecl_pocalls)) and
                   (def.size>sizeof(aint))) or
                  (((calloption = pocall_mwpascal) or (target_info.system=system_i386_wince)) and
                   (varspez=vs_const));
            end;
          arraydef :
            begin
              { array of const values are pushed on the stack as
                well as dyn. arrays }
              if (calloption in cdecl_pocalls) then
                result:=not(is_array_of_const(def) or
                        is_dynamic_array(def))
              else
                begin
                  result:=(
                           (tarraydef(def).highrange>=tarraydef(def).lowrange) and
                           (def.size>sizeof(aint))
                          ) or
                          is_open_array(def) or
                          is_array_of_const(def) or
                          is_array_constructor(def);
                end;
            end;
          objectdef :
            result:=is_object(def);
          stringdef :
            result:= (tstringdef(def).stringtype in [st_shortstring,st_longstring]);
          procvardef :
            result:=not(calloption in cdecl_pocalls) and not tprocvardef(def).is_addressonly;
          setdef :
            result:=not(calloption in cdecl_pocalls) and (not is_smallset(def));
        end;
      end;


    function ti8086paramanager.get_para_align(calloption : tproccalloption):byte;
      begin
        result:=std_param_align;
      end;


    function ti8086paramanager.get_volatile_registers_int(calloption : tproccalloption):tcpuregisterset;
      begin
        case calloption of
          pocall_internproc :
            result:=[];
          pocall_register,
          pocall_safecall,
          pocall_stdcall,
          pocall_cdecl,
          pocall_cppdecl,
          pocall_mwpascal :
            result:=[RS_AX,RS_DX,RS_CX];
          pocall_far16,
          pocall_pascal,
          pocall_oldfpccall :
            result:=[RS_AX,RS_DX,RS_CX,RS_SI,RS_DI,RS_BX];
          else
            internalerror(200309071);
        end;
      end;


    function ti8086paramanager.get_volatile_registers_fpu(calloption : tproccalloption):tcpuregisterset;
      begin
        result:=[0..first_fpu_imreg-1];
      end;


    function ti8086paramanager.get_volatile_registers_mm(calloption : tproccalloption):tcpuregisterset;
      begin
        result:=[0..first_mm_imreg-1];
      end;


    procedure ti8086paramanager.getintparaloc(pd : tabstractprocdef; nr : longint; var cgpara : tcgpara);
      var
        paraloc : pcgparalocation;
        psym: tparavarsym;
        pdef : tdef;
      begin
        psym:=tparavarsym(pd.paras[nr-1]);
        pdef:=psym.vardef;
        if push_addr_param(psym.varspez,pdef,pd.proccalloption) then
          pdef:=getpointerdef(pdef);
        cgpara.reset;
        cgpara.size:=def_cgsize(pdef);
        cgpara.intsize:=tcgsize2size[cgpara.size];
        cgpara.alignment:=get_para_align(pd.proccalloption);
        cgpara.def:=pdef;
        paraloc:=cgpara.add_location;
        with paraloc^ do
         begin
           size:=def_cgsize(pdef);
           def:=pdef;
           if pd.proccalloption=pocall_register then
             begin
               if (nr<=length(parasupregs)) then
                 begin
                   if nr=0 then
                     internalerror(200309271);
                   loc:=LOC_REGISTER;
                   register:=newreg(R_INTREGISTER,parasupregs[nr-1],R_SUBWHOLE);
                 end
               else
                 begin
                   loc:=LOC_REFERENCE;
                   reference.index:=NR_STACK_POINTER_REG;
                   { the previous parameters didn't take up room in memory }
                   reference.offset:=sizeof(aint)*(nr-length(parasupregs)-1)
                 end;
             end
           else
             begin
               loc:=LOC_REFERENCE;
               reference.index:=NR_STACK_POINTER_REG;
               reference.offset:=sizeof(aint)*nr;
             end;
          end;
      end;


    function  ti8086paramanager.get_funcretloc(p : tabstractprocdef; side: tcallercallee; forcetempdef: tdef): TCGPara;
      var
        retcgsize  : tcgsize;
        paraloc : pcgparalocation;
        sym: tfieldvarsym;
        usedef: tdef;
        handled: boolean;
      begin
        if not assigned(forcetempdef) then
          usedef:=p.returndef
        else
          usedef:=forcetempdef;
        { on darwin/i386, if a record has only one field and that field is a
          single or double, it has to be returned like a single/double }
        if (target_info.system in [system_i386_darwin,system_i386_iphonesim]) and
           ((usedef.typ=recorddef) or
            is_object(usedef)) and
           tabstractrecordsymtable(tabstractrecorddef(usedef).symtable).has_single_field(sym) and
           (sym.vardef.typ=floatdef) and
           (tfloatdef(sym.vardef).floattype in [s32real,s64real]) then
          usedef:=sym.vardef;

        handled:=set_common_funcretloc_info(p,usedef,retcgsize,result);
        { normally forcetempdef is passed straight through to
          set_common_funcretloc_info and that one will correctly determine whether
          the location is a temporary one, but that doesn't work here because we
          sometimes have to change the type }
        result.temporary:=assigned(forcetempdef);
        if handled then
          exit;

        { darwin/x86 requires that results < sizeof(aint) are sign/zero
          extended to sizeof(aint) }
        if (target_info.system in [system_i386_darwin,system_i386_iphonesim]) and
           (side=calleeside) and
           (result.intsize>0) and
           (result.intsize<sizeof(aint)) then
          begin
            result.def:=sinttype;
            result.intsize:=sizeof(aint);
            retcgsize:=OS_SINT;
            result.size:=retcgsize;
          end;

        { Return in FPU register? }
        if result.def.typ=floatdef then
          begin
            paraloc:=result.add_location;
            paraloc^.loc:=LOC_FPUREGISTER;
            paraloc^.register:=NR_FPU_RESULT_REG;
            paraloc^.size:=retcgsize;
            paraloc^.def:=result.def;
          end
        else
         { Return in register }
          begin
            paraloc:=result.add_location;
            paraloc^.loc:=LOC_REGISTER;
            if retcgsize in [OS_64,OS_S64] then
             begin
               { bits 0..15 }
               if side=callerside then
                 paraloc^.register:=NR_FUNCTION_RESULT64_LOW_REG
               else
                 paraloc^.register:=NR_FUNCTION_RETURN64_LOW_REG;
               paraloc^.size:=OS_16;
               paraloc^.def:=u16inttype;

               { bits 16..31 }
               paraloc:=result.add_location;
               paraloc^.loc:=LOC_REGISTER;
               if side=callerside then
                 paraloc^.register:=NR_FUNCTION_RESULT64_HIGH_REG
               else
                 paraloc^.register:=NR_FUNCTION_RETURN64_HIGH_REG;
               paraloc^.size:=OS_16;
               paraloc^.def:=u16inttype;

               { bits 32..47 }
               paraloc:=result.add_location;
               paraloc^.loc:=LOC_REGISTER;
               if side=callerside then
                 paraloc^.register:=NR_FUNCTION_RESULT64_HIGHER_REG
               else
                 paraloc^.register:=NR_FUNCTION_RETURN64_HIGHER_REG;
               paraloc^.size:=OS_16;
               paraloc^.def:=u16inttype;

               { bits 48..63 }
               paraloc:=result.add_location;
               paraloc^.loc:=LOC_REGISTER;
               if side=callerside then
                 paraloc^.register:=NR_FUNCTION_RESULT64_HIGHEST_REG
               else
                 paraloc^.register:=NR_FUNCTION_RETURN64_HIGHEST_REG;
               paraloc^.size:=OS_16;
               paraloc^.def:=u16inttype;
             end
            else if retcgsize in [OS_32,OS_S32] then
             begin
               { low 16bits }
               if side=callerside then
                 paraloc^.register:=NR_FUNCTION_RESULT32_LOW_REG
               else
                 paraloc^.register:=NR_FUNCTION_RETURN32_LOW_REG;
               paraloc^.size:=OS_16;
               paraloc^.def:=u16inttype;

               { high 16bits }
               paraloc:=result.add_location;
               paraloc^.loc:=LOC_REGISTER;
               if side=callerside then
                 paraloc^.register:=NR_FUNCTION_RESULT32_HIGH_REG
               else
                 paraloc^.register:=NR_FUNCTION_RETURN32_HIGH_REG;
               paraloc^.size:=OS_16;
               paraloc^.def:=u16inttype;
             end
            else
             begin
               paraloc^.size:=retcgsize;
               paraloc^.def:=result.def;
               if side=callerside then
                 paraloc^.register:=newreg(R_INTREGISTER,RS_FUNCTION_RESULT_REG,cgsize2subreg(R_INTREGISTER,retcgsize))
               else
                 paraloc^.register:=newreg(R_INTREGISTER,RS_FUNCTION_RETURN_REG,cgsize2subreg(R_INTREGISTER,retcgsize));
             end;
          end;
      end;


    procedure ti8086paramanager.create_stdcall_paraloc_info(p : tabstractprocdef; side: tcallercallee;paras:tparalist;var parasize:longint);
      var
        i  : integer;
        hp : tparavarsym;
        paradef : tdef;
        paraloc : pcgparalocation;
        l,
        paralen,
        varalign   : longint;
        paraalign  : shortint;
        paracgsize : tcgsize;
        firstparaloc,
        pushaddr   : boolean;
      begin
        paraalign:=get_para_align(p.proccalloption);
        { we push Flags and CS as long
          to cope with the IRETD
          and we save 6 register + 4 selectors }
        if po_interrupt in p.procoptions then
          inc(parasize,8+6*4+4*2);
        { Offset is calculated like:
           sub esp,12
           mov [esp+8],para3
           mov [esp+4],para2
           mov [esp],para1
           call function
          That means for pushes the para with the
          highest offset (see para3) needs to be pushed first
        }
        if p.proccalloption in pushleftright_pocalls then
          i:=paras.count-1
        else
          i:=0;
        while ((p.proccalloption in pushleftright_pocalls) and (i>=0)) or
              (not(p.proccalloption in pushleftright_pocalls) and (i<=paras.count-1)) do
          begin
            hp:=tparavarsym(paras[i]);
            paradef:=hp.vardef;
            pushaddr:=push_addr_param(hp.varspez,paradef,p.proccalloption);
            if pushaddr then
              begin
                paralen:=sizeof(aint);
                paracgsize:=OS_ADDR;
                paradef:=getpointerdef(paradef);
              end
            else
              begin
                paralen:=push_size(hp.varspez,paradef,p.proccalloption);
                { darwin/x86 requires that parameters < sizeof(aint) are sign/ }
                { zero extended to sizeof(aint)                                }
                if (target_info.system in [system_i386_darwin,system_i386_iphonesim]) and
                   (side = callerside) and
                   (paralen > 0) and
                   (paralen < sizeof(aint)) then
                  begin
                    paralen:=sizeof(aint);
                    paracgsize:=OS_SINT;
                    paradef:=sinttype;
                  end
                else
                  paracgsize:=def_cgsize(paradef);
              end;
            hp.paraloc[side].reset;
            hp.paraloc[side].size:=paracgsize;
            hp.paraloc[side].intsize:=paralen;
            hp.paraloc[side].def:=paradef;
            hp.paraloc[side].Alignment:=paraalign;
            { Copy to stack? }
            if (paracgsize=OS_NO) or
               (use_fixed_stack) then
              begin
                paraloc:=hp.paraloc[side].add_location;
                paraloc^.loc:=LOC_REFERENCE;
                paraloc^.size:=paracgsize;
                paraloc^.def:=paradef;
                if side=callerside then
                  paraloc^.reference.index:=NR_STACK_POINTER_REG
                else
                  paraloc^.reference.index:=NR_FRAME_POINTER_REG;
                varalign:=used_align(size_2_align(paralen),paraalign,paraalign);

                { don't let push_size return 16, because then we can    }
                { read past the end of the heap since the value is only }
                { 10 bytes long (JM)                                    }
                if (paracgsize = OS_F80) and
                   (target_info.system in [system_i386_darwin,system_i386_iphonesim]) then
                  paralen:=16;
                paraloc^.reference.offset:=parasize;
                if side=calleeside then
                  begin
                    inc(paraloc^.reference.offset,target_info.first_parm_offset);
                    if po_far in p.procoptions then
                      inc(paraloc^.reference.offset,2);
                  end;
                parasize:=align(parasize+paralen,varalign);
              end
            else
              begin
                if paralen=0 then
                  internalerror(200501163);
                firstparaloc:=true;
                while (paralen>0) do
                  begin
                    paraloc:=hp.paraloc[side].add_location;
                    paraloc^.loc:=LOC_REFERENCE;
                    { single and double need a single location }
                    if (paracgsize in [OS_F64,OS_F32]) then
                      begin
                        paraloc^.size:=paracgsize;
                        paraloc^.def:=paradef;
                        l:=paralen;
                      end
                    else
                      begin
                        { We can allocate at maximum 16 bits per location }
                        if paralen>=sizeof(aint) then
                          begin
                            l:=sizeof(aint);
                            paraloc^.def:=uinttype;
                          end
                        else
                          begin
                            l:=paralen;
                            paraloc^.def:=get_paraloc_def(paradef,l,firstparaloc);
                          end;
                        paraloc^.size:=int_cgsize(l);
                      end;
                    if (side=callerside) or
                       (po_nostackframe in p.procoptions) then
                      paraloc^.reference.index:=NR_STACK_POINTER_REG
                    else
                      paraloc^.reference.index:=NR_FRAME_POINTER_REG;
                    varalign:=used_align(size_2_align(l),paraalign,paraalign);
                    paraloc^.reference.offset:=parasize;
                    if side=calleeside then
                      begin
                        if not(po_nostackframe in p.procoptions) then
                          inc(paraloc^.reference.offset,target_info.first_parm_offset)
                        else
                          { return addres }
                          inc(paraloc^.reference.offset,2);
                        if po_far in p.procoptions then
                          inc(paraloc^.reference.offset,2);
                      end;
                    parasize:=align(parasize+l,varalign);
                    dec(paralen,l);
                    firstparaloc:=false;
                  end;
              end;
            if p.proccalloption in pushleftright_pocalls then
              dec(i)
            else
              inc(i);
          end;
      end;


    procedure ti8086paramanager.create_register_paraloc_info(p : tabstractprocdef; side: tcallercallee;paras:tparalist;
                                                            var parareg,parasize:longint);
      var
        hp : tparavarsym;
        paradef : tdef;
        paraloc : pcgparalocation;
        paracgsize : tcgsize;
        i : integer;
        l,
        paralen,
        varalign : longint;
        pushaddr : boolean;
        paraalign : shortint;
        pass : byte;
        firstparaloc : boolean;
      begin
        if paras.count=0 then
          exit;
        paraalign:=get_para_align(p.proccalloption);

        { clean up here so we can later detect properly if a parameter has been
          assigned or not
        }
        for i:=0 to paras.count-1 do
          tparavarsym(paras[i]).paraloc[side].reset;
        { Register parameters are assigned from left to right,
          stack parameters from right to left so assign first the
          register parameters in a first pass, in the second
          pass all unhandled parameters are done }
        for pass:=1 to 2 do
          begin
            if pass=1 then
              i:=0
            else
              i:=paras.count-1;
            while true do
              begin
                hp:=tparavarsym(paras[i]);
                paradef:=hp.vardef;
                if not(assigned(hp.paraloc[side].location)) then
                  begin
                    pushaddr:=push_addr_param(hp.varspez,hp.vardef,p.proccalloption);
                    if pushaddr then
                      begin
                        paralen:=sizeof(aint);
                        paracgsize:=OS_ADDR;
                        paradef:=getpointerdef(paradef);
                      end
                    else
                      begin
                        paralen:=push_size(hp.varspez,hp.vardef,p.proccalloption);
                        paracgsize:=def_cgsize(hp.vardef);
                      end;
                    hp.paraloc[side].size:=paracgsize;
                    hp.paraloc[side].intsize:=paralen;
                    hp.paraloc[side].Alignment:=paraalign;
                    hp.paraloc[side].def:=paradef;
                    {
                      EAX
                      EDX
                      ECX
                      Stack
                      Stack

                      64bit values,floats,arrays and records are always
                      on the stack.

                      In case of po_delphi_nested_cc, the parent frame pointer
                      is also always passed on the stack.
                    }
                    if (parareg<=high(parasupregs)) and
                       (paralen<=sizeof(aint)) and
                       (not(hp.vardef.typ in [floatdef,recorddef,arraydef]) or
                        pushaddr) and
                       (not(vo_is_parentfp in hp.varoptions) or
                        not(po_delphi_nested_cc in p.procoptions)) then
                      begin
                        if pass=1 then
                          begin
                            paraloc:=hp.paraloc[side].add_location;
                            paraloc^.size:=paracgsize;
                            paraloc^.def:=paradef;
                            paraloc^.loc:=LOC_REGISTER;
                            paraloc^.register:=newreg(R_INTREGISTER,parasupregs[parareg],cgsize2subreg(R_INTREGISTER,paracgsize));
                            inc(parareg);
                          end;
                      end
                    else
                      if pass=2 then
                        begin
                          { Copy to stack? }
                          if (use_fixed_stack) or
                             (paracgsize=OS_NO) then
                            begin
                              paraloc:=hp.paraloc[side].add_location;
                              paraloc^.loc:=LOC_REFERENCE;
                              paraloc^.size:=paracgsize;
                              paraloc^.def:=paradef;
                              if side=callerside then
                                paraloc^.reference.index:=NR_STACK_POINTER_REG
                              else
                                paraloc^.reference.index:=NR_FRAME_POINTER_REG;
                              varalign:=used_align(size_2_align(paralen),paraalign,paraalign);
                              paraloc^.reference.offset:=parasize;
                              if side=calleeside then
                                begin
                                  inc(paraloc^.reference.offset,target_info.first_parm_offset);
                                  if po_far in p.procoptions then
                                    inc(paraloc^.reference.offset,2);
                                end;
                              parasize:=align(parasize+paralen,varalign);
                            end
                          else
                            begin
                              if paralen=0 then
                                internalerror(200501163);
                              firstparaloc:=true;
                              while (paralen>0) do
                                begin
                                  paraloc:=hp.paraloc[side].add_location;
                                  paraloc^.loc:=LOC_REFERENCE;
                                  { Extended and double need a single location }
                                  if (paracgsize in [OS_F64,OS_F32]) then
                                    begin
                                      paraloc^.size:=paracgsize;
                                      paraloc^.def:=paradef;
                                      l:=paralen;
                                    end
                                  else
                                    begin
                                      { We can allocate at maximum 32 bits per location }
                                      if paralen>sizeof(aint) then
                                        begin
                                          l:=sizeof(aint);
                                          paraloc^.def:=uinttype;
                                        end
                                      else
                                        begin
                                          l:=paralen;
                                          paraloc^.def:=get_paraloc_def(paradef,l,firstparaloc);
                                        end;
                                      paraloc^.size:=int_cgsize(l);
                                    end;
                                  if side=callerside then
                                    paraloc^.reference.index:=NR_STACK_POINTER_REG
                                  else
                                    paraloc^.reference.index:=NR_FRAME_POINTER_REG;
                                  varalign:=used_align(size_2_align(l),paraalign,paraalign);
                                  paraloc^.reference.offset:=parasize;
                                  if side=calleeside then
                                    begin
                                      inc(paraloc^.reference.offset,target_info.first_parm_offset);
                                      if po_far in p.procoptions then
                                        inc(paraloc^.reference.offset,2);
                                    end;
                                  parasize:=align(parasize+l,varalign);
                                  dec(paralen,l);
                                  firstparaloc:=false;
                                end;
                            end;
                        end;
                  end;
                case pass of
                  1:
                    begin
                      if i=paras.count-1 then
                        break;
                      inc(i);
                    end;
                  2:
                    begin
                      if i=0 then
                        break;
                      dec(i);
                    end;
                end;
              end;
          end;
      end;


    function ti8086paramanager.create_paraloc_info(p : tabstractprocdef; side: tcallercallee):longint;
      var
        parasize,
        parareg : longint;
      begin
        parasize:=0;
        parareg:=0;
        case p.proccalloption of
          pocall_register :
            create_register_paraloc_info(p,side,p.paras,parareg,parasize);
          pocall_internproc :
            begin
              { Use default calling }
{$warnings off}
              if (pocall_default=pocall_register) then
                create_register_paraloc_info(p,side,p.paras,parareg,parasize)
              else
                create_stdcall_paraloc_info(p,side,p.paras,parasize);
{$warnings on}
            end;
          else
            create_stdcall_paraloc_info(p,side,p.paras,parasize);
        end;
        create_funcretloc_info(p,side);
        result:=parasize;
      end;


    function ti8086paramanager.create_varargs_paraloc_info(p : tabstractprocdef; varargspara:tvarargsparalist):longint;
      var
        parasize : longint;
      begin
        parasize:=0;
        { calculate the registers for the normal parameters }
        create_stdcall_paraloc_info(p,callerside,p.paras,parasize);
        { append the varargs }
        create_stdcall_paraloc_info(p,callerside,varargspara,parasize);
        result:=parasize;
      end;


    procedure ti8086paramanager.createtempparaloc(list: TAsmList;calloption : tproccalloption;parasym : tparavarsym;can_use_final_stack_loc : boolean;var cgpara:TCGPara);
      begin
        { Never a need for temps when value is pushed (calls inside parameters
          will simply allocate even more stack space for their parameters) }
        if not(use_fixed_stack) then
          can_use_final_stack_loc:=true;
        inherited createtempparaloc(list,calloption,parasym,can_use_final_stack_loc,cgpara);
      end;


begin
   paramanager:=ti8086paramanager.create;
end.
