{
  $Id$

  Translation of the GLaux headers for FreePascal
  Version for static linking in Win32 environment by Alexander Stohr.
  Latest change: 1999-11-13

  Further information:

  GLaux is an outdated toolkit from SGI and later used by Microsoft.
}
{*++ BUILD Version: 0004    // Increment this if a change has global effects

Copyright (c) 1985-95, Microsoft Corporation

Module Name:

    glaux.h

Abstract:

    Procedure declarations, constant definitions and macros for the OpenGL
    Auxiliary Library.

--*}
{*
 * (c) Copyright 1993, Silicon Graphics, Inc.
 * ALL RIGHTS RESERVED
 * Permission to use, copy, modify, and distribute this software for
 * any purpose and without fee is hereby granted, provided that the above
 * copyright notice appear in all copies and that both the copyright notice
 * and this permission notice appear in supporting documentation, and that
 * the name of Silicon Graphics, Inc. not be used in advertising
 * or publicity pertaining to distribution of the software without specific,
 * written prior permission.
 *
 * THE MATERIAL EMBODIED ON THIS SOFTWARE IS PROVIDED TO YOU "AS-IS"
 * AND WITHOUT WARRANTY OF ANY KIND, EXPRESS, IMPLIED OR OTHERWISE,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTY OF MERCHANTABILITY OR
 * FITNESS FOR A PARTICULAR PURPOSE.  IN NO EVENT SHALL SILICON
 * GRAPHICS, INC.  BE LIABLE TO YOU OR ANYONE ELSE FOR ANY DIRECT,
 * SPECIAL, INCIDENTAL, INDIRECT OR CONSEQUENTIAL DAMAGES OF ANY
 * KIND, OR ANY DAMAGES WHATSOEVER, INCLUDING WITHOUT LIMITATION,
 * LOSS OF PROFIT, LOSS OF USE, SAVINGS OR REVENUE, OR THE CLAIMS OF
 * THIRD PARTIES, WHETHER OR NOT SILICON GRAPHICS, INC.  HAS BEEN
 * ADVISED OF THE POSSIBILITY OF SUCH LOSS, HOWEVER CAUSED AND ON
 * ANY THEORY OF LIABILITY, ARISING OUT OF OR IN CONNECTION WITH THE
 * POSSESSION, USE OR PERFORMANCE OF THIS SOFTWARE.
 *
 * US Government Users Restricted Rights
 * Use, duplication, or disclosure by the Government is subject to
 * restrictions set forth in FAR 52.227.19(c)(2) or subparagraph
 * (c)(1)(ii) of the Rights in Technical Data and Computer Software
 * clause at DFARS 252.227-7013 and/or in similar or successor
 * clauses in the FAR or the DOD or NASA FAR Supplement.
 * Unpublished-- rights reserved under the copyright laws of the
 * United States.  Contractor/manufacturer is Silicon Graphics,
 * Inc., 2011 N.  Shoreline Blvd., Mountain View, CA 94039-7311.
 *
 * OpenGL(TM) is a trademark of Silicon Graphics, Inc.
 *}

{$MODE delphi}

{You have to enable Macros (compiler switch "-Sm") for compiling this unit!
 This is necessary for supporting different platforms with different calling
 conventions via a single unit.}

{$define WINNT}
{$define GLauximp}
{x$define UNICODE}

unit GLaux; { version which does statically linking }


interface

{$MACRO ON}

{$IFDEF Win32}
  {$DEFINE glaux_dll := external 'Glauximp.dll'}
  {$DEFINE glaux_callback := cdecl}
{$ELSE}
  {$MESSAGE Unsupported platform.}
{$ENDIF}


USES
  windows,
  GL;
{
}

TYPE
  LPCSTR  = Pointer;   { pointer on a zero terminated string }
  LPCWSTR = Pointer;   { pointer on a zero terminated unicode string }

{*
** ToolKit Window Types
** In the future, AUX_RGBA may be a combination of both RGB and ALPHA
*}

const
    AUX_RGB             = 0;
    AUX_RGBA            = AUX_RGB;
    AUX_INDEX           = 1;
    AUX_SINGLE          = 0;
    AUX_DOUBLE          = 2;
    AUX_DIRECT          = 0;
    AUX_INDIRECT        = 4;

    AUX_ACCUM           = 8;
    AUX_ALPHA           = 16;
    AUX_DEPTH24         = 32;      {* 24-bit depth buffer *}
    AUX_STENCIL         = 64;
    AUX_AUX             = 128;
    AUX_DEPTH16         = 256;     {* 16-bit depth buffer *}
    AUX_FIXED_332_PAL   = 512;
    AUX_DEPTH           = AUX_DEPTH16; {* default is 16-bit depth buffer *}

