extends Node3D

const PLAYER_SCENE: PackedScene = preload("res://escenas/jugador/jugador.tscn")
const APP_ID: String = "plantillamj2026"
const MAX_PLAYERS: int = 4
const JOIN_TIMEOUT: float = 10.0

static var pending_message: String = ""

var mode: String = ""
var private_game: bool = false
var private_code: String = ""
var game_name: String = ""
var joining: bool = false
var join_token: int = 0

@onready var net: Node = $Red
@onready var multiplayer_spawner: MultiplayerSpawner = $MultiplayerSpawner
@onready var players_container: Node = $Players
@onready var lan = $LanDiscovery
@onready var menu = $CanvasLayer/Menu
@onready var hud = $CanvasLayer/Hud


func _ready() -> void:
	multiplayer_spawner.spawn_function = _spawn_player
	lan.app_id = APP_ID
	lan.games_changed.connect(menu.set_games)
	lan.listen_failed.connect(func(): menu.show_message("No se pudo buscar partidas en esta red"))

	menu.solo_pressed.connect(_on_solo)
	menu.create_confirmed.connect(_on_create)
	menu.join_requested.connect(_on_join)
	menu.quit_pressed.connect(func(): get_tree().quit())
	menu.join_screen_opened.connect(lan.start_listening)
	menu.join_screen_closed.connect(lan.stop_listening)
	hud.leave_pressed.connect(func(): _back_to_menu(""))

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

	if pending_message != "":
		menu.show_message(pending_message)
		pending_message = ""


func _enter_world(info: String) -> void:
	menu.visible = false
	hud.visible = true
	hud.set_info(info)


func _back_to_menu(message: String) -> void:
	pending_message = message
	lan.stop_advertising()
	lan.stop_listening()
	net.leave()
	get_tree().reload_current_scene()


func _device_name() -> String:
	var n := OS.get_model_name()
	if n == "" or n == "GenericDevice":
		return "Jugador"
	return n


func _on_solo() -> void:
	mode = "solo"
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_enter_world("Un jugador")
	_spawn_player_for_peer(1)


func _on_create(is_private: bool, code: String, p_name: String) -> void:
	private_game = is_private
	private_code = code
	game_name = p_name if p_name != "" else "Partida de " + _device_name()
	if net.host(MAX_PLAYERS - 1) != OK:
		menu.show_message("No se pudo crear la partida")
		return
	mode = "host"
	lan.start_advertising({"name": game_name, "priv": private_game, "port": net.port,
		"code": private_code, "n": 1, "max": MAX_PLAYERS})
	_enter_world(game_name + " - Código: " + private_code if private_game else game_name)
	_spawn_player_for_peer(1)


func _on_join(entry: Dictionary, code: String) -> void:
	var p: int = lan.resolve(entry, code)
	if p <= 0:
		menu.show_code_error("Código incorrecto")
		return
	lan.stop_listening()
	_start_join(str(entry.get("ip", "")), p, JOIN_TIMEOUT)


func _start_join(ip: String, p: int, timeout: float) -> void:
	if net.join(ip, p) != OK:
		_show_join_screen("No se pudo conectar a la partida")
		return
	joining = true
	join_token += 1
	var token := join_token
	menu.show_message("Conectando...")
	get_tree().create_timer(timeout).timeout.connect(func():
		if token == join_token:
			_on_join_timeout())


func _on_join_timeout() -> void:
	if not joining:
		return
	joining = false
	net.leave()
	_show_join_screen("No se pudo conectar a la partida")


func _show_join_screen(message: String) -> void:
	menu.show_message(message)
	menu.show_join()


func _on_connected_to_server() -> void:
	joining = false
	mode = "client"
	_enter_world("Conectado")


func _on_connection_failed() -> void:
	if not joining:
		return
	joining = false
	net.leave()
	_show_join_screen("No se pudo conectar a la partida")


func _on_server_disconnected() -> void:
	if mode == "client":
		_back_to_menu("El anfitrión cerró la partida")


func _on_peer_connected(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	if players_container.get_child_count() >= MAX_PLAYERS:
		net.kick(peer_id)
		return
	_spawn_player_for_peer(peer_id)
	lan.set_count(players_container.get_child_count())


func _on_peer_disconnected(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	var player_node = players_container.get_node_or_null(str(peer_id))
	if player_node:
		player_node.queue_free()
	await get_tree().process_frame
	if is_inside_tree() and mode == "host":
		lan.set_count(players_container.get_child_count())


func _spawn_player_for_peer(peer_id: int) -> void:
	multiplayer_spawner.spawn(peer_id)


func _spawn_player(data: Variant = null) -> Node:
	var player: CharacterBody3D = PLAYER_SCENE.instantiate()
	player.name = str(data)
	return player
