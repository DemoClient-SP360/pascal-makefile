{
    $Id$
    Copyright (c) 2001 by Peter Vreman

    FPCMake - Main module

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}
{$ifdef fpc}{$mode objfpc}{$endif}
{$H+}
unit fpcmmain;
interface

    uses
      dos,
{$ifdef Unix}
  {$ifdef VER1_0}
  {$ifdef linux}
      linux,
  {$endif}
  {$else}
      unix,
  {$endif}
{$endif}
      sysutils,classes,
      fpcmdic;

    const
      Version='1.1';
      Title='FPCMake Version '+Version;
      TitleDate=Title+' ['+{$ifdef fpc}{$i %DATE}{$else}'n/a'{$endif}+']';

    type
      TTarget=(
        t_linux,t_go32v2,t_win32,t_os2,t_freebsd,t_beos,t_netbsd,
        t_amiga,t_atari
      );
      TTargetSet=set of TTarget;

    const
      TargetStr : array[TTarget] of string=(
        'linux','go32v2','win32','os2','freebsd','beos','netbsd',
        'amiga','atari'
      );

      TargetSuffix : array[TTarget] of string=(
        '_linux','_go32v2','_win32','_os2','_freebsd','_beos','_netbsd',
        '_amiga','_atari'
      );


    type
      TKeyValueItem = class(TDictionaryItem)
      private
        FValue : string;
      public
        constructor Create(const k,v:string);
        property Value:string read FValue write FValue;
      end;

      TKeyValue = class(TDictionary)
      private
        function GetKey(const k:string):string;
      public
        procedure Add(const k,v:String);
        property Key[const s:string]:string read GetKey write Add;default;
      end;

      TFPCMakeSection = class(TDictionaryItem)
      private
        FList       : TStringList;
        FDictionary : TKeyValue;
        procedure BuildIniDic(p:TDictionaryItem);
        procedure BuildMakefileDic(p:TDictionaryItem);
        function GetKey(const k:string):string;
      public
        constructor Create(const n:string);
        constructor CreateKeyValue(const n:string);
        destructor  Destroy;override;
        procedure AddLine(const s:string);
        procedure AddKey(const k,v:string);
        procedure Clear;
        procedure ParseIni;
        procedure BuildIni;
        procedure BuildMakefile;
        property Key[const s:string]:string read GetKey;default;
        property List:TStringList read FList;
        property Dictionary:TKeyValue read FDictionary;
      end;

      TTargetRequireList = array[ttarget] of TStringList;

      TFPCMakeVerbose = (FPCMakeError, FPCMakeInfo, FPCMakeDebug);

      TFPCMake = class
      private
        FStream         : TStream;
        FFileName       : string;
        FCommentChars   : TSysCharSet;
        FEmptyLines     : boolean;
        FSections       : TDictionary;
        FPackageSec,
        FExportSec      : TFPCMakeSection;
        FIsPackage      : boolean;
        FPackageName,
        FPackageVersion,
        FPackageTargets : string;
        FRequireList    : TTargetRequireList;
        FVariables      : TKeyValue;
        FIncludeTargets : TTargetSet;
        procedure Init;
        procedure ParseSec(p:TDictionaryItem);
        procedure PrintSec(p:TDictionaryItem);
        procedure PrintDic(p:TDictionaryItem);
        function  GetSec(const AName:string):TDictionaryItem;
        procedure LoadRequiredPackage(t:TTarget;const ReqName,ReqVersion:string);
        procedure LoadRequiredDir(t:TTarget;const MainPack,currdir,subdir:string);
        procedure LoadRequires(t:Ttarget;FromFPCMake:TFPCMake);
        function  CopySection(Sec:TFPCMakeSection;Secname:string):TFPCMakeSection;
      protected
        VerboseIdent : string;
      public
        constructor Create(const AFileName:string);
        constructor CreateFromStream(s:TStream;const AFileName:string);
        destructor  Destroy;override;
        procedure Verbose(lvl:TFPCMakeVerbose;const s:string);virtual;
        procedure SetTargets(const s:string);
        procedure LoadSections;
        procedure LoadMakefileFPC;
        procedure LoadPackageSection;
        procedure LoadRequireSection;
        function  GetTargetRequires(t:TTarget):TStringList;
        function  CheckLibcRequire:boolean;
        procedure CreateExportSection;
        procedure AddDefaultVariables;
        function  SubstVariables(const s:string):string;
        function  GetVariable(const inivar:string;dosubst:boolean):string;
        function  SetVariable(const inivar,value:string;add:boolean):string;
        procedure Print;
        property Section[const s:string]:TDictionaryItem read GetSec;default;
        property RequireList:TTargetRequireList read FRequireList;
        property Variables:TKeyValue read FVariables;
        property IsPackage:boolean read FIsPackage;
        property PackageName:string read FPackageName;
        property PackageVersion:string read FPackageVersion;
        property PackageSec:TFPCMakeSection read FPackageSec;
        property ExportSec:TFPCMakeSection read FExportSec;
        property CommentChars:TSysCharSet read FCommentChars write FCommentChars;
        property EmptyLines:Boolean read FEmptyLines write FEmptyLines;
        property IncludeTargets:TTargetSet read FIncludeTargets write FIncludeTargets;
      end;

    function posidx(const substr,s : string;idx:integer):integer;
    function GetToken(var s:string;sep:char):string;
    procedure AddToken(var s:string;const tok:string;sep:char);


