#include "photo_handler.h"
#include "private_capture_file.h"

#include <gio/gio.h>
#include <gst/app/gstappsink.h>
#include <gst/video/video.h>

#include <cstdio>

bool PhotoHandler::TakePicture(GstElement* appsink,
                               const std::string& output_path,
                               GError** error) {
  if (!appsink) {
    g_set_error(error, G_IO_ERROR, G_IO_ERROR_FAILED,
                "Appsink is null, camera not initialized");
    return false;
  }

  // Use the last-sample property (read-only) to avoid consumer conflicts
  // with the preview stream.
  GstSample* sample = nullptr;
  g_object_get(appsink, "last-sample", &sample, nullptr);
  if (!sample) {
    g_set_error(error, G_IO_ERROR, G_IO_ERROR_FAILED,
                "No frame available for capture");
    return false;
  }

  // Convert the RGBA sample to JPEG.
  GstCaps* jpeg_caps = gst_caps_from_string("image/jpeg");
  GError* convert_error = nullptr;
  GstSample* converted = gst_video_convert_sample(
      sample, jpeg_caps, GST_SECOND * 5, &convert_error);
  gst_caps_unref(jpeg_caps);
  gst_sample_unref(sample);

  if (!converted) {
    g_propagate_error(error, convert_error);
    return false;
  }

  // Extract the JPEG buffer and write to file.
  GstBuffer* buffer = gst_sample_get_buffer(converted);
  GstMapInfo map;
  if (!gst_buffer_map(buffer, &map, GST_MAP_READ)) {
    gst_sample_unref(converted);
    g_set_error(error, G_IO_ERROR, G_IO_ERROR_FAILED,
                "Failed to map JPEG buffer");
    return false;
  }

  FILE* file = OpenPrivateCaptureFile(output_path.c_str(), error);
  if (!file) {
    gst_buffer_unmap(buffer, &map);
    gst_sample_unref(converted);
    return false;
  }

  size_t written = fwrite(map.data, 1, map.size, file);
  const bool closed = fclose(file) == 0;
  gst_buffer_unmap(buffer, &map);
  gst_sample_unref(converted);

  if (written != map.size || !closed) {
    g_set_error(error, G_IO_ERROR, G_IO_ERROR_FAILED,
                "Incomplete write to output file");
    return false;
  }

  return true;
}
