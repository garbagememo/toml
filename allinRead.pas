program TomlParser;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, fgl;

type
  { --- 1. FGLを用いた配列型の定義 --- }
  
  { 1次元実数配列型 (TOMLの [x, y, z] ベクトル表現用) }
  TDoubleList = specialize TFPGList<Double>;

  { 2次元実数配列型 (多重配列表現: TDoubleListのリスト) }
  TDoubleMatrix = specialize TFPGObjectList<TDoubleList>;


  { --- 2. データ構造クラスの定義 --- }

  { オブジェクト要素クラス }
  TSceneObject = class
  public
    Name: string;
    ObjType: string;
    Filename: string;
    Radius: Double;
    Position: TDoubleList; // 1次元配列
    Emission: TDoubleList; // 1次元配列
    Color: TDoubleList;    // 1次元配列
    Material: string;

    constructor Create;
    destructor Destroy; override;
  end;

  { オブジェクトのリスト型 (FGL TFPGObjectList) }
  TSceneObjectList = specialize TFPGObjectList<TSceneObject>;

  { カメラ設定クラス }
  TCamera = class
  public
    Position: TDoubleList;
    Direction: TDoubleList;
    Width: Integer;
    Height: Integer;
    Samples: Integer;
    PlaneDistance: Double;

    constructor Create;
    destructor Destroy; override;
  end;

  { TOMLドキュメント全般クラス }
  TTOMLDocument = class
  public
    Camera: TCamera;
    Objects: TSceneObjectList; // 多重構造: Objects[i].Position[j]

    constructor Create;
    destructor Destroy; override;
    
    procedure LoadFromFile(const AFileName: string);
    procedure PrintSummary;
    function ExtractAllPositionsAsMatrix: TDoubleMatrix;
  end;

{ --- TSceneObject の実装 --- }

constructor TSceneObject.Create;
begin
  inherited Create;
  Position := TDoubleList.Create;
  Emission := TDoubleList.Create;
  Color := TDoubleList.Create;
  Radius := 0.0;
end;

destructor TSceneObject.Destroy;
begin
  Position.Free;
  Emission.Free;
  Color.Free;
  inherited Destroy;
end;

{ --- TCamera の実装 --- }

constructor TCamera.Create;
begin
  inherited Create;
  Position := TDoubleList.Create;
  Direction := TDoubleList.Create;
  Width := 0;
  Height := 0;
  Samples := 0;
  PlaneDistance := 0.0;
end;

destructor TCamera.Destroy;
begin
  Position.Free;
  Direction.Free;
  inherited Destroy;
end;

{ --- TTOMLDocument の実装 --- }

constructor TTOMLDocument.Create;
begin
  inherited Create;
  Camera := TCamera.Create;
  { FreeObjects = True でリスト破棄時に要素オブジェクトも自動解放 }
  Objects := TSceneObjectList.Create(True);
end;

destructor TTOMLDocument.Destroy;
begin
  Camera.Free;
  Objects.Free;
  inherited Destroy;
end;

{ TOMLファイルの読み込み処理 }
procedure TTOMLDocument.LoadFromFile(const AFileName: string);
var
  Lines: TStringList;
  I, HashPos, EqualPos: Integer;
  Line, TrimmedLine, Key, ValStr: string;
  CurrentSection: string;
  CurrentObj: TSceneObject;

  { インライン配列文字列 "[55.0, 40.0, 295.6]" を TDoubleList に変換 }
  function ParseDoubleList(const AStr: string): TDoubleList;
  var
    S, Sub: string;
    CommaPos: Integer;
    Val: Double;
  begin
    Result := TDoubleList.Create;
    S := Trim(AStr);
    
    { 囲みの角括弧 [ ] を除去 }
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
      begin
        Val := StrToFloatDef(Sub, 0.0);
        Result.Add(Val);
      end;
    end;
  end;

  { クォーテーションの除去 }
  function CleanString(const AStr: string): string;
  begin
    Result := Trim(AStr);
    if (Length(Result) >= 2) and (Result[1] = '"') and (Result[Length(Result)] = '"') then
      Result := Copy(Result, 2, Length(Result) - 2);
  end;

