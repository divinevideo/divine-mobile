cmake_minimum_required(VERSION 3.16)
project(divine_camera LANGUAGES CXX)
set(PLUGIN_NAME "divine_camera_plugin")
add_library(${PLUGIN_NAME} SHARED
  divine_camera_plugin.cc
  capture/camera_desktop_plugin.cc capture/camera_texture.cc capture/camera.cc
  capture/device_enumerator.cc capture/photo_handler.cc capture/record_handler.cc
  capture/image_stream_ffi.cc capture/pipewire_portal.cc)
apply_standard_settings(${PLUGIN_NAME})
target_compile_features(${PLUGIN_NAME} PRIVATE cxx_std_17)
set_target_properties(${PLUGIN_NAME} PROPERTIES CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)
target_include_directories(${PLUGIN_NAME} INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_include_directories(${PLUGIN_NAME} PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/capture")
find_package(PkgConfig REQUIRED)
pkg_check_modules(DIVINE_CAPTURE_GST REQUIRED IMPORTED_TARGET
  gstreamer-1.0 gstreamer-app-1.0 gstreamer-video-1.0)
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter PkgConfig::GTK PkgConfig::DIVINE_CAPTURE_GST)
set(divine_camera_bundled_libraries "" PARENT_SCOPE)

# Synthetic devices exist only in an explicitly opted-in Debug test consumer.
option(DIVINE_CAMERA_TEST_CAPTURE "Enable synthetic capture in Debug tests" OFF)
if(DIVINE_CAMERA_TEST_CAPTURE)
  target_compile_definitions(${PLUGIN_NAME} PRIVATE
    "$<$<CONFIG:Debug>:DIVINE_CAMERA_TEST_CAPTURE>")
endif()
