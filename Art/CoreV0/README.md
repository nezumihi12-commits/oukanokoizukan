# 花図鑑 庭パーツ Core v0

これは最終アートではなく、モジュール合成方式を実機で検証するためのプロトタイプ素材です。

- skeletons: 12
- leaves: 14
- flowers: 18
- inflorescences: 10

方針:
1. SVGを制作原本にする
2. iOSアプリにはPNG/PDFへ変換して入れるか、将来的にSwiftUI Canvas/Pathへ置換する
3. 色違い・忘却状態は原則として別画像を増やさずコードで表現する
4. 属固有の特徴は、共通パーツで庭が動いた後に追加する

画像のアンカーやスタイルは manifest.json を参照。
