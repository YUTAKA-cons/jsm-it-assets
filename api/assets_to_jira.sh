#!/bin/bash

# ==================================================
# Assetsの属性をJSMリクエストタイプに登録
#
# 1. Assets属性取得
# 2. フィールド生成
# 3. コンテキスト設定
# 4. Request Type / Screenに追加
# 5. フォームに表示
# ==================================================

# ==================================================
# Atlasian Config
# ==================================================
SCRIPT_DIR="$(cd $(dirname $0); pwd)"
source $SCRIPT_DIR/atlassian_config.sh

# ==================================================
# 設定（環境変数）
# ==================================================
OBJECT_SCHEMA_ID="2"
OBJECT_TYPE_ID="33"

PROJECT_ID="100"
ISSUE_TYPE_ID="1908"

DRY_RUN=true
LOG_FILE="field_sync.log"

# ==================================================
# ログ関数
# ==================================================
log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$LOG_FILE"
}
log "============ START ==========="

# ==================================================
# Assets属性取得（workspace API）
# ==================================================
log "Fetching Assets attributes..."

ATTRIBUTES="$(call_assets_api "/objecttype/$OBJECT_TYPE_ID/attributes")"

if [[ -z "$ATTRIBUTES" ]]; then
  log "ERROR: 属性取得失敗"
  exit 1
fi

# echo $ATTRIBUTES | jq

# ==================================================
# Jiraフィールド取得
# ==================================================
log "Fetching Jira fields..."

FIELDS=$(curl -s -u "$ATLASSIAN_EMAIL:$ATLASSIAN_API_TOKEN" \
"$ATLASSIAN_SITE/rest/api/3/field")

# ==================================================
# メイン処理
# ==================================================
echo "$ATTRIBUTES" | jq -c '
  if type=="array" then .[]
  else .values[]
  end
  ' | while read attr; do

  NAME=$(echo "$attr" | jq -r '.name')
  TYPE=$(echo "$attr" | jq -r '
    if .defaultType != null then .defaultType.name
    elif .referenceType != null then "Object"
    elif .type != null then .type
    else "Text"
    end
  ')
  FIELD_NAME="SYS_$NAME"

  # ==================================================
  # スキップ：固定フィールド＋既存チェック
  # ==================================================
  if [[ "$NAME" == "Key" || "$NAME" == "Created" || "$NAME" == "Updated" ]]; then
    continue
  fi

  if echo "$FIELDS" | jq -e ".[] | select(.name==\"$FIELD_NAME\")" > /dev/null; then
    log "Skip existing: $FIELD_NAME"
    continue
  fi

  # ==================================================
  # 型マッピング
  # ==================================================
  case "$TYPE" in
    Text)
      JIRA_TYPE="com.atlassian.jira.plugin.system.customfieldtypes:textfield"
      SEARCHER="com.atlassian.jira.plugin.system.customfieldtypes:textsearcher"
      ;;
    Integer|Float)
      JIRA_TYPE="com.atlassian.jira.plugin.system.customfieldtypes:float"
      SEARCHER="com.atlassian.jira.plugin.system.customfieldtypes:numbersearcher"
      ;;
    Boolean)
      JIRA_TYPE="com.atlassian.jira.plugin.system.customfieldtypes:multicheckboxes"
      SEARCHER="com.atlassian.jira.plugin.system.customfieldtypes:multiselectsearcher"
      ;;
    Date)
      JIRA_TYPE="com.atlassian.jira.plugin.system.customfieldtypes:datepicker"
      SEARCHER="com.atlassian.jira.plugin.system.customfieldtypes:daterange"
      ;;
    DateTime)
      JIRA_TYPE="com.atlassian.jira.plugin.system.customfieldtypes:datetime"
      SEARCHER="com.atlassian.jira.plugin.system.customfieldtypes:daterange"
      ;;
    User)
      JIRA_TYPE="com.atlassian.jira.plugin.system.customfieldtypes:userpicker"
      SEARCHER="com.atlassian.jira.plugin.system.customfieldtypes:userpickergroupsearcher"
      ;;
    Object)
      JIRA_TYPE="com.atlassian.jira.plugins.cmdb:cmdb-object-cftype"
      SEARCHER="com.atlassian.jira.plugins.cmdb:cmdb-object-searcher"
      ;;
    *)
      JIRA_TYPE="com.atlassian.jira.plugin.system.customfieldtypes:textfield"
      SEARCHER="com.atlassian.jira.plugin.system.customfieldtypes:textsearcher"
      ;;
  esac

  log "Create field: $FIELD_NAME ($TYPE)"

  if [ "$DRY_RUN" = true ]; then
    log "[DRY RUN] Skip create $FIELD_NAME"
    continue
  fi

  # ==================================================
  # フィールド作成
  # ==================================================
  RESPONSE=$(curl -s -w "%{http_code}" -o /tmp/field.json \
    -u "$ATLASSIAN_EMAIL:$ATLASSIAN_API_TOKEN" \
    -X POST "$ATLASSIAN_SITE/rest/api/3/field" \
    -H "Content-Type: application/json" \
    -d "{
      \"name\": \"$FIELD_NAME\",
      \"type\": \"$JIRA_TYPE\",
      \"searcherKey\": \"$SEARCHER\",
      \"description\": \"Auto-created from Assets: $NAME\"
    }")

  if [[ "$RESPONSE" != "201" ]]; then
    log "ERROR creating field: $FIELD_NAME"
    cat /tmp/field.json >> "$LOG_FILE"
    continue
  fi

  FIELD_ID=$(cat /tmp/field.json | jq -r '.id')

  log "Field created: $FIELD_NAME ($FIELD_ID)"

  # ==================================================
  # コンテキスト作成
  # ==================================================
  CONTEXT=$(curl -s -u "$ATLASSIAN_EMAIL:$ATLASSIAN_API_TOKEN" \
    -X POST "$ATLASSIAN_SITE/rest/api/3/field/$FIELD_ID/context" \
    -H "Content-Type: application/json" \
    -d "{
      \"name\": \"AST Context\",
      \"projectIds\": [\"$PROJECT_ID\"],
      \"issueTypeIds\": [\"$ISSUE_TYPE_ID\"]
    }")

  CONTEXT_ID=$(echo "$CONTEXT" | jq -r '.id')

  log "Context created: $CONTEXT_ID"

  # ==================================================
  # Screen追加
  # ==================================================
  curl -s -u "$ATLASSIAN_EMAIL:$ATLASSIAN_API_TOKEN" \
    -X POST "$ATLASSIAN_SITE/rest/api/3/screens/$SCREEN_ID/tabs/$TAB_ID/fields" \
    -H "Content-Type: application/json" \
    -d "{\"fieldId\":\"$FIELD_ID\"}" > /dev/null

  # ==================================================
  # Request Type追加
  # ==================================================
  curl -s -u "$ATLASSIAN_EMAIL:$ATLASSIAN_API_TOKEN" \
    -X PUT "$ATLASSIAN_SITE/rest/servicedeskapi/servicedesk/$SERVICEDESK_ID/requesttype/$REQUEST_TYPE_ID/field" \
    -H "Content-Type: application/json" \
    -d "{
      \"fieldId\": \"$FIELD_ID\",
      \"required\": false
    }" > /dev/null

  log "Added to RequestType: $FIELD_NAME"

  sleep 0.2

done

log "============ DONE ============"
echo "" | tee -a "$LOG_FILE"