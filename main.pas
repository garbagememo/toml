program Main;

{$mode objfpc}{$H+}

uses
  SysUtils, uTOML;

procedure DemonstrateTomlParsing(const AFileName: string);
var
  Doc: TTOMLDocument;
  CamTable, ObjTable: TTomlTable;
  ObjCount, I, J: Integer;
  
  // 単一値の受け取り変数
  Width, Samples: Integer;
  PlaneDist: Double;
  ObjName, ObjType: string;
  
  // FGL配列・多重配列の受け取り変数
  CamPos, ObjPos: TDoubleList;
  PositionsMatrix: TDoubleMatrix;
begin
  WriteLn('==================================================');
  WriteLn(' Loading File: ', AFileName);
  WriteLn('==================================================');

  Doc := TTomlDocument.Create;
  try
    Doc.LoadFromFile(AFileName);

    { --- 1. [camera] セクションからの単一値・1次元配列の取得 --- }
    CamTable := Doc.GetTable('camera');
    if CamTable <> nil then
    begin
      WriteLn('[Camera Settings]');
      
      { オーバーロード関数 GetValue / 直感的な GetInt, GetFloat を利用 }
      Width := CamTable.GetInt('width');
      Samples := CamTable.GetInt('samples');
      PlaneDist := CamTable.GetFloat('plane_distance');
      WriteLn(Format('  Resolution: %d px | Samples: %d | Plane Dist: %.1f', [Width, Samples, PlaneDist]));

      { キーを指定して1次元配列 (TDoubleList) を取得 }
      if CamTable.GetArray('position', CamPos) then
      begin
        try
          Write('  Position Array: [');
          for I := 0 to CamPos.Count - 1 do
          begin
            Write(CamPos[I]:0:1);
            if I < CamPos.Count - 1 then Write(', ');
          end;
          WriteLn(']');
        finally
          CamPos.Free;
        end;
      end;
    end;

    WriteLn;

    { --- 2. [objects] / [[objects]] セクションの巡回と個別取得 --- }
    ObjCount := Doc.GetTableCount('objects');
    WriteLn(Format('[Objects List] Count: %d', [ObjCount]));

    for I := 0 to ObjCount - 1 do
    begin
      ObjTable := Doc.GetTable('objects', I);
      
      { 一般化 GetValue オーバーロードによる取得 }
      ObjTable.GetValue('name', ObjName);
      ObjTable.GetValue('type', ObjType);

      WriteLn(Format('  Object #%d: Name="%s", Type="%s"', [I + 1, ObjName, ObjType]));

      { 1次元実数配列 (Position) の取得 }
      ObjPos := ObjTable.GetFloatArray('position');
      try
        if ObjPos.Count > 0 then
        begin
          Write('    Position: [');
          for J := 0 to ObjPos.Count - 1 do
          begin
            Write(ObjPos[J]:0:1);
            if J < ObjPos.Count - 1 then Write(', ');
          end;
          WriteLn(']');
        end;
      finally
        ObjPos.Free;
      end;
    end;

    WriteLn;

    { --- 3. FGL多重配列 (TDoubleMatrix: 2次元配列) の一括抽出デモ --- }
    WriteLn('[FGL Multi-Array Matrix Demo]');
    PositionsMatrix := Doc.GetMatrix('objects', 'position');
    try
      WriteLn(Format('  Extracted %d objects position vectors into 2D Matrix:', [PositionsMatrix.Count]));
      for I := 0 to PositionsMatrix.Count - 1 do
      begin
        Write(Format('  Row %d -> [', [I]));
        for J := 0 to PositionsMatrix[I].Count - 1 do
        begin
          { 2次元インデックスアクセス Matrix[i][j] }
          Write(PositionsMatrix[I][J]:0:1);
          if J < PositionsMatrix[I].Count - 1 then Write(', ');
        end;
        WriteLn(']');
      end;
    finally
      PositionsMatrix.Free;
    end;

  finally
    Doc.Free;
  end;
  WriteLn;
end;

var
  FileName: string;
begin
  if ParamCount > 0 then
    FileName := ParamStr(1)
  else
    FileName := 'toml-sphere.toml';

  if FileExists(FileName) then
    DemonstrateTomlParsing(FileName)
  else
    WriteLn('File not found: ', FileName);
end.
