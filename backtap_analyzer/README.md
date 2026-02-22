# Backtap Analyzer (Flutter MVP)

iPhoneのスクリーンショットを解析して、主に以下を抽出するMVPです。

- 何のアプリか（推定）
- 画面上の時間情報（時計/カウントダウン/解禁時刻など）

## Important

- iOS/Flutterアプリ単体では「他アプリ表示中の背面2タップ検知 + 直接スクショ取得」はできません。
- 実運用は `背面タップ -> ショートカット -> 本アプリに画像を渡す` 構成を想定します。
- 現在のMVPは「写真ライブラリからスクショ画像を選択して解析」です。

## 実装内容

- Flutter UI
  - 解析先の切替: On-device / Local API / Cloud API
  - スクショ保存フラグ
  - Local/Cloud URLとCloud APIキー設定（保存あり）
- iOSネイティブOCR
  - `Vision` による文字抽出
  - Flutter `MethodChannel` 連携 (`backtap_analyzer/ocr`)
- 解析ロジック
  - On-device: OCRテキストをルールベースで解析
  - Local/Cloud: HTTP POSTで外部APIに委譲

## セットアップ

```bash
flutter pub get
flutter run
```

## APIフォーマット（Local/Cloud）

リクエスト:

```json
{
  "text": "OCR text...",
  "save_screenshot": false,
  "image_path": "/path/to/image"
}
```

レスポンス（期待）:

```json
{
  "app_name": "YouTube",
  "time_text": "12:34",
  "time_type": "clock",
  "confidence": 0.93
}
```

## 追加予定

- iOSショートカット/App Intent経由の画像受け取り
- Android側の起動導線（クイック設定タイル/共有）
- 記憶機能（履歴の構造化保存）
