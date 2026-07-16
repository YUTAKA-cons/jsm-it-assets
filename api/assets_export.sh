#!/usr/bin/env bash
set -euo pipefail

# ==================================================
# Atlasian Config
# ==================================================
source atlasian_config.sh
OUTPUT_DIR="${OUTPUT_DIR:-../assets}"

# ==================================================
# Helpers
# ==================================================
safe_name() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9._-]/-/g'
}

# ==================================================
# Prepare output
# ==================================================
timestamp="$(date +%Y%m%d-%H%M%S)"
#base_dir="${OUTPUT_DIR}/${timestamp}"
base_dir="${OUTPUT_DIR}/json"
mkdir -p "${base_dir}"

echo "Output directory: ${base_dir}"

# ==================================================
# Step 1: Get schema list
# ==================================================
echo "---------------------------------------------"
echo "Getting object schema list..."
schemas_json="$(call_assets_api "/objectschema/list")"
echo "${schemas_json}" > "${base_dir}/objectschema-list.json"

# Support both array and paged response shapes
schema_count="$(echo "${schemas_json}" | jq 'if type=="array" then length else (.values // []) | length end')"
echo "Found ${schema_count} schemas"
echo

# ==================================================
# Step 2: Export details per schema
# ==================================================
echo "${schemas_json}" | jq -c '
  if type=="array" then .[]
  else (.values // [])[]
  end
' | while IFS= read -r schema; do
  schema_id="$(echo "${schema}" | jq -r '.id')"
  schema_name="$(echo "${schema}" | jq -r '.name')"
  schema_dir="${base_dir}/schemas/$(safe_name "${schema_name}")"
  mkdir -p "${schema_dir}/objecttypes"

  echo "Exporting schema: ${schema_name} (id=${schema_id})"

  echo "${schema}" > "${schema_dir}/schema.json"

  objecttypes_json="$(call_assets_api "/objectschema/${schema_id}/objecttypes")"
  echo "${objecttypes_json}" > "${schema_dir}/objecttypes.json"

  # Support either array or object with values
  echo "${objecttypes_json}" | jq -c '
    if type=="array" then .[]
    elif (.objectTypes? != null) then .objectTypes[]
    else (.values // [])[]
    end
  ' | while IFS= read -r ot; do
    ot_id="$(echo "${ot}" | jq -r '.id')"
    ot_name="$(echo "${ot}" | jq -r '.name')"
    ot_file_base="${schema_dir}/objecttypes/$(safe_name "${ot_name}")"

    echo "  - object type: ${ot_name} (id=${ot_id})"

    echo "${ot}" > "${ot_file_base}.json"

    attrs_json="$(call_assets_api "/objecttype/${ot_id}/attributes")"
    echo "${attrs_json}" > "${ot_file_base}-attributes.json"
  done
done

# Remove Defolt Assets
rm -rf "${base_dir}/schemas/services"

# ==================================================
# Step 3: Save metadata
# ==================================================
cat > "${base_dir}/metadata.json" <<EOF
{
  "site": "${ATLASSIAN_SITE}",
  "cloudId": "${CLOUD_ID}",
  "workspaceId": "${WORKSPACE_ID}",
  "exportedAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

# ==================================================
# Step 4: Mask Data
# ==================================================
JSON_DIR="$OUTPUT_DIR/json"
MASKED_DIR="../assets/json_masked"

# 1. フォルダのクリーンアップと複製（ディレクトリ構造ごと一瞬でコピー）
rm -rf "$MASKED_DIR"
cp -r "$JSON_DIR" "$MASKED_DIR"

# サブフォルダ配下のすべてのJSONファイルを走査
find "$OUTPUT_DIR" -type f -name "*.json" | while read -r json_file; do
  
  echo "処理中: $json_file"
  
  # 一時ファイルに出力してから上書き
  tmp_file=$(mktemp)
  jq '
    ( .. | objects | select(has("workspaceId")) ) .workspaceId = "********" |
    ( .. | objects | select(has("globalId")) )    .globalId    = "********" |
    ( .. | objects | select(has("email")) )       .email       = "********" |
    ( .. | objects | select(has("siteName")) )    .siteName    = "********" |
    ( .. | objects | select(has("apiKey")) )      .apiKey      = "********"
  ' "$json_file" > "$tmp_file" && mv "$tmp_file" "$json_file"

done

# ==================================================
# Final
# ==================================================
echo "Done."
echo "Saved under: ${base_dir}"
echo
