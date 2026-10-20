extends Node
# Autoload "Game": saved progress, prestige, permanent upgrades, achievements.

signal achievement_unlocked(id: String)

const SAVE_PATH := "user://bullet_heaven_save.json"

# ---------------------------------------------------------------- BIOMES
# Each biome is one level. Beat its boss to unlock the next one.
# mix = spawn weights for [Swarmer, Grunt, Tank, Gunner, Dasher]
var biomes: Array = [
	{
		"name": "Verdant Meadow",
		"bg": Color(0.06, 0.15, 0.09), "grid": Color(0.15, 0.32, 0.18, 0.40),
		"accent": Color(0.45, 0.85, 0.35), "boss_color": Color(0.55, 0.95, 0.30),
		"duration": 150.0, "hp_mult": 1.0, "density": 1.0,
		"mix": [5.0, 3.0, 1.0, 1.0, 0.6],
		"boss": "The Thorn Warden", "champion": "Bramble Brute",
	},
	{
		"name": "Scorched Dunes",
		"bg": Color(0.20, 0.14, 0.06), "grid": Color(0.45, 0.32, 0.12, 0.40),
		"accent": Color(0.95, 0.70, 0.25), "boss_color": Color(1.00, 0.75, 0.20),
		"duration": 180.0, "hp_mult": 1.35, "density": 1.2,
		"mix": [4.0, 3.0, 1.5, 2.0, 1.5],
		"boss": "The Sand Colossus", "champion": "Dune Stalker",
	},
	{
		"name": "Frostbite Hollow",
		"bg": Color(0.05, 0.10, 0.18), "grid": Color(0.25, 0.45, 0.65, 0.40),
		"accent": Color(0.55, 0.85, 1.00), "boss_color": Color(0.55, 0.85, 1.00),
		"duration": 210.0, "hp_mult": 1.8, "density": 1.4,
		"mix": [4.0, 2.5, 2.0, 2.5, 1.5],
		"boss": "The Glacier Wyrm", "champion": "Rime Reaver",
	},
	{
		"name": "Hellfire Rift",
		"bg": Color(0.16, 0.04, 0.05), "grid": Color(0.60, 0.15, 0.10, 0.45),
		"accent": Color(1.00, 0.35, 0.20), "boss_color": Color(1.00, 0.25, 0.25),
		"duration": 240.0, "hp_mult": 2.4, "density": 1.7,
		"mix": [4.0, 3.0, 2.5, 3.0, 2.0],
		"boss": "The Infernal Tyrant", "champion": "Cinder Knight",
	},
]

# ---------------------------------------------------------------- META UPGRADES
# Bought with souls between runs. Reset by Ascending.
var meta_order: Array = [
	"m_dmg", "m_hp", "m_speed", "m_rate", "m_xp", "m_magnet", "m_souls", "m_multi",
]
var meta_defs: Dictionary = {
	"m_dmg": {"name": "Power", "desc": "+5% damage per level", "base": 30, "growth": 1.35, "max": 20},
	"m_hp": {"name": "Vitality", "desc": "+10 max HP per level", "base": 25, "growth": 1.30, "max": 20},
	"m_speed": {"name": "Swiftness", "desc": "+3% move speed per level", "base": 40, "growth": 1.40, "max": 10},
	"m_rate": {"name": "Trigger Finger", "desc": "+4% fire rate per level", "base": 45, "growth": 1.40, "max": 10},
	"m_xp": {"name": "Wisdom", "desc": "+5% XP gain per level", "base": 35, "growth": 1.38, "max": 10},
	"m_magnet": {"name": "Magnetism", "desc": "+10% pickup range per level", "base": 20, "growth": 1.35, "max": 10},
	"m_souls": {"name": "Soul Harvest", "desc": "+5% souls per run per level", "base": 60, "growth": 1.45, "max": 10},
	"m_multi": {"name": "Twin Barrels", "desc": "+1 starting projectile", "base": 400, "growth": 3.0, "max": 3},
}

