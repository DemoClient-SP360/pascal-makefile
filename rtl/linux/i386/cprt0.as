#
#   $Id$
#   This file is part of the Free Pascal run time library.
#   Copyright (c) 1999-2000 by Michael Van Canneyt and Peter Vreman
#   members of the Free Pascal development team.
#
#   See the file COPYING.FPC, included in this distribution,
#   for details about the copyright.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY;without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
#**********************************************************************}
#
# Linux ELF startup code for Free Pascal
#
#
# Stack layout at program start:
#
#         nil
#         envn
#         ....
#         ....           ENVIRONMENT VARIABLES
#         env1
#         env0
#         nil
#         argn
#         ....
#         ....           COMMAND LINE OPTIONS
#         arg1
#         arg0
#         argc <--- esp
#

        .file   "cprt0.as"
        .text
        .globl  _start
        .type   _start,@function
_start:
        /* First locate the start of the environment variables */
        popl    %ecx                    /* Get argc in ecx */
        movl    %esp,%ebx               /* Esp now points to the arguments */
        leal    4(%esp,%ecx,4),%eax     /* The start of the environment is: esp+4*eax+8 */
        andl    $0xfffffff8,%esp        /* Align stack */

        movl    %eax,operatingsystem_parameter_envp    /* Move the environment pointer */
        movl    %ecx,operatingsystem_parameter_argc    /* Move the argument counter    */
        movl    %ebx,operatingsystem_parameter_argv    /* Move the argument pointer    */

        movl    %eax,__environ          /* libc environ */

        pushl   %eax
        pushl   %ebx
        pushl   %ecx

        call    __libc_init             /* init libc */
        movzwl  __fpu_control,%eax
        pushl   %eax
        call    __setfpucw
        popl    %eax
        pushl   $_fini
        call    atexit
        popl    %eax
        call    _init

        popl    %eax
        popl    %eax

        xorl    %ebp,%ebp
        call    PASCALMAIN              /* start the program */

        .globl _haltproc
        .type _haltproc,@function
_haltproc:
_haltproc2:             # GAS <= 2.15 bug: generates larger jump if a label is exported
        movzwl  operatingsystem_result,%ebx
	pushl   %ebx
	call    exit
        xorl    %eax,%eax
        incl    %eax                    /* eax=1, exit call */
	popl    %ebx
        int     $0x80
        jmp     _haltproc2

.data

.bss
        .type   ___fpc_brk_addr,@object
        .comm   ___fpc_brk_addr,4        /* heap management */

        .comm operatingsystem_parameter_envp,4
        .comm operatingsystem_parameter_argc,4
        .comm operatingsystem_parameter_argv,4

#
# $Log$
# Revision 1.4  2004-07-03 21:50:31  daniel
#   * Modified bootstrap code so separate prt0.as/prt0_10.as files are no
#     longer necessary
#
# Revision 1.3  2002/09/07 16:01:20  peter
#   * old logs removed and tabs fixed
#
