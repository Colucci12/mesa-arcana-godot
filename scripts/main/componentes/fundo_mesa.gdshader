shader_type canvas_item;
render_mode unshaded;

#include "res://scripts/main/componentes/iluminacao_ambiente.gdshaderinc"

uniform vec4 cor_base : source_color = vec4(0.047, 0.220, 0.173, 1.0);
uniform vec4 cor_iluminada : source_color = vec4(0.090, 0.290, 0.227, 1.0);
uniform float intensidade : hint_range(0.0, 1.0) = 0.65;
uniform float extensao : hint_range(0.3, 2.0) = 0.9;
uniform vec2 dimensoes = vec2(1280.0, 720.0);
uniform float intensidade_textura : hint_range(0.0, 0.2) = 0.0;
uniform float escala_textura : hint_range(0.5, 4.0) = 1.0;
uniform float intensidade_manchas : hint_range(0.0, 0.05) = 0.0;

float hash_feltro(vec2 amostra_feltro) {
	return fract(sin(dot(amostra_feltro, vec2(127.1, 311.7))) * 43758.5453);
}

float ruido_feltro(vec2 ponto_feltro) {
	vec2 celula_feltro = floor(ponto_feltro);
	vec2 fracao_feltro = fract(ponto_feltro);
	vec2 transicao_feltro = fracao_feltro * fracao_feltro * (3.0 - 2.0 * fracao_feltro);
	float linha_superior = mix(hash_feltro(celula_feltro), hash_feltro(celula_feltro + vec2(1.0, 0.0)), transicao_feltro.x);
	float linha_inferior = mix(hash_feltro(celula_feltro + vec2(0.0, 1.0)), hash_feltro(celula_feltro + vec2(1.0)), transicao_feltro.x);
	return mix(linha_superior, linha_inferior, transicao_feltro.y);
}

void fragment() {
	vec2 proporcao = dimensoes / min(dimensoes.x, dimensoes.y);
	float distancia = length((UV - vec2(0.5)) * proporcao);
	float luz = 1.0 - smoothstep(0.0, extensao, distancia);
	vec4 fundo_original = mix(cor_base, cor_iluminada, intensidade * luz);
	// Com a lâmpada ativa, o fundo acompanha o mesmo oval dos objetos da mesa.
	float foco = calcular_foco_luz(SCREEN_UV, SCREEN_PIXEL_SIZE);
	vec4 fundo_focal = mix(cor_base, cor_iluminada, foco);
	COLOR = mix(fundo_original, fundo_focal, luz_intensidade);
	if (intensidade_textura > 0.0 || intensidade_manchas > 0.0) {
		// Coordenadas da mesa, sem TIME: o material fica parado enquanto a luz pulsa.
		vec2 posicao_feltro = UV * dimensoes / max(escala_textura, 0.001);
		float grao_feltro = ruido_feltro(posicao_feltro / 1.75) - 0.5;
		float variacao_feltro = ruido_feltro(posicao_feltro / 35.0 + vec2(73.0, 119.0)) - 0.5;
		float manchas_feltro = smoothstep(0.6, 0.86, ruido_feltro(posicao_feltro / 170.0 + vec2(19.0, 47.0)));
		float relevo_feltro = intensidade_textura * (0.8 * grao_feltro + 0.4 * variacao_feltro);
		relevo_feltro -= intensidade_manchas * manchas_feltro;
		// Varia apenas o valor da superfície, antes de receber a iluminação da mesa.
		COLOR.rgb *= 1.0 + relevo_feltro;
	}
	COLOR.rgb = aplicar_iluminacao_ambiente(COLOR.rgb, SCREEN_UV, SCREEN_PIXEL_SIZE);
}
