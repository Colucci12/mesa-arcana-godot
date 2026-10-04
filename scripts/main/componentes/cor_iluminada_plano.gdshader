shader_type canvas_item;
render_mode unshaded;

#include "res://scripts/main/componentes/iluminacao_plano.gdshaderinc"

varying vec2 posicao_canvas;

void vertex() {
	posicao_canvas = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	COLOR.rgb = iluminar_plano(COLOR.rgb, posicao_canvas);
}
