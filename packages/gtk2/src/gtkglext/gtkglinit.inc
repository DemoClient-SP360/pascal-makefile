{ Original file is /usr/include/gtkglext-1.0/gtk/gtkglinit.h }

{$ifdef read_interface_rest}

{*
 * Initialization routines.
 *}

function gtk_gl_parse_args(argc: Plongint; argv: PPPAnsiChar): gboolean;
  cdecl; external GtkGLExtLib;
function gtk_gl_init_check(argc: Plongint; argv: PPPAnsiChar): gboolean;
  cdecl; external GtkGLExtLib;
procedure gtk_gl_init(argc: Plongint; argv: PPPAnsiChar);
  cdecl; external GtkGLExtLib;

{$endif read_interface_rest}
