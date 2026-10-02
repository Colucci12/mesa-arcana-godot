extends ColorRect
class_name MaoVisual

@export var curvatura: Curve
@export var rotacao: Curve
@export var rotacao_max_graus := 5
@export var separacao := -10
@export var offset_min := 0
@export var offset_max := -15
@export var mao_adversaria := false

@export_group("Perspectiva do conjunto")
@export var perspectiva_habilitada := false
@export_range(180.0, 900.0, 5.0) var largura_leque := 560.0
@export_range(0.3, 2.5, 0.05) var tamanho_conjunto := 1.25
@export_range(0.3, 1.5, 0.05) var altura_cartas := 1.0
@export_range(-180.0, 180.0, 1.0) var giro_leque := 0.0
@export_range(-25.0, 25.0, 1.0) var deformacao_conjunto := 0.0
@export var deformacao_progressiva := false
@export_range(-0.5, 0.5, 0.05) var variacao_tamanho := 0.0
@export var escala_base_carta := Vector2(1.5, 1.5)
@export_group("Inclinação das cartas")
@export var inclinacao_uniforme := Vector2.ZERO
@export var inclinacao_primeira := Vector2.ZERO
@export var inclinacao_ultima := Vector2.ZERO
@export var inclinacao_x_progressiva := false
@export var inclinacao_y_progressiva := false
@export_range(1.0, 89.0, 1.0) var limite_inclinacao := 89.0
@export_group("Interação e animação")
@export_range(0.05, 2.0, 0.05) var duracao_reorganizacao := 1.0
@export var sombras_visiveis := true

@onready var _grupo_visual: Node2D = $GrupoVisual
@onready var _conteudo: Control = $GrupoVisual/Cartas

var _ids_jogaveis: Array[int] = []
var _exibir_jogabilidade := false
var _recebendo := false
var _hover_habilitado := true
var _hover_no_verso := false


func _ready() -> void:
	child_entered_tree.connect(_recebeu_uma_carta)
	child_exiting_tree.connect(_entregou_uma_carta)
	_conteudo.child_entered_tree.connect(_recebeu_uma_carta)
	_conteudo.child_exiting_tree.connect(_entregou_uma_carta)
	_configurar_conjunto()
	resized.connect(_ao_redimensionar)
	reorganizar(false)


func obter_cartas() -> Array[Carta]:
	var cartas: Array[Carta] = []
	# Filtrar preserva compatibilidade com cenas antigas que adicionavam à raiz.
	for filho in get_children():
		if filho is Carta:
			cartas.append(filho)
	for filho in _conteudo.get_children():
		if filho is Carta:
			cartas.append(filho)
	return cartas


func quantidade_cartas() -> int:
	return obter_cartas().size()


func obter_carta(indice: int) -> Carta:
	var cartas := obter_cartas()
	return cartas[indice] if indice >= 0 and indice < cartas.size() else null


func receber_carta(carta: Carta, animar: bool = true) -> void:
	_recebendo = true
	if carta.get_parent() == null:
		_conteudo.add_child(carta)
	elif carta.get_parent() != _conteudo:
		if perspectiva_habilitada or carta.animacao_2_5d_habilitada:
			carta.animacao_2_5d_habilitada = true
			carta.reparentar_preservando_visual(_conteudo)
		else:
			var origem := carta.global_position
			var angulo := carta.get_global_transform().get_rotation()
			carta.reparent(_conteudo, true)
			carta.rotation = angulo - _conteudo.get_global_transform().get_rotation()
			carta.global_position = origem
	_recebendo = false
	_configurar_carta(carta)
	carta.verso = mao_adversaria
	reorganizar(animar)


func receber_carta_do_monte(carta: Carta) -> void:
	receber_carta(carta)


func remover_carta(carta: Carta) -> void:
	if is_ancestor_of(carta):
		carta.get_parent().remove_child(carta)


func limpar() -> void:
	for carta in obter_cartas():
		remover_carta(carta)
		carta.queue_free()


