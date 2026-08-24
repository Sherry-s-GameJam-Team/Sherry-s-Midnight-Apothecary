# Potion capabilities

Potion resource IDs and `numeric_id` values remain the stable asset, save, and console identities. `PotionData.main_effect_id` remains the legacy blending/executor key, `combat_effect_ids` lists the actual effects dispatched by a thrown bottle, `color_family` describes the pharmacological family, and `effect_tags` describe world-interaction capabilities.

New level mechanics must query `PotionCapabilityResolver` with a capability such as `freeze`, `machine_drive`, `impact`, `flow_control`, or `purify_strong`; they must not branch on potion IDs, colour names, or string containment.

The eight current resources retain their IDs. `purification_potion` is a high-purity blue-family special formula, not an eighth colour. Ordinary `blue_potion` supplies regular `purify`; the special formula supplies `purify_strong`, `anti_corruption`, and `black_magic_break` for severe-corruption gates.

The resolver retains narrowly scoped legacy aliases during migration. In particular, blue's old freeze interaction remains supported through the resolver, although `freeze` is formally a cyan capability. New content must not depend on that alias.

Current combat dispatch is: red `attack`; orange `speed`; yellow `buffer` plus legacy `lightning_meteor` impact discharge; green `healing`; cyan `shield`; blue `purify` plus derived `mana`; purple `calm` plus `concealment`; high-purity purification `purify`. Yellow buffer lasts four seconds and reduces damage by 35% and knockback by 60%. Cyan supplies a 32-point, four-second shield through the shared daytime damage path. Ordinary blue cannot satisfy `purify_strong` gates.
