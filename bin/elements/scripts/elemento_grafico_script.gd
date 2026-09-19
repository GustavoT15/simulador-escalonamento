class_name TabelaGrafico extends PanelContainer

## Emitted once, at the very end of start(), after the tick loop has fully
## finished AND the average-time results have been computed and written to
## tabela_resultados.
signal finalizado

const RECURSO_LIVRE:int = -1
const MAX_TICKS_SEM_PROGRESSO:int = 5

@export var tempo:float = .25
@export var tarefas:Array[TarefaInfo]

@export var cena:PackedScene
@export var counter:PackedScene
@export var troca:PackedScene
@export var label_display:RichTextLabel

@export var container:VBoxContainer
@export var painel_log:LogPanel
@export var tipo_escalonador:ESCALONADOR
@export var elemento_tarefa_id:PackedScene

@export var dropdown:MenuButton
@export var entrada_quantum:EntradaDeTexto
@export var entrada_custo_de_troca:EntradaDeTexto
@export var entrada_envelhecimento:EntradaDeTexto
@export var entrada_delay:EntradaDeTexto
@export var butao_heranca_p:Button
@export var butao_teto_p:Button
@export var quantumCounter:int = 0
@export var tarefaAnteriorUid:int = -1

var recurso:int = RECURSO_LIVRE
var ticks_sem_progresso:int = 0

@export var ultimaTarefaExecutadaUid = 0
@export var filaRoundRobin = []
@export var tabela_resultados:TabelaResultados
@export var prioridadeTeto = 0

@export var mediaTempoProcesso = 0
@export var mediaTempoExecucao = 0
@export var mediaTempoEspera = 0
@export var mediaTempoPrimeiraExecucao = 0

@export var mediaTotalTempoProcesso = 0
@export var mediaTotalTempoExecucao = 0
@export var mediaTotalTempoEspera = 0
@export var mediaTotalTempoPrimeiraExecucao = 0

@onready var separator = preload("res://elements/grafico/elemento_grafico_tupla.tscn")


func on_button_toggled(_pressed: bool):
	print(
		"toggled! heranca=",
		butao_heranca_p.is_pressed(),
		" teto=",
		butao_teto_p.is_pressed()
	)

	butao_heranca_p.modulate = Color.BLUE if butao_heranca_p.is_pressed() else Color.WHITE
	butao_teto_p.modulate = Color.BLUE if butao_teto_p.is_pressed() else Color.WHITE


# --- Funções que métodos externos podem chamar ---

func get_botao_ativo() -> Button:
	return butao_heranca_p.button_group.get_pressed_button()


func is_heranca_selecionado() -> bool:
	return butao_heranca_p.is_pressed()


func is_teto_selecionado() -> bool:
	return butao_teto_p.is_pressed()


func is_nenhum_selecionado() -> bool:
	return !is_instance_valid(butao_heranca_p.button_group.get_pressed_button())


var tupla_troca:TuplaTroca
var tempo_atual:int = 0
var tuplas_ativas:Array[GraficoTupla]


enum ESCALONADOR{
	FIRSTCOME=0,
	SHORTESTJOB=1,
	SHORTESTTIME=2,
	ROUNDROBIN=3,
	COOPERATIVA=4,
	PREEMPTIVA=5
}


func _ready()->void:
	butao_heranca_p.toggled.connect(on_button_toggled)
	butao_teto_p.toggled.connect(on_button_toggled)

	for i in ESCALONADOR.values():
		var tipo: ESCALONADOR = i as ESCALONADOR
		dropdown.get_popup().add_item(get_name_escalonador(tipo),i)

	dropdown.get_popup().id_pressed.connect(update_tipo)
	dropdown.text = get_name_escalonador(tipo_escalonador)


func update_tipo(id:int)->void:
	var tipo: ESCALONADOR = id as ESCALONADOR
	tipo_escalonador = tipo
	dropdown.text = get_name_escalonador(tipo)

	butao_heranca_p.visible = false
	butao_teto_p.visible = false

	match tipo:
		ESCALONADOR.FIRSTCOME:
			entrada_quantum.set_enabled(true)

		ESCALONADOR.SHORTESTJOB:
			pass

		ESCALONADOR.SHORTESTTIME:
			pass

		ESCALONADOR.ROUNDROBIN:
			pass

		ESCALONADOR.COOPERATIVA:
			pass

		ESCALONADOR.PREEMPTIVA:
			butao_heranca_p.visible = true
			butao_teto_p.visible = true


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


