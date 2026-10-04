extends Node2D

const HALO = preload("res://scripts/desenvolvimento/laboratorios/halo_vela.gdshader")
const COR_ILUMINADA = preload("res://scripts/main/componentes/cor_iluminada_plano.gdshader")

var _ajustes: Dictionary = {}
var _projetar: Callable
var _centro := Vector3.ZERO
var _halo: ColorRect
var _chama: Polygon2D
var _miolo: Polygon2D
var _geometria_valida := false
var _limites := Rect2()


func _ready() -> void:
	var corpo := ShaderMaterial.new()
	corpo.shader = COR_ILUMINADA
	material = corpo
	_halo = ColorRect.new()
	_halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_halo.show_behind_parent = true
	var brilho := ShaderMaterial.new()
	brilho.shader = HALO
	_halo.material = brilho
	add_child(_halo)
	_chama = Polygon2D.new()
	_chama.color = Color("ffb340")
	add_child(_chama)
	_miolo = Polygon2D.new()
	_miolo.color = Color("fff2b0")
	_chama.add_child(_miolo)
	visible = false


func configurar(ajustes: Dictionary, tamanho_plano: Vector2, projetar: Callable) -> void:
	_ajustes = ajustes
	_projetar = projetar
	_centro = Vector3(tamanho_plano.x * float(ajustes["x"]) / 100.0,
		tamanho_plano.y * float(ajustes["y"]) / 100.0, 0)
	visible = bool(ajustes["visivel"])
	var tamanho := float(ajustes["tamanho"])
	_geometria_valida = true
	var origem: Vector2 = _projetar.call(_centro)
	_limites = Rect2(origem, Vector2.ZERO) if origem.is_finite() else Rect2()
	# Oculta a geometria quando um ajuste extremo atravessa o plano da câmera.
	for x in [-32.0, 32.0]:
		for y in [-32.0, 32.0]:
			for z in [0.0, 123.0]:
				var ponto: Vector2 = _projetar.call(_centro + Vector3(x, y, z) * tamanho)
				if not ponto.is_finite():
					_geometria_valida = false
				else:
					_limites = _limites.expand(ponto)
	if not _geometria_valida:
		visible = false
		queue_redraw()
		return
	var topo := _centro + Vector3(0, 0, 80 * tamanho)
	var centro_chama: Vector2 = _projetar.call(topo + Vector3(0, 0, 20 * tamanho))
	var lateral: Vector2 = _projetar.call(topo + Vector3(tamanho, 0, 20 * tamanho))
	var escala := centro_chama.distance_to(lateral)
	_chama.position = centro_chama
	_chama.scale = Vector2.ONE * escala
	_chama.polygon = PackedVector2Array([Vector2(0, -22), Vector2(5, -10), Vector2(9, 1),
		Vector2(6, 10), Vector2(0, 13), Vector2(-7, 8), Vector2(-8, 0), Vector2(-4, -10)])
	_miolo.polygon = PackedVector2Array([Vector2(0, -8), Vector2(4, 3), Vector2(2, 10),
		Vector2(-3, 10), Vector2(-4, 3)])
	var diametro := 130.0 * escala * float(ajustes["halo_tamanho"]) / 100.0
	_halo.position = centro_chama - Vector2.ONE * diametro / 2.0
	_halo.size = Vector2.ONE * diametro
	_halo.visible = bool(ajustes["halo_ativo"]) and float(ajustes["halo_intensidade"]) > 0.0
	if _halo.visible:
		_limites = _limites.merge(Rect2(_halo.position, _halo.size))
	(_halo.material as ShaderMaterial).set_shader_parameter("intensidade", float(ajustes["halo_intensidade"]) / 100.0)
	queue_redraw()


func obter_limites() -> Rect2:
	return _limites


func _anel(raio: float, altura: float) -> PackedVector2Array:
	var pontos := PackedVector2Array()
	for indice in range(32):
		var angulo := TAU * indice / 32.0
		var ponto := _centro + Vector3(cos(angulo) * raio, sin(angulo) * raio, altura)
		pontos.append(_projetar.call(ponto))
	return pontos


func _draw() -> void:
	if _ajustes.is_empty() or not _geometria_valida:
		return
	var tamanho := float(_ajustes["tamanho"])
	draw_colored_polygon(_anel(32 * tamanho, 0), Color(0, 0, 0, 0.20))
	draw_colored_polygon(_anel(29 * tamanho, 3 * tamanho), Color("68411f"))
	draw_colored_polygon(_anel(27 * tamanho, 7 * tamanho), Color("b48242"))
	var superior := _anel(15 * tamanho, 80 * tamanho)
	var pontos_corpo := _anel(15 * tamanho, 8 * tamanho)
	pontos_corpo.append_array(superior)
	# Semicírculos fixos cruzam suas bordas quando a perspectiva desloca o topo
	# lateralmente. A silhueta convexa dos anéis completos acompanha esse deslocamento.
	var corpo := Geometry2D.convex_hull(pontos_corpo)
	# convex_hull repete o primeiro ponto no fim; o desenho fecha o polígono sozinho.
	if corpo.size() > 1:
		corpo.resize(corpo.size() - 1)
	if corpo.size() >= 3:
		draw_colored_polygon(corpo, Color("d6ad68"))
	draw_colored_polygon(superior, Color("f1d698"))
	var pavio: Vector2 = _projetar.call(_centro + Vector3(0, 0, 80 * tamanho))
	var ponta: Vector2 = _projetar.call(_centro + Vector3(0, 0, 89 * tamanho))
	draw_line(pavio, ponta, Color("392419"), 2 * tamanho, true)
