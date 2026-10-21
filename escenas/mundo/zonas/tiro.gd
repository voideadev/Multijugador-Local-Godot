extends Node3D
## Tiro al blanco: dianas fijas y móviles. Disparar = botón Disparar / tecla F.

const DIANA := preload("res://escenas/mundo/zonas/diana.gd")


func _ready() -> void:
	Ayuda.caja(self, Vector3(0, 0.05, 6), Vector3(18, 0.1, 3), Color(0.3, 0.3, 0.38))
	Ayuda.etiqueta(self, "LÍNEA DE TIRO", Vector3(0, 1.6, 6), 0.008, 48)
	Ayuda.caja(self, Vector3(0, 4, -34), Vector3(44, 8, 1), Color(0.35, 0.3, 0.28))
	for i in 5:
		_diana("Diana%d" % i, Vector3((i - 2) * 5.0, 0, -14), 0.0, 0.0, 1)
	_diana("DianaMovil0", Vector3(0, 0, -22), 8.0, 0.5, 2)
	_diana("DianaMovil1", Vector3(0, 0, -28), 10.0, 0.9, 3)


func _diana(nombre: String, pos: Vector3, amplitud: float, velocidad: float, valor: int) -> void:
	var d = DIANA.new()
	d.name = nombre
	d.position = pos
	d.amplitud = amplitud
	d.velocidad = velocidad
	d.valor = valor
	add_child(d)
