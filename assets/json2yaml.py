#!/usr/bin/env python3
import json
import re
import sys
from pathlib import Path
from typing import Any

try:
    import yaml
except ImportError:
    print("ERROR: PyYAML が必要です。 pip install pyyaml", file=sys.stderr)
    sys.exit(1)


DROP_KEYS = {
    "id",
    "globalId",
    "workspaceId",
    "created",
    "updated",
    "timestamp",
    "position",
    "objectCount",
    "abstractObjectType",
    "iconUrl",
    "system",
    "_links",
}

DROP_IF_NULL_KEYS = {
    "description",
    "defaultType",
    "minimumCardinality",
    "maximumCardinality",
    "suffix",
}

SORT_ARRAY_BY_KEY = {
    "attributes": "name",
    "objectTypes": "name",
    "values": "name",
}

FILE_NAME_MAP = {
    "schema.json": "schema.yaml",
    "objecttypes.json": "objecttypes.yaml",
}


def safe_name(name: str) -> str:
    name = name.strip().lower()
    name = re.sub(r"[^a-z0-9._-]+", "-", name)
    return name.strip("-") or "unnamed"


def is_scalar(value: Any) -> bool:
    return isinstance(value, (str, int, float, bool)) or value is None


def sort_list_if_possible(items: list[Any]) -> list[Any]:
    if not items:
        return items

    if all(is_scalar(x) for x in items):
        return sorted(items, key=lambda x: "" if x is None else str(x))

    if all(isinstance(x, dict) for x in items):
        for sort_key in ("name", "label"):
            if all(sort_key in x for x in items):
                return sorted(items, key=lambda x: str(x.get(sort_key, "")))
    return items


def normalize_reference_type(value: dict[str, Any]) -> dict[str, Any]:
    """
    参照属性っぽいものを見やすく寄せる。
    API の shape が揺れても極力崩さない。
    """
    out = dict(value)

    # 例:
    # "referenceObjectType": {"id": "...", "name": "Department"}
    # -> "referenceObjectType": "Department"
    ref = out.get("referenceObjectType")
    if isinstance(ref, dict):
        name = ref.get("name")
        if name:
            out["referenceObjectType"] = name

    # type 情報がネストしている場合の簡易整形
    attr_type = out.get("type")
    if isinstance(attr_type, dict):
        type_name = attr_type.get("name") or attr_type.get("label")
        if type_name:
            out["type"] = type_name

    # defaultType が dict の場合
    default_type = out.get("defaultType")
    if isinstance(default_type, dict):
        type_name = default_type.get("name") or default_type.get("label")
        if type_name:
            out["defaultType"] = type_name

    return out


def normalize_attribute(attr: dict[str, Any]) -> dict[str, Any]:
    keep_order = [
        "name",
        "label",
        "type",
        "description",
        "defaultType",
        "referenceObjectType",
        "unique",
        "required",
        "minimumCardinality",
        "maximumCardinality",
        "suffix",
        "options",
    ]

    attr = normalize_reference_type(attr)
    attr = normalize_obj(attr)

    normalized: dict[str, Any] = {}

    for key in keep_order:
        if key in attr:
            value = attr[key]
            if key in DROP_IF_NULL_KEYS and value in (None, "", [], {}):
                continue
            normalized[key] = value

    for key, value in attr.items():
        if key not in normalized:
            if key in DROP_IF_NULL_KEYS and value in (None, "", [], {}):
                continue
            normalized[key] = value

    return normalized


def normalize_schema(schema: dict[str, Any]) -> dict[str, Any]:
    keep_order = [
        "name",
        "description",
        "objectSchemaKey",
        "status",
    ]
    schema = normalize_obj(schema)
    normalized: dict[str, Any] = {}

    for key in keep_order:
        if key in schema:
            value = schema[key]
            if key in DROP_IF_NULL_KEYS and value in (None, "", [], {}):
                continue
            normalized[key] = value

    for key, value in schema.items():
        if key not in normalized:
            if key in DROP_IF_NULL_KEYS and value in (None, "", [], {}):
                continue
            normalized[key] = value

    return normalized


