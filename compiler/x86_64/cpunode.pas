{
    $Id$
    Copyright (c) 2000 by Florian Klaempfl

    Includes the x86-64 code generator

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
{ This is a helper unit to include the necessary code generator units
  for the x86-64 processor.
}
unit cpunode;

{$i fpcdefs.inc}

  interface

  implementation

    uses
       { generic nodes }
       ncgbas,
       ncgld,
       ncgflw,
       ncgcnv,
       ncgmem,
       ncgmat,
       ncgcon,
       ncgcal,
       ncgset,
       ncgopt,
       // n386con,n386flw,n386mat,n386mem,
       // n386set,n386inl,n386opt,
       { this not really a node }
       // n386obj
       { the cpu specific node units must be used after the generic ones to
         get the correct class pointer }
       nx86set,
       nx64add,
       nx64cnv,
       nx64mat,
       nx64inl
       ;

end.
{
  $Log$
  Revision 1.8  2004-02-22 12:04:04  florian
    + nx86set added
    * some more x86-64 fixes

  Revision 1.7  2004/02/05 01:24:08  florian
    * several fixes to compile x86-64 system

  Revision 1.6  2004/01/31 17:45:17  peter
    * Change several $ifdef i386 to x86
    * Change several OS_32 to OS_INT/OS_ADDR

  Revision 1.5  2004/01/20 12:59:37  florian
    * common addnode code for x86-64 and i386

  Revision 1.4  2003/04/30 22:15:59  florian
    * some 64 bit adaptions in ncgadd
    * x86-64 now uses ncgadd
    * tparamanager.ret_in_acc doesn't return true anymore for a void-def

  Revision 1.3  2003/04/30 20:53:32  florian
    * error when address of an abstract method is taken
    * fixed some x86-64 problems
    * merged some more x86-64 and i386 code

  Revision 1.2  2002/07/25 22:55:34  florian
    * several fixes, small test units can be compiled

  Revision 1.1  2002/07/24 22:38:15  florian
    + initial release of x86-64 target code

}
