#ifndef DEVICE_ENUMERATOR_H_
#define DEVICE_ENUMERATOR_H_

#include <string>
#include <vector>

struct DeviceInfo {
  std::string device_path;   // e.g. "/dev/video0"
  std::string name;          // e.g. "Integrated Camera" (from v4l2 card field)
  std::string bus_info;      // e.g. "usb-0000:00:14.0-4" (for deduplication)
  int lens_direction;        // 0=front, 1=back, 2=external
  int sensor_orientation;    // 0 for most Linux webcams
};

struct ResolutionInfo {
  int width;
  int height;
  int max_fps;               // Best framerate at this resolution
};

// Resolution preset indices (matches Dart ResolutionPreset enum order).
enum ResolutionPreset {
  kLow = 0,       // <= 240p
  kMedium = 1,    // <= 480p
  kHigh = 2,      // <= 720p
  kVeryHigh = 3,  // <= 1080p
  kUltraHigh = 4, // <= 2160p
  kMax = 5,       // Highest available
};

class DeviceEnumerator {
 public:
  // Scans /dev/video* and returns capture-capable devices, deduplicated by
  // bus_info so each physical camera appears only once.
  static std::vector<DeviceInfo> EnumerateDevices();

  // Enumerates supported resolutions and frame rates for a device.
  // Handles discrete, stepwise, and continuous frame size types.
  static std::vector<ResolutionInfo> EnumerateResolutions(
      const std::string& device_path);

  // Picks the best resolution for a given preset from the list of supported
  // resolutions. Returns the highest resolution whose height fits within
  // the preset ceiling, with at least 15 FPS.
  static ResolutionInfo SelectResolution(
      const std::vector<ResolutionInfo>& resolutions,
      int preset);

  // Returns true if |device_path| can deliver motion-JPEG (either
  // V4L2_PIX_FMT_MJPEG or the older V4L2_PIX_FMT_JPEG) at the given
  // width/height. Used to decide between an MJPEG and a raw capture pipeline
  // BEFORE building it: gst_parse_launch() succeeds even for an MJPEG pipeline
  // the camera cannot satisfy, so the choice must be probed up front rather
  // than inferred from a parse failure that never happens. Frame rate is not
  // checked because the MJPEG pipeline lets the native rate float and adapts it
  // downstream with videorate; pinning a specific source fps would spuriously
  // reject cameras that offer the size at a different native rate. Returns false
  // on any uncertainty so callers fall back to the always-safe raw capture path.
  static bool SupportsMjpeg(const std::string& device_path, int width,
                            int height);
};

#endif  // DEVICE_ENUMERATOR_H_
