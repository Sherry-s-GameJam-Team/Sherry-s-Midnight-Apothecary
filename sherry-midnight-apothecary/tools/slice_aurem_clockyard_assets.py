"""Slice the supplied Aurem Clockyard sheets into transparent scene props.

Run from the Godot project root.  The source images are the two user-provided
PNG sheets on the desktop; output stays in the level's `src` directory.
"""

from pathlib import Path
from PIL import Image
import cv2
import numpy as np


PROJECT_ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIR = Path(r"C:\Users\jisub\Desktop")
OUTPUT_DIR = PROJECT_ROOT / "day" / "levels" / "Aurem Clockyard" / "src"

# (output-relative PNG path, source-sheet index, left, top, right, bottom)
SPRITES = [
    # Sheet 1 — traversable stone-and-brass platforms.
    ("platforms/stone_corner_left_small.png", 1, 18, 30, 145, 191),
    ("platforms/stone_corner_left_chain.png", 1, 160, 29, 346, 191),
    ("platforms/stone_corner_left_plain.png", 1, 350, 28, 521, 191),
    ("platforms/stone_corner_left_tall.png", 1, 548, 27, 722, 191),
    ("platforms/stone_platform_chain_short.png", 1, 747, 28, 904, 174),
    ("platforms/stone_corner_right_tall.png", 1, 968, 29, 1103, 201),
    ("platforms/stone_corner_left_hanging.png", 1, 15, 195, 190, 380),
    ("platforms/stone_platform_short.png", 1, 214, 214, 375, 344),
    ("platforms/hanging_platform_triangular.png", 1, 383, 164, 551, 337),
    ("platforms/hanging_platform_wide.png", 1, 565, 205, 755, 351),
    ("platforms/stone_platform_tiny.png", 1, 788, 219, 906, 311),
    ("platforms/stone_corner_right_chain.png", 1, 910, 183, 1110, 377),
    ("platforms/stone_platform_long_left.png", 1, 154, 396, 520, 608),
    ("platforms/hanging_platform_long_chain.png", 1, 535, 386, 838, 564),
    ("platforms/stone_platform_tiny_round.png", 1, 864, 424, 970, 495),
    ("platforms/stone_corner_right_small.png", 1, 978, 400, 1103, 574),
    ("platforms/stone_arch_double.png", 1, 13, 615, 454, 804),
    ("platforms/stone_platform_mid_corner.png", 1, 392, 746, 729, 926),
    ("platforms/stone_platform_tiny_block.png", 1, 472, 565, 549, 662),
    ("platforms/stone_platform_micro_left.png", 1, 554, 607, 631, 669),
    ("platforms/stone_platform_micro_right.png", 1, 635, 611, 720, 675),
    ("platforms/stone_arch_wide.png", 1, 12, 803, 406, 1041),
    ("platforms/stone_arch_double_compact.png", 1, 385, 918, 709, 1094),
    ("platforms/stone_platform_tiny_chain.png", 1, 713, 936, 851, 1095),
    ("platforms/stone_ground_long.png", 1, 16, 1105, 950, 1375),
    ("platforms/stone_corner_right_micro.png", 1, 1012, 1225, 1116, 1378),
    # Sheet 1 — ladder and freestanding set dressing.
    ("props/banner_clockyard_large.png", 1, 20, 382, 143, 634),
    ("props/ladder_tall.png", 1, 731, 573, 804, 926),
    ("props/ladder_platform.png", 1, 840, 563, 1054, 735),
    ("props/ladder_arch_platform.png", 1, 846, 723, 1108, 950),
    ("props/ladder_short.png", 1, 842, 883, 914, 1102),
    ("props/wall_lantern_platform.png", 1, 976, 970, 1107, 1136),
    # Sheet 2 — architectural foreground assets.
    ("architecture/window_gothic_tall.png", 2, 14, 8, 148, 402),
    ("architecture/window_gothic_medium.png", 2, 142, 96, 270, 396),
    ("architecture/window_gothic_small.png", 2, 267, 205, 369, 398),
    ("architecture/column_clock_arch.png", 2, 742, 1012, 930, 1375),
    ("architecture/column_clock_tall.png", 2, 636, 1025, 745, 1375),
    ("architecture/column_clock_short.png", 2, 576, 1192, 649, 1376),
    ("architecture/clockwork_doorway.png", 2, 1025, 1003, 1118, 1374),
    ("architecture/platform_arch_corner.png", 2, 10, 906, 319, 1053),
    ("architecture/platform_arch_center.png", 2, 326, 936, 558, 1060),
    ("architecture/platform_arch_small.png", 2, 475, 1025, 652, 1160),
    ("architecture/platform_arch_gate.png", 2, 744, 1003, 937, 1200),
    # Sheet 2 — banners, light sources, and machinery.
    ("decorations/banner_clockyard_wide.png", 2, 349, 50, 476, 375),
    ("decorations/banner_clockyard_medium.png", 2, 477, 60, 578, 350),
    ("decorations/banner_clockyard_pennant.png", 2, 618, 73, 702, 321),
    ("decorations/banner_clockyard_vertical.png", 2, 945, 1033, 1028, 1242),
    ("decorations/wall_lamp_tall.png", 2, 708, 27, 798, 203),
    ("decorations/wall_lamp_small.png", 2, 708, 196, 809, 341),
    ("decorations/lantern_hanging.png", 2, 800, 105, 880, 379),
    ("decorations/chain_hanging_long.png", 2, 25, 405, 83, 719),
    ("decorations/chain_hanging_medium.png", 2, 85, 398, 145, 710),
    ("decorations/chain_weight.png", 2, 156, 394, 224, 683),
    ("mechanisms/clock_face_grand.png", 2, 480, 384, 741, 752),
    ("mechanisms/clock_face_large_left.png", 2, 15, 693, 301, 891),
    ("mechanisms/clock_face_large_right.png", 2, 899, 656, 1118, 907),
    ("mechanisms/clock_face_medium.png", 2, 837, 432, 1028, 680),
    ("mechanisms/clock_face_small.png", 2, 645, 682, 790, 838),
    ("mechanisms/pendulum_orb.png", 2, 337, 405, 464, 692),
    ("mechanisms/pendulum_orb_small.png", 2, 747, 361, 845, 673),
    ("mechanisms/gear_cluster.png", 2, 16, 730, 138, 865),
    ("mechanisms/gear_lever.png", 2, 389, 718, 587, 878),
    ("mechanisms/winch.png", 2, 441, 798, 580, 913),
    ("mechanisms/hanging_crane.png", 2, 580, 783, 690, 1020),
    ("mechanisms/hanging_platform_triangular.png", 2, 676, 830, 809, 1002),
    ("mechanisms/clock_pillar.png", 2, 817, 669, 923, 1005),
    ("mechanisms/lever_console.png", 2, 24, 1195, 165, 1377),
    ("mechanisms/gear_pedestal.png", 2, 152, 1233, 250, 1378),
    ("mechanisms/gear_pedestal_small.png", 2, 246, 1250, 360, 1376),
    ("mechanisms/pressure_gauge.png", 2, 354, 1247, 467, 1375),
    ("mechanisms/hand_crank.png", 2, 449, 1255, 559, 1374),
]


