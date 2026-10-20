extends Node2D
## ABH: Awesome Bullet Heaven - top-down auto-shooter. The whole game is built in code.

# ------------------------------------------------------------------ DATA
const ET: Array = [
	{"name": "Swarmer", "r": 9.0, "hp": 6.0, "speed": 125.0, "dmg": 6.0, "xp": 1.0},
	{"name": "Grunt", "r": 14.0, "hp": 24.0, "speed": 82.0, "dmg": 10.0, "xp": 2.0},
	{"name": "Tank", "r": 25.0, "hp": 110.0, "speed": 52.0, "dmg": 18.0, "xp": 6.0},
	{"name": "Gunner", "r": 13.0, "hp": 28.0, "speed": 72.0, "dmg": 8.0, "xp": 3.0},
	{"name": "Dasher", "r": 12.0, "hp": 20.0, "speed": 78.0, "dmg": 12.0, "xp": 3.0},
]
const ENEMY_COLORS: Array = [
	Color(0.92, 0.35, 0.40), Color(0.88, 0.58, 0.30), Color(0.60, 0.42, 0.80),
	Color(0.35, 0.78, 0.88), Color(0.96, 0.82, 0.30),
]
const UPGRADES: Array = [
	{"id": "dmg", "name": "Heavy Rounds", "desc": "+20% damage", "max": 10},
	{"id": "rate", "name": "Rapid Fire", "desc": "+15% fire rate", "max": 10},
	{"id": "multi", "name": "Multishot", "desc": "+1 projectile", "max": 6},
	{"id": "pierce", "name": "Piercing", "desc": "Bullets pass through +1 enemy", "max": 5},
	{"id": "speed", "name": "Light Boots", "desc": "+10% move speed", "max": 6},
	{"id": "hp", "name": "Iron Heart", "desc": "+25 max HP and heal 25", "max": 8},
	{"id": "regen", "name": "Regeneration", "desc": "+0.8 HP per second", "max": 5},
	{"id": "magnet", "name": "Magnet", "desc": "+35% pickup range", "max": 5},
	{"id": "blades", "name": "Orbiting Blades", "desc": "+1 spinning blade", "max": 6},
	{"id": "nova", "name": "Shock Nova", "desc": "Blast around you, wipes bullets", "max": 5},
	{"id": "crit", "name": "Deadeye", "desc": "+8% crit chance (crits hit 2.5x)", "max": 5},
	{"id": "pspeed", "name": "Hot Barrels", "desc": "+25% bullet speed", "max": 4},
]
const CELL := 64.0

# ------------------------------------------------------------------ STATE
var rng := RandomNumberGenerator.new()
var font: Font
var cam: Camera2D
var hud: Control
var time_anim := 0.0

var screen := "splash"        # menu biomes upgrades achv play levelup paused over
var buttons: Array = []
var toasts: Array = []

# run
var mode := "adventure"       # adventure | horde
var biome_idx := 0
var biome: Dictionary = {}
var run_time := 0.0
var kills := 0
var level := 1
var xp := 0.0
var xp_need := 6.0
var pending_levels := 0
var choices: Array = []
var upg_levels: Dictionary = {}
var P: Dictionary = {}

var player_pos := Vector2.ZERO
var player_hp := 100.0
var aim_dir := Vector2.RIGHT
var invuln_t := 0.0
var fire_cd := 0.0
var dash_t := 0.0
var dash_cd := 0.0
var dash_dir := Vector2.RIGHT
var dash_prev := false
var blade_ang := 0.0
var blade_tick := 0.0
var nova_cd := 3.0
var shake := 0.0
var damage_flash := 0.0
var slow_t := 0.0
var trail: Array = []

var enemies: Array = []
var pbullets: Array = []
var ebullets: Array = []
var gems: Array = []
var particles: Array = []
var dtexts: Array = []
var rings: Array = []
var grid: Dictionary = {}
var big: Array = []
var next_id := 1

var spawn_acc := 0.0
var surge_t := 20.0
var champion_done := false
var horde_next := 75.0
var boss_spawned := false
var boss_ref: Dictionary = {}
var banner_text := ""
var banner_t := 0.0
var ending := ""
var end_timer := 0.0
var ach_timer := 0.0
var regen_acc := 0.0

# results
var res_win := false
var res_souls := 0
var res_new_best := false

# test harness
var test_mode := false
var test_cfg: Array = []
var test_started := false
var test_frames := 0
var bot_move := Vector2.ZERO
var bot_dash := false
var test_menu_i := 0
var splash_t := 0.0

# touch / web
var touch_ui := false
var lite := false
var joy_id := -1
var joy_origin := Vector2.ZERO
var joy_vec := Vector2.ZERO
var dash_id := -1
var dash_touch := false


# ================================================================== SETUP
func _ready() -> void:
	rng.randomize()
	font = ThemeDB.fallback_font
	cam = Camera2D.new()
	add_child(cam)
	cam.make_current()
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	hud = Control.new()
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(hud)
	hud.draw.connect(_draw_hud)
	Game.achievement_unlocked.connect(_on_achievement)
	biome = Game.biomes[0]
	lite = OS.has_feature("web") or OS.has_feature("mobile")
	touch_ui = DisplayServer.is_touchscreen_available() and (OS.has_feature("web") or OS.has_feature("mobile"))
	for a in OS.get_cmdline_user_args():
		if str(a).begins_with("--test="):
			test_mode = true
			test_cfg = str(a).substr(7).split(":")
			screen = "menu"


func vsize() -> Vector2:
	return get_viewport_rect().size


func _on_achievement(id: String) -> void:
	toasts.append({"name": Game.achievement_name(id), "t": 4.5})


# ================================================================== LOOP
func _process(delta: float) -> void:
	time_anim += delta
	if screen == "splash":
		splash_t += delta
	if test_mode:
		_test_tick()
		return
	var dt := minf(delta, 0.033)
	if screen == "play":
		step(dt)
	for t in toasts:
		t["t"] -= delta
	toasts = toasts.filter(func(t): return t["t"] > 0.0)
	update_camera(dt)
	queue_redraw()
	hud.queue_redraw()


func update_camera(dt: float) -> void:
	var off := Vector2.ZERO
	if shake > 0.1:
		off = Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * shake
	shake = maxf(0.0, shake - dt * 40.0)
	if screen == "play" or screen == "levelup" or screen == "paused" or screen == "over":
		cam.position = player_pos + off
	else:
		cam.position = Vector2(time_anim * 25.0, time_anim * 12.0)


# ================================================================== INPUT
func _input(event: InputEvent) -> void:
	if screen == "splash":
		var pressed: bool = (event is InputEventKey and event.pressed and not event.echo) or (event is InputEventMouseButton and event.pressed)
		if pressed and splash_t >= 15.0:
			screen = "menu"
		return
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		_touch_input(event)
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mp := hud.get_local_mouse_position()
		for b in buttons:
			if b["rect"].has_point(mp):
				on_button(b["id"])
				break
	elif event is InputEventKey and event.pressed and not event.echo:
		var k: int = event.keycode
		if k == KEY_ESCAPE:
			if screen == "play":
				screen = "paused"
			elif screen == "paused":
				screen = "play"
			elif screen == "biomes" or screen == "upgrades" or screen == "achv":
				screen = "menu"
		elif screen == "levelup":
			if k == KEY_1 or k == KEY_KP_1:
				choose_upgrade(0)
			elif k == KEY_2 or k == KEY_KP_2:
				choose_upgrade(1)
			elif k == KEY_3 or k == KEY_KP_3:
				choose_upgrade(2)
		elif screen == "over":
			if k == KEY_R or k == KEY_ENTER:
				start_run(mode, biome_idx)
			elif k == KEY_M:
				screen = "menu"


func _touch_input(event: InputEvent) -> void:
	touch_ui = true
	if screen != "play":
		joy_id = -1
		joy_vec = Vector2.ZERO
		dash_id = -1
		dash_touch = false
		return
	var vs := vsize()
	if event is InputEventScreenTouch:
		var p: Vector2 = event.position
		if event.pressed:
			if p.distance_to(dash_center(vs)) < 100.0 and dash_id == -1:
				dash_id = event.index
				dash_touch = true
			elif p.x < vs.x * 0.55 and joy_id == -1:
				joy_id = event.index
				joy_origin = p
				joy_vec = Vector2.ZERO
		else:
			if event.index == joy_id:
				joy_id = -1
				joy_vec = Vector2.ZERO
			if event.index == dash_id:
				dash_id = -1
				dash_touch = false
	elif event is InputEventScreenDrag:
		if event.index == joy_id:
			var d: Vector2 = event.position - joy_origin
			joy_vec = d.limit_length(70.0) / 70.0


func dash_center(vs: Vector2) -> Vector2:
	return Vector2(vs.x - 120.0, vs.y - 130.0)


func on_button(id: String) -> void:
	if id == "adventure":
		screen = "biomes"
	elif id == "horde":
		start_run("horde", 0)
	elif id == "upgrades":
		screen = "upgrades"
	elif id == "achv":
		screen = "achv"
	elif id == "quit":
		get_tree().quit()
	elif id == "back":
		screen = "menu"
	elif id.begins_with("biome_"):
		start_run("adventure", int(id.substr(6)))
	elif id.begins_with("buy_"):
		Game.buy_meta(id.substr(4))
	elif id == "ascend":
		Game.ascend()
	elif id == "resume":
		screen = "play"
	elif id == "pause":
		screen = "paused"
	elif id == "retry":
		start_run(mode, biome_idx)
	elif id == "menu":
		screen = "menu"
	elif id.begins_with("pick_"):
		choose_upgrade(int(id.substr(5)))


func get_input_vector() -> Vector2:
	if joy_vec.length() > 0.12:
		return joy_vec
	var v := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		v.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		v.y += 1.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		v.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		v.x += 1.0
	return v.normalized()


