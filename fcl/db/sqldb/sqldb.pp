{   $Id$

    Copyright (c) 2004 by Joost van der Sluis


    SQL database & dataset

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}

unit sqldb;

{$mode objfpc}
{$H+}
{$M+}   // ### remove this!!!

interface

uses SysUtils, Classes, DB;

type
  TSQLConnection = class;
  TSQLTransaction = class;
  TSQLQuery = class;

  TStatementType = (stNone, stSelect, stInsert, stUpdate, stDelete,
    stDDL, stGetSegment, stPutSegment, stExecProcedure,
    stStartTrans, stCommit, stRollback, stSelectForUpd);

  TSQLHandle = Class(TObject)
    protected
    StatementType       : TStatementType;
  end;


const
 StatementTokens : Array[TStatementType] of string = ('(none)', 'select',
                  'insert', 'update', 'delete',
                  'create', 'get', 'put', 'execute',
                  'start','commit','rollback', '?'
                 );


{ TSQLConnection }
type
  TSQLConnection = class (TDatabase)
  private
    FPassword            : string;
    FTransaction         : TSQLTransaction;
    FUserName            : string;
    FHostName            : string;
    FCharSet             : string;
    FRole                : String;
    
    procedure SetTransaction(Value : TSQLTransaction);
  protected
    procedure DoInternalConnect; override;
    procedure DoInternalDisconnect; override;
    function GetHandle : pointer; virtual; abstract;

    Function AllocateCursorHandle : TSQLHandle; virtual; abstract;
    Function AllocateTransactionHandle : TSQLHandle; virtual; abstract;

    procedure FreeStatement(cursor : TSQLHandle); virtual; abstract;
    procedure PrepareStatement(cursor: TSQLHandle;ATransaction : TSQLTransaction;buf : string); virtual; abstract;
    procedure FreeFldBuffers(cursor : TSQLHandle); virtual; abstract;
    procedure Execute(cursor: TSQLHandle;atransaction:tSQLtransaction); virtual; abstract;
    procedure AddFieldDefs(cursor: TSQLHandle; FieldDefs : TfieldDefs); virtual; abstract;
    function GetFieldSizes(cursor : TSQLHandle) : integer; virtual; abstract;
    function Fetch(cursor : TSQLHandle) : boolean; virtual; abstract;
    procedure LoadFieldsFromBuffer(cursor : TSQLHandle;buffer : pchar); virtual; abstract;
    function GetFieldData(Cursor : TSQLHandle;Field: TField; FieldDefs : TfieldDefs; Buffer: Pointer;currbuff : pchar): Boolean; virtual;
    function GetTransactionHandle(trans : TSQLHandle): pointer; virtual; abstract;
    function Commit(trans : TSQLHandle) : boolean; virtual; abstract;
    function RollBack(trans : TSQLHandle) : boolean; virtual; abstract;
    function StartTransaction(trans : TSQLHandle) : boolean; virtual; abstract;
    procedure CommitRetaining(trans : TSQLHandle); virtual; abstract;
    procedure RollBackRetaining(trans : TSQLHandle); virtual; abstract;
  public
    destructor Destroy; override;
    property Handle: Pointer read GetHandle;
  published
    property Password : string read FPassword write FPassword;
    property Transaction : TSQLTransaction read FTransaction write SetTransaction;
    property UserName : string read FUserName write FUserName;
    property CharSet : string read FCharSet write FCharSet;
    property HostName : string Read FHostName Write FHostName;

    property Connected;
    Property Role :  String read FRole write FRole;
    property DatabaseName;
    property KeepConnection;
    property LoginPrompt;
    property Params;
    property OnLogin;
  end;

{ TSQLTransaction }


  TCommitRollbackAction = (caNone, caCommit, caCommitRetaining, caRollback,
    caRollbackRetaining);

  TSQLTransaction = class (TDBTransaction)
  private
    FTrans               : TSQLHandle;
    FAction              : TCommitRollbackAction;
    FActive              : boolean;

    procedure SetActive(Value : boolean);
  protected
    function GetHandle : Pointer; virtual;
  public
    procedure EndTransaction; override;
    procedure Commit; virtual;
    procedure CommitRetaining; virtual;
    procedure Rollback; virtual;
    procedure RollbackRetaining; virtual;
    procedure StartTransaction;
    constructor Create(AOwner : TComponent); override;
    destructor Destroy; override;
    property Handle: Pointer read GetHandle;
  published
    property Action : TCommitRollbackAction read FAction write FAction;
    property Active : boolean read FActive write SetActive;
    property Database;
  end;

