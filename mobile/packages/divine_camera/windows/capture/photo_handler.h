#pragma once

#include <cstdint>
#include <string>

class PhotoHandler {
 public:
  // Writes |bgra| pixels in the caller-selected saved orientation as a JPEG to |path|.
  // Returns true on success; sets |error| on failure.
  static bool Write(const uint8_t* bgra, int width, int height,
                    const std::wstring& path, std::string* error);
};
