{$mode objfpc}
{$h+}
{
    $Id$
    This file is part of the Free Pascal run time library.
    Copyright (c) 1999-2000 by the Free Pascal development team

    Delphi/Kylix compatibility unit: String handling routines. 
    
    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}
unit strutils;

interface

uses
  SysUtils{, Types};

{ ---------------------------------------------------------------------
    Case sensitive search/replace
  ---------------------------------------------------------------------}

Function AnsiResemblesText(const AText, AOther: string): Boolean;
Function AnsiContainsText(const AText, ASubText: string): Boolean;
Function AnsiStartsText(const ASubText, AText: string): Boolean;
Function AnsiEndsText(const ASubText, AText: string): Boolean;
Function AnsiReplaceText(const AText, AFromText, AToText: string): string;
Function AnsiMatchText(const AText: string; const AValues: array of string): Boolean;
Function AnsiIndexText(const AText: string; const AValues: array of string): Integer;

{ ---------------------------------------------------------------------
    Case insensitive search/replace
  ---------------------------------------------------------------------}

Function AnsiContainsStr(const AText, ASubText: string): Boolean;
Function AnsiStartsStr(const ASubText, AText: string): Boolean;
Function AnsiEndsStr(const ASubText, AText: string): Boolean;
Function AnsiReplaceStr(const AText, AFromText, AToText: string): string;
Function AnsiMatchStr(const AText: string; const AValues: array of string): Boolean;
Function AnsiIndexStr(const AText: string; const AValues: array of string): Integer;

{ ---------------------------------------------------------------------
    Playthingies
  ---------------------------------------------------------------------}

Function DupeString(const AText: string; ACount: Integer): string;
Function ReverseString(const AText: string): string;
Function AnsiReverseString(const AText: AnsiString): AnsiString;
Function StuffString(const AText: string; AStart, ALength: Cardinal;  const ASubText: string): string;
Function RandomFrom(const AValues: array of string): string; overload;
Function IfThen(AValue: Boolean; const ATrue: string; AFalse: string): string; 
Function IfThen(AValue: Boolean; const ATrue: string): string; // ; AFalse: string = ''

{ ---------------------------------------------------------------------
    VB emulations.
  ---------------------------------------------------------------------}

Function LeftStr(const AText: AnsiString; const ACount: Integer): AnsiString; 
Function RightStr(const AText: AnsiString; const ACount: Integer): AnsiString; 
Function MidStr(const AText: AnsiString; const AStart, ACount: Integer): AnsiString; 
Function RightBStr(const AText: AnsiString; const AByteCount: Integer): AnsiString;
Function MidBStr(const AText: AnsiString; const AByteStart, AByteCount: Integer): AnsiString;
Function AnsiLeftStr(const AText: AnsiString; const ACount: Integer): AnsiString;
Function AnsiRightStr(const AText: AnsiString; const ACount: Integer): AnsiString;
Function AnsiMidStr(const AText: AnsiString; const AStart, ACount: Integer): AnsiString;
{$ifndef ver1_0}
Function LeftBStr(const AText: AnsiString; const AByteCount: Integer): AnsiString;
Function LeftStr(const AText: WideString; const ACount: Integer): WideString; 
Function RightStr(const AText: WideString; const ACount: Integer): WideString; 
Function MidStr(const AText: WideString; const AStart, ACount: Integer): WideString; 
{$endif}

{ ---------------------------------------------------------------------
    Extended search and replace
  ---------------------------------------------------------------------}
  
