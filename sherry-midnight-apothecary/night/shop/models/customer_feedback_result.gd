class_name CustomerFeedbackResult
extends RefCounted

var immediate_text := ""
var outcome := PotionMatchResult.Outcome.FAILED
var tags: Array[StringName] = []
var reputation_delta := 0
var relationship_delta := 0
var schedule_revisit := false
var revisit_after_days := 0
var revisit_text := ""
var special_event_id: StringName = &""
var next_requirement_note := ""
