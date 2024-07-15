shader_type canvas_item;

uniform bool ext_texture_is_bgra;
uniform bool show_render;

const vec4 zero = vec4(0);

void fragment() {
	if (show_render) {
		COLOR = vec4(COLOR.rgb, 1);
	} else {
		COLOR = zero;
	}
	
	if (ext_texture_is_bgra) {
		COLOR = COLOR.bgra; // Swizzle BGRA to RGBA
	}
}
