{
    $Id$
    Copyright (c) 1997-98 by Carl Eric Codere

    Does the parsing for the AT&T styled inline assembler.

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
Unit Ra386att;

{$ifdef TP}
  {$N+,E+}
{$endif TP}

{**********************************************************************}
{ WARNING                                                              }
{**********************************************************************}
{  Any modification in the order or removal of terms in the tables     }
{  in i386.pas and intasmi3.pas will BREAK the code in this unit,      }
{  unless the appropriate changes are made to this unit. Addition      }
{  of terms though, will not change the code herein.                   }
{**********************************************************************}

{--------------------------------------------------------------------}
{ LEFT TO DO:                                                        }
{--------------------------------------------------------------------}
{ o Handle record offsets                                            }
{ o Add support imul,shld and shrd.                                  }
{ o Add support for nor operators.                                   }
{ o Bugfix of ao_imm8s for IMUL. (Currently the 3 operand imul will  }
{   be considered as invalid because I use ao_imm8 and the table     }
{   uses ao_imm8s).                                                  }
{ o In ConcatOpCode add more checking regarding suffixes and         }
{   destination registers. (started but unfinished).                 }
{--------------------------------------------------------------------}
Interface

uses
  i386,tree;

   function assemble: ptree;

const
 { this variable is TRUE if the lookup tables have already been setup  }
 { for fast access. On the first call to assemble the tables are setup }
 { and stay set up.                                                    }
 _asmsorted: boolean = FALSE;
 firstreg       = R_EAX;
 lastreg        = R_ST7;
 { Hack to support all opcodes in the i386 table    }
 { only tokens up to and including lastop_in_table  }
 { are checked for validity, otherwise...           }
 lastop_in_table = A_EMMS;

type
 tiasmops = array[firstop..lastop] of string[7];
 piasmops = ^tiasmops;

var
 previous_was_id : boolean;
 { sorted tables of opcodes }
 iasmops: piasmops;
 { uppercased tables of registers }
 iasmregs: array[firstreg..lastreg] of string[6];


Implementation

Uses
  files,aasm,globals,AsmUtils,strings,hcodegen,scanner,systems,
  cobjects,verbose,symtable,types;

type
 tinteltoken = (
   AS_NONE,AS_LABEL,AS_LLABEL,AS_STRING,AS_HEXNUM,AS_OCTALNUM,
   AS_BINNUM,AS_REALNUM,AS_COMMA,AS_LPAREN,
   AS_RPAREN,AS_COLON,AS_DOT,AS_PLUS,AS_MINUS,AS_STAR,AS_INTNUM,
   AS_SEPARATOR,AS_ID,AS_REGISTER,AS_OPCODE,AS_SLASH,AS_DOLLAR,
     {------------------ Assembler directives --------------------}
   AS_DB,AS_DW,AS_DD,AS_DQ,AS_GLOBAL,AS_ALIGN,AS_ASCII,
   AS_ASCIIZ,AS_LCOMM,AS_COMM,AS_SINGLE,AS_DOUBLE,AS_EXTENDED,
   AS_DATA,AS_TEXT,AS_END,
     {------------------ Assembler Operators  --------------------}
   AS_MOD,AS_SHL,AS_SHR,AS_NOT,AS_AND,AS_OR,AS_XOR,AS_NOR);

   tasmkeyword = string[8];
const
   { These tokens should be modified accordingly to the modifications }
   { in the different enumerations.                                   }
   firstdirective = AS_DB;
   lastdirective  = AS_END;
   firstsreg      = R_CS;
   lastsreg       = R_SS;

       _count_asmdirectives = longint(lastdirective)-longint(firstdirective);
       _count_asmprefixes   = 5;
       _count_asmspecialops = 25;
       _count_asmoverrides  = 3;

       _asmdirectives : array[0.._count_asmdirectives] of tasmkeyword =
       ('.byte','.word','.long','.quad','.globl','.align','.ascii',
        '.asciz','.lcomm','.comm','.single','.double','.tfloat',
        '.data','.text','END');

     {------------------ Missing opcodes from std list  ----------------}
       _asmprefixes: array[0.._count_asmprefixes] of tasmkeyword = (
       'REPNE','REPE','REP','REPZ','REPNZ','LOCK');

       _prefixtokens: array[0.._count_asmprefixes] of tasmop = (
       A_REPNE,A_REPE,A_REP,A_REPE,A_REPNE,A_LOCK);

       _specialops: array[0.._count_asmspecialops] of tasmkeyword = (
       'CMPSB','CMPSW','CMPSL','INSB','INSW','INSL','OUTSB','OUTSW','OUTSL',
       'SCASB','SCASW','SCASL','STOSB','STOSW','STOSL','MOVSB','MOVSW','MOVSL',
       'LODSB','LODSW','LODSL','LOCK','SEGCS','SEGDS','SEGES','SEGSS');

       _specialopstokens: array[0.._count_asmspecialops] of tasmop = (
       A_CMPS,A_CMPS,A_CMPS,A_INS,A_INS,A_INS,A_OUTS,A_OUTS,A_OUTS,
       A_SCAS,A_SCAS,A_SCAS,A_STOS,A_STOS,A_STOS,A_MOVS,A_MOVS,A_MOVS,
       A_LODS,A_LODS,A_LODS,A_LOCK,A_NONE,A_NONE,A_NONE,A_NONE);
     {------------------------------------------------------------------}
       { register type definition table for easier searching }
       _regtypes:array[firstreg..lastreg] of longint =
       (ao_reg32,ao_reg32,ao_reg32,ao_reg32,ao_reg32,ao_reg32,ao_reg32,ao_reg32,
       ao_reg16,ao_reg16,ao_reg16,ao_reg16,ao_reg16,ao_reg16,ao_reg16,ao_reg16,
       ao_reg8,ao_reg8,ao_reg8,ao_reg8,ao_reg8,ao_reg8,ao_reg8,ao_reg8,
       ao_none,ao_sreg2,ao_sreg2,ao_sreg2,ao_sreg3,ao_sreg3,ao_sreg2,
       ao_floatacc,ao_floatacc,ao_floatreg,ao_floatreg,ao_floatreg,ao_floatreg,
       ao_floatreg,ao_floatreg,ao_floatreg);

       _regsizes: array[firstreg..lastreg] of topsize =
       (S_L,S_L,S_L,S_L,S_L,S_L,S_L,S_L,
        S_W,S_W,S_W,S_W,S_W,S_W,S_W,S_W,
        S_B,S_B,S_B,S_B,S_B,S_B,S_B,S_B,
        { segment register }
        S_W,S_W,S_W,S_W,S_W,S_W,S_W,
        { can also be S_S or S_T - must be checked at run-time }
        S_FL,S_FL,S_FL,S_FL,S_FL,S_FL,S_FL,S_FL,S_FL);

       {topsize = (S_NO,S_B,S_W,S_L,S_BW,S_BL,S_WL,
                  S_IS,S_IL,S_IQ,S_FS,S_FL,S_FX,S_D);}
       _constsizes: array[S_NO..S_FS] of longint =
       (0,ao_imm8,ao_imm16,ao_imm32,0,0,0,ao_imm16,ao_imm32,0,ao_imm32);

       { converts from AT&T style to non-specific style... }
       _fpusizes:array[A_FILDQ..A_FIDIVRS] of topsize = (
                 {'fildq','filds',}
                 S_IQ,S_IS,
                 {'fildl','fldl','fldt','fistq','fists','fistl','fstl','fsts',}
                 S_IL,S_FL,S_FX,S_IQ,S_IS,S_IL,S_FL,S_FS,
                 {'fstps','fistpl','fstpl','fistps','fistpq','fstpt','fcomps',}
                 S_FS,S_IL,S_FL,S_IS,S_IQ,S_FX,S_FS,
                 {'ficompl','fcompl','ficomps','fcoms','ficoml','fcoml','ficoms',}
                 S_IL,S_FL,S_IS,S_FS,S_IL,S_FL,S_IS,
                 {'fiaddl','faddl','fiadds','fisubl','fsubl','fisubs','fsubs',}
                 S_IL,S_FL,S_IS,S_IL,S_FL,S_FS,S_IS,S_FS,
                 {'fsubr','fsubrs','fisubrl','fsubrl','fisubrs','fmuls','fimull',}
                 S_NO,S_FS,S_IL,S_FL,S_IS,S_FS,S_IL,
                 {'fmull','fimuls','fdivs','fidivl','fdivl','fidivs','fdivrs',}
                 S_FL,S_IL,S_FS,S_IL,S_FL,S_IS,S_FS,
                 {'fidivrl','fdivrl',}
                 S_IL,S_FL);
       _fpuopcodes:array[A_FILDQ..A_FIDIVRS] of tasmop = (
       A_FILD,A_FILD,A_FILD,A_FLD,A_FLD,A_FIST,A_FIST,A_FIST,A_FST,A_FST,
       A_FSTP,A_FISTP,A_FSTP,A_FISTP,A_FISTP,A_FSTP,
       A_FCOMP,A_FICOMP,A_FCOMP,A_FICOMP,
       A_FCOM,A_FICOM,A_FCOM,A_FICOM,A_FIADD,A_FADD,A_FIADD,
       A_FISUB,A_FSUB,A_FISUB,A_FSUB,A_FSUB,A_FSUBR,A_FISUBR,
       A_FSUBR,A_FISUBR,A_FMUL,A_FIMUL,A_FMUL,A_FIMUL,A_FDIV,A_FIDIV,
       A_FDIV,A_FIDIV,A_FDIVR,A_FIDIVR,A_FDIVR,A_FIDIVR);

 const
  newline = #10;
  firsttoken : boolean = TRUE;
  operandnum : byte = 0;
 charcount: byte = 0;
 var
 p : paasmoutput;
 actasmtoken: tinteltoken;
 actasmpattern: string;
 c: char;
 Instr: TInstruction;
 labellist: TAsmLabelList;
 line: string; { CHanged from const to var, there is a bug in 0.9.1 which
                 doesn't allow 255-char constant strings. MVC}

   Procedure SetupTables;
   { creates uppercased symbol tables. }
   var
     i: tasmop;
     j: tregister;
   Begin
     Message(assem_d_creating_lookup_tables);
     { opcodes }
     new(iasmops);
     for i:=firstop to lastop do
      iasmops^[i] := upper(att_op2str[i]);
     { opcodes }
     for j:=firstreg to lastreg do
      iasmregs[j] := upper(att_reg2str[j]);
   end;

  {---------------------------------------------------------------------}
  {                     Routines for the tokenizing                     }
  {---------------------------------------------------------------------}

   function is_asmopcode(const s: string):Boolean;
  {*********************************************************************}
  { FUNCTION is_asmopcode(s: string):Boolean                            }
  {  Description: Determines if the s string is a valid opcode          }
  {  if so returns TRUE otherwise returns FALSE.                        }
  {*********************************************************************}
   var
    i: tasmop;
    j: byte;
    hs: topsize;
    hid: string;
   Begin
     is_asmopcode := FALSE;
     { first search for extended opcodes }
     for j:=0 to _count_asmspecialops do
     Begin
       if s = _specialops[j] then
       Begin
         is_asmopcode:=TRUE;
         exit;
       end;
     end;

     for i:=firstop to lastop do
     Begin
            if s=iasmops^[i] then
             begin
               is_asmopcode := TRUE;
               exit
             end;
     end;
     { not found yet ... }
     { search for all possible suffixes }
     for hs:=S_WL downto S_B do
        if copy(s,length(s)-length(att_opsize2str[hs])+1,
          length(att_opsize2str[hs]))=upper(att_opsize2str[hs]) then
        begin
           { here we search the entire table... }
           hid:=copy(s,1,length(s)-length(att_opsize2str[hs]));
           for i:=firstop to lastop do
              if (length(hid) > 0) and (hid=iasmops^[i]) then
              begin
                is_asmopcode := TRUE;
                exit;
              end;
        end;
   end;



   Procedure is_asmdirective(const s: string; var token: tinteltoken);
  {*********************************************************************}
  { FUNCTION is_asmdirective(s: string; var token: tinteltoken):Boolean }
  {  Description: Determines if the s string is a valid directive       }
  { (an operator can occur in operand fields, while a directive cannot) }
  {  if so returns the directive token, otherwise does not change token.}
  {*********************************************************************}
   var
    i:byte;
   Begin
     for i:=0 to _count_asmdirectives do
     begin
        if s=_asmdirectives[i] then
        begin
           token := tinteltoken(longint(firstdirective)+i);
           exit;
        end;
     end;
   end;


   Procedure is_register(const s: string; var token: tinteltoken);
  {*********************************************************************}
  { PROCEDURE is_register(s: string; var token: tinteltoken);           }
  {  Description: Determines if the s string is a valid register, if    }
  {  so return token equal to A_REGISTER, otherwise does not change token}
  {*********************************************************************}
   Var
    i: tregister;
   Begin
     for i:=firstreg to lastreg do
     begin
      if s=iasmregs[i] then
      begin
        token := AS_REGISTER;
        exit;
      end;
     end;
   end;


  Function GetToken: tinteltoken;
  {*********************************************************************}
  { FUNCTION GetToken: tinteltoken;                                     }
  {  Description: This routine returns intel assembler tokens and       }
  {  does some minor syntax error checking.                             }
  {*********************************************************************}
  var
   token: tinteltoken;
   forcelabel: boolean;
   errorflag : boolean;
   temp: string;
   code: integer;
   value: byte;
  begin
    errorflag := FALSE;
    forcelabel := FALSE;
    actasmpattern :='';
    {* INIT TOKEN TO NOTHING *}
    token := AS_NONE;
    { while space and tab , continue scan... }
    while c in [' ',#9] do
     c:=current_scanner^.asmgetchar;
    { Possiblities for first token in a statement:                }
    {   Local Label, Label, Directive, Prefix or Opcode....       }
    if firsttoken and not (c in [newline,#13,'{',';']) then
    begin
      current_scanner^.gettokenpos;
      firsttoken := FALSE;
      { directive or local labe }
      if c = '.' then
      begin
        actasmpattern := c;
        { Let us point to the next character }
        c := current_scanner^.asmgetchar;
        while c in ['A'..'Z','a'..'z','0'..'9','_','$'] do
        begin
         actasmpattern := actasmpattern + c;
         c := current_scanner^.asmgetchar;
        end;

        { this is a local label... }
        if (actasmpattern[2] = 'L') and (c = ':') then
        Begin
          { local variables are case sensitive }
          gettoken := AS_LLABEL;
          { delete .L }
          delete(actasmpattern,1,2);
          { point to next character ... }
          c := current_scanner^.asmgetchar;
          exit;
        end
        { must be a directive }
        else
        Begin
         { directives are case sensitive!! }
         is_asmdirective(actasmpattern, token);
         if (token <> AS_NONE) then
          Begin
            gettoken := token;
            exit;
          end
         else
           Message1(assem_e_not_directive_or_local_symbol,actasmpattern);
        end;
      end; { endif }

      { only opcodes and global labels are allowed now. }
      while c in ['A'..'Z','a'..'z','0'..'9','_'] do
      begin
         actasmpattern := actasmpattern + c;
         c := current_scanner^.asmgetchar;
      end;

      if c = ':' then
      begin
           { uppervar(actasmpattern);
           Carl, you cannot change the label to upper
           if you want to be able to read in system unit
           don't forget that ATT syntax is case sensitive
           for labels !! (PM) }
           token := AS_LABEL;
           { let us point to the next character }
           c := current_scanner^.asmgetchar;
           gettoken := token;
           exit;
      end;


      If is_asmopcode(upper(actasmpattern)) then
      Begin
       uppervar(actasmpattern);
       gettoken := AS_OPCODE;
       exit;
      end
      else
      if upper(actasmpattern) = 'END' then
      begin
         gettoken := AS_END;
         exit;
      end
      else
      begin
         gettoken := AS_NONE;
         Message(assem_e_invalid_operand);
      end;
    end
    else { else firsttoken }
    { Here we must handle all possible cases                              }
    begin
      case c of

         '.':   { possiblities : - local label reference , such as in jmp @local1 }
                {                - field of object/record                         }
                {                - directive.                                     }
                            begin
                             if previous_was_id then
                             begin
                                c:=current_scanner^.asmgetchar;
                                gettoken:=AS_DOT;
                                exit;
                             end;
                             actasmpattern := c;
                             c:= current_scanner^.asmgetchar;
                             while c in  ['A'..'Z','a'..'z','0'..'9','_','$'] do
                             begin
                               actasmpattern := actasmpattern + c;
                               c := current_scanner^.asmgetchar;
                             end;
                             is_asmdirective(actasmpattern,token);
                             { if directive }
                             if (token <> AS_NONE) then
                             begin
                               gettoken := token;
                               exit;
                             end;
                             { local label references and directives }
                             { are case sensitive                    }
                             gettoken := AS_ID;
                             exit;
                            end;
      { identifier, register, opcode, prefix or directive }
         '_','A'..'Z','a'..'z': begin
                             actasmpattern := c;
                             c:= current_scanner^.asmgetchar;
                             while c in  ['A'..'Z','a'..'z','0'..'9','_','$'] do
                             begin
                               actasmpattern := actasmpattern + c;
                               c := current_scanner^.asmgetchar;
                             end;
                             { pascal is not case sensitive!    }
                             { therefore variables which are    }
                             { outside the scope of the asm     }
                             { block, should not be made case   }
                             { sensitive...  !!!!!              }
                             uppervar(actasmpattern);

                             If is_asmopcode(actasmpattern) then
                             Begin
                                    gettoken := AS_OPCODE;
                                    exit;
                             end;
                             { we handle this directive separately from }
                             { others.                                  }
                             if actasmpattern = 'END' then
                             Begin
                                 gettoken := AS_END;
                                 exit;
                             end;

                             { if found }
                             if (token <> AS_NONE) then
                             begin
                               gettoken := token;
                               exit;
                             end
                             { this is surely an identifier }
                             else
                               token := AS_ID;
                             gettoken := token;
                             exit;
                          end;
           '&':       begin
                         c:=current_scanner^.asmgetchar;
                         gettoken := AS_AND;
                      end;
           { character }
           '''' :     begin
                         c:=current_scanner^.asmgetchar;
                         if c = '\' then
                         Begin
                           { escape sequence }
                           c:=current_scanner^.asmgetchar;
                           case c of
                         newline: Message(scan_f_string_exceeds_line);
                             't': actasmpattern:=#09;
                             'b': actasmpattern:=#08;
                             '\': actasmpattern:='\';
                             'f': actasmpattern:=#12;
                             'n': actasmpattern:=#10;
                             'r': actasmpattern:=#13;
                             '"': actasmpattern:='"';
                             { octal number }
                             '0'..'7':
                                begin
                                   temp:=c;
                                   temp:=temp+current_scanner^.asmgetchar;
                                   temp:=temp+current_scanner^.asmgetchar;
                                   val(octaltodec(temp),value,code);
                                   if (code <> 0) then
                                    Message1(assem_e_error_in_octal_const,temp);
                                   actasmpattern:=chr(value);
                                end;
                             { hexadecimal number }
                             'x':
                                 begin
                                   temp:=current_scanner^.asmgetchar;
                                   temp:=temp+current_scanner^.asmgetchar;
                                   val(hextodec(temp),value,code);
                                   if (code <> 0) then
                                    Message1(assem_e_error_in_hex_const,temp);
                                   actasmpattern:=chr(value);
                                 end;
                             else
                              Begin
                                Message(assem_e_escape_seq_ignored);
                                actasmpattern:=c;
                              end
                           end; { end case }
                         end
                         else
                           actasmpattern:=c;

                         gettoken := AS_STRING;
                         c:=current_scanner^.asmgetchar;
                         exit;

                      end;
           { string }
           '"' :
                      begin
                         actasmpattern:='';
                         while true do
                         Begin
                           c:=current_scanner^.asmgetchar;
                           case c of
                            '\': Begin
                                  { escape sequences }
                                  c:=current_scanner^.asmgetchar;
                                  case c of
                                   newline: Message(scan_f_string_exceeds_line);
                                   't': actasmpattern:=actasmpattern+#09;
                                   'b': actasmpattern:=actasmpattern+#08;
                                   '\': actasmpattern:=actasmpattern+'\';
                                   'f': actasmpattern:=actasmpattern+#12;
                                   'n': actasmpattern:=actasmpattern+#10;
                                   'r': actasmpattern:=actasmpattern+#13;
                                   '"': actasmpattern:=actasmpattern+'"';
                                   { octal number }
                                   '0'..'7':
                                      begin
                                           temp:=c;
                                           temp:=temp+current_scanner^.asmgetchar;
                                           temp:=temp+current_scanner^.asmgetchar;
                                           val(octaltodec(temp),value,code);
                                           if (code <> 0) then
                                            Message1(assem_e_error_in_octal_const,temp);
                                           actasmpattern:=actasmpattern+chr(value);
                                      end;
                                   { hexadecimal number }
                                   'x':
                                     begin
                                       temp:=current_scanner^.asmgetchar;
                                       temp:=temp+current_scanner^.asmgetchar;
                                       val(hextodec(temp),value,code);
                                       if (code <> 0) then
                                        Message1(assem_e_error_in_hex_const,temp);
                                       actasmpattern:=actasmpattern+chr(value);
                                     end;
                                   else
                                     Begin
                                       Message(assem_e_escape_seq_ignored);
                                       actasmpattern:=actasmpattern+c;
                                     end
                                   end; { end case }
                                 end;
                            '"': begin
                                  c:=current_scanner^.asmgetchar;
                                  break;
                                 end;
                            newline: Message(scan_f_string_exceeds_line);
                           else
                             actasmpattern:=actasmpattern+c;
                           end;
                         end; { end case }
                   token := AS_STRING;
                   gettoken := token;
                   exit;
                 end;
           '$' :  begin
                   gettoken := AS_DOLLAR;
                   c:=current_scanner^.asmgetchar;
                   exit;
                  end;
           ',' : begin
                   gettoken := AS_COMMA;
                   c:=current_scanner^.asmgetchar;
                   exit;
                 end;
           '<' : begin
                   gettoken := AS_SHL;
                   c := current_scanner^.asmgetchar;
                   if c = '<' then
                     c := current_scanner^.asmgetchar;
                   exit;
                 end;
           '>' : begin
                   gettoken := AS_SHL;
                   c := current_scanner^.asmgetchar;
                   if c = '>' then
                     c := current_scanner^.asmgetchar;
                   exit;
                 end;
           '|' : begin
                   gettoken := AS_OR;
                   c := current_scanner^.asmgetchar;
                   exit;
                 end;
           '^' : begin
                  gettoken := AS_XOR;
                  c := current_scanner^.asmgetchar;
                  exit;
                 end;
           '!' : begin
                  Message(assem_e_nor_not_supported);
                  c := current_scanner^.asmgetchar;
                  gettoken := AS_NONE;
                  exit;
                 end;
           '(' : begin
                   gettoken := AS_LPAREN;
                   c:=current_scanner^.asmgetchar;
                   exit;
                 end;
           ')' : begin
                   gettoken := AS_RPAREN;
                   c:=current_scanner^.asmgetchar;
                   exit;
                 end;
           ':' : begin
                   gettoken := AS_COLON;
                   c:=current_scanner^.asmgetchar;
                   exit;
                 end;
           '+' : begin
                   gettoken := AS_PLUS;
                   c:=current_scanner^.asmgetchar;
                   exit;
                 end;
           '-' : begin
                   gettoken := AS_MINUS;
                   c:=current_scanner^.asmgetchar;
                   exit;
                 end;
           '*' : begin
                   gettoken := AS_STAR;
                   c:=current_scanner^.asmgetchar;
                   exit;
                 end;
           '/' : begin
                   c:=current_scanner^.asmgetchar;
                   { att styled comment }
                   if c='/' then
                     begin
                        repeat
                           c:=current_scanner^.asmgetchar;
                        until c=newline;
                        firsttoken := TRUE;
                        gettoken:=AS_SEPARATOR;
                        c:=current_scanner^.asmgetchar;
                        exit;
                     end
                   else
                     begin
                        gettoken := AS_SLASH;
                        c:=current_scanner^.asmgetchar;
                        exit;
                     end;
                 end;
           { register or modulo      }
           { only register supported }
           { for the moment.         }
           '%' : begin
                     actasmpattern := c;
                     c:=current_scanner^.asmgetchar;
                     while c in ['a'..'z','A'..'Z','0'..'9'] do
                     Begin
                        actasmpattern := actasmpattern + c;
                        c:=current_scanner^.asmgetchar;
                     end;
                     token := AS_NONE;
                     uppervar(actasmpattern);
                     if (actasmpattern = '%ST') and (c='(') then
                     Begin
                        actasmpattern:=actasmpattern+c;
                        c:=current_scanner^.asmgetchar;
                        if c in ['0'..'9'] then
                          actasmpattern := actasmpattern + c
                        else
                          Message(assem_e_invalid_fpu_register);
                        c:=current_scanner^.asmgetchar;
                        if c <> ')' then
                          Message(assem_e_invalid_fpu_register)
                        else
                        Begin
                          actasmpattern := actasmpattern + c;
                          c:=current_scanner^.asmgetchar; { let us point to next character. }
                        end;
                     end;
                     is_register(actasmpattern, token);
                     { if found }
                     if (token <> AS_NONE) then
                     begin
                        gettoken := token;
                        exit;
                     end
                     else
                     begin
                       Message(assem_w_modulo_not_supported);
                       gettoken := AS_NONE;
                     end;
                 end;
           { integer number }
           '1'..'9': begin
                        actasmpattern := c;
                        c := current_scanner^.asmgetchar;
                        while c in ['0'..'9'] do
                          Begin
                             actasmpattern := actasmpattern + c;
                             c:= current_scanner^.asmgetchar;
                          end;
                        gettoken := AS_INTNUM;
                        exit;
                     end;
           '0': begin
                { octal,hexa,real or binary number. }
                 actasmpattern := c;
                 c:=current_scanner^.asmgetchar;
                 case upcase(c) of
                   { binary }
                   'B': Begin
                          c:=current_scanner^.asmgetchar;
                          while c in ['0','1'] do
                          Begin
                            actasmpattern := actasmpattern + c;
                            c := current_scanner^.asmgetchar;
                          end;
                          gettoken := AS_BINNUM;
                          exit;
                        end;
                   { real }
                   'D': Begin
                          c:=current_scanner^.asmgetchar;
                          { get ridd of the 0d }
                          if (c='+') or (c='-') then
                            begin
                               actasmpattern:=c;
                               c:=current_scanner^.asmgetchar;
                            end
                          else
                            actasmpattern:='';
                        while c in ['0'..'9'] do
                          Begin
                             actasmpattern := actasmpattern + c;
                             c:= current_scanner^.asmgetchar;
                          end;
                        if c='.' then
                          begin
                             actasmpattern := actasmpattern + c;
                             c:=current_scanner^.asmgetchar;
                             while c in ['0'..'9'] do
                               Begin
                                  actasmpattern := actasmpattern + c;
                                  c:= current_scanner^.asmgetchar;
                               end;
                             if upcase(c) = 'E' then
                               begin
                                  actasmpattern := actasmpattern + c;
                                  c:=current_scanner^.asmgetchar;
                                  if (c = '+') or (c = '-') then
                                    begin
                                       actasmpattern := actasmpattern + c;
                                       c:=current_scanner^.asmgetchar;
                                    end;
                                  while c in ['0'..'9'] do
                                    Begin
                                       actasmpattern := actasmpattern + c;
                                       c:= current_scanner^.asmgetchar;
                                    end;
                               end;
                             gettoken := AS_REALNUM;
                             exit;
                          end
                        else
                        begin
                            Message1(assem_e_invalid_float_const,actasmpattern+c);
                            gettoken:=AS_NONE;
                        end;
                        end;
                   { hexadecimal }
                   'X': Begin
                          c:=current_scanner^.asmgetchar;
                          while c in ['0'..'9','a'..'f','A'..'F'] do
                          Begin
                            actasmpattern := actasmpattern + c;
                            c := current_scanner^.asmgetchar;
                          end;
                          gettoken := AS_HEXNUM;
                          exit;
                        end;
                   { octal }
                   '1'..'7': begin
                               actasmpattern := actasmpattern + c;
                               while c in ['0'..'7'] do
                               Begin
                                 actasmpattern := actasmpattern + c;
                                 c := current_scanner^.asmgetchar;
                               end;
                               gettoken := AS_OCTALNUM;
                               exit;
                             end;
                    else { octal number zero value...}
                      Begin
                         gettoken := AS_OCTALNUM;
                         exit;
                      end;
                   end; { end case }
                end;
    '{',#13,newline,';' : begin
                            { the comment is read by asmgetchar }
                            c:=current_scanner^.asmgetchar;
                            firsttoken := TRUE;
                            gettoken:=AS_SEPARATOR;
                           end;
            else
             Begin
               Message(scan_f_illegal_char);
             end;

      end; { end case }
    end; { end else if }
  end;


  {---------------------------------------------------------------------}
  {                     Routines for the output                         }
  {---------------------------------------------------------------------}


  { looks for internal names of variables and routines }
  Function SearchDirectVar(var Instr: TInstruction; const hs:string;operandnum:byte): Boolean;
  var
    p : pai_external;
  Begin
     SearchDirectVar:=false;
     { search in the list of internals }
     p:=search_assembler_symbol(internals,hs,EXT_ANY);
       if p=nil then
         p:=search_assembler_symbol(externals,hs,EXT_ANY);
     if p<>nil then
       begin
         { get symbol name                                  }
         { free the memory before changing the symbol name. }
         if assigned(instr.operands[operandnum].ref.symbol) then
           FreeMem(instr.operands[operandnum].ref.symbol,
               length(instr.operands[operandnum].ref.symbol^)+1);
         instr.operands[operandnum].ref.symbol:=newpasstr(strpas(p^.name));
           case p^.exttyp of
             EXT_BYTE   : instr.operands[operandnum].size := S_B;
             EXT_WORD   : instr.operands[operandnum].size := S_W;
             EXT_NEAR,EXT_FAR,EXT_PROC,EXT_DWORD,EXT_CODEPTR,EXT_DATAPTR:
             instr.operands[operandnum].size := S_L;
             EXT_QWORD  : instr.operands[operandnum].size := S_FL;
             EXT_TBYTE  : instr.operands[operandnum].size := S_FX;
           else
             { this is in the case where the instruction is LEA }
             { or something like that, in that case size is not }
             { important.                                       }
               instr.operands[operandnum].size := S_NO;
           end;
         SearchDirectVar := TRUE;
         Exit;
       end;
  end;


   { returns an appropriate ao_xxxx flag indicating the type }
   { of operand.                                             }
   function findtype(Var Opr: TOperand): longint;
   Begin
    With Opr do
    Begin
     case operandtype of
       OPR_REFERENCE:   Begin
                           if assigned(ref.symbol) then
                           { check if in local label list }
                           { if so then it is considered  }
                           { as a displacement.           }
                           Begin
                             if labellist.search(ref.symbol^) <> nil then
                               findtype := ao_disp
                             else
                               findtype := ao_mem; { probably a mem ref. }
                           end
                           else
                            findtype := ao_mem;
                        end;
       OPR_CONSTANT: Begin
                       { check if there is not already a default size }
                       if opr.size <> S_NO then
                       Begin
                          findtype := _constsizes[opr.size];
                         exit;
                       end;
                       if val < $ff then
                       Begin
                         findtype := ao_imm8;
                         opr.size := S_B;
                       end
                       else if val < $ffff then
                       Begin
                         findtype := ao_imm16;
                         opr.size := S_W;
                       end
                       else
                       Begin
                         findtype := ao_imm32;
                         opr.size := S_L;
                       end
                     end;
       OPR_REGISTER: Begin
                      findtype := _regtypes[reg];
                      exit;
                     end;
       OPR_SYMBOL:     Begin
                       findtype := ao_jumpabsolute;
                     end;
       OPR_NONE:     Begin
                       findtype := 0;
                     end;
       else
       Begin
        Message(assem_f_internal_error_in_findtype);
       end;
     end;
    end;
   end;


   Procedure HandleExtend(var instr: TInstruction);
   { Handles MOVZX, MOVSX ... }
   var
     instruc: tasmop;
     opsize : topsize;
   Begin
      instruc:=instr.getinstruction;
      { if we have A_MOVZX/A_MOVSX here, there is a big problem }
      { it should never happen, because it is already replaced  }
      { by ConcatOpcode!                                        }
      Case instruc of
        A_MOVZX,A_MOVSX: Message(assem_f_internal_error_in_handleextend);
        A_MOVSB, A_MOVSBL:
          Begin
             instruc := A_MOVSX;
             { Indirect memory reference with register        }
             { no size determined, therefore we determine it  }
             { with the suffix.                               }
             if instr.operands[1].size = S_NO then
                instr.operands[1].size := S_B;
          end;
        A_MOVSBW:
          Begin
             instruc := A_MOVSX;
             { Indirect memory reference with register        }
             { no size determined, therefore we determine it  }
             { with the suffix.                               }
             if instr.operands[1].size = S_NO then
                instr.operands[1].size := S_B;
          end;
        A_MOVSWL:
          Begin
            instruc := A_MOVSX;
            { Indirect memory reference with register        }
            { no size determined, therefore we determine it  }
            { with the suffix.                               }
            if instr.operands[1].size = S_NO then
               instr.operands[1].size := S_W;
          end;
        A_MOVZB:
          Begin
            instruc := A_MOVZX;
             { Indirect memory reference with register        }
             { no size determined, therefore we determine it  }
             { with the suffix.                               }
             if instr.operands[1].size = S_NO then
                instr.operands[1].size := S_B;
          end;
        A_MOVZWL:
          Begin
            instruc := A_MOVZX;
             { Indirect memory reference with register        }
             { no size determined, therefore we determine it  }
             { with the suffix.                               }
             if instr.operands[1].size = S_NO then
                instr.operands[1].size := S_W;
          end;
      End;

      With instr do
         Begin
           if operands[1].size = S_B then
           Begin
              if operands[2].size = S_L then
                 opsize := S_BL
              else
              if operands[2].size = S_W then
                 opsize := S_BW
              else
              begin
                 Message(assem_e_invalid_size_movzx);
                 exit;
              end;
           end
           else
           if operands[1].size = S_W then
           Begin
             if operands[2].size = S_L then
                opsize := S_WL
             else
             begin
                 Message(assem_e_invalid_size_movzx);
                 exit;
             end;
           end
           else
           begin
                 Message(assem_e_invalid_size_movzx);
                 exit;
           end;

           if operands[1].operandtype = OPR_REGISTER then
           Begin
              if operands[2].operandtype <> OPR_REGISTER then
                 Message(assem_e_invalid_opcode) { exit...}
              else
                 p^.concat(new(pai386,op_reg_reg(instruc,opsize,
                   operands[1].reg,operands[2].reg)));
           end
           else
           if operands[1].operandtype = OPR_REFERENCE then
           Begin
              if operands[2].operandtype <> OPR_REGISTER then
                 Message(assem_e_invalid_opcode) {exit...}
              else
                 p^.concat(new(pai386,op_ref_reg(instruc,opsize,
                   newreference(operands[1].ref),operands[2].reg)));
           end
     end; { end with }
   end;


  Procedure ConcatOpCode(var instr: TInstruction);
  {*********************************************************************}
  { First Pass:                                                         }
  {    - If this is a three operand opcode:                             }
  {          imul,shld,and shrd  -> check them manually.                }
  {*********************************************************************}
  var
    fits : boolean;
    i: longint;
    opsize: topsize;
    optyp1, optyp2, optyp3: longint;
    instruc: tasmop;
    href   : treference;
  Begin
    fits := FALSE;
     for i:=1 to instr.numops do
     Begin
       case instr.operands[i].operandtype of
         OPR_REGISTER: instr.operands[i].size :=
                         _regsizes[instr.operands[i].reg];
       end; { end case }
     end; { endif }
    { setup specific instructions for first pass }
    instruc := instr.getinstruction;

    Case instruc Of
      A_LEA,A_LDS,A_LSS,A_LES,A_LFS,A_LGS:
        Begin
          if instr.operands[2].size <> S_L then
            Begin
              Message(assem_e_16bit_base_in_32bit_segment);
              exit;
            end; { endif }
        end;
    End;

    With instr do
    Begin


      for i:=1 to numops do
      Begin
        With operands[i] do
        Begin
        { check for 16-bit bases/indexes and emit an error.   }
        { we cannot only emit a warning since gas does not    }
        { accept 16-bit indexes and bases.                    }
         if (operandtype = OPR_REFERENCE) and
           ((ref.base <> R_NO) or
           (ref.index <> R_NO)) then
           Begin
           { index or base defined. }
             if (ref.base <> R_NO) then
             Begin
               if not (ref.base in
                 [R_EAX,R_EBX,R_ECX,R_EDX,R_EBP,R_ESI,R_EDI,R_ESP]) then
                   Message(assem_e_16bit_base_in_32bit_segment);
             end;
           { index or base defined. }
             if (ref.index <> R_NO) then
             Begin
                 if not (ref.index in
                   [R_EAX,R_EBX,R_ECX,R_EDX,R_EBP,R_ESI,R_EDI,R_ESP]) then
                  Message(assem_e_16bit_index_in_32bit_segment);
             end;
           end;
           { Check for constants without bases/indexes in memory }
           { references.                                         }
           { Update: allow constant references under Go32v2, to  }
           { access data in the bios data segmement (JM)         }
{$ifndef Go32v2}
           if (operandtype = OPR_REFERENCE) and
              (ref.base = R_NO) and
              (ref.index = R_NO) and
              (ref.symbol = nil) and
              (ref.offset <> 0) then
              Begin
                ref.isintvalue := TRUE;
                Message(assem_e_const_ref_not_allowed);
              end;
{$endif Go32v2}
              opinfo := findtype(operands[i]);
          end; { end with }
     end; {endfor}


      { TAKE CARE OF SPECIAL OPCODES, TAKE CARE OF THEM INDIVUALLY.    }
      { ALL THE REST ARE TAKEN CARE BY OPCODE TABLE AND THIRD PASS.    }
      { is this right for ratti386 ? (PM) }
      { almost... here we check for the size of registers and references }
      { to determine the correct gas opcode to use, because if the token }
      { is A_MOVSX or A_MOVZX then that means that the person forgot to  }
      { specify the size..                                               }
      { if memory size is not specified, will of course give out an error}
      Case instruc Of
        A_MOVSX:
          Begin
            if numops = 2 then
              begin
                if stropsize = S_BL then
                  begin
                    operands[1].size := S_B;
                    stropsize := S_NO;
                    operands[2].size := S_L;
                    addinstr(A_MOVSBL)
                  end
                else
                  if stropsize = S_WL then
                    begin
                      operands[1].size := S_W;
                      stropsize := S_NO;
                      operands[2].size := S_L;
                      addinstr(A_MOVSWL)
                    end
                  else
                    if stropsize = S_BW then
                      begin
                        operands[1].size := S_B;
                        stropsize := S_NO;
                        operands[2].size := S_W;
                        addinstr(A_MOVSBW)
                      end
                    else
                      if (operands[1].size = S_B) and
                         (operands[2].size = S_W) then
                        addinstr(A_MOVSBW)
                      else
                        if (operands[1].size = S_B) and
                           (operands[2].size = S_L) then
                          addinstr(A_MOVSBL)
                        else
                          if (operands[1].size = S_W) and
                             (operands[2].size = S_L) then
                            addinstr(A_MOVSWL)
                          else
                            begin
                              Message(assem_e_invalid_size_movzx);
                              exit;
                            end;
                instruc := getinstruction; { reload instruction }
              end
            else
              begin
                Message(assem_e_too_many_operands);
                exit;
              end;
          end;
        A_MOVZX:
          Begin
            if numops = 2 then
              Begin
                if stropsize = S_BW then
                  begin
                    operands[1].size := S_B;
                    stropsize := S_NO;
                    operands[2].size := S_W;
                    addinstr(A_MOVZB)
                  end
                else
                  if stropsize = S_BL then
                    begin
                      operands[1].size := S_B;
                      stropsize := S_NO;
                      operands[2].size := S_L;
                      addinstr(A_MOVZB)
                    end
                  else
                    if stropsize = S_WL then
                      begin
                        operands[1].size := S_W;
                        stropsize := S_NO;
                        operands[2].size := S_L;
                        addinstr(A_MOVZWL)
                      end
                    else
          { change the instruction to conform to GAS }
                      if (operands[1].size = S_B) and
                         (operands[2].size in [S_W,S_L]) then
                        addinstr(A_MOVZB)
                      else
                        if (operands[1].size = S_W) and
                           (operands[2].size = S_L) then
                          addinstr(A_MOVZWL)
                        else
                          begin
                            Message(assem_e_invalid_size_movzx);
                            exit;
                          end;
                instruc := getinstruction;  { reload instruction }
              end
            else
              Begin
                Message(assem_e_too_many_operands);
                exit;
              end;
          end;
        A_FWAIT: FWaitWarning;
        A_BT,A_BTC,A_BTR,A_BTS:
          Begin
            if numops = 2 then
              Begin
                if (operands[1].operandtype = OPR_CONSTANT)
                   and (operands[1].val <= $ff) then
                  Begin
                    operands[1].opinfo := ao_imm8;
                    { no operand size if using constant. }
                    operands[1].size := S_NO;
                    fits := TRUE;
                  end
              end
            else
              Begin
                Message(assem_e_invalid_opcode_and_operand);
                exit;
              end;
          end;
        A_ENTER:
          Begin
            if numops =2 then
              Begin
                if (operands[1].operandtype = OPR_CONSTANT) and
                   (operands[1].val <= $ffff) then
                  Begin
                    operands[1].opinfo := ao_imm16;
                  end  { endif }
              end { endif }
            else
              Begin
                Message(assem_e_invalid_opcode_and_operand);
                exit;
              end
          end;
    {  Handle special opcodes for the opcode   }
    {  table. Set them up correctly.           }
        A_INS,A_IN:
          Begin
            if numops =2 then
              Begin
                if (operands[1].operandtype = OPR_REGISTER) and
                   (operands[1].reg = R_DX) then
                  Begin
                    operands[1].opinfo := ao_inoutportreg;
                    if (operands[2].operandtype = OPR_REGISTER) and
                       (operands[2].reg in [R_EAX,R_AX,R_AL]) and
                       (instruc = A_IN) then
                      Begin
                        operands[2].opinfo := ao_acc;
                        case operands[2].reg of
                          R_EAX: operands[2].size := S_L;
                          R_AX:  operands[2].size := S_W;
                          R_AL:  operands[2].size := S_B;
                        end;
                      end
                  end
                else
                  if (operands[1].operandtype = OPR_CONSTANT) and
                     (operands[1].val <= $ff) And
                     (instruc = A_IN) then
                    Begin
                      operands[1].opinfo := ao_imm8;
                      operands[1].size := S_B;
                      if (operands[2].operandtype = OPR_REGISTER) and
                         (operands[2].reg in [R_EAX,R_AX,R_AL]) and
                         (instruc = A_IN) then
                        Begin
                          operands[2].opinfo := ao_acc;
                        end
                    end;
              end
            else
              Begin
                Message(assem_e_invalid_opcode_and_operand);
                exit;
              end;
          end;
        A_OUTS,A_OUT:
          Begin
            if numops =2 then
              Begin
                if (operands[2].operandtype = OPR_REGISTER) and
                   (operands[2].reg = R_DX) then
                  Begin
                    operands[2].opinfo := ao_inoutportreg;
                    if (operands[1].operandtype = OPR_REGISTER) and
                       (operands[1].reg in [R_EAX,R_AX,R_AL]) and
                       (instruc = A_OUT) then
                      Begin
                        operands[1].opinfo := ao_acc;
                        fits := TRUE;
                      end
                  end
                else
                  if (operands[2].operandtype = OPR_CONSTANT) and
                     (operands[2].val <= $ff) and
                     (instruc = A_OUT) then
                    Begin
                      operands[2].opinfo := ao_imm8;
                      operands[2].size := S_B;
                      if (operands[1].operandtype = OPR_REGISTER) and
                         (operands[1].reg in [R_EAX,R_AX,R_AL]) and
                         (instruc = A_OUT) then
                        Begin
                          operands[1].opinfo := ao_acc;
                          fits := TRUE;
                        end
                    end;
              end
            else
              Begin
                Message(assem_e_invalid_opcode_and_operand);
                exit;
              end;
          end;
        A_RCL,A_RCR,A_ROL,A_ROR,A_SAL,A_SAR,A_SHL,A_SHR:
          Begin
            if numops =2 then
              Begin
                if (operands[1].operandtype = OPR_REGISTER) and
                   (operands[1].reg = R_CL) then
                  Begin
                    operands[1].opinfo := ao_shiftcount
                  end
                else
                  if (operands[1].operandtype = OPR_CONSTANT) and
                     (operands[1].val <= $ff) then
                    Begin
                      operands[1].opinfo := ao_imm8;
                      operands[1].size := S_B;
                    end;
              end
            else { if numops = 2 }
              Begin
                Message(assem_e_invalid_opcode_and_operand);
                exit;
              end;
          end;
      { this did not work  (PM) }
        A_DIV, A_IDIV:
          Begin
            if (operands[2].operandtype = OPR_REGISTER) and
               (operands[2].reg in [R_AL,R_AX,R_EAX]) then
              operands[2].opinfo := ao_acc;
          end;
        A_FNSTSW, A_FSTSW:
          Begin
        { %ax can be omitted in ATT syntax }
            if numops = 0 then
              Begin
                numops:=1;
                operands[1].operandtype:=OPR_REGISTER;
                operands[1].reg:=R_AX;
                operands[1].opinfo := ao_acc;
              end
            else
              if numops = 1 then
                Begin
                  if (operands[1].operandtype = OPR_REGISTER) and
                     (operands[1].reg = R_AX) then
                    operands[1].opinfo := ao_acc;
                end
              else
                Begin
                  Message(assem_e_invalid_opcode_and_operand);
                  exit;
                end;
          end;
        A_SHLD,A_SHRD:
      { these instruction are fully parsed individually on pass three }
      { so we just do a summary checking here.                        }
          Begin
            if numops = 3 then
              Begin
                if (operands[1].operandtype = OPR_CONSTANT) and
                   (operands[1].val <= $ff) then
                  Begin
                    operands[1].opinfo := ao_imm8;
                    operands[1].size := S_B;
                  end;
              end
            else
              Begin
                Message(assem_e_invalid_opcode_and_operand);
                exit;
              end;
          end;
        A_INT:
          Begin
            if numops = 1 then
              Begin
                if (operands[1].operandtype = OPR_CONSTANT) and
                   (operands[1].val <= $ff) then
                    operands[1].opinfo := ao_imm8;
              end
          end;
        A_RET:
          Begin
            if numops =1 then
              Begin
                if (operands[1].operandtype = OPR_CONSTANT) and
                   (operands[1].val <= $ffff) then
                  operands[1].opinfo := ao_imm16;
              end
          end;
       { all string instructions have default memory }
       { location which are ignored. Take care of    }
       { those.                                      }
       { Here could be added the code for segment    }
       { overrides.                                  }
        A_SCAS,A_CMPS,A_STOS,A_LODS:
          Begin
            if numops =1 then
              Begin
                if (operands[1].operandtype = OPR_REFERENCE) and
                   (assigned(operands[1].ref.symbol)) then
                  Freemem(operands[1].ref.symbol,length(operands[1].ref.symbol^)+1);
                operands[1].operandtype := OPR_NONE;
                numops := 0;
              end;
          end;
        A_XLAT:
          Begin
       { handle special TP syntax case for XLAT }
       { here we accept XLAT, XLATB and XLAT m8 }
            if (numops = 1) or (numops = 0) then
              Begin
                if (operands[1].operandtype = OPR_REFERENCE) and
                   (assigned(operands[1].ref.symbol)) then
                  Freemem(operands[1].ref.symbol,length(operands[1].ref.symbol^)+1);
                operands[1].operandtype := OPR_NONE;
                numops := 0;
              { always a byte for XLAT }
                instr.stropsize := S_B;
              end;
          end;
     { ------------------------------------------------------------------- }
     { ------------------------- SIZE CHECK ------------------------------ }
     { ------------- presently done only for most used opcodes  ---------- }
     {  Checks if the suffix concords with the destination size    , if    }
     {  not gives out an error. (This check is stricter then gas but is    }
     {  REQUIRED for intasmi3)                                             }
        A_MOV,A_ADD,A_SUB,A_ADC,A_SBB,A_CMP,A_AND,A_OR,A_TEST,A_XOR:
          begin
            if (instr.stropsize <> S_NO) and
               (instr.operands[2].size <> S_NO) then
              if (instr.stropsize <> instr.operands[2].size) then
                begin
                  Message(assem_e_size_suffix_and_dest_reg_dont_match);
                  exit;
                end;
          end;
        A_DEC,A_INC,A_NOT,A_NEG:
          begin
            if (instr.stropsize <> S_NO) and
               (instr.operands[1].size <> S_NO) then
              if (instr.stropsize <> instr.operands[1].size) then
                begin
                  Message(assem_e_size_suffix_and_dest_reg_dont_match);
                  exit;
                end;
          end;
        A_PUSH:
          Begin
            if (instr.operands[1].operandtype = OPR_CONSTANT) and
               (instr.stropsize = S_NO) then
              Message(assem_e_size_suffix_and_dest_reg_dont_match);
          end;
      End; { case }

   {we have to start a new case because A_INS etc are already handled before
    as well... (JM)}

      Case instruc of
        A_INS,A_MOVS,A_OUTS:
          Begin
            if numops =2 then
              Begin
                if (operands[2].operandtype = OPR_REFERENCE) and
                   (assigned(operands[2].ref.symbol)) then
                  Freemem(operands[2].ref.symbol,length(operands[2].ref.symbol^)+1);
                if (operands[1].operandtype = OPR_REFERENCE) and
                   (assigned(operands[1].ref.symbol)) then
                  Freemem(operands[1].ref.symbol,length(operands[2].ref.symbol^)+1);
                operands[2].operandtype := OPR_NONE;
                operands[1].operandtype := OPR_NONE;
                numops := 0;
              end;
          end;
     { handle parameter for segment overrides }
      end; { case }
    { ------------------------------------------------------------------- }

    { copy them to local variables }
    { for faster access            }
    optyp1:=operands[1].opinfo;
    optyp2:=operands[2].opinfo;
    optyp3:=operands[3].opinfo;

    end; { end with }

    { after reading the operands }
    { search the instruction     }
    { setup startvalue from cache }
    if ins_cache[instruc]<>-1 then
       i:=ins_cache[instruc]
    else i:=0;

    { I think this is too dangerous for me therefore i decided that for }
    { the att version only if the processor > i386 or we are compiling  }
    { the system unit then this will be allowed...                      }
    if (instruc > lastop_in_table) then
      begin
         Message1(assem_w_opcode_not_in_table,upper(att_op2str[instruc]));
         fits:=true;
      end
    else while not(fits) do
      begin
       { set the instruction cache, if the instruction }
       { occurs the first time                         }
       if (it[i].i=instruc) and (ins_cache[instruc]=-1) then
           ins_cache[instruc]:=i;

       if (it[i].i=instruc) and (instr.numops=it[i].ops) then
       begin
          { first fit }
          case instr.numops of
          0 : begin
                 fits:=true;
                 break;
              end;
          1 :
              Begin
                if (optyp1 and it[i].o1)<>0 then
                Begin
                   fits:=true;
                   break;
                end;
                { I consider sign-extended 8bit value to }
                { be equal to immediate 8bit therefore   }
                { convert...                             }
                if (optyp1 = ao_imm8) then
                Begin
                  { check if this is a simple sign extend. }
                  if (it[i].o1<>ao_imm8s) then
                  Begin
                    fits:=true;
                    break;
                  end;
                end;
              end;
          2 : if ((optyp1 and it[i].o1)<>0) and
               ((optyp2 and it[i].o2)<>0) then
               Begin
                     fits:=true;
                     break;
               end
               { if the operands can be swaped }
               { then swap them                }
               else if ((it[i].m and af_d)<>0) and
               ((optyp1 and it[i].o2)<>0) and
               ((optyp2 and it[i].o1)<>0) then
               begin
                 fits:=true;
                 break;
               end;
          3 : if ((optyp1 and it[i].o1)<>0) and
               ((optyp2 and it[i].o2)<>0) and
               ((optyp3 and it[i].o3)<>0) then
               Begin
                 fits:=true;
                 break;
               end;
          end; { end case }
       end; { endif }
       if it[i].i=A_NONE then
       begin
         { NO MATCH! }
         Message(assem_e_invalid_opcode_and_operand);
         exit;
       end;
       inc(i);
      end; { end while }

  { We add the opcode to the opcode linked list }
  if fits then
  Begin
    if instr.getprefix <> A_NONE then
    Begin
      p^.concat(new(pai386,op_none(instr.getprefix,S_NO)));
    end;
    { change from AT&T styled floating point to   }
    { intel styled floating point with valid size }
    { we use these instructions so it does not    }
    { mess up intasmi3                            }
    if (instruc >= A_FILDQ) and (instruc <= A_FIDIVRS) then
    Begin
      instr.stropsize := _fpusizes[instruc];
      instr.addinstr(_fpuopcodes[instruc]);
      instruc := instr.getinstruction;
    end;

    case instr.numops of
     0:
        if instr.stropsize <> S_NO then
        { is this a string operation opcode or xlat then check }
        { the size of the operation.                           }
          p^.concat(new(pai386,op_none(instruc,instr.stropsize)))
        else
          p^.concat(new(pai386,op_none(instruc,S_NO)));
     1: Begin
          case instr.operands[1].operandtype of
              { GAS requires that the size be set in the case of a push }
              { constant value,                                         }
           OPR_CONSTANT:
              Begin
                 if instruc = A_PUSH then
                   Begin
                      if instr.stropsize <> S_NO then
                         p^.concat(new(pai386,op_const(instruc,
                              instr.stropsize, instr.operands[1].val)))
                      else
                        Message(assem_e_invalid_opcode_and_operand);
                   end
                 else
                   p^.concat(new(pai386,op_const(instruc,
                      S_NO, instr.operands[1].val)));
              end;
           OPR_REGISTER:
             Begin
                if (instr.stropsize<>S_NO) then
                 opsize:=instr.stropsize
                else
                 opsize:=instr.operands[1].size;
                p^.concat(new(pai386,op_reg(instruc,opsize,instr.operands[1].reg)));
             End;
           OPR_SYMBOL:
             Begin
                p^.concat(new(pai386,op_csymbol(instruc,
                  instr.stropsize, newcsymbol(instr.operands[1].symbol^,0))));
             End;
           OPR_REFERENCE:
             { now first check suffix ... }
             if instr.stropsize <> S_NO then
               Begin
                  p^.concat(new(pai386,op_ref(instruc,
                    instr.stropsize,newreference(instr.operands[1].ref))));
               end
               { no suffix... therefore resort using intel styled checking .. }
             else if (instr.operands[1].size <> S_NO) and
                  Not ((instruc = A_CALL) or (instruc = A_JMP)) then
               Begin
                  p^.concat(new(pai386,op_ref(instruc,
                    instr.operands[1].size,newreference(instr.operands[1].ref))));
               end
             else
               Begin
                  { special jmp and call case with }
                  { symbolic references.           }
                  Case instruc of
                    A_CALL,A_JMP,A_FNSTCW,A_FSTCW,A_FLDCW,A_FNSTSW,
                    A_FSTSW,A_FLDENV,A_FSTENV,A_FNSAVE,A_FSAVE:
                      Begin
                        p^.concat(new(pai386,op_ref(instruc,
                          S_NO,newreference(instr.operands[1].ref))));
                      end
                    else
                      Message(assem_e_invalid_opcode_and_operand);
                  End
               end;
{ This either crashed the compiler or the symbol would always be nil! }
{ The problem is here is I didn't see any way of adding the labeled   }
{ symbol in the internal list, since i think from what i see in aasm  }
{ that these will automatically be declared as external ??            }

{ note: has to be changed to a case if ever activated again to avoid  }
{       range problems (JM)                                           }

{                              if (instruc in [A_JO,A_JNO,A_JB,A_JC,A_JNAE,
                                A_JNB,A_JNC,A_JAE,A_JE,A_JZ,A_JNE,A_JNZ,A_JBE,A_JNA,A_JNBE,
                                A_JA,A_JS,A_JNS,A_JP,A_JPE,A_JNP,A_JPO,A_JL,A_JNGE,A_JNL,A_JGE,
                                A_JLE,A_JNG,A_JNLE,A_JG,A_JCXZ,A_JECXZ,A_LOOP,A_LOOPZ,A_LOOPE,
                                A_LOOPNZ,A_LOOPNE,A_JMP,A_CALL]) then
                              Begin
                                if assigned(instr.operands[1].ref.symbol) then
                                   p^.concat(new(pai386,op_csymbol(instruc,
                                     S_NO,newcsymbol(instr.operands[1].ref.symbol^,instr.operands[1].ref.offset))))
                                else
                                  Message(assem_e_invalid_opcode_and_operand);
                              end
                              else
                              else
                                Message(assem_e_invalid_opcode_and_operand);
                          end;}
           OPR_NONE: Begin
                       Message(assem_f_internal_error_in_concatopcode);
                     end;
          else
           Begin
             Message(assem_f_internal_error_in_concatopcode);
           end;
          end;
        end;
     2:
        Begin
           Case instruc Of
             A_MOVSX,A_MOVZX,A_MOVSB,A_MOVSBL,A_MOVSBW,A_MOVSWL,
             A_MOVZB,A_MOVZWL:
               { movzx and movsx }
               HandleExtend(instr);
             else
             { other instructions }
               Begin
                 With instr do
                   Begin
                { source }
                     opsize := operands[1].size;
                     case operands[1].operandtype of
                     { reg,reg     }
                     { reg,ref     }
                     { const,reg -- IN/OUT }
                       OPR_REGISTER:
                         Begin
                           case operands[2].operandtype of
                             OPR_REGISTER:
                              { correction: according to the DJGPP FAQ, gas }
                              { doesn't even check correctly the size of    }
                              { operands, therefore let us specify a size!  }
                              { as in the GAS docs... destination tells us  }
                              { the size! This might give out invalid output }
                              { in some very rare cases (because the size   }
                              { checking is still not perfect).             }
                               if (opsize = operands[2].size) then
                                 begin
                                   p^.concat(new(pai386,op_reg_reg(instruc,
                                   opsize,operands[1].reg,operands[2].reg)));
                                 end
                               else
                               Case instruc of
                                 A_IN:
                                   p^.concat(new(pai386,op_reg_reg(instruc,
                                     operands[2].size,operands[1].reg,operands[2].reg)));
                                 A_OUT:
                                   p^.concat(new(pai386,op_reg_reg(instruc,
                                     operands[1].size,operands[1].reg,operands[2].reg)));
                            { these do not require any size specification. }
                                 A_SAL,A_SAR,A_SHL,A_SHR,A_ROL,A_ROR,A_RCR,
                                 A_RCL:
                               { outs and ins are already taken care by }
                               { the first pass.                        }
                                   p^.concat(new(pai386,op_reg_reg(instruc,
                                     S_NO,operands[1].reg,operands[2].reg)))
                                 else
                                   if stropsize <> S_NO then
                                     Begin
                                       p^.concat(new(pai386,op_reg_reg(instruc,
                                         stropsize,operands[1].reg,operands[2].reg)))
                                     end
                                   else
                                     Begin
                                       Message(assem_e_invalid_opcode_and_operand);
                                     end;
                               end; {case instruc of}
                             OPR_REFERENCE:
                           { variable name. }
                           { here we must check the instruction type }
                           { before deciding if to use and compare   }
                           { any sizes.                              }
                              if assigned(operands[2].ref.symbol) then
                                Begin
                                 if stropsize <> S_NO then
                                   Begin
                                     p^.concat(new(pai386,op_reg_ref(instruc,
                                       stropsize,operands[1].reg,newreference(operands[2].ref))))
                                   end
                                 else
                                   if (opsize = operands[2].size) Then
                                     p^.concat(new(pai386,op_reg_ref(instruc,
                                       opsize,operands[1].reg,newreference(operands[2].ref))))
                                 else
                                   Case instruc of
                                     A_RCL,A_RCR,A_ROL,A_ROR,A_SAL,A_SAR,
                                     A_SHR,A_SHL:
                                       p^.concat(new(pai386,op_reg_ref(instruc,
                                         opsize,operands[1].reg,newreference(operands[2].ref))))
                                     else
                                       Message(assem_e_invalid_size_in_ref);
                                   end
                                end
                              else
                                Begin
                                 { register reference }
                                  if stropsize <> S_NO then
                                    Begin
                                      p^.concat(new(pai386,op_reg_ref(instruc,
                                        stropsize,operands[1].reg,newreference(operands[2].ref))))
                                    end
                                  else
                                  if (opsize = operands[2].size) or
                                     (operands[2].size = S_NO) then
                                    p^.concat(new(pai386,op_reg_ref(instruc,
                                      opsize,operands[1].reg,newreference(operands[2].ref))))
                                  else
                                    Message(assem_e_invalid_size_in_ref);
                                end;
                             OPR_CONSTANT:  { OUT }
                               begin
                                 { determine first with suffix }
                                if instruc = A_OUT then
                                  begin
                                    if instr.stropsize <> S_NO then
                                      p^.concat(new(pai386,op_reg_const(instruc,stropsize,
                                        instr.operands[1].reg, instr.operands[2].val)))
                                   else
                                      p^.concat(new(pai386,op_reg_const(instruc,S_NO,
                                        instr.operands[1].reg, instr.operands[2].val)));
                                  end
                                else
                                  Message(assem_e_invalid_opcode);
                               end;
                             else { else case }
                               Begin
                                 Message(assem_f_internal_error_in_concatopcode);
                              end;
                           end; { end inner case }
                         end;
                  { const,reg   }
                  { const,const }
                  { const,ref   }
                       OPR_CONSTANT:
                         case instr.operands[2].operandtype of
                       { constant, constant does not have a specific size. }
                           OPR_CONSTANT:
                             p^.concat(new(pai386,op_const_const(instruc,
                               S_NO,operands[1].val,operands[2].val)));
                           OPR_REFERENCE:
                             Begin
                              { check for suffix first ... }
                               if (instr.stropsize <> S_NO) then
                                 Begin
                                   p^.concat(new(pai386,op_const_ref(instruc,
                                     stropsize,operands[1].val,
                                   newreference(operands[2].ref))))
                                 end
                               else
                           { resort to intel styled checking ... }
                                 if (operands[1].val <= $ff) and
                                    (operands[2].size in [S_B,S_W,S_L]) then
                                   p^.concat(new(pai386,op_const_ref(instruc,
                                     operands[2].size,operands[1].val,
                                     newreference(operands[2].ref))))
                               else
                                 if (operands[1].val <= $ffff) and
                                    (operands[2].size in [S_W,S_L]) then
                                   p^.concat(new(pai386,op_const_ref(instruc,
                                     operands[2].size,operands[1].val,
                                     newreference(operands[2].ref))))
                               else
                                 if (operands[1].val <= $7fffffff) and
                                    (operands[2].size in [S_L]) then
                                   p^.concat(new(pai386,op_const_ref(instruc,
                                     operands[2].size,operands[1].val,
                                     newreference(operands[2].ref))))
                               else
                                 Message(assem_e_invalid_size_in_ref);
                             end;
                           OPR_REGISTER:
                             Begin
                              { size of opcode determined by register }
                              if (operands[1].val <= $ff) and
                                 (operands[2].size in [S_B,S_W,S_L]) then
                                p^.concat(new(pai386,op_const_reg(instruc,
                                  operands[2].size,operands[1].val,
                                  operands[2].reg)))
                              else
                               if (operands[1].val <= $ffff) and
                                  (operands[2].size in [S_W,S_L]) then
                                 p^.concat(new(pai386,op_const_reg(instruc,
                                   operands[2].size,operands[1].val,
                                   operands[2].reg)))
                              else
                               if (operands[1].val <= $7fffffff) and
                                  (operands[2].size in [S_L]) then
                                 p^.concat(new(pai386,op_const_reg(instruc,
                                   operands[2].size,operands[1].val,
                                   operands[2].reg)))
                              else
                               Message(assem_e_invalid_opcode_size);
                             end;
                           else
                             Begin
                               Message(assem_f_internal_error_in_concatopcode);
                             end;
                         end; { end case }
                    { sym,reg     }
                       OPR_SYMBOL:
                         case instr.operands[2].operandtype of
                           OPR_REGISTER:
                             Begin
                               Case instruc of
                                 A_LDS,A_LES,A_LFS,A_LGS,A_LSS:
                                   opsize:=S_NO
                                 else
                                  if stropsize<>S_NO then
                                    opsize:=stropsize
                                 else
                                   if (opsize<>operands[2].size) then
                                     Message(assem_e_invalid_opcode_and_operand);
                              { create an temporary reference }
                               End; {case}
                               reset_reference(href);
                               href.symbol:=stringdup(instr.operands[1].symbol^);
                               p^.concat(new(pai386,op_ref_reg(instruc,opsize,
                                 newreference(href),operands[2].reg)));
                               clear_reference(href);
                             end;
                           else
                             Begin
                               Message(assem_f_internal_error_in_concatopcode);
                             end;
                         end; { end inner case }
                   { ref,reg     }
                   { ref,ref     }
                       OPR_REFERENCE:
                         case instr.operands[2].operandtype of
                           OPR_REGISTER:
                             if assigned(operands[1].ref.symbol) then
                            { global variable }
                               Begin
                                 Case instruc Of
                                   A_LDS,A_LES,A_LFS,A_LGS,A_LSS:
                                     opsize:=S_NO
                                   else
                                    if stropsize<>S_NO then
                                      opsize:=stropsize
                                    else
                                    if (opsize<>operands[2].size) then
                                      Message(assem_e_invalid_opcode_and_operand);
                                 end; { case }
                                 p^.concat(new(pai386,op_ref_reg(instruc,
                                   opsize,newreference(operands[1].ref),operands[2].reg)));
                               end
                             else
                               Begin
                              { register reference }
                              { possiblities:1) local variable which }
                              { has been replaced by bp and offset   }
                              { in this case size should be valid    }
                              {              2) Indirect register    }
                              { adressing, 2nd operand determines    }
                              { size.                                }
                                if (stropsize <> S_NO) then
                                  Begin
                                    p^.concat(new(pai386,op_ref_reg(instruc,
                                      stropsize,newreference(operands[1].ref),
                                      operands[2].reg)))
                                  end
                                else
                                 if (opsize = operands[2].size) or
                                    (opsize = S_NO) then
                                   Begin
                                     p^.concat(new(pai386,op_ref_reg(instruc,
                                       operands[2].size,newreference(operands[1].ref),
                                       operands[2].reg)));
                                   end
                                else
                                  Message(assem_e_invalid_size_in_ref);
                               end;
                           OPR_REFERENCE: { special opcodes }
                             p^.concat(new(pai386,op_ref_ref(instruc,
                               opsize,newreference(operands[1].ref),
                               newreference(operands[2].ref))));
                           else
                             Begin
                               Message(assem_f_internal_error_in_concatopcode);
                             end;
                         end; { end inner case }
                     end; { end case }
                   end; { end with }
               end; {end else of case instruc of movsx ... }
           end; { end case movsx ...}
        end;
     3: Begin
             { only imul, shld and shrd  }
             { middle must be a register }
           if (instruc = A_SHLD) Or (instruc = A_SHRD) and
              (instr.operands[2].operandtype = OPR_REGISTER) then
             Begin
               case instr.operands[2].size of
                S_W:  if instr.operands[1].operandtype = OPR_CONSTANT then
                        Begin
                          if instr.operands[1].val <= $ff then
                            Begin
                              if instr.operands[3].size in [S_W] then
                              Begin
                                 case instr.operands[3].operandtype of
                                  OPR_REFERENCE: { MISSING !!!! } ;
                                  OPR_REGISTER:  p^.concat(new(pai386,
                                     op_const_reg_reg(instruc, S_W,
                                     instr.operands[1].val, instr.operands[2].reg,
                                     instr.operands[3].reg)));
                                 else
                                    Message(assem_e_invalid_opcode_and_operand);
                                 end;
                              end
                              else
                                 Message(assem_e_invalid_opcode_and_operand);
                            end;
                        end
                      else
                        Message(assem_e_invalid_opcode_and_operand);
                S_L:  if instr.operands[1].operandtype = OPR_CONSTANT then
                        Begin
                          if instr.operands[1].val <= $ff then
                            Begin
                              if instr.operands[3].size in [S_L] then
                              Begin
                                 case instr.operands[3].operandtype of
                                  OPR_REFERENCE: { MISSING !!!! } ;
                                  OPR_REGISTER:  p^.concat(new(pai386,
                                     op_const_reg_reg(instruc, S_L,
                                     instr.operands[1].val, instr.operands[2].reg,
                                     instr.operands[3].reg)));
                                 else
                                   Message(assem_e_invalid_opcode_and_operand);
                                 end;
                              end
                              else
                                Message(assem_e_invalid_opcode_and_operand);
                            end;
                        end
                      else
                       Message(assem_e_invalid_opcode_and_operand);
                else
                  Message(assem_e_invalid_opcode_and_operand);
               end; { end case }
             end
             else
             if (instruc = A_IMUL) and (instr.operands[3].operandtype
               = OPR_REGISTER) then
             Begin
               case instr.operands[3].size of
                S_W:  if instr.operands[1].operandtype = OPR_CONSTANT then
                        Begin
                          if instr.operands[1].val <= $ffff then
                            Begin
                              if instr.operands[2].size in [S_W] then
                              Begin
                                 case instr.operands[2].operandtype of
                                  OPR_REFERENCE: { MISSING !!!! } ;
                                  OPR_REGISTER:  p^.concat(new(pai386,
                                     op_const_reg_reg(instruc, S_W,
                                     instr.operands[1].val, instr.operands[2].reg,
                                     instr.operands[3].reg)));
                                 else
                                  Message(assem_e_invalid_opcode_and_operand);
                                 end; { end case }
                              end
                              else
                                Message(assem_e_invalid_opcode_and_operand);
                            end;
                        end
                      else
                        Message(assem_e_invalid_opcode_and_operand);
                S_L:  if instr.operands[1].operandtype = OPR_CONSTANT then
                        Begin
                          if instr.operands[1].val <= $7fffffff then
                            Begin
                              if instr.operands[2].size in [S_L] then
                              Begin
                                 case instr.operands[2].operandtype of
                                  OPR_REFERENCE: { MISSING !!!! } ;
                                  OPR_REGISTER:  p^.concat(new(pai386,
                                     op_const_reg_reg(instruc, S_L,
                                     instr.operands[1].val, instr.operands[2].reg,
                                     instr.operands[3].reg)));
                                 else
                                   Message(assem_e_invalid_opcode_and_operand);
                                 end; { end case }
                              end
                              else
                               Message(assem_e_invalid_opcode_and_operand);
                            end;
                        end
                      else
                       Message(assem_e_invalid_opcode_and_operand);
                else
                  Message(assem_e_invalid_middle_sized_operand);
               end; { end case }
             end { endif }
           else
             Message(assem_e_invalid_three_operand_opcode);
        end;
  end; { end case }
 end;
 end;

    Procedure ConcatLabeledInstr(var instr: TInstruction);

      Var instruct : tasmop;
          i : longint;
    Begin
       instruct:=instr.getinstruction;
       Case instruct Of
         A_JO,A_JNO,A_JB,A_JC,A_JNAE,
         A_JNB,A_JNC,A_JAE,A_JE,A_JZ,A_JNE,A_JNZ,A_JBE,A_JNA,A_JNBE,
         A_JA,A_JS,A_JNS,A_JP,A_JPE,A_JNP,A_JPO,A_JL,A_JNGE,A_JNL,A_JGE,
         A_JLE,A_JNG,A_JNLE,A_JG,A_JCXZ,A_JECXZ,A_LOOP,A_LOOPZ,A_LOOPE,
         A_LOOPNZ,A_LOOPNE,A_JMP,A_CALL:
           Begin
             if (instr.numops <> 1) then
               Message(assem_e_invalid_labeled_opcode)
             else if instr.operands[1].operandtype <> OPR_LABINSTR then
                    Message(assem_e_invalid_labeled_opcode)
             else if assigned(instr.operands[1].hl) then
                    ConcatLabel(p,instruct, instr.operands[1].hl)
             else
               Begin
                 Message(assem_f_internal_error_in_concatlabeledinstr);
               end;
           end;
         A_MOV: { move from/to rel8 };
         else
          if (cs_compilesystem in aktmoduleswitches) then
            begin
             for i:=1 to instr.numops do
              if instr.operands[i].operandtype=OPR_LABINSTR then
               begin
                instr.operands[i].operandtype:=OPR_REFERENCE;
                instr.operands[i].ref.symbol:=newpasstr(lab2str(instr.operands[i].hl) );
                instr.operands[i].opinfo:=ao_mem;
                instr.operands[i].ref.base:=R_NO;
                instr.operands[i].ref.index:=R_NO;
                instr.operands[i].ref.segment:=R_DEFAULT_SEG;
                instr.operands[i].ref.offset:=0;
               end;
        { handle now as an ordinary opcode }
             concatopcode(instr);
            end
          else
            Message1(assem_e_invalid_operand,'');
       end; { case }
    end;



  {---------------------------------------------------------------------}
  {                     Routines for the parsing                        }
  {---------------------------------------------------------------------}

     procedure consume(t : tinteltoken);

     begin
       if t<>actasmtoken then
        Message(assem_e_syntax_error);
       actasmtoken:=gettoken;
       { if the token must be ignored, then }
       { get another token to parse.        }
       if actasmtoken = AS_NONE then
          actasmtoken := gettoken;
      end;





   function findregister(const s : string): tregister;
  {*********************************************************************}
  { FUNCTION findregister(s: string):tasmop;                            }
  {  Description: Determines if the s string is a valid register,       }
  {  if so returns correct tregister token, or R_NO if not found.       }
  {*********************************************************************}
   var
    i: tregister;
   begin
     findregister := R_NO;
     for i:=firstreg to lastreg do
       if s = iasmregs[i] then
       Begin
         findregister := i;
         exit;
       end;
   end;



   function findprefix(const s: string; var token: tasmop): boolean;
   var i: byte;
   Begin
     findprefix := FALSE;
     for i:=0 to _count_asmprefixes do
     Begin
       if s = _asmprefixes[i] then
       begin
          token := _prefixtokens[i];
          findprefix := TRUE;
          exit;
       end;
     end;
   end;


   function findsegment(const s:string): tregister;
  {*********************************************************************}
  { FUNCTION findsegment(s: string):tasmop;                             }
  {  Description: Determines if the s string is a valid segment register}
  {  if so returns correct tregister token, or R_NO if not found.       }
  {*********************************************************************}
   var
    i: tregister;
   Begin
     findsegment := R_DEFAULT_SEG;
     for i:=firstsreg to lastsreg do
       if s = iasmregs[i] then
       Begin
         findsegment := i;
         exit;
       end;
   end;


   function findopcode(const s: string): tasmop;
  {*********************************************************************}
  { FUNCTION findopcode(s: string): tasmop;                             }
  {  Description: Determines if the s string is a valid opcode          }
  {  if so returns correct tasmop token.                                }
  {*********************************************************************}
   var
    i: tasmop;
    j: byte;
    hs: topsize;
    hid: string;
   Begin
     findopcode := A_NONE;
     { first search for extended opcodes          }
     { now, in this case, we must use the suffix  }
     { to determine the size of the instruction   }
     for j:=0 to _count_asmspecialops do
     Begin
       if s = _specialops[j] then
       Begin
         findopcode := _specialopstokens[j];
         { set the size }
         case s[length(s)] of
         'B': instr.stropsize := S_B;
         'L': instr.stropsize := S_L;
         'W': instr.stropsize := S_W;
         end;
         exit;
       end;
     end;
     for i:=firstop to lastop do
     Begin
            if s=iasmops^[i] then
             begin
               findopcode := i;
               instr.stropsize := S_NO;
               exit;
             end;
     end;
     { not found yet ... }
     { search for all possible suffixes }
     for hs:=S_WL downto S_B do
        if copy(s,length(s)-length(att_opsize2str[hs])+1,
          length(att_opsize2str[hs]))=upper(att_opsize2str[hs]) then
        begin
           hid:=copy(s,1,length(s)-length(att_opsize2str[hs]));
           for i:=firstop to lastop do
              if (length(hid) > 0) and (hid=iasmops^[i]) then
              begin
                findopcode := i;
                instr.stropsize := hs;
                exit;
              end;
        end;
  end;


   Function CheckPrefix(prefix: tasmop; opcode:tasmop): Boolean;
   { Checks if the prefix is valid with the following instruction }
   { return false if not, otherwise true                          }
   Begin
     CheckPrefix := TRUE;
     Case prefix of
       A_REP,A_REPNE,A_REPE:
         Case opcode Of
           A_SCAS,A_INS,A_OUTS,A_MOVS,
           A_CMPS,A_LODS,A_STOS:;
           Else
             Begin
               CheckPrefix := FALSE;
               exit;
             end;
         End;
       A_LOCK:
         Case opcode Of
           A_BT,A_BTS,A_BTR,A_BTC,A_XCHG,A_ADD,A_OR,
           A_ADC,A_SBB,A_AND,A_SUB,A_XOR,A_NOT,A_NEG,A_INC,A_DEC:;
           Else
             Begin
               CheckPrefix := FALSE;
               Exit;
             end;
         End;
       A_NONE: exit; { no prefix here }
       else
         CheckPrefix := FALSE;
     end; { end case }
   end;


  Procedure InitAsmRef(var instr: TInstruction);
  {*********************************************************************}
  {  Description: This routine first check if the instruction is of     }
  {  type OPR_NONE, or OPR_REFERENCE , if not it gives out an error.    }
  {  If the operandtype = OPR_NONE or <> OPR_REFERENCE then it sets up  }
  {  the operand type to OPR_REFERENCE, as well as setting up the ref   }
  {  to point to the default segment.                                   }
  {*********************************************************************}
   Begin
     With instr do
     Begin
        case operands[operandnum].operandtype of
          OPR_REFERENCE: exit;
          OPR_NONE: ;
        else
          Message(assem_e_invalid_operand_type);
        end;
        operands[operandnum].operandtype := OPR_REFERENCE;
        operands[operandnum].ref.segment := R_DEFAULT_SEG;
     end;
   end;

   Function CheckOverride(segreg: tregister; var instr: TInstruction): Boolean;
   { Check if the override is valid, and if so then }
   { update the instr variable accordingly.         }
   Begin
     CheckOverride := FALSE;
     Case instr.getinstruction of
       A_MOVS,A_XLAT,A_CMPS:
         Begin
           CheckOverride := TRUE;
           Message(assem_e_segment_override_not_supported);
         end
     end
   end;




  Function CalculateExpression(expression: string): longint;
  var
    expr: TExprParse;
  Begin
   expr.Init;
   CalculateExpression := expr.Evaluate(expression);
   expr.Done;
  end;


  Procedure GetRecordOffsetSize(const expr: string;var offset:longint;var size:longint);
  {*********************************************************************}
  { PROCEDURE GetRecordOffsetSize                                       }
  {  Description: This routine builds up a record offset after a AS_DOT }
  {  token is encountered.                                              }
  {   On entry actasmtoken should be equal to AS_DOT                    }
  {*********************************************************************}
  { EXIT CONDITION:  On exit the routine should point to either the     }
  {       AS_COMMA or AS_SEPARATOR token.                               }
  { Warning: This is called recursively.                                }
  {*********************************************************************}
  var
    toffset,tsize : longint;
  Begin
    offset:=0;
    size:=0;
    Consume(AS_DOT);
    if actasmtoken = AS_ID then
      Begin
        if not GetTypeOffsetSize(expr,actasmpattern,toffset,tsize) and
           not GetVarOffsetSize(expr,actasmpattern,toffset,tsize) then
         begin
           Message(assem_e_syntax_error);
           toffset:=0;
           tsize:=0;
         end;
        inc(offset,toffset);
        size:=tsize;
        Consume(AS_ID);
        case actasmtoken of
          AS_SEPARATOR,
          AS_COMMA      : exit;
          AS_DOT        : begin
                            GetRecordOffsetSize(expr,toffset,tsize);
                            inc(offset,toffset);
                            size:=tsize;
                          end;

        else
          Begin
            Message(assem_e_syntax_error);
            repeat
              consume(actasmtoken)
            until (actasmtoken = AS_SEPARATOR) or (actasmtoken = AS_COMMA);
            exit;
          end;
        end;
      end
    else
      Begin
        Message(assem_e_syntax_error);
        repeat
          consume(actasmtoken)
        until (actasmtoken = AS_SEPARATOR) or (actasmtoken = AS_COMMA);
      end;
  end;


  Function BuildExpression: longint;
  {*********************************************************************}
  { FUNCTION BuildExpression: longint                                   }
  {  Description: This routine calculates a constant expression to      }
  {  a given value. The return value is the value calculated from       }
  {  the expression.                                                    }
  { The following tokens (not strings) are recognized:                  }
  {    (,),SHL,SHR,/,*,NOT,OR,XOR,AND,MOD,+/-,numbers,ID to constants.  }
  {*********************************************************************}
  { ENTRY: On entry the token should be any valid expression token.     }
  { EXIT:  On Exit the token points to either COMMA or SEPARATOR        }
  { ERROR RECOVERY: Tries to find COMMA or SEPARATOR token by consuming }
  {  invalid tokens.                                                    }
  {*********************************************************************}
  var expr: string;
      tempstr: string;
      l,k : longint;
      errorflag: boolean;
  Begin
    errorflag := FALSE;
    expr := '';
    tempstr := '';
    Repeat
      Case actasmtoken of
      AS_LPAREN: Begin
                  Consume(AS_LPAREN);
                  expr := expr + '(';
                end;
      AS_RPAREN: Begin
                  Consume(AS_RPAREN);
                  expr := expr + ')';
                end;
      AS_SHL:    Begin
                  Consume(AS_SHL);
                  expr := expr + '<';
                end;
      AS_SHR:    Begin
                  Consume(AS_SHR);
                  expr := expr + '>';
                end;
      AS_SLASH:  Begin
                  Consume(AS_SLASH);
                  expr := expr + '/';
                end;
      AS_MOD:    Begin
                  Consume(AS_MOD);
                  expr := expr + '%';
                end;
      AS_STAR:   Begin
                  Consume(AS_STAR);
                  expr := expr + '*';
                end;
      AS_PLUS:   Begin
                  Consume(AS_PLUS);
                  expr := expr + '+';
                end;
      AS_MINUS:  Begin
                  Consume(AS_MINUS);
                  expr := expr + '-';
                end;
      AS_AND:    Begin
                  Consume(AS_AND);
                  expr := expr + '&';
                end;
      AS_NOT:    Begin
                  Consume(AS_NOT);
                  expr := expr + '~';
                end;
      AS_XOR:    Begin
                  Consume(AS_XOR);
                  expr := expr + '^';
                end;
      AS_OR:     Begin
                  Consume(AS_OR);
                  expr := expr + '|';
                end;
      AS_ID:    Begin
                  tempstr:=actasmpattern;
                  previous_was_id:=TRUE;
                  consume(AS_ID);
                  if actasmtoken=AS_DOT then
                   begin
                     GetRecordOffsetSize(tempstr,l,k);
                     str(l, tempstr);
                     expr := expr + tempstr;
                   end
                  else
                   begin
                     if SearchIConstant(tempstr,l) then
                      begin
                        str(l, tempstr);
                        expr := expr + tempstr;
                      end
                     else
                      Message1(assem_e_invalid_const_symbol,actasmpattern);
                   end;
                  end;
      AS_INTNUM:  Begin
                   expr := expr + actasmpattern;
                   Consume(AS_INTNUM);
                 end;
      AS_BINNUM:  Begin
                      tempstr := BinaryToDec(actasmpattern);
                      if tempstr = '' then
                       Message(assem_f_error_converting_bin);
                      expr:=expr+tempstr;
                      Consume(AS_BINNUM);
                 end;

      AS_HEXNUM: Begin
                    tempstr := HexToDec(actasmpattern);
                    if tempstr = '' then
                     Message(assem_f_error_converting_hex);
                    expr:=expr+tempstr;
                    Consume(AS_HEXNUM);
                end;
      AS_OCTALNUM: Begin
                    tempstr := OctalToDec(actasmpattern);
                    if tempstr = '' then
                     Message(assem_f_error_converting_octal);
                    expr:=expr+tempstr;
                    Consume(AS_OCTALNUM);
                  end;
      { go to next term }
      AS_COMMA: Begin
                  if not ErrorFlag then
                    BuildExpression := CalculateExpression(expr)
                  else
                    BuildExpression := 0;
                  Exit;
               end;
      { go to next symbol }
      AS_SEPARATOR: Begin
                      if not ErrorFlag then
                        BuildExpression := CalculateExpression(expr)
                      else
                        BuildExpression := 0;
                      Exit;
                   end;
      else
        Begin
          { only write error once. }
          if not errorflag then
           Message(assem_e_invalid_constant_expression);
          { consume tokens until we find COMMA or SEPARATOR }
          Consume(actasmtoken);
          errorflag := TRUE;
        End;
      end;
    Until false;
  end;


  Procedure BuildRealConstant(typ : tfloattype);
  {*********************************************************************}
  { PROCEDURE BuilRealConst                                             }
  {  Description: This routine calculates a constant expression to      }
  {  a given value. The return value is the value calculated from       }
  {  the expression.                                                    }
  { The following tokens (not strings) are recognized:                  }
  {    +/-,numbers and real numbers                                     }
  {*********************************************************************}
  { ENTRY: On entry the token should be any valid expression token.     }
  { EXIT:  On Exit the token points to either COMMA or SEPARATOR        }
  { ERROR RECOVERY: Tries to find COMMA or SEPARATOR token by consuming }
  {  invalid tokens.                                                    }
  {*********************************************************************}
  var expr: string;
      tempstr: string;
      r : bestreal;
      code : word;
      negativ : boolean;
      errorflag: boolean;
  Begin
    errorflag := FALSE;
    Repeat
    negativ:=false;
    expr := '';
    tempstr := '';
    if actasmtoken=AS_PLUS then Consume(AS_PLUS)
    else if actasmtoken=AS_MINUS then
      begin
         negativ:=true;
         consume(AS_MINUS);
      end;
    Case actasmtoken of
      AS_INTNUM:  Begin
                   expr := actasmpattern;
                   Consume(AS_INTNUM);
                 end;
      AS_REALNUM:  Begin
                   expr := actasmpattern;
                   { in ATT syntax you have 0d in front of the real }
                   { should this be forced ?  yes i think so, as to }
                   { conform to gas as much as possible.            }
                   if (expr[1]='0') and (upper(expr[2])='D') then
                     expr:=copy(expr,3,255);
                   Consume(AS_REALNUM);
                 end;
      AS_BINNUM:  Begin
                      { checking for real constants with this should use  }
                      { real DECODING otherwise the compiler will crash!  }
                      Message(assem_w_float_bin_ignored);
                      Consume(AS_BINNUM);
                 end;

      AS_HEXNUM: Begin
                      { checking for real constants with this should use  }
                      { real DECODING otherwise the compiler will crash!  }
                    Message(assem_w_float_hex_ignored);
                    Consume(AS_HEXNUM);
                end;
      AS_OCTALNUM: Begin
                      { checking for real constants with this should use    }
                      { real DECODING otherwise the compiler will crash!    }
                      { xxxToDec using reals could be a solution, but the   }
                      { problem is that these will crash the m68k compiler  }
                      { when compiling -- because of lack of good fpu       }
                      { support.                                           }
                    Message(assem_w_float_octal_ignored);
                    Consume(AS_OCTALNUM);
                  end;
         else
           Begin
             { only write error once. }
             if not errorflag then
              Message(assem_e_invalid_real_const);
             { consume tokens until we find COMMA or SEPARATOR }
             Consume(actasmtoken);
             errorflag := TRUE;
           End;

         end;
      { go to next term }
      if (actasmtoken=AS_COMMA) or (actasmtoken=AS_SEPARATOR) then
        Begin
          if negativ then expr:='-'+expr;
          val(expr,r,code);
          if code<>0 then
            Begin
               r:=0;
               Message(assem_e_invalid_real_const);
               ConcatRealConstant(p,r,typ);
            End
          else
            Begin
              ConcatRealConstant(p,r,typ);
            End;
        end
      else
       Message(assem_e_invalid_real_const);
    Until actasmtoken=AS_SEPARATOR;
  end;



  Procedure BuildScaling(Var instr: TInstruction);
  {*********************************************************************}
  {  Takes care of parsing expression starting from the scaling value   }
  {  up to and including possible field specifiers.                     }
  { EXIT CONDITION:  On exit the routine should point to  AS_SEPARATOR  }
  { or AS_COMMA. On entry should point to the AS_COMMA token.           }
  {*********************************************************************}
  var str:string;
      l: longint;
      code: integer;
  Begin
     Consume(AS_COMMA);
     if (instr.operands[operandnum].ref.scalefactor <> 0)
     and (instr.operands[operandnum].ref.scalefactor <> 1) then
      Message(assem_f_internal_error_in_buildscale);
     case actasmtoken of
        AS_INTNUM: str := actasmpattern;
        AS_HEXNUM: str := HexToDec(actasmpattern);
        AS_BINNUM: str := BinaryToDec(actasmpattern);
        AS_OCTALNUM: str := OctalToDec(actasmpattern);
     else
        Message(assem_e_syntax_error);
     end;
     val(str, l, code);
     if code <> 0 then
       Message(assem_e_invalid_scaling_factor);
     if ((l = 2) or (l = 4) or (l = 8) or (l = 1)) and (code = 0) then
     begin
        instr.operands[operandnum].ref.scalefactor := l;
     end
     else
     Begin
        Message(assem_e_invalid_scaling_value);
        instr.operands[operandnum].ref.scalefactor := 0;
     end;
     if instr.operands[operandnum].ref.index = R_NO then
     Begin
        Message(assem_e_scaling_value_only_allowed_with_index);
        instr.operands[operandnum].ref.scalefactor := 0;
     end;
    { Consume the scaling number }
    Consume(actasmtoken);
    if actasmtoken = AS_RPAREN then
        Consume(AS_RPAREN)
    else
       Message(assem_e_invalid_scaling_value);
    { // .Field.Field ... or separator/comma // }
    if actasmtoken in [AS_COMMA,AS_SEPARATOR] then
    Begin
    end
    else
      Message(assem_e_syntax_error);
  end;




  Function BuildRefExpression(BetweenBrackets: Boolean): longint;
  {*********************************************************************}
  { FUNCTION BuildRefExpression: longint                                }
  {  Description: This routine calculates a constant offset expression  }
  {  to a given value. The return value is the value calculated from    }
  {  the expression.                                                    }
  {  If BetweenBrackets is false, it's an offset before the brackets of }
  {  a reference, such as 16(%ebp), otherwise it's one in between       }
  {  brackets, such as fs:(0x046c)                                      }
  { The following tokens (not strings) are recognized:                  }
  {    SHL,SHR,/,*,NOT,OR,XOR,AND,MOD,+/-,numbers,ID to constants.      }
  {*********************************************************************}
  { ENTRY: On entry the token should be any valid expression token.     }
  { EXIT:  On Exit the token points to the LPAREN token.                }
  { ERROR RECOVERY: Tries to find COMMA or SEPARATOR token by consuming }
  {  invalid tokens.                                                    }
  {*********************************************************************}
  var tempstr: string;
      expr: string;
    l,k : longint;
    errorflag : boolean;
  Begin
    errorflag := FALSE;
    tempstr := '';
    expr := '';
    Repeat
      Case actasmtoken of
      AS_RPAREN: Begin
                   If Not(BetweenBrackets) Then
                     Begin
                       Message(assem_e_parenthesis_are_not_allowed);
                       Consume(AS_RPAREN);
                     End
                   Else
                     Begin
                      { in this case a closing parenthesis denotes the end
                        of the expression }
                       If Not ErrorFlag Then
                          BuildRefExpression := CalculateExpression(expr)
                       else
                         BuildRefExpression := 0;
                     { no longer in an expression }
                       exit;
                     End
                 end;
      AS_SHL:    Begin
                   Consume(AS_SHL);
                   expr := expr + '<';
                 end;
      AS_SHR:    Begin
                  Consume(AS_SHR);
                  expr := expr + '>';
                end;
      AS_SLASH:  Begin
                  Consume(AS_SLASH);
                  expr := expr + '/';
                end;
      AS_MOD:    Begin
                  Consume(AS_MOD);
                  expr := expr + '%';
                end;
      AS_STAR:   Begin
                  Consume(AS_STAR);
                  expr := expr + '*';
                end;
      AS_PLUS:   Begin
                  Consume(AS_PLUS);
                  expr := expr + '+';
                end;
      AS_MINUS:  Begin
                  Consume(AS_MINUS);
                  expr := expr + '-';
                end;
      AS_AND:    Begin
                  Consume(AS_AND);
                  expr := expr + '&';
                end;
      AS_NOT:    Begin
                  Consume(AS_NOT);
                  expr := expr + '~';
                end;
      AS_XOR:    Begin
                  Consume(AS_XOR);
                  expr := expr + '^';
                end;
      AS_OR:     Begin
                  Consume(AS_OR);
                  expr := expr + '|';
                end;
      { End of reference }
      AS_LPAREN: Begin
                   If Not(BetweenBrackets) Then
                     Begin
                       if not ErrorFlag then
                          BuildRefExpression := CalculateExpression(expr)
                       else
                          BuildRefExpression := 0;
                     { no longer in an expression }
                       exit;
                     End
                   Else
                     Begin
                       Message(assem_e_parenthesis_are_not_allowed);
                       Consume(AS_RPAREN);
                     End
                  end;
      AS_ID:
                Begin
                  tempstr:=actasmpattern;
                  consume(AS_ID);
                  if actasmtoken=AS_DOT then
                   begin
                     GetRecordOffsetSize(tempstr,l,k);
                     str(l, tempstr);
                     expr := expr + tempstr;
                   end
                  else
                   begin
                     if SearchIConstant(tempstr,l) then
                      begin
                        str(l, tempstr);
                        expr := expr + tempstr;
                      end
                     else
                      Message1(assem_e_invalid_const_symbol,tempstr);
                   end;
                end;
      AS_INTNUM:  Begin
                   expr := expr + actasmpattern;
                   Consume(AS_INTNUM);
                 end;
      AS_BINNUM:  Begin
                      tempstr := BinaryToDec(actasmpattern);
                      if tempstr = '' then
                       Message(assem_f_error_converting_bin);
                      expr:=expr+tempstr;
                      Consume(AS_BINNUM);
                 end;

      AS_HEXNUM: Begin
                    tempstr := HexToDec(actasmpattern);
                    if tempstr = '' then
                     Message(assem_f_error_converting_hex);
                    expr:=expr+tempstr;
                    Consume(AS_HEXNUM);
                end;
      AS_OCTALNUM: Begin
                    tempstr := OctalToDec(actasmpattern);
                    if tempstr = '' then
                     Message(assem_f_error_converting_octal);
                    expr:=expr+tempstr;
                    Consume(AS_OCTALNUM);
                  end;
      else
        Begin
          { write error only once. }
          if not errorflag then
           Message(assem_e_invalid_constant_expression);
          BuildRefExpression := 0;
          if actasmtoken in [AS_COMMA,AS_SEPARATOR] then exit;
          { consume tokens until we find COMMA or SEPARATOR }
          Consume(actasmtoken);
          errorflag := TRUE;
        end;
      end;
    Until false;
  end;




  Procedure BuildReference(var Instr: TInstruction);
  {*********************************************************************}
  { PROCEDURE BuildBracketExpression                                    }
  {  Description: This routine builds up an expression after a LPAREN   }
  {  token is encountered.                                              }
  {   On entry actasmtoken should be equal to AS_LPAREN                 }
  {*********************************************************************}
  { EXIT CONDITION:  On exit the routine should point to either the     }
  {       AS_COMMA or AS_SEPARATOR token.                               }
  {*********************************************************************}
  var
    l:longint;
    code: integer;
    str: string;
  Begin
     Consume(AS_LPAREN);
     initAsmRef(instr);
     Case actasmtoken of
        { absolute offset, such as fs:(0x046c) }
        AS_HEXNUM,AS_INTNUM,AS_MINUS,
        AS_BINNUM,AS_OCTALNUM,AS_PLUS:
          Begin
            If Instr.Operands[OperandNum].Ref.Offset <> 0 Then
             { offset(offset) is invalid }
              Begin
                Message(assem_e_invalid_reference);
                while actasmtoken <> AS_SEPARATOR do
                  Consume(actasmtoken);
              End
            Else
              Begin
                Instr.Operands[OperandNum].Ref.Offset := BuildRefExpression(True);
                if actasmtoken <> AS_RPAREN then
                  Begin
                    Message(assem_e_invalid_reference);
                    while actasmtoken <> AS_SEPARATOR do
                      Consume(actasmtoken);
                  end
                else
                  Begin
                    Consume(AS_RPAREN);
                    if not (actasmtoken in [AS_COMMA, AS_SEPARATOR]) then
                      Begin
                        { error recovery ... }
                        Message(assem_e_invalid_reference);
                        while actasmtoken <> AS_SEPARATOR do
                          Consume(actasmtoken);
                      end;
                   end;
              End;
            exit;
          End;
        { // (reg ... // }
        AS_REGISTER: Begin
                       { Check if there is already a base (mostly ebp,esp) than this is
                         not allowed,becuase it will give crashing code }
                        if instr.operands[operandnum].ref.base<>R_NO then
                         Message(assem_e_cannot_index_relative_var);
                        instr.operands[operandnum].ref.base := findregister(actasmpattern);
                        Consume(AS_REGISTER);
                        { can either be a register or a right parenthesis }
                         { // (reg)       // }
                         if actasmtoken=AS_RPAREN then  Begin
                                       Consume(AS_RPAREN);
                                       if not (actasmtoken in [AS_COMMA,
                                         AS_SEPARATOR]) then
                                       Begin
                                         Message(assem_e_invalid_reference);
                                         { error recovery ... }
                                         while actasmtoken <> AS_SEPARATOR do
                                           Consume(actasmtoken);
                                       end;
                                         exit;
                                     end;
                       { // (reg,reg .. // }
                       { we need a comman here !! }
                       { oops..                   }
                        Consume(AS_COMMA);

                        Case actasmtoken of
                         AS_REGISTER: Begin
                                        instr.operands[operandnum].ref.index :=
                                           findregister(actasmpattern);
                                        Consume(AS_REGISTER);
                                        { check for scaling ... }
                                        case actasmtoken of
                                         AS_RPAREN:
                                               Begin
                                                 Consume(AS_RPAREN);
                                                 if not (actasmtoken in [AS_COMMA,
                                                    AS_SEPARATOR]) then
                                                  Begin
                                                    { error recovery ... }
                                                    Message(assem_e_invalid_reference);
                                                    while actasmtoken <> AS_SEPARATOR do
                                                    Consume(actasmtoken);
                                                  end;
                                                   exit;
                                               end;
                                         AS_COMMA:
                                               Begin
                                                 BuildScaling(instr);
                                               end;
                                         else
                                          Begin
                                             Message(assem_e_invalid_reference_syntax);
                                             while (actasmtoken <> AS_SEPARATOR) do
                                             Consume(actasmtoken);
                                          end;
                                         end; { end case }
                                        end;
                         else
                          Begin
                            Message(assem_e_invalid_reference_syntax);
                            while (actasmtoken <> AS_SEPARATOR) do
                                Consume(actasmtoken);
                          end;
                         end; {end case }
                     end;
        { // (, ...   // }
        AS_COMMA:  { can either be scaling, or index }
                   Begin
                     Consume(AS_COMMA);
                     case actasmtoken of
                       AS_REGISTER: Begin
                                      instr.operands[operandnum].ref.index :=
                                         findregister(actasmpattern);
                                      Consume(AS_REGISTER);
                                        { check for scaling ... }
                                        case actasmtoken of
                                         AS_RPAREN:
                                               Begin
                                                 Consume(AS_RPAREN);
                                                 if not (actasmtoken in [AS_COMMA,
                                                    AS_SEPARATOR]) then
                                                  Begin
                                                    { error recovery ... }
                                                    Message(assem_e_invalid_reference);
                                                    while actasmtoken <> AS_SEPARATOR do
                                                    Consume(actasmtoken);
                                                  end;
                                                   exit;
                                               end;
                                         AS_COMMA:
                                               Begin
                                                 BuildScaling(instr);
                                               end;
                                         else
                                          Begin
                                             Message(assem_e_invalid_reference_syntax);
                                             while (actasmtoken <> AS_SEPARATOR) do
                                             Consume(actasmtoken);
                                          end;
                                         end; {end case }
                                    end;
                       AS_HEXNUM,AS_INTNUM,   { we have to process the scaling }
                       AS_BINNUM,AS_OCTALNUM: { directly here...               }
                                              Begin
                                                  case actasmtoken of
                                                    AS_INTNUM: str :=
                                                       actasmpattern;
                                                    AS_HEXNUM: str :=
                                                       HexToDec(actasmpattern);
                                                    AS_BINNUM: str :=
                                                       BinaryToDec(actasmpattern);
                                                    AS_OCTALNUM: str :=
                                                       OctalToDec(actasmpattern);
                                                  else
                                                    Message(assem_e_syntax_error);
                                                  end; { end case }
                                                  val(str, l, code);
                                                  if code <> 0 then
                                                     Message(assem_e_invalid_scaling_factor);
                                                  if ((l = 2) or (l = 4) or (l = 8) or (l = 1)) and (code = 0) then
                                                  begin
                                                    instr.operands[operandnum].
                                                       ref.scalefactor := l;
                                                  end
                                                  else
                                                  Begin
                                                    Message(assem_e_invalid_scaling_value);
                                                    instr.operands[operandnum].
                                                       ref.scalefactor := 0;
                                                  end;
                                                  Consume(actasmtoken);
                                                  if actasmtoken <> AS_RPAREN then
                                                  Begin
                                                    Message(assem_e_invalid_scaling_value);
                                                    while actasmtoken <> AS_SEPARATOR do
                                                      Consume(actasmtoken);
                                                  end
                                                  else
                                                  Begin
                                                    Consume(AS_RPAREN);
                                                    if not (actasmtoken in [AS_COMMA,
                                                       AS_SEPARATOR]) then
                                                     Begin
                                                      { error recovery ... }
                                                      Message(assem_e_invalid_reference);
                                                      while actasmtoken <> AS_SEPARATOR do
                                                        Consume(actasmtoken);
                                                     end;
                                                    exit;
                                                  end;
                                              end;
                     else
                       Begin
                          Message(assem_e_invalid_reference_syntax);
                          while (actasmtoken <> AS_SEPARATOR) do
                          Consume(actasmtoken);
                       end;
                     end; { end case }
                   end;

     else
       Begin
         Message(assem_e_invalid_reference_syntax);
         while (actasmtoken <> AS_SEPARATOR) do
           Consume(actasmtoken);
       end;
     end; { end case }
  end;


  Procedure BuildOperand(var instr: TInstruction);
  {*********************************************************************}
  { EXIT CONDITION:  On exit the routine should point to either the     }
  {       AS_COMMA or AS_SEPARATOR token.                               }
  {*********************************************************************}
  var
    tempstr: string;
    expr: string;
    lab: Pasmlabel;
    hl: plabel;
    tsize,
    toffset : longint;
  Begin
   tempstr := '';
   expr := '';
   case actasmtoken of
   { // Memory reference //  }
     AS_LPAREN:
               Begin
                  initAsmRef(instr);
                  BuildReference(instr);
               end;
   { // Constant expression //  }
     AS_DOLLAR:  Begin
                      Consume(AS_DOLLAR);
                      if not (instr.operands[operandnum].operandtype in [OPR_NONE,OPR_CONSTANT]) then
                       Message(assem_e_invalid_operand_type);
                      { identifiers are handled by BuildExpression }
                      instr.operands[operandnum].operandtype := OPR_CONSTANT;
                      instr.operands[operandnum].val :=BuildExpression;
                 end;
   { // Constant memory offset .              // }
   { // This must absolutely be followed by ( // }
     AS_HEXNUM,AS_INTNUM,AS_MINUS,
     AS_BINNUM,AS_OCTALNUM,AS_PLUS:
                   Begin
                      InitAsmRef(instr);
                      instr.operands[operandnum].ref.offset:=BuildRefExpression(False);
                      BuildReference(instr);
                   end;
   { // Call from memory address // }
     AS_STAR:      Begin
                      Consume(AS_STAR);
                      InitAsmRef(instr);
                      if not CreateVarInstr(instr,actasmpattern,operandnum) then
                       Message(assem_e_syn_opcode_operand);
                   end;
   { // A constant expression, or a Variable ref. // }
     AS_ID:  Begin
              { // Local label.                      // }
              if (actasmpattern[1] ='.') and (actasmpattern[2] = 'L') then
              Begin
                  Begin
                    delete(actasmpattern,1,1);
                    delete(actasmpattern,1,1);
                    if actasmpattern = '' then
                     Message(assem_e_null_label_ref_not_allowed);
                    lab := labellist.search(actasmpattern);
                    { check if the label is already defined   }
                    { if so, we then check if the plabel is   }
                    { non-nil, if so we add it to instruction }
                    if assigned(lab) then
                     Begin
                     if assigned(lab^.lab) then
                       Begin
                         instr.operands[operandnum].operandtype := OPR_LABINSTR;
                         instr.operands[operandnum].hl := lab^.lab;
                         instr.labeled := TRUE;
                       end;
                     end
                    else
                    { the label does not exist, create it }
                    { emit the opcode, but set that the   }
                    { label has not been emitted          }
                     Begin
                        getlabel(hl);
                        labellist.insert(actasmpattern,hl,FALSE);
                        instr.operands[operandnum].operandtype := OPR_LABINSTR;
                        instr.operands[operandnum].hl := hl;
                        instr.labeled := TRUE;
                     end;
                  end;
                Consume(AS_ID);
                if not (actasmtoken in [AS_SEPARATOR,AS_COMMA]) then
                Begin
                  Message(assem_e_syntax_error);
                end;
              end
              { probably a variable or normal expression }
              { or a procedure (such as in CALL ID)      }
              else
               Begin
                 { check if this is a label, if so then }
                 { emit it as a label.                  }
                 if SearchLabel(actasmpattern,hl) then
                   Begin
                     instr.operands[operandnum].operandtype := OPR_LABINSTR;
                     instr.operands[operandnum].hl := hl;
                     instr.labeled := TRUE;
                     Consume(AS_ID);
                     if not (actasmtoken in [AS_SEPARATOR,AS_COMMA]) then
                       Message(assem_e_syntax_error);
                   end
                 else
                 { is it a normal variable ? }
                   Begin
                     { context for scanner }
                     previous_was_id:=TRUE;
                     initAsmRef(instr);
                     if not CreateVarInstr(instr,actasmpattern,operandnum) then
                       Begin
                         { look for special symbols ... }
                         if actasmpattern = '__RESULT' then
                             SetUpResult(instr,operandnum)
                         else
                         if actasmpattern = '__SELF' then
                         Begin
                           if assigned(procinfo._class) then
                             Begin
                               instr.operands[operandnum].operandtype := OPR_REFERENCE;
                               instr.operands[operandnum].ref.offset :=
                                 procinfo.ESI_offset;
                               instr.operands[operandnum].ref.base :=
                                 procinfo.framepointer;
                             end
                           else
                             Message(assem_e_cannot_use___SELF_outside_methode);
                         end
                         else
                         if actasmpattern = '__OLDEBP' then
                         Begin
                           if lexlevel>normal_function_level then
                             Begin
                               instr.operands[operandnum].operandtype := OPR_REFERENCE;
                               instr.operands[operandnum].ref.offset :=
                                 procinfo.framepointer_offset;
                               instr.operands[operandnum].ref.base :=
                                 procinfo.framepointer;
                             end
                           else
                             Message(assem_e_cannot_use___OLDEBP_outside_nested_procedure);
                         end { endif actasmpattern = '__OLDEBP' }
                         else
                         { check for direct symbolic names   }
                         { only if compiling the system unit }
                         if (cs_compilesystem in aktmoduleswitches) then
                         begin
                           if not SearchDirectVar(instr,actasmpattern,operandnum) then
                           Begin
                            { not found, finally ... add it anyways ... }
                            Message1(assem_w_id_supposed_external,actasmpattern);
                            instr.operands[operandnum].ref.symbol := newpasstr(actasmpattern);
                           end;
                         end
                         else
                          Message1(assem_e_unknown_id,actasmpattern);
                      end;
                     { constant expression? }
                     if (instr.operands[operandnum].operandtype=OPR_CONSTANT) then
                      instr.operands[operandnum].val := BuildExpression
                     else
                      begin
                        expr := actasmpattern;
                        Consume(AS_ID);
                        case actasmtoken of
                           AS_LPAREN: Begin
                                      { indexing }
                                       previous_was_id:=FALSE;
                                        BuildReference(instr);
                                      end;
                           AS_DOT :  Begin
                                       GetRecordOffsetSize(expr,toffset,tsize);
                                       inc(instr.operands[operandnum].ref.offset,toffset);
                                       SetOperandSize(instr,operandnum,tsize);
                                     end;
                           AS_SEPARATOR,AS_COMMA: ;
                        else
                           Message(assem_e_syntax_error);
                        end; { end case }
                     end;
                     { restore normal context }
                     previous_was_id := FALSE;
                   end; { end if }
               end; { end if }
             end; { end this case }
   { // Register, a variable reference or a constant reference // }
     AS_REGISTER: Begin
                   { save the type of register used. }
                   tempstr := actasmpattern;
                   Consume(AS_REGISTER);
                   if actasmtoken = AS_COLON then
                   Begin
                      Consume(AS_COLON);
                      initAsmRef(instr);
                      instr.operands[operandnum].ref.segment := findsegment(tempstr);
                      { here we can have either an identifier }
                      { or a constant, where either can be    }
                      { followed by a parenthesis...          }
                      { // Constant memory offset .              // }
                      { // This must absolutely be followed by ( // }
                      case actasmtoken of
                        AS_HEXNUM,AS_INTNUM,AS_MINUS,
                        AS_BINNUM,AS_OCTALNUM,AS_PLUS
                        :  Begin
                                       instr.operands[operandnum].
                                       ref.offset:=BuildRefExpression(False);
                                       BuildReference(instr);
                                      end;
                        AS_LPAREN: BuildReference(instr);
                        { only a variable is allowed ... }
                        AS_ID: Begin
                                 { is it a normal variable ? }
                                 if not CreateVarInstr(instr,actasmpattern,operandnum)
                                 then
                                 begin
                                  {  check for direct symbolic names   }
                                   { only if compiling the system unit }
                                   if (cs_compilesystem in aktmoduleswitches) then
                                   begin
                                     if not SearchDirectVar(instr,actasmpattern,operandnum) then
                                        Message(assem_e_invalid_seg_override);
                                   end
                                   else
                                        Message(assem_e_invalid_seg_override);
                                 end;
                                 Consume(actasmtoken);
                                 case actasmtoken of
                                   AS_SEPARATOR,AS_COMMA: ;
                                   AS_LPAREN: BuildReference(instr);
                                 else
                                  Begin
                                   Message(assem_e_invalid_seg_override);
                                   Consume(actasmtoken);
                                  end;
                                 end; {end case }
                               end;
                      else
                          Begin
                            Message(assem_e_invalid_seg_override);
                            Consume(actasmtoken);
                          end;
                      end; { end case }
                   end
                   { // Simple register // }
                   else if (actasmtoken = AS_SEPARATOR) or (actasmtoken = AS_COMMA) then
                   Begin
                        if not (instr.operands[operandnum].operandtype in [OPR_NONE,OPR_REGISTER]) then
                         Message(assem_e_invalid_operand_type);
                        instr.operands[operandnum].operandtype := OPR_REGISTER;
                        instr.operands[operandnum].reg := findregister(tempstr);
                   end
                   else
                    Message1(assem_e_syn_register,tempstr);
                 end;
     AS_SEPARATOR, AS_COMMA: ;
    else
     Begin
      Message(assem_e_syn_opcode_operand);
      Consume(actasmtoken);
     end;
  end; { end case }
 end;



  Procedure BuildConstant(maxvalue: longint);
  {*********************************************************************}
  { PROCEDURE BuildConstant                                             }
  {  Description: This routine takes care of parsing a DB,DD,or DW      }
  {  line and adding those to the assembler node. Expressions, range-   }
  {  checking are fullly taken care of.                                 }
  {   maxvalue: $ff -> indicates that this is a DB node.                }
  {             $ffff -> indicates that this is a DW node.              }
  {             $ffffffff -> indicates that this is a DD node.          }
  {*********************************************************************}
  { EXIT CONDITION:  On exit the routine should point to AS_SEPARATOR.  }
  {*********************************************************************}
  var
   strlength: byte;
   expr: string;
   value : longint;
  Begin
      Repeat
        Case actasmtoken of
          AS_STRING: Begin
                      if maxvalue = $ff then
                         strlength := 1
                      else
                         Message(assem_e_string_not_allowed_as_const);
                      expr := actasmpattern;
                      if length(expr) > 1 then
                       Message(assem_e_string_not_allowed_as_const);
                      Consume(AS_STRING);
                      Case actasmtoken of
                       AS_COMMA: Consume(AS_COMMA);
                       AS_SEPARATOR: ;
                      else
                         Message(assem_e_invalid_string_expression);
                      end; { end case }
                      ConcatString(p,expr);
                    end;
          AS_INTNUM,AS_BINNUM,
          AS_OCTALNUM,AS_HEXNUM:
                    Begin
                      value:=BuildExpression;
                      ConcatConstant(p,value,maxvalue);
                    end;
          AS_ID:
                     Begin
                      value:=BuildExpression;
                      if value > maxvalue then
                      Begin
                         Message(assem_e_expression_out_of_bounds);
                         { assuming a value of maxvalue }
                         value := maxvalue;
                      end;
                      ConcatConstant(p,value,maxvalue);
                  end;
          { These terms can start an assembler expression }
          AS_PLUS,AS_MINUS,AS_LPAREN,AS_NOT: Begin
                                          value := BuildExpression;
                                          ConcatConstant(p,value,maxvalue);
                                         end;
          AS_COMMA:  BEGIN
                       Consume(AS_COMMA);
                     END;
          AS_SEPARATOR: ;

        else
         Begin
           Message(assem_f_internal_error_in_buildconstant);
         end;
    end; { end case }
   Until actasmtoken = AS_SEPARATOR;
  end;


  Procedure BuildStringConstant(asciiz: boolean);
  {*********************************************************************}
  { PROCEDURE BuildStringConstant                                       }
  {  Description: Takes care of a ASCII, or ASCIIZ directive.           }
  {   asciiz: boolean -> if true then string will be null terminated.   }
  {*********************************************************************}
  { EXIT CONDITION:  On exit the routine should point to AS_SEPARATOR.  }
  { On ENTRY: Token should point to AS_STRING                           }
  {*********************************************************************}
  var
   expr: string;
   errorflag : boolean;
  Begin
      errorflag := FALSE;
      Repeat
        Case actasmtoken of
          AS_STRING: Begin
                      expr:=actasmpattern;
                      if asciiz then
                       expr:=expr+#0;
                      ConcatPasString(p,expr);
                      Consume(AS_STRING);
                    end;
          AS_COMMA:  BEGIN
                       Consume(AS_COMMA);
                     END;
          AS_SEPARATOR: ;
        else
         Begin
          Consume(actasmtoken);
          if not errorflag then
           Message(assem_e_invalid_string_expression);
          errorflag := TRUE;
         end;
    end; { end case }
   Until actasmtoken = AS_SEPARATOR;
  end;




  Procedure BuildOpCode;
  {*********************************************************************}
  { PROCEDURE BuildOpcode;                                              }
  {  Description: Parses the intel opcode and operands, and writes it   }
  {  in the TInstruction object.                                        }
  {*********************************************************************}
  { EXIT CONDITION:  On exit the routine should point to AS_SEPARATOR.  }
  { On ENTRY: Token should point to AS_OPCODE                           }
  {*********************************************************************}
  var asmtok: tasmop;
      op: tasmop;
      expr: string;
      segreg: tregister;
  Begin
    expr := '';
    asmtok := A_NONE; { assmume no prefix          }
    segreg := R_NO;   { assume no segment override }

    { //  prefix seg opcode               // }
    { //  prefix opcode                   // }
    if findprefix(actasmpattern,asmtok) then
    Begin
     { standard opcode prefix }
     if asmtok <> A_NONE then
       instr.addprefix(asmtok);
     Consume(AS_OPCODE);
    end;
    { //  opcode                          // }
    { allow for newline as in gas styled syntax }
    { under DOS you get two AS_SEPARATOR !! }
    while actasmtoken=AS_SEPARATOR do
      Consume(AS_SEPARATOR);
    if (actasmtoken <> AS_OPCODE) then
    Begin
      Message(assem_e_invalid_or_missing_opcode);
      { error recovery }
      While not (actasmtoken in [AS_SEPARATOR,AS_COMMA,AS_END]) do
         Consume(actasmtoken);
      exit;
    end
    else
    Begin
      op := findopcode(actasmpattern);
      instr.addinstr(op);
      { // Valid combination of prefix and instruction ? // }
      if (asmtok <> A_NONE) and (NOT CheckPrefix(asmtok,op)) then
        Message1(assem_e_invalid_prefix_and_opcode,actasmpattern);
      Consume(AS_OPCODE);
      { // Zero operand opcode ? // }
      if actasmtoken in [AS_SEPARATOR,AS_END] then
        exit
      else
        operandnum := 1;
    end;

    repeat
      case actasmtoken of
         { //  Operand delimiter // }
         AS_COMMA: Begin
                  if operandnum > MaxOperands then
                    Message(assem_e_too_many_operands)
                  else
                    Inc(operandnum);
                  Consume(AS_COMMA);
                end;
         { // End of asm operands for this opcode // }
         AS_SEPARATOR,
         AS_END : break;
       else
         BuildOperand(instr);
     end; { end case }
    until false;
  end;




  Function Assemble: Ptree;
  {*********************************************************************}
  { PROCEDURE Assemble;                                                 }
  {  Description: Parses the att assembler syntax, parsing is done      }
  {  according to GAs rules.                                            }
  {*********************************************************************}
  Var
   hl: plabel;
   labelptr,nextlabel : pasmlabel;
   commname : string;
   store_p : paasmoutput;

  Begin
    Message(assem_d_start_att);
    firsttoken := TRUE;
    operandnum := 0;
    if assigned(procinfo.retdef) and
       (is_fpu(procinfo.retdef) or
       ret_in_acc(procinfo.retdef)) then
      procinfo.funcret_is_valid:=true;
    { sets up all opcode and register tables in uppercase }
    if not _asmsorted then
    Begin
      SetupTables;
      _asmsorted := TRUE;
    end;
    p:=new(paasmoutput,init);
    { save pointer code section }
    store_p:=p;
    { setup label linked list }
    labellist.init;
    c:=current_scanner^.asmgetchar;
    actasmtoken:=gettoken;

    repeat
      case actasmtoken of
        AS_LLABEL: Begin
                    labelptr := labellist.search(actasmpattern);
                    if not assigned(labelptr) then
                    Begin
                        getlabel(hl);
                        labellist.insert(actasmpattern,hl,TRUE);
                        ConcatLabel(p,A_LABEL,hl);
                    end
                    else
                    { the label has already been inserted into the  }
                    { label list, either as an instruction label (in}
                    { this case it has not been emitted), or as a   }
                    { duplicate local symbol (in this case it has   }
                    { already been emitted).                        }
                    Begin
                       if labelptr^.emitted then
                        Message1(assem_e_dup_local_sym,'.L'+labelptr^.name^)
                       else
                        Begin
                          if assigned(labelptr^.lab) then
                            ConcatLabel(p,A_LABEL,labelptr^.lab);
                          labelptr^.emitted := TRUE;
                        end;
                    end;
                    Consume(AS_LLABEL);
                  end;
        AS_LABEL: Begin
                     { when looking for Pascal labels, these must }
                     { be in uppercase.                           }
                     if SearchLabel(upper(actasmpattern),hl) then
                       ConcatLabel(p,A_LABEL, hl)
                     else
                     Begin
                       if (cs_compilesystem in aktmoduleswitches) then
                       begin
                          Message1(assem_e_unknown_label_identifer,actasmpattern);
                          { once again we don't know what it represents }
                          { so we simply concatenate it                 }
                          ConcatLocal(p,actasmpattern);
                       end
                       else
                        Message1(assem_e_unknown_label_identifer,actasmpattern);
                     end;
                     Consume(AS_LABEL);
                 end;
        AS_DW:   Begin
                   Consume(AS_DW);
                   BuildConstant($ffff);
                 end;
        AS_DATA: Begin
                 { -- this should only be allowed for system development -- }
                 {    i think this should be fixed in the dos unit, and     }
                 {    not here.                                             }
                   if (cs_compilesystem in aktmoduleswitches) then
                       p:=datasegment
                   else
                       Message(assem_e_switching_sections_not_allowed);
                   Consume(AS_DATA);
                 end;
        AS_TEXT: Begin
                 { -- this should only be allowed for system development -- }
                 {    i think this should be fixed in the dos unit, and     }
                 {    not here.                                             }
                   if (cs_compilesystem in aktmoduleswitches) then
                        p:=store_p
                   else
                       Message(assem_e_switching_sections_not_allowed);
                   Consume(AS_TEXT);
                 end;
        AS_DB:   Begin
                  Consume(AS_DB);
                  BuildConstant($ff);
                end;
        AS_DD:   Begin
                 Consume(AS_DD);
                 BuildConstant($ffffffff);
                end;
        AS_DQ:  Begin
                 Consume(AS_DQ);
                 BuildRealConstant(s64bit);
                end;
        AS_SINGLE:   Begin
                 Consume(AS_SINGLE);
                 BuildRealConstant(s32real);
                end;
        AS_DOUBLE:   Begin
                 Consume(AS_DOUBLE);
                 BuildRealConstant(s64real);
                end;
        AS_EXTENDED:   Begin
                 Consume(AS_EXTENDED);
                 BuildRealConstant(s80real);
                end;
        AS_GLOBAL:
                  Begin
                   { normal units should not be able to declare }
                   { direct label names like this... anyhow     }
                   { procedural calls in asm blocks are         }
                   { supposedely replaced automatically         }
                   if (cs_compilesystem in aktmoduleswitches) then
                   begin
                     Consume(AS_GLOBAL);
                      if actasmtoken <> AS_ID then
                        Message(assem_e_invalid_global_def)
                      else
                        ConcatPublic(p,actasmpattern);
                      Consume(actasmtoken);
                      if actasmtoken <> AS_SEPARATOR then
                      Begin
                        Message(assem_e_line_separator_expected);
                        while actasmtoken <> AS_SEPARATOR do
                         Consume(actasmtoken);
                      end;
                   end
                   else
                   begin
                     Message(assem_w_globl_not_supported);
                     while actasmtoken <> AS_SEPARATOR do
                       Consume(actasmtoken);
                   end;
                  end;
        AS_ALIGN: Begin
                    Message(assem_w_align_not_supported);
                    while actasmtoken <> AS_SEPARATOR do
                     Consume(actasmtoken);
                  end;
        AS_ASCIIZ: Begin
                     Consume(AS_ASCIIZ);
                     BuildStringConstant(TRUE);
                   end;
        AS_ASCII: Begin
                    Consume(AS_ASCII);
                    BuildStringConstant(FALSE);
                  end;
        AS_LCOMM: Begin
                 { -- this should only be allowed for system development -- }
                 { -- otherwise may mess up future enhancements we might -- }
                 { -- add.                                               -- }
                   if (cs_compilesystem in aktmoduleswitches) then
                   begin
                     Consume(AS_LCOMM);
                      if actasmtoken <> AS_ID then
                        begin
                           Message(assem_e_invalid_lcomm_def);
                           { error recovery }
                           while actasmtoken <> AS_SEPARATOR do
                            Consume(actasmtoken);
                        end
                      else
                        begin
                           commname:=actasmpattern;
                           Consume(AS_COMMA);
                           ConcatLocalBss(actasmpattern,BuildExpression);
                           if actasmtoken <> AS_SEPARATOR then
                             Begin
                                Message(assem_e_line_separator_expected);
                                while actasmtoken <> AS_SEPARATOR do
                                  Consume(actasmtoken);
                             end;
                        end;
                   end
                   else
                   begin
                        Message(assem_w_lcomm_not_supported);
                        while actasmtoken <> AS_SEPARATOR do
                          Consume(actasmtoken);
                   end;
                  end;
        AS_COMM: Begin
                 { -- this should only be allowed for system development -- }
                 { -- otherwise may mess up future enhancements we might -- }
                 { -- add.                                               -- }
                   if (cs_compilesystem in aktmoduleswitches) then
                   begin
                     Consume(AS_COMM);
                      if actasmtoken <> AS_ID then
                        begin
                           Message(assem_e_invalid_comm_def);
                           { error recovery }
                           while actasmtoken <> AS_SEPARATOR do
                            Consume(actasmtoken);
                        end
                      else
                        begin
                           commname:=actasmpattern;
                           Consume(AS_COMMA);
                           ConcatGlobalBss(actasmpattern,BuildExpression);
                           if actasmtoken <> AS_SEPARATOR then
                           Begin
                             Message(assem_e_line_separator_expected);
                             while actasmtoken <> AS_SEPARATOR do
                              Consume(actasmtoken);
                           end;
                        end;
                   end
                   else
                   begin
                      Message(assem_w_comm_not_supported);
                      while actasmtoken <> AS_SEPARATOR do
                       Consume(actasmtoken);
                   end;
                 end;
        AS_OPCODE: Begin
                   instr.init;
                   BuildOpcode;
                   instr.numops := operandnum;
                   if instr.labeled then
                     ConcatLabeledInstr(instr)
                   else
                     ConcatOpCode(instr);
                   instr.done;
                  end;
        AS_SEPARATOR:Begin
                     Consume(AS_SEPARATOR);
                     { let us go back to the first operand }
                     operandnum := 0;
                    end;
        AS_END: break; { end assembly block }
    else
      Begin
         Message(assem_e_assemble_node_syntax_error);
         { error recovery }
         Consume(actasmtoken);
      end;
    end; { end case }
  until false;

  { check if there were undefined symbols.   }
  { if so, then list each of those undefined }
  { labels.                                  }
  if assigned(labellist.First) then
  Begin
    labelptr := labellist.First;
    While labelptr <> nil do
      Begin
         nextlabel:=labelptr^.next;
         if not labelptr^.emitted  then
          Message1(assem_e_local_sym_not_found_in_asm_statement,'.L'+labelptr^.name^);
         labelptr:=nextlabel;
      end;
  end;
  if p<>store_p then
    begin
       Message(assem_e_assembler_code_not_returned_to_text);
       p:=store_p;
    end;
  assemble := genasmnode(p);
  labellist.done;
  Message(assem_d_finish_att);
end;


var
  old_exit: pointer;

procedure ra386att_exit;{$ifndef FPC}far;{$endif}
begin
  if assigned(iasmops) then
    dispose(iasmops);
  exitproc:=old_exit;
end;


Begin
  previous_was_id := FALSE;
  line:='';
  { you will get range problems here }
  if lastop_in_table > last_instruction_in_cache then
   Internalerror(2111);
  old_exit := exitproc;
  exitproc := @ra386att_exit;
end.

{
  $Log$
  Revision 1.25  1998-12-09 13:23:40  jonas
    * replaced two "in [A_...]" constructs I had missed before
    * for shrd/shld: "if operands[1].operandtype = OPR_CONSTANT" instead of
      "if operands[3].operandtype ..."

  Revision 1.24  1998/12/08 23:03:48  jonas
    * allow constant offsets for go32v2 in assembler blocks

  Revision 1.23  1998/12/02 16:23:33  jonas
    * changed "if longintvar in set" to case or "if () or () .." statements
    * tree.pas: changed inlinenumber (and associated constructor/vars) to a byte

  Revision 1.22  1998/11/29 12:47:21  peter
    * fixes for 'asm sti end;'

  Revision 1.21  1998/11/16 15:38:54  peter
    * fixed instruct not in table msg

  Revision 1.20  1998/11/13 15:40:27  pierre
    + added -Se in Makefile cvstest target
    + lexlevel cleanup
      normal_function_level main_program_level and unit_init_level defined
    * tins_cache grown to A_EMMS (gave range check error in asm readers)
      (test added in code !)
    * -Un option was wrong
    * _FAIL and _SELF only keyword inside
      constructors and methods respectively

  Revision 1.19  1998/11/13 10:12:16  peter
    * constant fixes

  Revision 1.18  1998/11/05 23:48:26  peter
    * recordtype.field support in constant expressions
    * fixed imul for oa_imm8 which was not allowed
    * fixed reading of local typed constants
    * fixed comment reading which is not any longer a separator

  Revision 1.17  1998/10/28 21:34:39  peter
    * fixed some opsize

  Revision 1.16  1998/10/28 00:08:48  peter
    + leal procsym,eax is now allowed
    + constants are now handled also when starting an expression
    + call *pointer is now allowed

  Revision 1.15  1998/10/13 16:50:16  pierre
    * undid some changes of Peter that made the compiler wrong
      for m68k (I had to reinsert some ifdefs)
    * removed several memory leaks under m68k
    * removed the meory leaks for assembler readers
    * cross compiling shoud work again better
      ( crosscompiling sysamiga works
       but as68k still complain about some code !)

  Revision 1.14  1998/10/07 04:28:52  carl
    * bugfix of in/out with gas (ins/outs still left though)
    * bugfix of wrong error output with concatlabel
    * gettoken always returns something valid now

  Revision 1.13  1998/09/24 17:52:31  carl
    * bugfix from fix branch

  Revision 1.12.2.1  1998/09/24 17:47:16  carl
    * bugfix with objects/records access

  Revision 1.12  1998/09/03 17:08:46  pierre
    * better lines for stabs
      (no scroll back to if before else part
      no return to case line at jump outside case)
    + source lines also if not in order

  Revision 1.11  1998/09/02 15:16:44  carl
    * indirect register refs with movsx/movzx fixed

  Revision 1.10  1998/09/02 01:24:09  carl
    * bugfix of PUSH opcode with constants

  Revision 1.9  1998/08/21 08:45:49  pierre
    * better line info for asm statements

  Revision 1.8  1998/08/19 16:07:54  jonas
    * changed optimizer switches + cleanup of DestroyRefs in daopt386.pas

  Revision 1.7  1998/08/10 23:57:23  peter
    * use bestreal instead of extended

  Revision 1.6  1998/08/10 14:50:21  peter
    + localswitches, moduleswitches, globalswitches splitting

  Revision 1.5  1998/07/14 14:46:58  peter
    * released NEWINPUT

  Revision 1.4  1998/07/08 15:06:41  daniel
  + $N+,E+ added for TP.

  Revision 1.3  1998/07/07 11:20:07  peter
    + NEWINPUT for a better inputfile and scanner object

  Revision 1.2  1998/06/24 14:06:36  peter
    * fixed the name changes

  Revision 1.1  1998/06/23 14:00:17  peter
    * renamed RA* units

  Revision 1.13  1998/06/16 08:56:29  peter
    + targetcpu
    * cleaner pmodules for newppu

  Revision 1.12  1998/06/12 10:32:35  pierre
    * column problem hopefully solved
    + C vars declaration changed

  Revision 1.11  1998/05/31 14:13:35  peter
    * fixed call bugs with assembler readers
    + OPR_SYMBOL to hold a symbol in the asm parser
    * fixed staticsymtable vars which were acessed through %ebp instead of
      name

  Revision 1.10  1998/05/30 14:31:08  peter
    + $ASMMODE

  Revision 1.9  1998/05/29 09:58:16  pierre
    * OPR_REGISTER for 1 arg was missing in ratti386.pas
      (probably a merging problem)
    * errors at start of line were lost

  Revision 1.8  1998/05/28 16:34:36  carl
     * call bugfix
     * operand with regs bugfix (manual patch in both cases)

  Revision 1.7  1998/05/23 01:21:27  peter
    + aktasmmode, aktoptprocessor, aktoutputformat
    + smartlink per module $SMARTLINK-/+ (like MMX) and moved to aktswitches
    + $LIBNAME to set the library name where the unit will be put in
    * splitted cgi386 a bit (codeseg to large for bp7)
    * nasm, tasm works again. nasm moved to ag386nsm.pas

  Revision 1.6  1998/05/20 09:42:37  pierre
    + UseTokenInfo now default
    * unit in interface uses and implementation uses gives error now
    * only one error for unknown symbol (uses lastsymknown boolean)
      the problem came from the label code !
    + first inlined procedures and function work
      (warning there might be allowed cases were the result is still wrong !!)
    * UseBrower updated gives a global list of all position of all used symbols
      with switch -gb

  Revision 1.5  1998/04/29 13:52:23  peter
    * small optimize fix

  Revision 1.4  1998/04/29 10:34:04  pierre
    + added some code for ansistring (not complete nor working yet)
    * corrected operator overloading
    * corrected nasm output
    + started inline procedures
    + added starstarn : use ** for exponentiation (^ gave problems)
    + started UseTokenInfo cond to get accurate positions

  Revision 1.3  1998/04/08 16:58:07  pierre
    * several bugfixes
      ADD ADC and AND are also sign extended
      nasm output OK (program still crashes at end
      and creates wrong assembler files !!)
      procsym types sym in tdef removed !!
}

