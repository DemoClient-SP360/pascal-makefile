{
    $Id$
    Copyright (c) 1998-2002 by Florian Klaempfl

    Generate generic mathematical nodes

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
unit ncgmat;

{$i fpcdefs.inc}

interface

    uses
      node,nmat,cpubase,cgbase;

    type
      tcgunaryminusnode = class(tunaryminusnode)
      protected
         { This routine is called to change the sign of the
           floating point value in the floating point
           register r.

           This routine should be overriden, since
           the generic version is not optimal at all. The
           generic version assumes that floating
           point values are stored in the register
           in IEEE-754 format.
         }
         procedure emit_float_sign_change(r: tregister; _size : tcgsize);virtual;
{$ifdef SUPPORT_MMX}
         procedure second_mmx;virtual;abstract;
{$endif SUPPORT_MMX}
{$ifndef cpu64bit}
         procedure second_64bit;virtual;
{$endif cpu64bit}
         procedure second_integer;virtual;
         procedure second_float;virtual;
      public
         procedure pass_2;override;
      end;

      tcgmoddivnode = class(tmoddivnode)
         procedure pass_2;override;
      protected
         { This routine must do an actual 32-bit division, be it
           signed or unsigned. The result must set into the the
           @var(num) register.

           @param(signed Indicates if the division must be signed)
           @param(denum  Register containing the denominator
           @param(num    Register containing the numerator, will also receive result)

           The actual optimizations regarding shifts have already
           been done and emitted, so this should really a do a divide.
         }
         procedure emit_div_reg_reg(signed: boolean;denum,num : tregister);virtual;abstract;
         { This routine must do an actual 32-bit modulo, be it
           signed or unsigned. The result must set into the the
           @var(num) register.

           @param(signed Indicates if the modulo must be signed)
           @param(denum  Register containing the denominator
           @param(num    Register containing the numerator, will also receive result)

           The actual optimizations regarding shifts have already
           been done and emitted, so this should really a do a modulo.
         }
         procedure emit_mod_reg_reg(signed: boolean;denum,num : tregister);virtual;abstract;
{$ifndef cpu64bit}
         { This routine must do an actual 64-bit division, be it
           signed or unsigned. The result must set into the the
           @var(num) register.

           @param(signed Indicates if the division must be signed)
           @param(denum  Register containing the denominator
           @param(num    Register containing the numerator, will also receive result)

           The actual optimizations regarding shifts have already
           been done and emitted, so this should really a do a divide.
           Currently, this routine should only be implemented on
           64-bit systems, otherwise a helper is called in 1st pass.
         }
         procedure emit64_div_reg_reg(signed: boolean;denum,num : tregister64);virtual;
{$endif cpu64bit}
      end;

      tcgshlshrnode = class(tshlshrnode)
{$ifndef cpu64bit}
         procedure second_64bit;virtual;
{$endif cpu64bit}
         procedure second_integer;virtual;
         procedure pass_2;override;
      end;

      tcgnotnode = class(tnotnode)
      protected
         procedure second_boolean;virtual;abstract;
{$ifdef SUPPORT_MMX}
         procedure second_mmx;virtual;abstract;
{$endif SUPPORT_MMX}
{$ifndef cpu64bit}
         procedure second_64bit;virtual;
{$endif cpu64bit}
         procedure second_integer;virtual;
      public
         procedure pass_2;override;
      end;


implementation

    uses
      globtype,systems,
      cutils,verbose,globals,
      symconst,aasmbase,aasmtai,aasmcpu,defutil,
      parabase,
      pass_2,
      ncon,
      tgobj,ncgutil,cgobj,cgutils,paramgr
{$ifndef cpu64bit}
      ,cg64f32
{$endif cpu64bit}
      ;

{*****************************************************************************
                          TCGUNARYMINUSNODE
*****************************************************************************}

    procedure tcgunaryminusnode.emit_float_sign_change(r: tregister; _size : tcgsize);
      var
        href,
        href2 : treference;
      begin
        { get a temporary memory reference to store the floating
          point value
        }
        tg.gettemp(exprasmlist,tcgsize2size[_size],tt_normal,href);
        { store the floating point value in the temporary memory area }
        cg.a_loadfpu_reg_ref(exprasmlist,_size,r,href);
        { only single and double ieee are supported, for little endian
          the signed bit is in the second dword }
        href2:=href;
        case _size of
          OS_F64 :
            if target_info.endian = endian_little then
              inc(href2.offset,4);
          OS_F32 :
            ;
          else
            internalerror(200406021);
        end;
        { flip sign-bit (bit 31/63) of single/double }
        cg.a_op_const_ref(exprasmlist,OP_XOR,OS_32,aint($80000000),href2);
        cg.a_loadfpu_ref_reg(exprasmlist,_size,href,r);
        tg.ungetiftemp(exprasmlist,href);
      end;


{$ifndef cpu64bit}
    procedure tcgunaryminusnode.second_64bit;
      begin
        secondpass(left);
        { load left operator in a register }
        location_copy(location,left.location);
        location_force_reg(exprasmlist,location,OS_64,false);
        cg64.a_op64_loc_reg(exprasmlist,OP_NEG,OS_64,
           location,joinreg64(location.register64.reglo,location.register64.reghi));
      end;
{$endif cpu64bit}

    procedure tcgunaryminusnode.second_float;
      begin
        secondpass(left);
        location_reset(location,LOC_FPUREGISTER,def_cgsize(resulttype.def));
        case left.location.loc of
          LOC_REFERENCE,
          LOC_CREFERENCE :
            begin
              location.register:=cg.getfpuregister(exprasmlist,location.size);
              cg.a_loadfpu_ref_reg(exprasmlist,
                 def_cgsize(left.resulttype.def),
                 left.location.reference,location.register);
              emit_float_sign_change(location.register,def_cgsize(left.resulttype.def));
            end;
          LOC_FPUREGISTER:
            begin
               location.register:=left.location.register;
               emit_float_sign_change(location.register,def_cgsize(left.resulttype.def));
            end;
          LOC_CFPUREGISTER:
            begin
               location.register:=cg.getfpuregister(exprasmlist,location.size);
               cg.a_loadfpu_reg_reg(exprasmlist,left.location.size,left.location.register,location.register);
               emit_float_sign_change(location.register,def_cgsize(left.resulttype.def));
            end;
          else
            internalerror(200306021);
        end;
      end;


    procedure tcgunaryminusnode.second_integer;
      begin
        secondpass(left);
        { load left operator in a register }
        location_copy(location,left.location);
        location_force_reg(exprasmlist,location,OS_INT,false);
        cg.a_op_reg_reg(exprasmlist,OP_NEG,OS_INT,location.register,location.register);
      end;


    procedure tcgunaryminusnode.pass_2;
      begin
{$ifndef cpu64bit}
         if is_64bit(left.resulttype.def) then
           second_64bit
         else
{$endif cpu64bit}
{$ifdef SUPPORT_MMX}
           if (cs_mmx in aktlocalswitches) and is_mmx_able_array(left.resulttype.def) then
             second_mmx
         else
{$endif SUPPORT_MMX}
           if (left.resulttype.def.deftype=floatdef) then
             second_float
         else
           second_integer;
      end;


{*****************************************************************************
                             TCGMODDIVNODE
*****************************************************************************}

{$ifndef cpu64bit}
    procedure tcgmoddivnode.emit64_div_reg_reg(signed: boolean; denum,num:tregister64);
      begin
        { handled in pass_1 already, unless pass_1 is
          overriden
        }
        { should be handled in pass_1 (JM) }
        internalerror(200109052);
      end;
{$endif cpu64bit}


    procedure tcgmoddivnode.pass_2;
      var
         hreg1 : tregister;
         hdenom : tregister;
         power : longint;
         hl : tasmlabel;
         paraloc1 : tcgpara;
      begin
         secondpass(left);
         if codegenerror then
          exit;
         secondpass(right);
         if codegenerror then
          exit;
         location_copy(location,left.location);

{$ifndef cpu64bit}
         if is_64bit(resulttype.def) then
           begin
             { this code valid for 64-bit cpu's only ,
               otherwise helpers are called in pass_1
             }
             location_force_reg(exprasmlist,location,OS_64,false);
             location_copy(location,left.location);
             location_force_reg(exprasmlist,right.location,OS_64,false);
             emit64_div_reg_reg(is_signed(left.resulttype.def),
               joinreg64(right.location.register64.reglo,right.location.register64.reghi),
               joinreg64(location.register64.reglo,location.register64.reghi));
           end
         else
{$endif cpu64bit}
           begin
              { put numerator in register }
              location_force_reg(exprasmlist,left.location,OS_INT,false);
              hreg1:=left.location.register;

              if (nodetype=divn) and
                 (right.nodetype=ordconstn) and
                 ispowerof2(tordconstnode(right).value,power) then
                Begin
                  { for signed numbers, the numerator must be adjusted before the
                    shift instruction, but not wih unsigned numbers! Otherwise,
                    "Cardinal($ffffffff) div 16" overflows! (JM) }
                  If is_signed(left.resulttype.def) Then
                    Begin
                      objectlibrary.getlabel(hl);
                      cg.a_cmp_const_reg_label(exprasmlist,OS_INT,OC_GT,0,hreg1,hl);
                      if power=1 then
                        cg.a_op_const_reg(exprasmlist,OP_ADD,OS_INT,1,hreg1)
                      else
                        cg.a_op_const_reg(exprasmlist,OP_ADD,OS_INT,tordconstnode(right).value-1,hreg1);
                      cg.a_label(exprasmlist,hl);
                      cg.a_op_const_reg(exprasmlist,OP_SAR,OS_INT,power,hreg1);
                    End
                  Else { not signed }
                    cg.a_op_const_reg(exprasmlist,OP_SHR,OS_INT,power,hreg1);
                End
              else
                begin
                  { bring denominator to hdenom }
                  { hdenom is always free, it's }
                  { only used for temporary }
                  { purposes                }
                  hdenom := cg.getintregister(exprasmlist,OS_INT);
                  cg.a_load_loc_reg(exprasmlist,right.location.size,right.location,hdenom);
                  { verify if the divisor is zero, if so return an error
                    immediately
                  }
                  objectlibrary.getlabel(hl);
                  cg.a_cmp_const_reg_label(exprasmlist,OS_INT,OC_NE,0,hdenom,hl);
                  paraloc1.init;
                  paramanager.getintparaloc(pocall_default,1,paraloc1);
                  paramanager.allocparaloc(exprasmlist,paraloc1);
                  cg.a_param_const(exprasmlist,OS_S32,200,paraloc1);
                  paramanager.freeparaloc(exprasmlist,paraloc1);
                  cg.a_call_name(exprasmlist,'FPC_HANDLERROR');
                  paraloc1.done;
                  cg.a_label(exprasmlist,hl);
                  if nodetype = modn then
                    emit_mod_reg_reg(is_signed(left.resulttype.def),hdenom,hreg1)
                  else
                    emit_div_reg_reg(is_signed(left.resulttype.def),hdenom,hreg1);
                end;
              location_reset(location,LOC_REGISTER,OS_INT);
              location.register:=hreg1;
           end;
        cg.g_overflowcheck(exprasmlist,location,resulttype.def);
      end;


{*****************************************************************************
                             TCGSHLRSHRNODE
*****************************************************************************}


{$ifndef cpu64bit}
    procedure tcgshlshrnode.second_64bit;
      begin
         { already hanled in 1st pass }
         internalerror(2002081501);
      end;
{$endif cpu64bit}


    procedure tcgshlshrnode.second_integer;
      var
         op : topcg;
         hcountreg : tregister;
      begin
         { determine operator }
         case nodetype of
           shln: op:=OP_SHL;
           shrn: op:=OP_SHR;
         end;
         { load left operators in a register }
         location_copy(location,left.location);
         location_force_reg(exprasmlist,location,OS_INT,false);

         { shifting by a constant directly coded: }
         if (right.nodetype=ordconstn) then
           begin
              { l shl 32 should 0 imho, but neither TP nor Delphi do it in this way (FK)
              if right.value<=31 then
              }
              cg.a_op_const_reg(exprasmlist,op,location.size,
                tordconstnode(right).value and 31,location.register);
              {
              else
                emit_reg_reg(A_XOR,S_L,hregister1,
                  hregister1);
              }
           end
         else
           begin
              { load right operators in a register - this
                is done since most target cpu which will use this
                node do not support a shift count in a mem. location (cec)
              }
              if right.location.loc<>LOC_REGISTER then
                begin
                  hcountreg:=cg.getintregister(exprasmlist,OS_INT);
                  cg.a_load_loc_reg(exprasmlist,right.location.size,right.location,hcountreg);
                end
              else
                hcountreg:=right.location.register;
              cg.a_op_reg_reg(exprasmlist,op,OS_INT,hcountreg,location.register);
           end;
      end;


    procedure tcgshlshrnode.pass_2;
      begin
         secondpass(left);
         secondpass(right);
{$ifndef cpu64bit}
         if is_64bit(left.resulttype.def) then
           second_64bit
         else
{$endif cpu64bit}
           second_integer;
      end;


{*****************************************************************************
                               TCGNOTNODE
*****************************************************************************}

{$ifndef cpu64bit}
    procedure tcgnotnode.second_64bit;
      begin
        secondpass(left);
        location_force_reg(exprasmlist,left.location,def_cgsize(left.resulttype.def),false);
        location_copy(location,left.location);
        { perform the NOT operation }
        cg64.a_op64_reg_reg(exprasmlist,OP_NOT,location.size,left.location.register64,location.register64);
      end;
{$endif cpu64bit}


    procedure tcgnotnode.second_integer;
      begin
        secondpass(left);
        location_force_reg(exprasmlist,left.location,def_cgsize(left.resulttype.def),false);
        location_copy(location,left.location);
        { perform the NOT operation }
        cg.a_op_reg_reg(exprasmlist,OP_NOT,location.size,location.register,location.register);
      end;


    procedure tcgnotnode.pass_2;
      begin
        if is_boolean(resulttype.def) then
          second_boolean
{$ifdef SUPPORT_MMX}
        else if (cs_mmx in aktlocalswitches) and is_mmx_able_array(left.resulttype.def) then
          second_mmx
{$endif SUPPORT_MMX}
{$ifndef cpu64bit}
        else if is_64bit(left.resulttype.def) then
          second_64bit
{$endif cpu64bit}
        else
          second_integer;
      end;

begin
   cmoddivnode:=tcgmoddivnode;
   cunaryminusnode:=tcgunaryminusnode;
   cshlshrnode:=tcgshlshrnode;
   cnotnode:=tcgnotnode;
end.
{
  $Log$
  Revision 1.31  2005-02-13 18:55:19  florian
    + overflow checking for the arm

  Revision 1.30  2004/10/31 21:45:03  peter
    * generic tlocation
    * move tlocation to cgutils

  Revision 1.29  2004/09/25 14:23:54  peter
    * ungetregister is now only used for cpuregisters, renamed to
      ungetcpuregister
    * renamed (get|unget)explicitregister(s) to ..cpuregister
    * removed location-release/reference_release

  Revision 1.28  2004/09/21 17:25:12  peter
    * paraloc branch merged

  Revision 1.27.4.1  2004/08/31 20:43:06  peter
    * paraloc patch

  Revision 1.27  2004/06/20 08:55:29  florian
    * logs truncated

  Revision 1.26  2004/06/16 20:07:08  florian
    * dwarf branch merged

  Revision 1.25.2.4  2004/06/02 19:04:51  peter
    * fixed minusunary for float

  Revision 1.25.2.3  2004/05/31 16:39:42  peter
    * add ungetiftemp in a few locations

  Revision 1.25.2.2  2004/05/30 17:07:07  peter
    * fix shl shr for sparc

  Revision 1.25.2.1  2004/04/27 18:18:25  peter
    * aword -> aint

}
