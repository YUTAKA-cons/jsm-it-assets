#!/bin/sh
# ==================================================
# Atlasian Config
# ==================================================
SCRIPT_DIR="$(cd $(dirname $0); pwd)"
source $SCRIPT_DIR/atlassian_config.sh

echo "複数スキーマのJira Assets同期を開始します..."

# ==========================================
# スキーマごとの振り分けロジック
# ==========================================
for json_file in "$MASKED_JSON_DIR"/*.json; do
  [ -e "$json_file" ] || continue

  # 1. JSONから schemaKey を抽出 (例: "IT", "HR" など)
  # ※Step 1でフィルタ済みのクリーンなJSONを想定
  schema_key=$(jq -r '.objectSchemaKey // empty' "$json_file")

  if [ -z "$schema_key" ]; then
    echo "スキップ: objectSchemaKey が見つかりません ($json_file)"
    continue
  fi

  # 2. schemaKey に応じて、同期先の IMPORT_ID を動的に切り替え
  case "$schema_key" in
    "IT")
      IMPORT_ID="xxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
      ;;
    "HR")
      IMPORT_ID="yyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy"
      ;;
    "FAC")
      IMPORT_ID="zzzzzzz-zzzz-zzzz-zzzz-zzzzzzzzzzzz"
      ;;
    *)
      echo "警告: スキーマ '${schema_key}' に対応する IMPORT_ID が定義されていないためスキップします。($json_file)"
      continue
      ;;
  esac

  # 3. 対象のインポートAPIへPOST送信
  URL="${NEXT_JIRA_URL}/rest/assets/1.0/import/${IMPORT_ID}/data"
  echo "同期中: スキーマ [${schema_key}] -> 同期先 IMPORT_ID [${IMPORT_ID}]"

  response=$(curl --silent --output /dev/null --write-out "%{http_code}" \
    -X POST \
    -H "Authorization: Bearer ${ASSETS_IMPORT_TOKEN}" \
    -H "Content-Type: application/json" \
    -d @"$json_file" \
    "$URL")

  # 4. 結果の判定
  if [ "$response" = "200" ] || [ "$response" = "202" ]; then
    echo "  => 成功 (HTTP $response)"
  else
    echo "  => エラー: 送信に失敗しました (HTTP $response)"
  fi

done

echo "すべてのスキーマの同期処理が終了しました。"
