"""Build a transparent Godot sprite sheet from extracted bellows video frames."""

from collections import deque
import os
from pathlib import Path
from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path(os.environ.get("BELLOWS_FRAMES_DIR", str(ROOT / "night/art/alchemy/bellows/raw_frames")))
OUTPUT = ROOT / "night/art/alchemy/bellows/bellows_pump_sheet.png"
PREVIEW = ROOT / "night/art/alchemy/bellows/bellows_pump_preview.png"
ANIMATION_PREVIEW = ROOT / "night/art/alchemy/bellows/bellows_pump_cycle.gif"
FRAME_SIZE = (512, 288)


def background_color(image: Image.Image) -> tuple[int, int, int]:
    pixels = image.load()
    width, height = image.size
    samples: list[tuple[int, int, int]] = []
    for x in (0, 8, width - 9, width - 1):
        for y in (0, 8, height - 9, height - 1):
            samples.append(pixels[x, y])
    return tuple(sum(channel[index] for channel in samples) // len(samples) for index in range(3))


def connected_background(mask: list[list[bool]]) -> list[list[bool]]:
    height = len(mask)
    width = len(mask[0])
    seen = [[False] * width for _ in range(height)]
    queue = deque()
    for x in range(width):
        for y in (0, height - 1):
            if mask[y][x] and not seen[y][x]:
                seen[y][x] = True
                queue.append((x, y))
    for y in range(height):
        for x in (0, width - 1):
            if mask[y][x] and not seen[y][x]:
                seen[y][x] = True
                queue.append((x, y))
    while queue:
        x, y = queue.popleft()
        for offset_y in (-1, 0, 1):
            for offset_x in (-1, 0, 1):
                nx, ny = x + offset_x, y + offset_y
                if 0 <= nx < width and 0 <= ny < height and mask[ny][nx] and not seen[ny][nx]:
                    seen[ny][nx] = True
                    queue.append((nx, ny))
    return seen


def remove_background(image: Image.Image) -> Image.Image:
    image = image.convert("RGB")
    width, height = image.size
    background = background_color(image)
    rgb = image.load()
    background_mask = [[False] * width for _ in range(height)]
    for y in range(height):
        for x in range(width):
            red, green, blue = rgb[x, y]
            distance = max(abs(red - background[0]), abs(green - background[1]), abs(blue - background[2]))
            brightness = max(red, green, blue)
            # Conservative matte: only pixels that are very close to the sampled
            # backdrop can be removed. The flood fill keeps dark leather folds,
            # outlines, and detached metal details even when they are low contrast.
            background_mask[y][x] = distance <= 13 and brightness <= 72
    background = connected_background(background_mask)
    output = Image.new("RGBA", image.size)
    output_pixels = output.load()
    for y in range(height):
        for x in range(width):
            if not background[y][x]:
                red, green, blue = rgb[x, y]
                output_pixels[x, y] = (red, green, blue, 255)
    return output


def main() -> None:
    frame_paths = sorted(SOURCE.glob("bellows_*.bmp"))
    if not frame_paths:
        raise FileNotFoundError(f"No extracted frames found in {SOURCE}")
    frames = [remove_background(Image.open(frame_path)) for frame_path in frame_paths]
    if any(frame.size != FRAME_SIZE for frame in frames):
        raise ValueError(f"Expected {FRAME_SIZE} frames")

    sheet = Image.new("RGBA", (FRAME_SIZE[0] * len(frames), FRAME_SIZE[1]))
    for index, frame in enumerate(frames):
        sheet.alpha_composite(frame, (FRAME_SIZE[0] * index, 0))
    sheet.save(OUTPUT, optimize=True)

    preview = Image.new("RGBA", (FRAME_SIZE[0] * 5, FRAME_SIZE[1]), (39, 34, 29, 255))
    for preview_index, frame_index in enumerate((0, 3, 7, 11, len(frames) - 1)):
        preview.alpha_composite(frames[frame_index], (FRAME_SIZE[0] * preview_index, 0))
    preview.save(PREVIEW, optimize=True)
    frames[0].save(
        ANIMATION_PREVIEW,
        save_all=True,
        append_images=frames[1:],
        duration=43,
        loop=0,
        disposal=2,
        optimize=True,
    )
    print(f"Created {OUTPUT} with {len(frames)} frames")


if __name__ == "__main__":
    main()
