{
    $Id$
    Copyright (c) 1998-2002 by Florian Klaempfl

    Generate sparc assembler for in call nodes

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
unit ncpucall;

{$i fpcdefs.inc}

interface

    uses
      ncgcal;

    type
       tsparccallnode = class(tcgcallnode)
         procedure extra_post_call_code;override;
       end;


implementation

    uses
      cpubase,
      aasmtai,
      aasmcpu,
      paramgr,
      ncal;


    procedure tsparccallnode.extra_post_call_code;
      begin
        if paramanager.ret_in_param(procdefinition.rettype.def,procdefinition.proccalloption) then
          exprasmlist.concat(taicpu.op_const(A_UNIMP,procdefinition.rettype.def.size and $fff));
      end;


begin
  ccallnode:=TSparcCallNode;
end.
{
  $Log$
  Revision 1.15  2005-01-07 16:22:54  florian
    + implemented abi compliant handling of strucutured functions results on sparc platform

  Revision 1.14  2004/06/20 08:55:32  florian
    * logs truncated

}

