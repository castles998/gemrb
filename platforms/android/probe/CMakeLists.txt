cmake_minimum_required(VERSION 3.25)
project(gemrb_android_python_probe LANGUAGES C)

if(NOT ANDROID)
  message(FATAL_ERROR "Use the Android NDK CMake toolchain for this probe")
endif()
set(PYTHON_ANDROID_ROOT "" CACHE PATH "Extracted BeeWare Python 3.10 Android support b2")
set(python_library "${PYTHON_ANDROID_ROOT}/libs/${ANDROID_ABI}/libpython3.10.so")
if(NOT EXISTS "${python_library}")
  message(FATAL_ERROR "Missing Android Python library: ${python_library}")
endif()
add_library(android_python SHARED IMPORTED)
set_target_properties(android_python PROPERTIES
  IMPORTED_LOCATION "${python_library}"
  INTERFACE_INCLUDE_DIRECTORIES "${PYTHON_ANDROID_ROOT}/include/python3.10")
add_executable(gemrb_python_probe python_probe.c)
target_link_libraries(gemrb_python_probe PRIVATE android_python)
set_target_properties(gemrb_python_probe PROPERTIES BUILD_RPATH_USE_ORIGIN TRUE)
