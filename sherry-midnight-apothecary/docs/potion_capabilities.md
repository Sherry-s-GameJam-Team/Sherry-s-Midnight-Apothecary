# Potion capabilities

Potion resource IDs and `numeric_id` values remain the stable asset, save, and console identities. `PotionData.main_effect_id` remains the existing combat-executor key, while `color_family` describes the pharmacological family and `effect_tags` describe world-interaction capabilities.

New level mechanics must query `PotionCapabilityResolver` with a capability such as `freeze`, `machine_drive`, `impact`, `flow_control`, or `purify_strong`; they must not branch on potion IDs, colour names, or string containment.

The eight current resources retain their IDs. `purification_potion` is a high-purity blue-family special formula, not an eighth colour. Ordinary `blue_potion` supplies regular `purify`; the special formula supplies `purify_strong`, `anti_corruption`, and `black_magic_break` for severe-corruption gates.

The resolver retains narrowly scoped legacy aliases during migration. In particular, blue's old freeze interaction remains supported through the resolver, although `freeze` is formally a cyan capability. New content must not depend on that alias.
