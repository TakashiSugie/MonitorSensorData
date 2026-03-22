# SensorMonitor を Cloud Run にデプロイするための実装計画

## 概要

SensorMonitor Node.jsアプリ（Apple Watchセンサーデータ→WebSocket→ブラウザ ダッシュボード）をGoogle Cloud Runへ移行する。現状のコードベースは基本的なCloud Run対応（PORT環境変数、ping/pong）が済んでおり、仕上げの最適化とデプロイ支援スクリプト作成が主な作業。

## Proposed Changes

---

### Dockerfile 改善

#### [MODIFY] [Dockerfile](file:///Users/sugietakashi/Desktop/gemini/antigravity/playground/silver-sagan/BenchSenseR1/SensorMonitor/Dockerfile)

- `node:20-alpine` → `node:20-slim` へ変更（WebSocket互換性向上）
- 非rootユーザーで実行（セキュリティ強化）
- Cloud Run 推奨の `PORT` 環境変数デフォルト値を設定
- HEALTHCHECKを追加（ローカルDocker実行時の利便性）

---

### server.js Cloud Run 最適化

#### [MODIFY] [server.js](file:///Users/sugietakashi/Desktop/gemini/antigravity/playground/silver-sagan/BenchSenseR1/SensorMonitor/server.js)

- デフォルトポートを`8080`に変更（Cloud Run標準）
- グレースフルシャットダウン対応（`SIGTERM`ハンドリング）— Cloud Runがインスタンス停止時に`SIGTERM`を送信するため
- リクエストログ追加（Cloud Loggingで確認しやすくするため）
- Cloud Run環境検出の追加（`K_SERVICE`環境変数）

---

### index.html WebSocket 強化

#### [MODIFY] [index.html](file:///Users/sugietakashi/Desktop/gemini/antigravity/playground/silver-sagan/BenchSenseR1/SensorMonitor/index.html)

- WebSocket再接続にExponential Backoff（指数バックオフ）を追加
- 再接続上限と状態表示の改善
- Cloud Runのコールドスタートに対応した再接続ロジック

---

### デプロイスクリプト作成

#### [NEW] [deploy.sh](file:///Users/sugietakashi/Desktop/gemini/antigravity/playground/silver-sagan/BenchSenseR1/SensorMonitor/deploy.sh)

- `gcloud run deploy` をワンコマンドで実行できるシェルスクリプト
- リージョン、メモリ、インスタンス数などのデフォルト設定付き
- 初回セットアップ（API有効化）コマンドも含む

---

### ドキュメント更新

#### [MODIFY] [DEPLOY.md](file:///Users/sugietakashi/Desktop/gemini/antigravity/playground/silver-sagan/BenchSenseR1/SensorMonitor/DEPLOY.md)

- deploy.shスクリプトの活用方法を追記
- トラブルシューティングセクション追加

#### [MODIFY] [README.md](file:///Users/sugietakashi/Desktop/gemini/antigravity/playground/silver-sagan/BenchSenseR1/SensorMonitor/README.md)

- Cloud Runデプロイ時の使い方セクション追加

---

## Verification Plan

### ローカル Docker テスト

```bash
cd SensorMonitor
docker build -t benchsense-monitor .
docker run -p 8080:8080 benchsense-monitor
```

1. `curl http://localhost:8080/api/status` でヘルスチェック応答を確認
2. ブラウザで `http://localhost:8080` を開いてダッシュボード表示確認
3. `curl -X POST http://localhost:8080/api/sensor-data -H 'Content-Type: application/json' -d '{"samples":[{"t":1.0,"ax":0.1,"ay":-0.5,"az":0.9,"fay":-0.3,"phase":"descending","rep":0}]}'` でデータ受信テスト

### 手動確認（ユーザー）

- Cloud Runへの実際のデプロイは `deploy.sh` またはDEPLOY.mdの手順に従って実施
- デプロイ後のURLでダッシュボードアクセスを確認
- WatchアプリのSensorStreamer.swiftの`serverURL`をCloud Run URLに更新し、データ送信テスト