# ================================================================== RUN SETUP
func start_run(m: String, bidx: int) -> void:
	mode = m
	biome_idx = clampi(bidx, 0, Game.biomes.size() - 1)
	biome = Game.biomes[biome_idx]
	run_time = 0.0
	kills = 0
	level = 1
	xp = 0.0
	xp_need = need_for(1)
	pending_levels = 0
	choices = []
	upg_levels = {}
	P = {
		"dmg": 12.0 * Game.meta_mult("m_dmg", 0.05) * Game.prestige_mult(),
		"rate": 5.0 * Game.meta_mult("m_rate", 0.04),
		"multi": 1 + Game.meta_level("m_multi"),
		"pierce": 1,
		"pspeed": 520.0,
		"speed": 230.0 * Game.meta_mult("m_speed", 0.03),
		"max_hp": 100.0 + 10.0 * float(Game.meta_level("m_hp")),
		"regen": 0.0,
		"magnet": 90.0 * Game.meta_mult("m_magnet", 0.10),
		"blades": 0,
		"nova": 0,
		"crit": 0.05,
		"xp_mult": Game.meta_mult("m_xp", 0.05),
	}
	player_pos = Vector2.ZERO
	player_hp = P["max_hp"]
	aim_dir = Vector2.RIGHT
	invuln_t = 1.0
	fire_cd = 0.3
	dash_t = 0.0
	dash_cd = 0.0
	dash_prev = false
	blade_ang = 0.0
	blade_tick = 0.0
	nova_cd = 3.0
	shake = 0.0
	damage_flash = 0.0
	slow_t = 0.0
	trail = []
	enemies = []
	pbullets = []
	ebullets = []
	gems = []
	particles = []
	dtexts = []
	rings = []
	grid = {}
	big = []
	spawn_acc = 0.0
	surge_t = 18.0
	champion_done = false
	horde_next = 75.0
	boss_spawned = false
	boss_ref = {}
	ending = ""
	end_timer = 0.0
	ach_timer = 0.0
	regen_acc = 0.0
	banner("ENTERING " + String(biome["name"]).to_upper() if mode == "adventure" else "HORDE CHALLENGE", 2.5)
	screen = "play"


func need_for(lv: int) -> float:
	return 3.0 + 2.2 * float(lv) + pow(float(lv), 1.5)


func banner(text: String, secs: float) -> void:
	banner_text = text
	banner_t = secs


# ================================================================== STEP
func step(dt_in: float) -> void:
	var dt := dt_in
	if slow_t > 0.0:
		slow_t -= dt_in
		dt = dt_in * 0.35
	if ending == "":
		run_time += dt
	invuln_t = maxf(0.0, invuln_t - dt)
	damage_flash = maxf(0.0, damage_flash - dt)
	banner_t = maxf(0.0, banner_t - dt)
	if mode == "horde":
		var th: int = int(run_time / 90.0) % maxi(1, int(Game.data["biomes_unlocked"]))
		biome_idx = th
		biome = Game.biomes[biome_idx]

	build_grid()
	if ending != "dead":
		update_player(dt)
		auto_fire(dt)
		update_blades(dt)
		update_nova(dt)
	spawn_logic(dt)
	update_enemies(dt)
	update_pbullets(dt)
	update_ebullets(dt)
	update_gems(dt)
	update_fx(dt)
	enemies = enemies.filter(func(e): return not e["dead"])

	ach_timer -= dt
	if ach_timer <= 0.0:
		ach_timer = 0.5
		check_achievements()

	if ending != "":
		end_timer -= dt_in
		if end_timer <= 0.0:
			finish_run()
		return
	if pending_levels > 0:
		open_levelup()


# ------------------------------------------------------------------ player
func update_player(dt: float) -> void:
	var mv := bot_move if test_mode else get_input_vector()
	var want_dash := bot_dash if test_mode else (dash_touch or Input.is_physical_key_pressed(KEY_SPACE) or Input.is_physical_key_pressed(KEY_SHIFT))
	if want_dash and not dash_prev and dash_cd <= 0.0 and dash_t <= 0.0:
		dash_dir = mv if mv != Vector2.ZERO else aim_dir
		dash_t = 0.18
		dash_cd = 1.5
		invuln_t = maxf(invuln_t, 0.28)
		burst(player_pos, Color(0.6, 0.9, 1.0), 10, 160.0, 3.0)
	dash_prev = want_dash
	dash_cd = maxf(0.0, dash_cd - dt)
	if dash_t > 0.0:
		dash_t -= dt
		player_pos += dash_dir * 700.0 * dt
		trail.append({"pos": player_pos, "life": 0.25})
	else:
		player_pos += mv * float(P["speed"]) * dt
	for t in trail:
		t["life"] -= dt
	trail = trail.filter(func(t): return t["life"] > 0.0)
	if float(P["regen"]) > 0.0 and player_hp < float(P["max_hp"]):
		player_hp = minf(float(P["max_hp"]), player_hp + float(P["regen"]) * dt)


func hurt(amount: float) -> void:
	if invuln_t > 0.0 or ending == "dead":
		return
	player_hp -= amount
	invuln_t = 0.45
	shake = maxf(shake, 9.0)
	damage_flash = 0.3
	burst(player_pos, Color(1.0, 0.3, 0.3), 8, 180.0, 3.0)
	if player_hp <= 0.0:
		player_hp = 0.0
		ending = "dead"
		end_timer = 1.4
		shake = 18.0
		burst(player_pos, Color(0.6, 0.9, 1.0), 40, 320.0, 4.0)


# ------------------------------------------------------------------ weapons
func nearest_enemy() -> Dictionary:
	var best: Dictionary = {}
	var bd := 700.0 * 700.0
	for e in enemies:
		if e["dead"]:
			continue
		var d: float = (e["pos"] - player_pos).length_squared()
		if d < bd:
			bd = d
			best = e
	return best


func auto_fire(dt: float) -> void:
	fire_cd -= dt
	if fire_cd > 0.0:
		return
	var t := nearest_enemy()
	if t.is_empty():
		fire_cd = 0.05
		return
	var to: Vector2 = t["pos"] - player_pos
	aim_dir = to.normalized()
	var n: int = int(P["multi"])
	var spread := minf(0.13 * float(n - 1), 1.1)
	for i in n:
		var a := aim_dir.angle()
		if n > 1:
			a += lerpf(-spread * 0.5, spread * 0.5, float(i) / float(n - 1))
		var spd: float = float(P["pspeed"])
		pbullets.append({
			"pos": player_pos + Vector2.from_angle(a) * 18.0,
			"vel": Vector2.from_angle(a) * spd,
			"dmg": float(P["dmg"]),
			"pierce": int(P["pierce"]),
			"life": 0.45 + 0.0005 * spd,
			"r": 5.0,
			"hit": [],
		})
	fire_cd += 1.0 / float(P["rate"])
	if fire_cd < -0.1:
		fire_cd = 0.0


func update_blades(dt: float) -> void:
	var nb: int = int(P["blades"])
	if nb <= 0:
		return
	blade_ang += dt * 3.4
	blade_tick -= dt
	if blade_tick > 0.0:
		return
	blade_tick = 0.14
	var dmg: float = float(P["dmg"]) * 0.65
	for i in nb:
		var bp := blade_pos(i)
		for e in near_enemies(bp):
			var rr: float = float(e["r"]) + 16.0
			if (e["pos"] - bp).length_squared() <= rr * rr:
				damage_enemy(e, dmg, false)


func blade_pos(i: int) -> Vector2:
	var nb: int = int(P["blades"])
	return player_pos + Vector2.from_angle(blade_ang + TAU * float(i) / float(maxi(nb, 1))) * 88.0


func update_nova(dt: float) -> void:
	var lv: int = int(P["nova"])
	if lv <= 0:
		return
	nova_cd -= dt
	if nova_cd > 0.0:
		return
	nova_cd = 4.4 - 0.5 * float(lv)
	var radius := 130.0 + 30.0 * float(lv)
	var dmg := (30.0 + 22.0 * float(lv)) * float(P["dmg"]) / 12.0
	rings.append({"pos": player_pos, "r": 10.0, "maxr": radius, "life": 0.45, "max": 0.45})
	shake = maxf(shake, 5.0)
	for e in enemies:
		if e["dead"]:
			continue
		var diff: Vector2 = e["pos"] - player_pos
		if diff.length() <= radius + float(e["r"]):
			damage_enemy(e, dmg, false)
			if not e["big"]:
				e["pos"] += diff.normalized() * 45.0
	var keep: Array = []
	for b in ebullets:
		if (b["pos"] - player_pos).length() > radius:
			keep.append(b)
	ebullets = keep


func near_enemies(p: Vector2) -> Array:
	var out: Array = []
	var cx := int(floorf(p.x / CELL))
	var cy := int(floorf(p.y / CELL))
	for ox in range(-1, 2):
		for oy in range(-1, 2):
			var lst = grid.get(ckey(cx + ox, cy + oy))
			if lst != null:
				for e in lst:
					if not e["dead"]:
						out.append(e)
	for e in big:
		if not e["dead"]:
			out.append(e)
	return out


func ckey(cx: int, cy: int) -> int:
	return cx * 100003 + cy


func build_grid() -> void:
	grid.clear()
	big.clear()
	for e in enemies:
		if e["dead"]:
			continue
		if e["big"]:
			big.append(e)
			continue
		var p: Vector2 = e["pos"]
		var key := ckey(int(floorf(p.x / CELL)), int(floorf(p.y / CELL)))
		if grid.has(key):
			grid[key].append(e)
		else:
			grid[key] = [e]


# ------------------------------------------------------------------ bullets
func update_pbullets(dt: float) -> void:
	var i := pbullets.size() - 1
	while i >= 0:
		var b: Dictionary = pbullets[i]
		b["pos"] += b["vel"] * dt
		b["life"] -= dt
		var gone: bool = b["life"] <= 0.0
		if not gone:
			gone = bullet_hit(b)
		if gone:
			pbullets[i] = pbullets[pbullets.size() - 1]
			pbullets.pop_back()
		i -= 1


func bullet_hit(b: Dictionary) -> bool:
	var p: Vector2 = b["pos"]
	for e in near_enemies(p):
		if b["hit"].has(e["id"]):
			continue
		var rr: float = float(e["r"]) + float(b["r"])
		if (e["pos"] - p).length_squared() <= rr * rr:
			b["hit"].append(e["id"])
			var dmg: float = b["dmg"]
			var crit: bool = rng.randf() < float(P["crit"])
			if crit:
				dmg *= 2.5
			damage_enemy(e, dmg, crit)
			if not e["big"]:
				var kb: Vector2 = b["vel"]
				e["pos"] += kb.normalized() * 4.0
			b["pierce"] -= 1
			if b["pierce"] < 0:
				return true
	return false


