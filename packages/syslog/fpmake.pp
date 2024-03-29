{$ifndef ALLPACKAGES}
{$mode objfpc}{$H+}
program fpmake;

uses {$ifdef unix}cthreads,{$endif} fpmkunit;

Var
  P : TPackage;
  T : TTarget;
begin
  With Installer do
    begin
{$endif ALLPACKAGES}

    P:=AddPackage('syslog');
    P.ShortName := 'sysl';
{$ifdef ALLPACKAGES}
    P.Directory:=ADirectory;
{$endif ALLPACKAGES}
    P.Version:='3.3.1';
    P.OSes := [beos,haiku,freebsd,darwin,iphonesim,ios,solaris,netbsd,openbsd,linux,aix,dragonfly];
    P.SourcePath.Add('src');

    T:=P.Targets.AddUnit('systemlog.pp');

    P.ExamplePath.Add('examples');
    P.Targets.AddExampleProgram('testlog.pp');
    P.Sources.AddExampleFiles('examples/*',P.Directory,false,'.');


    P.NamespaceMap:='namespaces.lst';

{$ifndef ALLPACKAGES}
    Run;
    end;
end.
{$endif ALLPACKAGES}