func _recebeu_uma_carta(no: Node) -> void:
	var carta := no as Carta
	if carta == null:
		return
	if not carta.is_node_ready():
		await carta.ready
	if _recebendo:
		return
	_configurar_carta(carta)
	carta.verso = mao_adversaria
	reorganizar()


func _entregou_uma_carta(no: Node) -> void:
	if not no is Carta:
		return
	await no.tree_exited
	if is_inside_tree():
		reorganizar()


func _configurar_carta(carta: Carta) -> void:
	if perspectiva_habilitada:
		carta.animacao_2_5d_habilitada = true
		carta.limite_inclinacao_total = limite_inclinacao
		carta.definir_sombra_visivel(sombras_visiveis)
	carta.definir_hover_habilitado(_hover_habilitado, _hover_no_verso)
	carta.definir_jogavel(carta_permitida(carta.id_carta))


func definir_hover_habilitado(habilitado: bool, incluir_verso: bool = false) -> void:
	_hover_habilitado = habilitado
	_hover_no_verso = incluir_verso
	for carta in obter_cartas():
		carta.definir_hover_habilitado(habilitado, incluir_verso)


func definir_sombras_visiveis(visiveis: bool) -> void:
	sombras_visiveis = visiveis
	for carta in obter_cartas():
		carta.definir_sombra_visivel(visiveis)


func configurar_visual(ajustes: Dictionary, opcoes: Dictionary = {}, animar: bool = false) -> void:
	perspectiva_habilitada = true
	largura_leque = float(ajustes.get("largura", largura_leque))
	tamanho_conjunto = float(ajustes.get("tamanho", tamanho_conjunto))
	altura_cartas = float(ajustes.get("altura", altura_cartas))
	giro_leque = float(ajustes.get("giro", giro_leque))
	deformacao_conjunto = float(ajustes.get("deformacao", deformacao_conjunto))
	variacao_tamanho = float(ajustes.get("variacao_tamanho", variacao_tamanho))
	separacao = int(ajustes.get("separacao", separacao))
	offset_max = int(ajustes.get("curvatura", offset_max))
	rotacao_max_graus = int(ajustes.get("abertura", rotacao_max_graus))
	inclinacao_uniforme = Vector2(float(ajustes.get("inclinacao_x", 0.0)), float(ajustes.get("inclinacao_y", 0.0)))
	inclinacao_primeira = Vector2(float(ajustes.get("inclinacao_x_inicio", -inclinacao_uniforme.x)), float(ajustes.get("inclinacao_y_inicio", -inclinacao_uniforme.y)))
	inclinacao_ultima = Vector2(float(ajustes.get("inclinacao_x_fim", inclinacao_uniforme.x)), float(ajustes.get("inclinacao_y_fim", inclinacao_uniforme.y)))
	deformacao_progressiva = bool(opcoes.get("deformacao_progressiva", false))
	inclinacao_x_progressiva = bool(opcoes.get("inclinacao_x_progressiva", false))
	inclinacao_y_progressiva = bool(opcoes.get("inclinacao_y_progressiva", false))
	mao_adversaria = not bool(opcoes.get("frentes", not mao_adversaria))
	sombras_visiveis = bool(opcoes.get("sombras", sombras_visiveis))
	_configurar_conjunto()
	for carta in obter_cartas():
		_configurar_carta(carta)
	reorganizar(animar)


func _configurar_conjunto() -> void:
	if perspectiva_habilitada:
		color = Color.TRANSPARENT
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(180, 140)
		size = Vector2(largura_leque, 140)
		pivot_offset = Vector2.ZERO
		scale = Vector2(tamanho_conjunto, tamanho_conjunto * altura_cartas)
		rotation_degrees = giro_leque
		var angulo := 0.0 if deformacao_progressiva else deg_to_rad(deformacao_conjunto)
		# Equivalente ao antigo Node2D externo, inclusive com compressão vertical.
		_grupo_visual.transform = Transform2D(Vector2.RIGHT, Vector2(-altura_cartas * sin(angulo), cos(angulo)), Vector2.ZERO)
		_conteudo.position = Vector2(-size.x / 2.0, -Carta.SIZE.y / 2.0)
	else:
		_grupo_visual.transform = Transform2D.IDENTITY
		_conteudo.position = Vector2.ZERO
	_conteudo.size = size