func damage_enemy(e: Dictionary, amount: float, crit: bool) -> void:
	if e["dead"]:
		return
	e["hp"] -= amount
	e["flash"] = 0.07
	if dtexts.size() < (14 if lite else 40) and (crit or rng.randf() < 0.35):
		var p: Vector2 = e["pos"]
		dtexts.append({
			"pos": p + Vector2(rng.randf_range(-8.0, 8.0), -float(e["r"])),
			"life": 0.6, "text": str(int(amount)), "crit": crit,
		})
	if e["hp"] <= 0.0:
		kill_enemy(e)


func kill_enemy(e: Dictionary) -> void:
	e["dead"] = true
	kills += 1
	var p: Vector2 = e["pos"]
	var col: Color = enemy_color(int(e["type"]))
	burst(p, col, 6 if not e["big"] else 40, 170.0, 3.0)
	if e["boss"]:
		on_boss_killed(e)
		return
	if e["big"]:
		shake = maxf(shake, 10.0)
		Game.unlock("boss_slayer")
		for k in 12:
			drop_gem(p + Vector2.from_angle(TAU * float(k) / 12.0) * 30.0, 6.0, 0)
		drop_gem(p, 40.0, 1)
		banner("CHAMPION DEFEATED", 2.0)
		return
	drop_gem(p, float(e["xp"]), 0)
	if rng.randf() < 0.006:
		drop_gem(p + Vector2(10.0, 0.0), 18.0, 1)


func on_boss_killed(e: Dictionary) -> void:
	Game.unlock("boss_slayer")
	ending = "victory"
	end_timer = 3.2
	slow_t = 1.5
	shake = 22.0
	ebullets = []
	var p: Vector2 = e["pos"]
	burst(p, biome["boss_color"], 120, 420.0, 5.0)
	for o in enemies:
		if not o["dead"] and not o["boss"]:
			o["dead"] = true
			burst(o["pos"], enemy_color(int(o["type"])), 3, 120.0, 2.0)
			drop_gem(o["pos"], float(o["xp"]), 0)
	for g in gems:
		g["mag"] = true
	banner(String(e["name"]).to_upper() + " DEFEATED", 3.0)


func drop_gem(p: Vector2, v: float, kind: int) -> void:
	if gems.size() >= 260 and kind == 0:
		var g: Dictionary = gems[rng.randi() % gems.size()]
		g["val"] += v
		return
	gems.append({"pos": p, "val": v, "kind": kind, "mag": false})


func update_gems(dt: float) -> void:
	var rng_m: float = float(P["magnet"])
	var i := gems.size() - 1
	while i >= 0:
		var g: Dictionary = gems[i]
		var to: Vector2 = player_pos - g["pos"]
		var d := to.length()
		if g["mag"] or d < rng_m:
			g["pos"] += to / maxf(d, 0.01) * minf(d, (380.0 + 700.0 * (1.0 - clampf(d / 500.0, 0.0, 1.0))) * dt)
		if d < 18.0 and ending != "dead":
			if g["kind"] == 0:
				xp += float(g["val"]) * float(P["xp_mult"])
				check_level()
			else:
				player_hp = minf(float(P["max_hp"]), player_hp + float(g["val"]))
			gems[i] = gems[gems.size() - 1]
			gems.pop_back()
		i -= 1


func check_level() -> void:
	while xp >= xp_need:
		xp -= xp_need
		level += 1
		xp_need = need_for(level)
		pending_levels += 1


func update_ebullets(dt: float) -> void:
	var i := ebullets.size() - 1
	while i >= 0:
		var b: Dictionary = ebullets[i]
		b["pos"] += b["vel"] * dt
		b["life"] -= dt
		var gone: bool = b["life"] <= 0.0
		if not gone:
			var rr: float = float(b["r"]) + 11.0
			if (b["pos"] - player_pos).length_squared() < rr * rr:
				if invuln_t <= 0.0:
					hurt(float(b["dmg"]))
					gone = true
		if gone:
			ebullets[i] = ebullets[ebullets.size() - 1]
			ebullets.pop_back()
		i -= 1


func enemy_bullet(p: Vector2, v: Vector2, dmg: float, r: float = 6.0) -> void:
	if ebullets.size() > (420 if lite else 700):
		return
	ebullets.append({"pos": p, "vel": v, "dmg": dmg, "r": r, "life": 7.0})


# ------------------------------------------------------------------ enemies
func enemy_color(t: int) -> Color:
	return ENEMY_COLORS[t].lerp(biome["accent"], 0.22)


func hp_scale() -> float:
	if mode == "horde":
		return 1.0 + run_time / 60.0
	return 1.0 + run_time / 130.0


func make_enemy(t: int, p: Vector2) -> Dictionary:
	var d: Dictionary = ET[t]
	var hp: float = float(d["hp"]) * float(biome["hp_mult"]) * hp_scale()
	var e := {
		"id": next_id, "type": t, "pos": p, "r": d["r"], "hp": hp, "maxhp": hp,
		"speed": float(d["speed"]) * (1.0 + 0.04 * float(biome_idx)),
		"dmg": float(d["dmg"]) * (1.0 + 0.2 * float(biome_idx)),
		"xp": d["xp"], "dead": false, "flash": 0.0, "big": false, "boss": false,
		"face": Vector2.RIGHT, "shoot_t": rng.randf_range(1.0, 2.5),
		"state": 0, "state_t": rng.randf_range(1.0, 3.0), "dash_dir": Vector2.RIGHT,
		"strafe": 1.0 if rng.randf() < 0.5 else -1.0, "name": d["name"],
	}
	next_id += 1
	return e


func spawn_enemy(t: int, p: Vector2) -> void:
	enemies.append(make_enemy(t, p))


func pick_type() -> int:
	var mix: Array = biome["mix"]
	var total := 0.0
	for w in mix:
		total += float(w)
	var r := rng.randf() * total
	for i in mix.size():
		r -= float(mix[i])
		if r <= 0.0:
			return i
	return 0


func ring_pos(radius: float) -> Vector2:
	return player_pos + Vector2.from_angle(rng.randf() * TAU) * radius


func spawn_logic(dt: float) -> void:
	if ending != "":
		return
	var alive := enemies.size()
	var cap := 520 if mode == "adventure" else 760
	if lite:
		cap = 300 if mode == "adventure" else 380
	var rate: float
	if mode == "adventure":
		rate = (2.4 + 0.05 * run_time) * float(biome["density"])
	else:
		rate = 3.0 + 0.075 * run_time + 1.2 * float(biome_idx)
	if boss_spawned:
		rate *= 0.45
	spawn_acc += dt * rate
	while spawn_acc >= 1.0:
		spawn_acc -= 1.0
		if alive < cap:
			spawn_enemy(pick_type(), ring_pos(rng.randf_range(780.0, 880.0)))
			alive += 1
	surge_t -= dt
	if surge_t <= 0.0:
		surge_t = 24.0 if mode == "adventure" else 16.0
		var n := 22 + int(run_time / 15.0)
		var t := 0 if rng.randf() < 0.6 else 1
		var base := rng.randf() * TAU
		for i in n:
			if alive < cap + 80:
				spawn_enemy(t, player_pos + Vector2.from_angle(base + TAU * float(i) / float(n)) * 760.0)
				alive += 1
		banner("SWARM INCOMING!", 1.8)
	if mode == "adventure":
		var dur: float = biome["duration"]
		if not champion_done and run_time >= dur * 0.5:
			champion_done = true
			spawn_big(false)
		if not boss_spawned and run_time >= dur:
			boss_spawned = true
			spawn_big(true)
	else:
		if run_time >= horde_next:
			horde_next += 75.0
			spawn_big(false)


func spawn_big(is_boss: bool) -> void:
	var e := make_enemy(2, player_pos + Vector2.from_angle(rng.randf() * TAU) * 700.0)
	var hm: float = float(biome["hp_mult"])
	e["big"] = true
	e["boss"] = is_boss
	e["state"] = 0
	e["atk"] = ""
	e["atk_t"] = 0.0
	e["cd"] = 1.5
	e["phase"] = 0
	e["spin"] = 0.0
	e["spin_t"] = 0.0
	e["charge_dir"] = Vector2.RIGHT
	if is_boss:
		e["name"] = biome["boss"]
		e["r"] = 48.0
		e["hp"] = 6500.0 * hm
		e["speed"] = 48.0
		e["dmg"] = 22.0 + 4.0 * float(biome_idx)
		banner("BOSS: " + String(biome["boss"]).to_upper(), 3.0)
		boss_ref = e
		shake = 12.0
	else:
		e["name"] = biome["champion"]
		e["r"] = 34.0
		e["hp"] = 1700.0 * hm * (1.0 + run_time / 200.0)
		e["speed"] = 60.0
		e["dmg"] = 16.0 + 3.0 * float(biome_idx)
		banner("CHAMPION: " + String(biome["champion"]).to_upper(), 2.5)
	e["maxhp"] = e["hp"]
	enemies.append(e)


func update_enemies(dt: float) -> void:
	for e in enemies:
		if e["dead"]:
			continue
		e["flash"] = maxf(0.0, float(e["flash"]) - dt)
		if e["big"]:
			update_boss(e, dt)
		else:
			update_enemy(e, dt)


func update_enemy(e: Dictionary, dt: float) -> void:
	var epos: Vector2 = e["pos"]
	var to: Vector2 = player_pos - epos
	var d: float = maxf(to.length(), 0.001)
	var dir: Vector2 = to / d
	var sp: float = e["speed"]
	var vel: Vector2 = dir * sp
	var t: int = e["type"]
	if t == 3:
		if d < 240.0:
			vel = -dir * sp
		elif d < 340.0:
			vel = dir.orthogonal() * sp * 0.7 * float(e["strafe"])
		e["shoot_t"] -= dt
		if e["shoot_t"] <= 0.0 and d < 540.0:
			e["shoot_t"] = rng.randf_range(1.7, 2.5)
			enemy_bullet(epos, dir * 190.0, 7.0 + 2.0 * float(biome_idx))
	elif t == 4:
		e["state_t"] -= dt
		var st: int = e["state"]
		if st == 0:
			if e["state_t"] <= 0.0 and d < 440.0:
				e["state"] = 1
				e["state_t"] = 0.55
				e["dash_dir"] = dir
		elif st == 1:
			vel = Vector2.ZERO
			if e["state_t"] <= 0.0:
				e["state"] = 2
				e["state_t"] = 0.45
		else:
			vel = e["dash_dir"] * 560.0
			if e["state_t"] <= 0.0:
				e["state"] = 0
				e["state_t"] = rng.randf_range(2.0, 3.5)
	epos += vel * dt
	# separate from cell neighbours so hordes spread out
	var cx := int(floorf(epos.x / CELL))
	var cy := int(floorf(epos.y / CELL))
	var lst = grid.get(ckey(cx, cy))
	if lst != null:
		var n := 0
		for o in lst:
			if o["id"] == e["id"] or o["dead"]:
				continue
			var diff: Vector2 = epos - o["pos"]
			var dd := diff.length_squared()
			var mind: float = float(e["r"]) + float(o["r"])
			if dd < mind * mind and dd > 0.01:
				epos += diff / sqrt(dd) * (mind - sqrt(dd)) * minf(1.0, 6.0 * dt)
			n += 1
			if n > 8:
				break
	e["pos"] = epos
	e["face"] = dir
	if d < float(e["r"]) + 13.0:
		hurt(float(e["dmg"]))


