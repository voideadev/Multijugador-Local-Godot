extends CharacterBody3D

const VEL_MAX: float = 16.0
const ACEL: float = 12.0
const FRENADO: float = 8.0
const GIRO: float = 1.9

var conductor: int = 0
var inicio: Transform3D = Transform3D.IDENTITY
var vel_adelante: float = 0.0
var net_pos: Vector3 = Vector3.ZERO
var net_rot: float = 0.0
var net_vel: Vector3 = Vector3.ZERO
var desde_sync: float = 0.0
var tiene_sync: bool = false
var sync_t: float = 0.0
var color: Color = Color(0.9, 0.2, 0.2)
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func _ready() -> void:
	add_to_group("vehiculos")
	set_multiplayer_authority(1)
	inicio = global_transform
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(2.0, 1.0, 4.0)
	cs.shape = sh
	cs.position = Vector3(0, 0.7, 0)
	add_child(cs)
	_caja(Vector3(2.0, 0.7, 4.0), Vector3(0, 0.6, 0), color)
	_caja(Vector3(1.7, 0.6, 2.0), Vector3(0, 1.25, 0.3), Color(0.75, 0.85, 0.95))
	for x in [-1.05, 1.05]:
		for z in [-1.3, 1.3]:
			var w := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.4
			cm.bottom_radius = 0.4
			cm.height = 0.3
			w.mesh = cm
			w.rotation_degrees = Vector3(0, 0, 90)
			w.position = Vector3(x, 0.4, z)
			w.material_override = Ayuda.material(Color(0.1, 0.1, 0.1))
			add_child(w)
	_caja(Vector3(1.4, 0.2, 0.1), Vector3(0, 0.7, -2.02), Color(1, 1, 0.6))


func _caja(tam: Vector3, pos: Vector3, c: Color) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = tam
	mi.mesh = bm
	mi.position = pos
	mi.material_override = Ayuda.material(c)
	add_child(mi)


func _physics_process(delta: float) -> void:
	if is_multiplayer_authority():
		if conductor != 0:
			_conducir(delta)
		elif multiplayer.is_server():
			if not is_on_floor():
				velocity.y -= gravity * delta
				move_and_slide()
			if global_position.y < -15.0:
				global_transform = inicio
				velocity = Vector3.ZERO
		sync_t += delta
		var hay_peers: bool = multiplayer.get_peers().size() > 0
		if hay_peers and ((conductor != 0 and sync_t >= 0.033) or sync_t >= 1.0):
			sync_t = 0.0
			_sync_red.rpc(position, rotation.y, -global_basis.z * vel_adelante)
	elif tiene_sync:
		desde_sync += delta
		if desde_sync < 0.15:
			net_pos += net_vel * delta
		var k: float = clampf(delta * 20.0, 0.0, 1.0)
		position = position.lerp(net_pos, k)
		rotation.y = lerp_angle(rotation.y, net_rot, k)


func _conducir(delta: float) -> void:
	var inp := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var acel: float = -inp.y
	var objetivo: float = acel * VEL_MAX if acel > 0.0 else acel * VEL_MAX * 0.4
	var ritmo: float = ACEL if absf(acel) > 0.05 else FRENADO
	vel_adelante = move_toward(vel_adelante, objetivo if absf(acel) > 0.05 else 0.0, ritmo * delta)
	rotation.y -= inp.x * GIRO * delta * clampf(vel_adelante / 4.0, -1.0, 1.0)
	var adelante: Vector3 = -global_basis.z
	velocity.x = adelante.x * vel_adelante
	velocity.z = adelante.z * vel_adelante
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= gravity * delta
	move_and_slide()
	var rv: Vector3 = get_real_velocity()
	rv.y = 0.0
	vel_adelante = rv.dot(adelante)



func asignar_conductor(id: int) -> void:
	_rpc_conductor.rpc(id)


@rpc("any_peer", "call_local", "reliable")
func _rpc_conductor(id: int) -> void:
	var emisor: int = multiplayer.get_remote_sender_id()
	if emisor != 0 and emisor != 1:
		return
	var mundo := get_tree().get_first_node_in_group("mundo")
	if conductor != 0:
		var viejo = mundo.call("_jugador", conductor)
		if viejo != null:
			viejo.bajar_de(self)
	conductor = id
	vel_adelante = 0.0
	set_multiplayer_authority(id if id != 0 else 1)
	if id != 0:
		var nuevo = mundo.call("_jugador", id)
		if nuevo != null:
			nuevo.subir_a(self)


@rpc("any_peer", "call_remote", "unreliable")
func _sync_red(p: Vector3, ry: float, v: Vector3) -> void:
	if multiplayer.get_remote_sender_id() != get_multiplayer_authority():
		return
	net_pos = p
	net_rot = ry
	net_vel = v
	desde_sync = 0.0
	if not tiene_sync or position.distance_to(p) > 5.0:
		tiene_sync = true
		position = p
		rotation.y = ry
