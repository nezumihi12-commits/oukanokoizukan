# 花図鑑 v0.2 — 記憶の庭園

**v0.2を既存アプリへ更新する手順は [V02-GARDEN.md](docs/V02-GARDEN.md)。** 基本3形式の正解が初開花につながり、中央庭園で復習と色彩の回復を続けられるようになりました。既存の図鑑・写真・成績を保持し、保存形式v1をv2へ移行します。

Windowsで編集し、GitHub ActionsのmacOSランナーでビルドし、SideStoreでiPhoneに導入するためのプロジェクトです。iOS / iPadOS **17.0以上**。アプリ本体に外部パッケージ依存はありません。

**この納品物はソースプロジェクトです。IPAではありません。** v0.1は指定リポジトリのActions成功を確認し、実機起動済みとの共有会話も確認しました。今回のv0.2はWindows上の構文・データ・素材参照検査までで、Xcode型検査・XCTest・iOS実機は未実施です。更新後のActionsでテストとデバイスビルドを実行してください。テストが失敗した場合はIPAを出力しません。

## 収録機能

- 元HTMLの全**307属**・6項目を原文のまま収録。HTMLの「300属」表記より実データが7属多いため、件数は動的表示。
- 属名・読み・科名・旧科名・和名・備考の検索、図鑑グリッド、詳細、写真あり・発見済み・記憶済み・苦手フィルター。
- 属名→科名、和名→ラテン語属名、属名→和名、科名→属名列挙、写真問題、基本3形式のランダム混合。
- 全体／番号範囲／苦手／写真ありから1・5・20問を出題。対象が少ないときはその属数で開始。
- スペル1文字違いは部分点。現科名・旧科名と元HTMLの代表種候補を採点に利用。
- 属別・形式別正答率、3形式の平均による習熟度、記憶済み、日別回答数、完了／途中終了の履歴。
- PhotosPickerによる複数写真登録、拡大、削除、EXIF日時・GPS読取、現在地の記録、MapKit地図。
- 端末内JSONの原子的保存、写真込みバックアップの書き出し・復元。
- 基本3形式で初開花、中央庭園、段階制復習、記憶鮮度の5段階表示、おすすめ最大5属、全復習待ちの連続手入れ、お気に入り固定。
- 共有会話のCore v0 SVG 54パーツを復元した通常状態の画像と307属の描画定義。退色はアプリ側の効果のみ。最終アートではありません。
- GardenZone / HabitatDefinition / Observation / CharacterEvent、同期・通知・Widget用スナップショット・App Intent接続用ルーターの土台。

Firebase/Cloudinaryへの接続、Web版からの既存成績・写真の自動移行、中央庭園以外の区画、報酬・ショップ、Widget拡張、Shortcutsアクション公開、通知設定画面は含みません。東方Project・風見幽香の画像・正式台詞は含みません。v0.1移植の詳細は [移植仕様](docs/MIGRATION.md)。

## 最短のビルド手順（Mac不要）

1. ZIPを展開します。**Hanazukanフォルダーの中身**（`project.yml`、`App`、`Tests`、`scripts`、`.github`など）をGitHubリポジトリのルートに置きます。外側のHanazukanフォルダーごと置かないでください。
2. 元Web版を残す場合は、新しいリポジトリを作るのが簡単です。同じリポジトリでも、既存`index.html`を残してこれらをルートに追加できます。このプロジェクトはWeb版のファイルを変更しません。
3. GitHubのWebアップロードでは、隠しフォルダー **`.github/workflows/ios.yml`** が抜けていないか確認してください。GitHub Desktopでローカルフォルダーをコミットすると確実です。
4. `main` / `master`へ保存すると **Actions → Build and test iOS** が動きます。手動なら同画面の **Run workflow**。ワークフローを手動表示するにはデフォルトブランチに配置してください。
5. 成功した実行の **Artifacts → Hanazukan-unsigned-IPA** をダウンロードします。ZIPを展開し、`Hanazukan-unsigned.ipa`をiPhoneの「ファイル」へ移します。
6. [SideStore導入手順](docs/SIDESTORE.md)に従い、SideStoreでそのIPAを選びます。

