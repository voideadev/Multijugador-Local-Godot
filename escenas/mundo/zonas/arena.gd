extends Node3D
## Arena PvP: solo aquí los disparos hacen daño a otros jugadores (ver mundo.gd).


func _ready() -> void:
	var pared := Color(0.45, 0.2, 0.2)
	Ayuda.caja(self, Vector3(0, 0.02, 0), Vector3(26, 0.04, 26), Color(0.25, 0.1, 0.1), false)
	for lado in [-1, 1]:
		for seg in [-1, 1]:
			var c: float = seg * 8.0
			Ayuda.caja(self, Vector3(c, 1.5, lado * 13.0), Vector3(10, 3, 0.6), pared)
			Ayuda.caja(self, Vector3(lado * 13.0, 1.5, c), Vector3(0.6, 3, 10), pared)
	# coberturas
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			Ayuda.caja(self, Vector3(sx * 6.0, 1.0, sz * 6.0), Vector3(2.5, 2, 2.5), Color(0.5, 0.45, 0.4))
	Ayuda.caja(self, Vector3(0, 2.0, 0), Vector3(2, 4, 2), Color(0.35, 0.35, 0.4))
	Ayuda.caja(self, Vector3(0, 0.4, 4.5), Vector3(5, 0.8, 1), Color(0.5, 0.45, 0.4))
	Ayuda.caja(self, Vector3(0, 0.4, -4.5), Vector3(5, 0.8, 1), Color(0.5, 0.45, 0.4))