{*
** Window Masks
*}

{ These have been macros and were converted to boolean funtions }
FUNCTION AUX_WIND_IS_RGB            (x : DWORD) : BOOLEAN;
FUNCTION AUX_WIND_IS_INDEX          (x : DWORD) : BOOLEAN;
FUNCTION AUX_WIND_IS_SINGLE         (x : DWORD) : BOOLEAN;
FUNCTION AUX_WIND_IS_DOUBLE         (x : DWORD) : BOOLEAN;
FUNCTION AUX_WIND_IS_INDIRECT       (x : DWORD) : BOOLEAN;
FUNCTION AUX_WIND_IS_DIRECT         (x : DWORD) : BOOLEAN;
FUNCTION AUX_WIND_HAS_ACCUM         (x : DWORD) : BOOLEAN;
FUNCTION AUX_WIND_HAS_ALPHA         (x : DWORD) : BOOLEAN;
FUNCTION AUX_WIND_HAS_DEPTH         (x : DWORD) : BOOLEAN;
FUNCTION AUX_WIND_HAS_STENCIL       (x : DWORD) : BOOLEAN;
FUNCTION AUX_WIND_USES_FIXED_332_PAL(x : DWORD) : BOOLEAN;

{*
** ToolKit Event Structure
*}
type
    AUX_EVENTREC = RECORD
    {BEGIN}
        event : GLint;
        data  : ARRAY[0..3] OF GLint;
    END;

{*
** ToolKit Event Types
*}
CONST
    AUX_EXPOSE      = 1;
    AUX_CONFIG      = 2;
    AUX_DRAW        = 4;
    AUX_KEYEVENT    = 8;
    AUX_MOUSEDOWN   = 16;
    AUX_MOUSEUP     = 32;
    AUX_MOUSELOC    = 64;

{*
** Toolkit Event Data Indices
*}
    AUX_WINDOWX             = 0;
    AUX_WINDOWY             = 1;
    AUX_MOUSEX              = 0;
    AUX_MOUSEY              = 1;
    AUX_MOUSESTATUS         = 3;
    AUX_KEY                 = 0;
    AUX_KEYSTATUS           = 1;

{*
** ToolKit Event Status Messages
*}
    AUX_LEFTBUTTON          = 1;
    AUX_RIGHTBUTTON         = 2;
    AUX_MIDDLEBUTTON        = 4;
    AUX_SHIFT               = 1;
    AUX_CONTROL             = 2;

{*
** ToolKit Key Codes
*}
    AUX_RETURN              = #$0D;
    AUX_ESCAPE              = #$1B;
    AUX_SPACE               = #$20;
    AUX_LEFT                = #$25;
    AUX_UP                  = #$26;
    AUX_RIGHT               = #$27;
    AUX_DOWN                = #$28;
    AUX_A                   = 'A';
    AUX_B                   = 'B';
    AUX_C                   = 'C';
    AUX_D                   = 'D';
    AUX_E                   = 'E';
    AUX_F                   = 'F';
    AUX_G                   = 'G';
    AUX_H                   = 'H';
    AUX_I                   = 'I';
    AUX_J                   = 'J';
    AUX_K                   = 'K';
    AUX_L                   = 'L';
    AUX_M                   = 'M';
    AUX_N                   = 'N';
    AUX_O                   = 'O';
    AUX_P                   = 'P';
    AUX_Q                   = 'Q';
    AUX_R                   = 'R';
    AUX_S                   = 'S';
    AUX_T                   = 'T';
    AUX_U                   = 'U';
    AUX_V                   = 'V';
    AUX_W                   = 'W';
    AUX_X                   = 'X';
    AUX_Y                   = 'Y';
    AUX_Z                   = 'Z';
    AUX_a_                  = 'a';
    AUX_b_                  = 'b';
    AUX_c_                  = 'c';
    AUX_d_                  = 'd';
    AUX_e_                  = 'e';
    AUX_f_                  = 'f';
    AUX_g_                  = 'g';
    AUX_h_                  = 'h';
    AUX_i_                  = 'i';
    AUX_j_                  = 'j';
    AUX_k_                  = 'k';
    AUX_l_                  = 'l';
    AUX_m_                  = 'm';
    AUX_n_                  = 'n';
    AUX_o_                  = 'o';
    AUX_p_                  = 'p';
    AUX_q_                  = 'q';
    AUX_r_                  = 'r';
    AUX_s_                  = 's';
    AUX_t_                  = 't';
    AUX_u_                  = 'u';
    AUX_v_                  = 'v';
    AUX_w_                  = 'w';
    AUX_x_                  = 'x';
    AUX_y_                  = 'y';
    AUX_z_                  = 'z';
    AUX_0                   = '0';
    AUX_1                   = '1';
    AUX_2                   = '2';
    AUX_3                   = '3';
    AUX_4                   = '4';
    AUX_5                   = '5';
    AUX_6                   = '6';
    AUX_7                   = '7';
    AUX_8                   = '8';
    AUX_9                   = '9';

