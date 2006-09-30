{
    This file is part of the Free Component Library (FCL)
    Copyright (c) 2002 by Florian Klaempfl

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}
{$ifdef fpc}
{$mode objfpc}
{$endif}
{$H+}
{$ifdef CLASSESINLINE}{$inline on}{$endif}

unit contnrs;

interface

uses
  SysUtils,Classes;


Type
  TObjectListCallback = procedure(data:TObject;arg:pointer) of object;
  TObjectListStaticCallback = procedure(data:TObject;arg:pointer);

  TFPObjectList = class(TObject)
  private
    FFreeObjects : Boolean;
    FList: TFPList;
    function GetCount: integer;
    procedure SetCount(const AValue: integer);
  protected
    function GetItem(Index: Integer): TObject; {$ifdef CLASSESINLINE}inline;{$endif}
    procedure SetItem(Index: Integer; AObject: TObject); {$ifdef CLASSESINLINE}inline;{$endif}
    procedure SetCapacity(NewCapacity: Integer);
    function GetCapacity: integer;
  public
    constructor Create;
    constructor Create(FreeObjects : Boolean);
    destructor Destroy; override;
    procedure Clear;
    function Add(AObject: TObject): Integer; {$ifdef CLASSESINLINE}inline;{$endif}
    procedure Delete(Index: Integer); {$ifdef CLASSESINLINE}inline;{$endif}
    procedure Exchange(Index1, Index2: Integer);
    function Expand: TFPObjectList;
    function Extract(Item: TObject): TObject;
    function Remove(AObject: TObject): Integer;
    function IndexOf(AObject: TObject): Integer;
    function FindInstanceOf(AClass: TClass; AExact: Boolean; AStartAt: Integer): Integer;
    procedure Insert(Index: Integer; AObject: TObject); {$ifdef CLASSESINLINE}inline;{$endif}
    function First: TObject;
    function Last: TObject;
    procedure Move(CurIndex, NewIndex: Integer);
    procedure Assign(Obj:TFPObjectList);
    procedure Pack;
    procedure Sort(Compare: TListSortCompare);
    procedure ForEachCall(proc2call:TObjectListCallback;arg:pointer);
    procedure ForEachCall(proc2call:TObjectListStaticCallback;arg:pointer);
    property Capacity: Integer read GetCapacity write SetCapacity;
    property Count: Integer read GetCount write SetCount;
    property OwnsObjects: Boolean read FFreeObjects write FFreeObjects;
    property Items[Index: Integer]: TObject read GetItem write SetItem; default;
    property List: TFPList read FList;
  end;


  TObjectList = class(TList)
  private
    ffreeobjects : boolean;
  Protected
    Procedure Notify(Ptr: Pointer; Action: TListNotification); override;
    function GetItem(Index: Integer): TObject;
    Procedure SetItem(Index: Integer; AObject: TObject);
  public
    constructor create;
    constructor create(freeobjects : boolean);
    function Add(AObject: TObject): Integer;
    function Extract(Item: TObject): TObject;
    function Remove(AObject: TObject): Integer;
    function IndexOf(AObject: TObject): Integer;
    function FindInstanceOf(AClass: TClass; AExact: Boolean; AStartAt: Integer): Integer;
    Procedure Insert(Index: Integer; AObject: TObject);
    function First: TObject;
    Function Last: TObject;
    property OwnsObjects: Boolean read FFreeObjects write FFreeObjects;
    property Items[Index: Integer]: TObject read GetItem write SetItem; default;
  end;

  TComponentList = class(TObjectList)
  Private
    FNotifier : TComponent;
  Protected
    Procedure Notify(Ptr: Pointer; Action: TListNotification); override;
    Function GetItems(Index: Integer): TComponent;
    Procedure SetItems(Index: Integer; AComponent: TComponent);
    Procedure HandleFreeNotify(Sender: TObject; AComponent: TComponent);
  public
    destructor Destroy; override;
    Function Add(AComponent: TComponent): Integer;
    Function Extract(Item: TComponent): TComponent;
    Function Remove(AComponent: TComponent): Integer;
    Function IndexOf(AComponent: TComponent): Integer;
    Function First: TComponent;
    Function Last: TComponent;
    Procedure Insert(Index: Integer; AComponent: TComponent);
    property Items[Index: Integer]: TComponent read GetItems write SetItems; default;
  end;

  TClassList = class(TList)
  protected
    Function GetItems(Index: Integer): TClass;
    Procedure SetItems(Index: Integer; AClass: TClass);
  public
    Function Add(AClass: TClass): Integer;
    Function Extract(Item: TClass): TClass;
    Function Remove(AClass: TClass): Integer;
    Function IndexOf(AClass: TClass): Integer;
    Function First: TClass;
    Function Last: TClass;
    Procedure Insert(Index: Integer; AClass: TClass);
    property Items[Index: Integer]: TClass read GetItems write SetItems; default;
  end;

  TOrderedList = class(TObject)
  private
    FList: TList;
  protected
    Procedure PushItem(AItem: Pointer); virtual; abstract;
    Function PopItem: Pointer; virtual;
    Function PeekItem: Pointer; virtual;
    property List: TList read FList;
  public
    constructor Create;
    destructor Destroy; override;
    Function Count: Integer;
    Function AtLeast(ACount: Integer): Boolean;
    Function Push(AItem: Pointer): Pointer;
    Function Pop: Pointer;
    Function Peek: Pointer;
  end;

{ TStack class }

  TStack = class(TOrderedList)
  protected
    Procedure PushItem(AItem: Pointer); override;
  end;

{ TObjectStack class }

  TObjectStack = class(TStack)
  public
    Function Push(AObject: TObject): TObject;
    Function Pop: TObject;
    Function Peek: TObject;
  end;

{ TQueue class }

  TQueue = class(TOrderedList)
  protected
    Procedure PushItem(AItem: Pointer); override;
  end;

{ TObjectQueue class }

  TObjectQueue = class(TQueue)
  public
    Function Push(AObject: TObject): TObject;
    Function Pop: TObject;
    Function Peek: TObject;
  end;

{ ---------------------------------------------------------------------
    TPList with Hash support
  ---------------------------------------------------------------------}

type
  THashItem=record
    HashValue : LongWord;
    StrIndex  : Integer;
    NextIndex : Integer;
    Data      : Pointer;
  end;
  PHashItem=^THashItem;

