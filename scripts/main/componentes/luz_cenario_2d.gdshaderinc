// Campos opcionais do cenário, desativados nos materiais do jogo por padrão.
// Manter igual a MAXIMO em interno/luz_cenario_2d.gd.
#define MAXIMO_FONTES_CENARIO 48
uniform bool cenario_ativo = false;
uniform float cenario_ambiente = 1.0;
uniform vec3 cenario_transform_x = vec3(1.0, 0.0, 0.0);
uniform vec3 cenario_transform_y = vec3(0.0, 1.0, 0.0);
uniform int cenario_quantidade = 0;
uniform vec4 cenario_posicoes[MAXIMO_FONTES_CENARIO];
uniform vec4 cenario_cores[MAXIMO_FONTES_CENARIO];
uniform vec4 cenario_ajustes[MAXIMO_FONTES_CENARIO];
uniform vec4 cenario_detalhes[MAXIMO_FONTES_CENARIO];

float campo_cenario(vec2 cena, int i) {
	vec2 d = cena - cenario_posicoes[i].xy;
	vec4 ajuste = cenario_ajustes[i];
	d = vec2(ajuste.x * d.x + ajuste.y * d.y, -ajuste.y * d.x + ajuste.x * d.y);
	float distancia = length(d / cenario_posicoes[i].zw);
	return 1.0 - smoothstep(1.0 - ajuste.z, 1.0, distancia);
}

vec4 luzes_cenario(vec2 posicao) {
	vec3 p = vec3(posicao, 1.0);
	vec2 cena = vec2(dot(cenario_transform_x, p), dot(cenario_transform_y, p));
	vec3 energia = vec3(0.0);
	float sombra = 1.0;
	for (int i = 0; i < MAXIMO_FONTES_CENARIO; i++) {
		if (i >= cenario_quantidade) { break; }
		vec4 ajuste = cenario_ajustes[i];
		if (ajuste.w > 1.5) { continue; }
		float campo = campo_cenario(cena, i);
		if (ajuste.w > 0.5) {
			sombra *= 1.0 - clamp(campo * cenario_cores[i].a, 0.0, 1.0);
		} else {
			energia += campo * cenario_cores[i].a * cenario_cores[i].rgb;
		}
	}
	return vec4(energia, sombra);
}

vec3 brilhos_cenario(vec3 original, vec2 posicao) {
	vec3 p = vec3(posicao, 1.0);
	vec2 cena = vec2(dot(cenario_transform_x, p), dot(cenario_transform_y, p));
	vec3 brilho = vec3(0.0);
	float detalhe = dot(clamp(original, vec3(0.0), vec3(1.0)), vec3(0.2126, 0.7152, 0.0722));
	for (int i = 0; i < MAXIMO_FONTES_CENARIO; i++) {
		if (i >= cenario_quantidade) { break; }
		if (cenario_ajustes[i].w < 1.5) { continue; }
		float campo = campo_cenario(cena, i);
		campo = pow(campo, mix(1.0, 8.0, cenario_detalhes[i].x));
		float material = mix(1.0, detalhe, cenario_detalhes[i].y);
		brilho += cenario_cores[i].rgb * cenario_cores[i].a * campo * material;
	}
	return brilho;
}