{ TSQLQuery }

  TSQLQuery = class (Tbufdataset)
  private
    FCursor              : TSQLHandle;
    FOpen                : Boolean;
    FTransaction         : TSQLTransaction;
    FSQL                 : TStrings;
    FIsEOF               : boolean;
    FLoadingFieldDefs    : boolean;
    FRecordSize          : Integer;

    procedure SetTransaction(Value : TSQLTransaction);
    procedure FreeStatement;
    procedure PrepareStatement;
    procedure FreeFldBuffers;
    procedure Fetch;
    function LoadBuffer(Buffer : PChar): TGetResult;
    procedure SetFieldSizes;

    procedure Execute;

  protected
    // abstract & virual methods of TDataset
    procedure SetDatabase(Value : TDatabase); override;
    function AllocRecord(ExtraSize : integer): PChar; override;
    procedure FreeRecord(var Buffer: PChar); override;
    function GetFieldData(Field: TField; Buffer: Pointer): Boolean; override;
    function GetNextRecord(Buffer : pchar) : TGetResult; override;
    function GetRecordSize: Word; override;
    procedure InternalAddRecord(Buffer: Pointer; AAppend: Boolean); override;
    procedure InternalClose; override;
    procedure InternalDelete; override;
    procedure InternalHandleException; override;
    procedure InternalInitFieldDefs; override;
    procedure InternalInitRecord(Buffer: PChar); override;
    procedure InternalOpen; override;
    procedure InternalPost; override;
    function IsCursorOpen: Boolean; override;
    procedure SetFieldData(Field: TField; Buffer: Pointer); override;
    Function GetSQLStatementType(SQL : String) : TStatementType; virtual;
  public
    procedure ExecSQL; virtual;
    constructor Create(AOwner : TComponent); override;
    destructor Destroy; override;
  published
    // redeclared data set properties
    property Active;
//    property FieldDefs stored FieldDefsStored;
    property Filter;
    property Filtered;
    property FilterOptions;
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
    property OnCalcFields;
    property OnDeleteError;
    property OnEditError;
    property OnFilterRecord;
    property OnNewRecord;
    property OnPostError;
    property AutoCalcFields;
    property Database;

    property Transaction : TSQLTransaction read FTransaction write SetTransaction;
    property SQL         : TStrings read FSQL write FSQL;
  end;

implementation

ResourceString
  SErrAssTransaction = 'Cannot assign transaction while old transaction active!';
  SErrDatabasenAssigned = 'Database not assigned!';
  SErrTransactionnSet = 'Transaction not set';
  SErrNoStatement = 'SQL statement not set';
  SErrNoSelectStatement = 'Cannot open a non-select statement';
  
{ TSQLConnection }

procedure TSQLConnection.SetTransaction(Value : TSQLTransaction);
begin
  if FTransaction = nil then
  begin
    FTransaction := Value;
    if Assigned(FTransaction) then
      FTransaction.Database := Self;
    exit;
  end;

  if (Value <> FTransaction) and (Value <> nil) then
    if (not FTransaction.Active) then
    begin
      FTransaction := Value;
      FTransaction.Database := Self;
    end
    else
      DatabaseError(SErrAssTransaction);
end;

procedure TSQLConnection.DoInternalConnect;
begin
  if Connected then
    Close;
end;

procedure TSQLConnection.DoInternalDisconnect;
begin
end;

destructor TSQLConnection.Destroy;
begin
  if FTransaction <> nil then
  begin
    FTransaction.Active := False;
    FTransaction.Database := nil;
  end;
  inherited Destroy;
end;

function TSQLConnection.GetFieldData(Cursor : TSQLHandle;Field: TField; FieldDefs : TfieldDefs; Buffer: Pointer;currbuff : pchar): Boolean;

var
  x : longint;

begin
  Result := False;
  for x := 0 to FieldDefs.count-1 do
    begin
    if (Field.FieldName = FieldDefs[x].Name) then
      begin
      Move(CurrBuff^, Buffer^, Field.Size);
      Result := True;
      Break;
      end
    else Inc(CurrBuff, FieldDefs[x].Size);
    end;
end;

{ TSQLTransaction }

procedure TSQLTransaction.SetActive(Value : boolean);
begin
  if FActive and (not Value) then
    Rollback
  else if (not FActive) and Value then
    StartTransaction;
end;

function TSQLTransaction.GetHandle: pointer;
begin
  Result := (Database as tsqlconnection).GetTransactionHandle(FTrans);
end;

procedure TSQLTransaction.Commit;
begin
  if not FActive then Exit;
  if (Database as tsqlconnection).commit(FTrans) then FActive := false;
  FTrans.free;
end;

