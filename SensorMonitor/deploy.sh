#!/bin/bash
# ──────────────────────────────────────────────
# RepCount Sensor Monitor - Cloud Run デプロイスクリプト
# ──────────────────────────────────────────────
set -euo pipefail

# ─── 設定 ─────────────────────────────────────
SERVICE_NAME="repcount-monitor"
REGION="asia-northeast1"
MEMORY="256Mi"
MIN_INSTANCES=0
MAX_INSTANCES=2
PORT=8080

# ─── 色付き出力 ───────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# ─── gcloud CLI チェック ──────────────────────
if ! command -v gcloud &> /dev/null; then
  error "gcloud CLI がインストールされていません。\n  brew install --cask google-cloud-sdk"
fi

# ─── プロジェクト確認 ─────────────────────────
PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
if [ -z "$PROJECT_ID" ] || [ "$PROJECT_ID" = "(unset)" ]; then
  error "GCPプロジェクトが設定されていません。\n  gcloud config set project YOUR_PROJECT_ID"
fi

info "Project: $PROJECT_ID"
info "Service: $SERVICE_NAME"
info "Region:  $REGION"
echo ""

# ─── コマンド引数で動作を分岐 ─────────────────
case "${1:-deploy}" in
  setup)
    info "必要な API を有効化中..."
    gcloud services enable run.googleapis.com
    gcloud services enable cloudbuild.googleapis.com
    gcloud services enable artifactregistry.googleapis.com
    info "✅ API の有効化が完了しました"
    ;;

  deploy)
    info "Cloud Run にデプロイ中..."
    gcloud run deploy "$SERVICE_NAME" \
      --source . \
      --region "$REGION" \
      --allow-unauthenticated \
      --port "$PORT" \
      --memory "$MEMORY" \
      --min-instances "$MIN_INSTANCES" \
      --max-instances "$MAX_INSTANCES" \
      --set-env-vars="NODE_ENV=production"

    echo ""
    info "✅ デプロイ完了！"
    echo ""

    # サービス URL を取得して表示
    SERVICE_URL=$(gcloud run services describe "$SERVICE_NAME" \
      --region "$REGION" \
      --format='value(status.url)' 2>/dev/null)

    if [ -n "$SERVICE_URL" ]; then
      info "Dashboard URL: $SERVICE_URL"
      info "Status API:    $SERVICE_URL/api/status"
      echo ""
      info "Watch アプリの SensorStreamer.swift を更新してください:"
      echo "  var serverURL: String = \"$SERVICE_URL\""
    fi
    ;;

  status)
    info "サービスの状態を確認中..."
    gcloud run services describe "$SERVICE_NAME" \
      --region "$REGION" \
      --format='table(status.url, status.conditions[0].status, spec.template.spec.containers[0].resources.limits.memory)'
    ;;

  logs)
    info "最新ログを表示中..."
    gcloud run services logs read "$SERVICE_NAME" \
      --region "$REGION" \
      --limit=50
    ;;

  delete)
    warn "サービス '$SERVICE_NAME' を削除します。"
    read -p "続行しますか？ (y/N): " confirm
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
      gcloud run services delete "$SERVICE_NAME" --region "$REGION"
      info "✅ サービスを削除しました"
    else
      info "キャンセルしました"
    fi
    ;;

  *)
    echo "使い方: ./deploy.sh [command]"
    echo ""
    echo "Commands:"
    echo "  setup   - GCP API を有効化（初回のみ）"
    echo "  deploy  - Cloud Run にデプロイ（デフォルト）"
    echo "  status  - サービスの状態を確認"
    echo "  logs    - 最新ログを表示"
    echo "  delete  - サービスを削除"
    ;;
esac
