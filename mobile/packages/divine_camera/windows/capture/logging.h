#pragma once

#include <windows.h>

#include <cstdio>
#include <sstream>
#include <string>

// Diagnostic logging is opt-in and OFF by default, so the plugin stays quiet in
// consumer apps and avoids the cost of OutputDebugString under a debugger. To
// capture a trace for a bug report, set the environment variable
// CAMERA_DESKTOP_LOG to any value other than "0" before launching, then
// reproduce. Real errors still reach the app through the method channel
// (result.Error / cameraError) regardless of this setting.
inline bool DebugLogEnabled() {
  static const bool enabled = [] {
    char buf[16] = {};
    DWORD n = GetEnvironmentVariableA("CAMERA_DESKTOP_LOG", buf, sizeof(buf));
    if (n == 0) return false;             // not set
    if (n >= sizeof(buf)) return true;    // set to some long value
    return std::string(buf) != "0";
  }();
  return enabled;
}

inline void DebugLog(const std::string& msg) {
  if (!DebugLogEnabled()) return;
  std::string line = "[camera_desktop/windows] " + msg + "\n";
  OutputDebugStringA(line.c_str());
  std::fputs(line.c_str(), stderr);
  std::fflush(stderr);
}

inline std::string WideToUtf8(const std::wstring& w) {
  if (w.empty()) return {};
  int size = WideCharToMultiByte(CP_UTF8, 0, w.data(), (int)w.size(),
                                 nullptr, 0, nullptr, nullptr);
  std::string s(size, '\0');
  WideCharToMultiByte(CP_UTF8, 0, w.data(), (int)w.size(),
                      s.data(), size, nullptr, nullptr);
  return s;
}

inline std::string HrToString(HRESULT hr) {
  std::ostringstream ss;
  ss << "0x" << std::hex << static_cast<unsigned long>(hr);
  return ss.str();
}
