{
    $Id$
    Copyright (c) 2002 by Florian Klaempfl

    Generic calling convention handling

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
{# Parameter passing manager. Used to manage how
   parameters are passed to routines.
}
unit paramgr;

{$i fpcdefs.inc}

  interface

    uses
       cpubase,
       globtype,
       symconst,symtype,symdef;

    type
       {# This class defines some methods to take care of routine
          parameters. It should be overriden for each new processor
       }
       tparamanager = class
          {# Returns true if the return value can be put in accumulator }
          function ret_in_acc(def : tdef;calloption : tproccalloption) : boolean;virtual;

          {# Returns true if the return value is actually a parameter
             pointer.
          }
          function ret_in_param(def : tdef;calloption : tproccalloption) : boolean;virtual;

          function push_high_param(def : tdef;calloption : tproccalloption) : boolean;virtual;

          { Returns true if a parameter is too large to copy and only
            the address is pushed
          }
          function push_addr_param(def : tdef;calloption : tproccalloption) : boolean;virtual;
          { return the size of a push }
          function push_size(varspez:tvarspez;def : tdef;calloption : tproccalloption) : longint;
          { Returns true if a parameter needs to be copied on the stack, this
            is required for cdecl procedures
          }
          function copy_value_on_stack(def : tdef;calloption : tproccalloption) : boolean;
          {# Returns a structure giving the information on
            the storage of the parameter (which must be
            an integer parameter). This is only used when calling
            internal routines directly, where all parameters must
            be 4-byte values.

            @param(nr Parameter number of routine, starting from 1)
          }
          function getintparaloc(nr : longint) : tparalocation;virtual;abstract;
          {# This is used to populate the location information on all parameters
             for the routine. This is used for normal call resolution.
          }
          procedure create_param_loc_info(p : tabstractprocdef);virtual;abstract;

          {
            Returns the location where the invisible parameter for structured
            function results will be passed.
          }
          function getfuncretparaloc(p : tabstractprocdef) : tparalocation;virtual;

          {
            Returns the location where the invisible parameter for nested
            subroutines is passed.
          }
          function getframepointerloc(p : tabstractprocdef) : tparalocation;virtual;

          { Returns the self pointer location for the given tabstractprocdef,
            when the stack frame is already created. This is used by the code
            generating the wrappers for implemented interfaces.
          }
          function getselflocation(p : tabstractprocdef) : tparalocation;virtual;abstract;

          {
            Returns the location of the result if the result is in
            a register, the register(s) return depend on the type of
            the result.

            @param(def The definition of the result type of the function)
          }
          function getfuncresultloc(def : tdef;calloption:tproccalloption): tparalocation; virtual;
       end;

    procedure setparalocs(p : tprocdef);
    function getfuncretusedregisters(def : tdef;calloption:tproccalloption): tregisterset;

    var
       paralocdummy : tparalocation;
       paramanager : tparamanager;

  implementation

    uses
       cpuinfo,globals,systems,
       symbase,symsym,
       rgobj,
       defutil,cgbase,cginfo,verbose;

    { true if the return value is in accumulator (EAX for i386), D0 for 68k }
    function tparamanager.ret_in_acc(def : tdef;calloption : tproccalloption) : boolean;
      begin
         ret_in_acc:=(def.deftype in [orddef,pointerdef,enumdef,classrefdef]) or
                     ((def.deftype=stringdef) and (tstringdef(def).string_typ in [st_ansistring,st_widestring])) or
                     ((def.deftype=procvardef) and not(po_methodpointer in tprocvardef(def).procoptions)) or
                     ((def.deftype=objectdef) and not is_object(def)) or
                     ((def.deftype=setdef) and (tsetdef(def).settype=smallset));
      end;


    { true if uses a parameter as return value }
    function tparamanager.ret_in_param(def : tdef;calloption : tproccalloption) : boolean;
      begin
         ret_in_param:=(def.deftype in [arraydef,recorddef]) or
           ((def.deftype=stringdef) and (tstringdef(def).string_typ in [st_shortstring,st_longstring])) or
           ((def.deftype=procvardef) and (po_methodpointer in tprocvardef(def).procoptions)) or
           ((def.deftype=objectdef) and is_object(def)) or
           (def.deftype=variantdef) or
           ((def.deftype=setdef) and (tsetdef(def).settype<>smallset));
      end;


    function tparamanager.push_high_param(def : tdef;calloption : tproccalloption) : boolean;
      begin
         push_high_param:=not(calloption in [pocall_cdecl,pocall_cppdecl]) and
                          (
                           is_open_array(def) or
                           is_open_string(def) or
                           is_array_of_const(def)
                          );
      end;


    { true if a parameter is too large to copy and only the address is pushed }
    function tparamanager.push_addr_param(def : tdef;calloption : tproccalloption) : boolean;
      begin
        push_addr_param:=false;
        case def.deftype of
          variantdef,
          formaldef :
            push_addr_param:=true;
          recorddef :
            push_addr_param:=not(calloption in [pocall_cdecl,pocall_cppdecl]) and (def.size>pointer_size);
          arraydef :
            begin
              if (calloption in [pocall_cdecl,pocall_cppdecl]) then
               begin
                 { array of const values are pushed on the stack }
                 push_addr_param:=not is_array_of_const(def);
               end
              else
               begin
                 push_addr_param:=(
                                   (tarraydef(def).highrange>=tarraydef(def).lowrange) and
                                   (def.size>pointer_size)
                                  ) or
                                  is_open_array(def) or
                                  is_array_of_const(def) or
                                  is_array_constructor(def);
               end;
            end;
          objectdef :
            push_addr_param:=is_object(def);
          stringdef :
            push_addr_param:=not(calloption in [pocall_cdecl,pocall_cppdecl]) and (tstringdef(def).string_typ in [st_shortstring,st_longstring]);
          procvardef :
            push_addr_param:=not(calloption in [pocall_cdecl,pocall_cppdecl]) and (po_methodpointer in tprocvardef(def).procoptions);
          setdef :
            push_addr_param:=not(calloption in [pocall_cdecl,pocall_cppdecl]) and (tsetdef(def).settype<>smallset);
        end;
      end;


    { true if a parameter is too large to push and needs a concatcopy to get the value on the stack }
    function tparamanager.copy_value_on_stack(def : tdef;calloption : tproccalloption) : boolean;
      begin
        copy_value_on_stack:=false;
        { this is only for cdecl procedures }
        if not(calloption in [pocall_cdecl,pocall_cppdecl]) then
         exit;
        case def.deftype of
          variantdef,
          formaldef :
            copy_value_on_stack:=true;
          recorddef :
            copy_value_on_stack:=(def.size>pointer_size);
          arraydef :
            copy_value_on_stack:=(tarraydef(def).highrange>=tarraydef(def).lowrange) and
                                 (def.size>pointer_size);
          objectdef :
            copy_value_on_stack:=is_object(def);
          stringdef :
            copy_value_on_stack:=tstringdef(def).string_typ in [st_shortstring,st_longstring];
          procvardef :
            copy_value_on_stack:=(po_methodpointer in tprocvardef(def).procoptions);
          setdef :
            copy_value_on_stack:=(tsetdef(def).settype<>smallset);
        end;
      end;


    { return the size of a push }
    function tparamanager.push_size(varspez:tvarspez;def : tdef;calloption : tproccalloption) : longint;
      begin
        push_size:=-1;
        case varspez of
          vs_out,
          vs_var :
            push_size:=pointer_size;
          vs_value,
          vs_const :
            begin
                if push_addr_param(def,calloption) then
                  push_size:=pointer_size
                else
                  begin
                    { special array are normally pushed by addr, only for
                      cdecl array of const it comes here and the pushsize
                      is unknown }
                    if is_array_of_const(def) then
                      push_size:=0
                    else
                      push_size:=def.size;
                  end;
            end;
        end;
      end;


    function tparamanager.getfuncretparaloc(p : tabstractprocdef) : tparalocation;
      begin
         result.loc:=LOC_REFERENCE;
         result.size:=OS_ADDR;
         result.sp_fixup:=pointer_size;
         result.reference.index.enum:=stack_pointer_reg;
         result.reference.offset:=0;
      end;


    function tparamanager.getframepointerloc(p : tabstractprocdef) : tparalocation;
      begin
         result.loc:=LOC_REFERENCE;
         result.size:=OS_ADDR;
         result.sp_fixup:=pointer_size;
         result.reference.index.enum:=stack_pointer_reg;
         result.reference.offset:=0;
      end;


    function tparamanager.getfuncresultloc(def : tdef;calloption:tproccalloption): tparalocation;
      begin
         fillchar(result,sizeof(tparalocation),0);
         if is_void(def) then exit;

         result.size := def_cgsize(def);
         case def.deftype of
           orddef,
           enumdef :
             begin
               result.loc := LOC_REGISTER;
{$ifndef cpu64bit}
               if result.size in [OS_64,OS_S64] then
                begin
                  result.register64.reghi.enum:=accumulatorhigh;
                  result.register64.reglo.enum:=accumulator;
                end
               else
{$endif cpu64bit}
               result.register.enum:=accumulator;
             end;
           floatdef :
             begin
               result.loc := LOC_FPUREGISTER;
{$ifdef cpufpemu}
               if cs_fp_emulation in aktmoduleswitches then
                  result.register.enum := accumulator
               else
{$endif cpufpemu}
                  result.register.enum := FPU_RESULT_REG;
             end;
          else
             begin
                if ret_in_acc(def,calloption) then
                  begin
                    result.loc := LOC_REGISTER;
                    result.register.enum := accumulator;
                  end
                else
                   begin
                     result.loc := LOC_REFERENCE;
                     internalerror(2002081602);
(*
{$ifdef EXTDEBUG}
                     { it is impossible to have the
                       return value with an index register
                       and a symbol!
                     }
                     if (ref.index <> R_NO) or (assigned(ref.symbol)) then
                        internalerror(2002081602);
{$endif}
                     result.reference.index := ref.base;
                     result.reference.offset := ref.offset;
*)
                   end;
             end;
          end;
      end;


    function getfuncretusedregisters(def : tdef;calloption:tproccalloption): tregisterset;
      var
        paramloc : tparalocation;
        regset : tregisterset;
      begin
        regset:=[];
        getfuncretusedregisters:=[];
        { if nothing is returned in registers,
          its useless to continue on in this
          routine
        }
        if paramanager.ret_in_param(def,calloption) then
          exit;
        paramloc := paramanager.getfuncresultloc(def,calloption);
        case paramloc.loc of
          LOC_FPUREGISTER,
          LOC_CFPUREGISTER,
          LOC_MMREGISTER,
          LOC_CMMREGISTER,
          LOC_REGISTER,LOC_CREGISTER :
              begin
                regset := regset + [paramloc.register.enum];
                if ((paramloc.size in [OS_S64,OS_64]) and
                   (sizeof(aword) < 8))
                then
                  begin
                     regset := regset + [paramloc.registerhigh.enum];
                  end;
              end;
          else
            internalerror(20020816);
        end;
        getfuncretusedregisters:=regset;
      end;

    procedure setparalocs(p : tprocdef);

      var
         hp : tparaitem;

      begin
         hp:=tparaitem(p.para.first);
         while assigned(hp) do
           begin
              if (hp.paraloc.loc in [LOC_REGISTER,LOC_FPUREGISTER,
                 LOC_MMREGISTER]) and
                 (
                  (vo_regable in tvarsym(hp.parasym).varoptions) or
                  (vo_fpuregable in tvarsym(hp.parasym).varoptions) or
                   paramanager.push_addr_param(hp.paratype.def,p.proccalloption) or
                   (hp.paratyp in [vs_var,vs_out])
                 ) then
                begin
                   case hp.paraloc.loc of
                     LOC_REGISTER:
                       hp.paraloc.loc := LOC_CREGISTER;
                     LOC_FPUREGISTER:
                       hp.paraloc.loc := LOC_CFPUREGISTER;
{$ifdef SUPPORT_MMX}
                     LOC_MMREGISTER:
                       hp.paraloc.loc := LOC_CMMREGISTER;
{$endif}
                   end;
                   tvarsym(hp.parasym).paraitem:=hp;
                end;
              hp:=tparaitem(hp.next);
           end;
      end;

initialization
  ;
finalization
  paramanager.free;
end.

{
   $Log$
   Revision 1.35  2003-04-27 07:29:50  peter
     * aktprocdef cleanup, aktprocdef is now always nil when parsing
       a new procdef declaration
     * aktprocsym removed
     * lexlevel removed, use symtable.symtablelevel instead
     * implicit init/final code uses the normal genentry/genexit
     * funcret state checking updated for new funcret handling

   Revision 1.34  2003/04/23 13:15:04  peter
     * fix push_high_param for cdecl

   Revision 1.33  2003/04/23 10:14:30  peter
     * cdecl array of const has no addr push

   Revision 1.32  2003/04/22 13:47:08  peter
     * fixed C style array of const
     * fixed C array passing
     * fixed left to right with high parameters

   Revision 1.31  2003/02/02 19:25:54  carl
     * Several bugfixes for m68k target (register alloc., opcode emission)
     + VIS target
     + Generic add more complete (still not verified)

   Revision 1.30  2003/01/08 18:43:56  daniel
    * Tregister changed into a record

   Revision 1.29  2002/12/23 20:58:03  peter
     * remove unused global var

   Revision 1.28  2002/12/17 22:19:33  peter
     * fixed pushing of records>8 bytes with stdcall
     * simplified hightree loading

   Revision 1.27  2002/12/06 16:56:58  peter
     * only compile cs_fp_emulation support when cpufpuemu is defined
     * define cpufpuemu for m68k only

   Revision 1.26  2002/11/27 20:04:09  peter
     * tvarsym.get_push_size replaced by paramanager.push_size

   Revision 1.25  2002/11/27 02:33:19  peter
     * copy_value_on_stack method added for cdecl record passing

   Revision 1.24  2002/11/25 17:43:21  peter
     * splitted defbase in defutil,symutil,defcmp
     * merged isconvertable and is_equal into compare_defs(_ext)
     * made operator search faster by walking the list only once

   Revision 1.23  2002/11/18 17:31:58  peter
     * pass proccalloption to ret_in_xxx and push_xxx functions

   Revision 1.22  2002/11/16 18:00:04  peter
     * only push small arrays on the stack for win32

   Revision 1.21  2002/10/05 12:43:25  carl
     * fixes for Delphi 6 compilation
      (warning : Some features do not work under Delphi)

   Revision 1.20  2002/09/30 07:07:25  florian
     * fixes to common code to get the alpha compiler compiled applied

   Revision 1.19  2002/09/30 07:00:47  florian
     * fixes to common code to get the alpha compiler compiled applied

   Revision 1.18  2002/09/09 09:10:51  florian
     + added generic tparamanager.getframepointerloc

   Revision 1.17  2002/09/07 19:40:39  florian
     * tvarsym.paraitem is set now

   Revision 1.16  2002/09/01 21:04:48  florian
     * several powerpc related stuff fixed

   Revision 1.15  2002/08/25 19:25:19  peter
     * sym.insert_in_data removed
     * symtable.insertvardata/insertconstdata added
     * removed insert_in_data call from symtable.insert, it needs to be
       called separatly. This allows to deref the address calculation
     * procedures now calculate the parast addresses after the procedure
       directives are parsed. This fixes the cdecl parast problem
     * push_addr_param has an extra argument that specifies if cdecl is used
       or not

   Revision 1.14  2002/08/17 22:09:47  florian
     * result type handling in tcgcal.pass_2 overhauled
     * better tnode.dowrite
     * some ppc stuff fixed

   Revision 1.13  2002/08/17 09:23:38  florian
     * first part of procinfo rewrite

   Revision 1.12  2002/08/16 14:24:58  carl
     * issameref() to test if two references are the same (then emit no opcodes)
     + ret_in_reg to replace ret_in_acc
       (fix some register allocation bugs at the same time)
     + save_std_register now has an extra parameter which is the
       usedinproc registers

   Revision 1.11  2002/08/12 15:08:40  carl
     + stab register indexes for powerpc (moved from gdb to cpubase)
     + tprocessor enumeration moved to cpuinfo
     + linker in target_info is now a class
     * many many updates for m68k (will soon start to compile)
     - removed some ifdef or correct them for correct cpu

   Revision 1.10  2002/08/10 17:15:20  jonas
     * register parameters are now LOC_CREGISTER instead of LOC_REGISTER

   Revision 1.9  2002/08/09 07:33:02  florian
     * a couple of interface related fixes

   Revision 1.8  2002/08/06 20:55:21  florian
     * first part of ppc calling conventions fix

   Revision 1.7  2002/08/05 18:27:48  carl
     + more more more documentation
     + first version include/exclude (can't test though, not enough scratch for i386 :()...

   Revision 1.6  2002/07/30 20:50:43  florian
     * the code generator knows now if parameters are in registers

   Revision 1.5  2002/07/26 21:15:39  florian
     * rewrote the system handling

   Revision 1.4  2002/07/20 11:57:55  florian
     * types.pas renamed to defbase.pas because D6 contains a types
       unit so this would conflicts if D6 programms are compiled
     + Willamette/SSE2 instructions to assembler added

   Revision 1.3  2002/07/13 19:38:43  florian
     * some more generic calling stuff fixed

   Revision 1.2  2002/07/13 07:17:15  jonas
     * fixed memory leak reported by  Sergey Korshunoff

   Revision 1.1  2002/07/11 14:41:28  florian
     * start of the new generic parameter handling
}


