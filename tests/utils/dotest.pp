{
  $Id$
    This file is part of the Free Pascal test suite.
    Copyright (c) 1999-2002 by the Free Pascal development team.

    This program makes the compilation and
    execution of individual test sources.

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}
{$H+}
program dotest;
uses
  dos,
  teststr,
  testu,
  redir;

type
  tcompinfo = (compver,comptarget,compcpu);

const
{$ifdef UNIX}
  ExeExt='';
{$else UNIX}
  ExeExt='exe';
{$endif UNIX}

var
  Config : TConfig;
  CompilerBin : string;
  CompilerCPU : string;
  CompilerTarget : string;
  CompilerVersion : string;
  PPFile : string;
  PPFileInfo : string;
  TestName : string;

const
  LongLogfile : string[32] = 'longlog';
  FailLogfile : string[32] = 'faillist';
  DoGraph : boolean = false;
  DoInteractive : boolean = false;
  DoExecute : boolean = false;
  DoKnown : boolean = false;
  DoAll : boolean = false;
  DoUsual : boolean = true;
  ExtraCompilerOpts : string = '';
  DelExecutable : boolean = false;
  RemoteAddr : string = '';
  RemotePath : string = '';

Function FileExists (Const F : String) : Boolean;
{
  Returns True if the file exists, False if not.
}
Var
  info : searchrec;
begin
  FindFirst (F,anyfile,Info);
  FileExists:=DosError=0;
  FindClose (Info);
end;


function ToStr(l:longint):string;
var
  s : string;
begin
  Str(l,s);
  ToStr:=s;
end;


function ToStrZero(l:longint;nbzero : byte):string;
var
  s : string;
begin
  Str(l,s);
  while length(s)<nbzero do
    s:='0'+s;
  ToStrZero:=s;
end;


function trimspace(const s:string):string;
var
  i,j : longint;
