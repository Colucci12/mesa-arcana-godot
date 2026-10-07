extends RefCounted

# Manter igual a MAXIMO_FONTES_CENARIO em luz_cenario_2d.gdshaderinc.
const MAXIMO := 48
# Alvo separado: não ocupa nem reutiliza os IDs das peças da composição.
const ALVO_ORNAMENTO := -2
const PADRAO_PECA := {"claridade": 100.0, "contraste": 100.0, "saturacao": 100.0, "mesa": false}
const LIMITES_PECA := {"claridade": Vector2(0, 150), "contraste": Vector2(0, 200), "saturacao": Vector2(0, 200)}
const LIMITES := {"x": Vector2(-2560, 3840), "y": Vector2(-1440, 2160),
	"largura": Vector2(10, 3000), "altura": Vector2(10, 2000), "giro": Vector2(-180, 180),
	"intensidade": Vector2(0, 200), "suavidade": Vector2(1, 100)}
const LIMITES_BRILHO := {"concentracao": Vector2(0, 100), "material": Vector2(0, 100)}
const LIMITES_HALO := {"halo_x": Vector2(-2000, 2000), "halo_y": Vector2(-2000, 2000),
	"halo_largura": Vector2(5, 1200), "halo_altura": Vector2(5, 1200),
	"halo_giro": Vector2(-180, 180), "halo_intensidade": Vector2(0, 100),
	"halo_camada": Vector2(-100, 150)}


static func padrao() -> Dictionary:
	return {"ativa": true, "fontes": []}


static func fonte(sombra: bool = false) -> Dictionary:
	return {"nome": "Sombra de contato" if sombra else "Ponto de luz", "sombra": sombra, "brilho": false,
		"visivel": true, "x": 640.0, "y": 360.0, "largura": 400.0,
		"altura": 80.0 if sombra else 400.0, "giro": 0.0,
		"intensidade": 40.0, "suavidade": 100.0, "cor": [1.0, 0.67, 0.32],
		"todas": true, "alvos": [], "cartas": not sombra, "ornamento": false,
		"concentracao": 70.0, "material": 70.0,
		"halo_ativo": false, "halo_x": 0.0, "halo_y": 0.0, "halo_largura": 120.0,
		"halo_altura": 120.0, "halo_giro": 0.0, "halo_intensidade": 30.0,
		"halo_cor": [1.0, 0.60, 0.20], "halo_camada": 30.0}


static func brilho() -> Dictionary:
	var f := fonte()
	f["brilho"] = true
	f["nome"] = "Brilho de superfície"
	f["altura"] = 40.0
	f["intensidade"] = 80.0
	f["todas"] = false
	f["cartas"] = false
	return f


static func numeros(dados: Variant, base: Dictionary, limites: Dictionary) -> Dictionary:
	var resultado := base.duplicate(true)
	if dados is Dictionary:
		for chave in limites:
			var valor: Variant = dados.get(chave)
			if (valor is float or valor is int) and is_finite(float(valor)):
				var faixa: Vector2 = limites[chave]
				resultado[chave] = clampf(float(valor), faixa.x, faixa.y)
	return resultado


static func validar_peca(dados: Variant, mesa: bool = false) -> Dictionary:
	var resultado := numeros(dados, PADRAO_PECA, LIMITES_PECA)
	resultado["mesa"] = dados.get("mesa", mesa) if dados is Dictionary and dados.get("mesa", mesa) is bool else mesa
	return resultado


static func validar(dados: Variant) -> Dictionary:
	var resultado := padrao()
	if not dados is Dictionary:
		return resultado
	if dados.get("ativa") is bool:
		resultado["ativa"] = dados["ativa"]
	if dados.get("fontes") is Array:
		for entrada in dados["fontes"]:
			if not entrada is Dictionary or resultado["fontes"].size() >= MAXIMO:
				continue
			var f := numeros(entrada, fonte(), LIMITES)
			f = numeros(entrada, f, LIMITES_HALO)
			f = numeros(entrada, f, LIMITES_BRILHO)
			for chave in ["sombra", "brilho", "visivel", "todas", "cartas", "ornamento", "halo_ativo"]:
				if entrada.get(chave) is bool:
					f[chave] = entrada[chave]
			if entrada.get("nome") is String:
				f["nome"] = entrada["nome"].left(100)
			if bool(f["sombra"]):
				f["brilho"] = false
			for chave in ["cor", "halo_cor"]:
				var cor: Variant = entrada.get(chave)
				if cor is Array and cor.size() == 3:
					for i in range(3):
						if (cor[i] is float or cor[i] is int) and is_finite(float(cor[i])):
							f[chave][i] = clampf(float(cor[i]), 0, 1)
			if entrada.get("alvos") is Array:
				for id in entrada["alvos"]:
					if (id is float or id is int) and is_finite(float(id)) and int(id) > 0:
						f["alvos"].append(int(id))
			resultado["fontes"].append(f)
	return resultado


static func enviar(material: ShaderMaterial, dados: Dictionary, alvo: int,
		transformacao: Transform2D = Transform2D.IDENTITY, claridade: float = 100.0) -> void:
	material.set_shader_parameter("cenario_ativo", bool(dados["ativa"]))
	material.set_shader_parameter("cenario_ambiente", claridade / 100.0)
	material.set_shader_parameter("cenario_transform_x", Vector3(transformacao.x.x, transformacao.y.x, transformacao.origin.x))
	material.set_shader_parameter("cenario_transform_y", Vector3(transformacao.x.y, transformacao.y.y, transformacao.origin.y))
	var posicoes := PackedVector4Array()
	var cores := PackedVector4Array()
	var ajustes := PackedVector4Array()
	var detalhes := PackedVector4Array()
	for f in dados["fontes"]:
		if not bool(f["visivel"]):
			continue
		if alvo == -1:
			if not bool(f["cartas"]):
				continue
		elif alvo == ALVO_ORNAMENTO:
			if not bool(f["todas"]) and not bool(f.get("ornamento", false)):
				continue
		elif not bool(f["todas"]) and not f["alvos"].has(alvo):
			continue
		posicoes.append(Vector4(float(f["x"]), float(f["y"]), float(f["largura"]) / 2.0, float(f["altura"]) / 2.0))
		var cor: Array = f["cor"]
		cores.append(Vector4(float(cor[0]), float(cor[1]), float(cor[2]), float(f["intensidade"]) / 100.0))
		var angulo := deg_to_rad(float(f["giro"]))
		var tipo := 1.0 if bool(f["sombra"]) else (2.0 if bool(f["brilho"]) else 0.0)
		ajustes.append(Vector4(cos(angulo), sin(angulo), float(f["suavidade"]) / 100.0, tipo))
		detalhes.append(Vector4(float(f["concentracao"]) / 100.0, float(f["material"]) / 100.0, 0, 0))
	material.set_shader_parameter("cenario_quantidade", posicoes.size())
	posicoes.resize(MAXIMO)
	cores.resize(MAXIMO)
	ajustes.resize(MAXIMO)
	detalhes.resize(MAXIMO)
	material.set_shader_parameter("cenario_posicoes", posicoes)
	material.set_shader_parameter("cenario_cores", cores)
	material.set_shader_parameter("cenario_ajustes", ajustes)
	material.set_shader_parameter("cenario_detalhes", detalhes)
