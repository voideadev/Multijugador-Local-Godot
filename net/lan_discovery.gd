extends Node

signal games_changed(list: Array)
signal listen_failed

const PORT: int = 47891
const SEND_INTERVAL: float = 1.0
const EXPIRE_MS: int = 3500
const MAGIC: String = "plantilla-mj"

var app_id: String = ""
var advertising: bool = false
var listening: bool = false
var payload: Dictionary = {}
var send_t: float = 0.0
var found: Dictionary = {}
var sender := PacketPeerUDP.new()
var listener := PacketPeerUDP.new()
var responder := PacketPeerUDP.new()
var replier := PacketPeerUDP.new()
var prober := PacketPeerUDP.new()
var probe_t: float = 0.0


func start_advertising(info: Dictionary) -> void:
	var gid := randi()
	payload = {"m": MAGIC, "app": app_id, "gid": gid, "name": str(info.get("name", "Taller")),
		"priv": bool(info.get("priv", false)), "n": int(info.get("n", 1)), "max": int(info.get("max", 4))}
	if payload.priv:
		var salt := str(randi())
		payload["salt"] = salt
		payload["enc"] = _encrypt(str(info.port), str(info.code), salt)
		payload["chk"] = _check(str(info.port), str(info.code), salt)
	else:
		payload["port"] = int(info.port)
	sender.set_broadcast_enabled(true)
	sender.set_dest_address("255.255.255.255", PORT)
	advertising = true
	send_t = SEND_INTERVAL
	if not responder.is_bound():
		responder.bind(PORT)


func set_count(n: int) -> void:
	if advertising:
		payload["n"] = n
		send_t = SEND_INTERVAL


func stop_advertising() -> void:
	advertising = false
	sender.close()
	responder.close()


func start_listening() -> void:
	if listening:
		return
	if listener.bind(PORT) != OK:
		listener.close()
		listen_failed.emit()
		return
	listening = true
	probe_t = 0.0
	prober.set_broadcast_enabled(true)
	found.clear()
	games_changed.emit([])


func stop_listening() -> void:
	listening = false
	listener.close()
	prober.close()
	found.clear()



func resolve(entry: Dictionary, code: String) -> int:
	if not bool(entry.get("priv", false)):
		return int(entry.get("port", 0))
	var c := code.strip_edges()
	if c.is_empty():
		return 0
	var salt := str(entry.get("salt", ""))
	var key := (c + salt).sha256_buffer()
	var enc := str(entry.get("enc", "")).hex_decode()
	if enc.is_empty() or enc.size() > key.size():
		return 0
	var out := PackedByteArray()
	for i in enc.size():
		out.append(enc[i] ^ key[i])
	var port_text := out.get_string_from_ascii()
	if _check(port_text, c, salt) != str(entry.get("chk", "")):
		return 0
	return int(port_text)


func _encrypt(text: String, code: String, salt: String) -> String:
	var key := (code.strip_edges() + salt).sha256_buffer()
	var raw := text.to_ascii_buffer()
	var out := PackedByteArray()
	for i in raw.size():
		out.append(raw[i] ^ key[i])
	return out.hex_encode()


func _check(text: String, code: String, salt: String) -> String:
	return (code.strip_edges() + salt + text).sha256_text().left(12)


func _probe_targets() -> Array:
	var out: Array = ["255.255.255.255"]
	for a in IP.get_local_addresses():
		var parts: PackedStringArray = str(a).split(".")
		if parts.size() != 4 or parts[0] == "127" or parts[0] == "169":
			continue
		var base := parts[0] + "." + parts[1] + "." + parts[2] + "."
		for t in [base + "255", base + "1"]:
			if not out.has(t) and t != str(a):
				out.append(t)
	return out


func _send_probe() -> void:
	var data := JSON.stringify({"m": MAGIC, "app": app_id, "q": 1}).to_utf8_buffer()
	for t in _probe_targets():
		prober.set_dest_address(t, PORT)
		prober.put_packet(data)


func _answer_requests() -> void:
	while responder.get_available_packet_count() > 0:
		var text := responder.get_packet().get_string_from_utf8()
		var ip := responder.get_packet_ip()
		var d = JSON.parse_string(text)
		if typeof(d) != TYPE_DICTIONARY or not d.has("q"):
			continue
		if str(d.get("m", "")) != MAGIC or str(d.get("app", "")) != app_id:
			continue
		replier.set_dest_address(ip, PORT)
		replier.put_packet(JSON.stringify(payload).to_utf8_buffer())


func _process(delta: float) -> void:
	if advertising:
		_answer_requests()
		send_t += delta
		if send_t >= SEND_INTERVAL:
			send_t = 0.0
			sender.put_packet(JSON.stringify(payload).to_utf8_buffer())
	if listening:
		probe_t += delta
		if probe_t >= SEND_INTERVAL:
			probe_t = 0.0
			_send_probe()
		var changed := false
		while listener.get_available_packet_count() > 0:
			var text := listener.get_packet().get_string_from_utf8()
			var ip := listener.get_packet_ip()
			if _handle(text, ip):
				changed = true
		var now := Time.get_ticks_msec()
		for key in found.keys():
			if now - int(found[key].seen) > EXPIRE_MS:
				found.erase(key)
				changed = true
		if changed:
			_emit_list()


func _handle(text: String, ip: String) -> bool:
	var d = JSON.parse_string(text)
	if typeof(d) != TYPE_DICTIONARY or d.has("q"):
		return false
	if str(d.get("m", "")) != MAGIC or str(d.get("app", "")) != app_id:
		return false
	var key := ip + ":" + str(d.get("gid", 0))
	var entry := {"key": key, "ip": ip, "name": str(d.get("name", "Taller")), "priv": bool(d.get("priv", false)),
		"n": int(d.get("n", 1)), "max": int(d.get("max", 4)), "port": int(d.get("port", 0)),
		"salt": str(d.get("salt", "")), "enc": str(d.get("enc", "")), "chk": str(d.get("chk", "")),
		"seen": Time.get_ticks_msec()}
	var old = found.get(key)
	found[key] = entry
	if old == null:
		return true
	return int(old.n) != entry.n or str(old.name) != entry.name


func _emit_list() -> void:
	var list: Array = found.values()
	list.sort_custom(func(a, b): return str(a.name) < str(b.name))
	games_changed.emit(list)
