shader_type canvas_item;
render_mode unshaded, blend_mix;

// Border thickness in UV units (0..0.5). 0.02 ≈ 2% of the smallest side.
uniform float border_thickness : hint_range(0.0, 0.5) = 0.02;
// Soft edge for anti-aliasing around the inner border.
uniform float edge_smoothness : hint_range(0.0, 0.05) = 0.002;

// Per-corner radius in UV units (0..0.5): x=top-left, y=top-right, z=bottom-right, w=bottom-left
uniform vec4 corner_radius = vec4(0.0);

// Animation speed (units per second around the perimeter).
uniform float speed : hint_range(-10.0, 10.0) = 0.5;
// Direction toggle: true = clockwise, false = counter-clockwise.
uniform bool clockwise = true;

// Provide a GradientTexture1D here (Texture2D) to control colors.
uniform sampler2D gradient : source_color, filter_linear, repeat_enable;


vec3 hsv2rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(0.0, 0.6666667, 0.3333333)) * 6.0 - 3.0);
	vec3 rgb = clamp(p - 1.0, 0.0, 1.0);
	return c.z * mix(vec3(1.0), rgb, c.y);
}

void fragment() {
	vec2 uv = UV;

	// Estimate the item size in pixels using derivatives of UV
	vec2 duv_dx = dFdx(uv);
	vec2 duv_dy = dFdy(uv);
	float grad_u = length(vec2(duv_dx.x, duv_dy.x));
	float grad_v = length(vec2(duv_dx.y, duv_dy.y));
	float width_px = 1.0 / max(grad_u, 1e-6);
	float height_px = 1.0 / max(grad_v, 1e-6);
	vec2 size_px = vec2(width_px, height_px);
	vec2 p = uv * size_px; // position in pixels

	// Decide radii source: pixel radii (if provided) or UV radii scaled to pixels
	float base_scale = min(size_px.x, size_px.y);
	vec4 r_src_px = corner_radius * base_scale;

	// Clamp radii to reasonable bounds
	float r_tl = clamp(r_src_px.x, 0.0, 0.5 * base_scale);
	float r_tr = clamp(r_src_px.y, 0.0, 0.5 * base_scale);
	float r_br = clamp(r_src_px.z, 0.0, 0.5 * base_scale);
	float r_bl = clamp(r_src_px.w, 0.0, 0.5 * base_scale);

	// Compute distance from the outer rounded-rectangle border, positive inside, negative outside
	float d; // signed distance to outer border, positive inside
	// Also compute a perimeter parameter s along the border for color animation
	float s = 0.0;

	// Precompute straight lengths and arc lengths (in UV units)
	float L0 = max(0.0, size_px.x - (r_tl + r_tr)); // top straight length
	float L1 = max(0.0, size_px.y - (r_tr + r_br)); // right straight length
	float L2 = max(0.0, size_px.x - (r_br + r_bl)); // bottom straight length
	float L3 = max(0.0, size_px.y - (r_bl + r_tl)); // left straight length
	float A0 = 0.5 * PI * r_tl; // TL arc length
	float A1 = 0.5 * PI * r_tr; // TR arc length
	float A2 = 0.5 * PI * r_br; // BR arc length
	float A3 = 0.5 * PI * r_bl; // BL arc length
	float perim = L0 + L1 + L2 + L3 + A0 + A1 + A2 + A3;
	perim = max(perim, 1e-6);

	// Determine region and compute signed distance and perimeter position
	if (p.x < r_tl && p.y < r_tl) {
		// Top-left corner
		vec2 c = vec2(r_tl, r_tl);
		vec2 v = p - c;
		float lenv = length(v);
		d = r_tl - lenv;
		float theta = atan(v.y, v.x);
		if (theta < 0.0) theta += 2.0 * PI;
		float a = clamp(theta - PI, 0.0, 0.5 * PI);
		s = L0 + A1 + L1 + A2 + L2 + A3 + L3 + r_tl * a;
	} else if (p.y < r_tl && p.x >= r_tl && p.x <= size_px.x - r_tr) {
		// Top edge (left -> right)
		d = p.y;
		s = (p.x - r_tl);
	} else if (p.x > size_px.x - r_tr && p.y < r_tr) {
		// Top-right corner
		vec2 c = vec2(size_px.x - r_tr, r_tr);
		vec2 v = p - c;
		float lenv = length(v);
		d = r_tr - lenv;
		float theta = atan(v.y, v.x); // [-pi,pi]
		// Map to [-pi/2, 0] for this quadrant
		float a = clamp(theta + 0.5 * PI, 0.0, 0.5 * PI);
		s = L0 + r_tr * a;
	} else if (p.x > size_px.x - r_tr && p.y >= r_tr && p.y <= size_px.y - r_br) {
		// Right edge (top -> bottom)
		d = size_px.x - p.x;
		s = L0 + A1 + (p.y - r_tr);
	} else if (p.x > size_px.x - r_br && p.y > size_px.y - r_br) {
		// Bottom-right corner
		vec2 c = vec2(size_px.x - r_br, size_px.y - r_br);
		vec2 v = p - c;
		float lenv = length(v);
		d = r_br - lenv;
		float theta = atan(v.y, v.x); // [0, pi/2] in this quadrant for inside
		float a = clamp(theta - 0.0, 0.0, 0.5 * PI);
		s = L0 + A1 + L1 + r_br * a;
	} else if (p.y > size_px.y - r_br && p.x >= r_bl && p.x <= size_px.x - r_br) {
		// Bottom edge (right -> left)
		d = size_px.y - p.y;
		s = L0 + A1 + L1 + A2 + (size_px.x - r_br - p.x);
	} else if (p.x < r_bl && p.y > size_px.y - r_bl) {
		// Bottom-left corner
		vec2 c = vec2(r_bl, size_px.y - r_bl);
		vec2 v = p - c;
		float lenv = length(v);
		d = r_bl - lenv;
		float theta = atan(v.y, v.x);
		float a = clamp(theta - 0.5 * PI, 0.0, 0.5 * PI);
		s = L0 + A1 + L1 + A2 + L2 + r_bl * a;
	} else if (p.x < r_bl && p.y >= r_tl && p.y <= size_px.y - r_bl) {
		// Left edge (bottom -> top)
		d = p.x;
		s = L0 + A1 + L1 + A2 + L2 + A3 + (size_px.y - r_bl - p.y);
	} else {
		// Center area away from border; distance = min distance to any edge or corner (inside)
		float d_top = p.y;
		float d_right = size_px.x - p.x;
		float d_bottom = size_px.y - p.y;
		float d_left = p.x;
		d = min(min(d_top, d_right), min(d_bottom, d_left));
		// s fallback: project to nearest straight edge assuming top for simplicity
		s = clamp(p.x - r_tl, 0.0, L0);
	}

	// Convert thickness and smoothing to pixels from UV-based uniforms
	float base_scale2 = base_scale;
	float thickness_px = border_thickness * base_scale2;
	float smooth_px = edge_smoothness * base_scale2;
	float aa = max(smooth_px, fwidth(d));
	// Safety inset so the outer edge sits slightly inside the rounded rect to prevent corner clipping
	float inset_px = max(aa, 0.75);
	// Border mask band: [inset_px, inset_px + thickness_px] (grows inward only)
	float mask = smoothstep(inset_px - aa, inset_px + aa, d) - smoothstep(inset_px + thickness_px - aa, inset_px + thickness_px + aa, d);
	mask = clamp(mask, 0.0, 1.0);

	// Perimeter coordinate t in [0,1), increasing clockwise, wrapping
	float t = s / perim;

	float dir = clockwise ? 1.0 : -1.0;
	t = fract(t + TIME * speed * dir);

	vec4 col = texture(gradient, vec2(t, 0.5));
	COLOR = vec4(col.rgb, col.a * mask);
}
