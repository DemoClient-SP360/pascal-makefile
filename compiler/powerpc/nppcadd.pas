{
    $Id$
    Copyright (c) 2000-2002 by Florian Klaempfl and Jonas Maebe

    Code generation for add nodes on the PowerPC

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
unit nppcadd;

{$i fpcdefs.inc}

interface

    uses
       node,nadd,cpubase,cginfo;

    type
       tppcaddnode = class(taddnode)
          function pass_1: tnode; override;
          procedure pass_2;override;
         private
          procedure pass_left_and_right;
          procedure load_left_right(cmpop, load_constants: boolean);
          procedure clear_left_right(cmpop: boolean);
          function  getresflags : tresflags;
          procedure emit_compare(unsigned : boolean);
          procedure second_addfloat;
          procedure second_addboolean;
          procedure second_addsmallset;
{$ifdef SUPPORT_MMX}
          procedure second_addmmx;
{$endif SUPPORT_MMX}
          procedure second_add64bit;
       end;

  implementation

    uses
      globtype,systems,
      cutils,verbose,globals,
      symconst,symdef,paramgr,
      aasmbase,aasmtai,aasmcpu,defutil,htypechk,
      cgbase,cpuinfo,pass_1,pass_2,regvars,
      cpupara,
      ncon,nset,
      cga,ncgutil,tgobj,rgobj,rgcpu,cgobj,cg64f32;


{*****************************************************************************
                                  Pass 1
*****************************************************************************}

    function tppcaddnode.pass_1: tnode;
      begin
        if (nodetype in [equaln,unequaln]) and
           is_64bit(left.resulttype.def) then
          begin
            result := nil;
            firstpass(left);
            firstpass(right);
            expectloc := LOC_FLAGS;
            calcregisters(self,2,0,0);
            exit;
          end;
        result := inherited pass_1;
      end;


{*****************************************************************************
                                  Helpers
*****************************************************************************}

    procedure tppcaddnode.pass_left_and_right;
      var
        pushedregs : tmaybesave;
        tmpreg     : tregister;
        pushedfpu  : boolean;
      begin
        { calculate the operator which is more difficult }
        firstcomplex(self);

        { in case of constant put it to the left }
        if (left.nodetype=ordconstn) then
         swapleftright;

        secondpass(left);

        { are too few registers free? }
        maybe_save(exprasmlist,right.registers32,left.location,pushedregs);
        if location.loc=LOC_FPUREGISTER then
          pushedfpu:=maybe_pushfpu(exprasmlist,right.registersfpu,left.location)
        else
          pushedfpu:=false;
        secondpass(right);
        maybe_restore(exprasmlist,left.location,pushedregs);
        if pushedfpu then
          begin
            tmpreg := rg.getregisterfpu(exprasmlist);
            cg.a_loadfpu_loc_reg(exprasmlist,left.location,tmpreg);
            location_reset(left.location,LOC_FPUREGISTER,left.location.size);
            left.location.register := tmpreg;
          end;
      end;


    procedure tppcaddnode.load_left_right(cmpop, load_constants: boolean);

      procedure load_node(var n: tnode);
        begin
          case n.location.loc of
            LOC_REGISTER:
              if not cmpop then
                begin
                  location.register := n.location.register;
                  if is_64bit(n.resulttype.def) then
                    location.registerhigh := n.location.registerhigh;
                end;
            LOC_REFERENCE,LOC_CREFERENCE:
              begin
                location_force_reg(exprasmlist,n.location,def_cgsize(n.resulttype.def),false);
                if not cmpop then
                  begin
                    location.register := n.location.register;
                    if is_64bit(n.resulttype.def) then
                      location.registerhigh := n.location.registerhigh;
                  end;
              end;
            LOC_CONSTANT:
              begin
                if load_constants then
                  begin
                    location_force_reg(exprasmlist,n.location,def_cgsize(n.resulttype.def),false);
                    if not cmpop then
                      location.register := n.location.register;
                      if is_64bit(n.resulttype.def) then
                        location.registerhigh := n.location.registerhigh;
                  end;
              end;
          end;
        end;

      begin
        load_node(left);
        load_node(right);
        if not(cmpop) and
           (location.register.number = NR_NO) then
         begin
           location.register := rg.getregisterint(exprasmlist,OS_INT);
           if is_64bit(resulttype.def) then
             location.registerhigh := rg.getregisterint(exprasmlist,OS_INT);
         end;
      end;


    procedure tppcaddnode.clear_left_right(cmpop: boolean);
      begin
        if (right.location.loc in [LOC_REGISTER,LOC_FPUREGISTER]) and
           (cmpop or
            ((location.register.enum = R_INTREGISTER) and
             (location.register.number <> right.location.register.number)) or
              (location.register.enum <> right.location.register.enum)) then
          begin
            if (right.location.register.enum = R_INTREGISTER) then
              rg.ungetregisterint(exprasmlist,right.location.register)
            else
              rg.ungetregister(exprasmlist,right.location.register);
            if is_64bit(right.resulttype.def) then
              rg.ungetregisterint(exprasmlist,right.location.registerhigh)
          end;
        if (left.location.loc in [LOC_REGISTER,LOC_FPUREGISTER]) and
           (cmpop or
            ((location.register.enum = R_INTREGISTER) and
             (location.register.number <> left.location.register.number)) or
              (location.register.enum <> left.location.register.enum)) then
          begin
            if (left.location.register.enum = R_INTREGISTER) then
              rg.ungetregisterint(exprasmlist,left.location.register)
            else
              rg.ungetregister(exprasmlist,left.location.register);
            if is_64bit(left.resulttype.def) then
              rg.ungetregisterint(exprasmlist,left.location.registerhigh)
          end;
      end;


    function tppcaddnode.getresflags : tresflags;
      begin
        if (left.resulttype.def.deftype <> floatdef) then
          result.cr := R_CR0
        else
          result.cr := R_CR1;
        case nodetype of
          equaln : result.flag:=F_EQ;
          unequaln : result.flag:=F_NE;
        else
          if nf_swaped in flags then
            case nodetype of
              ltn : result.flag:=F_GT;
              lten : result.flag:=F_GE;
              gtn : result.flag:=F_LT;
              gten : result.flag:=F_LE;
            end
          else
            case nodetype of
              ltn : result.flag:=F_LT;
              lten : result.flag:=F_LE;
              gtn : result.flag:=F_GT;
              gten : result.flag:=F_GE;
            end;
        end
      end;


    procedure tppcaddnode.emit_compare(unsigned: boolean);
      var
        op : tasmop;
        tmpreg : tregister;
        useconst : boolean;
      begin
        // get the constant on the right if there is one
        if (left.location.loc = LOC_CONSTANT) then
          swapleftright;
        // can we use an immediate, or do we have to load the
        // constant in a register first?
        if (right.location.loc = LOC_CONSTANT) then
          begin
{$ifdef dummy}
            if (right.location.size in [OS_64,OS_S64]) and (hi(right.location.valueqword)<>0) and ((hi(right.location.valueqword)<>$ffffffff) or unsigned) then
              internalerror(2002080301);
{$endif extdebug}
            if (nodetype in [equaln,unequaln]) then
              if (unsigned and
                  (right.location.value > high(word))) or
                 (not unsigned and
                  (longint(right.location.value) < low(smallint)) or
                   (longint(right.location.value) > high(smallint))) then
                { we can then maybe use a constant in the 'othersigned' case
                 (the sign doesn't matter for // equal/unequal)}
                unsigned := not unsigned;

            if (unsigned and
                ((right.location.value) <= high(word))) or
               (not(unsigned) and
                (longint(right.location.value) >= low(smallint)) and
                (longint(right.location.value) <= high(smallint))) then
               useconst := true
            else
              begin
                useconst := false;
                tmpreg := cg.get_scratch_reg_int(exprasmlist,OS_INT);
                cg.a_load_const_reg(exprasmlist,OS_INT,
                  aword(right.location.value),tmpreg);
               end
          end
        else
          useconst := false;
        location.loc := LOC_FLAGS;
        location.resflags := getresflags;
        if not unsigned then
          if useconst then
            op := A_CMPWI
          else
            op := A_CMPW
        else
          if useconst then
            op := A_CMPLWI
          else
            op := A_CMPLW;

        if (right.location.loc = LOC_CONSTANT) then
          if useconst then
            exprasmlist.concat(taicpu.op_reg_const(op,
              left.location.register,longint(right.location.value)))
          else
            begin
              exprasmlist.concat(taicpu.op_reg_reg(op,
                left.location.register,tmpreg));
              cg.free_scratch_reg(exprasmlist,tmpreg);
            end
        else
          exprasmlist.concat(taicpu.op_reg_reg(op,
            left.location.register,right.location.register));
      end;


{*****************************************************************************
                                AddBoolean
*****************************************************************************}

    procedure tppcaddnode.second_addboolean;
      var
        cgop      : TOpCg;
        cgsize  : TCgSize;
        cmpop,
        isjump  : boolean;
        otl,ofl : tasmlabel;
        pushedregs : tmaybesave;
      begin
        { calculate the operator which is more difficult }
        firstcomplex(self);

        cmpop:=false;
        if (torddef(left.resulttype.def).typ=bool8bit) or
           (torddef(right.resulttype.def).typ=bool8bit) then
         cgsize:=OS_8
        else
          if (torddef(left.resulttype.def).typ=bool16bit) or
             (torddef(right.resulttype.def).typ=bool16bit) then
           cgsize:=OS_16
        else
           cgsize:=OS_32;

        if (cs_full_boolean_eval in aktlocalswitches) or
           (nodetype in [unequaln,ltn,lten,gtn,gten,equaln,xorn]) then
          begin
            if left.nodetype in [ordconstn,realconstn] then
             swapleftright;

            isjump:=(left.location.loc=LOC_JUMP);
            if isjump then
              begin
                 otl:=truelabel;
                 objectlibrary.getlabel(truelabel);
                 ofl:=falselabel;
                 objectlibrary.getlabel(falselabel);
              end;
            secondpass(left);
            if left.location.loc in [LOC_FLAGS,LOC_JUMP] then
             location_force_reg(exprasmlist,left.location,cgsize,false);
            if isjump then
             begin
               truelabel:=otl;
               falselabel:=ofl;
             end;

            maybe_save(exprasmlist,right.registers32,left.location,pushedregs);
            isjump:=(right.location.loc=LOC_JUMP);
            if isjump then
              begin
                 otl:=truelabel;
                 objectlibrary.getlabel(truelabel);
                 ofl:=falselabel;
                 objectlibrary.getlabel(falselabel);
              end;
            secondpass(right);
            maybe_restore(exprasmlist,left.location,pushedregs);
            if right.location.loc in [LOC_FLAGS,LOC_JUMP] then
             location_force_reg(exprasmlist,right.location,cgsize,false);
            if isjump then
             begin
               truelabel:=otl;
               falselabel:=ofl;
             end;

            cmpop := nodetype in [ltn,lten,gtn,gten,equaln,unequaln];

            { set result location }
            if not cmpop then
              location_reset(location,LOC_REGISTER,def_cgsize(resulttype.def))
             else
              location_reset(location,LOC_FLAGS,OS_NO);

            load_left_right(cmpop,false);

            if (left.location.loc = LOC_CONSTANT) then
              swapleftright;

            { compare the }
            case nodetype of
              ltn,lten,gtn,gten,
              equaln,unequaln :
                begin
                  if (right.location.loc <> LOC_CONSTANT) then
                    exprasmlist.concat(taicpu.op_reg_reg(A_CMPLW,
                      left.location.register,right.location.register))
                  else
                    exprasmlist.concat(taicpu.op_reg_const(A_CMPLWI,
                      left.location.register,longint(right.location.value)));
                  location.resflags := getresflags;
                end;
              else
                begin
                  case nodetype of
                    xorn :
                      cgop:=OP_XOR;
                    orn :
                      cgop:=OP_OR;
                    andn :
                      cgop:=OP_AND;
                    else
                      internalerror(200203247);
                  end;

                  if right.location.loc <> LOC_CONSTANT then
                    cg.a_op_reg_reg_reg(exprasmlist,cgop,OS_INT,
                      left.location.register,right.location.register,
                      location.register)
                  else
                    cg.a_op_const_reg_reg(exprasmlist,cgop,OS_INT,
                      aword(right.location.value),left.location.register,
                      location.register);
                end;
            end;
         end
        else
         begin
           // just to make sure we free the right registers
           cmpop := true;
           case nodetype of
             andn,
             orn :
               begin
                 location_reset(location,LOC_JUMP,OS_NO);
                 case nodetype of
                   andn :
                     begin
                        otl:=truelabel;
                        objectlibrary.getlabel(truelabel);
                        secondpass(left);
                        maketojumpbool(exprasmlist,left,lr_load_regvars);
                        cg.a_label(exprasmlist,truelabel);
                        truelabel:=otl;
                     end;
                   orn :
                     begin
                        ofl:=falselabel;
                        objectlibrary.getlabel(falselabel);
                        secondpass(left);
                        maketojumpbool(exprasmlist,left,lr_load_regvars);
                        cg.a_label(exprasmlist,falselabel);
                        falselabel:=ofl;
                     end;
                   else
                     CGMessage(type_e_mismatch);
                 end;
                 secondpass(right);
                 maketojumpbool(exprasmlist,right,lr_load_regvars);
               end;
           end;
         end;
        clear_left_right(cmpop);
      end;


{*****************************************************************************
                                AddFloat
*****************************************************************************}

    procedure tppcaddnode.second_addfloat;
      var
        reg   : tregister;
        op    : TAsmOp;
        cmpop : boolean;
        r     : Tregister;

      procedure location_force_fpureg(var l: tlocation);
        begin
          if not(l.loc in [LOC_FPUREGISTER,LOC_CFPUREGISTER]) then
            begin
              reg := rg.getregisterfpu(exprasmlist);
              cg.a_loadfpu_loc_reg(exprasmlist,l,reg);
              location_freetemp(exprasmlist,l);
              location_release(exprasmlist,l);
              location_reset(l,LOC_FPUREGISTER,l.size);
              l.register := reg;
            end;
        end;

      begin
        pass_left_and_right;

        cmpop:=false;
        case nodetype of
          addn :
            op:=A_FADD;
          muln :
            op:=A_FMUL;
          subn :
            op:=A_FSUB;
          slashn :
            op:=A_FDIV;
          ltn,lten,gtn,gten,
          equaln,unequaln :
            begin
              op:=A_FCMPO;
              cmpop:=true;
            end;
          else
            CGMessage(type_e_mismatch);
        end;

        // get the operands in the correct order, there are no special cases
        // here, everything is register-based
        if nf_swaped in flags then
          swapleftright;

        // put both operands in a register
        location_force_fpureg(right.location);
        location_force_fpureg(left.location);

        // initialize de result
        if not cmpop then
          begin
            location_reset(location,LOC_FPUREGISTER,def_cgsize(resulttype.def));
            if left.location.loc = LOC_FPUREGISTER then
              location.register := left.location.register
            else if right.location.loc = LOC_FPUREGISTER then
              location.register := right.location.register
            else
              location.register := rg.getregisterfpu(exprasmlist);
          end
        else
         begin
           location_reset(location,LOC_FLAGS,OS_NO);
           location.resflags := getresflags;
         end;

        // emit the actual operation
        if not cmpop then
          begin
            exprasmlist.concat(taicpu.op_reg_reg_reg(op,
              location.register,left.location.register,
              right.location.register))
          end
        else
          begin
            r.enum:=location.resflags.cr;
            exprasmlist.concat(taicpu.op_reg_reg_reg(op,
              r,left.location.register,right.location.register))
          end;

        clear_left_right(cmpop);
      end;

{*****************************************************************************
                                AddSmallSet
*****************************************************************************}

    procedure tppcaddnode.second_addsmallset;
      var
        cgop   : TOpCg;
        tmpreg : tregister;
        opdone,
        cmpop  : boolean;
      begin
        pass_left_and_right;

        { when a setdef is passed, it has to be a smallset }
        if ((left.resulttype.def.deftype=setdef) and
            (tsetdef(left.resulttype.def).settype<>smallset)) or
           ((right.resulttype.def.deftype=setdef) and
            (tsetdef(right.resulttype.def).settype<>smallset)) then
         internalerror(200203301);

        opdone := false;
        cmpop:=nodetype in [equaln,unequaln,lten,gten];

        { set result location }
        if not cmpop then
          location_reset(location,LOC_REGISTER,def_cgsize(resulttype.def))
         else
          location_reset(location,LOC_FLAGS,OS_NO);

        load_left_right(cmpop,false);

        if not(cmpop) and
           (location.register.number = NR_NO) then
          location.register := rg.getregisterint(exprasmlist,OS_INT);

        case nodetype of
          addn :
            begin
              if (nf_swaped in flags) and (left.nodetype=setelementn) then
                swapleftright;
              { are we adding set elements ? }
              if right.nodetype=setelementn then
                begin
                  { no range support for smallsets! }
                  if assigned(tsetelementnode(right).right) then
                   internalerror(43244);
                  if (right.location.loc = LOC_CONSTANT) then
                    cg.a_op_const_reg_reg(exprasmlist,OP_OR,OS_INT,
                      aword(1 shl aword(right.location.value)),
                      left.location.register,location.register)
                  else
                    begin
                      tmpreg := cg.get_scratch_reg_int(exprasmlist,OS_INT);
                      cg.a_load_const_reg(exprasmlist,OS_INT,1,tmpreg);
                      cg.a_op_reg_reg(exprasmlist,OP_SHL,OS_INT,
                        right.location.register,tmpreg);
                      if left.location.loc <> LOC_CONSTANT then
                        cg.a_op_reg_reg_reg(exprasmlist,OP_OR,OS_INT,tmpreg,
                          left.location.register,location.register)
                      else
                        cg.a_op_const_reg_reg(exprasmlist,OP_OR,OS_INT,
                          aword(left.location.value),tmpreg,location.register);
                      cg.free_scratch_reg(exprasmlist,tmpreg);
                    end;
                  opdone := true;
                end
              else
                cgop := OP_OR;
            end;
          symdifn :
            cgop:=OP_XOR;
          muln :
            cgop:=OP_AND;
          subn :
            begin
              cgop:=OP_AND;
              if (not(nf_swaped in flags)) then
                if (right.location.loc=LOC_CONSTANT) then
                  right.location.value := not(right.location.value)
                else
                  opdone := true
              else if (left.location.loc=LOC_CONSTANT) then
                left.location.value := not(left.location.value)
              else
                 begin
                   swapleftright;
                   opdone := true;
                 end;
              if opdone then
                begin
                  if left.location.loc = LOC_CONSTANT then
                    begin
                      tmpreg := cg.get_scratch_reg_int(exprasmlist,OS_INT);
                      cg.a_load_const_reg(exprasmlist,OS_INT,
                        aword(left.location.value),tmpreg);
                      exprasmlist.concat(taicpu.op_reg_reg_reg(A_ANDC,
                        location.register,tmpreg,right.location.register));
                      cg.free_scratch_reg(exprasmlist,tmpreg);
                    end
                  else
                    exprasmlist.concat(taicpu.op_reg_reg_reg(A_ANDC,
                      location.register,left.location.register,
                      right.location.register));
                end;
            end;
          equaln,
          unequaln :
            begin
              emit_compare(true);
              opdone := true;
            end;
          lten,gten:
            begin
              If (not(nf_swaped in flags) and
                  (nodetype = lten)) or
                 ((nf_swaped in flags) and
                  (nodetype = gten)) then
                swapleftright;
              // now we have to check whether left >= right
              tmpreg := cg.get_scratch_reg_int(exprasmlist,OS_INT);
              if left.location.loc = LOC_CONSTANT then
                begin
                  cg.a_op_const_reg_reg(exprasmlist,OP_AND,OS_INT,
                    not(left.location.value),right.location.register,tmpreg);
                  exprasmlist.concat(taicpu.op_reg_const(A_CMPWI,tmpreg,0));
                  // the two instructions above should be folded together by
                  // the peepholeoptimizer
                end
              else
                begin
                  if right.location.loc = LOC_CONSTANT then
                    begin
                      cg.a_load_const_reg(exprasmlist,OS_INT,
                        aword(right.location.value),tmpreg);
                      exprasmlist.concat(taicpu.op_reg_reg_reg(A_ANDC_,tmpreg,
                        tmpreg,left.location.register));
                    end
                  else
                    exprasmlist.concat(taicpu.op_reg_reg_reg(A_ANDC_,tmpreg,
                      right.location.register,left.location.register));
                end;
              cg.free_scratch_reg(exprasmlist,tmpreg);
              location.resflags.cr := R_CR0;
              location.resflags.flag := F_EQ;
              opdone := true;
            end;
          else
            internalerror(2002072701);
        end;

        if not opdone then
          begin
            // these are all commutative operations
            if (left.location.loc = LOC_CONSTANT) then
              swapleftright;
            if (right.location.loc = LOC_CONSTANT) then
              cg.a_op_const_reg_reg(exprasmlist,cgop,OS_INT,
                aword(right.location.value),left.location.register,
                location.register)
            else
              cg.a_op_reg_reg_reg(exprasmlist,cgop,OS_INT,
                right.location.register,left.location.register,
                location.register);
          end;

        clear_left_right(cmpop);
      end;

{*****************************************************************************
                                Add64bit
*****************************************************************************}

    procedure tppcaddnode.second_add64bit;
      var
        op         : TOpCG;
        op1,op2    : TAsmOp;
        hl4        : tasmlabel;
        cmpop,
        unsigned   : boolean;
        r          : Tregister;


      procedure emit_cmp64_hi;

        var
          oldleft, oldright: tlocation;
        begin
          // put the high part of the location in the low part
          location_copy(oldleft,left.location);
          location_copy(oldright,right.location);
          if left.location.loc = LOC_CONSTANT then
            left.location.valueqword := left.location.valueqword shr 32
          else
            left.location.registerlow := left.location.registerhigh;
          if right.location.loc = LOC_CONSTANT then
            right.location.valueqword := right.location.valueqword shr 32
          else
            right.location.registerlow := right.location.registerhigh;

          // and call the normal emit_compare
          emit_compare(unsigned);
          location_copy(left.location,oldleft);
          location_copy(right.location,oldright);
        end;


      procedure emit_cmp64_lo;

        begin
          emit_compare(true);
        end;


      procedure firstjmp64bitcmp;

        var
          oldnodetype: tnodetype;
        begin
           load_all_regvars(exprasmlist);
           { the jump the sequence is a little bit hairy }
           case nodetype of
              ltn,gtn:
                begin
                   cg.a_jmp_flags(exprasmlist,getresflags,truelabel);
                   { cheat a little bit for the negative test }
                   toggleflag(nf_swaped);
                   cg.a_jmp_flags(exprasmlist,getresflags,falselabel);
                   toggleflag(nf_swaped);
                end;
              lten,gten:
                begin
                   oldnodetype:=nodetype;
                   if nodetype=lten then
                     nodetype:=ltn
                   else
                     nodetype:=gtn;
                   cg.a_jmp_flags(exprasmlist,getresflags,truelabel);
                   { cheat for the negative test }
                   if nodetype=ltn then
                     nodetype:=gtn
                   else
                     nodetype:=ltn;
                   cg.a_jmp_flags(exprasmlist,getresflags,falselabel);
                   nodetype:=oldnodetype;
                end;
              equaln:
                begin
                  nodetype := unequaln;
                  cg.a_jmp_flags(exprasmlist,getresflags,falselabel);
                  nodetype := equaln;
                end;
              unequaln:
                begin
                  cg.a_jmp_flags(exprasmlist,getresflags,truelabel);
                end;
           end;
        end;


      procedure secondjmp64bitcmp;

        begin
           { the jump the sequence is a little bit hairy }
           case nodetype of
              ltn,gtn,lten,gten:
                begin
                   { the comparison of the low dword always has }
                   { to be always unsigned!                     }
                   cg.a_jmp_flags(exprasmlist,getresflags,truelabel);
                   cg.a_jmp_always(exprasmlist,falselabel);
                end;
              equaln:
                begin
                   nodetype := unequaln;
                   cg.a_jmp_flags(exprasmlist,getresflags,falselabel);
                   cg.a_jmp_always(exprasmlist,truelabel);
                   nodetype := equaln;
                end;
              unequaln:
                begin
                   cg.a_jmp_flags(exprasmlist,getresflags,truelabel);
                   cg.a_jmp_always(exprasmlist,falselabel);
                end;
           end;
        end;


    var
      tempreg64: tregister64;

      begin
        firstcomplex(self);

        pass_left_and_right;

        cmpop:=false;
        unsigned:=((left.resulttype.def.deftype=orddef) and
                   (torddef(left.resulttype.def).typ=u64bit)) or
                  ((right.resulttype.def.deftype=orddef) and
                   (torddef(right.resulttype.def).typ=u64bit));
        case nodetype of
          addn :
            begin
              op:=OP_ADD;
            end;
          subn :
            begin
              op:=OP_SUB;
            end;
          ltn,lten,
          gtn,gten,
          equaln,unequaln:
            begin
              op:=OP_NONE;
              cmpop:=true;
            end;
          xorn:
            op:=OP_XOR;
          orn:
            op:=OP_OR;
          andn:
            op:=OP_AND;
          muln:
            begin
              { should be handled in pass_1 (JM) }
              internalerror(200109051);
            end;
          else
            internalerror(2002072705);
        end;

        if not cmpop then
          location_reset(location,LOC_REGISTER,def_cgsize(resulttype.def));

        load_left_right(cmpop,(cs_check_overflow in aktlocalswitches) and
            (nodetype in [addn,subn]));

        if not(cs_check_overflow in aktlocalswitches) or
           not(nodetype in [addn,subn]) then
          begin
            case nodetype of
              ltn,lten,
              gtn,gten:
                begin
                  emit_cmp64_hi;
                  firstjmp64bitcmp;
                  emit_cmp64_lo;
                  secondjmp64bitcmp;
                end;
              equaln,unequaln:
                begin
                  // instead of doing a complicated compare, do
                  // (left.hi xor right.hi) or (left.lo xor right.lo)
                  // (somewhate optimized so that no superfluous 'mr's are
                  //  generated)
                  if (left.location.loc = LOC_CONSTANT) then
                    swapleftright;
                  if (right.location.loc = LOC_CONSTANT) then
                    begin
                      if left.location.loc = LOC_REGISTER then
                        begin
                          tempreg64.reglo := left.location.registerlow;
                          tempreg64.reghi := left.location.registerhigh;
                        end
                      else
                        begin
                          if (aword(right.location.valueqword) <> 0) then
                            tempreg64.reglo := cg.get_scratch_reg_int(exprasmlist,OS_INT)
                          else
                            tempreg64.reglo := left.location.registerlow;
                          if ((right.location.valueqword shr 32) <> 0) then
                            tempreg64.reghi := cg.get_scratch_reg_int(exprasmlist,OS_INT)
                          else
                            tempreg64.reghi := left.location.registerhigh;
                        end;

                      if (aword(right.location.valueqword) <> 0) then
                        { negative values can be handled using SUB, }
                        { positive values < 65535 using XOR.        }
                        if (longint(right.location.valueqword) >= -32767) and
                           (longint(right.location.valueqword) < 0) then
                          cg.a_op_const_reg_reg(exprasmlist,OP_SUB,OS_INT,
                            aword(right.location.valueqword),
                            left.location.registerlow,tempreg64.reglo)
                        else
                          cg.a_op_const_reg_reg(exprasmlist,OP_XOR,OS_INT,
                            aword(right.location.valueqword),
                            left.location.registerlow,tempreg64.reglo);

                      if ((right.location.valueqword shr 32) <> 0) then
                        if (longint(right.location.valueqword shr 32) >= -32767) and
                           (longint(right.location.valueqword shr 32) < 0) then
                          cg.a_op_const_reg_reg(exprasmlist,OP_SUB,OS_INT,
                            aword(right.location.valueqword shr 32),
                            left.location.registerhigh,tempreg64.reghi)
                        else
                          cg.a_op_const_reg_reg(exprasmlist,OP_XOR,OS_INT,
                            aword(right.location.valueqword shr 32),
                            left.location.registerhigh,tempreg64.reghi);
                    end
                  else
                    begin
                       tempreg64.reglo := cg.get_scratch_reg_int(exprasmlist,OS_INT);
                       tempreg64.reghi := cg.get_scratch_reg_int(exprasmlist,OS_INT);
                       cg64.a_op64_reg_reg_reg(exprasmlist,OP_XOR,
                         left.location.register64,right.location.register64,
                         tempreg64);
                    end;

                  r.enum:=R_INTREGISTER;
                  r.number:=NR_R0;
                  cg.a_reg_alloc(exprasmlist,r);
                  exprasmlist.concat(taicpu.op_reg_reg_reg(A_OR_,r,
                    tempreg64.reglo,tempreg64.reghi));
                  cg.a_reg_dealloc(exprasmlist,r);
                  if (tempreg64.reglo.number <> left.location.registerlow.number) then
                    cg.free_scratch_reg(exprasmlist,tempreg64.reglo);
                  if (tempreg64.reghi.number <> left.location.registerhigh.number) then
                    cg.free_scratch_reg(exprasmlist,tempreg64.reghi);

                  location_reset(location,LOC_FLAGS,OS_NO);
                  location.resflags := getresflags;
                end;
              xorn,orn,andn,addn:
                begin
                  if (location.registerlow.number = NR_NO) then
                    begin
                      location.registerlow := rg.getregisterint(exprasmlist,OS_INT);
                      location.registerhigh := rg.getregisterint(exprasmlist,OS_INT);
                    end;

                  if (left.location.loc = LOC_CONSTANT) then
                    swapleftright;
                  if (right.location.loc = LOC_CONSTANT) then
                    cg64.a_op64_const_reg_reg(exprasmlist,op,right.location.valueqword,
                      left.location.register64,location.register64)
                  else
                    cg64.a_op64_reg_reg_reg(exprasmlist,op,right.location.register64,
                      left.location.register64,location.register64);
                end;
              subn:
                begin
                  if (nf_swaped in flags) then
                    swapleftright;

                  if left.location.loc <> LOC_CONSTANT then
                    begin
                      if (location.registerlow.number = NR_NO) then
                        begin
                         location.registerlow := rg.getregisterint(exprasmlist,OS_INT);
                         location.registerhigh := rg.getregisterint(exprasmlist,OS_INT);
                      end;
                      if right.location.loc <> LOC_CONSTANT then
                        // reg64 - reg64
                        cg64.a_op64_reg_reg_reg(exprasmlist,OP_SUB,
                          right.location.register64,left.location.register64,
                          location.register64)
                      else
                        // reg64 - const64
                        cg64.a_op64_const_reg_reg(exprasmlist,OP_SUB,
                          right.location.valueqword,left.location.register64,
                          location.register64)
                    end
                  else if ((left.location.valueqword shr 32) = 0) then
                    begin
                      if (location.registerlow.number = NR_NO) then
                        begin
                         location.registerlow := rg.getregisterint(exprasmlist,OS_INT);
                         location.registerhigh := rg.getregisterint(exprasmlist,OS_INT);
                      end;
                      if (int64(left.location.valueqword) >= low(smallint)) and
                         (int64(left.location.valueqword) <= high(smallint)) then
                        begin
                          // consts16 - reg64
                          exprasmlist.concat(taicpu.op_reg_reg_const(A_SUBFIC,
                            location.registerlow,right.location.registerlow,
                            aword(left.location.value)));
                        end
                      else
                        begin
                          // const32 - reg64
                          location_force_reg(exprasmlist,left.location, 
                            OS_32,true);
                          exprasmlist.concat(taicpu.op_reg_reg_reg(A_SUBC,
                            location.registerlow,left.location.registerlow,
                            right.location.registerlow));
                        end;
                      exprasmlist.concat(taicpu.op_reg_reg(A_SUBFZE,
                        location.registerhigh,right.location.registerhigh));
                    end
                  else if (aword(left.location.valueqword) = 0) then
                    begin
                      // (const32 shl 32) - reg64
                      if (location.registerlow.number = NR_NO) then
                        begin
                         location.registerlow := rg.getregisterint(exprasmlist,OS_INT);
                         location.registerhigh := rg.getregisterint(exprasmlist,OS_INT);
                      end;
                      exprasmlist.concat(taicpu.op_reg_reg_const(A_SUBFIC,
                        location.registerlow,right.location.registerlow,0));
                      left.location.valueqword := left.location.valueqword shr 32;
                      location_force_reg(exprasmlist,left.location,OS_32,true);
                      exprasmlist.concat(taicpu.op_reg_reg_reg(A_SUBFE,
                        location.registerhigh,right.location.registerhigh,
                        left.location.register));
                    end
                  else
                    begin
                      // const64 - reg64
                      location_force_reg(exprasmlist,left.location,
                        def_cgsize(left.resulttype.def),false);
                      if (left.location.loc = LOC_REGISTER) then
                        location.register64 := left.location.register64
                      else if (location.registerlow.number = NR_NO) then
                        begin
                         location.registerlow := rg.getregisterint(exprasmlist,OS_INT);
                         location.registerhigh := rg.getregisterint(exprasmlist,OS_INT);
                        end;
                      cg64.a_op64_reg_reg_reg(exprasmlist,OP_SUB,
                        right.location.register64,left.location.register64,
                        location.register64);
                     end;
                end;
              else
                internalerror(2002072803);
            end;
          end
        else
          begin
            case nodetype of
              addn:
                begin
                  op1 := A_ADDC;
                  op2 := A_ADDEO_;
                end;
              subn:
                begin
                  op1 := A_SUBC;
                  op2 := A_SUBFEO_;
                end;
              else
                internalerror(2002072806);
            end;
            exprasmlist.concat(taicpu.op_reg_reg_reg(op1,location.registerlow,
              left.location.registerlow,right.location.registerlow));
            exprasmlist.concat(taicpu.op_reg_reg_reg(op2,location.registerhigh,
              right.location.registerhigh,left.location.registerhigh));
            cg.g_overflowcheck(exprasmlist,self);
          end;

        { set result location }
        { (emit_compare sets it to LOC_FLAGS for compares, so set the }
        {  real location only now) (JM)                               }
        if cmpop and
           not(nodetype in [equaln,unequaln]) then
          location_reset(location,LOC_JUMP,OS_NO);

        clear_left_right(cmpop);

      end;


{*****************************************************************************
                                AddMMX
*****************************************************************************}

{$ifdef SUPPORT_MMX}
    procedure ti386addnode.second_addmmx;
      var
        op         : TAsmOp;
        cmpop      : boolean;
        mmxbase    : tmmxtype;
        hregister  : tregister;
      begin
        pass_left_and_right;

        cmpop:=false;
        mmxbase:=mmx_type(left.resulttype.def);
        case nodetype of
          addn :
            begin
              if (cs_mmx_saturation in aktlocalswitches) then
                begin
                   case mmxbase of
                      mmxs8bit:
                        op:=A_PADDSB;
                      mmxu8bit:
                        op:=A_PADDUSB;
                      mmxs16bit,mmxfixed16:
                        op:=A_PADDSB;
                      mmxu16bit:
                        op:=A_PADDUSW;
                   end;
                end
              else
                begin
                   case mmxbase of
                      mmxs8bit,mmxu8bit:
                        op:=A_PADDB;
                      mmxs16bit,mmxu16bit,mmxfixed16:
                        op:=A_PADDW;
                      mmxs32bit,mmxu32bit:
                        op:=A_PADDD;
                   end;
                end;
            end;
          muln :
            begin
               case mmxbase of
                  mmxs16bit,mmxu16bit:
                    op:=A_PMULLW;
                  mmxfixed16:
                    op:=A_PMULHW;
               end;
            end;
          subn :
            begin
              if (cs_mmx_saturation in aktlocalswitches) then
                begin
                   case mmxbase of
                      mmxs8bit:
                        op:=A_PSUBSB;
                      mmxu8bit:
                        op:=A_PSUBUSB;
                      mmxs16bit,mmxfixed16:
                        op:=A_PSUBSB;
                      mmxu16bit:
                        op:=A_PSUBUSW;
                   end;
                end
              else
                begin
                   case mmxbase of
                      mmxs8bit,mmxu8bit:
                        op:=A_PSUBB;
                      mmxs16bit,mmxu16bit,mmxfixed16:
                        op:=A_PSUBW;
                      mmxs32bit,mmxu32bit:
                        op:=A_PSUBD;
                   end;
                end;
            end;
          xorn:
            op:=A_PXOR;
          orn:
            op:=A_POR;
          andn:
            op:=A_PAND;
          else
            CGMessage(type_e_mismatch);
        end;

        { left and right no register?  }
        { then one must be demanded    }
        if (left.location.loc<>LOC_MMXREGISTER) then
         begin
           if (right.location.loc=LOC_MMXREGISTER) then
            begin
              location_swap(left.location,right.location);
              toggleflag(nf_swaped);
            end
           else
            begin
              { register variable ? }
              if (left.location.loc=LOC_CMMXREGISTER) then
               begin
                 hregister:=rg.getregistermm(exprasmlist);
                 emit_reg_reg(A_MOVQ,S_NO,left.location.register,hregister);
               end
              else
               begin
                 if not(left.location.loc in [LOC_REFERENCE,LOC_CREFERENCE]) then
                  internalerror(200203245);

                 location_release(exprasmlist,left.location);

                 hregister:=rg.getregistermm(exprasmlist);
                 emit_ref_reg(A_MOVQ,S_NO,left.location.reference,hregister);
               end;

              location_reset(left.location,LOC_MMXREGISTER,OS_NO);
              left.location.register:=hregister;
            end;
         end;

        { at this point, left.location.loc should be LOC_MMXREGISTER }
        if right.location.loc<>LOC_MMXREGISTER then
         begin
           if (nodetype=subn) and (nf_swaped in flags) then
            begin
              if right.location.loc=LOC_CMMXREGISTER then
               begin
                 emit_reg_reg(A_MOVQ,S_NO,right.location.register,R_MM7);
                 emit_reg_reg(op,S_NO,left.location.register,R_MM7);
                 emit_reg_reg(A_MOVQ,S_NO,R_MM7,left.location.register);
               end
              else
               begin
                 if not(left.location.loc in [LOC_REFERENCE,LOC_CREFERENCE]) then
                  internalerror(200203247);
                 emit_ref_reg(A_MOVQ,S_NO,right.location.reference,R_MM7);
                 emit_reg_reg(op,S_NO,left.location.register,R_MM7);
                 emit_reg_reg(A_MOVQ,S_NO,R_MM7,left.location.register);
                 location_release(exprasmlist,right.location);
               end;
            end
           else
            begin
              if (right.location.loc=LOC_CMMXREGISTER) then
               begin
                 emit_reg_reg(op,S_NO,right.location.register,left.location.register);
               end
              else
               begin
                 if not(right.location.loc in [LOC_REFERENCE,LOC_CREFERENCE]) then
                  internalerror(200203246);
                 emit_ref_reg(op,S_NO,right.location.reference,left.location.register);
                 location_release(exprasmlist,right.location);
               end;
            end;
          end
        else
          begin
            { right.location=LOC_MMXREGISTER }
            if (nodetype=subn) and (nf_swaped in flags) then
             begin
               emit_reg_reg(op,S_NO,left.location.register,right.location.register);
               location_swap(left.location,right.location);
               toggleflag(nf_swaped);
             end
            else
             begin
               emit_reg_reg(op,S_NO,right.location.register,left.location.register);
             end;
          end;

        location_freetemp(exprasmlist,right.location);
        location_release(exprasmlist,right.location);
        if cmpop then
         begin
           location_freetemp(exprasmlist,left.location);
           location_release(exprasmlist,left.location);
         end;
        set_result_location(cmpop,true);
      end;
{$endif SUPPORT_MMX}


{*****************************************************************************
                                pass_2
*****************************************************************************}

    procedure tppcaddnode.pass_2;
    { is also being used for xor, and "mul", "sub, or and comparative }
    { operators                                                }
      var
         cmpop      : boolean;
         cgop       : topcg;
         op         : tasmop;
         tmpreg     : tregister;

         { true, if unsigned types are compared }
         unsigned : boolean;

         regstopush: tregisterset;

      begin
         { to make it more readable, string and set (not smallset!) have their
           own procedures }
         case left.resulttype.def.deftype of
           orddef :
             begin
               { handling boolean expressions }
               if is_boolean(left.resulttype.def) and
                  is_boolean(right.resulttype.def) then
                 begin
                   second_addboolean;
                   exit;
                 end
               { 64bit operations }
               else if is_64bit(left.resulttype.def) then
                 begin
                   second_add64bit;
                   exit;
                 end;
             end;
           stringdef :
             begin
               internalerror(2002072402);
               exit;
             end;
           setdef :
             begin
               { normalsets are already handled in pass1 }
               if (tsetdef(left.resulttype.def).settype<>smallset) then
                internalerror(200109041);
               second_addsmallset;
               exit;
             end;
           arraydef :
             begin
{$ifdef SUPPORT_MMX}
               if is_mmx_able_array(left.resulttype.def) then
                begin
                  second_addmmx;
                  exit;
                end;
{$endif SUPPORT_MMX}
             end;
           floatdef :
             begin
               second_addfloat;
               exit;
             end;
         end;

         { defaults }
         cmpop:=nodetype in [ltn,lten,gtn,gten,equaln,unequaln];
         unsigned:=not(is_signed(left.resulttype.def)) or
                   not(is_signed(right.resulttype.def));

         pass_left_and_right;

         { Convert flags to register first }
         { can any of these things be in the flags actually?? (JM) }

         if (left.location.loc = LOC_FLAGS) or
            (right.location.loc = LOC_FLAGS) then
           internalerror(2002072602);

         { set result location }
         if not cmpop then
           location_reset(location,LOC_REGISTER,def_cgsize(resulttype.def))
          else
           location_reset(location,LOC_FLAGS,OS_NO);

         load_left_right(cmpop, (cs_check_overflow in aktlocalswitches) and
            (nodetype in [addn,subn,muln]));

         if (location.register.number = NR_NO) and
            not(cmpop) then
           location.register := rg.getregisterint(exprasmlist,OS_INT);

         if not(cs_check_overflow in aktlocalswitches) or
            (cmpop) or
            (nodetype in [orn,andn,xorn]) then
           begin
             case nodetype of
               addn, muln, xorn, orn, andn:
                 begin
                   case nodetype of
                     addn:
                       cgop := OP_ADD;
                     muln:
                       if unsigned then
                         cgop := OP_MUL
                       else
                         cgop := OP_IMUL;
                     xorn:
                       cgop := OP_XOR;
                     orn:
                       cgop := OP_OR;
                     andn:
                       cgop := OP_AND;
                   end;
                   if (left.location.loc = LOC_CONSTANT) then
                     swapleftright;
                   if (right.location.loc <> LOC_CONSTANT) then
                     cg.a_op_reg_reg_reg(exprasmlist,cgop,OS_INT,
                       left.location.register,right.location.register,
                       location.register)
                   else
                     cg.a_op_const_reg_reg(exprasmlist,cgop,OS_INT,
                       aword(right.location.value),left.location.register,
                     location.register);
                 end;
               subn:
                 begin
                   if (nf_swaped in flags) then
                     swapleftright;
                   if left.location.loc <> LOC_CONSTANT then
                     if right.location.loc <> LOC_CONSTANT then
                       cg.a_op_reg_reg_reg(exprasmlist,OP_SUB,OS_INT,
                         right.location.register,left.location.register,
                         location.register)
                     else
                       cg.a_op_const_reg_reg(exprasmlist,OP_SUB,OS_INT,
                         aword(right.location.value),left.location.register,
                         location.register)
                   else
                     if (longint(left.location.value) >= low(smallint)) and
                        (longint(left.location.value) <= high(smallint)) then
                       begin
                         exprasmlist.concat(taicpu.op_reg_reg_const(A_SUBFIC,
                           location.register,right.location.register,
                           longint(left.location.value)));
                       end
                     else
                       begin
                         tmpreg := cg.get_scratch_reg_int(exprasmlist,OS_INT);
                         cg.a_load_const_reg(exprasmlist,OS_INT,
                           aword(left.location.value),tmpreg);
                         cg.a_op_reg_reg_reg(exprasmlist,OP_SUB,OS_INT,
                           right.location.register,tmpreg,location.register);
                         cg.free_scratch_reg(exprasmlist,tmpreg);
                       end;
                 end;
               ltn,lten,gtn,gten,equaln,unequaln :
                 begin
                   emit_compare(unsigned);
                 end;
             end;
           end
         else
           // overflow checking is on and we have an addn, subn or muln
           begin
             case nodetype of
               addn:
                 op := A_ADDO_;
               subn:
                 op := A_SUBO_;
               muln:
                  op := A_MULLWO_;
               else
                 internalerror(2002072601);
             end;
             exprasmlist.concat(taicpu.op_reg_reg_reg(op,location.register,
               left.location.register,right.location.register));
             cg.g_overflowcheck(exprasmlist,self);
           end;

         clear_left_right(cmpop);
      end;

begin
   caddnode:=tppcaddnode;
end.
{
  $Log$
  Revision 1.30  2003-05-30 18:49:14  jonas
    * fixed problem where sometimes no register was allocated for the result
      of an addnode when using regvars

  Revision 1.29  2003/04/27 11:55:34  jonas
    * fixed overflow checking form of 64bit add instruction

  Revision 1.28  2003/04/27 11:06:06  jonas
    * fixed 64bit "const - reg/ref" bugs

  Revision 1.27  2003/04/24 22:29:58  florian
    * fixed a lot of PowerPC related stuff

  Revision 1.26  2003/04/23 22:18:01  peter
    * fixes to get rtl compiled

  Revision 1.25  2003/04/23 12:35:35  florian
    * fixed several issues with powerpc
    + applied a patch from Jonas for nested function calls (PowerPC only)
    * ...

  Revision 1.24  2003/03/11 21:46:24  jonas
    * lots of new regallocator fixes, both in generic and ppc-specific code
      (ppc compiler still can't compile the linux system unit though)

  Revision 1.23  2003/03/10 18:11:41  olle
    * changed ungetregister to ungetregisterint in tppcaddnode.clear_left_right

  Revision 1.22  2003/02/19 22:00:16  daniel
    * Code generator converted to new register notation
    - Horribily outdated todo.txt removed

  Revision 1.21  2003/01/08 18:43:58  daniel
   * Tregister changed into a record

  Revision 1.20  2002/11/25 17:43:27  peter
    * splitted defbase in defutil,symutil,defcmp
    * merged isconvertable and is_equal into compare_defs(_ext)
    * made operator search faster by walking the list only once

  Revision 1.19  2002/10/21 18:08:05  jonas
    * some range errors fixed

  Revision 1.18  2002/09/08 14:14:49  jonas
    * more optimizations for 64bit compares

  Revision 1.17  2002/09/07 22:15:48  jonas
    * fixed optimized 64 compares

  Revision 1.16  2002/09/04 19:42:45  jonas
    * fixed bugs in 64bit operations (registers weren't always allocated for
      the result)
    * optimized 'const64 - reg64/mem64'
    * optimized equaln/unequaln with 64bit values (change them to
      '(left.hi xor right.hi) or (left.lo xor right.lo)' so there are less
      branches and the result can be returned in the flags this way. Could
      be done for the i386 too probably.

  Revision 1.15  2002/08/31 21:30:46  florian
    * fixed several problems caused by Jonas' commit :)

  Revision 1.14  2002/08/31 19:26:20  jonas
    * fixed 64bit comparisons

  Revision 1.13  2002/08/17 22:09:47  florian
    * result type handling in tcgcal.pass_2 overhauled
    * better tnode.dowrite
    * some ppc stuff fixed

  Revision 1.12  2002/08/14 18:41:48  jonas
    - remove valuelow/valuehigh fields from tlocation, because they depend
      on the endianess of the host operating system -> difficult to get
      right. Use lo/hi(location.valueqword) instead (remember to use
      valueqword and not value!!)

  Revision 1.11  2002/08/11 14:32:32  peter
    * renamed current_library to objectlibrary

  Revision 1.10  2002/08/11 13:24:18  peter
    * saving of asmsymbols in ppu supported
    * asmsymbollist global is removed and moved into a new class
      tasmlibrarydata that will hold the info of a .a file which
      corresponds with a single module. Added librarydata to tmodule
      to keep the library info stored for the module. In the future the
      objectfiles will also be stored to the tasmlibrarydata class
    * all getlabel/newasmsymbol and friends are moved to the new class

  Revision 1.9  2002/08/11 11:40:16  jonas
    * some overflow checking fixes

  Revision 1.8  2002/08/11 06:14:40  florian
    * fixed powerpc compilation problems

  Revision 1.7  2002/08/10 17:15:31  jonas
    * various fixes and optimizations

  Revision 1.6  2002/08/06 20:55:24  florian
    * first part of ppc calling conventions fix

  Revision 1.5  2002/08/05 08:58:54  jonas
    * fixed compilation problems

  Revision 1.4  2002/08/04 12:57:56  jonas
    * more misc. fixes, mostly constant-related

  Revision 1.3  2002/07/28 16:02:49  jonas
    + 64 bit operations (badly tested), everything is implemented now!
    * some small fixes

  Revision 1.2  2002/07/27 20:00:59  jonas
    + second_addboolean(), second_addfloat() and second_addsmallset()
      (64bit stuff is all that's left to do)

  Revision 1.1  2002/07/26 12:31:57  jonas
    + intial implementation of add nodes, only integer/enumeration/pointer/...
      handling is finished
}