# ------------------------------------------------------------------ bosses
func update_boss(e: Dictionary, dt: float) -> void:
	var epos: Vector2 = e["pos"]
	var to: Vector2 = player_pos - epos
	var d: float = maxf(to.length(), 0.001)
	var dir: Vector2 = to / d
	e["face"] = dir
	var is_boss: bool = e["boss"]
	var frac: float = float(e["hp"]) / float(e["maxhp"])
	var phase := 0
	if is_boss:
		phase = 0 if frac > 0.66 else (1 if frac > 0.33 else 2)
		if phase != int(e["phase"]):
			e["phase"] = phase
			e["cd"] = 0.8
			e["atk"] = ""
			shake = 14.0
			banner("PHASE " + str(phase + 1), 1.6)
			fire_ring(epos, 24, 170.0, 0.0, e)
	var atk: String = e["atk"]
	if atk == "":
		if d > 150.0:
			epos += dir * float(e["speed"]) * (1.0 + 0.25 * float(phase)) * dt
		e["cd"] -= dt
		if e["cd"] <= 0.0:
			start_attack(e, phase)
	else:
		e["atk_t"] -= dt
		if atk == "spiral":
			e["spin_t"] -= dt
			if e["spin_t"] <= 0.0:
				e["spin_t"] = 0.085
				var arms := 1 + phase + (1 if biome_idx >= 2 else 0)
				for k in arms:
					var a: float = float(e["spin"]) + TAU * float(k) / float(arms)
					enemy_bullet(epos, Vector2.from_angle(a) * 170.0, boss_dmg())
				e["spin"] += 0.31
			if e["atk_t"] <= 0.0:
				finish_attack(e, phase)
		elif atk == "charge_wind":
			if e["atk_t"] <= 0.0:
				e["atk"] = "charge"
				e["atk_t"] = 0.65
		elif atk == "charge":
			epos += e["charge_dir"] * 520.0 * dt
			if e["atk_t"] <= 0.0:
				finish_attack(e, phase)
	e["pos"] = epos
	if d < float(e["r"]) + 13.0:
		hurt(float(e["dmg"]))


func boss_dmg() -> float:
	return 9.0 + 2.5 * float(biome_idx)


func start_attack(e: Dictionary, phase: int) -> void:
	var pool: Array = ["ring", "fan"]
	if not e["boss"]:
		pool = ["fan", "ring", "charge"]
	elif phase == 1:
		pool = ["ring", "fan", "spiral", "summon"]
	elif phase == 2:
		pool = ["ring", "spiral", "fan", "summon", "charge"]
	if e["boss"] and biome_idx >= 1 and phase >= 1:
		pool.append("charge")
	var pick: String = pool[rng.randi() % pool.size()]
	var epos: Vector2 = e["pos"]
	var to: Vector2 = player_pos - epos
	if pick == "ring":
		var n := 18 + 4 * phase + 3 * biome_idx
		fire_ring(epos, n, 150.0 + 10.0 * float(biome_idx), 0.0, e)
		if phase >= 2:
			fire_ring(epos, n, 205.0, PI / float(n), e)
		finish_attack(e, phase)
	elif pick == "fan":
		var n := 5 + 2 * phase + biome_idx
		var base := to.angle()
		for i in n:
			var a := base + lerpf(-0.55, 0.55, float(i) / float(maxi(n - 1, 1)))
			enemy_bullet(epos, Vector2.from_angle(a) * 215.0, boss_dmg())
		finish_attack(e, phase)
	elif pick == "summon":
		for i in 6 + 2 * phase:
			spawn_enemy(0 if i % 3 != 0 else 1, epos + Vector2.from_angle(TAU * float(i) / 8.0) * 70.0)
		banner("MINIONS!", 1.2)
		finish_attack(e, phase)
	elif pick == "spiral":
		e["atk"] = "spiral"
		e["atk_t"] = 3.2
		e["spin_t"] = 0.0
	else:
		e["atk"] = "charge_wind"
		e["atk_t"] = 0.8
		e["charge_dir"] = to.normalized()


func fire_ring(p: Vector2, n: int, spd: float, offset: float, _e: Dictionary) -> void:
	for i in n:
		var a := offset + TAU * float(i) / float(n)
		enemy_bullet(p, Vector2.from_angle(a) * spd, boss_dmg())


func finish_attack(e: Dictionary, phase: int) -> void:
	e["atk"] = ""
	e["cd"] = maxf(0.7, 1.9 - 0.35 * float(phase) - 0.12 * float(biome_idx))


# ------------------------------------------------------------------ fx
func burst(p: Vector2, col: Color, n: int, spd: float, size: float) -> void:
	for i in n:
		if particles.size() > (140 if lite else 450):
			return
		var a := rng.randf() * TAU
		var s := rng.randf_range(0.25, 1.0) * spd
		var life := rng.randf_range(0.25, 0.6)
		particles.append({
			"pos": p, "vel": Vector2.from_angle(a) * s, "life": life, "max": life,
			"col": col, "size": rng.randf_range(0.6, 1.0) * size,
		})


func update_fx(dt: float) -> void:
	var i := particles.size() - 1
	while i >= 0:
		var p: Dictionary = particles[i]
		p["pos"] += p["vel"] * dt
		p["vel"] *= 0.93
		p["life"] -= dt
		if p["life"] <= 0.0:
			particles[i] = particles[particles.size() - 1]
			particles.pop_back()
		i -= 1
	for t in dtexts:
		t["life"] -= dt
		t["pos"] += Vector2(0.0, -40.0) * dt
	dtexts = dtexts.filter(func(t): return t["life"] > 0.0)
	for r in rings:
		r["life"] -= dt
	rings = rings.filter(func(r): return r["life"] > 0.0)


# ------------------------------------------------------------------ level up
func open_levelup() -> void:
	var pool: Array = []
	for u in UPGRADES:
		if int(upg_levels.get(u["id"], 0)) < int(u["max"]):
			pool.append(u)
	pool.shuffle()
	choices = []
	for i in mini(3, pool.size()):
		choices.append(pool[i])
	if choices.is_empty():
		choices.append({"id": "heal", "name": "Second Wind", "desc": "Heal 40 HP", "max": 1})
	screen = "levelup"


func choose_upgrade(i: int) -> void:
	if i < 0 or i >= choices.size():
		return
	var id: String = choices[i]["id"]
	upg_levels[id] = int(upg_levels.get(id, 0)) + 1
	if id == "dmg":
		P["dmg"] = float(P["dmg"]) * 1.2
	elif id == "rate":
		P["rate"] = float(P["rate"]) * 1.15
	elif id == "multi":
		P["multi"] = int(P["multi"]) + 1
	elif id == "pierce":
		P["pierce"] = int(P["pierce"]) + 1
	elif id == "speed":
		P["speed"] = float(P["speed"]) * 1.1
	elif id == "hp":
		P["max_hp"] = float(P["max_hp"]) + 25.0
		player_hp = minf(float(P["max_hp"]), player_hp + 25.0)
	elif id == "regen":
		P["regen"] = float(P["regen"]) + 0.8
	elif id == "magnet":
		P["magnet"] = float(P["magnet"]) * 1.35
	elif id == "blades":
		P["blades"] = int(P["blades"]) + 1
	elif id == "nova":
		P["nova"] = int(P["nova"]) + 1
	elif id == "crit":
		P["crit"] = float(P["crit"]) + 0.08
	elif id == "pspeed":
		P["pspeed"] = float(P["pspeed"]) * 1.25
	elif id == "heal":
		player_hp = minf(float(P["max_hp"]), player_hp + 40.0)
	pending_levels -= 1
	invuln_t = maxf(invuln_t, 0.8)
	if pending_levels > 0:
		open_levelup()
	else:
		screen = "play"


# ------------------------------------------------------------------ achievements / results
func check_achievements() -> void:
	if kills >= 1:
		Game.unlock("first_blood")
	if kills >= 100:
		Game.unlock("kills_100")
	if kills >= 1000:
		Game.unlock("kills_1000")
	if run_time >= 60.0:
		Game.unlock("survive_60")
	if run_time >= 180.0:
		Game.unlock("survive_180")
	if level >= 10:
		Game.unlock("level_10")
	if level >= 25:
		Game.unlock("level_25")
	if int(P["multi"]) >= 5 and int(P["blades"]) >= 3 and int(P["nova"]) >= 3:
		Game.unlock("arsenal")
	if mode == "horde" and run_time >= 300.0:
		Game.unlock("horde_300")


func finish_run() -> void:
	res_win = ending == "victory"
	var base := float(kills) * 0.2 + run_time * 0.5
	if mode == "horde":
		base = float(kills) * 0.25 + run_time * 0.8
	elif res_win:
		base += 100.0 * float(biome_idx + 1)
	res_souls = int(round(base * Game.soul_mult()))
	Game.add_souls(res_souls)
	Game.data["total_kills"] = int(Game.data["total_kills"]) + kills
	res_new_best = false
	if mode == "horde":
		if int(run_time) > int(Game.data["best_horde"]):
			Game.data["best_horde"] = int(run_time)
			res_new_best = true
	elif res_win:
		Game.unlock("clear_" + str(biome_idx))
		Game.data["biomes_unlocked"] = maxi(int(Game.data["biomes_unlocked"]), mini(biome_idx + 2, Game.biomes.size()))
	check_achievements()
	Game.save_data()
	screen = "over"


