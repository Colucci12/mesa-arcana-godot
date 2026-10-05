extends Node2D

var _faces: Array[Dictionary] = []
var _origem := Vector3.ZERO
var _tamanho := 1.0
var _projetar: Callable
var _limites_janela := Rect2()
var _janela_visivel := false


func configurar(ajustes: Dictionary, tamanho_plano: Vector2, projetar: Callable) -> void:
	_faces.clear()
	_janela_visivel = false
	_projetar = projetar
	_tamanho = float(ajustes["tamanho"])
	_origem = Vector3(tamanho_plano.x / 2.0 + tamanho_plano.x * float(ajustes["x"]) / 100.0,
		-float(ajustes["distancia"]), -350.0 - tamanho_plano.y * float(ajustes["y"]) / 100.0)
	_retangulo(Rect2(-1500, -650, 3000, 1500), Color("202928"))
	for linha in range(13):
		var y := -650.0 + linha * 120.0
		_retangulo(Rect2(-1500, y, 3000, 3), Color("17201f"))
		for coluna in range(12):
			var x := -1500.0 + coluna * 270.0 + (135.0 if linha % 2 == 0 else 0.0)
			_retangulo(Rect2(x, y, 2, 120), Color("17201f"))
	var janela := PackedVector2Array([Vector2(-145, -65), Vector2(-145, -265),
		Vector2(-85, -320), Vector2(0, -345), Vector2(85, -320),
		Vector2(145, -265), Vector2(145, -65)])
	var moldura := PackedVector2Array()
	for ponto in janela:
		moldura.append(Vector2(ponto.x * 1.08, (ponto.y + 205) * 1.08 - 205))
	_face(moldura, Color("35443d"))
	var abertura := _face(janela, Color("123e3c"))
	if not abertura.is_empty():
		_limites_janela = Rect2(abertura[0], Vector2.ZERO)
		for ponto in abertura:
			_limites_janela = _limites_janela.expand(ponto)
		_janela_visivel = true
	# Lua e caixilho pertencem ao mesmo plano vertical da parede.
	var lua := PackedVector2Array()
	var recorte := PackedVector2Array()
	for indice in range(32):
		var angulo := TAU * indice / 32.0
		lua.append(Vector2(70, -272) + Vector2(cos(angulo), sin(angulo)) * 22)
		recorte.append(Vector2(79, -279) + Vector2(cos(angulo), sin(angulo)) * 20)
	_face(lua, Color("789e88"))
	_face(recorte, Color("123e3c"))
	_retangulo(Rect2(-4, -340, 8, 275), Color("35443d"))
	_retangulo(Rect2(-145, -214, 290, 8), Color("35443d"))
	_retangulo(Rect2(-172, -68, 344, 18), Color("475044"))
	visible = bool(ajustes["visivel"])
	var claridade := float(ajustes["claridade"]) / 100.0
	modulate = Color(claridade, claridade, claridade, 1)
	queue_redraw()


func _face(locais: PackedVector2Array, cor: Color) -> PackedVector2Array:
	var pontos := PackedVector2Array()
	for local in locais:
		var ponto: Vector2 = _projetar.call(_origem + Vector3(local.x * 2.0, 0, -local.y * 1.4) * _tamanho)
		if not ponto.is_finite():
			return PackedVector2Array()
		pontos.append(ponto)
	_faces.append({"pontos": pontos, "cor": cor})
	return pontos


func _retangulo(area: Rect2, cor: Color) -> void:
	_face(PackedVector2Array([area.position, area.position + Vector2(area.size.x, 0),
		area.end, area.position + Vector2(0, area.size.y)]), cor)


func obter_limites_janela() -> Rect2:
	return _limites_janela if _janela_visivel else Rect2()


func _draw() -> void:
	for face in _faces:
		draw_colored_polygon(face["pontos"], face["cor"])
