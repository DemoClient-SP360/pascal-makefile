{ list of all dos scancode for key giving 0 as AnsiChar }
Const
   kbNoKey       = $00;
   kbAltEsc      = $01;  {Alt+Esc = scancode 01, ascii code 0.}
   kbEsc         = $01;  {Esc     = scancode 01, ascii code 27.}
   kbAltSpace    = $02;
   kbCtrlIns     = $04;
   kbShiftIns    = $05;
   kbCtrlDel     = $06;
   kbShiftDel    = $07;
   kbAltBack     = $08;
   kbAltShiftBack= $09;
   kbShiftTab    = $0F;
   kbAltQ        = $10;
   kbAltW        = $11;
   kbAltE        = $12;
   kbAltR        = $13;
   kbAltT        = $14;
   kbAltY        = $15;
   kbAltU        = $16;
   kbAltI        = $17;
   kbAltO        = $18;
   kbAltP        = $19;
   kbAltLftBrack = $1A;
   kbAltRgtBrack = $1B;
   kbAltA        = $1E;
   kbAltS        = $1F;
   kbAltD        = $20;
   kbAltF        = $21;
   kbAltG        = $22;
   kbAltH        = $23;
   kbAltJ        = $24;
   kbAltK        = $25;
   kbAltL        = $26;
   kbAltSemiCol  = $27;
   kbAltQuote    = $28;
   kbAltOpQuote  = $29;
   kbAltBkSlash  = $2B;
   kbAltZ        = $2C;
   kbAltX        = $2D;
   kbAltC        = $2E;
   kbAltV        = $2F;
   kbAltB        = $30;
   kbAltN        = $31;
   kbAltM        = $32;
   kbAltComma    = $33;
   kbAltPeriod   = $34;
   kbAltSlash    = $35;
   kbAltGreyAst  = $37;
   kbF1          = $3B;
   kbF2          = $3C;
   kbF3          = $3D;
   kbF4          = $3E;
   kbF5          = $3F;
   kbF6          = $40;
   kbF7          = $41;
   kbF8          = $42;
   kbF9          = $43;
   kbF10         = $44;
   kbHome        = $47;
   kbUp          = $48;
   kbPgUp        = $49;
   kbLeft        = $4B;
   kbCenter      = $4C;
   kbRight       = $4D;
   kbAltGrayPlus = $4E;
   kbend         = $4F;
   kbDown        = $50;
   kbPgDn        = $51;
   kbIns         = $52;
   kbDel         = $53;
   kbShiftF1     = $54;
   kbShiftF2     = $55;
   kbShiftF3     = $56;
   kbShiftF4     = $57;
   kbShiftF5     = $58;
   kbShiftF6     = $59;
   kbShiftF7     = $5A;
   kbShiftF8     = $5B;
   kbShiftF9     = $5C;
   kbShiftF10    = $5D;
   kbCtrlF1      = $5E;
   kbCtrlF2      = $5F;
   kbCtrlF3      = $60;
   kbCtrlF4      = $61;
   kbCtrlF5      = $62;
   kbCtrlF6      = $63;
   kbCtrlF7      = $64;
   kbCtrlF8      = $65;
   kbCtrlF9      = $66;
   kbCtrlF10     = $67;
   kbAltF1       = $68;
   kbAltF2       = $69;
   kbAltF3       = $6A;
   kbAltF4       = $6B;
   kbAltF5       = $6C;
   kbAltF6       = $6D;
   kbAltF7       = $6E;
   kbAltF8       = $6F;
   kbAltF9       = $70;
   kbAltF10      = $71;
   kbCtrlPrtSc   = $72;
   kbCtrlLeft    = $73;
   kbCtrlRight   = $74;
   kbCtrlend     = $75;
   kbCtrlPgDn    = $76;
   kbCtrlHome    = $77;
   kbAlt1        = $78;
   kbAlt2        = $79;
   kbAlt3        = $7A;
   kbAlt4        = $7B;
   kbAlt5        = $7C;
   kbAlt6        = $7D;
   kbAlt7        = $7E;
   kbAlt8        = $7F;
   kbAlt9        = $80;
   kbAlt0        = $81;
   kbAltMinus    = $82;
   kbAltEqual    = $83;
   kbCtrlPgUp    = $84;
   kbF11         = $85;
   kbF12         = $86;
   kbShiftF11    = $87;
   kbShiftF12    = $88;
   kbCtrlF11     = $89;
   kbCtrlF12     = $8A;
   kbAltF11      = $8B;
   kbAltF12      = $8C;
   kbCtrlUp      = $8D;
   kbCtrlMinus   = $8E;
   kbCtrlCenter  = $8F;
   kbCtrlGreyPlus= $90;
   kbCtrlDown    = $91;
   kbCtrlTab     = $94;
   kbAltHome     = $97;
   kbAltUp       = $98;
   kbAltPgUp     = $99;
   kbAltLeft     = $9B;
   kbAltRight    = $9D;
   kbAltend      = $9F;
   kbAltDown     = $A0;
   kbAltPgDn     = $A1;
   kbAltIns      = $A2;
   kbAltDel      = $A3;
   kbAltTab      = $A5;
