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
var _luz: Dictionary = {}
var _camera := Vector3.ZERO
var _contraste := 0.4


func configurar(ajustes: Dictionary, tamanho_plano: Vector2, projetar: Callable,
		luz: Dictionary = {}, camera: Vector3 = Vector3(800, 1100, 650)) -> void:
	_faces.clear()
	_tem_limites = false
	_projetar = projetar
	_luz = luz
	_camera = camera
	_contraste = float(ajustes.get("contraste", 40.0)) / 100.0
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
	var profundidade := float(ajustes.get("profundidade", 180.0))
	var prateleiras := maxi(roundi(float(ajustes.get("prateleiras", 3.0))), 1)
	var espessura := minf(float(ajustes.get("espessura", 24.0)),
		minf(largura / 5.0, minf(altura / (prateleiras * 2.0 + 4.0), profundidade / 3.0)))
	var estrutura := Color.html(str(ajustes.get("cor_estrutura", "766249")))
	var fundo := Color.html(str(ajustes.get("cor_fundo", "1a2421")))
	_retangulo(-largura / 2.0, 0, largura, altura, 0, fundo)
	# Laterais e interior ocupam regiões separadas, sem faces cruzadas.
	var partes: Array[Dictionary] = [
		{"inicio": -largura / 2.0, "fim": -largura / 2.0 + espessura, "interior": false},
		{"inicio": -largura / 2.0 + espessura, "fim": largura / 2.0 - espessura, "interior": true},
		{"inicio": largura / 2.0 - espessura, "fim": largura / 2.0, "interior": false}]
	for parte in _ordem_blocos(partes, 0):
		if bool(parte["interior"]):
			_montar_interior(ajustes, largura, altura, profundidade, espessura, prateleiras, estrutura)
		else:
			_caixa(Vector3(float(parte["inicio"]), 0, 0), Vector3(espessura, altura, profundidade), estrutura)
	_inclinar_na_tela(deg_to_rad(float(ajustes.get("inclinacao", 0.0))))
	visible = bool(ajustes["visivel"]) and _tem_limites
	var claridade := float(ajustes["claridade"]) / 100.0
	modulate = Color(claridade, claridade, claridade, 1)
	queue_redraw()


func _montar_interior(ajustes: Dictionary, largura: float, altura: float, profundidade: float,
		espessura: float, prateleiras: int, estrutura: Color) -> void:
	var interior := largura - espessura * 2.0
	var intervalo := (altura - espessura * 2.0) / prateleiras
	var faixas: Array[Dictionary] = []
	for nivel in range(prateleiras):
		var apoio := espessura + nivel * intervalo
		faixas.append({"inicio": apoio, "fim": apoio + espessura, "livros": false})
		faixas.append({"inicio": apoio + espessura, "fim": apoio + intervalo,
			"livros": true, "nivel": nivel})
	faixas.append({"inicio": altura - espessura, "fim": altura, "livros": false})
	for faixa in _ordem_blocos(faixas, 1):
		var base := float(faixa["inicio"])
		var tamanho := float(faixa["fim"]) - base
		if bool(faixa["livros"]):
			if bool(ajustes["livros"]):
				_montar_livros(ajustes, int(faixa["nivel"]), interior, base, tamanho, profundidade)
		else:
			_caixa(Vector3(-interior / 2.0, base, 0), Vector3(interior, tamanho, profundidade), estrutura)


func _ordem_blocos(blocos: Array[Dictionary], eixo: int, primeiro: int = 0,
		ultimo: int = -1) -> Array[Dictionary]:
	# Cada divisão é um plano entre peças. Desenha o lado distante antes do próximo.
	if ultimo < 0:
		ultimo = blocos.size() - 1
	if primeiro > ultimo:
		return []
	if primeiro == ultimo:
		return [blocos[primeiro]]
	var meio := primeiro + ((ultimo - primeiro) >> 1)
	var corte := (float(blocos[meio]["fim"]) + float(blocos[meio + 1]["inicio"])) / 2.0
	var baixos := _ordem_blocos(blocos, eixo, primeiro, meio)
	var altos := _ordem_blocos(blocos, eixo, meio + 1, ultimo)
	if _lado_positivo(eixo, corte):
		baixos.append_array(altos)
		return baixos
	altos.append_array(baixos)
	return altos


