shader_type canvas_item;
render_mode unshaded;

#include "res://scripts/main/componentes/iluminacao_plano.gdshaderinc"

uniform vec3 inversa_x;
uniform vec3 inversa_y;
uniform vec3 inversa_z;
uniform vec4 regiao_textura;
uniform vec4 cor_camada : source_color = vec4(0.0);
varying vec2 ponto_projetado;
varying vec2 posicao_canvas;

void vertex() {
	ponto_projetado = VERTEX;
	posicao_canvas = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec3 ponto = vec3(ponto_projetado, 1.0);
	float denominador = dot(inversa_z, ponto);
	if (abs(denominador) < 0.000001) {
		discard;
	}
	vec2 origem = vec2(dot(inversa_x, ponto), dot(inversa_y, ponto)) / denominador;
	if (any(lessThan(origem, vec2(0.0))) || any(greaterThan(origem, vec2(1.0)))) {
		discard;
	}
	COLOR = texture(TEXTURE, regiao_textura.xy + origem * regiao_textura.zw);
	COLOR.rgb = mix(COLOR.rgb, cor_camada.rgb, cor_camada.a);
	COLOR.rgb = iluminar_plano(COLOR.rgb, posicao_canvas);
}
