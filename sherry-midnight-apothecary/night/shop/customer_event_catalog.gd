class_name CustomerEventCatalog
extends RefCounted

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

static var EVENTS: Array[Dictionary] = [
	_event(&"young_villager_fatigue_01", &"young_villager", "米洛·维森", "夜归的村民", 1, 100, "最近走夜路回家总要歇好几次，手脚也一直发凉。别给我太猛的，明早还得下地。", ["fatigue", "low_energy", "cold_hands"], &"activation", &"circulation", ["gentle"], [], ["volatile"], &"sunrise_tonic", 2, "夜惊与重复梦境", ["从胸口开始暖起来了……不是猛地发热，是整个人慢慢有劲了。这个劲儿正好，不会顶得难受。", "精神是回来了，就是手脚还是有点凉。不过比刚才强多了。", "心跳一下快了不少……确实有劲，可这股热来得有点冲。", "好像是有点变化……可我还是提不起劲。这个应该不是治乏力的吧？", "等等，我心跳得也太快了……手都开始抖了！我只是累，不是要去拼命。", "像刚晒到清晨的太阳一样……这不是普通的提神药吧？连手脚都一起暖起来了。"]),
	_event(&"herbalist_mist_01", &"herbalist", "艾尔莎·罗文", "山路采药人", 2, 100, "这几天山雾不对劲，吸进去以后舌根发涩，指尖像泡在冷水里。我还得在山里待一整天。", ["contamination", "chill", "numb_fingers", "metallic_taste"], &"purification", &"stabilization", ["long_duration"], [], ["conductive", "volatile"], &"mountain_mist_ward", 3, "山雾污染样本调查", ["舌根那股涩味散了，指尖也不再发冷。药力很稳，这样我能在山里撑一整天。", "雾气留下的怪味是退了，可冷意还黏在骨头里。净是净了，没完全稳住。", "手指是不冷了，可舌根那股金属味还在。你先压住了症状，雾本身还没清干净。", "这药也许对别的伤有用，可山雾进到身体里的那股涩味一点没退。", "别——这药力像在把雾往里引！这种会导魔、会乱窜的东西不能拿来对付山雾。", "这不是普通净化药……雾还没碰到皮肤就先散了。你从哪学来的这种护山配方？"]),
	_event(&"blacksmith_overwork_01", &"blacksmith", "布兰特·霍尔姆", "炉火铁匠", 2, 105, "明早之前得赶完一批铁件，胳膊已经抬不稳了。给我来点起效快的，可别让我犯困。", ["fatigue", "muscle_weakness", "trembling"], &"activation", &"circulation", ["rapid_action"], ["sedation"], ["anesthetic"], &"forgeheart_tonic", 2, "机械异常闲谈线索", ["热劲一下顶到肩膀，手臂也重新有力了。起效够快，今晚这批铁能赶完。", "精神是上来了，胳膊还是发沉。能干活，但撑不了太久。", "心口是热起来了，可力气来得慢。我要的是能马上抡锤的劲，不是只把血催快。", "酸痛也许轻了点，可我还是没力气。止痛和能不能抡锤子是两回事。", "手是不疼了，可我连锤子都快拿不起来了！我说了明天要干活。", "这股热劲跟炉膛一个节奏……怪了，连锤子都像轻了。你这配方专给铁匠做的？"]),
	_event(&"scholar_cursed_ink_01", &"scholar", "尤利安·维尔德", "学者", 3, 105, "抄旧卷以后眼后总像针扎。更怪的是，有几行字会自己换位置……也许只是我熬夜太久了。", ["headache", "eye_pain", "ink_residue", "moving_letters"], &"purification", &"analgesia", ["gentle"], [], ["conductive", "volatile"], &"lucid_memory_tonic", 3, "禁书与古代符号调查", ["头痛退了……更重要的是，那些字终于停在原来的位置。果然不是单纯熬夜。", "字不动了，这很好。只是眼后还是一阵阵刺痛……污染清了，炎症还在。", "头是不痛了，可我刚才明明看见那一行又换了位置。你先治了症状，没有治那瓶墨。", "困意或暖意都没用。只要那些字还会自己移动，我就知道问题还在。", "停下！墨迹刚才顺着瓶口亮起来了——这药在给它供魔，不是在治疗我。", "不只是字停了……我突然想起这段符号在哪本封存目录里见过。这个药连记忆都理顺了。"]),
	_event(&"monk_phantom_bell_01", &"monk", "马提亚斯·埃伯恩", "第二教廷的修士", 3, 110, "连续三夜，我一闭眼就听见钟声。可修道院的钟根本没有响。昨晚开始，清醒时也能听见了。", ["insomnia", "phantom_sound", "nightmare", "magic_corruption"], &"purification", &"sedation", ["anti_magic"], [], ["conductive"], &"holy_water", 3, "群体梦境污染线索", ["钟声停了。不是远了，是彻底没有了……今晚我应该能真正睡着。", "脑子清静了许多，可一闭眼仍有一点余响。污染像是退了，睡眠还没恢复。", "睡意很重，可钟声仍在梦里敲。你让我睡着了，却没有把它赶出去。", "身体的感觉变了，可那钟声没有变。它不像寻常病痛。", "你把它引得更近了……我现在连睁着眼都能听见。别再用这种导魔药性。", "这是圣水？……钟声像被从房间里整个擦掉了。连我自己都没想到会这么彻底。"]),
	_event(&"town_guard_sprain_01", &"town_guard", "莱昂·格雷夫", "街道守卫", 4, 105, "追人时踩空扭了脚，肿得厉害。今晚还得换岗，能让我走稳就行，别把我弄得昏昏沉沉。", ["sprain", "swelling", "pain", "unstable_ankle"], &"analgesia", &"regeneration", ["rapid_action"], ["sedation"], ["anesthetic"], &"marching_draught", 2, "城内水污染闲谈线索", ["肿痛压下去了，脚踝也能使上力。起效够快，今晚换岗前正好。", "不怎么疼了，可一踩地还是发虚。至少今晚能慢慢走。", "脚踝像是稳了些，可痛得我不敢跑。治好了结构，不代表我现在能执勤。", "脚是热了点，也可能精神了点，可扭伤还是老样子。", "是没痛感了，可我连路都走不直。今晚我要巡逻，不是躺床上。", "痛退得快，腿也没发麻——这东西像专门给巡逻队配的。要是稳定些，队里肯定有人想买。"]),
	_event(&"ranger_corrupted_claw_01", &"ranger", "凯尔·阿登", "常霁区巡林人", 5, 110, "林子里那东西抓了我一下。伤口不算深，可黑纹正顺着手臂往上爬，里面像有东西在动。", ["wound", "black_residue", "spreading_veins", "cold_sensation"], &"purification", &"regeneration", ["anti_magic", "long_duration"], ["activation"], ["conductive", "volatile"], &"black_magic_cleanser", 3, "腐化兽追踪事件", ["黑纹停住了，伤口边缘也开始恢复。最要紧的是，那股往上爬的感觉没了。", "黑纹不再扩散了，这最重要。可伤口还是像被什么从里面撕着。", "皮肉合得太快了，可黑纹还在下面动——这不对。你把伤口封上了，污染还没出去。", "疼是不疼了，可黑线已经过了手腕。别再管表面症状了。", "它在加速！黑纹刚才一下窜上来了——你给我的药在喂它！", "这配方我认不出来……但黑纹像被从血里一根根拔出去一样。它真的在退。"]),
	_event(&"innkeeper_smoke_cough_01", &"innkeeper", "玛尔塔·贝伦", "旅店经营者", 5, 100, "最近灶房烟道总倒灌，我嗓子烧得慌，一开口就咳。今晚客人多，最好别让我困，也别让我吐。", ["cough", "throat_pain", "inflammation", "smoke_residue"], &"analgesia", &"purification", ["antitussive", "gentle"], ["sedation"], ["emetic", "volatile"], &"clear_breath_elixir", 2, "旅店共同梦境线索", ["喉咙不再火烧一样，咳嗽也压下去了。药劲又不冲，今晚总算能把客人应付完。", "喉咙没那么疼了，可还是一开口就咳。至少说话不再像吞刀子。", "烟味好像散了，可喉咙还是肿得厉害。清掉刺激是一回事，炎症还得处理。", "我是想止咳，不是想提神、催眠或者暖身子。这杯没对上症。", "咳是没顾上咳了——我差点把晚饭全吐出来！今晚一屋子客人呢！", "这一口下去像把肺里积的烟都扫干净了。连说话都顺了——这个配方我愿意常备。"]),
]