func _lado_positivo(eixo: int, corte: float) -> bool:
	# A orientação projetada também funciona no modo artístico de verticais retas.
	var locais: Array[Vector3]
	if eixo == 0:
		locais = [Vector3(corte, 0, 0), Vector3(corte, 0, 10),
			Vector3(corte, 10, 10), Vector3(corte, 10, 0)]
	else:
		locais = [Vector3(0, corte, 0), Vector3(10, corte, 0),
			Vector3(10, corte, 10), Vector3(0, corte, 10)]
	var pontos := PackedVector2Array()
	for local in locais:
		var ponto := _ponto(local.x, local.y, local.z)
		if not ponto.is_finite():
			return _camera_no_eixo(eixo) > corte
		pontos.append(ponto)
	var area := _area_projetada(pontos)
	if is_zero_approx(area):
		return _camera_no_eixo(eixo) > corte
	return area > 0.0


func _camera_no_eixo(eixo: int) -> float:
	return (_camera - _origem).dot(_horizontal) if eixo == 0 else _camera.z - _origem.z


func _inclinar_na_tela(angulo: float) -> void:
	if not _tem_limites or is_zero_approx(angulo):
		return
	# Giro de composição após a projeção: todas as faces giram juntas.
	var centro := _limites.get_center()
	_tem_limites = false
	for face in _faces:
		var pontos: PackedVector2Array = face["pontos"]
		for indice in range(pontos.size()):
			var ponto := centro + (pontos[indice] - centro).rotated(angulo)
			pontos[indice] = ponto
			if not _tem_limites:
				_limites = Rect2(ponto, Vector2.ZERO)
				_tem_limites = true
			_limites = _limites.expand(ponto)
		face["pontos"] = pontos


func _montar_livros(ajustes: Dictionary, nivel: int, interior: float, apoio: float,
		altura_livre: float, profundidade: float) -> void:
	# Dimensões próprias: ampliar o móvel abre espaço sem ampliar os livros.
	var largura_base := float(ajustes.get("largura_livros", 20.0))
	var altura_base := float(ajustes.get("altura_livros", 160.0))
	var profundidade_base := float(ajustes.get("profundidade_livros", 90.0))
	var faixa := interior * float(ajustes.get("ocupacao_livros", 85.0)) / 100.0
	var folga := 2.0
	var capacidade := maxi(floori((faixa + folga) / (largura_base * 1.15 + folga)), 0)
	var quantidade := mini(maxi(roundi(float(ajustes.get("quantidade_livros", 20.0))), 0), capacidade)
	if quantidade == 0 or altura_livre <= 0.0:
		return
	var larguras := PackedFloat32Array()
	var soma := 0.0
	for indice in range(quantidade):
		var largura := largura_base * (0.85 + ((indice + nivel) % 4) * 0.1)
		larguras.append(largura)
		soma += largura
	var espaco := (faixa - soma) / (quantidade - 1) if quantidade > 1 else 0.0
	var x := -faixa / 2.0 if quantidade > 1 else -larguras[0] / 2.0
	var recuo := minf(20.0, profundidade * 0.1)
	var livros: Array[Dictionary] = []
	for indice in range(quantidade):
		var l := float(larguras[indice])
		var h := minf(altura_base * (0.85 + ((indice + nivel) % 4) * 0.1), altura_livre * 0.95)
		var p := minf(profundidade_base * (0.9 + (indice % 3) * 0.05), profundidade - recuo - 2.0)
		var frente := profundidade - recuo - (indice % 3) * minf(3.0, profundidade * 0.01)
		var inicio := maxf(frente - p, 2.0)
		livros.append({"inicio": x, "fim": x + l, "altura": h, "fundo": inicio, "frente": frente,
			"cor": CORES_LIVROS[(indice + nivel * 2) % CORES_LIVROS.size()]})
		x += l + espaco
	for livro in _ordem_blocos(livros, 0):
		x = float(livro["inicio"])
		var l := float(livro["fim"]) - x
		var h := float(livro["altura"])
		var inicio := float(livro["fundo"])
		var frente := float(livro["frente"])
		_caixa(Vector3(x, apoio, inicio), Vector3(l, h, frente - inicio), livro["cor"])
		var faixa_dourada := minf(2.0, h * 0.04)
		_retangulo(x + l * 0.15, apoio + h * 0.13, l * 0.7, faixa_dourada, frente, Color("ac9566"))
		_retangulo(x + l * 0.15, apoio + h * 0.82, l * 0.7, faixa_dourada, frente, Color("ac9566"))


