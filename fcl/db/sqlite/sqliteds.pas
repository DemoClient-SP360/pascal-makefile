unit SqliteDS;

{
    This is SqliteDS/TSqliteDataset, a TDataset descendant class for use with fpc compiler
    Copyright (C) 2004  Luiz Am�rico Pereira C�mara
    Email: pascalive@bol.com.br

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU Lesser General Public License as published by
    the Free Software Foundation; either version 2.1 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

}

{$Mode ObjFpc}
{$H+}
{  $Define DEBUG}
interface

uses Classes, SysUtils, Db;

type
  PDataRecord = ^DataRecord;
  PPDataRecord = ^PDataRecord;
  DataRecord = record
    Row: PPchar;
    BookmarkData: Pointer;
    BookmarkFlag: TBookmarkFlag;
    Next: PDataRecord;
    Previous: PDataRecord;
  end;
 
  TSqliteDataset = class(TDataSet)
  private
    FFileName: String;
    FSql: String;
    FTableName: String;   
    FCurrentItem: PDataRecord;
    FBeginItem: PDataRecord;
    FEndItem: PDataRecord;
    FCacheItem: PDataRecord;
    FBufferSize: Integer;
    FRowBufferSize: Integer;
    FRowCount: Integer;
    FRecordCount: Integer;
    FSqliteReturnId: Integer;
    FDataAllocated: Boolean;
    FSaveOnClose: Boolean;
    FSqliteHandle: Pointer;
    FDBError: PPChar;
    FUpdatedItems: TList;
    FAddedItems: TList;
    FDeletedItems: TList;
    FOrphanItems: TList;
    procedure BuildLinkedList;
    procedure DisposeLinkedList;
    procedure SetSql (AValue:String);
  protected
    function AllocRecordBuffer: PChar; override;
    procedure FreeRecordBuffer(var Buffer: PChar); override;
    procedure GetBookmarkData(Buffer: PChar; Data: Pointer); override;
    function GetBookmarkFlag(Buffer: PChar): TBookmarkFlag; override;
    function GetRecord(Buffer: PChar; GetMode: TGetMode; DoCheck: Boolean): TGetResult; override;
    function GetRecordCount: Integer; override;
    function GetRecNo: Integer; override;
    function GetRecordSize: Word; override; 
    procedure InternalAddRecord(Buffer: Pointer; DoAppend: Boolean); override;
    procedure InternalClose; override;
    procedure InternalDelete; override;
    procedure InternalFirst; override;
    procedure InternalGotoBookmark(ABookmark: Pointer); override;
    procedure InternalHandleException; override;
    procedure InternalInitFieldDefs; override;
    procedure InternalInitRecord(Buffer: PChar); override;
    procedure InternalLast; override;
    procedure InternalOpen; override;
    procedure InternalPost; override;
    procedure InternalSetToRecord(Buffer: PChar); override;
    function IsCursorOpen: Boolean; override;    
    procedure SetBookmarkData(Buffer: PChar; Data: Pointer); override;
    procedure SetBookmarkFlag(Buffer: PChar; Value: TBookmarkFlag); override;
    procedure SetFieldData(Field: TField; Buffer: Pointer); override;  
    procedure SetRecNo(Value: Integer); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function GetFieldData(Field: TField; Buffer: Pointer): Boolean; override;
    // Additional procedures
    function ApplyUpdates: Boolean;
    procedure CloseHandle;
    function CreateDataSet(MustCloseHandle:Boolean): Boolean;
    function ExecSQL:Integer;
    function ExecSQL(ASql:String):Integer;
    function SqliteReturnString: String;
    {$Ifdef DEBUG}
    property BeginItem: PDataRecord read FBeginItem;
    property EndItem: PDataRecord read FEndItem;
    {$Endif}
    property SqliteReturnId: Integer read FSqliteReturnId;
    property SQL: String read FSql write SetSql;
    property TableName: String read FTableName write FTableName;
    property FileName: String read FFileName write FFileName;
    property SaveOnClose: Boolean read FSaveOnClose write FSaveOnClose; 
   published
    property Active;
    property BeforeOpen;
    property AfterOpen;
    property BeforeClose;
    property AfterClose;
    property BeforeInsert;
    property AfterInsert;
    property BeforeEdit;
    property AfterEdit;
    property BeforePost;
    property AfterPost;
    property BeforeCancel;
    property AfterCancel;
    property BeforeDelete;
    property AfterDelete;
    property BeforeScroll;
    property AfterScroll;
    property OnDeleteError;
    property OnEditError;
  end;

