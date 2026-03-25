# 20260311_BenchCoach_仕様書
MVP 完全仕様書（日本語版）

Version: 0.1
Author: Takashi Sugie
Platform: Apple Watch (watchOS)
iOS側のアプリは不要です。

---

# 1. プロダクト概要

## アプリ名
BenchCoach

## コンセプト
Apple Watch を使用してベンチプレスの回数を自動カウントするアプリ。

ユーザーはスマートフォンを触らずにトレーニング回数を記録できる。

## 提供価値

従来の筋トレログアプリ

セット終了
↓
スマホを取り出す
↓
回数入力

BenchCoach

rep成功
↓
Apple Watch振動
↓
自動カウント

スマホ操作なしでトレーニング記録可能。

---

# 2. 対象ユーザー

- Apple Watchユーザー
- ジム利用者
- 筋トレユーザー
- ベンチプレスを行うユーザー

---

# 3. MVPの目的

以下の機能を提供する最小アプリを開発する。

## MVP機能

- ベンチプレス回数の自動カウント
- rep成功時の振動通知
- セット終了検出
- セッション保存

## 精度目標

70〜80%

※誤検出よりも取りこぼしを優先する。

---

# 4. 対応プラットフォーム

## Apple Watch

OS

watchOS

## 使用技術

- Swift
- SwiftUI
- CoreMotion
- HealthKit
- WatchKit Haptics

---

# 5. ユースケース

## UC-01 トレーニング開始

1. ユーザーがアプリを起動
2. STARTボタンを押す
3. ワークアウトセッション開始

画面

Bench Press
START

---

## UC-02 rep検出

ユーザーがベンチプレスを行う。

システム処理

センサー取得
↓
動作判定
↓
rep検出

成功時

rep +1
↓
振動通知

---

## UC-03 セット終了

一定時間動作がない場合

10秒

↓

セット終了

↓

結果画面表示

---

# 6. 機能要件

## F-01 ワークアウト開始

START押下時

HKWorkoutSession開始

---

## F-02 モーション取得

CoreMotionを使用。

取得データ

- userAcceleration
- rotationRate
- gravity
- attitude

更新頻度

50Hz

---

## F-03 rep検出

ベンチプレス動作

下降
↓
最下点
↓
上昇
↓
ロックアウト

を検出しrepを確定する。

---

## F-04 振動通知

rep成功時

WKInterfaceDevice.play(.click)

---

## F-05 セット終了検出

条件

10秒間モーションなし

---

## F-06 手動補正

ユーザー操作

+1
-1

---

## F-07 セッション保存

保存データ

date
repCount
duration
exerciseType

---

# 7. 画面仕様

## 画面1 ホーム

Bench Press

START

---

## 画面2 トレーニング画面

Rep: X

STOP
+1
-1

---

## 画面3 結果画面

Bench Press

10 reps

SAVE

---

# 8. データモデル

## WorkoutSession

id: UUID
date: Date
exerciseType: String
repCount: Int
duration: Double

---

# 9. モーション処理仕様

## 使用センサー

userAcceleration
rotationRate
gravity

---

## rep検出アルゴリズム

状態マシン

IDLE
↓
DESCENDING
↓
BOTTOM
↓
ASCENDING
↓
LOCKOUT
↓
COUNTED

---

## 判定条件

DESCENDING

accY < -threshold

BOTTOM

速度低下

ASCENDING

accY > threshold

LOCKOUT

安定状態

COUNTED

rep++

---

## クールダウン

二重カウント防止

800ms

---

# 10. セット終了判定

条件

motionMagnitude < smallThreshold

時間

10秒

---

# 11. ハプティクス

rep成功

click

目標回数到達

success

---

# 12. センサーログ

ログ内容

timestamp
accX
accY
accZ
rotX
rotY
rotZ

保存形式

CSV

---

# 13. 開発フェーズ

## Phase1

Watchアプリ骨格作成

## Phase2

センサー取得

## Phase3

rep検出

## Phase4

振動通知

## Phase5

セッション保存

---

# 14. 成功基準

rep検出率

70%以上

---

# 15. 将来機能

- rep速度（バー速度）
- AIフォーム分析
- PR検出
- トレーニング提案

---

# 16. Antigravity用プロンプト

この仕様書をもとにApple Watchアプリを開発してください。

技術

watchOS
SwiftUI
CoreMotion
HealthKit

MVPを実装してください。
