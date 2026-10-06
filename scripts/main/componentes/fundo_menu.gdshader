shader_type canvas_item;
render_mode unshaded;

uniform float desfoque : hint_range(0.0, 4.0) = 1.1;
uniform float escurecimento : hint_range(0.0, 0.8) = 0.18;
uniform bool leitura_esquerda = true;

void fragment() {
	vec2 passo = TEXTURE_PIXEL_SIZE * desfoque;
	vec3 cor = texture(TEXTURE, UV).rgb * 0.36;
	cor += texture(TEXTURE, UV + vec2(passo.x, 0.0)).rgb * 0.12;
	cor += texture(TEXTURE, UV - vec2(passo.x, 0.0)).rgb * 0.12;
	cor += texture(TEXTURE, UV + vec2(0.0, passo.y)).rgb * 0.12;
	cor += texture(TEXTURE, UV - vec2(0.0, passo.y)).rgb * 0.12;
	cor += texture(TEXTURE, UV + passo).rgb * 0.04;
	cor += texture(TEXTURE, UV - passo).rgb * 0.04;
	cor += texture(TEXTURE, UV + vec2(passo.x, -passo.y)).rgb * 0.04;
	cor += texture(TEXTURE, UV + vec2(-passo.x, passo.y)).rgb * 0.04;
	float borda = smoothstep(0.25, 0.8, length((UV - vec2(0.5)) * vec2(0.92, 1.0)));
	float esquerda = leitura_esquerda ? (1.0 - smoothstep(0.1, 0.62, UV.x)) * 0.22 : 0.0;
	cor *= 1.0 - escurecimento - borda * 0.22 - esquerda;
	COLOR = vec4(cor, 1.0);
}
