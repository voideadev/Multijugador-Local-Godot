extends AnimatableBody3D

var base: Vector3 = Vector3.ZERO
var eje: Vector3 = Vector3.RIGHT
var amplitud: float = 3.0
var velocidad: float = 1.0
var fase: float = 0.0


func _ready() -> void:
	sync_to_physics = true
	base = position


func _physics_process(_delta: float) -> void:
	position = base + eje * sin(Ayuda.tiempo() * velocidad + fase) * amplitud