func _mundo(local: Vector3) -> Vector3:
	return _origem + _horizontal * local.x + Vector3(0, 0, local.y) + _frente * local.z


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


func _area_projetada(pontos: PackedVector2Array) -> float:
	var area := 0.0
	var origem := pontos[0]
	for indice in range(1, pontos.size() - 1):
		area += (pontos[indice] - origem).cross(pontos[indice + 1] - origem)
	return area


func _face(locais: Array[Vector3], cor: Color, normal_local: Vector3) -> void:
	var pontos := PackedVector2Array()
	var cores := PackedColorArray()
	var normal := (_horizontal * normal_local.x + Vector3(0, 0, normal_local.y)
		+ _frente * normal_local.z).normalized()
	for local in locais:
		var ponto := _ponto(local.x, local.y, local.z)
		if not ponto.is_finite():
			return
		var mundo := _mundo(local)
		pontos.append(ponto)
		cores.append(_iluminar(cor, mundo, normal))
	if _area_projetada(pontos) <= 0.001:
		return
	for ponto in pontos:
		if not _tem_limites:
			_limites = Rect2(ponto, Vector2.ZERO)
			_tem_limites = true
		_limites = _limites.expand(ponto)
	_faces.append({"pontos": pontos, "cores": cores})


func _retangulo(x: float, altura: float, largura: float, tamanho_vertical: float,
		frente: float, cor: Color) -> void:
	_face([Vector3(x, altura + tamanho_vertical, frente), Vector3(x + largura, altura + tamanho_vertical, frente),
		Vector3(x + largura, altura, frente), Vector3(x, altura, frente)], cor, Vector3(0, 0, 1))


func _caixa(origem: Vector3, tamanho: Vector3, cor: Color) -> void:
	var a := origem
	var b := origem + tamanho
	_face([Vector3(a.x, b.y, b.z), b, Vector3(b.x, a.y, b.z), Vector3(a.x, a.y, b.z)], cor, Vector3(0, 0, 1))
	_face([Vector3(b.x, b.y, a.z), Vector3(a.x, b.y, a.z), a, Vector3(b.x, a.y, a.z)], cor, Vector3(0, 0, -1))
	_face([Vector3(a.x, a.y, b.z), a, Vector3(a.x, b.y, a.z), Vector3(a.x, b.y, b.z)], cor, Vector3(-1, 0, 0))
	_face([Vector3(b.x, a.y, a.z), Vector3(b.x, a.y, b.z), b, Vector3(b.x, b.y, a.z)], cor, Vector3(1, 0, 0))
	_face([Vector3(a.x, b.y, a.z), Vector3(b.x, b.y, a.z), b, Vector3(a.x, b.y, b.z)], cor, Vector3(0, 1, 0))
	_face([a, Vector3(a.x, a.y, b.z), Vector3(b.x, a.y, b.z), Vector3(b.x, a.y, a.z)], cor, Vector3(0, -1, 0))


func _iluminar(cor: Color, ponto: Vector3, normal: Vector3) -> Color:
	var direcao := Vector3(-0.35, 0.4, 1).normalized()
	var volume := 1.0 - _contraste * (1.0 - maxf(normal.dot(direcao), 0.0)) * 0.8
	var ambiente := float(_luz.get("ambiente", 100.0)) / 100.0
	var energia := Vector3.ONE * ambiente * volume
	if bool(_luz.get("ativa", false)):
		var posicao: Vector3 = _luz["posicao"]
		var diferenca := posicao - ponto
		var alcance := maxf(float(_luz.get("alcance", 800.0)), 1.0)
		var atenuacao := exp(-2.0 * diferenca.length_squared() / (alcance * alcance))
		var incidencia := 0.15 + 0.85 * maxf(normal.dot(diferenca.normalized()), 0.0)
		var tom: Color = _luz.get("cor", Color("ffc16b"))
		energia += Vector3(tom.r, tom.g, tom.b) * float(_luz.get("intensidade", 100.0)) / 100.0 * atenuacao * incidencia
	return Color(cor.r * energia.x, cor.g * energia.y, cor.b * energia.z, cor.a)


func obter_limites() -> Rect2:
	return _limites


func _draw() -> void:
	for face in _faces:
		draw_polygon(face["pontos"], face["cores"])
