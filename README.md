# BenchCoach

Apple Watchでベンチプレスの回数を自動カウントするwatchOSアプリ。

## 機能

- **自動rep検出**: CoreMotionセンサーを使ったベンチプレス動作の自動検出
- **ハプティクスフィードバック**: rep成功時にApple Watchが振動で通知
- **セット終了検出**: 10秒間動作がない場合に自動でセット終了
- **手動補正**: +1/-1ボタンでrep数を手動調整
- **HealthKit連携**: ワークアウトセッションをHealthKitに記録
- **センサーログ**: CSV形式でモーションデータを保存（精度改善用）

## 技術スタック

- **watchOS 10+**
- **SwiftUI**
- **CoreMotion** (50Hz, userAcceleration + rotationRate)
- **HealthKit** (HKWorkoutSession)
- **WatchKit Haptics**

## プロジェクトセットアップ

### Xcodeでのプロジェクト作成

1. Xcode を開く
2. **File > New > Project** を選択
3. **watchOS > App** を選択
4. 以下を設定:
   - Product Name: `BenchCoach`
   - Interface: `SwiftUI`
   - Language: `Swift`
5. プロジェクトを作成
6. デフォルトで生成されたファイルを削除
7. `BenchCoachWatch/` 配下のファイルをすべてプロジェクトに追加

### Capabilities設定

1. プロジェクト設定 > **Signing & Capabilities**
2. **+ Capability** から以下を追加:
   - **HealthKit**
3. **Background Modes** で以下を有効化:
   - **Workout processing**

## ファイル構成

```
BenchCoachWatch/
├── BenchCoachApp.swift          # アプリエントリポイント
├── Info.plist                   # 権限設定
├── Models/
│   └── WorkoutSession.swift     # データモデル
├── Managers/
│   ├── MotionManager.swift      # CoreMotion + rep検出
│   ├── WorkoutManager.swift     # HealthKitセッション
│   └── HapticsManager.swift     # 振動フィードバック
├── Views/
│   ├── HomeView.swift           # ホーム (START)
│   ├── WorkoutView.swift        # トレーニング中
│   └── ResultView.swift         # 結果 (SAVE)
└── Utilities/
    └── SensorLogger.swift       # CSVログ
```

## rep検出アルゴリズム

状態マシンベースの検出：

```
IDLE → DESCENDING → BOTTOM → ASCENDING → LOCKOUT → COUNTED → IDLE
```

- **DESCENDING**: Y軸加速度 < -0.3 (バーの下降)
- **BOTTOM**: モーション停止 (最下点)
- **ASCENDING**: Y軸加速度 > 0.3 (バーの上昇)
- **LOCKOUT**: モーション安定 (ロックアウト)
- **COUNTED**: rep確定 + 800msクールダウン

## センサーモニタリングダッシュボード

Watch実機でのrep検出デバッグ用に、センサーデータをリアルタイムで可視化するダッシュボードを搭載。

### 使い方

1. `SensorStreamer.swift` の `serverHost` をMacのローカルIPアドレスに変更
   ```bash
   ifconfig en0 | grep "inet "  # MacのIPを確認
   ```
2. サーバー起動
   ```bash
   cd SensorMonitor && npm install && node server.js
   ```
3. ブラウザで http://localhost:8765 を開く
4. Watch実機でワークアウト開始 → ダッシュボードにリアルタイムでデータが流れます

詳細は [SensorMonitor/README.md](SensorMonitor/README.md) を参照。

## ライセンス

Private - All rights reserved.
