#!/usr/bin/env python3
from __future__ import annotations

import sys
from pathlib import Path
from typing import Any

import yaml


def bool_mark(value: Any) -> str:
    if value is True:
        return "○"
    if value is False:
        return "-"
    return "-"


def render_scalar(value: Any) -> str:
    if value is None:
        return ""
    if isinstance(value, list):
        return ", ".join(str(v) for v in value)
    if isinstance(value, dict):
        if "name" in value:
            return str(value["name"])
        return str(value)
    return str(value)


def markdown_table(headers: list[str], rows: list[list[str]]) -> str:
    lines = []
    lines.append("| " + " | ".join(headers) + " |")
    lines.append("|" + "|".join(["---"] * len(headers)) + "|")
    for row in rows:
        lines.append("| " + " | ".join(row) + " |")
    return "\n".join(lines)


def render_attributes(attributes: list[dict[str, Any]]) -> str:
    rows: list[list[str]] = []
    for attr in attributes:
        rows.append(
            [
                str(attr.get("name", "")),
                render_scalar(attr.get("type", "")),
                bool_mark(attr.get("required", False)),
                bool_mark(attr.get("unique", False)),
                render_scalar(attr.get("referenceObjectType", "")),
                render_scalar(attr.get("description", "")),
            ]
        )
    return markdown_table(
        ["名前", "型", "必須", "一意", "参照先", "説明"],
        rows,
    )


def render_key_values(data: dict[str, Any], skip_keys: set[str]) -> str:
    rows: list[list[str]] = []
    for key, value in data.items():
        if key in skip_keys:
            continue
        rows.append([str(key), render_scalar(value)])
    if not rows:
        return ""
    return markdown_table(["項目", "値"], rows)


def render_schema_doc(data: dict[str, Any], title: str) -> str:
    parts: list[str] = [f"# {title}", ""]
    kv = render_key_values(data, {"attributes", "objectTypes", "schemas"})
    if kv:
        parts += ["## 基本情報", "", kv, ""]

    attrs = data.get("attributes")
    if isinstance(attrs, list) and attrs:
        parts += ["## 属性一覧", "", render_attributes(attrs), ""]

    object_types = data.get("objectTypes")
    if isinstance(object_types, list) and object_types:
        rows = []
        for item in object_types:
            rows.append(
                [
                    str(item.get("name", "")),
                    render_scalar(item.get("parentObjectType", "")),
                    render_scalar(item.get("description", "")),
                ]
            )
        parts += [
            "## Object Types",
            "",
            markdown_table(["名前", "親", "説明"], rows),
            "",
        ]

    schemas = data.get("schemas")
    if isinstance(schemas, list) and schemas:
        rows = []
        for item in schemas:
            rows.append(
                [
                    str(item.get("name", "")),
                    render_scalar(item.get("objectSchemaKey", "")),
                    render_scalar(item.get("description", "")),
                ]
            )
        parts += [
            "## Schemas",
            "",
            markdown_table(["名前", "キー", "説明"], rows),
            "",
        ]

    return "\n".join(parts).strip() + "\n"


def convert_file(src: Path, root_in: Path, root_out: Path) -> None:
    with src.open("r", encoding="utf-8") as f:
        data = yaml.safe_load(f)

    if data is None:
        data = {}

    title = data.get("name") if isinstance(data, dict) else src.stem
    if not title:
        title = src.stem

    md = render_schema_doc(data if isinstance(data, dict) else {"value": data}, str(title))

    dst = (root_out / src.relative_to(root_in)).with_suffix(".md")
    dst.parent.mkdir(parents=True, exist_ok=True)
    dst.write_text(md, encoding="utf-8")
    print(f"[yaml->md] {src} -> {dst}")


def main() -> int:
    if len(sys.argv) != 3:
        print("Usage: python scripts/yaml_to_markdown.py <input_dir> <output_dir>", file=sys.stderr)
        return 1

    root_in = Path(sys.argv[1]).resolve()
    root_out = Path(sys.argv[2]).resolve()

    if not root_in.exists():
        print(f"Input dir not found: {root_in}", file=sys.stderr)
        return 1

    files = sorted(root_in.rglob("*.yaml"))
    if not files:
        print(f"No YAML files found under: {root_in}", file=sys.stderr)
        return 1

    for src in files:
        convert_file(src, root_in, root_out)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())

