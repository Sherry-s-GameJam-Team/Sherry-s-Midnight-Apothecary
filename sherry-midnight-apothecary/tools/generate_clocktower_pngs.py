import math
import os
from PIL import Image, ImageDraw

OUTPUT_DIR = r"c:\Users\jisub\Documents\Sherry’s Midnight Apothecary 雪莉的午夜药水铺\sherry-midnight-apothecary\day\levels\Aurem Clockyard\src\mechanisms"
os.makedirs(OUTPUT_DIR, exist_ok=True)

def generate_giant_spring():
    img = Image.new("RGBA", (200, 300), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    # Base
    draw.rounded_rectangle([30, 260, 170, 290], radius=8, fill=(212, 175, 55, 255), outline=(58, 34, 5, 255), width=3)
    draw.rounded_rectangle([50, 240, 150, 260], radius=4, fill=(139, 90, 43, 255), outline=(58, 34, 5, 255), width=2)
    # Center shaft
    draw.rounded_rectangle([90, 40, 110, 240], radius=6, fill=(180, 140, 40, 255), outline=(58, 34, 5, 255), width=2)
    # Coils
    for y in range(60, 230, 32):
        draw.ellipse([45, y, 155, y + 26], fill=(255, 170, 0, 230), outline=(212, 175, 55, 255), width=4)
        draw.ellipse([65, y + 4, 135, y + 22], fill=(255, 220, 100, 180))
    # Top Cap
    draw.ellipse([85, 25, 115, 55], fill=(212, 175, 55, 255), outline=(58, 34, 5, 255), width=3)
    draw.ellipse([93, 33, 107, 47], fill=(255, 120, 0, 255))
    img.save(os.path.join(OUTPUT_DIR, "giant_spring.png"))

def generate_gear_spirit():
    img = Image.new("RGBA", (100, 100), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    cx, cy, r = 50, 50, 36
    # Gear teeth
    for i in range(12):
        ang = i * (math.pi / 6)
        tx = cx + math.cos(ang) * 44
        ty = cy + math.sin(ang) * 44
        draw.rectangle([tx - 5, ty - 5, tx + 5, ty + 5], fill=(212, 140, 0, 255), outline=(60, 30, 0, 255), width=2)
    # Body
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(230, 160, 20, 255), outline=(60, 30, 0, 255), width=3)
    draw.ellipse([cx - 24, cy - 24, cx + 24, cy + 24], fill=(50, 30, 10, 255), outline=(255, 180, 0, 255), width=2)
    # Eyes
    draw.ellipse([40, 42, 46, 54], fill=(255, 230, 50, 255))
    draw.ellipse([54, 42, 60, 54], fill=(255, 230, 50, 255))
    img.save(os.path.join(OUTPUT_DIR, "gear_spirit.png"))

def generate_retro_clockbird():
    img = Image.new("RGBA", (120, 90), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    # Body
    draw.ellipse([30, 25, 90, 65], fill=(255, 160, 0, 255), outline=(78, 44, 0, 255), width=3)
    # Wing
    draw.polygon([(45, 40), (25, 20), (60, 15), (70, 30)], fill=(255, 200, 50, 255), outline=(78, 44, 0, 255))
    # Head & beak
    draw.ellipse([75, 20, 100, 48], fill=(255, 160, 0, 255), outline=(78, 44, 0, 255), width=2)
    draw.polygon([(98, 30), (116, 35), (98, 42)], fill=(255, 220, 50, 255), outline=(78, 44, 0, 255))
    # Eye
    draw.ellipse([86, 28, 93, 35], fill=(255, 30, 60, 255))
    # Tail
    draw.polygon([(35, 45), (10, 60), (25, 40)], fill=(180, 100, 0, 255), outline=(78, 44, 0, 255))
    img.save(os.path.join(OUTPUT_DIR, "retro_clockbird.png"))

def generate_beat_light():
    img = Image.new("RGBA", (60, 90), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    # Mount
    draw.rectangle([25, 0, 35, 20], fill=(78, 52, 46, 255), outline=(39, 28, 25, 255), width=2)
    draw.polygon([(15, 20), (45, 20), (50, 30), (10, 30)], fill=(188, 170, 164, 255), outline=(62, 39, 35, 255), width=2)
    # Glass Dome
    draw.ellipse([10, 26, 50, 66], fill=(255, 150, 0, 200), outline=(255, 213, 79, 255), width=3)
    draw.ellipse([22, 38, 38, 54], fill=(255, 255, 200, 255))
    draw.rectangle([22, 65, 38, 77], fill=(93, 64, 55, 255), outline=(39, 28, 25, 255), width=2)
    img.save(os.path.join(OUTPUT_DIR, "beat_light.png"))

def generate_clock_hands():
    # Hour hand (70, 360)
    img_h = Image.new("RGBA", (70, 360), (0, 0, 0, 0))
    draw_h = ImageDraw.Draw(img_h)
    draw_h.ellipse([7, 297, 63, 353], fill=(212, 175, 55, 255), outline=(43, 26, 0, 255), width=4)
    draw_h.polygon([(24, 325), (26, 160), (15, 130), (35, 40), (55, 130), (44, 160), (46, 325)], fill=(212, 175, 55, 255), outline=(43, 26, 0, 255), width=3)
    draw_h.polygon([(35, 10), (46, 45), (24, 45)], fill=(255, 215, 0, 255), outline=(43, 26, 0, 255), width=2)
    img_h.save(os.path.join(OUTPUT_DIR, "clock_hand_hour.png"))

    # Minute hand (70, 480)
    img_m = Image.new("RGBA", (70, 480), (0, 0, 0, 0))
    draw_m = ImageDraw.Draw(img_m)
    draw_m.ellipse([7, 417, 63, 473], fill=(224, 184, 56, 255), outline=(43, 26, 0, 255), width=4)
    draw_m.polygon([(27, 445), (29, 180), (18, 140), (35, 30), (52, 140), (41, 180), (43, 445)], fill=(224, 184, 56, 255), outline=(43, 26, 0, 255), width=3)
    draw_m.polygon([(35, 5), (48, 35), (22, 35)], fill=(0, 229, 255, 255), outline=(43, 26, 0, 255), width=2)
    img_m.save(os.path.join(OUTPUT_DIR, "clock_hand_minute.png"))

def generate_synchronizer_rings():
    img = Image.new("RGBA", (400, 400), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    cx, cy = 200, 200
    # Dial plate
    draw.ellipse([10, 10, 390, 390], fill=(26, 18, 11, 240), outline=(212, 175, 55, 255), width=8)
    # Outer Ring
    draw.ellipse([50, 50, 350, 350], outline=(255, 111, 0, 255), width=8)
    # Middle Ring
    draw.ellipse([95, 95, 305, 305], outline=(255, 213, 79, 255), width=6)
    # Inner Ring
    draw.ellipse([140, 140, 260, 260], outline=(0, 229, 255, 255), width=6)
    # Top Marker
    draw.polygon([(200, 8), (190, 28), (210, 28)], fill=(255, 215, 0, 255), outline=(255, 111, 0, 255), width=2)
    # Center Hub
    draw.ellipse([176, 176, 224, 224], fill=(62, 39, 35, 255), outline=(255, 213, 79, 255), width=4)
    draw.ellipse([190, 190, 210, 210], fill=(255, 215, 0, 255))
    img.save(os.path.join(OUTPUT_DIR, "synchronizer_rings.png"))

if __name__ == "__main__":
    generate_giant_spring()
    generate_gear_spirit()
    generate_retro_clockbird()
    generate_beat_light()
    generate_clock_hands()
    generate_synchronizer_rings()
    print("ALL PNGs GENERATED SUCCESSFULLY")