const
  { Default word delimiters are any character except the core alphanumerics. }
  WordDelimiters: set of Char = [#0..#255] - ['a'..'z','A'..'Z','1'..'9','0'];

type
  TStringSeachOption = (soDown, soMatchCase, soWholeWord);
  TStringSearchOptions = set of TStringSeachOption;

Function SearchBuf(Buf: PChar; BufLen: Integer; SelStart, SelLength: Integer; SearchString: String; Options: TStringSearchOptions): PChar;
Function SearchBuf(Buf: PChar; BufLen: Integer; SelStart, SelLength: Integer; SearchString: String): PChar; // ; Options: TStringSearchOptions = [soDown]
Function PosEx(const SubStr, S: string; Offset: Cardinal): Integer;
Function PosEx(const SubStr, S: string): Integer; // Offset: Cardinal = 1

{ ---------------------------------------------------------------------
    Soundex Functions.
  ---------------------------------------------------------------------}

type
  TSoundexLength = 1..MaxInt;

Function Soundex(const AText: string; ALength: TSoundexLength): string;
Function Soundex(const AText: string): string; // ; ALength: TSoundexLength = 4

type
  TSoundexIntLength = 1..8;

Function SoundexInt(const AText: string; ALength: TSoundexIntLength): Integer;
Function SoundexInt(const AText: string): Integer; //; ALength: TSoundexIntLength = 4
Function DecodeSoundexInt(AValue: Integer): string;
Function SoundexWord(const AText: string): Word;
Function DecodeSoundexWord(AValue: Word): string;
Function SoundexSimilar(const AText, AOther: string; ALength: TSoundexLength): Boolean;
Function SoundexSimilar(const AText, AOther: string): Boolean; //; ALength: TSoundexLength = 4
Function SoundexCompare(const AText, AOther: string; ALength: TSoundexLength): Integer;
Function SoundexCompare(const AText, AOther: string): Integer; //; ALength: TSoundexLength = 4
Function SoundexProc(const AText, AOther: string): Boolean;

type
  TCompareTextProc = Function(const AText, AOther: string): Boolean;

Const
  AnsiResemblesProc: TCompareTextProc = @SoundexProc;

implementation

{ ---------------------------------------------------------------------
    Auxiliary functions
  ---------------------------------------------------------------------}

Procedure NotYetImplemented (FN : String);

begin
  Raise Exception.CreateFmt('Function "%s" (strutils) is not yet implemented',[FN]);
end;  

{ ---------------------------------------------------------------------
    Case sensitive search/replace
  ---------------------------------------------------------------------}

Function AnsiResemblesText(const AText, AOther: string): Boolean;

begin
  NotYetImplemented(' AnsiResemblesText');
end;



Function AnsiContainsText(const AText, ASubText: string): Boolean;

begin
  NotYetImplemented(' AnsiContainsText');
end;



Function AnsiStartsText(const ASubText, AText: string): Boolean;

begin
  NotYetImplemented(' AnsiStartsText');
end;



Function AnsiEndsText(const ASubText, AText: string): Boolean;

begin
  NotYetImplemented(' AnsiEndsText');
end;



Function AnsiReplaceText(const AText, AFromText, AToText: string): string;

begin
  NotYetImplemented(' AnsiReplaceText');
end;



Function AnsiMatchText(const AText: string; const AValues: array of string): Boolean;

begin
  NotYetImplemented(' AnsiMatchText');
end;



Function AnsiIndexText(const AText: string; const AValues: array of string): Integer;

begin
  NotYetImplemented(' AnsiIndexText');
end;




{ ---------------------------------------------------------------------
    Case insensitive search/replace
  ---------------------------------------------------------------------}

Function AnsiContainsStr(const AText, ASubText: string): Boolean;

begin
  NotYetImplemented(' AnsiContainsStr');
end;



Function AnsiStartsStr(const ASubText, AText: string): Boolean;

begin
  NotYetImplemented(' AnsiStartsStr');
end;



Function AnsiEndsStr(const ASubText, AText: string): Boolean;

begin
  NotYetImplemented(' AnsiEndsStr');
end;



Function AnsiReplaceStr(const AText, AFromText, AToText: string): string;

begin
  NotYetImplemented(' AnsiReplaceStr');
end;



Function AnsiMatchStr(const AText: string; const AValues: array of string): Boolean;

begin
  NotYetImplemented(' AnsiMatchStr');
end;



Function AnsiIndexStr(const AText: string; const AValues: array of string): Integer;

begin
  NotYetImplemented(' AnsiIndexStr');
end;




{ ---------------------------------------------------------------------
    Playthingies
  ---------------------------------------------------------------------}

Function DupeString(const AText: string; ACount: Integer): string;

begin
  NotYetImplemented(' DupeString');
end;



Function ReverseString(const AText: string): string;

begin
  NotYetImplemented(' ReverseString');
end;



Function AnsiReverseString(const AText: AnsiString): AnsiString;

begin
  NotYetImplemented(' AnsiReverseString');
end;



Function StuffString(const AText: string; AStart, ALength: Cardinal;  const ASubText: string): string;

begin
  NotYetImplemented(' StuffString');
end;



Function RandomFrom(const AValues: array of string): string; overload;

begin
  NotYetImplemented(' RandomFrom');
end;



Function IfThen(AValue: Boolean; const ATrue: string; AFalse: string): string; 

begin
  NotYetImplemented(' IfThen');
end;



Function IfThen(AValue: Boolean; const ATrue: string): string; // ; AFalse: string = ''

begin
  NotYetImplemented(' IfThen');
end;




{ ---------------------------------------------------------------------
    VB emulations.
  ---------------------------------------------------------------------}

Function LeftStr(const AText: AnsiString; const ACount: Integer): AnsiString; 

begin
  NotYetImplemented(' LeftStr');
end;



Function RightStr(const AText: AnsiString; const ACount: Integer): AnsiString; 

begin
  NotYetImplemented(' RightStr');
end;



Function MidStr(const AText: AnsiString; const AStart, ACount: Integer): AnsiString; 

begin
  NotYetImplemented(' MidStr');
end;



Function LeftBStr(const AText: AnsiString; const AByteCount: Integer): AnsiString;

begin
  NotYetImplemented(' LeftBStr');
end;



Function RightBStr(const AText: AnsiString; const AByteCount: Integer): AnsiString;

begin
  NotYetImplemented(' RightBStr');
end;



Function MidBStr(const AText: AnsiString; const AByteStart, AByteCount: Integer): AnsiString;

begin
  NotYetImplemented(' MidBStr');
end;



Function AnsiLeftStr(const AText: AnsiString; const ACount: Integer): AnsiString;

begin
  NotYetImplemented(' AnsiLeftStr');
end;



Function AnsiRightStr(const AText: AnsiString; const ACount: Integer): AnsiString;

begin
  NotYetImplemented(' AnsiRightStr');
end;



Function AnsiMidStr(const AText: AnsiString; const AStart, ACount: Integer): AnsiString;

begin
  NotYetImplemented(' AnsiMidStr');
end;

{$ifndef ver1_0}
Function LeftStr(const AText: WideString; const ACount: Integer): WideString; 

begin
  NotYetImplemented(' LeftStr');
end;



Function RightStr(const AText: WideString; const ACount: Integer): WideString; 

begin
  NotYetImplemented(' RightStr');
end;



Function MidStr(const AText: WideString; const AStart, ACount: Integer): WideString; 

begin
  NotYetImplemented(' MidStr');
end;
{$endif}




{ ---------------------------------------------------------------------
    Extended search and replace
  ---------------------------------------------------------------------}

Function SearchBuf(Buf: PChar; BufLen: Integer; SelStart, SelLength: Integer; SearchString: String; Options: TStringSearchOptions): PChar;

begin
  NotYetImplemented(' SearchBuf');
end;



Function SearchBuf(Buf: PChar; BufLen: Integer; SelStart, SelLength: Integer; SearchString: String): PChar; // ; Options: TStringSearchOptions = [soDown]

begin
  NotYetImplemented(' SearchBuf');
end;



Function PosEx(const SubStr, S: string; Offset: Cardinal): Integer;

begin
  NotYetImplemented(' PosEx');
end;



Function PosEx(const SubStr, S: string): Integer; // Offset: Cardinal = 1

begin
  NotYetImplemented(' PosEx');
end;




{ ---------------------------------------------------------------------
    Soundex Functions.
  ---------------------------------------------------------------------}
Const
SScore : array[1..255] of Char =
     ('0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0', // 1..32
      '0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0', // 33..64
      '0','1','2','3','0','1','2','i','0','2','2','4','5','5','0','1','2','6','2','3','0','1','i','2','i','2', // 64..90
      '0','0','0','0','0','0', // 91..95
      '0','1','2','3','0','1','2','i','0','2','2','4','5','5','0','1','2','6','2','3','0','1','i','2','i','2', // 96..122
      '0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0', // 123..154
      '0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0', // 155..186
      '0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0', // 187..218
      '0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0', // 219..250
      '0','0','0','0','0'); // 251..255 
                    


Function Soundex(const AText: string; ALength: TSoundexLength): string;

Var
  S,PS : Char;
  I,L : integer;
  
begin
  Result:='';
  PS:=#0;
  If Length(AText)>0 then
    begin
    Result:=Upcase(AText[1]);
    I:=2;
    L:=Length(AText);
    While (I<=L) and (Length(Result)<ALength) do
      begin
      S:=SScore[Ord(AText[i])];
      If Not (S in ['0','i',PS]) then
        Result:=Result+S;
      If (S<>'i') then
        PS:=S;
      Inc(I);  
      end;
    end;
  L:=Length(Result);
  If (L<ALength) then  
    Result:=Result+StringOfChar('0',Alength-L);
end;



Function Soundex(const AText: string): string; // ; ALength: TSoundexLength = 4

begin
  Result:=Soundex(AText,4);
end;



Function SoundexInt(const AText: string; ALength: TSoundexIntLength): Integer;

begin
  NotYetImplemented(' SoundexInt');
end;



Function SoundexInt(const AText: string): Integer; //; ALength: TSoundexIntLength = 4

begin
  NotYetImplemented(' SoundexInt');
end;



Function DecodeSoundexInt(AValue: Integer): string;

begin
  NotYetImplemented(' DecodeSoundexInt');
end;



Function SoundexWord(const AText: string): Word;

Var  
  S : String;

begin
  S:=SoundEx(Atext,4);
  Writeln('Soundex result : "',S,'"');
  Result:=Ord(S[1])-Ord('A');
  Result:=Result*26+StrToInt(S[2]);
  Result:=Result*7+StrToInt(S[3]);
  Result:=Result*7+StrToInt(S[4]);
end;



Function DecodeSoundexWord(AValue: Word): string;

begin
  NotYetImplemented(' DecodeSoundexWord');
end;



Function SoundexSimilar(const AText, AOther: string; ALength: TSoundexLength): Boolean;

begin
  NotYetImplemented(' SoundexSimilar');
end;



Function SoundexSimilar(const AText, AOther: string): Boolean; //; ALength: TSoundexLength = 4

begin
  NotYetImplemented(' SoundexSimilar');
end;



Function SoundexCompare(const AText, AOther: string; ALength: TSoundexLength): Integer;

begin
  NotYetImplemented(' SoundexCompare');
end;



Function SoundexCompare(const AText, AOther: string): Integer; //; ALength: TSoundexLength = 4

begin
  NotYetImplemented(' SoundexCompare');
end;



Function SoundexProc(const AText, AOther: string): Boolean;

begin
  NotYetImplemented(' SoundexProc');
end;

end.
