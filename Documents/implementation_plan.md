# RepCount 大規模アップデート 実装計画

## 概要

提案された「インターバルタイマー」「目標回数・通知」「音声カウント」「挙上速度（VBT）」「複数セット記録」の**全5機能**をアプリに統合する。
アプリの根本的なデータ構造（1ワークアウト = 1セット → 1ワークアウト = 複数セット）が変わるため、アーキテクチャを刷新しつつ、段階的に開発を進める。

## フェーズと機能の分割

### Phase 1: 目標回数と音声カウント (Target & Voice)
一番手軽にユーザー体験を向上できるフィードバック機能から実装する。
- **UI**: `WeightSelectionView` に「目標回数（例: 8回、10回）」のピッカーを追加する。
- **ロジック**: `AVFoundation` を用い、`AVSpeechSynthesizer` でレップ数を英語（または日本語）で読み上げる。
- **通知**: 目標回数に達した際、強いハプティクスと特別な音声（"Goal!" や "Perfect!"）を鳴らす。

### Phase 2: 挙上速度（VBT）の計測
既存のアルゴリズムをチューニングし、速度データをUIと記録に活かす。
- **ロジック**: `RepDetector` において、ステートが `ascending` の間に発生した最大速度（Peak Velocity）と平均速度（Mean Velocity）を算出する。
- **UI**: `WorkoutView` に「リアルタイム速度」や「前回のレップの速度」を表示し、速度を意識したトレーニングを可能にする。

### Phase 3: 複数セット対応とインターバルタイマー (Sets & Rest)
アプリのデータ構造を大きく変える中核アップデート。
- **データモデル**:
  ```swift
  struct WorkoutSet: Codable, Identifiable {
      var id: UUID = UUID()
      var weight: Int
      var targetReps: Int
      var actualReps: Int
      var avgVelocity: Double // Phase 2 で追加される要素
      var duration: TimeInterval
  }
  
  struct WorkoutSession: Codable, Identifiable {
      var id: UUID = UUID()
      var date: Date
      var sets: [WorkoutSet] // 複数セットを保持
  }
  ```
  ※※ 構造が変わるため、古い UserDefaults の保存データと競合した場合は、クラッシュを防ぐために古いデータをリセットするフェールセーフを入れる。
- **ワークアウトフロー**:
  - `HomeView` → `WeightSelectionView`（重量・回数設定） → `WorkoutView`（1セット目）
  - 1セット目を「完了 (Finish Set)」すると、**`RestView`（インターバルタイマー画面 60s~120sなど）** に遷移。
  - タイマーがゼロになる（またはスキップする）と再び `WorkoutView`（2セット目）へ。
  - すべてのセットを終えて「ワークアウト終了 (End Workout)」を押すと、`ResultView` へ。
- **UI更新**: `ResultView` や `HistoryView` に、何セット行ったか、総ボリューム（重量×回数）がいくつかを詳細表示するように変更する。


## User Review Required

> [!CAUTION]
> **過去の履歴データの扱いについて**
> `WorkoutSession` のデータ構造が「単一の記録」から「複数のセットの配列」に変わるため、アップデート前に保存された過去の履歴データはそのままでは読み込めなくなります。
> 今回は個人開発のプロトタイプ段階と推測し、**「古い形式のデータは読み込み時に破棄（リセット）する」** アプローチを採用します。もし過去の記録を絶対に引き継ぎたい場合は、マイグレーション処理が必要になります。

以上のフェーズに分けて、少しずつ確実に実装していきます。よろしいでしょうか？
