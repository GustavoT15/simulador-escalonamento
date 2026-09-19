class_name TarefaModulo extends PanelContainer

@export var tarefa:TarefaInfo
@export var titulo:RichTextLabel
@export var descricao:RichTextLabel
@export var caixa_cheque:CheckBox
@export var remover:Button
@export var sobe:Button
@export var desce:Button
@export var id:int:
	set(value):
		if is_instance_valid(tarefa):
			tarefa.uid =value
		id = value
var nome_primario_feminino = ["Tarefa","Requisição","Negociação"]
var nome_primario_masculino = ["Favor","Pedido","Processo"]
var nome_secundario_masculino = ["Rude","Espontaneo","Amoroso","Estranho","Particular","Honesto"]
var nome_secundario_feminino = ["Rude","Espontanea","Amorosa","Estranha","Particular","Honesta"]

var nome_selecionado:String

var removendo:bool = false

func _ready()->void:
	if !is_instance_valid(tarefa):
		queue_free()
		return
	sobe.pressed.connect(sobir)
	desce.pressed.connect(descer)
	remover.pressed.connect(remove)
	if tarefa.nome.is_empty():
		var nome:String = nome_primario_masculino.pick_random() +" "+ nome_secundario_masculino.pick_random()
		if randf_range(0,1) > .5:
			nome = nome_primario_feminino.pick_random() +" "+ nome_secundario_feminino.pick_random()
		nome_selecionado = nome
		tarefa.nome = nome_selecionado
	descricao.set_text("
Prioridade : 			%s
Tempo de Execução : 	%s
Momento de entrada : 	%s"%[tarefa.Prioridade,tarefa.Tempo_Processo,tarefa.Tempo_Entrada])

	var container = %GridContainer
	for i in ["Prioridade","%3d" % tarefa.Prioridade,"Tempo de Execução","%3d" % tarefa.Tempo_Processo,"Momento de entrada","%3d" % tarefa.Tempo_Entrada,"Momento de pedido de recurso","%3d" % tarefa.TempoPedidoRecurso,"Tempo de recurso","%3d" % tarefa.TempoUsoRecurso]:
		var text = RichTextLabel.new()
		container.add_child(text)
		text.text = i
		print(text.text)
		text.fit_content = true
		text.custom_minimum_size.x = 25
	#	text.horizontal_alignment =HORIZONTAL_ALIGNMENT_LEFT
		text.autowrap_mode =TextServer.AUTOWRAP_OFF

	fade_in(1.0)
	
	
	atualizar_titulo()


func sobir()->void:
	get_parent().move_child(self,clamp(get_index()-1,0,99999))
func descer()->void:
	get_parent().move_child(self,clamp(get_index()+1,0,99999))

func atualizar_titulo()->void:
	titulo.set_text(tarefa.nome + " UID : %s"%[id])
func fade_in(time:float = 3.0)->void:
	var tween = create_tween()
	var prev_size = size.y
	print(prev_size)
	self.custom_maximum_size.y = 0
	tween.tween_property(self,"custom_maximum_size:y",prev_size,time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tween.finished
	return
func fade_out(time:float = 3.0)->void:
	var tween = create_tween()

	tween.tween_property(self,"custom_maximum_size:y",0,time)
	await tween.finished
	return
func remove()->void:
	removendo = true
	await fade_out(.5)
	queue_free()	
	

func get_selecionado()->bool:
	if !is_instance_valid(caixa_cheque):
		return false
	return caixa_cheque.is_pressed()
