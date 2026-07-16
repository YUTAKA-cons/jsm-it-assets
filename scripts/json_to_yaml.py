#!/usr/bin/env python3
from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from typing import Any

import yaml


DROP_KEYS = {
    "id",
    "globalId",
    "workspaceId",
    "created",
    "updated",
    "timestamp",
    "position",
    "objectCount",
    "_links",
    "iconUrl",
}

KEEP_ID_KEYS = {"objectSchemaKey"}

NULL_LIKE = (None, "", [], {})


def slugify(value: str) -> str:
    value = value.strip().lower()
    value = re.sub(r"[^a-z0-9._-]+", "-", value)
    return value.strip("-") or "unnamed"


def sort_key_for_dict(d: dict[str, Any]) -> tuple[str, str]:
    return (
        str(d.get("name", "")),
        str(d.get("label", "")),
    )


def sort_list(values: list[Any]) -> list[Any]:
    if not values:
        return values
    if all(isinstance(v, dict) for v in values):
        if all(("name" in v or "label" in v) for v in values):
            return sorted(values, key=sort_key_for_dict)
        return values
    if all(isinstance(v, (str, int, float, bool)) or v is None for v in values):
        return sorted(values, key=lambda x: "" if x is None else str(x))
    return values


def compact_object(obj: dict[str, Any]) -> dict[str, Any]:
    return {k: v for k, v in obj.items() if v not in NULL_LIKE}


def normalize_value(value: Any) -> Any:
    if isinstance(value, dict):
        out: dict[str, Any] = {}
        for key, val in value.items():
            if key in DROP_KEYS:
                continue
            if key.endswith("Id") and key not in KEEP_ID_KEYS:
                continue
            out[key] = normalize_value(val)

        if isinstance(out.get("referenceObjectType"), dict):
            out["referenceObjectType"] = (
                out["referenceObjectType"].get("name")
                or out["referenceObjectType"].get("label")
                or out["referenceObjectType"]
            )

        if isinstance(out.get("parentObjectType"), dict):
            out["parentObjectType"] = (
                out["parentObjectType"].get("name")
                or out["parentObjectType"].get("label")
                or out["parentObjectType"]
            )

        if isinstance(out.get("type"), dict):
            out["type"] = out["type"].get("name") or out["type"].get("label") or out["type"]

        if isinstance(out.get("defaultType"), dict):
            out["defaultType"] = (
                out["defaultType"].get("name")
                or out["defaultType"].get("label")
                or out["defaultType"]
            )

        if "options" in out and isinstance(out["options"], list):
            out["options"] = sort_list(out["options"])

        return compact_object(out)

    if isinstance(value, list):
        normalized = [normalize_value(v) for v in value]
        normalized = [v for v in normalized if v not in NULL_LIKE]
        return sort_list(normalized)

    return value


def normalize_schema(data: Any) -> Any:
    if isinstance(data, list):
        return {"schemas": [normalize_value(x) for x in data if isinstance(x, dict)]}
    if isinstance(data, dict) and isinstance(data.get("values"), list):
        return {"schemas": [normalize_value(x) for x in data["values"] if isinstance(x, dict)]}
    return normalize_value(data)


def normalize_objecttypes(data: Any) -> Any:
    if isinstance(data, list):
        return {"objectTypes": [normalize_value(x) for x in data if isinstance(x, dict)]}
    if isinstance(data, dict) and isinstance(data.get("objectTypes"), list):
        return {"objectTypes": [normalize_value(x) for x in data["objectTypes"] if isinstance(x, dict)]}
    if isinstance(data, dict) and isinstance(data.get("values"), list):
        return {"objectTypes": [normalize_value(x) for x in data["values"] if isinstance(x, dict)]}
    return normalize_value(data)


def normalize_attributes(data: Any) -> Any:
    if isinstance(data, list):
        return {"attributes": [normalize_value(x) for x in data if isinstance(x, dict)]}
    if isinstance(data, dict) and isinstance(data.get("attributes"), list):
        return {"attributes": [normalize_value(x) for x in data["attributes"] if isinstance(x, dict)]}
    if isinstance(data, dict) and isinstance(data.get("values"), list):
        return {"attributes": [normalize_value(x) for x in data["values"] if isinstance(x, dict)]}
    return normalize_value(data)


def transform_for_file(path: Path, data: Any) -> Any:
    name = path.name

    if name == "objectschema-list.json":
        return normalize_schema(data)
    if name == "objecttypes.json":
        return normalize_objecttypes(data)
    if name.endswith("-attributes.json"):
        return normalize_attributes(data)

    return normalize_value(data)


def output_path(root_in: Path, root_out: Path, src: Path) -> Path:
    rel = src.relative_to(root_in)
    return (root_out / rel).with_suffix(".yaml")


def main() -> int:
    if len(sys.argv) != 3:
        print("Usage: python scripts/json_to_yaml.py <input_dir> <output_dir>", file=sys.stderr)
        return 1

    root_in = Path(sys.argv[1]).resolve()
    root_out = Path(sys.argv[2]).resolve()

    if not root_in.exists():
        print(f"Input dir not found: {root_in}", file=sys.stderr)
        return 1

    files = sorted(root_in.rglob("*.json"))
    if not files:
        print(f"No JSON files found under: {root_in}", file=sys.stderr)
        return 1

    for src in files:
        with src.open("r", encoding="utf-8") as f:
            raw = json.load(f)

        normalized = transform_for_file(src, raw)
        dst = output_path(root_in, root_out, src)
        dst.parent.mkdir(parents=True, exist_ok=True)

        with dst.open("w", encoding="utf-8") as f:
            yaml.safe_dump(
                normalized,
                f,
                allow_unicode=True,
                sort_keys=False,
                default_flow_style=False,
            )

        print(f"[json->yaml] {src} -> {dst}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())

