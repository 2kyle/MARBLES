// A texture slot for an artist: if a picture is dropped into
// assets/textures/ (see assets/textures/README.md), it is laid over the
// painted colour here. With no picture the slot does nothing at all.
//
// The picture is projected from three sides (triplanar), so it needs no UVs
// and wraps round any shape. Grey (0.5) leaves the colour as it is, lighter
// brightens, darker darkens, so a grey grain, brush or noise picture adds
// detail without changing the colours. A coloured picture works too: turn
// detail_tint up to 1 to use its colours.
uniform sampler2D detail_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform bool use_detail = false;
// How many times the picture repeats per metre.
uniform float detail_scale = 1.0;
// 0..1: how strongly it shows.
uniform float detail_strength = 0.6;
// 0 = only light and shade (overlay), 1 = the picture's own colours.
uniform float detail_tint = 0.0;

vec3 triplanar_detail(vec3 pos, vec3 nrm) {
	vec3 w = pow(abs(nrm), vec3(4.0));
	w /= max(w.x + w.y + w.z, 0.0001);
	vec3 p = pos * detail_scale;
	return texture(detail_tex, p.zy).rgb * w.x + texture(detail_tex, p.xz).rgb * w.y + texture(detail_tex, p.xy).rgb * w.z;
}

vec3 apply_detail(vec3 col, vec3 pos, vec3 nrm) {
	if (!use_detail) {
		return col;
	}
	vec3 t = triplanar_detail(pos, nrm);
	vec3 overlay = col * (t * 2.0);
	return mix(col, mix(overlay, t, detail_tint), detail_strength);
}
