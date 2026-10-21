extends CharacterBody3D

@export var speed: float = 5.0
@export var jump_velocity: float = 4.5
@export var look_sensitivity: float = 0.005
@export var camera_distance: float = 4.0
@export var eye_height: float = 1.6
@export var sync_interval: float = 0.033
@export var smooth_speed: float = 20.0
@export var max_extrapolacion: float = 0.15
@export var climb_speed: float = 3.5

var yaw: float = 0.0
var pitch: float = -0.3
var first_person: bool = false
var look_touch: int = -1
var jump_requested: bool = false
var net_position: Vector3 = Vector3.ZERO
var net_rotation: float = 0.0
var net_velocity: Vector3 = Vector3.ZERO
var desde_sync: float = 0.0
var got_first_sync: bool = false
var sync_t: float = 0.0
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var escalando: int = 0
var climb_cd: float = 0.0
var impulso: Vector3 = Vector3.ZERO
var punto_reaparicion: Vector3 = Vector3.ZERO
var fire_cd: float = 0.0
var accion_requested: bool = false
var btn_disparar: Button
var btn_accion: Button
var etiqueta: Label3D
var mundo: Node = null
var vehiculo: Node3D = null

@onready var body_mesh: MeshInstance3D = $Cuerpo
@onready var pivot: Node3D = $Pivote
@onready var arm: SpringArm3D = $Pivote/Brazo
@onready var camera: Camera3D = $Pivote/Brazo/Camara
@onready var ui: CanvasLayer = $Interfaz
@onready var btn_camera: Button = $Interfaz/Raiz/BtnCamara
@onready var btn_jump: Button = $Interfaz/Raiz/BtnSaltar


func _ready() -> void:
	set_multiplayer_authority(name.to_int())
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.from_hsv(fmod(absf(name.to_float()) * 0.618, 1.0), 0.65, 0.95)
	body_mesh.material_override = mat
	position = _spawn_point()
	net_position = position
	punto_reaparicion = position
	add_to_group("jugadores")
	mundo = get_tree().get_first_node_in_group("mundo")
	_crear_etiqueta()
	if is_multiplayer_authority():
		arm.add_excluded_object(get_rid())
		_registrar_acciones()
		_crear_botones()
		camera.make_current()
		btn_camera.pressed.connect(toggle_camera)
		btn_jump.button_down.connect(func(): jump_requested = true)
		_apply_camera_mode()
	else:
		ui.queue_free()
		pivot.queue_free()
		set_process_input(false)
		set_process(false)


func _spawn_point() -> Vector3:
	var id := absi(name.to_int())
	return Vector3((id % 5 - 2) * 2.0, 1.0, (floori(id / 7.0) % 3 - 1) * 2.0)


func toggle_camera() -> void:
	first_person = not first_person
	_apply_camera_mode()


func _apply_camera_mode() -> void:
	arm.spring_length = 0.0 if first_person else camera_distance
	body_mesh.visible = not first_person


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if look_touch == -1 and _in_look_area(event.position):
				look_touch = event.index
		elif event.index == look_touch:
			look_touch = -1
	elif event is InputEventScreenDrag and event.index == look_touch:
		yaw -= event.relative.x * look_sensitivity
		pitch = clampf(pitch - event.relative.y * look_sensitivity, -1.3, 1.2)


func _in_look_area(pos: Vector2) -> bool:
	var size := get_viewport().get_visible_rect().size
	if pos.x < size.x * 0.4:
		return false
	for c in [btn_camera, btn_jump, btn_disparar, btn_accion]:
		if c.get_global_rect().has_point(pos):
			return false
	return true


func _process(delta: float) -> void:
	if vehiculo != null:
		var objetivo: Vector3 = vehiculo.global_position + Vector3(0.0, 1.8, 0.0)
		pivot.global_position = pivot.global_position.lerp(objetivo, clampf(delta * 15.0, 0.0, 1.0))
	else:
		pivot.global_position = global_position + Vector3(0.0, eye_height, 0.0)
	pivot.rotation = Vector3(pitch, yaw, 0.0)