func adicionar_cena(cena:PackedScene,msg:String,cor:Color)->void:
	var instancia = cena.instantiate()
	instancia.mensagem = msg
	instancia.cor = cor
	%uid_container.call_deferred("add_child",(instancia))


static func get_name_escalonador(tipo: ESCALONADOR) -> String:
	match tipo:
		ESCALONADOR.FIRSTCOME:
			return "First-Come, First-Served"

		ESCALONADOR.SHORTESTJOB:
			return "Shortest Job First"

		ESCALONADOR.SHORTESTTIME:
			return "Shortest Remaining Time First"

		ESCALONADOR.ROUNDROBIN:
			return "Round-Robin"

		ESCALONADOR.COOPERATIVA:
			return "Prioridade Cooperativa"

		ESCALONADOR.PREEMPTIVA:
			return "Prioridade Preemptiva"

	return "Desconhecido"


func start(n_tarefa:Array[TarefaInfo])->void:
	if !validar_campos():
		push_warning(
			"TabelaGrafico (%s): validação de campos falhou, execução ignorada."
			% get_name_escalonador(tipo_escalonador)
		)

		finalizado.emit()
		return
	var arr:Array[TarefaInfo]
	for i in n_tarefa:
		arr.append(i.duplicate())

	prioridadeTeto = 0

	if is_instance_valid(tabela_resultados):
		tabela_resultados.clear()

	painel_log.clear()

	tempo = float(entrada_delay.get_entrada())

	# Reset completo da simulação.
	tuplas_ativas.clear()
	filaRoundRobin = []
	tarefaAnteriorUid = -1
	quantumCounter = 0

	# Resource is always reset between simulations.
	recurso = RECURSO_LIVRE

	# Reset watchdog.
	ticks_sem_progresso = 0

	for i in container.get_children():
		i.queue_free()

	tempo_atual = 0
	tarefas = arr

	for i in %uid_container.get_children():
		i.queue_free()

	## Cria Troca
	tupla_troca = troca.instantiate()
	tupla_troca.tempo_troca = int(entrada_custo_de_troca.get_entrada())
	tupla_troca.ticks_ativo = 0

	container.add_child(tupla_troca)
	tuplas_ativas.append(tupla_troca)

	adicionar_cena(elemento_tarefa_id,"Troca",Color.WHITE)


	## Cria tarefas
	for i in tarefas:
		i.ReiniciarDados()
		i.Executou_Antes = false
		i.PrioridadeOriginal = i.Prioridade

		var instancia:GraficoTupla = cena.instantiate()

		instancia.tarefa = i
		instancia.tabela = self

		container.add_child(instancia)
		tuplas_ativas.append(instancia)

		adicionar_cena(
			elemento_tarefa_id,
			"UID:%s" % [i.uid],
			Color.WHITE
		)


	## Cria Counter
	var inst = counter.instantiate()
	container.add_child(inst)
	tuplas_ativas.append(inst)

	processo_id_atual += 1

	if tipo_escalonador == ESCALONADOR.PREEMPTIVA:
		if is_teto_selecionado():
			var tuplasDisputando = tuplas_ativas.filter(
				func(x:GraficoTupla):
					return (
						!(x is TuplaCounter)
						and !(x is TuplaTroca)
						and !x.get_finalizado()
						and !x.estaSuspenso()
						and x.tarefa.TempoUsoRecurso > 0
					)
			)

			tuplasDisputando.sort_custom(
				func(x,y):
					return x.tarefa.Prioridade > y.tarefa.Prioridade
			)

			if !tuplasDisputando.is_empty():
				prioridadeTeto = tuplasDisputando.get(0).tarefa.Prioridade

	await tick(processo_id_atual)

	mediaTempoProcesso = 0
	mediaTempoExecucao = 0
	mediaTempoEspera = 0
	mediaTempoPrimeiraExecucao = 0

	for i in tarefas:
		mediaTempoProcesso += i.Tempo_Processo
		mediaTempoExecucao += i.Tempo_Execucao
		mediaTempoEspera += i.Tempo_Espera
		mediaTempoPrimeiraExecucao += i.Tempo_Primeira_Execucao

		if is_instance_valid(tabela_resultados):
			tabela_resultados.add_tuple(
				i.uid,
				i.nome,
				i.Tempo_Execucao,
				i.Tempo_Processo,
				i.Tempo_Espera,
				i.Tempo_Primeira_Execucao
			)

	if len(tarefas) > 0:
		mediaTempoProcesso /= len(tarefas)
		mediaTempoExecucao /= len(tarefas)
		mediaTempoEspera /= len(tarefas)
		mediaTempoPrimeiraExecucao /= len(tarefas)

		if is_instance_valid(tabela_resultados):
			tabela_resultados.add_tuple(
				0,
				"Média",
				mediaTempoExecucao,
				mediaTempoProcesso,
				mediaTempoEspera,
				mediaTempoPrimeiraExecucao
			)

	finalizado.emit()


