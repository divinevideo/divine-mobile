#pragma once

#include <string>
#include <vector>

struct DeviceInfo {
  std::wstring friendly_name;
  std::wstring symbolic_link;
};

class DeviceEnumerator {
 public:
  /// Returns all connected video capture devices.
  static std::vector<DeviceInfo> EnumerateVideoDevices();

  /// Finds the symbolic link for a camera whose dart-side name is |name|.
  /// The name format is "Friendly Name (symbolic_link)".
  /// Returns empty string if not found.
  static std::wstring FindSymbolicLink(const std::string& name);
};
