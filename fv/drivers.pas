{ $Id$ }
{********[ SOURCE FILE OF GRAPHICAL FREE VISION ]**********}
{                                                          }
{    System independent clone of DRIVERS.PAS               }
{                                                          }
{    Interface Copyright (c) 1992 Borland International    }
{                                                          }
{    Copyright (c) 1996, 1997, 1998, 1999, 2000            }
{    by Leon de Boer                                       }
{    ldeboer@attglobal.net  - primary e-mail addr          }
{    ldeboer@projectent.com.au - backup e-mail addr        }
{                                                          }
{    Original FormatStr kindly donated by Marco Schmidt    }
{                                                          }
{    Mouse callback hook under FPC with kind assistance of }
{    Pierre Muller, Gertjan Schouten & Florian Klaempfl.   }
{                                                          }
{****************[ THIS CODE IS FREEWARE ]*****************}
{                                                          }
{     This sourcecode is released for the purpose to       }
{   promote the pascal language on all platforms. You may  }
{   redistribute it and/or modify with the following       }
{   DISCLAIMER.                                            }
{                                                          }
{     This SOURCE CODE is distributed "AS IS" WITHOUT      }
{   WARRANTIES AS TO PERFORMANCE OF MERCHANTABILITY OR     }
{   ANY OTHER WARRANTIES WHETHER EXPRESSED OR IMPLIED.     }
{                                                          }
{*****************[ SUPPORTED PLATFORMS ]******************}
{                                                          }
{ Only Free Pascal Compiler supported                      }
{                                                          }
{**********************************************************}

UNIT Drivers;

{<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>}
                                  INTERFACE
{<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>}

{====Include file to sort compiler platform out =====================}
{$I Platform.inc}
{====================================================================}

{==== Compiler directives ===========================================}

{$X+} { Extended syntax is ok }
{$R-} { Disable range checking }
{$IFNDEF OS_UNIX}
{$S-} { Disable Stack Checking }
{$ENDIF}
{$I-} { Disable IO Checking }
{$Q-} { Disable Overflow Checking }
{$V-} { Turn off strict VAR strings }
{====================================================================}

USES
   {$IFDEF OS_WINDOWS}                                { WIN/NT CODE }
         Windows,                                     { Standard unit }
   {$ENDIF}

   {$IFDEF OS_OS2}                                    { OS2 CODE }
     {$IFDEF PPC_Virtual}                             { VIRTUAL PASCAL UNITS }
       OS2Def, OS2Base, OS2PMAPI,                     { Standard units }
     {$ENDIF}
     {$IFDEF PPC_Speed}                               { SPEED PASCAL UNITS }
       BseDos, Os2Def,                                { Standard units }
     {$ENDIF}
     {$IFDEF PPC_FPC}                                 { FPC UNITS }
       DosCalls, Os2Def,                              { Standard units }
     {$ENDIF}
   {$ENDIF}

   {$IFDEF OS_UNIX}
     {$ifdef VER1_0}
       linux,
     {$else}
       unix,
     {$endif}
   {$ENDIF}

   video,
{$ifdef HasSysMsgUnit}
   SysMsg,
{$endif HasSysMsgUnit}
{$IFDEF GRAPH_API}                                    { GRAPH CODE }
   Graph,                                             { Standard unit }
{$ENDIF}
   GFVGraph,                                          { GFV graphics unit }
   FVCommon, Objects;                                 { GFV standard units }

{***************************************************************************}
{                              PUBLIC CONSTANTS                             }
{***************************************************************************}

{---------------------------------------------------------------------------}
{                              EVENT TYPE MASKS                             }
{---------------------------------------------------------------------------}
CONST
   evMouseDown = $0001;                               { Mouse down event }
   evMouseUp   = $0002;                               { Mouse up event }
   evMouseMove = $0004;                               { Mouse move event }
   evMouseAuto = $0008;                               { Mouse auto event }
   evKeyDown   = $0010;                               { Key down event }
   evCommand   = $0100;                               { Command event }
   evBroadcast = $0200;                               { Broadcast event }

{---------------------------------------------------------------------------}
{                             EVENT CODE MASKS                              }
{---------------------------------------------------------------------------}
CONST
   evNothing   = $0000;                               { Empty event }
   evMouse     = $000F;                               { Mouse event }
   evKeyboard  = $0010;                               { Keyboard event }
   evMessage   = $FF00;                               { Message event }

{---------------------------------------------------------------------------}
{                             EXTENDED KEY CODES                            }
{---------------------------------------------------------------------------}
CONST
   kbNoKey       = $0000;  kbAltEsc      = $0100;  kbEsc         = $011B;
   kbAltSpace    = $0200;  kbCtrlIns     = $0400;  kbShiftIns    = $0500;
   kbCtrlDel     = $0600;  kbShiftDel    = $0700;  kbAltBack     = $0800;
   kbAltShiftBack= $0900;  kbBack        = $0E08;  kbCtrlBack    = $0E7F;
   kbShiftTab    = $0F00;  kbTab         = $0F09;  kbAltQ        = $1000;
   kbCtrlQ       = $1011;  kbAltW        = $1100;  kbCtrlW       = $1117;
   kbAltE        = $1200;  kbCtrlE       = $1205;  kbAltR        = $1300;
   kbCtrlR       = $1312;  kbAltT        = $1400;  kbCtrlT       = $1414;
   kbAltY        = $1500;  kbCtrlY       = $1519;  kbAltU        = $1600;
   kbCtrlU       = $1615;  kbAltI        = $1700;  kbCtrlI       = $1709;
   kbAltO        = $1800;  kbCtrlO       = $180F;  kbAltP        = $1900;
   kbCtrlP       = $1910;  kbAltLftBrack = $1A00;  kbAltRgtBrack = $1B00;
   kbCtrlEnter   = $1C0A;  kbEnter       = $1C0D;  kbAltA        = $1E00;
   kbCtrlA       = $1E01;  kbAltS        = $1F00;  kbCtrlS       = $1F13;
   kbAltD        = $2000;  kbCtrlD       = $2004;  kbAltF        = $2100;
   kbCtrlF       = $2106;  kbAltG        = $2200;  kbCtrlG       = $2207;
   kbAltH        = $2300;  kbCtrlH       = $2308;  kbAltJ        = $2400;
   kbCtrlJ       = $240A;  kbAltK        = $2500;  kbCtrlK       = $250B;
   kbAltL        = $2600;  kbCtrlL       = $260C;  kbAltSemiCol  = $2700;
   kbAltQuote    = $2800;  kbAltOpQuote  = $2900;  kbAltBkSlash  = $2B00;
   kbAltZ        = $2C00;  kbCtrlZ       = $2C1A;  kbAltX        = $2D00;
   kbCtrlX       = $2D18;  kbAltC        = $2E00;  kbCtrlC       = $2E03;
   kbAltV        = $2F00;  kbCtrlV       = $2F16;  kbAltB        = $3000;
   kbCtrlB       = $3002;  kbAltN        = $3100;  kbCtrlN       = $310E;
   kbAltM        = $3200;  kbCtrlM       = $320D;  kbAltComma    = $3300;
   kbAltPeriod   = $3400;  kbAltSlash    = $3500;  kbAltGreyAst  = $3700;
   kbSpaceBar    = $3920;  kbF1          = $3B00;  kbF2          = $3C00;
   kbF3          = $3D00;  kbF4          = $3E00;  kbF5          = $3F00;
   kbF6          = $4000;  kbF7          = $4100;  kbF8          = $4200;
   kbF9          = $4300;  kbF10         = $4400;  kbHome        = $4700;
   kbUp          = $4800;  kbPgUp        = $4900;  kbGrayMinus   = $4A2D;
   kbLeft        = $4B00;  kbCenter      = $4C00;  kbRight       = $4D00;
   kbAltGrayPlus = $4E00;  kbGrayPlus    = $4E2B;  kbEnd         = $4F00;
   kbDown        = $5000;  kbPgDn        = $5100;  kbIns         = $5200;
   kbDel         = $5300;  kbShiftF1     = $5400;  kbShiftF2     = $5500;
   kbShiftF3     = $5600;  kbShiftF4     = $5700;  kbShiftF5     = $5800;
   kbShiftF6     = $5900;  kbShiftF7     = $5A00;  kbShiftF8     = $5B00;
   kbShiftF9     = $5C00;  kbShiftF10    = $5D00;  kbCtrlF1      = $5E00;
   kbCtrlF2      = $5F00;  kbCtrlF3      = $6000;  kbCtrlF4      = $6100;
   kbCtrlF5      = $6200;  kbCtrlF6      = $6300;  kbCtrlF7      = $6400;
   kbCtrlF8      = $6500;  kbCtrlF9      = $6600;  kbCtrlF10     = $6700;
   kbAltF1       = $6800;  kbAltF2       = $6900;  kbAltF3       = $6A00;
   kbAltF4       = $6B00;  kbAltF5       = $6C00;  kbAltF6       = $6D00;
   kbAltF7       = $6E00;  kbAltF8       = $6F00;  kbAltF9       = $7000;
   kbAltF10      = $7100;  kbCtrlPrtSc   = $7200;  kbCtrlLeft    = $7300;
   kbCtrlRight   = $7400;  kbCtrlEnd     = $7500;  kbCtrlPgDn    = $7600;
   kbCtrlHome    = $7700;  kbAlt1        = $7800;  kbAlt2        = $7900;
   kbAlt3        = $7A00;  kbAlt4        = $7B00;  kbAlt5        = $7C00;
   kbAlt6        = $7D00;  kbAlt7        = $7E00;  kbAlt8        = $7F00;
   kbAlt9        = $8000;  kbAlt0        = $8100;  kbAltMinus    = $8200;
   kbAltEqual    = $8300;  kbCtrlPgUp    = $8400;  kbF11         = $8500;
   kbF12         = $8600;  kbShiftF11    = $8700;  kbShiftF12    = $8800;
   kbCtrlF11     = $8900;  kbCtrlF12     = $8A00;  kbAltF11      = $8B00;
   kbAltF12      = $8C00;  kbCtrlUp      = $8D00;  kbCtrlMinus   = $8E00;
   kbCtrlCenter  = $8F00;  kbCtrlGreyPlus= $9000;  kbCtrlDown    = $9100;
   kbCtrlTab     = $9400;  kbAltHome     = $9700;  kbAltUp       = $9800;
   kbAltPgUp     = $9900;  kbAltLeft     = $9B00;  kbAltRight    = $9D00;
   kbAltEnd      = $9F00;  kbAltDown     = $A000;  kbAltPgDn     = $A100;
   kbAltIns      = $A200;  kbAltDel      = $A300;  kbAltTab      = $A500;