const
  MaxHashListSize = Maxint div 16;
  MaxHashStrSize  = Maxint;
  MaxHashTableSize = Maxint div 4;
  MaxItemsPerHash = 3;

type
  PHashItemList = ^THashItemList;
  THashItemList = array[0..MaxHashListSize - 1] of THashItem;
  PHashTable = ^THashTable;
  THashTable = array[0..MaxHashTableSize - 1] of Integer;

{ TFPHashList class }

  TFPHashList = class(TObject)
  private
    { ItemList }
    FHashList     : PHashItemList;
    FCount,
    FCapacity : Integer;
    { Hash }
    FHashTable    : PHashTable;
    FHashCapacity : Integer;
    { Strings }
    FStrs     : PChar;
    FStrCount,
    FStrCapacity : Integer;
  protected
    function Get(Index: Integer): Pointer;
    procedure SetCapacity(NewCapacity: Integer);
    procedure SetCount(NewCount: Integer);
    Procedure RaiseIndexError(Index : Integer);
    function  AddStr(const s:shortstring): Integer;
    procedure AddToHashTable(Index: Integer);
    procedure StrExpand(MinIncSize:Integer);
    procedure SetStrCapacity(NewCapacity: Integer);
    procedure SetHashCapacity(NewCapacity: Integer);
    procedure ReHash;
  public
    constructor Create;
    destructor Destroy; override;
    function Add(const AName:shortstring;Item: Pointer): Integer;
    procedure Clear;
    function NameOfIndex(Index: Integer): String;
    procedure Delete(Index: Integer);
    class procedure Error(const Msg: string; Data: PtrInt);
    function Expand: TFPHashList;
    function Extract(item: Pointer): Pointer;
    function IndexOf(Item: Pointer): Integer;
    function Find(const s:shortstring): Pointer;
    function Remove(Item: Pointer): Integer;
    procedure Pack;
    procedure ShowStatistics;
    procedure ForEachCall(proc2call:TListCallback;arg:pointer);
    procedure ForEachCall(proc2call:TListStaticCallback;arg:pointer);
    property Capacity: Integer read FCapacity write SetCapacity;
    property Count: Integer read FCount write SetCount;
    property Items[Index: Integer]: Pointer read Get; default;
    property List: PHashItemList read FHashList;
    property Strs: PChar read FStrs;
  end;


{ TFPHashObjectList class }

  TFPHashObjectList = class;

  TFPHashObject = class
  private
    FOwner : TFPHashObjectList;
    FCachedStr : pshortstring;
    FStrIndex  : Integer;
  protected
    function GetName:shortstring;
  public
    constructor Create(HashObjectList:TFPHashObjectList;const s:shortstring);
    property Name:shortstring read GetName;
  end;

  TFPHashObjectList = class(TObject)
  private
    FFreeObjects : Boolean;
    FHashList: TFPHashList;
    function GetCount: integer;
    procedure SetCount(const AValue: integer);
  protected
    function GetItem(Index: Integer): TObject;
    procedure SetCapacity(NewCapacity: Integer);
    function GetCapacity: integer;
  public
    constructor Create(FreeObjects : boolean = True);
    destructor Destroy; override;
    procedure Clear;
    function Add(const AName:shortstring;AObject: TObject): Integer;
    function NameOfIndex(Index: Integer): shortstring;
    procedure Delete(Index: Integer);
    function Expand: TFPHashObjectList;
    function Extract(Item: TObject): TObject;
    function Remove(AObject: TObject): Integer;
    function IndexOf(AObject: TObject): Integer;
    function Find(const s:shortstring): TObject;
    function FindInstanceOf(AClass: TClass; AExact: Boolean; AStartAt: Integer): Integer;
    procedure Pack;
    procedure ShowStatistics;
    procedure ForEachCall(proc2call:TObjectListCallback;arg:pointer);
    procedure ForEachCall(proc2call:TObjectListStaticCallback;arg:pointer);
    property Capacity: Integer read GetCapacity write SetCapacity;
    property Count: Integer read GetCount write SetCount;
    property OwnsObjects: Boolean read FFreeObjects write FFreeObjects;
    property Items[Index: Integer]: TObject read GetItem; default;
    property List: TFPHashList read FHashList;
  end;


{ ---------------------------------------------------------------------
    Hash support, implemented by Dean Zobec
  ---------------------------------------------------------------------}


  { Must return a Longword value in the range 0..TableSize,
   usually via a mod operator;  }
  THashFunction = function(const S: string; const TableSize: Longword): Longword;

  TIteratorMethod = procedure(Item: Pointer; const Key: string;
     var Continue: Boolean) of object;

  { THTNode }

  THTNode = class(TObject)
  private
    FData: pointer;
    FKey: string;
  public
    constructor CreateWith(const AString: String);
    function HasKey(const AKey: string): boolean;
    property Key: string read FKey;
    property Data: pointer read FData write FData;
  end;

  { TFPHashTable }

  TFPHashTable = class(TObject)
  private
    FHashTable: TFPObjectList;
    FHashTableSize: Longword;
    FHashFunction: THashFunction;
    FCount: Longword;
    function GetDensity: Longword;
    function GetNumberOfCollisions: Longword;
    procedure SetHashTableSize(const Value: Longword);
    procedure InitializeHashTable;
    function GetVoidSlots: Longword;
    function GetLoadFactor: double;
    function GetAVGChainLen: double;
    function GetMaxChainLength: Longword;
    function Chain(const index: Longword):TFPObjectList;
  protected
    function ChainLength(const ChainIndex: Longword): Longword; virtual;
    procedure SetData(const index: string; const AValue: Pointer); virtual;
    function GetData(const index: string):Pointer; virtual;
    function FindOrCreateNew(const aKey: string): THTNode; virtual;
    function ForEachCall(aMethod: TIteratorMethod): THTNode; virtual;
    procedure SetHashFunction(AHashFunction: THashFunction); virtual;
  public
    constructor Create;
    constructor CreateWith(AHashTableSize: Longword; aHashFunc: THashFunction);
    destructor Destroy; override;
    procedure ChangeTableSize(const ANewSize: Longword); virtual;
    procedure Clear; virtual;
    procedure Add(const aKey: string; AItem: pointer); virtual;
    procedure Delete(const aKey: string); virtual;
    function Find(const aKey: string): THTNode;
    function IsEmpty: boolean;
    property HashFunction: THashFunction read FHashFunction write SetHashFunction;
    property Count: Longword read FCount;
    property HashTableSize: Longword read FHashTableSize write SetHashTableSize;
    property Items[const index: string]: Pointer read GetData write SetData; default;
    property HashTable: TFPObjectList read FHashTable;
    property VoidSlots: Longword read GetVoidSlots;
    property LoadFactor: double read GetLoadFactor;
    property AVGChainLen: double read GetAVGChainLen;
    property MaxChainLength: Longword read GetMaxChainLength;
    property NumberOfCollisions: Longword read GetNumberOfCollisions;
    property Density: Longword read GetDensity;
  end;

  EDuplicate = class(Exception);
  EKeyNotFound = class(Exception);


  function RSHash(const S: string; const TableSize: Longword): Longword;

