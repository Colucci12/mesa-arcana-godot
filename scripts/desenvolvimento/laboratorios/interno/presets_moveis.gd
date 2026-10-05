extends RefCounted

const ARQUIVO := "user://laboratorio_moveis.json"
const PADRAO_CAMERA := {"profundidade_camera": 200.0, "perspectiva": 50.0}
const LIMITES_CAMERA := {"profundidade_camera": Vector2(60, 650), "perspectiva": Vector2(35, 100)}
const PADRAO := {"visivel": true, "livros": true, "verticais_retas": false,
	"x": -1100.0, "distancia": 500.0, "altura_base": -350.0, "largura": 600.0,
	"altura": 600.0, "angulo": -35.0, "inclinacao": 0.0, "claridade": 75.0, "profundidade": 180.0,
	"espessura": 24.0, "contraste": 40.0, "cor_estrutura": "766249", "cor_fundo": "1a2421",
	"prateleiras": 3.0, "quantidade_livros": 20.0, "largura_livros": 20.0,
	"altura_livros": 160.0, "profundidade_livros": 90.0, "ocupacao_livros": 85.0}
const LIMITES := {"x": Vector2(-2200, 2200), "distancia": Vector2(0, 2400),
	"altura_base": Vector2(-1200, 400), "largura": Vector2(200, 4000), "altura": Vector2(200, 4000),
	"angulo": Vector2(-75, 75), "inclinacao": Vector2(-180, 180),
	"claridade": Vector2(0, 100), "profundidade": Vector2(40, 600),
	"espessura": Vector2(4, 100), "contraste": Vector2(0, 100), "prateleiras": Vector2(1, 16),
	"quantidade_livros": Vector2(0, 120), "largura_livros": Vector2(5, 100),
	"altura_livros": Vector2(40, 400), "profundidade_livros": Vector2(10, 300),
	"ocupacao_livros": Vector2(10, 100)}


static func validar_camera(dados: Variant, referencia: Dictionary = {}) -> Dictionary:
	var camera := PADRAO_CAMERA.duplicate()
	# Composições antigas recuperam a câmera da mesa uma vez, sem vínculo posterior.
	for origem in [referencia, dados]:
		if not origem is Dictionary:
			continue
		for chave in LIMITES_CAMERA:
			var valor: Variant = origem.get(chave)
			if (valor is float or valor is int) and is_finite(float(valor)):
				var limites: Vector2 = LIMITES_CAMERA[chave]
				camera[chave] = clampf(float(valor), limites.x, limites.y)
	return camera


static func padrao(indice: int) -> Dictionary:
	var ajustes := PADRAO.duplicate()
	if indice == 1:
		ajustes["x"] = -float(ajustes["x"])
		ajustes["angulo"] = -float(ajustes["angulo"])
	return ajustes


static func validar(dados: Variant, indice: int = 0) -> Dictionary:
	var ajustes := padrao(indice)
	if not dados is Dictionary:
		return ajustes
	for chave in LIMITES:
		var valor: Variant = dados.get(chave)
		if (valor is float or valor is int) and is_finite(float(valor)):
			ajustes[chave] = clampf(float(valor), LIMITES[chave].x, LIMITES[chave].y)
	for chave in ["visivel", "livros", "verticais_retas"]:
		if dados.get(chave) is bool:
			ajustes[chave] = dados[chave]
	for chave in ["prateleiras", "quantidade_livros"]:
		ajustes[chave] = float(roundi(ajustes[chave]))
	for chave in ["cor_estrutura", "cor_fundo"]:
		if dados.get(chave) is String and Color.html_is_valid(dados[chave]):
			ajustes[chave] = Color.html(dados[chave]).to_html(false)
	return ajustes


static func aplicar_movel(dados: Variant, atual: Dictionary, indice: int) -> Dictionary:
	var ajustes := validar(dados, indice)
	# Carregar uma estrutura não desloca o móvel já colocado na composição.
	for chave in ["x", "distancia", "altura_base", "angulo", "inclinacao", "visivel"]:
		ajustes[chave] = atual[chave]
	return ajustes


static func ler(grupo: String) -> Dictionary:
	if not FileAccess.file_exists(ARQUIVO):
		return {}
	var dados: Variant = JSON.parse_string(FileAccess.get_file_as_string(ARQUIVO))
	if dados is Dictionary and dados.get(grupo) is Dictionary:
		return dados[grupo].duplicate(true)
	return {}


static func salvar(grupo: String, nome: String, perfil: Dictionary) -> Error:
	var dados: Dictionary = {}
	if FileAccess.file_exists(ARQUIVO):
		var anteriores: Variant = JSON.parse_string(FileAccess.get_file_as_string(ARQUIVO))
		if not anteriores is Dictionary:
			return ERR_FILE_CORRUPT
		dados = anteriores
	if not dados.get(grupo) is Dictionary:
		dados[grupo] = {}
	dados[grupo][nome] = perfil.duplicate(true)
	var arquivo := FileAccess.open(ARQUIVO, FileAccess.WRITE)
	if arquivo == null:
		return FileAccess.get_open_error()
	arquivo.store_string(JSON.stringify(dados, "\t"))
	arquivo.flush()
	return arquivo.get_error()
