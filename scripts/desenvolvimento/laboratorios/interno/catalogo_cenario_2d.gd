extends RefCounted

const PASTA := "res://images/teste_ambiente/"
const LUZ = preload("res://scripts/desenvolvimento/laboratorios/interno/luz_cenario_2d.gd")
const CHAMAS = preload("res://scripts/desenvolvimento/laboratorios/interno/chamas_cenario_2d.gd")

# Os recortes são regiões das texturas originais; nenhum PNG é modificado.
const PECAS := [
	{"nome": "Background", "arquivo": "fundo.png", "recorte": [0, 0, 1672, 941]},
	{"nome": "Estante esquerda", "arquivo": "esquerda.png", "recorte": [0, 0, 1086, 1448]},
	{"nome": "Estante direita", "arquivo": "direita.png", "recorte": [0, 0, 1086, 1448]},
	{"nome": "Mesa", "arquivo": "mesa.png", "recorte": [0, 200, 1448, 740]},
	{"nome": "Vela curta", "arquivo": "velas.png", "recorte": [145, 175, 185, 280]},
	{"nome": "Vela com alça", "arquivo": "velas.png", "recorte": [390, 120, 290, 335]},
	{"nome": "Vela alta simples", "arquivo": "velas.png", "recorte": [720, 25, 245, 435]},
	{"nome": "Vela em taça", "arquivo": "velas.png", "recorte": [1060, 10, 220, 460]},
	{"nome": "Vela alta derretida", "arquivo": "velas.png", "recorte": [140, 470, 235, 580]},
	{"nome": "Vela com castiçal", "arquivo": "velas.png", "recorte": [465, 455, 240, 600]},
	{"nome": "Vela torcida", "arquivo": "velas.png", "recorte": [790, 570, 235, 480]},
	{"nome": "Vela com lua", "arquivo": "velas.png", "recorte": [1105, 660, 240, 410]},
	{"nome": "Tigela e magia", "arquivo": "tigela.png", "recorte": [0, 0, 1254, 1254]},
	{"nome": "Esfera armilar grande", "arquivo": "ornamentos.png", "recorte": [0, 0, 495, 610]},
	{"nome": "Esfera armilar pequena", "arquivo": "ornamentos.png", "recorte": [480, 155, 265, 370]},
	{"nome": "Ornamento solar", "arquivo": "ornamentos.png", "recorte": [725, 40, 265, 315]},
	{"nome": "Hera curta", "arquivo": "heras.png", "recorte": [10, 15, 335, 175]},
	{"nome": "Hera pendente", "arquivo": "heras.png", "recorte": [15, 190, 195, 440]},
	{"nome": "Hera horizontal", "arquivo": "heras.png", "recorte": [100, 920, 1280, 160]},
	{"nome": "Folha de velas completa", "arquivo": "velas.png", "recorte": [0, 0, 1448, 1086]},
	{"nome": "Folha de ornamentos completa", "arquivo": "ornamentos.png", "recorte": [0, 0, 1448, 1086]},
	{"nome": "Folha de heras completa", "arquivo": "heras.png", "recorte": [0, 0, 1448, 1086]},
	{"nome": "Chão", "arquivo": "chao.png", "recorte": [0, 0, 1672, 941]},
	{"nome": "Janela", "arquivo": "janela.png", "recorte": [0, 0, 1448, 1086]},
]

const LIMITES := {
	"x": Vector2(-2560, 3840), "y": Vector2(-1440, 2160),
	"largura": Vector2(5, 4000), "altura": Vector2(5, 4000),
	"giro": Vector2(-180, 180), "camada": Vector2(-100, 100),
}


static func criar(indice: int, id: int) -> Dictionary:
	var modelo: Dictionary = PECAS[clampi(indice, 0, PECAS.size() - 1)]
	var recorte: Array = modelo["recorte"].duplicate()
	var aparencia := LUZ.validar_peca({}, modelo["arquivo"] == "mesa.png")
	return {"id": id, "nome": modelo["nome"], "arquivo": modelo["arquivo"],
		"recorte": recorte, "x": 640.0, "y": 360.0, "largura": 180.0,
		"altura": 180.0 * float(recorte[3]) / float(recorte[2]), "giro": 0.0,
		"camada": 20.0, "visivel": true, "travada": false, "espelhar": false,
		"proporcional": true, "aparencia": aparencia, "chamas": [],
		"cantos": [[0.0, 0.0], [1.0, 0.0], [1.0, 1.0], [0.0, 1.0]]}


static func composicao_inicial() -> Array[Dictionary]:
	var resultado: Array[Dictionary] = []
	var disposicao := [
		[0, 640, 360, 1280, 720, -50],
		[1, 135, 265, 510, 680, -20],
		[2, 1145, 265, 510, 680, -20],
		[3, 640, 490, 1180, 440, 0],
	]
	for valores in disposicao:
		var peca := criar(int(valores[0]), resultado.size() + 1)
		peca["x"] = float(valores[1])
		peca["y"] = float(valores[2])
		peca["largura"] = float(valores[3])
		peca["altura"] = float(valores[4])
		peca["camada"] = float(valores[5])
		peca["travada"] = valores[0] == 0
		resultado.append(peca)
	return resultado


static func cantos_validos(cantos: Array) -> bool:
	if cantos.size() != 4:
		return false
	var pontos := PackedVector2Array()
	for canto in cantos:
		if not canto is Array or canto.size() != 2:
			return false
		for valor in canto:
			if not (valor is float or valor is int) or not is_finite(float(valor)):
				return false
		pontos.append(Vector2(float(canto[0]), float(canto[1])))
	# Convexo e com a orientação original: impede cantos cruzados e projeções singulares.
	for i in range(4):
		if (pontos[(i + 1) % 4] - pontos[i]).cross(pontos[(i + 2) % 4] - pontos[(i + 1) % 4]) < 0.01:
			return false
	return true


static func validar(dados: Variant) -> Dictionary:
	if not dados is Dictionary:
		return {}
	var indice := -1
	for i in range(PECAS.size()):
		if PECAS[i]["arquivo"] == dados.get("arquivo"):
			indice = i
			break
	if indice < 0:
		return {}
	var peca := criar(indice, 0)
	peca["chamas"] = CHAMAS.validar(dados.get("chamas"))
	peca["aparencia"] = LUZ.validar_peca(dados.get("aparencia"), peca["arquivo"] == "mesa.png")
	if dados.get("id") is float or dados.get("id") is int:
		peca["id"] = int(dados["id"])
	if dados.get("nome") is String:
		peca["nome"] = dados["nome"].left(100)
	for chave in LIMITES:
		var valor: Variant = dados.get(chave)
		if (valor is float or valor is int) and is_finite(float(valor)):
			var limite: Vector2 = LIMITES[chave]
			peca[chave] = clampf(float(valor), limite.x, limite.y)
	for chave in ["visivel", "travada", "espelhar", "proporcional"]:
		if dados.get(chave) is bool:
			peca[chave] = dados[chave]
	var recorte: Variant = dados.get("recorte")
	if recorte is Array and recorte.size() == 4:
		var valido := true
		for valor in recorte:
			if not (valor is float or valor is int) or not is_finite(float(valor)):
				valido = false
		if valido:
			peca["recorte"] = [maxf(0, float(recorte[0])), maxf(0, float(recorte[1])),
				maxf(1, float(recorte[2])), maxf(1, float(recorte[3]))]
	var cantos: Variant = dados.get("cantos")
	if cantos is Array and cantos_validos(cantos):
		peca["cantos"] = cantos.duplicate(true)
	return peca
