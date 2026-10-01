# v0.3 検証記録

2026-10-01。基点 main: 57bf0402caa1ed24a00ea1a2f57352a3623bcfaf。

実行済み:
- Tree-sitterによる全Swiftファイルの構文解析、project/workflow YAML、ソースパス検査。
- scripts/validate.py: 元307属・6フィールド・回答データ・SHA256・54植物SVG/PNG参照を検査。
- habitatAttributes.json: 307属すべてを網羅、各8区画の適性値0...1、推奨2区画。
- 完全ZIPおよび差分ZIPのCRC、基点へ差分を重ねた内容と完成プロジェクトの一致。

未実行:
- XCTest 37件（今回12件追加）のApple SDKでのコンパイル・実行。
- iOS Simulator、実機でのフリック/ドラッグ/レイアウト確認。
- v0.3のGitHub Actions/unsigned IPA生成。

この環境はWindowsでXcodeがない。GitHub連携のtree作成は403で拒否され、今回のリモート反映はない。
基点v0.2のActions成功は確認済みだが、この変更のビルド成功を意味しない。
