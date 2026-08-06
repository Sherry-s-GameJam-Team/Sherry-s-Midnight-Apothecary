class_name PotionDoseReservation
extends RefCounted

var reservation_id := 0
var potion_id: StringName
var requested_dose := 0.0
var allocations: Array[Dictionary] = []
var active := true