{ ------------------------------- REMARK ------------------------------ }
{ New keys not initially defined by Borland in their unit interface.    }
{ ------------------------------ END REMARK --- Leon de Boer, 15May96 - }
   kbFullStop    = $342E;  kbComma       = $332C;  kbBackSlash   = $352F;
   kbApostrophe  = $2827;  kbSemiColon   = $273B;  kbEqual       = $0D3D;
   kbGreaterThan = $343E;  kbLessThan    = $333C;  kbQuestion    = $353F;
   kbQuote       = $2822;  kbColon       = $273A;  kbPlus        = $0D2B;
   kbPipe        = $2B7C;  kbSlash       = $2B5C;  kbExclaim     = $0221;
   kbAt          = $0340;  kbNumber      = $0423;  kbPercent     = $0625;
   kbCaret       = $075E;  kbAmpersand   = $0826;  kbAsterix     = $092A;
   kbLeftBracket = $0A28;  kbRightBracket= $0B29;  kbApprox      = $2960;
   kbTilde       = $297E;  kbDollar      = $0524;  kbMinus       = $0C2D;
   kbUnderline   = $0C5F;  kbLeftSqBr    = $1A5B;  kbRightSqBr   = $1B5D;
   kbLeftCurlyBr = $1A7B;  kbRightCurlyBr= $1B7D;

{---------------------------------------------------------------------------}
{                      KEYBOARD STATE AND SHIFT MASKS                       }
{---------------------------------------------------------------------------}
CONST
   kbRightShift  = $0001;                             { Right shift key }
   kbLeftShift   = $0002;                             { Left shift key }
   kbCtrlShift   = $0004;                             { Control key down }
   kbAltShift    = $0008;                             { Alt key down }
   kbScrollState = $0010;                             { Scroll lock on }
   kbNumState    = $0020;                             { Number lock on }
   kbCapsState   = $0040;                             { Caps lock on }
   kbInsState    = $0080;                             { Insert mode on }

   kbBothShifts  = kbRightShift + kbLeftShift;        { Right & Left shifts }

{---------------------------------------------------------------------------}
{                         MOUSE BUTTON STATE MASKS                          }
{---------------------------------------------------------------------------}
CONST
   mbLeftButton   = $01;                              { Left mouse button }
   mbRightButton  = $02;                              { Right mouse button }
   mbMiddleButton = $04;                              { Middle mouse button }

{---------------------------------------------------------------------------}
{                         SCREEN CRT MODE CONSTANTS                         }
{---------------------------------------------------------------------------}
CONST
   smBW80    = $0002;                                 { Black and white }
   smCO80    = $0003;                                 { Colour mode }
   smMono    = $0007;                                 { Monochrome mode }
   smFont8x8 = $0100;                                 { 8x8 font mode }

{***************************************************************************}
{                          PUBLIC TYPE DEFINITIONS                          }
{***************************************************************************}

{ ******************************* REMARK ****************************** }
{    The TEvent definition is completely compatable with all existing   }
{  code but adds two new fields ID and Data into the message record     }
{  which helps with WIN/NT and OS2 message processing.                  }
{ ****************************** END REMARK *** Leon de Boer, 11Sep97 * }

{---------------------------------------------------------------------------}
{                          EVENT RECORD DEFINITION                          }
{---------------------------------------------------------------------------}
TYPE
   TEvent = PACKED RECORD
      What: Sw_Word;                                     { Event type }
      Case Sw_Word Of
        evNothing: ();                                { ** NO EVENT ** }
        evMouse: (
          Buttons: Byte;                              { Mouse buttons }
          Double: Boolean;                            { Double click state }
          Where: TPoint);                             { Mouse position }
        evKeyDown: (                                  { ** KEY EVENT ** }
          Case Sw_Integer Of
            0: (KeyCode:  Word);                       { Full key code }
            1: (CharCode: Char;                       { Char code }
                ScanCode: Byte;                       { Scan code }
                KeyShift: byte));                     { Shift states }
        evMessage: (                                  { ** MESSAGE EVENT ** }
          Command: Sw_Word;                              { Message command }
          Id     : Sw_Word;                              { Message id }
          Data   : Real;                              { Message data }
          Case Sw_Word Of
            0: (InfoPtr: Pointer);                    { Message pointer }
            1: (InfoLong: Longint);                   { Message longint }
            2: (InfoWord: Word);                      { Message Sw_Word }
            3: (InfoInt: Integer);                    { Message Sw_Integer }
            4: (InfoByte: Byte);                      { Message byte }
            5: (InfoChar: Char));                     { Message character }
   END;
   PEvent = ^TEvent;

{$ifdef USE_VIDEO_API}
   TVideoMode = Video.TVideoMode;                     { Screen mode }
{$else not USE_VIDEO_API}
   TVideoMode = Sw_Word;                              { Screen mode }
{$endif USE_VIDEO_API}

{---------------------------------------------------------------------------}
{                    ERROR HANDLER FUNCTION DEFINITION                      }
{---------------------------------------------------------------------------}
TYPE
   TSysErrorFunc = FUNCTION (ErrorCode: Sw_Integer; Drive: Byte): Sw_Integer;

{***************************************************************************}
{                            INTERFACE ROUTINES                             }
{***************************************************************************}

{ Get Dos counter ticks }
Function GetDosTicks:longint; { returns ticks at 18.2 Hz, just like DOS }