implementation

uses
  RtlConsts;

ResourceString
  DuplicateMsg = 'An item with key %0:s already exists';
  KeyNotFoundMsg = 'Method: %0:s key [''%1:s''] not found in container';
  NotEmptyMsg = 'Hash table not empty.';

const
  NPRIMES = 28;

  PRIMELIST: array[0 .. NPRIMES-1] of Longword =
  ( 53,         97,         193,       389,       769,
    1543,       3079,       6151,      12289,     24593,
    49157,      98317,      196613,    393241,    786433,
    1572869,    3145739,    6291469,   12582917,  25165843,
    50331653,   100663319,  201326611, 402653189, 805306457,
    1610612741, 3221225473, 4294967291 );

constructor TFPObjectList.Create(FreeObjects : boolean);
begin
  Create;
  FFreeObjects := Freeobjects;
end;

destructor TFPObjectList.Destroy;
begin
  if (FList <> nil) then
  begin
    Clear;
    FList.Destroy;
  end;
  inherited Destroy;
end;

procedure TFPObjectList.Clear;
var
  i: integer;
begin
  if FFreeObjects then
    for i := 0 to FList.Count - 1 do
      TObject(FList[i]).Free;
  FList.Clear;
end;

constructor TFPObjectList.Create;
begin
  inherited Create;
  FList := TFPList.Create;
  FFreeObjects := True;
end;

function TFPObjectList.GetCount: integer;
begin
  Result := FList.Count;
end;

procedure TFPObjectList.SetCount(const AValue: integer);
begin
  if FList.Count <> AValue then
    FList.Count := AValue;
end;

function TFPObjectList.GetItem(Index: Integer): TObject; {$ifdef CLASSESINLINE}inline;{$endif}
begin
  Result := TObject(FList[Index]);
end;

procedure TFPObjectList.SetItem(Index: Integer; AObject: TObject); {$ifdef CLASSESINLINE}inline;{$endif}
begin
  if OwnsObjects then
    TObject(FList[Index]).Free;
  FList[index] := AObject;
end;

procedure TFPObjectList.SetCapacity(NewCapacity: Integer);
begin
  FList.Capacity := NewCapacity;
end;

function TFPObjectList.GetCapacity: integer;
begin
  Result := FList.Capacity;
end;

function TFPObjectList.Add(AObject: TObject): Integer; {$ifdef CLASSESINLINE}inline;{$endif}
begin
  Result := FList.Add(AObject);
end;

procedure TFPObjectList.Delete(Index: Integer); {$ifdef CLASSESINLINE}inline;{$endif}
begin
  if OwnsObjects then
    TObject(FList[Index]).Free;
  FList.Delete(Index);
end;

procedure TFPObjectList.Exchange(Index1, Index2: Integer);
begin
  FList.Exchange(Index1, Index2);
end;

function TFPObjectList.Expand: TFPObjectList;
begin
  FList.Expand;
  Result := Self;
end;

function TFPObjectList.Extract(Item: TObject): TObject;
begin
  Result := TObject(FList.Extract(Item));
end;

function TFPObjectList.Remove(AObject: TObject): Integer;
begin
  Result := IndexOf(AObject);
  if (Result <> -1) then
  begin
    if OwnsObjects then
      TObject(FList[Result]).Free;
    FList.Delete(Result);
  end;
end;

function TFPObjectList.IndexOf(AObject: TObject): Integer;
begin
  Result := FList.IndexOf(Pointer(AObject));
end;

function TFPObjectList.FindInstanceOf(AClass: TClass; AExact: Boolean; AStartAt : Integer): Integer;
var
  I : Integer;
begin
  I:=AStartAt;
  Result:=-1;
  If AExact then
    while (I<Count) and (Result=-1) do
      If Items[i].ClassType=AClass then
        Result:=I
      else
        Inc(I)
  else
    while (I<Count) and (Result=-1) do
      If Items[i].InheritsFrom(AClass) then
        Result:=I
      else
        Inc(I);
end;

procedure TFPObjectList.Insert(Index: Integer; AObject: TObject); {$ifdef CLASSESINLINE}inline;{$endif}
begin
  FList.Insert(Index, Pointer(AObject));
end;

procedure TFPObjectList.Move(CurIndex, NewIndex: Integer);
begin
  FList.Move(CurIndex, NewIndex);
end;

procedure TFPObjectList.Assign(Obj: TFPObjectList);
var
  i: Integer;
begin
  Clear;
  for I := 0 to Obj.Count - 1 do
    Add(Obj[i]);
end;

procedure TFPObjectList.Pack;
begin
  FList.Pack;
end;

procedure TFPObjectList.Sort(Compare: TListSortCompare);
begin
  FList.Sort(Compare);
end;

function TFPObjectList.First: TObject;
begin
  Result := TObject(FList.First);
end;

function TFPObjectList.Last: TObject;
begin
  Result := TObject(FList.Last);
end;

procedure TFPObjectList.ForEachCall(proc2call:TObjectListCallback;arg:pointer);
begin
  FList.ForEachCall(TListCallBack(proc2call),arg);
end;

procedure TFPObjectList.ForEachCall(proc2call:TObjectListStaticCallback;arg:pointer);
begin
  FList.ForEachCall(TListStaticCallBack(proc2call),arg);
end;


{ TObjectList }

constructor tobjectlist.create(freeobjects : boolean);

begin
  inherited create;
  ffreeobjects:=freeobjects;
end;

Constructor tobjectlist.create;

begin
  inherited create;
  ffreeobjects:=True;
end;

Procedure TObjectList.Notify(Ptr: Pointer; Action: TListNotification);

