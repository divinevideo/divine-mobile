#include "device_enumerator.h"

#include <fcntl.h>
#include <glib.h>
#include <linux/videodev2.h>
#include <sys/ioctl.h>
#include <unistd.h>

#include <algorithm>
#include <cstring>
#include <set>

static const int kMaxDeviceIndex = 64;
static const int kMinFps = 15;

// Standard resolutions to probe when the device reports stepwise/continuous
// frame sizes instead of discrete sizes.
static const int kStandardHeights[] = {240, 480, 720, 1080, 2160};
static const int kStandardWidths[] = {320, 640, 1280, 1920, 3840};

// Maximum height per resolution preset.
static int MaxHeightForPreset(int preset) {
  switch (preset) {
    case ResolutionPreset::kLow:
      return 240;
    case ResolutionPreset::kMedium:
      return 480;
    case ResolutionPreset::kHigh:
      return 720;
    case ResolutionPreset::kVeryHigh:
      return 1080;
    case ResolutionPreset::kUltraHigh:
      return 2160;
    case ResolutionPreset::kMax:
    default:
      return 99999;
  }
}

// Queries the maximum FPS for a given format and resolution via
// VIDIOC_ENUM_FRAMEINTERVALS. Returns 0 if it cannot be determined.
static int QueryMaxFps(int fd, __u32 pixel_format, int width, int height) {
  struct v4l2_frmivalenum frmival;
  memset(&frmival, 0, sizeof(frmival));
  frmival.pixel_format = pixel_format;
  frmival.width = width;
  frmival.height = height;
  frmival.index = 0;

  int max_fps = 0;
  while (ioctl(fd, VIDIOC_ENUM_FRAMEINTERVALS, &frmival) == 0) {
    if (frmival.type == V4L2_FRMIVAL_TYPE_DISCRETE) {
      if (frmival.discrete.numerator > 0) {
        int fps = frmival.discrete.denominator / frmival.discrete.numerator;
        if (fps > max_fps) max_fps = fps;
      }
    } else if (frmival.type == V4L2_FRMIVAL_TYPE_STEPWISE ||
               frmival.type == V4L2_FRMIVAL_TYPE_CONTINUOUS) {
      // Use the minimum interval (= maximum fps).
      if (frmival.stepwise.min.numerator > 0) {
        int fps =
            frmival.stepwise.min.denominator / frmival.stepwise.min.numerator;
        if (fps > max_fps) max_fps = fps;
      }
      break;  // Only one entry for stepwise/continuous.
    }
    frmival.index++;
  }
  return max_fps > 0 ? max_fps : 30;  // Default to 30 if unknown.
}

std::vector<DeviceInfo> DeviceEnumerator::EnumerateDevices() {
  std::vector<DeviceInfo> devices;
  std::set<std::string> seen_bus_info;
  int open_failures = 0;

  for (int i = 0; i < kMaxDeviceIndex; i++) {
    char path[32];
    snprintf(path, sizeof(path), "/dev/video%d", i);

    int fd = open(path, O_RDONLY | O_NONBLOCK);
    if (fd < 0) {
      open_failures++;
      continue;
    }

    struct v4l2_capability cap;
    memset(&cap, 0, sizeof(cap));
    if (ioctl(fd, VIDIOC_QUERYCAP, &cap) != 0) {
      close(fd);
      continue;
    }

    // Use per-node device_caps when available, otherwise fall back to
    // device-wide capabilities.
    __u32 effective_caps = (cap.capabilities & V4L2_CAP_DEVICE_CAPS)
                               ? cap.device_caps
                               : cap.capabilities;

    // Must support video capture (single-plane or multi-plane).
    bool is_capture =
        (effective_caps &
         (V4L2_CAP_VIDEO_CAPTURE | V4L2_CAP_VIDEO_CAPTURE_MPLANE)) != 0;

    // Filter out non-camera nodes (M2M, metadata, output-only).
    bool is_non_camera =
        (effective_caps & (V4L2_CAP_VIDEO_M2M | V4L2_CAP_VIDEO_M2M_MPLANE |
                           V4L2_CAP_META_CAPTURE | V4L2_CAP_VIDEO_OUTPUT)) !=
        0;

    if (!is_capture || is_non_camera) {
      close(fd);
      continue;
    }

    // Deduplicate by bus_info, each physical camera may expose multiple nodes.
    std::string bus(reinterpret_cast<const char*>(cap.bus_info));
    if (!bus.empty() && seen_bus_info.count(bus)) {
      close(fd);
      continue;
    }
    if (!bus.empty()) seen_bus_info.insert(bus);

    DeviceInfo info;
    info.device_path = path;
    info.name = reinterpret_cast<const char*>(cap.card);
    info.bus_info = bus;
    // Most Linux webcams are external USB cameras.
    info.lens_direction = 2;  // CameraLensDirection.external
    info.sensor_orientation = 0;
    devices.push_back(info);

    close(fd);
  }
  if (open_failures > 0) {
    g_info("[camera_desktop] V4L2 enumeration: %d /dev/videoN node(s) could"
           " not be opened (normal if indices are sparse)", open_failures);
  }
  g_info("[camera_desktop] V4L2 enumeration found %zu camera(s)", devices.size());
  for (const auto& d : devices) {
    g_info("[camera_desktop]   → %s (%s)", d.name.c_str(), d.device_path.c_str());
  }
  return devices;
}

