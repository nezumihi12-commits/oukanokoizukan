# Windowsからビルド済みIPAを導入する

このアプリはiOS 17以上が必要です。unsigned IPAはそのまま開くだけではインストールできません。SideStoreで署名して導入します。

## SideStoreがすでに使える場合

1. Actions成功後のArtifact ZIPを展開して、**Hanazukan-unsigned.ipa**をiPhoneの「ファイル」に保存。
2. SideStoreの現行ガイドが指定するVPNを接続。SideStoreの **My Apps → ＋** からIPAを選択し、署名と導入を待つ。
3. 花図鑑を起動。[実機チェックリスト](DEVICE-CHECKLIST.md)でまとめて確認する。
4. 更新時は同じアカウント・同じBundle IDを使い、前のアプリを削除せず新しいIPAを導入する。先に写真込みバックアップを保存しておく。
5. SideStoreに表示される署名期限までに更新する。無料アカウントでは通常7日の期限があるため、My Appsの残日数表示を確認する。

Artifactはダウンロード用のZIPです。SideStoreに渡すのは展開後の`.ipa`で、プロジェクトZIPやArtifact ZIPではありません。

## SideStoreの初回設定が必要な場合

2026-09-30に確認した[公式の前提条件](https://docs.sidestore.io/docs/installation/prerequisites)と[導入ガイド](https://docs.sidestore.io/docs/installation/install)を使用してください。公式手順は現在、PC側の**iloader**と端末側の**LocalDevVPN**を案内しています。古いAltServer/WireGuard手順と混ぜず、端末のiOSに該当する項目に従います。

大まかな流れは、PCとiPhoneをUSB接続して信頼 → iloaderでApple Accountにサインイン → Install SideStore (Stable) → iPhoneで開発者を信頼し、必要なDeveloper Modeを有効化 → LocalDevVPNを接続 → SideStoreに同じアカウントでサインイン → My AppsからSideStoreを一度更新、です。Windows側に必要なAppleドライバー等は公式の前提条件ページを確認してください。

Apple Accountの入力はiloader/SideStore側で行います。このプロジェクトやGitHub Secretsへの入力は不要です。署名可能なアプリ数・App ID数の制限や端末の状態により導入できないことがあります。

## 困ったとき

| 状況 | 確認 |
|---|---|
| Actionsにワークフローが出ない | `.github/workflows/ios.yml`がリポジトリのルート基準にあり、デフォルトブランチに入っているか |
| ビルド失敗 | Build-and-test-diagnosticsの最初のコンパイルエラーを確認。Xcodeの型検査はActionsが初回 |
| IPAが見つからない | 成功した実行のArtifactsからダウンロードしてZIPを展開したか |
| SideStoreで期限・署名のエラー | VPN接続、Apple Account、署名期限、アプリ数の制限を確認 |
| OSアップデート後に動かない | 公式手順のペアリング情報更新が必要な場合あり |
| 新旧2つの花図鑑ができた | Bundle IDや署名アカウントを途中で変えていないか |
| 位置が出ない | iOS設定の位置情報許可、写真のGPS有無、地図通信を確認 |

SideStore自体の問題は[公式トラブルシューティング](https://docs.sidestore.io/docs/troubleshooting)を参照してください。
