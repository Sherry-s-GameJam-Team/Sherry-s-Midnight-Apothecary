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

# The clinical requirement stays explicit below each line, while these profiles
# give every recurring patient a stable voice across diagnosis and outcomes.
const DIALOGUE_PROFILES := {
	&"young_villager": {
		"case_lines": [
			"雪莉，我明明睡了一整夜，腿却像还留在梦里。今天干活时差点把麦筐扣在自己头上。",
			"身上有力气了，可一忙起来就又虚得发抖。我想把这点劲真正留住。",
			"我现在能一口气跑过田埂，可心口总像慢半拍。这应该不是我想多了吧？",
			"力气是回来了，脑子却不肯停。晚上一闭眼，连羊都在梦里追我。",
		],
		"mature_line": "我又有个新毛病。我记着你说过别硬撑，所以这回第一个就来找你了。",
		"worsened_line": "上次喝完更难受了。我不是来怪你的……我就是有点害怕。",
		"feedback": ["对，就是这种感觉！像终于从冷被窝里爬出来了。", "好多了，明天应该能正常干活。我过一天再来让你看看。", "是有点用……不过还像少了一把劲。", "唉，还是一样。我明天再来，你可别忘了我。", "等等，心跳得不对……这瓶不能再喝了！", "那股阴冷一下子散了。雪莉，你真的救了我。"],
		"revisit": "我会照你说的休息，过一两天再来。",
		"refusal": "好吧……那我先回去撑一撑。两天后你要记得我啊。",
		"lost": "我每次都是抱着希望来的。算了，以后不麻烦你了。",
	},
	&"herbalist": {
		"case_lines": ["这不是普通山雾。它粘在指节和舌根上，我试过三种解毒叶，都只能压住表层。", "表层污染已经褪了，但冷意正在沿着手臂往上走。这次需要让药性更平稳。", "污染没再扩散，残留物却在灼痛。别用麻痹欺骗它，我们要一起把根拔出来。", "身体已经干净，睡着后却还能闻到那股雾。现在要处理的是它留下的印记。"],
		"mature_line": "我带来了新的症状记录。先别看我的结论，说说你从脉象里看到了什么。",
		"worsened_line": "上次配方把污染推得更深了。先别道歉，把每个步骤重新记一遍，我们找出偏差。",
		"feedback": ["主副药性咬合得很好。这是一瓶可以写进药典的配方。", "主症已经被压住，走向正确。明日我再带记录来。", "有效，但副药性衰减得太快。这次只能算试剂。", "污染没有反应。明天重配，并且保留今晚的数据。", "停。这个效果会加速污染，立刻封存剩余药液。", "污染核已经析出。纯度很高——我承认，这次你比我更准。"],
		"revisit": "我会记录体温、痛感和污染纹路，一至两天后复查。",
		"refusal": "我理解药材不足，但病情不会等人。两天后我带自己的样本再来。",
		"lost": "一名药师可以拒绝配方，却不能一再拒绝病人。我会另找同行。",
	},
	&"blacksmith": {
		"case_lines": ["炉子没熄，我这双手先熄火了。别给我什么甜水，来点真能顶事的。", "力气回来了，可胸口一抡锤就响得像风箱。给这台老机器加点火。", "火劲太散，手还在抖。好钢要收着打，人也一样。", "手稳了，肩膀里那道旧裂口又在疼。这次得真正补上它。"],
		"mature_line": "新毛病，旧身子。你看需要添火、回火，还是整块重锻。",
		"worsened_line": "上次那瓶把小毛病烧成了大窟窿。今晚别猜，看准了再下锤。",
		"feedback": ["好！这才叫正火候。手稳，气也顺。", "能用。还没到出炉的时候，我明天再来回一次火。", "管点用，但锤子还是拎不稳。", "不行，这火根本没烧进去。明天再来。", "呕——这是治人还是淬剑？快拿开！", "像把渣子从铁水里全撗了出去。这手艺，我服。"],
		"revisit": "我会少打两炉铁。一两天后来给你验货。",
		"refusal": "今晚不接这活？行，我自己扛两天。",
		"lost": "打不出的铁就别反复进炉。我不会再来了。",
	},
	&"scholar": {
		"case_lines": ["请容我纠正：这不是‘眼花’，是墨迹在视野边缘自行重排。某种诅咒语法正在穿过我。", "诅咒主体已被除去，但眼后的刺痛仍然保留着它的断句。", "疼痛消退后，那些字开始在梦里朗读自己。这已经是精神层面的残响。", "我不再看到字，却会在清醒时突然失去方向感。需要为精神建立一个稳定的边界。"],
		"mature_line": "我将新症状按发作时间编了索引。当然，临床判断仍交给你。",
		"worsened_line": "上次的药效引发了一条新的注释——它正在我的视野里反复书写‘错误’。",
		"feedback": ["完全吻合。症状像被删去的错误段落一样消失了。", "主要症状已得到控制。我会在明日的附录中记录后续变化。", "有限有效。若是论文，这个结论还不足以通过审查。", "结果不支持我们的假设。明天应当更换配方。", "这不是误差，是危险反应。请立即中止。", "黑魔法的核心结构消失了。这值得一篇独立论文——共同署名，如何？"],
		"revisit": "我会继续记录视觉与梦境样本，一至两日后复诊。",
		"refusal": "可惜。我会将本次记为‘无法取得治疗’，两日后再来。",
		"lost": "连续的拒绝已经足以形成结论。我将停止这项临床尝试。",
	},
	&"ranger": {
		"case_lines": ["林子里的东西抓了我。伤口不深，黑纹却在走。先让肉长回来。", "伤口开始合了，黑纹没停。先除脏东西，再护住新肉。", "污染退了三寸，伤口边缘还是灰的。这次让它干净地长好。", "伤口没事了，但黑纹曾经走过的地方会突然发冷。得把残留锁住。"],
		"mature_line": "又有新伤。我说症状，你选药；像以前一样。",
		"worsened_line": "黑纹比昨天多了一指宽。上次那种药性，不能再碰。",
		"feedback": ["黑纹停了，伤口也在收。准。", "稳住了。我明天巡林后再来。", "有效，但不够。今晚我会离林线远点。", "没变化。明天换一种。", "黑纹动了。把药拿走，现在。", "它死了。不是蛰伏，是彻底消失。好药。"],
		"revisit": "我会标记黑纹边缘。一两天后来对照。",
		"refusal": "知道了。我会自己包扎，两天后再来。",
		"lost": "我不能再把性命押在一扇不会开的门上。告辞。",
	},
	&"town_guard": {
		"case_lines": ["执勤时扭了脚。我还能站岗，但这种肿法撑不过两轮换防。", "脚踝一落地就疼。先压住痛感，再让拉伤复原。", "肿消了，旧伤在长时间站立后还会抽痛。治好它，别只让我感觉不到。", "伤处已经恢复，但关节在石路上仍会打晃。我需要它重新稳住。"],
		"mature_line": "报告新症状。不影响交接班，但需要尽快处理。",
		"worsened_line": "报告：上次用药后症状升级。我不追究失误，但今晚必须纠正。",
		"feedback": ["肿痛和失稳同时缓解。处置准确，谢谢。", "已恢复到可执勤状态。明日下岗后复诊。", "可以行走，但还不能追人。需要继续处理。", "症状未解除。我会申请换岗，明天再来。", "伤处正在恶化。立即停药，这是命令。", "异常污染完全清除。我会向守备队正式推荐你。"],
		"revisit": "我会减少巡逻路线，一至两天后按时报到。",
		"refusal": "收到。我会登记为未受理，两天后再来。",
		"lost": "多次求助未被受理。从今天起，我将改用守备队的医疗渠道。",
	},
	&"innkeeper": {
		"case_lines": ["客人们说炉火很暖，可我吸进去的全是烟。今晚还要煮汤，先帮我把嗓子清干净吧。", "烟已经淡了，喝水时却像吞了热砂。这次先让它别那么疼。", "喉咙不烧了，每次咳嗽还是会带出灰味。得把剩下的烟彻底清掉。", "烟尘没了，嗓子却被折腾得像旧围裙。该把损伤补回来了。"],
		"mature_line": "开店的人总有新毛病，就像旅店总有新客人。今晚又得麻烦你了。",
		"worsened_line": "上次那瓶下去，可把小火苗扇成大火了。我不生气，咱们今晚仔细点就好。",
		"feedback": ["哎呀，嗓子一下就亮堂了。今晚的热汤算我请你。", "舒服多了。我明天关门时再过来让你听听。", "能顺气了，但说话还是疼。咱们再慢慢调。", "还是咳得厉害。明天我让伙计早点看店。", "咳、咳——不对，这下连气都吸不进去了！", "那股烟油味彻底没了。这不是普通药水，是救命的手艺。"],
		"revisit": "我会把炉门开小些，一两天后带热汤来复诊。",
		"refusal": "今晚太忙了，对吧？没事，我先回去煮点梨水，两天后再来。",
		"lost": "我也是开店的，知道什么叫照顾不过来。可我不能再等了。保重吧，雪莉。",
	},
	&"monk": {
		"case_lines": ["钟楼今夜没有敲钟，我却听见了第十三声。那不是神谕。请先清除它留在我身上的污秽。", "污秽已离开血肉，钟声却仍在梦中回响。我需要安静，不是遗忘。", "梦境安静了，醒来时灵魂却仍蒙着灰。先使心神安定，再除去最后的阴影。", "黑暗已经离去，可我七日未曾真正入睡。今夜，我只求一场没有钟声的深眠。"],
		"mature_line": "新的试炼已至。我会如实陈述身心之变，请你以药理作答。",
		"worsened_line": "上次的药使钟声更近了。它现在会在我开口前，替我说出第一个字。",
		"feedback": ["内外皆归于宁定。这瓶药中有精确，也有怜悯。", "阴影已退至门外。明日我将再来，确认它不会返回。", "安静只维持了片刻。但片刻也是恩惠。", "钟声未停。我会守夜至天明，然后再来。", "这药在喂养那道声音。快移开它，在它学会你的名字之前。", "污秽的核心已被洗净。今夜的钟声，终于只会来自钟楼。"],
		"revisit": "我会记下每一次钟声与梦醒，一至两日后归来。",
		"refusal": "今夜的门未为我打开。我接受，并在两日后再次叩门。",
		"lost": "连续的沉默也是一种回答。我不会再来了。愿你的灯仍为别人亮着。",
	},
}


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
	var profile: Dictionary = DIALOGUE_PROFILES.get(StringName(str(patient.npc_id)), {})
	var secondary_text := "，并以%s辅助" % EFFECT_NAMES.get(secondary, str(secondary)) if secondary != &"" else ""
	var case_lines: Array = profile.get("case_lines", [])
	var spoken_line := str(profile.get("mature_line", "我想请你再看看这次的症状。")) if mature else str(case_lines[mini(stage_index, case_lines.size() - 1)]) if not case_lines.is_empty() else "我想请你看看这次的症状。"
	if branch == "worsened":
		spoken_line = str(profile.get("worsened_line", "上次用药后症状反而加重了。"))
	var request := "%s\n诊疗需求：以%s为主%s，药力按%d级病情控制。" % [spoken_line, EFFECT_NAMES.get(primary, str(primary)), secondary_text, severity]
	if wants_special:
		request += " 若能使用高纯蓝强净化配方最好。"
	var lines: Array = profile.get("feedback", [])
	return {
		"event_id": event_id, "npc_id": patient.npc_id, "name": patient.name,
		"identity": patient.identity, "start_day": patient.start_day, "modifier": patient.modifier,
		"request": request, "visible_symptoms": (patient.symptoms as Array).duplicate(),
		"primary_need": primary, "secondary_need": secondary, "severity": severity,
		"forbidden_effects": forbidden_effects,
		"preferred_special_potion_id": &"purification_potion" if wants_special else &"",
		"case_stage": stage_index, "case_branch": branch, "mature_case": mature,
		"revisit_note": str(profile.get("revisit", "请在一至两天后回来复诊。")), "feedback_lines": lines,
		"refusal_line": str(profile.get("refusal", "我会在两天后再来。")),
		"permanent_departure_line": str(profile.get("lost", "我不会再来了。")),
		"portrait": PORTRAITS.get(patient.npc_id), "success_flag": str(event_id) + "_resolved",
		"is_due_followup": int(state.get("visit_count", 0)) > 0,
	}


static func _patient_index(npc_id: StringName) -> int:
	for index in range(PATIENTS.size()):
		if PATIENTS[index].npc_id == npc_id:
			return index
	return 0
