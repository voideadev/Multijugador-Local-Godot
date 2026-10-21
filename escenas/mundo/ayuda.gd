class_name Ayuda
extends RefCounted

const ZONAS: Dictionary = {
	"tiro": Vector3(0, 0, -50),
	"arena": Vector3(-50, 0, -50),
	"pong": Vector3(50, 0, -50),
	"parkour": Vector3(-55, 0, 0),
	"escalada": Vector3(55, 0, 0),
	"futbol": Vector3(-50, 0, 52),
	"fisica": Vector3(0, 0, 52),
	"bolos": Vector3(50, 0, 52),
}


static var offset_reloj: float = 0.0



static func tiempo() -> float:
	return Time.get_ticks_msec() / 1000.0 + offset_reloj


static func nombre_jugador(id: int) -> String:
	if id == 1:
		return "Anfitrión"
	return "Jugador %d" % (id % 100)


static func material(color: Color, emision: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	if emision > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emision
	return m


static func caja(padre: Node, pos: Vector3, tam: Vector3, color: Color, con_colision: bool = true) -> Node3D:
	var nodo: Node3D
	if con_colision:
		nodo = StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = tam
		cs.shape = sh
		nodo.add_child(cs)
	else:
		nodo = Node3D.new()
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = tam
	mi.mesh = bm
	mi.material_override = material(color)
	nodo.add_child(mi)
	nodo.position = pos
	padre.add_child(nodo)
	return nodo


static func area(padre: Node, pos: Vector3, tam: Vector3) -> Area3D:
	var a := Area3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = tam
	cs.shape = sh
	a.add_child(cs)
	a.position = pos
	padre.add_child(a)
	return a


static func etiqueta(padre: Node, texto: String, pos: Vector3, pixel: float = 0.01, tam_fuente: int = 64) -> Label3D:
	var l := Label3D.new()
	l.text = texto
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.pixel_size = pixel
	l.font_size = tam_fuente
	l.outline_size = 16
	l.position = pos
	padre.add_child(l)
	return l