begin
  if FFreeObjects then
    if (Action=lnDeleted) then
      TObject(Ptr).Free;
  inherited Notify(Ptr,Action);
end;


Function TObjectList.GetItem(Index: Integer): TObject;

begin
  Result:=TObject(Inherited Get(Index));
end;


Procedure TObjectList.SetItem(Index: Integer; AObject: TObject);

Var
  O : TObject;

begin
  if OwnsObjects then
    begin
    O:=GetItem(Index);
    O.Free;
    end;
  Put(Index,Pointer(AObject));
end;


Function TObjectList.Add(AObject: TObject): Integer;

begin
  Result:=Inherited Add(Pointer(AObject));
end;


Function TObjectList.Extract(Item: TObject): TObject;

begin
  Result:=Tobject(Inherited Extract(Pointer(Item)));
end;


Function TObjectList.Remove(AObject: TObject): Integer;

begin
  Result:=Inherited Remove(Pointer(AObject));
end;


Function TObjectList.IndexOf(AObject: TObject): Integer;

begin
  Result:=Inherited indexOF(Pointer(AObject));
end;


Function TObjectList.FindInstanceOf(AClass: TClass; AExact: Boolean; AStartAt : Integer): Integer;

Var
  I : Integer;

begin
  I:=AStartAt;
  Result:=-1;
  If AExact then
    While (I<Count) and (Result=-1) do
      If Items[i].ClassType=AClass then
        Result:=I
      else
        Inc(I)
  else
    While (I<Count) and (Result=-1) do
      If Items[i].InheritsFrom(AClass) then
        Result:=I
      else
        Inc(I);
end;


procedure TObjectList.Insert(Index: Integer; AObject: TObject);
begin
  Inherited Insert(Index,Pointer(AObject));
end;


function TObjectList.First: TObject;

begin
  Result := TObject(Inherited First);
end;


function TObjectList.Last: TObject;

begin
  Result := TObject(Inherited Last);
end;

{ TListComponent }

Type
  TlistComponent = Class(TComponent)
  Private
    Flist : TComponentList;
  Public
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  end;

procedure TlistComponent.Notification(AComponent: TComponent;
  Operation: TOperation);
begin
  If (Operation=opremove) then
    Flist.HandleFreeNotify(Self,AComponent);
  inherited;
end;

{ TComponentList }

Function TComponentList.Add(AComponent: TComponent): Integer;
begin
  Result:=Inherited Add(AComponent);
end;

destructor TComponentList.Destroy;
begin
  inherited;
  FreeAndNil(FNotifier);
end;

Function TComponentList.Extract(Item: TComponent): TComponent;
begin
  Result:=TComponent(Inherited Extract(Item));
end;

Function TComponentList.First: TComponent;
begin
  Result:=TComponent(Inherited First);
end;

Function TComponentList.GetItems(Index: Integer): TComponent;
begin
  Result:=TComponent(Inherited Items[Index]);
end;

Procedure TComponentList.HandleFreeNotify(Sender: TObject;
  AComponent: TComponent);
begin
  Extract(Acomponent);
end;

Function TComponentList.IndexOf(AComponent: TComponent): Integer;
begin
  Result:=Inherited IndexOf(AComponent);
end;

Procedure TComponentList.Insert(Index: Integer; AComponent: TComponent);
begin
  Inherited Insert(Index,Acomponent)
end;

Function TComponentList.Last: TComponent;
begin
  Result:=TComponent(Inherited Last);
end;

Procedure TComponentList.Notify(Ptr: Pointer; Action: TListNotification);
begin
  If FNotifier=NIl then
    begin
    FNotifier:=TlistComponent.Create(nil);
    TlistComponent(FNotifier).FList:=Self;
    end;
  If Assigned(Ptr) then
    With TComponent(Ptr) do
      case Action of
        lnAdded : FreeNotification(FNotifier);
        lnExtracted, lnDeleted: RemoveFreeNotification(FNotifier);
      end;
  inherited Notify(Ptr, Action);
end;

Function TComponentList.Remove(AComponent: TComponent): Integer;
begin
  Result:=Inherited Remove(AComponent);
end;

Procedure TComponentList.SetItems(Index: Integer; AComponent: TComponent);
begin
  Put(Index,AComponent);
end;

{ TClassList }

Function TClassList.Add(AClass: TClass): Integer;
begin
  Result:=Inherited Add(Pointer(AClass));
end;

Function TClassList.Extract(Item: TClass): TClass;
begin
  Result:=TClass(Inherited Extract(Pointer(Item)));
end;

Function TClassList.First: TClass;
begin
  Result:=TClass(Inherited First);
end;

Function TClassList.GetItems(Index: Integer): TClass;
begin
  Result:=TClass(Inherited Items[Index]);
end;

Function TClassList.IndexOf(AClass: TClass): Integer;
begin
  Result:=Inherited IndexOf(Pointer(AClass));
end;

Procedure TClassList.Insert(Index: Integer; AClass: TClass);
begin
  Inherited Insert(index,Pointer(AClass));
end;

Function TClassList.Last: TClass;
begin
  Result:=TClass(Inherited Last);
end;

Function TClassList.Remove(AClass: TClass): Integer;
begin
  Result:=Inherited Remove(Pointer(AClass));
end;

Procedure TClassList.SetItems(Index: Integer; AClass: TClass);
begin
  Put(Index,Pointer(Aclass));
end;

{ TOrderedList }

Function TOrderedList.AtLeast(ACount: Integer): Boolean;
begin
  Result:=(FList.Count>=Acount)
end;

Function TOrderedList.Count: Integer;
begin
  Result:=FList.Count;
end;

constructor TOrderedList.Create;
begin
  FList:=Tlist.Create;
end;

destructor TOrderedList.Destroy;
begin
  FList.Free;
end;

Function TOrderedList.Peek: Pointer;
begin
  If AtLeast(1) then
    Result:=PeekItem
  else
    Result:=Nil;
end;

Function TOrderedList.PeekItem: Pointer;
begin
  With Flist do
    Result:=Items[Count-1]
end;

Function TOrderedList.Pop: Pointer;
begin
  If Atleast(1) then
    Result:=PopItem
  else
    Result:=Nil;
end;

Function TOrderedList.PopItem: Pointer;
begin
  With FList do
    If Count>0 then
      begin
      Result:=Items[Count-1];
      Delete(Count-1);
      end
    else
      Result:=Nil;
