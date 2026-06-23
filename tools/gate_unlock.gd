extends SceneTree

## Headless campaign unlock-chain gate: verifies the mission progression rule
## (each mission unlocks once the previous is cleared, first always available)
## and MissionConfig.next_id ordering. Pure logic — mutates ProfileManager's
## in-memory cleared list only (no disk writes). GATE_UNLOCK_OK = chain correct.

func _process(_delta: float) -> bool:
	var pm: Node = root.get_node("/root/ProfileManager")
	var ids: Array[String] = []
	for m in MissionConfig.MISSIONS:
		ids.append(String(m.get("id", "")))
	var ok: bool = true

	# Progressive clearing: with the first N missions cleared, exactly N+1 should
	# be unlocked (capped at the total).
	for cleared in range(ids.size() + 1):
		var arr: Array[String] = []
		for j in range(cleared):
			arr.append(ids[j])
		pm.cleared_missions = arr
		var unlocked: int = _unlocked_count(pm, ids)
		var expected: int = mini(cleared + 1, ids.size())
		if unlocked != expected:
			print("FAIL cleared=%d unlocked=%d expected=%d" % [cleared, unlocked, expected])
			ok = false

	# next_id chain must walk m1 -> ... -> last -> "".
	for i in ids.size():
		var nxt: String = MissionConfig.next_id(ids[i])
		var exp: String = ids[i + 1] if i + 1 < ids.size() else ""
		if nxt != exp:
			print("FAIL next_id(%s)=%s expected=%s" % [ids[i], nxt, exp])
			ok = false

	if ok:
		print("GATE_UNLOCK_OK")
	quit(0 if ok else 1)
	return true

## Mirrors campaign_menu's rule: first mission is free, each later one needs the
## previous cleared.
func _unlocked_count(pm: Node, ids: Array[String]) -> int:
	var prev: bool = true
	var n: int = 0
	for id in ids:
		if prev:
			n += 1
		prev = pm.is_mission_cleared(id)
	return n
