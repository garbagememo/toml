program process_toml;

{$mode objfpc}{$H+}{$J-}

uses
  SysUtils,
  TOML,        // ハイレベルAPI (ParseTOMLFromFile等)
  TOML.Types;  // TTOMLTable, TTOMLArray, TTOMLValue 等の型定義

{ 配列要素（float）を綺麗に出力するためのヘルパー関数 }
procedure PrintFloatArray(const ALabel: string; AArray: TTOMLArray);
var
  i: Integer;
begin
  Write('    ', ALabel, ': [');
  for i := 0 to AArray.Count - 1 do
  begin
    Write(AArray.GetItem(i).AsFloat:0:2);
    if i < AArray.Count - 1 then
      Write(', ');
  end;
  WriteLn(']');
end;

{ カメラ設定 [camera] の処理 }
procedure ProcessCamera(ACamera: TTOMLTable);
var
  Val: TTOMLValue;
begin
  WriteLn('  --- Camera Settings ---');
  if ACamera.TryGetValue('width', Val) then 
    WriteLn('    Width: ', Val.AsInteger);
  if ACamera.TryGetValue('height', Val) then 
    WriteLn('    Height: ', Val.AsInteger);
  if ACamera.TryGetValue('samples', Val) then 
    WriteLn('    Samples: ', Val.AsInteger);
  if ACamera.TryGetValue('plane_distance', Val) then 
    WriteLn('    Plane Distance: ', Val.AsFloat:0:2);

  if ACamera.TryGetValue('position', Val) and (Val.ValueType = tvtArray) then
    PrintFloatArray('Position', Val.AsArray);

  if ACamera.TryGetValue('direction', Val) and (Val.ValueType = tvtArray) then
    PrintFloatArray('Direction', Val.AsArray);
end;

{ 1つのオブジェクト (テーブル) の詳細を出力 }
procedure ProcessObjectTable(AObjTable: TTOMLTable; Index: Integer);
var
  Val: TTOMLValue;
begin
  WriteLn('  --- Object #', Index, ' ---');
  if AObjTable.TryGetValue('name', Val) then 
    WriteLn('    Name: ', Val.AsString);
  if AObjTable.TryGetValue('type', Val) then 
    WriteLn('    Type: ', Val.AsString);
  if AObjTable.TryGetValue('filename', Val) then 
    WriteLn('    Filename: ', Val.AsString);
  if AObjTable.TryGetValue('material', Val) then 
    WriteLn('    Material: ', Val.AsString);
  if AObjTable.TryGetValue('radius', Val) then 
    WriteLn('    Radius: ', Val.AsFloat:0:2);

  if AObjTable.TryGetValue('position', Val) and (Val.ValueType = tvtArray) then
    PrintFloatArray('Position', Val.AsArray);

  if AObjTable.TryGetValue('color', Val) and (Val.ValueType = tvtArray) then
    PrintFloatArray('Color', Val.AsArray);

  if AObjTable.TryGetValue('emission', Val) and (Val.ValueType = tvtArray) then
    PrintFloatArray('Emission', Val.AsArray);
end;

{ オブジェクト一覧 ([objects] / [[objects]]) の処理 }
procedure ProcessObjects(AObjectsVal: TTOMLValue);
var
  ObjArray: TTOMLArray;
  i: Integer;
begin
  // [[objects]] (配列形式) の場合
  if AObjectsVal.ValueType = tvtArray then
  begin
    ObjArray := AObjectsVal.AsArray;
    for i := 0 to ObjArray.Count - 1 do
    begin
      if ObjArray.GetItem(i).ValueType = tvtTable then
        ProcessObjectTable(ObjArray.GetItem(i).AsTable, i + 1);
    end;
  end
  // [objects] (単一テーブル形式) の場合
  else if AObjectsVal.ValueType = tvtTable then
  begin
    ProcessObjectTable(AObjectsVal.AsTable, 1);
  end;
end;

{ 指定されたTOMLファイル全体をパースして表示 }
procedure ProcessTOMLFile(const AFileName: string);
var
  RootTable: TTOMLTable;
  Val: TTOMLValue;
begin
  WriteLn('==================================================');
  WriteLn('Processing: ', AFileName);
  WriteLn('==================================================');

  if not FileExists(AFileName) then
  begin
    WriteLn('Error: File not found - ', AFileName);
    WriteLn;
    Exit;
  end;

  try
    // ParseTOMLFromFile を呼び出してルートテーブルを取得
    RootTable := ParseTOMLFromFile(AFileName);
    try
      // 1. [camera] の処理
      if RootTable.TryGetValue('camera', Val) and (Val.ValueType = tvtTable) then
      begin
        ProcessCamera(Val.AsTable);
        WriteLn;
      end;

      // 2. objects ( [objects] または [[objects]] ) の処理
      if RootTable.TryGetValue('objects', Val) then
      begin
        ProcessObjects(Val);
        WriteLn;
      end;

    finally
      // メモリ解放 (ルートテーブルをFreeすると内包されるすべてのオブジェクトもFreeされる)
      RootTable.Free;
    end;
  except
    on E: Exception do
      WriteLn('Error parsing TOML file: ', E.Message);
  end;
  WriteLn;
end;

var
  TargetFiles: array[0..2] of string = (
    'test-sphere.toml',
    'test-cornel.toml',
    'test-obj.toml'
  );
  FileName: string;
begin
  // 指定された3つのTOMLファイルを順次処理
  for FileName in TargetFiles do
  begin
    ProcessTOMLFile(FileName);
  end;
end.