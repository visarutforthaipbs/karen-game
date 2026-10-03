class_name OnlineBoard
extends RefCounted

## Opt-in online leaderboard client (beta). Honor-system server; every failure
## is silent during gameplay; explicit score deletion reports success/failure.
## Nothing runs unless the player
## turned GameSettings.online_board on.

const BASE_URL = "https://undertwoskies-board.undertwoskies-game.workers.dev"
const GAME_VERSION = "beta3"
const TIMEOUT = 10.0

static func enabled() -> bool:
	GameSettings.ensure_loaded()
	return GameSettings.online_board

## Pure payload builder (no IO)
static func build_payload(state: Node) -> Dictionary:
	GameSettings.ensure_loaded()
	var st: Dictionary = state.stats
	var plots = int(st.get("plots_completed", 0))
	return {
		"client_id": GameSettings.client_id,
		"secret": GameSettings.client_secret,
		"name": SaveGame.sanitize_name(GameSettings.player_name),
		"plots": plots,
		"year": int(state.current_year),
		"avg_ash": float(st.get("ash_sum", 0.0)) / maxf(1.0, plots),
		"detections": int(st.get("hotspots_detected", 0)) + int(st.get("drone_photos", 0)) + int(st.get("camera_trips", 0)) + int(st.get("ranger_sightings", 0)),
		"cause": state.end_cause(),
		"version": GAME_VERSION,
		"mode": "endless",
		"week": "",
	}

static func _hex(n: int, digits: int) -> String:
	return ("%0" + str(digits) + "x") % n

## Creates (once) a random anonymous id and secret and saves them
static func ensure_identity() -> void:
	GameSettings.ensure_loaded()
	if GameSettings.client_id != "" and GameSettings.client_secret != "":
		return
	GameSettings.client_id = "%s-%s-%s-%s-%s" % [
		_hex(randi(), 8), _hex(randi() & 0xFFFF, 4), _hex(randi() & 0xFFFF, 4),
		_hex(randi() & 0xFFFF, 4), _hex((randi() << 16) ^ randi(), 12)]
	GameSettings.client_secret = _hex(randi(), 8) + _hex(randi(), 8) + _hex(randi(), 8) + _hex(randi(), 8)
	GameSettings.save_settings()

static func _make_request(parent: Node) -> HTTPRequest:
	if parent == null or not is_instance_valid(parent) or not parent.is_inside_tree():
		return null
	var http = HTTPRequest.new()
	http.timeout = TIMEOUT
	parent.add_child(http)
	return http

static func _send(parent: Node, method: int, url: String, headers: PackedStringArray, body: String, on_json: Callable, on_failure: Callable = Callable()) -> void:
	var http = _make_request(parent)
	if http == null:
		if on_failure.is_valid():
			on_failure.call()
		return
	http.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, data: PackedByteArray):
		var succeeded = false
		if result == HTTPRequest.RESULT_SUCCESS and code >= 200 and code < 300:
			var parsed = JSON.parse_string(data.get_string_from_utf8())
			if parsed is Dictionary and bool(parsed.get("ok", false)) and on_json.is_valid():
				succeeded = true
				on_json.call(parsed)
		if not succeeded and on_failure.is_valid():
			on_failure.call()
		if is_instance_valid(http):
			http.queue_free(), CONNECT_ONE_SHOT)
	if http.request(url, headers, method, body) != OK:
		http.queue_free()
		if on_failure.is_valid():
			on_failure.call()

static func submit(parent: Node, state: Node, on_rank: Callable = Callable()) -> void:
	if not enabled():
		return
	ensure_identity()
	var body = JSON.stringify(build_payload(state))
	_send(parent, HTTPClient.METHOD_POST, BASE_URL + "/v1/scores", PackedStringArray(["Content-Type: application/json"]), body, func(res: Dictionary):
		var rank = res.get("rank", null)
		if (rank is float or rank is int) and on_rank.is_valid():
			on_rank.call(int(rank)))

static func fetch_top(parent: Node, n: int, on_rows: Callable) -> void:
	if not enabled():
		return
	var url = "%s/v1/top?mode=endless&week=&n=%d" % [BASE_URL, n]
	_send(parent, HTTPClient.METHOD_GET, url, PackedStringArray(), "", func(res: Dictionary):
		var rows = res.get("rows", null)
		if rows is Array and on_rows.is_valid():
			on_rows.call(rows))

## Completion receives a deleted count on success, or -1 on failure.
static func delete_my_scores(parent: Node, on_done: Callable = Callable()) -> void:
	GameSettings.ensure_loaded()
	if GameSettings.client_id == "" or GameSettings.client_secret == "":
		if on_done.is_valid():
			on_done.call(-1)
		return
	var url = "%s/v1/scores?client_id=%s&secret=%s" % [BASE_URL, GameSettings.client_id.uri_encode(), GameSettings.client_secret.uri_encode()]
	_send(parent, HTTPClient.METHOD_DELETE, url, PackedStringArray(), "", func(res: Dictionary):
		if on_done.is_valid():
			on_done.call(int(res.get("deleted", 0))), func():
		if on_done.is_valid():
			on_done.call(-1))