begin
  { 小数点区切り文字を '.' に固定 }
  DefaultFormatSettings.DecimalSeparator := '.';

  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(AFileName);
    CurrentSection := '';
    CurrentObj := nil;

    for I := 0 to Lines.Count - 1 do
    begin
      Line := Lines[I];

      { コメント '#' の除去 }
      HashPos := Pos('#', Line);
      if HashPos > 0 then
        Line := Copy(Line, 1, HashPos - 1);

      TrimmedLine := Trim(Line);
      if TrimmedLine = '' then Continue;

      { テーブル配列 [[objects]] の判定 }
      if (Length(TrimmedLine) > 4) and 
         (Copy(TrimmedLine, 1, 2) = '[[') and 
         (Copy(TrimmedLine, Length(TrimmedLine) - 1, 2) = ']]') then
      begin
        CurrentSection := LowerCase(Trim(Copy(TrimmedLine, 3, Length(TrimmedLine) - 4)));
        if CurrentSection = 'objects' then
        begin
          CurrentObj := TSceneObject.Create;
          Objects.Add(CurrentObj);
        end;
        Continue;
      end;

      { 単一セクション [camera] または [objects] の判定 }
      if (Length(TrimmedLine) > 2) and 
         (TrimmedLine[1] = '[') and 
         (TrimmedLine[Length(TrimmedLine)] = ']') then
      begin
        CurrentSection := LowerCase(Trim(Copy(TrimmedLine, 2, Length(TrimmedLine) - 2)));
        if CurrentSection = 'objects' then
        begin
          CurrentObj := TSceneObject.Create;
          Objects.Add(CurrentObj);
        end;
        Continue;
      end;

      { key = value の解析 }
      EqualPos := Pos('=', TrimmedLine);
      if EqualPos > 0 then
      begin
        Key := LowerCase(Trim(Copy(TrimmedLine, 1, EqualPos - 1)));
        ValStr := Trim(Copy(TrimmedLine, EqualPos + 1, Length(TrimmedLine) - EqualPos));

        { [camera] セクションの項目設定 }
        if CurrentSection = 'camera' then
        begin
          if Key = 'position' then
          begin
            Camera.Position.Free;
            Camera.Position := ParseDoubleList(ValStr);
          end
          else if Key = 'direction' then
          begin
            Camera.Direction.Free;
            Camera.Direction := ParseDoubleList(ValStr);
          end
          else if Key = 'width' then
            Camera.Width := StrToIntDef(ValStr, 0)
          else if Key = 'height' then
            Camera.Height := StrToIntDef(ValStr, 0)
          else if Key = 'samples' then
            Camera.Samples := StrToIntDef(ValStr, 0)
          else if Key = 'plane_distance' then
            Camera.PlaneDistance := StrToFloatDef(ValStr, 0.0);
        end
        
        { [objects] または [[objects]] セクションの項目設定 }
        else if (CurrentSection = 'objects') and (CurrentObj <> nil) then
        begin
          if Key = 'name' then
            CurrentObj.Name := CleanString(ValStr)
          else if Key = 'type' then
            CurrentObj.ObjType := CleanString(ValStr)
          else if Key = 'filename' then
            CurrentObj.Filename := CleanString(ValStr)
          else if Key = 'material' then
            CurrentObj.Material := CleanString(ValStr)
          else if Key = 'radius' then
            CurrentObj.Radius := StrToFloatDef(ValStr, 0.0)
          else if Key = 'position' then
          begin
            CurrentObj.Position.Free;
            CurrentObj.Position := ParseDoubleList(ValStr);
          end
          else if Key = 'emission' then
          begin
            CurrentObj.Emission.Free;
            CurrentObj.Emission := ParseDoubleList(ValStr);
          end
          else if Key = 'color' then
          begin
            CurrentObj.Color.Free;
            CurrentObj.Color := ParseDoubleList(ValStr);
          end;
        end;
      end;
    end;
  finally
    Lines.Free;
  end;
end;

{ 読み込んだ結果を表示するデモ関数 }
procedure TTOMLDocument.PrintSummary;
var
  I, J: Integer;
  Obj: TSceneObject;