# ---------------------------------------------------------------- ACHIEVEMENTS
var achievements: Array = [
	{"id": "first_blood", "name": "First Blood", "desc": "Defeat your first enemy."},
	{"id": "kills_100", "name": "Crowd Control", "desc": "Defeat 100 enemies in one run."},
	{"id": "kills_1000", "name": "Mass Extinction", "desc": "Defeat 1000 enemies in one run."},
	{"id": "survive_60", "name": "Still Standing", "desc": "Survive 60 seconds."},
	{"id": "survive_180", "name": "Unkillable", "desc": "Survive 3 minutes."},
	{"id": "level_10", "name": "Getting Strong", "desc": "Reach level 10 in a run."},
	{"id": "level_25", "name": "Power Spike", "desc": "Reach level 25 in a run."},
	{"id": "boss_slayer", "name": "Boss Slayer", "desc": "Defeat any boss or champion."},
	{"id": "arsenal", "name": "Walking Arsenal", "desc": "Have 5+ projectiles, 3+ blades and a level 3 nova at once."},
	{"id": "clear_0", "name": "Meadow Cleared", "desc": "Defeat the Thorn Warden."},
	{"id": "clear_1", "name": "Dunes Cleared", "desc": "Defeat the Sand Colossus."},
	{"id": "clear_2", "name": "Hollow Cleared", "desc": "Defeat the Glacier Wyrm."},
	{"id": "clear_3", "name": "Rift Cleared", "desc": "Defeat the Infernal Tyrant."},
	{"id": "rich", "name": "Soul Collector", "desc": "Earn 1000 souls in total."},
	{"id": "ascended", "name": "Ascended", "desc": "Ascend for the first time."},
	{"id": "horde_300", "name": "Horde Breaker", "desc": "Survive 5 minutes in Horde Challenge."},
]

var data: Dictionary = {}


func _ready() -> void:
	data = _default_data()
	load_data()


func _default_data() -> Dictionary:
	return {
		"souls": 0,
		"cycle_souls": 0,
		"lifetime_souls": 0,
		"rank": 0,
		"meta": {},
		"ach": {},
		"biomes_unlocked": 1,
		"total_kills": 0,
		"best_horde": 0,
	}


func load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	for key in data.keys():
		if parsed.has(key):
			data[key] = parsed[key]
	for key in ["souls", "cycle_souls", "lifetime_souls", "rank", "biomes_unlocked", "total_kills", "best_horde"]:
		data[key] = int(data[key])
	data["biomes_unlocked"] = clampi(int(data["biomes_unlocked"]), 1, biomes.size())


func save_data() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(data))
	f.close()


# ---------------------------------------------------------------- SOULS / META
func add_souls(n: int) -> void:
	data["souls"] = int(data["souls"]) + n
	data["cycle_souls"] = int(data["cycle_souls"]) + n
	data["lifetime_souls"] = int(data["lifetime_souls"]) + n
	if int(data["lifetime_souls"]) >= 1000:
		unlock("rich")


func meta_level(id: String) -> int:
	return int(data["meta"].get(id, 0))


func meta_max(id: String) -> int:
	return int(meta_defs[id]["max"])


func meta_maxed(id: String) -> bool:
	return meta_level(id) >= meta_max(id)


func meta_cost(id: String) -> int:
	var d: Dictionary = meta_defs[id]
	return int(round(float(d["base"]) * pow(float(d["growth"]), float(meta_level(id)))))


func buy_meta(id: String) -> bool:
	if meta_maxed(id):
		return false
	var cost := meta_cost(id)
	if int(data["souls"]) < cost:
		return false
	data["souls"] = int(data["souls"]) - cost
	data["meta"][id] = meta_level(id) + 1
	save_data()
	return true


func meta_mult(id: String, per_level: float) -> float:
	return 1.0 + per_level * float(meta_level(id))


# ---------------------------------------------------------------- PRESTIGE
func prestige_mult() -> float:
	return 1.0 + 0.10 * float(int(data["rank"]))


func soul_mult() -> float:
	return meta_mult("m_souls", 0.05) * prestige_mult()


func ascend_cost() -> int:
	return int(round(400.0 * pow(float(int(data["rank"]) + 1), 1.4)))


func can_ascend() -> bool:
	return int(data["cycle_souls"]) >= ascend_cost()


func ascend() -> bool:
	if not can_ascend():
		return false
	data["rank"] = int(data["rank"]) + 1
	data["souls"] = 0
	data["cycle_souls"] = 0
	data["meta"] = {}
	save_data()
	unlock("ascended")
	return true


# ---------------------------------------------------------------- ACHIEVEMENTS
func is_unlocked(id: String) -> bool:
	return bool(data["ach"].get(id, false))


func unlock(id: String) -> void:
	if is_unlocked(id):
		return
	data["ach"][id] = true
	save_data()
	achievement_unlocked.emit(id)


func achievement_name(id: String) -> String:
	for a in achievements:
		if a["id"] == id:
			return a["name"]
	return id


func unlocked_count() -> int:
	var n := 0
	for a in achievements:
		if is_unlocked(a["id"]):
			n += 1
	return n
