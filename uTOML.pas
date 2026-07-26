unit uTOML;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, fgl;

type
  { --- FGLによる動的配列・多重配列型の定義 --- }
  
  { 1次元実数配列型 }
  TDoubleList = specialize TFPGList<Double>;
  { 1次元文字列配列型 }
  TStringFGLList = specialize TFPGList<string>;
  { 2次元実数配列型 (多重配列: TDoubleListのリスト) }
  TDoubleMatrix = specialize TFPGObjectList<TDoubleList>;

  { --- キーバリュー管理クラス --- }
  
  TTomlPair = class
  public
    Key: string;
    RawValue: string;
    constructor Create(const AKey, ARawValue: string);
  end;

  TTomlPairList = specialize TFPGObjectList<TTomlPair>;

  { --- TOMLテーブル（1セクションまたは1オブジェクト）クラス --- }
  
  TTomlTable = class
  private
    FPairs: TTomlPairList;
    function FindPair(const AKey: string): TTomlPair;
    function CleanString(const AStr: string): string;
  public
    constructor Create;
    destructor Destroy; override;

    procedure SetValue(const AKey, ARawValue: string);
    function HasKey(const AKey: string): Boolean;

    { =================================================== }
    { 1. 単一値を取り出す関数群 (Getter & Overload)      }
    { =================================================== }
    function GetString(const AKey: string; const ADefault: string = ''): string;
    function GetInt(const AKey: string; const ADefault: Integer = 0): Integer;
    function GetFloat(const AKey: string; const ADefault: Double = 0.0): Double;
    function GetBool(const AKey: string; const ADefault: Boolean = False): Boolean;

    { キーを与えて値を取り出す一般化オーバーロード関数 (成功時True) }
    function GetValue(const AKey: string; out AValue: string): Boolean; overload;
    function GetValue(const AKey: string; out AValue: Integer): Boolean; overload;
    function GetValue(const AKey: string; out AValue: Double): Boolean; overload;
    function GetValue(const AKey: string; out AValue: Boolean): Boolean; overload;

    { =================================================== }
    { 2. 配列を取り出す関数群 (FGLを利用)                }
    { =================================================== }
    function GetFloatArray(const AKey: string): TDoubleList;
    function GetStringArray(const AKey: string): TStringFGLList;

    { キーを与えて配列を取り出す一般化オーバーロード関数 (成功時True) }
    function GetArray(const AKey: string; out AList: TDoubleList): Boolean; overload;
    function GetArray(const AKey: string; out AList: TStringFGLList): Boolean; overload;
  end;

  TTomlTableList = specialize TFPGObjectList<TTomlTable>;

  { --- セクション構造管理 --- }
  
  TTomlSection = class
  public
    Name: string;
    Tables: TTomlTableList;
    constructor Create(const AName: string);
    destructor Destroy; override;
  end;

  TTomlSectionList = specialize TFPGObjectList<TTomlSection>;

  { --- TOMLドキュメント全体クラス --- }
  
  TTomlDocument = class
  private
    FSections: TTomlSectionList;
    FGlobalTable: TTomlTable;
    function GetOrCreateSection(const AName: string): TTomlSection;
    function FindSection(const AName: string): TTomlSection;
  public
    constructor Create;
    destructor Destroy; override;

    procedure LoadFromFile(const AFileName: string);
    procedure LoadFromStrings(ALines: TStrings);

    { セクション・テーブルアクセス }
    function GetTable(const ASectionName: string; AIndex: Integer = 0): TTomlTable;
    function GetTableCount(const ASectionName: string): Integer;
    property GlobalTable: TTomlTable read FGlobalTable;

    { =================================================== }
    { 3. FGL多重配列 (TDoubleMatrix) 抽出用ヘルパー       }
    { =================================================== }
    { 指定セクションの全テーブルから指定キーの配列を集約し2次元配列として返す }
    function GetMatrix(const ASectionName, AArrayKey: string): TDoubleMatrix;
  end;

implementation

{ --- TTomlPair --- }

constructor TTomlPair.Create(const AKey, ARawValue: string);
begin
  inherited Create;
  Key := LowerCase(Trim(AKey));
  RawValue := Trim(ARawValue);
end;

{ --- TTomlTable --- }

constructor TTomlTable.Create;
begin
  inherited Create;
  FPairs := TTomlPairList.Create(True);
end;

destructor TTomlTable.Destroy;
begin
  FPairs.Free;
  inherited Destroy;
end;

function TTomlTable.FindPair(const AKey: string): TTomlPair;
var
  I: Integer;
  TargetKey: string;
begin
  Result := nil;
  TargetKey := LowerCase(Trim(AKey));
  for I := 0 to FPairs.Count - 1 do
  begin
    if FPairs[I].Key = TargetKey then
      Exit(FPairs[I]);
  end;
end;

function TTomlTable.CleanString(const AStr: string): string;
begin
  Result := Trim(AStr);
  if (Length(Result) >= 2) and (Result[1] = '"') and (Result[Length(Result)] = '"') then
    Result := Copy(Result, 2, Length(Result) - 2);
