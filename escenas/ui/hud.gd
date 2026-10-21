extends Control

signal leave_pressed


func _ready() -> void:
	%BtnSalir.pressed.connect(func(): leave_pressed.emit())


func set_info(text: String) -> void:
	%Info.text = text
