shader_type canvas_item;
render_mode unshaded;

uniform vec3 inversa_x;
uniform vec3 inversa_y;
uniform vec3 inversa_z;
uniform vec4 regiao_textura;
uniform vec4 cor : source_color = vec4(1.0, 0.76, 0.23, 1.0);
uniform float espessura = 2.5;
uniform float intensidade = 1.0;
uniform float opacidade = 0.0;
varying vec2 ponto_projetado;

void vertex() {
	ponto_projetado = VERTEX;
}

float mascara(sampler2D fonte, vec2 ponto) {
	vec3 p = vec3(ponto, 1.0);
	float d = dot(inversa_z, p);
	if (abs(d) < 0.000001) { return 0.0; }
	vec2 uv = vec2(dot(inversa_x, p), dot(inversa_y, p)) / d;
	if (any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0)))) { return 0.0; }
	// Sombras translúcidas ficam fora da máscara; a face escura continua opaca.
	return smoothstep(0.55, 0.75, texture(fonte, regiao_textura.xy + uv * regiao_textura.zw).a);
}

void fragment() {
	float centro = mascara(TEXTURE, ponto_projetado);
	float exterior = 0.0;
	if (centro < 0.999 && opacidade > 0.001) {
		for (int i = 0; i < 16; i++) {
			float angulo = float(i) * 0.392699082;
			exterior = max(exterior, mascara(TEXTURE, ponto_projetado + vec2(cos(angulo), sin(angulo)) * espessura));
		}
	}
	// Dilatação da imagem composta: nenhuma linha nas divisões entre cartas.
	COLOR = vec4(cor.rgb * intensidade, max(exterior - centro, 0.0) * opacidade * cor.a);
}
