extends Control
class_name DescarteVisual

signal cartas_visiveis_alteradas

const COR_PONTILHADO = Color(0.88, 0.94, 0.81, 0.65)

@export var perspectiva_habilitada := false
@export_range(0.05, 2.0, 0.05) var duracao_animacao := 1.0
@export_range(0.0, 30.0, 0.05) var variacao_x := 0.0
@export_range(0.0, 30.0, 0.05) var variacao_y := 6.0
@export_range(0.0, 30.0, 0.05) var variacao_rotacao := 10.0
@export_range(10, 20, 1) var maximo_cartas_visiveis := 20:
	set(valor):
		var limite := clampi(valor, 10, 20)
		if maximo_cartas_visiveis == limite:
			return
		maximo_cartas_visiveis = limite
		if is_node_ready():
			_atualizar_visibilidade()
@export_range(0.05, 0.5, 0.01) var duracao_acomodacao := 0.18

var _cartas_pousadas: Array[Carta] = []
var _cartas_visiveis: Array[Carta] = []
var _variacoes_por_carta: Dictionary = {}
var _sorteio := RandomNumberGenerator.new()

func _ready() -> void:
	_sorteio.randomize()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _draw() -> void:
	var margem := 7.0
	var direita := size.x - margem
	var abaixo := size.y - margem
	for x in range(int(margem), int(direita) + 1, 12):
		draw_circle(Vector2(x, margem), 1.8, COR_PONTILHADO)
		draw_circle(Vector2(x, abaixo), 1.8, COR_PONTILHADO)
	for y in range(int(margem), int(abaixo) + 1, 12):
		draw_circle(Vector2(margem, y), 1.8, COR_PONTILHADO)
		draw_circle(Vector2(direita, y), 1.8, COR_PONTILHADO)

func receber_carta(carta: Carta) -> void:
	var usar_perspectiva := perspectiva_habilitada or carta.animacao_2_5d_habilitada
	if usar_perspectiva:
		carta.animacao_2_5d_habilitada = true
		carta.reparentar_preservando_visual(self)
	else:
		carta.reparent(self, true)
	carta.state = false
	carta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	carta.verso = false
	var estado := estado_destino_carta(carta)
	if usar_perspectiva:
		carta.definir_hover_habilitado(false)
		carta.definir_sombra_visivel(true)
		carta.reorganizacao_concluida.connect(_confirmar_chegada.bind(carta), CONNECT_ONE_SHOT)
		carta.aplicar_estado_visual(estado, true, duracao_animacao)
	else:
		carta.reposicionar(estado["posicao"], estado["rotacao"])
		carta.tween_de_reposicionamento.finished.connect(_confirmar_chegada.bind(carta), CONNECT_ONE_SHOT)

func _confirmar_chegada(carta: Carta) -> void:
	if not is_instance_valid(carta) or carta.get_parent() != self:
		return
	if not _cartas_pousadas.has(carta):
		_cartas_pousadas.append(carta)
	_atualizar_visibilidade()

func obter_cartas_visiveis() -> Array[Carta]:
	return _cartas_visiveis.duplicate()

func _atualizar_visibilidade() -> void:
	var pousadas: Array[Carta] = []
	for carta in _cartas_pousadas:
		if is_instance_valid(carta) and carta.get_parent() == self:
			pousadas.append(carta)
	pousadas.sort_custom(func(a: Carta, b: Carta): return a.get_index() < b.get_index())
	_cartas_pousadas = pousadas
	_cartas_visiveis = pousadas.slice(maxi(0, pousadas.size() - maximo_cartas_visiveis))
	for carta in _cartas_pousadas:
		carta.visible = _cartas_visiveis.has(carta)
	cartas_visiveis_alteradas.emit()

func estado_destino_carta(carta: Carta) -> Dictionary:
	var id := carta.get_instance_id()
	if not _variacoes_por_carta.has(id):
		# Guardar a variação da instância, inclusive quando ela fica oculta na pilha.
		_variacoes_por_carta[id] = Vector3(_sorteio.randf_range(-1.0, 1.0), _sorteio.randf_range(-1.0, 1.0), _sorteio.randf_range(-1.0, 1.0))
	var variacao: Vector3 = _variacoes_por_carta[id]
	return {"posicao": (size - Carta.SIZE) / 2.0 + Vector2(variacao.x * variacao_x, variacao.y * variacao_y),
		"rotacao": variacao.z * variacao_rotacao,
		"escala": Vector2(1.5, 1.5), "inclinacao": Vector2.ZERO, "deformacao": 0.0}

func alterar_cor_carta(id_carta: int, cor: Carta_Base.Cores) -> void:
	for filho in get_children():
		var carta := filho as Carta
		if carta and carta.id_carta == id_carta:
			carta.alterar_cor_visual(cor)
			return

func limpar() -> void:
	_cartas_pousadas.clear()
	_cartas_visiveis.clear()
	_variacoes_por_carta.clear()
	for carta in get_children():
		remove_child(carta)
		carta.queue_free()
	cartas_visiveis_alteradas.emit()

