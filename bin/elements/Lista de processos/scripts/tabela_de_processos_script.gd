class_name TabelaDeProcessos extends Control

@export var botao_salvar:Button

@export var botao_remover_preset:Button
@export var botao_adicionar:Button
@export var botao_aleatorizar:Button
@export var text_aleatorizar:RichTextLabel
@export var botao_limpar:Button
@export var texto_entrada_nome_save:LineEdit
@export var dropdown_presets:MenuButton
@export var texto_entrada_rand_count:EntradaDeTexto
@export var texto_entrada_inicio:EntradaDeTexto
@export var texto_entrada_prioridade:EntradaDeTexto
@export var texto_entrada_tempo_processo:EntradaDeTexto
@export var texto_entrada_tempo_pedido_recurso:EntradaDeTexto
@export var texto_entrada_tempo_recurso:EntradaDeTexto
@export var container_tarefas:Control

@onready var packedscene_tarefa_modulo = preload("res://elements/Lista de processos/Elemento_Tarefa_modulo.tscn")

var _preset_names: Array[String] = []
signal preset_updated


func _ready()->void:
	botao_aleatorizar.mouse_entered.connect(mouse_enter_random)
	botao_aleatorizar.mouse_exited.connect(mouse_leave_random)
	botao_adicionar.pressed.connect(criar_tarefa)
	botao_remover_preset.pressed.connect(_on_remover_preset_pressed)
	botao_limpar.pressed.connect(limpar_lista)
	botao_aleatorizar.pressed.connect(criar_array_aleatorio)
	container_tarefas.child_order_changed.connect(atualizar_ids)
	botao_salvar.pressed.connect(save)
	texto_entrada_nome_save.text_changed.connect(_on_nome_save_text_changed)
	build_menu_button()
	_update_remover_preset_button()

func build_menu_button() -> void:
	var popup := dropdown_presets.get_popup()
	popup.clear()

	var save_names := get_all_save_names()

	if save_names.is_empty():
		popup.add_item("Nada salvo!")
		popup.set_item_disabled(0, true)
		_preset_names = []
		return

	for i in save_names.size():
		popup.add_item(save_names[i], i)

	# Avoid connecting multiple times if build_menu_button() is called more than once
	if not popup.id_pressed.is_connected(_on_preset_selected):
		popup.id_pressed.connect(_on_preset_selected)

	# Keep the names around so we can map id -> name in the callback
	_preset_names = save_names

func get_all_save_names() -> Array[String]:
	var names: Array[String] = []
	var dir := DirAccess.open("user://")
	if dir == null:
		push_error("Could not open user:// directory")
		return names

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".save"):
			names.append(file_name.get_basename())  # strips the ".save" extension
		file_name = dir.get_next()
	dir.list_dir_end()

	names.sort()
	return names


func _on_preset_selected(id: int) -> void:
	
	var save_name :String
	if 	!_preset_names.is_empty():
		save_name = _preset_names[id]
	var dict := load_dict(save_name)
	if id < 0:
		dict.clear()
	if dict.is_empty():
		dropdown_presets.set_text("Selecionar cfg")
		_update_remover_preset_button()
		return
	set_valores_from_dict(dict)
	dropdown_presets.text = save_name
	_update_remover_preset_button()
	print("Loaded preset: ", save_name)

func _on_nome_save_text_changed(_new_text: String) -> void:
	_update_remover_preset_button()

func _update_remover_preset_button() -> void:
	var save_name := dropdown_presets.get_text().validate_filename()
	var is_valid := not save_name.is_empty() and FileAccess.file_exists("user://%s.save" % save_name)
	botao_remover_preset.disabled = not is_valid

func _on_remover_preset_pressed() -> void:
	var save_name := texto_entrada_nome_save.get_text().validate_filename()
	if save_name.is_empty():
		return

	var file_path := "user://%s.save" % save_name
	if FileAccess.file_exists(file_path):
		var err := DirAccess.remove_absolute(ProjectSettings.globalize_path(file_path))
		if err != OK:
			push_error("Failed to remove save file: %s" % error_string(err))
			return
		build_menu_button()
		_update_remover_preset_button()
	preset_updated.emit()