end;

Function TOrderedList.Push(AItem: Pointer): Pointer;
begin
  PushItem(Aitem);
  Result:=AItem;
end;

{ TStack }

Procedure TStack.PushItem(AItem: Pointer);
begin
  FList.Add(Aitem);
end;

{ TObjectStack }

Function TObjectStack.Peek: TObject;
begin
  Result:=TObject(Inherited Peek);
end;

Function TObjectStack.Pop: TObject;
begin
  Result:=TObject(Inherited Pop);
end;

Function TObjectStack.Push(AObject: TObject): TObject;
begin
  Result:=TObject(Inherited Push(Pointer(AObject)));
end;

{ TQueue }

Procedure TQueue.PushItem(AItem: Pointer);
begin
  With Flist Do
    Insert(0,AItem);
end;

{ TObjectQueue }

Function TObjectQueue.Peek: TObject;
begin
  Result:=TObject(Inherited Peek);
end;

Function TObjectQueue.Pop: TObject;
begin
  Result:=TObject(Inherited Pop);
end;

Function TObjectQueue.Push(AObject: TObject): TObject;
begin
  Result:=TObject(Inherited Push(Pointer(Aobject)));
end;


{*****************************************************************************
                            TFPHashList
*****************************************************************************}

    function FPHash1(const s:string):LongWord;
      Var
        g : LongWord;
        p,pmax : pchar;
      begin
        result:=0;
        p:=@s[1];
        pmax:=@s[length(s)+1];
        while (p<pmax) do
          begin
            result:=result shl 4 + LongWord(p^);
            g:=result and LongWord($F0000000);
            if g<>0 then
              result:=result xor (g shr 24) xor g;
            inc(p);
          end;
        If result=0 then
          result:=$ffffffff;
      end;

    function FPHash(const s:string):LongWord;
      Var
        p,pmax : pchar;
      begin
{$ifopt Q+}
{$define overflowon}
{$Q-}
{$endif}
        result:=0;
        p:=@s[1];
        pmax:=@s[length(s)+1];
        while (p<pmax) do
          begin
            result:=LongWord((result shl 5) - result) xor LongWord(P^);
            inc(p);
          end;
{$ifdef overflowon}
{$Q+}
{$undef overflowon}
{$endif}
      end;


procedure TFPHashList.RaiseIndexError(Index : Integer);
begin
  Error(SListIndexError, Index);
end;


function TFPHashList.Get(Index: Integer): Pointer;
begin
  If (Index < 0) or (Index >= FCount) then
    RaiseIndexError(Index);
  Result:=FHashList^[Index].Data;
end;


function TFPHashList.NameOfIndex(Index: Integer): String;
begin
  If (Index < 0) or (Index >= FCount) then
    RaiseIndexError(Index);
  with FHashList^[Index] do
    begin
      if StrIndex>=0 then
        Result:=PShortString(@FStrs[StrIndex])^
      else
        Result:='';
    end;
end;


function TFPHashList.Extract(item: Pointer): Pointer;
var
  i : Integer;
begin
  result := nil;
  i := IndexOf(item);
  if i >= 0 then
   begin
     Result := item;
     Delete(i);
   end;
end;


procedure TFPHashList.SetCapacity(NewCapacity: Integer);
begin
  If (NewCapacity < FCount) or (NewCapacity > MaxHashListSize) then
     Error (SListCapacityError, NewCapacity);
  if NewCapacity = FCapacity then
    exit;
  ReallocMem(FHashList, NewCapacity*SizeOf(THashItem));
  FCapacity := NewCapacity;
end;


procedure TFPHashList.SetCount(NewCount: Integer);
begin
  if (NewCount < 0) or (NewCount > MaxHashListSize)then
    Error(SListCountError, NewCount);
  If NewCount > FCount then
    begin
      If NewCount > FCapacity then
        SetCapacity(NewCount);
      If FCount < NewCount then
        FillChar(FHashList^[FCount], (NewCount-FCount) div Sizeof(THashItem), 0);
    end;
  FCount := Newcount;
end;


procedure TFPHashList.SetStrCapacity(NewCapacity: Integer);
begin
  If (NewCapacity < FStrCount) or (NewCapacity > MaxHashStrSize) then
     Error (SListCapacityError, NewCapacity);
  if NewCapacity = FStrCapacity then
    exit;
  ReallocMem(FStrs, NewCapacity);
  FStrCapacity := NewCapacity;
end;


procedure TFPHashList.SetHashCapacity(NewCapacity: Integer);
begin
  If (NewCapacity < 1) then
    Error (SListCapacityError, NewCapacity);
  if FHashCapacity=NewCapacity then
    exit;
  FHashCapacity:=NewCapacity;
  ReallocMem(FHashTable, FHashCapacity*sizeof(Integer));
  ReHash;
end;


procedure TFPHashList.ReHash;
var
  i : Integer;
begin
  FillDword(FHashTable^,FHashCapacity,LongWord(-1));
  For i:=0 To FCount-1 Do
    AddToHashTable(i);
end;


constructor TFPHashList.Create;
begin
  SetHashCapacity(1);
end;


destructor TFPHashList.Destroy;
begin
  Clear;
  if assigned(FHashTable) then
    FreeMem(FHashTable);
  inherited Destroy;
end;


function TFPHashList.AddStr(const s:shortstring): Integer;
var
  Len : Integer;
begin
  len:=length(s)+1;
  if FStrCount+Len >= FStrCapacity then
    StrExpand(Len);
  System.Move(s[0],FStrs[FStrCount],Len);
  result:=FStrCount;
  inc(FStrCount,Len);
end;


procedure TFPHashList.AddToHashTable(Index: Integer);
var
  HashIndex : Integer;
begin
  with FHashList^[Index] do
    begin
      if not assigned(Data) then
        exit;
      HashIndex:=HashValue mod LongWord(FHashCapacity);
      NextIndex:=FHashTable^[HashIndex];
      FHashTable^[HashIndex]:=Index;
    end;
end;


function TFPHashList.Add(const AName:shortstring;Item: Pointer): Integer;
begin
  if FCount = FCapacity then
    Expand;
  with FHashList^[FCount] do
    begin
      HashValue:=FPHash(AName);
      Data:=Item;
      StrIndex:=AddStr(AName);
    end;
  AddToHashTable(FCount);
  Result := FCount;
  inc(FCount);