implementation

uses SQLite;

function GetFieldDefs(TheDataset: TDataset; Columns: Integer; ColumnValues: PPChar; ColumnNames: PPChar): integer; cdecl;
var
  FieldSize:Word;
  Counter:Integer;
  AType:TFieldType;
  ColumnStr:String;
  TempAttributes:TFieldAttributes;
begin
 // Sqlite is typeless (allows any type in any field) 
 // regardless of what is in Create Table, but returns 
 // exactly what is in Create Table statement
 // here is a trick to get the datatype.
 // If the field contains another type, there will be problems  
 For Counter:= 0 to Columns - 1 do
 begin
   ColumnStr:= UpCase(StrPas(ColumnNames[Counter + Columns]));
   If (ColumnStr = 'INTEGER') or (ColumnStr = 'INT') then  
   begin  
     AType:= ftInteger;
     FieldSize:=SizeOf(Integer); 
   end  
   else
   begin
     AType:= ftString;
     FieldSize:=0;
   end;
   with TheDataset.FieldDefs do
   begin
     Add(StrPas(ColumnNames[Counter]), AType, FieldSize, False); 
     If Items[Counter].Name = '_ROWID_' then
     begin
       TempAttributes:=Items[Counter].Attributes;
       System.Include(TempAttributes,faReadonly);
       Items[Counter].Attributes:=TempAttributes;
     end;
   end;
 end;
 result:=-1;
end; 
 
// TSqliteDataset override methods

function TSqliteDataset.AllocRecordBuffer: PChar;
begin
  Result := AllocMem(FBufferSize);
end;

procedure TSqliteDataset.BuildLinkedList;
var
  TempItem:PDataRecord;
  vm:Pointer;
  ColumnNames,ColumnValues:PPChar;
  Counter:Integer;
begin
  FSqliteReturnId:=sqlite_compile(FSqliteHandle,Pchar(FSql),nil,@vm,nil);  
  if FSqliteReturnId <> SQLITE_OK then
  case FSqliteReturnId of
  SQLITE_ERROR:
    DatabaseError('Invalid Sql',Self);
  else
    DatabaseError('Unknow Error',Self);
  end;
  FDataAllocated:=True;
  New(FBeginItem);
  FBeginItem^.Next:=nil;
  FBeginItem^.Previous:=nil;
  TempItem:=FBeginItem;
  FRecordCount:=0; 
  FSqliteReturnId:=sqlite_step(vm,@FRowCount,@ColumnValues,@ColumnNames);
  while FSqliteReturnId = SQLITE_ROW do
  begin
    Inc(FRecordCount);
    New(TempItem^.Next);
    TempItem^.Next^.Previous:=TempItem;
    TempItem:=TempItem^.Next;
    GetMem(TempItem^.Row,FRowBufferSize);
    For Counter := 0 to FRowCount - 1 do
      TempItem^.Row[Counter]:=StrNew(ColumnValues[Counter]);     
    FSqliteReturnId:=sqlite_step(vm,@FRowCount,@ColumnValues,@ColumnNames);  
  end;
  sqlite_finalize(vm, nil); 
  // Init EndItem        
  if FRecordCount <> 0 then 
  begin
    New(TempItem^.Next);
    TempItem^.Next^.Previous:=TempItem;
    FEndItem:=TempItem^.Next;    
  end  
  else
  begin
    New(FEndItem);
    FEndItem^.Previous:=FBeginItem;    
    FBeginItem^.Next:=FEndItem;
  end;   
  FEndItem^.Next:=nil;
   // Alloc item used in append/insert 
  New(FCacheItem);
  GetMem(FCacheItem^.Row,FRowBufferSize);
  For Counter := 0 to FRowCount - 1 do
    FCacheItem^.Row[Counter]:=nil;     
