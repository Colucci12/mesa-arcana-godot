extends RefCounted

# Mesmo limite das áreas ocultas em asset_cenario_2d.gdshader.
const MAXIMO := 16
const TEXTURA = preload("res://images/ambiente/chamas.png")
const SHADER = preload("res://scripts/main/cenario/chama_cenario.gdshader")
const TAMANHO_QUADRO := Vector2(240, 400)
# A folha não tem espaçamento regular. Recortes e bases alinham os oito desenhos pelo pavio.
const QUADROS: Array[Vector4] = [Vector4(211, 77, 176, 345), Vector4(603, 40, 199, 381),
	Vector4(1013, 83, 184, 338), Vector4(1424, 99, 191, 322),
	Vector4(211, 495, 184, 328), Vector4(602, 449, 190, 374),
	Vector4(1012, 501, 196, 322), Vector4(1428, 518, 182, 304)]
const BASES: Array[Vector2] = [Vector2(88.30, 342), Vector2(90.65, 378), Vector2(86.64, 335),
	Vector2(85.68, 319), Vector2(87.55, 325), Vector2(93.66, 371),
	Vector2(90.31, 319), Vector2(81.72, 301)]
const LIMITES := {"x": Vector2(-25, 125), "y": Vector2(-25, 125),
	"largura": Vector2(0.1, 100), "altura": Vector2(0.1, 100), "giro": Vector2(-180, 180),
	"velocidade": Vector2(1, 24), "fase": Vector2(0, 100), "quadro": Vector2(1, 8),
	"brilho": Vector2(0, 200), "corte_x": Vector2(-25, 125), "corte_y": Vector2(-25, 125),
	"corte_largura": Vector2(0.1, 100), "corte_altura": Vector2(0.1, 100)}
const FOGOS_VELAS: Array[Rect2] = [Rect2(190, 172, 96, 127), Rect2(476, 118, 74, 134),
	Rect2(776, 23, 109, 184), Rect2(1120, 9, 90, 145),
	Rect2(228, 464, 84, 137), Rect2(546, 455, 79, 116),
	Rect2(860, 568, 79, 128), Rect2(1180, 657, 77, 135)]
const PAVIOS_VELAS: Array[Vector2] = [Vector2(236, 296), Vector2(512, 248), Vector2(829, 199),
	Vector2(1163, 150), Vector2(264, 596), Vector2(583, 561), Vector2(900, 688), Vector2(1218, 786)]


static func padrao() -> Dictionary:
	return {"nome": "Chama", "visivel": true, "animada": true, "suave": true,
		"ocultar": false, "x": 50.0, "y": 25.0, "largura": 6.0, "altura": 12.0,
		"giro": 0.0, "velocidade": 8.0, "fase": 0.0, "quadro": 1.0, "brilho": 100.0,
		"corte_x": 50.0, "corte_y": 20.0, "corte_largura": 4.0, "corte_altura": 8.0}


static func nova(peca: Dictionary) -> Dictionary:
	var chama := padrao()
	var quantidade: int = peca["chamas"].size()
	chama["nome"] = "Chama %d" % (quantidade + 1)
	chama["fase"] = float((int(peca["id"]) * 17 + quantidade * 43) % 100)
	if peca["arquivo"] != "velas.png":
		return chama
	var r: Array = peca["recorte"]
	var recorte := Rect2(Vector2(r[0], r[1]), Vector2(r[2], r[3]))
	var candidatas: Array[int] = []
	for indice in range(FOGOS_VELAS.size()):
		if recorte.has_point(PAVIOS_VELAS[indice]):
			candidatas.append(indice)
	if candidatas.is_empty():
		return chama
	var indice := candidatas[quantidade % candidatas.size()]
	var pavio: Vector2 = (PAVIOS_VELAS[indice] - recorte.position) / recorte.size * 100.0
	var corte: Rect2 = FOGOS_VELAS[indice].intersection(recorte)
	var centro: Vector2 = (corte.get_center() - recorte.position) / recorte.size * 100.0
	var tamanho: Vector2 = corte.size / recorte.size * 100.0
	chama.merge({"x": pavio.x, "y": pavio.y, "largura": maxf(tamanho.x * 1.15, 1),
		"altura": maxf(tamanho.y * 1.05, 1), "ocultar": true, "corte_x": centro.x,
		"corte_y": centro.y, "corte_largura": maxf(tamanho.x, 1), "corte_altura": maxf(tamanho.y, 1)}, true)
	return chama


static func validar(dados: Variant) -> Array[Dictionary]:
	var resultado: Array[Dictionary] = []
	if not dados is Array:
		return resultado
	for entrada in dados:
		if not entrada is Dictionary or resultado.size() >= MAXIMO:
			continue
		var chama := padrao()
		for chave in LIMITES:
			var valor: Variant = entrada.get(chave)
			if (valor is float or valor is int) and is_finite(float(valor)):
				chama[chave] = clampf(float(valor), LIMITES[chave].x, LIMITES[chave].y)
		for chave in ["visivel", "animada", "suave", "ocultar"]:
			if entrada.get(chave) is bool:
				chama[chave] = entrada[chave]
		if entrada.get("nome") is String:
			chama["nome"] = entrada["nome"].left(100)
		resultado.append(chama)
	return resultado


static func configurar(material: ShaderMaterial, chama: Dictionary) -> void:
	var quadros := PackedVector4Array()
	var bases := PackedVector2Array()
	for indice in range(QUADROS.size()):
		var q: Vector4 = QUADROS[indice]
		# Folga para as bordas semitransparentes, preservando o alinhamento da base.
		quadros.append(Vector4(q.x - 12, q.y - 12, q.z + 24, q.w + 24))
		bases.append(BASES[indice] + Vector2(12, 12))
	material.set_shader_parameter("quadros", quadros)
	material.set_shader_parameter("bases", bases)
	material.set_shader_parameter("tamanho_quadro", TAMANHO_QUADRO)
	for chave in ["animada", "suave", "velocidade", "fase", "quadro"]:
		material.set_shader_parameter(chave, chama[chave])
	material.set_shader_parameter("brilho", float(chama["brilho"]) / 100.0)
