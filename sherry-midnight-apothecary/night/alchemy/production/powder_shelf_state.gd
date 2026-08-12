class_name PowderShelfState
extends RefCounted

signal changed

var items: Array[PowderInstanceData] = []


func add_powder(powder: PowderInstanceData) -> bool:
	if powder == null or powder.source_instance_id == &"" or powder.amount <= 0.0:
		return false
	items.append(powder)
	changed.emit()
	return true


func take_powder(instance_id: StringName) -> PowderInstanceData:
	for index in items.size():
		if items[index].source_instance_id == instance_id and items[index].usable_for_brewing:
			var result := items[index]
			items.remove_at(index)
			changed.emit()
			return result
	return null


func return_powder(powder: PowderInstanceData) -> void:
	if powder != null:
		items.append(powder)
		changed.emit()


func has_powder(instance_id: StringName) -> bool:
	for powder: PowderInstanceData in items:
		if powder.source_instance_id == instance_id:
			return true
	return false


func snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for powder: PowderInstanceData in items:
		result.append(powder.to_dict())
	return result
