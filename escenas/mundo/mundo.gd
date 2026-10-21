extends Node3D

const TIRO := preload("res://escenas/mundo/zonas/tiro.gd")
const ARENA := preload("res://escenas/mundo/zonas/arena.gd")
const PONG := preload("res://escenas/mundo/zonas/pong.gd")
const FUTBOL := preload("res://escenas/mundo/zonas/futbol.gd")
const BOLOS := preload("res://escenas/mundo/zonas/bolos.gd")
const FISICA := preload("res://escenas/mundo/zonas/fisica.gd")
const ESCALADA := preload("res://escenas/mundo/zonas/escalada.gd")
const PARKOUR := preload("res://escenas/mundo/zonas/parkour.gd")
const MONEDAS := preload("res://escenas/mundo/zonas/monedas.gd")
const GARAJE := preload("res://escenas/mundo/zonas/garaje.gd")

const NOMBRES: Dictionary = {
	"tiro": "TIRO AL BLANCO", "arena": "ARENA PvP", "pong": "PONG",
	"parkour": "PARKOUR + LAVA", "escalada": "ESCALADA", "futbol": "FÚTBOL",
	"fisica": "CAJAS Y TRAMPOLINES", "bolos": "BOLOS",
}
const AYUDA_ZONA: Dictionary = {
	"tiro": "Tiro: botón Disparar (tecla F) a las dianas",
	"arena": "Arena PvP: aquí los disparos hacen daño a otros jugadores",
	"pong": "Pong: ponte detrás de una paleta (azul o roja) y muévete de lado",
	"parkour": "Parkour: la lava te devuelve al último checkpoint",
	"escalada": "Escalada: acércate a la pared y empuja el joystick hacia arriba",
	"futbol": "Fútbol: Acción (tecla E) cerca del balón para patear",
	"fisica": "Cajas: Acción (E) para agarrar y lanzar. Círculos de colores = trampolines",
	"bolos": "Bolos: ponte tras la bola y pulsa Acción (E) mirando a los bolos",
}

var puntos: Dictionary = {}
var vidas: Dictionary = {}
var ultimo_disparo: Dictionary = {}
var zonas: Array = []
var reloj_t: float = 0.0
var reloj_inicial: bool = true
var hud_t: float = 0.0
var hud_layer: CanvasLayer
var hud_vida: Label
var hud_puntos: Label
var hud_zona: Label


func _ready() -> void:
	add_to_group("mundo")
	Ayuda.offset_reloj = 0.0
	_crear_zona("Tiro", TIRO, "tiro")
	_crear_zona("Arena", ARENA, "arena")
	_crear_zona("Pong", PONG, "pong")
	_crear_zona("Parkour", PARKOUR, "parkour")
	_crear_zona("Escalada", ESCALADA, "escalada")
	_crear_zona("Futbol", FUTBOL, "futbol")
	_crear_zona("Fisica", FISICA, "fisica")
	_crear_zona("Bolos", BOLOS, "bolos")
	var g: Node3D = GARAJE.new()
	g.name = "Garaje"
	g.position = Vector3(0, 0, 7)
	add_child(g)
	var m: Node3D = MONEDAS.new()
	m.name = "Monedas"
	add_child(m)
	zonas.append(m)
	_crear_letreros_plaza()
	_crear_hud()
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)


func _crear_zona(nombre: String, script: GDScript, clave: String) -> void:
	var z: Node3D = script.new()
	z.name = nombre
	z.position = Ayuda.ZONAS[clave]
	add_child(z)
	zonas.append(z)
	Ayuda.etiqueta(z, NOMBRES[clave], Vector3(0, 13, 0), 0.03, 64)


func _crear_letreros_plaza() -> void:
	for clave in Ayuda.ZONAS:
		var c: Vector3 = Ayuda.ZONAS[clave]
		var dir: Vector3 = c.normalized()
		var p: Vector3 = dir * 13.0
		Ayuda.caja(self, p + Vector3(0, 1.1, 0), Vector3(0.2, 2.2, 0.2), Color(0.4, 0.3, 0.2), false)
		Ayuda.etiqueta(self, "%s\n%d m" % [NOMBRES[clave], int(c.length())], p + Vector3(0, 2.8, 0), 0.008, 48)


