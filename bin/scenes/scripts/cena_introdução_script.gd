extends SubViewportContainer

@onready var text = %Text
@onready var overlay=$SubViewport/ColorRect2
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	
	var tw = create_tween()
	
	text.set_visible_ratio(0.0)
	tw.tween_method(set_modulate,Color(0,0,0,1),Color.WHITE,1.0)
	tw.tween_method(text.set_visible_ratio,0.0,1.0,1.0)
	
	await tw.finished
	await get_tree().create_timer(3.0).timeout
	
	tw = create_tween()
	tw.tween_method(text.set_visible_ratio,1.0,0.0,1.0)
	tw.tween_method(set_modulate,Color(1,1,1,1),Color.BLACK,1.0)
	
	await tw.finished

	$SubViewport/SubViewportContainer.queue_free()

	var scene = load("res://scenes/TelaPrincipal.tscn").instantiate()
	$SubViewport.add_child(scene)
	$SubViewport.move_child(scene, 0)

#	await scene.ready

	tw = create_tween()
	tw.tween_method(set_modulate, Color.BLACK, Color.WHITE, 1.0)
