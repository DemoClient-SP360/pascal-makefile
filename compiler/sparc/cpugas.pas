{*****************************************************************************}
{ File                   : cpugas.pas                                         }
{ Author                 : Mazen NEIFER                                       }
{ Project                : Free Pascal Compiler (FPC)                         }
{ Creation date          : 2002\05\01                                         }
{ Last modification date : 2002\08\22                                         }
{ Licence                : GPL                                                }
{ Bug report             : mazen.neifer.01@supaero.org                        }
{*****************************************************************************}
{   $Id$
    Copyright (c) 1998-2000 by Florian Klaempfl

    This unit implements an asmoutput class for SPARC AT&T syntax

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

 ****************************************************************************}
UNIT CpuGas;
{$MACRO ON}{$INCLUDE fpcdefs.inc}
INTERFACE
USES
  cclasses,cpubase,
  globals,
  aasmbase,aasmtai,aasmcpu,assemble,aggas;
TYPE
  TGasSPARC=class(TGnuAssembler)
    PROCEDURE WriteInstruction(hp:Tai);OVERRIDE;
  END;
IMPLEMENTATION
USES
  strings,
  dos,
  globtype,
  fmodule,finput,
  cutils,systems,
  verbose;
{$DEFINE gas_reg2str:=std_reg2str}
CONST
  line_length = 70;