std::vector<ResolutionInfo> DeviceEnumerator::EnumerateResolutions(
    const std::string& device_path) {
  std::vector<ResolutionInfo> resolutions;

  int fd = open(device_path.c_str(), O_RDONLY | O_NONBLOCK);
  if (fd < 0) {
    g_info("[camera_desktop] EnumerateResolutions: failed to open %s",
           device_path.c_str());
    return resolutions;
  }

  struct v4l2_fmtdesc fmt;
  memset(&fmt, 0, sizeof(fmt));
  fmt.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
  fmt.index = 0;

  // Track seen width×height pairs to avoid duplicates across formats.
  std::set<std::pair<int, int>> seen;

  while (ioctl(fd, VIDIOC_ENUM_FMT, &fmt) == 0) {
    struct v4l2_frmsizeenum frmsize;
    memset(&frmsize, 0, sizeof(frmsize));
    frmsize.pixel_format = fmt.pixelformat;
    frmsize.index = 0;

    while (ioctl(fd, VIDIOC_ENUM_FRAMESIZES, &frmsize) == 0) {
      if (frmsize.type == V4L2_FRMSIZE_TYPE_DISCRETE) {
        int w = frmsize.discrete.width;
        int h = frmsize.discrete.height;
        int fps = QueryMaxFps(fd, fmt.pixelformat, w, h);
        if (!seen.count({w, h})) {
          seen.insert({w, h});
          resolutions.push_back({w, h, fps});
        } else {
          // Same resolution may appear in MJPEG and YUYV with different fps.
          for (auto& r : resolutions) {
            if (r.width == w && r.height == h && fps > r.max_fps) {
              r.max_fps = fps;
            }
          }
        }
      } else if (frmsize.type == V4L2_FRMSIZE_TYPE_STEPWISE ||
                 frmsize.type == V4L2_FRMSIZE_TYPE_CONTINUOUS) {
        // Generate standard resolutions within the reported range.
        for (int si = 0; si < 5; si++) {
          int w = kStandardWidths[si];
          int h = kStandardHeights[si];
          if (w >= (int)frmsize.stepwise.min_width &&
              w <= (int)frmsize.stepwise.max_width &&
              h >= (int)frmsize.stepwise.min_height &&
              h <= (int)frmsize.stepwise.max_height &&
              !seen.count({w, h})) {
            seen.insert({w, h});
            int fps = QueryMaxFps(fd, fmt.pixelformat, w, h);
            resolutions.push_back({w, h, fps});
          }
        }
        break;  // One entry for stepwise/continuous.
      }
      frmsize.index++;
    }
    fmt.index++;
  }

  close(fd);

  // Sort by resolution (height primary, width secondary) descending.
  std::sort(resolutions.begin(), resolutions.end(),
            [](const ResolutionInfo& a, const ResolutionInfo& b) {
              if (a.height != b.height) return a.height > b.height;
              return a.width > b.width;
            });

  g_info("[camera_desktop] Device %s: %zu resolution(s) available",
         device_path.c_str(), resolutions.size());

  return resolutions;
}

