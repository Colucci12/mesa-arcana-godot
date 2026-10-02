shader_type canvas_item;
render_mode unshaded;

uniform sampler2D textura_origem : filter_linear, repeat_disable;
uniform sampler2D textura_receptor : filter_linear, repeat_disable;
uniform vec3 inversa_x;
uniform vec3 inversa_y;
uniform vec3 inversa_z;
uniform vec3 receptor_x;
uniform vec3 receptor_y;
uniform vec3 receptor_z;
uniform vec4 regiao_origem;
uniform vec4 regiao_receptor;
uniform vec3 altura_plano;
uniform float altura_receptor;
uniform vec2 tamanho_captura;
uniform float intensidade = 0.30;
uniform float suavidade = 2.0;
uniform float suavidade_por_altura = 0.035;
uniform bool fonte_localizada = true;
uniform float altura_fonte = 700.0;
varying vec2 ponto_projetado;

void vertex() {
	ponto_projetado = VERTEX;
}

float silhueta(vec2 uv) {
	if (any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0)))) {
		return 0.0;
	}
	vec2 pixel = regiao_origem.zw / tamanho_captura * 0.5;
	vec2 coordenada = clamp(regiao_origem.xy + uv * regiao_origem.zw,
		regiao_origem.xy + pixel, regiao_origem.xy + regiao_origem.zw - pixel);
	return texture(textura_origem, coordenada).a;
}

void fragment() {
	vec3 ponto = vec3(ponto_projetado, 1.0);
	float denominador = dot(inversa_z, ponto);
	float denominador_receptor = dot(receptor_z, ponto);
	if (abs(denominador) < 0.000001 || abs(denominador_receptor) < 0.000001) {
		discard;
	}
	vec2 uv = vec2(dot(inversa_x, ponto), dot(inversa_y, ponto)) / denominador;
	vec2 receptor = vec2(dot(receptor_x, ponto), dot(receptor_y, ponto)) / denominador_receptor;
	if (any(lessThan(receptor, vec2(0.0))) || any(greaterThan(receptor, vec2(1.0)))) {
		discard;
	}
	float altura_origem = dot(altura_plano, vec3(uv, 1.0));
	float distancia = altura_origem - altura_receptor;
	if (distancia <= 0.01 || (fonte_localizada && altura_origem >= altura_fonte - 0.5)) {
		discard;
	}
	// Recortar no desenho da carta receptora, incluindo suas margens transparentes.
	float alpha_receptor = texture(textura_receptor, regiao_receptor.xy + receptor * regiao_receptor.zw).a;
	vec2 passo = vec2(min(suavidade + distancia * suavidade_por_altura, 20.0)) / tamanho_captura;
	float alpha = silhueta(uv) * 0.20;
	alpha += silhueta(uv + passo * vec2(1.0, 0.0)) * 0.10;
	alpha += silhueta(uv + passo * vec2(-1.0, 0.0)) * 0.10;
	alpha += silhueta(uv + passo * vec2(0.0, 1.0)) * 0.10;
	alpha += silhueta(uv + passo * vec2(0.0, -1.0)) * 0.10;
	alpha += silhueta(uv + passo * vec2(0.707, 0.707)) * 0.10;
	alpha += silhueta(uv + passo * vec2(-0.707, 0.707)) * 0.10;
	alpha += silhueta(uv + passo * vec2(0.707, -0.707)) * 0.10;
	alpha += silhueta(uv + passo * vec2(-0.707, -0.707)) * 0.10;
	COLOR = vec4(0.015, 0.020, 0.018, alpha * alpha_receptor * intensidade / (1.0 + distancia * 0.002));
}