{+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
{                          BUFFER MOVE ROUTINES                             }
{+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}

{-CStrLen------------------------------------------------------------
Returns the length of string S, where S is a control string using tilde
characters ('~') to designate shortcut characters. The tildes are
excluded from the length of the string, as they will not appear on
the screen. For example, given the string '~B~roccoli' as its
parameter, CStrLen returns 8.
25May96 LdB
---------------------------------------------------------------------}
FUNCTION CStrLen (Const S: String): Sw_Integer;

{-MoveStr------------------------------------------------------------
Moves a string into a buffer for use with a view's WriteBuf or WriteLine.
Dest must be a TDrawBuffer (or an equivalent array of Sw_Words). The
characters in Str are moved into the low bytes of corresponding Sw_Words
in Dest. The high bytes of the Sw_Words are set to Attr, or remain
unchanged if Attr is zero.
25May96 LdB
---------------------------------------------------------------------}
PROCEDURE MoveStr (Var Dest; Const Str: String; Attr: Byte);

{-MoveCStr-----------------------------------------------------------
The characters in Str are moved into the low bytes of corresponding
Sw_Words in Dest. The high bytes of the Sw_Words are set to Lo(Attr) or
Hi(Attr). Tilde characters (~) in the string toggle between the two
attribute bytes passed in the Attr Sw_Word.
25May96 LdB
---------------------------------------------------------------------}
PROCEDURE MoveCStr (Var Dest; Const Str: String; Attrs: Word);

{-MoveBuf------------------------------------------------------------
Count bytes are moved from Source into the low bytes of corresponding
Sw_Words in Dest. The high bytes of the Sw_Words in Dest are set to Attr,
or remain unchanged if Attr is zero.
25May96 LdB
---------------------------------------------------------------------}
PROCEDURE MoveBuf (Var Dest, Source; Attr: Byte; Count: Sw_Word);

{-MoveChar------------------------------------------------------------
Moves characters into a buffer for use with a view's WriteBuf or
WriteLine. Dest must be a TDrawBuffer (or an equivalent array of Sw_Words).
The low bytes of the first Count Sw_Words of Dest are set to C, or
remain unchanged if Ord(C) is zero. The high bytes of the Sw_Words are
set to Attr, or remain unchanged if Attr is zero.
25May96 LdB
---------------------------------------------------------------------}
PROCEDURE MoveChar (Var Dest; C: Char; Attr: Byte; Count: Sw_Word);

{+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
{                        KEYBOARD SUPPORT ROUTINES                          }
{+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}

{-GetAltCode---------------------------------------------------------
Returns the scancode corresponding to Alt+Ch key that is given.
25May96 LdB
---------------------------------------------------------------------}
FUNCTION GetAltCode (Ch: Char): Word;

{-GetCtrlCode--------------------------------------------------------
Returns the scancode corresponding to Alt+Ch key that is given.
25May96 LdB
---------------------------------------------------------------------}
FUNCTION GetCtrlCode (Ch: Char): Word;

{-GetAltChar---------------------------------------------------------
Returns the ascii character for the Alt+Key scancode that was given.
25May96 LdB
---------------------------------------------------------------------}
FUNCTION GetAltChar (KeyCode: Word): Char;

{-GetCtrlChar--------------------------------------------------------
Returns the ascii character for the Ctrl+Key scancode that was given.
25May96 LdB
---------------------------------------------------------------------}
FUNCTION GetCtrlChar (KeyCode: Word): Char;

{-CtrlToArrow--------------------------------------------------------
Converts a WordStar-compatible control key code to the corresponding
cursor key code.
25May96 LdB
---------------------------------------------------------------------}
FUNCTION CtrlToArrow (KeyCode: Word): Word;

{+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
{                        KEYBOARD CONTROL ROUTINES                          }
{+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}

{-GetShiftState------------------------------------------------------
Returns a byte containing the current Shift key state. The return
value contains a combination of the kbXXXX constants for shift states.
08Jul96 LdB
---------------------------------------------------------------------}
FUNCTION GetShiftState: Byte;

{-GetKeyEvent--------------------------------------------------------
Checks whether a keyboard event is available. If a key has been pressed,
Event.What is set to evKeyDown and Event.KeyCode is set to the scan
code of the key. Otherwise, Event.What is set to evNothing.
19May98 LdB
---------------------------------------------------------------------}
PROCEDURE GetKeyEvent (Var Event: TEvent);

{+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
{                          MOUSE CONTROL ROUTINES                           }
{+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}

{-ShowMouse----------------------------------------------------------
Decrements the hide counter and if zero the mouse is shown on screen.
30Jun98 LdB
---------------------------------------------------------------------}
PROCEDURE ShowMouse;

{-HideMouse----------------------------------------------------------
If mouse hide counter is zero it removes the cursor from the screen.
The hide counter is then incremented by one count.
30Jun98 LdB
---------------------------------------------------------------------}
PROCEDURE HideMouse;

{-GetMouseEvent------------------------------------------------------
Checks whether a mouse event is available. If a mouse event has occurred,
Event.What is set to evMouseDown, evMouseUp, evMouseMove, or evMouseAuto
and the button and double click variables are set appropriately.
06Jan97 LdB
---------------------------------------------------------------------}
PROCEDURE GetMouseEvent (Var Event: TEvent);

{$ifdef HasSysMsgUnit}
{-GetSystemEvent------------------------------------------------------
Checks whether a system event is available. If a system event has occurred,
Event.What is set to evCommand appropriately
10Oct2000 PM
---------------------------------------------------------------------}
procedure GetSystemEvent (Var Event: TEvent);
{$endif HasSysMsgUnit}

{+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
{                      EVENT HANDLER CONTROL ROUTINES                       }
{+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}

{-InitEvents---------------------------------------------------------
Initializes the event manager, enabling the mouse handler routine and
under DOS/DPMI shows the mouse on screen. It is called automatically
by TApplication.Init.
02May98 LdB
---------------------------------------------------------------------}
PROCEDURE InitEvents;

{-DoneEvents---------------------------------------------------------
Terminates event manager and disables the mouse and under DOS hides
the mouse. It is called automatically by TApplication.Done.
02May98 LdB
---------------------------------------------------------------------}
PROCEDURE DoneEvents;

{+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
{                           VIDEO CONTROL ROUTINES                          }
{+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}

{-InitVideo---------------------------------------------------------
Initializes the video manager, Saves the current screen mode in
StartupMode, and switches to the mode indicated by ScreenMode.
19May98 LdB
---------------------------------------------------------------------}
PROCEDURE InitVideo;

{-DoneVideo---------------------------------------------------------
Terminates the video manager by restoring the initial screen mode
(given by StartupMode), clearing the screen, and restoring the cursor.
Called automatically by TApplication.Done.
03Jan97 LdB
---------------------------------------------------------------------}
PROCEDURE DoneVideo;

{-ClearScreen--------------------------------------------------------
Does nothing provided for compatability purposes only.
04Jan97 LdB
---------------------------------------------------------------------}
PROCEDURE ClearScreen;

{-SetVideoMode-------------------------------------------------------
Does nothing provided for compatability purposes only.
04Jan97 LdB
---------------------------------------------------------------------}
PROCEDURE SetVideoMode (Mode: Sw_Word);

{+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
{                           ERROR CONTROL ROUTINES                          }
{+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}

{-InitSysError-------------------------------------------------------
Error handling is not yet implemented so this simply sets
SysErrActive=True (ie it lies) and exits.
20May98 LdB
---------------------------------------------------------------------}
PROCEDURE InitSysError;

{-DoneSysError-------------------------------------------------------
Error handling is not yet implemented so this simply sets
SysErrActive=False and exits.
20May98 LdB
---------------------------------------------------------------------}
PROCEDURE DoneSysError;

{-SystemError---------------------------------------------------------
Error handling is not yet implemented so this simply drops through.
20May98 LdB
---------------------------------------------------------------------}
FUNCTION SystemError (ErrorCode: Sw_Integer; Drive: Byte): Sw_Integer;

{+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
{                           STRING FORMAT ROUTINES                          }
{+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}

{-PrintStr-----------------------------------------------------------
Does nothing provided for compatability purposes only.
30Jun98 LdB
---------------------------------------------------------------------}
PROCEDURE PrintStr (CONST S: String);

{-FormatStr----------------------------------------------------------
A string formatting routine that given a string that includes format
specifiers and a list of parameters in Params, FormatStr produces a
formatted output string in Result.
18Feb99 LdB
---------------------------------------------------------------------}
PROCEDURE FormatStr (Var Result: String; CONST Format: String; Var Params);

{+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
{                 >> NEW QUEUED EVENT HANDLER ROUTINES <<                   }
{+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}

{-PutEventInQueue-----------------------------------------------------
If there is room in the queue the event is placed in the next vacant
position in the queue manager.
17Mar98 LdB
---------------------------------------------------------------------}
FUNCTION PutEventInQueue (Var Event: TEvent): Boolean;

{-NextQueuedEvent----------------------------------------------------
If there are queued events the next event is loaded into event else
evNothing is returned.
17Mar98 LdB
---------------------------------------------------------------------}
PROCEDURE NextQueuedEvent(Var Event: TEvent);

{***************************************************************************}
{                        INITIALIZED PUBLIC VARIABLES                       }
{***************************************************************************}

PROCEDURE HideMouseCursor;
PROCEDURE ShowMouseCursor;


{---------------------------------------------------------------------------}
{                INITIALIZED DOS/DPMI/WIN/NT/OS2 VARIABLES                  }
{---------------------------------------------------------------------------}
CONST
   CheckSnow    : Boolean = False;                    { Compatability only }
   MouseEvents  : Boolean = False;                    { Mouse event state }
   MouseReverse : Boolean = False;                    { Mouse reversed }
   HiResScreen  : Boolean = False;                    { Compatability only }
   CtrlBreakHit : Boolean = False;                    { Compatability only }
   SaveCtrlBreak: Boolean = False;                    { Compatability only }
   SysErrActive : Boolean = False;                    { Compatability only }
   FailSysErrors: Boolean = False;                    { Compatability only }
   ButtonCount  : Byte = 0;                           { Mouse button count }
   DoubleDelay  : Sw_Word = 8;                           { Double click delay }
   RepeatDelay  : Sw_Word = 8;                           { Auto mouse delay }
   SysColorAttr : Sw_Word = $4E4F;                       { System colour attr }
   SysMonoAttr  : Sw_Word = $7070;                       { System mono attr }
   StartupMode  : Sw_Word = $FFFF;                       { Compatability only }
   CursorLines  : Sw_Word = $FFFF;                       { Compatability only }
   ScreenBuffer : Pointer = Nil;                      { Compatability only }
   SaveInt09    : Pointer = Nil;                      { Compatability only }
   SysErrorFunc : TSysErrorFunc = {$ifdef FPC}@{$endif}SystemError; { System error ptr }

{---------------------------------------------------------------------------}
{          >>> NEW INITIALIZED DOS/DPMI/WIN/NT/OS2 VARIABLES <<<            }
{---------------------------------------------------------------------------}
CONST
   TextModeGFV    : Boolean = False;                     { DOS/DPMI textmode op }
   UseFixedFont   : Boolean = True;
   DefLineNum     : Sw_Integer = 25;                     { Default line number }
   DefFontHeight  : Sw_Integer = 0;                      { Default font height }
   SysFontWidth   : Sw_Integer = 8;                      { System font width }
   SysFontHeight  : Sw_Integer = 16;                     { System font height }

{***************************************************************************}
{                      UNINITIALIZED PUBLIC VARIABLES                       }
{***************************************************************************}

{---------------------------------------------------------------------------}
{                UNINITIALIZED DOS/DPMI/WIN/NT/OS2 VARIABLES                }
{---------------------------------------------------------------------------}
VAR
   MouseIntFlag: Byte;                                { Mouse in int flag }
   MouseButtons: Byte;                                { Mouse button state }
   ScreenWidth : Byte;                                { Screen text width }
   ScreenHeight: Byte;                                { Screen text height }
{$IFNDEF Use_Video_API}
   ScreenMode  : Sw_Word;                                { Screen mode }
{$Else Use_Video_API}
   ScreenMode  : TVideoMode;                         { Screen mode }
{$Endif Use_Video_API}
   MouseWhere  : TPoint;                              { Mouse position }

{<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>}
                               IMPLEMENTATION
{<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>}
{ API Units }
  USES
  FVConsts,
{$IFDEF GRAPH_API}                                    { GRAPH CODE }
{$ifdef win32}
  win32gr,
{$endif}
{$ENDIF GRAPH_API}                                    { GRAPH CODE }
  Keyboard,Mouse;

{***************************************************************************}
{                        PRIVATE INTERNAL CONSTANTS                         }
{***************************************************************************}

{---------------------------------------------------------------------------}
{                 DOS/DPMI MOUSE INTERRUPT EVENT QUEUE SIZE                 }
{---------------------------------------------------------------------------}
CONST EventQSize = 16;                                { Default int bufsize }

{---------------------------------------------------------------------------}
{                DOS/DPMI/WIN/NT/OS2 NEW EVENT QUEUE MAX SIZE               }
{---------------------------------------------------------------------------}
CONST QueueMax = 64;                                  { Max new queue size }

{---------------------------------------------------------------------------}
{   MAX WIEW WIDTH to avoid TDrawBuffer overrun in views unit               }
{---------------------------------------------------------------------------}
CONST MaxViewWidth = 132;                                { Max view width }

{***************************************************************************}
{                          PRIVATE INTERNAL TYPES                           }
{***************************************************************************}

{***************************************************************************}
{                  PRIVATE INTERNAL INITIALIZED VARIABLES                   }
{***************************************************************************}

{---------------------------------------------------------------------------}
{          DOS/DPMI/WIN/NT/OS2 ALT KEY SCANCODES FROM KEYS (0-127)          }
{---------------------------------------------------------------------------}
CONST AltCodes: Array [0..127] Of Byte = (
      $00, $00, $00, $00, $00, $00, $00, $00,         { $00 - $07 }
      $00, $00, $00, $00, $00, $00, $00, $00,         { $08 - $0F }
      $00, $00, $00, $00, $00, $00, $00, $00,         { $10 - $17 }
      $00, $00, $00, $00, $00, $00, $00, $00,         { $18 - $1F }
      $00, $00, $00, $00, $00, $00, $00, $00,         { $20 - $27 }
      $00, $00, $00, $00, $00, $82, $00, $00,         { $28 - $2F }
      $81, $78, $79, $7A, $7B, $7C, $7D, $7E,         { $30 - $37 }
      $7F, $80, $00, $00, $00, $83, $00, $00,         { $38 - $3F }
      $00, $1E, $30, $2E, $20, $12, $21, $22,         { $40 - $47 }
      $23, $17, $24, $25, $26, $32, $31, $18,         { $48 - $4F }
      $19, $10, $13, $1F, $14, $16, $2F, $11,         { $50 - $57 }
      $2D, $15, $2C, $00, $00, $00, $00, $00,         { $58 - $5F }
      $00, $00, $00, $00, $00, $00, $00, $00,         { $60 - $67 }
      $00, $00, $00, $00, $00, $00, $00, $00,         { $68 - $6F }
      $00, $00, $00, $00, $00, $00, $00, $00,         { $70 - $77 }
      $00, $00, $00, $00, $00, $00, $00, $00);        { $78 - $7F }

{***************************************************************************}
{                  PRIVATE INTERNAL INITIALIZED VARIABLES                   }
{***************************************************************************}

{---------------------------------------------------------------------------}
{                           NEW CONTROL VARIABLES                           }
{---------------------------------------------------------------------------}
CONST
   HideCount : Sw_Integer = 0;                           { Cursor hide count }
   QueueCount: Sw_Word = 0;                              { Queued message count }
   QueueHead : Sw_Word = 0;                              { Queue head pointer }
   QueueTail : Sw_Word = 0;                              { Queue tail pointer }

{***************************************************************************}
{                 PRIVATE INTERNAL UNINITIALIZED VARIABLES                  }
{***************************************************************************}

{---------------------------------------------------------------------------}
{                     UNINITIALIZED DOS/DPMI/API VARIABLES                      }
{---------------------------------------------------------------------------}
VAR
   LastDouble : Boolean;                              { Last double buttons }
   LastButtons: Byte;                                 { Last button state }
   DownButtons: Byte;                                 { Last down buttons }
   EventCount : Sw_Word;                                 { Events in queue }
   AutoDelay  : Sw_Word;                                 { Delay time count }
   DownTicks  : Sw_Word;                                 { Down key tick count }
   AutoTicks  : Sw_Word;                                 { Held key tick count }
   LastWhereX : Sw_Word;                                 { Last x position }
   LastWhereY : Sw_Word;                                 { Last y position }
   DownWhereX : Sw_Word;                                 { Last x position }
   DownWhereY : Sw_Word;                                 { Last y position }
   LastWhere  : TPoint;                               { Last mouse position }
   DownWhere  : TPoint;                               { Last down position }
   EventQHead : Pointer;                              { Head of queue }
   EventQTail : Pointer;                              { Tail of queue }
   EventQueue : Array [0..EventQSize - 1] Of TEvent;  { Event queue }
   EventQLast : RECORD END;                           { Simple end marker }


{---------------------------------------------------------------------------}
{  GetDosTicks (18.2 Hz)                                                    }
{---------------------------------------------------------------------------}

Function GetDosTicks:longint; { returns ticks at 18.2 Hz, just like DOS }
{$IFDEF OS_OS2}
  const
    QSV_MS_COUNT = 14;
  var
    L: longint;
  begin
    DosQuerySysInfo (QSV_MS_COUNT, QSV_MS_COUNT, L, 4);
    GetDosTicks := L div 55;
  end;
{$ENDIF}
{$IFDEF OS_UNIX}
  var
    tv : TimeVal;
  {  tz : TimeZone;}
  begin
    GetTimeOfDay(tv{,tz});
    GetDosTicks:=((tv.Sec mod 86400) div 60)*1092+((tv.Sec mod 60)*1000000+tv.USec) div 54945;
  end;
{$ENDIF OS_UNIX}
{$IFDEF OS_WINDOWS}
  begin
     GetDosTicks:=GetTickCount div 55;
  end;
{$ENDIF OS_WINDOWS}
{$IFDEF OS_DOS}
  begin
    GetDosTicks:=MemL[$40:$6c];
  end;
{$ENDIF OS_DOS}

{---------------------------------------------------------------------------}
{                UNINITIALIZED DOS/DPMI/WIN/NT/OS2 VARIABLES                }
{---------------------------------------------------------------------------}
VAR
   SaveExit: Pointer;                                 { Saved exit pointer }
   Queue   : Array [0..QueueMax-1] Of TEvent;         { New message queue }

{***************************************************************************}
{                         PRIVATE INTERNAL ROUTINES                         }
{***************************************************************************}

PROCEDURE ShowMouseCursor;
BEGIN
  ShowMouse;
END;

PROCEDURE HideMouseCursor;
BEGIN
  HideMouse;
END;

{+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
{               DOS/DPMI/WIN/NT/OS2 PRIVATE INTERNAL ROUTINES               }
{+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}

{---------------------------------------------------------------------------}
{  ExitDrivers -> Platforms DOS/DPMI/WIN/NT/OS2 - Updated 08Jun98 LdB       }
{---------------------------------------------------------------------------}
PROCEDURE ExitDrivers; {$IFNDEF PPC_FPC}{$IFNDEF OS_UNIX} FAR; {$ENDIF}{$ENDIF}
BEGIN
   DoneSysError;                                      { Relase error trap }
   DoneEvents;                                        { Close event driver }
   DoneKeyboard;
   DoneVideo;
   ExitProc := SaveExit;                              { Restore old exit }
END;

{---------------------------------------------------------------------------}
{  DetectVideo -> Platforms DOS/DPMI/WIN/NT/OS2 - Updated 19May98 LdB       }
{---------------------------------------------------------------------------}
{$IFDEF Use_Video_API}

procedure DetectVideo;
VAR
  CurrMode : TVideoMode;
begin
  { Video.InitVideo; Incompatible with BP
    and forces a screen clear which is often a bad thing PM }
  GetVideoMode(CurrMode);
  ScreenMode:=CurrMode;
end;
{$else not Use_Video_API}
PROCEDURE DetectVideo;
{$IFDEF OS_DOS}                                       { DOS/DPMI CODE }
ASSEMBLER;
   {$IFDEF ASM_BP}                                    { BP COMPATABLE ASM }
   ASM
     MOV AH, $0F;                                     { Set function id }
     PUSH BP;                                         { Safety!! save reg }
     INT $10;                                         { Get current crt mode }
     POP BP;                                          { Restore register }
     PUSH AX;                                         { Hold result }
     MOV AX, $1130;                                   { Set function id }
     MOV BH, 0;                                       { Zero register }
     MOV DL, 0;                                       { Zero register }
     PUSH BP;                                         { Safety!! save reg }
     INT $10;                                         { Get ext-video mode }
     POP BP;                                          { Restore register }
     POP AX;                                          { Recover held value }
     MOV DH, AH;                                      { Transfer high mode }
     CMP DL, 25;                                      { Check screen ht }
     SBB AH, AH;                                      { Subtract borrow }
     INC AH;                                          { Make #1 if in high }
     MOV CL, 1;                                       { Preset value of 1 }
     OR DL, DL;                                       { Test for zero }
     JNZ @@1;                                         { Branch if not zero }
     MOV CL, 0                                        { Set value to zero }
     MOV DL, 24;                                      { Zero = 24 lines }
   @@1:
     INC DL;                                          { Add one line }
     MOV ScreenWidth, DH;                             { Hold screen width }
     MOV ScreenHeight, DL;                            { Hold screen height }
     MOV HiResScreen, CL;                             { Set hires mask }
     CMP AL, smMono;                                  { Is screen mono }
     JZ @@Exit1;                                      { Exit of mono }
     CMP AL, smBW80;                                  { Is screen B&W }
     JZ @@Exit1;                                      { Exit if B&W }
     MOV AX, smCO80;                                  { Else set to colour }
   @@Exit1:
     MOV ScreenMode, AX;                              { Hold screen mode }
   END;
   {$ENDIF}
   {$IFDEF ASM_FPC}                                   { FPC COMPATABLE ASM }
   ASM
     MOVB $0x0F, %AH;                                 { Set function id }
     PUSHL %EBP;                                      { Save register }
     INT $0x10;                                       { Get current crt mode }
     POPL %EBP;                                       { Restore register }
     PUSHL %EAX;                                      { Hold result }
     MOVW $0x1130, %AX;                               { Set function id }
     MOVB $0, %BH;                                    { Zero register }
     MOVB $0, %DL;                                    { Zero register }
     PUSHL %EBP;                                      { Safety!! save reg }
     INT $0x10;                                       { Get ext-video mode }
     POPL %EBP;                                       { Restore register }
     POPL %EAX;                                       { Recover held value }
     MOVB %AH, %DH;                                   { Transfer high mode }
     CMPB $25, %DL;                                   { Check screen ht }
     SBB %AH, %AH;                                    { Subtract borrow }
     INCB %AH;                                        { Make #1 if in high }
     MOVB $1, %CL;                                    { Preset value of 1 }
     ORB %DL, %DL;                                    { Test for zero }
     JNZ .L_JMP1;                                     { Branch if not zero }
     MOVB $0, %CL;                                    { Set value to zero }
     MOVB $24, %DL;                                   { Zero = 24 lines }
   .L_JMP1:
     INCB %DL;                                        { Add one line }
     MOVB %DH, SCREENWIDTH;                           { Hold screen width }
     MOVB %DL, SCREENHEIGHT;                          { Hold screen height }
     MOVB %CL, HIRESSCREEN;                           { Set hires mask }
     CMPB $07, %AL;                                   { Is screen mono }
     JZ .L_Exit1;                                     { Exit of mono }
     CMPB $02, %AL;                                   { Is screen B&W }
     JZ .L_Exit1;                                     { Exit if B&W }
     MOVW $03, %AX;                                   { Else set to colour }
   .L_Exit1:
     MOVW %AX, SCREENMODE;                            { Hold screen mode }
   END;
   {$ENDIF}
{$ENDIF}
{$IFDEF OS_WINDOWS}                                   { WIN/NT CODE }
VAR Dc: HDC;
BEGIN
   Dc := GetDc(0);                                    { Get screen context }
   If ((GetDeviceCaps(Dc, BitsPixel) > 1) OR          { Colour capacity }
   (GetDeviceCaps(Dc, Planes) > 1)) Then              { Colour capacity }
     ScreenMode := smCO80 Else ScreenMode := smMono;  { Screen mode }
   ReleaseDc(0, Dc);                                  { Release context }
END;
{$ENDIF}
{$IFDEF OS_OS2}                                       { OS2 CODE }
VAR Ps: Hps; Dc: Hdc; Colours: LongInt;
BEGIN
   Ps := WinGetPS(HWND_Desktop);                      { Get desktop PS }
   Dc := GpiQueryDevice(Ps);                          { Get gpi context }
   DevQueryCaps(Dc, Caps_Phys_Colors, 1, Colours);    { Colour capacity }
   If (Colours> 2) Then ScreenMode := smCO80          { Colour screen }
     Else ScreenMode := smMono;                       { Mono screen }
   WinReleasePS(Ps);                                  { Release desktop PS }
END;
{$ENDIF}
{$endif not Use_Video_API}

{---------------------------------------------------------------------------}
{  DetectMouse -> Platforms DOS/DPMI/WIN/NT/OS2 - Updated 19May98 LdB       }
FUNCTION DetectMouse: Byte;
begin
  DetectMouse:=Mouse.DetectMouse;
end;

{***************************************************************************}
{                            INTERFACE ROUTINES                             }
{***************************************************************************}

{+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
{                           BUFFER MOVE ROUTINES                            }
{+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}

{---------------------------------------------------------------------------}
{  CStrLen -> Platforms DOS/DPMI/WIN/NT/OS2 - Updated 25May96 LdB           }
{---------------------------------------------------------------------------}
FUNCTION CStrLen (Const S: String): Sw_Integer;
VAR I, J: Sw_Integer;
BEGIN
   J := 0;                                            { Set result to zero }
   For I := 1 To Length(S) Do
     If (S[I] <> '~') Then Inc(J);                    { Inc count if not ~ }
   CStrLen := J;                                      { Return length }
END;

{---------------------------------------------------------------------------}
{  MoveStr -> Platforms DOS/DPMI/WIN/NT/OS2 - Updated 10Jul99 LdB           }
{---------------------------------------------------------------------------}
PROCEDURE MoveStr (Var Dest; Const Str: String; Attr: Byte);
VAR I: Word; P: PWord;
BEGIN
   For I := 1 To Length(Str) Do Begin                 { For each character }
     P := @TWordArray(Dest)[I-1];                     { Pointer to Sw_Word }
     If (Attr <> 0) Then WordRec(P^).Hi := Attr;      { Copy attribute }
     WordRec(P^).Lo := Byte(Str[I]);                  { Copy string char }
   End;
END;

{---------------------------------------------------------------------------}
{  MoveCStr -> Platforms DOS/DPMI/WIN/NT/OS2 - Updated 10Jul99 LdB          }
{---------------------------------------------------------------------------}
PROCEDURE MoveCStr (Var Dest; Const Str: String; Attrs: Word);
VAR B: Byte; I, J: Sw_Word; P: PWord;
BEGIN
   J := 0;                                            { Start position }
   For I := 1 To Length(Str) Do Begin                 { For each character }
     If (Str[I] <> '~') Then Begin                    { Not tilde character }
       P := @TWordArray(Dest)[J];                     { Pointer to Sw_Word }
       If (Lo(Attrs) <> 0) Then
         WordRec(P^).Hi := Lo(Attrs);                 { Copy attribute }
       WordRec(P^).Lo := Byte(Str[I]);                { Copy string char }
       Inc(J);                                        { Next position }
     End Else Begin
       B := Hi(Attrs);                                { Hold attribute }
       WordRec(Attrs).Hi := Lo(Attrs);                { Copy low to high }
       WordRec(Attrs).Lo := B;                        { Complete exchange }
     End;
   End;
END;

{---------------------------------------------------------------------------}
{  MoveBuf -> Platforms DOS/DPMI/WIN/NT/OS2 - Updated 10Jul99 LdB           }
{---------------------------------------------------------------------------}
PROCEDURE MoveBuf (Var Dest, Source; Attr: Byte; Count: Sw_Word);
VAR I: Word; P: PWord;
BEGIN
   For I := 1 To Count Do Begin
     P := @TWordArray(Dest)[I-1];                     { Pointer to Sw_Word }
     If (Attr <> 0) Then WordRec(P^).Hi := Attr;      { Copy attribute }
     WordRec(P^).Lo := TByteArray(Source)[I-1];       { Copy source data }
   End;
END;

{---------------------------------------------------------------------------}
{  MoveChar -> Platforms DOS/DPMI/WIN/NT/OS2 - Updated 10Jul99 LdB          }
{---------------------------------------------------------------------------}
PROCEDURE MoveChar (Var Dest; C: Char; Attr: Byte; Count: Sw_Word);
VAR I: Word; P: PWord;
BEGIN
   For I := 1 To Count Do Begin
     P := @TWordArray(Dest)[I-1];                     { Pointer to Sw_Word }
     If (Attr <> 0) Then WordRec(P^).Hi := Attr;      { Copy attribute }
     If (Ord(C) <> 0) Then WordRec(P^).Lo := Byte(C); { Copy character }
   End;
END;

{+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
{                        KEYBOARD SUPPORT ROUTINES                          }
{+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}

{---------------------------------------------------------------------------}
{  GetAltCode -> Platforms DOS/DPMI/WIN/NT/OS2 - Updated 25May96 LdB        }
{---------------------------------------------------------------------------}
FUNCTION GetAltCode (Ch: Char): Word;
BEGIN
   GetAltCode := 0;                                   { Preset zero return }
   Ch := UpCase(Ch);                                  { Convert upper case }
   If (Ch < #128) Then
     GetAltCode := AltCodes[Ord(Ch)] SHL 8            { Return code }
     Else If (Ch = #240) Then GetAltCode := $0200     { Return code }
       Else GetAltCode := 0;                          { Return zero }
END;

{---------------------------------------------------------------------------}
{  GetCtrlCode -> Platforms DOS/DPMI/WIN/NT/OS2 - Updated 25May96 LdB       }
{---------------------------------------------------------------------------}
FUNCTION GetCtrlCode (Ch: Char): Word;
BEGIN
   GetCtrlCode := GetAltCode(Ch) OR (Ord(Ch) - $40);  { Ctrl+key code }
END;

{---------------------------------------------------------------------------}
{  GetAltChar -> Platforms DOS/DPMI/WIN/NT/OS2 - Updated 25May96 LdB        }
{---------------------------------------------------------------------------}
FUNCTION GetAltChar (KeyCode: Word): Char;
VAR I: Sw_Integer;
BEGIN
   GetAltChar := #0;                                  { Preset fail return }
   If (Lo(KeyCode) = 0) Then Begin                    { Extended key }
     If (Hi(KeyCode) <= $83) Then Begin               { Highest value in list }
       I := 0;                                        { Start at first }
       While (I < 128) AND (Hi(KeyCode) <> AltCodes[I])
         Do Inc(I);                                   { Search for match }
       If (I < 128) Then GetAltChar := Chr(I);        { Return character }
     End Else
       If (Hi(KeyCode)=$02) Then GetAltChar := #240;  { Return char }
   End;
END;

{---------------------------------------------------------------------------}
{  GetCtrlChar -> Platforms DOS/DPMI/WIN/NT/OS2 - Updated 25May96 LdB       }
{---------------------------------------------------------------------------}
FUNCTION GetCtrlChar (KeyCode: Word): Char;
VAR C: Char;
BEGIN
  C := #0;                                            { Preset #0 return }
  If (Lo(KeyCode) > 0) AND (Lo(KeyCode) <= 26) Then   { Between 1-26 }
    C := Chr(Lo(KeyCode) + $40);                      { Return char A-Z }
  GetCtrlChar := C;                                   { Return result }
END;

{---------------------------------------------------------------------------}
{  CtrlToArrow -> Platforms DOS/DPMI/WIN/NT/OS2 - Updated 25May96 LdB       }
{---------------------------------------------------------------------------}
FUNCTION CtrlToArrow (KeyCode: Word): Word;
CONST NumCodes = 11;
      CtrlCodes : Array [0..NumCodes-1] Of Char =
        (#19, #4, #5, #24, #1, #6, #7, #22, #18, #3, #8);
      ArrowCodes: Array [0..NumCodes-1] Of Sw_Word =
       (kbLeft, kbRight, kbUp, kbDown, kbHome, kbEnd, kbDel, kbIns,
        kbPgUp, kbPgDn, kbBack);
VAR I: Sw_Integer;
BEGIN
   CtrlToArrow := KeyCode;                            { Preset key return }
   For I := 0 To NumCodes - 1 Do
     If WordRec(KeyCode).Lo = Byte(CtrlCodes[I])      { Matches a code }
     Then Begin
       CtrlToArrow := ArrowCodes[I];                  { Return key stroke }
       Exit;                                          { Now exit }
     End;
END;

{+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
{                        KEYBOARD CONTROL ROUTINES                          }
{+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}

{---------------------------------------------------------------------------}
{  GetShiftState -> Platforms DOS/DPMI/WIN/NT/OS2 - Updated 08Jul96 LdB     }
{---------------------------------------------------------------------------}
FUNCTION GetShiftState: Byte;
begin
  GetShiftState:=Keyboard.GetKeyEventShiftState(Keyboard.PollShiftStateEvent);
end;

{---------------------------------------------------------------------------}
{  GetKeyEvent -> Platforms DOS/DPMI/WIN/NT/OS2 - Updated 19May98 LdB       }
{---------------------------------------------------------------------------}
procedure GetKeyEvent (Var Event: TEvent);
var
  key      : TKeyEvent;
  keycode  : Word;
  keyshift : byte;
begin
  if Keyboard.PollKeyEvent<>0 then
   begin
     key:=Keyboard.GetKeyEvent;
     keycode:=Keyboard.GetKeyEventCode(key);
     keyshift:=KeyBoard.GetKeyEventShiftState(key);
     { fixup shift-keys }
     if keyshift and kbShift<>0 then
       begin
         case keycode of
           $5200 : keycode:=kbShiftIns;
           $5300 : keycode:=kbShiftDel;
           $8500 : keycode:=kbShiftF1;
           $8600 : keycode:=kbShiftF2;
         end;
       end
     { fixup ctrl-keys }
     else if keyshift and kbCtrl<>0 then
       begin
         case keycode of
           $5200,
           $9200 : keycode:=kbCtrlIns;
           $5300,
           $9300 : keycode:=kbCtrlDel;
         end;
       end
     { fixup alt-keys }
     else if keyshift and kbAlt<>0 then
       begin
         case keycode of
           $0e08,
           $0e00 : keycode:=kbAltBack;
         end;
       end
     { fixup normal keys }
     else
       begin
         case keycode of
           $e00d : keycode:=kbEnter;
         end;
       end;
     Event.What:=evKeyDown;
     Event.KeyCode:=keycode;
     Event.KeyShift:=keyshift;
   end
  else
   Event.What:=evNothing;
end;


{+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
{                          MOUSE CONTROL ROUTINES                           }
{+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}

{---------------------------------------------------------------------------}
{  HideMouse -> Platforms DOS/DPMI/WIN/NT/OS2 - Updated 30Jun98 LdB         }
{---------------------------------------------------------------------------}
procedure HideMouse;
begin
{ Is mouse hidden yet?
  If (HideCount = 0) Then}
    Mouse.HideMouse;
{  Inc(HideCount);}
end;

{---------------------------------------------------------------------------}
{  ShowMouse -> Platforms DOS/DPMI/WIN/NT/OS2 - Updated 30Jun98 LdB         }
{---------------------------------------------------------------------------}
procedure ShowMouse;
begin
{  if HideCount>0 then
    dec(HideCount);
  if (HideCount=0) then}
   Mouse.ShowMouse;
end;

{---------------------------------------------------------------------------}
{  GetMouseEvent -> Platforms DOS/DPMI/WINDOWS/OS2 - Updated 30Jun98 LdB    }
{---------------------------------------------------------------------------}
procedure GetMouseEvent (Var Event: TEvent);
var
  e : Mouse.TMouseEvent;
begin
  if Mouse.PollMouseEvent(e) then
   begin
     Mouse.GetMouseEvent(e);
     MouseWhere.X:=e.x * SysFontWidth;
     MouseWhere.Y:=e.y * SysFontHeight;
     Event.Double:=false;
     case e.Action of
       MouseActionMove :
         Event.What:=evMouseMove;
       MouseActionDown :
         begin
           Event.What:=evMouseDown;
           if (DownButtons=e.Buttons) and (LastWhere.X=MouseWhere.X) and (LastWhere.Y=MouseWhere.Y) and
              (GetDosTicks-DownTicks<=DoubleDelay) then
             Event.Double:=true;
           DownButtons:=e.Buttons;
           DownWhere.X:=MouseWhere.x;
           DownWhere.Y:=MouseWhere.y;
           DownTicks:=GetDosTicks;
           AutoTicks:=GetDosTicks;
           if AutoTicks=0 then
             AutoTicks:=1;
           AutoDelay:=RepeatDelay;
         end;
       MouseActionUp :
         begin
           AutoTicks:=0;
           Event.What:=evMouseUp;
           AutoTicks:=0;
         end;
     end;
     Event.Buttons:=e.Buttons;
     Event.Where.X:=MouseWhere.x;
     Event.Where.Y:=MouseWhere.y;
     LastButtons:=Event.Buttons;
     LastWhere.x:=Event.Where.x;
     LastWhere.y:=Event.Where.y;
   end
  else if (AutoTicks <> 0) and (GetDosTicks >= AutoTicks + AutoDelay) then
   begin
     Event.What:=evMouseAuto;
     Event.Buttons:=LastButtons;
     Event.Where.X:=LastWhere.x;
     Event.Where.Y:=LastWhere.y;
     AutoTicks:=GetDosTicks;
     AutoDelay:=1;
   end
  else
   FillChar(Event,sizeof(TEvent),0);
end;

{$ifdef HasSysMsgUnit}
{---------------------------------------------------------------------------}
{  GetSystemEvent                                                           }
{---------------------------------------------------------------------------}
procedure GetSystemEvent (Var Event: TEvent);
var
  SysEvent : TsystemEvent;
begin
  if PollSystemEvent(SysEvent) then
    begin
      SysMsg.GetSystemEvent(SysEvent);
      case SysEvent.typ of
      SysNothing :
        Event.What:=evNothing;
      SysSetFocus :
        begin
          Event.What:=evBroadcast;
          Event.Command:=cmReceivedFocus;
        end;
      SysReleaseFocus :
        begin
          Event.What:=evBroadcast;
          Event.Command:=cmReleasedFocus;
        end;
      SysClose :
        begin
          Event.What:=evCommand;
          Event.Command:=cmQuitApp;
        end;
      SysResize :
        begin
          Event.What:=evCommand;
          Event.Command:=cmResizeApp;
          Event.Id:=SysEvent.x;
          Event.InfoWord:=SysEvent.y;
        end;
      else
        Event.What:=evNothing;
      end;
    end
  else
    Event.What:=evNothing;
end;
{$endif HasSysMsgUnit}


{+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
{                      EVENT HANDLER CONTROL ROUTINES                       }
{+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}

{---------------------------------------------------------------------------}
{  InitEvents -> Platforms DOS/DPMI/WIN/NT/OS2 - Updated 07Sep99 LdB        }
{---------------------------------------------------------------------------}
PROCEDURE InitEvents;
BEGIN
  If (ButtonCount <> 0) Then
    begin                   { Mouse is available }
     Mouse.InitMouse;                                 { Hook the mouse }
     { this is required by the use of HideCount variable }
     Mouse.ShowMouse;                                 { visible by default }
     { HideCount:=0;  }
     LastButtons := 0;                                { Clear last buttons }
     DownButtons := 0;                                { Clear down buttons }
     MouseWhere.X:=Mouse.GetMouseX;
     MouseWhere.Y:=Mouse.GetMouseY;                   { Get mouse position }
     LastWhere.x:=MouseWhere.x;
     LastWhereX:=MouseWhere.x;
     LastWhere.y:=MouseWhere.y;
     LastWhereY:=MouseWhere.y;
     MouseEvents := True;                             { Set initialized flag }
    end;
{$ifdef HasSysMsgUnit}
  InitSystemMsg;
{$endif HasSysMsgUnit}
END;

{---------------------------------------------------------------------------}
{  DoneEvents -> Platforms DOS/DPMI/WIN/NT/OS2 - Updated 30Jul99 LdB        }
{---------------------------------------------------------------------------}
PROCEDURE DoneEvents;
BEGIN
{$ifdef HasSysMsgUnit}
  DoneSystemMsg;
{$endif HasSysMsgUnit}
  Mouse.DoneMouse;
  MouseEvents:=false;
END;

{+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
{                           VIDEO CONTROL ROUTINES                          }
{+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}

const
  VideoInitialized : boolean = false;

{---------------------------------------------------------------------------}
{  InitVideo -> Platforms DOS/DPMI/WIN/NT/OS2 - Updated 26Nov99 LdB         }
{---------------------------------------------------------------------------}
PROCEDURE InitVideo;
VAR
{$ifdef GRAPH_API}
  I, J: Integer;
  Ts : TextSettingsType;
{$else not GRAPH_API}
  I, J: Integer;
{$IFDEF OS_WINDOWS}
  Dc, Mem: HDc; TempFont: TLogFont; Tm: TTextmetric;
{$ENDIF}
{$IFDEF OS_OS2}
  Ts, Fs: Sw_Integer; Ps: HPs; Tm: FontMetrics;
{$ENDIF}
{$ENDIF}
{$ifdef USE_VIDEO_API}
    StoreScreenMode : TVideoMode;
{$endif USE_VIDEO_API}
BEGIN
if VideoInitialized then
  DoneVideo;
{$ifdef GRAPH_API}
if Not TextmodeGFV then
  begin
{$ifdef go32v2}
    I := VGA;
    J := VGAHi;
{$else not go32v2}
{$ifdef win32}
    I := VESA;
    J := mLargestWindow16;
    DefFontHeight:=8;
{$else not win32}
    I := Detect;                                   { Detect video card }
    J := 0;                                        { Zero select mode }
{$endif win32}
{$endif go32v2}
    InitGraph(I, J, '');                           { Initialize graphics }
    I := Graph.GetMaxX;                            { Fetch max x size }
    J := Graph.GetMaxY;                            { Fetch max y size }
    If (DefFontHeight = 0) Then                    { Font height not set }
      J := (Graph.GetMaxY+1) DIV DefLineNum        { Approx font height }
      Else J := DefFontHeight;                     { Use set font height }
    I := J DIV (TextHeight('H')+4);                { Approx magnification }
    If (I < 1) Then I := 1;                        { Must be 1 or above }
    GetTextSettings(Ts);                           { Get text style }
    SetTextStyle(Ts.Font, Ts.Direction, I);        { Set new font settings }
    SysFontWidth := TextWidth('H');                { Transfer font width }
    SysFontHeight := TextHeight('H')+4;            { Transfer font height }
    ScreenWidth := (Graph.GetMaxX+1) DIV
      SysFontWidth;                                { Calc screen width }
    if ScreenWidth > MaxViewWidth then
      ScreenWidth := MaxViewWidth;
    ScreenHeight := (Graph.GetMaxY+1) DIV
      SysFontHeight;                               { Calc screen height }
    UseFixedFont:=true;
{$ifdef USE_VIDEO_API}
    if assigned(Video.VideoBuf) then
      FreeMem(Video.VideoBuf);
    GetMem(Video.VideoBuf,sizeof(word)*ScreenWidth*ScreenHeight);
    if assigned(Video.OldVideoBuf) then
      FreeMem(Video.OldVideoBuf);
    GetMem(Video.OldVideoBuf,sizeof(word)*ScreenWidth*ScreenHeight);
    GetMem(GFVGraph.SpVideoBuf,sizeof(pextrainfo)*(ScreenWidth+1)*(ScreenHeight+1));
    FillChar(Video.VideoBuf^,sizeof(word)*ScreenWidth*ScreenHeight,#0);
    FillChar(Video.OldVideoBuf^,sizeof(word)*ScreenWidth*ScreenHeight,#0);
    FillChar(GFVGraph.SpVideoBuf^,sizeof(pextrainfo)*(ScreenWidth+1)*(ScreenHeight+1),#0);
    ScreenMode.color:=true;
    ScreenMode.col:=ScreenWidth;
    ScreenMode.row:=ScreenHeight;
    GfvGraph.SysFontWidth:=SysFontWidth;
    GfvGraph.SysFontHeight:=SysFontHeight;
    GfvGraph.TextScreenWidth:=ScreenWidth;
    GfvGraph.TextScreenHeight:=ScreenHeight;
    SetupExtraInfo;
{$endif USE_VIDEO_API}
{$ifdef win32}
    SetGraphHooks;
{$endif}
  end
else
{$endif GRAPH_API}
  begin
{$ifdef USE_VIDEO_API}
    StoreScreenMode:=ScreenMode;
{$endif USE_VIDEO_API}
    Video.InitVideo;
{$ifdef USE_VIDEO_API}
    GetVideoMode(ScreenMode);
    If (StoreScreenMode.color<>ScreenMode.color) or
       (StoreScreenMode.row<>ScreenMode.row) or
       (StoreScreenMode.col<>ScreenMode.col) then
      begin
        Video.SetVideoMode(StoreScreenMode);
        GetVideoMode(ScreenMode);
      end;
{$endif USE_VIDEO_API}
    if ScreenWidth > MaxViewWidth then
      ScreenWidth := MaxViewWidth;
    ScreenWidth:=Video.ScreenWidth;
    ScreenHeight:=Video.ScreenHeight;
    SetViewPort(0,0,ScreenWidth,ScreenHeight,true,true);
    I := ScreenWidth*8 -1;                         { Mouse width }
    J := ScreenHeight*8 -1;                        { Mouse height }
    SysScreenWidth := I + 1;
    SysScreenHeight := J + 1;
    SysFontWidth := 8;                             { Font width }
    SysFontHeight := 8;                            { Font height }
  end;
VideoInitialized:=true;
END;

{---------------------------------------------------------------------------}
{  DoneVideo -> Platforms DOS/DPMI/WIN/NT/OS2 - Updated 19May98 LdB         }
{---------------------------------------------------------------------------}
PROCEDURE DoneVideo;
BEGIN
  if not VideoInitialized then
    exit;
{$ifdef GRAPH_API}
  if Not TextmodeGFV then
    begin
{$ifdef USE_VIDEO_API}
      FreeMem(Video.VideoBuf,sizeof(word)*ScreenWidth*ScreenHeight);
      Video.VideoBuf:=nil;
      FreeMem(Video.OldVideoBuf,sizeof(word)*ScreenWidth*ScreenHeight);
      Video.OldVideoBuf:=nil;
      FreeExtraInfo;
{$endif USE_VIDEO_API}
      CloseGraph;
{$ifdef win32}
    UnsetGraphHooks;
{$endif}
    end
  else
{$endif GRAPH_API}
{$ifdef USE_video_api}
    Video.DoneVideo;
{$else not USE_video_api}
   ; { nothing to do }
{$endif not USE_video_api}
  VideoInitialized:=false;
END;

{---------------------------------------------------------------------------}
{  ClearScreen -> Platforms DOS/DPMI/WIN/NT/OS2 - Updated 04Jan97 LdB       }
{---------------------------------------------------------------------------}
PROCEDURE ClearScreen;
BEGIN
{$ifdef GRAPH_API}
  if Not TextmodeGFV then
    begin
      Graph.ClearDevice;
    end
  else
{$endif GRAPH_API}
{$ifdef USE_video_api}
    Video.ClearScreen;
{$else not USE_video_api}
   ; { nothing to do }
{$endif not USE_video_api}
END;

{---------------------------------------------------------------------------}
{  SetVideoMode -> Platforms DOS/DPMI/WIN/NT/OS2 - Updated 10Nov99 LdB      }
{---------------------------------------------------------------------------}
PROCEDURE SetVideoMode (Mode: Sw_Word);
BEGIN
   If (Mode > $100) Then DefLineNum := 50             { 50 line mode request }
     Else DefLineNum := 24;                           { Normal 24 line mode }
END;

{+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
{                           ERROR CONTROL ROUTINES                          }
{+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}

{---------------------------------------------------------------------------}
{  InitSysError -> Platforms DOS/DPMI/WIN/NT/OS2 - Updated 20May98 LdB      }
{---------------------------------------------------------------------------}
PROCEDURE InitSysError;
BEGIN
   SysErrActive := True;                              { Set active flag }
END;

{---------------------------------------------------------------------------}
{  DoneSysError -> Platforms DOS/DPMI/WIN/NT/OS2 - Updated 20May98 LdB      }
{---------------------------------------------------------------------------}
PROCEDURE DoneSysError;
BEGIN
   SysErrActive := False;                             { Clear active flag }
END;

{---------------------------------------------------------------------------}
{  SystemError -> Platforms DOS/DPMI/WIN/NT/OS2 - Updated 20May98 LdB       }
{---------------------------------------------------------------------------}
FUNCTION SystemError (ErrorCode: Sw_Integer; Drive: Byte): Sw_Integer;
BEGIN
   If (FailSysErrors = False) Then Begin              { Check error ignore }

   End Else SystemError := 1;                         { Return 1 for ignored }
END;

{+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
{                           STRING FORMAT ROUTINES                          }
{+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}

{---------------------------------------------------------------------------}
{  PrintStr -> Platforms DOS/DPMI/WIN/NT/OS2 - Updated 18Feb99 LdB          }
{---------------------------------------------------------------------------}
PROCEDURE PrintStr (CONST S: String);
BEGIN
   Write(S);                                          { Write to screen }
END;

{---------------------------------------------------------------------------}
{  FormatStr -> Platforms DOS/DPMI/WIN/NT/OS2 - Updated 13Jul99 LdB         }
{---------------------------------------------------------------------------}
PROCEDURE FormatStr (Var Result: String; CONST Format: String; Var Params);
TYPE TLongArray = Array[0..0] Of LongInt;
VAR ResultLength, FormatIndex, Justify, Wth: Byte; Fill: Char; S: String;

   FUNCTION LongToStr (L: Longint; Radix: Byte): String;
   CONST HexChars: Array[0..15] Of Char =
    ('0', '1', '2', '3', '4', '5', '6', '7',
     '8', '9', 'A', 'B', 'C', 'D', 'E', 'F');
   VAR I: LongInt; S: String; Sign: String[1];
   BEGIN
     LongToStr := '';                                 { Preset empty return }
     If (L < 0) Then Begin                            { If L is negative }
       Sign := '-';                                   { Sign is negative }
       L := Abs(L);                                   { Convert to positive }
     End Else Sign := '';                             { Sign is empty }
     S := '';                                         { Preset empty string }
     Repeat
       I := L MOD Radix;                              { Radix mod of value }
       S := HexChars[I] + S;                          { Add char to string }
       L := L DIV Radix;                              { Divid by radix }
     Until (L = 0);                                   { Until no remainder }
     LongToStr := Sign + S;                           { Return result }
   END;

   PROCEDURE HandleParameter (I : LongInt);
   BEGIN
     While (FormatIndex <= Length(Format)) Do Begin   { While length valid }
       While (Format[FormatIndex] <> '%') AND         { Param char not found }
       (FormatIndex <= Length(Format)) Do Begin       { Length still valid }
         Result[ResultLength+1] := Format[FormatIndex]; { Transfer character }
         Inc(ResultLength);                           { One character added }
         Inc(FormatIndex);                            { Next param char }
       End;
       If (FormatIndex < Length(Format)) AND          { Not last char and }
       (Format[FormatIndex] = '%') Then Begin         { '%' char found }
         Fill := ' ';                                 { Default fill char }
         Justify := 0;                                { Default justify }
         Wth := 0;                                    { Default 0=no width }
         Inc(FormatIndex);                            { Next character }
         If (Format[FormatIndex] = '0') Then
           Fill := '0';                               { Fill char to zero }
         If (Format[FormatIndex] = '-') Then Begin    { Optional just char }
           Justify := 1;                              { Right justify }
           Inc(FormatIndex);                          { Next character }
         End;
         While ((FormatIndex <= Length(Format)) AND   { Length still valid }
         (Format[FormatIndex] >= '0') AND
         (Format[FormatIndex] <= '9')) Do Begin       { Numeric character }
           Wth := Wth * 10;                           { Multiply x10 }
           Wth := Wth + Ord(Format[FormatIndex])-$30; { Add numeric value }
           Inc(FormatIndex);                          { Next character }
         End;
         If ((FormatIndex <= Length(Format)) AND      { Length still valid }
         (Format[FormatIndex] = '#')) Then Begin      { Parameter marker }
           Inc(FormatIndex);                          { Next character }
           HandleParameter(Wth);                      { Width is param idx }
         End;
         If (FormatIndex <= Length(Format)) Then Begin{ Length still valid }
           Case Format[FormatIndex] Of
             'c': S := Char(TLongArray(Params)[I]);  { Character parameter }
             'd': S := LongToStr(TLongArray(Params)[I],
               10);                                   { Decimal parameter }
             's': S := PString(TLongArray(Params)[I])^;{ String parameter }
             'x': S := LongToStr(TLongArray(Params)[I],
               16);                                   { Hex parameter }
             '%': Begin                               { Literal % }
               S := '%';                              { Set string }
               Inc(FormatIndex);                      { Next character }
               Move(S[1], Result[ResultLength+1], 1); { '%' char to result }
               Inc(ResultLength, Length(S));          { Inc result length }
               Continue;                              { Now continue }
             End;
           End;
           Inc(I);                                    { Next parameter }
           Inc(FormatIndex);                          { Next character }
           If (Wth > 0) Then Begin                    { Width control active }
             If (Length(S) > Wth) Then Begin          { We must shorten S }
               If (Justify=1) Then                    { Check right justify }
                 S := Copy(S, Length(S)-Wth+1, Wth)   { Take right side data }
                 Else S := Copy(S, 1, Wth);           { Take left side data }
             End Else Begin                           { We must pad out S }
               If (Justify=1) Then                    { Right justify }
                 While (Length(S) < Wth) Do
                   S := S+Fill Else                   { Right justify fill }
                 While (Length(S) < Wth) Do
                   S := Fill + S;                     { Left justify fill }
             End;
           End;
           Move(S[1], Result[ResultLength+1],
             Length(S));                              { Move data to result }
           ResultLength := ResultLength + Length(S);  { Adj result length }
         End;
       End;
     End;
   END;

BEGIN
   ResultLength := 0;                                 { Zero result length }
   FormatIndex := 1;                                  { Format index to 1 }
   HandleParameter(0);                                { Handle parameter }
   SetLength(Result, ResultLength);                   { Set string length }
END;

{+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
{                    NEW QUEUED EVENT HANDLER ROUTINES                      }
{+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}

{---------------------------------------------------------------------------}
{  PutEventInQueue -> Platforms DOS/DPMI/WIN/NT/OS2 - Updated 17Mar98 LdB   }
{---------------------------------------------------------------------------}
FUNCTION PutEventInQueue (Var Event: TEvent): Boolean;
BEGIN
   If (QueueCount < QueueMax) Then Begin              { Check room in queue }
     Queue[QueueHead] := Event;                       { Store event }
     Inc(QueueHead);                                  { Inc head position }
     If (QueueHead = QueueMax) Then QueueHead := 0;   { Roll to start check }
     Inc(QueueCount);                                 { Inc queue count }
     PutEventInQueue := True;                         { Return successful }
   End Else PutEventInQueue := False;                 { Return failure }
END;

{---------------------------------------------------------------------------}
{  NextQueuedEvent -> Platforms DOS/DPMI/WIN/NT/OS2 - Updated 17Mar98 LdB   }
{---------------------------------------------------------------------------}
PROCEDURE NextQueuedEvent(Var Event: TEvent);
BEGIN
   If (QueueCount > 0) Then Begin                     { Check queued event }
     Event := Queue[QueueTail];                       { Fetch next event }
     Inc(QueueTail);                                  { Inc tail position }
     If (QueueTail = QueueMax) Then QueueTail := 0;   { Roll to start check }
     Dec(QueueCount);                                 { Dec queue count }
   End Else Event.What := evNothing;                  { Return empty event }
END;

{***************************************************************************}
{                      UNIT INITIALIZATION ROUTINE                          }
{***************************************************************************}
BEGIN
   ButtonCount := DetectMouse;                        { Detect mouse }
   DetectVideo;                                       { Detect video }
   { text mode is the default mode }
   TextModeGFV:=True;
   InitKeyboard;
   {$ifdef Graph_API}
   TextModeGFV:=false;
   {$endif Graph_API}
{$ifdef HasSysMsgUnit}
   InitSystemMsg;
{$endif HasSysMsgUnit}
{$ifdef win32}
   SetFileApisToOEM;
   SetConsoleCP(437);
   SetConsoleOutputCP(437);
{$endif}

   SaveExit := ExitProc;                              { Save old exit }
   ExitProc := @ExitDrivers;                          { Set new exit }
END.
{
 $Log$
 Revision 1.35  2002-09-22 19:42:22  hajny
   + FPC/2 support added

 Revision 1.34  2002/09/13 22:24:30  pierre
  * fix Alt+'9' recognition in GetAltChar function

 Revision 1.33  2002/09/13 09:21:15  pierre
  * don't call InitVideo in DetectVideo procedure

 Revision 1.32  2002/09/09 08:04:05  pierre
  * remove all warnings about far

 Revision 1.31  2002/09/07 15:06:36  peter
   * old logs removed and tabs fixed

 Revision 1.30  2002/06/10 19:40:14  pierre
  * add DoneMouse in DoneEvents

 Revision 1.29  2002/06/10 18:16:55  pierre
  * set Event.What to evNothing if no event in GetSystemEvent

 Revision 1.28  2002/06/07 14:08:28  pierre
  * try to get resizing to work

 Revision 1.27  2002/06/06 20:33:35  pierre
  * remove system event by calling sysmsg.getsystemevent

 Revision 1.26  2002/06/06 13:57:50  pierre
  + activate/desactivate system messages

 Revision 1.25  2002/06/06 06:43:29  pierre
  * avoid more than 132 columns, to avoid TDrawBuffer overrun

 Revision 1.24  2002/06/04 11:12:41  marco
  * Renamefest

 Revision 1.23  2002/05/31 12:38:37  pierre
  * try to enhance graph mode

 Revision 1.22  2002/05/29 21:21:54  pierre
  * Use VGAHi for go32v2 graph version for now

 Revision 1.21  2002/05/29 19:36:12  pierre
  * fix graph related problems

 Revision 1.20  2002/05/28 19:14:35  pierre
  * adapt to new GraphUpdateScreen function

 Revision 1.19  2002/05/24 10:36:52  pierre
  * Try to enhance win32 special chars support

 Revision 1.18  2002/05/24 09:36:33  pierre
  + use win32gr unit to add mouse and keyboard support for win32 graph

 Revision 1.17  2002/05/23 15:07:31  pierre
  * compute graphic size correctly

 Revision 1.16  2002/05/23 06:34:06  pierre
  * fix go32v2 build failure

 Revision 1.15  2002/05/21 12:21:53  pierre
  * fix various graphic problems

 Revision 1.14  2002/05/16 20:21:50  pierre
  + fix for bug report 1953 adapted from S Wiktor

}
{******************[ REVISION HISTORY ]********************}
{  Version  Date        Fix                                }
{  -------  ---------   ---------------------------------  }
{  1.00     26 Jul 96   First DOS/DPMI platform release    }
{  1.10     18 Nov 97   Windows conversion added.          }
{  1.20     29 Aug 97   Platform.inc sort added.           }
{  1.30     10 Jun 98   Virtual pascal 2.0 code added.     }
{  1.40     13 Jul 98   Added FormatStr by Marco Schmidt.  }
{  1.50     14 Jul 98   Fixed width = 0 in FormatStr.      }
{  1.60     13 Aug 98   Complete rewrite of FormatStr.     }
{  1.70     10 Sep 98   Added mouse int hook for FPC.      }
{  1.80     10 Sep 98   Checks run & commenting added.     }
{  1.90     15 Oct 98   Fixed for FPC version 0.998        }
{  1.91     18 Feb 99   Added PrintStr functions           }
{  1.92     18 Feb 99   FormatStr literal '%' fix added    }
{  1.93     10 Jul 99   Sybil 2.0 code added               }
{  1.94     15 Jul 99   Fixed for FPC 0.9912 release       }
{  1.95     26 Jul 99   Windows..Scales to GFV system font }
{  1.96     30 Jul 99   Fixed Ctrl+F1..F10 in GetKeyEvent  }
{  1.97     07 Sep 99   InitEvent, DoneEvent fixed for OS2 }
{  1.98     09 Sep 99   GetMouseEvent fixed for OS2.       }
{  1.99     03 Nov 99   FPC windows support added.         }
{  2.00     26 Nov 99   Graphics stuff moved to GFVGraph   }
{  2.01     21 May 00   DOS fixed to use std GRAPH unit    }
{**********************************************************}
