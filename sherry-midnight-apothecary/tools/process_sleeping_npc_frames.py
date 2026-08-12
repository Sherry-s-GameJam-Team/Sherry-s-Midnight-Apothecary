"""Extract and key 30 evenly sampled sleeping-NPC frames from a green-screen video."""

from __future__ import annotations

import argparse
import subprocess
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter


def smoothstep(edge0: float, edge1: float, value: np.ndarray) -> np.ndarray:
    value = np.clip((value - edge0) / (edge1 - edge0), 0.0, 1.0)
    return value * value * (3.0 - 2.0 * value)


def decode_frames(ffmpeg: Path, source: Path, width: int, height: int, count: int, duration: float) -> list[np.ndarray]:
    fps = count / duration
    command = [
        str(ffmpeg), "-v", "error", "-i", str(source),
        "-an", "-vf", f"fps={fps:.10f}", "-frames:v", str(count),
        "-f", "rawvideo", "-pix_fmt", "rgb24", "pipe:1",
    ]
    result = subprocess.run(command, check=True, stdout=subprocess.PIPE)
    frame_bytes = width * height * 3
    if len(result.stdout) < frame_bytes * count:
        raise RuntimeError(f"Expected {count} frames, received {len(result.stdout) // frame_bytes}")
    pixels = np.frombuffer(result.stdout[: frame_bytes * count], dtype=np.uint8)
    return [frame.copy() for frame in pixels.reshape(count, height, width, 3)]


def estimate_screen(rgb: np.ndarray) -> np.ndarray:
    height, width = rgb.shape[:2]
    strip_y = max(18, height // 18)
    strip_x = max(18, width // 24)
    samples = np.concatenate(
        [
            rgb[:strip_y].reshape(-1, 3),
            rgb[:, :strip_x].reshape(-1, 3),
            rgb[:, -strip_x:].reshape(-1, 3),
        ],
        axis=0,
    ).astype(np.float32)
    # Only green-dominant border samples contribute to the screen estimate.
    green = samples[:, 1] > np.maximum(samples[:, 0], samples[:, 2]) * 1.08
    return np.median(samples[green], axis=0) / 255.0


def key_frame(frame: np.ndarray) -> Image.Image:
    rgb = frame.astype(np.float32) / 255.0
    screen = estimate_screen(frame)
    chroma = rgb / np.maximum(rgb.sum(axis=2, keepdims=True), 1.0 / 255.0)
    screen_chroma = screen / screen.sum()
    chroma_distance = np.linalg.norm(chroma - screen_chroma, axis=2)

    # The low threshold clears the textured green plate; the broad transition
    # keeps antialiased fur and translucent magic smoke intact.
    alpha = smoothstep(0.040, 0.135, chroma_distance)
    green_excess = rgb[:, :, 1] - (rgb[:, :, 0] + rgb[:, :, 2]) * 0.5
    green_gate = smoothstep(0.005, 0.080, green_excess)
    alpha = np.maximum(alpha, (1.0 - green_gate) * smoothstep(0.025, 0.11, chroma_distance))

    # Slightly stabilize the matte while preserving the thin smoke curls.
    alpha_image = Image.fromarray(np.uint8(np.clip(alpha, 0.0, 1.0) * 255), "L")
    alpha_image = alpha_image.filter(ImageFilter.MedianFilter(3)).filter(ImageFilter.GaussianBlur(0.55))
    alpha = np.asarray(alpha_image, dtype=np.float32) / 255.0

    # Undo green-screen contribution in partially transparent pixels.
    safe_alpha = np.maximum(alpha[:, :, None], 0.06)
    foreground = (rgb - (1.0 - alpha[:, :, None]) * screen[None, None, :]) / safe_alpha
    foreground = np.clip(foreground, 0.0, 1.0)

    # Strong de-spill: neutralize any remaining green dominance most heavily
    # around translucent boundaries, without tinting the black/white subject.
    rb_max = np.maximum(foreground[:, :, 0], foreground[:, :, 2])
    spill = np.maximum(foreground[:, :, 1] - rb_max, 0.0)
    spill_weight = np.clip((1.0 - alpha) ** 0.35 + green_gate * 0.45, 0.0, 1.0)
    foreground[:, :, 1] -= spill * spill_weight
    foreground[:, :, 0] += spill * spill_weight * 0.10
    foreground[:, :, 2] += spill * spill_weight * 0.16
    foreground = np.clip(foreground, 0.0, 1.0)
    foreground[alpha < 0.012] = 0.0

    rgba = np.dstack((np.uint8(foreground * 255), np.uint8(alpha * 255)))
    return Image.fromarray(rgba, "RGBA")


def union_bounds(frames: list[Image.Image], padding: int = 18) -> tuple[int, int, int, int]:
    boxes = [frame.getchannel("A").point(lambda value: 255 if value >= 20 else 0).getbbox() for frame in frames]
    boxes = [box for box in boxes if box is not None]
    left = max(0, min(box[0] for box in boxes) - padding)
    top = max(0, min(box[1] for box in boxes) - padding)
    right = min(frames[0].width, max(box[2] for box in boxes) + padding)
    bottom = min(frames[0].height, max(box[3] for box in boxes) + padding)
    return left, top, right, bottom


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--ffmpeg", type=Path, required=True)
    parser.add_argument("--duration", type=float, default=10.01)
    parser.add_argument("--count", type=int, default=30)
    parser.add_argument("--frame-width", type=int, default=512)
    args = parser.parse_args()

    args.output.mkdir(parents=True, exist_ok=True)
    decoded = decode_frames(args.ffmpeg, args.source, 1280, 720, args.count, args.duration)
    keyed = [key_frame(frame) for frame in decoded]
    bounds = union_bounds(keyed)
    cropped = [frame.crop(bounds) for frame in keyed]
    ratio = args.frame_width / cropped[0].width
    frame_size = (args.frame_width, round(cropped[0].height * ratio))
    resized = [frame.resize(frame_size, Image.Resampling.LANCZOS) for frame in cropped]

    columns = 5
    rows = (args.count + columns - 1) // columns
    atlas = Image.new("RGBA", (frame_size[0] * columns, frame_size[1] * rows))
    for index, frame in enumerate(resized):
        atlas.alpha_composite(frame, ((index % columns) * frame_size[0], (index // columns) * frame_size[1]))
    atlas.save(args.output / "sleeping_npc_idle_30f.png", optimize=True)
    resized[0].save(args.output / "sleeping_npc_idle_preview.png", optimize=True)
    print(f"frames={args.count} frame_size={frame_size[0]}x{frame_size[1]} atlas={atlas.width}x{atlas.height} crop={bounds}")


if __name__ == "__main__":
    main()