// Returns true if |pixel_format| on |fd| offers |width|x|height| as a discrete
// size or within a stepwise/continuous range. Conservative: returns false if
// the size is not advertised. Frame rate is intentionally not checked here; see
// SupportsMjpeg.
static bool FormatSupportsSize(int fd, __u32 pixel_format, int width,
                               int height) {
  struct v4l2_frmsizeenum frmsize;
  memset(&frmsize, 0, sizeof(frmsize));
  frmsize.pixel_format = pixel_format;
  frmsize.index = 0;

  while (ioctl(fd, VIDIOC_ENUM_FRAMESIZES, &frmsize) == 0) {
    if (frmsize.type == V4L2_FRMSIZE_TYPE_DISCRETE) {
      if ((int)frmsize.discrete.width == width &&
          (int)frmsize.discrete.height == height) {
        return true;
      }
    } else if (frmsize.type == V4L2_FRMSIZE_TYPE_STEPWISE ||
               frmsize.type == V4L2_FRMSIZE_TYPE_CONTINUOUS) {
      // One entry for stepwise/continuous; the size is in range or it is not.
      return width >= (int)frmsize.stepwise.min_width &&
             width <= (int)frmsize.stepwise.max_width &&
             height >= (int)frmsize.stepwise.min_height &&
             height <= (int)frmsize.stepwise.max_height;
    }
    frmsize.index++;
  }
  return false;
}

bool DeviceEnumerator::SupportsMjpeg(const std::string& device_path,
                                     int width, int height) {
  int fd = open(device_path.c_str(), O_RDONLY | O_NONBLOCK);
  if (fd < 0) {
    return false;
  }

  bool supported = false;
  struct v4l2_fmtdesc fmt;
  memset(&fmt, 0, sizeof(fmt));
  fmt.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
  fmt.index = 0;

  while (ioctl(fd, VIDIOC_ENUM_FMT, &fmt) == 0) {
    // Cameras advertise motion-JPEG as either V4L2_PIX_FMT_MJPEG or the older
    // V4L2_PIX_FMT_JPEG; GStreamer's image/jpeg + jpegdec decodes both. Only the
    // target size must be offered: the MJPEG pipeline pins width/height but lets
    // the native frame rate float, and the downstream videorate adapts it to the
    // requested fps (the same way the raw-capture path does).
    if ((fmt.pixelformat == V4L2_PIX_FMT_MJPEG ||
         fmt.pixelformat == V4L2_PIX_FMT_JPEG) &&
        FormatSupportsSize(fd, fmt.pixelformat, width, height)) {
      supported = true;
      break;
    }
    fmt.index++;
  }

  close(fd);
  g_info("[camera_desktop] SupportsMjpeg(%s, %dx%d) = %s",
         device_path.c_str(), width, height, supported ? "true" : "false");
  return supported;
}

ResolutionInfo DeviceEnumerator::SelectResolution(
    const std::vector<ResolutionInfo>& resolutions,
    int preset) {
  int max_height = MaxHeightForPreset(preset);

  // Find the highest resolution that fits within the preset ceiling and
  // has at least kMinFps. Resolutions are sorted descending.
  for (const auto& r : resolutions) {
    if (r.height <= max_height && r.max_fps >= kMinFps) {
      g_info("[camera_desktop] SelectResolution(preset=%d): primary match"
             " %dx%d@%dfps", preset, r.width, r.height, r.max_fps);
      return r;
    }
  }
  // Fallback: relax FPS requirement.
  for (const auto& r : resolutions) {
    if (r.height <= max_height) {
      g_info("[camera_desktop] SelectResolution(preset=%d): relaxed-FPS"
             " fallback %dx%d@%dfps", preset, r.width, r.height, r.max_fps);
      return r;
    }
  }
  // Absolute fallback: return the lowest resolution available.
  if (!resolutions.empty()) {
    const auto& r = resolutions.back();
    g_info("[camera_desktop] SelectResolution(preset=%d): lowest-available"
           " fallback %dx%d@%dfps", preset, r.width, r.height, r.max_fps);
    return r;
  }
  // No resolutions found, return a default and let GStreamer negotiate.
  g_info("[camera_desktop] SelectResolution(preset=%d): no resolutions"
         " available, using hardcoded default 640x480@30fps", preset);
  return {640, 480, 30};
}
