class_name ObjetoFisico
extends RigidBody3D

var agarrable: bool = false
var portador: int = 0
var inicio: Transform3D = Transform3D.IDENTITY
var net_pos: Vector3 = Vector3.ZERO
var net_rot: Quaternion = Quaternion.IDENTITY
var net_vel: Vector3 = Vector3.ZERO
var desde_sync: float = 0.0
var tiene_sync: bool = false
var sync_t: float = 0.0



func configurar(forma: String, tam: Vector3, masa_kg: float, color: Color, es_agarrable: bool) -> void:
	agarrable = es_agarrable
	mass = masa_kg
	add_to_group("objetos_fisicos")
	var malla := MeshInstance3D.new()
	var col := CollisionShape3D.new()
	var rebote: float = 0.1
	if forma == "esfera":
		var sm := SphereMesh.new()
		sm.radius = tam.x
		sm.height = tam.x * 2.0
		malla.mesh = sm
		var ss := SphereShape3D.new()
		ss.radius = tam.x
		col.shape = ss
		rebote = 0.6
		continuous_cd = true
	elif forma == "cilindro":
		var cm := CylinderMesh.new()
		cm.top_radius = tam.x
		cm.bottom_radius = tam.x
		cm.height = tam.y
		malla.mesh = cm
		var cs := CylinderShape3D.new()
		cs.radius = tam.x
		cs.height = tam.y
		col.shape = cs
	else:
		var bm := BoxMesh.new()
		bm.size = tam
		malla.mesh = bm
		var bs := BoxShape3D.new()
		bs.size = tam
		col.shape = bs
	malla.material_override = Ayuda.material(color)
	add_child(malla)
	add_child(col)
	var pm := PhysicsMaterial.new()
	pm.bounce = rebote
	pm.friction = 0.8
	physics_material_override = pm
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	collision_mask = 3
	linear_damp = 0.3
	angular_damp = 0.8


func _ready() -> void:
	inicio = global_transform


func _physics_process(delta: float) -> void:
	if multiplayer.is_server():
		if portador != 0:
			_seguir_portador()
		elif freeze:
			freeze = false
		if global_position.y < -15.0:
			reiniciar()
		sync_t += delta
		var hay_peers: bool = multiplayer.get_peers().size() > 0
		if hay_peers and (((portador != 0 or not sleeping) and sync_t >= 0.033) or sync_t >= 1.0):
			sync_t = 0.0
			_sync_red.rpc(global_position, global_basis.get_rotation_quaternion(), portador != 0, linear_velocity)
	else:
		if not freeze:
			freeze = true
		if tiene_sync:
			desde_sync += delta
			if desde_sync < 0.15:
				net_pos += net_vel * delta
			var k: float = clampf(delta * 20.0, 0.0, 1.0)
			global_position = global_position.lerp(net_pos, k)
			var q: Quaternion = global_basis.get_rotation_quaternion().slerp(net_rot, k)
			global_basis = Basis(q)


func _seguir_portador() -> void:
	var jug: Node3D = null
	for j in get_tree().get_nodes_in_group("jugadores"):
		if str(j.name) == str(portador):
			jug = j
			break
	if jug == null:
		soltar(Vector3.ZERO)
		return
	freeze = true
	var adelante: Vector3 = -jug.global_basis.z
	adelante.y = 0.0
	adelante = adelante.normalized()
	global_position = jug.global_position + Vector3(0.0, 1.1, 0.0) + adelante * 1.3
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO


func _set_llevado(b: bool) -> void:
	collision_layer = 0 if b else 1
	collision_mask = 0 if b else 3



func agarrar(peer: int) -> void:
	portador = peer
	_set_llevado(true)



func soltar(vel: Vector3) -> void:
	portador = 0
	_set_llevado(false)
	freeze = false
	linear_velocity = vel
	sleeping = false



func patear(dir: Vector3, fuerza: float) -> void:
	sleeping = false
	apply_central_impulse(dir.normalized() * fuerza * mass + Vector3.UP * fuerza * 0.2 * mass)



func reiniciar() -> void:
	if portador != 0:
		portador = 0
		_set_llevado(false)
	freeze = false
	global_transform = inicio
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	if multiplayer.get_peers().size() > 0:
		_sync_red.rpc(global_position, global_basis.get_rotation_quaternion(), false, Vector3.ZERO)


@rpc("authority", "call_remote", "unreliable")
func _sync_red(p: Vector3, q: Quaternion, llevado: bool, v: Vector3) -> void:
	net_pos = p
	net_rot = q
	net_vel = v
	desde_sync = 0.0
	_set_llevado(llevado)
	if not tiene_sync or global_position.distance_to(p) > 3.0:
		tiene_sync = true
		global_position = p
		global_basis = Basis(q)
