extends Node3D
## Monedas repartidas por todo el mapa. El anfitrión decide quién la coge (+1 punto)
## y avisa a todos; reaparecen a los 20 segundos.

var coins: Array = []
var recogidas: Dictionary = {}


func _ready() -> void:
	var pos: Array = []
	for i in 12:
		var ang: float = TAU * i / 12.0
		pos.append(Vector3(cos(ang) * 18.0, 1.0, sin(ang) * 18.0))
	var z: Dictionary = Ayuda.ZONAS
	pos.append(z["escalada"] + Vector3(0, 15.8, -3))
	pos.append(z["escalada"] + Vector3(0, 15.8, 3))
	pos.append(z["escalada"] + Vector3(16, 12.8, 0))
	pos.append(z["parkour"] + Vector3(-18, 6.9, 0.5))
	pos.append(z["parkour"] + Vector3(-5.5, 9.0, 12))
	pos.append(z["parkour"] + Vector3(-2.5, 9.0, 12))
	pos.append(z["fisica"] + Vector3(-4, 4.3, 3))
	pos.append(z["fisica"] + Vector3(6, 8.3, 3))
	pos.append(z["fisica"] + Vector3(16, 14.8, 3))
	pos.append(z["arena"] + Vector3(0, 4.8, 0))
	for i in pos.size():
		_crear(i, pos[i])


func _crear(i: int, p: Vector3) -> void:
	var a := Area3D.new()
	a.name = "Moneda%d" % i
	a.position = p
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.8
	cs.shape = sh
	a.add_child(cs)
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.4
	cm.bottom_radius = 0.4
	cm.height = 0.08
	mi.mesh = cm
	mi.rotation_degrees = Vector3(90, 0, 0)
	mi.material_override = Ayuda.material(Color(1, 0.85, 0.1), 1.5)
	a.add_child(mi)
	add_child(a)
	a.body_entered.connect(_on_body.bind(i))
	coins.append(a)


func _process(delta: float) -> void:
	for c in coins:
		c.rotation.y += delta * 2.0


func _on_body(body: Node3D, i: int) -> void:
	if not multiplayer.is_server() or recogidas.has(i) or not body.is_in_group("jugadores"):
		return
	recogidas[i] = true
	get_parent().sumar_puntos(body.name.to_int(), 1)
	_rpc_recoger.rpc(i)
	get_tree().create_timer(20.0).timeout.connect(func() -> void:
		if is_inside_tree():
			recogidas.erase(i)
			_rpc_aparecer.rpc(i))


func estado_a_nuevo(id: int) -> void:
	var lista: Array = recogidas.keys()
	_rpc_estado.rpc_id(id, lista)


@rpc("authority", "call_local", "reliable")
func _rpc_recoger(i: int) -> void:
	coins[i].visible = false
	coins[i].set_deferred("monitoring", false)


@rpc("authority", "call_local", "reliable")
func _rpc_aparecer(i: int) -> void:
	coins[i].visible = true
	coins[i].set_deferred("monitoring", true)


@rpc("authority", "call_remote", "reliable")
func _rpc_estado(lista: Array) -> void:
	for i in lista:
		coins[int(i)].visible = false
		coins[int(i)].set_deferred("monitoring", false)
