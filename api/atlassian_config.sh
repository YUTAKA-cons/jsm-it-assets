#!/usr/bin/env bash
set -euo pipefail

# ==================================================
# Import Config
# ==================================================
SCRIPT_DIR="$(cd $(dirname $0); pwd)"
# `.env` ファイルが存在する場合のみ読み込む
if [ -f $SCRIPT_DIR/.env ]; then
  # 内部の変数を一括で環境変数としてエクスポート（有効化）する
  set -o allexport
  source $SCRIPT_DIR/.env
  set +o allexport
fi

# ==================================================
# Helpers
# ==================================================
require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: required command not found: $1" >&2
    exit 1
  }
}

require_cmd curl
require_cmd jq

auth="${ATLASSIAN_EMAIL}:${ATLASSIAN_API_TOKEN}"

call_site_api() {
  local path="$1"
  curl -sS --fail \
    --user "$auth" \
    --header "Accept: application/json" \
    "${ATLASSIAN_SITE}${path}"
}

call_assets_api() {
  local path="$1"
  curl -sS --fail \
    --user "$auth" \
    --header "Accept: application/json" \
    "https://api.atlassian.com/ex/jira/${CLOUD_ID}/jsm/assets/workspace/${WORKSPACE_ID}/v1${path}"
}

# ==================================================
# Step1: Get cloudId
# ==================================================
echo "--------------------------------------------------------"
echo "Getting cloudId..."
CLOUD_ID="$(curl -sS --fail "${ATLASSIAN_SITE}/_edge/tenant_info" | jq -r '.cloudId')"

if [ -z "${CLOUD_ID}" ] || [ "${CLOUD_ID}" = "null" ]; then
  echo "ERROR: cloudId could not be retrieved." >&2
  exit 1
fi

echo " cloudId: ${CLOUD_ID}"
echo

# ==================================================
# Step2: Get workspaceId
# ==================================================
echo "--------------------------------------------------------"
echo "Getting workspaceId..."
workspace_json="$(call_site_api "/rest/servicedeskapi/assets/workspace")"
# echo "${workspace_json}" > "${base_dir}/workspace.json"

WORKSPACE_ID="$(
  echo "${workspace_json}" | jq -r '
    if type == "array" then
      .[0].workspaceId
    elif (.values? | type) == "array" then
      .values[0].workspaceId
    else
      .workspaceId
    end
  '
)"

if [ -z "${WORKSPACE_ID}" ] || [ "${WORKSPACE_ID}" = "null" ]; then
  echo "ERROR: workspaceId could not be retrieved." >&2
  echo "Response saved to ${base_dir}/workspace.json" >&2
  exit 1
fi

echo " workspaceId: ${WORKSPACE_ID}"
echo
