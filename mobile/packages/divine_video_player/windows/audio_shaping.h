#ifndef DIVINE_VIDEO_PLAYER_AUDIO_SHAPING_H_
#define DIVINE_VIDEO_PLAYER_AUDIO_SHAPING_H_

#include <flutter/encodable_value.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.Media.Playback.h>

#include <cstdint>
#include <memory>
#include <mutex>
#include <vector>

namespace divine_video_player {

// The activatable class id of the audio effect this plugin registers. The
// app manifest maps it to divine_video_player_plugin.dll, so Windows can
// create it for a MediaPlayer without the plugin being installed as a
// package.
inline constexpr wchar_t kAudioShapingEffectClass[] =
    L"DivineVideoPlayer.AudioShapingEffect";

// One band of Dart's AudioEqualizer.
struct EqualizerBand {
  enum class Type { kLowShelf, kPeak, kHighShelf };
  Type type = Type::kPeak;
  double frequency_hz = 1000;
  double gain_db = 0;
  double q = 0.7071067811865476;
};

// Reads AudioEqualizer.toMap() the way the Android and Apple players do:
// unusable bands are skipped, and an equalizer whose gains are all zero is
// empty.
std::vector<EqualizerBand> ParseEqualizer(const flutter::EncodableMap* map);

// What a player's sound passes through: an equalizer, then a gain above 1
// for volumes that amplify. Both feed a -1 dBFS limiter.
struct AudioShapingSettings {
  std::vector<EqualizerBand> bands;
  double boost = 1.0;
};

// Settings shared between a player and the audio effect that Windows creates
// for it on a Media Foundation thread.
class AudioShaping {
 public:
  void Set(AudioShapingSettings settings);
  AudioShapingSettings Get(uint64_t* version) const;

 private:
  mutable std::mutex mutex_;
  AudioShapingSettings settings_;
  uint64_t version_ = 1;
};

// Whether Windows can create the shaping effect, which needs the host app's
// manifest to register kAudioShapingEffectClass.
bool AudioShapingAvailable();

// Adds the shaping effect to `player`, reading its settings from `shaping`,
// and returns whether it did. Without the manifest entry the player is left
// untouched and plays unshaped.
bool AttachAudioShaping(
    const winrt::Windows::Media::Playback::MediaPlayer& player,
    const std::shared_ptr<AudioShaping>& shaping);

// Releases the link AttachAudioShaping made, once the player is closed.
void DetachAudioShaping(const std::shared_ptr<AudioShaping>& shaping);

// Applies settings to interleaved float samples. Exposed for the effect and
// kept free of Windows Runtime types so the math stays checkable.
class AudioShaper {
 public:
  void Configure(const AudioShapingSettings& settings, double sample_rate,
                 uint32_t channels);
  void Process(float* samples, size_t frames);
  void Reset();

 private:
  struct Biquad {
    double b0 = 1, b1 = 0, b2 = 0, a1 = 0, a2 = 0;
  };

  struct Limiter {
    double gain = 1.0;
    void Apply(float* samples, size_t frames, uint32_t channels,
               double release);
  };

  std::vector<Biquad> sections_;
  // z1, z2 for each section and channel.
  std::vector<double> state_;
  bool equalizer_boosts_ = false;
  double boost_ = 1.0;
  double release_ = 0;
  uint32_t channels_ = 0;
  Limiter equalizer_limiter_;
  Limiter boost_limiter_;
};

}  // namespace divine_video_player

#endif  // DIVINE_VIDEO_PLAYER_AUDIO_SHAPING_H_
