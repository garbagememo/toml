program TOMLParserDemo;

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



{ テスト・実行用メインプログラム }
var
   Doc: TOMLDocument;
   CamTable: TOMLTable;
   ObjArray: TOMLArray;
   ObjTable: TOMLTable;
   PosArray: TOMLArray;
   I: Integer;
begin
   Doc := TOMLDocument.Create;
   try
      // アップロードされたTOMLファイルをロード
      Doc.LoadFromFile(ParamStr(1));

      WriteLn('=== TOMLDocument パーステスト ===');

      // [camera] テーブルの取得
      CamTable := Doc.Root.GetTable('camera');
      if CamTable <> nil then begin
         WriteLn('[camera]');
         WriteLn('  Width          : ', CamTable.GetInt('width'));
         WriteLn('  Height         : ', CamTable.GetInt('height'));
         WriteLn('  Plane Distance : ', CamTable.GetFloat('plane_distance'):0:1);

         // 配列要素の取得 (camera.position)
         PosArray := CamTable.GetArray('position');
         if PosArray <> nil then
            WriteLn(Format('  Position       : [%.1f, %.1f, %.1f]',
                           [PosArray[0].AsFloat, PosArray[1].AsFloat, PosArray[2].AsFloat]));
      end;

      // [[objects]] テーブル配列の取得
      ObjArray := Doc.Root.GetArray('objects');
      if ObjArray <> nil then begin
         WriteLn(#10, Format('[[objects]] (合計: %d 件)', [ObjArray.Count]));
         for I := 0 to ObjArray.Count - 1 do begin
            ObjTable := ObjArray[I].AsTable;
            WriteLn(Format('  [%d] Name: "%s", Type: "%s"', [
                              I,
                              ObjTable.GetString('name'),
                              ObjTable.GetString('type')
                                                            ]));
            if ObjTable.Find('filename') <> nil then
               WriteLn('      Filename: ', ObjTable.GetString('filename'));
            if ObjTable.Find('radius') <> nil then
               WriteLn('      Radius  : ', ObjTable.GetFloat('radius'):0:1);
         end;
      end;

   finally
      Doc.Free;
   end;
end.