func update_display()->void:
	if !get_finalizado():
		label_display.set_text(
			"Processando...\nTick Atual : %s\nEscalonador : %s"
			% [
				tempo_atual,
				get_name_escalonador(tipo_escalonador)
			]
		)
	else:
		label_display.set_text(
			"FINALIZADO!\nTicks usados nesse processo : %s\nEscalonador : %s"
			% [
				tempo_atual,
				get_name_escalonador(tipo_escalonador)
			]
		)


func get_finalizado()->bool:
	# The watchdog can terminate a genuinely stuck simulation.
	if ticks_sem_progresso >= MAX_TICKS_SEM_PROGRESSO:
		return true

	for i in tuplas_ativas:
		if i is GraficoTupla and !(i is TuplaCounter or i is TuplaTroca):
			if !i.get_finalizado():
				return false

	return true


var processo_id_atual:int = 0


# Returns true if there is at least one unfinished task that has already
# arrived and is not blocked by the resource.
#
# This is intentionally different from simply checking for unfinished tasks.
# Tasks with Tempo_Entrada in the future are normal idle time and must NOT
# trigger the 5-tick watchdog.
func existe_tarefa_executavel()->bool:
	for x in tuplas_ativas:
		if x is TuplaCounter or x is TuplaTroca:
			continue

		if x.get_finalizado():
			continue

		if x.tarefa.Tempo_Entrada > tempo_atual:
			continue

		if !x.estaSuspenso():
			return true

	return false



func existe_tarefa_chegou()->bool:
	for x in tuplas_ativas:
		if x is TuplaCounter or x is TuplaTroca:
			continue

		if x.get_finalizado():
			continue

		if x.tarefa.Tempo_Entrada <= tempo_atual:
			return true

	return false


func tick(processo_id:int = 0)->void:
	while processo_id == processo_id_atual:

		# Snapshot of every task's progress before this tick.
		var estado_antes:Array = []

		for i in tuplas_ativas:
			if i is GraficoTupla:
				estado_antes.append({
					"tupla": i,
					"ticks_ativo": i.ticks_ativo,
					"ticks_recurso": i.ticks_recurso
				})

		match tipo_escalonador:
			ESCALONADOR.FIRSTCOME:
				processo_first_come()

			ESCALONADOR.SHORTESTJOB:
				processo_shortest_job()

			ESCALONADOR.SHORTESTTIME:
				processo_shortest_remaining_time()

			ESCALONADOR.ROUNDROBIN:
				processo_round_robin()

			ESCALONADOR.COOPERATIVA:
				processo_cooperativa()

			ESCALONADOR.PREEMPTIVA:
				processo_preemptiva()


		# Determine whether at least one task actually progressed.
		var houve_progresso:bool = false

		for estado in estado_antes:
			var tupla:GraficoTupla = estado["tupla"]

			if (
				tupla.ticks_ativo != estado["ticks_ativo"]
				or tupla.ticks_recurso != estado["ticks_recurso"]
			):
				houve_progresso = true
				break


		if houve_progresso:
			ticks_sem_progresso = 0

		else:

			if existe_tarefa_chegou():
				ticks_sem_progresso += 1
			else:
				ticks_sem_progresso = 0


		tempo_atual += 1
		update_display()


		if get_finalizado():
			return


		# Safety net.
		if ticks_sem_progresso >= MAX_TICKS_SEM_PROGRESSO:
			push_warning(
				"TabelaGrafico (%s): simulação interrompida após %d ticks sem progresso. "
				% [
					get_name_escalonador(tipo_escalonador),
					MAX_TICKS_SEM_PROGRESSO
				]
			)

			# Clear a stale resource owner before ending the simulation.
			# This prevents a terminated run from carrying resource state into
			# another run.
			recurso = RECURSO_LIVRE

			finalizado.emit()
			return


		if tempo > 0:
			await get_tree().create_timer(tempo).timeout
		else:
			await get_tree().process_frame