end;

procedure TTomlTable.SetValue(const AKey, ARawValue: string);
var
  Pair: TTomlPair;
begin
  Pair := FindPair(AKey);
  if Pair <> nil then
    Pair.RawValue := Trim(ARawValue)
  else
    FPairs.Add(TTomlPair.Create(AKey, ARawValue));
end;

function TTomlTable.HasKey(const AKey: string): Boolean;
begin
  Result := (FindPair(AKey) <> nil);
end;

{ --- 単一値取得関数 --- }

function TTomlTable.GetString(const AKey: string; const ADefault: string = ''): string;
var
  Pair: TTomlPair;
begin
  Pair := FindPair(AKey);
  if Pair <> nil then
    Result := CleanString(Pair.RawValue)
  else
    Result := ADefault;
end;

function TTomlTable.GetInt(const AKey: string; const ADefault: Integer = 0): Integer;
var
  Pair: TTomlPair;
begin
  Pair := FindPair(AKey);
  if Pair <> nil then
    Result := StrToIntDef(Pair.RawValue, ADefault)
  else
    Result := ADefault;
end;

function TTomlTable.GetFloat(const AKey: string; const ADefault: Double = 0.0): Double;
var
  Pair: TTomlPair;
begin
  Pair := FindPair(AKey);
  if Pair <> nil then
    Result := StrToFloatDef(Pair.RawValue, ADefault)
  else
    Result := ADefault;
end;

function TTomlTable.GetBool(const AKey: string; const ADefault: Boolean = False): Boolean;
var
  Pair: TTomlPair;
  S: string;
begin
  Pair := FindPair(AKey);
  if Pair <> nil then
  begin
    S := LowerCase(Trim(Pair.RawValue));
    Result := (S = 'true') or (S = '1');
  end
  else
    Result := ADefault;
end;

{ オーバーロード化された GetValue }

function TTomlTable.GetValue(const AKey: string; out AValue: string): Boolean;
begin
  Result := HasKey(AKey);
  if Result then AValue := GetString(AKey);
end;

function TTomlTable.GetValue(const AKey: string; out AValue: Integer): Boolean;
begin
  Result := HasKey(AKey);
  if Result then AValue := GetInt(AKey);
end;

function TTomlTable.GetValue(const AKey: string; out AValue: Double): Boolean;
begin
  Result := HasKey(AKey);
  if Result then AValue := GetFloat(AKey);
end;

function TTomlTable.GetValue(const AKey: string; out AValue: Boolean): Boolean;
begin
  Result := HasKey(AKey);
  if Result then AValue := GetBool(AKey);
end;

{ --- 配列取得関数 --- }

function TTomlTable.GetFloatArray(const AKey: string): TDoubleList;
var
  Pair: TTomlPair;
  S, Sub: string;
  CommaPos: Integer;
begin
  Result := TDoubleList.Create;
  Pair := FindPair(AKey);
  if Pair = nil then Exit;

  S := Trim(Pair.RawValue);
  if (Length(S) >= 2) and (S[1] = '[') and (S[Length(S)] = ']') then
    S := Copy(S, 2, Length(S) - 2);

  while Length(S) > 0 do
  begin
    CommaPos := Pos(',', S);
    if CommaPos > 0 then
    begin
      Sub := Trim(Copy(S, 1, CommaPos - 1));
      S := Trim(Copy(S, CommaPos + 1, Length(S) - CommaPos));
    end
    else
    begin
      Sub := Trim(S);
      S := '';
    end;

    if Sub <> '' then
      Result.Add(StrToFloatDef(Sub, 0.0));
  end;
end;

function TTomlTable.GetStringArray(const AKey: string): TStringFGLList;
var
  Pair: TTomlPair;
  S, Sub: string;
  CommaPos: Integer;
begin
  Result := TStringFGLList.Create;
  Pair := FindPair(AKey);
  if Pair = nil then Exit;

  S := Trim(Pair.RawValue);
  if (Length(S) >= 2) and (S[1] = '[') and (S[Length(S)] = ']') then
    S := Copy(S, 2, Length(S) - 2);

  while Length(S) > 0 do
  begin
    CommaPos := Pos(',', S);
    if CommaPos > 0 then
    begin
      Sub := Trim(Copy(S, 1, CommaPos - 1));
      S := Trim(Copy(S, CommaPos + 1, Length(S) - CommaPos));
    end
    else
    begin
      Sub := Trim(S);
      S := '';
    end;

    if Sub <> '' then
      Result.Add(CleanString(Sub));
  end;
end;

function TTomlTable.GetArray(const AKey: string; out AList: TDoubleList): Boolean;
begin
  Result := HasKey(AKey);
  if Result then
    AList := GetFloatArray(AKey)
  else
    AList := TDoubleList.Create;
end;

function TTomlTable.GetArray(const AKey: string; out AList: TStringFGLList): Boolean;
begin
  Result := HasKey(AKey);
  if Result then
    AList := GetStringArray(AKey)
  else
    AList := TStringFGLList.Create;