func set_valores_from_dict(dict:Dictionary)->void:
	limpar_lista()
	texto_entrada_nome_save.set_text(dict.get("name", ""))
	var tarefas: Dictionary = dict.get("tarefas", {})
	for i in tarefas:
		var tarefa_dict: Dictionary = tarefas[i]
		var trf = TarefaInfo.new()
		trf.nome = str_to_var(tarefa_dict.get("nome", ""))
		trf.Tempo_Processo = str_to_var(tarefa_dict.get("Tempo_Processo", ""))
		trf.Tempo_Entrada = str_to_var(tarefa_dict.get("Tempo_Entrada", ""))
		trf.Prioridade = str_to_var(tarefa_dict.get("Prioridade", ""))
		trf.TempoPedidoRecurso = str_to_var(tarefa_dict.get("TempoPedidoRecurso", ""))
		trf.TempoUsoRecurso = str_to_var(tarefa_dict.get("TempoUsoRecurso", ""))
		criar_tarefacontainer_from_tarefa(trf)

func get_valores_as_dict() -> Dictionary:
	var dict: Dictionary = {}
	dict.tarefas = {}
	for i: TarefaInfo in get_all_tarefas():
		var id = i.nome + str(i.uid)
		dict.tarefas[id] = {}  # <-- create the sub-dictionary first!
		dict.tarefas[id].nome = var_to_str(i.nome)
		dict.tarefas[id].Tempo_Processo = var_to_str(i.Tempo_Processo)
		dict.tarefas[id].Tempo_Entrada = var_to_str(i.Tempo_Entrada)
		dict.tarefas[id].Prioridade = var_to_str(i.Prioridade)
		dict.tarefas[id].TempoPedidoRecurso = var_to_str(i.TempoPedidoRecurso)
		dict.tarefas[id].TempoUsoRecurso = var_to_str(i.TempoUsoRecurso)

	return dict

func load_dict(save_name: String) -> Dictionary:
	var sanitized_name := save_name.validate_filename()
	var file_path = "user://%s.save" % sanitized_name

	if not FileAccess.file_exists(file_path):
		push_error("Save file not found: %s" % file_path)
		return {}

	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("Could not open save file: %s" % error_string(FileAccess.get_open_error()))
		return {}

	var content := file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(content)
	if parsed == null or not (parsed is Dictionary):
		push_error("Failed to parse save file")
		return {}
	preset_updated.emit()
	return parsed

func save() -> void:
	if texto_entrada_nome_save.get_text().is_empty():
		texto_entrada_nome_save.modulate = Color.RED
		return
	texto_entrada_nome_save.modulate = Color.WHITE

	var dict = get_valores_as_dict()
	var save_name = texto_entrada_nome_save.get_text().validate_filename()
	dict["name"] = save_name  # use string key, not dict.name

	var file_path = "user://%s.save" % save_name

	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not open file for writing: %s" % error_string(FileAccess.get_open_error()))
		return

	file.store_string(JSON.stringify(dict))
	file.close()
	build_menu_button()  # refresh dropdown so the new/updated preset shows up
	_update_remover_preset_button()
	preset_updated.emit()

func remover_tarefas()->void:
	for i in container_tarefas.get_children():
		if i is TarefaModulo:
			if i.get_selecionado():
				i.remove()
				await get_tree().create_timer(.1).timeout
	atualizar_ids()

func limpar_lista()->void:	
	for i in container_tarefas.get_children():
		if i is TarefaModulo:
			i.remove()
			await get_tree().create_timer(.1).timeout
	return
func atualizar_ids()->void:
	var num:int= 0
	for i in container_tarefas.get_children():
		if !i.removendo:
			num += 1
			i.id = num
			i.atualizar_titulo()
			
func get_all_tarefas()->Array[TarefaInfo]:
	var arr:Array[TarefaInfo]
	for i in container_tarefas.get_children():
		if i is TarefaModulo:
			arr.append(i.tarefa)
	return arr