func processo_first_come() -> void:
	var tupla:Array[GraficoTupla] = []

	for x in tuplas_ativas:
		if x is TuplaCounter or x is TuplaTroca:
			continue

		if x.tarefa.Tempo_Entrada > tempo_atual:
			continue

		if x.get_finalizado():
			continue

		# A task holding the resource must remain eligible.
		#
		# estaSuspenso() returns false for the task whose UID is stored in
		# recurso, so this also protects the resource holder from being
		# accidentally removed from the FCFS queue.
		if x.estaSuspenso():
			continue

		tupla.append(x)


	# FCFS:
	# Earlier arrival first.
	# UID is only used as the deterministic tie-breaker.
	tupla.sort_custom(
		func(x:GraficoTupla,y:GraficoTupla):
			if x.tarefa.Tempo_Entrada == y.tarefa.Tempo_Entrada:
				return x.tarefa.uid < y.tarefa.uid

			return x.tarefa.Tempo_Entrada < y.tarefa.Tempo_Entrada
	)


	if tupla.is_empty():
		mecanismo_geral(null)
	else:
		var proxima:GraficoTupla = tupla.get(0)

		gerenciarRecurso(proxima)
		mecanismo_geral(proxima.tarefa)


func processo_shortest_job() -> void:
	var em_Execucao = null
	var tarefa = null

	var tupla = tuplas_ativas.filter(
		func(x:GraficoTupla):
			return (
				!(x is TuplaCounter)
				and !(x is TuplaTroca)
				and x.tarefa.Tempo_Entrada <= tempo_atual
				and !x.get_finalizado()
				and !x.estaSuspenso()
			)
	)

	var index_Exec = tupla.find_custom(
		func(x):
			if x != null:
				return x.tarefa.Executou_Antes == true

			return false
	)

	if index_Exec >= 0:
		em_Execucao = tupla.get(index_Exec)
		gerenciarRecurso(em_Execucao)
		tarefa = em_Execucao.tarefa

	else:
		tupla.sort_custom(
			func(x,y):
				if x.tarefa.Executou_Antes != y.tarefa.Executou_Antes:
					return x.tarefa.Executou_Antes > y.tarefa.Executou_Antes

				return x.tarefa.Tempo_Processo < y.tarefa.Tempo_Processo
		)

		if !tupla.is_empty():
			gerenciarRecurso(tupla.get(0))
			tarefa = tupla.get(0).tarefa

	mecanismo_geral(tarefa)


func processo_shortest_remaining_time()->void:
	var tarefa = null

	var tupla = tuplas_ativas.filter(
		func(x:GraficoTupla):
			return (
				!(x is TuplaCounter)
				and !(x is TuplaTroca)
				and x.tarefa.Tempo_Entrada <= tempo_atual
				and !x.get_finalizado()
				and !x.estaSuspenso()
			)
	)

	tupla.sort_custom(
		func(x,y):
			return (
				x.tarefa.Tempo_Processo - x.ticks_ativo
				<
				y.tarefa.Tempo_Processo - y.ticks_ativo
			)
	)

	if !tupla.is_empty():
		gerenciarRecurso(tupla.get(0))
		tarefa = tupla.get(0).tarefa

	mecanismo_geral(tarefa)


