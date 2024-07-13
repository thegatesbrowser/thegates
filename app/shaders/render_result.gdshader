shader_type canvas_item;

uniform bool ext_texture_is_bgra;
uniform bool fill_alpha;

void fragment() {
	if (ext_texture_is_bgra) {
		COLOR = COLOR.bgra; // Swizzle BGRA to RGBA
	}
	
	if (fill_alpha) {
		COLOR = vec4(COLOR.r, COLOR.g, COLOR.b, 1);
	}
}
