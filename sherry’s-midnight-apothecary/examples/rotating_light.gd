extends DirectionalLight2D


func _process(delta: float) -> void:
	rotation += delta # intentional indefinitely increasing floating point value
