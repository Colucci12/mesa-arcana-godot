extends Control
class_name Carta

signal selecionada(id_carta: int)

var id_carta: int = -1

var SCALE := self.scale
const SIZE := Vector2(71, 95)
var posicao : Vector2

var tween_de_reposicionamento: Tween = null
var _tween_da_cor: Tween = null
var _cor_de_fundo: Carta_Base.Cores = Carta_Base.Cores.PRETO
	
var verso := true:
	set(v):
		if verso == v: return
		verso = v
		virar_carta()	
	
var state := false:
	set(v): 
		state = v
		carta_esta_em_foco()

#FUNÇÕES TRIGGER
func _ready() -> void:
	global_position = posicao

func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return
	if verso or id_carta <= 0:
		return
	selecionada.emit(id_carta)
	accept_event()

#FUNÇÕES NORMAIS
func carta_esta_em_foco():
	if state:
		z_index = 10
	else:
		z_index = 0

func definir_jogavel(jogavel: bool) -> void:
	modulate = Color.WHITE if jogavel else Color(0.55, 0.55, 0.55)
		
func virar_carta():
	var tween = create_tween()
	
	tween.tween_property(self, "scale:x", 0.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	tween.tween_callback(_trocar_textura_visual)
	
	tween.tween_property(self, "scale:x", SCALE.x, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	if verso: tween.tween_callback(_limpar_carta)

func _limpar_carta():
	$ColorRect.color = Color.TRANSPARENT
	$simbolo_centro.texture.region = Rect2(-40, -40, 40, 40)
	$simbolo_esquerdo.texture.region = Rect2(-40, -40, 40, 40)
	$simbolo_direito.texture.region = Rect2(-40, -40, 40, 40)
	
	id_carta = -1

#ANIMAÇÕES E EMBELEZAMENTOS
func _on_mouse_entered() -> void:
	if verso: return
	
	state = true
	
	var tweeen = create_tween()
	tweeen.set_trans(Tween.TRANS_CIRC)
	tweeen.set_ease(Tween.EASE_IN_OUT)
	tweeen.tween_property(self, "scale", Vector2(SCALE.x+0.2, SCALE.y+0.2), 0.1)

func _on_mouse_exited() -> void:
	if verso: return
	
	state = false
	
	var tweeen = create_tween()
	tweeen.set_trans(Tween.TRANS_ELASTIC)
	tweeen.set_ease(Tween.EASE_OUT)
	tweeen.tween_property(self, "scale", Vector2(SCALE.x, SCALE.y), 0.2	)

func _trocar_textura_visual():
	if $costas_carta.visible:
		$costas_carta.visible = false
	else:
		$costas_carta.visible = true

func reposicionar(p_posicao:Vector2, p_rotacao:float) -> void:
	if tween_de_reposicionamento and tween_de_reposicionamento.is_valid():
		tween_de_reposicionamento.kill()

	tween_de_reposicionamento = create_tween()
	tween_de_reposicionamento.set_trans(Tween.TRANS_CUBIC)
	tween_de_reposicionamento.set_ease(Tween.EASE_OUT)
	
	tween_de_reposicionamento.tween_property(self, "position", p_posicao, 1)
	tween_de_reposicionamento.parallel().tween_property(self, "rotation_degrees", p_rotacao, 1)

func alterar_cor_visual(cor: Carta_Base.Cores) -> void:
	if not MAP_CORES.has(cor):
		return
	_cor_de_fundo = cor
	if _tween_da_cor and _tween_da_cor.is_valid():
		_tween_da_cor.kill()
	_tween_da_cor = create_tween()
	_tween_da_cor.tween_property($ColorRect, "color", MAP_CORES[_cor_de_fundo], 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func teleportar(p_posicao:Vector2 = Vector2(0,0), p_rotacao:float = 0.0) -> void:
	self.position = p_posicao
	self.rotation_degrees = p_rotacao

#SETUP LOGICO
const MAP_CORES = {
	Carta_Base.Cores.AZUL: Color.NAVY_BLUE,
	Carta_Base.Cores.VERDE: Color.WEB_GREEN,
	Carta_Base.Cores.AMARELO: Color.GOLDENROD,
	Carta_Base.Cores.VERMELHO: Color.DARK_RED,
	Carta_Base.Cores.PRETO: Color.BLACK}

const COORDENADAS_PLANILHA = {
		"0": [Vector2i(0, 0), Vector2i(0, 0)],
		"1": [Vector2i(1, 0), Vector2i(1, 0)],
		"2": [Vector2i(2, 0), Vector2i(2, 0)],
		"3": [Vector2i(3, 0), Vector2i(3, 0)],
		"4": [Vector2i(4, 0), Vector2i(4, 0)],
		"5": [Vector2i(5, 0), Vector2i(5, 0)],
		
		"6": [Vector2i(0, 1), Vector2i(0, 1)],
		"7": [Vector2i(1, 1), Vector2i(1, 1)],
		"8": [Vector2i(2, 1), Vector2i(2, 1)],
		"9": [Vector2i(3, 1), Vector2i(3, 1)],
		"PULA": [Vector2i(4, 1), Vector2i(4, 1)],
		"INVERTE": [Vector2i(5, 1), Vector2i(5, 1)],
		
		"+2": [Vector2i(0, 2), Vector2i(1, 2)],
		"TROCACOR": [Vector2i(3, 2), Vector2i(3, 2)],
		"+4": [Vector2i(4, 2), Vector2i(2, 2)],
		"TROCAMAO": [Vector2i(3, 2), Vector2i(5, 2)]
	}

func setup(dados_carta: Carta_Base):
	if dados_carta == null:
		push_error("Erro: Carta instanciada sem dados")
		return
		
	id_carta = dados_carta.get_id()
	_configurar_visual(dados_carta.get_cor(), dados_carta.valor)

func setup_dados(dados_carta: Dictionary) -> void:
	id_carta = int(dados_carta.get("id", -1))
	var nome_cor := String(dados_carta.get("cor", "PRETO"))
	var cor: Carta_Base.Cores = Carta_Base.Cores.get(nome_cor, Carta_Base.Cores.PRETO)
	var valor := String(dados_carta.get("valor", ""))
	_configurar_visual(cor, valor)

func _configurar_visual(cor: Carta_Base.Cores, valor: String) -> void:
	_cor_de_fundo = cor
	const LARGURA = 35
	const ALTURA = 39
	var cor_visual = MAP_CORES.get(cor, Color.REBECCA_PURPLE)
	var par_coordenadas = COORDENADAS_PLANILHA.get(valor, [Vector2i(0, 0), Vector2i(0, 0)])
	var coord_centro = par_coordenadas[1]
	var coord_lados = par_coordenadas[0]
	
	var regiao_centro = Rect2(coord_centro.x * LARGURA, coord_centro.y * ALTURA, LARGURA, ALTURA)
	var regiao_lados = Rect2(coord_lados.x * LARGURA, coord_lados.y * ALTURA, LARGURA, ALTURA)
	
	$simbolo_centro.texture = $simbolo_centro.texture.duplicate()
	$simbolo_esquerdo.texture = $simbolo_esquerdo.texture.duplicate()
	$simbolo_direito.texture = $simbolo_direito.texture.duplicate()
	
	$ColorRect.color = cor_visual
	$simbolo_centro.texture.region = regiao_centro
	$simbolo_esquerdo.texture.region = regiao_lados
	$simbolo_direito.texture.region = regiao_lados
