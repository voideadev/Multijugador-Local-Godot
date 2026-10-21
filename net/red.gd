extends Node

const DEFAULT_PORT: int = 47892
const PORT_TRIES: int = 10

var peer: ENetMultiplayerPeer = null
var port: int = 0



func host(max_clients: int) -> Error:
	var p: int = DEFAULT_PORT
	for i in PORT_TRIES:
		var candidate := ENetMultiplayerPeer.new()
		if candidate.create_server(p, max_clients) == OK:
			peer = candidate
			port = p
			multiplayer.multiplayer_peer = peer
			return OK
		p += 1
	return ERR_CANT_CREATE


func join(ip: String, p: int) -> Error:
	var candidate := ENetMultiplayerPeer.new()
	var err := candidate.create_client(ip, p)
	if err != OK:
		return err
	peer = candidate
	port = p
	multiplayer.multiplayer_peer = peer
	return OK


func kick(peer_id: int) -> void:
	if peer:
		peer.disconnect_peer(peer_id)


func leave() -> void:
	if peer:
		peer.close()
		peer = null
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
