extends CharacterBody3D
# Player.gd — حركة موحدة تشتغل بالكيبورد على PC وباللمس على Android تلقائياً
# مفيش حاجة تتغير بين المنصتين — نفس الملف، نفس المشروع، تصدير مختلف بس
#
# الحركة نسبية للكاميرا: "قدّام" = الاتجاه اللي الكاميرا بتبص عليه.
# الكاميرا (CameraPivot) بتتفصل عن دوران الجسم (top_level) وليها زاوية yaw خاصة بيها،
# عشان لف الجسم ناحية اتجاه الحركة ما يغيّرش اتجاه "قدّام" (كان بيعمل حلقة ويلغي الحركة).
# التحكم في الكاميرا: PC = اضغط كليك يمين واسحب | موبايل = اسحب بصباعك على يمين الشاشة.

const WALK_SPEED := 5.0
const RUN_MULTIPLIER := 1.6
const JUMP_VELOCITY := 4.5
const GRAVITY := 9.8

const SEND_INTERVAL := 0.1
const CAMERA_MOUSE_SENS := 0.005
const CAMERA_TOUCH_SENS := 0.006

var _send_timer := 0.0
var _cam_yaw := 0.0
var _rmb_down := false

# GameManager بيقفل الإدخال وقت الموت/الريسباون
var input_locked := false

# لو فيه PlayerStats (V2+) هيتلاقى تلقائي ويتستخدم لضبط الجري بالستامينا
@onready var stats: Node = get_node_or_null("PlayerStats")
@onready var _camera_pivot: Node3D = get_node_or_null("CameraPivot")
@onready var _combat: Node = get_node_or_null("CombatSystem")


func _ready() -> void:
	if _camera_pivot:
		_camera_pivot.top_level = true  # الكاميرا ما ترثش دوران الجسم
		_camera_pivot.global_position = global_position


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		_rmb_down = event.pressed
	elif event is InputEventMouseMotion and _rmb_down:
		_cam_yaw -= event.relative.x * CAMERA_MOUSE_SENS


func _physics_process(delta: float) -> void:
	if MobileControls.is_mobile():
		_cam_yaw -= MobileControls.consume_camera_drag().x * CAMERA_TOUCH_SENS

	_handle_movement(delta)
	_update_camera()
	_send_position_to_server(delta)
	_send_stats_to_server(delta)

	if MobileControls.is_mobile():
		MobileControls.consume_one_shot_inputs()


func _update_camera() -> void:
	if _camera_pivot == null:
		return
	_camera_pivot.global_position = global_position
	_camera_pivot.rotation = Vector3(0.0, _cam_yaw, 0.0)


func _get_movement_input() -> Vector2:
	if input_locked:
		return Vector2.ZERO
	if MobileControls.is_mobile():
		return MobileControls.movement_vector
	return Input.get_vector("move_left", "move_right", "move_forward", "move_back")


func _is_jump_pressed() -> bool:
	if input_locked:
		return false
	if MobileControls.is_mobile():
		return MobileControls.jump_just_pressed
	return Input.is_action_just_pressed("jump")


func _is_run_held() -> bool:
	if input_locked:
		return false
	if MobileControls.is_mobile():
		return MobileControls.run_held
	return Input.is_action_pressed("run")


func _is_interact_pressed() -> bool:
	if input_locked:
		return false
	if MobileControls.is_mobile():
		return MobileControls.interact_just_pressed
	return Input.is_action_just_pressed("interact")


func _is_attack_pressed() -> bool:
	# على PC الهجوم بكليك الشمال (CombatSystem بيسمعه بنفسه). هنا زر الموبايل بس.
	if input_locked:
		return false
	return MobileControls.is_mobile() and MobileControls.attack_just_pressed


func _handle_movement(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	if _is_jump_pressed() and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# الاتجاه نسبي لزاوية الكاميرا (مش لدوران الجسم)
	var input_dir := _get_movement_input()
	var direction := Basis(Vector3.UP, _cam_yaw) * Vector3(input_dir.x, 0.0, input_dir.y)
	if direction.length() > 1.0:
		direction = direction.normalized()
	var is_moving := direction.length() > 0.1

	var can_run := true
	var base_speed := WALK_SPEED
	if stats != null and stats.has_method("can_run"):
		can_run = stats.can_run()
	if stats != null and "move_speed" in stats:
		base_speed = stats.move_speed  # بيراعي فروق السرعة بين الأعراق/المهن (V6)

	var is_running := _is_run_held() and can_run
	var speed := base_speed * (RUN_MULTIPLIER if is_running else 1.0)

	if stats != null and stats.has_method("notify_running"):
		stats.notify_running(is_running and is_moving)

	if is_moving:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		var target_rot := atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_rot, 10.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	_update_animation(is_moving, is_running)

	move_and_slide()

	if _is_interact_pressed():
		_try_interact()

	if _is_attack_pressed() and _combat != null and _combat.has_method("attack"):
		_combat.attack()


func _try_interact() -> void:
	for trader in get_tree().get_nodes_in_group("traders"):
		trader.try_open_shop_for(self)


func _send_position_to_server(delta: float) -> void:
	_send_timer += delta
	if _send_timer >= SEND_INTERVAL:
		_send_timer = 0.0
		NetworkManager.send_position(global_position, rotation.y)


func _send_stats_to_server(_delta: float) -> void:
	if stats != null and stats.has_method("get_hp_data"):
		var d: Dictionary = stats.get_hp_data()
		NetworkManager.send_stats(d.hp, d.max_hp, d.level)


# ربط حركات Mixamo بحالة اللاعب
var _anim_player: AnimationPlayer = null
var _current_anim_key := ""


func _update_animation(is_moving: bool, is_running: bool) -> void:
	# الجسم البشري بيتركّب بعد إنشاء الشخصية، فنفضل ندوّر عليه لحد ما نلاقيه
	if _anim_player == null or not is_instance_valid(_anim_player):
		_anim_player = null
		var body := get_node_or_null("HumanBody")
		if body:
			_anim_player = _find_anim_player(body)
			_current_anim_key = ""
	if _anim_player == null:
		return
	# الجسم بيلف ناحية اتجاه الحركة، فمفيش مشي لورا: أي حركة = مشي لقدّام
	var key := "talk_phone"  # وقوف
	if is_moving:
		key = "strut_walk" if is_running else "catwalk_walk"
	if key != _current_anim_key:
		_current_anim_key = key
		if _anim_player.has_animation("mixamo/%s" % key):
			_anim_player.play("mixamo/%s" % key)


func _find_anim_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for c in node.get_children():
		var f := _find_anim_player(c)
		if f:
			return f
	return null
