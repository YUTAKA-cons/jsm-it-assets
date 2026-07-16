#!/usr/bin/env python3
from __future__ import annotations

import sys
from pathlib import Path
import yaml


def load_yaml(path: Path):
    if not path.exists():
        return None
    with path.open("r", encoding="utf-8") as f:
        return yaml.safe_load(f)


def save_yaml(path: Path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as f:
        yaml.safe_dump(
            data,
            f,
            allow_unicode=True,
            sort_keys=False,
            default_flow_style=False,
        )


def merge_object_type(obj_file: Path, attr_file: Path, out_file: Path):
    obj = load_yaml(obj_file) or {}
    attrs = load_yaml(attr_file) or {}

    attributes = attrs.get("attributes", [])

    merged = dict(obj)
    if attributes:
        merged["attributes"] = attributes

    save_yaml(out_file, merged)

    print(f"[merge] {obj_file.name} + {attr_file.name} -> {out_file}")


def main():
    if len(sys.argv) != 3:
        print("Usage: python merge_object_types.py <input_dir> <output_dir>")
        return 1

    root_in = Path(sys.argv[1])
    root_out = Path(sys.argv[2])

    for obj_file in root_in.rglob("*.yaml"):
        if obj_file.name.endswith("-attributes.yaml"):
            continue
        if obj_file.name in ("objecttypes.yaml", "schema.yaml"):
            continue

        attr_file = obj_file.with_name(obj_file.stem + "-attributes.yaml")

        rel = obj_file.relative_to(root_in)
        out_file = root_out / rel

        if attr_file.exists():
            merge_object_type(obj_file, attr_file, out_file)
        else:
            data = load_yaml(obj_file)
            save_yaml(out_file, data)
            print(f"[copy] {obj_file} -> {out_file}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())

