{
    $Id$
    Copyright (c) 1998-2002 by Florian Klaempfl, Pierre Muller

    interprets the commandline options which are arm specific

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
unit cpuswtch;

{$i fpcdefs.inc}

interface

uses
  options;

type
  toptionarm=class(toption)
    procedure interpret_proc_specific_options(const opt:string);override;
  end;

implementation

uses
  cutils,globtype,systems,globals;

procedure toptionarm.interpret_proc_specific_options(const opt:string);
var
  more: string;
  j: longint;
begin
  More:=Upper(copy(opt,3,length(opt)-2));
  case opt[2] of
   'O' : Begin
           j := 3;
           While (j <= Length(Opt)) Do
             Begin
               case opt[j] of
                 '-' :
                   begin
                     initglobalswitches:=initglobalswitches-[cs_optimize,cs_fastoptimize,cs_slowoptimize,cs_littlesize,
                       cs_regvars,cs_uncertainopts];
                     FillChar(ParaAlignment,sizeof(ParaAlignment),0);
                   end;
                 'a' :
                   begin
                     UpdateAlignmentStr(Copy(Opt,j+1,255),ParaAlignment);
                     j:=length(Opt);
                   end;
                 'g' : initglobalswitches:=initglobalswitches+[cs_littlesize];
                 'G' : initglobalswitches:=initglobalswitches-[cs_littlesize];
                 'r' :
                   begin
                     initglobalswitches:=initglobalswitches+[cs_regvars];
                     Simplify_ppu:=false;
                   end;
                 'u' : initglobalswitches:=initglobalswitches+[cs_uncertainopts];
                 '1' : initglobalswitches:=initglobalswitches-[cs_fastoptimize,cs_slowoptimize]+[cs_optimize];
                 '2' : initglobalswitches:=initglobalswitches-[cs_slowoptimize]+[cs_optimize,cs_fastoptimize];
                 '3' : initglobalswitches:=initglobalswitches+[cs_optimize,cs_fastoptimize,cs_slowoptimize];
{$ifdef dummy}
                 'p' :
                   Begin
                     If j < Length(Opt) Then
                       Begin
                         Case opt[j+1] Of
                           '1': initoptprocessor := Class386;
                           '2': initoptprocessor := ClassP5;
                           '3': initoptprocessor := ClassP6
                           Else IllegalPara(Opt)
                         End;
                         Inc(j);
                       End
                     Else IllegalPara(opt)
                   End;
{$endif dummy}
                 else IllegalPara(opt);
               End;
               Inc(j)
             end;
         end;
{$ifdef dummy}
   'R' : begin
           if More='GAS' then
            initasmmode:=asmmode_ppc_gas
           else
            if More='MOTOROLA' then
             initasmmode:=asmmode_ppc_motorola
           else
            if More='DIRECT' then
             initasmmode:=asmmode_direct
           else
            IllegalPara(opt);
         end;
{$endif dummy}
  else
   IllegalPara(opt);
  end;
end;


initialization
  coption:=toptionarm;
end.
{
  $Log$
  Revision 1.1  2003-08-20 15:50:13  florian
    * more arm stuff
}
