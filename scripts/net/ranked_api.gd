extends RefCounted
## The house: the server ranked matches are played on, which keeps the
## standings and the figures (the API in server/, see its README). Every call
## is a request over HTTP that comes back as a Dictionary: {ok, status, data,
## error}, where `error` is an English text for the player (Loc translates it).
## No class name: preload it.
##
## Where the house is: `--ranked-url=<url>` on the command line, or the
## `[ranked] url` of the settings file, or DEFAULT_URL. Empty: there is no
## house yet, and the ranked screens say so.
##
## A member signs in once; the game keeps the token the house gave them
## (Settings.ranked_token), never the password.

## Fill in with the address of the VPS once the house is open, e.g.
## "https://liar.example.com". The settings file and the command line win.
const DEFAULT_URL := ""
const TIMEOUT := 10.0

static var _url := ""
static var _url_read := false


static func url() -> String:
	if not _url_read:
		_url_read = true
		_url = DEFAULT_URL
		if Settings.ranked_url != "":
			_url = Settings.ranked_url
		for arg: String in OS.get_cmdline_user_args() + OS.get_cmdline_args():
			if arg.begins_with("--ranked-url="):
				_url = arg.trim_prefix("--ranked-url=")
		_url = _url.strip_edges().trim_suffix("/")
	return _url


static func configured() -> bool:
	return url() != ""


static func signed_in() -> bool:
	return Settings.ranked_token != ""


## Calls the house: `method` (HTTPClient.METHOD_*), `path` from the root
## ("/v1/standings"), `body` sent as JSON (null: none), with the member's
## token when `auth` (`token`, if given: a member other than the one signed in
## on this machine, as the tests have).
static func call_house(method: int, path: String, body: Variant = null, auth := true, token := "") -> Dictionary:
	if not configured():
		return {"ok": false, "status": 0, "data": null, "error": "The house has no address yet."}
	var tree := Engine.get_main_loop() as SceneTree
	var http := HTTPRequest.new()
	http.timeout = TIMEOUT
	http.accept_gzip = true
	# Deferred: the screen asking may be on its way into the tree.
	tree.root.add_child.call_deferred(http)
	await http.ready
	var headers := PackedStringArray(["Accept: application/json"])
	var text := ""
	if body != null:
		headers.append("Content-Type: application/json")
		text = JSON.stringify(body)
	var key := token if token != "" else Settings.ranked_token
	if auth and key != "":
		headers.append("Authorization: Bearer " + key)
	var problem := http.request(url() + path, headers, method, text)
	if problem != OK:
		http.queue_free()
		return {"ok": false, "status": 0, "data": null, "error": "Could not reach the house."}
	var done: Array = await http.request_completed
	http.queue_free()
	var result: int = done[0]
	var status: int = done[1]
	var raw: PackedByteArray = done[3]
	if result != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "status": 0, "data": null, "error": "Could not reach the house."}
	var data: Variant = JSON.parse_string(raw.get_string_from_utf8()) if raw.size() > 0 else null
	if status >= 200 and status < 300:
		return {"ok": true, "status": status, "data": data, "error": ""}
	if status == 401 and token == "":
		# The token is no good any more: the member signs in again.
		forget_member()
	var said := ""
	if data is Dictionary:
		said = str(data.get("error", data.get("detail", "")))
	return {"ok": false, "status": status, "data": data, "error": said if said != "" else "The house turned the request down."}


static func get_json(path: String, auth := true, token := "") -> Dictionary:
	return await call_house(HTTPClient.METHOD_GET, path, null, auth, token)


static func post_json(path: String, body: Variant = {}, auth := true, token := "") -> Dictionary:
	return await call_house(HTTPClient.METHOD_POST, path, body, auth, token)


static func delete_json(path: String) -> Dictionary:
	return await call_house(HTTPClient.METHOD_DELETE, path)


## Signs in (`new_member` false) or joins the house as a new member. The
## token is kept; returns the call's result, with the profile in data.me.
static func enter(member_name: String, password: String, new_member: bool) -> Dictionary:
	var answer: Dictionary = await post_json("/v1/accounts" if new_member else "/v1/sessions",
			{"name": member_name, "password": password}, false)
	if answer.ok and answer.data is Dictionary:
		Settings.ranked_token = str(answer.data.get("token", ""))
		Settings.ranked_name = str(answer.data.get("me", {}).get("name", member_name))
		Settings.save()
	return answer


static func sign_out() -> void:
	if signed_in():
		await delete_json("/v1/sessions")
	forget_member()


static func forget_member() -> void:
	Settings.ranked_token = ""
	Settings.save()