end;

constructor TSqliteDataset.Create(AOwner: TComponent);
begin
  BookmarkSize := SizeOf(Pointer); 
  FBufferSize := SizeOf(PPDataRecord);
  FUpdatedItems:= TList.Create;
  FUpdatedItems.Capacity:=20;
  FAddedItems:= TList.Create;
  FAddedItems.Capacity:=20;
  FOrphanItems:= TList.Create;
  FOrphanItems.Capacity:=20;
  FDeletedItems:= TList.Create;
  FDeletedItems.Capacity:=20;
  FSaveOnClose:=False;
  inherited Create(AOwner);
end;

destructor TSqliteDataset.Destroy;
begin
  FUpdatedItems.Destroy;
  FAddedItems.Destroy;
  FDeletedItems.Destroy;
  FOrphanItems.Destroy;
  inherited Destroy;
end;

procedure TSqliteDataset.DisposeLinkedList;
var
  TempItem:PDataRecord;
  Counter:Integer;
begin
  //Todo insert debug info
  FDataAllocated:=False;
  //Dispose cache item
  for Counter:= 0 to FRowCount - 1 do
    StrDispose(FCacheItem^.Row[Counter]);
  FreeMem(FCacheItem^.Row,FRowBufferSize);
  Dispose(FCacheItem);
  If FBeginItem^.Next = nil then //remove it??
    exit;
  TempItem:=FBeginItem^.Next;
  Dispose(FBeginItem);
  while TempItem^.Next <> nil do
  begin
    for Counter:= 0 to FRowCount - 1 do
      StrDispose(TempItem^.Row[Counter]);  
    FreeMem(TempItem^.Row,FRowBufferSize);
    TempItem:=TempItem^.Next;
    Dispose(TempItem^.Previous);
  end; 
  // Free last item
  Dispose(TempItem);  
  for Counter:= 0 to FOrphanItems.Count - 1 do
  begin
    TempItem:=PDataRecord(FOrphanItems[Counter]);
    for Counter:= 0 to FRowCount - 1 do
      StrDispose(TempItem^.Row[Counter]);  
    FreeMem(TempItem^.Row,FRowBufferSize);
    Dispose(TempItem);  
  end;     
end;

procedure TSqliteDataset.FreeRecordBuffer(var Buffer: PChar);
begin
  FreeMem(Buffer);
end;

procedure TSqliteDataset.GetBookmarkData(Buffer: PChar; Data: Pointer);
begin
  Pointer(Data^) := PPDataRecord(Buffer)^^.BookmarkData;
end;

function TSqliteDataset.GetBookmarkFlag(Buffer: PChar): TBookmarkFlag;
begin
  Result := PPDataRecord(Buffer)^^.BookmarkFlag;
end;

function TSqliteDataset.GetFieldData(Field: TField; Buffer: Pointer): Boolean;
var
  ValError:Word;
  FieldRow:PChar;
begin
  if FRecordCount = 0 then // avoid exception in empty datasets
  begin
    Result:=False;
    Exit;
  end;  
  FieldRow:=PPDataRecord(ActiveBuffer)^^.Row[Field.Index];
  Result := FieldRow <> nil;  
  if Result and (Buffer <> nil) then //supports GetIsNull
  begin
    case Field.Datatype of
    ftString:
      begin
        Move(FieldRow^,PChar(Buffer)^,StrLen(FieldRow)+1);
      end;
    ftInteger:
      begin
        Val(StrPas(FieldRow),LongInt(Buffer^),ValError);
        Result:= ValError = 0;  
      end;
    end;
  end;        
end;

