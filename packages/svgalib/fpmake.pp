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

    P:=AddPackage('svgalib');
    P.ShortName := 'svga';
{$ifdef ALLPACKAGES}
    P.Directory:=ADirectory;
{$endif ALLPACKAGES}
    P.Version:='3.3.1';
    P.OSes := [beos,haiku,linux,freebsd,solaris,netbsd,openbsd,dragonfly];
    P.SourcePath.Add('src');

    T:=P.Targets.AddUnit('svgalib.pp');
    T:=P.Targets.AddUnit('vgamouse.pp');

    P.Sources.AddSrc('README.txt');
 
    P.ExamplePath.Add('examples');
    P.Targets.AddExampleProgram('testvga.pp');
    P.Targets.AddExampleProgram('vgatest.pp');
    P.Sources.AddExampleFiles('examples/*',P.Directory,false,'.');


    P.NamespaceMap:='namespaces.lst';

{$ifndef ALLPACKAGES}
    Run;
    end;
end.
{$endif ALLPACKAGES}
