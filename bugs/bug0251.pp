

const
  c : byte = 5;
  r : real = 3.4;
var
  l : longint;
  cc : char;
  rr : real;

begin
  l:=longint(@r);
  if (l mod 4)<>0 then
    begin
       Writeln('static const are not aligned properly !');
    end;
  l:=longint(@rr);
  if (l mod 4)<>0 then
    begin
       Writeln('static var are not aligned properly !');
    end;
end.
