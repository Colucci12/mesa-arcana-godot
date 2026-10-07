shader_type canvas_item;
render_mode unshaded;

#include "res://scripts/main/componentes/luz_cenario_2d.gdshaderinc"

uniform vec3 inversa_x;
uniform vec3 inversa_y;
uniform vec3 inversa_z;
uniform float angulo = 0.0;
uniform vec2 escala_fonte = vec2(1.25, 0.95);
uniform float opacidade = 0.55;
uniform bool mostrar_seta = true;
uniform float sentido = 1.0;
uniform vec4 cor_seta : source_color = vec4(1.0, 0.82, 0.36, 1.0);
varying vec2 ponto_projetado;
varying vec2 posicao_canvas;

void vertex() {
	ponto_projetado = VERTEX;
	posicao_canvas = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec3 p = vec3(ponto_projetado, 1.0);
	float d = dot(inversa_z, p);
	if (abs(d) < 0.000001) { discard; }
	vec2 uv = vec2(dot(inversa_x, p), dot(inversa_y, p)) / d;
	vec2 q = uv - vec2(0.5);
	float c = cos(angulo);
	float s = sin(angulo);
	// Desenho circularizado e giro no plano original; o encaixe projetado é fixo.
	vec2 girado = vec2(c * q.x + s * q.y, -s * q.x + c * q.y);
	vec2 amostra = vec2(0.5) + girado * escala_fonte;
	vec4 desenho = vec4(0.0);
	if (all(greaterThanEqual(amostra, vec2(0.0))) && all(lessThanEqual(amostra, vec2(1.0)))) {
		desenho = texture(TEXTURE, amostra);
	}
	if (mostrar_seta) {
		vec2 seta = girado - vec2(0.0, -0.37);
		seta.x *= sentido;
		float limite = 0.024 * (0.034 - seta.x) / 0.054;
		float borda = max(abs(seta.y) - limite, max(-0.02 - seta.x, seta.x - 0.034));
		float cobertura = 1.0 - smoothstep(-0.001, 0.001, borda);
		desenho.rgb = mix(desenho.rgb, cor_seta.rgb, cobertura);
		desenho.a = max(desenho.a, cobertura * cor_seta.a);
	}
	if (cenario_ativo) {
		vec4 campo = luzes_cenario(posicao_canvas);
		vec3 brilho = brilhos_cenario(desenho.rgb, posicao_canvas);
		desenho.rgb = (desenho.rgb * (vec3(cenario_ambiente) + campo.rgb) + brilho) * campo.a;
	}
	COLOR = vec4(desenho.rgb, desenho.a * opacidade);
}
