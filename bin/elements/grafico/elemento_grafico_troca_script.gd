class_name TuplaTroca extends GraficoTupla
@export var tempo_troca:int = 1
func _ready()->void:
	pass
func get_finalizado()->bool:
	return ticks_ativo >= tempo_troca + 1 or tempo_troca == 0
	
func step(tempo_atual:int = 0,ativo:bool = false)->void:
	tempo = tempo_atual
	var delta = tempo_troca-(ticks_ativo)
	if !get_finalizado():
		if ativo:
			if ticks_ativo < tempo_troca:
				adicionar_cena(elemento_tarefa_ativa,str(delta),Color.YELLOW*1.0)
			else:
				adicionar_cena(elemento_vazio,"...",cor*0.01)
			ticks_ativo +=1
		else:
			adicionar_cena(elemento_vazio,"...",cor*0.01)
	else:
		adicionar_cena(elemento_vazio,"...",cor*0.01)

func reiniciar():
	ticks_ativo = 0