begin
  WriteLn('========================================');
  WriteLn(' Camera Settings');
  WriteLn('========================================');
  Write('Position: [');
  for I := 0 to Camera.Position.Count - 1 do
  begin
    Write(Camera.Position[I]:0:1);
    if I < Camera.Position.Count - 1 then Write(', ');
  end;
  WriteLn(']');

  WriteLn('Width: ', Camera.Width, ' | Height: ', Camera.Height, ' | Samples: ', Camera.Samples);
  WriteLn('Plane Distance: ', Camera.PlaneDistance:0:1);
  WriteLn;

  WriteLn('========================================');
  WriteLn(' Objects List (Count: ', Objects.Count, ')');
  WriteLn('========================================');
  for I := 0 to Objects.Count - 1 do
  begin
    Obj := Objects[I];
    WriteLn(Format('[Object #%d] %s (Type: %s)', [I + 1, Obj.Name, Obj.ObjType]));
    if Obj.Filename <> '' then WriteLn('  Filename : ', Obj.Filename);
    if Obj.Radius > 0 then     WriteLn('  Radius   : ', Obj.Radius:0:1);
    if Obj.Material <> '' then WriteLn('  Material : ', Obj.Material);

    { 多重配列要素アクセスの例 1: Objects[i].Position[j] }
    if Obj.Position.Count > 0 then
    begin
      Write('  Position : [');
      for J := 0 to Obj.Position.Count - 1 do
      begin
        Write(Obj.Position[J]:0:3);
        if J < Obj.Position.Count - 1 then Write(', ');
      end;
      WriteLn(']');
    end;

    if Obj.Color.Count > 0 then
    begin
      Write('  Color    : [');
      for J := 0 to Obj.Color.Count - 1 do
      begin
        Write(Obj.Color[J]:0:3);
        if J < Obj.Color.Count - 1 then Write(', ');
      end;
      WriteLn(']');
    end;
    WriteLn;
  end;
end;

{ 全オブジェクトのPositionベクトルを2次元実数配列(TDoubleMatrix)として出力する関数 }
function TTOMLDocument.ExtractAllPositionsAsMatrix: TDoubleMatrix;
var
  I, J: Integer;
  Obj: TSceneObject;
  PosVector: TDoubleList;
begin
  Result := TDoubleMatrix.Create(True);
  for I := 0 to Objects.Count - 1 do
  begin
    Obj := Objects[I];
    PosVector := TDoubleList.Create;
    for J := 0 to Obj.Position.Count - 1 do
      PosVector.Add(Obj.Position[J]);
    Result.Add(PosVector);
  end;
end;

{ --- メインプログラム --- }

var
  Doc: TTOMLDocument;
  Matrix: TDoubleMatrix;
  I, J: Integer;
  FileName: string;
begin
  if ParamCount > 0 then
    FileName := ParamStr(1)
  else
    FileName := 'scene.toml';

  if not FileExists(FileName) then
  begin
    WriteLn('エラー: ファイル "', FileName, '" が見つかりません。');
    WriteLn('使い方: ./TomlParser <tomlファイルパス>');
    Halt(1);
  end;

  Doc := TTOMLDocument.Create;
  try
    Doc.LoadFromFile(FileName);
    Doc.PrintSummary;

    { FGLによる2次元多重配列 (TDoubleMatrix) のアクセス例 }
    WriteLn('========================================');
    WriteLn(' FGL 2次元多重配列 (TDoubleMatrix) アクセス例');
    WriteLn('========================================');
    Matrix := Doc.ExtractAllPositionsAsMatrix;
    try
      for I := 0 to Matrix.Count - 1 do
      begin
        Write(Format('Matrix[%d] (Object #%d Pos) -> ', [I, I + 1]));
        for J := 0 to Matrix[I].Count - 1 do
        begin
          { Matrix[I][J] で多次元インデックスアクセス }
          Write(Matrix[I][J]:0:1, ' ');
        end;
        WriteLn;
      end;
    finally
      Matrix.Free;
    end;

  finally
    Doc.Free;
  end;
end.