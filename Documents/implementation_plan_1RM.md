# 1RM計算 & クラウドダッシュボード同期 機能実装計画

## 1. 推定MAX(1RM)の計算
- Epleyの公式（`重量 × (1 + 0.0333 × 回数)`）を使用します。
- **データモデル**: 現在 `WorkoutSession` には `weight` がOptional型 (`Int?`) で保持されています。`weight` と `repCount` が両方揃っている場合のみ 1RM を算出してIntで返す Computed Property `estimated1RM` を追加します。
- **UI表示**:
  - `ResultView`: 「完了したレップ数」の下に、計算した1RMを強調表示します。
  - `HistoryView`: 一覧上の各要素に「★ 1RM: 〇〇kg」のように付加価値として表示します。

## 2. クラウドダッシュボードへの記録送信
WebSocketを利用して、完了したワークアウトデータをJSONとして配信します。

- **WatchOS (Client) 側**:
  - `SensorStreamer` クラスに、以下のフォーマットのJSONを送信するメソッドを追加します。
    ```json
    {
      "type": "session_result",
      "date": "2026-03-25T10:00:00Z",
      "weight": 80,
      "reps": 10,
      "estimated1RM": 106,
      "averageVelocity": 0.45,
      "duration": 55.0
    }
    ```
  - この送信は `WorkoutManager.saveAndReturn()` 内で実行します。

- **Node.js Server & Dashboard 側**:
  - 現在のダッシュボードは「リアルタイムなセンサーのグラフ（`type: telemetry`）」表示に特化しています。
  - 新たに `session_result` タイプのメッセージを受信処理し、フロントエンド側（[index.html](file:///Users/sugietakashi/Desktop/gemini/antigravity/playground/silver-sagan/RepCountR1/SensorMonitor/index.html) / `app.js`）でグラフの下部などに「**本日のセッション履歴一覧（テーブル形式）**」として動的に追記・表示するように改修します。

## 確認事項（User Review Required）
> [!NOTE]
> クラウドサイド（サーバー）では現在、DB（データベース）を持たせずにWebSocketでのリアルタイム中継を行っています。そのため、ブラウザをリロードすると表示されていた履歴テーブルは消えてしまいます。（プロトタイプとしてはこれで十分かと思われます）
> もし「永続的にサーバー側にも履歴を残したい」場合はSQLiteやFirebaseを入れる必要がありますが、今回はまずは「ブラウザを開いている間に飛んできた終了結果をダッシュボードに表示する」形で進めてよろしいでしょうか？
