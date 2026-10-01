shader_type canvas_item;
render_mode unshaded;

#include "res://scripts/scripts_de_cena/iluminacao_ambiente.gdshaderinc"
#include "res://scripts/scripts_de_cena/acabamento_carta.gdshaderinc"

varying vec4 cor_modulada_objeto;

void vertex() {
	cor_modulada_objeto = COLOR;
}

void fragment() {
	vec4 arte_objeto = texture(TEXTURE, UV);
	if (acabamento_claros > 0.0 || acabamento_tinta > 0.0 || acabamento_variacao_tinta > 0.0) {
		arte_objeto.rgb = aplicar_acabamento_carta(arte_objeto.rgb, UV, vec2(1.0) / TEXTURE_PIXEL_SIZE);
	}
	COLOR = arte_objeto * cor_modulada_objeto;
	COLOR.rgb = aplicar_iluminacao_ambiente(COLOR.rgb, SCREEN_UV, SCREEN_PIXEL_SIZE);
}
