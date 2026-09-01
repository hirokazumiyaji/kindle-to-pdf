# KindleToPDF GUI アプリケーション設計

## 目的

既存の `KindleToPDFCore` を共有しつつ、FolioBinder 相当の macOS GUI アプリケーションを追加する。CLI は維持し、同じキャプチャ・ページ送り・クロップ・PDF 生成ロジックを利用する。

## スコープ（v1）

### 含める

- SwiftUI による macOS アプリ（スキャン、ライブラリ、セットアップ、設定）
- ワンボタンでスキャン開始〜PDF 生成まで
- ページ方向の自動切替と最終ページ検知（既存コアの挙動）
- ライブラリ一覧・プレビュー・再開・削除
- テストスキャンとクロップ調整 UI（自動クロップ結果の確認・手動 inset 上書き）
- アプリ設定の永続化

### 含めない

- CLI 成果物のライブラリ自動取り込み
- OCR によるタイトル／著者の自動認識
- クラウド同期・外部 API
- DRM 回避や Kindle 内部データへのアクセス

## アーキテクチャ

```text
KindleToPDFApp (SwiftUI, macOS 13+)
  ├─ AppState / Navigation
  ├─ ScanViewModel      → CaptureCoordinator
  ├─ LibraryViewModel   → LibraryStore
  ├─ SetupViewModel     → TestCapture + CropSettings
  └─ SettingsViewModel  → AppSettingsStore

KindleToPDFCore (既存)
  ├─ CaptureCoordinator
  ├─ MacOSWindowLocator / MacOSPageTurner / MacOSApplicationActivator
  ├─ MacOSWindowCapture + EdgeBackgroundCropper
  ├─ SessionStore / PDFWriter
  └─ CLIParser (CLI 専用)

kindle-to-pdf (既存 CLI, 維持)
```

### パッケージ構成

`Package.swift` に macOS アプリターゲットを追加する。

- `KindleToPDFCore` … 共有ライブラリ（変更は最小限）
- `KindleToPDF` … 既存 CLI
- `KindleToPDFApp` … 新規 GUI（`KindleToPDFCore` に依存）

配布は `scripts/package-app.sh` を拡張し、GUI アプリ Bundle を生成する。CLI 単体 Bundle も引き続き生成可能とする。

### 実行モデル

- キャプチャは `Task` でバックグラウンド実行。UI は `@MainActor` で進捗を更新する。
- 停止は既存の `stopRequested` クロージャで `SignalStopController` 相当を GUI から呼ぶ。
- ページ送りのため Kindle を前面化する（既存挙動を維持）。スキャン中は他作業と併用しにくいことを UI で明示する。

## データモデル

### ライブラリルート（既定）

`~/Documents/KindleToPDF/`

```text
KindleToPDF/
  Library/
    <book-id>.json          # 書籍エントリ
  Sessions/
    <book-id>/
      state.json
      pages/
        0001.png
  PDFs/
    <book-id>.pdf
  Settings/
    settings.json           # アプリ全体設定
    crop-defaults.json      # グローバル手動クロップ inset
```

### 書籍エントリ（`Library/<book-id>.json`）

| フィールド | 説明 |
|---|---|
| `id` | UUID |
| `displayName` | 表示名（手動編集可） |
| `createdAt` / `updatedAt` | ISO8601 |
| `status` | `scanning` / `ready` / `completed` |
| `sessionPath` | `Sessions/<book-id>/` |
| `pdfPath` | `PDFs/<book-id>.pdf`（未生成時は null） |
| `capturedPageCount` | 取得済みページ数 |
| `requestedPageCount` | 上限（null なら最終まで） |
| `cropOverride` | 書籍固有の手動 inset（任意） |

### アプリ設定（`Settings/settings.json`）

- 既定のライブラリルート
- 既定のめくりキー（`right` / `left` / `pagedown`）
- ページ上限の既定（null 可）
- 自動クロップのオンオフ
- グローバル手動 inset（上下左右 px）

### CLI との関係

- CLI は任意の `--output` と隣接 `.kindle-session` を使用する（現状維持）。
- GUI ライブラリは GUI が管理したパスのみを一覧表示する。
- CLI 成果の自動取り込みは v1 では行わない。

## UI フロー

### 1. スキャン

1. Kindle で本を開き、開始ページを表示する（フルスクリーン推奨を短く案内）。
2. スキャン画面で表示名・ページ上限（空なら最終まで）・ウィンドウ・めくりキーを確認し、**開始**。
3. 実行中は進捗（取得済みページ数）、経過時間、状態メッセージを表示。**停止**でセッションを残して中断。
4. 最終ページ検知または上限到達で PDF を生成し、ライブラリに `completed` として登録。完了ダイアログから Finder 表示／プレビューへ。

