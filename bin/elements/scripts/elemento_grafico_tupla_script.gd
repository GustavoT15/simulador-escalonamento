class_name GraficoTupla extends HBoxContainer


@export var tempo:int = 0
@export var tarefa:TarefaInfo
@export var tabela:TabelaGrafico

@export var elemento_tarefa_ativa:PackedScene
@export var elemento_tarefa:PackedScene
@export var elemento_vazio:PackedScene
@export var elemento_suspenso:PackedScene

@export var ticks_ativo:int = 0
@export var ticks_recurso:int = 0

var cor:Color


func _ready() -> void:

	cor = [
		Color.BLUE,
		Color.AQUA,
		Color.INDIGO,
		Color.VIOLET,
		Color.RED,
		Color.PALE_VIOLET_RED,
		Color.CRIMSON,
		Color.DEEP_PINK,
		Color.PINK
	].pick_random()


	if !is_instance_valid(tarefa):
		queue_free()
		return


func adicionar_cena(
	cena:PackedScene,
	msg:String,
	cor:Color
) -> void:

	var instancia = cena.instantiate()

	instancia.mensagem = msg
	instancia.cor = cor

	add_child(instancia)


func get_finalizado() -> bool:

	return (
		ticks_ativo >= tarefa.Tempo_Processo
		and
		ticks_recurso >= tarefa.TempoUsoRecurso
	)


func step(
	tempo_atual:int = 0,
	ativo:bool = false
) -> void:

	tempo = tempo_atual

	var delta = (
		tarefa.Tempo_Processo
		-
		ticks_ativo
	)


	if (
		tempo >= tarefa.Tempo_Entrada
		and
		!get_finalizado()
	):

		if ativo and !estaSuspenso():

			if tarefa.uid == tabela.getRecursoId():

				# IMPORTANT:
				# The resource is consumed only while the task actually
				# owns it.

				if (
					ticks_ativo >= tarefa.TempoPedidoRecurso
					and
					ticks_recurso < tarefa.TempoUsoRecurso
				):

					ticks_recurso += 1

					adicionar_cena(
						elemento_tarefa_ativa,
						str(
							tarefa.TempoUsoRecurso
							-
							ticks_recurso
						),
						Color.SADDLE_BROWN
					)

				else:

					ticks_ativo += 1

					adicionar_cena(
						elemento_tarefa_ativa,
						str(delta),
						cor
					)

			else:

				ticks_ativo += 1

				adicionar_cena(
					elemento_tarefa_ativa,
					str(delta),
					cor
				)


			if get_finalizado():

				tarefa.Tempo_Execucao = (
					tempo
					-
					tarefa.Tempo_Entrada
				)

				tarefa.CalcularTempoEspera()


		elif estaSuspenso():

			adicionar_cena(
				elemento_tarefa_ativa,
				str(delta),
				Color.WEB_GRAY
			)


		else:

			adicionar_cena(
				elemento_tarefa,
				str(delta),
				cor * 0.5
			)


	else:

		adicionar_cena(
			elemento_vazio,
			"",
			cor * 0.1
		)


func estaSuspenso() -> bool:

	# Resource is free.
	if tabela.recurso == TabelaGrafico.RECURSO_LIVRE:
		return false


	# This task owns the resource.
	if tarefa.uid == tabela.recurso:
		return false


	# This task hasn't reached its resource request point yet.
	# Therefore it isn't blocked by the resource.
	if tarefa.TempoPedidoRecurso > ticks_ativo:
		return false


	# The task needs the resource and another task owns it.
	if ticks_recurso < tarefa.TempoUsoRecurso:
		return true


	return false