func _crear_hud() -> void:
	hud_layer = CanvasLayer.new()
	hud_layer.layer = 6
	hud_layer.visible = false
	add_child(hud_layer)
	hud_vida = _label(Vector2(14, 100), 28)
	hud_puntos = _label(Vector2(14, 140), 26)
	hud_zona = _label(Vector2(0, 96), 24)
	hud_zona.anchor_right = 1.0
	hud_zona.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _label(pos: Vector2, tam: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_constant_override("outline_size", 8)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	hud_layer.add_child(l)
	return l


func _process(delta: float) -> void:
	if multiplayer.is_server() and multiplayer.get_peers().size() > 0:
		reloj_t += delta
		if reloj_t >= 2.0:
			reloj_t = 0.0
			_rpc_reloj.rpc(Ayuda.tiempo())
	var local: Node3D = _jugador_local()
	hud_layer.visible = local != null
	if local == null:
		return
	hud_vida.text = "Vida: %d" % int(vidas.get(local.name.to_int(), 100))
	var mejor: float = 28.0
	var texto: String = ""
	for clave in Ayuda.ZONAS:
		var d: float = local.global_position.distance_to(Ayuda.ZONAS[clave])
		if d < mejor:
			mejor = d
			texto = AYUDA_ZONA[clave]
	hud_zona.text = texto
	hud_t += delta
	if hud_t >= 0.5:
		hud_t = 0.0
		_actualizar_puntos()


func _actualizar_puntos() -> void:
	var ids: Array = []
	for j in get_tree().get_nodes_in_group("jugadores"):
		ids.append(j.name.to_int())
	ids.sort()
	var t: String = "Puntos:"
	for id in ids:
		t += "\n%s: %d" % [Ayuda.nombre_jugador(id), int(puntos.get(id, 0))]
	hud_puntos.text = t


func _jugador_local() -> Node3D:
	for j in get_tree().get_nodes_in_group("jugadores"):
		if j.is_multiplayer_authority():
			return j as Node3D
	return null


func _jugador(id: int) -> Node3D:
	for j in get_tree().get_nodes_in_group("jugadores"):
		if str(j.name) == str(id):
			return j as Node3D
	return null



func _on_peer_connected(id: int) -> void:
	if not multiplayer.is_server():
		return
	_rpc_reloj.rpc_id(id, Ayuda.tiempo())
	_rpc_puntos.rpc_id(id, puntos)
	_rpc_vidas.rpc_id(id, vidas)
	for z in zonas:
		if z.has_method("estado_a_nuevo"):
			z.estado_a_nuevo(id)


func _on_peer_disconnected(id: int) -> void:
	if not multiplayer.is_server():
		return
	puntos.erase(id)
	vidas.erase(id)
	for o in get_tree().get_nodes_in_group("objetos_fisicos"):
		if o.portador == id:
			o.soltar(Vector3.ZERO)
	for v in get_tree().get_nodes_in_group("vehiculos"):
		if v.conductor == id:
			v.conductor = 0
			v.set_multiplayer_authority(1)
	_rpc_puntos.rpc(puntos)
	_rpc_vidas.rpc(vidas)



func sumar_puntos(id: int, cantidad: int) -> void:
	if not multiplayer.is_server():
		return
	puntos[id] = int(puntos.get(id, 0)) + cantidad
	_rpc_puntos.rpc(puntos)


@rpc("authority", "call_local", "reliable")
func _rpc_puntos(d: Dictionary) -> void:
	puntos = d
	if hud_puntos != null:
		_actualizar_puntos()


@rpc("authority", "call_local", "reliable")
func _rpc_vidas(d: Dictionary) -> void:
	vidas = d


@rpc("authority", "call_local", "reliable")
func _rpc_reaparecer(id: int) -> void:
	var j: Node3D = _jugador(id)
	if j != null and j.is_multiplayer_authority():
		j.reaparecer_plaza()


@rpc("authority", "call_remote", "unreliable")
func _rpc_reloj(t_servidor: float) -> void:
	var nuevo: float = t_servidor - Time.get_ticks_msec() / 1000.0
	if reloj_inicial:
		reloj_inicial = false
		Ayuda.offset_reloj = nuevo
	else:
		Ayuda.offset_reloj = lerpf(Ayuda.offset_reloj, nuevo, 0.3)



func pedir_disparo(origen: Vector3, dir: Vector3) -> void:
	if multiplayer.is_server():
		_srv_disparo(1, origen, dir)
	else:
		_rpc_disparo.rpc_id(1, origen, dir)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_disparo(origen: Vector3, dir: Vector3) -> void:
	if multiplayer.is_server():
		_srv_disparo(multiplayer.get_remote_sender_id(), origen, dir)


func _srv_disparo(id: int, origen: Vector3, dir: Vector3) -> void:
	var jug: Node3D = _jugador(id)
	if jug == null or dir.length() < 0.1:
		return
	var ahora: int = Time.get_ticks_msec()
	var ultimo: int = ultimo_disparo.get(id, 0)
	if ahora - ultimo < 200:
		return
	ultimo_disparo[id] = ahora
	if origen.distance_to(jug.global_position) > 8.0:
		return
	dir = dir.normalized()
	var q := PhysicsRayQueryParameters3D.create(origen, origen + dir * 80.0)
	q.exclude = [jug.get_rid()]
	var r: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	var fin: Vector3 = origen + dir * 80.0
	if not r.is_empty():
		fin = r["position"]
		var n: Node = r["collider"] as Node
		if n != null:
			if n.is_in_group("dianas"):
				n.golpear(id)
			elif n.is_in_group("jugadores"):
				_danar(n.name.to_int(), id, 25)
			elif n is ObjetoFisico:
				var o: ObjetoFisico = n as ObjetoFisico
				o.sleeping = false
				o.apply_impulse(dir * 3.0, fin - o.global_position)
	var desde: Vector3 = jug.global_position + Vector3(0, 1.3, 0) + dir * 0.5
	_rpc_fx_disparo.rpc(desde, fin)


func _en_arena(p: Vector3) -> bool:
	var c: Vector3 = Ayuda.ZONAS["arena"]
	return absf(p.x - c.x) < 13.0 and absf(p.z - c.z) < 13.0


func _danar(victima: int, atacante: int, cantidad: int) -> void:
	if victima == atacante:
		return
	var jv: Node3D = _jugador(victima)
	var ja: Node3D = _jugador(atacante)
	if jv == null or ja == null:
		return
	if not (_en_arena(jv.global_position) and _en_arena(ja.global_position)):
		return
	var v: int = int(vidas.get(victima, 100)) - cantidad
	if v <= 0:
		vidas[victima] = 100
		sumar_puntos(atacante, 3)
		_rpc_reaparecer.rpc(victima)
	else:
		vidas[victima] = v
	_rpc_vidas.rpc(vidas)


@rpc("authority", "call_local", "unreliable")
func _rpc_fx_disparo(desde: Vector3, hasta: Vector3) -> void:
	var largo: float = desde.distance_to(hasta)
	if largo < 0.1:
		return
	var dir: Vector3 = (hasta - desde) / largo
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.02
	cm.bottom_radius = 0.02
	cm.height = largo
	mi.mesh = cm
	var mat := Ayuda.material(Color(1, 0.9, 0.3), 3.0)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	add_child(mi)
	var base: Basis = Basis.IDENTITY
	if absf(dir.dot(Vector3.UP)) < 0.999:
		base = Basis(Quaternion(Vector3.UP, dir))
	elif dir.y < 0.0:
		base = Basis(Vector3.RIGHT, PI)
	mi.global_transform = Transform3D(base, (desde + hasta) / 2.0)
	get_tree().create_timer(0.08).timeout.connect(func() -> void:
		if is_instance_valid(mi):
			mi.queue_free())



func pedir_accion() -> void:
	if multiplayer.is_server():
		_srv_accion(1)
	else:
		_rpc_accion.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_accion() -> void:
	if multiplayer.is_server():
		_srv_accion(multiplayer.get_remote_sender_id())


func _srv_accion(id: int) -> void:
	var jug: Node3D = _jugador(id)
	if jug == null:
		return
	var adelante: Vector3 = -jug.global_basis.z
	adelante.y = 0.0
	adelante = adelante.normalized()

	for v in get_tree().get_nodes_in_group("vehiculos"):
		if v.conductor == id:
			v.asignar_conductor(0)
			return
	var cercano: Node3D = null
	var dv: float = 4.0
	for v in get_tree().get_nodes_in_group("vehiculos"):
		var dd: float = v.global_position.distance_to(jug.global_position)
		if v.conductor == 0 and dd < dv:
			dv = dd
			cercano = v
	if cercano != null:
		cercano.asignar_conductor(id)
		return
	for o in get_tree().get_nodes_in_group("objetos_fisicos"):
		var obj: ObjetoFisico = o as ObjetoFisico
		if obj.portador == id:
			obj.soltar(adelante * 7.0 + Vector3.UP * 3.0)
			return
	var mejor: ObjetoFisico = null
	var dist: float = 2.6
	var centro: Vector3 = jug.global_position + Vector3(0, 0.9, 0)
	for o in get_tree().get_nodes_in_group("objetos_fisicos"):
		var obj2: ObjetoFisico = o as ObjetoFisico
		var d: float = obj2.global_position.distance_to(centro)
		if obj2.portador == 0 and d < dist:
			dist = d
			mejor = obj2
	if mejor == null:
		return
	if mejor.agarrable:
		mejor.agarrar(id)
	else:
		mejor.patear(adelante, 9.0)
