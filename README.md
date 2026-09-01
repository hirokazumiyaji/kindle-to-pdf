# kindle-to-pdf

macOSのKindleアプリに表示されているページを自動キャプチャし、画像PDFへまとめるツールです。

SwiftUIのGUIアプリと、従来のCLIの両方を提供します。Kindle内部ファイルの読み出し、DRM解除、暗号化データの復号は行いません。

## 必要環境

- macOS 13以上
- Swift 5.9以上
- Kindleアプリ

## GUIアプリのインストール

```bash
zsh scripts/package-app.sh gui
```

既定では `$HOME/Documents/KindleToPDF.app` を作成します。出力先を変える場合は第2引数を指定します。

```bash
zsh scripts/package-app.sh gui "$HOME/Documents/KindleToPDF.app"
```

作成した `KindleToPDF.app` を開いて使います。再ビルドするとadhoc署名が変わるため、権限を再登録してください。

## 権限設定

キャプチャには次のmacOS権限が必要です。初回起動時にセットアップシートが表示されます。システム設定へ追加してください。

- システム設定 > プライバシーとセキュリティ > アクセシビリティ
- システム設定 > プライバシーとセキュリティ > 画面収録
- システム設定 > プライバシーとセキュリティ > オートメーション（Kindleの操作を求められた場合）

権限確認は現在の実行プロセスに対して行われます。CLIを使う場合も、後述のApp Bundle内の実行ファイルを使ってください。

## ライブラリの場所

GUIの書籍・セッション・PDF・設定は次の場所に保存します（設定画面で確認できます）。

```text
~/Documents/KindleToPDF/
  Library/          # 書籍エントリ
  Sessions/         # キャプチャ途中のページ
  PDFs/             # 生成したPDF
  Settings/
    settings.json   # アプリ設定（ライブラリルート、めくりキー、ページ上限、自動クロップ、グローバル inset）
```

クロップの既定 inset も `settings.json` に含めます。`crop-defaults.json` は使いません。

## 画面の概要

サイドバーから次の4画面を切り替えます。

- **スキャン** — Kindleで本を開き、開始ページを表示してから開始します。表示名・ページ上限・ウィンドウ・めくりキーを確認し、ワンボタンでキャプチャからPDF生成まで行います。停止するとセッションを残して中断できます。
- **ライブラリ** — 取得済みの本の一覧、PDFプレビュー、再開、削除、Finder表示。
- **セットアップ** — テストスキャン（3ページ）で自動クロップ結果を確認し、余白 inset を調整して既定値として保存します。
- **設定** — ライブラリルート、既定めくりキー、既定ページ上限、自動クロップ、グローバル inset、権限状態。

スキャン中はKindleを前面化します。フルスクリーン表示を推奨します。他の作業との同時利用は想定していません。

## CLIのパッケージ

CLI単体のApp Bundleも作成できます。

```bash
zsh scripts/package-app.sh cli "$HOME/Documents/KindleToPDFCLI.app"
```

第1引数にパスだけを渡す従来の呼び出しも、CLIパッケージとして動作します。

```bash
zsh scripts/package-app.sh "$HOME/Documents/KindleToPDF.app"
```

リリースバイナリだけが必要な場合は次でも構いません。

```bash
swift build -c release
```

実行ファイルは `.build/release/kindle-to-pdf`（CLI）と `.build/release/KindleToPDFApp`（GUI）に生成されます。

## CLIの使い方

1. Kindleアプリで対象の本を開く。
2. 取得を開始したいページを表示する。
3. Kindleウィンドウを別デスクトップまたは別ディスプレイへ移動する。
4. Kindleウィンドウを最小化せずに、次のコマンドを実行する。

```bash
"$HOME/Documents/KindleToPDFCLI.app/Contents/MacOS/kindle-to-pdf" capture \
  --output "$PWD/book.pdf"
```

`--pages`を省略すると、画面が変わらなくなるまで（最終ページまで）取得します。上限を付ける場合だけ指定します。

```bash
"$HOME/Documents/KindleToPDFCLI.app/Contents/MacOS/kindle-to-pdf" capture \
  --output "$PWD/book.pdf" \
  --pages 200
```

`--pages`は現在表示中のページを1ページ目として数えます。Kindleウィンドウが複数ある場合は、タイトルを指定できます。

```bash
"$HOME/Documents/KindleToPDFCLI.app/Contents/MacOS/kindle-to-pdf" capture \
  --output "$PWD/book.pdf" \
  --window "Kindle"
```

既定のページ送りは右矢印です。進まない場合は左矢印へ自動切替します（縦書き向け）。固定したい場合は`--next-key`を指定します。

```bash
"$HOME/Documents/KindleToPDFCLI.app/Contents/MacOS/kindle-to-pdf" capture \
  --output "$PWD/book.pdf" \
  --next-key left
```

CLIは任意の `--output` と隣接する `.kindle-session` を使います。GUIライブラリへの自動取り込みはしません。

## 停止と再開（CLI）

`Ctrl-C`で停止すると、保存済みページと状態が出力PDFの隣へ残ります。

```text
book.pdf
book.kindle-session/
  state.json
  pages/
    0001.png
    0002.png
```

同じ本を同じ開始位置でKindleに開き、次のコマンドで再開します。`--pages`を最初に指定していた場合は同じ値を付けてください。

```bash
"$HOME/Documents/KindleToPDFCLI.app/Contents/MacOS/kindle-to-pdf" capture \
  --output "$PWD/book.pdf" \
  --resume
```

再開時は同じ本とページ位置を利用者が確認してください。ツールは本文のタイトルや実ページ番号を照合しません。

## 制限

- 出力は画面画像を並べた画像PDFです。OCRやテキスト検索には対応しません。
- Kindleウィンドウを最小化・非表示にした状態は保証対象外です。
- ページ送りのため、実行中はKindleを前面化します。別作業と同時には使いにくい場合があります。
- どちらの方向にもページが進まない場合は、最終ページと判断してそこまでのPDFを作成します。
- 四隅から均一と判断できる外周背景の余白は自動で除去します。ページ内部の余白は保持し、外周背景を確実に判定できない画像は変更しません。