func processo_round_robin() -> void:
	var tarefa = null

	var tupla = tuplas_ativas.filter(
		func(x:GraficoTupla):
			return (
				!(x is TuplaCounter)
				and !(x is TuplaTroca)
				and x not in filaRoundRobin
				and x.tarefa.Tempo_Entrada <= tempo_atual
				and !x.get_finalizado()
				and !x.estaSuspenso()
			)
	)

	tupla.sort_custom(
		func(x,y):
			return x.tarefa.uid < y.tarefa.uid
	)

	filaRoundRobin.append_array(tupla)

	if len(filaRoundRobin) >= 1:

		filaRoundRobin = filaRoundRobin.filter(
			func(x:GraficoTupla):
				return !x.estaSuspenso()
		)

		if filaRoundRobin.is_empty():
			mecanismo_geral(tarefa)
			return

		if filaRoundRobin.get(0).get_finalizado():
			quantumCounter = 0
			filaRoundRobin.pop_front()

		if filaRoundRobin.is_empty():
			mecanismo_geral(tarefa)
			return

		if int(entrada_quantum.get_entrada()) > 0:

			if quantumCounter <= (
				int(entrada_quantum.get_entrada())
				- int(entrada_custo_de_troca.get_entrada())
			):
				quantumCounter += 1
				tarefa = filaRoundRobin.get(0).tarefa

			elif quantumCounter > (
				int(entrada_quantum.get_entrada())
				- int(entrada_custo_de_troca.get_entrada())
			):
				filaRoundRobin.append(filaRoundRobin.pop_front())

				if filaRoundRobin.front() != null:
					tarefa = filaRoundRobin.front().tarefa

				quantumCounter = 0

		else:
			tarefa = filaRoundRobin.get(0).tarefa

		gerenciarRecurso(filaRoundRobin.get(0))

	mecanismo_geral(tarefa)


func processo_cooperativa() -> void:
	var em_Execucao = null
	var tarefa = null

	var tupla = tuplas_ativas.filter(
		func(x:GraficoTupla):
			return (
				!(x is TuplaCounter)
				and !(x is TuplaTroca)
				and x.tarefa.Tempo_Entrada <= tempo_atual
				and !x.get_finalizado()
				and !x.estaSuspenso()
			)
	)

	var index_Exec = tupla.find_custom(
		func(x):
			if x != null:
				return x.tarefa.Executou_Antes == true

			return false
	)

	if index_Exec >= 0:
		em_Execucao = tupla.get(index_Exec)
		gerenciarRecurso(em_Execucao)
		tarefa = em_Execucao.tarefa

	else:
		tupla.sort_custom(
			func(x,y):
				if x.tarefa.Executou_Antes != y.tarefa.Executou_Antes:
					return x.tarefa.Executou_Antes > y.tarefa.Executou_Antes

				return x.tarefa.Prioridade > y.tarefa.Prioridade
		)

		tupla = tupla.slice(0,1)

		tupla.sort_custom(
			func(x,y):
				return x.tarefa.uid < y.tarefa.uid
		)

		if !tupla.is_empty():
			gerenciarRecurso(tupla.get(0))
			tarefa = tupla.get(0).tarefa

	mecanismo_geral(tarefa)


func processo_preemptiva() -> void:
	var tarefa = null

	var tupla = tuplas_ativas.filter(
		func(x:GraficoTupla):
			return (
				!(x is TuplaCounter)
				and !(x is TuplaTroca)
				and x.tarefa.Tempo_Entrada <= tempo_atual
				and !x.get_finalizado()
				and !x.estaSuspenso()
			)
	)

	if is_heranca_selecionado():

		var tuplasDisputando = tuplas_ativas.filter(
			func(x:GraficoTupla):
				return (
					!(x is TuplaCounter)
					and !(x is TuplaTroca)
					and x.tarefa.Tempo_Entrada <= tempo_atual
					and !x.get_finalizado()
					and (
						x.estaSuspenso()
						or x.tarefa.uid == recurso
					)
				)
		)

		var recurso_index = tuplas_ativas.find_custom(
			func(x):
				return (
					!(x is TuplaCounter)
					and !(x is TuplaTroca)
					and x.tarefa.uid == recurso
				)
		)

		var tuplaComRecurso:GraficoTupla = null

		if recurso_index >= 0:
			tuplaComRecurso = tuplas_ativas.get(recurso_index)

		if (
			tuplaComRecurso != null
			and !tuplasDisputando.is_empty()
		):
			tuplasDisputando.sort_custom(
				func(x,y):
					return x.tarefa.Prioridade > y.tarefa.Prioridade
			)

			tuplaComRecurso.tarefa.Prioridade = (
				tuplasDisputando.get(0).tarefa.Prioridade
			)


	tupla.sort_custom(
		func(x,y):
			return x.tarefa.Prioridade > y.tarefa.Prioridade
	)

	tupla = tupla.slice(0,1)

	tupla.sort_custom(
		func(x,y):
			if x.tarefa.Prioridade == y.tarefa.Prioridade:
				return x.tarefa.uid < y.tarefa.uid

			return x.tarefa.Prioridade > y.tarefa.Prioridade
	)

	if !tupla.is_empty():
		gerenciarRecurso(tupla.get(0))
		tarefa = tupla.get(0).tarefa

	mecanismo_geral(tarefa)


