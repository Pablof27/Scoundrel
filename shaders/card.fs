#if defined(VERTEX) || __VERSION__ > 100 || defined(GL_FRAGMENT_PRECISION_HIGH)
	#define MY_HIGHP_OR_MEDIUMP highp
#else
	#define MY_HIGHP_OR_MEDIUMP mediump
#endif

/*
    Card shader
    Vertex: fake 3D tilt. The homogeneous w of every vertex is offset so the card behaves like a
            plane rotated towards `tilt`, which also gives perspective-correct texturing.
    Pixel:  dissolve/burn (adapted from dissolve.fs), white flash and drop-shadow mode.
*/

extern MY_HIGHP_OR_MEDIUMP vec2 card_center;
extern MY_HIGHP_OR_MEDIUMP vec2 card_half;
extern MY_HIGHP_OR_MEDIUMP vec2 tilt;

#ifdef VERTEX
vec4 position(mat4 transform_projection, vec4 vertex_position)
{
    MY_HIGHP_OR_MEDIUMP vec2 rel = (vertex_position.xy - card_center) / card_half;
    MY_HIGHP_OR_MEDIUMP float w = 1.0 + 0.08 * dot(rel, tilt);
    MY_HIGHP_OR_MEDIUMP vec4 p = transform_projection * vertex_position;
    MY_HIGHP_OR_MEDIUMP vec4 c = transform_projection * vec4(card_center, 0.0, 1.0);
    return vec4(c.xy * w + (p.xy - c.xy), p.z * w, w);
}
#endif

#ifdef PIXEL
extern MY_HIGHP_OR_MEDIUMP number dissolve;
extern MY_HIGHP_OR_MEDIUMP number time;
extern MY_HIGHP_OR_MEDIUMP vec4 texture_details;
extern MY_HIGHP_OR_MEDIUMP vec2 image_details;
extern MY_HIGHP_OR_MEDIUMP number shadow;
extern MY_HIGHP_OR_MEDIUMP number flash;
extern MY_HIGHP_OR_MEDIUMP vec4 burn_colour_1;
extern MY_HIGHP_OR_MEDIUMP vec4 burn_colour_2;

vec4 dissolve_mask(vec4 tex, vec2 uv)
{
    bool is_shadow = shadow > 0.5;
    if (dissolve < 0.001) {
        return vec4(is_shadow ? vec3(0.) : tex.rgb, is_shadow ? tex.a * 0.35 : tex.a);
    }

    MY_HIGHP_OR_MEDIUMP float adjusted_dissolve = (dissolve*dissolve*(3.-2.*dissolve))*1.02 - 0.01;

    MY_HIGHP_OR_MEDIUMP float t = time * 10.0 + 2003.;
    MY_HIGHP_OR_MEDIUMP vec2 floored_uv = (floor((uv*texture_details.ba)))/max(texture_details.b, texture_details.a);
    MY_HIGHP_OR_MEDIUMP vec2 uv_scaled_centered = (floored_uv - 0.5) * 2.3 * max(texture_details.b, texture_details.a);

    MY_HIGHP_OR_MEDIUMP vec2 field_part1 = uv_scaled_centered + 50.*vec2(sin(-t / 143.6340), cos(-t / 99.4324));
    MY_HIGHP_OR_MEDIUMP vec2 field_part2 = uv_scaled_centered + 50.*vec2(cos( t / 53.1532),  cos( t / 61.4532));
    MY_HIGHP_OR_MEDIUMP vec2 field_part3 = uv_scaled_centered + 50.*vec2(sin(-t / 87.53218), sin(-t / 49.0000));

    MY_HIGHP_OR_MEDIUMP float field = (1.+ (
        cos(length(field_part1) / 19.483) + sin(length(field_part2) / 33.155) * cos(field_part2.y / 15.73) +
        cos(length(field_part3) / 27.193) * sin(field_part3.x / 21.92) ))/2.;
    MY_HIGHP_OR_MEDIUMP vec2 borders = vec2(0.2, 0.8);

    MY_HIGHP_OR_MEDIUMP float res = (.5 + .5* cos( (adjusted_dissolve) / 82.612 + ( field + -.5 ) *3.14))
    - (floored_uv.x > borders.y ? (floored_uv.x - borders.y)*(5. + 5.*dissolve) : 0.)*(dissolve)
    - (floored_uv.y > borders.y ? (floored_uv.y - borders.y)*(5. + 5.*dissolve) : 0.)*(dissolve)
    - (floored_uv.x < borders.x ? (borders.x - floored_uv.x)*(5. + 5.*dissolve) : 0.)*(dissolve)
    - (floored_uv.y < borders.x ? (borders.x - floored_uv.y)*(5. + 5.*dissolve) : 0.)*(dissolve);

    if (tex.a > 0.01 && burn_colour_1.a > 0.01 && !is_shadow && res < adjusted_dissolve + 0.8*(0.5-abs(adjusted_dissolve-0.5)) && res > adjusted_dissolve) {
        if (res < adjusted_dissolve + 0.5*(0.5-abs(adjusted_dissolve-0.5))) {
            tex.rgba = burn_colour_1.rgba;
        } else if (burn_colour_2.a > 0.01) {
            tex.rgba = burn_colour_2.rgba;
        }
    }

    return vec4(is_shadow ? vec3(0.) : tex.rgb, res > adjusted_dissolve ? (is_shadow ? tex.a * 0.35 : tex.a) : 0.);
}

vec4 effect(vec4 colour, Image texture, vec2 texture_coords, vec2 screen_coords)
{
    MY_HIGHP_OR_MEDIUMP vec4 tex = Texel(texture, texture_coords);
    MY_HIGHP_OR_MEDIUMP vec2 uv = ((texture_coords * image_details) - texture_details.xy * texture_details.ba) / texture_details.ba;

    if (shadow < 0.5) {
        tex.rgb = mix(tex.rgb, vec3(1.0), flash);
        if (dissolve > 0.01) {
            if (burn_colour_2.a > 0.01) {
                tex.rgb = tex.rgb*(1.-0.6*dissolve) + 0.6*burn_colour_2.rgb*dissolve;
            } else if (burn_colour_1.a > 0.01) {
                tex.rgb = tex.rgb*(1.-0.6*dissolve) + 0.6*burn_colour_1.rgb*dissolve;
            }
        }
    }

    return dissolve_mask(tex, uv) * colour;
}
#endif
