// Live-preview chroma key for the video editor.
//
// This is a port of pro_video_editor's render-side keyer so the editor preview
// and the exported file agree. The formula is specified once, in the plugin's
// `ChromaKeyMath` (Kotlin), and implemented by its GLES fragment shader and by
// its Metal kernel on Apple. This file is the third implementation and
// must stay in lockstep with it — every constant below is copied from there.
//
// Like the renderers, the matte is ramped on the binomial average of each
// pixel's 3x3 neighbourhood of key distances
// (`ChromaKeyMath.neighbourhoodDistance`). The preview filters the picture as
// drawn on screen, so its neighbourhood is three screen pixels rather than
// three video pixels; at a phone's size the two are about equal.
//
// Differences from the render-side shader, both deliberate:
//
//   * It only ever produces the transparent variant. The colour / image / video
//     background is composited *behind* this widget by Flutter, which keeps one
//     shader for all four background modes and needs no second sampler.
//   * Flutter composites premultiplied, the plugin's GLES path is straight
//     alpha (Media3's convention). Input is un-premultiplied on the way in and
//     the result is premultiplied on the way out.

#include <flutter/runtime_effect.glsl>

// Engine-set: the size of the bound texture. Must be the first uniform.
uniform vec2 uSize;

// The key's position in the Cb/Cr chroma plane.
uniform vec2 uKeyCbCr;

// Unit vector from neutral toward the key hue; zero for a neutral key colour,
// which disables despill rather than dividing by zero.
uniform vec2 uKeyDir;

uniform float uSimilarity;
uniform float uSmoothness;

// Already scaled by (1 - uLumaWeight), as the renderers do, so a neutral key
// does not despill.
uniform float uSpill;

// The key colour's luma, and how much brightness counts toward the matte:
// 0 for a saturated key, 1 for a neutral one (ChromaKeyDetector.lumaWeightOf).
uniform float uKeyLuma;
uniform float uLumaWeight;

// Engine-set: the filter input.
uniform sampler2D uTexture;

out vec4 fragColor;

// Flutter's texture is premultiplied; the key is specified on straight RGB.
// A fully transparent pixel (the rounded corners the player is clipped to, or
// a letterbox gap) carries no colour to key and reads as black; the centre's
// own zero alpha is folded back in below, so it never reaches the output.
vec3 straight(vec4 premultiplied) {
  return premultiplied.a > 0.0 ? premultiplied.rgb / premultiplied.a
                               : vec3(0.0);
}

// The key distance of one pixel: chroma, plus brightness weighted by how
// neutral the key is (`ChromaKeyMath.distance`).
float keyDistance(vec3 rgb) {
  float y = dot(rgb, vec3(0.299, 0.587, 0.114));
  vec2 cbcr = vec2(
      dot(rgb, vec3(-0.168736, -0.331264, 0.5)),
      dot(rgb, vec3(0.5, -0.418688, -0.081312)));
  return length(vec3(cbcr - uKeyCbCr, (y - uKeyLuma) * uLumaWeight));
}

// The key distance of the neighbour `offset` pixels away, clamped to the edge.
float tap(vec2 uv, vec2 offset) {
  vec2 texel = 1.0 / uSize;
  vec2 coord = clamp(uv + offset * texel, 0.5 * texel, 1.0 - 0.5 * texel);
  return keyDistance(straight(texture(uTexture, coord)));
}

void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
// Impeller's OpenGLES backend hands the texture over y-flipped.
#ifdef IMPELLER_TARGET_OPENGLES
  uv.y = 1.0 - uv.y;
#endif

  vec4 src = texture(uTexture, uv);
  vec3 rgb = straight(src);

  float y = dot(rgb, vec3(0.299, 0.587, 0.114));
  vec2 cbcr = vec2(
      dot(rgb, vec3(-0.168736, -0.331264, 0.5)),
      dot(rgb, vec3(0.5, -0.418688, -0.081312)));

  // Matte: the neighbourhood's binomial average, ramped by smoothstep. The
  // weights are symmetric, so the y-flip above leaves it unchanged. `max`
  // keeps a zero-width ramp from dividing by zero.
  float nw = tap(uv, vec2(-1.0, -1.0));
  float n = tap(uv, vec2(0.0, -1.0));
  float ne = tap(uv, vec2(1.0, -1.0));
  float w = tap(uv, vec2(-1.0, 0.0));
  float c = keyDistance(rgb);
  float e = tap(uv, vec2(1.0, 0.0));
  float sw = tap(uv, vec2(-1.0, 1.0));
  float s = tap(uv, vec2(0.0, 1.0));
  float se = tap(uv, vec2(1.0, 1.0));
  float d = (4.0 * c + 2.0 * (n + w + e + s) + nw + ne + sw + se) / 16.0;
  float a = smoothstep(uSimilarity, uSimilarity + max(uSmoothness, 1e-4), d);

  // Spill: remove the chroma component pointing at the key hue, keeping y so a
  // despilled pixel never darkens. Only pixels leaning toward the key
  // (projection > 0) are touched, so a complementary colour is never
  // desaturated.
  float projection = dot(cbcr, uKeyDir);
  if (uSpill > 0.0 && projection > 0.0) {
    vec2 c = cbcr - uKeyDir * projection * uSpill;
    rgb = clamp(vec3(
        y + 1.402 * c.y,
        y - 0.344136 * c.x - 0.714136 * c.y,
        y + 1.772 * c.x), 0.0, 1.0);
  }

  float outA = src.a * a;
  fragColor = vec4(rgb * outA, outA);
}
