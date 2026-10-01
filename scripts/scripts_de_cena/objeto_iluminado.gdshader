shader_type canvas_item;
render_mode unshaded;

#include "res://scripts/scripts_de_cena/iluminacao_ambiente.gdshaderinc"

void fragment() {
	COLOR.rgb = aplicar_iluminacao_ambiente(COLOR.rgb, SCREEN_UV, SCREEN_PIXEL_SIZE);
}