# ================================================================== BOT (tests)
func bot_think() -> void:
	var flee := Vector2.ZERO
	for e in enemies:
		if e["dead"]:
			continue
		var diff: Vector2 = player_pos - e["pos"]
		var d := diff.length()
		if d < 260.0:
			flee += diff / maxf(d * d, 25.0) * (3.0 if e["big"] else 1.0)
	for b in ebullets:
		var diff2: Vector2 = player_pos - b["pos"]
		var d2 := diff2.length()
		if d2 < 120.0:
			flee += diff2.orthogonal() / maxf(d2 * d2, 25.0) * 2.0
	var target := Vector2.ZERO
	var best := 1e9
	for g in gems:
		var dg: float = (g["pos"] - player_pos).length()
		if dg < best:
			best = dg
			target = g["pos"] - player_pos
	var mv := flee * 60.0
	if best < 400.0 and flee.length() < 0.01:
		mv += target.normalized() * 0.5
	if mv.length() < 0.05:
		mv = Vector2.from_angle(time_anim * 0.7) * 0.4
	bot_move = mv.normalized()
	bot_dash = flee.length() > 0.08 and dash_cd <= 0.0


func _test_tick() -> void:
	var what: String = test_cfg[0] if test_cfg.size() > 0 else "0"
	if what == "menus":
		_test_menus()
		return
	if what == "shot":
		await _test_shot()
		return
	var seconds: float = float(test_cfg[1]) if test_cfg.size() > 1 else 60.0
	var tmode: String = test_cfg[2] if test_cfg.size() > 2 else "adventure"
	if not test_started:
		test_started = true
		start_run(tmode, int(what))
		if test_cfg.size() > 3 and test_cfg[3] == "god":
			P["dmg"] = float(P["dmg"]) * 6.0
			P["multi"] = 4
			P["max_hp"] = 5000.0
			player_hp = 5000.0
		print("TEST start mode=", tmode, " biome=", what, " seconds=", seconds)
	for i in 60:
		if screen == "play":
			bot_think()
			step(1.0 / 60.0)
		elif screen == "levelup":
			choose_upgrade(rng.randi() % choices.size())
		elif screen == "over":
			_print_result()
			get_tree().quit()
			return
		test_frames += 1
		if test_frames % 1800 == 0:
			print("t=%d hp=%d lv=%d kills=%d enemies=%d ebul=%d pbul=%d gems=%d" % [
				int(run_time), int(player_hp), level, kills, enemies.size(),
				ebullets.size(), pbullets.size(), gems.size()])
		if run_time >= seconds:
			print("TEST time limit reached")
			_print_result()
			get_tree().quit()
			return
	if test_frames % 120 == 0:
		update_camera(0.05)
		queue_redraw()
		hud.queue_redraw()


func _print_result() -> void:
	print("RESULT screen=", screen, " win=", res_win, " time=", int(run_time), " level=", level,
		" kills=", kills, " souls=", res_souls, " hp=", int(player_hp))


func _test_menus() -> void:
	test_frames += 1
	var order := ["menu", "biomes", "upgrades", "achv", "menu"]
	if test_frames % 20 == 0:
		if test_menu_i < order.size():
			screen = order[test_menu_i]
			test_menu_i += 1
		else:
			start_run("adventure", 0)
			player_pos = Vector2(100, 100)
			for i in 40:
				spawn_enemy(i % 5, ring_pos(200.0 + float(i) * 8.0))
			spawn_big(true)
			spawn_big(false)
			for i in 30:
				enemy_bullet(ring_pos(150.0), Vector2.from_angle(float(i)) * 100.0, 5.0)
			P["blades"] = 3
			P["nova"] = 2
			rings.append({"pos": player_pos, "r": 10.0, "maxr": 200.0, "life": 0.4, "max": 0.4})
			screen = "play"
			for k in 120:
				bot_think()
				step(1.0 / 60.0)
			open_levelup()
			update_camera(0.1)
			queue_redraw()
			hud.queue_redraw()
			await get_tree().process_frame
			screen = "paused"
			await get_tree().process_frame
			screen = "over"
			await get_tree().process_frame
			print("MENUS OK")
			get_tree().quit()
			return
	update_camera(0.05)
	queue_redraw()
	hud.queue_redraw()


# ================================================================== DRAW: WORLD
func _draw() -> void:
	if screen == "splash":
		return
	var vs := vsize()
	var c := cam.position
	var tl := c - vs * 0.5
	draw_rect(Rect2(tl - Vector2(4, 4), vs + Vector2(8, 8)), biome["bg"])
	# grid
	var gs := 96.0
	var gcol: Color = biome["grid"]
	var x0 := floorf(tl.x / gs) * gs
	var y0 := floorf(tl.y / gs) * gs
	var x := x0
	while x < tl.x + vs.x + gs:
		draw_line(Vector2(x, tl.y - 2), Vector2(x, tl.y + vs.y + 2), gcol, 1.0)
		x += gs
	var y := y0
	while y < tl.y + vs.y + gs:
		draw_line(Vector2(tl.x - 2, y), Vector2(tl.x + vs.x + 2, y), gcol, 1.0)
		y += gs
	draw_decor(tl, vs)
	if screen == "menu" or screen == "biomes" or screen == "upgrades" or screen == "achv":
		return

	for g in gems:
		var gp: Vector2 = g["pos"]
		if g["kind"] == 0:
			var s := 4.0 + minf(float(g["val"]), 12.0) * 0.4
			draw_colored_polygon(PackedVector2Array([gp + Vector2(0, -s), gp + Vector2(s, 0), gp + Vector2(0, s), gp + Vector2(-s, 0)]), Color(0.4, 1.0, 0.7))
		else:
			draw_circle(gp, 8.0, Color(1.0, 0.3, 0.4))
			draw_rect(Rect2(gp + Vector2(-5, -1.5), Vector2(10, 3)), Color.WHITE)
			draw_rect(Rect2(gp + Vector2(-1.5, -5), Vector2(3, 10)), Color.WHITE)
	for r in rings:
		var k: float = 1.0 - float(r["life"]) / float(r["max"])
		var rp: Vector2 = r["pos"]
		var rad: float = lerpf(10.0, float(r["maxr"]), k)
		draw_arc(rp, rad, 0.0, TAU, 64, Color(0.6, 0.9, 1.0, 1.0 - k), 6.0)
		draw_circle(rp, rad, Color(0.5, 0.8, 1.0, 0.12 * (1.0 - k)))
	for e in enemies:
		if not e["dead"]:
			draw_enemy(e)
	# player bullets
	for b in pbullets:
		var bp: Vector2 = b["pos"]
		var bv: Vector2 = b["vel"]
		draw_line(bp - bv * 0.035, bp, Color(1.0, 0.9, 0.4, 0.5), 7.0)
		draw_line(bp - bv * 0.03, bp, Color(1.0, 1.0, 0.8), 3.0)
	# enemy bullets
	for b in ebullets:
		var ep: Vector2 = b["pos"]
		var rr: float = b["r"]
		draw_circle(ep, rr + 4.0, Color(1.0, 0.2, 0.35, 0.28))
		draw_circle(ep, rr, Color(1.0, 0.25, 0.4))
		draw_circle(ep, rr * 0.5, Color(1.0, 0.9, 0.9))
	# blades
	for i in int(P.get("blades", 0)):
		var bl := blade_pos(i)
		draw_circle(bl, 18.0, Color(0.6, 0.95, 1.0, 0.25))
		draw_circle(bl, 11.0, Color(0.85, 1.0, 1.0))
		draw_arc(bl, 14.0, 0.0, TAU, 16, Color(0.3, 0.8, 1.0), 3.0)
	# player trail + player
	for t in trail:
		var a: float = float(t["life"]) / 0.25
		draw_circle(t["pos"], 12.0 * a, Color(0.5, 0.9, 1.0, 0.35 * a))
	if ending != "dead":
		draw_player()
	for p in particles:
		var a: float = float(p["life"]) / float(p["max"])
		var pc: Color = p["col"]
		pc.a = a
		draw_circle(p["pos"], float(p["size"]) * a + 0.5, pc)
	for t in dtexts:
		var a: float = clampf(float(t["life"]) / 0.6, 0.0, 1.0)
		var tc := Color(1.0, 0.85, 0.3, a) if t["crit"] else Color(1.0, 1.0, 1.0, a)
		var fs := 22 if t["crit"] else 15
		draw_string(font, t["pos"], t["text"], HORIZONTAL_ALIGNMENT_CENTER, -1, fs, tc)


func draw_player() -> void:
	var p := player_pos
	var blink := invuln_t > 0.0 and int(time_anim * 20.0) % 2 == 0
	var body := Color(0.55, 0.9, 1.0) if not blink else Color(1, 1, 1, 0.5)
	draw_circle(p, 26.0, Color(0.4, 0.8, 1.0, 0.10))
	draw_circle(p, 19.0, Color(0.4, 0.8, 1.0, 0.16))
	draw_line(p, p + aim_dir * 26.0, Color(0.9, 0.95, 1.0), 6.0)
	draw_circle(p, 13.0, body)
	draw_circle(p, 7.0, Color(0.1, 0.25, 0.4))
	draw_arc(p, 14.0, 0.0, TAU, 24, Color.WHITE, 2.0)
	var pk := p + aim_dir * 8.0
	draw_circle(pk, 3.0, Color(1.0, 0.95, 0.6))