procedure TSQLTransaction.CommitRetaining;
begin
  if not FActive then Exit;
  (Database as tsqlconnection).commitRetaining(FTrans);
end;

procedure TSQLTransaction.Rollback;
begin
  if not FActive then Exit;
  if (Database as tsqlconnection).RollBack(FTrans) then FActive := false;
  FTrans.free;
end;

procedure TSQLTransaction.EndTransaction;
begin
  Rollback;
end;

procedure TSQLTransaction.RollbackRetaining;
begin
  if not FActive then Exit;
  (Database as tsqlconnection).RollBackRetaining(FTrans);
end;

procedure TSQLTransaction.StartTransaction;

var db : TSQLConnection;

begin
  if Active then Active := False;

  db := (Database as tsqlconnection);

  if Db = nil then
    DatabaseError(SErrDatabasenAssigned);

  if not Db.Connected then
    Db.Open;
  if not assigned(FTrans) then FTrans := Db.AllocateTransactionHandle;

  if Db.StartTransaction(FTrans) then FActive := true;
end;

constructor TSQLTransaction.Create(AOwner : TComponent);
begin
  inherited Create(AOwner);
end;

destructor TSQLTransaction.Destroy;
begin
  // This will also do a Rollback, if the transaction is currently active
  Active := False;

//  Database.Transaction := nil;

  inherited Destroy;
end;

{ TSQLQuery }

procedure TSQLQuery.SetTransaction(Value : TSQLTransaction);
begin
  CheckInactive;
  if (FTransaction <> Value) then
    FTransaction := Value;
end;

procedure TSQLQuery.SetDatabase(Value : TDatabase);

var db : tsqlconnection;

begin
  if (Database <> Value) then
    begin
    db := value as tsqlconnection;
    inherited setdatabase(value);
    if (FTransaction = nil) and (Assigned(Db.Transaction)) then
      SetTransaction(Db.Transaction);
    end;
end;

procedure TSQLQuery.FreeStatement;
begin
  (Database as tsqlconnection).FreeStatement(FCursor);
end;

procedure TSQLQuery.PrepareStatement;
var
  Buf : string;
  x   : integer;
  db  : tsqlconnection;
begin
  db := (Database as tsqlconnection);
  if Db = nil then
    DatabaseError(SErrDatabasenAssigned);
  if not Db.Connected then
    db.Open;
  if FTransaction = nil then
    DatabaseError(SErrTransactionnSet);
    
  if not FTransaction.Active then
    FTransaction.StartTransaction;

  if assigned(fcursor) then FCursor.free;
  FCursor := Db.AllocateCursorHandle;

  for x := 0 to FSQL.Count - 1 do
    Buf := Buf + FSQL[x] + ' ';

  if Buf='' then
    begin
    DatabaseError(SErrNoStatement);
    exit;
    end;

  FCursor.StatementType := GetSQLStatementType(buf);

  Db.PrepareStatement(Fcursor,FTransaction,buf);
end;

procedure TSQLQuery.FreeFldBuffers;
begin
  (Database as tsqlconnection).FreeFldBuffers(FCursor);
end;

procedure TSQLQuery.Fetch;
begin
  if not (Fcursor.StatementType in [stSelect]) then
    Exit;

  FIsEof := not (Database as tsqlconnection).Fetch(Fcursor);
end;

function TSQLQuery.LoadBuffer(Buffer : PChar): TGetResult;
begin
  Fetch;
  if FIsEOF then
  begin
    Result := grEOF;
    Exit;
  end;
  (Database as tsqlconnection).LoadFieldsFromBuffer(FCursor,buffer);
  Result := grOK;
end;

procedure TSQLQuery.SetFieldSizes;
begin
  FRecordSize := (Database as tsqlconnection).GetfieldSizes(Fcursor);
end;

procedure TSQLQuery.Execute;
begin
  (Database as tsqlconnection).execute(Fcursor,FTransaction);
end;

function TSQLQuery.AllocRecord(ExtraSize : integer): PChar;
begin
  Result := AllocMem(FRecordSize+ExtraSize);
end;

procedure TSQLQuery.FreeRecord(var Buffer: PChar);
begin
  if Assigned(@Buffer) then
    FreeMem(Buffer);
end;

function TSQLQuery.GetFieldData(Field: TField; Buffer: Pointer): Boolean;
begin
  result := (Database as tsqlconnection).GetFieldData(Fcursor,Field,FieldDefs,buffer,activebuffer);
end;

function TSQLQuery.GetNextRecord(Buffer: PChar): TGetResult;
begin
  if FIsEOF then
    Result := grEof
  else
    Result := LoadBuffer(Buffer);
end;

