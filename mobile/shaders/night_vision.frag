// The night vision effect on a still, for its tile in the video editor's
// effects picker.
//
// The renderers draw the effect natively, with `NightVisionVideoEffect` on
// Android, iOS and macOS. This is the same shader: the picture as night
// vision goggles show it, brightened into green phosphor, with fine noise,
// faint scanlines and darker corners.
//
// The brightness is lifted, more in the shadows, and turned into the
// phosphor's green, which pales towards white where it is brightest. The
// noise changes 24 times a second, from 64 patterns the renderers step
// through, so it stays fine grain rather than a flicker; its mean is zero,
// so the picture keeps its brightness.
//
// Distances are in pixels with y up, from the bottom left, as natively;
// Flutter counts y down, so it is flipped on the way in. `s` is the shorter
// side, `e` a grain cell and half a scanline, in pixels.

#include <flutter/runtime_effect.glsl>

// Engine-set: the size of the bound texture. Must be the first uniform.
uniform vec2 uSize;

// How far the picture turns into night vision, 0 to 1.
uniform float uIntensity;

// Which of the 64 noise patterns shows, 0 to 63.
uniform float uNoiseFrame;

// How much grain the tube adds, as a share of the default.
uniform float uGrain;

// The phosphor's colour when dim, and how far it lifts towards white as it
// glows brighter.
uniform vec3 uBase;
uniform vec3 uLift;

uniform sampler2D uTexture;

out vec4 fragColor;

vec3 tap(vec2 q) {
  q = clamp(q, vec2(0.5), uSize - 0.5);
  return texture(uTexture, vec2(q.x, uSize.y - q.y) / uSize).rgb;
}

float luma(vec3 c) {
  return dot(c, vec3(0.299, 0.587, 0.114));
}

float grain(vec2 q) {
  return fract(52.9829189 * fract(dot(q, vec2(0.06711056, 0.00583715))));
}

void main() {
  vec2 fragCoord = FlutterFragCoord().xy;
  vec2 p = vec2(fragCoord.x, uSize.y - fragCoord.y);
  float s = min(uSize.x, uSize.y);
  float e = max(1.0, s / 540.0);
  vec3 color = tap(p);
  float level = clamp(1.1 * pow(max(luma(color), 0.0), 0.75), 0.0, 1.0);
  float noise = grain(floor(p / e) + uNoiseFrame * vec2(37.0, 17.0)) - 0.5;
  float scan = 0.94 + 0.06 * step(0.5, fract(p.y / (2.0 * e)));
  float corner = length(p / uSize - 0.5);
  float tube = 1.0 - 0.65 * smoothstep(0.35, 0.75, corner);
  float glow = clamp((level + 0.12 * uGrain * noise) * scan * tube, 0.0, 1.0);
  vec3 phosphor = (uBase + uLift * glow) * glow + vec3(0.0, 0.03, 0.01);
  fragColor = vec4(mix(color, clamp(phosphor, 0.0, 1.0), uIntensity), 1.0);
}