def normalize_object_type(obj: dict[str, Any]) -> dict[str, Any]:
    keep_order = [
        "name",
        "description",
        "icon",
        "iconName",
        "parentObjectType",
        "abstract",
    ]

    out = normalize_obj(obj)

    parent = out.get("parentObjectType")
    if isinstance(parent, dict):
        parent_name = parent.get("name")
        if parent_name:
            out["parentObjectType"] = parent_name

    normalized: dict[str, Any] = {}
    for key in keep_order:
        if key in out:
            value = out[key]
            if key in DROP_IF_NULL_KEYS and value in (None, "", [], {}):
                continue
            normalized[key] = value

    for key, value in out.items():
        if key not in normalized:
            if key in DROP_IF_NULL_KEYS and value in (None, "", [], {}):
                continue
            normalized[key] = value

    return normalized


def normalize_obj(data: Any) -> Any:
    if isinstance(data, dict):
        out: dict[str, Any] = {}

        for key, value in data.items():
            if key in DROP_KEYS:
                continue

            if key.endswith("Id") and key not in {"objectSchemaKey"}:
                continue

            norm_value = normalize_obj(value)

            if key in DROP_IF_NULL_KEYS and norm_value in (None, "", [], {}):
                continue

            out[key] = norm_value

        if "options" in out and isinstance(out["options"], list):
            out["options"] = sort_list_if_possible(out["options"])

        return out

    if isinstance(data, list):
        normalized = [normalize_obj(x) for x in data]
        return sort_list_if_possible(normalized)

    return data


def choose_transform(input_path: Path, data: Any) -> Any:
    name = input_path.name

    if name == "schema.json" and isinstance(data, dict):
        return normalize_schema(data)

    if name.endswith("-attributes.json"):
        if isinstance(data, list):
            return {"attributes": [normalize_attribute(x) for x in data if isinstance(x, dict)]}
        if isinstance(data, dict):
            if isinstance(data.get("values"), list):
                return {"attributes": [normalize_attribute(x) for x in data["values"] if isinstance(x, dict)]}
            if isinstance(data.get("attributes"), list):
                return {"attributes": [normalize_attribute(x) for x in data["attributes"] if isinstance(x, dict)]}

    if name.endswith(".json") and "objecttypes" in input_path.parts:
        if isinstance(data, dict):
            return normalize_object_type(data)

    if name == "objecttypes.json":
        if isinstance(data, list):
            return {"objectTypes": [normalize_object_type(x) for x in data if isinstance(x, dict)]}
        if isinstance(data, dict):
            if isinstance(data.get("objectTypes"), list):
                return {"objectTypes": [normalize_object_type(x) for x in data["objectTypes"] if isinstance(x, dict)]}
            if isinstance(data.get("values"), list):
                return {"objectTypes": [normalize_object_type(x) for x in data["values"] if isinstance(x, dict)]}

    if name == "objectschema-list.json":
        if isinstance(data, list):
            return {"schemas": [normalize_schema(x) for x in data if isinstance(x, dict)]}
        if isinstance(data, dict):
            if isinstance(data.get("values"), list):
                return {"schemas": [normalize_schema(x) for x in data["values"] if isinstance(x, dict)]}
            return normalize_obj(data)

    return normalize_obj(data)


def output_path_for(input_path: Path, root_in: Path, root_out: Path) -> Path:
    rel = input_path.relative_to(root_in)
    out_name = FILE_NAME_MAP.get(rel.name, rel.name.replace(".json", ".yaml"))
    return root_out / rel.parent / out_name


def write_yaml(path: Path, data: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as f:
        yaml.safe_dump(
            data,
            f,
            allow_unicode=True,
            sort_keys=False,
            default_flow_style=False,
        )


def process_file(input_path: Path, root_in: Path, root_out: Path) -> None:
    with input_path.open("r", encoding="utf-8") as f:
        raw = json.load(f)

    normalized = choose_transform(input_path, raw)
    out_path = output_path_for(input_path, root_in, root_out)
    write_yaml(out_path, normalized)
    print(f"[OK] {input_path} -> {out_path}")


def main() -> int:
    if len(sys.argv) != 3:
        print(
            "使い方: normalize_assets.py <input_dir> <output_dir>\n"
            "例: python normalize_assets.py assets-export/20260326-153000 normalized-assets",
            file=sys.stderr,
        )
        return 1

    root_in = Path(sys.argv[1]).resolve()
    root_out = Path(sys.argv[2]).resolve()

    if not root_in.exists():
        print(f"ERROR: 入力ディレクトリが存在しません: {root_in}", file=sys.stderr)
        return 1

    json_files = sorted(root_in.rglob("*.json"))
    if not json_files:
        print(f"ERROR: JSON ファイルが見つかりません: {root_in}", file=sys.stderr)
        return 1

    for path in json_files:
        process_file(path, root_in, root_out)

    print(f"\nDone. Output: {root_out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
