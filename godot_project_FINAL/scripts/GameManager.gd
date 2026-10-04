extends Node3D
class_name GameManager
# GameManager.gd — نقطة التجميع النهائية، مرتبط بالـ Main.tscn (المشهد الرئيسي)

@onready var player: Node = $Player

# أدنى مستوى سلاح/ملابس لكل مهنة — بيتحط في المخزون أول ما الشخصية تتعمل
const STARTING_GEAR := {
	"warrior":
	[
		{"id": "rusty_sword", "name": "سيف صدئ", "type": "weapon"},
		{"id": "cloth_armor", "name": "درع قماش", "type": "armor"}
	],
	"mage":
	[
		{"id": "wooden_staff", "name": "عصا خشبية", "type": "weapon"},
		{"id": "apprentice_robe", "name": "رداء متدرب", "type": "armor"}
	],
	"sorcerer":
	[
		{"id": "cracked_wand", "name": "عصا سحرية متصدعة", "type": "weapon"},
		{"id": "tattered_cloak", "name": "عباءة ممزقة", "type": "armor"}
	],
	"priest":
	[
		{"id": "wooden_mace", "name": "صولجان خشبي", "type": "weapon"},
		{"id": "novice_vestment", "name": "ثوب كهنوتي مبتدئ", "type": "armor"}
	],
	"healer":
	[
		{"id": "healing_wand", "name": "عصا شفاء بسيطة", "type": "weapon"},
		{"id": "healer_robe", "name": "رداء معالج", "type": "armor"}
	],
	"blacksmith":
	[
		{"id": "old_hammer", "name": "مطرقة قديمة", "type": "weapon"},
		{"id": "leather_apron", "name": "مريلة جلدية", "type": "armor"}
	],
	"trader":
	[
		{"id": "small_dagger", "name": "خنجر صغير", "type": "weapon"},
		{"id": "merchant_coat", "name": "معطف تاجر", "type": "armor"}
	],
	"farmer":
	[
		{"id": "wooden_hoe", "name": "فأس خشبي", "type": "weapon"},
		{"id": "farmer_clothes", "name": "ملابس مزارع", "type": "armor"}
	],
	"beast_tamer":
	[
		{"id": "taming_whip", "name": "سوط ترويض", "type": "weapon"},
		{"id": "tamer_vest", "name": "صدرية مروض", "type": "armor"}
	],
}

var _spawn_point: Vector3 = Vector3.ZERO
var _profession_id: String = "warrior"
var _session_started: bool = false  # منع تشغيل _on_connected مرتين
var _progress_ready: bool = false  # التقدم اتحمّل — قبلها أي حفظ (خروج/Home) بيتجاهل
var _is_dead: bool = false


func _ready() -> void:
	player.add_to_group("players")
	_spawn_point = (player as Node3D).global_position

	NetworkManager.login_failed.connect(_on_login_failed)
	NetworkManager.connected_to_server.connect(_on_connected)

	# 1) شاشة البداية المتحركة (تسجيل الدخول في النص + مؤثرات + موسيقى)
	var title := TitleScreen.new()
	get_tree().root.add_child.call_deferred(title)
	await title.login_confirmed

	# 2) اختيار أونلاين/أوفلاين (بيتم تخطيها لو الإعداد محفوظ من قبل)
	var menu := ConnectionMenu.new()
	get_tree().root.add_child(menu)
	await menu.mode_selected

	await NetworkManager.login_and_join_world()


