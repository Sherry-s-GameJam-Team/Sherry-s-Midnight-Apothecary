"""Import cyan plant artwork into the processing-ready herb library.

Usage:
    python tools/import_cyan_plant_library.py --source <cyan-source-directory>
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
CANVAS_SIZE = 4096
PLANTS = (
    ("回潮棘蕨", "returning_tide_thorn_fern", "回潮棘蕨", "Returning-Tide Thorn Fern", "回潮棘蕨.png", ("p1.png", "p2.png", "p3.png")),
    ("汐盘荷", "tideplate_lotus", "汐盘荷", "Tideplate Lotus", "汐盘荷.png", ("1.png", "2.png", "3.png")),
    ("潮灯花", "tide_lantern_flower", "潮灯花", "Tide-Lantern Flower", "潮灯花.png", ("1.png", "2.png", "3.png")),
)


def _resize_rgba(image: Image.Image) -> Image.Image:
    """Normalize supplied source art to the production board's 4096-square canvas."""
    image = image.convert("RGBA")
    if image.size == (CANVAS_SIZE, CANVAS_SIZE):
        return image
    return image.resize((CANVAS_SIZE, CANVAS_SIZE), Image.Resampling.LANCZOS)


def _write_trimmed_piece(image: Image.Image, path: Path) -> tuple[int, int, int, int]:
    rgba = np.asarray(image)
    alpha = rgba[:, :, 3]
    ys, xs = np.nonzero(alpha > 0)
    if xs.size == 0:
        raise ValueError(f"{path.name} has no visible pixels")
    x0, x1 = int(xs.min()), int(xs.max()) + 1
    y0, y1 = int(ys.min()), int(ys.max()) + 1
    path.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(rgba[y0:y1, x0:x1], "RGBA").save(path)
    return x0, y0, x1 - x0, y1 - y0


def _import_plant(source_root: Path, spec: tuple[object, ...]) -> None:
    source_name, ingredient_id, display_name, english_name, whole_name, part_names = spec
    input_dir = source_root / str(source_name)
    output_dir = ROOT / "day" / "interactables" / "herb" / "herbs" / str(ingredient_id)
    preview_dir = output_dir / "preview"
    pieces_dir = output_dir / "pieces" / "cyan"

    whole = _resize_rgba(Image.open(input_dir / str(whole_name)))
    preview_dir.mkdir(parents=True, exist_ok=True)
    whole.save(preview_dir / "herb_preview.png")
    whole.resize((256, 256), Image.Resampling.LANCZOS).save(preview_dir / "herb_slot_thumb.png")

    parts = []
    for index, part_name in enumerate(part_names, 1):
        rect = _write_trimmed_piece(_resize_rgba(Image.open(input_dir / str(part_name))), pieces_dir / f"piece_{index:02d}.png")
        parts.append({"id": f"{ingredient_id}_piece_{index:02d}", "source_rect": rect})
    (output_dir / "source").mkdir(parents=True, exist_ok=True)
    (output_dir / "source" / "split_manifest.json").write_text(
        json.dumps({"herb_id": ingredient_id, "display_name_zh": display_name, "english_name": english_name, "canvas_size": [CANVAS_SIZE, CANVAS_SIZE], "pieces": parts}, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", required=True, type=Path)
    args = parser.parse_args()
    for spec in PLANTS:
        _import_plant(args.source, spec)


if __name__ == "__main__":
    main()
