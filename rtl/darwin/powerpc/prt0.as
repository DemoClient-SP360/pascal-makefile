/* Startup code for programs linked with GNU libc.
   Copyright (C) 1998, 1999, 2000, 2001 Free Software Foundation, Inc.
   This file is part of the GNU C Library.

   The GNU C Library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.

   The GNU C Library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with the GNU C Library; if not, write to the Free
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA
   02111-1307 USA.  */

        .section ".text"
        .globl  _start
_start:
	mr 	26,1	
	/* Set up an initial stack frame, and clear the LR.  */
	clrrwi	1,1,4
	li	0,0
	stwu	1,-16(1)
	mtlr	0
	stw	0,0(1)
	lwz     3,0(26)       /* get argc */
        lis 	11,U_SYSTEM_ARGC@ha
	stw 	3,U_SYSTEM_ARGC@l(11); 
	
	addi    4,26,4        /* get argv */
        lis 	11,U_SYSTEM_ARGV@ha
	stw 	4,U_SYSTEM_ARGV@l(11); 
	
	addi    27,3,1        /* calculate argc + 1 into r27 */
        slwi    27,27,2       /* calculate (argc + 1) * sizeof(char *) into r27 */
        add     5,4,27       /* get address of env[0] */
	lis 	11,U_SYSTEM_ENVP@ha
	stw 	5,U_SYSTEM_ENVP@l(11); 
	
	bl	PASCALMAIN

        .globl  _haltproc
        .type   _haltproc,@function
_haltproc:
        li      0,1	         /* exit call */
	lis	3,U_SYSTEM_EXITCODE@h
	stw	3,U_SYSTEM_EXITCODE@l(3)
        sc
        b	_haltproc

	/* Define a symbol for the first piece of initialized data.  */
	.section ".data"
	.globl	__data_start
__data_start:
data_start:
        .globl  ___fpc_brk_addr         /* heap management */
        .type   ___fpc_brk_addr,@object
        .size   ___fpc_brk_addr,4
___fpc_brk_addr:
        .long   0
/*
  $Log$
  Revision 1.1  2003-05-20 23:56:40  florian
    * basic setup; derived from FreeBSD and Linux

  Revision 1.10  2003/05/12 22:36:45  florian
    + added setup of argv, argc and envp

  Revision 1.9  2002/09/07 16:01:20  peter
    * old logs removed and tabs fixed

  Revision 1.8  2002/08/31 21:29:57  florian
    * several PC related fixes

  Revision 1.7  2002/08/31 16:13:12  florian
    * made _start global

  Revision 1.6  2002/08/31 14:02:23  florian
    * r3 renamed to 3

  Revision 1.5  2002/08/31 14:01:28  florian
    * _haltproc to prt0.as added (Linux/PPC)

  Revision 1.4  2002/08/31 13:11:11  florian
    * several fixes for Linux/PPC compilation

  Revision 1.3  2002/08/19 21:19:15  florian
    * small fixes

  Revision 1.2  2002/07/26 17:09:44  florian
    * log fixed

  Revision 1.1  2002/07/26 16:57:40  florian
    + initial version, plain copy from glibc/sysdeps/powerpc/elf/start.S
*/
