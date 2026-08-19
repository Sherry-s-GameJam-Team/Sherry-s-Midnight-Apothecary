import os, re
from PIL import Image

with open('characters/sherry/sherry_animations.tres', 'r', encoding='utf-8') as f:
    content = f.read()

tex_map = {}
for m in re.finditer(r'path="([^"]+)" id="([^"]+)"', content):
    path, id_ = m.group(1), m.group(2)
    local_path = path.replace('res://', '')
    if os.path.exists(local_path) and local_path.endswith('.png'):
        im = Image.open(local_path)
        tex_map[id_] = (path, im.size)

anim_blocks = re.findall(r'(\[sub_resource type="Animation" id="[^"]+"\][\s\S]*?)(?=\n\[sub_resource|\n\[resource|\Z)', content)

for block in anim_blocks:
    name_m = re.search(r'resource_name = "([^"]+)"', block)
    if not name_m:
        continue
    name = name_m.group(1)
    
    texs = re.findall(r'ExtResource\("([^"]+)"\)', block)
    sizes = set(tex_map[t][1] for t in texs if t in tex_map)
    
    scale_m = re.search(r'path = NodePath\("SherrySprite/SherryVisual:scale"\)[\s\S]*?"values": \[([^\]]+)\]', block)
    if scale_m:
        vals = [v.strip() for v in scale_m.group(1).split(',')]
        unique_vals = list(set(vals[:10]))
    else:
        unique_vals = ['NONE']
    
    print(f'{name:<22} Sizes: {str(sizes):<20} Scale: {unique_vals}')
