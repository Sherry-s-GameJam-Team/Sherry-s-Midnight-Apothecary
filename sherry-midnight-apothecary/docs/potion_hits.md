# Potion direct hits

Every thrown bottle is a `PotionProjectile` (`res://shared/potions/runtime/potion_projectile.gd`). When its `CharacterBody2D` collides with a physics body in `PotionThrowTuning.projectile_collision_mask`, it breaks at the contact point and walks from the collided node up through its parents to find `receive_potion_hit(hit: Dictionary)`.

首次进入药水瞄准时，顶部 HintUI 显示“按住鼠标左键瞄准并蓄能；25%剂量达到4倍效果，继续蓄力只会增加消耗。”；`tutorial_throw_potion` 仅作为存档去重键，不会显示给玩家。

## 瞄准蓄能、剂量与效果叠加

普通库存投掷不再使用固定剂量。进入瞄准时先预留一瓶的 5%，之后按未受子弹时间影响的真实瞄准时间，以每秒 10%、每次 1% 的剂量刻度增加预计消耗；一次最多消耗 100%。松开有效投掷时才用最终剂量替换最低预留并提交，取消瞄准或拖拽距离不足不会消耗药水。

效果倍率在 5% 剂量时为 `×1`，并在 5%～25% 区间线性叠加，到 25% 时达到 `×4`。超过 25% 后效果保持 `×4`，继续瞄准只会增加药水消耗。瞄准期间，快捷栏旁的“药水蓄能”面板同步显示预计消耗、效果倍率和超过临界值后的浪费警告。若剩余总剂量不足预计值，实际消耗和倍率按可用剂量封顶；不足最低 5% 时不能开始投掷。

机关投掷模式生成虚拟药水，不读取库存，也不会使用本蓄能倍率，始终按 `×1` 处理。

An enemy can put its collision shape on its root body, or on a child physics body below that root. The receiver method may live on either node or any ancestor.

```gdscript
func receive_potion_hit(hit: Dictionary) -> void:
	var potion_id: StringName = hit.potion_id
	var point: Vector2 = hit.impact_point
	# Apply health, stagger, reactions, or AI state here.
```

`hit` contains `potion`, `potion_id`, a copied `payload`, `effect_multiplier`, `consumed_dose`, `impact_point`, `impact_normal`, and `projectile`. `PotionProjectile.direct_hit(receiver, hit)` is emitted after the receiver is called. Splash effect amounts consume `payload.effect_stack_multiplier` automatically; direct-hit-only encounter logic can read the top-level multiplier when it needs charged-hit scaling.

Direct collision is distinct from the splash effect: the existing `PotionEffectExecutor` still performs its circular `effect_radius` query and calls `apply_potion_effect(effect_id, context)` for compatible targets. An enemy that needs both direct impact and area effects can implement both methods.

For an enemy to receive direct hits, ensure its physics body's collision layer overlaps `PotionThrowTuning.projectile_collision_mask` (currently layer 1 by default). The projectile itself has collision layer 0, so it does not act as an obstacle for other bodies.
