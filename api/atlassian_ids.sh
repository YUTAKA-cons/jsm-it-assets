#!/bin/sh
# ==================================================
# Atlasian Config
# ==================================================
SCRIPT_DIR="$(cd $(dirname $0); pwd)"
source $SCRIPT_DIR/atlassian_config.sh

# ==================================================
# ServiceDesk ID
# ==================================================
echo "========================================================"
echo "Get ServiceDesk List..."
SERVICE_DESKS=$(curl -s -X GET \
  "$ATLASSIAN_SITE/rest/servicedeskapi/servicedesk" \
  -u "$ATLASSIAN_EMAIL:$ATLASSIAN_API_TOKEN" \
  -H "Accept: application/json")

# ==================================================
# ServiceDeskごとに処理
# ==================================================
echo "$SERVICE_DESKS" | jq -c '.values[]' | while read sd; do

  SD_ID=$(echo "$sd" | jq -r '.id')
  SD_NAME=$(echo "$sd" | jq -r '.projectName')
  SD_KEY=$(echo "$sd" | jq -r '.projectKey')

  echo " ID: $SD_ID | $SD_NAME ($SD_KEY)"

  # ================================================
  # Request Type取得
  # ================================================
  RESPONSE=$(curl -s -X GET \
    "$ATLASSIAN_SITE/rest/servicedeskapi/servicedesk/$SD_ID/requesttype" \
    -u "$ATLASSIAN_EMAIL:$ATLASSIAN_API_TOKEN" \
    -H "Accept: application/json")

  # ================================================
  # 出力
  # ================================================
  CLEAN_RESPONSE=$(echo "$RESPONSE" | tr -d '\000-\031')
  echo "$CLEAN_RESPONSE" | jq -r '
    .values[] |
    "   RequestTypeID: \(.id) | Name: \(.name)"
  '
  echo "--------------------------------------------------------"

done
echo ""

# ==================================================
# Screen ID
# ==================================================
echo "========================================================"
echo "Get Screen ID..."
SCREEN_LIST=$(curl -s -X GET \
  "$ATLASSIAN_SITE/rest/api/3/screens" \
  -u "$ATLASSIAN_EMAIL:$ATLASSIAN_API_TOKEN" \
  -H "Content-Type: application/json")

echo "$SCREEN_LIST" | jq -r '
  .values[] |
  " ScreenID: \(.id) | Name: \(.name)"
'
echo "========================================================"
echo

# ==================================================