implementation

    resourcestring
      s_not_list_sec='Not a list section "%s"';
      s_not_key_value_sec='Not a key-value section "%s"';
      s_err_section_start='%s:%d: Wrong section start';
      s_err_not_key_value='Parse error key=value excepted: "%s"';
      s_err_no_section='%s:%d: Entries without section';
      s_no_package_name='No package name set';
      s_no_package_version='No package version set';
      s_err_require_format='Wrong require format "%s"';
      s_wrong_package_name='Package name "%s" expected, but "%s" found';
      s_wrong_package_version='Package version "%s" expected, but version "%s" found';
      s_directory_not_found='Directory "%s" not found';
      s_makefilefpc_not_found='No Makefile.fpc found in directory "%s"';
      s_package_not_found='Target "%s", package "%s" not found';
      s_fpcmake_version_required='FPCMake version "%s" is required';
      s_no_targets_set='No targets set';
      s_targets_info='Targets: "%s"';
      s_globals='Globals:';


{****************************************************************************
                                 Helpers
****************************************************************************}

    Function PathExists ( F : String) : Boolean;
      Var
        Info : TSearchRec;
      begin
        if F[Length(f)] in ['/','\'] then
         Delete(f,length(f),1);
        PathExists:=(findfirst(F,faAnyFile,info)=0) and
                    ((info.attr and fadirectory)=fadirectory);
        findclose(Info);
      end;


    Function PathOrFileExists ( F : String) : Boolean;
      Var
        Info : Dos.SearchRec;
      begin
        if F[Length(f)] in ['/','\'] then
         Delete(f,length(f),1);
        dos.findfirst(f,fareadonly+faarchive+fahidden+fadirectory,info);
        PathOrFileExists:=(Doserror=0);
        dos.findclose(Info);
      end;


    function posidx(const substr,s : string;idx:integer):integer;
      var
        i,j : integer;
        e   : boolean;
      begin
        i:=idx;
        j:=0;
        e:=(length(SubStr)>0);
        while e and (i<=Length(s)-Length(SubStr)) do
         begin
           inc(i);
           if (SubStr[1]=s[i]) and (Substr=Copy(s,i,Length(SubStr))) then
            begin
              j:=i;
              e:=false;
            end;
         end;
        PosIdx:=j;
      end;


    function GetToken(var s:string;sep:char):string;
      var
        i : integer;
      begin
        s:=Trim(s);
        i:=pos(sep,s);
        if i=0 then
         begin
           Result:=s;
           s:='';
         end
        else
         begin
           Result:=Copy(s,1,i-1);
           Delete(s,1,i);
         end;
      end;


    procedure AddToken(var s:string;const tok:string;sep:char);
      begin
        if tok='' then
         exit;
        if s<>'' then
         s:=s+sep+tok
        else
         s:=tok;
      end;


{****************************************************************************
                               TKeyValueItem
****************************************************************************}

    constructor TKeyValueItem.Create(const k,v:string);
      begin
        inherited Create(k);
        value:=v;
      end;


{****************************************************************************
                                 TKeyValue
****************************************************************************}

    function TKeyValue.GetKey(const k:string):string;
      var
        p : TKeyValueItem;
      begin
        p:=TKeyValueItem(Search(k));
        if p=nil then
         GetKey:=''
        else
         GetKey:=p.Value;
      end;


    procedure TKeyValue.Add(const k,v:string);
      var
        p : TKeyValueItem;
      begin
        p:=TKeyValueItem(Search(k));
        if p=nil then
         begin
           p:=TKeyValueItem.Create(k,v);
           Insert(p);
         end
        else
         p.Value:=v;
      end;


{****************************************************************************
                               TFPCMakeSection
****************************************************************************}

    constructor TFPCMakeSection.Create(const n:string);
      begin
        inherited Create(n);
        FList:=TStringList.Create;
        FDictionary:=nil;
      end;


    constructor TFPCMakeSection.CreateKeyValue(const n:string);
      begin
        inherited Create(n);
        FList:=nil;
        FDictionary:=TKeyValue.Create;
      end;


    destructor TFPCMakeSection.Destroy;
      begin
        inherited Destroy;
        FList.Free;
        FDictionary.Free;
      end;


    procedure TFPCMakeSection.Clear;
      begin
        FList.Free;
        FList:=TStringList.Create;
        FDictionary.Free;
        FDictionary:=nil;
      end;


    procedure TFPCMakeSection.AddLine(const s:string);
      begin
        if FList=nil then
         raise Exception.Create(Format(s_not_list_sec,[Name]));
        FList.Add(s);
      end;


    procedure TFPCMakeSection.AddKey(const k,v:string);
      begin
        if FDictionary=nil then
         raise Exception.Create(Format(s_not_key_value_sec,[Name]));
        { Don't add empty values }
        if v<>'' then
         FDictionary.Add(k,v);
      end;


    function TFPCMakeSection.GetKey(const k:string):string;
      begin
        if FDictionary=nil then
         raise Exception.Create(Format(s_not_key_value_sec,[Name]));
        GetKey:=FDictionary[k];
      end;


    procedure TFPCMakeSection.ParseIni;
      var
        p : TKeyValueItem;
        i,j,len,maxi : integer;
        s,newkey,value : string;
      begin
        { If already processed skip }
        if assigned(FDictionary) then
         exit;
        { Don't process rules section }
        if (Name='prerules') or (Name='rules') then
         exit;
        { Parse the section }
        FDictionary:=TKeyValue.Create;
        { Parse the list }
        maxi:=FList.Count;
        i:=0;
        while (i<maxi) do
         begin
           s:=Trim(FList[i]);
           len:=Length(s);
           { Concat lines ending with \ }
           while s[len]='\' do
            begin
              Delete(s,len,1);
              if i+1<maxi then
               begin
                 inc(i);
                 s:=s+Trim(FList[i]);
                 len:=Length(s);
               end;
            end;
           { Parse key=value line }
           j:=0;
           while (j<len) and (s[j+1] in ['A'..'Z','a'..'z','0'..'9','_']) do
            inc(j);
           NewKey:=Copy(s,1,j);
           While (j<len) and (s[j+1] in [' ',#9]) do
            inc(j);
           inc(j);
           if s[j]<>'=' then
            Raise Exception.Create(Format(s_err_not_key_value,[s]));
           While (j<len) and (s[j+1] in [' ',#9]) do
            inc(j);
           Value:=Copy(s,j+1,len-j);
           p:=TKeyValueItem(FDictionary.Search(NewKey));
           { Concat values if key already exists }
           if assigned(p) then
            AddToken(p.FValue,Value,' ')
           else
            FDictionary.Add(NewKey,Value);
           inc(i);
         end;
        { List is not used anymore }
        FList.Free;
        FList:=nil;
      end;



    procedure TFPCMakeSection.BuildIniDic(p:TDictionaryItem);
      begin
        with TKeyValueItem(p) do
         begin
           FList.Add(Name+'='+Value);
         end;
      end;


    procedure TFPCMakeSection.BuildIni;
      begin
        if assigned(FList) then
         exit;
        FList:=TStringList.Create;
        FDictionary.Foreach(@BuildIniDic);
        FDictionary.Free;
        FDictionary:=nil;
      end;


    procedure TFPCMakeSection.BuildMakefileDic(p:TDictionaryItem);
      begin
        FList.Add(Uppercase(Name+'_'+TKeyValueItem(p).Name)+'='+TKeyValueItem(p).Value);
      end;


    procedure TFPCMakeSection.BuildMakefile;
      begin
        if assigned(FList) then
         exit;
        FList:=TStringList.Create;
        FDictionary.Foreach(@BuildMakefileDic);
        FDictionary.Free;
        FDictionary:=nil;
      end;


{****************************************************************************
                                   TFPCMake
****************************************************************************}

    constructor TFPCMake.Create(const AFileName:string);
      begin
        FFileName:=AFileName;
        FStream:=nil;
        Init;
      end;


    constructor TFPCMake.CreateFromStream(s:TStream;const AFileName:string);
      begin
        FFileName:=AFileName;
        FStream:=s;
        Init;
      end;


    procedure TFPCMake.Init;
      var
        t : ttarget;
      begin
        FSections:=TDictionary.Create;
        for t:=low(ttarget) to high(ttarget) do
         FRequireList[t]:=TStringList.Create;
        FVariables:=TKeyValue.Create;
        FCommentChars:=[';','#'];
        FEmptyLines:=false;
        FIsPackage:=false;
        FPackageName:='';
        FPackageVersion:='';
        FPackageSec:=nil;
        FExportSec:=nil;
        FIncludeTargets:=[low(TTarget)..high(TTarget)];
        VerboseIdent:='';
      end;


    destructor TFPCMake.Destroy;
      var
        t : ttarget;
      begin
        FSections.Free;
        for t:=low(ttarget) to high(ttarget) do
         FRequireList[t].Free;
        FVariables.Free;
      end;


    procedure TFPCMake.LoadSections;
      var
        SLInput : TStringList;
        i,j,n : integer;
        s,
        SecName : string;
        CurrSec : TFPCMakeSection;
      begin
        try
          SLInput:=TStringList.Create;
          if assigned(FStream) then
           SLInput.LoadFromStream(FStream)
          else
           SLInput.LoadFromFile(FFileName);
          { Load Input into sections list }
          n:=SLInput.Count;
          i:=0;
          while (i<n) do
           begin
             s:=Trim(SLInput[i]);
             if (EmptyLines and (s='')) or
                ((s<>'') and not(s[1] in FCommentChars)) then
              begin
                { section start? }
                if (s<>'') and (s[1]='[') then
                 begin
                   j:=pos(']',s);
                   if j=0 then
                    raise Exception.Create(Format(s_err_section_start,[FFileName,i]));
                   SecName:=Copy(s,2,j-2);
                   CurrSec:=TFPCMakeSection(FSections[SecName]);
                   if CurrSec=nil then
                    CurrSec:=TFPCMakeSection(FSections.Insert(TFPCMakeSection.Create(SecName)));
                 end
                else
                 begin
                   if CurrSec=nil then
                    raise Exception.Create(Format(s_err_no_section,[FFileName,i]));
                   { Insert string without spaces stripped }
                   CurrSec.AddLine(SLInput[i]);
                 end;
              end;
             inc(i);
           end;
        finally
          SLInput.Free;
        end;
      end;


    function TFPCMake.CopySection(Sec:TFPCMakeSection;Secname:string):TFPCMakeSection;
      begin
        Result:=TFPCMakeSection(FSections[SecName]);
        if Sec=Nil then
         exit;
        { Clear old section or if not existing create new }
        if assigned(Result) then
         Result.Clear
        else
         Result:=TFPCMakeSection(FSections.Insert(TFPCMakeSection.Create(SecName)));
        Sec.BuildIni;
        Result.List.AddStrings(Sec.List);
        Result.ParseIni;
        Sec.ParseIni;
      end;


    procedure TFPCMake.LoadMakefileFPC;
      begin
        LoadSections;
        { Parse all sections }
        FSections.Foreach(@ParseSec);
        { Add some default variables like FPCDIR, UNITSDIR }
        AddDefaultVariables;
        { Load package section }
        LoadPackageSection;
        LoadRequireSection;
      end;


    procedure TFPCMake.Verbose(lvl:TFPCMakeVerbose;const s:string);
      begin
        writeln(VerboseIdent,s);
      end;


    procedure TFPCMake.SetTargets(const s:string);
      var
        hslst : string;
        hs : string;
        t  : TTarget;
      begin
        FIncludeTargets:=[];
        hslst:=s;
        repeat
          hs:=LowerCase(GetToken(hslst,','));
          if hs='' then
           break;
          for t:=low(TTarget) to high(TTarget) do
           if hs=TargetStr[t] then
            include(FIncludeTargets,t);
        until false;
        if FIncludeTargets=[] then
         raise Exception.Create(s_no_targets_set)
        else
         begin
           hs:='';
           for t:=low(TTarget) to high(TTarget) do
            if t in FIncludeTargets then
             AddToken(hs,TargetStr[t],' ');
           Verbose(FPCMakeDebug,Format(s_targets_info,[hs]));
         end;
      end;


    procedure TFPCMake.LoadPackageSection;
      var
        hs,s : string;
        t : TTarget;
      begin
        { Get package info from package section }
        FPackageSec:=TFPCMakeSection(FSections['package']);
        if FPackageSec=nil then
         exit;
        { Parse the section to key=value pairs }
        FPackageSec.ParseIni;
        { Are we a subpart of a package, then load that package }
        s:=FPackageSec['main'];
        if s<>'' then
         begin
           SetVariable('package_name',s,false);
           FPackageName:=s;
         end
        else
         begin
           { mandatory name }
           FPackageName:=FPackageSec['name'];
           if FPackageName='' then
            Raise Exception.Create(s_no_package_name);
           { mandatory version }
           FPackageVersion:=FPackageSec['version'];
           if FPackageVersion='' then
            Raise Exception.Create(s_no_package_version);
           FIsPackage:=true;
           { optional targets }
           FPackageTargets:='';
           s:=LowerCase(FPackageSec['targets']);
           repeat
             hs:=GetToken(s,' ');
             if hs='' then
              break;
             for t:=low(TTarget) to high(TTarget) do
              if hs=TargetStr[t] then
               begin
                 AddToken(FPackageTargets,hs,' ');
                 break;
               end;
           until false;
           { Set the ExportSec }
           FExportSec:=TFPCMakeSection(FSections[Lowercase(FPackageName)]);
         end;
      end;


    procedure TFPCMake.CreateExportSection;
      var
        t : TTarget;
      begin
        { Don't create a section twice }
        if FExportSec<>nil then
         exit;
        { Look if we've already an own section, else create a new
          key-value section }
        FExportSec:=TFPCMakeSection(FSections[LowerCase(FPackageName)]);
        if FExportSec=nil then
         FExportSec:=TFPCMakeSection(FSections.Insert(TFPCMakeSection.CreateKeyValue(LowerCase(FPackageName))));
        { Add default the values to the export section }
        FExportSec.AddKey('name',FPackageName);
        FExportSec.AddKey('version',FPackageVersion);
        { Add required packages }
        for t:=low(TTarget) to high(TTarget) do
         FExportSec.AddKey('require'+TargetSuffix[t],FPackageSec['require'+TargetSuffix[t]]);
        { Unit dir }
        {FExportSec.AddKey('unitdir','$(UNITSDIR)/'+Lowercase(PackageName));}
      end;


    procedure TFPCMake.LoadRequiredPackage(t:TTarget;const ReqName,ReqVersion:string);

        function TryFile(const fn:string):boolean;
        var
          ReqFPCMake : TFPCMake;
        begin
          TryFile:=false;
          if FileExists(fn) then
           begin
             VerboseIdent:=VerboseIdent+'  ';
             Verbose(FPCMakeDebug,'Package '+ReqName+': '+fn);

             ReqFPCMake:=TFPCMake.Create(fn);
             ReqFPCMake.LoadSections;
             ReqFPCMake.LoadPackageSection;
             { Check package name and version }
             if LowerCase(ReqFPCMake.PackageName)<>ReqName then
              raise Exception.Create(Format(s_wrong_package_name,[ReqName,LowerCase(ReqFPCMake.PackageName)]));
             if (ReqVersion<>'') and (ReqFPCMake.PackageVersion<ReqVersion) then
              raise Exception.Create(Format(s_wrong_package_version,[ReqVersion,ReqFPCMake.PackageVersion]));
             { First load the requirements of this package }
             LoadRequires(t,ReqFPCMake);
             { Get a copy of the package section }
             CopySection(ReqFPCMake.PackageSec,ReqName+'_package');
             { Get a copy of the export section }
             CopySection(ReqFPCMake.ExportSec,ReqName);
             { Get a copy of the require section }
             CopySection(TFPCMakeSection(ReqFPCMake['require']),ReqName+'_require');
             { Free }
             ReqFPCMake.Free;
             Delete(VerboseIdent,1,2);
             TryFile:=true;
           end;
        end;

      var
        s : string;
      begin
        { Force the current target }
        SetVariable('TARGET',TargetStr[t],false);
        { Check for Makefile.fpc }
        s:=SubstVariables('$(addsuffix /'+ReqName+'/Makefile.fpc,$(FPCDIR)) $(addsuffix /'+ReqName+'/Makefile.fpc,$(PACKAGESDIR)) $(addsuffix /'+ReqName+'/Makefile.fpc,$(REQUIRE_PACKAGESDIR))');
        Verbose(FPCMakeDebug,'Looking for Makefile.fpc: "'+s+'"');
        s:=SubstVariables('$(firstword $(wildcard '+s+'))');
        if TryFile(s) then
         exit;
        { Check for Package.fpc }
        s:=SubstVariables('$(addsuffix /'+ReqName+'/Package.fpc,$(FPCDIR)) $(addsuffix /'+ReqName+'/Package.fpc,$(UNITSDIR)) $(addsuffix /'+ReqName+'/Package.fpc,$(REQUIRE_UNITSDIR))');
        Verbose(FPCMakeDebug,'Looking for Package.fpc: "'+s+'"');
        s:=SubstVariables('$(firstword $(wildcard '+s+'))');
        if TryFile(s) then
         exit;
        Raise Exception.Create(Format(s_package_not_found,[TargetStr[t],Reqname]));
      end;


    procedure TFPCMake.LoadRequiredDir(t:TTarget;const MainPack,currdir,subdir:string);
        var
          ReqFPCMake : TFPCMake;
          s : string;
        begin
          VerboseIdent:=VerboseIdent+'  ';
          s:=currdir+subdir;
          Verbose(FPCMakeDebug,'Subdir: '+s+'/Makefile.fpc');
          if not FileExists(s+'/Makefile.fpc') then
           begin
             { give better error what is wrong }
             if not PathExists(s) then
              Raise Exception.Create(Format(s_directory_not_found,[s]))
             else
              Raise Exception.Create(Format(s_makefilefpc_not_found,[s]));
           end;
          { Process Makefile.fpc }
          ReqFPCMake:=TFPCMake.Create(currdir+subdir+'/Makefile.fpc');
          ReqFPCMake.LoadSections;
          ReqFPCMake.LoadPackageSection;
          { Are we a subpackage? }
          if (ReqFPCMake.GetVariable('package_name',false)<>MainPack) then
           begin
             ReqFPCMake.Free;
             Delete(VerboseIdent,1,2);
             exit;
           end;
          { Load the requirements of this package }
          LoadRequires(t,ReqFPCMake);
          { Add the current requirements to our parents requirements }
          s:=Trim(ReqFPCMake.GetVariable('require_packages',true)+' '+ReqFPCMake.GetVariable('require_packages'+targetsuffix[t],true));
          SetVariable('require_packages'+targetsuffix[t],s,true);
          if ReqFPCMake.GetVariable('require_libc',false)<>'' then
           SetVariable('require_libc','y',false);
          { Free }
          ReqFPCMake.Free;
          Delete(VerboseIdent,1,2);
        end;


    procedure TFPCMake.LoadRequires(t:Ttarget;FromFPCMake:TFPCMake);
      var
        s,
        ReqDir,
        ReqName,
        ReqVersion : string;
        i,j : integer;
      begin
        { packages }
        s:=Trim(FromFPCMake.GetVariable('require_packages',true)+' '+FromFPCMake.GetVariable('require_packages'+TargetSuffix[t],true));
        Verbose(FPCMakeDebug,'Required packages for '+TargetStr[t]+': '+s);
        repeat
          reqname:=GetToken(s,' ');
          if reqname='' then
           break;
          i:=Pos('(',ReqName);
          if i>0 then
           begin
             j:=Pos(')',ReqName);
             if (i=1) or (j=0) then
              Raise Exception.Create(Format(s_err_require_format,[ReqName]));
             ReqVersion:=Copy(ReqName,i+1,j-i-1);
             ReqName:=Copy(ReqName,1,i-1);
           end
         else
           ReqVersion:='';
          { We only use lowercase names }
          ReqName:=Lowercase(ReqName);
          { Already loaded ? }
         if (RequireList[t].IndexOf(ReqName)=-1) then
           begin
             LoadRequiredPackage(t,ReqName,ReqVersion);
             RequireList[t].Add(ReqName);
           end;
        until false;
        { sub dirs }
        s:=FromFPCMake.GetVariable('target_dirs',true)+' '+FromFPCMake.GetVariable('target_dirs'+TargetSuffix[t],true);
        Verbose(FPCMakeDebug,'Required dirs for '+TargetStr[t]+': '+s);
        repeat
          reqdir:=GetToken(s,' ');
          if reqdir='' then
           break;
          LoadRequiredDir(t,FromFPCMake.FPackageName,ExtractFilePath(FromFPCMake.FFileName),ReqDir)
        until false;
      end;


    procedure TFPCMake.LoadRequireSection;

        function CheckVar(const s:string):boolean;
        var
          t : ttarget;
        begin
          result:=false;
          if GetVariable(s,false)<>'' then
           begin
             result:=true;
             exit;
           end;
          for t:=low(ttarget) to high(ttarget) do
           if t in FIncludeTargets then
            begin
              if GetVariable(s+targetsuffix[t],false)<>'' then
               begin
                 result:=true;
                 exit;
               end;
            end;
        end;

      var
        s : string;
        t : ttarget;
      begin
        { Check FPCMake version }
        s:=GetVariable('require_fpcmake',false);
        if (s>version) then
         raise Exception.Create(Format(s_fpcmake_version_required,[s]));
        { Maybe add an implicit rtl dependency if there is something
          to compile }
        s:=GetVariable('require_packages',false);
        if (GetVariable('require_nortl',false)='') and
           (CheckVar('target_programs') or
            CheckVar('target_units') or
            CheckVar('target_examples')) and
           (Pos('rtl(',s)=0) then
         begin
           s:='rtl '+s;
           SetVariable('require_packages',s,false);
         end;
        { Load recursively all required packages starting with this Makefile.fpc }
        for t:=low(TTarget) to high(TTarget) do
         if t in FIncludeTargets then
          LoadRequires(t,self);
      end;


    function TFPCMake.GetTargetRequires(t:TTarget):TStringList;
      var
        ReqSec  : TFPCMakeSection;
        ReqList : TStringList;

        procedure AddReqSec(t:TTarget;Sec:TFPCMakeSection);
        var
          s,
          ReqName : string;
          RSec : TFPCMakeSection;
          i : integer;
        begin
          s:=Sec['packages']+' '+Sec['packages'+TargetSuffix[t]];
          repeat
            ReqName:=GetToken(s,' ');
            if ReqName='' then
             break;
            i:=Pos('(',ReqName);
            if i>0 then
             ReqName:=Copy(ReqName,1,i-1);
            { We only use lowercase names }
            ReqName:=Lowercase(ReqName);
            { Already loaded ? }
            if (ReqList.IndexOf(ReqName)=-1) then
             begin
               RSec:=TFPCMakeSection(FSections[ReqName+'_require']);
               if assigned(RSec) then
                AddReqSec(t,RSec);
               ReqList.Add(ReqName);
             end;
          until false;
        end;

      begin
        ReqList:=TStringList.Create;
        ReqSec:=TFPCMakeSection(FSections['require']);
        if assigned(ReqSec) then
         AddReqSec(t,ReqSec);
        GetTargetRequires:=ReqList;
      end;


    function TFPCMake.CheckLibcRequire:boolean;
      var
        i : integer;
        RSec : TFPCMakeSection;
        t : ttarget;
      begin
        Result:=false;
        if GetVariable('require_libc',false)<>'' then
         begin
           Result:=true;
           exit;
         end;
        for t:=low(ttarget) to high(ttarget) do
         if t in FIncludeTargets then
          begin
            for i:=0 to RequireList[t].Count-1 do
             begin
               RSec:=TFPCMakeSection(FSections[RequireList[t][i]+'_require']);
               if assigned(RSec) then
                begin
                  if RSec['libc']<>'' then
                   begin
                     Result:=true;
                     exit;
                   end;
                end;
             end;
          end;
      end;


    procedure TFPCMake.AddDefaultVariables;
      var
        hs,s : string;
      begin
        { Already set FPCDIR }
        hs:='';
        s:=GetVariable('FPCDIR',false);
        if s<>'' then
         hs:=SubstVariables('$(wildcard $(addprefix '+s+'/,rtl units))');
        { Load from environment }
        if hs='' then
         begin
           s:=GetEnv('FPCDIR');
           if s<>'' then
            hs:=SubstVariables('$(wildcard $(addprefix '+s+'/,rtl units))');
         end;
        { default_fpcdir }
        if hs='' then
         begin
           s:=GetVariable('default_fpcdir',true);
           { add the current subdir to relative paths }
           if s<>'' then
            begin
{$ifdef UNIX}
              if (s[1]<>'/') then
{$else}
              if (length(s)>2) and (s[2]<>':') then
{$endif}
               s:=ExtractFilePath(FFileName)+s;
              hs:=SubstVariables('$(wildcard $(addprefix '+s+'/,rtl units))');
            end
         end;
        { OS defaults }
        if hs='' then
         begin
{$ifdef UNIX}
{$ifndef beos}
           if FileExists('/usr/local/bin/ppc386') then
            begin
              s:=ExtractFilePath(ReadLink('/usr/local/bin/ppc386'));
              if s<>'' then
               begin
                 if s[length(s)]='/' then
                  delete(s,length(s),1);
                 hs:=SubstVariables('$(wildcard $(addprefix '+s+'/,rtl units))');
               end;
            end;
           if hs='' then
            begin
              if FileExists('/usr/bin/ppc386') then
               begin
                 s:=ExtractFilePath(ReadLink('/usr/bin/ppc386'));
                 if s<>'' then
                  begin
                    if s[length(s)]='/' then
                     delete(s,length(s),1);
                    hs:=SubstVariables('$(wildcard $(addprefix '+s+'/,rtl units))');
                  end;
               end;
            end;
{$endif}
{$else UNIX}
           hs:=ExtractFilePath(FSearch('ppc386.exe',getenv('PATH')));
           if hs<>'' then
            begin
              s:=hs+'/..';
              hs:=SubstVariables('$(wildcard $(addprefix '+s+'/,rtl units))');
              if hs='' then
               begin
                 s:=s+'/..';
                 hs:=SubstVariables('$(wildcard $(addprefix '+s+'/,rtl units))');
               end;
            end;
           if hs='' then
            s:='c:/pp';
{$endif UNIX}
         end;
        SetVariable('FPCDIR',s,false);
        { PACKAGESDIR }
        if GetVariable('PACKAGESDIR',false)='' then
         SetVariable('PACKAGESDIR','$(FPCDIR)/packages',false);
        { UNITSDIR }
        if GetVariable('UNITSDIR',false)='' then
         SetVariable('UNITSDIR','$(FPCDIR)/units/$(TARGET)',false);

        Verbose(FPCMakeDebug,s_globals);
        Variables.Foreach(@PrintDic);
      end;


    function TFPCMake.SubstVariables(const s:string):string;

      function Expect(var s:string;c:char):boolean;
      begin
        if (s<>'') and (s[1]=c) then
         begin
           Delete(s,1,1);
           Result:=true;
         end
        else
         begin
           Verbose(FPCMakeError,'Error "'+c+'" expected');
           Result:=false;
         end;
      end;

      function GetVar(var s:string;untilc:char):string;
      var
        i,j,k : integer;
        first : boolean;
        func,
        tok,s1,s2,s3 : string;
        Sec   : TFPCMakeSection;
      begin
        Result:='';
        repeat
          j:=Pos(untilc,s);
          if j=0 then
           j:=Length(s)+1;
          i:=Pos('$(',s);
          if (j<i) or (i=0) then
           break;
          Result:=Result+Copy(s,1,i-1);
          Delete(s,1,i+1);
          { Maybe Function ? }
          j:=Pos(')',s);
          if j=0 then
           j:=Length(s)+1;
          i:=Pos(' ',s);
          if i=0 then
           i:=Length(s)+1;
          if i<j then
           begin
             { It's a function }
             Func:=Copy(s,1,i-1);
//writeln('func: ',func);
             { $(wildcard <list>) }
             if Func='wildcard' then
              begin
                Delete(s,1,9);
                s1:=GetVar(s,')');
                Expect(s,')');
                first:=true;
                repeat
                  tok:=GetToken(s1,' ');
                  if tok='' then
                   break;
                  if PathOrFileExists(tok) then
                   begin
                     if not first then
                      Result:=Result+' '
                     else
                      first:=false;
                     Result:=Result+tok;
                   end;
                until false;
              end
             { $(addprefix <suffix>,<list>) }
             else if Func='addprefix' then
              begin
                Delete(s,1,10);
                s1:=GetVar(s,',');
                if Expect(s,',') then
                 begin
                   s2:=GetVar(s,')');
                   Expect(s,')');
                 end;
                first:=true;
                repeat
                  tok:=GetToken(s2,' ');
                  if tok='' then
                   break;
                  if not first then
                   Result:=Result+' '
                  else
                   first:=false;
                  Result:=Result+s1+tok;
                until false;
              end
             { $(addsuffix <suffix>,<list>) }
             else if Func='addsuffix' then
              begin
                Delete(s,1,10);
                s1:=GetVar(s,',');
                if Expect(s,',') then
                 begin
                   s2:=GetVar(s,')');
                   Expect(s,')');
                 end;
                first:=true;
                repeat
                  tok:=GetToken(s2,' ');
                  if tok='' then
                   break;
                  if not first then
                   Result:=Result+' '
                  else
                   first:=false;
                  Result:=Result+tok+s1;
                until false;
              end
             { $(firstword <list>) }
             else if Func='firstword' then
              begin
                Delete(s,1,10);
                s1:=GetVar(s,')');
                Expect(s,')');
                Result:=GetToken(s1,' ');
              end
           end
          else
           begin
             s2:=Copy(s,1,j-1);
             Delete(s,1,j);
             k:=pos('_',s2);
             if k>0 then
              begin
                s3:=LowerCase(Copy(s2,k+1,Length(s2)-k));
                s2:=LowerCase(Copy(s2,1,k-1));
                Sec:=TFPCMakeSection(Section[s2]);
                if assigned(Sec) then
                 s2:=Sec[s3]
                else
                 s2:='';
              end
             else
              s2:=Variables[s2];
             Insert(s2,s,1);
           end;
        until false;
        Result:=Result+Copy(s,1,j-1);
        Delete(s,1,j-1);
      end;

      var
        s1 : string;
      begin
//writeln('S: ',s);
        s1:=s;
        Result:=GetVar(s1,#0);
//writeln('R: ',result);
      end;


    function TFPCMake.GetVariable(const inivar:string;dosubst:boolean):string;
      var
        Sec : TFPCMakeSection;
        Dic : TKeyValue;
        i   : integer;
      begin
        Result:='';
        i:=Pos('_',inivar);
        if i<>0 then
         begin
           Sec:=TFPCMakeSection(FSections[Copy(Inivar,1,i-1)]);
           if assigned(Sec) then
            begin
              if not assigned(Sec.Dictionary) then
               Sec.ParseIni;
              Dic:=TKeyValue(Sec.Dictionary);
              Result:=Dic[Copy(IniVar,i+1,Length(IniVar)-i)];
            end
           else
            exit;
         end
        else
         Result:=Variables[IniVar];
        { Substition asked ? }
        if dosubst then
         Result:=SubstVariables(Result);
      end;


    function TFPCMake.SetVariable(const inivar,value:string;add:boolean):string;
      var
        Sec : TFPCMakeSection;
        P   : TKeyValueItem;
        i   : integer;
        key : string;
      begin
        Result:='';
        i:=Pos('_',inivar);
        if i<>0 then
         begin
           Sec:=TFPCMakeSection(FSections[Copy(Inivar,1,i-1)]);
           if Sec=nil then
            Sec:=TFPCMakeSection(FSections.Insert(TFPCMakeSection.CreateKeyValue(Copy(Inivar,1,i-1))));
           key:=Copy(IniVar,i+1,Length(IniVar)-i);
           p:=TKeyValueItem(Sec.Dictionary.Search(Key));
           if assigned(p) then
            begin
              if Add then
               AddToken(p.FValue,Value,' ')
              else
               p.Value:=Value;
            end
           else
            TKeyValue(Sec.Dictionary).Add(key,value);
         end
        else
         Variables[IniVar]:=value;
      end;


    procedure TFPCMake.ParseSec(p:TDictionaryItem);
      begin
        TFPCMakeSection(p).ParseIni;
      end;


    procedure TFPCMake.PrintSec(p:TDictionaryItem);
      var
        i : integer;
      begin
        with TFPCMakeSection(p) do
         begin
           Verbose(FPCMakeDebug,'['+Name+']');
           if assigned(FList) then
            begin
              Verbose(FPCMakeDebug,'  List:');
              for i:=0 to FList.Count-1 do
               Verbose(FPCMakeDebug,'   "'+FList[i]+'"');
              if assigned(FDictionary) then
               Verbose(FPCMakeDebug,'');
            end;
           if assigned(FDictionary) then
            begin
              Verbose(FPCMakeDebug,'  Dictionary:');
              FDictionary.Foreach(@PrintDic);
            end;
         end;
      end;


    procedure TFPCMake.PrintDic(p:TDictionaryItem);
      begin
        with TKeyValueItem(p) do
         begin
           Verbose(FPCMakeDebug,'   '+name+' = "'+value+'"');
         end;
      end;


    procedure TFPCMake.Print;
      begin
        { global variables }
        Verbose(FPCMakeDebug,'[global variables]');
        Verbose(FPCMakeDebug,'  Dictionary:');
        Variables.Foreach(@PrintDic);
        { sections }
        FSections.Foreach(@PrintSec);
      end;


    function TFPCMake.GetSec(const AName:string):TDictionaryItem;
      begin
        GetSec:=FSections.Search(AName);
      end;

end.
{
  $Log$
  Revision 1.14  2001-09-29 19:47:50  carl
  * make it work for BeOS

  Revision 1.13  2001/08/22 20:45:19  peter
    * firstword added
    * pathexist fix to include sysfile

  Revision 1.12  2001/08/10 10:28:55  pierre
   + netbsd target added

  Revision 1.11  2001/08/02 20:50:29  peter
    * -T<target> support
    * better error reporting for not found dirs
    * some cleanups and nicer strings

  Revision 1.10  2001/07/31 22:02:32  peter
    * install Package.fpc

  Revision 1.9  2001/07/24 09:06:40  pierre
   + added amiga and atari targets

  Revision 1.8  2001/07/13 21:01:59  peter
    * cygdrive support
    * fixed cygwin detection
    * fixed some duplicate and extraeous spaces

  Revision 1.7  2001/06/04 21:42:57  peter
    * Arguments added
    * Start of Package.fpc creation

  Revision 1.6  2001/06/02 19:20:24  peter
    * beos target added

  Revision 1.5  2001/02/22 21:11:24  peter
    * fpcdir detection added
    * fixed loading of variables in fpcmake itself

  Revision 1.4  2001/02/05 20:44:56  peter
    * variable substition like GNU Make. wildcard,addprefix,addsuffix
      already implemented

  Revision 1.3  2001/02/01 22:00:10  peter
    * default.fpcdir is back
    * subdir requirement checking works, but not very optimal yet as
      it can load the same Makefile.fpc multiple times

  Revision 1.2  2001/01/29 21:49:10  peter
    * lot of updates

  Revision 1.1  2001/01/24 21:59:36  peter
    * first commit of new fpcmake

}
