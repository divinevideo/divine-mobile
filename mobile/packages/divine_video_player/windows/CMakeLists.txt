cmake_minimum_required(VERSION 3.14)

set(PROJECT_NAME "divine_video_player")
project(${PROJECT_NAME} LANGUAGES CXX)

# This value is used when generating builds using this plugin, so it must
# not be changed.
set(PLUGIN_NAME "divine_video_player_plugin")

add_library(${PLUGIN_NAME} SHARED
  "audio_overlays.cpp"
  "audio_overlays.h"
  "audio_shaping.cpp"
  "audio_shaping.h"
  "divine_video_player_plugin_c_api.cpp"
  "divine_video_player_plugin.cpp"
  # Exports the activation factory Windows uses to create the audio effect.
  "divine_video_player_plugin.def"
  "divine_video_player_plugin.h"
  "encodable_utils.h"
  "media_sources.cpp"
  "media_sources.h"
  "native_log.cpp"
  "native_log.h"
  "platform_thread.cpp"
  "platform_thread.h"
  "playback_telemetry.cpp"
  "playback_telemetry.h"
  "remote_media.cpp"
  "remote_media.h"
  "texture_output.cpp"
  "texture_output.h"
  "timeline.cpp"
  "timeline.h"
  "track_ends.cpp"
  "track_ends.h"
  "video_player_instance.cpp"
  "video_player_instance.h"
)

# apply_standard_settings() turns C++ exceptions off, and C++/WinRT reports
# every failed Windows Runtime call as an exception, so this target sets the
# same warnings itself and keeps exceptions on. C++20 brings the coroutines
# the asynchronous Windows Runtime calls are awaited with.
target_compile_features(${PLUGIN_NAME} PUBLIC cxx_std_20)
target_compile_options(${PLUGIN_NAME} PRIVATE /W4 /WX /wd"4100" /EHsc /bigobj)
target_compile_definitions(${PLUGIN_NAME} PRIVATE
  "$<$<CONFIG:Debug>:_DEBUG>"
  FLUTTER_PLUGIN_IMPL
  NOMINMAX
  WIN32_LEAN_AND_MEAN
)

set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_link_libraries(${PLUGIN_NAME} PRIVATE
  flutter
  flutter_wrapper_plugin
  d3d11
  dxgi
  windowsapp
)

# Nothing to bundle: playback uses Media Foundation from Windows itself.
set(divine_video_player_bundled_libraries
  ""
  PARENT_SCOPE
)