begin
  i:=length(s);
  while (i>0) and (s[i] in [#9,' ']) do
   dec(i);
  j:=1;
  while (j<i) and (s[j] in [#9,' ']) do
   inc(j);
  trimspace:=Copy(s,j,i-j+1);
end;


function IsInList(const entry,list:string):boolean;
var
  i,istart : longint;
begin
  IsInList:=false;
  i:=0;
  while (i<length(list)) do
   begin
     { Find list item }
     istart:=i+1;
     while (i<length(list)) and
           (list[i+1]<>',') do
      inc(i);
     if Upcase(entry)=Upcase(TrimSpace(Copy(list,istart,i-istart+1))) then
      begin
        IsInList:=true;
        exit;
      end;
     { skip , }
     inc(i);
   end;
end;


procedure SetPPFileInfo;
Var
  info : searchrec;
  dt : DateTime;
begin
  FindFirst (PPFile,anyfile,Info);
  If DosError=0 then
    begin
      UnpackTime(info.time,dt);
      PPFileInfo:=PPFile+' '+ToStr(dt.year)+'/'+ToStrZero(dt.month,2)+'/'+
        ToStrZero(dt.day,2)+' '+ToStrZero(dt.Hour,2)+':'+ToStrZero(dt.min,2)+':'+ToStrZero(dt.sec,2);
    end
  else
    PPFileInfo:=PPfile;
  FindClose (Info);
end;


function SplitPath(const s:string):string;
var
  i : longint;
begin
  i:=Length(s);
  while (i>0) and not(s[i] in ['/','\']) do
   dec(i);
  SplitPath:=Copy(s,1,i);
end;


function ForceExtension(Const HStr,ext:String):String;
{
  Return a filename which certainly has the extension ext
}
var
  j : longint;
begin
  j:=length(Hstr);
  while (j>0) and (Hstr[j]<>'.') do
   dec(j);
  if j=0 then
   j:=255;
  if Ext<>'' then
   ForceExtension:=Copy(Hstr,1,j-1)+'.'+Ext
  else
   ForceExtension:=Copy(Hstr,1,j-1);
end;


procedure Copyfile(const fn1,fn2:string;append:boolean);
const
  bufsize = 16384;
var
  f,g : file;
  i   : longint;
  buf : pointer;
begin
  if Append then
   Verbose(V_Debug,'Appending '+fn1+' to '+fn2)
  else
   Verbose(V_Debug,'Copying '+fn1+' to '+fn2);
  assign(f,fn1);
  assign(g,fn2);
  {$I-}
   reset(f,1);
  {$I+}
  if ioresult<>0 then
   Verbose(V_Error,'Can''t open '+fn1);
  if append then
   begin
     {$I-}
      reset(g,1);
     {$I+}
     if ioresult<>0 then
      append:=false
     else
      seek(g,filesize(g));
   end;
  if not append then
   begin
     {$I-}
      rewrite(g,1);
     {$I+}
     if ioresult<>0 then
      Verbose(V_Error,'Can''t open '+fn2+' for output');
   end;
  getmem(buf,bufsize);
  repeat
    blockread(f,buf^,bufsize,i);
    blockwrite(g,buf^,i);
  until i<bufsize;
  freemem(buf,bufsize);
  close(f);
  close(g);
end;


procedure AddLog(const logfile,s:string);
var
  t : text;
begin
  assign(t,logfile);
  {$I-}
   append(t);
  {$I+}
  if ioresult<>0 then
   begin
     {$I-}
      rewrite(t);
     {$I+}
     if ioresult<>0 then
      Verbose(V_Abort,'Can''t append to '+logfile);
   end;
  writeln(t,s);
  close(t);
end;


function GetCompilerInfo(c:tcompinfo):boolean;

  function GetToken(var s:string):string;
  var
    i : longint;
  begin
    i:=pos(' ',s);
    if i=0 then
     i:=length(s)+1;
    GetToken:=Copy(s,1,i-1);
    Delete(s,1,i);
  end;

var
  t  : text;
  hs : string;
begin
  GetCompilerInfo:=false;
  { Try to get all information in one call, this is
    supported in 1.1. Older compilers 1.0.x will only
    return the first info }
  case c of
    compver :
      hs:='-iVTPTO';
    compcpu :
      hs:='-iTPTOV';
    comptarget :
      hs:='-iTOTPV';
  end;
  ExecuteRedir(CompilerBin,hs,'','out','');
  assign(t,'out');
  {$I-}
   reset(t);
   readln(t,hs);
   close(t);
   erase(t);
  {$I+}
  if ioresult<>0 then
   Verbose(V_Error,'Can''t get Compiler Info')
  else
   begin
     Verbose(V_Debug,'Retrieved Compiler Info: "'+hs+'"');
     case c of
       compver :
         begin
           CompilerVersion:=GetToken(hs);
           CompilerCPU:=GetToken(hs);
           CompilerTarget:=GetToken(hs);
         end;
       compcpu :
         begin
           CompilerCPU:=GetToken(hs);
           CompilerTarget:=GetToken(hs);
           CompilerVersion:=GetToken(hs);
         end;
       comptarget :
         begin
           CompilerTarget:=GetToken(hs);
           CompilerCPU:=GetToken(hs);
           CompilerVersion:=GetToken(hs);
         end;
     end;
     GetCompilerInfo:=true;
   end;
end;


function GetCompilerVersion:boolean;
begin
  if CompilerVersion='' then
    GetCompilerVersion:=GetCompilerInfo(compver)
  else
    GetCompilerVersion:=true;
  if GetCompilerVersion then
    Verbose(V_Debug,'Current Compiler Version: "'+CompilerVersion+'"');
end;


function GetCompilerCPU:boolean;
begin
  if CompilerCPU='' then
    GetCompilerCPU:=GetCompilerInfo(compcpu)
  else
    GetCompilerCPU:=true;
  if GetCompilerCPU then
    Verbose(V_Debug,'Current Compiler CPU: "'+CompilerCPU+'"');
end;


function GetCompilerTarget:boolean;
begin
  if CompilerTarget='' then
    GetCompilerTarget:=GetCompilerInfo(comptarget)
  else
    GetCompilerTarget:=true;
  if GetCompilerTarget then
    Verbose(V_Debug,'Current Compiler Target: "'+CompilerTarget+'"');
end;


function ExitWithInternalError(const OutName:string):boolean;
var
  t : text;
  s : string;
begin
  ExitWithInternalError:=false;
  { open logfile }
  assign(t,Outname);
  {$I-}
   reset(t);
  {$I+}
  if ioresult<>0 then
   exit;
  while not eof(t) do
   begin
     readln(t,s);
     if pos('Fatal: Internal error ',s)>0 then
      begin
        ExitWithInternalError:=true;
        break;
      end;
   end;
  close(t);
end;


function RunCompiler:boolean;
var
  outname,
  args : string;
  execres : boolean;
begin
  RunCompiler:=false;
  OutName:=ForceExtension(PPFile,'log');
  args:='-n -Fuunits '+ExtraCompilerOpts;
{$ifdef unix}
  { Add runtime library path to current dir to find .so files }
  if Config.NeedLibrary then
   args:=args+' ''-k-rpath .''';
{$endif unix}
  if Config.NeedOptions<>'' then
   args:=args+' '+Config.NeedOptions;
  args:=args+' '+ppfile;
  Verbose(V_Debug,'Executing '+compilerbin+' '+args);
  { also get the output from as and ld that writes to stderr sometimes }
  execres:=ExecuteRedir(CompilerBin,args,'',OutName,OutName);
  Verbose(V_Debug,'Exitcode '+ToStr(ExecuteResult));

  { Error during execution? }
  if (not execres) and (ExecuteResult=0) then
    begin
      AddLog(FailLogFile,TestName);
      AddLog(ResLogFile,failed_to_compile+PPFileInfo);
      AddLog(LongLogFile,line_separation);
      AddLog(LongLogFile,failed_to_compile+PPFileInfo);
      CopyFile(OutName,LongLogFile,true);
      { avoid to try again }
      AddLog(ForceExtension(PPFile,'elg'),failed_to_compile+PPFileInfo);
      Verbose(V_Abort,'IOStatus: '+ToStr(IOStatus));
      exit;
    end;

  { Check for internal error }
  if ExitWithInternalError(OutName) then
   begin
     AddLog(FailLogFile,TestName);
     if Config.Note<>'' then
      AddLog(FailLogFile,Config.Note);
     AddLog(ResLogFile,failed_to_compile+PPFileInfo+' internalerror generated');
     AddLog(LongLogFile,line_separation);
     AddLog(LongLogFile,failed_to_compile+PPFileInfo);
     if Config.Note<>'' then
      AddLog(LongLogFile,Config.Note);
     CopyFile(OutName,LongLogFile,true);
     { avoid to try again }
     AddLog(ForceExtension(PPFile,'elg'),'Failed to compile '++PPFileInfo);
     Verbose(V_Abort,'Internal error in compiler');
     exit;
   end;

  { Shoud the compile fail ? }
  if Config.ShouldFail then
   begin
     if ExecuteResult<>0 then
      begin
        AddLog(ResLogFile,success_compilation_failed+PPFileInfo);
        { avoid to try again }
        AddLog(ForceExtension(PPFile,'elg'),success_compilation_failed+PPFileInfo);
        RunCompiler:=true;
      end
     else
      begin
        AddLog(FailLogFile,TestName);
        if Config.Note<>'' then
          AddLog(FailLogFile,Config.Note);
        AddLog(ResLogFile,failed_compilation_successful+PPFileInfo);
        AddLog(LongLogFile,line_separation);
        AddLog(LongLogFile,failed_compilation_successful+PPFileInfo);
        { avoid to try again }
        AddLog(ForceExtension(PPFile,'elg'),failed_compilation_successful+PPFileInfo);
        if Config.Note<>'' then
          AddLog(LongLogFile,Config.Note);
        CopyFile(OutName,LongLogFile,true);
      end;
   end
  else
   begin
     if (ExecuteResult<>0) and
        (((Config.KnownCompileNote<>'') and (Config.KnownCompileError=0)) or
         ((Config.KnownCompileError<>0) and (ExecuteResult=Config.KnownCompileError))) then
      begin
        AddLog(FailLogFile,TestName+known_problem+Config.KnownCompileNote);
        AddLog(ResLogFile,failed_to_run+PPFileInfo+known_problem+Config.KnownCompileNote);
        AddLog(LongLogFile,line_separation);
        AddLog(LongLogFile,known_problem+Config.KnownCompileNote);
        AddLog(LongLogFile,failed_to_compile+PPFileInfo+' ('+ToStr(ExecuteResult)+')');
        Copyfile(OutName,LongLogFile,true);
        Verbose(V_Abort,known_problem+'exitcode: '+ToStr(ExecuteResult));
      end
     else if ExecuteResult<>0 then
      begin
        AddLog(FailLogFile,TestName);
        if Config.Note<>'' then
          AddLog(FailLogFile,Config.Note);
        AddLog(ResLogFile,failed_to_compile+PPFileInfo);
        AddLog(LongLogFile,line_separation);
        AddLog(LongLogFile,failed_to_compile+PPFileInfo);
        if Config.Note<>'' then
          AddLog(LongLogFile,Config.Note);
        CopyFile(OutName,LongLogFile,true);
        { avoid to try again }
        AddLog(ForceExtension(PPFile,'elg'),failed_to_compile+PPFileInfo);
        Verbose(V_Abort,'Exitcode: '+ToStr(ExecuteResult)+' (expected 0)');
      end
     else
      begin
        AddLog(ResLogFile,successfully_compiled+PPFileInfo);
        RunCompiler:=true;
      end;
   end;
end;


function RunExecutable:boolean;
var
  outname,
  TestExe : string;
  execres  : boolean;
begin
  RunExecutable:=false;
  execres:=true;
  TestExe:=ForceExtension(PPFile,ExeExt);
  OutName:=ForceExtension(PPFile,'elg');
  Verbose(V_Debug,'Executing '+TestExe);
  if RemoteAddr<>'' then
    begin
      ExecuteRedir('ssh',RemoteAddr+' rm -f '+RemotePath+'/'+TestExe,'',OutName,'');
      ExecuteRedir('scp',TestExe+' '+RemoteAddr+':'+RemotePath+'/'+TestExe,'',OutName,'');
      { don't redirect interactive and graph programs .. }
      if Config.IsInteractive or Config.UsesGraph then
        ExecuteRedir(TestExe,'','','','')
      else
        ExecuteRedir('ssh',RemoteAddr+' '+RemotePath+'/'+TestExe,'',OutName,'');
      if DelExecutable then
        ExecuteRedir('ssh',RemoteAddr+' rm -f '+RemotePath+'/'+TestExe,'',OutName,'');
    end
  else
    begin
      { don't redirect interactive and graph programs .. }
      if Config.IsInteractive or Config.UsesGraph then
        execres:=ExecuteRedir(TestExe,'','','','')
      else
        execres:=ExecuteRedir(TestExe,'','',OutName,'');
    end;
  Verbose(V_Debug,'Exitcode '+ToStr(ExecuteResult));

  { Error during execution? }
  if (not execres) and (ExecuteResult=0) then
    begin
      AddLog(FailLogFile,TestName);
      AddLog(ResLogFile,failed_to_run+PPFileInfo);
      AddLog(LongLogFile,line_separation);
      AddLog(LongLogFile,failed_to_run+PPFileInfo);
      CopyFile(OutName,LongLogFile,true);
      { avoid to try again }
      AddLog(ForceExtension(PPFile,'elg'),failed_to_run+PPFileInfo);
      Verbose(V_Abort,'IOStatus: '+ToStr(IOStatus));
      exit;
    end;

  if ExecuteResult<>Config.ResultCode then
   begin
     if (ExecuteResult<>0) and
        (ExecuteResult=Config.KnownRunError) then
       begin
         AddLog(FailLogFile,TestName+known_problem+Config.KnownRunNote);
         AddLog(ResLogFile,failed_to_run+PPFileInfo+known_problem+Config.KnownRunNote);
         AddLog(LongLogFile,line_separation);
         AddLog(LongLogFile,known_problem+Config.KnownRunNote);
         AddLog(LongLogFile,failed_to_run+PPFileInfo+' ('+ToStr(ExecuteResult)+')');
         Copyfile(OutName,LongLogFile,true);
         Verbose(V_Abort,known_problem+'exitcode: '+ToStr(ExecuteResult)+' (expected '+ToStr(Config.ResultCode)+')');
       end
     else
       begin
         AddLog(FailLogFile,TestName);
         AddLog(ResLogFile,failed_to_run+PPFileInfo);
         AddLog(LongLogFile,line_separation);
         AddLog(LongLogFile,failed_to_run+PPFileInfo+' ('+ToStr(ExecuteResult)+')');
         Copyfile(OutName,LongLogFile,true);
         Verbose(V_Abort,'Exitcode: '+ToStr(ExecuteResult)+' (expected '+ToStr(Config.ResultCode)+')');
       end
   end
  else
   begin
     AddLog(ResLogFile,successfully_run+PPFileInfo);
     RunExecutable:=true;
   end;
end;


procedure getargs;
var
  ch   : char;
  para : string;
  i    : longint;

  procedure helpscreen;
  begin
    writeln('dotest [Options] <File>');
    writeln;
    writeln('Options can be:');
    writeln('  -C<compiler>  set compiler to use');
    writeln('  -V            verbose');
    writeln('  -E            execute test also');
    writeln('  -X            don''t use COMSPEC');
    writeln('  -A            include ALL tests');
    writeln('  -G            include graph tests');
    writeln('  -K            include known bug tests');
    writeln('  -I            include interactive tests');
    writeln('  -R<remote>    run the tests remotely with the given ssh address');
    writeln('  -P<path>      path to the tests tree on the remote machine');
    writeln('  -T            remove executables after execution (applies only for remote tests)');
    writeln('  -Y<opts>      extra options passed to the compiler. Several -Y<opt> can be given.');
    halt(1);
  end;

begin
  PPFile:='';
  if exeext<>'' then
    CompilerBin:='ppc386.'+exeext
  else
    CompilerBin:='ppc386';
  for i:=1 to paramcount do
   begin
     para:=Paramstr(i);
     if (para[1]='-') then
      begin
        ch:=Upcase(para[2]);
        delete(para,1,2);
        case ch of
         'A' :
           begin
             DoGraph:=true;
             DoInteractive:=true;
             DoKnown:=true;
             DoAll:=true;
           end;
         'C' : CompilerBin:=Para;
         'E' : DoExecute:=true;
         'G' : begin
                 DoGraph:=true;
                 if para='-' then
                   DoUsual:=false;
               end;
         'I' : begin
                 DoInteractive:=true;
                 if para='-' then
                   DoUsual:=false;
               end;
         'K' : begin
                 DoKnown:=true;
                 if para='-' then
                   DoUsual:=false;
               end;
         'V' : DoVerbose:=true;

         'X' : UseComSpec:=false;

         'P' : RemotePath:=Para;

         'Y' : ExtraCompilerOpts:= ExtraCompilerOpts +' '+ Para;

         'R' : RemoteAddr:=Para;

         'T' : DelExecutable:=true;
        end;
     end
    else
     begin
       If PPFile<>'' then
         HelpScreen;
       PPFile:=ForceExtension(Para,'pp');
     end;
    end;
  if (PPFile='') then
   HelpScreen;
  SetPPFileInfo;
  TestName:=Copy(PPFile,1,Pos('.pp',PPFile)-1);
  Verbose(V_Debug,'Running test '+TestName+', file '+PPFile);
end;


procedure RunTest;
var
  Res : boolean;
  OutName : string;
begin
  Res:=GetConfig(ppfile,Config);
  OutName:=ForceExtension(PPFile,'elg');

  if Res then
   begin
     if Config.UsesGraph and (not DoGraph) then
      begin
        AddLog(ResLogFile,skipping_graph_test+PPFileInfo);
        { avoid a second attempt by writing to elg file }
        AddLog(OutName,skipping_graph_test+PPFileInfo);
        Verbose(V_Abort,skipping_graph_test);
        Res:=false;
      end;
   end;

  if Res then
   begin
     if Config.IsInteractive and (not DoInteractive) then
      begin
        { avoid a second attempt by writing to elg file }
        AddLog(OutName,skipping_interactive_test+PPFileInfo);
        AddLog(ResLogFile,skipping_interactive_test+PPFileInfo);
        Verbose(V_Abort,skipping_interactive_test);
        Res:=false;
      end;
   end;

  if Res then
   begin
     if Config.IsKnownCompileError and (not DoKnown) then
      begin
        { avoid a second attempt by writing to elg file }
        AddLog(OutName,skipping_known_bug+PPFileInfo);
        AddLog(ResLogFile,skipping_known_bug+PPFileInfo);
        Verbose(V_Abort,skipping_known_bug);
        Res:=false;
      end;
   end;

  if Res and not DoUsual then
    res:=(Config.IsInteractive and DoInteractive) or
         (Config.IsKnownRunError and DoKnown) or
         (Config.UsesGraph and DoGraph);

  if Res then
   begin
     if (Config.MinVersion<>'') and not DoAll then
      begin
        Verbose(V_Debug,'Required compiler version: '+Config.MinVersion);
        Res:=GetCompilerVersion;
        if CompilerVersion<Config.MinVersion then
         begin
           { avoid a second attempt by writing to elg file }
           AddLog(OutName,skipping_compiler_version_too_low+PPFileInfo);
           AddLog(ResLogFile,skipping_compiler_version_too_low+PPFileInfo);
           Verbose(V_Abort,'Compiler version too low '+CompilerVersion+' < '+Config.MinVersion);
           Res:=false;
         end;
      end;
   end;

  if Res then
   begin
     if (Config.MaxVersion<>'') and not DoAll then
      begin
        Verbose(V_Debug,'Highest compiler version: '+Config.MaxVersion);
        Res:=GetCompilerVersion;
        if CompilerVersion>Config.MaxVersion then
         begin
           { avoid a second attempt by writing to elg file }
           AddLog(OutName,skipping_compiler_version_too_high+PPFileInfo);
           AddLog(ResLogFile,skipping_compiler_version_too_high+PPFileInfo);
           Verbose(V_Abort,'Compiler version too high '+CompilerVersion+' > '+Config.MaxVersion);
           Res:=false;
         end;
      end;
   end;

  if Res then
   begin
     if Config.NeedCPU<>'' then
      begin
        Verbose(V_Debug,'Required compiler cpu: '+Config.NeedCPU);
        Res:=GetCompilerCPU;
        if not IsInList(CompilerCPU,Config.NeedCPU) then
         begin
           { avoid a second attempt by writing to elg file }
           AddLog(OutName,skipping_other_cpu+PPFileInfo);
           AddLog(ResLogFile,skipping_other_cpu+PPFileInfo);
           Verbose(V_Abort,'Compiler cpu "'+CompilerCPU+'" is not in list "'+Config.NeedCPU+'"');
           Res:=false;
         end;
      end;
   end;

  if Res then
   begin
     if Config.SkipCPU<>'' then
      begin
        Verbose(V_Debug,'Skip compiler cpu: '+Config.NeedCPU);
        Res:=GetCompilerCPU;
        if IsInList(CompilerCPU,Config.SkipCPU) then
         begin
           { avoid a second attempt by writing to elg file }
           AddLog(OutName,skipping_other_cpu+PPFileInfo);
           AddLog(ResLogFile,skipping_other_cpu+PPFileInfo);
           Verbose(V_Abort,'Compiler cpu "'+CompilerCPU+'" is in list "'+Config.SkipCPU+'"');
           Res:=false;
         end;
      end;
   end;

  if Res then
   begin
     if Config.NeedTarget<>'' then
      begin
        Verbose(V_Debug,'Required compiler target: '+Config.NeedTarget);
        Res:=GetCompilerTarget;
        if not IsInList(CompilerTarget,Config.NeedTarget) then
         begin
           { avoid a second attempt by writing to elg file }
           AddLog(OutName,skipping_other_target+PPFileInfo);
           AddLog(ResLogFile,skipping_other_target+PPFileInfo);
           Verbose(V_Abort,'Compiler target "'+CompilerTarget+'" is not in list "'+Config.NeedTarget+'"');
           Res:=false;
         end;
      end;
   end;

  if Res then
   begin
     if Config.SkipTarget<>'' then
      begin
        Verbose(V_Debug,'Skip compiler target: '+Config.NeedTarget);
        Res:=GetCompilerTarget;
        if IsInList(CompilerTarget,Config.SkipTarget) then
         begin
           { avoid a second attempt by writing to elg file }
           AddLog(OutName,skipping_other_target+PPFileInfo);
           AddLog(ResLogFile,skipping_other_target+PPFileInfo);
           Verbose(V_Abort,'Compiler target "'+CompilerTarget+'" is in list "'+Config.SkipTarget+'"');
           Res:=false;
         end;
      end;
   end;

  if Res then
   begin
     Res:=RunCompiler;
     if Res and Config.NeedRecompile then
      Res:=RunCompiler;
   end;

  if Res then
   begin
     if (Config.NoRun) then
      begin
        { avoid a second attempt by writing to elg file }
        AddLog(OutName,skipping_run_test+PPFileInfo);
        AddLog(ResLogFile,skipping_run_test+PPFileInfo);
        Verbose(V_Debug,skipping_run_test);
      end
     else if Config.IsKnownRunError and (not DoKnown) then
      begin
        { avoid a second attempt by writing to elg file }
        AddLog(OutName,skipping_known_bug+PPFileInfo);
        AddLog(ResLogFile,skipping_known_bug+PPFileInfo);
        Verbose(V_Abort,skipping_known_bug);
      end
     else
      begin
        if (not Config.ShouldFail) and DoExecute then
         begin
           if FileExists(ForceExtension(PPFile,'ppu')) or
              FileExists(ForceExtension(PPFile,'ppo')) or
              FileExists(ForceExtension(PPFile,'ppw')) then
             begin
               AddLog(ForceExtension(PPFile,'elg'),skipping_run_unit+PPFileInfo);
               AddLog(ResLogFile,skipping_run_unit+PPFileInfo);
               Verbose(V_Debug,'Unit found, skipping run test')
             end
           else
            Res:=RunExecutable;
         end;
      end;
   end;
end;


begin
  GetArgs;
  RunTest;
end.
{
  $Log$
  Revision 1.33  2004-05-02 09:31:52  peter
    * remove failed_to_execute_ strings, use the failed_to_run

  Revision 1.32  2004/04/29 21:41:44  peter
    * test result of execution and report as failure with iostatus displayed

  Revision 1.31  2004/04/01 12:51:32  olle
    + Several -Y<opt> is now allowed

  Revision 1.30  2004/03/21 19:15:18  florian
    * explanation for running the testsuite remotely
    + dotest supports remote execution using scp/ssh

  Revision 1.29  2003/10/31 16:14:20  peter
    * remove compileerror10, note10
    * remove known, use knowncompileerror,knownrunerror instead
    * knowncompileerror,knownrunerror tests are now really skipped

  Revision 1.28  2003/10/13 14:19:02  peter
    * digest updated for max version limit

  Revision 1.27  2003/06/13 08:16:34  pierre
   * fix a problem with KNOWNCOMPILE10ERROR

  Revision 1.26  2003/02/20 12:41:15  pierre
   + handle KNOWNCOMPILEERROR and KNOWNCOMPILE10ERROR

  Revision 1.25  2002/12/24 22:30:41  peter
    * small verbosity update

  Revision 1.24  2002/12/24 21:47:49  peter
    * NeedTarget, SkipTarget, SkipCPU added
    * Retrieve compiler info in a single call for 1.1 compiler

  Revision 1.23  2002/12/17 15:04:32  michael
  + Added dbdigest to store results in a database

  Revision 1.22  2002/12/15 13:30:46  peter
    * NEEDLIBRARY option to add -rpath to the linker for unix. This is
      needed to test runtime library tests. The library needs the -FE.
      option to place the .so in the correct directory

  Revision 1.21  2002/12/05 16:03:34  pierre
   + -X option to disable UseComSpec

  Revision 1.20  2002/11/18 16:42:43  pierre
   + KNOWNRUNERROR added

  Revision 1.19  2002/11/18 01:31:07  pierre
   + use -n option
   + use -G- for only graph
   + use -I- for only interactive
   + use -K- for only known bugs.

  Revision 1.18  2002/11/14 10:36:12  pierre
   * add internalerror info to log file

  Revision 1.17  2002/11/13 15:26:24  pierre
   + digest program added

  Revision 1.16  2002/11/13 15:19:44  pierre
   log strings moved to teststr unit

  Revision 1.15  2002/09/07 15:40:56  peter
    * old logs removed and tabs fixed

  Revision 1.14  2002/04/21 18:15:32  peter
    * Check for internal errors

  Revision 1.13  2002/03/03 13:27:28  hajny
    + added support for OS/2 units (.ppo)

  Revision 1.12  2002/01/29 13:24:16  pierre
   + also generate .elg file for units

  Revision 1.11  2002/01/29 12:51:08  pierre
    + PPFileInfo to also display time stamp of test file
    * generate .elg file in several cases
      to avoid trying to recompute the same test
      over and over again.

}
