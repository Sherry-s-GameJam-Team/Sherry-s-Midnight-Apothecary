Grail-Lily / 圣杯百合

Source files:
- flower.png
- leaf01.png
- leaf02.png
- leaf03.png
- leaf04.png
- main.png

The supplied 4096x4096 decomposition exports contained opaque white canvas areas
and unrelated solid black export rectangles. Project sprites were extracted with
the imagegen background-extraction workflow, using a flat #ff00ff chroma key,
then converted to alpha PNGs with remove_chroma_key.py.

Flower gameplay effect:
- base quality: 1.10
- flower quality multiplier: 1.35
- resulting flower-piece quality: 1.485 (before grinding quality factor)
