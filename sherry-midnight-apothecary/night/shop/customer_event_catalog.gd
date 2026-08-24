class_name CustomerEventCatalog
extends RefCounted

const EFFECT_IDS: Array[StringName] = [
	&"circulation", &"activation", &"analgesia", &"regeneration",
	&"stabilization", &"purification", &"sedation",
]
const EFFECT_NAMES := {
	&"circulation": "红·循环", &"activation": "橙·活化",
	&"analgesia": "黄·镇痛", &"regeneration": "绿·再生",
	&"stabilization": "青·稳定", &"purification": "蓝·净化",
	&"sedation": "紫·镇静",
}
const EFFECT_UNLOCK_DAY := {
	&"activation": 0, &"regeneration": 0, &"stabilization": 0,
	&"purification": 0, &"analgesia": 2, &"circulation": 3, &"sedation": 5,
}
const NIGHT_CUSTOMER_CAPS: Array[int] = [2, 3, 4, 5, 6, 7, 8, 8]

const PORTRAITS := {
	&"young_villager": preload("res://characters/npcs/01_young_villager/frontal_bust.png"),
	&"herbalist": preload("res://characters/npcs/02_herbalist/frontal_bust.png"),
	&"blacksmith": preload("res://characters/npcs/03_blacksmith/frontal_bust.png"),
	&"scholar": preload("res://characters/npcs/04_scholar/frontal_bust.png"),
	&"monk": preload("res://characters/npcs/05_monk/frontal_bust.png"),
	&"town_guard": preload("res://characters/npcs/06_town_guard/frontal_bust.png"),
	&"ranger": preload("res://characters/npcs/07_ranger/frontal_bust.png"),
	&"innkeeper": preload("res://characters/npcs/08_innkeeper/frontal_bust.png"),
}

const PATIENTS: Array[Dictionary] = [
	{"npc_id":&"young_villager", "name":"米洛·维森", "identity":"夜归的村民", "start_day":0, "modifier":1.00, "symptoms":["乏力", "手脚发凉", "夜间惊醒"], "forbidden":&"sedation", "stages":[[&"activation",&""],[&"activation",&"regeneration"],[&"activation",&"circulation"],[&"sedation",&"activation"]]},
	{"npc_id":&"herbalist", "name":"艾尔莎·罗文", "identity":"山路采药人", "start_day":0, "modifier":1.00, "symptoms":["雾气污染", "指尖发冷", "舌根发涩"], "forbidden":&"circulation", "stages":[[&"purification",&""],[&"purification",&"stabilization"],[&"purification",&"analgesia"],[&"purification",&"sedation"]]},
	{"npc_id":&"blacksmith", "name":"布兰特·霍尔姆", "identity":"炉火铁匠", "start_day":1, "modifier":1.05, "symptoms":["过劳", "手臂颤抖", "炉热反噬"], "forbidden":&"sedation", "stages":[[&"activation",&""],[&"activation",&"circulation"],[&"stabilization",&"activation"],[&"regeneration",&"activation"]]},
	{"npc_id":&"scholar", "name":"尤利安·维尔德", "identity":"旧卷学者", "start_day":1, "modifier":1.05, "symptoms":["诅咒墨迹", "眼后刺痛", "字迹幻动"], "forbidden":&"circulation", "stages":[[&"purification",&""],[&"purification",&"analgesia"],[&"sedation",&"purification"],[&"stabilization",&"sedation"]]},
	{"npc_id":&"ranger", "name":"凯尔·阿登", "identity":"常霁区巡林人", "start_day":1, "modifier":1.10, "symptoms":["抓伤", "黑纹扩散", "伤口发冷"], "forbidden":&"activation", "stages":[[&"regeneration",&""],[&"purification",&"regeneration"],[&"regeneration",&"purification"],[&"stabilization",&"purification"]]},
	{"npc_id":&"town_guard", "name":"莱昂·格雷夫", "identity":"街道守卫", "start_day":2, "modifier":1.05, "symptoms":["扭伤", "肿痛", "脚踝不稳"], "forbidden":&"sedation", "stages":[[&"regeneration",&""],[&"analgesia",&"regeneration"],[&"regeneration",&"analgesia"],[&"stabilization",&"regeneration"]]},
	{"npc_id":&"innkeeper", "name":"玛尔塔·贝伦", "identity":"旅店经营者", "start_day":2, "modifier":1.00, "symptoms":["烟尘残留", "喉咙灼痛", "持续咳嗽"], "forbidden":&"sedation", "stages":[[&"purification",&""],[&"analgesia",&"purification"],[&"purification",&"analgesia"],[&"regeneration",&"purification"]]},
	{"npc_id":&"monk", "name":"马提亚斯·埃伯恩", "identity":"第二教廷的修士", "start_day":5, "modifier":1.10, "symptoms":["幻听钟声", "噩梦", "黑魔法污染"], "forbidden":&"activation", "stages":[[&"purification",&""],[&"purification",&"sedation"],[&"sedation",&"purification"],[&"sedation",&"sedation"]]},
]