func draw_enemy(e: Dictionary) -> void:
	var p: Vector2 = e["pos"]
	var r: float = e["r"]
	var t: int = e["type"]
	var col: Color = enemy_color(t)
	var flash: bool = float(e["flash"]) > 0.0
	if e["boss"]:
		col = biome["boss_color"]
	elif e["big"]:
		col = enemy_color(2).lightened(0.15)
	var face: Vector2 = e["face"]
	if e["big"]:
		var pulse := 1.0 + 0.04 * sin(time_anim * 6.0)
		var spikes := 14 if e["boss"] else 8
		var pts := PackedVector2Array()
		for i in spikes * 2:
			var a := TAU * float(i) / float(spikes * 2) + time_anim * 0.4
			var rr := r * (1.28 if i % 2 == 0 else 0.92) * pulse
			pts.append(p + Vector2.from_angle(a) * rr)
		draw_colored_polygon(pts, Color.WHITE if flash else col.darkened(0.35))
		draw_circle(p, r * 0.82, Color.WHITE if flash else col)
		draw_circle(p, r * 0.5, col.darkened(0.55))
		var side := face.orthogonal() * r * 0.28
		draw_circle(p + face * r * 0.25 + side, r * 0.14, Color.WHITE)
		draw_circle(p + face * r * 0.25 - side, r * 0.14, Color.WHITE)
		var atk: String = e["atk"]
		if atk == "charge_wind":
			var cd: Vector2 = e["charge_dir"]
			var al := 0.3 + 0.3 * sin(time_anim * 25.0)
			draw_line(p, p + cd * 700.0, Color(1.0, 0.2, 0.2, al), r * 1.4)
		return
	if t == 4 and int(e["state"]) == 1:
		var dd: Vector2 = e["dash_dir"]
		draw_line(p, p + dd * 240.0, Color(1.0, 0.2, 0.2, 0.55), 4.0)
	var fill: Color = Color.WHITE if flash else col
	if t == 0:
		draw_circle(p, r, col.darkened(0.35))
		draw_circle(p, r * 0.75, fill)
	elif t == 1:
		draw_circle(p, r, col.darkened(0.4))
		draw_circle(p, r * 0.8, fill)
	elif t == 2:
		var pts := PackedVector2Array()
		for i in 6:
			pts.append(p + Vector2.from_angle(TAU * float(i) / 6.0 + 0.3) * r)
		draw_colored_polygon(pts, col.darkened(0.4))
		var pts2 := PackedVector2Array()
		for i in 6:
			pts2.append(p + Vector2.from_angle(TAU * float(i) / 6.0 + 0.3) * r * 0.75)
		draw_colored_polygon(pts2, fill)
	elif t == 3:
		draw_circle(p, r, col.darkened(0.4))
		draw_circle(p, r * 0.78, fill)
		draw_line(p - Vector2(r * 0.5, 0), p + Vector2(r * 0.5, 0), Color(0.05, 0.1, 0.15), 3.0)
		draw_line(p - Vector2(0, r * 0.5), p + Vector2(0, r * 0.5), Color(0.05, 0.1, 0.15), 3.0)
	else:
		var d := PackedVector2Array([p + face * r * 1.2, p + face.orthogonal() * r * 0.9, p - face * r * 1.0, p - face.orthogonal() * r * 0.9])
		draw_colored_polygon(d, fill)
	if t != 3 and t != 2:
		var side := face.orthogonal() * r * 0.3
		draw_circle(p + face * r * 0.35 + side, r * 0.2, Color.WHITE)
		draw_circle(p + face * r * 0.35 - side, r * 0.2, Color.WHITE)
		draw_circle(p + face * r * 0.42 + side, r * 0.1, Color(0.1, 0.1, 0.15))
		draw_circle(p + face * r * 0.42 - side, r * 0.1, Color(0.1, 0.1, 0.15))


func hash_cell(cx: int, cy: int) -> int:
	var h: int = (cx * 73856093) ^ (cy * 19349663)
	return absi(h) % 100000


func draw_decor(tl: Vector2, vs: Vector2) -> void:
	var cs := 192.0
	var accent: Color = biome["accent"]
	var gx0 := int(floorf(tl.x / cs)) - 1
	var gx1 := int(ceilf((tl.x + vs.x) / cs)) + 1
	var gy0 := int(floorf(tl.y / cs)) - 1
	var gy1 := int(ceilf((tl.y + vs.y) / cs)) + 1
	var bi := 0
	for i in Game.biomes.size():
		if Game.biomes[i]["name"] == biome["name"]:
			bi = i
	for cx in range(gx0, gx1):
		for cy in range(gy0, gy1):
			var h := hash_cell(cx, cy)
			if h % 100 > 58:
				continue
			var p := Vector2(float(cx) * cs + float(h % 173), float(cy) * cs + float((h / 7) % 167))
			var s := 0.7 + float(h % 50) / 100.0
			if bi == 0:
				var gc := Color(accent.r, accent.g, accent.b, 0.35)
				for k in 3:
					var ox := float(k - 1) * 5.0 * s
					draw_line(p + Vector2(ox, 0), p + Vector2(ox * 2.0, -14.0 * s), gc, 2.0)
				if h % 9 == 0:
					draw_circle(p + Vector2(0, -16.0 * s), 3.5 * s, Color(1.0, 0.9, 0.5, 0.7))
			elif bi == 1:
				draw_arc(p, 30.0 * s, PI * 1.1, PI * 1.9, 12, Color(accent.r, accent.g, accent.b, 0.30), 3.0)
				if h % 6 == 0:
					draw_circle(p + Vector2(20, 8), 6.0 * s, Color(0.35, 0.25, 0.12, 0.8))
			elif bi == 2:
				var ic := Color(accent.r, accent.g, accent.b, 0.38)
				var q := PackedVector2Array([p + Vector2(0, -22 * s), p + Vector2(9 * s, 0), p + Vector2(0, 10 * s), p + Vector2(-9 * s, 0)])
				draw_colored_polygon(q, ic)
				draw_line(p + Vector2(0, -22 * s), p + Vector2(0, 10 * s), Color(1, 1, 1, 0.35), 1.5)
			else:
				var lc := Color(1.0, 0.45, 0.15, 0.55)
				var pts := PackedVector2Array([p, p + Vector2(18, 10) * s, p + Vector2(30, -6) * s, p + Vector2(52, 8) * s])
				draw_polyline(pts, lc, 3.0)
				if h % 5 == 0:
					draw_circle(p + Vector2(0, -20 - 10.0 * sin(time_anim * 2.0 + float(h))), 2.5, Color(1.0, 0.7, 0.3, 0.8))


# ================================================================== DRAW: HUD
func _t(ci: CanvasItem, s: String, pos: Vector2, size: int, col: Color, align: int = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	ci.draw_string(font, pos + Vector2(2, 2), s, align, width, size, Color(0, 0, 0, 0.6))
	ci.draw_string(font, pos, s, align, width, size, col)


func _bar(ci: CanvasItem, rect: Rect2, frac: float, col: Color) -> void:
	ci.draw_rect(rect, Color(0, 0, 0, 0.55))
	ci.draw_rect(Rect2(rect.position, Vector2(rect.size.x * clampf(frac, 0.0, 1.0), rect.size.y)), col)
	ci.draw_rect(rect, Color(1, 1, 1, 0.5), false, 2.0)


func _btn(ci: CanvasItem, rect: Rect2, label: String, id: String, enabled: bool = true, size: int = 26) -> void:
	var hov: bool = enabled and rect.has_point(ci.get_local_mouse_position())
	var bg := Color(0.10, 0.12, 0.2, 0.92)
	if hov:
		bg = Color(0.2, 0.28, 0.45, 0.96)
	if not enabled:
		bg = Color(0.08, 0.08, 0.1, 0.8)
	ci.draw_rect(rect, bg)
	var edge: Color = biome["accent"] if enabled else Color(0.3, 0.3, 0.35)
	ci.draw_rect(rect, edge, false, 3.0 if hov else 2.0)
	var tc := Color.WHITE if enabled else Color(0.5, 0.5, 0.55)
	_t(ci, label, Vector2(rect.position.x, rect.position.y + rect.size.y * 0.5 + float(size) * 0.35), size, tc, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)
	if enabled:
		buttons.append({"rect": rect, "id": id})


func _fmt_time(t: float) -> String:
	return "%d:%02d" % [int(t) / 60, int(t) % 60]


func _draw_hud() -> void:
	buttons = []
	var vs := vsize()
	var cx := vs.x * 0.5
	if screen == "splash":
		_splash(cx, vs)
		return
	var accent: Color = biome["accent"]
	if screen != "play" and screen != "levelup" and screen != "paused" and screen != "over":
		hud.draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.55))
	if screen == "menu":
		_menu(cx, vs)
	elif screen == "biomes":
		_screen_biomes(cx, vs)
	elif screen == "upgrades":
		_screen_upgrades(cx, vs)
	elif screen == "achv":
		_screen_achv(cx, vs)
	else:
		_play_hud(cx, vs)
		if screen == "levelup":
			_levelup(cx, vs)
		elif screen == "paused":
			hud.draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.6))
			_t(hud, "PAUSED", Vector2(0, 280), 64, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, vs.x)
			_btn(hud, Rect2(cx - 160, 330, 320, 54), "RESUME", "resume")
			_btn(hud, Rect2(cx - 160, 400, 320, 54), "QUIT TO MENU", "menu")
		elif screen == "over":
			_over(cx, vs)
	# achievement toasts
	var ty := vs.y - 80.0
	for t in toasts:
		var rect := Rect2(vs.x - 350.0, ty, 330.0, 62.0)
		hud.draw_rect(rect, Color(0.08, 0.1, 0.16, 0.95))
		hud.draw_rect(rect, Color(1.0, 0.82, 0.25), false, 3.0)
		_t(hud, "ACHIEVEMENT UNLOCKED", rect.position + Vector2(14, 24), 14, Color(1.0, 0.82, 0.25))
		_t(hud, String(t["name"]), rect.position + Vector2(14, 49), 22, Color.WHITE)
		ty -= 72.0
	if accent.a < 0.0:
		return


func _splash(cx: float, vs: Vector2) -> void:
	hud.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.02, 0.03, 0.06))
	var a := clampf(splash_t / 2.5, 0.0, 1.0)
	var pulse := 0.5 + 0.5 * sin(splash_t * 2.0)
	var mid := Vector2(cx, vs.y * 0.45)
	for i in 5:
		var rr := 150.0 + float(i) * 60.0 + 10.0 * pulse
		hud.draw_arc(mid, rr, 0.0, TAU, 64, Color(0.3, 0.6, 1.0, a * 0.10), 3.0)
	_t(hud, "DANTHEMAN", Vector2(0, mid.y - 10), 96, Color(0.55, 0.85, 1.0, a), HORIZONTAL_ALIGNMENT_CENTER, vs.x)
	_t(hud, "GAMING", Vector2(0, mid.y + 80), 96, Color(1.0, 0.85, 0.35, a), HORIZONTAL_ALIGNMENT_CENTER, vs.x)
	var b := clampf((splash_t - 3.0) / 2.0, 0.0, 1.0)
	_t(hud, "presents", Vector2(0, mid.y + 130), 26, Color(0.8, 0.85, 0.95, b), HORIZONTAL_ALIGNMENT_CENTER, vs.x)
	var c := clampf((splash_t - 6.0) / 2.0, 0.0, 1.0)
	_t(hud, "ABH  -  AWESOME BULLET HEAVEN", Vector2(0, mid.y + 190), 38, Color(1.0, 0.5, 0.3, c), HORIZONTAL_ALIGNMENT_CENTER, vs.x)
	if splash_t >= 15.0:
		var d := 0.55 + 0.45 * sin(time_anim * 4.0)
		_t(hud, "Click or press any key to start", Vector2(0, vs.y - 60), 22, Color(1, 1, 1, d), HORIZONTAL_ALIGNMENT_CENTER, vs.x)


