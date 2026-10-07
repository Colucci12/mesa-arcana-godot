extends RefCounted

const REFERENCIA := Vector2(1280, 720)


static func matriz(mesa: MesaVisual, ponto: Vector3, eixo_u: Vector3, eixo_v: Vector3,
		camera: Dictionary = {}) -> Basis:
	var profundidade := mesa.tamanho_plano.y
	var aparente := float(camera.get("profundidade_camera", mesa.profundidade_aparente))
	var cosseno := aparente / profundidade
	var seno := sqrt(1.0 - cosseno * cosseno)
	var distante := float(camera.get("perspectiva", mesa.largura_distante * 100.0)) / 100.0
	var py := (1.0 - distante) / profundidade
	var pz := py * cosseno / seno
	var origem := mesa.position - Vector2(0, aparente / 2.0)
	var denominador := Vector3(-py * eixo_u.y - pz * eixo_u.z,
		-py * eixo_v.y - pz * eixo_v.z, 1.0 - py * ponto.y - pz * ponto.z)
	var x := distante * Vector3(eixo_u.x, eixo_v.x, ponto.x - mesa.largura_proxima / 2.0) + origem.x * denominador
	var y := distante * Vector3(cosseno * eixo_u.y - seno * eixo_u.z,
		cosseno * eixo_v.y - seno * eixo_v.z, cosseno * ponto.y - seno * ponto.z) + origem.y * denominador
	return Basis(Vector3(x.x, y.x, denominador.x), Vector3(x.y, y.y, denominador.y),
		Vector3(x.z, y.z, denominador.z))


static func ponto_sala(mesa: MesaVisual, ponto: Vector3, camera: Dictionary = {}) -> Vector2:
	var q := matriz(mesa, ponto, Vector3.RIGHT, Vector3.UP, camera) * Vector3(0, 0, 1)
	if q.z <= 0.001:
		return Vector2(NAN, NAN)
	return Vector2(q.x, q.y) / q.z + REFERENCIA * Vector2(0.5, 0.55) - mesa.position


static func posicao_camera(mesa: MesaVisual, camera: Dictionary = {}) -> Vector3:
	var cosseno := float(camera.get("profundidade_camera", mesa.profundidade_aparente)) / mesa.tamanho_plano.y
	var seno := sqrt(1.0 - cosseno * cosseno)
	var distante := float(camera.get("perspectiva", mesa.largura_distante * 100.0)) / 100.0
	var py := maxf((1.0 - distante) / mesa.tamanho_plano.y, 0.000001)
	return Vector3(mesa.largura_proxima / 2.0, seno * seno / py, seno * cosseno / py)
