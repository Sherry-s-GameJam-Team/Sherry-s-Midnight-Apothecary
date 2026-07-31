"""Build processing-ready Old Man's Noose assets from the approved alpha preview."""

from __future__ import annotations

import json
from pathlib import Path

import cv2
import numpy as np
from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
HERB_ROOT = ROOT / "night" / "art" / "herbs" / "old_mans_noose"
PREVIEW_PATH = HERB_ROOT / "preview" / "herb_preview.png"
MASTER_PATH = HERB_ROOT / "source" / "master_4096.png"
PIECES_ROOT = HERB_ROOT / "pieces"
CANVAS_SIZE = 4096


def _premultiplied_resize(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    rgba = np.asarray(image.convert("RGBA"), dtype=np.float32)
    alpha = rgba[:, :, 3:4] / 255.0
    premultiplied = np.concatenate((rgba[:, :, :3] * alpha, rgba[:, :, 3:4]), axis=2)
    resized_channels = [
        cv2.resize(premultiplied[:, :, channel], size, interpolation=cv2.INTER_LANCZOS4)
        for channel in range(4)
    ]
    resized = np.stack(resized_channels, axis=2)
    out_alpha = np.clip(resized[:, :, 3:4], 0.0, 255.0)
    # Lanczos can create isolated near-transparent ringing far from thin curls.
    # Dropping sub-visible alpha keeps the host piece free of ghost silhouettes.
    out_alpha[out_alpha < 5.0] = 0.0
    safe_alpha = np.maximum(out_alpha / 255.0, 1.0 / 255.0)
    out_rgb = np.clip(resized[:, :, :3] / safe_alpha, 0.0, 255.0)
    return Image.fromarray(np.concatenate((out_rgb, out_alpha), axis=2).astype(np.uint8), "RGBA")


def _bbox(mask: np.ndarray) -> tuple[int, int, int, int]:
    ys, xs = np.nonzero(mask)
    return int(xs.min()), int(ys.min()), int(xs.max() + 1), int(ys.max() + 1)


def _write_piece(master: np.ndarray, mask: np.ndarray, path: Path) -> tuple[int, int, int, int]:
    x0, y0, x1, y1 = _bbox(mask)
    piece = master[y0:y1, x0:x1].copy()
    piece[:, :, 3] = np.where(mask[y0:y1, x0:x1], piece[:, :, 3], 0)
    path.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(piece, "RGBA").save(path)
    return x0, y0, x1 - x0, y1 - y0


def main() -> None:
    source = Image.open(PREVIEW_PATH).convert("RGBA")
    master_image = _premultiplied_resize(source, (CANVAS_SIZE, CANVAS_SIZE))
    MASTER_PATH.parent.mkdir(parents=True, exist_ok=True)
    master_image.save(MASTER_PATH)
    master = np.asarray(master_image).copy()
    alpha = master[:, :, 3]

    yy, xx = np.indices(alpha.shape)
    scale = CANVAS_SIZE / 1254.0
    # Conservative cut line follows the lower bark edge. Upper attachment caps
    # remain with the host while every free-hanging body becomes detachable.
    native_x = xx / scale
    branch_floor = np.where(
        native_x < 350.0,
        (680.0 - 0.60 * native_x) * scale,
        575.0 * scale - 0.30 * xx,
    )
    below_branch = yy > branch_floor
    candidate = ((alpha > 0) & below_branch).astype(np.uint8)
    count, labels, stats, centroids = cv2.connectedComponentsWithStats(candidate, 8)

    components: list[tuple[float, int]] = []
    for label in range(1, count):
        _x, _y, _w, height, area = stats[label]
        if area > 7000 * scale * scale and height > 100 * scale:
            components.append((float(centroids[label][0]), label))
    components.sort()
    if len(components) != 11:
        raise RuntimeError(f"Expected 11 detachable thalli, found {len(components)}")

    detachable_union = np.zeros(alpha.shape, dtype=bool)
    manifest_pieces: list[dict[str, object]] = []
    for index, (_center_x, label) in enumerate(components, 1):
        mask = labels == label
        if index == 1:
            # The leftmost ribbon passes under a broad crustose patch. Keep the
            # lower loop while assigning that unrelated yellow patch to host.
            mask &= (xx > 185.0 * scale) | (yy > 650.0 * scale)
        detachable_union |= mask
        filename = f"thallus_{index:02d}.png"
        rect = _write_piece(master, mask, PIECES_ROOT / "thalli" / filename)
        manifest_pieces.append(
            {
                "id": f"old_mans_noose_thallus_{index:02d}",
                "role": f"thallus_{index:02d}",
                "source_rect": list(rect),
                "area_ratio": round(float(mask.sum()) / float(detachable_union.size), 8),
                "path": f"pieces/thalli/{filename}",
            }
        )

    total_thallus_area = sum(float(piece["area_ratio"]) for piece in manifest_pieces)
    for piece in manifest_pieces:
        piece["area_ratio"] = round(float(piece["area_ratio"]) / total_thallus_area, 8)

    host_mask = (alpha > 0) & ~detachable_union
    host_rect = _write_piece(master, host_mask, PIECES_ROOT / "host" / "lichen_branch.png")
    manifest = {
        "herb_id": "old_mans_noose",
        "display_name_zh": "绞索老汉",
        "display_name_en": "Old Man’s Noose",
        "canvas_size": [CANVAS_SIZE, CANVAS_SIZE],
        "source_reference": "6.png",
        "generated_master": "source/master_4096.png",
        "host_piece": {
            "id": "old_mans_noose_lichen_branch",
            "role": "lichen_branch",
            "source_rect": list(host_rect),
            "path": "pieces/host/lichen_branch.png",
        },
        "thallus_pieces": manifest_pieces,
    }
    (HERB_ROOT / "source" / "split_manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )

    thumb = _premultiplied_resize(source, (256, 256))
    thumb.save(HERB_ROOT / "preview" / "herb_slot_thumb.png")
    thumb.save(HERB_ROOT / "preview" / "herb_badge.png")
    print(f"Built {len(components) + 1} Old Man's Noose processing pieces.")


if __name__ == "__main__":
    main()
