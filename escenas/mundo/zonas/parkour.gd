extends Node3D
## Parkour sobre lava. La lava te devuelve al último checkpoint (bandera roja).
## Las plataformas móviles usan el reloj compartido: se ven igual en todos los equipos.

const PM := preload("res://escenas/mundo/plataforma_movil.gd")

const FIJAS: Array = [
	[Vector3(11, 0.6, 2), 3.0],
	[Vector3(7.5, 1.2, 4), 2.5],
	[Vector3(4, 1.8, 1.5), 2.5],
	[Vector3(0.5, 2.4, -1.5), 2.5],
	[Vector3(-3, 3.0, -4), 2.5],
	[Vector3(-11, 4.1, 1), 2.5],
	[Vector3(-14.5, 4.7, -2.5), 2.5],
	[Vector3(-18, 5.3, 0.5), 2.5],
	[Vector3(-18, 6.5, 10.5), 3.0],
	[Vector3(-14, 7.1, 13), 2.5],
	[Vector3(-9.5, 7.7, 13), 2.5],
]


func _ready() -> void:
	# lava
	Ayuda.caja(self, Vector3(-4, 0.03, 0), Vector3(36, 0.04, 28), Color(1.0, 0.3, 0.05), false).get_child(0).material_override = Ayuda.material(Color(1.0, 0.3, 0.05), 2.0)
	var lava := Ayuda.area(self, Vector3(-4, 0.3, 0), Vector3(36, 0.6, 28))
	lava.body_entered.connect(_lava)
	# plataformas fijas
	for p in FIJAS:
		var pos: Vector3 = p[0]
		var s: float = p[1]
		Ayuda.caja(self, Vector3(pos.x, pos.y - 0.2, pos.z), Vector3(s, 0.4, s), Color(0.55, 0.55, 0.65))
	# plataformas móviles
	_movil("Movil1", Vector3(-7, 3.3, -1), 3.0, Vector3(0, 0, 1), 3.0, 0.9)
	_movil("Movil2", Vector3(-18, 5.7, 5), 3.0, Vector3(0, 0, 1), 2.5, 0.8)
	# meta
	Ayuda.caja(self, Vector3(-4, 8.1, 12), Vector3(5, 0.4, 5), Color(0.9, 0.8, 0.2))
	Ayuda.etiqueta(self, "META", Vector3(-4, 11, 12), 0.02, 64)
	# rampa de bajada
	var a := Vector3(-1.5, 8.1, 12.5)
	var b := Vector3(14, 0.0, 17)
	var dir: Vector3 = b - a
	var rampa := Ayuda.caja(self, (a + b) / 2.0, Vector3(4, 0.4, dir.length()), Color(0.4, 0.7, 0.9))
	rampa.transform = Transform3D(Basis.looking_at(dir.normalized(), Vector3.UP), (a + b) / 2.0)
	# checkpoints
	_checkpoint(Vector3(16.5, 0, 0), Vector3(6, 3, 14), Vector3(16.5, 1.0, 0))
	_checkpoint(Vector3(-3, 4.0, -4), Vector3(2.5, 2, 2.5), Vector3(-3, 3.8, -4))
	_checkpoint(Vector3(-18, 6.3, 0.5), Vector3(2.5, 2, 2.5), Vector3(-18, 6.1, 0.5))


func _movil(nombre: String, pos: Vector3, tam: float, eje: Vector3, amp: float, vel: float) -> void:
	var p = PM.new()
	p.name = nombre
	p.position = pos
	p.eje = eje
	p.amplitud = amp
	p.velocidad = vel
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(tam, 0.4, tam)
	cs.shape = sh
	p.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(tam, 0.4, tam)
	mi.mesh = bm
	mi.material_override = Ayuda.material(Color(0.9, 0.5, 0.2))
	p.add_child(mi)
	add_child(p)


func _checkpoint(pos_area: Vector3, tam: Vector3, destino_local: Vector3) -> void:
	var a := Ayuda.area(self, pos_area + Vector3(0, tam.y / 2.0, 0), tam)
	a.body_entered.connect(_on_checkpoint.bind(to_global(destino_local)))
	if pos_area.y > 0.5:
		Ayuda.caja(self, pos_area + Vector3(0, 0.9, 0), Vector3(0.1, 1.8, 0.1), Color.WHITE, false)
		Ayuda.caja(self, pos_area + Vector3(0.3, 1.5, 0), Vector3(0.6, 0.4, 0.05), Color(1, 0.1, 0.1), false)


func _on_checkpoint(body: Node3D, destino: Vector3) -> void:
	if body.is_in_group("jugadores") and body.is_multiplayer_authority():
		body.punto_reaparicion = destino


func _lava(body: Node3D) -> void:
	if body.is_in_group("jugadores") and body.is_multiplayer_authority():
		body.reaparecer()