def transparentize(image: Image.Image) -> Image.Image:
    """Remove the black backdrop and only the obvious pure-red sheet artifacts."""
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            r, g, b, a = pixels[x, y]
            is_backdrop = r <= 12 and g <= 12 and b <= 12
            is_red_artifact = r >= 165 and g <= 68 and b <= 42
            if is_backdrop or is_red_artifact:
                pixels[x, y] = (r, g, b, 0)
    # The generator occasionally leaves isolated coloured flecks between
    # assets.  They are never a connected part of a prop, so discard only
    # very small alpha islands while keeping chains, flames, and gear teeth.
    alpha = np.array(rgba.getchannel("A"))
    count, labels, stats, _ = cv2.connectedComponentsWithStats(
        (alpha > 0).astype(np.uint8), connectivity=8
    )
    for label in range(1, count):
        if stats[label, cv2.CC_STAT_AREA] < 48:
            alpha[labels == label] = 0
    rgba.putalpha(Image.fromarray(alpha))
    return rgba


def main() -> None:
    sources = {
        1: Image.open(SOURCE_DIR / "ChatGPT Image 2026年8月18日 17_37_46.png"),
        2: Image.open(SOURCE_DIR / "ChatGPT Image 2026年8月18日 17_37_54.png"),
    }
    for relative_path, sheet, left, top, right, bottom in SPRITES:
        output_path = OUTPUT_DIR / relative_path
        output_path.parent.mkdir(parents=True, exist_ok=True)
        crop = sources[sheet].crop((left, top, right, bottom))
        transparentize(crop).save(output_path)
        print(output_path.relative_to(PROJECT_ROOT))


if __name__ == "__main__":
    main()