func mecanismo_geral(tarefaAtiva:TarefaInfo) -> void:
	var tuplaAnterior:GraficoTupla

	for x in tuplas_ativas:
		if (
			!(x is TuplaCounter)
			and !(x is TuplaTroca)
			and x.tarefa.uid == tarefaAnteriorUid
		):
			tuplaAnterior = x


	for i in tuplas_ativas:

		if i is TuplaCounter:
			i.step(tempo_atual,false)


		elif i is TuplaTroca:

			if (
				tarefaAtiva != null
				and tarefaAtiva.uid != tarefaAnteriorUid
				and i.get_finalizado()
			):
				i.ticks_ativo = 0

			if (
				int(entrada_custo_de_troca.get_entrada()) > 0
				and tarefaAtiva != null
				and tarefaAtiva.uid != tarefaAnteriorUid
				and !i.get_finalizado()
			):
				i.step(tempo_atual, true)
			else:
				i.step(tempo_atual,false)


		elif i is GraficoTupla:

			if (
				int(entrada_envelhecimento.get_entrada()) > 0
				and tarefaAtiva != null
				and tarefaAtiva.uid != i.tarefa.uid
			):
				i.tarefa.Envelhecer(
					int(entrada_envelhecimento.get_entrada())
				)


			if (
				is_instance_valid(tarefaAtiva)
				and i.tarefa.uid == tarefaAtiva.uid
				and tupla_troca.get_finalizado()
			):
				tarefaAnteriorUid = tarefaAtiva.uid


			if (
				is_instance_valid(tarefaAtiva)
				and i.tarefa.uid == tarefaAtiva.uid
				and !i.get_finalizado()
				and tupla_troca.get_finalizado()
			):
				i.step(tempo_atual, true)

				if !i.tarefa.Executou_Antes:
					i.tarefa.Tempo_Primeira_Execucao = (
						tempo_atual - i.tarefa.Tempo_Entrada
					)

					i.tarefa.Executou_Antes = true

				painel_log.queue_message(
					"Passo %s : UID %s Escolhido para execução"
					% [tempo_atual, i.tarefa.uid]
				)

				if i.get_finalizado():
					i.tarefa.ReiniciarPrioridade()

			else:
				i.step(tempo_atual, false)


	# Release the resource AFTER the selected task has taken its step.
	#
	# This is important because ticks_recurso is updated inside GraficoTupla.step().
	var tarefaUsandoRecurso = get_tarefa_usando_recurso()

	if (
		tarefaUsandoRecurso != null
		and tarefaUsandoRecurso.ticks_recurso
			>= tarefaUsandoRecurso.tarefa.TempoUsoRecurso
	):
		tarefaUsandoRecurso.tarefa.ReiniciarPrioridade()
		liberarRecurso()


func get_tarefa_usando_recurso()->GraficoTupla:
	# -1 means "resource is free".
	if recurso == RECURSO_LIVRE:
		return null

	for x in tuplas_ativas:
		if (
			!(x is TuplaCounter)
			and !(x is TuplaTroca)
			and x.tarefa.uid == recurso
		):
			return x

	# Defensive recovery:
	# If recurso refers to a task that no longer exists, don't leave the
	# simulation permanently locked.
	recurso = RECURSO_LIVRE
	return null


func liberarRecurso() -> void:
	recurso = RECURSO_LIVRE


func getRecursoId() -> int:
	return recurso


func gerenciarRecurso(tupla:GraficoTupla) -> void:
	if tupla == null:
		return

	if (
		tupla.tarefa.TempoUsoRecurso > 0
		and tupla.tarefa.TempoPedidoRecurso <= tupla.ticks_ativo
		and tupla.ticks_recurso < tupla.tarefa.TempoUsoRecurso
		and !tupla.tarefa.PediuRecurso
	):
		tupla.tarefa.PediuRecurso = true


	# -1 is the ONLY value that means "resource is free".
	#
	# Therefore UID 0 can safely own the resource.
	if (
		recurso == RECURSO_LIVRE
		and tupla.tarefa.PediuRecurso
		and tupla.ticks_recurso < tupla.tarefa.TempoUsoRecurso
	):
		recurso = tupla.tarefa.uid

		if is_teto_selecionado():
			tupla.tarefa.Prioridade = prioridadeTeto
