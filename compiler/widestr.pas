{
    $Id$
    Copyright (c) 2000-2002 by Florian Klaempfl

    This unit contains basic functions for unicode support in the
    compiler, this unit is mainly necessary to bootstrap widestring
    support ...

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
unit widestr;

  interface

    uses
       charset,globtype
       ;


    type
       tcompilerwidechar = word;
       tcompilerwidecharptr = ^tcompilerwidechar;
       pcompilerwidechar = ^tcompilerwidechar;

       pcompilerwidestring = ^_tcompilerwidestring;
       _tcompilerwidestring = record
          data : pcompilerwidechar;
          maxlen,len : SizeInt;
       end;

    procedure initwidestring(var r : pcompilerwidestring);
    procedure donewidestring(var r : pcompilerwidestring);
    procedure setlengthwidestring(r : pcompilerwidestring;l : SizeInt);
    function getlengthwidestring(r : pcompilerwidestring) : SizeInt;
    procedure concatwidestringchar(r : pcompilerwidestring;c : tcompilerwidechar);
    procedure concatwidestrings(s1,s2 : pcompilerwidestring);
    function comparewidestrings(s1,s2 : pcompilerwidestring) : SizeInt;
    procedure copywidestring(s,d : pcompilerwidestring);
    function asciichar2unicode(c : char) : tcompilerwidechar;
    function unicode2asciichar(c : tcompilerwidechar) : char;
    procedure ascii2unicode(p : pchar;l : SizeInt;r : pcompilerwidestring);
    procedure unicode2ascii(r : pcompilerwidestring;p : pchar);
    function getcharwidestring(r : pcompilerwidestring;l : SizeInt) : tcompilerwidechar;
    function cpavailable(const s : string) : boolean;

  implementation

    uses
       cp8859_1,cp850,cp437,
       globals;


    procedure initwidestring(var r : pcompilerwidestring);

      begin
         new(r);
         r^.data:=nil;
         r^.len:=0;
         r^.maxlen:=0;
      end;

    procedure donewidestring(var r : pcompilerwidestring);

      begin
         if assigned(r^.data) then
           freemem(r^.data);
         dispose(r);
         r:=nil;
      end;

    function getcharwidestring(r : pcompilerwidestring;l : SizeInt) : tcompilerwidechar;

      begin
         getcharwidestring:=r^.data[l];
      end;

    function getlengthwidestring(r : pcompilerwidestring) : SizeInt;

      begin
         getlengthwidestring:=r^.len;
      end;

    procedure setlengthwidestring(r : pcompilerwidestring;l : SizeInt);

      begin
         if r^.maxlen>=l then
           exit;
         if assigned(r^.data) then
           reallocmem(r^.data,sizeof(tcompilerwidechar)*l)
         else
           getmem(r^.data,sizeof(tcompilerwidechar)*l);
      end;

    procedure concatwidestringchar(r : pcompilerwidestring;c : tcompilerwidechar);

      begin
         if r^.len>=r^.maxlen then
           setlengthwidestring(r,r^.len+16);
         r^.data[r^.len]:=c;
         inc(r^.len);
      end;

    procedure concatwidestrings(s1,s2 : pcompilerwidestring);
      begin
         setlengthwidestring(s1,s1^.len+s2^.len);
         inc(s1^.len,s2^.len);
         move(s2^.data^,s1^.data[s1^.len],s2^.len*sizeof(tcompilerwidechar));
      end;

    procedure copywidestring(s,d : pcompilerwidestring);

      begin
         setlengthwidestring(d,s^.len);
         d^.len:=s^.len;
         move(s^.data^,d^.data^,s^.len*sizeof(tcompilerwidechar));
      end;

    function comparewidestrings(s1,s2 : pcompilerwidestring) : SizeInt;
      var
         maxi,temp : SizeInt;
      begin
         if pointer(s1)=pointer(s2) then
           begin
              comparewidestrings:=0;
              exit;
           end;
         maxi:=s1^.len;
         temp:=s2^.len;
         if maxi>temp then
           maxi:=Temp;
         temp:=compareword(s1^.data^,s2^.data^,maxi);
         if temp=0 then
           temp:=s1^.len-s2^.len;
         comparewidestrings:=temp;
      end;

    function asciichar2unicode(c : char) : tcompilerwidechar;
      var
         m : punicodemap;
      begin
         m:=getmap(aktsourcecodepage);
         asciichar2unicode:=getunicode(c,m);
      end;

    function unicode2asciichar(c : tcompilerwidechar) : char;

      begin
        {$ifdef fpc}{$warning todo}{$endif}
        unicode2asciichar:=#0;
      end;

    procedure ascii2unicode(p : pchar;l : SizeInt;r : pcompilerwidestring);
      var
         source : pchar;
         dest   : tcompilerwidecharptr;
         i      : SizeInt;
         m      : punicodemap;
      begin
         m:=getmap(aktsourcecodepage);
         setlengthwidestring(r,l);
         source:=p;
         r^.len:=l;
         dest:=tcompilerwidecharptr(r^.data);
         for i:=1 to l do
           begin
              dest^:=getunicode(source^,m);
              inc(dest);
              inc(source);
           end;
      end;

    procedure unicode2ascii(r : pcompilerwidestring;p:pchar);
(*
      var
         m : punicodemap;
         i : longint;

      begin
         m:=getmap(aktsourcecodepage);
         { should be a very good estimation :) }
         setlengthwidestring(r,length(s));
         // !!!! MBCS
         for i:=1 to length(s) do
           begin
           end;
      end;
*)
      var
        source : tcompilerwidecharptr;
        dest   : pchar;
        i      : longint;
      begin
        source:=tcompilerwidecharptr(r^.data);
        dest:=p;
        for i:=1 to r^.len do
         begin
           if word(source^)<128 then
            dest^:=char(word(source^))
           else
            dest^:=' ';
           inc(dest);
           inc(source);
         end;
      end;


    function cpavailable(const s : string) : boolean;
      begin
          cpavailable:=mappingavailable(s);
      end;

end.
{
  $Log$
  Revision 1.16  2004-10-15 09:14:17  mazen
  - remove $IFDEF DELPHI and related code
  - remove $IFDEF FPCPROCVAR and related code

  Revision 1.15  2004/06/20 08:55:30  florian
    * logs truncated

  Revision 1.14  2004/06/16 20:07:10  florian
    * dwarf branch merged

  Revision 1.13  2004/05/02 11:48:46  peter
    * strlenint is replaced with sizeint

  Revision 1.12.2.2  2004/05/02 00:45:51  peter
    * define sizeint for 1.0.x

  Revision 1.12.2.1  2004/05/02 00:31:33  peter
    * fixedi i386 compile

}