func _ao_redimensionar() -> void:
	if perspectiva_habilitada:
		_conteudo.position = Vector2(-size.x / 2.0, -Carta.SIZE.y / 2.0)
	_conteudo.size = size


func calcular_estado_carta(indice: int, quantidade: int) -> Dictionary:
	var progresso := float(indice) / (quantidade - 1) if quantidade > 1 else 0.5
	var amplitude := progresso * 2.0 - 1.0
	var espacamento := float(separacao)
	var largura_total := Carta.SIZE.x * quantidade + espacamento * maxi(quantidade - 1, 0)
	if quantidade > 1 and largura_total > size.x:
		espacamento = (size.x - Carta.SIZE.x * quantidade) / (quantidade - 1)
		largura_total = size.x
	var deslocamento := (size.x - largura_total) / 2.0
	var deslocamento_y := float(offset_min)
	if quantidade > 1 or perspectiva_habilitada:
		deslocamento_y += offset_max * curvatura.sample(progresso)
	var angulo := rotacao_max_graus * rotacao.sample(progresso) if quantidade > 1 else 0.0
	var inclinacao := inclinacao_uniforme
	if inclinacao_x_progressiva:
		inclinacao.x = lerpf(inclinacao_primeira.x, inclinacao_ultima.x, progresso)
	if inclinacao_y_progressiva:
		inclinacao.y = lerpf(inclinacao_primeira.y, inclinacao_ultima.y, progresso)
	return {
		"posicao": Vector2(deslocamento + (Carta.SIZE.x + espacamento) * indice, deslocamento_y),
		"rotacao": angulo,
		"escala": escala_base_carta * (1.0 + variacao_tamanho * amplitude / 2.0),
		"inclinacao": inclinacao,
		"deformacao": deformacao_conjunto * amplitude if deformacao_progressiva else 0.0
	}


func reorganizar(animar: bool = true) -> void:
	var cartas := obter_cartas()
	for indice in range(cartas.size()):
		var carta := cartas[indice]
		var estado := calcular_estado_carta(indice, cartas.size())
		if perspectiva_habilitada or carta.animacao_2_5d_habilitada:
			carta.aplicar_estado_visual(estado, animar, duracao_reorganizacao)
		elif animar:
			carta.reposicionar(estado["posicao"], estado["rotacao"])
		else:
			if carta.tween_de_reposicionamento and carta.tween_de_reposicionamento.is_valid():
				carta.tween_de_reposicionamento.kill()
			carta.teleportar(estado["posicao"], estado["rotacao"])


func configurar_leque(nova_separacao: int, nova_curvatura: int, nova_abertura: int, animar: bool = true) -> void:
	separacao = nova_separacao
	offset_max = nova_curvatura
	rotacao_max_graus = nova_abertura
	reorganizar(animar)


func mostrar_cartas_jogaveis(ids: Array) -> void:
	_ids_jogaveis.clear()
	for id_carta in ids:
		_ids_jogaveis.append(int(id_carta))
	_exibir_jogabilidade = true
	_atualizar_jogabilidade()


func limpar_jogabilidade() -> void:
	_ids_jogaveis.clear()
	_exibir_jogabilidade = false
	_atualizar_jogabilidade()


func carta_permitida(id_carta: int) -> bool:
	return not _exibir_jogabilidade or _ids_jogaveis.has(id_carta)


func _atualizar_jogabilidade() -> void:
	for carta in obter_cartas():
		carta.definir_jogavel(carta_permitida(carta.id_carta))


func trocar_cartas_com(outra_mao: MaoVisual) -> void:
	var proprias := obter_cartas()
	var outras := outra_mao.obter_cartas()
	for carta in proprias:
		outra_mao.receber_carta(carta)
	for carta in outras:
		receber_carta(carta)
