extends Control
class_name Carta

signal selecionada(id_carta: int)

@export var deslocamento_sombra := Vector2(3, 5)
@export_range(0.0, 20.0, 0.5) var inclinacao_maxima: float = 12.0
@export var inclinacao_base := Vector2.ZERO:
	set(valor):
		inclinacao_base = valor
		if is_node_ready():
			_definir_inclinacao(_inclinacao_atual)

var id_carta: int = -1

var SCALE := self.scale
const SIZE := Vector2(71, 95)
var posicao : Vector2

var tween_de_reposicionamento: Tween = null
var _tween_da_cor: Tween = null
var _tween_do_hover: Tween = null
var _tween_da_virada: Tween = null
var _virando: bool = false
var _hover_habilitado: bool = true
var _hover_no_verso: bool = false
var _inclinacao_atual := Vector2.ZERO
var _cor_de_fundo: Carta_Base.Cores = Carta_Base.Cores.PRETO
var _iluminacao: IluminacaoAmbiente
	
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
	set_notify_transform(true)
	_atualizar_sombra()
	set_process(false)
	_definir_inclinacao(Vector2.ZERO)
	_solicitar_atualizacao_visual()

func _process(delta: float) -> void:
	var inclinacao_destino := Vector2.ZERO
	if state and _hover_permitido():
		var mouse_relativo := get_local_mouse_position() / SIZE * 2.0 - Vector2.ONE
		mouse_relativo = mouse_relativo.clamp(-Vector2.ONE, Vector2.ONE)
		inclinacao_destino = Vector2(-mouse_relativo.y, mouse_relativo.x) * inclinacao_maxima
	_definir_inclinacao(_inclinacao_atual.lerp(inclinacao_destino, 1.0 - exp(-16.0 * delta)))
	if not state and _inclinacao_atual.length_squared() < 0.0001:
		_definir_inclinacao(Vector2.ZERO)
		set_process(false)

func _definir_inclinacao(inclinacao: Vector2) -> void:
	_inclinacao_atual = inclinacao
	var total := (inclinacao_base + inclinacao).clamp(Vector2(-55, -55), Vector2(55, 55))
	$TexturaCarta.material.set_shader_parameter("inclinacao", total)

func _solicitar_atualizacao_visual() -> void:
	$SubViewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func _notification(notificacao: int) -> void:
	if notificacao == NOTIFICATION_TRANSFORM_CHANGED and is_node_ready():
		_atualizar_sombra()

func _atualizar_sombra() -> void:
	var transformacao := get_global_transform_with_canvas()
	if absf(transformacao.determinant()) < 0.0001:
		return
	var escala_sombra := minf(transformacao.x.length(), transformacao.y.length())
	var deslocamento_na_tela := deslocamento_sombra * escala_sombra
	if is_instance_valid(_iluminacao):
		var centro_na_tela := transformacao * (size / 2.0)
		var dimensoes_tela := get_viewport().get_visible_rect().size
		var sombra_lampada := _iluminacao.deslocamento_sombra_na_tela(centro_na_tela, dimensoes_tela)
		deslocamento_na_tela = deslocamento_na_tela.lerp(sombra_lampada * escala_sombra, _iluminacao.intensidade)
	var deslocamento_local := transformacao.affine_inverse() * (transformacao.origin + deslocamento_na_tela)
	$Sombra.position = $TexturaCarta.position + deslocamento_local

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

func definir_sombra_visivel(visivel: bool) -> void:
	$Sombra.visible = visivel

func definir_hover_habilitado(habilitado: bool, incluir_verso: bool = false) -> void:
	_hover_habilitado = habilitado
	_hover_no_verso = incluir_verso
	mouse_filter = Control.MOUSE_FILTER_STOP if habilitado else Control.MOUSE_FILTER_IGNORE
	if not habilitado:
		if _tween_do_hover and _tween_do_hover.is_valid():
			_tween_do_hover.kill()
		state = false
		_definir_inclinacao(Vector2.ZERO)
		set_process(false)
		if not _virando:
			scale = SCALE

func _hover_permitido() -> bool:
	return _hover_habilitado and not _virando and (not verso or _hover_no_verso)

func definir_deformacao(graus: float) -> void:
	$TexturaCarta.material.set_shader_parameter("deformacao", clampf(graus, -25.0, 25.0))

func definir_acabamento(intensidade_claros: float, intensidade_tinta: float, variacao_tinta: float = 0.0, escala_variacao: float = 18.0) -> void:
	var material_carta := $TexturaCarta.material as ShaderMaterial
	material_carta.set_shader_parameter("acabamento_claros", clampf(intensidade_claros, 0.0, 0.05))
	material_carta.set_shader_parameter("acabamento_tinta", clampf(intensidade_tinta, 0.0, 0.08))
	material_carta.set_shader_parameter("acabamento_variacao_tinta", clampf(variacao_tinta, 0.0, 0.15))
	material_carta.set_shader_parameter("acabamento_escala_variacao", clampf(escala_variacao, 4.0, 48.0))

