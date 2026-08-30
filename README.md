# kindle-to-pdf

macOSのKindleアプリに表示されているページを自動キャプチャし、画像PDFへまとめるCLIです。

Kindle内部ファイルの読み出し、DRM解除、暗号化データの復号は行いません。

## 必要環境

- macOS 13以上
- Swift 5.9以上
- Kindleアプリ

## ビルド

```bash
swift build -c release
```

実行ファイルは`.build/release/kindle-to-pdf`に生成されます。

## 権限設定

権限確認は現在の実行プロセスに対して行われます。単独のCLIではなく、次のスクリプトでApp Bundleを作成してください。

```bash
zsh scripts/package-app.sh "$HOME/Documents/KindleToPDF.app"
```

作成された`KindleToPDF.app`を、次のmacOS設定へ追加してください。

- システム設定 > プライバシーとセキュリティ > アクセシビリティ
- システム設定 > プライバシーとセキュリティ > 画面収録
- システム設定 > プライバシーとセキュリティ > オートメーション（Kindleの操作を求められた場合）

権限変更後は、作成したApp Bundle内の実行ファイルを使います。再ビルドするとadhoc署名が変わるため、権限を再登録してください。

## 使い方

1. Kindleアプリで対象の本を開く。
2. 取得を開始したいページを表示する。
3. Kindleウィンドウを別デスクトップまたは別ディスプレイへ移動する。
4. Kindleウィンドウを最小化せずに、次のコマンドを実行する。

```bash
"$HOME/Documents/KindleToPDF.app/Contents/MacOS/kindle-to-pdf" capture \
  --output "$PWD/book.pdf"
```

`--pages`を省略すると、画面が変わらなくなるまで（最終ページまで）取得します。上限を付ける場合だけ指定します。

```bash
"$HOME/Documents/KindleToPDF.app/Contents/MacOS/kindle-to-pdf" capture \
  --output "$PWD/book.pdf" \
  --pages 200
```

`--pages`は現在表示中のページを1ページ目として数えます。Kindleウィンドウが複数ある場合は、タイトルを指定できます。

```bash
"$HOME/Documents/KindleToPDF.app/Contents/MacOS/kindle-to-pdf" capture \
  --output "$PWD/book.pdf" \
  --window "Kindle"
```

既定のページ送りは右矢印です。進まない場合は左矢印へ自動切替します（縦書き向け）。固定したい場合は`--next-key`を指定します。

```bash
"$HOME/Documents/KindleToPDF.app/Contents/MacOS/kindle-to-pdf" capture \
  --output "$PWD/book.pdf" \
  --next-key left
```

## 停止と再開

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
"$HOME/Documents/KindleToPDF.app/Contents/MacOS/kindle-to-pdf" capture \
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
