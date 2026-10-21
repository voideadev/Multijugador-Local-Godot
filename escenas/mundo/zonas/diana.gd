extends AnimatableBody3D
## Diana: cae al recibir un disparo y se levanta sola. Todo sincronizado por RPC.

var amplitud: float = 0.0
var velocidad: float = 1.0
var valor: int = 1
var base_x: float = 0.0
var abatida: bool = false
var pivote: Node3D
var cs: CollisionShape3D


func _ready() -> void:
	add_to_group("dianas")
	sync_to_physics = true
	base_x = position.x
	pivote = Node3D.new()
	add_child(pivote)
	var poste := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(0.15, 1.6, 0.15)
	poste.mesh = pm
	poste.position = Vector3(0, 0.8, -0.1)
	poste.material_override = Ayuda.material(Color(0.4, 0.3, 0.2))
	pivote.add_child(poste)
	var radios: Array = [0.8, 0.55, 0.25]
	var colores: Array = [Color.WHITE, Color(0.9, 0.15, 0.15), Color(1, 0.85, 0.1)]
	for i in 3:
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = radios[i]
		cm.bottom_radius = radios[i]
		cm.height = 0.1
		mi.mesh = cm
		mi.rotation_degrees = Vector3(90, 0, 0)
		mi.position = Vector3(0, 1.6, 0.02 * i)
		mi.material_override = Ayuda.material(colores[i])
		pivote.add_child(mi)
	cs = CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = 0.8
	sh.height = 0.2
	cs.shape = sh
	cs.rotation_degrees = Vector3(90, 0, 0)
	cs.position = Vector3(0, 1.6, 0)
	add_child(cs)


func _physics_process(_d: float) -> void:
	if amplitud > 0.0:
		position.x = base_x + sin(Ayuda.tiempo() * velocidad) * amplitud


## Solo se llama en el anfitrión (desde mundo.gd).
func golpear(peer: int) -> void:
	if abatida:
		return
	abatida = true
	var m = get_tree().get_first_node_in_group("mundo")
	if m:
		m.sumar_puntos(peer, valor)
	_caer.rpc()
	get_tree().create_timer(3.0).timeout.connect(func() -> void:
		if is_inside_tree():
			_levantar.rpc())


@rpc("authority", "call_local", "reliable")
func _caer() -> void:
	abatida = true
	cs.set_deferred("disabled", true)
	var tw := create_tween()
	tw.tween_property(pivote, "rotation_degrees:x", -90.0, 0.25)


@rpc("authority", "call_local", "reliable")
func _levantar() -> void:
	abatida = false
	cs.set_deferred("disabled", false)
	var tw := create_tween()
	tw.tween_property(pivote, "rotation_degrees:x", 0.0, 0.25)