end;

procedure TFPHashList.Clear;
begin
  if Assigned(FHashList) then
    begin
      FCount:=0;
      SetCapacity(0);
      FHashList := nil;
    end;
  SetHashCapacity(1);
  if Assigned(FStrs) then
    begin
      FStrCount:=0;
      SetStrCapacity(0);
      FStrs := nil;
    end;
end;

procedure TFPHashList.Delete(Index: Integer);
begin
  If (Index<0) or (Index>=FCount) then
    Error (SListIndexError, Index);
  with FHashList^[Index] do
    begin
      Data:=nil;
      StrIndex:=-1;
    end;
end;

class procedure TFPHashList.Error(const Msg: string; Data: PtrInt);
begin
  Raise EListError.CreateFmt(Msg,[Data]) at get_caller_addr(get_frame);
end;

function TFPHashList.Expand: TFPHashList;
var
  IncSize : Longint;
begin
  Result := Self;
  if FCount < FCapacity then
    exit;
  IncSize := 4;
  if FCapacity > 127 then
    Inc(IncSize, FCapacity shr 2)
  else if FCapacity > 8 then
    inc(IncSize,8)
  else if FCapacity > 3 then
    inc(IncSize,4);
  SetCapacity(FCapacity + IncSize);
  { Maybe expand hash also }
  if FCount>FHashCapacity*MaxItemsPerHash then
    SetHashCapacity(FCount div MaxItemsPerHash);
end;

procedure TFPHashList.StrExpand(MinIncSize:Integer);
var
  IncSize : Longint;
begin
  if FStrCount+MinIncSize < FStrCapacity then
    exit;
  IncSize := 64+MinIncSize;
  if FStrCapacity > 255 then
    Inc(IncSize, FStrCapacity shr 2);
  SetStrCapacity(FStrCapacity + IncSize);
end;

function TFPHashList.IndexOf(Item: Pointer): Integer;
begin
  Result := 0;
  while(Result < FCount) and (FHashList^[Result].Data <> Item) do
    inc(Result);
  If Result = FCount then
    Result := -1;
end;

function TFPHashList.Find(const s:shortstring): Pointer;
var
  CurrHash : LongWord;
  Index,
  HashIndex : Integer;
  Len,
  LastChar  : Char;
begin
  CurrHash:=FPHash(s);
  HashIndex:=CurrHash mod LongWord(FHashCapacity);
  Index:=FHashTable^[HashIndex];
  Len:=Char(Length(s));
  LastChar:=s[Byte(Len)];
  while Index<>-1 do
    begin
      with FHashList^[Index] do
        begin
          if assigned(Data) and
             (HashValue=CurrHash) and
             (Len=FStrs[StrIndex]) and
             (LastChar=FStrs[StrIndex+Byte(Len)]) and
             (s=PShortString(@FStrs[StrIndex])^) then
            begin
              Result:=Data;
              exit;
            end;
          Index:=NextIndex;
        end;
    end;
  Result:=nil;
end;

function TFPHashList.Remove(Item: Pointer): Integer;
begin
  Result := IndexOf(Item);
  If Result <> -1 then
    Self.Delete(Result);
end;

procedure TFPHashList.Pack;
var
  NewCount,
  i : integer;
  pdest,
  psrc : PHashItem;
begin
  NewCount:=0;
  psrc:=@FHashList[0];
  pdest:=psrc;
  For I:=0 To FCount-1 Do
    begin
      if assigned(psrc^.Data) then
        begin
          pdest^:=psrc^;
          inc(pdest);
          inc(NewCount);
        end;
      inc(psrc);
    end;
  FCount:=NewCount;
  { We need to ReHash to update the IndexNext }
  ReHash;
  { Release over-capacity }
  SetCapacity(FCount);
  SetStrCapacity(FStrCount);
end;


procedure TFPHashList.ShowStatistics;
var
  HashMean,
  HashStdDev : Double;
  Index,
  i,j : Integer;
begin
  { Calculate Mean and StdDev }
  HashMean:=0;
  HashStdDev:=0;
  for i:=0 to FHashCapacity-1 do
    begin
      j:=0;
      Index:=FHashTable^[i];
      while (Index<>-1) do
        begin
          inc(j);
          Index:=FHashList^[Index].NextIndex;
        end;
      HashMean:=HashMean+j;
      HashStdDev:=HashStdDev+Sqr(j);
    end;
  HashMean:=HashMean/FHashCapacity;
  HashStdDev:=(HashStdDev-FHashCapacity*Sqr(HashMean));
  If FHashCapacity>1 then
    HashStdDev:=Sqrt(HashStdDev/(FHashCapacity-1))
  else
    HashStdDev:=0;
  { Print info to stdout }
  Writeln('HashSize   : ',FHashCapacity);
  Writeln('HashMean   : ',HashMean:1:4);
  Writeln('HashStdDev : ',HashStdDev:1:4);
  Writeln('ListSize   : ',FCount,'/',FCapacity);
  Writeln('StringSize : ',FStrCount,'/',FStrCapacity);
end;


procedure TFPHashList.ForEachCall(proc2call:TListCallback;arg:pointer);
var
  i : integer;
  p : pointer;
begin
  For I:=0 To Count-1 Do
    begin
      p:=FHashList^[i].Data;
      if assigned(p) then
        proc2call(p,arg);
    end;
end;


procedure TFPHashList.ForEachCall(proc2call:TListStaticCallback;arg:pointer);
var
  i : integer;
  p : pointer;
begin
  For I:=0 To Count-1 Do
    begin
      p:=FHashList^[i].Data;
      if assigned(p) then
        proc2call(p,arg);
    end;
end;


{*****************************************************************************
                               TFPHashObject
*****************************************************************************}

constructor TFPHashObject.Create(HashObjectList:TFPHashObjectList;const s:shortstring);
var
  Index : Integer;
begin
  FOwner:=HashObjectList;
  Index:=HashObjectList.Add(s,Self);
  FStrIndex:=HashObjectList.List.List^[Index].StrIndex;
  FCachedStr:=PShortString(@FOwner.List.Strs[FStrIndex]);
end;


function TFPHashObject.GetName:shortstring;
begin
  FCachedStr:=PShortString(@FOwner.List.Strs[FStrIndex]);
  Result:=FCachedStr^;
end;


