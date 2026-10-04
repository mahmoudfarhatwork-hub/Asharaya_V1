extends Node
# tests/sim_gameplay.gd — محاكاة لعب كاملة بدون واجهة: شاشة البداية ← الأوفلاين ← إنشاء شخصية ← حركة ← كلام مع NPC ← شراء ← قتال ← حفظ.
# التشغيل:  godot --headless --path godot_project_FINAL res://tests/sim_gameplay.tscn
# أي سطر SIM_FAIL أو ERROR في المخرجات = مشكلة محتاجة إصلاح.

var town: Node
var ok: int = 0
var bad: int = 0
var replies: Array = []


func t(label: String, cond: bool) -> void:
	if cond:
		ok += 1
		print("SIM_OK   ", label)
	else:
		bad += 1
		print("SIM_FAIL ", label)


func wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func find_root_child(script_class: GDScript) -> Node:
	for c in get_tree().root.get_children():
		if c.get_script() == script_class:
			return c
	return null


func _ready() -> void:
	town = load("res://scenes/StarterTown.tscn").instantiate()
	add_child(town)
	call_deferred("_run")


func _run() -> void:
	await wait(1.0)
	var player: Node3D = town.get_node("Player")
	t("player exists and in group players", player != null and player.is_in_group("players"))

	# 1) شاشة البداية
	var title = find_root_child(TitleScreen)
	t("title screen shown", title != null)
	if title:
		title._on_login_pressed()
	await wait(0.6)

	# 2) شاشة الاتصال: أوفلاين
	var menu = find_root_child(ConnectionMenu)
	t("connection menu shown", menu != null)
	if menu:
		menu._on_offline_pressed()
	await wait(1.5)
	t("network offline mode", NetworkManager.is_offline)

	# 3) إنشاء الشخصية (عرق بشري/ذكر/محارب)
	t("character creation screen opened", is_instance_valid(CharacterCreationUI) and CharacterCreationUI.get_child_count() > 0)
	CharacterCreationUI._selected_race = "human"
	CharacterCreationUI._selected_gender = "male"
	CharacterCreationUI._selected_profession = "warrior"
	CharacterCreationUI._on_confirm()
	await wait(2.5)

	var body = player.get_node_or_null("HumanBody")
	t("HumanBody (Mixamo) attached", body != null)
	var anim_player: AnimationPlayer = null
	if body:
		anim_player = _find_anim(body)
	t("AnimationPlayer found", anim_player != null)
	if anim_player:
		var lib_ok: bool = anim_player.has_animation_library("mixamo")
		t("mixamo animation library added", lib_ok)
		if lib_ok:
			var names: PackedStringArray = anim_player.get_animation_library("mixamo").get_animation_list()
			t("6 animations in library (got %d)" % names.size(), names.size() == 6)
			print("SIM_INFO animations: ", names, " playing: ", anim_player.current_animation)

	var stats = player.get_node("PlayerStats")
	t("stats: warrior hp > 0", stats.hp > 0)
	t("starting coins = 3 iron", CurrencySystem.total_in_iron() == 3)
	var inv = player.get_node("Inventory")
	t("starting gear given", inv.has_item("rusty_sword"))

	# 4) حركة
	var p0: Vector3 = player.global_position
	Input.action_press("move_forward")
	await wait(1.2)
	Input.action_release("move_forward")
	var moved: float = p0.distance_to(player.global_position)
	t("player moves forward (%.2f m)" % moved, moved > 0.5)
	if anim_player:
		print("SIM_INFO anim while moving: ", anim_player.current_animation)

	# 5) NPCs في المدينة
	var npcs: Array = get_tree().get_nodes_in_group("npcs")
	t("town NPCs registered (%d)" % npcs.size(), npcs.size() >= 9)
	var smith: Node3D = null
	var farmer: Node3D = null
	for n in npcs:
		var prof: Dictionary = n.get_meta("profile", {})
		if prof.get("job", "") == "blacksmith":
			smith = n
		if prof.get("job", "") == "farmer":
			farmer = n
	t("blacksmith + farmer NPC found", smith != null and farmer != null)

	Dialogue.response_ready.connect(func(id, text): replies.append([id, text]))
	CurrencySystem.add_iron_value(500)
	await _chat(player, smith, "اهلا يا معلم")
	await _chat(player, smith, "عايز اشتري سيف")
	await _chat(player, smith, "تمام")
	t("bought iron_sword via chat", inv.has_item("iron_sword"))
	await _chat(player, smith, "فين السوق؟")
	await _chat(player, smith, "عندك مهمة ليا؟")
	await _chat(player, farmer, "عايز اشتري خبز")
	await _chat(player, farmer, "تمام")
	t("bought bread via chat", inv.has_item("bread"))
	await _chat(player, smith, "انت غبي يا حمار")
	await _chat(player, smith, "هقتلك")
	t("NPC replied to every message (%d replies)" % replies.size(), replies.size() >= 9)
	for r in replies:
		print("SIM_CHAT [", r[0], "] ", r[1])

	# 6) قتال: وحش قريب + قتله + مكافآت
	var mon = Monster.create("bat", player.global_position + Vector3(0, 0, -2))
	town.add_child(mon)
	mon.add_to_group("monsters")
	await wait(0.5)
	var xp0: int = stats.xp
	var iron0: int = CurrencySystem.total_in_iron()
	mon.take_damage(9999, player)
	await wait(0.2)
	t("monster killed gives xp or level", stats.xp > xp0 or stats.level > 1)
	t("monster killed gives coins", CurrencySystem.total_in_iron() >= iron0)
	var cs = player.get_node("CombatSystem")
	cs.attack()
	await wait(0.3)

	# 7) حفظ
	town._periodic_save()
	await wait(0.3)
	t("offline save file exists", FileAccess.file_exists("user://offline_save.json"))
	Dialogue._save_memory()
	t("npc memory saved", FileAccess.file_exists("user://npc_memory.json"))

	# 7b) محاكاة إعادة تشغيل: نكسب XP، نحفظ، نعيد قراءة الملف، نصفّر القيم، نحمّل من الحفظ
	stats.gain_xp(150)
	var level_before: int = stats.level
	town._periodic_save()
	await wait(0.2)
	NetworkManager._load_local_file()   # قراءة جديدة من الملف (زي فتح اللعبة من الأول)
	stats.level = 1
	stats.xp = 0
	inv.slots.fill(null)
	await stats.load_saved()
	await inv.load_saved()
	t("level survives save + reload (%d)" % stats.level, level_before >= 2 and stats.level == level_before)
	t("inventory survives save + reload", inv.has_item("rusty_sword"))

	# 8) ترك اللعبة تشتغل شوية (ليل/نهار/NPC behavior/أداء)
	await wait(4.0)
	print("SIM_SUMMARY ok=%d bad=%d" % [ok, bad])
	get_tree().quit(1 if bad > 0 else 0)


func _chat(player: Node3D, npc: Node3D, text: String) -> void:
	player.global_position = npc.global_position + Vector3(0, 0.1, 2.0)
	await wait(0.15)
	var n0: int = replies.size()
	Dialogue.handle_player_chat(text)
	await wait(2.4)
	t("reply to '%s' (%d->%d)" % [text, n0, replies.size()], replies.size() > n0)


func _find_anim(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for c in node.get_children():
		var f := _find_anim(c)
		if f:
			return f
	return null
