{
    $Id$
    This file is part of the Free Pascal Integrated Development Environment
    Copyright (c) 1998 by Berczi Gabor

    Main program of the IDE

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}
program FP;

{$I globdir.inc}

uses
{$ifdef IDEHeapTrc}
  HeapTrc,
{$endif IDEHeapTrc}
  Dos,Objects,
  BrowCol,
  Views,App,Dialogs,ColorSel,Menus,StdDlg,Validate,
  {$ifdef EDITORS}Editors{$else}WEditor{$endif},
  ASCIITab,Calc,
  WViews,
  FPIDE,FPCalc,FPCompile,
  FPIni,FPViews,FPConst,FPVars,FPUtils,FPHelp,FPSwitch,FPUsrScr,
  FPTools,{$ifndef NODEBUG}FPDebug,{$endif}FPTemplt,FPCatch,FPRedir,FPDesk
{$ifdef FPC}
  ,dpmiexcp
{$endif FPC}
  ;


procedure ProcessParams(BeforeINI: boolean);

  function IsSwitch(const Param: string): boolean;
  begin
    IsSwitch:=(Param<>'') and (Param[1]<>DirSep) { <- allow UNIX root-relative paths            }
          and (Param[1] in ['-','/']);           { <- but still accept dos switch char, eg. '/' }
  end;

var I: Sw_integer;
    Param: string;
begin
  for I:=1 to ParamCount do
  begin
    Param:=ParamStr(I);
    if IsSwitch(Param) then
      begin
        Param:=copy(Param,2,255);
        if Param<>'' then
        case Upcase(Param[1]) of
          'C' : { custom config file (BP compatiblity) }
           if BeforeINI then
            INIPath:=copy(Param,2,255);
          'R' : { enter the directory last exited from (BP comp.) }
            begin
              Param:=copy(Param,2,255);
              if (Param='') or (Param='+') then
                StartupOptions:=StartupOptions or soReturnToLastDir
              else
              if (Param='-') then
                StartupOptions:=StartupOptions and (not soReturnToLastDir);
            end;
        end;
      end
    else
      if not BeforeINI then
        TryToOpenFile(nil,Param,0,0,false);
  end;
end;

