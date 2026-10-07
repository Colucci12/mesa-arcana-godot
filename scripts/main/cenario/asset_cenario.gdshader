shader_type canvas_item;
render_mode unshaded;
#include "res://scripts/main/componentes/iluminacao_plano.gdshaderinc"

uniform vec3 inversa_x;
uniform vec3 inversa_y;
uniform vec3 inversa_z;
uniform vec4 recorte_uv;
uniform bool espelhar = false;
varying vec2 ponto_local;
varying vec2 ponto_cena;
uniform vec3 peca_transform_x;
uniform vec3 peca_transform_y;
uniform float contraste = 1.0;
uniform float saturacao = 1.0;
// Mesmo limite de CHAMAS.MAXIMO em interno/chamas_cenario_2d.gd.
uniform int quantidade_chamas_ocultas = 0;
uniform vec4 chamas_ocultas[16];

void vertex() {
	ponto_local = VERTEX;
	ponto_cena = vec2(dot(peca_transform_x, vec3(VERTEX, 1.0)), dot(peca_transform_y, vec3(VERTEX, 1.0)));
}

void fragment() {
	vec3 p = vec3(ponto_local, 1.0);
	vec2 uv = vec2(dot(inversa_x, p), dot(inversa_y, p)) / dot(inversa_z, p);
	if (espelhar) { uv.x = 1.0 - uv.x; }
	vec2 margem = TEXTURE_PIXEL_SIZE * 0.5;
	vec2 amostra = clamp(recorte_uv.xy + uv * recorte_uv.zw,
		recorte_uv.xy + margem, recorte_uv.xy + recorte_uv.zw - margem);
	COLOR = texture(TEXTURE, amostra);
	for (int i = 0; i < 16; i++) {
		if (i >= quantidade_chamas_ocultas) { break; }
		vec4 area = chamas_ocultas[i];
		vec2 local = (uv - area.xy) / area.zw;
		if (all(greaterThanEqual(local, vec2(0.0))) && all(lessThanEqual(local, vec2(1.0)))) {
			float borda = min(min(local.x, 1.0 - local.x), min(local.y, 1.0 - local.y));
			COLOR.a *= 1.0 - smoothstep(0.0, 0.02, borda);
		}
	}
	if (cenario_ativo) {
		float cinza = dot(COLOR.rgb, vec3(0.2126, 0.7152, 0.0722));
		COLOR.rgb = max(mix(vec3(cinza), COLOR.rgb, saturacao), vec3(0.0));
		COLOR.rgb = clamp((COLOR.rgb - vec3(0.5)) * contraste + vec3(0.5), vec3(0.0), vec3(1.0));
	}
	COLOR.rgb = iluminar_plano(COLOR.rgb, ponto_cena);
}
