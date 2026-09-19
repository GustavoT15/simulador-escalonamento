class_name TabelaResultados extends VBoxContainer

## Este script agora monta sua própria hierarquia interna em _ready():
##
##   TabelaResultados (VBoxContainer)  <- anexe este script aqui (em qualquer Control)
##       ├── header_grid  (GridContainer)   -> fica sempre visível, não rola
##       └── scroll       (ScrollContainer) -> só o corpo rola
##               └── body_grid (GridContainer)
##
## Não é mais necessário montar GridContainer/ScrollContainer manualmente na cena:
## o script cria tudo sozinho. Basta o nó pai ter tamanho definido (ex: dentro de
## um Control com anchors preenchendo a área, ou com custom_minimum_size setado)
## para o ScrollContainer saber quando deve mostrar as barras de rolagem.

const COLUMNS := 6
var HEADERS := [
	"Uid",
	"Nome",
	"Tempo de Execução",
	"Tempo de Processo",
	"Tempo de Espera",
	"Primeira Execução",
]

var header_grid: GridContainer
var scroll: ScrollContainer
var body_grid: GridContainer


func _ready() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_build_header()
	_build_scroll_body()


func _build_header() -> void:
	if is_instance_valid(header_grid):
		header_grid.queue_free()
	header_grid = GridContainer.new()
	header_grid.name = "HeaderGrid"
	header_grid.columns = COLUMNS
	header_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(header_grid)

	for h in HEADERS:
		var label := create_text(h)
		label.add_theme_color_override("default_color", Color.WHITE)
		header_grid.add_child(label)


func _build_scroll_body() -> void:
	if is_instance_valid(scroll):
		scroll.queue_free()
	scroll = ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	body_grid = GridContainer.new()
	body_grid.name = "BodyGrid"
	body_grid.columns = COLUMNS
	body_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body_grid)


func create_text(msg: String) -> RichTextLabel:
	var text_label := RichTextLabel.new()
	text_label.text = msg
	text_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	text_label.fit_content = true
	text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return text_label


func add_tuple(
	uid: int,
	nome: String,
	tempo_execucao: float,
	tempo_processo: float,
	tempo_espera: float,
	primeira_execucao: float
) -> void:
	for value in [uid, nome, tempo_execucao, tempo_processo, tempo_espera, primeira_execucao]:
		body_grid.add_child(create_text(str(value)))

	_sync_column_widths()


func clear() -> void:
	for child in body_grid.get_children():
		child.queue_free()


## Faz as colunas do cabeçalho acompanharem a largura das colunas do corpo,
## para as "abas"/colunas ficarem alinhadas mesmo com o corpo rolando.
func _sync_column_widths() -> void:
	await get_tree().process_frame  # espera o layout recalcular os tamanhos

	var body_children := body_grid.get_children()
	var header_children := header_grid.get_children()
	if body_children.is_empty():
		return

	for col in range(COLUMNS):
		var max_width := 0.0
		var row := col
		while row < body_children.size():
			max_width = max(max_width, body_children[row].size.x)
			row += COLUMNS
		if col < header_children.size():
			header_children[col].custom_minimum_size.x = max_width
