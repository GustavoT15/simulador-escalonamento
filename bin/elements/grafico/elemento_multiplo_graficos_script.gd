class_name TabelaMultiploGrafico extends PanelContainer

@export var title:RichTextLabel
@export var container:GridContainer
@export var entrada_quantum:EntradaDeTexto
@export var entrada_custo_de_troca:EntradaDeTexto
@export var entrada_envelhecimento:EntradaDeTexto
@export var entrada_delay:EntradaDeTexto
@export var butao_heranca_p:Button
@export var butao_teto_p:Button
@export var painel_log:LogPanel
@export var tabela_resultados:TabelaResultados
@export var lista:VBoxContainer
@export var gerar_50:CheckBox
var graficos : Array[TabelaGrafico]

signal finalizado

func _ready()->void:
	var carregado = load("res://elements/grafico/Elemento_Grafico_Mini.tscn")
	for i in container.get_children():
		i.queue_free()
	gerar_50.pressed.connect(on_50_toggle)
	#var text = RichTextLabel.new()
	for i in TabelaGrafico.ESCALONADOR:
		var instancia:TabelaGrafico = carregado.instantiate()
		instancia.painel_log = painel_log
		container.add_child(instancia)
		graficos.append(instancia)
		# FIX: assigning tipo_escalonador directly skips update_tipo(), which is
		# what actually configures the per-scheduler UI state (enabling the
		# quantum field for FIRSTCOME, showing herança/teto for PREEMPTIVA,
		# etc.). Without this, each dynamically created grafico was left in
		# whatever default state the scene happened to have, which could make
		# validar_campos() behave inconsistently per scheduler type.
		instancia.update_tipo(TabelaGrafico.ESCALONADOR[i])
	#add_child(text)
	build_lista()

func build_lista() -> void:
	for i in lista.get_children():
		i.queue_free()

	var save_names := get_all_save_names()

	if save_names.is_empty():
		var label := Label.new()
		label.text = "No saves found"
		label.modulate = Color(1, 1, 1, 0.5)
		lista.add_child(label)
		return

	for save_name in save_names:
		var checkbox := CheckBox.new()
		checkbox.text = save_name
		lista.add_child(checkbox)

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
			names.append(file_name.get_basename())
		file_name = dir.get_next()
	dir.list_dir_end()

	names.sort()
	return names

func validar_campos()->bool:
	var correto:bool = true

	for i in [
		entrada_custo_de_troca,
		entrada_delay,
		entrada_envelhecimento,
		entrada_quantum
	]:
		i.modulate = Color.WHITE

		if i.get_entrada() < 0 and i != entrada_delay:
			i.modulate = Color.RED
			correto = false

	if (
		int(entrada_quantum.get_entrada()) > 0
		and int(entrada_custo_de_troca.get_entrada())
			>= int(entrada_quantum.get_entrada())
	):
		entrada_custo_de_troca.modulate = Color.RED
		entrada_quantum.modulate = Color.RED
		correto = false

	return correto


func on_50_toggle(_n=null)->void:
	lista.visible = !gerar_50.is_pressed()
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

	return parsed

	

func dict_to_tarefas(dict: Dictionary) -> Array[TarefaInfo]:
	var arr: Array[TarefaInfo] = []
	var tarefas: Dictionary = dict.get("tarefas", {})
	var id = 0
	for i in tarefas:
		var tarefa_dict: Dictionary = tarefas[i]
		var trf := TarefaInfo.new()
		trf.uid =  id
		trf.nome = str_to_var(tarefa_dict.get("nome", ""))
		trf.Tempo_Processo = str_to_var(tarefa_dict.get("Tempo_Processo", ""))
		trf.Tempo_Entrada = str_to_var(tarefa_dict.get("Tempo_Entrada", ""))
		trf.Prioridade = str_to_var(tarefa_dict.get("Prioridade", ""))
		trf.TempoPedidoRecurso = str_to_var(tarefa_dict.get("TempoPedidoRecurso", ""))
		trf.TempoUsoRecurso = str_to_var(tarefa_dict.get("TempoUsoRecurso", ""))
		id +=1
		arr.append(trf)
	return arr

func get_all_scenarios() -> Dictionary:
	var dict: Dictionary = {}
	for i in lista.get_children():
		if i is CheckBox:
			if i.is_pressed():
				var loaded := load_dict(i.text)
				if loaded.is_empty():
					continue
				dict[i.text] = dict_to_tarefas(loaded)
	return dict

