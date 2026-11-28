cmake_minimum_required(VERSION 3.19)
project(divine_camera LANGUAGES CXX)
set(PLUGIN_NAME "divine_camera_plugin")
add_library(${PLUGIN_NAME} SHARED
  divine_camera_plugin.cpp capture/camera_desktop_plugin.cpp capture/camera.cpp
  capture/camera_texture.cpp capture/device_enumerator.cpp capture/image_stream_ffi.cpp
  capture/photo_handler.cpp capture/record_handler.cpp)
apply_standard_settings(${PLUGIN_NAME})
target_compile_features(${PLUGIN_NAME} PRIVATE cxx_std_17)
set_target_properties(${PLUGIN_NAME} PROPERTIES CXX_VISIBILITY_PRESET hidden)
get_target_property(_divine_capture_definitions ${PLUGIN_NAME} COMPILE_DEFINITIONS)
list(REMOVE_ITEM _divine_capture_definitions "_HAS_EXCEPTIONS=0")
set_target_properties(${PLUGIN_NAME} PROPERTIES COMPILE_DEFINITIONS "${_divine_capture_definitions}")
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL _HAS_EXCEPTIONS=1 NOMINMAX WIN32_LEAN_AND_MEAN)
if(MSVC)
  target_compile_options(${PLUGIN_NAME} PRIVATE /utf-8 /EHsc)
endif()
target_include_directories(${PLUGIN_NAME} PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/../native/include")
target_include_directories(${PLUGIN_NAME} INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter flutter_wrapper_plugin
  mf mfplat mfreadwrite mfuuid ole32 strmiids uuid windowscodecs d3d11 dxgi)
# The owning integration harness may opt into synthetic devices for Debug.
# A Release build never defines either test source macro.
option(DIVINE_CAMERA_TEST_CAPTURE "Enable synthetic capture in Debug tests" OFF)
if(DIVINE_CAMERA_TEST_CAPTURE)
  target_sources(${PLUGIN_NAME} PRIVATE capture/fake_camera_source.cpp)
  target_compile_definitions(${PLUGIN_NAME} PRIVATE
    "$<$<CONFIG:Debug>:CAMERA_DESKTOP_FAKE_CAMERA>"
    "$<$<CONFIG:Debug>:DIVINE_CAMERA_TEST_CAPTURE>")
endif()
set(divine_camera_bundled_libraries "" PARENT_SCOPE)
