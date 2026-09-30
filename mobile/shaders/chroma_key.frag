// Live-preview chroma key for the video editor.
//
// This is a port of pro_video_editor's render-side keyer so the editor preview
// and the exported file agree. The formula is specified once, in the plugin's
// `ChromaKeyMath` (Kotlin), and implemented by its GLES fragment shader and by
// Apple's Core Image colour cube. This file is the third implementation and
// must stay in lockstep with it — every constant below is copied from there.
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
uniform float uSpill;

// The key colour's luma, and how much brightness counts toward the matte:
// 0 for a saturated key, 1 for a neutral one (ChromaKeyDetector.lumaWeightOf).
uniform float uKeyLuma;
uniform float uLumaWeight;

// Engine-set: the filter input.
uniform sampler2D uTexture;

out vec4 fragColor;

void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
// Impeller's OpenGLES backend hands the texture over y-flipped.
#ifdef IMPELLER_TARGET_OPENGLES
  uv.y = 1.0 - uv.y;
#endif

  vec4 src = texture(uTexture, uv);

  // Flutter's texture is premultiplied; the key is specified on straight RGB.
  // A fully transparent source pixel (the rounded corners the player is clipped
  // to, or a letterbox gap) carries no colour to key, and `outA` below folds
  // its zero alpha back in, so the branch value never reaches the output.
  vec3 rgb = src.a > 0.0 ? src.rgb / src.a : vec3(0.0);

  float y = dot(rgb, vec3(0.299, 0.587, 0.114));
  vec2 cbcr = vec2(
      dot(rgb, vec3(-0.168736, -0.331264, 0.5)),
      dot(rgb, vec3(0.5, -0.418688, -0.081312)));

  // Matte: distance in the chroma plane, plus brightness weighted by how
  // neutral the key is, ramped by smoothstep. `max` keeps a zero-width ramp
  // from dividing by zero.
  float d = length(vec3(cbcr - uKeyCbCr, (y - uKeyLuma) * uLumaWeight));
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
