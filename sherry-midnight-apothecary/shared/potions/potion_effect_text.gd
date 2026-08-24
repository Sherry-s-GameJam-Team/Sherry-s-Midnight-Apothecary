class_name PotionEffectText
extends RefCounted

static func describe(effect_id: StringName) -> String:
	match effect_id:
		&"attack": return "形成高压冲击并震散目标"
		&"speed": return "活化目标并提升行动速度"
		&"purify": return "净化异常状态"
		&"healing": return "修复伤势并促进再生"
		&"shield": return "生成调衡防护屏障"
		&"mana": return "恢复魔力"
		&"buffer": return "缓冲伤害、击退与环境震荡"
		&"calm": return "镇静精神并降低敌意"
		&"concealment": return "降低自身被感知程度"
		&"lightning_meteor": return "释放冲击放电"
		_: return "无稳定药效"


static func describe_potion(potion: PotionData) -> String:
	if potion == null:
		return "无稳定药效"
	var descriptions: Array[String] = []
	var effect_ids: Array[StringName] = potion.combat_effect_ids if not potion.combat_effect_ids.is_empty() else [potion.main_effect_id]
	for effect_id: StringName in effect_ids:
		var value := describe(effect_id)
		if not descriptions.has(value):
			descriptions.append(value)
	return "；".join(descriptions)
