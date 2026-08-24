extends RefCounted

const RED := preload("res://shared/definitions/data/potions/red_potion.tres")
const BLUE := preload("res://shared/definitions/data/potions/blue_potion.tres")
const CYAN := preload("res://shared/definitions/data/potions/cyan_potion.tres")
const PURIFICATION := preload("res://shared/definitions/data/potions/purification_potion.tres")


static func run(test: TestSupport) -> void:
	test.expect(PotionCapabilityResolver.has_capability(RED, &"impact"), "Red potion exposes impact without changing its persistent ID.")
	test.expect_equal(RED.numeric_id, 1, "Red potion preserves console numeric ID 1.")
	test.expect(PotionCapabilityResolver.has_capability(CYAN, &"freeze"), "Cyan potion owns the formal freeze capability.")
	test.expect(PotionCapabilityResolver.has_capability(BLUE, &"purify"), "Blue potion owns regular purification.")
	test.expect(not BLUE.effect_tags.has(&"freeze"), "Blue's legacy freeze alias is not a formal data tag.")
	test.expect(PotionCapabilityResolver.hit_has_capability({"potion": BLUE}, &"freeze"), "The resolver preserves legacy blue-to-freeze interactions during migration.")
	test.expect(PotionCapabilityResolver.has_capability(PURIFICATION, &"purify_strong"), "The special formula exposes strong purification.")
	test.expect_equal(PURIFICATION.numeric_id, 8, "High-purity purification preserves numeric ID 8.")
	test.expect(not PotionCapabilityResolver.has_capability(BLUE, &"purify_strong"), "Ordinary blue purification cannot satisfy strong-purification gates.")
	test.expect(PotionCapabilityResolver.hit_has_capability({"potion_id": &"blue_ice_potion"}, &"freeze"), "Legacy ID-only direct-hit callers remain compatible.")