static func eligible_for_day(current_day: int, flags: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event in EVENTS:
		if current_day >= int(event.start_day) and current_day <= 30 and not bool(flags.get(str(event.success_flag), false)):
			result.append(event.duplicate(true))
	return result

static func _event(event_id: StringName, npc_id: StringName, character_name: String, identity: String, start_day: int, modifier: int, request: String, symptoms: Array, primary: StringName, secondary: StringName, requirements: Array, forbidden_effects: Array, forbidden_traits: Array, preferred_special: StringName, revisit_days: int, revisit_note: String, lines: Array) -> Dictionary:
	var severity := 1 if event_id == &"young_villager_fatigue_01" or event_id == &"innkeeper_smoke_cough_01" else 3 if event_id == &"ranger_corrupted_claw_01" else 2
	return {"event_id":event_id,"npc_id":npc_id,"name":character_name,"identity":identity,"start_day":start_day,"modifier":float(modifier)/100.0,"request":request,"visible_symptoms":symptoms,"primary_need":primary,"secondary_need":secondary,"special_requirements":requirements,"severity":severity,"forbidden_effects":forbidden_effects,"forbidden_traits":forbidden_traits,"preferred_special_potion_id":preferred_special,"revisit_days":revisit_days,"revisit_note":revisit_note,"feedback_lines":lines,"portrait":PORTRAITS.get(npc_id),"success_flag":str(event_id)+"_resolved"}
