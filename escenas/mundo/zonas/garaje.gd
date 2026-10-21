extends Node3D
## Garaje junto a la plaza: tres coches para montar (Acción / E) y conducir.

const VEHICULO := preload("res://escenas/mundo/vehiculo.gd")


func _ready() -> void:
	Ayuda.etiqueta(self, "GARAJE: Acción (E) para montar", Vector3(0, 3.5, 0), 0.01, 56)
	var colores: Array = [Color(0.9, 0.2, 0.2), Color(0.2, 0.5, 0.95), Color(0.95, 0.8, 0.15)]
	for i in 3:
		var v: CharacterBody3D = VEHICULO.new()
		v.name = "Coche%d" % i
		v.position = Vector3((i - 1) * 6.0, 0.05, 0)
		v.color = colores[i]
		add_child(v)
