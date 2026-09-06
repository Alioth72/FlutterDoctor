"""Convert the official ME-rPPG state.json into compact Flutter assets."""

from __future__ import annotations

import argparse
import json
import struct
from pathlib import Path
from typing import Any


def shape_of(value: Any) -> list[int]:
    shape: list[int] = []
    current = value
    while isinstance(current, list):
        shape.append(len(current))
        current = current[0] if current else None
    return shape


def flatten(value: Any):
    if isinstance(value, list):
        for item in value:
            yield from flatten(item)
    else:
        yield float(value)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("binary_output", type=Path)
    parser.add_argument("manifest_output", type=Path)
    args = parser.parse_args()

    states = json.loads(args.source.read_text(encoding="utf-8"))
    args.binary_output.parent.mkdir(parents=True, exist_ok=True)
    tensors: list[dict[str, Any]] = []
    offset = 0

    with args.binary_output.open("wb") as output:
        for name, nested_values in states.items():
            values = list(flatten(nested_values))
            output.write(struct.pack(f"<{len(values)}f", *values))
            tensors.append(
                {
                    "name": name,
                    "shape": shape_of(nested_values),
                    "offsetBytes": offset,
                    "elementCount": len(values),
                }
            )
            offset += len(values) * 4

    manifest = {
        "format": "float32-little-endian",
        "tensorCount": len(tensors),
        "totalBytes": offset,
        "tensors": tensors,
    }
    args.manifest_output.write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
    )


if __name__ == "__main__":
    main()
