{
    $Id$
    This file is part of the Free Component Library (FCL)
    Copyright (c) 1998 by Michael Van Canneyt and Florian Klaempfl

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}

{ exceptions aren't implemented yet in the compiler }
{$define NoExceptions}

{ determine the type of the resource/form file }
{$define Win16Res}
unit Classes;

interface

uses
  objpas;

{$i classesh.inc}

implementation

{ OS - independent class implementations are in /inc directory. }

{$i classes.inc}

end.
{
  $Log$
  Revision 1.2  1998-05-04 14:31:51  michael
  + Split classes file.

  Revision 1.1  1998/05/04 12:16:01  florian
    + Initial revisions after making a new directory structure

}