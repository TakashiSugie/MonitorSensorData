# BenchSense Sensor Monitor

Apple Watchのセンサーデータをリアルタイムで可視化するモニタリングダッシュボード。

## アーキテクチャ

```
Apple Watch (CoreMotion 50Hz) → HTTP POST → Node.js Server → WebSocket → Browser Dashboard
```

## 使い方

### 1. サーバーIPアドレスの確認

ターミナルで以下を実行してMacのローカルIPアドレスを確認：

```bash
ifconfig en0 | grep "inet "
# 例: inet 192.168.150.90
```

### 2. Watch側の設定

`SensorStreamer.swift` の `serverHost` を手順1で確認したIPアドレスに変更：

```swift
var serverHost: String = "192.168.150.90"  // ← MacのローカルIPに書き換え
```

> ⚠️ WatchとMacは **同じWiFiネットワーク** に接続されている必要があります。

### 3. サーバー起動

```bash
cd SensorMonitor && node server.js
```

ターミナルにダッシュボードURLと利用可能なネットワークIPが表示されます。

### 4. ダッシュボードを開く

ブラウザで http://localhost:8765 を開く。

### 5. データ受信開始

Watch実機でワークアウトを開始 → ダッシュボードにリアルタイムでセンサーデータが表示されます。

## ダッシュボード機能

- **リアルタイム波形チャート**: accX / accY / accZ + filteredAccY の時系列グラフ
- **閾値ライン表示**: descendThreshold(-0.3) / ascendThreshold(0.3) の水平線
- **RepDetector状態表示**: IDLE → DESCENDING → BOTTOM → ASCENDING → LOCKOUT のフェーズ可視化
- **Repカウンター**: 現在のrep数をリアルタイム表示
- **CSVエクスポート**: 受信データをCSVとしてダウンロード

## トラブルシューティング

- **Watchからデータが届かない場合**: WatchとMacが同じWiFiに接続されているか確認
- **IPアドレスが変わった場合**: `ifconfig en0` で再確認し、`SensorStreamer.swift` を更新
- **ポート競合**: `node server.js 8080` のように別ポートを指定可能