function TSqliteDataset.GetRecord(Buffer: PChar; GetMode: TGetMode; DoCheck: Boolean): TGetResult;
begin
  Result := grOk;
  case GetMode of
    gmPrior:
      if (FCurrentItem^.Previous = FBeginItem) or (FCurrentItem = FBeginItem) then
      begin
        Result := grBOF;
        FCurrentItem := FBeginItem;
      end
      else
        FCurrentItem:=FCurrentItem^.Previous;
    gmCurrent:
      if (FCurrentItem = FBeginItem) or (FCurrentItem = FEndItem) then
         Result := grError;
    gmNext:
      if (FCurrentItem = FEndItem) or (FCurrentItem^.Next = FEndItem) then
        Result := grEOF
      else
        FCurrentItem:=FCurrentItem^.Next;
  end; //case
  if Result = grOk then
  begin
    PDataRecord(Pointer(Buffer)^):=FCurrentItem;
    with FCurrentItem^ do
    begin
      BookmarkData := FCurrentItem;
      BookmarkFlag := bfCurrent;
    end;
  end
    else if (Result = grError) and DoCheck then
      DatabaseError('SqliteDs - No records',Self);
end;

function TSqliteDataset.GetRecordCount: Integer;
begin
  Result := FRecordCount;
end;

function TSqliteDataset.GetRecNo: Integer;
var
  TempItem,TempActive:PDataRecord;
begin
  Result:= -1;
  TempItem:=FBeginItem;
  TempActive:=PPDataRecord(ActiveBuffer)^;
  while TempActive <> TempItem do
  begin
    if TempItem^.Next <> nil then
    begin
      inc(Result);
      TempItem:=TempItem^.Next;
    end  
    else
    begin
      Result:=-1;
      DatabaseError('GetRecNo - ActiveItem Not Found',Self);
      break;    
    end;      
  end;  
end;

function TSqliteDataset.GetRecordSize: Word;
begin
  Result := FBufferSize; //??
end;

procedure TSqliteDataset.InternalAddRecord(Buffer: Pointer; DoAppend: Boolean);
var
  NewItem: PDataRecord;
  Counter:Integer;
begin
  //Todo: implement insert ??
  if PPDataRecord(Buffer)^ <> FCacheItem then
    DatabaseError('PPDataRecord(Buffer) <> FCacheItem - Problem',Self);
  New(NewItem);
  GetMem(NewItem^.Row,FRowBufferSize);
  for Counter := 0 to FRowCount - 1 do 
    NewItem^.Row[Counter]:=StrNew(FCacheItem^.Row[Counter]);   
  FEndItem^.Previous^.Next:=NewItem;
  NewItem^.Previous:=FEndItem^.Previous;
  NewItem^.Next:=FEndItem;
  FEndItem^.Previous:=NewItem;
  Inc(FRecordCount);
  FAddedItems.Add(NewItem);
end;

procedure TSqliteDataset.InternalClose;
begin
  if FSaveOnClose then
    ApplyUpdates;  
  if DefaultFields then
    DestroyFields;
  if FDataAllocated then
    DisposeLinkedList;  
  if FSqliteHandle <> nil then
  begin
    CloseHandle;
    FSqliteHandle := nil;
  end;
  FAddedItems.Clear;
  FUpdatedItems.Clear;
  FDeletedItems.Clear;
  FOrphanItems.Clear;
  FRecordCount:=0;
end;

procedure TSqliteDataset.InternalDelete;
var
  TempItem:PDataRecord;
begin
  Dec(FRecordCount);
  TempItem:=PPDataRecord(ActiveBuffer)^;
  // Remove from changed list
  FUpdatedItems.Remove(TempItem);
  if FAddedItems.Remove(TempItem) = -1 then
    FDeletedItems.Add(TempItem);
  FOrphanItems.Add(TempItem);
  TempItem^.Next^.Previous:=TempItem^.Previous;
  TempItem^.Previous^.Next:=TempItem^.Next;
  if FCurrentItem = TempItem then
  begin
    if FCurrentItem^.Previous <> FBeginItem then
      FCurrentItem:= FCurrentItem^.Previous
    else
      FCurrentItem:= FCurrentItem^.Next;  
  end;    
end;

procedure TSqliteDataset.InternalFirst;
begin
  FCurrentItem := FBeginItem;
end;

