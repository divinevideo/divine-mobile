#ifndef PHOTO_HANDLER_H_
#define PHOTO_HANDLER_H_

#include <gst/gst.h>
#include <string>

class PhotoHandler {
 public:
  // Captures a still image from the appsink's last-sample property (read-only,
  // no consumer conflict with the preview stream). Converts the RGBA frame to
  // JPEG via gst_video_convert_sample and writes it to |output_path|.
  // Returns true on success; sets |error| on failure.
  static bool TakePicture(GstElement* appsink,
                          const std::string& output_path,
                          GError** error);
};

#endif  // PHOTO_HANDLER_H_