procedure TSQLQuery.InternalAddRecord(Buffer: Pointer; AAppend: Boolean);
begin
  // not implemented - sql dataset
end;

procedure TSQLQuery.InternalClose;
begin
  FreeFldBuffers;
  FreeStatement;
  if DefaultFields then
    DestroyFields;
  FIsEOF := False;
  FRecordSize := 0;
  FOpen:=False;
  FCursor.free;
  inherited internalclose;
end;

procedure TSQLQuery.InternalDelete;
begin
  // not implemented - sql dataset
end;

procedure TSQLQuery.InternalHandleException;
begin
end;

procedure TSQLQuery.InternalInitFieldDefs;
begin
  if FLoadingFieldDefs then
    Exit;

  FLoadingFieldDefs := True;

  try
    FieldDefs.Clear;
    
    (Database as tsqlconnection).AddFieldDefs(fcursor,FieldDefs);
  finally
    FLoadingFieldDefs := False;
  end;
end;

procedure TSQLQuery.InternalInitRecord(Buffer: PChar);
begin
  FillChar(Buffer^, FRecordSize, #0);
end;

procedure TSQLQuery.InternalOpen;
begin
  try
    PrepareStatement;
    if Fcursor.StatementType in [stSelect] then
      begin
      Execute;
      FOpen:=True;
      InternalInitFieldDefs;
      if DefaultFields then
        CreateFields;
      SetFieldSizes;
      BindFields(True);
      end
    else
      DatabaseError(SErrNoSelectStatement,Self);
  except
    on E:Exception do
      raise;
  end;
  inherited InternalOpen;
end;

procedure TSQLQuery.InternalPost;
begin
  // not implemented - sql dataset
end;

function TSQLQuery.IsCursorOpen: Boolean;
begin
  Result := FOpen;
end;

procedure TSQLQuery.SetFieldData(Field: TField; Buffer: Pointer);
begin
end;

// public part

procedure TSQLQuery.ExecSQL;
begin
  try
    PrepareStatement;
    Execute;
  finally
    FreeStatement;
  end;
end;

constructor TSQLQuery.Create(AOwner : TComponent);
begin
  inherited Create(AOwner);
  FSQL := TStringList.Create;
end;

destructor TSQLQuery.Destroy;
begin
  if Active then Close;
//  if assigned(FCursor) then FCursor.destroy;
  FSQL.Free;
  inherited Destroy;
end;

Function TSQLQuery.GetSQLStatementType(SQL : String) : TStatementType;

Var
  L       : Integer;
  cmt     : boolean;
  P,PE,PP : PChar;
  S       : string;
  T       : TStatementType;

begin
  Result:=stNone;
  L:=Length(SQL);
  If (L=0) then
    Exit;
  P:=Pchar(SQL);
  PP:=P;
  Cmt:=False;
  While ((P-PP)<L) do
    begin
    if not (P^ in [' ',#13,#10,#9]) then
      begin
      if not Cmt then
        begin
        // Check for comment.
        Cmt:=(P^='/') and (((P-PP)<=L) and (P[1]='*'));
        if not (cmt) then
          Break;
        end
      else
        begin
        // Check for end of comment.
         Cmt:=Not( (P^='*') and (((P-PP)<=L) and (P[1]='/')) );
        If not cmt then
          Inc(p);
        end;
      end;
    inc(P);
    end;
  PE:=P+1;
  While ((PE-PP)<L) and (PE^ in ['0'..'9','a'..'z','A'..'Z','_']) do
   Inc(PE);
  Setlength(S,PE-P);
  Move(P^,S[1],(PE-P));
  S:=Lowercase(s);
  For t:=stselect to strollback do
    if (S=StatementTokens[t]) then
      Exit(t);
end;

function TSQLQuery.getrecordsize : Word;

begin
  result := FRecordSize;
end;

end.

{
  $Log$
  Revision 1.4  2004-10-10 14:24:22  michael
  * Large patch from Joost Van der Sluis.
  * Float fix in interbase
  + Commit and commitretaining for pqconnection
  + Preparestatement and prepareselect joined.
  + Freestatement and FreeSelect joined
  + TSQLQuery.GetSQLStatementType implemented
  + TBufDataset.AllocBuffer now no longer does a realloc
  + Fetch=True means succesfully got data. False means end of data.
  + Default implementation of GetFieldData implemented/

  Revision 1.3  2004/10/02 14:52:25  michael
  + Added mysql connection

  Revision 1.2  2004/09/26 16:56:32  michael
  + Further fixes from Joost van der sluis for Postgresql

  Revision 1.1  2004/08/31 09:49:47  michael
  + initial implementation of TSQLQuery

}
