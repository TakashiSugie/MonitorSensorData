# Premium Subscription（Standardプラン）実装計画

ユーザーからの要望に基づき、VBT（挙上速度ベーストレーニング）を活用したStandardプラン（月額500円）向けの機能群を実装・統合します。

## 実装内容の概要

### 1. サブスクリプション管理 (StoreKit 2)
#### [NEW] `SubscriptionManager.swift`
- StoreKit 2 を使用して購入処理と「Standard Plan」のステータス検証（Premium判定）を実装します。
- `@Published var isPremium: Bool` を提供し、アプリ全体で無料/有料の表示切り替えを行います。

### 2. パーソナライズされた「今日のアドバイス」 (オートレギュレーション)
#### [NEW] `VBTAdvisor.swift`
- 当日の「第1Rep目の速度」と、過去の同重量での平均速度を比較・分析するユーティリティクラスを作成します。
- 状態を「絶好調」「通常」「疲労気味」と判定します。
- 次のセットに向けた具体的なアクション（「+2.5kg増やす」「現状維持」「重量・回数を減らす」）を提案します。
#### [MODIFY] [ResultView.swift](file:///Users/sugietakashi/Desktop/gemini/antigravity/playground/silver-sagan/BenchSenseR1/BenchCoach/BenchCoach%20Watch%20App/Views/ResultView.swift)
- `isPremium` が true の場合、セット終了後の画面上部に VBT Advisor からのフィードバックメッセージを表示します。

### 3. VBT目標ゾーンのカスタマイズ機能
#### [NEW] `VBTZone.swift` (Model)
- 目的に応じた速度ゾーンを定義します。例: 
  - 最大筋力 (Max Strength): 0.15 - 0.35 m/s
  - 筋肥大 (Hypertrophy): 0.35 - 0.50 m/s
  - パワー向上 (Power): 0.75 - 1.0 m/s
#### [MODIFY] `SettingsView.swift`
- Premiumユーザー専用の設定として、ターゲットとするVBTゾーンを選択できる機能を追加します。
#### [MODIFY] [WorkoutView.swift](file:///Users/sugietakashi/Desktop/gemini/antigravity/playground/silver-sagan/BenchSenseR1/BenchCoach/BenchCoach%20Watch%20App/Views/WorkoutView.swift)
- トレーニング画面に選択中のターゲットゾーン（例: 0.35 - 0.50）を表示し、計測された速度がゾーンに収まっているかを視覚的に分かりやすくします。

### 4. 履歴制限と高度なグラフ分析
#### [MODIFY] [SessionStore.swift](file:///Users/sugietakashi/Desktop/gemini/antigravity/playground/silver-sagan/BenchSenseR1/BenchCoach/BenchCoach%20Watch%20App/Managers/SessionStore.swift) & [HistoryView.swift](file:///Users/sugietakashi/Desktop/gemini/antigravity/playground/silver-sagan/BenchSenseR1/BenchCoach/BenchCoach%20Watch%20App/Views/HistoryView.swift)
- **無料ユーザー**: 履歴の閲覧を直近の数件（例: 3件）に制限し、リスト下部に「Premiumに登録してすべての履歴をアンロック」等の案内を表示します。
- **Premiumユーザー**: 無制限にすべての履歴を閲覧可能にします。
#### [MODIFY] [ResultView.swift](file:///Users/sugietakashi/Desktop/gemini/antigravity/playground/silver-sagan/BenchSenseR1/BenchCoach/BenchCoach%20Watch%20App/Views/ResultView.swift)
- Premiumユーザー向けに、本日の速度推移グラフ（Lifting Velocity）へ「過去のベスト記録（または平均）」を比較用ラインとして重ね合わせて表示します。

### 5. CSVデータ書き出し・外部連携
#### [NEW] `DataExportManager.swift`
- 1Repごとの速度データとタイムスタンプから成るCSVテキストを生成するロジックを実装します。
#### [MODIFY] [HistoryView.swift](file:///Users/sugietakashi/Desktop/gemini/antigravity/playground/silver-sagan/BenchSenseR1/BenchCoach/BenchCoach%20Watch%20App/Views/HistoryView.swift) / [ResultView.swift](file:///Users/sugietakashi/Desktop/gemini/antigravity/playground/silver-sagan/BenchSenseR1/BenchCoach/BenchCoach%20Watch%20App/Views/ResultView.swift)
- iOS・WatchOS間の `WatchConnectivity` またはWatchOS単体での共有機能（ShareSheet等）を利用し、CSVデータをエクスポートできるボタンを追加します。（※WatchOS単体での柔軟なファイル保存には制限があるため、テキストデータ共有やiOS転送のための実装を主とします）

---

## お客様へのご確認事項
> [!IMPORTANT]
> Apple Watch単体アプリでの「CSVエクスポート」および「クラウドダッシュボード連携」については以下のような仕様上の制約があります。
> 1. **CSV共有機能**: Watch上にFilesアプリがないため、生成したCSVをメール等で共有(Share)するか、将来的にiOSペアアプリを作成してそちらへ転送(`WCSession`)するのが一般的です。とりあえず生成したCSV情報をShareSheetでテキストやファイル送付として共有する一時的な実装としますか？
> 2. **StoreKit設定**: アプリ側の購入ロジックと購入画面は今回構築しますが、実際に決済をテストしたり本番公開するためには、後日お客様の「App Store Connect」アカウントでサブスクリプション商品の登録作業が必要です。

## 検証計画
1. XcodeのローカルStoreKit設定ファイル（StoreKit Configuration）を作成し、サブスクリプションのテスト購入を実施します。
2. サブスクリプション未加入（無料）状態では、履歴が3件しか表示されず、制限案内が出ていることを確認します。
3. 課金（Premium）状態にした後は、すべての履歴が閲覧でき、結果画面に個別アドバイス、設定画面にゾーン選択などが表示されることを確認します。