{*
** ToolKit Gets and Sets
*}
    AUX_FD                  = 1;  {* return fd (long) *}
    AUX_COLORMAP            = 3;  {* pass buf of r, g and b (unsigned char) *}
    AUX_GREYSCALEMAP        = 4;
    AUX_FOGMAP              = 5;  {* pass fog and color bits (long) *}
    AUX_ONECOLOR            = 6;  {* pass index, r, g, and b (long) *}

{*
** Color Macros
*}

    AUX_BLACK               = 0;
    AUX_RED                 = 13;
    AUX_GREEN               = 14;
    AUX_YELLOW              = 15;
    AUX_BLUE                = 16;
    AUX_MAGENTA             = 17;
    AUX_CYAN                = 18;
    AUX_WHITE               = 19;

{ this was a macro and is now a procedure }
{ PROCEDURE AUX_SETCOLOR(x, y); - TODO }

{*
** RGB Image Structure
*}

type
    AUX_RGBImageRec = RECORD
    {BEGIN}
        sizeX, sizeY : GLint;
        data : ^BYTE;
    END;
    pAUX_RGBImageRec = ^AUX_RGBImageRec;

{*
** Prototypes
*}

Procedure auxInitDisplayMode(mode:GLenum); glaux_dll;
Procedure auxInitPosition(x,y,w,h:Integer); glaux_dll;

{$ifndef WINNT}
FUNCTION  auxInitWindow(name:LPCSTR)  : GLenum; glaux_dll;
{$else}
{$ifdef UNICODE }
FUNCTION  auxInitWindow (name:LPCWSTR) : GLenum; glaux_dll name 'auxInitWindowW';
{$else}
FUNCTION  auxInitWindow (name:LPCSTR)  : GLenum; glaux_dll name 'auxInitWindowA';
{$endif}
FUNCTION  auxInitWindowA(name:LPCSTR)  : GLenum; glaux_dll;
FUNCTION  auxInitWindowW(name:LPCWSTR) : GLenum; glaux_dll;
{$endif}

PROCEDURE auxCloseWindow; glaux_dll;
PROCEDURE auxQuit;        glaux_dll;
PROCEDURE auxSwapBuffers; glaux_dll;

{ callbacks }
type
  TAUXMAINPROC    = PROCEDURE;                           glaux_callback;
  TAUXEXPOSEPROC  = PROCEDURE(w, h : integer);           glaux_callback;
  TAUXRESHAPEPROC = PROCEDURE(w, h : GLsizei);           glaux_callback;
  TAUXIDLEPROC    = PROCEDURE;                           glaux_callback;
  TAUXKEYPROC     = PROCEDURE;                           glaux_callback;
  TAUXMOUSEPROC   = PROCEDURE(VAR event : AUX_EVENTREC); glaux_callback;

{ callback setup routines }
PROCEDURE auxMainLoop   (func : TAUXMAINPROC); glaux_dll;
PROCEDURE auxExposeFunc (func : TAUXEXPOSEPROC); glaux_dll;
PROCEDURE auxReshapeFunc(func : TAUXRESHAPEPROC); glaux_dll;
PROCEDURE auxIdleFunc   (func : TAUXIDLEPROC); glaux_dll;
PROCEDURE auxKeyFunc    (val : integer; func : TAUXKEYPROC); glaux_dll;
PROCEDURE auxMouseFunc  (v1, v2 :integer; func : TAUXMOUSEPROC); glaux_dll;

