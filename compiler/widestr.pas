{
    $Id$
    Copyright (c) 2000 by Florian Klaempfl

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

{    uses
       charset;
}

    type
       tcompilerwidechar = word;
{$ifdef delphi}
       { delphi doesn't allow pointer accessing as array }
       tcompilerwidechararray = array[0..0] of tcompilerwidechar;
       pcompilerwidechar = ^tcompilerwidechararray;
{$else}
       pcompilerwidechar = ^tcompilerwidechar;
{$endif}

       pcompilerwidestring = ^tcompilerwidestring;
       tcompilerwidestring = record
          data : pcompilerwidechar;
          maxlen,len : longint;
       end;

    procedure initwidestring(var r : tcompilerwidestring);
    procedure donewidestring(var r : tcompilerwidestring);
    procedure setlengthwidestring(var r : tcompilerwidestring;l : longint);
    function getlengthwidestring(const r : tcompilerwidestring) : longint;
    procedure concatwidestringchar(var r : tcompilerwidestring;c : tcompilerwidechar);
    procedure concatwidestrings(const s1,s2 : tcompilerwidestring;
      var r : tcompilerwidestring);
    function comparewidestrings(const s1,s2 : tcompilerwidestring) : shortint;
    procedure copywidestring(const s : tcompilerwidestring;var d : tcompilerwidestring);
    function asciichar2unicode(c : char) : tcompilerwidechar;
    function unicode2asciichar(c : tcompilerwidechar) : char;
    procedure ascii2unicode(const s : string;var r : tcompilerwidestring);
    function getcharwidestring(const r : tcompilerwidestring;l : longint) : tcompilerwidechar;
    function cpavailable(const s : string) : boolean;

  implementation

{    uses
       i8869_1,cp850,cp437; }

    uses
       globals;

    procedure initwidestring(var r : tcompilerwidestring);

      begin
         r.data:=nil;
         r.len:=0;
         r.maxlen:=0;
      end;

    procedure donewidestring(var r : tcompilerwidestring);

      begin
         if assigned(r.data) then
           freemem(r.data);
         r.data:=nil;
         r.maxlen:=0;
         r.len:=0;
      end;

    function getcharwidestring(const r : tcompilerwidestring;l : longint) : tcompilerwidechar;

      begin
         getcharwidestring:=r.data[l];
      end;

    function getlengthwidestring(const r : tcompilerwidestring) : longint;

      begin
         getlengthwidestring:=r.len;
      end;

    procedure setlengthwidestring(var r : tcompilerwidestring;l : longint);

      begin
         if r.maxlen>=l then
           exit;
         if assigned(r.data) then
           reallocmem(r.data,sizeof(tcompilerwidechar)*l)
         else
           getmem(r.data,sizeof(tcompilerwidechar)*l);
      end;

    procedure concatwidestringchar(var r : tcompilerwidestring;c : tcompilerwidechar);

      begin
         if r.len>=r.maxlen then
           setlengthwidestring(r,r.len+16);
         r.data[r.len]:=c;
         inc(r.len);
      end;

    procedure concatwidestrings(const s1,s2 : tcompilerwidestring;
      var r : tcompilerwidestring);

      begin
         setlengthwidestring(r,s1.len+s2.len);
         r.len:=s1.len+s2.len;
         move(s1.data^,r.data^,s1.len*2);
         move(s2.data^,r.data[s1.len],s2.len*2);
      end;

    function comparewidestringwidestring(const s1,s2 : tcompilerwidestring) : longint;

      begin
        {$ifdef fpc}{$warning todo}{$endif}
        comparewidestringwidestring:=0;
      end;

    procedure copywidestring(const s : tcompilerwidestring;var d : tcompilerwidestring);

      begin
         setlengthwidestring(d,s.len);
         d.len:=s.len;
         move(s.data^,d.data^,s.len);
      end;

    function comparewidestrings(const s1,s2 : tcompilerwidestring) : shortint;

      begin
         {!!!!!! FIXME }
         comparewidestrings:=0;
      end;

    function asciichar2unicode(c : char) : tcompilerwidechar;
{!!!!!!!!
      var
         m : punicodemap;

      begin
         m:=getmap(aktsourcecodepage);
         asciichar2unicode:=getunicode(c,m);
      end;
}
      begin
        {$ifdef fpc}{$warning todo}{$endif}
        asciichar2unicode:=0;
      end;

    function unicode2asciichar(c : tcompilerwidechar) : char;

      begin
      end;

    procedure ascii2unicode(const s : string;var r : tcompilerwidestring);
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
      begin
      end;

    function cpavailable(const s : string) : boolean;
{!!!!!!
      begin
          cpavailable:=mappingavailable(s);
      end;
}

      begin
        cpavailable:=false;
      end;

end.
{
  $Log$
  Revision 1.5  2001-05-27 14:30:55  florian
    + some widestring stuff added

  Revision 1.4  2001/05/08 21:06:33  florian
    * some more support for widechars commited especially
      regarding type casting and constants

  Revision 1.3  2001/04/13 01:22:17  peter
    * symtable change to classes
    * range check generation and errors fixed, make cycle DEBUG=1 works
    * memory leaks fixed

  Revision 1.2  2001/04/02 21:20:35  peter
    * resulttype rewrite

  Revision 1.1  2000/11/29 00:30:43  florian
    * unused units removed from uses clause
    * some changes for widestrings

}
