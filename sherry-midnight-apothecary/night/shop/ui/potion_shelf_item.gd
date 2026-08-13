class_name PotionShelfItem
extends Button

@onready var bottle_visual: PotionBottleVisual = %BottleVisual
@onready var name_label: Label = %PotionName
@onready var quality_label: Label = %QualityLabel
@onready var dose_bar: ProgressBar = %DoseBar
@onready var dose_label: Label = %DoseLabel
@onready var price_label: Label = %PriceLabel


func show_potion(potion: PotionData, instance: Dictionary, price: int) -> void:
	name_label.text = str(instance.get("custom_name", "")).strip_edges()
	if name_label.text.is_empty(): name_label.text = potion.display_name
	quality_label.text = "品质 %.0f%%" % (float(instance.get("quality", 1.0)) * 100.0)
	var dose := clampf(float(instance.get("remaining_dose", 1.0)), 0.0, 1.0)
	dose_bar.value = dose * 100.0
	dose_label.text = "剩余 %.0f%%" % (dose * 100.0)
	price_label.text = "%d 曜" % price
	bottle_visual.show_instance(potion, instance)
