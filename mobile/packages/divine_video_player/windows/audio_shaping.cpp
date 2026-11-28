#include "audio_shaping.h"

#include <MemoryBuffer.h>
#include <activation.h>
#include <winstring.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Media.Effects.h>
#include <winrt/Windows.Media.MediaProperties.h>
#include <winrt/Windows.Media.h>

#include <algorithm>
#include <cmath>
#include <map>
#include <string>
#include <string_view>
#include <utility>

#include "encodable_utils.h"
#include "native_log.h"

namespace divine_video_player {

namespace {

using flutter::EncodableList;
using flutter::EncodableMap;
using flutter::EncodableValue;
using winrt::Windows::Foundation::Collections::IPropertySet;
using winrt::Windows::Foundation::Collections::IVectorView;
using winrt::Windows::Foundation::Collections::PropertySet;
using winrt::Windows::Media::AudioBuffer;
using winrt::Windows::Media::AudioBufferAccessMode;
using winrt::Windows::Media::AudioFrame;
using winrt::Windows::Media::Effects::IBasicAudioEffect;
using winrt::Windows::Media::Effects::MediaEffectClosedReason;
using winrt::Windows::Media::Effects::ProcessAudioFrameContext;
using winrt::Windows::Media::MediaProperties::AudioEncodingProperties;

constexpr double kPi = 3.14159265358979323846;
// -1 dBFS, as on Android and Apple platforms.
constexpr double kLimiterCeiling = 0.891251;
constexpr double kLimiterReleaseSeconds = 0.05;
constexpr double kDefaultQ = 0.7071067811865476;
constexpr wchar_t kShapingIdKey[] = L"DivineShapingId";
constexpr char kAudioLog[] = "DivineVideoPlayer.Audio";

// Players' settings by an id the effect's configuration carries; the effect
// is created by Windows and can only be handed values, not pointers.
std::mutex g_registry_mutex;
std::map<uint64_t, std::weak_ptr<AudioShaping>> g_registry;

uint64_t RegistryId(const std::shared_ptr<AudioShaping>& shaping) {
  return reinterpret_cast<uint64_t>(shaping.get());
}

std::shared_ptr<AudioShaping> LookUp(uint64_t id) {
  std::lock_guard<std::mutex> lock(g_registry_mutex);
  const auto it = g_registry.find(id);
  return it == g_registry.end() ? nullptr : it->second.lock();
}

// Runs inside a MediaPlayer's audio pipeline and shapes its samples with the
// settings of the player that attached it.
struct AudioShapingEffect
    : winrt::implements<AudioShapingEffect, IBasicAudioEffect,
                        winrt::Windows::Media::IMediaExtension> {
  IVectorView<AudioEncodingProperties> SupportedEncodingProperties() {
    auto formats = winrt::single_threaded_vector<AudioEncodingProperties>();
    for (const uint32_t rate : {48000u, 44100u}) {
      for (const uint32_t channels : {2u, 1u}) {
        AudioEncodingProperties format =
            AudioEncodingProperties::CreatePcm(rate, channels, 32);
        format.Subtype(L"Float");
        formats.Append(format);
      }
    }
    return formats.GetView();
  }

  bool UseInputFrameForOutput() const { return true; }
  bool TimeIndependent() const { return true; }

  void SetEncodingProperties(const AudioEncodingProperties& format) {
    sample_rate_ = format.SampleRate();
    channels_ = format.ChannelCount();
    is_float_ = format.Subtype() == L"Float" && format.BitsPerSample() == 32;
    configured_version_ = 0;
    NativeLog::Debug(kAudioLog,
                     "Shaping effect runs at " + std::to_string(sample_rate_) +
                         " Hz, " + std::to_string(channels_) + " channel(s)" +
                         (is_float_ ? "" : ", passing through non-float audio"));
  }

  void ProcessFrame(const ProcessAudioFrameContext& context) {
    if (!shaping_ || !is_float_ || channels_ == 0) return;
    uint64_t version = 0;
    const AudioShapingSettings settings = shaping_->Get(&version);
    if (version != configured_version_) {
      shaper_.Configure(settings, sample_rate_, channels_);
      configured_version_ = version;
    }

    AudioFrame frame = context.InputFrame();
    AudioBuffer buffer = frame.LockBuffer(AudioBufferAccessMode::ReadWrite);
    auto reference = buffer.CreateReference();
    auto access =
        reference.as<::Windows::Foundation::IMemoryBufferByteAccess>();
    uint8_t* data = nullptr;
    uint32_t capacity = 0;
    winrt::check_hresult(access->GetBuffer(&data, &capacity));
    const size_t frames = buffer.Length() / (sizeof(float) * channels_);
    shaper_.Process(reinterpret_cast<float*>(data), frames);
  }

  void Close(MediaEffectClosedReason) { shaping_.reset(); }

  void DiscardQueuedFrames() { shaper_.Reset(); }

  void SetProperties(const IPropertySet& configuration) {
    if (!configuration || !configuration.HasKey(kShapingIdKey)) return;
    const auto id =
        winrt::unbox_value<uint64_t>(configuration.Lookup(kShapingIdKey));
    shaping_ = LookUp(id);
  }

 private:
  std::shared_ptr<AudioShaping> shaping_;
  AudioShaper shaper_;
  uint32_t sample_rate_ = 48000;
  uint32_t channels_ = 0;
  bool is_float_ = false;
  uint64_t configured_version_ = 0;
};

struct AudioShapingEffectFactory
    : winrt::implements<AudioShapingEffectFactory,
                        winrt::Windows::Foundation::IActivationFactory> {
  winrt::Windows::Foundation::IInspectable ActivateInstance() const {
    return winrt::make<AudioShapingEffect>();
  }
};

bool ReadBandType(const std::string& name, EqualizerBand::Type* type) {
  if (name == "lowShelf") {
    *type = EqualizerBand::Type::kLowShelf;
  } else if (name == "peak") {
    *type = EqualizerBand::Type::kPeak;
  } else if (name == "highShelf") {
    *type = EqualizerBand::Type::kHighShelf;
  } else {
    return false;
  }
  return true;
}

}  // namespace

std::vector<EqualizerBand> ParseEqualizer(const EncodableMap* map) {
  std::vector<EqualizerBand> bands;
  if (map == nullptr) return bands;
  const EncodableList* list = ReadList(*map, "bands");
  if (list == nullptr) return bands;
  bool any_gain = false;
  for (const EncodableValue& value : *list) {
    const auto* band_map = std::get_if<EncodableMap>(&value);
    if (band_map == nullptr) continue;
    EqualizerBand band;
    const std::optional<std::string> type = ReadString(*band_map, "type");
    if (!type || !ReadBandType(*type, &band.type)) continue;
    const std::optional<double> frequency =
        ReadDouble(*band_map, "frequencyHz");
    if (!frequency || !std::isfinite(*frequency) || *frequency <= 0) continue;
    band.frequency_hz = *frequency;
    band.gain_db = ReadDouble(*band_map, "gainDb").value_or(0.0);
    if (!std::isfinite(band.gain_db)) continue;
    const std::optional<double> q = ReadDouble(*band_map, "q");
    band.q = q && std::isfinite(*q) && *q > 0 ? *q : kDefaultQ;
    any_gain = any_gain || band.gain_db != 0;
    bands.push_back(band);
  }
  if (!any_gain) bands.clear();
  return bands;
}

void AudioShaping::Set(AudioShapingSettings settings) {
  std::lock_guard<std::mutex> lock(mutex_);
  settings_ = std::move(settings);
  ++version_;
}

AudioShapingSettings AudioShaping::Get(uint64_t* version) const {
  std::lock_guard<std::mutex> lock(mutex_);
  *version = version_;
  return settings_;
}

bool AudioShapingAvailable() {
  // Media Foundation fails the whole item, effectOptional or not, when the
  // effect class cannot be created, so a host without the manifest entry
  // must not be handed the effect at all.
  static const bool available = [] {
    try {
      winrt::get_activation_factory(
          winrt::hstring(kAudioShapingEffectClass));
      return true;
    } catch (const winrt::hresult_error& error) {
      NativeLog::Warning(
          kAudioLog,
          "Equalizers and volumes above 1 are off: the app manifest does not "
          "register DivineVideoPlayer.AudioShapingEffect (" +
              winrt::to_string(error.message()) + ")");
      return false;
    }
  }();
  return available;
}

bool AttachAudioShaping(
    const winrt::Windows::Media::Playback::MediaPlayer& player,
    const std::shared_ptr<AudioShaping>& shaping) {
  if (!AudioShapingAvailable()) return false;
  const uint64_t id = RegistryId(shaping);
  {
    std::lock_guard<std::mutex> lock(g_registry_mutex);
    g_registry[id] = shaping;
  }
  PropertySet configuration;
  configuration.Insert(kShapingIdKey, winrt::box_value(id));
  player.AddAudioEffect(kAudioShapingEffectClass, /*effectOptional=*/true,
                        configuration);
  return true;
}

void DetachAudioShaping(const std::shared_ptr<AudioShaping>& shaping) {
  std::lock_guard<std::mutex> lock(g_registry_mutex);
  g_registry.erase(RegistryId(shaping));
}

void AudioShaper::Configure(const AudioShapingSettings& settings,
                            double sample_rate, uint32_t channels) {
  const bool same_layout =
      settings.bands.size() == sections_.size() && channels == channels_;
  sections_.clear();
  equalizer_boosts_ = false;
  for (const EqualizerBand& band : settings.bands) {
    if (band.gain_db == 0) {
      // An identity section; keep the index so the history stays aligned.
      sections_.push_back(Biquad{});
      continue;
    }
    equalizer_boosts_ = equalizer_boosts_ || band.gain_db > 0;
    // RBJ Audio-EQ-Cookbook, normalised by a0, as on Android and Apple.
    const double a = std::pow(10.0, band.gain_db / 40.0);
    const double corner = std::clamp(band.frequency_hz, 1.0, 0.45 * sample_rate);
    const double w0 = 2.0 * kPi * corner / sample_rate;
    const double cosine = std::cos(w0);
    const double sine = std::sin(w0);
    double b0, b1, b2, a0, a1, a2;
    if (band.type == EqualizerBand::Type::kPeak) {
      const double alpha = sine / (2.0 * band.q);
      b0 = 1 + alpha * a;
      b1 = -2 * cosine;
      b2 = 1 - alpha * a;
      a0 = 1 + alpha / a;
      a1 = -2 * cosine;
      a2 = 1 - alpha / a;
    } else {
      // Shelf slope 1, so Q does not apply.
      const double alpha = sine / 2.0 * std::sqrt(2.0);
      const double k = 2.0 * std::sqrt(a) * alpha;
      if (band.type == EqualizerBand::Type::kLowShelf) {
        b0 = a * ((a + 1) - (a - 1) * cosine + k);
        b1 = 2 * a * ((a - 1) - (a + 1) * cosine);
        b2 = a * ((a + 1) - (a - 1) * cosine - k);
        a0 = (a + 1) + (a - 1) * cosine + k;
        a1 = -2 * ((a - 1) + (a + 1) * cosine);
        a2 = (a + 1) + (a - 1) * cosine - k;
      } else {
        b0 = a * ((a + 1) + (a - 1) * cosine + k);
        b1 = -2 * a * ((a - 1) + (a + 1) * cosine);
        b2 = a * ((a + 1) + (a - 1) * cosine - k);
        a0 = (a + 1) - (a - 1) * cosine + k;
        a1 = 2 * ((a - 1) - (a + 1) * cosine);
        a2 = (a + 1) - (a - 1) * cosine - k;
      }
    }
    sections_.push_back(
        Biquad{b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0});
  }
  channels_ = channels;
  boost_ = std::max(1.0, settings.boost);
  release_ = std::exp(-1.0 / (kLimiterReleaseSeconds * sample_rate));
  // Retuning with the same number of bands keeps the filter history, so a
  // control being dragged does not click.
  if (!same_layout) {
    state_.assign(sections_.size() * channels_ * 2, 0.0);
  }
  // A band at 0 dB is skipped, so its history starts clean if it returns.
  for (size_t s = 0; s < settings.bands.size(); ++s) {
    if (settings.bands[s].gain_db != 0) continue;
    std::fill_n(state_.begin() + s * channels_ * 2, channels_ * 2, 0.0);
  }
}

void AudioShaper::Reset() {
  std::fill(state_.begin(), state_.end(), 0.0);
  equalizer_limiter_.gain = 1.0;
  boost_limiter_.gain = 1.0;
}

void AudioShaper::Process(float* samples, size_t frames) {
  if (sections_.empty() && boost_ <= 1.0) return;
  if (!sections_.empty()) {
    for (size_t frame = 0; frame < frames; ++frame) {
      for (uint32_t channel = 0; channel < channels_; ++channel) {
        double sample = samples[frame * channels_ + channel];
        for (size_t s = 0; s < sections_.size(); ++s) {
          const Biquad& q = sections_[s];
          double* z = &state_[(s * channels_ + channel) * 2];
          // Transposed direct form II.
          const double out = q.b0 * sample + z[0];
          z[0] = q.b1 * sample - q.a1 * out + z[1];
          z[1] = q.b2 * sample - q.a2 * out;
          sample = out;
        }
        samples[frame * channels_ + channel] = static_cast<float>(sample);
      }
    }
    if (equalizer_boosts_) {
      equalizer_limiter_.Apply(samples, frames, channels_, release_);
    }
  }
  if (boost_ > 1.0) {
    const float gain = static_cast<float>(boost_);
    for (size_t i = 0; i < frames * channels_; ++i) samples[i] *= gain;
    boost_limiter_.Apply(samples, frames, channels_, release_);
  }
}

void AudioShaper::Limiter::Apply(float* samples, size_t frames,
                                 uint32_t channels, double release) {
  for (size_t frame = 0; frame < frames; ++frame) {
    float* values = samples + frame * channels;
    double peak = 0;
    for (uint32_t c = 0; c < channels; ++c) {
      peak = std::max(peak, static_cast<double>(std::abs(values[c])));
    }
    const double target = peak > kLimiterCeiling ? kLimiterCeiling / peak : 1.0;
    // Attack at once, release over 50 ms.
    gain = target < gain ? target : target + (gain - target) * release;
    if (gain < 1.0) {
      for (uint32_t c = 0; c < channels; ++c) {
        values[c] = static_cast<float>(values[c] * gain);
      }
    }
  }
}

}  // namespace divine_video_player

// Windows creates the effect through these exports: the app manifest names
// this DLL for kAudioShapingEffectClass. divine_video_player_plugin.def
// exports them undecorated.
extern "C" HRESULT __stdcall DllGetActivationFactory(
    HSTRING class_id, ::IActivationFactory** factory) {
  try {
    *factory = nullptr;
    uint32_t length = 0;
    const wchar_t* name = WindowsGetStringRawBuffer(class_id, &length);
    if (std::wstring_view(name, length) !=
        divine_video_player::kAudioShapingEffectClass) {
      return CLASS_E_CLASSNOTAVAILABLE;
    }
    winrt::Windows::Foundation::IActivationFactory created =
        winrt::make<divine_video_player::AudioShapingEffectFactory>();
    *factory = static_cast<::IActivationFactory*>(winrt::detach_abi(created));
    return S_OK;
  } catch (...) {
    return winrt::to_hresult();
  }
}

extern "C" HRESULT __stdcall DllCanUnloadNow() {
  // The plugin stays loaded for the life of the app.
  return S_FALSE;
}
