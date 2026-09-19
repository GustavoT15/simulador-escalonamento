class_name Step extends PanelContainer

@export var mensagem:String = ""
@export var cor:Color
@export var text:RichTextLabel

func _ready()->void:
	self_modulate = cor
	text.text = mensagem
