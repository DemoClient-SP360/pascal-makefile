{
    $Id$
    Copyright (c) 1998-2002 by Florian Klaempfl

    Does the parsing of the statements

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
unit pstatmnt;

{$i fpcdefs.inc}

interface
    uses
      tokens,node;


    function statement_block(starttoken : ttoken) : tnode;

    { reads an assembler block }
    function assembler_block : tnode;


implementation

    uses
       { common }
       cutils,
       { global }
       globtype,globals,verbose,
       systems,cpuinfo,
       { aasm }
       cpubase,aasmbase,aasmtai,aasmcpu,
       { symtable }
       symconst,symbase,symtype,symdef,symsym,symtable,defutil,defcmp,
       paramgr,
       { pass 1 }
       pass_1,htypechk,
       nbas,nmat,nadd,ncal,nmem,nset,ncnv,ninl,ncon,nld,nflw,
       { parser }
       scanner,
       pbase,pexpr,
       { codegen }
       tgobj,rgobj,cgbase
       ,ncgutil
       ,radirect
{$ifdef i386}
  {$ifndef NoRa386Int}
       ,ra386int
  {$endif NoRa386Int}
  {$ifndef NoRa386Att}
       ,ra386att
  {$endif NoRa386Att}
{$else}
       ,rasm
{$endif i386}
       ;


    function statement : tnode;forward;


    function if_statement : tnode;
      var
         ex,if_a,else_a : tnode;
      begin
         consume(_IF);
         ex:=comp_expr(true);
         consume(_THEN);
         if token<>_ELSE then
           if_a:=statement
         else
           if_a:=nil;

         if try_to_consume(_ELSE) then
            else_a:=statement
         else
           else_a:=nil;
         if_statement:=genloopnode(ifn,ex,if_a,else_a,false);
      end;

    { creates a block (list) of statements, til the next END token }
    function statements_til_end : tnode;

      var
         first,last : tstatementnode;

      begin
         first:=nil;
         while token<>_END do
           begin
              if first=nil then
                begin
                   last:=cstatementnode.create(statement,nil);
                   first:=last;
                end
              else
                begin
                   last.right:=cstatementnode.create(statement,nil);
                   last:=tstatementnode(last.right);
                end;
              if not try_to_consume(_SEMICOLON) then
                break;
              consume_emptystats;
           end;
         consume(_END);
         statements_til_end:=cblocknode.create(first,true);
      end;


    function case_statement : tnode;
      var
         { contains the label number of currently parsed case block }
         aktcaselabel : tasmlabel;
         firstlabel : boolean;
         root : pcaserecord;

         { the typ of the case expression }
         casedef : tdef;

      procedure newcaselabel(l,h : TConstExprInt;first:boolean);

        var
           hcaselabel : pcaserecord;

        procedure insertlabel(var p : pcaserecord);

          begin
             if p=nil then p:=hcaselabel
             else
                if (p^._low>hcaselabel^._low) and
                   (p^._low>hcaselabel^._high) then
                  if (hcaselabel^.statement = p^.statement) and
                     (p^._low = hcaselabel^._high + 1) then
                    begin
                      p^._low := hcaselabel^._low;
                      dispose(hcaselabel);
                    end
                  else
                    insertlabel(p^.less)
                else
                  if (p^._high<hcaselabel^._low) and
                     (p^._high<hcaselabel^._high) then
                    if (hcaselabel^.statement = p^.statement) and
                       (p^._high+1 = hcaselabel^._low) then
                      begin
                        p^._high := hcaselabel^._high;
                        dispose(hcaselabel);
                      end
                    else
                      insertlabel(p^.greater)
                  else Message(parser_e_double_caselabel);
          end;

        begin
           new(hcaselabel);
           hcaselabel^.less:=nil;
           hcaselabel^.greater:=nil;
           hcaselabel^.statement:=aktcaselabel;
           hcaselabel^.firstlabel:=first;
           objectlibrary.getlabel(hcaselabel^._at);
           hcaselabel^._low:=l;
           hcaselabel^._high:=h;
           insertlabel(root);
        end;

      var
         code,caseexpr,p,instruc,elseblock : tnode;
         hl1,hl2 : TConstExprInt;
         casedeferror : boolean;

      begin
         consume(_CASE);
         caseexpr:=comp_expr(true);
       { determines result type }
       {$ifndef newra}
         rg.cleartempgen;
       {$endif}
         do_resulttypepass(caseexpr);
         casedeferror:=false;
         casedef:=caseexpr.resulttype.def;
         if (not assigned(casedef)) or
            not(is_ordinal(casedef)) then
          begin
            CGMessage(type_e_ordinal_expr_expected);
            { create a correct tree }
            caseexpr.free;
            caseexpr:=cordconstnode.create(0,u32bittype,false);
            { set error flag so no rangechecks are done }
            casedeferror:=true;
          end;

         consume(_OF);
         inc(statement_level);
         root:=nil;
         instruc:=nil;
         repeat
           objectlibrary.getlabel(aktcaselabel);
           firstlabel:=true;

           { maybe an instruction has more case labels }
           repeat
             p:=expr;
             if is_widechar(casedef) then
               begin
                  if (p.nodetype=rangen) then
                    begin
                       trangenode(p).left:=ctypeconvnode.create(trangenode(p).left,cwidechartype);
                       trangenode(p).right:=ctypeconvnode.create(trangenode(p).right,cwidechartype);
                       do_resulttypepass(trangenode(p).left);
                       do_resulttypepass(trangenode(p).right);
                    end
                  else
                    begin
                       p:=ctypeconvnode.create(p,cwidechartype);
                       do_resulttypepass(p);
                    end;
               end;

             hl1:=0;
             hl2:=0;
             if (p.nodetype=rangen) then
               begin
                  { type checking for case statements }
                  if is_subequal(casedef, trangenode(p).left.resulttype.def) and
                     is_subequal(casedef, trangenode(p).right.resulttype.def) then
                    begin
                      hl1:=get_ordinal_value(trangenode(p).left);
                      hl2:=get_ordinal_value(trangenode(p).right);
                      if hl1>hl2 then
                        CGMessage(parser_e_case_lower_less_than_upper_bound);
                      if not casedeferror then
                       begin
                         testrange(casedef,hl1,false);
                         testrange(casedef,hl2,false);
                       end;
                    end
                  else
                    CGMessage(parser_e_case_mismatch);
                  newcaselabel(hl1,hl2,firstlabel);
               end
             else
               begin
                  { type checking for case statements }
                  if not is_subequal(casedef, p.resulttype.def) then
                    CGMessage(parser_e_case_mismatch);
                  hl1:=get_ordinal_value(p);
                  if not casedeferror then
                    testrange(casedef,hl1,false);
                  newcaselabel(hl1,hl1,firstlabel);
               end;
             p.free;
             if token=_COMMA then
               consume(_COMMA)
             else
               break;
             firstlabel:=false;
           until false;
           consume(_COLON);

           { handles instruction block }
           p:=clabelnode.createcase(aktcaselabel,statement);

           { concats instruction }
           instruc:=cstatementnode.create(p,instruc);

           if not(token in [_ELSE,_OTHERWISE,_END]) then
             consume(_SEMICOLON);
         until (token in [_ELSE,_OTHERWISE,_END]);

         if (token in [_ELSE,_OTHERWISE]) then
           begin
              if not try_to_consume(_ELSE) then
                consume(_OTHERWISE);
              elseblock:=statements_til_end;
           end
         else
           begin
              elseblock:=nil;
              consume(_END);
           end;
         dec(statement_level);

         code:=ccasenode.create(caseexpr,instruc,root);

         tcasenode(code).elseblock:=elseblock;

         case_statement:=code;
      end;


    function repeat_statement : tnode;

      var
         first,last,p_e : tnode;

      begin
         consume(_REPEAT);
         first:=nil;
         inc(statement_level);

         while token<>_UNTIL do
           begin
              if first=nil then
                begin
                   last:=cstatementnode.create(statement,nil);
                   first:=last;
                end
              else
                begin
                   tstatementnode(last).right:=cstatementnode.create(statement,nil);
                   last:=tstatementnode(last).right;
                end;
              if not try_to_consume(_SEMICOLON) then
                break;
              consume_emptystats;
           end;
         consume(_UNTIL);
         dec(statement_level);

         first:=cblocknode.create(first,true);
         p_e:=comp_expr(true);
         repeat_statement:=genloopnode(whilerepeatn,p_e,first,nil,true);
      end;


    function while_statement : tnode;

      var
         p_e,p_a : tnode;

      begin
         consume(_WHILE);
         p_e:=comp_expr(true);
         consume(_DO);
         p_a:=statement;
         while_statement:=genloopnode(whilerepeatn,p_e,p_a,nil,false);
      end;


    function for_statement : tnode;

      var
         p_e,tovalue,p_a : tnode;
         backward : boolean;

      begin
         { parse loop header }
         consume(_FOR);
         p_e:=expr;
         if token=_DOWNTO then
           begin
              consume(_DOWNTO);
              backward:=true;
           end
         else
           begin
              consume(_TO);
              backward:=false;
           end;
         tovalue:=comp_expr(true);
         consume(_DO);

         { ... now the instruction }
         p_a:=statement;
         for_statement:=genloopnode(forn,p_e,tovalue,p_a,backward);
      end;


    function _with_statement : tnode;

      var
         right,p : tnode;
         i,levelcount : longint;
         withsymtable,symtab : tsymtable;
         obj : tobjectdef;
         hp : tnode;
      begin
         p:=comp_expr(true);
         do_resulttypepass(p);
         set_varstate(p,false);
         right:=nil;
         if (not codegenerror) and
            (p.resulttype.def.deftype in [objectdef,recorddef]) then
          begin
            case p.resulttype.def.deftype of
              objectdef :
                begin
                   obj:=tobjectdef(p.resulttype.def);
                   symtab:=twithsymtable.Create(obj,obj.symtable.symsearch);
                   withsymtable:=symtab;
                   if (p.nodetype=loadn) and
                      (tloadnode(p).symtable=aktprocdef.localst) then
                     twithsymtable(symtab).direct_with:=true;
                   twithsymtable(symtab).withrefnode:=p;
                   levelcount:=1;
                   obj:=obj.childof;
                   while assigned(obj) do
                    begin
                      symtab.next:=twithsymtable.create(obj,obj.symtable.symsearch);
                      symtab:=symtab.next;
                      if (p.nodetype=loadn) and
                         (tloadnode(p).symtable=aktprocdef.localst) then
                        twithsymtable(symtab).direct_with:=true;
                      twithsymtable(symtab).withrefnode:=p;
                      obj:=obj.childof;
                      inc(levelcount);
                    end;
                   symtab.next:=symtablestack;
                   symtablestack:=withsymtable;
                 end;
              recorddef :
                begin
                   symtab:=trecorddef(p.resulttype.def).symtable;
                   levelcount:=1;
                   withsymtable:=twithsymtable.create(trecorddef(p.resulttype.def),symtab.symsearch);
                   if (p.nodetype=loadn) and
                      (tloadnode(p).symtable=aktprocdef.localst) then
                   twithsymtable(withsymtable).direct_with:=true;
                   twithsymtable(withsymtable).withrefnode:=p;
                   withsymtable.next:=symtablestack;
                   symtablestack:=withsymtable;
                end;
            end;
            if token=_COMMA then
             begin
               consume(_COMMA);
               right:=_with_statement{$ifdef FPCPROCVAR}(){$endif};
             end
            else
             begin
               consume(_DO);
               if token<>_SEMICOLON then
                right:=statement
               else
                right:=cerrornode.create;
             end;
            for i:=1 to levelcount do
             symtablestack:=symtablestack.next;
            _with_statement:=cwithnode.create(twithsymtable(withsymtable),p,right,levelcount);
          end
         else
          begin
            Message(parser_e_false_with_expr);
            { try to recover from error }
            if token=_COMMA then
             begin
               consume(_COMMA);
               hp:=_with_statement{$ifdef FPCPROCVAR}(){$endif};
               if (hp=nil) then; { remove warning about unused }
             end
            else
             begin
               consume(_DO);
               { ignore all }
               if token<>_SEMICOLON then
                statement;
             end;
            _with_statement:=nil;
          end;
      end;


    function with_statement : tnode;
      begin
         consume(_WITH);
         with_statement:=_with_statement;
      end;


    function raise_statement : tnode;

      var
         p,pobj,paddr,pframe : tnode;

      begin
         pobj:=nil;
         paddr:=nil;
         pframe:=nil;
         consume(_RAISE);
         if not(token in endtokens) then
           begin
              { object }
              pobj:=comp_expr(true);
              if try_to_consume(_AT) then
                begin
                   paddr:=comp_expr(true);
                   if try_to_consume(_COMMA) then
                     pframe:=comp_expr(true);
                end;
           end
         else
           begin
              if (block_type<>bt_except) then
                Message(parser_e_no_reraise_possible);
           end;
         p:=craisenode.create(pobj,paddr,pframe);
         raise_statement:=p;
      end;


    function try_statement : tnode;

      var
         p_try_block,p_finally_block,first,last,
         p_default,p_specific,hp : tnode;
         ot : ttype;
         sym : tvarsym;
         old_block_type : tblock_type;
         exceptsymtable : tsymtable;
         objname,objrealname : stringid;
         srsym : tsym;
         srsymtable : tsymtable;
         oldaktexceptblock: integer;

      begin
         procinfo.flags:=procinfo.flags or pi_uses_exceptions;

         p_default:=nil;
         p_specific:=nil;

         { read statements to try }
         consume(_TRY);
         first:=nil;
         inc(exceptblockcounter);
         oldaktexceptblock := aktexceptblock;
         aktexceptblock := exceptblockcounter;
         inc(statement_level);

         while (token<>_FINALLY) and (token<>_EXCEPT) do
           begin
              if first=nil then
                begin
                   last:=cstatementnode.create(statement,nil);
                   first:=last;
                end
              else
                begin
                   tstatementnode(last).right:=cstatementnode.create(statement,nil);
                   last:=tstatementnode(last).right;
                end;
              if not try_to_consume(_SEMICOLON) then
                break;
              consume_emptystats;
           end;
         p_try_block:=cblocknode.create(first,true);

         if try_to_consume(_FINALLY) then
           begin
              inc(exceptblockcounter);
              aktexceptblock := exceptblockcounter;
              p_finally_block:=statements_til_end;
              try_statement:=ctryfinallynode.create(p_try_block,p_finally_block);
              dec(statement_level);
           end
         else
           begin
              consume(_EXCEPT);
              old_block_type:=block_type;
              block_type:=bt_except;
              inc(exceptblockcounter);
              aktexceptblock := exceptblockcounter;
              ot:=generrortype;
              p_specific:=nil;
              if (idtoken=_ON) then
                { catch specific exceptions }
                begin
                   repeat
                     consume(_ID);
                     if token=_ID then
                       begin
                          objname:=pattern;
                          objrealname:=orgpattern;
                          { can't use consume_sym here, because we need already
                            to check for the colon }
                          searchsym(objname,srsym,srsymtable);
                          consume(_ID);
                          { is a explicit name for the exception given ? }
                          if try_to_consume(_COLON) then
                            begin
                               consume_sym(srsym,srsymtable);
                               if (srsym.typ=typesym) and
                                  is_class(ttypesym(srsym).restype.def) then
                                 begin
                                    ot:=ttypesym(srsym).restype;
                                    sym:=tvarsym.create(objrealname,ot);
                                 end
                               else
                                 begin
                                    sym:=tvarsym.create(objrealname,generrortype);
                                    if (srsym.typ=typesym) then
                                      Message1(type_e_class_type_expected,ttypesym(srsym).restype.def.typename)
                                    else
                                      Message1(type_e_class_type_expected,ot.def.typename);
                                 end;
                               exceptsymtable:=tstt_exceptsymtable.create;
                               exceptsymtable.insert(sym);
                               { insert the exception symtable stack }
                               exceptsymtable.next:=symtablestack;
                               symtablestack:=exceptsymtable;
                            end
                          else
                            begin
                               { check if type is valid, must be done here because
                                 with "e: Exception" the e is not necessary }
                               if srsym=nil then
                                begin
                                  identifier_not_found(objrealname);
                                  srsym:=generrorsym;
                                end;
                               { support unit.identifier }
                               if srsym.typ=unitsym then
                                 begin
                                    consume(_POINT);
                                    srsym:=searchsymonlyin(tunitsym(srsym).unitsymtable,pattern);
                                    if srsym=nil then
                                     begin
                                       identifier_not_found(orgpattern);
                                       srsym:=generrorsym;
                                     end;
                                    consume(_ID);
                                 end;
                               { check if type is valid, must be done here because
                                 with "e: Exception" the e is not necessary }
                               if (srsym.typ=typesym) and
                                  is_class(ttypesym(srsym).restype.def) then
                                 ot:=ttypesym(srsym).restype
                               else
                                 begin
                                    ot:=generrortype;
                                    if (srsym.typ=typesym) then
                                      Message1(type_e_class_type_expected,ttypesym(srsym).restype.def.typename)
                                    else
                                      Message1(type_e_class_type_expected,ot.def.typename);
                                 end;
                               exceptsymtable:=nil;
                            end;
                       end
                     else
                       consume(_ID);
                     consume(_DO);
                     hp:=connode.create(nil,statement);
                     if ot.def.deftype=errordef then
                       begin
                          hp.free;
                          hp:=cerrornode.create;
                       end;
                     if p_specific=nil then
                       begin
                          last:=hp;
                          p_specific:=last;
                       end
                     else
                       begin
                          tonnode(last).left:=hp;
                          last:=tonnode(last).left;
                       end;
                     { set the informations }
                     { only if the creation of the onnode was succesful, it's possible }
                     { that last and hp are errornodes (JM)                            }
                     if last.nodetype = onn then
                       begin
                         tonnode(last).excepttype:=tobjectdef(ot.def);
                         tonnode(last).exceptsymtable:=exceptsymtable;
                       end;
                     { remove exception symtable }
                     if assigned(exceptsymtable) then
                       begin
                         symtablestack:=symtablestack.next;
                         if last.nodetype <> onn then
                           exceptsymtable.free;
                       end;
                     if not try_to_consume(_SEMICOLON) then
                        break;
                     consume_emptystats;
                   until (token in [_END,_ELSE]);
                   if try_to_consume(_ELSE) then
                     begin
                       { catch the other exceptions }
                       p_default:=statements_til_end;
                     end
                   else
                     consume(_END);
                end
              else
                begin
                   { catch all exceptions }
                   p_default:=statements_til_end;
                end;
              dec(statement_level);

              block_type:=old_block_type;
              try_statement:=ctryexceptnode.create(p_try_block,p_specific,p_default);
           end;
         aktexceptblock := oldaktexceptblock;
      end;


    function _asm_statement : tnode;
      var
        asmstat : tasmnode;
        Marker  : tai;
        r       : tregister;
        found   : boolean;
        hs      : string;
      begin
         Inside_asm_statement:=true;
         case aktasmmode of
           asmmode_none : ; { just be there to allow to a compile without
                              any assembler readers }
{$ifdef i386}
  {$ifndef NoRA386Att}
           asmmode_i386_att:
             asmstat:=tasmnode(ra386att.assemble);
  {$endif NoRA386Att}
  {$ifndef NoRA386Int}
           asmmode_i386_intel:
             asmstat:=tasmnode(ra386int.assemble);
  {$endif NoRA386Int}
{$else not i386}
           asmmode_standard:
             asmstat:=tasmnode(rasm.assemble);
{$endif i386}
           asmmode_direct:
             begin
               if not target_asm.allowdirect then
                 Message(parser_f_direct_assembler_not_allowed);
               if (aktprocdef.proccalloption=pocall_inline) then
                 Begin
                    Message1(parser_w_not_supported_for_inline,'direct asm');
                    Message(parser_w_inlining_disabled);
                    aktprocdef.proccalloption:=pocall_fpccall;
                 End;
               asmstat:=tasmnode(radirect.assemble);
             end;

         else
           Message(parser_f_assembler_reader_not_supported);
         end;

         { Read first the _ASM statement }
         consume(_ASM);

         { END is read }
         if try_to_consume(_LECKKLAMMER) then
           begin
             if token<>_RECKKLAMMER then
              begin
                repeat
                  { it's possible to specify the modified registers }
                  hs:=upper(pattern);
                  found:=false;
                  for r.enum:=firstreg to lastreg do
                   if hs=upper(std_reg2str[r.enum]) then
                    begin
                      include(rg.usedinproc,r.enum);
                      include(rg.usedbyproc,r.enum);
                      found:=true;
                      break;
                    end;
                  if not(found) then
                    Message(asmr_e_invalid_register);
                  consume(_CSTRING);
                  if not try_to_consume(_COMMA) then
                    break;
                until false;
              end;
             consume(_RECKKLAMMER);
           end
         else
           begin
              rg.usedbyproc := ALL_REGISTERS;
              rg.usedinproc := ALL_REGISTERS;
           end;

         { mark the start and the end of the assembler block
           this is needed for the optimizer }
         If Assigned(AsmStat.p_asm) Then
           Begin
             Marker := Tai_Marker.Create(AsmBlockStart);
             AsmStat.p_asm.Insert(Marker);
             Marker := Tai_Marker.Create(AsmBlockEnd);
             AsmStat.p_asm.Concat(Marker);
           End;
         Inside_asm_statement:=false;
         _asm_statement:=asmstat;
      end;


    function statement : tnode;
      var
         p       : tnode;
         code    : tnode;
         filepos : tfileposinfo;
         srsym   : tsym;
         srsymtable : tsymtable;
         s       : stringid;
      begin
         filepos:=akttokenpos;
         case token of
           _GOTO :
             begin
                if not(cs_support_goto in aktmoduleswitches)then
                 Message(sym_e_goto_and_label_not_supported);
                consume(_GOTO);
                if (token<>_INTCONST) and (token<>_ID) then
                  begin
                     Message(sym_e_label_not_found);
                     code:=cerrornode.create;
                  end
                else
                  begin
                     if token=_ID then
                      consume_sym(srsym,srsymtable)
                     else
                      begin
                        searchsym(pattern,srsym,srsymtable);
                        if srsym=nil then
                         begin
                           identifier_not_found(pattern);
                           srsym:=generrorsym;
                           srsymtable:=nil;
                         end;
                        consume(token);
                      end;

                     if srsym.typ<>labelsym then
                       begin
                          Message(sym_e_id_is_no_label_id);
                          code:=cerrornode.create;
                       end
                     else
                       begin
                         code:=cgotonode.create(tlabelsym(srsym));
                         tgotonode(code).labsym:=tlabelsym(srsym);
                         { set flag that this label is used }
                         tlabelsym(srsym).used:=true;
                       end;
                  end;
             end;
           _BEGIN :
             code:=statement_block(_BEGIN);
           _IF :
             code:=if_statement;
           _CASE :
             code:=case_statement;
           _REPEAT :
             code:=repeat_statement;
           _WHILE :
             code:=while_statement;
           _FOR :
             code:=for_statement;
           _WITH :
             code:=with_statement;
           _TRY :
             code:=try_statement;
           _RAISE :
             code:=raise_statement;
           { semicolons,else until and end are ignored }
           _SEMICOLON,
           _ELSE,
           _UNTIL,
           _END:
             code:=cnothingnode.create;
           _FAIL :
             begin
                if (aktprocdef.proctypeoption<>potype_constructor) then
                  Message(parser_e_fail_only_in_constructor);
                consume(_FAIL);
                code:=cfailnode.create;
             end;
           _ASM :
             code:=_asm_statement;
           _EOF :
             Message(scan_f_end_of_file);
         else
           begin
             p:=expr;

             { When a colon follows a intconst then transform it into a label }
             if try_to_consume(_COLON) then
              begin
                s:=tostr(tordconstnode(p).value);
                p.free;
                searchsym(s,srsym,srsymtable);
                if assigned(srsym) then
                 begin
                   if tlabelsym(srsym).defined then
                    Message(sym_e_label_already_defined);
                   tlabelsym(srsym).defined:=true;
                   p:=clabelnode.create(tlabelsym(srsym),nil);
                 end
                else
                 begin
                   identifier_not_found(s);
                   p:=cnothingnode.create;
                 end;
              end;

             if p.nodetype=labeln then
              begin
                { the pointer to the following instruction }
                { isn't a very clean way                   }
                tlabelnode(p).left:=statement{$ifdef FPCPROCVAR}(){$endif};
                { be sure to have left also resulttypepass }
                resulttypepass(tlabelnode(p).left);
              end;

             { blockn support because a read/write is changed into a blocknode }
             { with a separate statement for each read/write operation (JM)    }
             { the same is true for val() if the third parameter is not 32 bit }
             if not(p.nodetype in [nothingn,calln,assignn,breakn,inlinen,
                                   continuen,labeln,blockn,exitn]) then
               Message(cg_e_illegal_expression);

             { specify that we don't use the value returned by the call }
             { Question : can this be also improtant
               for inlinen ??
               it is used for :
                - dispose of temp stack space
                - dispose on FPU stack }
             if p.nodetype=calln then
               exclude(p.flags,nf_return_value_used);

             code:=p;
           end;
         end;
         if assigned(code) then
          code.set_tree_filepos(filepos);
         statement:=code;
      end;


    function statement_block(starttoken : ttoken) : tnode;

      var
         first,last : tnode;
         filepos : tfileposinfo;

      begin
         first:=nil;
         filepos:=akttokenpos;
         consume(starttoken);
         inc(statement_level);

         while not(token in [_END,_FINALIZATION]) do
           begin
              if first=nil then
                begin
                   last:=cstatementnode.create(statement,nil);
                   first:=last;
                end
              else
                begin
                   tstatementnode(last).right:=cstatementnode.create(statement,nil);
                   last:=tstatementnode(last).right;
                end;
              if (token in [_END,_FINALIZATION]) then
                break
              else
                begin
                   { if no semicolon, then error and go on }
                   if token<>_SEMICOLON then
                     begin
                        consume(_SEMICOLON);
                        consume_all_until(_SEMICOLON);
                     end;
                   consume(_SEMICOLON);
                end;
              consume_emptystats;
           end;

         { don't consume the finalization token, it is consumed when
           reading the finalization block, but allow it only after
           an initalization ! }
         if (starttoken<>_INITIALIZATION) or (token<>_FINALIZATION) then
           consume(_END);

         dec(statement_level);

         last:=cblocknode.create(first,true);
         last.set_tree_filepos(filepos);
         statement_block:=last;
      end;


    function assembler_block : tnode;

      {# Optimize the assembler block by removing all references
         which are via the frame pointer by replacing them with
         references via the stack pointer.

         This is only available to certain cpu targets where
         the frame pointer saving must be done explicitly.
      }
      procedure OptimizeFramePointer(p:tasmnode);
      var
        hp : tai;
        parafixup,
        i : longint;
      begin
        { replace framepointer with stackpointer }
        procinfo.framepointer.enum:=R_INTREGISTER;
        procinfo.framepointer.number:=NR_STACK_POINTER_REG;
        { set the right value for parameters }
        dec(aktprocdef.parast.address_fixup,pointer_size);
        { replace all references to parameters in the instructions,
          the parameters can be identified by the parafixup option
          that is set. For normal user coded [ebp+4] this field is not
          set }
        parafixup:=aktprocdef.parast.address_fixup;
        hp:=tai(p.p_asm.first);
        while assigned(hp) do
         begin
           if hp.typ=ait_instruction then
            begin
              { fixup the references }
              for i:=1 to taicpu(hp).ops do
               begin
                 with taicpu(hp).oper[i-1] do
                  if typ=top_ref then
                   begin
                     case ref^.options of
                       ref_parafixup :
                         begin
                           ref^.offsetfixup:=parafixup;
                           ref^.base.enum:=R_INTREGISTER;
                           ref^.base.number:=NR_STACK_POINTER_REG;
                         end;
                     end;
                   end;
               end;
            end;
           hp:=tai(hp.next);
         end;
      end;

{$ifdef CHECKFORPUSH}
      function UsesPush(p:tasmnode):boolean;
      var
        hp : tai;
      begin
        hp:=tai(p.p_asm.first);
        while assigned(hp) do
         begin
           if (hp.typ=ait_instruction) and
              (taicpu(hp).opcode=A_PUSH) then
            begin
              UsesPush:=true;
              exit;
            end;
           hp:=tai(hp.next);
         end;
        UsesPush:=false;
      end;
{$endif CHECKFORPUSH}

      var
        p : tnode;
      begin
         { Rename the funcret so that recursive calls are possible }
         if not is_void(aktprocdef.rettype.def) then
           symtablestack.rename(aktprocdef.resultname,'$hiddenresult');

         { force the asm statement }
         if token<>_ASM then
           consume(_ASM);
         procinfo.Flags := procinfo.Flags Or pi_is_assembler;
         p:=_asm_statement;

         { set the framepointer to esp for assembler functions when the
           following conditions are met:
           - if the are no local variables (except the allocated result)
           - if the are no parameters
           - no reference to the result variable (refcount<=1)
           - result is not stored as parameter
           - target processor has optional frame pointer save
             (vm, i386, vm only currently)
         }
         if (po_assembler in aktprocdef.procoptions) and
{$ifndef powerpc}
            { is this really necessary??? }
            (aktprocdef.parast.datasize=0) and
{$endif powerpc}
            (aktprocdef.localst.datasize=aktprocdef.rettype.def.size) and
            (aktprocdef.owner.symtabletype<>objectsymtable) and
            (not assigned(aktprocdef.funcretsym) or
             (tvarsym(aktprocdef.funcretsym).refcount<=1)) and
            not(paramanager.ret_in_param(aktprocdef.rettype.def,aktprocdef.proccalloption)) then
            begin
               { we don't need to allocate space for the locals }
               aktprocdef.localst.datasize:=0;
               procinfo.firsttemp_offset:=0;
               { only for cpus with different frame- and stack pointer the code must be changed }
               if (NR_STACK_POINTER_REG<>NR_FRAME_POINTER_REG)
{$ifdef CHECKFORPUSH}
                 and not(UsesPush(tasmnode(p)))
{$endif CHECKFORPUSH}
                 then
                 OptimizeFramePointer(tasmnode(p));
            end;

        { Flag the result as assigned when it is returned in a
          register.
        }
        if assigned(aktprocdef.funcretsym) and
           (not paramanager.ret_in_param(aktprocdef.rettype.def,aktprocdef.proccalloption)) then
          tvarsym(aktprocdef.funcretsym).varstate:=vs_assigned;

        { because the END is already read we need to get the
          last_endtoken_filepos here (PFV) }
        last_endtoken_filepos:=akttokenpos;

        assembler_block:=p;
      end;

end.
{
  $Log$
  Revision 1.93  2003-04-27 07:29:50  peter
    * aktprocdef cleanup, aktprocdef is now always nil when parsing
      a new procdef declaration
    * aktprocsym removed
    * lexlevel removed, use symtable.symtablelevel instead
    * implicit init/final code uses the normal genentry/genexit
    * funcret state checking updated for new funcret handling

  Revision 1.92  2003/04/26 11:30:59  florian
    * fixed the powerpc to work with the new function result handling

  Revision 1.91  2003/04/25 20:59:34  peter
    * removed funcretn,funcretsym, function result is now in varsym
      and aliases for result and function name are added using absolutesym
    * vs_hidden parameter for funcret passed in parameter
    * vs_hidden fixes
    * writenode changed to printnode and released from extdebug
    * -vp option added to generate a tree.log with the nodetree
    * nicer printnode for statements, callnode

  Revision 1.90  2002/04/25 20:15:40  florian
    * block nodes within expressions shouldn't release the used registers,
      fixed using a flag till the new rg is ready

  Revision 1.89  2003/04/25 08:25:26  daniel
    * Ifdefs around a lot of calls to cleartempgen
    * Fixed registers that are allocated but not freed in several nodes
    * Tweak to register allocator to cause less spills
    * 8-bit registers now interfere with esi,edi and ebp
      Compiler can now compile rtl successfully when using new register
      allocator

  Revision 1.88  2003/03/28 19:16:57  peter
    * generic constructor working for i386
    * remove fixed self register
    * esi added as address register for i386

  Revision 1.87  2003/03/17 18:55:30  peter
    * allow more tokens instead of only semicolon after inherited

  Revision 1.86  2003/02/19 22:00:14  daniel
    * Code generator converted to new register notation
    - Horribily outdated todo.txt removed

  Revision 1.85  2003/01/08 18:43:56  daniel
   * Tregister changed into a record

  Revision 1.84  2003/01/01 21:05:24  peter
    * fixed assembler methods stackpointer optimization that was
      broken after the previous change

  Revision 1.83  2002/12/29 18:59:34  peter
    * fixed parsing of declarations before asm statement

  Revision 1.82  2002/12/27 18:18:56  peter
    * check for else after empty raise statement

  Revision 1.81  2002/11/27 02:37:14  peter
    * case statement inlining added
    * fixed inlining of write()
    * switched statementnode left and right parts so the statements are
      processed in the correct order when getcopy is used. This is
      required for tempnodes

  Revision 1.80  2002/11/25 17:43:22  peter
    * splitted defbase in defutil,symutil,defcmp
    * merged isconvertable and is_equal into compare_defs(_ext)
    * made operator search faster by walking the list only once

  Revision 1.79  2002/11/18 17:31:58  peter
    * pass proccalloption to ret_in_xxx and push_xxx functions

  Revision 1.78  2002/09/07 19:34:08  florian
    + tcg.direction is used now

  Revision 1.77  2002/09/07 15:25:07  peter
    * old logs removed and tabs fixed

  Revision 1.76  2002/09/07 12:16:03  carl
    * second part bug report 1996 fix, testrange in cordconstnode
      only called if option is set (also make parsing a tiny faster)

  Revision 1.75  2002/09/02 18:40:52  peter
    * fixed parsing of register names with lowercase

  Revision 1.74  2002/09/01 14:43:12  peter
    * fixed direct assembler for i386

  Revision 1.73  2002/08/25 19:25:20  peter
    * sym.insert_in_data removed
    * symtable.insertvardata/insertconstdata added
    * removed insert_in_data call from symtable.insert, it needs to be
      called separatly. This allows to deref the address calculation
    * procedures now calculate the parast addresses after the procedure
      directives are parsed. This fixes the cdecl parast problem
    * push_addr_param has an extra argument that specifies if cdecl is used
      or not

  Revision 1.72  2002/08/17 09:23:40  florian
    * first part of procinfo rewrite

  Revision 1.71  2002/08/16 14:24:58  carl
    * issameref() to test if two references are the same (then emit no opcodes)
    + ret_in_reg to replace ret_in_acc
      (fix some register allocation bugs at the same time)
    + save_std_register now has an extra parameter which is the
      usedinproc registers

  Revision 1.70  2002/08/11 14:32:27  peter
    * renamed current_library to objectlibrary

  Revision 1.69  2002/08/11 13:24:12  peter
    * saving of asmsymbols in ppu supported
    * asmsymbollist global is removed and moved into a new class
      tasmlibrarydata that will hold the info of a .a file which
      corresponds with a single module. Added librarydata to tmodule
      to keep the library info stored for the module. In the future the
      objectfiles will also be stored to the tasmlibrarydata class
    * all getlabel/newasmsymbol and friends are moved to the new class

  Revision 1.68  2002/08/10 14:46:30  carl
    + moved target_cpu_string to cpuinfo
    * renamed asmmode enum.
    * assembler reader has now less ifdef's
    * move from nppcmem.pas -> ncgmem.pas vec. node.

  Revision 1.67  2002/08/09 19:11:44  carl
    + reading of used registers in assembler routines is now
      cpu-independent

  Revision 1.66  2002/08/06 20:55:22  florian
    * first part of ppc calling conventions fix

  Revision 1.65  2002/07/28 20:45:22  florian
    + added direct assembler reader for PowerPC

  Revision 1.64  2002/07/20 11:57:56  florian
    * types.pas renamed to defbase.pas because D6 contains a types
      unit so this would conflicts if D6 programms are compiled
    + Willamette/SSE2 instructions to assembler added

  Revision 1.63  2002/07/19 11:41:36  daniel
  * State tracker work
  * The whilen and repeatn are now completely unified into whilerepeatn. This
    allows the state tracker to change while nodes automatically into
    repeat nodes.
  * Resulttypepass improvements to the notn. 'not not a' is optimized away and
    'not(a>b)' is optimized into 'a<=b'.
  * Resulttypepass improvements to the whilerepeatn. 'while not a' is optimized
    by removing the notn and later switchting the true and falselabels. The
    same is done with 'repeat until not a'.

  Revision 1.62  2002/07/16 15:34:20  florian
    * exit is now a syssym instead of a keyword

  Revision 1.61  2002/07/11 14:41:28  florian
    * start of the new generic parameter handling

  Revision 1.60  2002/07/04 20:43:01  florian
    * first x86-64 patches

  Revision 1.59  2002/07/01 18:46:25  peter
    * internal linker
    * reorganized aasm layer

  Revision 1.58  2002/05/18 13:34:13  peter
    * readded missing revisions

  Revision 1.57  2002/05/16 19:46:44  carl
  + defines.inc -> fpcdefs.inc to avoid conflicts if compiling by hand
  + try to fix temp allocation (still in ifdef)
  + generic constructor calls
  + start of tassembler / tmodulebase class cleanup

}
