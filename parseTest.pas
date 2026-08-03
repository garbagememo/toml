program parseTest;

{$mode objfpc}{$H+}{$M+}
{$codepage UTF8}

uses
  {$IFDEF UNIX}
  cwstring,
  {$ENDIF}
  {$IFDEF WINDOWS}
  Windows,
  {$ENDIF}
  SysUtils, Classes, StrUtils, Generics.Collections,
  uTOML;



var
  Doc: TOMLDocument;
  ObjArrayVal, Val: TOMLValue;
  PosArray: TOMLArray;
  ObjTable: TOMLTable;
  I: Integer;
begin
  Doc := TOMLDocument.Create;
  try
    Doc.LoadFromFile('toml-sphere.toml');


    WriteLn('=== GetValueByPath の使用例 ==='#10);

    // 1. 数値（整数）の取得: "camera.width"
    Val := Doc.GetValueByPath('camera.width');
    if Val <> nil then
      WriteLn('Camera Width: ', Val.AsInt)
    else
      WriteLn('camera.width が見つかりませんでした');

    // 2. 浮動小数点数の取得: "camera.plane_distance"[cite: 1]
    Val := Doc.GetValueByPath('camera.plane_distance');
    if Val <> nil then
      WriteLn('Plane Distance: ', Val.AsFloat:0:1);

    // 3. 配列（Vector3）の取得: "camera.position"[cite: 1]
    Val := Doc.GetValueByPath('camera.position');
    if (Val <> nil) and (Val.ValueType = tvtArray) then
    begin
      PosArray := Val.AsArray;
      WriteLn(Format('Camera Position: [%.1f, %.1f, %.1f]', [
        PosArray[0].AsFloat,
        PosArray[1].AsFloat,
        PosArray[2].AsFloat
      ]));
    end;

    // 4. 文字列の取得 (単一 [objects] テーブルの場合): "objects.name"[cite: 1]
    Val := Doc.GetValueByPath('objects.name');
    if Val <> nil then
      WriteLn('Object Name: ', Val.AsString);

    // 5. 存在しないキーを取得しようとした場合（安全な評価）
    Val := Doc.GetValueByPath('camera.unknown_key');
    if Val = nil then
      WriteLn('camera.unknown_key は存在しません（nil が返されます）');
    // 'objects' 全体の配列を取得
    ObjArrayVal := Doc.GetValueByPath('objects');

    writeln('==========GetValueByPathによる多重配列の取得=====');

    if (ObjArrayVal <> nil) and (ObjArrayVal.ValueType = tvtArray) then
    begin
      WriteLn('オブジェクト総数: ', ObjArrayVal.AsArray.Count);

      // 0番目のオブジェクト（Sky Light）のプロパティを取得
      ObjTable := ObjArrayVal.AsArray[0].AsTable;
      WriteLn('0番目の名前: ', ObjTable.GetString('name'));     // Sky Light
      WriteLn('0番目の半径: ', ObjTable.GetFloat('radius'):0:1); // 100000.0

      // 1番目のオブジェクト（Ground）のプロパティを取得
      ObjTable := ObjArrayVal.AsArray[1].AsTable;
      WriteLn('1番目の名前: ', ObjTable.GetString('name'));     // Ground
    end;
  finally
    Doc.Free;
  end;
end.
