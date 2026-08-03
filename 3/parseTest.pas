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
  ObjTable: TOMLTable;
  I: Integer;
begin
  Doc := TOMLDocument.Create;
  try
    Doc.LoadFromFile('toml-sphere.toml');

    // 'objects' 全体の配列を取得
    ObjArrayVal := Doc.GetValueByPath('objects');

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
