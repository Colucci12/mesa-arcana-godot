shader_type canvas_item;
render_mode unshaded;

uniform float largura_distante : hint_range(0.15, 1.0) = 0.56;

void fragment() {
	// Mesma projeção do laboratório oblíquo, incluindo o caso retangular (1.0).
	float largura = mix(largura_distante, 1.0, UV.y);
	vec2 origem = vec2(0.5 + (UV.x - 0.5) / largura, UV.y / largura);
	if (any(lessThan(origem, vec2(0.0))) || any(greaterThan(origem, vec2(1.0)))) {
		discard;
	}
	COLOR = texture(TEXTURE, origem);
}