static func customer_cap_for_day(current_day: int) -> int:
	return NIGHT_CUSTOMER_CAPS[clampi(current_day, 0, NIGHT_CUSTOMER_CAPS.size() - 1)] if current_day < NIGHT_CUSTOMER_CAPS.size() else 8


static func eligible_for_day(current_day: int, _flags: Dictionary, customer_states: Dictionary = {}) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for patient in PATIENTS:
		var npc_id := StringName(str(patient.npc_id))
		var state: Dictionary = customer_states.get(str(npc_id), customer_states.get(npc_id, {}))
		if current_day < int(patient.start_day):
			continue
		if bool(state.get("permanently_lost", false)) or float(state.get("patience", 100.0)) <= 0.0:
			continue
		var next_visit_day := int(state.get("next_visit_day", int(patient.start_day)))
		if int(state.get("visit_count", 0)) > 0 and current_day < next_visit_day:
			continue
		result.append(_case_for(patient, state, current_day))
	return result


static func _case_for(patient: Dictionary, state: Dictionary, current_day: int) -> Dictionary:
	var stages: Array = patient.stages
	var stage_index := maxi(int(state.get("case_stage", 0)), 0)
	var mature := stage_index >= stages.size() and current_day >= 8
	var pair: Array
	if mature:
		var seed := current_day * 17 + int(state.get("visit_count", 0)) * 7 + _patient_index(StringName(str(patient.npc_id))) * 11
		pair = [EFFECT_IDS[posmod(seed, 7)], EFFECT_IDS[posmod(floori(float(seed) / 7.0) + seed, 7)]]
	else:
		stage_index = mini(stage_index, stages.size() - 1)
		pair = (stages[stage_index] as Array).duplicate()
		while pair.size() > 1 and pair[1] != &"" and current_day < int(EFFECT_UNLOCK_DAY.get(pair[1], 0)) and stage_index > 0:
			stage_index -= 1
			pair = (stages[stage_index] as Array).duplicate()
	var primary := StringName(str(pair[0]))
	var secondary := StringName(str(pair[1])) if pair.size() > 1 else &""
	var branch := str(state.get("case_branch", "normal"))
	var base_severity := 1 if current_day <= 1 else 2 if current_day <= 4 else 3
	var severity := clampi(base_severity + (1 if branch == "worsened" else 0), 1, 3)
	var forbidden_effects: Array[StringName] = []
	if current_day >= 4 and StringName(str(patient.forbidden)) not in [primary, secondary]:
		forbidden_effects.append(StringName(str(patient.forbidden)))
	var wants_special: bool = current_day >= 6 and StringName(str(patient.npc_id)) == &"herbalist" and primary == &"purification"
	var event_id := StringName("%s_case_%d_%s" % [patient.npc_id, stage_index, branch])
	var secondary_text := "，并以%s辅助" % EFFECT_NAMES.get(secondary, str(secondary)) if secondary != &"" else ""
	var branch_text := "上次用药后反而加重了，" if branch == "worsened" else "复诊时仍有残留，" if int(state.get("visit_count", 0)) > 0 else ""
	var request := "%s我需要以%s为主%s的药。药力请按%d级病情控制。" % [branch_text, EFFECT_NAMES.get(primary, str(primary)), secondary_text, severity]
	if wants_special:
		request += " 若能使用高纯蓝强净化配方最好。"
	var lines := ["主症和伴随症状都在消退，这次配得很准确。", "主要问题已经稳住，剩下的需要下次复诊继续观察。", "有一部分缓解，但主副药效还没有完全对上。", "症状没有得到控制，我得尽快回来复诊。", "不对，这股药力正在让症状恶化！", "污染核心被完整清除了，这确实是高纯净化配方。"]
	return {
		"event_id": event_id, "npc_id": patient.npc_id, "name": patient.name,
		"identity": patient.identity, "start_day": patient.start_day, "modifier": patient.modifier,
		"request": request, "visible_symptoms": (patient.symptoms as Array).duplicate(),
		"primary_need": primary, "secondary_need": secondary, "severity": severity,
		"forbidden_effects": forbidden_effects,
		"preferred_special_potion_id": &"purification_potion" if wants_special else &"",
		"case_stage": stage_index, "case_branch": branch, "mature_case": mature,
		"revisit_note": "请在一至两天后回来复诊。", "feedback_lines": lines,
		"portrait": PORTRAITS.get(patient.npc_id), "success_flag": str(event_id) + "_resolved",
		"is_due_followup": int(state.get("visit_count", 0)) > 0,
	}


static func _patient_index(npc_id: StringName) -> int:
	for index in range(PATIENTS.size()):
		if PATIENTS[index].npc_id == npc_id:
			return index
	return 0
