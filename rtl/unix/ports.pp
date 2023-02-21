{
    This file is part of the Free Pascal run time library.
    Copyright (c) 1999-2000 by Michael Van Canneyt
    member of the Free Pascal development team

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}

{$IFNDEF FPC_DOTTEDUNITS}
Unit ports;
{$ENDIF FPC_DOTTEDUNITS}

{$inline on}

Interface

{$ifndef cpullvm}
{$I portsh.inc}
{$endif}

implementation

{$ifndef cpullvm}
{$I ports.inc}
{$endif}

end.
