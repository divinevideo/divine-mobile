// The light leak clip transition on a still, for its tile in the video
// editor's transition picker.
//
// pro_video_editor draws the transition natively, with
// `ClipTransitionEffects` on Android, iOS and macOS. This is the same light:
// three warm lights in the light leak effect's colors drift in from the left
// edge, each falling off as smoothstep(1 - r), clamped to 1 and screened over
// the picture in turn.
//
// Distances are in pixels with y down, as natively. Centres are fractions of
// the frame; reaches are fractions of its longer side `l`.

#include <flutter/runtime_effect.glsl>

// Engine-set: the size of the bound texture. Must be the first uniform.
uniform vec2 uSize;

// The transition's progress after its curve, kept within 0 to 1.
uniform float uProgress;

// How strong the lights are, as a multiple of their colors.
uniform float uStrength;

uniform sampler2D uTexture;

out vec4 fragColor;

vec3 screenLight(vec3 base, vec2 p, float l, vec2 start, vec2 end, vec2 reach,
    vec3 color) {
  vec2 centre = mix(start, end, uProgress) * uSize;
  vec2 d = (p - centre) / (reach * l);
  float falloff = smoothstep(0.0, 1.0, 1.0 - length(d));
  vec3 glow = clamp(color * uStrength * falloff, 0.0, 1.0);
  return 1.0 - (1.0 - base) * (1.0 - glow);
}

void main() {
  vec2 p = FlutterFragCoord().xy;
  float l = max(uSize.x, uSize.y);
  vec3 color = texture(uTexture, p / uSize).rgb;
  color = screenLight(color, p, l, vec2(-0.2, 0.3), vec2(0.85, 0.5),
    vec2(0.55, 0.8), vec3(0.95, 0.49, 0.17));
  color = screenLight(color, p, l, vec2(-0.1, -0.05), vec2(1.1, 0.1),
    vec2(0.6, 0.3), vec3(0.75, 0.21, 0.24));
  color = screenLight(color, p, l, vec2(-0.3, 0.85), vec2(0.7, 0.7),
    vec2(0.4, 0.4), vec3(0.55, 0.45, 0.28));
  fragColor = vec4(color, 1.0);
}
