class_name TarefaInfo extends Resource

@export var nome:String
@export var uid:int = 0
@export_range(1,999,1.0) var Tempo_Processo:int = 2 ##Quanto tempo do processador essa tarefa precisa
@export_range(1,999,1.0) var Tempo_Entrada:int = 0 ##Quando que essa entrada entrou na fila
@export_range(0,999,1.0) var Prioridade:int = 1 ##A prioridade dessa tarefa
@export_range(-1,999,1.0) var TempoPedidoRecurso:int = 0
@export_range(1,999,1.0) var TempoUsoRecurso:int = 0

@export var Tempo_Execucao:int = 0
@export var Tempo_Espera:int = 0
@export var Executou_Antes:bool = false
@export var Tempo_Primeira_Execucao:int = 0
@export var PediuRecurso:bool = false
@export var PrioridadeOriginal = 1

func CalcularTempoEspera():
	self.Tempo_Espera =  self.Tempo_Execucao - self.Tempo_Processo

func Envelhecer(taxaEnvelhecimento:int):
	Prioridade+= taxaEnvelhecimento

func ReiniciarPrioridade():
	Prioridade = PrioridadeOriginal

func ReiniciarDados():
	PediuRecurso = false
	Tempo_Execucao = 0
	Tempo_Espera = 0
	Tempo_Primeira_Execucao = 0
	pass
