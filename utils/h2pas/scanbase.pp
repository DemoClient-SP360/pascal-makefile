{
    Copyright (c) 1998-2000 by Florian Klaempfl

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


unit scanbase;
{$H+}

interface

uses strings, h2plexlib,h2pyacclib;

const
   version = '1.0.0';

type
   Char=system.char;
   ttyp = (
      t_id,
      { p contains the string }
      t_arraydef,
      { }
      t_pointerdef,
      { p1 contains the definition
        if in type overrider
        or nothing for args
      }
      t_addrdef,

      t_void,
      { no field }
      t_dec,
      { }
      t_declist,
      { p1 is t_dec
        next if exists }
      t_memberdec,
      { p1 is type specifier
        p2 is declarator_list }
      t_structdef,
      { }
      t_memberdeclist,
      { p1 is memberdec
        next is next if it exist }
      t_procdef,
      { }
      t_uniondef,
      { }
      t_enumdef,
      { }
      t_enumlist,
      { }
      t_preop,
      { p contains the operator string
        p1 contains the right expr }
      t_bop,
      { p contains the operator string
        p1 contains the left expr
        p2 contains the right expr }
      t_arrayop,
      {
        p1 contains the array expr
        p2 contains the index expressions }
      t_callop,
      {
        p1 contains the proc expr
        p2 contains the index expressions }
      t_arg,
      {
        p1 contain the typedef
        p2 the declarator (t_dec)
      }
      t_arglist,
      { }
      t_funexprlist,
      { }
      t_exprlist,
      { p1 contains the expr
        next contains the next if it exists }
      t_ifexpr,
      { p1 contains the condition expr
        p2 contains the if branch
        p3 contains the else branch }
      t_funcname,
      { p1 contains the function dname
        p2 contains the funexprlist
        p3 possibly contains the return type }
      t_typespec,
      { p1 is the type itself
        p2 the typecast expr }
      t_size_specifier,
      { p1 expr for size }
      t_default_value,
      { p1 expr for value }
      t_statement_list,
      { p1 is the statement
        next is next if it exist }
      t_whilenode,
      t_fornode,
      t_dowhilenode,
      t_switchnode,
      t_gotonode,
      t_continuenode,
      t_breaknode
      );

const
  ttypstr: array[ttyp] of string =
  (
    't_id',
    't_arraydef',
    't_pointerdef',
    't_addrdef',
    't_void',
    't_dec',
    't_declist',
    't_memberdec',
    't_structdef',
    't_memberdeclist',
    't_procdef',
    't_uniondef',
    't_enumdef',
    't_enumlist',
    't_preop',
    't_bop',
    't_arrayop',
    't_callop',
    't_arg',
    't_arglist',
    't_funexprlist',
    't_exprlist',
    't_ifexpr',
    't_funcname',
    't_typespec',
    't_size_specifier',
    't_default_value',
    't_statement_list',
    't_whilenode',
    't_fornode',
    't_dowhilenode',
    't_switchnode',
    't_gotonode',
    't_continuenode',
    't_breaknode'
  );

type
  presobject = ^tresobject;
  tresobject = object
     typ : ttyp;
     p : pchar;
     next : presobject;
     p1,p2,p3 : presobject;
     { name of int/real, then no T prefix is required }
     intname : boolean;
     constructor init_no(t : ttyp);
     constructor init_one(t : ttyp;_p1 : presobject);
     constructor init_two(t : ttyp;_p1,_p2 : presobject);
     constructor init_three(t : ttyp;_p1,_p2,_p3 : presobject);
     constructor init_id(const s : string);
     constructor init_intid(const s : string);
     constructor init_bop(const s : string;_p1,_p2 : presobject);
     constructor init_preop(const s : string;_p1 : presobject);
     procedure setstr(const s:string);
     function str : string;
     function strlength : byte;
     function get_copy : presobject;
     { can this ve considered as a constant ? }
     function is_const : boolean;
     destructor done;
  end;

  tblocktype = (bt_type,bt_const,bt_var,bt_func,bt_no);


var
   infile : string;
   outfile : text;
   c : char;
   aktspace : string;
   block_type : tblocktype;
   commentstr: string;

const
   in_define : boolean = false;
   { True if define spans to the next line }
   cont_line : boolean = false;
   { 1 after define; 2 after the ID to print the first separating space }
   in_space_define : byte = 0;
   arglevel : longint = 0;

   {> 1 = ifdef level in a ifdef C++ block
      1 = first level in an ifdef block
      0 = not in an ifdef block
     -1 = in else part of ifdef block, process like we weren't in the block
          but skip the incoming end.
    > -1 = ifdef sublevel in an else block.
   }
   cplusblocklevel : LongInt = 0;


procedure internalerror(i : integer);

function strpnew(const s : string) : pchar;

procedure writetree(p: presobject);

function NotInCPlusBlock : Boolean; inline;

procedure skip_until_eol;

procedure commenteof;

procedure copy_until_eol;

procedure HandleMultiLineComment;
procedure HandleSingleLineComment;
Procedure CheckLongString;
Procedure HandleContinuation;
Procedure HandleEOL;
Procedure HandleWhiteSpace;
Procedure HandleIdentifier;
Procedure HandleLongInteger;
Procedure HandleHexLongInteger;
Procedure HandleNumber;
Procedure HandleDeref;
Procedure HandleCallingConvention(aCC : Integer);
Procedure HandlePalmPilotCallingConvention;
Procedure HandleIllegalCharacter;

// Preprocessor routines...

Procedure HandlePreProcIfDef;
Procedure HandlePreProcIf;
Procedure HandlePreProcElse;
Procedure HandlePreProcElIf;
Procedure HandlePreProcEndif;
Procedure HandlePreProcUndef;
Procedure HandlePreProcInclude;
Procedure HandlePreProcLineInfo;
Procedure HandlePreProcPragma;
Procedure HandlePreProcDefine;
Procedure HandlePreProcError;
Procedure HandlePreProcStripConditional(isEnd : Boolean);
Procedure EnterCplusPlus;

const
   newline = #10;

implementation

uses
   h2poptions,converu;


procedure writeentry(p: presobject; var currentlevel: integer);
begin
                 if assigned(p^.p1) then
                    begin
                      WriteLn(' Entry p1[',ttypstr[p^.p1^.typ],']',p^.p1^.str);
                    end;
                 if assigned(p^.p2) then
                    begin
                      WriteLn(' Entry p2[',ttypstr[p^.p2^.typ],']',p^.p2^.str);
                    end;
                 if assigned(p^.p3) then
                    begin
                      WriteLn(' Entry p3[',ttypstr[p^.p3^.typ],']',p^.p3^.str);
                    end;
end;

procedure writetree(p: presobject);
var
 i : integer;
 localp: presobject;
 localp1: presobject;
 currentlevel : integer;
begin
  localp:=p;
  currentlevel:=0;
  while assigned(localp) do
     begin
      WriteLn('Entry[',ttypstr[localp^.typ],']',localp^.str);
      case localp^.typ of
      { Some arguments sharing the same type }
      t_arglist:
        begin
           localp1:=localp;
           while assigned(localp1) do
              begin
                 writeentry(localp1,currentlevel);
                 localp1:=localp1^.p1;
              end;
        end;
      end;

      localp:=localp^.next;
     end;
end;



procedure internalerror(i : integer);
  begin
     writeln('Internal error ',i,' in line ',yylineno);
     halt(1);
  end;


procedure commenteof;
  begin
     writeln('unexpected EOF inside comment at line ',yylineno);
  end;


procedure copy_until_eol;
  begin
    c:=get_char;
    while c<>newline do
     begin
       write(outfile,c);
       c:=get_char;
     end;
  end;


procedure skip_until_eol;
  begin
    c:=get_char;
    while c<>newline do
     c:=get_char;
  end;


function strpnew(const s : string) : pchar;
  var
    p : pchar;
  begin
     getmem(p,length(s)+1);
     strpcopy(p,s);
     strpnew:=p;
  end;

function NotInCPlusBlock : Boolean; inline;

begin
  NotInCPlusBlock := cplusblocklevel < 1;
end;

constructor tresobject.init_preop(const s : string;_p1 : presobject);
  begin
     typ:=t_preop;
     p:=strpnew(s);
     p1:=_p1;
     p2:=nil;
     p3:=nil;
     next:=nil;
     intname:=false;
  end;

constructor tresobject.init_bop(const s : string;_p1,_p2 : presobject);
  begin
     typ:=t_bop;
     p:=strpnew(s);
     p1:=_p1;
     p2:=_p2;
     p3:=nil;
     next:=nil;
     intname:=false;
  end;

constructor tresobject.init_id(const s : string);
  begin
     typ:=t_id;
     p:=strpnew(s);
     p1:=nil;
     p2:=nil;
     p3:=nil;
     next:=nil;
     intname:=false;
  end;

constructor tresobject.init_intid(const s : string);
  begin
     typ:=t_id;
     p:=strpnew(s);
     p1:=nil;
     p2:=nil;
     p3:=nil;
     next:=nil;
     intname:=true;
  end;

constructor tresobject.init_two(t : ttyp;_p1,_p2 : presobject);
  begin
     typ:=t;
     p1:=_p1;
     p2:=_p2;
     p3:=nil;
     p:=nil;
     next:=nil;
     intname:=false;
  end;

constructor tresobject.init_three(t : ttyp;_p1,_p2,_p3 : presobject);
  begin
     typ:=t;
     p1:=_p1;
     p2:=_p2;
     p3:=_p3;
     p:=nil;
     next:=nil;
     intname:=false;
  end;

constructor tresobject.init_one(t : ttyp;_p1 : presobject);
  begin
     typ:=t;
     p1:=_p1;
     p2:=nil;
     p3:=nil;
     next:=nil;
     p:=nil;
     intname:=false;
  end;

constructor tresobject.init_no(t : ttyp);
  begin
     typ:=t;
     p:=nil;
     p1:=nil;
     p2:=nil;
     p3:=nil;
     next:=nil;
     intname:=false;
  end;

procedure tresobject.setstr(const s : string);
  begin
     if assigned(p) then
      strdispose(p);
     p:=strpnew(s);
  end;

function tresobject.str : string;
  begin
     str:=strpas(p);
  end;

function tresobject.strlength : byte;
  begin
     if assigned(p) then
       strlength:=strlen(p)
     else
       strlength:=0;
  end;

{ can this ve considered as a constant ? }
function tresobject.is_const : boolean;
  begin
     case typ of
       t_id,t_void :
         is_const:=true;
       t_preop  :
         is_const:= ((str='-') or (str=' not ')) and p1^.is_const;
       t_bop  :
         is_const:= p2^.is_const and p1^.is_const;
     else
       is_const:=false;
     end;
  end;

function tresobject.get_copy : presobject;
  var
     newres : presobject;
  begin
     newres:=new(presobject,init_no(typ));
     newres^.intname:=intname;
     if assigned(p) then
       newres^.p:=strnew(p);
     if assigned(p1) then
       newres^.p1:=p1^.get_copy;
     if assigned(p2) then
       newres^.p2:=p2^.get_copy;
     if assigned(p3) then
       newres^.p3:=p3^.get_copy;
     if assigned(next) then
       newres^.next:=next^.get_copy;
     get_copy:=newres;
  end;

destructor tresobject.done;
  begin
     (* writeln('disposing ',byte(typ)); *)
     if assigned(p)then strdispose(p);
     if assigned(p1) then
       dispose(p1,done);
     if assigned(p2) then
       dispose(p2,done);
     if assigned(p3) then
       dispose(p3,done);
     if assigned(next) then
       dispose(next,done);
  end;
    

procedure HandleMultiLineComment;

begin
  if not NotInCPlusBlock then
    begin
    Skip_until_eol;
    exit;
    end;  
  if not stripcomment then
    write(outfile,aktspace,'{');
  repeat
    c:=get_char;
    case c of
       '*' :
         begin
           c:=get_char;
           if c='/' then
            begin
              if not stripcomment then
               write(outfile,' }');
              c:=get_char;
              if c=newline then
                writeln(outfile);
              unget_char(c);
              flush(outfile);
              exit;
            end
           else
            begin
              if not stripcomment then
               write(outfile,'*');
              unget_char(c)
            end;
          end;
        newline :
          begin
            if not stripcomment then
             begin
               writeln(outfile);
               write(outfile,aktspace);
             end;
          end;
        { Don't write this thing out, to
          avoid nested comments.
        }
      '{','}' :
          begin
          end;
        #0 :
          commenteof;
        else
          if not stripcomment then
           write(outfile,c);
    end;
  until false;
  flush(outfile);
end;

procedure HandleSingleLineComment;

begin
  if not NotInCPlusBlock then
    begin
    skip_until_eol;
    exit;
    end;

  commentstr:='';
  if (in_define) and not (stripcomment) then
  begin
     commentstr:='{';
  end
  else
  If not stripcomment then
    write(outfile,aktspace,'{');

  repeat
    c:=get_char;
    case c of
      newline :
        begin
          unget_char(c);
          if not stripcomment then
            begin
              if in_define then
                begin
                  commentstr:=commentstr+' }';
                end
              else
                begin
                  write(outfile,' }');
                  writeln(outfile);
                end;
            end;
          flush(outfile);
          exit;
        end;
      { Don't write this comment out,
        to avoid nested comment problems
      }
      '{','}' :
          begin
          end;
      #0 :
        commenteof;
      else
        if not stripcomment then
          begin
            if in_define then
             begin
               commentstr:=commentstr+c;
             end
            else
              write(outfile,c);
          end;
    end;
  until false;
  flush(outfile);
end;
  
Procedure CheckLongString;

begin
  if NotInCPlusBlock then
    begin
      if win32headers then
        return(CSTRING)
      else
        return(256);
    end
    else skip_until_eol;
end;

Procedure HandleLongInteger;

begin
  if NotInCPlusBlock then
  begin
     if yytext[1]='0' then
       begin
          delete(yytext,1,1);
          yytext:='&'+yytext;
       end;
     while yytext[length(yytext)] in ['L','U','l','u'] do
       Delete(yytext,length(yytext),1);
     return(NUMBER);
  end
   else skip_until_eol;
end;

Procedure HandleHexLongInteger;

begin
  if NotInCPlusBlock then
  begin
     (* handle pre- and postfixes *)
     if copy(yytext,1,2)='0x' then
       begin
          delete(yytext,1,2);
          yytext:='$'+yytext;
       end;
     while yytext[length(yytext)] in ['L','U','l','u'] do
       Delete(yytext,length(yytext),1);
     return(NUMBER);
  end
  else
   skip_until_eol;
end;

procedure HandleNumber;

begin
  if NotInCPlusBlock then
  begin
    return(NUMBER);
  end
  else
    skip_until_eol;
end;

Procedure HandleDeref;

begin
  if NotInCPlusBlock then
  begin
    if in_define then
      return(DEREF)
    else
      return(256);
  end
  else
    skip_until_eol;
end;
 
Procedure HandlePreProcIfDef;

begin
  if cplusblocklevel > 0 then
    Inc(cplusblocklevel)
  else
  begin
    if cplusblocklevel < 0 then
      Dec(cplusblocklevel);
    write(outfile,'{$ifdef ');
    copy_until_eol;
    writeln(outfile,'}');
    flush(outfile);
  end;
end;

Procedure HandlePreProcElse;

begin
  if cplusblocklevel < -1 then
  begin
    writeln(outfile,'{$else}');
    block_type:=bt_no;
    flush(outfile);
  end
  else
    case cplusblocklevel of
    0 :
        begin
          writeln(outfile,'{$else}');
          block_type:=bt_no;
          flush(outfile);
        end;
    1 : cplusblocklevel := -1;
    -1 : cplusblocklevel := 1;
    end;
end;

Procedure HandlePreProcEndif;

begin
   if cplusblocklevel > 0 then
   begin
     Dec(cplusblocklevel);
   end
   else
   begin
     case cplusblocklevel of
       0 : begin
             writeln(outfile,'{$endif}');
             block_type:=bt_no;
             flush(outfile);
           end;
       -1 : begin
             cplusblocklevel :=0;
            end
      else
        inc(cplusblocklevel);
      end;
   end;
end;

Procedure HandlePreProcElif;

begin
  if cplusblocklevel < -1 then
  begin
    if not stripinfo then
      write(outfile,'(*** was #elif ****)');
    write(outfile,'{$else');
    copy_until_eol;
    writeln(outfile,'}');
    block_type:=bt_no;
    flush(outfile);
  end
  else
    case cplusblocklevel of
    0 :
        begin
          if not stripinfo then
            write(outfile,'(*** was #elif ****)');
          write(outfile,'{$else');
          copy_until_eol;
          writeln(outfile,'}');
          block_type:=bt_no;
          flush(outfile);
        end;
    1 : cplusblocklevel := -1;
    -1 : cplusblocklevel := 1;
    end;
end;

Procedure HandlePreProcUndef;

begin
  write(outfile,'{$undef');
  copy_until_eol;
  writeln(outfile,'}');
  flush(outfile);
end;

Procedure HandlePreProcInclude;

begin
  if NotInCPlusBlock then
    begin
      write(outfile,'{$include');
      copy_until_eol;
      writeln(outfile,'}');
      flush(outfile);
      block_type:=bt_no;
    end
  else
   skip_until_eol;
end;

Procedure HandlePreProcIf;

begin
  if cplusblocklevel > 0 then
    Inc(cplusblocklevel)
  else
  begin
    if cplusblocklevel < 0 then
      Dec(cplusblocklevel);
    write(outfile,'{$if');
    copy_until_eol;
    writeln(outfile,'}');
    flush(outfile);
    block_type:=bt_no;
  end;
end;

Procedure HandlePreProcLineInfo;

begin
  if NotInCPlusBlock then
    (* preprocessor line info *)
    repeat
      c:=get_char;
      case c of
        newline :
          begin
            unget_char(c);
            exit;
          end;
        #0 :
          commenteof;
      end;
    until false
  else
    skip_until_eol;
end;

procedure HandlePreProcPragma;

begin
  if not stripinfo then
   begin
     write(outfile,'(** unsupported pragma');
     write(outfile,'#pragma');
     copy_until_eol;
     writeln(outfile,'*)');
     flush(outfile);
   end
  else
   skip_until_eol;
  block_type:=bt_no;
end;

Procedure HandleContinuation;

begin
   if in_define then
   begin
     cont_line:=true;
   end
   else
   begin
     writeln('Unexpected wrap of line ',yylineno);
     writeln('"',yyline,'"');
     return(256);
   end;
end;

Procedure HandleEOL;
begin
  if not in_define then
    exit;
  in_space_define:=0;
  if cont_line then
  begin
    cont_line:=false;
  end
  else
  begin
    in_define:=false;
    if NotInCPlusBlock then
      return(NEW_LINE)
    else
      skip_until_eol
  end;
end;

Procedure HandlePreProcDefine;

begin
  if NotInCPlusBlock then
   begin
     commentstr:='';
     in_define:=true;
     in_space_define:=1;
     return(DEFINE);
   end
  else
    skip_until_eol;
end;

Procedure HandlePreProcError;

begin
  write(outfile,'{$error');
  copy_until_eol;
  writeln(outfile,'}');
  flush(outfile);
end;

Procedure EnterCplusPlus;
begin
  Inc(cplusblocklevel);
end;

Procedure HandlePreProcStripConditional(isEnd : Boolean);

begin
  if not stripinfo then
    if isEnd then
      writeln(outfile,'{ C++ end of extern C conditionnal removed }')
    else
      writeln(outfile,'{ C++ extern C conditionnal removed }');
end;

Procedure HandleIdentifier;

begin
  if NotInCPlusBlock then
  begin
    if in_space_define=1 then
      in_space_define:=2;
    return(ID);
  end
  else
    skip_until_eol;
end;

Procedure HandleWhiteSpace;

begin
  if NotInCPlusBlock then
  begin
     if (arglevel=0) and (in_space_define=2) then
      begin
        in_space_define:=0;
        return(SPACE_DEFINE);
      end;
  end
  else
    skip_until_eol;
end;

Procedure HandleCallingConvention(aCC :integer);

begin
  if NotInCPlusBlock then
  begin
    if Win32headers then
      return(aCC)
    else
      return(ID);
  end
  else
  begin
    skip_until_eol;
  end;
end;

Procedure HandlePalmPilotCallingConvention;

begin
  if NotInCPlusBlock then
  begin
    if not palmpilot then
      return(ID)
    else
      return(SYS_TRAP);
  end
  else
  begin
    skip_until_eol;
  end;
end;

Procedure HandleIllegalCharacter;
begin
   writeln('Illegal character in line ',yylineno);
   writeln('"',yyline,'"');
   return(256);
end;

end.