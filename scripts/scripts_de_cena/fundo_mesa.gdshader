shader_type canvas_item;
render_mode unshaded;

#include "res://scripts/scripts_de_cena/iluminacao_ambiente.gdshaderinc"

uniform vec4 cor_base : source_color = vec4(0.047, 0.220, 0.173, 1.0);
uniform vec4 cor_iluminada : source_color = vec4(0.090, 0.290, 0.227, 1.0);
uniform float intensidade : hint_range(0.0, 1.0) = 0.65;
uniform float extensao : hint_range(0.3, 2.0) = 0.9;
uniform vec2 dimensoes = vec2(1280.0, 720.0);

void fragment() {
	vec2 proporcao = dimensoes / min(dimensoes.x, dimensoes.y);
	float distancia = length((UV - vec2(0.5)) * proporcao);
	float luz = 1.0 - smoothstep(0.0, extensao, distancia);
	vec4 fundo_original = mix(cor_base, cor_iluminada, intensidade * luz);
	// Com a lâmpada ativa, o fundo acompanha o mesmo oval dos objetos da mesa.
	float foco = calcular_foco_luz(SCREEN_UV, SCREEN_PIXEL_SIZE);
	vec4 fundo_focal = mix(cor_base, cor_iluminada, foco);
	COLOR = mix(fundo_original, fundo_focal, luz_intensidade);
	COLOR.rgb = aplicar_iluminacao_ambiente(COLOR.rgb, SCREEN_UV, SCREEN_PIXEL_SIZE);
}
