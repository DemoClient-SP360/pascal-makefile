{$ifndef ALLPACKAGES}
{$mode objfpc}{$H+}
program fpmake;

uses fpmkunit;

Var
  P : TPackage;
  T : TTarget;
begin
  With Installer do
    begin
{$endif ALLPACKAGES}

    P:=AddPackage('libtar');
{$ifdef ALLPACKAGES}
    P.Directory:='libtar';
{$endif ALLPACKAGES}
    P.Version:='2.7.1';

    P.Author := 'Stefan Heymann';
    P.License := 'LGPL with modification, ';
    P.HomepageURL := 'http://www.destructor.de/';
    P.Description := 'Library for handling tar-files.';

    P.OSes:=AllOSes-[embedded];

    P.SourcePath.Add('src');
    T:=P.Targets.AddUnit('libtar.pp');

{$ifndef ALLPACKAGES}
    Run;
    end;
end.
{$endif ALLPACKAGES}
