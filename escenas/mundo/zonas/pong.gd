extends Node3D
## Pong 3D. Ponte en la zona azul o roja (detrás de la paleta) y muévete de lado:
## tu posición mueve la paleta. Si un lado está vacío juega un bot.
## El anfitrión calcula la bola; los demás reciben su posición.

const W: float = 5.0
const L: float = 8.0
const PZ: float = 7.2
const PAD_HALF: float = 1.3
const R: float = 0.3
const VEL_INICIAL: float = 8.0
const VEL_MAX: float = 17.0

var bola: Vector2 = Vector2.ZERO
var vel: Vector2 = Vector2.ZERO
var rapidez: float = VEL_INICIAL
var pad: Array = [0.0, 0.0]
var bola_vis: Vector2 = Vector2.ZERO
var pads_vis: Array = [0.0, 0.0]
var puntos: Array = [0, 0]
var ids: Array = [0, 0]
var espera: float = 1.0
var envio_t: float = 0.0

var malla_bola: MeshInstance3D
var mallas_pad: Array = []
var marcador: Label3D


func _ready() -> void:
	Ayuda.caja(self, Vector3(0, 0.02, 0), Vector3(2 * W, 0.04, 2 * L), Color(0.08, 0.12, 0.2), false)
	Ayuda.caja(self, Vector3(0, 0.045, 0), Vector3(2 * W, 0.02, 0.15), Color(0.8, 0.8, 0.8), false)
	for lado in [-1, 1]:
		Ayuda.caja(self, Vector3(lado * (W + 0.25), 0.4, 0), Vector3(0.5, 0.8, 2 * L), Color(0.8, 0.8, 0.85))
		var col := Color(0.2, 0.4, 1.0) if lado == -1 else Color(1.0, 0.3, 0.3)
		var zc: float = lado * (L + 1.65)
		Ayuda.caja(self, Vector3(0, 0.03, zc), Vector3(2 * (W + 1.0), 0.04, 3.7), col, false)
		var nombre := "PALETA AZUL" if lado == -1 else "PALETA ROJA"
		Ayuda.etiqueta(self, nombre + "\n(ponte aquí)", Vector3(0, 1.8, zc), 0.008, 48)
		var p := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(2 * PAD_HALF, 0.5, 0.35)
		p.mesh = bm
		p.material_override = Ayuda.material(col, 1.0)
		add_child(p)
		mallas_pad.append(p)
	malla_bola = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = R
	sm.height = R * 2.0
	malla_bola.mesh = sm
	malla_bola.material_override = Ayuda.material(Color.WHITE, 2.0)
	add_child(malla_bola)
	marcador = Ayuda.etiqueta(self, "0  :  0", Vector3(0, 3.5, 0), 0.02, 64)
	_aplicar_visual()


func _physics_process(delta: float) -> void:
	if multiplayer.is_server():
		_servidor(delta)
		bola_vis = bola
		pads_vis = pad.duplicate()
	else:
		var k: float = clampf(delta * 18.0, 0.0, 1.0)
		bola_vis = bola_vis.lerp(bola, k)
		for i in 2:
			pads_vis[i] = lerpf(float(pads_vis[i]), float(pad[i]), k)
	_aplicar_visual()


func _aplicar_visual() -> void:
	malla_bola.position = Vector3(bola_vis.x, 0.4, bola_vis.y)
	mallas_pad[0].position = Vector3(float(pads_vis[0]), 0.4, -PZ)
	mallas_pad[1].position = Vector3(float(pads_vis[1]), 0.4, PZ)


func _servidor(delta: float) -> void:
	var objetivo: Array = [null, null]
	ids = [0, 0]
	for j in get_tree().get_nodes_in_group("jugadores"):
		var lp: Vector3 = to_local(j.global_position)
		if absf(lp.x) > W + 1.0:
			continue
		if lp.z < -L + 0.2 and lp.z > -L - 3.7:
			if objetivo[0] == null:
				objetivo[0] = lp.x
				ids[0] = j.name.to_int()
		elif lp.z > L - 0.2 and lp.z < L + 3.7:
			if objetivo[1] == null:
				objetivo[1] = lp.x
				ids[1] = j.name.to_int()
	var hay_humanos: bool = objetivo[0] != null or objetivo[1] != null
	var lim: float = W - PAD_HALF
	for i in 2:
		if objetivo[i] != null:
			pad[i] = clampf(float(objetivo[i]), -lim, lim)
		else:
			var seguir: float = 0.0
			if (i == 0 and vel.y < 0.0) or (i == 1 and vel.y > 0.0):
				seguir = bola.x
			pad[i] = move_toward(float(pad[i]), clampf(seguir, -lim, lim), 5.0 * delta)
	if not hay_humanos:
		bola = Vector2.ZERO
		vel = Vector2.ZERO
		espera = 1.0
	elif vel == Vector2.ZERO:
		espera -= delta
		if espera <= 0.0:
			_sacar()
	else:
		_mover_bola(delta)
	envio_t += delta
	if envio_t >= 0.04 and multiplayer.get_peers().size() > 0:
		envio_t = 0.0
		_rpc_estado.rpc(bola, float(pad[0]), float(pad[1]))


func _sacar() -> void:
	rapidez = VEL_INICIAL
	var dz: float = -1.0 if randf() < 0.5 else 1.0
	vel = Vector2(randf_range(-0.6, 0.6), dz).normalized() * rapidez


func _mover_bola(delta: float) -> void:
	bola += vel * delta
	if bola.x > W - R:
		bola.x = W - R
		vel.x = -absf(vel.x)
	elif bola.x < -W + R:
		bola.x = -W + R
		vel.x = absf(vel.x)
	if vel.y > 0.0 and bola.y + R >= PZ and bola.y - R < PZ + 0.3:
		if absf(bola.x - float(pad[1])) <= PAD_HALF + R:
			_rebotar(1)
	elif vel.y < 0.0 and bola.y - R <= -PZ and bola.y + R > -PZ - 0.3:
		if absf(bola.x - float(pad[0])) <= PAD_HALF + R:
			_rebotar(0)
	if bola.y > L:
		_punto(0)
	elif bola.y < -L:
		_punto(1)


func _rebotar(i: int) -> void:
	var desv: float = (bola.x - float(pad[i])) / (PAD_HALF + R)
	rapidez = minf(rapidez + 0.7, VEL_MAX)
	var dz: float = 1.0 if i == 0 else -1.0
	vel = Vector2(desv * 0.9, dz).normalized() * rapidez
	bola.y = (-PZ + R + 0.01) if i == 0 else (PZ - R - 0.01)


func _punto(i: int) -> void:
	puntos[i] += 1
	vel = Vector2.ZERO
	bola = Vector2.ZERO
	espera = 1.5
	if int(ids[i]) != 0:
		get_parent().sumar_puntos(int(ids[i]), 1)
	_rpc_marcador.rpc(puntos[0], puntos[1])


func estado_a_nuevo(id: int) -> void:
	_rpc_marcador.rpc_id(id, puntos[0], puntos[1])


@rpc("authority", "call_remote", "unreliable")
func _rpc_estado(b: Vector2, a: float, c: float) -> void:
	bola = b
	pad[0] = a
	pad[1] = c


@rpc("authority", "call_local", "reliable")
func _rpc_marcador(a: int, b: int) -> void:
	marcador.text = "%d  :  %d" % [a, b]