VAR
{$ifdef GDB}
      n_line       : byte;     { different types of source lines }
      linecount,
      includecount : longint;
      funcname     : pchar;
      stabslastfileinfo : tfileposinfo;
{$endif}
      lastsec      : tsection; { last section type written }
      lastfileinfo : tfileposinfo;
      infile,
      lastinfile   : tinputfile;
      symendcount  : longint;

   function fixline(s:string):string;
   {
     return s with all leading and ending spaces and tabs removed
   }
     var
       i,j,k : longint;
     begin
       i:=length(s);
       while (i>0) and (s[i] in [#9,' ']) do
        dec(i);
       j:=1;
       while (j<i) and (s[j] in [#9,' ']) do
        inc(j);
       for k:=j to i do
        if s[k] in [#0..#31,#127..#255] then
         s[k]:='.';
       fixline:=Copy(s,j,i-j+1);
     end;

    function single2str(d : single) : string;
      var
         hs : string;
      begin
         str(d,hs);
      { replace space with + }
         if hs[1]=' ' then
          hs[1]:='+';
         single2str:='0d'+hs
      end;

    function double2str(d : double) : string;
      var
         hs : string;
      begin
         str(d,hs);
      { replace space with + }
         if hs[1]=' ' then
          hs[1]:='+';
         double2str:='0d'+hs
      end;

    function extended2str(e : extended) : string;
      var
         hs : string;
      begin
         str(e,hs);
      { replace space with + }
         if hs[1]=' ' then
          hs[1]:='+';
         extended2str:='0d'+hs
      end;


    function getreferencestring(var ref : treference) : string;
    var
      s : string;
    begin
      with ref do
       begin
         inc(offset,offsetfixup);
         offsetfixup:=0;
       { have we a segment prefix ? }
       { These are probably not correctly handled under GAS }
       { should be replaced by coding the segment override  }
       { directly! - DJGPP FAQ                              }
         if segment<>R_NO then
          s:=gas_reg2str[segment]+':'
         else
          s:='';
         if assigned(symbol) then
          s:=s+symbol.name;
         if offset<0 then
          s:=s+tostr(offset)
         else
          if (offset>0) then
           begin
             if assigned(symbol) then
              s:=s+'+'+tostr(offset)
             else
              s:=s+tostr(offset);
           end
         else if (index=R_NO) and (base=R_NO) and not assigned(symbol) then
           s:=s+'0';
         if (index<>R_NO) and (base=R_NO) then
          begin
            s:=s+'(,'+gas_reg2str[index];
            if scalefactor<>0 then
             s:=s+','+tostr(scalefactor)+')'
            else
             s:=s+')';
          end
         else
          if (index=R_NO) and (base<>R_NO) then
           s:=s+'('+gas_reg2str[base]+')'
          else
           if (index<>R_NO) and (base<>R_NO) then
            begin
              s:=s+'('+gas_reg2str[base]+','+gas_reg2str[index];
              if scalefactor<>0 then
               s:=s+','+tostr(scalefactor)+')'
              else
               s := s+')';
            end;
       end;
      getreferencestring:=s;
    end;

    function getopstr(const o:toper) : string;
    var
      hs : string;
    begin
      case o.typ of
        top_reg :
          getopstr:=gas_reg2str[o.reg];
        top_ref :
          getopstr:=getreferencestring(o.ref^);
        top_const :
          getopstr:='$'+tostr(longint(o.val));
        top_symbol :
          begin
            if assigned(o.sym) then
              hs:='$'+o.sym.name
            else
              hs:='$';
            if o.symofs>0 then
             hs:=hs+'+'+tostr(o.symofs)
            else
             if o.symofs<0 then
              hs:=hs+tostr(o.symofs)
            else
             if not(assigned(o.sym)) then
               hs:=hs+'0';
            getopstr:=hs;
          end;
        else
          internalerror(10001);
      end;
    end;

    function getopstr_jmp(const o:toper) : string;
    var
      hs : string;
    begin
      case o.typ of
        top_reg :
          getopstr_jmp:='*'+gas_reg2str[o.reg];
        top_ref :
          getopstr_jmp:='*'+getreferencestring(o.ref^);
        top_const :
          getopstr_jmp:=tostr(longint(o.val));
        top_symbol :
          begin
            hs:=o.sym.name;
            if o.symofs>0 then
             hs:=hs+'+'+tostr(o.symofs)
            else
             if o.symofs<0 then
              hs:=hs+tostr(o.symofs);
            getopstr_jmp:=hs;
          end;
        else
          internalerror(10001);
      end;
    end;


{****************************************************************************
                            TISPARCATTASMOUTPUT
 ****************************************************************************}

    const
      ait_const2str : array[ait_const_32bit..ait_const_8bit] of string[8]=
       (#9'.long'#9,#9'.short'#9,#9'.byte'#9);
PROCEDURE TGasSPARC.WriteInstruction(hp:Tai);
  VAR
    Op:TAsmOp;
    s:STRING;
    i:Integer;
    sep:STRING[3];
  BEGIN
    IF hp.typ<>ait_instruction
    THEN
      Exit;
       taicpu(hp).SetOperandOrder(op_att);
       op:=taicpu(hp).opcode;
       { call maybe not translated to call }
       s:=#9+std_op2str[op]+cond2str[taicpu(hp).condition];
    IF is_CallJmp(op)
    THEN
           { call and jmp need an extra handling                          }
           { this code is only called if jmp isn't a labeled instruction  }
           { quick hack to overcome a problem with manglednames=255 chars }
      BEGIN
{        IF op<>A_JMPl
        THEN
          s:=cond2str(op,taicpu(hp).condition)+','
        ELSE}
          s:=#9'b'#9;
        s:=s+getopstr_jmp(taicpu(hp).oper[0]);
      END
    ELSE
      BEGIN {process operands}
        s:=#9+std_op2str[op];
        IF taicpu(hp).ops<>0
        THEN
          BEGIN
            {
              if not is_calljmp(op) then
                sep:=','
              else
            }
            sep:=#9;
            FOR i:=0 TO taicpu(hp).ops-1 DO
              BEGIN
                s:=s+sep+getopstr(taicpu(hp).oper[i]);
                sep:=',';
              END;
          END;
      END;
    AsmWriteLn(s);
  END;
{*****************************************************************************
                                  Initialize
*****************************************************************************}
CONST
  as_SPARC_as_info:TAsmInfo=(
    id           : as_gas;
    idtxt  : 'AS';
    asmbin : 'as';
    asmcmd : '-o $OBJ $ASM';
    supported_target : system_any;
    outputbinary: false;
    allowdirect : true;
    needar : true;
    labelprefix_only_inside_procedure : false;
    labelprefix : '.L';
    comment : '# ';
    secnames : ({sec_none}'',           {no section}
                {sec_code}'.text',      {executable code}
                {sec_data}'.data',      {initialized R/W data}
                {sec_bss}'.bss',        {uninitialized R/W data}
                {sec_idata2}'.comment', {comments}
                {sec_idata4}'.debug',   {debugging information}
                {sec_idata5}'.rodata',  {RO data}
                {sec_idata6}'.line',    {line numbers info for symbolic debug}
                {sec_idata7}'.init',    {runtime intialization code}
                {sec_edata}'.fini',     {runtime finalization code}
                {sec_stab}'.stab',
                {sec_stabstr} '.stabstr',
                {sec_common}'.note')    {note info}
  );
INITIALIZATION
  RegisterAssembler(as_SPARC_as_info,TGasSPARC);
END.
