class_name SelectionHUDData
extends RefCounted

## Data-driven selection HUD (mockup spec): one builder turns ANY selectable
## entity (unit, building, resource node) into a plain Dictionary the panels
## render. Keys: name, subtitle, icon (res:// path or ""), hp {cur,max},
## stats [{label, value}], status (String), queue [{label, progress 0-1}].
## Panels never poke entity internals directly — everything funnels here.

const UNIT_NAMES: Dictionary = {
	"soldier": "Soldier", "archer": "Archer", "raider": "Raider",
	"villager": "Villager", "ix_lattice_guard": "Lattice Guard", "ix_weaver": "Weaver",
}
const UNIT_ROLES: Dictionary = {
	"Villager": "Gatherer, Builder", "Weaver": "Gatherer, Builder",
	"Soldier": "Melee Infantry", "Archer": "Ranged", "Raider": "Cavalry",
	"Lattice Guard": "Heavy Infantry",
}
const UNIT_ICONS: Dictionary = {
	"Villager": "unit_villager", "Weaver": "unit_villager",
	"Soldier": "unit_soldier", "Archer": "unit_archer",
	"Raider": "unit_raider", "Lattice Guard": "unit_soldier",
}
const BUILDING_ICONS: Dictionary = {
	"Town Center": "bld_tc", "Farm": "bld_farm", "Storehouse": "bld_storehouse",
	"House": "bld_house", "Obsidian Pylon": "bld_pylon", "Barracks": "bld_barracks",
	"Tower": "bld_tower", "Monument": "bld_monument", "Ascension Beacon": "bld_beacon",
}
const RES_LABEL: Dictionary = {&"wood": "Wood", &"food": "Food", &"gold": "Gold"}

static func build(node: Node) -> Dictionary:
	var d: Dictionary = {
		"name": display_name(node), "subtitle": "", "icon": "",
		"hp": {}, "stats": [], "status": "", "queue": [],
	}
	d["subtitle"] = String(UNIT_ROLES.get(d["name"], ""))
	var icon_key: String = String(UNIT_ICONS.get(d["name"],
		BUILDING_ICONS.get(d["name"], "")))
	if icon_key != "":
		var p: String = "res://assets/ui/icons/%s.png" % icon_key
		if ResourceLoader.exists(p):
			d["icon"] = p
	_fill_hp(node, d)
	_fill_stats(node, d)
	_fill_status(node, d)
	_fill_queue(node, d)
	return d

static func display_name(node: Node) -> String:
	var bn: Variant = node.get("building_name")
	if bn != null and String(bn) != "":
		return String(bn)
	var sa: Variant = node.get("sprite_asset")
	if sa != null and UNIT_NAMES.has(String(sa)):
		return UNIT_NAMES[String(sa)]
	return node.name

static func _fill_hp(node: Node, d: Dictionary) -> void:
	var stat := node.get_node_or_null("StatComponent") as StatComponent
	if stat != null:
		d["hp"] = {"cur": stat.get_health_ratio() * stat.max_health, "max": stat.max_health}
		return
	var hp_v: Variant = node.get("hp")
	var max_v: Variant = node.get("max_hp")
	if hp_v != null and max_v != null:
		d["hp"] = {"cur": float(hp_v), "max": float(max_v)}

static func _fill_stats(node: Node, d: Dictionary) -> void:
	var stats: Array = d["stats"]
	var atk: Variant = node.get("attack_damage")
	if atk != null and float(atk) > 0.0:
		stats.append({"label": "ATK", "value": int(float(atk))})
	var stat: Node = node.get_node_or_null("StatComponent")
	if stat != null:
		var arm: Variant = stat.get("armor")
		if arm != null:
			stats.append({"label": "ARM", "value": int(float(arm))})

## Live activity line: gather progress, construction, or training head.
static func _fill_status(node: Node, d: Dictionary) -> void:
	var hc := node.get_node_or_null("HarvestComponent") as HarvestComponent
	if hc != null:
		var info: Dictionary = hc.carry_info()
		var t: StringName = info["type"]
		if t != &"":
			d["status"] = "Gathering %s  %d / %d" % [
				String(RES_LABEL.get(t, String(t).capitalize())),
				int(info["amount"]), int(info["cap"])]
		return
	if bool(node.get("under_construction")):
		d["status"] = "Under construction"
	elif bool(node.get("has_rally_point")):
		d["status"] = "Rally point set"

static func _fill_queue(node: Node, d: Dictionary) -> void:
	var q_v: Variant = node.get("queue")
	if not (q_v is Array):
		return
	var q: Array = q_v
	var out: Array = d["queue"]
	for i in q.size():
		var entry: Dictionary = q[i]
		var item: Dictionary = {
			"label": String(entry.get("label", entry.get("research_id", "?"))),
			"progress": -1.0,
		}
		if i == 0:
			var dur: float = float(entry.get("duration", 1.0))
			var left: float = float(node.get("production_timer"))
			item["progress"] = clampf(1.0 - left / maxf(dur, 0.01), 0.0, 1.0)
		out.append(item)