{*****************************************************************************
            TFPHashObjectList (Copied from rtl/objpas/classes/lists.inc)
*****************************************************************************}

constructor TFPHashObjectList.Create(FreeObjects : boolean = True);
begin
  inherited Create;
  FHashList := TFPHashList.Create;
  FFreeObjects := Freeobjects;
end;

destructor TFPHashObjectList.Destroy;
begin
  if (FHashList <> nil) then
  begin
    Clear;
    FHashList.Destroy;
  end;
  inherited Destroy;
end;

procedure TFPHashObjectList.Clear;
var
  i: integer;
begin
  if FFreeObjects then
    for i := 0 to FHashList.Count - 1 do
      TObject(FHashList[i]).Free;
  FHashList.Clear;
end;

function TFPHashObjectList.GetCount: integer;
begin
  Result := FHashList.Count;
end;

procedure TFPHashObjectList.SetCount(const AValue: integer);
begin
  if FHashList.Count <> AValue then
    FHashList.Count := AValue;
end;

function TFPHashObjectList.GetItem(Index: Integer): TObject;
begin
  Result := TObject(FHashList[Index]);
end;

procedure TFPHashObjectList.SetCapacity(NewCapacity: Integer);
begin
  FHashList.Capacity := NewCapacity;
end;

function TFPHashObjectList.GetCapacity: integer;
begin
  Result := FHashList.Capacity;
end;

function TFPHashObjectList.Add(const AName:shortstring;AObject: TObject): Integer;
begin
  Result := FHashList.Add(AName,AObject);
end;

function TFPHashObjectList.NameOfIndex(Index: Integer): shortString;
begin
  Result := FHashList.NameOfIndex(Index);
end;

procedure TFPHashObjectList.Delete(Index: Integer);
begin
  if OwnsObjects then
    TObject(FHashList[Index]).Free;
  FHashList.Delete(Index);
end;

function TFPHashObjectList.Expand: TFPHashObjectList;
begin
  FHashList.Expand;
  Result := Self;
end;

function TFPHashObjectList.Extract(Item: TObject): TObject;
begin
  Result := TObject(FHashList.Extract(Item));
end;

function TFPHashObjectList.Remove(AObject: TObject): Integer;
begin
  Result := IndexOf(AObject);
  if (Result <> -1) then
  begin
    if OwnsObjects then
      TObject(FHashList[Result]).Free;
    FHashList.Delete(Result);
  end;
end;

function TFPHashObjectList.IndexOf(AObject: TObject): Integer;
begin
  Result := FHashList.IndexOf(Pointer(AObject));
end;


function TFPHashObjectList.Find(const s:shortstring): TObject;
begin
  result:=TObject(FHashList.Find(s));
end;


function TFPHashObjectList.FindInstanceOf(AClass: TClass; AExact: Boolean; AStartAt : Integer): Integer;
var
  I : Integer;
begin
  I:=AStartAt;
  Result:=-1;
  If AExact then
    while (I<Count) and (Result=-1) do
      If Items[i].ClassType=AClass then
        Result:=I
      else
        Inc(I)
  else
    while (I<Count) and (Result=-1) do
      If Items[i].InheritsFrom(AClass) then
        Result:=I
      else
        Inc(I);
end;


procedure TFPHashObjectList.Pack;
begin
  FHashList.Pack;
end;


procedure TFPHashObjectList.ShowStatistics;
begin
  FHashList.ShowStatistics;
end;


procedure TFPHashObjectList.ForEachCall(proc2call:TObjectListCallback;arg:pointer);
begin
  FHashList.ForEachCall(TListCallBack(proc2call),arg);
end;


procedure TFPHashObjectList.ForEachCall(proc2call:TObjectListStaticCallback;arg:pointer);
begin
  FHashList.ForEachCall(TListStaticCallBack(proc2call),arg);
end;


{ ---------------------------------------------------------------------
    Hash support, by Dean Zobec
  ---------------------------------------------------------------------}

{ Default hash function }

function RSHash(const S: string; const TableSize: Longword): Longword;
const
  b = 378551;
var
  a: Longword;
  i: Longword;
begin
 a := 63689;
 Result := 0;
 if length(s)>0 then
   for i := 1 to Length(S) do
   begin
     Result := Result * a + Ord(S[i]);
     a := a * b;
   end;
 Result := (Result and $7FFFFFFF) mod TableSize;
end;

{ THTNode }

constructor THTNode.CreateWith(const AString: string);
begin
  inherited Create;
  FKey := AString;
end;

function THTNode.HasKey(const AKey: string): boolean;
begin
  if Length(AKey) <> Length(FKey) then
  begin
    Result := false;
    exit;
  end
  else
    Result := CompareMem(PChar(FKey), PChar(AKey), length(AKey));
end;

{ TFPHashTable }

constructor TFPHashTable.Create;
begin
  Inherited Create;
  FHashTable := TFPObjectList.Create(True);
  HashTableSize := 196613;
  FHashFunction := @RSHash;
end;

constructor TFPHashTable.CreateWith(AHashTableSize: Longword;
  aHashFunc: THashFunction);
begin
  Inherited Create;
  FHashTable := TFPObjectList.Create(True);
  HashTableSize := AHashTableSize;
  FHashFunction := aHashFunc;
end;

destructor TFPHashTable.Destroy;
begin
  FHashTable.Free;
  inherited Destroy;
end;

function TFPHashTable.GetDensity: Longword;
begin
  Result := FHashTableSize - VoidSlots
end;

function TFPHashTable.GetNumberOfCollisions: Longword;
begin
  Result := FCount -(FHashTableSize - VoidSlots)
end;

procedure TFPHashTable.SetData(const index: string; const AValue: Pointer);
begin
  FindOrCreateNew(index).Data := AValue;
end;

procedure TFPHashTable.SetHashTableSize(const Value: Longword);
var
  i: Longword;
  newSize: Longword;
begin
  if Value <> FHashTableSize then
  begin
    i := 0;
    while (PRIMELIST[i] < Value) and (i < 27) do
     inc(i);
    newSize := PRIMELIST[i];
    if Count = 0 then
    begin
      FHashTableSize := newSize;
      InitializeHashTable;
    end
    else
      ChangeTableSize(newSize);
  end;
end;

procedure TFPHashTable.InitializeHashTable;
var
  i: LongWord;
