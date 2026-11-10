shader_type canvas_item;
// Sombra: pinta todo pixel visível do sprite com uma cor única e transparente.
// Cor padrão = contorno da paleta (k, #22161E) com 35% de opacidade.

uniform vec4 shadow_color : source_color = vec4(0.133, 0.086, 0.118, 0.35);

void fragment() {
	COLOR = vec4(shadow_color.rgb, shadow_color.a * texture(TEXTURE, UV).a);
}
