{ shows a problem of name mangling  }
Unit tbs0181a;

Interface

  type mylongint = longint;
       mylongint2 = mylongint;

  procedure dummy(var l : mylongint);

Implementation

  var l : longint;

  procedure use_before_implemented;
    begin
       dummy(l);
    end;

  procedure dummy(var l : mylongint2);
    begin
       l:=78;
    end;

begin
   use_before_implemented;
end.
