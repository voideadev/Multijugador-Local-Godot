extends Node3D
## Cajas y trampolines.
## Cajas: Acción (E) cerca para agarrar; Acción otra vez para lanzar. Se sincronizan.
## Trampolines: salta sobre los círculos de colores.

const PADS: Array = [
	{"x": -4.0, "fuerza": 10.0, "alto": 3.5, "color": Color(0.2, 0.9, 0.3)},
	{"x": 6.0, "fuerza": 14.0, "alto": 7.5, "color": Color(1.0, 0.8, 0.1)},
	{"x": 16.0, "fuerza": 18.5, "alto": 14.0, "color": Color(1.0, 0.3, 0.3)},
]


func _ready() -> void:
	# pirámide de cajas agarrables
	var n: int = 0
	for fila in 4:
		var cuantas: int = 4 - fila
		for k in cuantas:
			var c := ObjetoFisico.new()
			c.name = "Caja%d" % n
			c.position = Vector3(-14.0 + (k - (cuantas - 1) / 2.0) * 1.05, 0.46 + fila * 0.95, -6.0)
			c.configurar("caja", Vector3(0.9, 0.9, 0.9), 2.0, Color.from_hsv(fila * 0.15, 0.6, 0.95), true)
			add_child(c)
			n += 1
	for i in 6:
		var c2 := ObjetoFisico.new()
		c2.name = "Caja%d" % n
		c2.position = Vector3(-14.0 + i * 1.8, 0.46, 2.0)
		c2.configurar("caja", Vector3(0.9, 0.9, 0.9), 2.0, Color.from_hsv(0.55 + i * 0.05, 0.5, 0.95), true)
		add_child(c2)
		n += 1
	# trampolines con su plataforma de destino
	for i in PADS.size():
		var d: Dictionary = PADS[i]
		var x: float = d["x"]
		var color: Color = d["color"]
		var pad := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 1.2
		cm.bottom_radius = 1.2
		cm.height = 0.3
		pad.mesh = cm
		pad.material_override = Ayuda.material(color, 1.0)
		pad.position = Vector3(x, 0.15, 8.0)
		add_child(pad)
		var a := Ayuda.area(self, Vector3(x, 0.4, 8.0), Vector3(2.2, 0.8, 2.2))
		a.body_entered.connect(_on_pad.bind(float(d["fuerza"])))
		var alto: float = d["alto"]
		Ayuda.caja(self, Vector3(x, alto - 0.25, 3.0), Vector3(5, 0.5, 5), color)


func _on_pad(body: Node3D, fuerza: float) -> void:
	if body.is_in_group("jugadores") and body.is_multiplayer_authority():
		body.impulsar(Vector3.ZERO, fuerza)