func start(n_tarefa: Array[TarefaInfo],generate:bool = gerar_50.is_pressed()) -> void:
	if !validar_campos():
		await get_tree().process_frame
		finalizado.emit()
		return
	tabela_resultados.clear()
	tabela_resultados.HEADERS = [
		"Id","Nome","Media Tempo Execução","Media Tempo Processo","Media Tempo Espera","Media Tempo Primeira Execução"
	]
	tabela_resultados._build_header()
	tabela_resultados._build_scroll_body()
	var scenarios := get_all_scenarios()
	graficos.map(func(x): 
		x.mediaTotalTempoProcesso = 0
		x.mediaTotalTempoExecucao = 0
		x.mediaTotalTempoEspera = 0
		x.mediaTotalTempoPrimeiraExecucao = 0)

	if generate:
		scenarios.clear()
		for i in 50:
			scenarios[i] = TabelaDeProcessos.gerar_array_aleatorio(5)
	var count = 0
	for scenario_name in scenarios:
		var tarefas: Array[TarefaInfo] = scenarios[scenario_name]
		count+=1
		for i in graficos:
			title.set_text ("Tarefa : %s/%s"%[count,scenarios.keys().size()])
			i.entrada_custo_de_troca.entrada_de_texto.value = entrada_custo_de_troca.entrada_de_texto.value
			# NOTE: still hardcoded to 0 here rather than forwarding
			# entrada_delay - left as-is since a 0-delay batch run is
			# probably intentional for 50 scenarios, but flagging it: this
			# means the parent panel's own delay field has no effect on the
			# batch run at all right now.
			i.entrada_delay.entrada_de_texto.value = 0.00# entrada_delay.entrada_de_texto.value
			i.entrada_envelhecimento.entrada_de_texto.value = entrada_envelhecimento.entrada_de_texto.value
			i.entrada_quantum.entrada_de_texto.value = entrada_quantum.entrada_de_texto.value
			##Ponto inicial, aqui vamos iniciar o processamento de todas as tabelas graficos
			i.start(tarefas) # <--- Chame essa função! (não aguardado de propósito, roda em paralelo)

		# FIX: the mediaTotal* accumulation used to happen immediately after
		# firing i.start(tarefas), which is NOT awaited - so it was reading
		# i.mediaTempoProcesso etc. before this scenario's simulation had
		# produced them (getting either the previous scenario's leftover
		# numbers, or 0 on the very first scenario). It now runs only after
		# we've confirmed, via get_finalizado()/finalizado, that this
		# scenario's run for this specific grafico has truly finished.
		for i in graficos:
			if not i.get_finalizado():
				await i.finalizado
			i.mediaTotalTempoProcesso += i.mediaTempoProcesso
			i.mediaTotalTempoExecucao += i.mediaTempoExecucao
			i.mediaTotalTempoEspera += i.mediaTempoEspera
			i.mediaTotalTempoPrimeiraExecucao += i.mediaTempoPrimeiraExecucao
	for i in graficos:
		# FIX: mediaTotal* are declared as int (default 0), so this used to be
		# integer division and truncated the average instead of computing it
		# properly (e.g. 7/2 becoming 3 instead of 3.5). Casting to float
		# before dividing fixes this without needing to change the exported
		# variable types.
		i.mediaTotalTempoProcesso = float(i.mediaTotalTempoProcesso) / scenarios.size()
		i.mediaTotalTempoExecucao = float(i.mediaTotalTempoExecucao) / scenarios.size()
		i.mediaTotalTempoEspera = float(i.mediaTotalTempoEspera) / scenarios.size()
		i.mediaTotalTempoPrimeiraExecucao = float(i.mediaTotalTempoPrimeiraExecucao) / scenarios.size()
		tabela_resultados.add_tuple(i.tipo_escalonador, TabelaGrafico.get_name_escalonador(i.tipo_escalonador) ,i.mediaTotalTempoExecucao, i.mediaTotalTempoProcesso, i.mediaTotalTempoEspera, i.mediaTotalTempoPrimeiraExecucao)
	



		
		##Melhor trocar por um await que espera certinho todos terminarem, mas fica a teu criterio.
		##Aqui você também pode retirar os dados finais de todas a tabelas, só rodar outro loop aqui coletando tudo
		
	## 	For i in graficos:
	##		i.retornar_resultados()
	finalizado.emit()