func _on_connected() -> void:
	if _session_started:
		return
	_session_started = true
	print("🎮 اللعبة جاهزة، اللاعب متصل بالسيرفر")

	# V6: هل ده حساب جديد ولا لاعب راجع؟ نتأكد من وجود بيانات شخصية محفوظة
	var character_data: Dictionary = await NetworkManager.load_player_data(
		"player_progress", "character", {}
	)
	var is_new_character := character_data.is_empty()

	if is_new_character:
		# حساب جديد — لازم يختار عرق/جنس/مهنة أول مرة بس
		CharacterCreationUI.show_creation_screen()
		var result: Array = await CharacterCreationUI.character_created
		_apply_character(result[0], result[1], result[2], result[3])
	else:
		# لاعب راجع — نفس الشكل والمهنة والعرق زي ما هو، مفيش تغيير
		_apply_character(
			character_data.get("race", "human"),
			character_data.get("gender", "male"),
			character_data.get("profession", "warrior"),
			int(character_data.get("appearance_seed", 0))
		)

	# التقدم (إحصائيات/مخزون/مهام) بيتحمّل هنا: بعد جاهزية الملف المحلي أو السيرفر،
	# وبعد تطبيق إحصائيات العرق/المهنة عشان الحفظ يكتب فوقها (مستوى، صحة قصوى، عملات...)
	await _load_progress()

	if is_new_character:
		_give_starting_gear(_profession_id)

	_progress_ready = true
	if is_new_character:
		_periodic_save()  # نثبّت الشخصية الجديدة فوراً، مش بعد 30 ثانية

	var stats: PlayerStats = player.get_node_or_null("PlayerStats")
	if stats:
		HUD.bind_to_stats(stats)
		stats.died.connect(_on_player_died)

	# حفظ دوري كل 30 ثانية بدل ما نعتمد بس على حفظ يدوي
	var save_timer := Timer.new()
	save_timer.wait_time = 30.0
	save_timer.autostart = true
	save_timer.timeout.connect(_periodic_save)
	add_child(save_timer)


func _load_progress() -> void:
	var stats: PlayerStats = player.get_node_or_null("PlayerStats")
	var inv: Inventory = player.get_node_or_null("Inventory")
	var quests: QuestSystem = player.get_node_or_null("QuestSystem")
	if stats:
		await stats.load_saved()
	if inv:
		await inv.load_saved()
	if quests:
		await quests.load_saved()


func _apply_character(
	race_id: String, gender: String, profession_id: String, appearance_seed: int
) -> void:
	_profession_id = profession_id
	var stats: PlayerStats = player.get_node_or_null("PlayerStats")
	if stats:
		stats.apply_character_data(race_id, profession_id)

	# التركيب البصري — يحمّل/يبني الجسم والراس والشعر والملابس حسب العرق والمهنة
	CharacterAssembly.assemble(player, race_id, gender, profession_id, appearance_seed)

	var brain := get_node_or_null("/root/Dialogue")
	if brain and brain.has_method("set_player_info"):
		brain.set_player_info("", gender, race_id)


# سلاح وملابس أدنى مستوى حسب المهنة — للشخصية الجديدة بس (مش كل مرة اللاعب يدخل،
# عشان لو باع السيف الصدئ ما يرجعلوش)
func _give_starting_gear(profession_id: String) -> void:
	var inv: Inventory = player.get_node_or_null("Inventory")
	if inv == null:
		return
	var gear: Array = STARTING_GEAR.get(profession_id, STARTING_GEAR["warrior"])
	for item in gear:
		if not inv.has_item(item["id"]):
			inv.add_item(item["id"], item["name"], item["type"], 1)


func _on_player_died() -> void:
	if _is_dead:
		return
	_is_dead = true
	player.set("input_locked", true)
	print("💀 اللاعب مات — ريسباون بعد ثواني")
	await get_tree().create_timer(2.5).timeout

	var stats: PlayerStats = player.get_node_or_null("PlayerStats")
	if stats:
		stats.respawn()
	(player as Node3D).global_position = _spawn_point
	player.set("velocity", Vector3.ZERO)
	player.set("input_locked", false)
	_is_dead = false
	_periodic_save()


func _periodic_save() -> void:
	if not _progress_ready:
		return  # لسه شاشة البداية/الاتصال/إنشاء الشخصية: مفيش تقدم يتحفظ (وإلا هنمسح الحفظ الحقيقي)
	var stats: PlayerStats = player.get_node_or_null("PlayerStats")
	var inv: Inventory = player.get_node_or_null("Inventory")
	var quests: QuestSystem = player.get_node_or_null("QuestSystem")
	if stats:
		stats.save_data()
	if inv:
		inv.save_inventory()
	if quests:
		quests.save_quests()


func _on_login_failed(reason: String) -> void:
	push_error("❌ فشل الاتصال بالسيرفر: %s — تأكد إن Nakama شغال (docker compose up)" % reason)


func _notification(what: int) -> void:
	# حفظ فوري لما اللاعب يقفل اللعبة أو يضغط Home (آمن لو لسه في شاشة البداية: _periodic_save بتتجاهل)
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_periodic_save()