begin
  if FHashTableSize>0 Then
    for i := 0 to FHashTableSize-1 do
     FHashTable.Add(nil);
  FCount := 0;
end;

procedure TFPHashTable.ChangeTableSize(const ANewSize: Longword);
var
  SavedTable: TFPObjectList;
  SavedTableSize: Longword;
  i, j: Longword;
  temp: THTNode;
begin
  SavedTable := FHashTable;
  SavedTableSize := FHashTableSize;
  FHashTableSize := ANewSize;
  FHashTable := TFPObjectList.Create(True);
  InitializeHashTable;
  If SavedTableSize>0 Then
    for i := 0 to SavedTableSize-1 do
    begin
      if Assigned(SavedTable[i]) then
      for j := 0 to TFPObjectList(SavedTable[i]).Count -1 do
      begin
        temp := THTNode(TFPObjectList(SavedTable[i])[j]);
        Add(temp.Key, temp.Data);
      end;
    end;
  SavedTable.Free;
end;

procedure TFPHashTable.SetHashFunction(AHashFunction: THashFunction);
begin
  if IsEmpty then
    FHashFunction := AHashFunction
  else
    raise Exception.Create(NotEmptyMsg);
end;

function TFPHashTable.Find(const aKey: string): THTNode;
var
  hashCode: Longword;
  chn: TFPObjectList;
  i: Longword;
begin
  hashCode := FHashFunction(aKey, FHashTableSize);
  chn := Chain(hashCode);
  if Assigned(chn) then
  begin
    if chn.count>0 then
     for i := 0 to chn.Count - 1 do
      if THTNode(chn[i]).HasKey(aKey) then
      begin
        result := THTNode(chn[i]);
        exit;
      end;
  end;
  Result := nil;
end;

function TFPHashTable.GetData(const Index: string): Pointer;
var
  node: THTNode;
begin
  node := Find(Index);
  if Assigned(node) then
    Result := node.Data
  else
    Result := nil;
end;

function TFPHashTable.FindOrCreateNew(const aKey: string): THTNode;
var
  hashCode: Longword;
  chn: TFPObjectList;
  i: Longword;
begin
  hashCode := FHashFunction(aKey, FHashTableSize);
  chn := Chain(hashCode);
  if Assigned(chn)  then
  begin
    if chn.count>0 then
     for i := 0 to chn.Count - 1 do
      if THTNode(chn[i]).HasKey(aKey) then
        begin
          Result := THTNode(chn[i]);
          exit;
        end
  end
  else
    begin
      FHashTable[hashcode] := TFPObjectList.Create(true);
      chn := Chain(hashcode);
    end;
  inc(FCount);
  Result := THTNode.CreateWith(aKey);
  chn.Add(Result);
end;

function TFPHashTable.ChainLength(const ChainIndex: Longword): Longword;
begin
  if Assigned(Chain(ChainIndex)) then
    Result := Chain(ChainIndex).Count
  else
    Result := 0;
end;

procedure TFPHashTable.Clear;
var
  i: Longword;
begin
  if FHashTableSize>0 Then
    for i := 0 to FHashTableSize - 1 do
      begin
        if Assigned(Chain(i)) then
          Chain(i).Clear;
      end;
  FCount := 0;
end;

function TFPHashTable.ForEachCall(aMethod: TIteratorMethod): THTNode;
var
  i, j: Longword;
  continue: boolean;
begin
  Result := nil;
  continue := true;
  if FHashTableSize>0 then
   for i := 0 to FHashTableSize-1 do
    begin
      if assigned(Chain(i)) then
      begin
       if chain(i).count>0 then
        for j := 0 to Chain(i).Count-1 do
        begin
          aMethod(THTNode(Chain(i)[j]).Data, THTNode(Chain(i)[j]).Key, continue);
          if not continue then
          begin
            Result := THTNode(Chain(i)[j]);
            Exit;
          end;
        end;
      end;
    end;
end;

procedure TFPHashTable.Add(const aKey: string; aItem: pointer);
var
  hashCode: Longword;
  chn: TFPObjectList;
  i: Longword;
  NewNode: THtNode;
begin
  hashCode := FHashFunction(aKey, FHashTableSize);
  chn := Chain(hashCode);
  if Assigned(chn)  then
  begin
    if chn.count>0 then
      for i := 0 to chn.Count - 1 do
        if THTNode(chn[i]).HasKey(aKey) then
          Raise EDuplicate.CreateFmt(DuplicateMsg, [aKey]);
  end
  else
    begin
      FHashTable[hashcode] := TFPObjectList.Create(true);
      chn := Chain(hashcode);
    end;
  inc(FCount);
  NewNode := THTNode.CreateWith(aKey);
  NewNode.Data := aItem;
  chn.Add(NewNode);
end;

procedure TFPHashTable.Delete(const aKey: string);
var
  hashCode: Longword;
  chn: TFPObjectList;
  i: Longword;
begin
  hashCode := FHashFunction(aKey, FHashTableSize);
  chn := Chain(hashCode);
  if Assigned(chn) then
  begin
    if chn.count>0 then
    for i := 0 to chn.Count - 1 do
      if THTNode(chn[i]).HasKey(aKey) then
      begin
        chn.Delete(i);
        dec(FCount);
        exit;
      end;
  end;
  raise EKeyNotFound.CreateFmt(KeyNotFoundMsg, ['Delete', aKey]);
end;

function TFPHashTable.IsEmpty: boolean;
begin
  Result := (FCount = 0);
end;

function TFPHashTable.Chain(const index: Longword): TFPObjectList;
begin
  Result := TFPObjectList(FHashTable[index]);
end;

function TFPHashTable.GetVoidSlots: Longword;
var
  i: Longword;
  num: Longword;
begin
  num := 0;
  if FHashTableSize>0 Then
    for i:= 0 to FHashTableSize-1 do
      if Not Assigned(Chain(i)) then
        inc(num);
  result := num;
end;

function TFPHashTable.GetLoadFactor: double;
begin
  Result := Count / FHashTableSize;
end;

function TFPHashTable.GetAVGChainLen: double;
begin
  result := Count / (FHashTableSize - VoidSlots);
end;

function TFPHashTable.GetMaxChainLength: Longword;
var
  i: Longword;
begin
  Result := 0;
  if FHashTableSize>0 Then
   for i := 0 to FHashTableSize-1 do
      if ChainLength(i) > Result then
        Result := ChainLength(i);
end;

end.
