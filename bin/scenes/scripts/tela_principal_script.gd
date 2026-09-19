extends Control

@export var buttao_iniciar_processo:Button
@export var processos_tab:TabelaDeProcessos
@export var grafico_tab:TabelaGrafico
@export var multigrafico_tab:TabelaMultiploGrafico
func _ready()->void:
	buttao_iniciar_processo.pressed.connect(start)
	processos_tab.preset_updated.connect(multigrafico_tab.build_lista)
	pass
func start()->void:
	buttao_iniciar_processo.disabled = true
	if grafico_tab.visible:
		await grafico_tab.start(processos_tab.get_all_tarefas())
#		await grafico_tab.finalizado
		buttao_iniciar_processo.disabled = false
	else:
		multigrafico_tab.start(processos_tab.get_all_tarefas())	
		await multigrafico_tab.finalizado
		buttao_iniciar_processo.disabled = false
	pass