FUNCTION  auxGetColorMapSize : integer; glaux_dll;
PROCEDURE auxGetMouseLoc(var x, y : integer); glaux_dll;
PROCEDURE auxSetOneColor(id : integer; r, g, b : GLfloat); glaux_dll;
PROCEDURE auxSetFogRamp(v1, v2 : integer); glaux_dll;
PROCEDURE auxSetGreyRamp; glaux_dll;
PROCEDURE auxSetRGBMap(id : integer; var map : GLfloat); glaux_dll;

{$ifndef WINNT}
FUNCTION auxRGBImageLoad(name : LPCSTR) : pAUX_RGBImageRec; glaux_dll;
{$else}
{$ifndef GLAUXIMP}{ not present in GLauximp.dll }
{$ifdef UNICODE}
FUNCTION auxRGBImageLoad (name : LPCWSTR): pAUX_RGBImageRec; glaux_dll name 'auxRGBImageLoadW';
{$else}
FUNCTION auxRGBImageLoad (name : LPCSTR) : pAUX_RGBImageRec; glaux_dll name 'auxRGBImageLoadA';
{$endif}
FUNCTION auxRGBImageLoadA(name : LPCSTR) : pAUX_RGBImageRec; glaux_dll;
FUNCTION auxRGBImageLoadW(name : LPCWSTR): pAUX_RGBImageRec; glaux_dll;
{$endif}
{$endif}

{$ifndef WINNT}
{ this function is Windows specific! }
FUNCTION auxDIBImageLoad(name : LPCSTR) : pAUX_RGBImageRec; glaux_dll;
{$else}
{$ifndef GLAUXIMP}{ not present in GLauximp.dll }
{$ifdef UNICODE }
FUNCTION auxDIBImageLoad (name : LPCWSTR): pAUX_RGBImageRec; glaux_dll name 'auxDIBImageLoadW';
{$else}
FUNCTION auxDIBImageLoad (name : LPCSTR) : pAUX_RGBImageRec; glaux_dll name 'auxDIBImageLoadA';
{$endif}
FUNCTION auxDIBImageLoadA(name : LPCSTR) : pAUX_RGBImageRec; glaux_dll;
FUNCTION auxDIBImageLoadW(name : LPCWSTR): pAUX_RGBImageRec; glaux_dll;
{$endif}
{$endif}

PROCEDURE auxCreateFont; glaux_dll;

{$ifndef WINNT}
PROCEDURE auxDrawStr (name : LPCSTR);  glaux_dll;
{$else}
{$ifndef GLAUXIMP}{ not present in GLauximp.dll }
{$ifdef UNICODE }
PROCEDURE auxDrawStr (name : LPCWSTR); glaux_dll name 'auxDrawStrW';
{$else}
PROCEDURE auxDrawStr (name : LPCSTR);  glaux_dll name 'auxDrawStrA';
{$endif}
PROCEDURE auxDrawStrA(name : LPCSTR);  glaux_dll;
PROCEDURE auxDrawStrW(name : LPCWSTR); glaux_dll;
{$endif}
{$endif}

PROCEDURE auxWireSphere(v : GLdouble); glaux_dll;
PROCEDURE auxSolidSphere(v : GLdouble); glaux_dll;
PROCEDURE auxWireCube(v : GLdouble); glaux_dll;
PROCEDURE auxSolidCube(v : GLdouble); glaux_dll;
PROCEDURE auxWireBox(v1, v2, v3 : GLdouble); glaux_dll;
PROCEDURE auxSolidBox(v1, v2, v3 : GLdouble); glaux_dll;
PROCEDURE auxWireTorus(v1, v2 : GLdouble); glaux_dll;
PROCEDURE auxSolidTorus(v1, v2 : GLdouble); glaux_dll;
PROCEDURE auxWireCylinder(v1, v2 : GLdouble); glaux_dll;
PROCEDURE auxSolidCylinder(v1, v2 :  GLdouble); glaux_dll;
PROCEDURE auxWireIcosahedron(v : GLdouble); glaux_dll;
PROCEDURE auxSolidIcosahedron(v : GLdouble); glaux_dll;
PROCEDURE auxWireOctahedron(v : GLdouble); glaux_dll;
PROCEDURE auxSolidOctahedron(v : GLdouble); glaux_dll;
PROCEDURE auxWireTetrahedron(v : GLdouble); glaux_dll;
PROCEDURE auxSolidTetrahedron(v : GLdouble); glaux_dll;
PROCEDURE auxWireDodecahedron(v : GLdouble); glaux_dll;
PROCEDURE auxSolidDodecahedron(v : GLdouble); glaux_dll;
PROCEDURE auxWireCone(v1, v2 : GLdouble); glaux_dll;
PROCEDURE auxSolidCone(v1, v2 : GLdouble); glaux_dll;
PROCEDURE auxWireTeapot(v : GLdouble); glaux_dll;
PROCEDURE auxSolidTeapot(v: GLdouble); glaux_dll;

