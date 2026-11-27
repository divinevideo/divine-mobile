package co.openvine.app.videoeffects

import ch.waio.pro_video_editor.effects.CustomVideoEffectShader
import ch.waio.pro_video_editor.effects.CustomVideoEffects
import com.divinevideo.divine_video_player.VideoFrameEffects

/**
 * A blast in one of its [Style]s: plasma, an energy wave or a smoke burst.
 *
 * Within 60 ms of a strike the blast bursts, about half the frame's shorter
 * side across, and spreads as a ring with a ragged edge, past the farthest
 * corner about two thirds of the way through. The plasma bursts as a white-hot
 * ball with a hairy edge in its colour, which hollows out over the next 0.3 s
 * into a ring of liquid: a height field whose slope bends the picture like
 * water, by up to a tenth of the shorter side, whose depth tints it through the
 * colour, and which catches the light from the top left in glossy highlights.
 * The energy wave bursts as a ball glowing hot in its colour that opens into a
 * ring crackling with arcs, over a finer shimmer of heat. The smoke burst
 * pushes a billow of smoke in its colour outward, streaked from the middle,
 * densest at its front, shaded from the top left and thinning as it goes.
 * Within 16% of the shorter side from the frame's edge the bending eases off,
 * so it never reads past the edge. The picture rattles for 0.4 s and punches in
 * by up to 6%, zoomed in by just enough to keep its edges hidden.
 *
 * Its params, from the Dart `CustomVideoEffect`, are `intensity` (0–1: how hard
 * the blast lands), `strikesUs`, when it strikes, in microseconds after the
 * effect's start, `hitUs`, how long one blast lasts, which stretches or
 * squeezes its 0.8 s animation (see [BassHits]), and the look the user set (see
 * [HitLook]): where it bursts, how far it spreads, how hard the picture rattles
 * and punches in, and its colour, each style's own by default. Each style
 * flashes, so the Dart side times the strikes, on the beat, once or again and
 * again, within three flashes a second together with the video's other flashes,
 * and this draws them as they come.
 */
