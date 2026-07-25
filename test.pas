program ParseTomlWithLibrary;

{$mode objfpc}{$H+}{$J-}

uses
  SysUtils, Classes, TOML, TOML.Types, FGL;

type
  // 3次元ベクトル構造体
  TVector3 = record
    X, Y, Z: Double;
  end;

  // カメラ設定構造体
  TCamera = record
    Position: TVector3;
    Direction: TVector3;
    Width: Integer;
    Height: Integer;
    Samples: Integer;
    PlaneDistance: Double;
  end;

  // オブジェクト構造体
  TSceneObject = record
    Name: string;
    ObjectType: string;
    Radius: Double;
    Position: TVector3;
    Emission: TVector3;
    Color: TVector3;
    Material: string;
  end;

  // FGL を使用したジェネリックリスト型定義
  TSceneObjectList = specialize TFPGList<TSceneObject>;

  // シーン全体データ構造体
  TSceneData = record
    Camera: TCamera;
    Objects: TSceneObjectList;
  end;

// ====================================================
// パース補助関数 (toml-fp の TTOMLArray から TVector3 を抽出)
// ====================================================
function GetVector3(Value: TTOMLValue): TVector3;
var
  Arr: TTOMLArray;
begin
  Result.X := 0.0; Result.Y := 0.0; Result.Z := 0.0;
  if (Value <> nil) and (Value.ValueType = tvtArray) then
  begin
    Arr := Value.AsArray;
    if Arr.Count >= 3 then
    begin
      Result.X := Arr.GetItem(0).AsFloat;
      Result.Y := Arr.GetItem(1).AsFloat;
      Result.Z := Arr.GetItem(2).AsFloat;
    end;
  end;
end;

// ====================================================
// toml-fp を使用した TOML パース関数
// ====================================================
function ParseTomlFileWithLib(const FilePath: string; out Scene: TSceneData): Boolean;
var
  RootTable, CamTable, ObjTable: TTOMLTable;
  Val, SubVal: TTOMLValue;
  ObjArray: TTOMLArray;
  SceneObj: TSceneObject;
  I: Integer;
begin
  Result := False;
  Scene.Objects := nil;

  if not FileExists(FilePath) then
  begin
    Writeln('エラー: ファイルが見つかりません -> ', FilePath);
    Exit;
  end;

  try
    // FGL リストの初期化
    Scene.Objects := TSceneObjectList.Create;

    try
      // toml-fp ライブラリの関数でファイルからテーブルを生成
      RootTable := ParseTOMLFromFile(FilePath);
      try
        // ------------------------------------------------
        // 1. [camera] テーブルの読み込み
        // ------------------------------------------------
        if RootTable.TryGetValue('camera', Val) and (Val.ValueType = tvtTable) then
        begin
          CamTable := Val.AsTable;

          if CamTable.TryGetValue('position', SubVal) then
            Scene.Camera.Position := GetVector3(SubVal);

          if CamTable.TryGetValue('direction', SubVal) then
            Scene.Camera.Direction := GetVector3(SubVal);

          if CamTable.TryGetValue('width', SubVal) then
            Scene.Camera.Width := SubVal.AsInteger;

          if CamTable.TryGetValue('height', SubVal) then
            Scene.Camera.Height := SubVal.AsInteger;

          if CamTable.TryGetValue('samples', SubVal) then
            Scene.Camera.Samples := SubVal.AsInteger;

          if CamTable.TryGetValue('plane_distance', SubVal) then
            Scene.Camera.PlaneDistance := SubVal.AsFloat;
        end;

        // ------------------------------------------------
        // 2. [[objects]] テーブル配列の読み込み
        // ------------------------------------------------
        if RootTable.TryGetValue('objects', Val) and (Val.ValueType = tvtArray) then
        begin
          ObjArray := Val.AsArray;

          for I := 0 to ObjArray.Count - 1 do
          begin
            if ObjArray.GetItem(I).ValueType = tvtTable then
            begin
              ObjTable := ObjArray.GetItem(I).AsTable;
              
              // TSceneObject を初期化
              FillChar(SceneObj, SizeOf(SceneObj), 0);

              if ObjTable.TryGetValue('name', SubVal) then
                SceneObj.Name := SubVal.AsString;

              if ObjTable.TryGetValue('type', SubVal) then
                SceneObj.ObjectType := SubVal.AsString;

              if ObjTable.TryGetValue('radius', SubVal) then
                SceneObj.Radius := SubVal.AsFloat;

              if ObjTable.TryGetValue('position', SubVal) then
                SceneObj.Position := GetVector3(SubVal);

              if ObjTable.TryGetValue('emission', SubVal) then
                SceneObj.Emission := GetVector3(SubVal);

              if ObjTable.TryGetValue('color', SubVal) then
                SceneObj.Color := GetVector3(SubVal);

              if ObjTable.TryGetValue('material', SubVal) then
                SceneObj.Material := SubVal.AsString;

              // FGL リストに追加
              Scene.Objects.Add(SceneObj);
            end;
          end;
        end;

        Result := True;
      finally
        // RootTable を Free すると、内部のすべてのネストされたテーブル・配列・値も自動で破棄されます
        RootTable.Free;
      end;
    except
      on E: Exception do
      begin
        Writeln('TOMLパースエラー: ', E.Message);
        if Scene.Objects <> nil then
          Scene.Objects.Free;
        Result := False;
      end;
    end;
  except
    on E: Exception do
    begin
      Writeln('初期化エラー: ', E.Message);
      Result := False;
    end;
  end;
end;

// ====================================================
// メイン処理
// ====================================================
var
  Scene: TSceneData;
  Obj: TSceneObject;
  I: Integer;
  FileName: string;
begin
  FileName := 'test.toml'; // 読み込むファイル名

  Writeln('toml-fp を使用して TOML データを読み込み中: ', FileName);
  if ParseTomlFileWithLib(FileName, Scene) then
  begin
    Writeln('--- パース完了 ---');

    // カメラ情報の出力
    Writeln('[Camera]');
    Writeln('  Pos: (', Scene.Camera.Position.X:0:1, ', ', Scene.Camera.Position.Y:0:1, ', ', Scene.Camera.Position.Z:0:1, ')');
    Writeln('  Resolution: ', Scene.Camera.Width, 'x', Scene.Camera.Height);
    Writeln('  Samples: ', Scene.Camera.Samples);
    Writeln('  Plane Distance: ', Scene.Camera.PlaneDistance:0:1);
    Writeln;

    // オブジェクト一覧の出力
    Writeln('[Objects (Total: ', Scene.Objects.Count, ')]');
    for I := 0 to Scene.Objects.Count - 1 do
    begin
      Obj := Scene.Objects[I];
      Writeln(Format('  #%d: %s (%s, Material: %s)', [I + 1, Obj.Name, Obj.ObjectType, Obj.Material]));
      Writeln(Format('      Radius: %g', [Obj.Radius]));
      Writeln(Format('      Pos: (%g, %g, %g)', [Obj.Position.X, Obj.Position.Y, Obj.Position.Z]));
      Writeln(Format('      Color: (%g, %g, %g)', [Obj.Color.X, Obj.Color.Y, Obj.Color.Z]));
    end;

    // リソースの解放
    Scene.Objects.Free;
  end;
end.