procedure TSqliteDataset.InternalGotoBookmark(ABookmark: Pointer);
begin
  FCurrentItem := PDataRecord(ABookmark^);
end;

procedure TSqliteDataset.InternalHandleException;
begin
  //??
end;

procedure TSqliteDataset.InternalInitFieldDefs;
begin
  FieldDefs.Clear;
  sqlite_exec(FSqliteHandle,PChar('PRAGMA empty_result_callbacks = ON;PRAGMA show_datatypes = ON;'),nil,nil,nil);
  FSqliteReturnId:=sqlite_exec(FSqliteHandle,PChar(FSql),@GetFieldDefs,Self,nil);
  {
  if FSqliteReturnId <> SQLITE_ABORT then
     DatabaseError(SqliteReturnString,Self);
  }
  FRowBufferSize:=(SizeOf(PPChar)*FieldDefs.Count);
end;


procedure TSqliteDataset.InternalInitRecord(Buffer: PChar);
var
  Counter:Integer;
begin
  for Counter:= 0 to FRowCount - 1 do
  begin
    StrDispose(FCacheItem^.Row[Counter]);
    FCacheItem^.Row[Counter]:=nil;
  end;
  PPDataRecord(Buffer)^:=FCacheItem;    
end;

procedure TSqliteDataset.InternalLast;
begin
  FCurrentItem := FEndItem;
end;

procedure TSqliteDataset.InternalOpen;
begin
  if not FileExists(FFileName) then
    DatabaseError('File '+FFileName+' not found',Self);
  FSqliteHandle:=sqlite_open(PChar(FFileName),0,FDBError);
  InternalInitFieldDefs;
  BuildLinkedList;               
  FCurrentItem:=FBeginItem;  
  if DefaultFields then 
    CreateFields;
  BindFields(True);  
end;

procedure TSqliteDataset.InternalPost;
begin
  if (State<>dsEdit) then 
    InternalAddRecord(ActiveBuffer,True);
end;

procedure TSqliteDataset.InternalSetToRecord(Buffer: PChar);
begin
  FCurrentItem:=PPDataRecord(Buffer)^;
end;

function TSqliteDataset.IsCursorOpen: Boolean;
begin
   Result := FDataAllocated;
end;

procedure TSqliteDataset.SetBookmarkData(Buffer: PChar; Data: Pointer);
begin
  PPDataRecord(Buffer)^^.BookmarkData := Pointer(Data^);
end;

procedure TSqliteDataset.SetBookmarkFlag(Buffer: PChar; Value: TBookmarkFlag);
begin
  PPDataRecord(Buffer)^^.BookmarkFlag := Value;
end;

procedure TSqliteDataset.SetFieldData(Field: TField; Buffer: Pointer);
var
  TempStr:String;
  ActiveItem:PDataRecord;
begin
  ActiveItem:=PPDataRecord(ActiveBuffer)^;
  if (ActiveItem <> FCacheItem) and (FUpdatedItems.IndexOf(ActiveItem) = -1) and (FAddedItems.IndexOf(ActiveItem) = -1) then
    FUpdatedItems.Add(ActiveItem);
  if Buffer = nil then
    ActiveItem^.Row[Field.Index]:=nil
  else
    case Field.Datatype of
    ftString:
      begin
        StrDispose(ActiveItem^.Row[Field.Index]);  
        ActiveItem^.Row[Field.Index]:=StrNew(PChar(Buffer));
      end;
    ftInteger:
      begin
        StrDispose(ActiveItem^.Row[Field.Index]);  
        Str(LongInt(Buffer^),TempStr);  
        ActiveItem^.Row[Field.Index]:=StrAlloc(Length(TempStr)+1);
        StrPCopy(ActiveItem^.Row[Field.Index],TempStr);
      end;
    end;        
end;

procedure TSqliteDataset.SetRecNo(Value: Integer);
begin
 //
end;

// Specific functions 

procedure TSqliteDataset.SetSql(AValue:String);
begin   
  FSql:=AValue;
  // Todo: Retrieve Tablename from SQL ??
end;    