class BlastVideoEffect(private val style: Style, params: Map<String, Any?>) :
    ShaderVideoEffect(FRAGMENT_SHADER) {

    /** How the blast looks; [shaderValue] is what the shader branches on. */
    enum class Style(val id: String, val shaderValue: Float, val defaultColor: Long) {
        PLASMA("divine.plasma", 0f, 0xFF4CBFFF),
        ENERGY("divine.energyWave", 1f, 0xFFFF290F),
        SMOKE("divine.smokeBurst", 2f, 0xFFD1CFC9),
    }

    private val intensity = intensityOf(params)

    private val look = HitLook(params, style.defaultColor)

    private val strikesUs = LightningStrikes.strikesOf(params)

    private val hitUs = BassHits.hitOf(params, BLAST_US)

    override fun setUniforms(shader: CustomVideoEffectShader, effectTimeUs: Long) {
        val age = BassHits.ageOf(strikesUs, hitUs, BLAST_US, effectTimeUs)
        shader.setFloat("uIntensity", if (age == null) 0f else intensity)
        shader.setFloat("uAge", age ?: 0f)
        shader.setFloat("uStyle", style.shaderValue)
        shader.setFloat("uReach", look.reach)
        shader.setFloats("uCenter", look.center)
        shader.setFloat("uShake", look.shake)
        shader.setFloat("uPunch", look.punch)
        shader.setFloats("uColor", look.color)
    }

    companion object {
        /** How long a blast's own animation lasts: the ring has spread past the corners by then. */
        const val BLAST_US = 800_000L

        /** Registers every style, each under its own id, for exports and for the editor preview. */
        fun register() {
            for (style in Style.values()) {
                CustomVideoEffects.register(style.id) { params -> BlastVideoEffect(style, params) }
                VideoFrameEffects.register(style.id) { params -> BlastVideoEffect(style, params) }
            }
        }

        // `s` is the frame's shorter side, and `a` the pixel's offset from the
        // centre in shorter sides; `plasma`, `energy` and `smoke` are 1 for the
        // style drawn and 0 for the others, whose terms they multiply away.
        // The hash is Dave Hoskins' "hash without sine" with 3.33 in place of
        // its 33.33, as the paint effects use it. `liquid` is the height of the
        // liquid, or of the shimmering air, at `a`: a swell along the ring and
        // ripples in its wake. At no intensity every term is zero and each
        // pixel is read as it is.
        private const val FRAGMENT_SHADER = ShaderVideoEffect.PRELUDE + """
uniform float uIntensity;
uniform float uAge;
uniform float uStyle;
uniform float uReach;
uniform vec2 uCenter;
uniform float uShake;
uniform float uPunch;
uniform vec3 uColor;

float hash(vec2 q) {
  vec3 r = fract(vec3(q.xyx) * 0.1031);
  r += dot(r, r.yzx + 3.33);
  return fract((r.x + r.y) * r.z);
}

float noise(vec2 q) {
  vec2 i = floor(q);
  vec2 f = q - i;
  f = f * f * (3.0 - 2.0 * f);
  float bottom = mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x);
  float top = mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x);
  return mix(bottom, top, f.y);
}

float fbm(vec2 q) {
  return (0.5 * noise(q) + 0.25 * noise(q * 2.03 + 17.1) + 0.125 * noise(q * 4.01 + 41.7)) / 0.875;
}

float liquid(vec2 a, float lobe, float ring, float wide, vec2 warp, float age, float calm, float grain) {
  float x = (length(a) + lobe - ring) / wide;
  float behind = ring - length(a) - lobe;
  float wake = smoothstep(-0.03, 0.06, behind) * (1.0 - smoothstep(0.08, 0.45, behind));
  float ripples = fbm(a * grain + 2.2 * warp + vec2(0.7 * age, -0.9 * age));
  return exp(-x * x) * (0.6 + 0.8 * ripples) + calm * wake * ripples;
}

void main() {
  if (uIntensity <= 0.0) {
    gl_FragColor = vec4(texture2D(uFrame, vTexCoord).rgb, 1.0);
    return;
  }
  vec2 p = vTexCoord * uSize;
  vec2 c = vec2(uCenter.x, 1.0 - uCenter.y) * uSize;
  vec2 m = uSize * 0.5;
  float s = min(uSize.x, uSize.y);
  vec2 d = p - c;
  float r = length(d);
  vec2 dir = d / max(r, 0.001);
  vec2 a = d / s;
  float edge = min(min(p.x, uSize.x - p.x), min(p.y, uSize.y - p.y));
  float keep = smoothstep(0.0, 0.16 * s, edge);
  float smoke = step(1.5, uStyle);
  float energy = step(0.5, uStyle) - smoke;
  float plasma = 1.0 - energy - smoke;

  float t = min(uAge / 0.8, 1.0);
  float pop = min(uAge / 0.06, 1.0);
  pop = 1.0 - (1.0 - pop) * (1.0 - pop);
  float far = 1.6 * uReach * length(max(c, uSize - c)) / s;
  float ring = 0.28 * pop + max(far - 0.28, 0.0) * pow(t, 1.1);
  float wide = 0.07 + 0.08 * t;
  float calm = 1.0 - t * t;
  float lobes = fbm(dir * 2.5 + vec2(3.0 * uAge, -2.0 * uAge));
  float lobe = 0.07 * (lobes - 0.5) * (0.3 + ring) * smoothstep(0.0, 0.08, r / s);
  vec2 warp = vec2(noise(a * 2.5 + vec2(0.0, uAge)), noise(a * 2.5 + vec2(5.2, 1.3 - uAge)));
  float grain = 4.0 + 5.0 * energy;

  float h = liquid(a, lobe, ring, wide, warp, uAge, calm, grain);
  float hx = liquid(a + vec2(0.004, 0.0), lobe, ring, wide, warp, uAge, calm, grain);
  float hy = liquid(a + vec2(0.0, 0.004), lobe, ring, wide, warp, uAge, calm, grain);
  vec2 slope = vec2(hx - h, hy - h) / 0.004;
  float amount = uIntensity * calm;
  float bend = 0.012 * plasma + 0.006 * energy + 0.004 * smoke;
  vec2 q = p - s * bend * amount * keep * slope;

  float rattle = max(1.0 - uAge / 0.4, 0.0);
  rattle = rattle * rattle * rattle;
  float punch = max(1.0 - uAge / 0.3, 0.0);
  punch = punch * punch;
  float jolt = 0.012 * uIntensity * uShake * rattle;
  float zoom = 1.0 + 2.2 * jolt + 0.06 * uIntensity * uPunch * punch;
  vec2 shake = jolt * s * vec2(sin(81.681 * uAge + 0.6), sin(106.814 * uAge + 2.1));
  q = m + (q - m) / zoom + shake;

  vec3 color = tap(q);
  float depth = clamp(h * 1.2, 0.0, 1.0) * amount;
  color *= mix(vec3(1.0), uColor * uColor, (0.9 * plasma + 0.6 * energy) * depth);
  vec3 normal = normalize(vec3(-0.08 * slope, 1.0));
  float facing = max(dot(normal, vec3(-0.2159, 0.3022, 0.9282)), 0.0);
  float shine = (1.3 * pow(facing, 48.0) + 0.3 * pow(facing, 8.0)) * clamp(h * 3.0, 0.0, 1.0);
  color += plasma * amount * shine * mix(uColor, vec3(1.0), 0.5);

  float rr = r / s + lobe;
  float x = (rr - ring) / wide;
  float arc = 1.0 - abs(2.0 * noise(a * 9.0 + 3.0 * warp + vec2(4.0 * uAge, -5.0 * uAge)) - 1.0);
  arc = pow(arc, 14.0) * exp(-x * x) * (1.0 + 2.0 * clamp(h - 0.5, 0.0, 1.0));
  color += energy * amount * arc * mix(uColor, vec3(1.0), 0.35);

  vec2 billow = a * 2.5 / (0.5 + ring) + 1.5 * warp + vec2(0.4 * uAge, 0.3 * uAge);
  float streaks = mix(0.5, fbm(dir * 7.0 + vec2(1.3 * rr - 2.0 * uAge, 0.0)), smoothstep(0.05, 0.25, r / s));
  float puffs = 0.7 * fbm(billow) + 0.3 * streaks;
  float lit = 0.7 * fbm(billow + vec2(-0.25, 0.35)) + 0.3 * streaks;
  float front = exp(-(rr - ring + 0.06) * (rr - ring + 0.06) / 0.02);
  float thick = (1.0 - smoothstep(ring - 0.04, ring + 0.08, rr)) * (0.35 + 0.65 * front);
  float cloud = smoothstep(0.2, 0.6, puffs * (0.7 + 0.6 * thick)) * thick;
  float shade = clamp(0.7 + 3.0 * (lit - puffs), 0.35, 1.1);
  color = mix(color, uColor * shade, smoke * uIntensity * 0.9 * cloud * (1.0 - t * t * t));

  float hair = fbm(dir * 24.0 + vec2(-9.0 * uAge, 7.0 * uAge));
  float inside = 1.0 - smoothstep(ring - 0.03, ring + 0.005, rr);
  float hollow = ring * smoothstep(0.08, 0.35, t);
  float core = inside * smoothstep(hollow - 0.12, hollow, rr) * (1.0 - smoothstep(0.0, 0.4, t));
  float halo = exp(-max(rr - ring, 0.0) / (0.012 + 0.05 * hair * hair)) * (1.0 - inside);
  float rim = exp(-(rr - ring) * (rr - ring) / 0.0004);
  float glow = (1.0 - smoke) * uIntensity * min(1.4 * core + (0.7 * rim + 0.6 * halo) * calm, 1.0);
  vec3 hot = mix(uColor, vec3(1.0), 0.8);
  vec3 light = mix(uColor, hot, clamp(1.6 * core, 0.0, 1.0));
  gl_FragColor = vec4(clamp(mix(color, light, glow), 0.0, 1.0), 1.0);
}
"""
    }
}