Apple Account、証明書、パスワード、GitHub Secretsは**ビルドには不要**です。GitHub側はunsigned IPAを作り、SideStoreが端末への導入時に署名します。公開リポジトリではソースとArtifactsも公開され得るため、個人の写真・バックアップをコミットしないでください。

Bundle IDは`project.yml`の`io.github.nezumihi12.hanazukan`です。初回に変更するなら以降も同じ値に固定してください。更新の際は同じApple Account・同じBundle IDで上書きし、アプリを削除しない運用にします。

## 一度の実機導入で確認する項目

[実機チェックリスト](docs/DEVICE-CHECKLIST.md)を順番に使ってください。検索、全形式、採点境界、保存、日付変更、写真・位置、バックアップを一巡できます。

## 保存とバックアップ

アプリ専用Application Support/Hanazukanの`state.json`と`Photos/*.jpg`に保存します。回答のたびに成績を保存し、保存に失敗した場合は次の問題へ進みません。保存データが壊れていたり未知のバージョンだった場合、空データで上書きせず起動エラーを表示します。

**記録 → 写真を含むバックアップを作成 → JSONを共有・保存**で、アプリ外の「ファイル」などへ保存してください。復元は **記録 → バックアップを復元**。形式・植物ID・写真参照などを検証してから確認を表示し、現在のデータを置換します。復元写真は新しいIDで書き込み、最後に状態を原子的に保存するため、途中の書き込み失敗で現在の写真を置き換えません。

バックアップは写真をBase64として含むJSONです。大量写真ではファイルサイズ・メモリ消費が大きくなります。写真は最大1800pxに縮小して保存します。別の「学習データを書き出す」は画像なしの調査用JSONで、復元用ではありません。どちらにも位置情報が含まれる場合があります。

アプリ削除は端末内記録も消すため、先にバックアップを外部保存してください。Web版のlocalStorage/IndexedDBは別領域で、このアプリには自動移行されません。

## 開発構成

| 場所 | 役割 |
|---|---|
| `App/Core` | データモデル、採点、出題対象、バックアップ検証 |
| `App/Services` | 永続化、写真、位置、同期・通知・拡張の接続点 |
| `App/Views` | 学習・図鑑・記録・庭 |
| `App/Resources` | 307属データ、和名正解候補、オリジナル幾何学アイコン |
| `Tests` | 採点・集計・保存・バックアップ・写真のXCTest |
| `project.yml` | XcodeGenのプロジェクト定義 |
| `.github/workflows/ios.yml` | テスト → デバイスビルド → IPA化 |

Windowsでデータを検査する場合は`python scripts/validate.py`。Macが使える場合は`brew install xcodegen`、`xcodegen generate`でXcodeプロジェクトを生成できます。生成した`.xcodeproj`は保存不要です。

Actionsのランナーは`macos-15`、利用可能なiPhone Simulatorを自動選択します。Xcode/Homebrew/XcodeGenのバージョンは実行ログに残しますが、厳密に固定した再現ビルドではありません。ランナー更新時には設定の調整が必要になる場合があります。失敗時は`Build-and-test-diagnostics`のログと`.xcresult`で最初のエラーを確認してください。

## 参照

- [元Web版](https://github.com/nezumihi12-commits/hanazukan) — 参照コミット・添付のSHA-256は`docs/source-manifest.json`。
- [XcodeGen Project Spec](https://github.com/yonaskolb/XcodeGen/blob/master/Docs/ProjectSpec.md) — プロジェクト定義。
- [Apple PhotosPicker](https://developer.apple.com/documentation/photosui/photospicker) / [MapKit Map](https://developer.apple.com/documentation/mapkit/map) — 写真・地図のAPI。
- [SideStore公式導入ガイド](https://docs.sidestore.io/docs/installation/install) — 導入・署名更新。

元の植物情報はユーザー提供データを保持し、植物分類の再監修は行っていません。既存リポジトリにライセンス指定がないため、この納品で元データや元コードに新しいライセンスを付与していません。
