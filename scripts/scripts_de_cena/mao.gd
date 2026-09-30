extends ColorRect
class_name MaoVisual

@export var curvatura:Curve
@export var rotacao:Curve
@export var rotacao_max_graus := 5
@export var separacao := -10
@export var offset_min := 0
@export var offset_max := -15

@export var mao_adversaria := false

var _ids_jogaveis: Array[int] = []
var _exibir_jogabilidade: bool = false

#FUNÇÕES TRIGGER
func _ready() -> void:
	child_entered_tree.connect(_recebeu_uma_carta)
	child_exiting_tree.connect(_entregou_uma_carta)

func _recebeu_uma_carta(carta:Node) -> void:
	var carta_visual := carta as Carta
	if not carta_visual: return
	
	_atualizar_leque()
	
	carta_visual.verso = mao_adversaria
	_aplicar_jogabilidade(carta_visual)

func _entregou_uma_carta(carta:Node) -> void:
	await carta.tree_exited
	
	_atualizar_leque()

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

func trocar_cartas_com(outra_mao: MaoVisual) -> void:
	var cartas_proprias := get_children()
	var cartas_da_outra_mao := outra_mao.get_children()
	for carta in cartas_proprias:
		carta.reparent(outra_mao, true)
	for carta in cartas_da_outra_mao:
		carta.reparent(self, true)

func carta_permitida(id_carta: int) -> bool:
	return not _exibir_jogabilidade or _ids_jogaveis.has(id_carta)

func _atualizar_jogabilidade() -> void:
	for filho in get_children():
		var carta := filho as Carta
		if carta:
			_aplicar_jogabilidade(carta)

func _aplicar_jogabilidade(carta: Carta) -> void:
	carta.definir_jogavel(carta_permitida(carta.id_carta))

#FUNÇÕES DE EMBELEZAMENTO
func _atualizar_leque():
	var cartas := get_child_count()
	if cartas == 0:
		return
	if cartas == 1:
		var carta_unica := get_child(0)
		carta_unica.reposicionar(Vector2((size.x - Carta.SIZE.x) / 2.0, offset_min), 0.0)
		return

	var tamanho_todas_cartas := Carta.SIZE.x *  cartas + separacao * (cartas -1)
	var separacao_final = separacao
	
	if tamanho_todas_cartas > size.x:
		separacao_final = (size.x - Carta.SIZE.x * cartas) / (cartas -1)
		tamanho_todas_cartas = size.x
		
	var offset := (size.x - tamanho_todas_cartas) / 2
	
	for i in cartas:
		var carta := get_child(i)
		var multiplicador_cima := curvatura.sample(1.0 / (cartas-1) * i)
		var multiplicador_rotacao := rotacao.sample(1.0 / (cartas-1) * i)
		
		var final_x:float = offset + Carta.SIZE.x * i + separacao_final * i
		var final_y:float = offset_min + offset_max * multiplicador_cima
		
		carta.reposicionar(Vector2(final_x, final_y), (rotacao_max_graus * multiplicador_rotacao))
