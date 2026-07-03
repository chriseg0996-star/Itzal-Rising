extends Node

# Manages timed alert notifications. Max 5 visible at once.
# Consumers call AlertManager.push(text, level) where level is "error"|"warning"|"info".
# Alerts auto-expire after 6 seconds.

signal alert_pushed(text: String, level: String)
signal alert_cleared(index: int)
signal deal_offered(deal: Dictionary)
signal deal_resolved(id: StringName, accepted: bool)
signal ticker_updated(text: String)

const MAX_ALERTS: int = 5
const ALERT_LIFETIME: float = 6.0

# ── Deals: periodic opt-in offers (modal Accept/Decline, 20s expiry) ──
const DEAL_MIN_WAIT: float = 120.0   # 150s ±30s between offers
const DEAL_MAX_WAIT: float = 180.0
const DEAL_TTL: float = 20.0

## Data-driven deal table — add entries here, no code changes needed.
## Fields: id (StringName), text (shown on the card), cost (spent on Accept;
## Accept fails politely if unaffordable), grant (player resources),
## enemy_grant (drawback: the Decay gain resources), buff_train + duration
## (player training-speed multiplier for N seconds), gamble {chance, win}.
const DEALS: Array[Dictionary] = [
	{"id": &"timber_deal", "text": "Obsidian traders offer 75 gold for 150 wood.",
	 "cost": {&"wood": 150}, "grant": {&"gold": 75}},
	{"id": &"harvest_pact", "text": "A jungle clan trades 80 wood for 100 food.",
	 "cost": {&"food": 100}, "grant": {&"wood": 80}},
	{"id": &"overclock", "text": "Overclock the lattice: +15% training speed for 60s — but the Decay sense it and gain 100 wood.",
	 "cost": {&"gold": 50}, "buff_train": 1.15, "duration": 60.0, "enemy_grant": {&"wood": 100}},
	{"id": &"war_tithe", "text": "Accept the war tithe: gain 120 food now; the Decay claim 150 wood.",
	 "grant": {&"food": 120}, "enemy_grant": {&"wood": 150}},
	{"id": &"obsidian_gamble", "text": "Stake 75 gold on an obsidian dig — 50% chance to strike 200 gold.",
	 "cost": {&"gold": 75}, "gamble": {"chance": 0.5, "win": {&"gold": 200}}},
	{"id": &"lattice_surge", "text": "Channel a lattice surge: +15% training speed for 45s at 60 wood upkeep.",
	 "cost": {&"wood": 60}, "buff_train": 1.15, "duration": 45.0},
]

var _alerts: Array = []
var _deal_wait: float = 0.0
var _active_deal: Dictionary = {}
var _deal_ttl: float = 0.0
var _buff_left: float = 0.0
var _deal_rng := RandomNumberGenerator.new()

func _ready() -> void:
	_deal_rng.randomize()
	_arm_deal_timer()

func _arm_deal_timer() -> void:
	_deal_wait = _deal_rng.randf_range(DEAL_MIN_WAIT, DEAL_MAX_WAIT)

func get_active_deal() -> Dictionary:
	return _active_deal

func get_deal_time_left() -> float:
	return _deal_ttl

## Accept/decline the showing deal (UI calls this; expiry auto-declines).
func resolve_deal(accepted: bool) -> void:
	if _active_deal.is_empty():
		return
	var deal: Dictionary = _active_deal
	var id: StringName = deal.get("id", &"")
	if accepted and not _apply_deal(deal):
		accepted = false  # couldn't afford — treated as a decline
	_active_deal = {}
	_deal_ttl = 0.0
	deal_resolved.emit(id, accepted)
	ticker_updated.emit("Deal %s: %s" % ["accepted" if accepted else "declined", String(id)])
	# The offer timer was held while this deal showed (never two at once);
	# re-arming it here queues the next offer naturally.
	_arm_deal_timer()

## Interprets the data table through existing autoloads — no new global state.
func _apply_deal(deal: Dictionary) -> bool:
	var cost: Dictionary = deal.get("cost", {})
	if not cost.is_empty():
		if not ResourceManager.can_afford(cost, 0):
			push("Can't afford that deal", "warning")
			return false
		ResourceManager.spend(cost, 0)
	for type in deal.get("grant", {}):
		ResourceManager.add_resource(type, int(deal["grant"][type]), 0)
	for type in deal.get("enemy_grant", {}):
		ResourceManager.add_resource(type, int(deal["enemy_grant"][type]), 1)
	if deal.has("buff_train"):
		GameStats.train_speed_mult = float(deal["buff_train"])
		_buff_left = float(deal.get("duration", 60.0))
	if deal.has("gamble"):
		var g: Dictionary = deal["gamble"]
		if _deal_rng.randf() < float(g.get("chance", 0.5)):
			for type in g.get("win", {}):
				ResourceManager.add_resource(type, int(g["win"][type]), 0)
			push("The dig struck rich!", "info")
		else:
			push("The dig came up empty...", "warning")
	return true

func _offer_deal() -> void:
	_active_deal = DEALS[_deal_rng.randi() % DEALS.size()]
	_deal_ttl = DEAL_TTL
	deal_offered.emit(_active_deal)
	ticker_updated.emit("Deal offered: %s" % String(_active_deal.get("text", "")))

## Deals only run mid-match (a Town Center exists). Leaving the match clears
## any showing offer and re-arms the timer.
func _in_match() -> bool:
	return get_tree().get_first_node_in_group("town_center") != null

func push(text: String, level: String = "info") -> void:
	if _alerts.size() >= MAX_ALERTS:
		_alerts.pop_front()
		alert_cleared.emit(0)
	_alerts.append({"text": text, "level": level, "time_remaining": ALERT_LIFETIME})
	alert_pushed.emit(text, level)

func get_alerts() -> Array:
	return _alerts

func register_building(b: Node) -> void:
	if b == null or not is_instance_valid(b):
		return
	if b.has_signal("building_damaged") and not b.is_connected("building_damaged", _on_building_damaged):
		b.connect("building_damaged", _on_building_damaged)

func _on_building_damaged(_building: Node) -> void:
	push("Base under attack!", "error")

func _process(delta: float) -> void:
	_tick_deals(delta)
	if _alerts.is_empty():
		return
	var i: int = _alerts.size() - 1
	while i >= 0:
		_alerts[i]["time_remaining"] = float(_alerts[i]["time_remaining"]) - delta
		if float(_alerts[i]["time_remaining"]) <= 0.0:
			_alerts.remove_at(i)
			alert_cleared.emit(i)
		i -= 1

func _tick_deals(delta: float) -> void:
	# Training buff countdown runs regardless of match state.
	if _buff_left > 0.0:
		_buff_left -= delta
		if _buff_left <= 0.0:
			GameStats.train_speed_mult = 1.0
			ticker_updated.emit("Training buff expired")
	if not _in_match():
		if not _active_deal.is_empty():
			_active_deal = {}
			_deal_ttl = 0.0
		return
	if not _active_deal.is_empty():
		_deal_ttl -= delta
		if _deal_ttl <= 0.0:
			var id: StringName = _active_deal.get("id", &"")
			_active_deal = {}
			deal_resolved.emit(id, false)
			ticker_updated.emit("Deal expired: %s" % String(id))
			_arm_deal_timer()
		return
	_deal_wait -= delta
	if _deal_wait <= 0.0:
		_offer_deal()