func _menu(cx: float, vs: Vector2) -> void:
	var pulse := 0.8 + 0.2 * sin(time_anim * 3.0)
	var ac: Color = biome["accent"]
	_t(hud, "ABH", Vector2(0, 150), 110, Color(ac.r * pulse + 0.2, ac.g * pulse + 0.2, ac.b * pulse + 0.2), HORIZONTAL_ALIGNMENT_CENTER, vs.x)
	_t(hud, "AWESOME BULLET HEAVEN", Vector2(0, 192), 32, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, vs.x)
	_t(hud, "survive  -  shoot  -  ascend", Vector2(0, 224), 20, Color(0.8, 0.85, 0.95), HORIZONTAL_ALIGNMENT_CENTER, vs.x)
	var y := 255.0
	_btn(hud, Rect2(cx - 190, y, 380, 56), "ADVENTURE", "adventure")
	y += 68.0
	var horde_ok: bool = int(Game.data["biomes_unlocked"]) >= 2
	_btn(hud, Rect2(cx - 190, y, 380, 56), "HORDE CHALLENGE" if horde_ok else "HORDE (clear Meadow)", "horde", horde_ok)
	y += 68.0
	_btn(hud, Rect2(cx - 190, y, 380, 56), "UPGRADES & ASCEND", "upgrades")
	y += 68.0
	_btn(hud, Rect2(cx - 190, y, 380, 56), "ACHIEVEMENTS  %d/%d" % [Game.unlocked_count(), Game.achievements.size()], "achv")
	y += 68.0
	if not OS.has_feature("web"):
		_btn(hud, Rect2(cx - 190, y, 380, 56), "QUIT", "quit")
	var info := "Souls: %d     Rank: %d  (+%d%% damage & souls)" % [int(Game.data["souls"]), int(Game.data["rank"]), int(round((Game.prestige_mult() - 1.0) * 100.0))]
	if int(Game.data["best_horde"]) > 0:
		info += "     Best horde: " + _fmt_time(float(Game.data["best_horde"]))
	_t(hud, info, Vector2(0, vs.y - 60), 22, Color(1.0, 0.85, 0.4), HORIZONTAL_ALIGNMENT_CENTER, vs.x)
	var hint := "WASD / Arrows: move     Space / Shift: dash     Your gun fires automatically     Esc: pause"
	if touch_ui:
		hint = "Drag on the left to move     Tap DASH on the right     Your gun fires automatically"
	_t(hud, hint, Vector2(0, vs.y - 28), 18, Color(0.7, 0.75, 0.85), HORIZONTAL_ALIGNMENT_CENTER, vs.x)


func _screen_biomes(cx: float, vs: Vector2) -> void:
	_t(hud, "CHOOSE YOUR BIOME", Vector2(0, 90), 52, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, vs.x)
	_btn(hud, Rect2(20, 20, 140, 44), "< BACK", "back", true, 20)
	var n: int = Game.biomes.size()
	var w := 270.0
	var gap := 24.0
	var x0 := cx - (float(n) * w + float(n - 1) * gap) * 0.5
	for i in n:
		var b: Dictionary = Game.biomes[i]
		var unlocked: bool = i < int(Game.data["biomes_unlocked"])
		var rect := Rect2(x0 + float(i) * (w + gap), 150, w, 440)
		var bgc: Color = b["bg"]
		hud.draw_rect(rect, bgc.lightened(0.05) if unlocked else Color(0.07, 0.07, 0.09))
		var acc: Color = b["accent"]
		hud.draw_rect(rect, acc if unlocked else Color(0.3, 0.3, 0.35), false, 3.0)
		_t(hud, str(b["name"]) if unlocked else "LOCKED", Vector2(rect.position.x, rect.position.y + 50), 28, Color.WHITE if unlocked else Color(0.5, 0.5, 0.55), HORIZONTAL_ALIGNMENT_CENTER, w)
		if unlocked:
			for k in 6:
				var gp := rect.position + Vector2(40.0 + float(k) * 38.0, 100.0 + float((k * 37) % 50))
				hud.draw_circle(gp, 6.0 + float(k % 3) * 3.0, Color(acc.r, acc.g, acc.b, 0.4))
			_t(hud, "Boss:", Vector2(rect.position.x, rect.position.y + 230), 18, Color(0.8, 0.8, 0.85), HORIZONTAL_ALIGNMENT_CENTER, w)
			_t(hud, str(b["boss"]), Vector2(rect.position.x, rect.position.y + 258), 24, b["boss_color"], HORIZONTAL_ALIGNMENT_CENTER, w)
			_t(hud, "Danger: " + "*".repeat(i + 1), Vector2(rect.position.x, rect.position.y + 300), 22, Color(1.0, 0.8, 0.4), HORIZONTAL_ALIGNMENT_CENTER, w)
			_t(hud, "Boss at " + _fmt_time(float(b["duration"])), Vector2(rect.position.x, rect.position.y + 330), 18, Color(0.8, 0.8, 0.85), HORIZONTAL_ALIGNMENT_CENTER, w)
			if Game.is_unlocked("clear_" + str(i)):
				_t(hud, "CLEARED", Vector2(rect.position.x, rect.position.y + 372), 22, Color(0.4, 1.0, 0.5), HORIZONTAL_ALIGNMENT_CENTER, w)
			_btn(hud, Rect2(rect.position.x + 30, rect.position.y + 385, w - 60, 40), "PLAY", "biome_" + str(i), true, 22)
		else:
			_t(hud, "Defeat the previous boss", Vector2(rect.position.x, rect.position.y + 240), 18, Color(0.55, 0.55, 0.6), HORIZONTAL_ALIGNMENT_CENTER, w)


func _screen_upgrades(cx: float, vs: Vector2) -> void:
	_t(hud, "SOUL UPGRADES", Vector2(0, 80), 52, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, vs.x)
	_t(hud, "Souls: %d" % int(Game.data["souls"]), Vector2(0, 118), 26, Color(1.0, 0.85, 0.4), HORIZONTAL_ALIGNMENT_CENTER, vs.x)
	_btn(hud, Rect2(20, 20, 140, 44), "< BACK", "back", true, 20)
	var order: Array = Game.meta_order
	for i in order.size():
		var id: String = order[i]
		var d: Dictionary = Game.meta_defs[id]
		var col := i % 2
		var row := i / 2
		var rect := Rect2(cx - 410.0 + float(col) * 430.0, 145.0 + float(row) * 92.0, 390.0, 82.0)
		var maxed := Game.meta_maxed(id)
		var can: bool = (not maxed) and int(Game.data["souls"]) >= Game.meta_cost(id)
		var hov: bool = can and rect.has_point(hud.get_local_mouse_position())
		hud.draw_rect(rect, Color(0.2, 0.28, 0.45, 0.95) if hov else Color(0.10, 0.12, 0.2, 0.92))
		hud.draw_rect(rect, Color(0.5, 0.9, 0.6) if can else Color(0.35, 0.38, 0.45), false, 2.0)
		_t(hud, str(d["name"]) + "   Lv %d/%d" % [Game.meta_level(id), Game.meta_max(id)], rect.position + Vector2(14, 30), 24, Color.WHITE)
		_t(hud, str(d["desc"]), rect.position + Vector2(14, 56), 16, Color(0.75, 0.8, 0.9))
		var cost_s := "MAX" if maxed else str(Game.meta_cost(id)) + " souls"
		_t(hud, cost_s, rect.position + Vector2(0, 30), 22, Color(1.0, 0.85, 0.4) if can else Color(0.6, 0.6, 0.65), HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x - 14.0)
		if can:
			buttons.append({"rect": rect, "id": "buy_" + id})
	# ascend panel
	var pr := Rect2(cx - 410.0, 545.0, 820.0, 120.0)
	hud.draw_rect(pr, Color(0.14, 0.08, 0.2, 0.95))
	hud.draw_rect(pr, Color(0.8, 0.5, 1.0), false, 3.0)
	var rank: int = int(Game.data["rank"])
	_t(hud, "ASCEND  (Rank %d -> %d)" % [rank, rank + 1], pr.position + Vector2(20, 36), 28, Color(0.85, 0.6, 1.0))
	_t(hud, "Resets souls and soul upgrades. Permanent +10% damage and souls per rank.", pr.position + Vector2(20, 66), 17, Color(0.85, 0.85, 0.92))
	_t(hud, "Souls earned this cycle: %d / %d" % [int(Game.data["cycle_souls"]), Game.ascend_cost()], pr.position + Vector2(20, 96), 19, Color(1.0, 0.85, 0.4))
	_btn(hud, Rect2(pr.position.x + pr.size.x - 220, pr.position.y + 28, 200, 62), "ASCEND", "ascend", Game.can_ascend(), 26)


func _screen_achv(cx: float, vs: Vector2) -> void:
	_t(hud, "ACHIEVEMENTS   %d / %d" % [Game.unlocked_count(), Game.achievements.size()], Vector2(0, 80), 48, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, vs.x)
	_btn(hud, Rect2(20, 20, 140, 44), "< BACK", "back", true, 20)
	var list: Array = Game.achievements
	for i in list.size():
		var a: Dictionary = list[i]
		var col := i % 3
		var row := i / 3
		var rect := Rect2(cx - 600.0 + float(col) * 400.0, 120.0 + float(row) * 90.0, 380.0, 78.0)
		var got: bool = Game.is_unlocked(a["id"])
		hud.draw_rect(rect, Color(0.14, 0.17, 0.1, 0.95) if got else Color(0.09, 0.1, 0.14, 0.92))
		hud.draw_rect(rect, Color(1.0, 0.82, 0.25) if got else Color(0.3, 0.32, 0.38), false, 2.0)
		_t(hud, str(a["name"]), rect.position + Vector2(14, 30), 24, Color.WHITE if got else Color(0.6, 0.62, 0.68))
		_t(hud, str(a["desc"]), rect.position + Vector2(14, 58), 15, Color(0.8, 0.85, 0.9) if got else Color(0.5, 0.52, 0.58))
		if got:
			_t(hud, "DONE", rect.position + Vector2(0, 30), 18, Color(0.4, 1.0, 0.5), HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x - 12.0)


