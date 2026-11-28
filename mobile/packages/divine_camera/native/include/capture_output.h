#ifndef DIVINE_CAPTURE_OUTPUT_H_
#define DIVINE_CAPTURE_OUTPUT_H_

#include <filesystem>
#include <stdexcept>

// The Dart owner allocates one private directory before each capture.
enum class CaptureFileKind { kPhoto, kVideo };

inline std::filesystem::path CaptureOutputFile(
    const std::filesystem::path& directory, CaptureFileKind kind) {
  std::error_code error;
  if (!directory.is_absolute() ||
      !std::filesystem::is_directory(directory, error) || error) {
    throw std::invalid_argument(
        "Capture output directory must exist and be absolute");
  }
  const auto output = directory /
      (kind == CaptureFileKind::kPhoto ? "photo.jpg" : "recording.mp4");
  const auto status = std::filesystem::symlink_status(output, error);
  if (status.type() != std::filesystem::file_type::not_found ||
      (error && error != std::errc::no_such_file_or_directory)) {
    throw std::invalid_argument("Capture output must not already exist");
  }
  return output;
}

#endif  // DIVINE_CAPTURE_OUTPUT_H_
