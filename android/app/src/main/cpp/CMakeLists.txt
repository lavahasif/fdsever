cmake_minimum_required(VERSION 3.22.1)
project("fdserver_monitor" LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_library(fdserver_monitor SHARED
    native_monitor.cpp
)

# Android log library for __android_log_print
find_library(log-lib log)

target_link_libraries(fdserver_monitor
    ${log-lib}
)

# Optimization flags for release builds
target_compile_options(fdserver_monitor PRIVATE
    -O2
    -fvisibility=hidden
    -ffunction-sections
    -fdata-sections
)
