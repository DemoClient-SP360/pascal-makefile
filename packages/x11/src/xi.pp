{
 $Xorg: XI.h,v 1.4 2001/02/09 02:03:23 xorgcvs Exp $

************************************************************

Copyright 1989, 1998  The Open Group

Permission to use, copy, modify, distribute, and sell this software and its
documentation for any purpose is hereby granted without fee, provided that
the above copyright notice appear in all copies and that both that
copyright notice and this permission notice appear in supporting
documentation.

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
OPEN GROUP BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN
AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

Except as contained in this notice, the name of The Open Group shall not be
used in advertising or otherwise to promote the sale, use or other dealings
in this Software without prior written authorization from The Open Group.

Copyright 1989 by Hewlett-Packard Company, Palo Alto, California.

                        All Rights Reserved

Permission to use, copy, modify, and distribute this software and its
documentation for any purpose and without fee is hereby granted,
provided that the above copyright notice appear in all copies and that
both that copyright notice and this permission notice appear in
supporting documentation, and that the name of Hewlett-Packard not be
used in advertising or publicity pertaining to distribution of the
software without specific, written prior permission.

HEWLETT-PACKARD DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE, INCLUDING
ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS, IN NO EVENT SHALL
HEWLETT-PACKARD BE LIABLE FOR ANY SPECIAL, INDIRECT OR CONSEQUENTIAL DAMAGES OR
ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS,
WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION,
ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS
SOFTWARE.

********************************************************/
 $XFree86: xc/include/extensions/XI.h,v 1.5 2001/12/14 19:53:28 dawes Exp $

 Definitions used by the server, library and client

        Pascal Convertion was made by Ido Kannner - kanerido@actcom.net.il

Histroy:
        2004/10/15 - Fixed a bug of accessing second based records by removing "paced record" and chnaged it to
                     "reocrd" only.
        2004/10/07 - Removed the "uses X;" line. The unit does not need it.
        2004/10/03 - Conversion from C header to Pascal unit.
}
{$PACKRECORDS C} {$MACRO ON} {$DEFINE MACROS}
{$MODE OBJFPC}
{$IFNDEF FPC_DOTTEDUNITS}
unit xi;
{$ENDIF FPC_DOTTEDUNITS}
interface

{$IFDEF FPC_DOTTEDUNITS}
uses
  System.CTypes;
{$ELSE FPC_DOTTEDUNITS}
uses
  ctypes;
{$ENDIF FPC_DOTTEDUNITS}

const
        sz_xGetExtensionVersionReq           =  8;
        sz_xGetExtensionVersionReply         = 32;
        sz_xListInputDevicesReq              =  4;
        sz_xListInputDevicesReply            = 32;
        sz_xOpenDeviceReq                    =  8;
        sz_xOpenDeviceReply                  = 32;
        sz_xCloseDeviceReq                   =  8;
        sz_xSetDeviceModeReq                 =  8;
        sz_xSetDeviceModeReply               = 32;
        sz_xSelectExtensionEventReq          = 12;
        sz_xGetSelectedExtensionEventsReq    =  8;
        sz_xGetSelectedExtensionEventsReply  = 32;
        sz_xChangeDeviceDontPropagateListReq = 12;
        sz_xGetDeviceDontPropagateListReq    =  8;
        sz_xGetDeviceDontPropagateListReply  = 32;
        sz_xGetDeviceMotionEventsReq         = 16;
        sz_xGetDeviceMotionEventsReply       = 32;
        sz_xChangeKeyboardDeviceReq          =  8;
        sz_xChangeKeyboardDeviceReply        = 32;
        sz_xChangePointerDeviceReq           =  8;
        sz_xChangePointerDeviceReply         = 32;
        sz_xGrabDeviceReq                    = 20;
        sz_xGrabDeviceReply                  = 32;
        sz_xUngrabDeviceReq                  = 12;
        sz_xGrabDeviceKeyReq                 = 20;
        sz_xGrabDeviceKeyReply               = 32;
        sz_xUngrabDeviceKeyReq               = 16;
        sz_xGrabDeviceButtonReq              = 20;
        sz_xGrabDeviceButtonReply            = 32;
        sz_xUngrabDeviceButtonReq            = 16;
        sz_xAllowDeviceEventsReq             = 12;
        sz_xGetDeviceFocusReq                =  8;
        sz_xGetDeviceFocusReply              = 32;
        sz_xSetDeviceFocusReq                = 16;
        sz_xGetFeedbackControlReq            =  8;
        sz_xGetFeedbackControlReply          = 32;
        sz_xChangeFeedbackControlReq         = 12;
        sz_xGetDeviceKeyMappingReq           =  8;
        sz_xGetDeviceKeyMappingReply         = 32;
        sz_xChangeDeviceKeyMappingReq        =  8;
        sz_xGetDeviceModifierMappingReq      =  8;
        sz_xSetDeviceModifierMappingReq      =  8;
        sz_xSetDeviceModifierMappingReply    = 32;
        sz_xGetDeviceButtonMappingReq        =  8;
        sz_xGetDeviceButtonMappingReply      = 32;
        sz_xSetDeviceButtonMappingReq        =  8;
        sz_xSetDeviceButtonMappingReply      = 32;
        sz_xQueryDeviceStateReq              =  8;
        sz_xQueryDeviceStateReply            = 32;
        sz_xSendExtensionEventReq            = 16;
        sz_xDeviceBellReq                    =  8;
        sz_xSetDeviceValuatorsReq            =  8;
        sz_xSetDeviceValuatorsReply          = 32;
        sz_xGetDeviceControlReq              =  8;
        sz_xGetDeviceControlReply            = 32;
        sz_xChangeDeviceControlReq           =  8;
        sz_xChangeDeviceControlReply         = 32;
        sz_xListDevicePropertiesReq          =  8;
        sz_xListDevicePropertiesReply        = 32;
        sz_xChangeDevicePropertyReq          = 20;
        sz_xDeleteDevicePropertyReq          = 12;
        sz_xGetDevicePropertyReq             = 24;
        sz_xGetDevicePropertyReply           = 32;

