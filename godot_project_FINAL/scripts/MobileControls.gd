extends Node
# MobileControls.gd — Autoload (Singleton)
# بيبني واجهة تحكم لمس (جويستيك + أزرار + سحب الكاميرا) بالكود بالكامل — مفيش ملف .tscn منفصل
#
# بيظهر تلقائي بس لو اللعبة شغالة على Android/iOS. على PC مش هيظهر خالص.
# المقاسات بتتحسب من حجم الـ viewport (مش من DisplayServer.screen_get_size)، عشان تتطابق مع
# إحداثيات اللمس بعد ما الـ stretch mode يكبّر الواجهة على الشاشات الكبيرة.

var movement_vector: Vector2 = Vector2.ZERO
var run_held: bool = false
var jump_just_pressed: bool = false
var interact_just_pressed: bool = false
var attack_just_pressed: bool = false

var _camera_drag: Vector2 = Vector2.ZERO

const JOYSTICK_RADIUS := 80.0
const CAMERA_ZONE_MIN_X := 0.35  # أي لمسة على يمين 35% من العرض (بره الأزرار) بتحرّك الكاميرا

var _joystick_touch_index: int = -1
var _run_touch_index: int = -1
var _camera_touch_index: int = -1

var _joystick_base_pos: Vector2
var _buttons: Dictionary = {}  # اسم الزر -> {"pos": Vector2, "radius": float, "node": Control}

var _canvas: CanvasLayer
var _joystick_base_visual: Control
var _joystick_knob_visual: Control


# دايرة بترسم نفسها (بدل ما نكتب GDScript كنص ونعمله reload وقت التشغيل)
class _Circle:
	extends Control
	var circle_color: Color = Color(1, 1, 1, 0.3)

	func _draw() -> void:
		draw_circle(size / 2.0, size.x / 2.0, circle_color)


func is_mobile() -> bool:
	return OS.get_name() == "Android" or OS.get_name() == "iOS"


func _ready() -> void:
	if not is_mobile():
		return  # على PC، السكريبت ده منفعلش خالص، الكيبورد والماوس هما اللي شغالين

	_build_ui()
	get_viewport().size_changed.connect(_layout)
	set_process_input(true)


func _viewport_size() -> Vector2:
	return get_viewport().get_visible_rect().size


func _build_ui() -> void:
	_canvas = CanvasLayer.new()
	_canvas.layer = 100
	get_tree().root.call_deferred("add_child", _canvas)

	_joystick_base_visual = _make_circle(Color(1, 1, 1, 0.2))
	_joystick_knob_visual = _make_circle(Color(1, 1, 1, 0.4))
	_canvas.add_child(_joystick_base_visual)
	_canvas.add_child(_joystick_knob_visual)

	_add_button("attack", Color(1, 0.25, 0.25, 0.55), 55.0, "هجوم")
	_add_button("jump", Color(0.2, 0.6, 1, 0.5), 45.0, "قفز")
	_add_button("run", Color(1, 0.6, 0.2, 0.5), 45.0, "جري")
	_add_button("interact", Color(0.2, 1, 0.4, 0.5), 40.0, "تفاعل")

	_layout()


func _add_button(id: String, color: Color, radius: float, label_text: String) -> void:
	var c := _make_circle(color)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(lbl)
	_canvas.add_child(c)
	_buttons[id] = {"pos": Vector2.ZERO, "radius": radius, "node": c}


func _make_circle(color: Color) -> Control:
	var c := _Circle.new()
	c.circle_color = color
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _place(c: Control, pos: Vector2, radius: float) -> void:
	c.size = Vector2(radius * 2.0, radius * 2.0)
	c.position = pos - Vector2(radius, radius)
	c.queue_redraw()


# بيتنادى أول مرة وكل ما حجم الشاشة يتغير
func _layout() -> void:
	var vs := _viewport_size()

	_joystick_base_pos = Vector2(150.0, vs.y - 150.0)
	_place(_joystick_base_visual, _joystick_base_pos, JOYSTICK_RADIUS)
	_place(
		_joystick_knob_visual,
		_joystick_base_pos + movement_vector * JOYSTICK_RADIUS,
		JOYSTICK_RADIUS * 0.5
	)

	_buttons["attack"]["pos"] = Vector2(vs.x - 120.0, vs.y - 130.0)
	_buttons["jump"]["pos"] = Vector2(vs.x - 260.0, vs.y - 100.0)
	_buttons["run"]["pos"] = Vector2(vs.x - 240.0, vs.y - 230.0)
	_buttons["interact"]["pos"] = Vector2(vs.x - 110.0, vs.y - 250.0)
	for id in _buttons:
		var b: Dictionary = _buttons[id]
		_place(b["node"], b["pos"], b["radius"])


func _button_at(pos: Vector2) -> String:
	for id in _buttons:
		var b: Dictionary = _buttons[id]
		if pos.distance_to(b["pos"]) <= float(b["radius"]) * 1.15:
			return id
	return ""


func _set_knob(offset: Vector2) -> void:
	if _joystick_knob_visual:
		_place(_joystick_knob_visual, _joystick_base_pos + offset, JOYSTICK_RADIUS * 0.5)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var pos: Vector2 = event.position
		if event.pressed:
			var btn := _button_at(pos)
			if (
				pos.distance_to(_joystick_base_pos) <= JOYSTICK_RADIUS * 1.5
				and _joystick_touch_index == -1
			):
				_joystick_touch_index = event.index
			elif btn == "jump":
				jump_just_pressed = true
			elif btn == "interact":
				interact_just_pressed = true
			elif btn == "attack":
				attack_just_pressed = true
			elif btn == "run":
				run_held = true
				_run_touch_index = event.index
			elif (
				btn == ""
				and pos.x > _viewport_size().x * CAMERA_ZONE_MIN_X
				and _camera_touch_index == -1
			):
				_camera_touch_index = event.index
		else:
			if event.index == _joystick_touch_index:
				_joystick_touch_index = -1
				movement_vector = Vector2.ZERO
				_set_knob(Vector2.ZERO)
			if event.index == _run_touch_index:
				_run_touch_index = -1
				run_held = false
			if event.index == _camera_touch_index:
				_camera_touch_index = -1

	elif event is InputEventScreenDrag:
		if event.index == _joystick_touch_index:
			var offset: Vector2 = event.position - _joystick_base_pos
			offset = offset.limit_length(JOYSTICK_RADIUS)
			movement_vector = offset / JOYSTICK_RADIUS
			_set_knob(offset)
		elif event.index == _camera_touch_index:
			_camera_drag += event.relative


# يُستدعى من Player.gd في نهاية كل فريم عشان يصفّر الأزرار اللي "ضغطة واحدة" (قفز/تفاعل/هجوم)
func consume_one_shot_inputs() -> void:
	jump_just_pressed = false
	interact_just_pressed = false
	attack_just_pressed = false


# سحب الكاميرا المتراكم من آخر فريم (بيتصفّر بعد القراءة)
func consume_camera_drag() -> Vector2:
	var d := _camera_drag
	_camera_drag = Vector2.ZERO
	return d
