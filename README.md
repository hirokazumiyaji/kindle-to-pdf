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

実行に使うターミナルアプリを、次のmacOS設定へ追加してください。

- システム設定 > プライバシーとセキュリティ > アクセシビリティ
- システム設定 > プライバシーとセキュリティ > 画面収録

権限を変更した後は、ターミナルアプリを再起動してください。

## 使い方

1. Kindleアプリで対象の本を開く。
2. 取得を開始したいページを表示する。
3. Kindleウィンドウを別デスクトップまたは別ディスプレイへ移動する。
4. Kindleウィンドウを最小化せずに、次のコマンドを実行する。

```bash
.build/release/kindle-to-pdf capture \
  --output "$PWD/book.pdf" \
  --pages 200
```

`--pages`は現在表示中のページを1ページ目として数えます。Kindleウィンドウが複数ある場合は、タイトルを指定できます。

```bash
.build/release/kindle-to-pdf capture \
  --output "$PWD/book.pdf" \
  --pages 200 \
  --window "Kindle - Book"
```

ページ送りが反応しない場合は、PageDownへ変更できます。

```bash
.build/release/kindle-to-pdf capture \
  --output "$PWD/book.pdf" \
  --pages 200 \
  --next-key pagedown
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

同じ本を同じ開始位置でKindleに開き、次のコマンドで再開します。

```bash
.build/release/kindle-to-pdf capture \
  --output "$PWD/book.pdf" \
  --pages 200 \
  --resume
```

再開時は同じ本とページ位置を利用者が確認してください。ツールは本文のタイトルや実ページ番号を照合しません。

## 制限

- 出力は画面画像を並べた画像PDFです。OCRやテキスト検索には対応しません。
- Kindleウィンドウを最小化・非表示にした状態は保証対象外です。
- Kindleアプリがバックグラウンドのページ送りを受け付けない環境では、別作業と同時に動作しない場合があります。
- ページ画像に変化がない場合は、重複ページを追加せず停止します。