func _physics_process(delta: float) -> void:
	_actualizar_etiqueta()
	if is_multiplayer_authority():
		if vehiculo != null:
			_conduciendo(delta)
		else:
			_move(delta)
		_acciones(delta)
		if position.y < -25.0:
			reaparecer_plaza()
		sync_t += delta
		if sync_t >= sync_interval:
			sync_t = 0.0
			_sync_state.rpc(position, rotation.y, velocity)
	else:
	
		desde_sync += delta
		if desde_sync < max_extrapolacion and vehiculo == null:
			net_position += net_velocity * delta
		var k := clampf(delta * smooth_speed, 0.0, 1.0)
		position = position.lerp(net_position, k)
		rotation.y = lerp_angle(rotation.y, net_rotation, k)


func _move(delta: float) -> void:
	climb_cd = maxf(0.0, climb_cd - delta)
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var quiere_saltar: bool = jump_requested or Input.is_action_just_pressed("ui_accept")
	jump_requested = false
	if escalando > 0 and climb_cd <= 0.0:
		_mover_trepando(delta, input_dir, quiere_saltar)
		return
	if not is_on_floor():
		velocity.y -= gravity * delta
	if is_on_floor() and quiere_saltar:
		velocity.y = jump_velocity
	var dir := Basis(Vector3.UP, yaw) * Vector3(input_dir.x, 0.0, input_dir.y)
	if dir.length() > 0.01:
		dir = dir.normalized()
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
		if not first_person:
			rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), clampf(delta * 12.0, 0.0, 1.0))
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed)
		velocity.z = move_toward(velocity.z, 0.0, speed)
	velocity.x += impulso.x
	velocity.z += impulso.z
	impulso = impulso.move_toward(Vector3.ZERO, 4.0 * delta)
	if first_person:
		rotation.y = yaw
	move_and_slide()


func _mover_trepando(delta: float, input_dir: Vector2, quiere_saltar: bool) -> void:
	velocity.y = -input_dir.y * climb_speed
	var lat := Basis(Vector3.UP, yaw) * Vector3(input_dir.x, 0.0, 0.0)
	velocity.x = lat.x * speed * 0.6
	velocity.z = lat.z * speed * 0.6
	rotation.y = lerp_angle(rotation.y, yaw, clampf(delta * 12.0, 0.0, 1.0))
	if quiere_saltar:
		climb_cd = 0.5
		impulso = (Basis(Vector3.UP, yaw) * Vector3(0.0, 0.0, 1.0)) * 3.5
		velocity.y = jump_velocity + 0.5
	move_and_slide()


func subir_a(v: Node3D) -> void:
	vehiculo = v
	if is_multiplayer_authority():
		arm.add_excluded_object(v.get_rid())
		arm.spring_length = 7.5
		pitch = -0.3
	body_mesh.visible = false
	$Colision.set_deferred("disabled", true)
	velocity = Vector3.ZERO
	impulso = Vector3.ZERO
	escalando = 0


func bajar_de(v: Node3D) -> void:
	vehiculo = null
	if is_multiplayer_authority():
		arm.remove_excluded_object(v.get_rid())
		_apply_camera_mode()
	body_mesh.visible = not (is_multiplayer_authority() and first_person)
	$Colision.set_deferred("disabled", false)
	var lado: Vector3 = v.global_basis.x * 2.4
	position = v.global_position + lado + Vector3(0.0, 0.8, 0.0)
	velocity = Vector3.ZERO
	net_position = position


func _conduciendo(delta: float) -> void:
	position = vehiculo.position + Vector3(0.0, 0.8, 0.0)
	rotation.y = vehiculo.rotation.y
	net_position = position
	if look_touch == -1:
		yaw = lerp_angle(yaw, vehiculo.rotation.y, clampf(delta * 3.0, 0.0, 1.0))
		pitch = lerpf(pitch, -0.3, clampf(delta * 2.0, 0.0, 1.0))



func impulsar(horizontal: Vector3, vertical: float) -> void:
	impulso = horizontal
	velocity.y = vertical
	climb_cd = 0.4


func entrar_escalada() -> void:
	escalando += 1


