{
   $Id$
}

{****************************************************************************
                                 Interface
****************************************************************************}

{$ifdef read_interface}

{$ifndef gtkwin}
function  GDK_GET_ROOT_WINDOW : PGdkWindow;
function  GDK_GET_ROOT_PARENT : PGdkWindow;
function  GDK_GET_XDISPLAY : PDisplay;
function  GDK_WINDOW_XDISPLAY(win : PGdkWindowPrivate) : PDisplay;
function  GDK_WINDOW_XWINDOW(win : PGdkWindowPrivate) : Twindow;
function  GDK_IMAGE_XDISPLAY(image : PGdkImagePrivate) : PDisplay;
function  GDK_IMAGE_XIMAGE(image : PGdkImagePrivate) : PXImage;
function  GDK_GC_XDISPLAY(gc : PGdkGCPrivate) : PDisplay;
function  GDK_GC_XGC(gc : PGdkGCPrivate) : TGC;
function  GDK_COLORMAP_XDISPLAY(cmap : PGdkColorMapPrivate) : PDisplay;
function  GDK_COLORMAP_XCOLORMAP(cmap : PGdkColorMapPrivate) : TColorMap;
function  GDK_VISUAL_XVISUAL(vis : PGdkVisualPrivate) : PVisual;
function  GDK_FONT_XDISPLAY(font : PGdkFontPrivate) : PDisplay;
function  GDK_FONT_XFONT(font : PGdkFontPrivate) : gpointer;

function  gdkx_visual_get(xvisualid:TVisualID):PGdkVisual;cdecl;external gdkdll name 'gdkx_visual_get';
function  gdkx_colormap_get(xcolormap:TColormap):PGdkColormap;cdecl;external gdkdll name 'gdkx_colormap_get';
function  gdk_get_client_window(dpy:pDisplay; win:TWindow):TWindow;cdecl;external gdkdll name 'gdk_get_client_window';
function  gdk_pixmap_foreign_new(anid:guint32):PGdkPixmap;cdecl;external gdkdll name 'gdk_pixmap_foreign_new';
function  gdk_window_foreign_new(anid:guint32):PGdkWindow;cdecl;external gdkdll name 'gdk_window_foreign_new';
{$endif}

{$endif read_interface}


{****************************************************************************
                              Implementation
****************************************************************************}

{$ifdef read_implementation}

{$ifndef gtkwin}
function  GDK_GET_ROOT_WINDOW : PGdkWindow;
    begin
       GDK_GET_ROOT_WINDOW:=PGdkwindow(gdk_root_window);
    end;

function  GDK_GET_ROOT_PARENT : PGdkWindow;
    begin
       GDK_GET_ROOT_PARENT:=PGdkWindow(@(gdk_root_parent));
    end;

function  GDK_GET_XDISPLAY : PDisplay;
    begin
       GDK_GET_XDISPLAY:=gdk_display;
    end;

function  GDK_WINDOW_XDISPLAY(win : PGdkWindowPrivate) : PDisplay;
    begin
       GDK_WINDOW_XDISPLAY:=(PGdkWindowPrivate(win))^.xdisplay;
    end;

function  GDK_WINDOW_XWINDOW(win : PGdkWindowPrivate) : Twindow;
    begin
       GDK_WINDOW_XWINDOW:=(PGdkWindowPrivate(win))^.xwindow;
    end;

function  GDK_IMAGE_XDISPLAY(image : PGdkImagePrivate) : PDisplay;
    begin
       GDK_IMAGE_XDISPLAY:=(PGdkImagePrivate(image))^.xdisplay;
    end;

function  GDK_IMAGE_XIMAGE(image : PGdkImagePrivate) : PXImage;
    begin
       GDK_IMAGE_XIMAGE:=(PGdkImagePrivate(image))^.ximage;
    end;

function  GDK_GC_XDISPLAY(gc : PGdkGCPrivate) : PDisplay;
    begin
       GDK_GC_XDISPLAY:=(PGdkGCPrivate(gc))^.xdisplay;
    end;

function  GDK_GC_XGC(gc : PGdkGCPrivate) : TGC;
    begin
       GDK_GC_XGC:=(PGdkGCPrivate(gc))^.xgc;
    end;

function  GDK_COLORMAP_XDISPLAY(cmap : PGdkColorMapPrivate) : PDisplay;
    begin
       GDK_COLORMAP_XDISPLAY:=(PGdkColormapPrivate(cmap))^.xdisplay;
    end;

function  GDK_COLORMAP_XCOLORMAP(cmap : PGdkColorMapPrivate) : TColorMap;
    begin
       GDK_COLORMAP_XCOLORMAP:=(PGdkColormapPrivate(cmap))^.xcolormap;
    end;

function  GDK_VISUAL_XVISUAL(vis : PGdkVisualPrivate) : PVisual;
    begin
       GDK_VISUAL_XVISUAL:=(PGdkVisualPrivate(vis))^.xvisual;
    end;

function  GDK_FONT_XDISPLAY(font : PGdkFontPrivate) : PDisplay;
    begin
       GDK_FONT_XDISPLAY:=(PGdkFontPrivate(font))^.xdisplay;
    end;

function  GDK_FONT_XFONT(font : PGdkFontPrivate) : gpointer;
    begin
       GDK_FONT_XFONT:=(PGdkFontPrivate(font))^.xfont;
    end;

{$endif}

{$endif read_implementation}


{
  $Log$
  Revision 1.1  2000-07-13 06:34:02  michael
  + Initial import

  Revision 1.1  1999/11/24 23:36:33  peter
    * moved to packages dir

  Revision 1.5  1999/10/21 14:35:23  peter
    * removed glibdll constant

  Revision 1.4  1999/10/06 17:42:47  peter
    * external is now only in the interface
    * removed gtk 1.0 support

  Revision 1.3  1999/05/11 00:37:55  peter
    * win32 fixes

  Revision 1.2  1999/05/07 15:09:44  peter
    * more fixes

  Revision 1.1  1999/05/07 10:40:22  peter
    * first things for 1.2

}

