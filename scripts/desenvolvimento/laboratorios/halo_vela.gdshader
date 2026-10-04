shader_type canvas_item;
render_mode unshaded, blend_add;

uniform float intensidade : hint_range(0.0, 1.0) = 0.30;

void fragment() {
	float distancia = length((UV - 0.5) * 2.0);
	float borda = 1.0 - smoothstep(0.0, 1.0, distancia);
	float brilho = borda * borda * intensidade;
	COLOR = vec4(1.0, 0.58, 0.18, brilho);
}
