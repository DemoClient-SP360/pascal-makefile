{
    $Id$
    This file is part of the Free Pascal run time library.
    Copyright (c) 1993-98 by Gernot Tenchio

    Mandelbrot Example using the Graph unit

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}
program mandel;

{
  Mandelbrot example using the graph unit.

  Note: For linux you need to run this program as root !!
}

uses
{$ifdef go32v2}
{$ifdef profile}
{ profile needs only to be inserted in _USES
  for version < 0.99.9 PM }
  profile, 
{$endif profile}
  heaptrc,
  dpmiexcp,
{$endif go32v2}
  Graph;

{$ifdef FPC}
{$ifdef go32v2}
{$ifndef ver0_99_8}
{$define has_colors_equal}
{$endif ver0_99_8}
{$endif go32v2}
{$endif FPC}

const
  shift:byte=12;

var
  SearchPoint,ActualPoint,NextPoint       : PointType;
  LastColor                              : longint;
  Gd,Gm,
  Max_Color,Max_X_Width,
  Max_Y_Width,Y_Width                    : integer;
  Y1,Y2,X1,X2,Dy,Dx                      : Real;
  Zm                                     : Integer;
  Flag                                   : boolean;
  LineY                                  : array [0..600] OF BYTE;
  LineX                                  : array [0..100,0..600] OF INTEGER;
const
    SX : array [0..7] OF SHORTINT=(-1, 0, 1, 1, 1, 0,-1,-1);
    SY : array [0..7] OF SHORTINT=(-1,-1,-1, 0, 1, 1, 1, 0);
type
    arrayType = array[1..50] of integer;

{------------------------------------------------------------------------------}
{$ifndef has_colors_equal}
  function ColorsEqual(c1, c2 : longint) : boolean;
    begin
       ColorsEqual:=((GetMaxColor=$FF) and ((c1 and $FF)=(c2 and $FF))) or
         ((GetMaxColor=$7FFF) and ((c1 and $F8F8F8)=(c2 and $F8F8F8))) or
         ((GetMaxColor=$FFFF) and ((c1 and $F8FCF8)=(c2 and $F8FCF8))) or
         ((GetMaxColor>$10000) and ((c1 and $FFFFFF)=(c2 and $FFFFFF)));
    end;
    
{$endif not has_colors_equal}

{------------------------------------------------------------------------------}
function CalcMandel(Point:PointType; z:integer) : Longint ;
var
  x,y,xq,yq,Cx,Cy : real ;
begin
  Cy:=y2 + dy*Point.y ;
  Cx:=x2 + dx*Point.x ;
  X:=-Cx ; Y:=-Cy ;
  repeat
    xq:=x * x;
    yq:=y * y  ;
    y :=x * y;
    y :=y + y - cy;
    x :=xq - yq - cx ;
    z :=z -1;
  until (Z=0) or (Xq + Yq > 4 );
  if Z=0 Then
    CalcMandel:=(blue and $FFFFFF)
  else if getMaxColor>255 then
    CalcMandel:=(stdcolors[(z mod 254) + 1] and $FFFFFF)
  else
    CalcMandel:=(z mod Max_Color) + 1 ;
end;

{-----------------------------------------------------------------------------}
procedure Partition(var A : arrayType; First, Last : Byte);
var
  Right,Left : byte ;
  V,Temp     : integer;
begin
    V := A[(First + Last) SHR 1];
    Right := First;
    Left := Last;
    repeat
      while (A[Right] < V) do
        inc(Right);
      while (A[Left] > V) do
        Dec(Left);
      if (Right <= Left) then
        begin
          Temp:=A[Left];
          A[Left]:=A[Right];
          A[Right]:=Temp;
          Right:=Right+1;
          Left:=Left-1;
        end;
    until Right > Left;
    if (First < Left) then
      Partition(A, First, Left);
    if (Right < Last) then
      Partition(A, Right, Last)
end;

{-----------------------------------------------------------------------------}
function BlackScan(var NextPoint:PointType) : boolean;
begin
  BlackScan:=true;
  repeat
    if NextPoint.X=Max_X_Width then
      begin
        if NextPoint.Y < Y_Width then
          begin
            NextPoint.X:=0 ;
            NextPoint.Y:=NextPoint.Y+1;
          end
        else
          begin
            BlackScan:=false;
            exit;
          end ; { IF }
      end ; { IF }
    NextPoint.X:=NextPoint.X+1;
  until GetPixel(NextPoint.X,NextPoint.Y)=0;
end ;

{------------------------------------------------------------------------------}
procedure Fill(Ymin,Ymax,LastColor:integer);
var
 P1,P3,P4,P    : integer ;
 Len,P2        : byte ;
 Darray        : arraytype;
begin
  SetColor(LastColor);
  for P1:=Ymin+1 to Ymax-1 do
   begin
     Len:=LineY[P1] ;
     if Len >= 2 then
      begin
        for P2:=1 to Len do
          Darray[P2]:=LineX[P2,P1] ;
        if Len > 2 then
          Partition(Darray,1,len);
        P2:=1;
        repeat
          P3:= Darray[P2] ; P4:= Darray[P2 + 1];
          if P3 <> P4 then
           begin
             line ( P3 , P1 , P4 , P1) ;
             if Flag then
              begin
                P:=Max_Y_Width-P1;
                line ( P3 , P , P4 , P ) ;
              end;
           end; { IF }
          P2:=P2+2;
        until P2 >= Len ;
      end; { IF }
   end; { FOR }
end;

{-----------------------------------------------------------------------------}
Function NewPosition(Last:Byte):Byte;
begin
  newposition:=(((last+1) and 254)+6) and 7;
end;

