{
    This file is part of the Free Pascal run time library.
    Copyright (c) 1999-2000 by Florian Klaempfl
    member of the Free Pascal development team

    Keyboard unit for MS-DOS

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}
{$IFNDEF FPC_DOTTEDUNITS}
unit Keyboard;
{$ENDIF FPC_DOTTEDUNITS}
interface

{$i keybrdh.inc}

implementation

{$IFDEF FPC_DOTTEDUNITS}
uses
  TP.DOS;
{$ELSE FPC_DOTTEDUNITS}
uses
  dos;
{$ENDIF FPC_DOTTEDUNITS}


{$i keyboard.inc}

var
  keyboard_type: byte;  { 0=83/84-key keyboard, $10=101/102+ keyboard }


procedure SysInitKeyboard;
var
  regs: registers;
begin
  keyboard_type:=0;
  if (Mem[$40:$96] and $10)<>0 then
    begin
      regs.ax:=$1200;
      intr($16,regs);
      if regs.ax<>$1200 then
        keyboard_type:=$10;
    end;
  regs.ax:=$6601;
  msdos(regs);
  if (regs.flags and fCarry) = 0 then
     CurrentLegacy2EnhancedKeyEventTranslationCodePage:=regs.bx;
end;


function SysGetShiftState: Byte;
begin
  SysGetShiftState:=(mem[$40:$17] and %1100) or
                   ((mem[$40:$17] and %0010) shr 1) or
                   ((mem[$40:$17] and %0001) shl 1);
end;


function SysGetKeyEvent: TKeyEvent;

var
  regs : registers;
begin
  regs.ah:=keyboard_type;
  intr($16,regs);
  if (regs.al=$e0) and (regs.ah<>0) then
   regs.al:=0;
  SysGetKeyEvent:=(kbPhys shl 24) or regs.ax or (longint(SysGetShiftState) shl 16);
end;


function SysPollKeyEvent: TKeyEvent;
var
  regs : registers;
begin
  regs.ah:=keyboard_type+1;
  intr($16,regs);
  if (regs.flags and fzero)<>0 then
   exit(0);
  if (regs.al=$e0) and (regs.ah<>0) then
   regs.al:=0;
  SysPollKeyEvent:=(kbPhys shl 24) or regs.ax or (longint(SysGetShiftState) shl 16);
end;


Const
  SysKeyboardDriver : TKeyboardDriver = (
    InitDriver : @SysInitKeyboard;
    DoneDriver : Nil;
    GetKeyevent : @SysGetKeyEvent;
    PollKeyEvent : @SysPollKeyEvent;
    GetShiftState : @SysGetShiftState;
    TranslateKeyEvent : Nil;
    TranslateKeyEventUnicode : Nil;
    GetEnhancedKeyEvent : Nil;
    PollEnhancedKeyEvent : Nil;
  );

begin
  SetKeyBoardDriver(SysKeyBoardDriver);
end.
