// The intros and outros on a still, for their tiles in the video editor's
// effects picker.
//
// The renderers draw the effects natively, with `IntroOutroVideoEffect` on
// Android, iOS and macOS. This is the same shader: the picture is covered by
// `uAmount` in one of five looks, whose structure `uShape` sets. 0 fades it to
// a colour from black to white, 1 closes a circle on it with an edge from hard
// to soft, 2 closes black bars over it in one to eight bands, 3 draws red stage
// curtains in from the sides with three to twelve folds each, and 4 blurs it
// slightly to heavily. The native effect works out the amount from the time
// since the effect started; the tile animates it.
//
// Distances are in pixels with y up, from the bottom left, as natively;
// Flutter counts y down, so it is flipped on the way in. `s` is the shorter
// side. A curtain hangs from a rail at the top, and its bottom trails behind
// while it moves, by `uSwing`, so `reach`, how far it covers its half of the
// frame, is worked out per row. Its cloth is as wide as its half: the cloth by
// its edge hangs in folds of their natural `width`, and what is left over is
// pushed together towards the side, `squeeze` times tighter and darker
// there. `inset` is how far a pixel lies inside the curtain from its edge,
// `fold` how many folds of cloth lie between them, fanning out a little
// towards the bottom and spaced unevenly. Each fold is lit from the middle of
// the stage, with a velvet sheen and fine nap on the side facing it, and the
// tops lie in the shadow of the stage opening. The blur's taps lie
// on a golden-angle spiral, each turned from the one before by the golden
// angle, whose cosine and sine are the constants.

#include <flutter/runtime_effect.glsl>

// Engine-set: the size of the bound texture. Must be the first uniform.
uniform vec2 uSize;

// How far the picture is covered, 0 (not at all) to 1 (completely).
uniform float uAmount;

// The structure of the look, 0 to 1: the slider.
uniform float uShape;

// The look: 0 fade, 1 circle, 2 cinema bars, 3 curtain, 4 focus.
uniform float uStyle;

// How far the bottom of a moving curtain trails behind its top, 0 at rest:
// up to about 0.8 while it closes and -0.8 while it opens, swinging a little
// the other way near the end.
uniform float uSwing;

uniform sampler2D uTexture;

out vec4 fragColor;

vec3 tap(vec2 q) {
  q = clamp(q, vec2(0.5), uSize - 0.5);
  return texture(uTexture, vec2(q.x, uSize.y - q.y) / uSize).rgb;
}

void main() {
  vec2 fragCoord = FlutterFragCoord().xy;
  vec2 p = vec2(fragCoord.x, uSize.y - fragCoord.y);
  float k = uAmount;
  if (k <= 0.0) {
    fragColor = vec4(tap(p), 1.0);
    return;
  }
  vec2 c = 0.5 * uSize;
  float s = min(uSize.x, uSize.y);
  vec3 color;
  if (uStyle < 0.5) {
    color = mix(tap(p), vec3(uShape), k);
  } else if (uStyle < 1.5) {
    float soft = 1.0 + 0.3 * s * uShape;
    float reach = length(c) + soft;
    float r = reach - (reach + soft) * k;
    color = tap(p) * smoothstep(-0.5 * soft, 0.5 * soft, r - length(p - c));
  } else if (uStyle < 2.5) {
    float band = uSize.y / (1.0 + floor(7.0 * uShape + 0.5));
    float y = p.y - band * floor(p.y / band);
    float bar = (0.5 * band + 1.0) * k;
    color = tap(p) * clamp(min(y, band - y) - bar + 0.5, 0.0, 1.0);
  } else if (uStyle < 3.5) {
    float yN = p.y / uSize.y;
    float full = c.x + 1.0;
    float reach = max(full * k - uSwing * 0.18 * c.x * (1.0 - yN) * (1.0 - yN), 0.0);
    float inset = reach - min(p.x, uSize.x - p.x);
    float cloth = clamp(inset + 0.5, 0.0, 1.0);
    float along = clamp(inset, 0.0, reach) / max(reach, 0.001);
    float excess = max(full - reach, 0.0);
    float squeeze = 1.0 + 3.0 * excess * along * along / max(reach, 0.001);
    float folds = 3.0 + 9.0 * uShape;
    float width = full / folds;
    float fold = (clamp(inset, 0.0, reach) + excess * along * along * along) / width * (0.92 + 0.08 * yN);
    fold += 0.12 * sin(2.3 * fold + 0.4);
    float a = 6.2831853 * fract(fold);
    float relief = clamp(width / squeeze / (0.012 * s) - 0.5, 0.0, 1.0) * (0.7 + 0.3 * sin(1.7 * fold + 0.6));
    float ridge = 0.5 + 0.5 * relief * (sin(a) + 0.3 * sin(2.0 * a + 1.3)) / 1.3;
    float facing = relief * (cos(a) + 0.6 * cos(2.0 * a + 1.3)) / 1.6;
    float nap = 1.0 + 0.05 * relief * sin(43.982297 * fold + 1.0);
    float stack = 1.0 - 0.35 * clamp((squeeze - 1.0) / 6.0, 0.0, 1.0);
    float diffuse = (0.12 + 0.6 * ridge + 0.4 * (0.5 + 0.5 * facing)) * nap * stack;
    float sheen = facing * facing * (0.5 + 0.5 * facing);
    float light = (0.62 + 0.48 * yN) * (1.0 - 0.45 * exp((yN - 1.0) / 0.06)) * (1.0 - 0.45 * exp(-max(inset, 0.0) / (0.006 * s)));
    vec3 velvet = (vec3(0.52, 0.03, 0.06) * diffuse + vec3(0.4, 0.09, 0.1) * sheen) * light;
    float shade = 1.0 - 0.55 * min(reach / (0.04 * s), 1.0) * exp(min(inset, 0.0) / (0.04 * s));
    color = mix(tap(p) * shade * (1.0 - 0.2 * k), velvet, cloth);
  } else {
    float radius = (0.01 + 0.05 * uShape) * s * k;
    vec3 sum = vec3(0.0);
    vec2 dir = vec2(1.0, 0.0);
    for (int i = 0; i < 48; i++) {
      float r = radius * sqrt((float(i) + 0.5) / 48.0);
      sum += tap(p + r * dir);
      dir = vec2(dir.x * -0.73736888 - dir.y * 0.67549029, dir.x * 0.67549029 + dir.y * -0.73736888);
    }
    color = sum / 48.0;
  }
  fragColor = vec4(color, 1.0);
}
