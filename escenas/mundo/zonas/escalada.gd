extends Node3D
## Escalada: acércate a la pared y empuja el joystick hacia arriba. Saltar = soltarse hacia atrás.
## Cada jugador escala en su propio equipo y su posición ya se sincroniza.


func _ready() -> void:
	# pared grande (cara hacia el oeste, hacia la plaza)
	Ayuda.caja(self, Vector3(0, 7.5, 0), Vector3(3, 15, 10), Color(0.5, 0.42, 0.38))
	_zona_escalada(Vector3(-2.1, 7.9, 0), Vector3(1.2, 15.8, 10), Vector3(1, 0, 0))
	for i in 40:
		var y: float = 1.0 + fmod(i * 1.7, 13.0)
		var z: float = -4.0 + fmod(i * 2.3, 8.0)
		Ayuda.caja(self, Vector3(-1.62, y, z), Vector3(0.25, 0.35, 0.5), Color.from_hsv(fmod(i * 0.13, 1.0), 0.7, 0.95), false)
	# torre con cuatro caras escalables
	Ayuda.caja(self, Vector3(16, 6, 0), Vector3(6, 12, 6), Color(0.4, 0.45, 0.55))
	_zona_escalada(Vector3(12.4, 6.4, 0), Vector3(1.2, 12.8, 6), Vector3(1, 0, 0))
	_zona_escalada(Vector3(19.6, 6.4, 0), Vector3(1.2, 12.8, 6), Vector3(-1, 0, 0))
	_zona_escalada(Vector3(16, 6.4, -3.6), Vector3(6, 12.8, 1.2), Vector3(0, 0, 1))
	_zona_escalada(Vector3(16, 6.4, 3.6), Vector3(6, 12.8, 1.2), Vector3(0, 0, -1))


## dir_pared: hacia dónde está la pared respecto a quien trepa.
func _zona_escalada(pos: Vector3, tam: Vector3, dir_pared: Vector3) -> void:
	var a := Ayuda.area(self, pos, tam)
	a.body_entered.connect(_entra)
	a.body_exited.connect(_sale.bind(dir_pared))


func _entra(body: Node3D) -> void:
	if body.is_in_group("jugadores") and body.is_multiplayer_authority():
		body.entrar_escalada()


func _sale(body: Node3D, dir_pared: Vector3) -> void:
	if body.is_in_group("jugadores") and body.is_multiplayer_authority():
		body.salir_escalada(dir_pared)
