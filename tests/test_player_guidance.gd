extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, text: String) -> void:
	print("PASS " if ok else "FAIL ", text)
	if not ok: failures += 1
func run() -> void:
	root.size = Vector2i(1280, 720)
	var game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.fire_grid.simulation_paused = true
	for actor in [game.player, game.elder, game.youth]: actor.set_physics_process(false)
	var p = game.player
	var hud = game.hud
	p.input_enabled = true
	p.water_capacity = 30.0
	p.water = 0.0
	p.global_position = p.refill_point + Vector3(3.6, 0, 0)
	p._update_refill(1.0)
	hud._update_refill_guidance()
	check(p.water == 0.0 and hud.refill_hint.text.contains("ถัง"), "outside radius shows approach without refilling")
	p.global_position = p.refill_point + Vector3(3.4, 20, 0)
	p._update_refill(1.0)
	hud._update_refill_guidance()
	check(p.water == 5.0 and hud.refill_hint.text.contains("กำลังเติมน้ำ") and hud.refill_hint.text.contains("30"), "horizontal radius fills at original rate with upgraded capacity")
	p.input_enabled = false
	p._update_refill(1.0)
	hud._update_refill_guidance()
	check(p.water == 5.0 and not hud.refill_hint.text.contains("กำลัง"), "disabled input never claims active refill")
	p.input_enabled = true
	p._update_refill(100.0)
	hud._update_refill_guidance()
	check(p.water == 30.0 and hud.refill_hint.text == "น้ำเต็มแล้ว", "refill caps at capacity and explains completion")
	hud.update_stamina(50, 100, 6)
	check(hud.breath_hint.text.contains("ออกจากควัน"), "coughing explains leaving smoke")
	hud.update_stamina(40, 100, 5)
	check(hud.breath_hint.text == "ควันลดลง · ยังไออยู่", "decay above cough threshold does not promise stamina recovery")
	hud.update_stamina(41, 100, 3.9)
	check(hud.breath_hint.text == "กำลังฟื้นลมหายใจ", "below threshold identifies stamina recovery")
	hud.update_stamina(100, 100, 0)
	check(not hud.breath_hint.visible, "full breath clears recovery hint")
	# Actual smoke exposure decay preserves the cough delay and original rates.
	game.fire_grid.cell_types.fill(game.fire_grid.CellType.ASH)
	p.global_position = game.fire_grid.get_cell_world_pos(20,20)
	p.smoke_exposure = 6
	p.current_stamina = 70
	p._update_smoke_and_stamina(1.0)
	check(is_equal_approx(p.smoke_exposure, 4.5) and is_equal_approx(p.current_stamina, 52), "clean air reduces exposure but cough still drains above threshold")
	p._update_smoke_and_stamina(1.0)
	check(is_equal_approx(p.smoke_exposure, 3.0) and p.current_stamina > 52, "breath recovers only after exposure falls below threshold")
	hud.set_minimal(true)
	check(not hud.refill_marker.visible and not hud.vitals_card.visible, "minimal HUD hides refill and breath guidance")
	hud.set_minimal(false)
	p.water = 0
	p.refill_point = p.global_position + Vector3(1000, 0, 1000)
	hud._update_refill_guidance()
	check(hud.refill_marker.visible and hud.refill_marker.position.x >= 24 and hud.refill_marker.position.x <= 1100, "empty tank offscreen cue stays within screen margins")
	hud.show_satellite_sweep_ui()
	check(not hud.refill_marker.visible, "satellite hides refill marker")
	game.queue_free()
	await process_frame
	print("GUIDANCE RESULT: ", failures)
	quit(1 if failures else 0)