{-----------------------------------------------------------------------------}
procedure CalcBounds;
var
  lastOperation,KK,
  Position                     : Byte ;
  foundcolor                   : longint;
  Start,Found,NotFound         : boolean ;
  MerkY,Ymax                   : Integer ;
label
  L;
begin
  repeat
    FillChar(LineY,SizeOf(LineY),0) ;
    ActualPoint:=NextPoint;
    LastColor:=CalcMandel(NextPoint,Zm) ;
    putpixel (ActualPoint.X,ActualPoint.Y,LastColor);
    if Flag then
      putpixel (ActualPoint.X,Max_Y_Width-ActualPoint.Y,LastColor) ;
    Ymax:=NextPoint.Y ;
    MerkY:=NextPoint.Y ;
    NotFound:=false ;
    Start:=false ;
    LastOperation:=4 ;
    repeat
      Found:=false ;
      KK:=0 ;
      Position:=NewPosition(LastOperation);
      repeat
        LastOperation:=(Position+KK) and 7 ;
        SearchPoint.X:=ActualPoint.X+Sx[LastOperation];
        SearchPoint.Y:=ActualPoint.Y+Sy[LastOperation];
        if ((SearchPoint.X < 0) or
            (SearchPoint.X > Max_X_Width) or
            (SearchPoint.Y < NextPoint.Y) or
            (SearchPoint.Y > Y_Width)) then
          goto L;
        if (SearchPoint.X=NextPoint.X) and (SearchPoint.Y=NextPoint.Y) then
          begin
            Start:=true ;
            Found:=true ;
          end
        else
          begin
            FoundColor:=GetPixel(SearchPoint.X,SearchPoint.Y) ;
            if FoundColor = 0 then
              begin
                FoundColor:= CalcMandel (SearchPoint,Zm) ;
                Putpixel (SearchPoint.X,SearchPoint.Y,FoundColor) ;
                if Flag then
                  PutPixel (SearchPoint.X,Max_Y_Width-SearchPoint.Y,FoundColor) ;
              end ;
            if ColorsEqual(FoundColor,LastColor) then
              begin
                if ActualPoint.Y <> SearchPoint.Y then
                  begin
                    if SearchPoint.Y = MerkY then
                      LineY[ActualPoint.Y]:=LineY[ActualPoint.Y]-1;
                    MerkY:= ActualPoint.Y ;
                    LineY[SearchPoint.Y]:=LineY[SearchPoint.Y]+1;
                  end ;
                LineX[LineY[SearchPoint.Y],SearchPoint.Y]:=SearchPoint.X ;
                if SearchPoint.Y > Ymax then Ymax:= SearchPoint.Y ;
                  Found:=true ;
                ActualPoint:=SearchPoint ;
              end;
L:
            KK:=KK+1;
            if KK > 8 then
              begin
                Start:=true ;
                NotFound:=true ;
              end;
          end;
      until Found or (KK > 8);
    until Start ;
    if not NotFound then
      Fill(NextPoint.Y,Ymax,LastColor) ;
  until not BlackScan(NextPoint);
end ;


{------------------------------------------------------------------------------
                              MAINROUTINE
------------------------------------------------------------------------------}
{$ifndef Linux}
  var
     error : word;
     st : string;
{$endif not Linux}
     
begin
  {$ifdef go32v2}
  {$ifdef debug}
  {$warning If the compilation fails, you need to recompile}
  {$warning the graph unit with -dDEBUG option }
  Write('Use linear ? ');
  readln(st);
  if st='y' then UseLinear:=true;
  if UseLinear then
    begin
       Write('Switch physical address (default true) ? ');
       readln(st);
       if st='y' then switch_physical_address:=true
       else if st='n' then switch_physical_address:=false;
       Write('Split physical address (default false) ? ');
       readln(st);
       if st='y' then split_physical_address:=true
       else if st='n' then split_physical_address:=false;
    end;
  {$endif debug}
  {$endif go32v2}
{$ifdef Linux}
  gm:=0;
  gd:=0;
{$else}
  if paramcount>0 then
    begin
       val(paramstr(1),gm,error);
       if error<>0 then
         gm:=$103;
    end
  else
    gm:=$103;
  gd:=$ff;
  {$ifDEF TURBO}
    gd:=detect;
  {$endif}
{$endif}
  InitGraph(gd,gm,'D:\bp\bgi');
  if GraphResult <> grOk then Halt(1);
  Max_X_Width:=GetMaxX;
  Max_y_Width:=GetMaxY;
  Max_Color:=GetMaxColor-1;
  ClearViewPort;

  x1:=-0.9;
  x2:= 2.2;
  y1:= 1.25;
  y2:=-1.25;
  zm:=90;
  dx:=(x1 - x2) / Max_X_Width ;
  dy:=(y1 - y2) / Max_Y_Width ;
  if abs(y1) = abs(y2) then
   begin
{$ifndef NOFLAG}
     flag:=true;
{$endif NOFLAG}
     Y_Width:=Max_Y_Width shr 1
   end
  else
   begin
     flag:=false;
     Y_Width:=Max_Y_Width;
   end;
  NextPoint.X:=0;
  NextPoint.Y:=0;
  LastColor:=CalcMandel(SearchPoint,zm);
  CalcBounds ;
{$ifndef fpc_profile}
  readln;
{$endif fpc_profile}
  CloseGraph;
end.
{
  $Log$
  Revision 1.2  1998-11-18 11:45:06  pierre
   * LinearFrameBuffer test added

  Revision 1.1  1998/11/17 18:17:53  pierre
    + mandel changed for new graph unit (probably not very linux compatible !)

  Revision 1.3  1998/09/11 10:55:25  peter
    + header+log

}