### 2. セットアップ（クロップ）

1. **テストスキャン**（数ページ）を実行し、プレビュー画像を表示。
2. 自動クロップ結果を並べて確認。問題なければ「自動のまま」で保存。
3. 必要なら手動で余白（上下左右 inset）をスライダーで調整し、グローバル既定または書籍固有に保存。
4. 手動 inset は `EdgeBackgroundCropper` の結果に対する追加レイヤとして適用する（自動判定を壊さない）。

### 3. ライブラリ

- 一覧: 表示名、状態、ページ数、更新日時。
- ダブルクリック: PDF プレビュー（`PDFKit` または Quick Look）。
- コンテキストメニュー: 再開、PDF 再生成、削除、Finder で表示。

### 4. 設定

- ライブラリルート、既定めくりキー、既定ページ上限、自動クロップ、グローバル inset。

## 画面構成

| 画面 | 主な要素 |
|---|---|
| スキャン | 開始／停止、進捗、出力名、ページ上限、ウィンドウ、めくりキー |
| ライブラリ | グリッドまたはリスト、検索、状態フィルタ、プレビュー |
| セットアップ | テストスキャン、クロッププレビュー、inset スライダー、保存 |
| 設定 | 既定値、権限状態、ライブラリフォルダを開く |

ナビゲーションは `NavigationSplitView`（サイドバー: スキャン / ライブラリ / セットアップ / 設定）。

## エラー処理

| 状況 | UI の振る舞い |
|---|---|
| Accessibility / 画面収録 / オートメーション未許可 | スキャン開始前にブロック。設定アプリへのリンクと手順を表示 |
| Kindle 未起動 | エラーダイアログ。「Kindle を起動してから再試行」 |
| ウィンドウ特定失敗 | `--window` 相当の入力欄を強調。複数ウィンドウ時は一覧から選択 |
| キャプチャ失敗 | スキャン中断。セッションは保存済みページまで保持 |
| ユーザー停止 | 非エラー終了。ライブラリを `scanning` のまま残し再開可能 |
| 最終ページ検知 | 正常完了。PDF 生成して `completed` |
| PDF 生成失敗 | セッションは保持。再生成ボタンをライブラリに表示 |

エラーメッセージは既存の `CaptureError` / `PlatformError` の文言を再利用し、GUI ではユーザー向けに短く整形する。

## 権限

初回起動または権限不足時にセットアップシートを表示する。

1. **アクセシビリティ** … キー送信
2. **画面収録** … ウィンドウキャプチャ
3. **オートメーション** … Kindle の activate（AppleScript）

各項目について:

- 現在の許可状態を表示
- システム設定を開くボタン
- 再チェックボタン（`MacOSPermissionChecker` を再利用）

再ビルドで署名が変わった場合は権限の再登録が必要であることを設定画面に記載する。

## コア側の変更（最小）

GUI 向けに以下のみ追加・調整する。

- `CaptureCoordinator` の進捗コールバック（ページ保存時に `capturedPageCount` を通知）
- 手動 inset 適用用の `CropSettings` と画像後処理（`EdgeBackgroundCropper` の後段）
- `LibraryStore` / `AppSettingsStore`（GUI 専用、Core または App ターゲット内）

既存 CLI の引数・挙動は破壊しない。

## テスト

### 単体

- `LibraryStore`: エントリの CRUD、パス解決
- `AppSettingsStore`: 読み書き、デフォルト値
- `ManualInsetCropper`（新規）: inset 適用のピクセル境界
- 既存 `KindleToPDFCoreTests` はすべて維持

### 結合（macOS 手動）

- 権限未許可時にスキャンがブロックされること
- スキャン開始〜3ページ〜停止〜再開〜PDF 完了
- ライブラリ一覧・プレビュー・削除
- セットアップのテストスキャンと inset 保存が次の本に反映されること
- CLI が従来どおり動作すること

## 完了条件

- GUI からワンボタンで PDF まで完了できる
- ライブラリで履歴の閲覧・再開・削除ができる
- セットアップでクロップを調整し、以降のスキャンに反映できる
- CLI は変更後も従来コマンドで動作する
- 単体テストが追加され、既存テストがすべて通過する

## 実装順序（案2: 一括、内部マイルストーン）

1. パッケージに `KindleToPDFApp` ターゲット追加、空の SwiftUI シェル
2. `LibraryStore` / `AppSettingsStore` / データモデル
3. スキャン画面 + `CaptureCoordinator` 接続（進捗コールバック追加）
4. ライブラリ画面（一覧・プレビュー・再開・削除）
5. セットアップ画面（テストスキャン・クロッププレビュー・inset）
6. 設定画面・権限シート
7. `package-app.sh` 拡張、README 更新