static func gerar_array_aleatorio(qtd: int, gerar_recurso:bool = false) -> Array[TarefaInfo]:
	var tarefas: Array[TarefaInfo] = []
	for i in range(qtd):
		# Restrição: tempo de processo <= 6
		var tempo_processo = randi_range(1, 6)
		# Restrição: tempo de entrada <= 8
		var tempo_entrada = randi_range(0, 8)
		# Restrição: prioridade <= 5
		var prioridade = randi_range(1, 5)

		# O tempo do pedido não pode ultrapassar o tempo de processo
		var tempo_pedido_recurso = randi_range(0, tempo_processo)
		# Restrição: Tempo de uso de recurso não pode ser maior que o de processo
		var tempo_uso_recurso = randi_range(1, tempo_processo)
		if !gerar_recurso:
			tempo_pedido_recurso = 0
			tempo_uso_recurso = 0
		var trf := TarefaInfo.new()
		trf.Prioridade = prioridade
		trf.Tempo_Entrada = tempo_entrada
		trf.Tempo_Processo = tempo_processo
		trf.TempoPedidoRecurso = tempo_pedido_recurso
		trf.TempoUsoRecurso = tempo_uso_recurso
		trf.uid = i
		tarefas.append(trf)
	return tarefas

func mouse_enter_random()->void:
	if randf_range(0,1) > .9:
		text_aleatorizar.set_text("[tornado][rainbow]Aleatorizar![/rainbow][/tornado]")
func mouse_leave_random()->void:
	text_aleatorizar.set_text("Aleatorizar")

func criar_array_aleatorio() -> void:
	var qtd = int(texto_entrada_rand_count.get_entrada())
	if qtd == 0 or qtd > 8:
		texto_entrada_rand_count.set_modulate(Color.RED)
		texto_entrada_rand_count.nome_exibir = "Quantidade de processos muito baixa!"
		if qtd > 8:
			texto_entrada_rand_count.nome_exibir = "Quantidade de processos muito alta!"
		return
	texto_entrada_rand_count.nome_exibir = "Quantidade de processos"
	texto_entrada_rand_count.set_modulate(Color.WHITE)
	_on_preset_selected(-1)
	await limpar_lista()

	var tarefas := gerar_array_aleatorio(qtd,true)
	for trf in tarefas:
		criar_tarefacontainer_from_tarefa(trf)
func validarCampos() -> bool:
	var correto:bool = true
	for i in [texto_entrada_prioridade,texto_entrada_inicio,texto_entrada_tempo_processo,texto_entrada_tempo_pedido_recurso, texto_entrada_tempo_recurso]:
		i.modulate = Color.WHITE
		if i.get_entrada() < 0:
			i.modulate = Color.RED
			correto = false
	if int(texto_entrada_tempo_processo.get_entrada()) < 1:
		texto_entrada_tempo_processo.modulate = Color.RED
		correto = false
	if int(texto_entrada_tempo_pedido_recurso.get_entrada()) > 0 and int(texto_entrada_tempo_recurso.get_entrada() < 1):
		texto_entrada_tempo_recurso.modulate = Color.RED
		correto = false
	if int(texto_entrada_tempo_recurso.get_entrada()) > int(texto_entrada_tempo_processo.get_entrada()):
		texto_entrada_tempo_recurso.modulate = Color.RED
		correto = false
	
	return correto
	pass


func criar_tarefacontainer_from_tarefa(trf:TarefaInfo)->void:
	var instancia = packedscene_tarefa_modulo.instantiate()
	instancia.tarefa = trf
	container_tarefas.add_child(instancia)
	atualizar_ids()
func criar_tarefa(
	prioridade: int = int(texto_entrada_prioridade.get_entrada()),
	tempo_entrada: int = int(texto_entrada_inicio.get_entrada()),
	tempo_processo: int = int(texto_entrada_tempo_processo.get_entrada()),
	tempo_pedido_recurso: int = int(texto_entrada_tempo_pedido_recurso.get_entrada()),
	tempo_uso_recurso: int = int(texto_entrada_tempo_recurso.get_entrada()),
	ignorar_validacao:bool = false) -> void:
	if !validarCampos() and !ignorar_validacao:
		return
	
	var instancia = packedscene_tarefa_modulo.instantiate()
	var recurso = TarefaInfo.new()

	recurso.Prioridade = prioridade
	recurso.Tempo_Entrada = tempo_entrada
	recurso.Tempo_Processo = tempo_processo
	recurso.TempoPedidoRecurso = tempo_pedido_recurso
	recurso.TempoUsoRecurso = tempo_uso_recurso

	instancia.tarefa = recurso
	instancia.id = container_tarefas.get_children().size() + 1

	container_tarefas.add_child(instancia)
	atualizar_ids()
