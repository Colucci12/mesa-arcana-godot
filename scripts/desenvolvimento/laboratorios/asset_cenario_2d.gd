extends Node2D

const SHADER = preload("res://scripts/desenvolvimento/laboratorios/asset_cenario_2d.gdshader")
const CATALOGO = preload("res://scripts/desenvolvimento/laboratorios/interno/catalogo_cenario_2d.gd")
const LUZ = preload("res://scripts/desenvolvimento/laboratorios/interno/luz_cenario_2d.gd")

var perfil: Dictionary
var _poligono: Polygon2D
var _material: ShaderMaterial
var _arquivo := ""
var _imagem: Image
var _projecao := Basis.IDENTITY
var _inversa := Basis.IDENTITY
var _recorte := Rect2()


func _preparar_poligono() -> void:
	_poligono = Polygon2D.new()
	_poligono.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_poligono.material = _material
	add_child(_poligono)


func aplicar(dados: Dictionary) -> void:
	perfil = dados
	if _poligono == null:
		_preparar_poligono()
	if _arquivo != str(perfil["arquivo"]):
		_arquivo = str(perfil["arquivo"])
		_poligono.texture = load(CATALOGO.PASTA + _arquivo) as Texture2D
		_imagem = _poligono.texture.get_image()
	var tamanho := _poligono.texture.get_size()
	var r: Array = perfil["recorte"]
	_recorte = Rect2(Vector2(float(r[0]), float(r[1])), Vector2(float(r[2]), float(r[3])))
	_recorte.position = _recorte.position.clamp(Vector2.ZERO, tamanho - Vector2.ONE)
	_recorte.size = _recorte.size.clamp(Vector2.ONE, tamanho - _recorte.position)
	perfil["recorte"] = [_recorte.position.x, _recorte.position.y, _recorte.size.x, _recorte.size.y]
	position = Vector2(float(perfil["x"]), float(perfil["y"]))
	rotation = deg_to_rad(float(perfil["giro"]))
	z_index = roundi(float(perfil["camada"]))
	visible = bool(perfil["visivel"])
	var dimensoes := Vector2(float(perfil["largura"]), float(perfil["altura"]))
	var pontos := PackedVector2Array()
	for canto in perfil["cantos"]:
		pontos.append((Vector2(float(canto[0]), float(canto[1])) - Vector2(0.5, 0.5)) * dimensoes)
	_poligono.polygon = pontos
	_projecao = _homografia(pontos)
	_inversa = _projecao.inverse()
	_material.set_shader_parameter("inversa_x", Vector3(_inversa.x.x, _inversa.y.x, _inversa.z.x))
	_material.set_shader_parameter("inversa_y", Vector3(_inversa.x.y, _inversa.y.y, _inversa.z.y))
	_material.set_shader_parameter("inversa_z", Vector3(_inversa.x.z, _inversa.y.z, _inversa.z.z))
	_material.set_shader_parameter("recorte_uv", Vector4(_recorte.position.x / tamanho.x,
		_recorte.position.y / tamanho.y, _recorte.size.x / tamanho.x, _recorte.size.y / tamanho.y))
	_material.set_shader_parameter("espelhar", bool(perfil["espelhar"]))
	_material.set_shader_parameter("peca_transform_x", Vector3(transform.x.x, transform.y.x, position.x))
	_material.set_shader_parameter("peca_transform_y", Vector3(transform.x.y, transform.y.y, position.y))
	_material.set_shader_parameter("contraste", float(perfil["aparencia"]["contraste"]) / 100.0)
	_material.set_shader_parameter("saturacao", float(perfil["aparencia"]["saturacao"]) / 100.0)


func aplicar_luz(dados: Dictionary, referencia: Node) -> void:
	LUZ.enviar(_material, dados, int(perfil["id"]), Transform2D.IDENTITY, float(perfil["aparencia"]["claridade"]))
	referencia.configurar_luz_mesa(_material, bool(perfil["aparencia"]["mesa"]))


func pontos_na_cena() -> PackedVector2Array:
	var pontos := PackedVector2Array()
	for ponto in _poligono.polygon:
		pontos.append(transform * ponto)
	return pontos


func contem(ponto: Vector2) -> bool:
	var local := transform.affine_inverse() * ponto
	if not Geometry2D.is_point_in_polygon(local, _poligono.polygon):
		return false
	var uv3 := _inversa * Vector3(local.x, local.y, 1)
	var uv := Vector2(uv3.x, uv3.y) / uv3.z
	if bool(perfil["espelhar"]):
		uv.x = 1.0 - uv.x
	var pixel := _recorte.position + uv * _recorte.size
	var x := clampi(int(pixel.x), 0, _imagem.get_width() - 1)
	var y := clampi(int(pixel.y), 0, _imagem.get_height() - 1)
	return _imagem.get_pixel(x, y).a > 0.1


func canto_normalizado(ponto: Vector2) -> Vector2:
	var local := transform.affine_inverse() * ponto
	return local / Vector2(float(perfil["largura"]), float(perfil["altura"])) + Vector2(0.5, 0.5)


func _homografia(p: PackedVector2Array) -> Basis:
	# Mapeia o retângulo da imagem ao quadrilátero sem a emenda diagonal de UV afim.
	var d1 := p[1] - p[2]
	var d2 := p[3] - p[2]
	var d3 := p[0] - p[1] + p[2] - p[3]
	var g := 0.0
	var h := 0.0
	if d3.length_squared() > 0.000001:
		var divisor := d1.cross(d2)
		g = d3.cross(d2) / divisor
		h = d1.cross(d3) / divisor
	var coluna_x := p[1] - p[0] + g * p[1]
	var coluna_y := p[3] - p[0] + h * p[3]
	return Basis(Vector3(coluna_x.x, coluna_x.y, g), Vector3(coluna_y.x, coluna_y.y, h),
		Vector3(p[0].x, p[0].y, 1))
