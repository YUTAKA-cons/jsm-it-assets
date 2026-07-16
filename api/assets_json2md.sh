#!/usr/bin/env bash
set -euo pipefail

# ==================================================
# Atlasian Config
# ==================================================
# source atlasian_config.sh
JSON_DIR="${JSON_DIR:-../assets/json}"
MD_DIR="../assets/difinition"

rm -rf "$MD_DIR"
mkdir -p "$MD_DIR"

echo "=== サブフォルダを含めた一括マスク ＆ スキーマ定義のMD変換を開始 ==="

# サブフォルダ配下のすべてのJSONファイルを走査
find "$JSON_DIR" -type f -name "*objecttypes.json" | while read -r json_file; do
  
  echo "処理中: $json_file"

  # ----------------------------------------------------
  # "objecttypes" を含むファイルのみMarkdown変換
  # ----------------------------------------------------
  base_name=$(basename "$json_file" .json)
  # 大文字小文字を区別せずに判定するために小文字化
  base_name_lower=$(echo "$base_name" | tr 'A-Z' 'a-z')

  if [ "${base_name_lower#*objecttypes}" != "$base_name_lower" ]; then
    relative_path="${json_file#$JSON_DIR/}"
    relative_dir=$(dirname "$relative_path")

    # 階層の区切り文字「/」を「_」に置換してファイル名を生成
    if [ "$relative_dir" = "." ]; then
      # ルート直下にファイルがあった場合
      new_md_name="${base_name}.md"
    else
      # サブフォルダ名とファイル名をアンダースコアで結合
      dir_prefix=$(echo "$relative_dir" | tr '/' '_')
      new_md_name="${dir_prefix}.md"
    fi
    
    target_md_file="$MD_DIR/$new_md_name"
    echo "  => [スキーマ定義] Markdown変換 ➔ $target_md_file"

    # 出力
    jq -r '
      "| ID | オブジェクトタイプ名 | キー | 説明 |",
      "| :--- | :--- | :--- | :--- |",
      (.objectTypes[] | "| \(.id) | \(.name) | \(.objectTypeKey) | \(.description) |")
    ' "$json_file" > "$target_md_file"

  fi

done