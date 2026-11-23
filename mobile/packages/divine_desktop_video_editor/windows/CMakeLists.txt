cmake_minimum_required(VERSION 3.19)
project(divine_desktop_video_editor LANGUAGES CXX)
set(PLUGIN_NAME "divine_desktop_video_editor_plugin")
add_library(${PLUGIN_NAME} SHARED divine_desktop_video_editor_plugin.cpp worker_lifetime.cpp)
apply_standard_settings(${PLUGIN_NAME})
# Filesystem failures are translated at the channel boundary. Keep STL
# exceptions enabled for this target rather than inheriting Flutter's disabled
# STL exception definition, which would terminate on those failures.
get_target_property(_divine_definitions ${PLUGIN_NAME} COMPILE_DEFINITIONS)
list(REMOVE_ITEM _divine_definitions "_HAS_EXCEPTIONS=0")
set_target_properties(${PLUGIN_NAME} PROPERTIES COMPILE_DEFINITIONS "${_divine_definitions}")
target_compile_definitions(${PLUGIN_NAME} PRIVATE _HAS_EXCEPTIONS=1)
target_compile_features(${PLUGIN_NAME} PRIVATE cxx_std_17)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL NOMINMAX WIN32_LEAN_AND_MEAN)
target_include_directories(${PLUGIN_NAME} INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter flutter_wrapper_plugin)
add_subdirectory("../native" "${CMAKE_CURRENT_BINARY_DIR}/media")
add_dependencies(${PLUGIN_NAME} divine_media_worker)
set(divine_desktop_video_editor_bundled_libraries "" PARENT_SCOPE)
function(_divine_install_media_worker)
  # Flutter's Windows install prefix contains $<TARGET_FILE_DIR:...>. Put it
  # directly in DESTINATION so CMake evaluates it; a relative destination
  # prepends the unresolved prefix at install time instead.
  install(TARGETS divine_media_worker
    RUNTIME DESTINATION "${CMAKE_INSTALL_PREFIX}/data/divine_media" COMPONENT Runtime)
endfunction()
cmake_language(DEFER DIRECTORY "${CMAKE_SOURCE_DIR}" CALL _divine_install_media_worker)
