extends Node2D

const SHADER = preload("res://scripts/desenvolvimento/laboratorios/halo_cenario_2d.gdshader")

var _halos: Array[Polygon2D] = []


func atualizar(dados: Dictionary) -> void:
	visible = bool(dados["ativa"])
	while _halos.size() < dados["fontes"].size():
		var poligono := Polygon2D.new()
		var material := ShaderMaterial.new()
		material.shader = SHADER
		poligono.material = material
		add_child(poligono)
		_halos.append(poligono)
	for indice in range(_halos.size()):
		var halo := _halos[indice]
		if indice >= dados["fontes"].size():
			halo.hide()
			continue
		var f: Dictionary = dados["fontes"][indice]
		halo.visible = bool(f["visivel"]) and bool(f["halo_ativo"]) and not bool(f["sombra"]) and not bool(f["brilho"])
		if not halo.visible:
			continue
		halo.position = Vector2(float(f["x"]) + float(f["halo_x"]), float(f["y"]) + float(f["halo_y"]))
		halo.rotation = deg_to_rad(float(f["halo_giro"]))
		halo.z_index = roundi(float(f["halo_camada"]))
		var raios := Vector2(float(f["halo_largura"]), float(f["halo_altura"])) / 2.0
		halo.polygon = PackedVector2Array([Vector2(-raios.x, -raios.y), Vector2(raios.x, -raios.y), raios, Vector2(-raios.x, raios.y)])
		var material := halo.material as ShaderMaterial
		var cor: Array = f["halo_cor"]
		material.set_shader_parameter("raios", raios)
		material.set_shader_parameter("cor", Color(float(cor[0]), float(cor[1]), float(cor[2])))
		material.set_shader_parameter("intensidade", float(f["halo_intensidade"]) / 100.0)