{*
** Window specific functions
** hwnd, hdc, and hglrc valid after auxInitWindow()
*}
FUNCTION  auxGetHWND : HWND; glaux_dll;
FUNCTION  auxGetHDC : HDC; glaux_dll;
FUNCTION  auxGetHGLRC : HGLRC; glaux_dll;

{*
** Viewperf support functions and constants
*}
{* Display Mode Selection Criteria *}

CONST { was an unnamed enum }
    AUX_USE_ID                  = 1;
    AUX_EXACT_MATCH             = 2;
    AUX_MINIMUM_CRITERIA        = 3;

PROCEDURE auxInitDisplayModePolicy(val : GLenum); glaux_dll;
FUNCTION  auxInitDisplayModeID(val : GLint) : GLenum; glaux_dll;
FUNCTION  auxGetDisplayModePolicy : GLenum; glaux_dll;
FUNCTION  auxGetDisplayModeID : GLint; glaux_dll;
FUNCTION  auxGetDisplayMode : GLenum; glaux_dll;


implementation

{ these functions are resolved macros -
  they should be "inline" if compile can do this }

FUNCTION AUX_WIND_IS_RGB(x : DWORD) : BOOLEAN;
BEGIN
  AUX_WIND_IS_RGB := ((x AND AUX_INDEX) = 0);
END;

FUNCTION AUX_WIND_IS_INDEX(x : DWORD) : BOOLEAN;
BEGIN
  AUX_WIND_IS_INDEX := ((x AND AUX_INDEX) <> 0);
END;

FUNCTION AUX_WIND_IS_SINGLE(x : DWORD) : BOOLEAN;
BEGIN
  AUX_WIND_IS_SINGLE := ((x AND AUX_DOUBLE) = 0);
END;

FUNCTION AUX_WIND_IS_DOUBLE(x : DWORD) : BOOLEAN;
BEGIN
  AUX_WIND_IS_DOUBLE := ((x AND AUX_DOUBLE) <> 0);
END;

FUNCTION AUX_WIND_IS_INDIRECT(x : DWORD) : BOOLEAN;
BEGIN
  AUX_WIND_IS_INDIRECT := ((x AND AUX_INDIRECT) <> 0);
END;

FUNCTION AUX_WIND_IS_DIRECT(x : DWORD) : BOOLEAN;
BEGIN
  AUX_WIND_IS_DIRECT := ((x AND AUX_INDIRECT) = 0);
END;

FUNCTION AUX_WIND_HAS_ACCUM(x : DWORD) : BOOLEAN;
BEGIN
  AUX_WIND_HAS_ACCUM := ((x AND AUX_ACCUM) <> 0);
END;

FUNCTION AUX_WIND_HAS_ALPHA(x : DWORD) : BOOLEAN;
BEGIN
  AUX_WIND_HAS_ALPHA := ((x AND AUX_ALPHA) <> 0);
END;

FUNCTION AUX_WIND_HAS_DEPTH(x : DWORD) : BOOLEAN;
BEGIN
  AUX_WIND_HAS_DEPTH := ((x AND (AUX_DEPTH24 OR AUX_DEPTH16)) <> 0);
END;

FUNCTION AUX_WIND_HAS_STENCIL(x : DWORD) : BOOLEAN;
BEGIN
  AUX_WIND_HAS_STENCIL := ((x AND AUX_STENCIL) <> 0);
END;

FUNCTION AUX_WIND_USES_FIXED_332_PAL(x : DWORD) : BOOLEAN;
BEGIN
  AUX_WIND_USES_FIXED_332_PAL := ((x AND AUX_FIXED_332_PAL) <> 0);
END;

{extern float auxRGBMap[20][3];

PROCEDURE AUX_SETCOLOR(x, y);
BEGIN
  IF (AUX_WIND_IS_RGB((x))
  THEN glColor3fv(auxRGBMap[y])
  ELSE glIndexf(y));
END;
 - TODO}


{begin{of init}
end.


{
  $Log$
  Revision 1.3  2000-10-01 22:17:59  peter
    * new bounce demo

  Revision 1.1.2.2  2000/10/01 22:12:28  peter
    * new demo

}
