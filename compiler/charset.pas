{
    $Id$
    This file is part of the Free Pascal run time library.
    Copyright (c) 2000 by Florian Klaempfl
    member of the Free Pascal development team.

    This unit implements several classes for charset conversions

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************
}
unit charset;

{$i fpcdefs.inc}

  interface

    type
       tunicodechar = word;
       tunicodestring = ^tunicodechar;

       tcsconvert = class
         // !!!!!!1constructor create;
       end;

       tunicodecharmappingflag = (umf_noinfo,umf_leadbyte,umf_undefined,
         umf_unused);

       punicodecharmapping = ^tunicodecharmapping;
       tunicodecharmapping = record
          unicode : tunicodechar;
          flag : tunicodecharmappingflag;
          reserved : byte;
       end;

       punicodemap = ^tunicodemap;
       tunicodemap = record
          cpname : string[20];
          map : punicodecharmapping;
          lastchar : longint;
          next : punicodemap;
          internalmap : boolean;
       end;

       tcp2unicode = class(tcsconvert)
       end;

    function loadunicodemapping(const cpname,f : string) : punicodemap;
    procedure registermapping(p : punicodemap);
    function getmap(const s : string) : punicodemap;
    function mappingavailable(const s : string) : boolean;
    function getunicode(c : char;p : punicodemap) : tunicodechar;
    function getascii(c : tunicodechar;p : punicodemap) : string;

  implementation

    var
       mappings : punicodemap;

    function loadunicodemapping(const cpname,f : string) : punicodemap;

      var
         data : punicodecharmapping;
         datasize : longint;
         t : text;
         s,hs : string;
         scanpos,charpos,unicodevalue : longint;
         code : integer;
         flag : tunicodecharmappingflag;
         p : punicodemap;
         lastchar : longint;

      begin
         lastchar:=-1;
         loadunicodemapping:=nil;
         datasize:=256;
         getmem(data,sizeof(tunicodecharmapping)*datasize);
         assign(t,f);
         {$I-}
         reset(t);
         {$I+}
         if ioresult<>0 then
           begin
              freemem(data,sizeof(tunicodecharmapping)*datasize);
              exit;
           end;
         while not(eof(t)) do
           begin
              readln(t,s);
              if (s[1]='0') and (s[2]='x') then
                begin
                   flag:=umf_unused;
                   scanpos:=3;
                   hs:='$';
                   while s[scanpos] in ['0'..'9','A'..'F','a'..'f'] do
                     begin
                        hs:=hs+s[scanpos];
                        inc(scanpos);
                     end;
                   val(hs,charpos,code);
                   if code<>0 then
                     begin
                        freemem(data,sizeof(tunicodecharmapping)*datasize);
                        close(t);
                        exit;
                     end;
                   while not(s[scanpos] in ['0','#']) do
                     inc(scanpos);
                   if s[scanpos]='#' then
                     begin
                        { special char }
                        unicodevalue:=$ffff;
                        hs:=copy(s,scanpos,length(s)-scanpos+1);
                        if hs='#DBCS LEAD BYTE' then
                          flag:=umf_leadbyte;
                     end
                   else
                     begin
                        { C hex prefix }
                        inc(scanpos,2);
                        hs:='$';
                        while s[scanpos] in ['0'..'9','A'..'F','a'..'f'] do
                          begin
                             hs:=hs+s[scanpos];
                             inc(scanpos);
                          end;
                        val(hs,unicodevalue,code);
                        if code<>0 then
                          begin
                             freemem(data,sizeof(tunicodecharmapping)*datasize);
                             close(t);
                             exit;
                          end;
                        if charpos>datasize then
                          begin
                             { allocate 1024 bytes more because         }
                             { if we need more than 256 entries it's    }
                             { probably a mbcs with a lot of            }
                             { entries                                  }
                             datasize:=charpos+1024;
                             reallocmem(data,sizeof(tunicodecharmapping)*datasize);
                          end;
                        flag:=umf_noinfo;
                     end;
{$ifdef delphi}
                   data^.flag:=flag;
                   data^.unicode:=unicodevalue;
{$else}
                   data[charpos].flag:=flag;
                   data[charpos].unicode:=unicodevalue;
{$endif delphi}
                   if charpos>lastchar then
                     lastchar:=charpos;
                end;
           end;
         close(t);
         new(p);
         p^.lastchar:=lastchar;
         p^.cpname:=cpname;
         p^.internalmap:=false;
         p^.next:=nil;
         p^.map:=data;
         loadunicodemapping:=p;
      end;

    procedure registermapping(p : punicodemap);

      begin
         p^.next:=mappings;
         mappings:=p;
      end;

    function getmap(const s : string) : punicodemap;

      var
         hp : punicodemap;

      const
         mapcache : string = '';
         mapcachep : punicodemap = nil;

      begin
         if (mapcache=s) and (mapcachep^.cpname=s) then
           begin
              getmap:=mapcachep;
              exit;
           end;
         hp:=mappings;
         while assigned(hp) do
           begin
              if hp^.cpname=s then
                begin
                   getmap:=hp;
                   mapcache:=s;
                   mapcachep:=hp;
                   exit;
                end;
              hp:=hp^.next;
           end;
         getmap:=nil;
      end;

    function mappingavailable(const s : string) : boolean;

      begin
         mappingavailable:=getmap(s)<>nil;
      end;

    function getunicode(c : char;p : punicodemap) : tunicodechar;

      begin
         if ord(c)<=p^.lastchar then
{$ifdef Delphi}
           getunicode:=p^.map.unicode
{$else}
           getunicode:=p^.map[ord(c)].unicode
{$endif}
         else
           getunicode:=0;
      end;

    function getascii(c : tunicodechar;p : punicodemap) : string;

      var
         i : longint;

      begin
         { at least map to space }
         getascii:=#32;
         for i:=0 to p^.lastchar do
{$ifdef Delphi}
           if p^.map.unicode=c then
{$else}
           if p^.map[i].unicode=c then
{$endif}
             begin
                if i<256 then
                  getascii:=chr(i)
                else
                  getascii:=chr(i div 256)+chr(i mod 256);
                exit;
             end;
      end;

  var
     hp : punicodemap;

initialization
  mappings:=nil;
finalization
  while assigned(mappings) do
    begin
       hp:=mappings^.next;
       if not(mappings^.internalmap) then
         begin
            freemem(mappings^.map);
            dispose(mappings);
         end;
       mappings:=hp;
    end;
end.
{
  $Log$
  Revision 1.4  2003-04-22 14:33:38  peter
    * removed some notes/hints

  Revision 1.3  2002/10/05 12:43:24  carl
    * fixes for Delphi 6 compilation
     (warning : Some features do not work under Delphi)

  Revision 1.2  2002/09/07 15:25:02  peter
    * old logs removed and tabs fixed

  Revision 1.1  2002/07/20 17:11:48  florian
    + source code page support

}