end;

{ --- TTomlSection --- }

constructor TTomlSection.Create(const AName: string);
begin
  inherited Create;
  Name := LowerCase(Trim(AName));
  Tables := TTomlTableList.Create(True);
end;

destructor TTomlSection.Destroy;
begin
  Tables.Free;
  inherited Destroy;
end;

{ --- TTomlDocument --- }

constructor TTomlDocument.Create;
begin
  inherited Create;
  FSections := TTomlSectionList.Create(True);
  FGlobalTable := TTomlTable.Create;
end;

destructor TTomlDocument.Destroy;
begin
  FSections.Free;
  FGlobalTable.Free;
  inherited Destroy;
end;

function TTomlDocument.FindSection(const AName: string): TTomlSection;
var
  I: Integer;
  Target: string;
begin
  Result := nil;
  Target := LowerCase(Trim(AName));
  for I := 0 to FSections.Count - 1 do
  begin
    if FSections[I].Name = Target then
      Exit(FSections[I]);
  end;
end;

function TTomlDocument.GetOrCreateSection(const AName: string): TTomlSection;
begin
  Result := FindSection(AName);
  if Result = nil then
  begin
    Result := TTomlSection.Create(AName);
    FSections.Add(Result);
  end;
end;

procedure TTomlDocument.LoadFromFile(const AFileName: string);
var
  Lines: TStringList;
begin
  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(AFileName);
    LoadFromStrings(Lines);
  finally
    Lines.Free;
  end;
end;

procedure TTomlDocument.LoadFromStrings(ALines: TStrings);
var
  I, HashPos, EqualPos: Integer;
  Line, TrimmedLine, Key, ValStr, SecName: string;
  CurrentTable: TTomlTable;
  CurrentSec: TTomlSection;
begin
  DefaultFormatSettings.DecimalSeparator := '.';
  CurrentTable := FGlobalTable;

  for I := 0 to ALines.Count - 1 do
  begin
    Line := ALines[I];

    { コメント '#' の除外 }
    HashPos := Pos('#', Line);
    if HashPos > 0 then
      Line := Copy(Line, 1, HashPos - 1);

    TrimmedLine := Trim(Line);
    if TrimmedLine = '' then Continue;

    { [[section]] の判定 (テーブル配列) }
    if (Length(TrimmedLine) > 4) and (Copy(TrimmedLine, 1, 2) = '[[') and (Copy(TrimmedLine, Length(TrimmedLine) - 1, 2) = ']]') then
    begin
      SecName := Trim(Copy(TrimmedLine, 3, Length(TrimmedLine) - 4));
      CurrentSec := GetOrCreateSection(SecName);
      CurrentTable := TTomlTable.Create;
      CurrentSec.Tables.Add(CurrentTable);
      Continue;
    end;

    { [section] の判定 (単一テーブル) }
    if (Length(TrimmedLine) > 2) and (TrimmedLine[1] = '[') and (TrimmedLine[Length(TrimmedLine)] = ']') then
    begin
      SecName := Trim(Copy(TrimmedLine, 2, Length(TrimmedLine) - 2));
      CurrentSec := GetOrCreateSection(SecName);
      CurrentTable := TTomlTable.Create;
      CurrentSec.Tables.Add(CurrentTable);
      Continue;
    end;

    { キー・バリューの読み取り }
    EqualPos := Pos('=', TrimmedLine);
    if EqualPos > 0 then
    begin
      Key := Trim(Copy(TrimmedLine, 1, EqualPos - 1));
      ValStr := Trim(Copy(TrimmedLine, EqualPos + 1, Length(TrimmedLine) - EqualPos));
      CurrentTable.SetValue(Key, ValStr);
    end;
  end;
end;

function TTomlDocument.GetTable(const ASectionName: string; AIndex: Integer = 0): TTomlTable;
var
  Sec: TTomlSection;
begin
  Result := nil;
  Sec := FindSection(ASectionName);
  if (Sec <> nil) and (AIndex >= 0) and (AIndex < Sec.Tables.Count) then
    Result := Sec.Tables[AIndex];
end;

function TTomlDocument.GetTableCount(const ASectionName: string): Integer;
var
  Sec: TTomlSection;
begin
  Sec := FindSection(ASectionName);
  if Sec <> nil then
    Result := Sec.Tables.Count
  else
    Result := 0;
end;

{ 指定セクションの指定キー（実数配列）を収集し、2次元多重配列 (TDoubleMatrix) として構築 }
function TTomlDocument.GetMatrix(const ASectionName, AArrayKey: string): TDoubleMatrix;
var
  Sec: TTomlSection;
  I: Integer;
  Table: TTomlTable;
begin
  Result := TDoubleMatrix.Create(True);
  Sec := FindSection(ASectionName);
  if Sec = nil then Exit;

  for I := 0 to Sec.Tables.Count - 1 do
  begin
    Table := Sec.Tables[I];
    if Table.HasKey(AArrayKey) then
      Result.Add(Table.GetFloatArray(AArrayKey));
  end;
end;

end.
