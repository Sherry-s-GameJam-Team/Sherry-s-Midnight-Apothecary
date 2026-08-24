"""Import supplied colored plant artwork into the processing-ready herb library.

Usage:
    python tools/import_cyan_plant_library.py --color cyan --source <cyan-source-directory>
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
CANVAS_SIZE = 4096
PLANTS_BY_COLOR = {
"cyan": (
    ("回潮棘蕨", "returning_tide_thorn_fern", "回潮棘蕨", "Returning-Tide Thorn Fern", "回潮棘蕨.png", ("p1.png", "p2.png", "p3.png")),
    ("汐盘荷", "tideplate_lotus", "汐盘荷", "Tideplate Lotus", "汐盘荷.png", ("1.png", "2.png", "3.png")),
    ("潮灯花", "tide_lantern_flower", "潮灯花", "Tide-Lantern Flower", "潮灯花.png", ("1.png", "2.png", "3.png")),
),
"red": (
    ("枫心乌脉", "maple_heart_dark_vein", "枫心乌脉", "Mapleheart Dark Vein", "枫心乌脉.png", ("1.png", "2.png", "3.png")),
    ("枫髓辰晶", "maple_marrow_star_crystal", "枫髓辰晶", "Maple-Marrow Star Crystal", "枫髓辰晶.png", ("1.png", "2.png", "3.png")),
    ("驿灯垂果", "waystation_lantern_fruit", "驿灯垂果", "Waystation Lantern Fruit", "驿灯垂果.png", ("1.png", "2.png")),
),
"orange": (
    ("刻阳花", "sun_etched_flower", "刻阳花", "Sun-Etched Flower", "刻阳花.png", ("1.png", "2.png", "3.png")),
    ("垂灯钟伞", "hanging_lantern_bell_cap", "垂灯钟伞", "Hanging Lantern Bell Cap", "垂灯钟伞.png", ("1.png", "2.png", "3.png")),
    ("晨轮晶冠", "morning_wheel_crystal_crown", "晨轮晶冠", "Morning-Wheel Crystal Crown", "橙1.png", ("1.png", "2.png", "3.png")),
),
}

COLOR_SETTINGS = {
    "red": {"display_name": "红色部位层", "display_color": "Color(0.7882353, 0.2235294, 0.2392157, 1)", "spectrum_values": (0.04, 0.085, 0.12)},
    "orange": {"display_name": "橙色部位层", "display_color": "Color(0.9254902, 0.5058824, 0.172549, 1)", "spectrum_values": (0.165, 0.215, 0.265)},
    "cyan": {"display_name": "青色部位层", "display_color": "Color(0.1882353, 0.7843137, 0.8078431, 1)", "spectrum_values": (0.61, 0.65, 0.69)},
}


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


def _write_library_resources(ingredient_id: str, display_name: str, english_name: str, color_id: str, parts: list[dict[str, object]]) -> None:
    settings = COLOR_SETTINGS[color_id]
    spectrum_x = settings["spectrum_values"][list(PLANTS_BY_COLOR[color_id]).index(next(spec for spec in PLANTS_BY_COLOR[color_id] if spec[1] == ingredient_id))]
    display_color = settings["display_color"]
    herb_root = f"res://day/interactables/herb/herbs/{ingredient_id}"
    resource_path = ROOT / "shared" / "definitions" / "data" / "ingredients" / f"{ingredient_id}.tres"
    ext_resources = [
        '[ext_resource type="Script" path="res://shared/definitions/ingredient_data.gd" id="1_ingredient"]',
        '[ext_resource type="Script" path="res://shared/definitions/herb_color_layer_data.gd" id="2_layer"]',
        '[ext_resource type="Script" path="res://shared/definitions/herb_piece_data.gd" id="3_piece"]',
        f'[ext_resource type="Texture2D" path="{herb_root}/preview/herb_slot_thumb.png" id="4_icon"]',
        f'[ext_resource type="Texture2D" path="{herb_root}/preview/herb_preview.png" id="5_preview"]',
    ]
    for index in range(1, len(parts) + 1):
        ext_resources.append(f'[ext_resource type="Texture2D" path="{herb_root}/pieces/{color_id}/piece_{index:02d}.png" id="{index + 5}_piece_{index:02d}"]')
    blocks = ['[gd_resource type="Resource" script_class="IngredientData" load_steps=%d format=3]' % (5 + len(parts)), "", *ext_resources]
    for index, part in enumerate(parts, 1):
        rect = part["source_rect"]
        blocks.extend([
            "",
            f'[sub_resource type="Resource" id="Piece_{index:02d}"]',
            'script = ExtResource("3_piece")',
            f'id = &"{ingredient_id}_piece_{index:02d}"',
            f'display_name = "{display_name}·部位{index:02d}"',
            f'texture = ExtResource("{index + 5}_piece_{index:02d}")',
            f'source_rect = Rect2i({rect[0]}, {rect[1]}, {rect[2]}, {rect[3]})',
            f'area_ratio = {1.0 / len(parts):.6f}',
            f'color_id = &"{color_id}"',
            f'spectrum_x = {spectrum_x}',
            f'display_color = {display_color}',
            f'z_order = {index}',
        ])
    pieces = ", ".join(f'SubResource("Piece_{index:02d}")' for index in range(1, len(parts) + 1))
    blocks.extend([
        "",
        '[sub_resource type="Resource" id="Layer_main"]',
        'script = ExtResource("2_layer")',
        f'id = &"{ingredient_id}_{color_id}_layer"',
        f'display_name = "{settings["display_name"]}"',
        f'color_id = &"{color_id}"',
        f'display_color = {display_color}',
        f'spectrum_x = {spectrum_x}',
        f'pieces = Array[ExtResource("3_piece")]([{pieces}])',
        "",
        "[resource]",
        'script = ExtResource("1_ingredient")',
        f'id = &"{ingredient_id}"',
        f'display_name = "{display_name}"',
        f'english_name = "{english_name}"',
        f'description = "一株带有{settings["display_name"][:2]}药性的珍稀植物。"',
        'icon = ExtResource("4_icon")',
        'preview_texture = ExtResource("5_preview")',
        'reference_canvas_size = Vector2i(4096, 4096)',
        'production_layers = Array[ExtResource("2_layer")]([SubResource("Layer_main")])',
        'base_value = 18',
        f'spectrum_start = {spectrum_x - 0.015:.3f}',
        f'spectrum_end = {spectrum_x + 0.015:.3f}',
        'base_quality = 1.1',
        'base_concentration = 1.05',
        "",
    ])
    resource_path.write_text("\n".join(blocks), encoding="utf-8")
    scene_name = "".join(part.title() for part in ingredient_id.split("_"))
    (ROOT / "day" / "interactables" / "herb" / "herbs" / ingredient_id / f"{ingredient_id}_herb.tscn").write_text(
        "[gd_scene load_steps=2 format=3]\n\n[ext_resource type=\"PackedScene\" path=\"res://day/interactables/herb/herb.tscn\" id=\"1_base\"]\n\n[node name=\"%sHerb\" instance=ExtResource(\"1_base\")]\ningredient_id = &\"%s\"\n" % (scene_name, ingredient_id),
        encoding="utf-8",
    )


def _import_plant(source_root: Path, color_id: str, spec: tuple[object, ...]) -> None:
    source_name, ingredient_id, display_name, english_name, whole_name, part_names = spec
    input_dir = source_root / str(source_name)
    output_dir = ROOT / "day" / "interactables" / "herb" / "herbs" / str(ingredient_id)
    preview_dir = output_dir / "preview"
    pieces_dir = output_dir / "pieces" / color_id

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
    _write_library_resources(str(ingredient_id), str(display_name), str(english_name), color_id, parts)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--color", required=True, choices=PLANTS_BY_COLOR.keys())
    parser.add_argument("--source", required=True, type=Path)
    args = parser.parse_args()
    for spec in PLANTS_BY_COLOR[args.color]:
        _import_plant(args.source, args.color, spec)


if __name__ == "__main__":
    main()