function TSqliteDataset.ExecSQL(ASql:String):Integer;
begin
  Result:=0;
  if FSqliteHandle <> nil then
  begin
    FSqliteReturnId:= sqlite_exec(FSqliteHandle,PChar(ASql),nil,nil,nil);
    Result:=sqlite_changes(FSqliteHandle);
  end;      
end;    

function TSqliteDataset.ExecSQL:Integer;
begin
  Result:=ExecSQL(FSql);  
end;

function TSqliteDataset.ApplyUpdates:Boolean;
var
  CounterFields,CounterItems:Integer;
  SqlTemp:String;
  Quote:Char;
begin
  Result:=False;
  if (FTableName <> '') and (Fields[0].FieldName = '_ROWID_')  then
  begin
    SqlTemp:='BEGIN TRANSACTION; ';
    // Update changed records
    For CounterItems:= 0 to FUpdatedItems.Count - 1 do  
    begin
      SqlTemp:=SqlTemp+'UPDATE '+FTableName+' SET ';
      for CounterFields:= 1 to Fields.Count - 1 do
      begin
        if PDataRecord(FUpdatedItems[CounterItems])^.Row[CounterFields] <> nil then
        begin
          if Fields[CounterFields].DataType = ftString then
            Quote:='"'
          else
            Quote:=' ';  
          SqlTemp:=SqlTemp + Fields[CounterFields].FieldName +' = '+Quote+
          StrPas(PDataRecord(FUpdatedItems[CounterItems])^.Row[CounterFields])+Quote+' , ';
        end
        else
          SqlTemp:=SqlTemp + Fields[CounterFields].FieldName +' = NULL , ';  
      end;
      system.delete(SqlTemp,Length(SqlTemp)-2,2);
      SqlTemp:=SqlTemp+'WHERE _ROWID_ = '+StrPas(PDataRecord(FUpdatedItems[CounterItems])^.Row[0])+';';
    end;
    // Add new records
    For CounterItems:= 0 to FAddedItems.Count - 1 do  
    begin
      SqlTemp:=SqlTemp+'INSERT INTO '+FTableName+ ' ( ';
      for CounterFields:= 1 to Fields.Count - 1 do
      begin
        SqlTemp:=SqlTemp + Fields[CounterFields].FieldName; 
        if CounterFields <> Fields.Count - 1 then
          SqlTemp:=SqlTemp+' , ';
      end; 
      SqlTemp:=SqlTemp+') VALUES ( ';
      for CounterFields:= 1 to Fields.Count - 1 do
      begin
        if PDataRecord(FAddedItems[CounterItems])^.Row[CounterFields] <> nil then
        begin
          if Fields[CounterFields].DataType = ftString then
            Quote:='"'
          else
            Quote:=' ';  
          SqlTemp:=SqlTemp + Quote+ StrPas(PDataRecord(FAddedItems[CounterItems])^.Row[CounterFields])+Quote;
        end
        else
          SqlTemp:=SqlTemp + 'NULL';
        if CounterFields <> Fields.Count - 1 then
          SqlTemp:=SqlTemp+' , ';
      end;
      SqlTemp:=SqlTemp+') ;';    
    end;  
    // Delete Items
    For CounterItems:= 0 to FDeletedItems.Count - 1 do  
    begin
      SqlTemp:=SqlTemp+'DELETE FROM '+FTableName+ ' WHERE _ROWID_ = '+
        StrPas(PDataRecord(FDeletedItems[CounterItems])^.Row[0])+';';    
    end;
    SqlTemp:=SqlTemp+'END TRANSACTION; ';
    {$ifdef DEBUG}
    writeln('ApplyUpdates Sql: ',SqlTemp);
    {$endif}  
   FAddedItems.Clear;
   FUpdatedItems.Clear;
   FDeletedItems.Clear;   
   FSqliteReturnId:=sqlite_exec(FSqliteHandle,PChar(SqlTemp),nil,nil,nil);
   Result:= FSqliteReturnId = SQLITE_OK;
  end;  
  {$ifdef DEBUG}
    writeln('ApplyUpdates Result: ',Result);
  {$endif}   
end;    