func _play_hud(cx: float, vs: Vector2) -> void:
	if screen == "play":
		_btn(hud, Rect2(vs.x - 74, 90, 54, 44), "II", "pause", true, 22)
		if touch_ui:
			if joy_id != -1:
				hud.draw_circle(joy_origin, 70.0, Color(1, 1, 1, 0.10))
				hud.draw_arc(joy_origin, 70.0, 0.0, TAU, 40, Color(1, 1, 1, 0.35), 3.0)
				hud.draw_circle(joy_origin + joy_vec * 70.0, 30.0, Color(1, 1, 1, 0.35))
			else:
				var hp := Vector2(150.0, vs.y - 130.0)
				hud.draw_arc(hp, 70.0, 0.0, TAU, 40, Color(1, 1, 1, 0.18), 3.0)
				_t(hud, "MOVE", hp + Vector2(-50, 8), 20, Color(1, 1, 1, 0.35), HORIZONTAL_ALIGNMENT_CENTER, 100.0)
			var dc := dash_center(vs)
			var ready_d := dash_cd <= 0.0
			hud.draw_circle(dc, 62.0, Color(0.4, 0.8, 1.0, 0.35 if (ready_d and not dash_touch) else 0.15))
			hud.draw_arc(dc, 62.0, 0.0, TAU, 40, Color(0.6, 0.9, 1.0, 0.6 if ready_d else 0.25), 3.0)
			_t(hud, "DASH", dc + Vector2(-50, 8), 22, Color(1, 1, 1, 0.8 if ready_d else 0.35), HORIZONTAL_ALIGNMENT_CENTER, 100.0)
	if damage_flash > 0.0:
		var a := damage_flash * 0.8
		hud.draw_rect(Rect2(0, 0, vs.x, 24), Color(1, 0, 0, a))
		hud.draw_rect(Rect2(0, vs.y - 24, vs.x, 24), Color(1, 0, 0, a))
		hud.draw_rect(Rect2(0, 0, 24, vs.y), Color(1, 0, 0, a))
		hud.draw_rect(Rect2(vs.x - 24, 0, 24, vs.y), Color(1, 0, 0, a))
	var mhp: float = float(P["max_hp"])
	_bar(hud, Rect2(20, 20, 320, 26), player_hp / mhp, Color(0.9, 0.2, 0.3))
	_t(hud, "%d / %d" % [int(player_hp), int(mhp)], Vector2(20, 40), 18, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 320.0)
	_bar(hud, Rect2(20, 54, 320, 14), xp / xp_need, Color(0.35, 0.95, 0.7))
	_t(hud, "LV %d" % level, Vector2(350, 68), 22, Color(0.5, 1.0, 0.8))
	# dash
	var df: float = 1.0 - clampf(dash_cd / 1.5, 0.0, 1.0)
	_bar(hud, Rect2(20, 76, 120, 8), df, Color(0.5, 0.85, 1.0) if df >= 1.0 else Color(0.3, 0.45, 0.6))
	_t(hud, "DASH", Vector2(148, 86), 13, Color(0.7, 0.85, 1.0))
	# top centre
	if mode == "adventure":
		var dur: float = float(biome["duration"])
		if boss_spawned:
			_t(hud, String(biome["name"]).to_upper(), Vector2(0, 40), 26, biome["accent"], HORIZONTAL_ALIGNMENT_CENTER, vs.x)
		else:
			_t(hud, "BOSS IN " + _fmt_time(maxf(0.0, dur - run_time)), Vector2(0, 40), 28, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, vs.x)
			_t(hud, String(biome["name"]), Vector2(0, 64), 18, biome["accent"], HORIZONTAL_ALIGNMENT_CENTER, vs.x)
	else:
		_t(hud, "HORDE  " + _fmt_time(run_time), Vector2(0, 42), 32, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, vs.x)
		_t(hud, "Best " + _fmt_time(float(Game.data["best_horde"])), Vector2(0, 66), 16, Color(1.0, 0.85, 0.4), HORIZONTAL_ALIGNMENT_CENTER, vs.x)
	_t(hud, "KILLS %d" % kills, Vector2(0, 40), 28, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, vs.x - 24.0)
	_t(hud, "TIME " + _fmt_time(run_time), Vector2(0, 66), 18, Color(0.8, 0.85, 0.95), HORIZONTAL_ALIGNMENT_RIGHT, vs.x - 24.0)
	# weapons line
	var wl := "Shots x%d" % int(P["multi"])
	if int(P["blades"]) > 0:
		wl += "   Blades x%d" % int(P["blades"])
	if int(P["nova"]) > 0:
		wl += "   Nova L%d" % int(P["nova"])
	_t(hud, wl, Vector2(20, vs.y - 18), 16, Color(0.8, 0.85, 0.95))
	# boss bar
	for e in enemies:
		if e["big"] and not e["dead"]:
			var bw := minf(760.0, vs.x - 80.0)
			var by := vs.y - 70.0 if e["boss"] else vs.y - 120.0
			_bar(hud, Rect2(cx - bw * 0.5, by, bw, 22 if e["boss"] else 14), float(e["hp"]) / float(e["maxhp"]), biome["boss_color"] if e["boss"] else Color(0.8, 0.5, 1.0))
			_t(hud, String(e["name"]).to_upper(), Vector2(cx - bw * 0.5, by - 6), 20, Color.WHITE)
	if banner_t > 0.0:
		var a := clampf(banner_t / 0.5, 0.0, 1.0)
		_t(hud, banner_text, Vector2(0, vs.y * 0.3), 52, Color(1.0, 0.95, 0.7, a), HORIZONTAL_ALIGNMENT_CENTER, vs.x)


func _levelup(cx: float, vs: Vector2) -> void:
	hud.draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.6))
	_t(hud, "LEVEL UP!", Vector2(0, 170), 64, Color(0.5, 1.0, 0.8), HORIZONTAL_ALIGNMENT_CENTER, vs.x)
	_t(hud, "Pick an upgrade  (click or press 1 / 2 / 3)", Vector2(0, 208), 20, Color(0.8, 0.85, 0.95), HORIZONTAL_ALIGNMENT_CENTER, vs.x)
	var n := choices.size()
	var w := 300.0
	var gap := 30.0
	var x0 := cx - (float(n) * w + float(n - 1) * gap) * 0.5
	for i in n:
		var c: Dictionary = choices[i]
		var rect := Rect2(x0 + float(i) * (w + gap), 260, w, 240)
		var hov: bool = rect.has_point(hud.get_local_mouse_position())
		hud.draw_rect(rect, Color(0.2, 0.3, 0.45, 0.97) if hov else Color(0.10, 0.12, 0.2, 0.96))
		hud.draw_rect(rect, Color(0.5, 1.0, 0.8) if hov else Color(0.4, 0.5, 0.65), false, 3.0)
		_t(hud, "[%d]" % (i + 1), rect.position + Vector2(14, 30), 20, Color(1.0, 0.85, 0.4))
		_t(hud, str(c["name"]), rect.position + Vector2(0, 90), 28, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, w)
		_t(hud, str(c["desc"]), rect.position + Vector2(14, 135), 17, Color(0.8, 0.85, 0.95), HORIZONTAL_ALIGNMENT_CENTER, w - 28.0)
		var lv: int = int(upg_levels.get(c["id"], 0))
		if c["id"] != "heal":
			_t(hud, "Level %d -> %d" % [lv, lv + 1], rect.position + Vector2(0, 205), 20, Color(0.5, 1.0, 0.8), HORIZONTAL_ALIGNMENT_CENTER, w)
		buttons.append({"rect": rect, "id": "pick_" + str(i)})


func _over(cx: float, vs: Vector2) -> void:
	hud.draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.65))
	var title := "VICTORY!" if res_win else ("RUN OVER" if mode == "horde" else "YOU DIED")
	var tcol := Color(1.0, 0.85, 0.3) if res_win else Color(1.0, 0.35, 0.4)
	_t(hud, title, Vector2(0, 170), 84, tcol, HORIZONTAL_ALIGNMENT_CENTER, vs.x)
	var y := 240.0
	var lines: Array = [
		"Survived  " + _fmt_time(run_time),
		"Enemies defeated  %d" % kills,
		"Level reached  %d" % level,
		"Souls earned  +%d" % res_souls,
	]
	if res_new_best:
		lines.append("NEW HORDE RECORD!")
	elif res_win and biome_idx + 1 < Game.biomes.size() and mode == "adventure":
		lines.append("Next biome unlocked: " + str(Game.biomes[biome_idx + 1]["name"]))
	for l in lines:
		_t(hud, str(l), Vector2(0, y), 30, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, vs.x)
		y += 42.0
	_btn(hud, Rect2(cx - 200, y + 20, 400, 56), "TRY AGAIN  (R)", "retry")
	_btn(hud, Rect2(cx - 200, y + 90, 400, 56), "MENU  (M)", "menu")


var shot_busy := false


func _test_shot() -> void:
	if shot_busy:
		return
	shot_busy = true
	var bi: int = int(test_cfg[1]) if test_cfg.size() > 1 else 0
	start_run("adventure", bi)
	P["blades"] = 3
	P["nova"] = 2
	P["multi"] = 3
	for k in 25 * 60:
		bot_think()
		step(1.0 / 60.0)
		if screen == "levelup":
			choose_upgrade(0)
	run_time = float(biome["duration"]) - 1.0
	for k in 600:
		bot_think()
		step(1.0 / 60.0)
		if screen == "levelup":
			choose_upgrade(0)
	update_camera(0.05)
	for k in 3:
		queue_redraw()
		hud.queue_redraw()
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/shot_%d.png" % bi)
	var names := ["menu", "upgrades", "levelup"]
	for n in names:
		screen = n
		if n == "levelup":
			open_levelup()
		for q in 3:
			queue_redraw()
			hud.queue_redraw()
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/shot_%s.png" % n)
	get_tree().quit()
