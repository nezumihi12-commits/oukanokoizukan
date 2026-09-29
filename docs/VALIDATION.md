# 納品時の検証結果

検査日: 2026-09-30 / Windows

- PASS: 307属、307個の一意なLatin ID、元の6項目、配列順を保持。
- PASS: 添付HTMLと公開GitHubのindex.htmlは改行コードを除いて一致。
- PASS: 元getJpInfoに由来する和名正解候補が全307属を網羅。
- PASS: genera.json / japaneseAnswers.jsonのSHA-256がsource-manifest.jsonと一致。
- PASS: 14個のSwiftファイルをtree-sitter-swiftで構文解析。構文エラーなし。
- PASS: project.yml / ios.ymlのYAML構文と参照先パス。
- PASS: アプリアイコンの各サイズ、RGB、不透明画像、ファイル参照。
- PASS: ZIPに.github/workflows/ios.yml、全ソース・リソース・説明書を収録。

XCTestは14メソッドを実装。全307属×基本3形式の正答テストも含む。
**XCTestの実行、Xcodeの型検査、iOS Simulator、device build、IPA作成、SideStore、実機UIの確認は未実施。**
これらはWindows上の構文・整合性検査では保証できない。GitHub Actionsがテスト成功後にデバイス用IPAを生成する。

プロジェクト作成のみで、ユーザーのGitHubリポジトリへの変更・pushは行っていない。
