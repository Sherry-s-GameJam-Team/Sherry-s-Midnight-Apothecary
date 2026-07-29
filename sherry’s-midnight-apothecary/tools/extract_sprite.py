import os
import sys
import cv2
import numpy as np

VIDEO = sys.argv[1] if len(sys.argv) > 1 else r"C:\Users\jisub\Desktop\idle.mp4"
OUT = r"C:\Users\jisub\Desktop\spite"
PREFIX = sys.argv[2] if len(sys.argv) > 2 else "idle"

os.makedirs(OUT, exist_ok=True)
cap = cv2.VideoCapture(VIDEO)
count = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))

indices = np.linspace(0, count - 1, 12).round().astype(int)

for frame_no, idx in enumerate(indices, 1):
    cap.set(cv2.CAP_PROP_POS_FRAMES, int(idx))
    ok, frame = cap.read()
    if not ok:
        continue

    # Run GrabCut on a smaller copy, then bring the matte back to full resolution.
    scale = 0.35
    small = cv2.resize(frame, (round(width * scale), round(height * scale)), interpolation=cv2.INTER_AREA)
    sw, sh = small.shape[1], small.shape[0]
    mask = np.full((sh, sw), cv2.GC_BGD, np.uint8)
    x0, y0, x1, y1 = round(520 * scale), round(2 * scale), round(1400 * scale), round((height - 2) * scale)
    mask[y0:y1, x0:x1] = cv2.GC_PR_FGD
    # The outer border is known background; the center is probable foreground.
    mask[round(8 * scale):round((height - 25) * scale), round(700 * scale):round(1235 * scale)] = cv2.GC_FGD
    bgd = np.zeros((1, 65), np.float64)
    fgd = np.zeros((1, 65), np.float64)
    cv2.grabCut(small, mask, None, bgd, fgd, 4, cv2.GC_INIT_WITH_MASK)
    alpha_small = np.where((mask == cv2.GC_FGD) | (mask == cv2.GC_PR_FGD), 255, 0).astype(np.uint8)
    alpha = cv2.resize(alpha_small, (width, height), interpolation=cv2.INTER_CUBIC)

    # Remove small islands and soften the matte edge for clean animation frames.
    kernel = np.ones((3, 3), np.uint8)
    alpha = cv2.morphologyEx(alpha, cv2.MORPH_OPEN, kernel, iterations=1)
    alpha = cv2.morphologyEx(alpha, cv2.MORPH_CLOSE, kernel, iterations=2)
    alpha = cv2.GaussianBlur(alpha, (3, 3), 0)

    # Clear pale background/shadow regions that are connected to the image border.
    hsv = cv2.cvtColor(frame, cv2.COLOR_BGR2HSV)
    pale = ((hsv[:, :, 1] < 45) & (hsv[:, :, 2] > 170)).astype(np.uint8)
    n, labels, stats, _ = cv2.connectedComponentsWithStats(pale, 8)
    border_labels = set()
    for x, y, w, h, area in stats[1:]:
        if x == 0 or y == 0 or x + w >= width or y + h >= height:
            border_labels.add(len(border_labels))
    if border_labels:
        border_mask = np.zeros_like(pale)
        for label in range(1, n):
            x, y, w, h, area = stats[label]
            if x == 0 or y == 0 or x + w >= width or y + h >= height:
                border_mask[labels == label] = 1
        alpha[border_mask > 0] = 0

    # Use one generous, stable crop for every frame so the hat and limbs stay intact.
    left, top, right, bottom = 500, 0, 1400, height

    bgr = frame[top:bottom, left:right]
    a = alpha[top:bottom, left:right]
    bgra = cv2.cvtColor(bgr, cv2.COLOR_BGR2BGRA)
    bgra[:, :, 3] = a
    out_path = os.path.join(OUT, f"{PREFIX}_{frame_no:02d}.png")
    cv2.imwrite(out_path, bgra)

cap.release()
print(f"wrote {len(indices)} frames to {OUT}")
