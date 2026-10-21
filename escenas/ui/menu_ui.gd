extends Control

signal solo_pressed
signal create_confirmed(is_private: bool, code: String, game_name: String)
signal join_requested(entry: Dictionary, code: String)
signal quit_pressed
signal join_screen_opened
signal join_screen_closed

var games: Array = []
var pending_entry: Dictionary = {}
var message_token: int = 0

@onready var screens: Array = [%Principal, %Multi, %Crear, %Unirse, %Codigo]


func _ready() -> void:
	%BtnSolo.pressed.connect(func(): solo_pressed.emit())
	%BtnMulti.pressed.connect(func(): show_screen(%Multi))
	%BtnSalir.pressed.connect(func(): quit_pressed.emit())
	%BtnAtrasMulti.pressed.connect(show_main)
	%BtnCrear.pressed.connect(_open_create)
	%BtnUnirse.pressed.connect(show_join)
	%BtnPublica.toggled.connect(func(_on): _refresh_type())
	%BtnPrivada.toggled.connect(func(_on): _refresh_type())
	%BtnConfirmarCrear.pressed.connect(_confirm_create)
	%BtnAtrasCrear.pressed.connect(func(): show_screen(%Multi))
	%BtnAtrasUnirse.pressed.connect(_leave_join)
	%BtnEntrar.pressed.connect(_confirm_code)
	%BtnCancelarCodigo.pressed.connect(func(): show_screen(%Unirse))
	%Mensaje.text = ""
	show_main()


func show_screen(target: Control) -> void:
	for s in screens:
		s.visible = s == target


func show_main() -> void:
	show_screen(%Principal)


func show_multi() -> void:
	show_screen(%Multi)


func show_join() -> void:
	show_screen(%Unirse)
	join_screen_opened.emit()
	_rebuild_list()


func _leave_join() -> void:
	join_screen_closed.emit()
	show_screen(%Multi)


func _open_create() -> void:
	%BtnPublica.button_pressed = true
	%CodigoCrear.text = str(randi_range(1000, 9999))
	%NombreCrear.text = ""
	_refresh_type()
	show_screen(%Crear)


func _refresh_type() -> void:
	%FilaCodigo.visible = %BtnPrivada.button_pressed


func _confirm_create() -> void:
	var is_private: bool = %BtnPrivada.button_pressed
	var code: String = %CodigoCrear.text.strip_edges()
	if is_private and code.is_empty():
		show_message("Escribe un código para la partida privada")
		return
	create_confirmed.emit(is_private, code, %NombreCrear.text.strip_edges())


func _confirm_code() -> void:
	var code: String = %CodigoUnirse.text.strip_edges()
	if code.is_empty():
		%ErrorCodigo.text = "Escribe el código"
		return
	%ErrorCodigo.text = ""
	join_requested.emit(pending_entry, code)


func show_code_error(text: String) -> void:
	%ErrorCodigo.text = text


func set_games(list: Array) -> void:
	games = list
	if %Unirse.visible:
		_rebuild_list()


func _rebuild_list() -> void:
	for c in %Lista.get_children():
		c.queue_free()
	%EstadoBusqueda.text = "Elige una partida" if not games.is_empty() else "Buscando partidas en tu wifi..."
	for g in games:
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 84)
		b.add_theme_font_size_override("font_size", 30)
		var t := "%s  (%d/%d)" % [g.name, g.n, g.max]
		if g.priv:
			t += "  [privada]"
		var full: bool = int(g.n) >= int(g.max)
		if full:
			t += "  llena"
		b.text = t
		b.disabled = full
		b.pressed.connect(_on_game_pressed.bind(g))
		%Lista.add_child(b)


func _on_game_pressed(entry: Dictionary) -> void:
	if entry.priv:
		pending_entry = entry
		%CodigoUnirse.text = ""
		%ErrorCodigo.text = ""
		show_screen(%Codigo)
		%CodigoUnirse.grab_focus()
	else:
		join_requested.emit(entry, "")


func show_message(text: String) -> void:
	message_token += 1
	var token := message_token
	%Mensaje.text = text
	await get_tree().create_timer(4.0).timeout
	if token == message_token:
		%Mensaje.text = ""