const
        INAME  = 'XInputExtension';

const
        XI_KEYBOARD    = 'KEYBOARD';
        XI_MOUSE       = 'MOUSE';
        XI_TABLET      = 'TABLET';
        XI_TOUCHSCREEN = 'TOUCHSCREEN';
        XI_TOUCHPAD    = 'TOUCHPAD';
        XI_BARCODE     = 'BARCODE';
        XI_BUTTONBOX   = 'BUTTONBOX';
        XI_KNOB_BOX    = 'KNOB_BOX';
        XI_ONE_KNOB    = 'ONE_KNOB';
        XI_NINE_KNOB   = 'NINE_KNOB';
        XI_TRACKBALL   = 'TRACKBALL';
        XI_QUADRATURE  = 'QUADRATURE';
        XI_ID_MODULE   = 'ID_MODULE';
        XI_SPACEBALL   = 'SPACEBALL';
        XI_DATAGLOVE   = 'DATAGLOVE';
        XI_EYETRACKER  = 'EYETRACKER';
        XI_CURSORKEYS  = 'CURSORKEYS';
        XI_FOOTMOUSE   = 'FOOTMOUSE';
        XI_JOYSTICK    = 'JOYSTICK';

const
        Dont_Check                      = 0;
        XInput_Initial_Release          = 1;
        XInput_Add_XDeviceBell          = 2;
        XInput_Add_XSetDeviceValuators  = 3;
        XInput_Add_XChangeDeviceControl = 4;
        XInput_Add_DevicePresenceNotify = 5;
        XInput_Add_DeviceProperties     = 6;

const
        XI_Absent  = 0;
        XI_Present = 1;

const
        XI_Initial_Release_Major = 1;
        XI_Initial_Release_Minor = 0;

const
        XI_Add_XDeviceBell_Major = 1;
        XI_Add_XDeviceBell_Minor = 1;

const
        XI_Add_XSetDeviceValuators_Major = 1;
        XI_Add_XSetDeviceValuators_Minor = 2;

const
        XI_Add_XChangeDeviceControl_Major = 1;
        XI_Add_XChangeDeviceControl_Minor = 3;

const
        XI_Add_DevicePresenceNotify_Major = 1;
        XI_Add_DevicePresenceNotify_Minor = 4;

const
        XI_Add_DeviceProperties_Major = 1;
        XI_Add_DeviceProperties_Minor = 5;

const
        DEVICE_RESOLUTION = 1;
        DEVICE_ABS_CALIB  = 2;
        DEVICE_CORE       = 3;
        DEVICE_ENABLE     = 4;
        DEVICE_ABS_AREA   = 5;

const
        NoSuchExtension = 1;

const
        COUNT  = 0;
        CREATE = 1;

const
        NewPointer  = 0;
        NewKeyboard = 1;