procedure TSqliteDataset.CloseHandle;
begin
  sqlite_close(FSqliteHandle);
end;  

function TSqliteDataset.CreateDataSet(MustCloseHandle:Boolean): Boolean;
var
  SqlTemp:String;
  Counter:Integer;
begin
  if (FTableName <> '') and (FieldDefs.Count > 0) then
  begin
    FSqliteHandle:= sqlite_open(PChar(FFileName),0,FDBError);
    SqlTemp:='CREATE TABLE '+FTableName+' (';
    for Counter := 0 to FieldDefs.Count-1 do
    begin
      SqlTemp:=SqlTemp + FieldDefs[Counter].Name;
      if FieldDefs[Counter].DataType = ftInteger then
        SqlTemp:=SqlTemp + ' INTEGER'
      else
        SqlTemp:=SqlTemp + ' VARCHAR';
      if Counter <>  FieldDefs.Count - 1 then
        SqlTemp:=SqlTemp+ ' , ';   
    end;
    SqlTemp:=SqlTemp+');';
    {$ifdef DEBUG}
    writeln('CreateDataSet Sql: ',SqlTemp);
    {$endif}  
    FSqliteReturnId:=sqlite_exec(FSqliteHandle,PChar(SqlTemp),nil,nil,nil);   
    Result:= FSqliteReturnId = SQLITE_OK;
    if MustCloseHandle then
      CloseHandle;
  end
  else
    Result:=False;  
end; 

function TSqliteDataset.SqliteReturnString: String;
begin
 case FSqliteReturnId of
      SQLITE_OK           : Result := 'SQLITE_OK          '; 
      SQLITE_ERROR        : Result := 'SQLITE_ERROR       ';
      SQLITE_INTERNAL     : Result := 'SQLITE_INTERNAL    '; 
      SQLITE_PERM         : Result := 'SQLITE_PERM        '; 
      SQLITE_ABORT        : Result := 'SQLITE_ABORT       '; 
      SQLITE_BUSY         : Result := 'SQLITE_BUSY        '; 
      SQLITE_LOCKED       : Result := 'SQLITE_LOCKED      '; 
      SQLITE_NOMEM        : Result := 'SQLITE_NOMEM       '; 
      SQLITE_READONLY     : Result := 'SQLITE_READONLY    '; 
      SQLITE_INTERRUPT    : Result := 'SQLITE_INTERRUPT   '; 
      SQLITE_IOERR        : Result := 'SQLITE_IOERR       '; 
      SQLITE_CORRUPT      : Result := 'SQLITE_CORRUPT     '; 
      SQLITE_NOTFOUND     : Result := 'SQLITE_NOTFOUND    '; 
      SQLITE_FULL         : Result := 'SQLITE_FULL        '; 
      SQLITE_CANTOPEN     : Result := 'SQLITE_CANTOPEN    '; 
      SQLITE_PROTOCOL     : Result := 'SQLITE_PROTOCOL    '; 
      SQLITE_EMPTY        : Result := 'SQLITE_EMPTY       '; 
      SQLITE_SCHEMA       : Result := 'SQLITE_SCHEMA      '; 
      SQLITE_TOOBIG       : Result := 'SQLITE_TOOBIG      '; 
      SQLITE_CONSTRAINT   : Result := 'SQLITE_CONSTRAINT  '; 
      SQLITE_MISMATCH     : Result := 'SQLITE_MISMATCH    '; 
      SQLITE_MISUSE       : Result := 'SQLITE_MISUSE      '; 
      SQLITE_NOLFS        : Result := 'SQLITE_NOLFS       '; 
      SQLITE_AUTH         : Result := 'SQLITE_AUTH        '; 
      SQLITE_FORMAT       : Result := 'SQLITE_FORMAT      '; 
     // SQLITE_RANGE        : Result := 'SQLITE_RANGE       '; 
      SQLITE_ROW          : Result := 'SQLITE_ROW         '; 
      SQLITE_DONE         : Result := 'SQLITE_DONE        '; 
  else
    Result:='Unknow Return Value';    
 end;
end;  
 
end. 