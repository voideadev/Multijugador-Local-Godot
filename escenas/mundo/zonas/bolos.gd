extends Node3D
## Bolos: ponte detrás de la bola negra y pulsa Acción (E) mirando hacia los bolos.

var pines: Array = []
var bola: ObjetoFisico
var t: float = 0.0
var t_derribo: float = 0.0
var derribados: int = 0
var contador: Label3D


func _ready() -> void:
	Ayuda.caja(self, Vector3(0, 0.02, -1), Vector3(3.2, 0.04, 24), Color(0.75, 0.6, 0.35), false)
	Ayuda.caja(self, Vector3(-1.9, 0.5, -1), Vector3(0.4, 1.0, 24), Color(0.3, 0.3, 0.35))
	Ayuda.caja(self, Vector3(1.9, 0.5, -1), Vector3(0.4, 1.0, 24), Color(0.3, 0.3, 0.35))
	Ayuda.caja(self, Vector3(0, 1.5, -13.2), Vector3(4.2, 3, 0.6), Color(0.2, 0.2, 0.25))
	var n: int = 0
	for fila in 4:
		for k in fila + 1:
			var p := ObjetoFisico.new()
			p.name = "Pin%d" % n
			p.position = Vector3((k - fila * 0.5) * 0.5, 0.4, -9.0 - fila * 0.8)
			p.configurar("cilindro", Vector3(0.14, 0.8, 0.0), 0.8, Color(0.95, 0.95, 0.95), false)
			add_child(p)
			pines.append(p)
			n += 1
	bola = ObjetoFisico.new()
	bola.name = "BolaBolos"
	bola.position = Vector3(0, 0.35, 9.0)
	bola.configurar("esfera", Vector3(0.3, 0, 0), 4.0, Color(0.1, 0.1, 0.12), false)
	add_child(bola)
	contador = Ayuda.etiqueta(self, "Bolos derribados: 0", Vector3(0, 4.0, -12.0), 0.012, 64)


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	t += delta
	if t < 0.5:
		return
	t = 0.0
	var n: int = 0
	for p in pines:
		if p.global_basis.y.y < 0.7:
			n += 1
	if n != derribados:
		derribados = n
		_rpc_contador.rpc(n)
	if derribados > 0:
		t_derribo += 0.5
		if t_derribo >= 8.0:
			t_derribo = 0.0
			for p in pines:
				p.reiniciar()
			bola.reiniciar()
	else:
		t_derribo = 0.0
	if bola.global_position.z < to_global(Vector3(0, 0, -13.5)).z:
		bola.reiniciar()


func estado_a_nuevo(id: int) -> void:
	_rpc_contador.rpc_id(id, derribados)


@rpc("authority", "call_local", "reliable")
func _rpc_contador(n: int) -> void:
	contador.text = "Bolos derribados: %d" % n
