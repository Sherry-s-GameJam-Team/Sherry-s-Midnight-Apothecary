class_name CustomerFeedbackResolver
extends RefCounted

static func resolve(event: Dictionary, match: PotionMatchResult) -> CustomerFeedbackResult:
	var result := CustomerFeedbackResult.new()
	result.outcome = match.outcome
	result.tags = match.tags.duplicate()
	result.schedule_revisit = true
	result.revisit_after_days = int(event.get("revisit_days", 0))
	result.revisit_text = str(event.get("revisit_note", ""))
	result.next_requirement_note = str(event.get("revisit_note", ""))
	var lines: Array = event.get("feedback_lines", [])
	var line_index := 3
	match match.outcome:
		PotionMatchResult.Outcome.SPECIAL:
			line_index = 5; result.reputation_delta = 6; result.relationship_delta = 16
		PotionMatchResult.Outcome.DANGEROUS:
			line_index = 4; result.reputation_delta = -8; result.relationship_delta = -15
		PotionMatchResult.Outcome.PERFECT:
			line_index = 0; result.reputation_delta = 4; result.relationship_delta = 12
		PotionMatchResult.Outcome.SATISFIED:
			line_index = 1; result.reputation_delta = 2; result.relationship_delta = 7
		PotionMatchResult.Outcome.ACCEPTABLE:
			line_index = 2; result.reputation_delta = 0; result.relationship_delta = 2
		_:
			result.reputation_delta = -2; result.relationship_delta = -5
	result.immediate_text = str(lines[line_index]) if line_index < lines.size() else "这瓶药的效果似乎没有对上症状。"
	return result
