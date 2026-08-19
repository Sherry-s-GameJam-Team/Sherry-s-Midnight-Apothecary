class_name HelionAnimationMap
extends RefCounted

const IDLE := &"idle_intro"
const MINUTE_SWEEP := &"minute_sweep"
const REWIND_CAST := &"rewind_cast"
const PHASE3_TRANSFORM := &"phase3_transform"
const TIME_RING_BURST := &"time_ring_burst"
const PHASE3_HOLD := &"phase3_hold"
const RECOVERY := &"recovery"
const PURIFIED_IDLE := &"purified_idle"

# The source video did not produce a clean standalone hit animation.
# Recommended hit feedback: short positional recoil + shader flash, then return to current phase idle.