const
        XPOINTER  = 0;
        XKEYBOARD = 1;

const
        UseXKeyboard = $FF;

const
        IsXPointer         = 0;
        IsXKeyboard        = 1;
        IsXExtensionDevice = 2;
        IsXExtensionKeyboard = 3;
        IsXExtensionPointer  = 4;

const
        AsyncThisDevice   = 0;
        SyncThisDevice    = 1;
        ReplayThisDevice  = 2;
        AsyncOtherDevices = 3;
        AsyncAll          = 4;
        SyncAll           = 5;

const
        FollowKeyboard = 3;
{$ifndef RevertToFollowKeyboard}
        {$IFDEF MACROS}
                {$define RevertToFollowKeyboard := 3}
        {$ELSE}
                RevertToFollowKeyboard = 3;
        {$ENDIF}
{$ENDIF}

const
        DvAccelNum   = Cardinal(1) shl 0;
        DvAccelDenom = Cardinal(1) shl 1;
        DvThreshold  = Cardinal(1) shl 2;

const
        DvKeyClickPercent = Cardinal(1) shl 0;
        DvPercent         = Cardinal(1) shl 1;
        DvPitch           = Cardinal(1) shl 2;
        DvDuration        = Cardinal(1) shl 3;
        DvLed             = Cardinal(1) shl 4;
        DvLedMode         = Cardinal(1) shl 5;
        DvKey             = Cardinal(1) shl 6;
        DvAutoRepeatMode  = Cardinal(1) shl 7;

const
        DvString = Cardinal(1) shl 0;

const
        DvInteger = Cardinal(1) shl 0;

const
        DeviceMode         = Cardinal(1) shl 0;
        Relative           =  0;
        Absolute           =  1;
{ Merged from Metrolink tree for XINPUT stuff }
        TS_Raw             = 57;
        TS_Scaled          = 58;
        SendCoreEvents     = 59;
        DontSendCoreEvents = 60;
{ End of merged section }

const
        ProximityState = Cardinal(1) shl 1;
        InProximity    = Cardinal(0) shl 1;
        OutOfProximity = Cardinal(1) shl 1;

const
        AddToList      = 0;
        DeleteFromList = 1;

const
        KeyClass       = 0;
        ButtonClass    = 1;
        ValuatorClass  = 2;
        FeedbackClass  = 3;
        ProximityClass = 4;
        FocusClass     = 5;
        OtherClass     = 6;
        AttachClass    = 7;

const
        KbdFeedbackClass     = 0;
        PtrFeedbackClass     = 1;
        StringFeedbackClass  = 2;
        IntegerFeedbackClass = 3;
        LedFeedbackClass     = 4;
        BellFeedbackClass    = 5;

const
        _devicePointerMotionHint = 0;
        _deviceButton1Motion     = 1;
        _deviceButton2Motion     = 2;
        _deviceButton3Motion     = 3;
        _deviceButton4Motion     = 4;
        _deviceButton5Motion     = 5;
        _deviceButtonMotion      = 6;
        _deviceButtonGrab        = 7;
        _deviceOwnerGrabButton   = 8;
        _noExtensionEvent        = 9;

const
        _devicePresence = 0;

const
        _deviceEnter = 0;
        _deviceLeave = 1;

const
        DeviceAdded          = 0;
        DeviceRemoved        = 1;
        DeviceEnabled        = 2;
        DeviceDisabled       = 3;
        DeviceUnrecoverable  = 4;
        DeviceControlChanged = 5;

const
        XI_BadDevice  = 0;
        XI_BadEvent   = 1;
        XI_BadMode    = 2;
        XI_DeviceBusy = 3;
        XI_BadClass   = 4;

{ Make XEventClass be a CARD32 for 64 bit servers.  Don't affect client
  definition of XEventClass since that would be a library interface change.
  See the top of X.h for more _XSERVER64 magic.

  But, don't actually use the CARD32 type.  We can't get it defined here
  without polluting the namespace.
}
type
{$ifdef _XSERVER64}
        XEventClass = cuint;
{$ELSE}
        XEventClass = culong;
{$ENDIF}
        PPXEventClass = ^PXEventClass;
        PXEventClass = ^TXEventClass;
        TXEventClass = XEventClass;

(*******************************************************************
 *
 * Extension version structure.
 *
 *)

type
        PXExtensionVersion = ^TXExtensionVersion;
        TXExtensionVersion = record
                              present       : cint;
                              major_version : cshort;
                              minor_version : cshort;
                             end;

implementation

end.