func definir_iluminacao(iluminacao: IluminacaoAmbiente) -> void:
	if is_instance_valid(_iluminacao) and _iluminacao.parametros_alterados.is_connected(_atualizar_sombra):
		_iluminacao.parametros_alterados.disconnect(_atualizar_sombra)
	_iluminacao = iluminacao
	_iluminacao.aplicar_em($TexturaCarta.material as ShaderMaterial, true)
	_iluminacao.parametros_alterados.connect(_atualizar_sombra)
	if not get_viewport().size_changed.is_connected(_atualizar_sombra):
		get_viewport().size_changed.connect(_atualizar_sombra)
	_atualizar_sombra()
		
func virar_carta():
	if _tween_do_hover and _tween_do_hover.is_valid():
		_tween_do_hover.kill()
	if _tween_da_virada and _tween_da_virada.is_valid():
		_tween_da_virada.kill()
	_virando = true
	state = false
	_definir_inclinacao(Vector2.ZERO)
	set_process(false)
	scale.y = SCALE.y
	_tween_da_virada = create_tween()
	
	_tween_da_virada.tween_property(self, "scale:x", 0.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	_tween_da_virada.tween_callback(_trocar_textura_visual)
	
	_tween_da_virada.tween_property(self, "scale:x", SCALE.x, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	if verso: _tween_da_virada.tween_callback(_limpar_carta)
	_tween_da_virada.tween_callback(_finalizar_virada)

func _finalizar_virada() -> void:
	_virando = false
	if _hover_permitido() and get_viewport().gui_get_hovered_control() == self:
		_on_mouse_entered()

func _limpar_carta():
	$SubViewport/Visual/ColorRect.color = Color.TRANSPARENT
	$SubViewport/Visual/simbolo_centro.texture.region = Rect2(-40, -40, 40, 40)
	$SubViewport/Visual/simbolo_esquerdo.texture.region = Rect2(-40, -40, 40, 40)
	$SubViewport/Visual/simbolo_direito.texture.region = Rect2(-40, -40, 40, 40)
	
	id_carta = -1
	_solicitar_atualizacao_visual()

#ANIMAÇÕES E EMBELEZAMENTOS
func _on_mouse_entered() -> void:
	if not _hover_permitido(): return
	
	state = true
	set_process(true)
	_animar_hover(SCALE + Vector2(0.2, 0.2), 0.35)

func _on_mouse_exited() -> void:
	if not _hover_permitido(): return
	
	state = false
	_animar_hover(SCALE, 0.2)

func _animar_hover(escala_destino: Vector2, duracao: float) -> void:
	if _tween_do_hover and _tween_do_hover.is_valid():
		_tween_do_hover.kill()
	_tween_do_hover = create_tween()
	_tween_do_hover.set_trans(Tween.TRANS_ELASTIC)
	_tween_do_hover.set_ease(Tween.EASE_OUT)
	_tween_do_hover.tween_property(self, "scale", escala_destino, duracao)

func _trocar_textura_visual():
	$SubViewport/Visual/costas_carta.visible = verso
	_solicitar_atualizacao_visual()

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
	_tween_da_cor.tween_method(_definir_cor_fundo, $SubViewport/Visual/ColorRect.color, MAP_CORES[_cor_de_fundo], 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _definir_cor_fundo(cor: Color) -> void:
	$SubViewport/Visual/ColorRect.color = cor
	_solicitar_atualizacao_visual()

func teleportar(p_posicao:Vector2 = Vector2(0,0), p_rotacao:float = 0.0) -> void:
	self.position = p_posicao
	self.rotation_degrees = p_rotacao

#SETUP LOGICO
const MAP_CORES = {
	Carta_Base.Cores.AZUL: Color("#2A4F8F"),
	Carta_Base.Cores.VERDE: Color("#2F6B3B"),
	Carta_Base.Cores.AMARELO: Color("#B88A1B"),
	Carta_Base.Cores.VERMELHO: Color("#8F1E28"),
	Carta_Base.Cores.PRETO: Color("#14161A")}

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
	
	$SubViewport/Visual/simbolo_centro.texture = $SubViewport/Visual/simbolo_centro.texture.duplicate()
	$SubViewport/Visual/simbolo_esquerdo.texture = $SubViewport/Visual/simbolo_esquerdo.texture.duplicate()
	$SubViewport/Visual/simbolo_direito.texture = $SubViewport/Visual/simbolo_direito.texture.duplicate()
	
	$SubViewport/Visual/ColorRect.color = cor_visual
	$SubViewport/Visual/simbolo_centro.texture.region = regiao_centro
	$SubViewport/Visual/simbolo_esquerdo.texture.region = regiao_lados
	$SubViewport/Visual/simbolo_direito.texture.region = regiao_lados
	_solicitar_atualizacao_visual()
