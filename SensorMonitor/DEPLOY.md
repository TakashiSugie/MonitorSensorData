# SensorMonitor を Cloud Run にデプロイする手順

## 前提条件

- Google アカウント
- クレジットカード（課金アカウント登録に必要。無料枠内なら請求は発生しません）

---

## 1. gcloud CLI のインストール

```bash
# Homebrew でインストール
brew install --cask google-cloud-sdk
```

インストール後、ターミナルを再起動するか以下を実行:
```bash
source "$(brew --prefix)/share/google-cloud-sdk/path.zsh.inc"
```

## 2. GCP プロジェクトのセットアップ

```bash
# Google アカウントでログイン
gcloud auth login

# 新しいプロジェクトを作成（プロジェクトIDは全世界でユニーク）
gcloud projects create repcount-monitor --name="RepCount Monitor"

# 作成したプロジェクトをデフォルトに設定
gcloud config set project repcount-monitor
```

> ⚠️ プロジェクトID `repcount-monitor` が既に使われている場合は別の名前にしてください。

## 3. 課金アカウントの紐付け

```bash
# 課金アカウント一覧を確認
gcloud billing accounts list

# 課金アカウントをプロジェクトに紐付け（BILLING_ACCOUNT_ID を置き換え）
gcloud billing projects link repcount-monitor --billing-account=BILLING_ACCOUNT_ID
```

課金アカウントがない場合は、[Google Cloud Console](https://console.cloud.google.com/billing) でクレジットカードを登録して作成してください。

## 4. 必要な API を有効化

```bash
gcloud services enable run.googleapis.com
gcloud services enable cloudbuild.googleapis.com
gcloud services enable artifactregistry.googleapis.com
```

## 5. Cloud Run にデプロイ

SensorMonitor ディレクトリで以下を実行:

```bash
cd SensorMonitor

# ソースコードから直接デプロイ（Docker不要）
gcloud run deploy repcount-monitor \
  --source . \
  --region asia-northeast1 \
  --allow-unauthenticated \
  --port 8080 \
  --memory 256Mi \
  --min-instances 0 \
  --max-instances 2
```

> `--region asia-northeast1` は東京リージョンです。

デプロイが完了すると、以下のような URL が表示されます:
```
Service URL: https://repcount-monitor-xxxxx-an.a.run.app
```

## 6. 動作確認

```bash
# ヘルスチェック
curl https://repcount-monitor-xxxxx-an.a.run.app/api/status

# ブラウザでダッシュボードを開く
open https://repcount-monitor-xxxxx-an.a.run.app
```

## 7. Watch アプリの送信先を更新

`SensorStreamer.swift` の `serverURL` を Cloud Run の URL に変更:

```swift
var serverURL: String = "https://repcount-monitor-xxxxx-an.a.run.app"
```

その後、Watch アプリを再ビルド・デプロイしてください。

---

## カスタムドメインの設定（任意）

Cloud Run にカスタムドメインをマッピングする場合:

```bash
gcloud run domain-mappings create \
  --service repcount-monitor \
  --domain your-domain.com \
  --region asia-northeast1
```

表示された DNS レコードを Cloudflare（または使用中の DNS）に設定してください。

---

## よく使うコマンド

```bash
# サービスの状態確認
gcloud run services describe repcount-monitor --region asia-northeast1

# ログの確認
gcloud run services logs read repcount-monitor --region asia-northeast1

# 再デプロイ（コード更新後）
cd SensorMonitor
gcloud run deploy repcount-monitor --source . --region asia-northeast1

# サービスの削除（不要になったら）
gcloud run services delete repcount-monitor --region asia-northeast1
```

---

## コストについて

| 項目 | 無料枠 |
|------|--------|
| Cloud Run リクエスト | 200万リクエスト/月 |
| Cloud Run CPU | 180,000 vCPU秒/月 |
| Cloud Run メモリ | 360,000 GiB秒/月 |
| Cloud Build | 120分/日 |
| Artifact Registry | 0.5 GB |

個人利用レベルではほぼ無料枠内に収まります。
