#include "photo_handler.h"
#include "private_capture_file.h"
#include "../../native/include/pixel_transform.h"

#include <gio/gio.h>
#include <gst/app/gstappsink.h>
#include <gst/video/video.h>

#include <cstdio>

bool PhotoHandler::TakePicture(GstElement* appsink,
                               const std::string& output_path,
                               GError** error, bool mirror_output) {
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

  if (mirror_output) {
    GstCaps* caps = gst_sample_get_caps(sample);
    GstVideoInfo info;
    GstBuffer* source = gst_sample_get_buffer(sample);
    GstBuffer* copy = source ? gst_buffer_copy_deep(source) : nullptr;
    GstVideoFrame frame;
    const bool mapped = copy && caps && gst_video_info_from_caps(&info, caps) &&
        GST_VIDEO_INFO_FORMAT(&info) == GST_VIDEO_FORMAT_RGBA &&
        gst_video_frame_map(&frame, &info, copy, GST_MAP_READWRITE);
    bool mirrored = false;
    if (mapped) {
      mirrored = divine_capture::MirrorFourByteRows(
          static_cast<uint8_t*>(GST_VIDEO_FRAME_PLANE_DATA(&frame, 0)),
          GST_VIDEO_FRAME_PLANE_STRIDE(&frame, 0),
          GST_VIDEO_FRAME_WIDTH(&frame), GST_VIDEO_FRAME_HEIGHT(&frame));
      gst_video_frame_unmap(&frame);
    }
    GstSample* output = mirrored
        ? gst_sample_new(copy, caps, gst_sample_get_segment(sample), nullptr)
        : nullptr;
    if (copy) gst_buffer_unref(copy);
    gst_sample_unref(sample);
    if (!output) {
      g_set_error(error, G_IO_ERROR, G_IO_ERROR_FAILED,
                  "Failed to mirror the captured frame");
      return false;
    }
    sample = output;
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
