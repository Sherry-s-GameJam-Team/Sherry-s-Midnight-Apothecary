class_name PotionEffectText
extends RefCounted

static func describe(effect_id: StringName) -> String:
	match effect_id:
		&"attack": return "强化攻击"
		&"speed": return "提升行动速度"
		&"purify": return "净化异常状态"
		&"healing": return "恢复生命与伤势"
		&"shield": return "生成防护屏障"
		&"mana": return "恢复魔力"
		&"concealment": return "提供隐匿效果"
		&"lightning_meteor": return "召唤雷击与星陨"
		_: return "无稳定药效"
