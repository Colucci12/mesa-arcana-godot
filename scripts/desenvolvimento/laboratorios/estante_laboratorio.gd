extends Node2D

const CORES_LIVROS := [Color("815039"), Color("355951"), Color("525372"),
	Color("7a6942"), Color("62443d"), Color("466370"), Color("605b42"), Color("384c40")]

var _faces: Array[Dictionary] = []
var _origem := Vector3.ZERO
var _horizontal := Vector3.RIGHT
var _frente := Vector3.DOWN
var _projetar: Callable
var _verticais_retas := false
var _proporcao_vertical := 1.0
var _limites := Rect2()
var _tem_limites := false


func configurar(ajustes: Dictionary, tamanho_plano: Vector2, projetar: Callable) -> void:
	_faces.clear()
	_tem_limites = false
	_projetar = projetar
	_verticais_retas = bool(ajustes.get("verticais_retas", false))
	_origem = Vector3(tamanho_plano.x / 2.0 + float(ajustes["x"]),
		-float(ajustes["distancia"]), float(ajustes["altura_base"]))
	if _verticais_retas:
		var centro: Vector2 = _projetar.call(_origem)
		var acima: Vector2 = _projetar.call(_origem + Vector3(0, 0, 1))
		var lateral: Vector2 = _projetar.call(_origem + Vector3.RIGHT)
		_proporcao_vertical = NAN
		if centro.is_finite() and acima.is_finite() and lateral.is_finite():
			_proporcao_vertical = (acima.y - centro.y) / maxf(absf(lateral.x - centro.x), 0.001)
	var angulo := deg_to_rad(float(ajustes["angulo"]))
	_horizontal = Vector3(cos(angulo), sin(angulo), 0)
	_frente = Vector3(-sin(angulo), cos(angulo), 0)
	var largura := float(ajustes["largura"])
	var altura := float(ajustes["altura"])
	_retangulo(-largura / 2.0, 0, largura, altura, 0, Color("1a2421"))
	_retangulo(-largura / 2.0, 0, largura * 0.06, altura, 38, Color("514738"))
	_retangulo(largura * 0.44, 0, largura * 0.06, altura, 38, Color("65533d"))
	_retangulo(-largura / 2.0, altura - 18, largura, 18, 40, Color("766249"))
	for nivel in range(3):
		var apoio := altura * (0.06 + nivel * 0.29)
		if bool(ajustes["livros"]):
			for indice in range(8):
				var x := largura * (-0.38 + indice * 0.095)
				var l := largura * (0.05 + (indice % 3) * 0.008)
				var h := altura * (0.14 + ((indice + nivel) % 4) * 0.018)
				_retangulo(x, apoio + 9, l, h, 25, CORES_LIVROS[(indice + nivel * 2) % CORES_LIVROS.size()])
				_retangulo(x + l * 0.15, apoio + 9 + h * 0.13, l * 0.7, 4, 26, Color("ac9566"))
				_retangulo(x + l * 0.15, apoio + 9 + h * 0.82, l * 0.7, 3, 26, Color("ac9566"))
		_prateleira(largura, apoio)
	visible = bool(ajustes["visivel"]) and _tem_limites
	var claridade := float(ajustes["claridade"]) / 100.0
	modulate = Color(claridade, claridade, claridade, 1)
	queue_redraw()


func _ponto(x: float, altura: float, frente: float) -> Vector2:
	var base := _origem + _horizontal * x + _frente * frente
	if not _verticais_retas:
		return _projetar.call(base + Vector3(0, 0, altura))
	# Mantém a profundidade da base, mas estende cada coluna na vertical.
	# A escala segue a distância de cada ponto, sem crescer com a altura.
	# Uma proporção comum preserva as linhas retas de todas as prateleiras.
	var apoio: Vector2 = _projetar.call(base)
	var lateral: Vector2 = _projetar.call(base + Vector3.RIGHT)
	if not apoio.is_finite() or not lateral.is_finite() or not is_finite(_proporcao_vertical):
		return Vector2(NAN, NAN)
	var escala := absf(lateral.x - apoio.x)
	return apoio + Vector2(0, escala * _proporcao_vertical * altura)


func _face(pontos: PackedVector2Array, cor: Color) -> void:
	for ponto in pontos:
		if not ponto.is_finite():
			return
	for ponto in pontos:
		if not _tem_limites:
			_limites = Rect2(ponto, Vector2.ZERO)
			_tem_limites = true
		_limites = _limites.expand(ponto)
	_faces.append({"pontos": pontos, "cor": cor})


func _retangulo(x: float, altura: float, largura: float, tamanho_vertical: float, frente: float, cor: Color) -> void:
	_face(PackedVector2Array([_ponto(x, altura, frente), _ponto(x + largura, altura, frente),
		_ponto(x + largura, altura + tamanho_vertical, frente), _ponto(x, altura + tamanho_vertical, frente)]), cor)


func _prateleira(largura: float, altura: float) -> void:
	_face(PackedVector2Array([_ponto(-largura / 2.0, altura + 8, 0),
		_ponto(largura / 2.0, altura + 8, 0), _ponto(largura / 2.0, altura + 8, 48),
		_ponto(-largura / 2.0, altura + 8, 48)]), Color("7b6b50"))
	_retangulo(-largura / 2.0 - 8, altura, largura + 16, 8, 48, Color("554a39"))


func obter_limites() -> Rect2:
	return _limites


func _draw() -> void:
	for face in _faces:
		draw_colored_polygon(face["pontos"], face["cor"])
