@tool
class_name EntradaDeTexto extends VBoxContainer
@export var valor_inicial:float = 0
@export var is_int:bool = true
@export var nome_exibir:String:
	set(value):
		nome_exibir = value
		update_name()
@export var titulo:RichTextLabel
@export var entrada_de_texto:SpinBox


func set_enabled(n:bool)->void:
	entrada_de_texto.editable = n
func update_name()->void:
	if !is_instance_valid(titulo):
		return
	titulo.set_text(nome_exibir)
	
	pass

func _ready()->void:
	update_name()
	if !is_int:
		entrada_de_texto.step = .01
	entrada_de_texto.value = valor_inicial

func get_entrada()->float:
	return entrada_de_texto.get_value()
	
