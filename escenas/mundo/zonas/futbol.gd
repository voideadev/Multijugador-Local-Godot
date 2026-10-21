extends Node3D
## Fútbol: acércate al balón y pulsa Acción (tecla E) para patearlo hacia donde miras.
## El balón lo simula el anfitrión y se sincroniza con todos.

const HX: float = 11.0
const HZ: float = 16.0

var balon: ObjetoFisico
var goles: Array = [0, 0]
var en_pausa: bool = false
var marcador: Label3D


func _ready() -> void:
	var muro := Color(0.85, 0.85, 0.9)
	Ayuda.caja(self, Vector3(0, 0.02, 0), Vector3(2 * HX, 0.04, 2 * HZ), Color(0.15, 0.5, 0.2), false)
	Ayuda.caja(self, Vector3(0, 0.045, 0), Vector3(2 * HX, 0.02, 0.2), Color.WHITE, false)
	# muros laterales con una entrada en el centro (4 m)
	var largo: float = HZ - 2.0
	for lado in [-1, 1]:
		for seg in [-1, 1]:
			Ayuda.caja(self, Vector3(lado * HX, 1.5, seg * (2.0 + largo / 2.0)), Vector3(0.5, 3, largo), muro)
		# puerta invisible solo para el balón (capa 2)
		var puerta := StaticBody3D.new()
		puerta.collision_layer = 2
		puerta.collision_mask = 0
		var pcs := CollisionShape3D.new()
		var psh := BoxShape3D.new()
		psh.size = Vector3(0.5, 3, 4)
		pcs.shape = psh
		puerta.add_child(pcs)
		puerta.position = Vector3(lado * HX, 1.5, 0)
		add_child(puerta)
	for lado in [-1, 1]:
		var red := Color(1.0, 0.3, 0.3) if lado == -1 else Color(0.3, 0.5, 1.0)
		var ancho: float = HX - 3.0
		for seg in [-1, 1]:
			Ayuda.caja(self, Vector3(seg * (3.0 + ancho / 2.0), 1.5, lado * HZ), Vector3(ancho, 3, 0.5), muro)
		Ayuda.caja(self, Vector3(0, 1.5, lado * (HZ + 2.8)), Vector3(6.8, 3, 0.4), red)
		Ayuda.caja(self, Vector3(-3.2, 1.5, lado * (HZ + 1.4)), Vector3(0.4, 3, 2.8), red)
		Ayuda.caja(self, Vector3(3.2, 1.5, lado * (HZ + 1.4)), Vector3(0.4, 3, 2.8), red)
		Ayuda.caja(self, Vector3(0, 3.1, lado * (HZ + 1.4)), Vector3(6.8, 0.2, 2.8), red)
		var a := Ayuda.area(self, Vector3(0, 1.2, lado * (HZ + 1.4)), Vector3(5.6, 2.4, 2.4))
		a.body_entered.connect(_on_gol.bind(lado))
	balon = ObjetoFisico.new()
	balon.name = "Balon"
	balon.position = Vector3(0, 0.6, 0)
	balon.configurar("esfera", Vector3(0.5, 0, 0), 0.45, Color.WHITE, false)
	add_child(balon)
	marcador = Ayuda.etiqueta(self, "Azul 0 - 0 Rojo", Vector3(0, 6.0, 0), 0.02, 64)


func _physics_process(_d: float) -> void:
	if multiplayer.is_server() and balon.global_position.distance_to(global_position) > 30.0:
		balon.reiniciar()


func _on_gol(body: Node3D, lado: int) -> void:
	if not multiplayer.is_server() or body != balon or en_pausa:
		return
	en_pausa = true
	var idx: int = 0 if lado == -1 else 1
	goles[idx] += 1
	_rpc_marcador.rpc(goles[0], goles[1])
	get_tree().create_timer(2.0).timeout.connect(func() -> void:
		if is_inside_tree():
			balon.reiniciar()
			en_pausa = false)


func estado_a_nuevo(id: int) -> void:
	_rpc_marcador.rpc_id(id, goles[0], goles[1])


@rpc("authority", "call_local", "reliable")
func _rpc_marcador(a: int, b: int) -> void:
	marcador.text = "Azul %d - %d Rojo" % [a, b]