func salir_escalada(dir_pared: Vector3) -> void:
	escalando = maxi(0, escalando - 1)
	
	if escalando == 0 and climb_cd <= 0.0 and velocity.y > 0.5:
		impulsar(dir_pared * 3.5, 5.5)



func reaparecer() -> void:
	position = punto_reaparicion
	velocity = Vector3.ZERO
	impulso = Vector3.ZERO
	net_position = position



func reaparecer_plaza() -> void:
	punto_reaparicion = _spawn_point()
	reaparecer()


func _acciones(delta: float) -> void:
	fire_cd = maxf(0.0, fire_cd - delta)
	if fire_cd <= 0.0 and (btn_disparar.is_pressed() or Input.is_action_pressed("disparar")):
		fire_cd = 0.25
		if mundo != null:
			mundo.pedir_disparo(camera.global_position, -camera.global_basis.z)
	if accion_requested or Input.is_action_just_pressed("accion"):
		accion_requested = false
		if mundo != null:
			mundo.pedir_accion()


func _registrar_acciones() -> void:
	_accion_tecla("disparar", KEY_F)
	_accion_tecla("accion", KEY_E)


func _accion_tecla(nombre: StringName, tecla: Key) -> void:
	if InputMap.has_action(nombre):
		return
	InputMap.add_action(nombre)
	var ev := InputEventKey.new()
	ev.physical_keycode = tecla
	InputMap.action_add_event(nombre, ev)


func _crear_botones() -> void:
	var raiz: Control = $Interfaz/Raiz
	btn_disparar = _boton("Disparar", -430.0, -230.0, -260.0, -60.0, raiz)
	btn_accion = _boton("Acción", -230.0, -410.0, -60.0, -250.0, raiz)
	btn_accion.button_down.connect(func(): accion_requested = true)
	var mira := Label.new()
	mira.text = "+"
	mira.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mira.add_theme_font_size_override("font_size", 36)
	mira.add_theme_constant_override("outline_size", 8)
	mira.add_theme_color_override("font_outline_color", Color.BLACK)
	mira.anchor_left = 0.5
	mira.anchor_right = 0.5
	mira.anchor_top = 0.5
	mira.anchor_bottom = 0.5
	mira.offset_left = -12.0
	mira.offset_right = 12.0
	mira.offset_top = -24.0
	mira.offset_bottom = 24.0
	raiz.add_child(mira)


func _boton(texto: String, izq: float, arriba: float, der: float, abajo: float, padre: Control) -> Button:
	var b := Button.new()
	b.text = texto
	b.focus_mode = Control.FOCUS_NONE
	b.anchor_left = 1.0
	b.anchor_right = 1.0
	b.anchor_top = 1.0
	b.anchor_bottom = 1.0
	b.offset_left = izq
	b.offset_top = arriba
	b.offset_right = der
	b.offset_bottom = abajo
	b.add_theme_font_size_override("font_size", 30)
	padre.add_child(b)
	return b


func _crear_etiqueta() -> void:
	etiqueta = Label3D.new()
	etiqueta.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	etiqueta.pixel_size = 0.006
	etiqueta.font_size = 48
	etiqueta.outline_size = 12
	etiqueta.position = Vector3(0.0, 2.25, 0.0)
	etiqueta.visible = not is_multiplayer_authority()
	add_child(etiqueta)


func _actualizar_etiqueta() -> void:
	if etiqueta == null or not etiqueta.visible:
		return
	var id: int = name.to_int()
	var v: int = 100
	if mundo != null:
		v = int(mundo.vidas.get(id, 100))
	var t: String = "%s  HP %d" % [Ayuda.nombre_jugador(id), v]
	if t != etiqueta.text:
		etiqueta.text = t


@rpc("any_peer", "call_remote", "unreliable")
func _sync_state(pos: Vector3, rot_y: float, vel: Vector3) -> void:
	if multiplayer.get_remote_sender_id() != get_multiplayer_authority():
		return
	net_position = pos
	net_rotation = rot_y
	net_velocity = vel
	desde_sync = 0.0
	if not got_first_sync or position.distance_to(pos) > 3.0:
		got_first_sync = true
		position = pos
		rotation.y = rot_y
