class_name HudSystem
extends CanvasLayer

## Sprint 1 HUD — text only. Flat node structure, no nested Control wrappers.
## LevelBase wires signals to the public setters below.

@onready var timer_label: Label = find_child("TimerLabel") as Label
@onready var level_label: Label = find_child("LevelLabel") as Label
@onready var points_bar: ProgressBar = find_child("PointsBar") as ProgressBar
@onready var goals_label: Label = find_child("GoalsLabel") as Label
@onready var win_label: Label = find_child("WinLabel") as Label
@onready var fail_label: Label = find_child("FailLabel") as Label
@onready var win_screen: Control = find_child("WinScreen") as Control
@onready var fail_screen: Control = find_child("FailScreen") as Control


func _ready() -> void:
	win_screen.hide()
	fail_screen.hide()


# --- Setters called by LevelBase signal connections ---

func set_timer(remaining: float, urgent: bool) -> void:
	var s := int(remaining)
	timer_label.text = "%02d:%02d" % [s / 60, s % 60]
	if urgent:
		timer_label.add_theme_color_override("font_color", Color.RED)
	else:
		timer_label.remove_theme_color_override("font_color")


func set_level(new_level: int) -> void:
	level_label.text = "Level %d" % new_level


func set_points(accumulated: int, thresholds: Array[int], level: int) -> void:
	if level >= 10:
		points_bar.value = 1.0
		return
	var lo := 0 if level == 1 else thresholds[level - 2]
	var hi := thresholds[level - 1]
	points_bar.value = 0.0 if hi == lo else float(accumulated - lo) / float(hi - lo)


func set_goals(counters: Dictionary) -> void:
	var lines: PackedStringArray = []
	for id: String in counters.keys():
		lines.append("%s: %d" % [id, counters[id]])
	goals_label.text = "\n".join(lines)


func show_win(stars: int) -> void:
	win_label.text = "Level Complete!\n" + "★".repeat(stars) + "☆".repeat(3 - stars)
	win_screen.show()


func show_fail() -> void:
	fail_label.text = "Time's Up!"
	fail_screen.show()
