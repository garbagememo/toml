program ParseTomlData;

{$mode objfpc}{$H+}{$J-}

uses
  SysUtils, Classes, StrUtils;

type
  // 3次元ベクトル用構造体
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

  TObjectArray = array of TSceneObject;

  // シーン全体データ
  TSceneData = record
    Camera: TCamera;
    Objects: TObjectArray;
  end;

// ====================================================
// パース補助関数
// ====================================================

// コメント（# 以降）を除去し、前後空白を詰める
function TrimComment(const Line: string): string;
var
  Idx: Integer;
begin
  Idx := Pos('#', Line);
  if Idx > 0 then
    Result := Trim(Copy(Line, 1, Idx - 1))
  else
    Result := Trim(Line);
end;

// 配列文字列 "[x, y, z]" を TVector3 に変換
function ParseVector3(const S: string): TVector3;
var
  CleanS: string;
  Parts: TStringArray;
  FS: TFormatSettings;
begin
  Result.X := 0.0; Result.Y := 0.0; Result.Z := 0.0;
  FS := DefaultFormatSettings;
  FS.DecimalSeparator := '.'; // 小数点をドット固定
  
  CleanS := StringReplace(S, '[', '', [rfReplaceAll]);
  CleanS := StringReplace(CleanS, ']', '', [rfReplaceAll]);
  CleanS := Trim(CleanS);
  
  Parts := CleanS.Split([',']);
  if Length(Parts) >= 3 then
  begin
    Result.X := StrToFloatDef(Trim(Parts[0]), 0.0, FS);
    Result.Y := StrToFloatDef(Trim(Parts[1]), 0.0, FS);
    Result.Z := StrToFloatDef(Trim(Parts[2]), 0.0, FS);
  end;
end;

// ダブルクォーテーションで囲まれた文字列のクォート除去
function ParseStringValue(const S: string): string;
begin
  Result := Trim(S);
  if (Length(Result) >= 2) and (Result[1] = '"') and (Result[Length(Result)] = '"') then
    Result := Copy(Result, 2, Length(Result) - 2);
end;

// ====================================================
// TOML パース関数
// ====================================================
function ParseTomlFile(const FilePath: string; out Scene: TSceneData): Boolean;
var
  Lines: TStringList;
  I: Integer;
  Line, Section, Key, Value: string;
  EqIdx: Integer;
  ObjCount: Integer;
  FS: TFormatSettings;
begin
  Result := False;
  FS := DefaultFormatSettings;
  FS.DecimalSeparator := '.';
  
  if not FileExists(FilePath) then
  begin
    Writeln('エラー: ファイルが見つかりません -> ', FilePath);
    Exit;
  end;

  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(FilePath);
    Section := '';
    ObjCount := 0;
    SetLength(Scene.Objects, 0);

    for I := 0 to Lines.Count - 1 do
    begin
      Line := TrimComment(Lines[I]);
      if Line = '' then Continue;

      // [[objects]] などのテーブル配列ヘッダーの検出
      if (LeftStr(Line, 2) = '[[') and (RightStr(Line, 2) = ']]') then
      begin
        Section := Copy(Line, 3, Length(Line) - 4);
        if Section = 'objects' then
        begin
          Inc(ObjCount);
          SetLength(Scene.Objects, ObjCount);
        end;
        Continue;
      end
      // [camera] などの通常のテーブルヘッダーの検出
      else if (LeftStr(Line, 1) = '[') and (RightStr(Line, 1) = ']') then
      begin
        Section := Copy(Line, 2, Length(Line) - 2);
        Continue;
      end;

      // Key = Value ペアのパース
      EqIdx := Pos('=', Line);
      if EqIdx > 0 then
      begin
        Key := Trim(Copy(Line, 1, EqIdx - 1));
        Value := Trim(Copy(Line, EqIdx + 1, Length(Line) - EqIdx));

        if Section = 'camera' then
        begin
          case Key of
            'position':       Scene.Camera.Position := ParseVector3(Value);
            'direction':      Scene.Camera.Direction := ParseVector3(Value);
            'width':          Scene.Camera.Width := StrToIntDef(Value, 0);
            'height':         Scene.Camera.Height := StrToIntDef(Value, 0);
            'samples':        Scene.Camera.Samples := StrToIntDef(Value, 0);
            'plane_distance': Scene.Camera.PlaneDistance := StrToFloatDef(Value, 0.0, FS);
          end;
        end
        else if Section = 'objects' then
        begin
          case Key of
            'name':     Scene.Objects[ObjCount - 1].Name := ParseStringValue(Value);
            'type':     Scene.Objects[ObjCount - 1].ObjectType := ParseStringValue(Value);
            'radius':   Scene.Objects[ObjCount - 1].Radius := StrToFloatDef(Value, 0.0, FS);
            'position': Scene.Objects[ObjCount - 1].Position := ParseVector3(Value);
            'emission': Scene.Objects[ObjCount - 1].Emission := ParseVector3(Value);
            'color':    Scene.Objects[ObjCount - 1].Color := ParseVector3(Value);
            'material': Scene.Objects[ObjCount - 1].Material := ParseStringValue(Value);
          end;
        end;
      end;
    end;
    Result := True;
  finally
    Lines.Free;
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
  FileName := 'scene.toml'; // 対象のTOMLファイル名

  Writeln('TOMLデータを読み込み中: ', FileName);
  if ParseTomlFile(FileName, Scene) then
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
    Writeln('[Objects (Total: ', Length(Scene.Objects), ')]');
    for I := 0 to High(Scene.Objects) do
    begin
      Obj := Scene.Objects[I];
      Writeln(Format('  #%d: %s (%s, Material: %s)', [I + 1, Obj.Name, Obj.ObjectType, Obj.Material]));
      Writeln(Format('      Radius: %g', [Obj.Radius]));
      Writeln(Format('      Pos: (%g, %g, %g)', [Obj.Position.X, Obj.Position.Y, Obj.Position.Z]));
      Writeln(Format('      Color: (%g, %g, %g)', [Obj.Color.X, Obj.Color.Y, Obj.Color.Z]));
    end;
  end;
end.