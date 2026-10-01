shader_type canvas_item;
render_mode unshaded, blend_premul_alpha;

#include "res://scripts/scripts_de_cena/iluminacao_ambiente.gdshaderinc"

uniform vec2 inclinacao = vec2(0.0);
uniform vec2 tamanho_textura = vec2(87.0, 111.0);
uniform float largura_contorno : hint_range(0.0, 2.0, 0.05) = 0.65;
uniform vec4 cor_contorno : source_color = vec4(0.42, 0.43, 0.46, 0.55);

varying vec2 posicao_na_tela;
varying vec4 cor_modulada;

void vertex() {
	posicao_na_tela = (UV - 0.5) * tamanho_textura * 1.5;
	VERTEX += (UV - 0.5) * tamanho_textura * 0.5;
	cor_modulada = COLOR;
}

void fragment() {
	vec2 angulos = radians(inclinacao);
	float seno_x = sin(angulos.x);
	float cosseno_x = cos(angulos.x);
	float seno_y = sin(angulos.y);
	float cosseno_y = cos(angulos.y);
	vec3 eixo_x = vec3(cosseno_y, 0.0, -seno_y);
	vec3 eixo_y = vec3(seno_y * seno_x, cosseno_x, cosseno_y * seno_x);
	vec3 normal = vec3(seno_y * cosseno_x, -seno_x, cosseno_y * cosseno_x);
	float distancia = tamanho_textura.y * 1.7;
	vec3 raio = vec3(posicao_na_tela, -distancia);
	float denominador = dot(raio, normal);
	if (denominador >= -0.0001) {
		discard;
	}
	float intersecao = -distancia * normal.z / denominador;
	vec3 ponto = vec3(posicao_na_tela * intersecao, distancia * (1.0 - intersecao));
	vec2 uv = vec2(dot(ponto, eixo_x), dot(ponto, eixo_y)) / tamanho_textura + 0.5;
	if (any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0)))) {
		discard;
	}
	vec4 textura = texture(TEXTURE, uv);
	vec2 passo = vec2(largura_contorno) / tamanho_textura;
	float cobertura = textura.a;
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			cobertura = max(cobertura, texture(TEXTURE, uv + vec2(float(x), float(y)) * passo).a);
		}
	}
	float alfa_contorno = cobertura * cor_contorno.a * (1.0 - textura.a);
	textura += vec4(cor_contorno.rgb * alfa_contorno, alfa_contorno);
	// Tratar a arte antes da modulação mantém o papel legível nas cartas escurecidas.
	vec3 arte_carta = textura.rgb / max(textura.a, 0.00001);
	arte_carta = aplicar_iluminacao_ambiente(arte_carta, SCREEN_UV, SCREEN_PIXEL_SIZE);
	COLOR = vec4(arte_carta * textura.a, textura.a);
	COLOR *= vec4(cor_modulada.rgb * cor_modulada.a, cor_modulada.a);
}
