{
    This file is part of the Free Pascal run time library.

    A file in Amiga system run time library.
    Copyright (c) 2002 by Nils Sjoholm
    member of the Amiga RTL development team.

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}

 {
        History:

        Made this unit to help porting from HS Pascal
        to fpc. Feel free to add more stuff.
        09 Nov 2002.

        Added the define use_amiga_smartlink.
        13 Jan 2003.
        nils.sjoholm@mailbox.swipnet.se Nils Sjoholm
}

{$IFNDEF FPC_DOTTEDUNITS}
unit hisoft;
{$ENDIF FPC_DOTTEDUNITS}

interface

{$IFDEF FPC_DOTTEDUNITS}
uses Amiga.Core.Exec, Amiga.Core.Gadtools,Amiga.Utils.Pastoc,Amiga.Core.Amigados,Amiga.Core.Intuition;
{$ELSE FPC_DOTTEDUNITS}
uses exec, gadtools,pastoc,amigados,intuition;
{$ENDIF FPC_DOTTEDUNITS}

type
    ppbyte = pointer;

const
    NULL = 0;
    TRUE_ = 1;
    FALSE_ = 0;

procedure MakeMenu(var mnm: tNewMenu;
        nmType: byte;
        nmLabel: ShortString;
        nmCommKey: ShortString;
        nmFlags: word;
        nmMutualExclude: longint;
        nmUserData: longint);

function ptrtopas(s : PAnsiChar): ShortString;
function FExpandLock( l : BPTR): ShortString;
Function CSCPAR(rk : pRemember; s : ShortString) : STRPTR;

implementation


(*
 * A little routine to fill in the members of a NewMenu struct
 *
 *)
procedure MakeMenu(var mnm: tNewMenu;
        nmType: byte;
        nmLabel: ShortString;
        nmCommKey: ShortString;
        nmFlags: word;
        nmMutualExclude: longint;
        nmUserData: longint);
begin
        mnm.nm_Type := nmType;
        if nmLabel <> '' then
           mnm.nm_Label := pas2c(nmLabel)
        else mnm.nm_Label := nil;
        if nmCommKey <> '' then
           mnm.nm_CommKey := pas2c(nmCommKey)
        else mnm.nm_CommKey := nil;
        mnm.nm_Flags := nmFlags;
        mnm.nm_MutualExclude := nmMutualExclude;
        mnm.nm_UserData := pointer(nmUserData);
end;

function ptrtopas(s : PAnsiChar): ShortString;
begin
   ptrtopas := strpas(s);
end;

function FExpandLock( l : BPTR): ShortString;
var
   buffer : array[0..255] of AnsiChar;
begin
  {$if not defined(AMIGA_V1_2_ONLY)}
   if l <> 0 then begin
      if NameFromLock(l,buffer,255) then FExpandLock := strpas(buffer)
      else FExpandLock := '';
   end else
   {$endif}
     FExpandLock := '';
end;

Function CSCPAR(rk : pRemember; s : ShortString) : STRPTR;
VAR
        p : STRPTR;

begin
  s := s + #0;
  p := AllocRemember(rk, length(s), MEMF_CLEAR);
  if p <> nil then
        move(s[1], p^, length(s));
  CSCPAR := p;
end;

end.
