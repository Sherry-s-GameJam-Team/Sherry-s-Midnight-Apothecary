with open('characters/sherry/sherry_animations.tres', 'r', encoding='utf-8') as f:
    text = f.read()

cast_old = '"values": [Vector2(1, 1), Vector2(1, 1), Vector2(1, 1), Vector2(1, 1), Vector2(1, 1), Vector2(1, 1), Vector2(1, 1), Vector2(1, 1), Vector2(1, 1), Vector2(1, 1), Vector2(1, 1), Vector2(1, 1), Vector2(1, 1), Vector2(1, 1), Vector2(1, 1), Vector2(1, 1), Vector2(1, 1), Vector2(1, 1), Vector2(1, 1), Vector2(1, 1), Vector2(1, 1), Vector2(1, 1), Vector2(1, 1), Vector2(1, 1), Vector2(1, 1), Vector2(1, 1), Vector2(1, 1), Vector2(1, 1), Vector2(1, 1), Vector2(1, 1)]'
cast_new = '"values": [Vector2(0.45765, 0.45765), Vector2(0.45765, 0.45765), Vector2(0.45765, 0.45765), Vector2(0.45765, 0.45765), Vector2(0.45765, 0.45765), Vector2(0.45765, 0.45765), Vector2(0.45765, 0.45765), Vector2(0.45765, 0.45765), Vector2(0.45765, 0.45765), Vector2(0.45765, 0.45765), Vector2(0.45765, 0.45765), Vector2(0.45765, 0.45765), Vector2(0.45765, 0.45765), Vector2(0.45765, 0.45765), Vector2(0.45765, 0.45765), Vector2(0.45765, 0.45765), Vector2(0.45765, 0.45765), Vector2(0.45765, 0.45765), Vector2(0.45765, 0.45765), Vector2(0.45765, 0.45765), Vector2(0.45765, 0.45765), Vector2(0.45765, 0.45765), Vector2(0.45765, 0.45765), Vector2(0.45765, 0.45765), Vector2(0.45765, 0.45765), Vector2(0.45765, 0.45765), Vector2(0.45765, 0.45765), Vector2(0.45765, 0.45765), Vector2(0.45765, 0.45765), Vector2(0.45765, 0.45765)]'

castr_old = '"values": [Vector2(-1, 1), Vector2(-1, 1), Vector2(-1, 1), Vector2(-1, 1), Vector2(-1, 1), Vector2(-1, 1), Vector2(-1, 1), Vector2(-1, 1), Vector2(-1, 1), Vector2(-1, 1), Vector2(-1, 1), Vector2(-1, 1), Vector2(-1, 1), Vector2(-1, 1), Vector2(-1, 1), Vector2(-1, 1), Vector2(-1, 1), Vector2(-1, 1), Vector2(-1, 1), Vector2(-1, 1), Vector2(-1, 1), Vector2(-1, 1), Vector2(-1, 1), Vector2(-1, 1), Vector2(-1, 1), Vector2(-1, 1), Vector2(-1, 1), Vector2(-1, 1), Vector2(-1, 1), Vector2(-1, 1)]'
castr_new = '"values": [Vector2(-0.45765, 0.45765), Vector2(-0.45765, 0.45765), Vector2(-0.45765, 0.45765), Vector2(-0.45765, 0.45765), Vector2(-0.45765, 0.45765), Vector2(-0.45765, 0.45765), Vector2(-0.45765, 0.45765), Vector2(-0.45765, 0.45765), Vector2(-0.45765, 0.45765), Vector2(-0.45765, 0.45765), Vector2(-0.45765, 0.45765), Vector2(-0.45765, 0.45765), Vector2(-0.45765, 0.45765), Vector2(-0.45765, 0.45765), Vector2(-0.45765, 0.45765), Vector2(-0.45765, 0.45765), Vector2(-0.45765, 0.45765), Vector2(-0.45765, 0.45765), Vector2(-0.45765, 0.45765), Vector2(-0.45765, 0.45765), Vector2(-0.45765, 0.45765), Vector2(-0.45765, 0.45765), Vector2(-0.45765, 0.45765), Vector2(-0.45765, 0.45765), Vector2(-0.45765, 0.45765), Vector2(-0.45765, 0.45765), Vector2(-0.45765, 0.45765), Vector2(-0.45765, 0.45765), Vector2(-0.45765, 0.45765), Vector2(-0.45765, 0.45765)]'

def replace_in_anim(text, anim_id, old_str, new_str):
    header = f'[sub_resource type="Animation" id="{anim_id}"]'
    start = text.find(header)
    if start == -1:
        print(f"Header {anim_id} not found!")
        return text
    next_sub = text.find('[sub_resource', start + len(header))
    if next_sub == -1:
        next_sub = text.find('[resource', start + len(header))
    section = text[start:next_sub]
    if old_str not in section:
        print(f"old_str not found in {anim_id}!")
        return text
    new_section = section.replace(old_str, new_str)
    return text[:start] + new_section + text[next_sub:]

text = replace_in_anim(text, "Animation_cast", cast_old, cast_new)
text = replace_in_anim(text, "Animation_cast_right", castr_old, castr_new)

with open('characters/sherry/sherry_animations.tres', 'w', encoding='utf-8') as f:
    f.write(text)

print("Done patching cast animations!")