Procedure MyStreamError(Var S: TStream); {$ifndef FPC}far;{$endif}
var ErrS: string;
begin
  {$ifdef GABOR}{$ifdef TP}asm int 3;end;{$endif}{$endif}
  case S.Status of
    stGetError : ErrS:='Get of unregistered object type';
    stPutError : ErrS:='Put of unregistered object type';
  else ErrS:='';
  end;
  if Assigned(Application) then
    ErrorBox('Stream error: '+#13+ErrS,nil)
  else
    writeln('Error: ',ErrS);
end;

procedure RegisterIDEObjects;
begin
  RegisterApp;
  RegisterAsciiTab;
  RegisterCalc;
  RegisterColorSel;
  RegisterDialogs;
{$ifdef EDITORS}
  RegisterEditors;
{$else}
  RegisterCodeEditors;
{$endif}
  RegisterFPCalc;
  RegisterFPCompile;
  RegisterFPTools;
  RegisterFPViews;
  RegisterMenus;
  RegisterStdDlg;
  RegisterObjects;
  RegisterValidate;
  RegisterViews;
end;

var CanExit : boolean;

BEGIN
  {$ifdef DEV}HeapLimit:=4096;{$endif}
  writeln('� Free Pascal IDE  Version '+VersionStr);
  StartupDir:=CompleteDir(FExpand('.'));
  IDEDir:=CompleteDir(DirOf(Paramstr(0)));

  RegisterIDEObjects;
  StreamError:=@MyStreamError;

  ProcessParams(true);

{$ifdef VESA}
  InitVESAScreenModes;
{$endif}
  InitRedir;
{$ifndef NODEBUG}
  InitBreakpoints;
{$endif}
  InitReservedWords;
  InitHelpFiles;
  InitSwitches;
  InitINIFile;
  InitUserScreen;
  InitTools;
  InitTemplates;

  ReadSwitches(SwitchesPath);
  MyApp.Init;

  { load all options after init because of open files }
  ReadINIFile;
  InitDesktopFile;
  LoadDesktop;

  { Update IDE }
  MyApp.Update;
  MyApp.UpdateTarget;

  ProcessParams(false);

  repeat
  MyApp.Run;
    if (AutoSaveOptions and asEditorFiles)=0 then CanExit:=true else
      CanExit:=MyApp.SaveAll;
  until CanExit;

  { must be written before done for open files }
  if (AutoSaveOptions and asEnvironment)<>0 then
    if WriteINIFile=false then
      ErrorBox('Error saving configuration.',nil);
  if (AutoSaveOptions and asDesktop)<>0 then
    if SaveDesktop=false then
      ErrorBox('Error saving desktop.',nil);

  DoneDesktopFile;

  MyApp.Done;

  WriteSwitches(SwitchesPath);

  DoneTemplates;
  DoneTools;
  DoneUserScreen;
  DoneSwitches;
  DoneHelpFiles;
  DoneReservedWords;
  ClearToolMessages;
  DoneBrowserCol;
{$ifndef NODEBUG}
  DoneDebugger;
  DoneBreakpoints;
{$endif}

  StreamError:=nil;
END.
{
  $Log$
  Revision 1.24  1999-06-28 12:40:56  pierre
   + clear tool messages at exit

  Revision 1.23  1999/06/25 00:48:05  pierre
   + adds current target in menu at startup

  Revision 1.22  1999/05/22 13:44:28  peter
    * fixed couple of bugs

  Revision 1.21  1999/04/07 21:55:40  peter
    + object support for browser
    * html help fixes
    * more desktop saving things
    * NODEBUG directive to exclude debugger

  Revision 1.20  1999/03/23 16:16:36  peter
    * linux fixes

  Revision 1.19  1999/03/23 15:11:26  peter
    * desktop saving things
    * vesa mode
    * preferences dialog

  Revision 1.18  1999/03/21 22:51:35  florian
    + functional screen mode switching added

  Revision 1.17  1999/03/16 12:38:06  peter
    * tools macro fixes
    + tph writer
    + first things for resource files

  Revision 1.16  1999/03/12 01:13:01  peter
    * use TryToOpen() with parameter files to overcome double opened files
      at startup

  Revision 1.15  1999/03/08 14:58:08  peter
    + prompt with dialogs for tools

  Revision 1.14  1999/03/05 17:53:00  pierre
   + saving and opening of open files on exit

  Revision 1.13  1999/03/01 15:41:48  peter
    + Added dummy entries for functions not yet implemented
    * MenuBar didn't update itself automatically on command-set changes
    * Fixed Debugging/Profiling options dialog
    * TCodeEditor converts spaces to tabs at save only if efUseTabChars is
 set
    * efBackSpaceUnindents works correctly
    + 'Messages' window implemented
    + Added '$CAP MSG()' and '$CAP EDIT' to available tool-macros
    + Added TP message-filter support (for ex. you can call GREP thru
      GREP2MSG and view the result in the messages window - just like in TP)
    * A 'var' was missing from the param-list of THelpFacility.TopicSearch,
      so topic search didn't work...
    * In FPHELP.PAS there were still context-variables defined as word instead
      of THelpCtx
    * StdStatusKeys() was missing from the statusdef for help windows
    + Topic-title for index-table can be specified when adding a HTML-files

  Revision 1.12  1999/02/20 15:18:25  peter
    + ctrl-c capture with confirm dialog
    + ascii table in the tools menu
    + heapviewer
    * empty file fixed
    * fixed callback routines in fpdebug to have far for tp7

  Revision 1.11  1999/02/18 13:44:30  peter
    * search fixed
    + backward search
    * help fixes
    * browser updates

  Revision 1.10  1999/02/15 09:07:10  pierre
   * HEAPTRC conditionnal renamed IDEHEAPTRC

  Revision 1.9  1999/02/10 09:55:43  pierre
     + Memory tracing if compiled with -dHEAPTRC
     * Many memory leaks removed

  Revision 1.8  1999/02/08 09:30:59  florian
    + some split heap stuff, in $ifdef TEMPHEAP

  Revision 1.7  1999/02/05 13:51:38  peter
    * unit name of FPSwitches -> FPSwitch which is easier to use
    * some fixes for tp7 compiling

  Revision 1.6  1999/01/21 11:54:10  peter
    + tools menu
    + speedsearch in symbolbrowser
    * working run command

  Revision 1.5  1999/01/12 14:29:31  peter
    + Implemented still missing 'switch' entries in Options menu
    + Pressing Ctrl-B sets ASCII mode in editor, after which keypresses (even
      ones with ASCII < 32 ; entered with Alt+<###>) are interpreted always as
      ASCII chars and inserted directly in the text.
    + Added symbol browser
    * splitted fp.pas to fpide.pas

}
