class_name TuplaCounter extends GraficoTupla

func _ready()->void:
	pass
func step(tempo_atual:int = 0,ativo:bool = false)->void:
	tempo = tempo_atual
	adicionar_cena(elemento_vazio,str(tempo),cor*.1)
